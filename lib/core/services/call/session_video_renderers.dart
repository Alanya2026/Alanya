import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Rendus vidéo d'une session, à durée de vie **session** et non écran.
///
/// Ils vivaient dans `_OngoingCallScreenState` et `_OngoingMeetScreenState`,
/// donc créés à l'ouverture de l'écran plein et détruits à sa fermeture. Tant
/// que la vidéo ne s'affichait qu'à cet endroit, c'était juste. Ça ne l'est plus
/// dès qu'une fenêtre flottante doit continuer à montrer l'appel après que
/// l'écran a été quitté : le rendu qu'elle afficherait aurait été libéré sous
/// elle. Un rendu détruit ne lève pas — il rend un carré noir —, ce qui rend le
/// défaut d'autant plus désagréable à diagnostiquer.
///
/// La propriété vit donc ici, et la libération est arrimée à la fin de session
/// (`CallSessionGuard.release`), là où sont déjà soldés le wakelock, la
/// proximité, le service de premier plan et CallKit. Les écrans et la fenêtre
/// **s'abonnent** : ils lisent, ils n'initialisent ni ne libèrent jamais.
class SessionVideoRenderers extends ChangeNotifier {
  SessionVideoRenderers._();
  static final SessionVideoRenderers instance = SessionVideoRenderers._();

  RTCVideoRenderer? _local;
  RTCVideoRenderer? _remote;
  final Map<String, RTCVideoRenderer> _group = {};

  bool _ready = false;
  bool _initializing = false;
  bool _syncingGroup = false;

  ChangeNotifier? _source;
  VoidCallback? _onSourceChanged;

  bool _localCameraFront = true;

  /// La vue locale n'est en miroir que devant la caméra avant, où l'on se
  /// regarde comme dans une glace. Sur la caméra arrière, une image inversée
  /// part à l'opposé du geste de celui qui tient le téléphone.
  ///
  /// Ne concerne que l'affichage local : la vidéo envoyée n'est jamais inversée.
  bool get mirrorLocal => _localCameraFront;

  /// À appeler après une bascule, et à chaque nouvelle capture, qui part
  /// toujours sur la caméra avant.
  void setLocalCameraFront(bool isFront) {
    if (_localCameraFront == isFront) return;
    _localCameraFront = isFront;
    notifyListeners();
  }

  /// True quand `local` et `remote` sont initialisés et affichables.
  bool get isReady => _ready;

  /// Rendu de la caméra locale. Null tant que [ensureInitialized] n'a pas fini.
  RTCVideoRenderer? get local => _local;

  /// Rendu du correspondant en 1-à-1 (ou du flux mis en avant).
  RTCVideoRenderer? get remote => _remote;

  /// Rendus des participants d'une conférence ou d'une réunion, par identifiant.
  Map<String, RTCVideoRenderer> get group => Map.unmodifiable(_group);

  RTCVideoRenderer? groupRenderer(String id) => _group[id];

  /// La première trame arrive, ou la taille change — une caméra qu'on rallume,
  /// typiquement.
  ///
  /// Sans cette notification, la tuile restait figée sur l'avatar après une
  /// reprise : rien n'annonçait à l'interface qu'il y avait de nouveau une
  /// image à montrer. Le branchement vit ici depuis que les rendus y vivent,
  /// et sert du même coup l'écran d'appel, celui de réunion et les fenêtres.
  void _onRendererResize() => notifyListeners();

  /// Prépare les deux rendus principaux. Idempotent et sûr en concurrence :
  /// l'écran plein et la fenêtre flottante peuvent l'appeler en même temps.
  Future<void> ensureInitialized() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      final local = RTCVideoRenderer();
      final remote = RTCVideoRenderer();
      await local.initialize();
      await remote.initialize();
      local.onResize = _onRendererResize;
      remote.onResize = _onRendererResize;
      _local = local;
      _remote = remote;
      _ready = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[SessionVideoRenderers] ** initialisation: $e');
    } finally {
      _initializing = false;
    }
  }

  /// S'abonne au service qui porte les flux, et rejoue [sync] à chaque
  /// changement.
  ///
  /// L'abonnement vit ici plutôt que dans l'écran, et c'est tout l'intérêt :
  /// c'était `_OngoingCallScreenState` qui tenait `srcObject` à jour, donc plus
  /// personne ne le faisait dès l'écran quitté. Un correspondant qui rallume sa
  /// caméra pendant que l'appel est en fenêtre doit apparaître quand même.
  void bind(ChangeNotifier source, VoidCallback sync) {
    unbind();
    _source = source;
    _onSourceChanged = sync;
    source.addListener(sync);
    sync();
  }

  void unbind() {
    final source = _source;
    final listener = _onSourceChanged;
    if (source != null && listener != null) {
      source.removeListener(listener);
    }
    _source = null;
    _onSourceChanged = null;
  }

  /// Branche les flux principaux. Sans effet si rien n'a changé — réaffecter
  /// `srcObject` à l'identique refait passer le rendu par un cycle noir.
  void syncMain({MediaStream? localStream, MediaStream? remoteStream}) {
    if (!_ready) return;
    var changed = false;
    if (_local!.srcObject != localStream) {
      _local!.srcObject = localStream;
      changed = true;
    }
    if (_remote!.srcObject != remoteStream) {
      _remote!.srcObject = remoteStream;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Aligne les rendus de groupe sur les flux présents : crée ce qui manque,
  /// libère ce qui est parti. Voir [diffGroupRenderers] pour la décision.
  Future<void> syncGroup(Map<String, MediaStream> streams) async {
    // Le déclencheur est un `notifyListeners` synchrone, mais l'initialisation
    // d'un rendu ne l'est pas : deux notifications rapprochées lanceraient deux
    // passes concurrentes, qui créeraient chacune un rendu pour le même
    // participant. La seconde est simplement sautée — une notification suivra.
    if (_syncingGroup) return;
    _syncingGroup = true;
    try {
      await _syncGroup(streams);
    } finally {
      _syncingGroup = false;
    }
  }

  Future<void> _syncGroup(Map<String, MediaStream> streams) async {
    final diff = diffGroupRenderers(
      existing: _group.keys.toSet(),
      incoming: streams.keys.toSet(),
    );
    if (diff.toCreate.isEmpty && diff.toDrop.isEmpty) {
      // Les identifiants n'ont pas bougé, mais un flux a pu être remplacé.
      var changed = false;
      streams.forEach((id, stream) {
        final r = _group[id];
        if (r != null && r.srcObject != stream) {
          r.srcObject = stream;
          changed = true;
        }
      });
      if (changed) notifyListeners();
      return;
    }

    for (final id in diff.toDrop) {
      final renderer = _group.remove(id);
      if (renderer == null) continue;
      renderer.srcObject = null;
      await renderer.dispose();
    }

    for (final id in diff.toCreate) {
      final renderer = RTCVideoRenderer();
      try {
        await renderer.initialize();
      } catch (e) {
        debugPrint('[SessionVideoRenderers] ** rendu $id: $e');
        continue;
      }
      renderer.onResize = _onRendererResize;
      _group[id] = renderer;
    }

    streams.forEach((id, stream) {
      final r = _group[id];
      if (r != null && r.srcObject != stream) r.srcObject = stream;
    });

    notifyListeners();
  }

  /// Détache les flux sans rien libérer, et sans rien attendre.
  ///
  /// Pour le seul cas où l'activité meurt sous nos pieds : le moteur Flutter se
  /// détache alors que le producteur d'images continue de pousser des trames, et
  /// la première arrivée après coup emporte le processus — `FlutterJNI is not
  /// attached to native`, levée depuis `ImageReaderSurfaceProducer.onImage`.
  ///
  /// [release] ne peut pas servir ici : ses `dispose()` sont autant d'allers et
  /// retours qui n'auront pas le temps de s'exécuter. Le détachement, lui, part
  /// en un message par rendu et a une chance d'arriver avant la fin. C'est un
  /// filet, pas une garantie.
  ///
  /// Réversible : [resync] rebranche tout si l'application revient.
  void detachStreams() {
    if (!_ready && _group.isEmpty) return;
    for (final renderer in _group.values) {
      renderer.srcObject = null;
    }
    _local?.srcObject = null;
    _remote?.srcObject = null;
    debugPrint('[SessionVideoRenderers] Flux détachés (activité détruite)');
  }

  /// Rejoue le branchement des flux posé par [bind].
  ///
  /// `syncMain` ne réaffecte que ce qui a changé : après un [detachStreams],
  /// tout a changé, et tout revient.
  void resync() => _onSourceChanged?.call();

  /// Libère tout. Appelée à la fin de session, jamais depuis un écran.
  Future<void> release() async {
    unbind();
    _localCameraFront = true;
    if (!_ready && _group.isEmpty) return;

    for (final renderer in _group.values) {
      renderer.srcObject = null;
      try {
        await renderer.dispose();
      } catch (e) {
        debugPrint('[SessionVideoRenderers] ** dispose groupe: $e');
      }
    }
    _group.clear();

    // `srcObject = null` avant `dispose` : le rendu détaché de son flux ne peut
    // plus recevoir d'image pendant la libération.
    _local?.srcObject = null;
    _remote?.srcObject = null;
    try {
      await _local?.dispose();
      await _remote?.dispose();
    } catch (e) {
      debugPrint('[SessionVideoRenderers] ** dispose principal: $e');
    }
    _local = null;
    _remote = null;
    _ready = false;
    notifyListeners();
    debugPrint('[SessionVideoRenderers] Rendus libérés');
  }
}

/// Ce qu'il faut créer et ce qu'il faut libérer pour aligner les rendus de
/// groupe sur les flux présents.
///
/// Isolée du reste parce que c'est ici que se logent les fautes — un rendu
/// oublié fuit la mémoire vidéo, un rendu libéré trop tôt noircit la tuile d'un
/// participant qui parle encore — et parce que c'est la seule part de ce
/// fichier qui se teste sans appareil.
({Set<String> toCreate, Set<String> toDrop}) diffGroupRenderers({
  required Set<String> existing,
  required Set<String> incoming,
}) {
  return (
    toCreate: incoming.difference(existing),
    toDrop: existing.difference(incoming),
  );
}
