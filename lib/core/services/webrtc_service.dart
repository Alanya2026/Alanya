import 'dart:async';
import 'call/call_ice_constraints.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../theme/locale_controller.dart';
import 'call/call_permissions_helper.dart';
import 'call/video_capture_profile.dart';

enum CallType { audio, video }

class _BufferedIce {
  _BufferedIce(this.candidate, this.generation) : addedAt = DateTime.now();
  final RTCIceCandidate candidate;
  final int generation;
  final DateTime addedAt;
}

class WebRTCService {
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final List<_BufferedIce> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;
  int _iceGeneration = 0;
  static const int _maxPendingIce = 64;
  static const Duration _pendingIceTtl = Duration(seconds: 30);
  bool _replaceAudioLock = false;

  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCSessionDescription)? onOffer;
  Function(RTCSessionDescription)? onAnswer;

  /// @deprecated Préférer [onConnectionStateChanged]. Conservé pour compat.
  Function()? onConnectionFailure;
  Function(RTCPeerConnectionState)? onConnectionStateChanged;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get hasLocalVideoTrack =>
      _localStream?.getVideoTracks().isNotEmpty == true;
  int get iceGeneration => _iceGeneration;
  RTCPeerConnectionState? get connectionState =>
      _peerConnection?.connectionState;

  bool get isPcConnected =>
      connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  bool get isPcUsable {
    final s = connectionState;
    if (s == null || _peerConnection == null) return false;
    return s != RTCPeerConnectionState.RTCPeerConnectionStateFailed &&
        s != RTCPeerConnectionState.RTCPeerConnectionStateClosed;
  }

  /// Exposé pour `SpeakingDetector` (lecture de `getStats()` afin de
  /// détecter qui parle). Ne pas utiliser pour modifier l'état du PC depuis
  /// l'extérieur de ce service.
  RTCPeerConnection? get peerConnection => _peerConnection;

  // Les demandes de permission micro/caméra vivent désormais dans
  // `CallPermissionsHelper.ensureCallMediaPermissions` : elles lisent le statut
  // avant de demander, et sont jouées dès la sonnerie plutôt qu'entre le tap
  // sur « Répondre » et l'ouverture de la capture.

  /// Ferme la pile média précédente s'il en reste une.
  ///
  /// Contrairement à [dispose], ne touche ni aux callbacks ni au flux distant
  /// assigné par l'appelant : `init` va tout réassigner juste après. Le but est
  /// uniquement de ne pas laisser derrière soi une PeerConnection vivante et
  /// des pistes de capture ouvertes.
  Future<void> _disposeCurrentStack() async {
    final previousPc = _peerConnection;
    final previousStream = _localStream;
    if (previousPc == null && previousStream == null) return;

    debugPrint(
      '[WebRTC] ♻ Pile précédente encore présente — fermeture avant réinit',
    );
    _peerConnection = null;
    _localStream = null;
    _remoteDescriptionSet = false;
    clearPendingIce();

    if (previousPc != null) {
      // Désarmer d'abord : un Closed émis pendant close() ne doit pas réveiller
      // les handlers de l'appel courant.
      previousPc.onIceCandidate = null;
      previousPc.onConnectionState = null;
      previousPc.onIceConnectionState = null;
      previousPc.onTrack = null;
      try {
        await previousPc.close();
      } catch (e) {
        debugPrint('[WebRTC] ** Erreur fermeture PC précédente: $e');
      }
    }

    if (previousStream != null) {
      for (final track in previousStream.getTracks()) {
        try {
          await track.stop();
        } catch (e) {
          debugPrint('[WebRTC] ** Erreur arrêt piste précédente: $e');
        }
      }
      try {
        await previousStream.dispose();
      } catch (e) {
        debugPrint('[WebRTC] ** Erreur disposition stream précédent: $e');
      }
    }
  }

  /// Initialisation complète : capture puis pile de transport.
  ///
  /// Conservée pour les appelants qui n'ont rien à gagner à séparer les deux
  /// phases (conférence, restauration d'un sortant, réunions). Le décrochage
  /// 1-à-1, lui, appelle [acquireLocalMedia] et [buildPeerConnection]
  /// séparément afin de lancer la capture sans attendre le réseau.
  Future<void> init(
    CallType type, {
    List<Map<String, dynamic>>? iceServers,
  }) async {
    await acquireLocalMedia(type);
    await buildPeerConnection(type, iceServers: iceServers);
  }

  /// Ouvre le micro (et la caméra en vidéo). Ne touche pas au transport.
  ///
  /// C'est ici, et nulle part ailleurs, que le témoin de confidentialité
  /// s'allume. La capture ne dépend ni des serveurs ICE ni de la
  /// `PeerConnection` : les enchaîner plaçait l'ouverture du micro derrière un
  /// aller-retour HTTPS vers `/turn/credentials` et une construction native,
  /// d'où les quelques secondes de décalage après le décrochage.
  Future<MediaStream> acquireLocalMedia(CallType type) async {
    try {
      debugPrint('[WebRTC] ========== Acquisition média ==========');
      debugPrint(
        '[WebRTC] isWeb: $kIsWeb, Platform: ${kIsWeb ? "WEB" : (_isAndroid ? "ANDROID" : "iOS")}',
      );
      debugPrint('[WebRTC] Call Type: $type');

      // La pile précédente est fermée ICI, et surtout pas dans
      // [buildPeerConnection] : `_disposeCurrentStack` ferme aussi
      // `_localStream`, elle détruirait donc le flux qu'on vient d'acquérir.
      await _disposeCurrentStack();

      if (!kIsWeb) {
        // Normalement déjà acquise pendant la sonnerie : cet appel ne fait
        // alors que relire un statut. S'il faut vraiment demander — préchauffage
        // non joué, réveil par push — le comportement reste celui d'avant.
        final micGranted =
            await CallPermissionsHelper.ensureCallMediaPermissions(
              isVideo: type == CallType.video,
            );
        if (!micGranted) {
          throw Exception(
            LocaleController.instance.l10n.microphonePermissionDenied,
          );
        }
      } else {
        debugPrint(
          '[WebRTC] Plateforme WEB - Les permissions seront demandées par le navigateur via getUserMedia',
        );
      }

      debugPrint('[WebRTC] Appel à _getUserMedia...');
      _localStream = await _getUserMedia(type);
      debugPrint(
        '[WebRTC] !! Local stream obtenu: ${_localStream?.getTracks().length} track(s), ID=${_localStream?.id}',
      );
      onLocalStream?.call(_localStream!);
      return _localStream!;
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur lors de l\'acquisition média: $e');
      await dispose();
      rethrow;
    }
  }

  /// Acquiert et attache uniquement une piste vidéo à une session audio
  /// existante. Le flux audio et la PeerConnection restent en place.
  Future<void> addLocalVideoTrack() async {
    final stream = _localStream;
    final pc = _peerConnection;
    if (stream == null || pc == null) {
      throw StateError('Impossible d’ajouter la vidéo sans session WebRTC');
    }
    if (hasLocalVideoTrack) return;

    MediaStream? videoOnlyStream;
    try {
      videoOnlyStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': videoCaptureConstraints(),
      });
      final tracks = videoOnlyStream.getVideoTracks();
      if (tracks.isEmpty) {
        throw StateError('Aucune piste vidéo fournie par la caméra');
      }
      final track = tracks.first;
      await stream.addTrack(track);
      await pc.addTrack(track, stream);
      onLocalStream?.call(stream);
    } catch (error) {
      for (final track
          in videoOnlyStream?.getTracks() ?? const <MediaStreamTrack>[]) {
        try {
          await track.stop();
        } catch (stopError) {
          debugPrint('[WebRTC] ** Erreur arrêt vidéo après échec: $stopError');
        }
      }
      try {
        await videoOnlyStream?.dispose();
      } catch (disposeError) {
        debugPrint(
          '[WebRTC] ** Erreur disposition vidéo après échec: $disposeError',
        );
      }
      rethrow;
    }
  }

  /// Retire la piste vidéo ajoutée par une renégociation échouée.
  Future<bool> discardLocalVideoTrack() async {
    final stream = _localStream;
    final pc = _peerConnection;
    if (stream == null) return true;
    var succeeded = true;
    final tracks = List<MediaStreamTrack>.from(stream.getVideoTracks());
    if (pc != null) {
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          try {
            await sender.replaceTrack(null);
          } catch (error) {
            succeeded = false;
            debugPrint(
              '[WebRTC] ** Erreur retrait piste vidéo du sender: $error',
            );
          }
        }
      }
    }
    for (final track in tracks) {
      try {
        await stream.removeTrack(track);
      } catch (error) {
        succeeded = false;
        debugPrint('[WebRTC] ** Erreur retrait piste vidéo du flux: $error');
      }
      try {
        await track.stop();
      } catch (error) {
        succeeded = false;
        debugPrint('[WebRTC] ** Erreur arrêt piste vidéo: $error');
      }
    }
    onLocalStream?.call(stream);
    return succeeded;
  }

  /// Construit la `PeerConnection` et y attache le flux déjà acquis.
  ///
  /// Suppose [acquireLocalMedia] appelée au préalable.
  Future<void> buildPeerConnection(
    CallType type, {
    List<Map<String, dynamic>>? iceServers,
  }) async {
    try {
      final localStream = _localStream;
      if (localStream == null) {
        throw StateError(
          'buildPeerConnection sans flux local : appeler acquireLocalMedia d\'abord',
        );
      }

      final configuration = {
        'iceServers':
            iceServers ??
            const [
              {'urls': 'stun:stun.l.google.com:19302'},
              {'urls': 'stun:stun1.l.google.com:19302'},
            ],
      };

      // La pile précédente a déjà été soldée par [acquireLocalMedia]. Ne PAS
      // la refermer ici : `_disposeCurrentStack` arrête aussi les pistes de
      // `_localStream`, et le flux qu'on s'apprête à attacher est justement
      // celui qu'elle vient d'ouvrir.
      debugPrint(
        '[WebRTC] Création du PeerConnection avec ${(configuration['iceServers'] as List).length} iceServer(s)...',
      );
      _peerConnection = await createPeerConnection(configuration);
      debugPrint('[WebRTC] PeerConnection créé avec succès');

      _peerConnection!.onIceCandidate = (candidate) {
        // Type host = LAN, srflx = via STUN, relay = via TURN.
        final c = candidate.candidate ?? '';
        final type = c.contains(' typ relay ')
            ? 'relay/TURN'
            : c.contains(' typ srflx ')
            ? 'srflx/STUN'
            : c.contains(' typ host ')
            ? 'host/LAN'
            : 'unknown';
        debugPrint(
          '[WebRTC] 🧊 ICE candidate généré (type=$type, candidate=${c.split(' ').first}) cb=${onIceCandidate != null}',
        );
        onIceCandidate?.call(candidate);
      };

      _peerConnection!.onIceConnectionState = (state) {
        debugPrint('[WebRTC] 🔗 ICE connection state: $state');
      };

      _peerConnection!.onConnectionState = (state) {
        debugPrint('[WebRTC] 🔌 Peer connection state: $state');
        onConnectionStateChanged?.call(state);

        // Closed = terminal. Disconnected = transitoire (ne pas fail immédiat).
        // Failed = hard failure (ICE restart côté CallService, pas hang-up ici).
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          debugPrint('[WebRTC] ** Peer connection closed (terminal)');
          onConnectionFailure?.call();
          return;
        }
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          debugPrint('[WebRTC] ** Peer connection failed (restart needed)');
          // Compat: anciens handlers qui terminent encore via onConnectionFailure
          // sont remplacés progressivement ; on n'appelle plus failure sur Failed
          // si onConnectionStateChanged est branché.
          if (onConnectionStateChanged == null) {
            onConnectionFailure?.call();
          }
        }
        // Disconnected : volontairement ignoré pour hang-up (CallService gère).
      };

      _peerConnection!.onIceGatheringState = (state) {
        debugPrint('[WebRTC] 🧊 ICE gathering state: $state');
      };

      _peerConnection!.onTrack = (event) {
        debugPrint(
          '[WebRTC] 🎥 Track reçu: ${event.streams.length} stream(s), kind=${event.track.kind}',
        );
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint(
            '[WebRTC] !! Remote stream assigné (ID=${_remoteStream?.id})',
          );
          debugPrint(
            '[WebRTC]  Remote stream tracks: Audio=${_remoteStream?.getAudioTracks().length}, Video=${_remoteStream?.getVideoTracks().length}',
          );

          // Log détails des pistes
          _remoteStream?.getAudioTracks().forEach((track) {
            debugPrint(
              '[WebRTC] 🎵 Audio track: kind=${track.kind}, enabled=${track.enabled}, label="${track.label}", id=${track.id}',
            );
          });
          _remoteStream?.getVideoTracks().forEach((track) {
            debugPrint(
              '[WebRTC]  Video track: kind=${track.kind}, enabled=${track.enabled}, label="${track.label}", id=${track.id}',
            );
          });

          onRemoteStream?.call(_remoteStream!);
        } else {
          debugPrint('[WebRTC] ** Track reçu sans streams!');
        }
      };

      debugPrint('[WebRTC] Ajout des tracks au PeerConnection...');
      localStream.getTracks().forEach((track) {
        debugPrint(
          '[WebRTC] ➕ Ajout track: kind=${track.kind}, enabled=${track.enabled}, label="${track.label}", id=${track.id}',
        );
        _peerConnection!.addTrack(track, localStream);
      });
      debugPrint(
        '[WebRTC] Local stream setup: Audio=${localStream.getAudioTracks().length}, Video=${localStream.getVideoTracks().length}',
      );

      if (_isAndroid) {
        debugPrint('[WebRTC] Configuration des transceivers pour Android...');
        try {
          final audioTransceivers = await _peerConnection!.getTransceivers();
          for (final t in audioTransceivers) {
            debugPrint('[WebRTC]   - mid=${t.mid}');
          }
        } catch (e) {
          debugPrint('[WebRTC] ** Erreur vérification transceivers: $e');
        }
      }

      // !! Log des transceivers (diagnostic Android)
      if (_isAndroid) {
        try {
          final transceivers = await _peerConnection!.getTransceivers();
          debugPrint('[WebRTC] 📡 Transceivers finaux: ${transceivers.length}');
          for (int i = 0; i < transceivers.length; i++) {
            final t = transceivers[i];
            debugPrint('[WebRTC]   [$i] mid=${t.mid}');
          }
        } catch (e) {
          debugPrint('[WebRTC] ** Erreur lecture des transceivers: $e');
        }
      }

      debugPrint(
        '[WebRTC] ========== Initialisation WebRTC réussie ==========',
      );
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur lors de l\'initialisation: $e');
      debugPrint('[WebRTC] Type d\'erreur: ${e.runtimeType}');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      await dispose();
      rethrow;
    }
  }

  Future<MediaStream> _getUserMedia(CallType type) async {
    try {
      debugPrint(
        '[WebRTC] _getUserMedia - Type: $type, isWeb: $kIsWeb, Platform: ${_isAndroid ? "ANDROID" : "iOS/WEB"}',
      );

      final dynamic audioConstraints;

      if (_isAndroid) {
        // Format compatible avec Android et flutter_webrtc
        audioConstraints = {
          'mandatory': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
        };
      } else if (kIsWeb) {
        // Format WebRTC standard pour le web
        audioConstraints = {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        };
      } else {
        // iOS et autres : accepter n'importe quel audio
        audioConstraints = true;
      }

      final constraints = <String, dynamic>{
        'audio': audioConstraints,
        'video': type == CallType.video ? videoCaptureConstraints() : false,
      };

      debugPrint('[WebRTC] Contraintes: $constraints');

      try {
        return await navigator.mediaDevices.getUserMedia(constraints);
      } catch (e1) {
        debugPrint('[WebRTC] ** getUserMedia avec contraintes échouée: $e1');

        // Fallback avec contraintes minimales sur Android
        if (_isAndroid) {
          debugPrint(
            '[WebRTC] 📍 Tentative fallback Android avec contraintes minimales...',
          );
          final fallbackConstraints = <String, dynamic>{
            'audio': true,
            'video': type == CallType.video
                ? {
                    'width': {'ideal': 720},
                    'height': {'ideal': 480},
                  }
                : false,
          };
          debugPrint('[WebRTC] Contraintes fallback: $fallbackConstraints');
          try {
            return await navigator.mediaDevices.getUserMedia(
              fallbackConstraints,
            );
          } catch (e2) {
            // Dernier repli : l'audio seul.
            //
            // `ensureCallMediaPermissions` documente et applique déjà « une
            // caméra refusée n'est pas bloquante : l'appel se dégrade en
            // audio » — elle se contente de journaliser et rend l'état du
            // micro. Mais rien en aval ne dégradait quoi que ce soit : les deux
            // tentatives ci-dessus demandent la vidéo, l'exception remontait
            // jusqu'au `catch` d'`answerCall`, qui appelait `rejectCall()`.
            //
            // Un appel vidéo entrant décroché sur un téléphone où la caméra n'a
            // jamais été autorisée était donc REFUSÉ — l'appelant recevait un
            // refus — alors que le micro, lui, était accordé. Et le démarrage à
            // froid depuis une notification est exactement le contexte où la
            // permission caméra n'a jamais été demandée au calme.
            if (type != CallType.video) rethrow;
            debugPrint('[WebRTC] ** vidéo indisponible ($e2) → audio seul');
            return await navigator.mediaDevices.getUserMedia(<String, dynamic>{
              'audio': true,
              'video': false,
            });
          }
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur getUserMedia: $e');
      debugPrint('[WebRTC] Type d\'erreur: ${e.runtimeType}');
      debugPrint('[WebRTC] Stack: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer({bool iceRestart = false}) async {
    debugPrint('[WebRTC]  Création offre SDP iceRestart=$iceRestart...');
    try {
      final offer = iceRestart
          ? await _peerConnection!.createOffer(iceRestartOfferConstraints)
          : await _peerConnection!.createOffer();
      debugPrint(
        '[WebRTC] !! Offre créée: type=${offer.type}, sdp_length=${offer.sdp?.length}',
      );

      // Log les codecs dans l'offre (diagnostic)
      if (offer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(
          r'a=rtpmap:\d+ (\w+)',
        ).allMatches(offer.sdp!);
        debugPrint('[WebRTC]  Codecs dans l\'offre:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }

      await _peerConnection!.setLocalDescription(offer);
      debugPrint('[WebRTC] !! LocalDescription définie');
      return offer;
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur createOffer: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Incrémente la génération ICE et purge les candidats bufferisés.
  int bumpIceGeneration() {
    _iceGeneration += 1;
    clearPendingIce();
    debugPrint('[WebRTC] iceGeneration=$_iceGeneration (bump + purge buffer)');
    return _iceGeneration;
  }

  void clearPendingIce() {
    _pendingIceCandidates.clear();
  }

  /// true si [generation] est encore la génération courante (null = accepter).
  bool acceptsIceGeneration(int? generation) {
    if (generation == null) return true;
    return generation == _iceGeneration;
  }

  Future<RTCSessionDescription> createAnswer() async {
    debugPrint('[WebRTC]  Création réponse SDP...');
    try {
      final answer = await _peerConnection!.createAnswer();
      debugPrint(
        '[WebRTC] !! Réponse créée: type=${answer.type}, sdp_length=${answer.sdp?.length}',
      );

      // Log les codecs dans la réponse (diagnostic)
      if (answer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(
          r'a=rtpmap:\d+ (\w+)',
        ).allMatches(answer.sdp!);
        debugPrint('[WebRTC] Codecs dans la réponse:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }

      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[WebRTC] !! LocalDescription définie');
      return answer;
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur createAnswer: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<bool> rollbackNegotiation() async {
    final pc = _peerConnection;
    if (pc == null) return true;
    try {
      await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
      return true;
    } catch (error) {
      debugPrint('[WebRTC] ** Rollback renégociation impossible: $error');
      return false;
    }
  }

  Future<void> handleOffer(RTCSessionDescription offer) async {
    debugPrint(
      '[WebRTC] 📥 Traitement offre reçue: type=${offer.type}, sdp_length=${offer.sdp?.length}',
    );
    try {
      // Log les codecs dans l'offre reçue (diagnostic)
      if (offer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(
          r'a=rtpmap:\d+ (\w+)',
        ).allMatches(offer.sdp!);
        debugPrint('[WebRTC] 📋 Codecs dans l\'offre reçue:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }

      await _peerConnection!.setRemoteDescription(offer);
      debugPrint('[WebRTC] !! RemoteDescription (offre) définie');

      _remoteDescriptionSet = true;
      await _flushPendingIceCandidates();
      debugPrint('[WebRTC] !! handleOffer succès');
    } catch (e) {
      debugPrint('[WebRTC] ** handleOffer échoué: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> handleAnswer(RTCSessionDescription answer) async {
    debugPrint(
      '[WebRTC] ... Traitement réponse reçue: type=${answer.type}, sdp_length=${answer.sdp?.length}',
    );
    try {
      // Log les codecs dans la réponse reçue (diagnostic)
      if (answer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(
          r'a=rtpmap:\d+ (\w+)',
        ).allMatches(answer.sdp!);
        debugPrint('[WebRTC] 📋 Codecs dans la réponse reçue:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }

      await _peerConnection!.setRemoteDescription(answer);
      debugPrint('[WebRTC] !! RemoteDescription (réponse) définie');

      _remoteDescriptionSet = true;
      await _flushPendingIceCandidates();
      debugPrint('[WebRTC] !! handleAnswer succès');
    } catch (e) {
      debugPrint('[WebRTC] ** handleAnswer échoué: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> addIceCandidate(
    RTCIceCandidate candidate, {
    int? generation,
  }) async {
    if (generation != null && generation != _iceGeneration) {
      debugPrint(
        '[WebRTC] 🧊 ICE ignoré (gen=$generation courante=$_iceGeneration)',
      );
      return;
    }

    _prunePendingIce();

    if (_peerConnection == null) {
      _bufferIce(candidate, generation ?? _iceGeneration);
      debugPrint(
        '[WebRTC] 🧊 ICE candidate bufferisé (PC null, ${_pendingIceCandidates.length} en attente)',
      );
      return;
    }

    if (!_remoteDescriptionSet) {
      _bufferIce(candidate, generation ?? _iceGeneration);
      debugPrint(
        '[WebRTC] 🧊 ICE candidate bufferisé (pas de remote desc, ${_pendingIceCandidates.length} en attente)',
      );
      return;
    }

    try {
      debugPrint(
        '[WebRTC] ++ Application ICE candidate gen=${generation ?? _iceGeneration}',
      );
      await _peerConnection!.addCandidate(candidate);
      debugPrint('[WebRTC] !! ICE candidate ajouté avec succès');
    } catch (e) {
      debugPrint('[WebRTC]  addCandidate échoué: $e');
    }
  }

  void _bufferIce(RTCIceCandidate candidate, int generation) {
    if (_pendingIceCandidates.length >= _maxPendingIce) {
      _pendingIceCandidates.removeAt(0);
    }
    _pendingIceCandidates.add(_BufferedIce(candidate, generation));
  }

  void _prunePendingIce() {
    final now = DateTime.now();
    _pendingIceCandidates.removeWhere(
      (b) =>
          b.generation != _iceGeneration ||
          now.difference(b.addedAt) > _pendingIceTtl,
    );
  }

  Future<void> _flushPendingIceCandidates() async {
    _prunePendingIce();
    if (_pendingIceCandidates.isEmpty) {
      debugPrint('[WebRTC] 🧊 Pas de candidates en attente');
      return;
    }

    if (_peerConnection == null) {
      debugPrint(
        '[WebRTC] 🧊 PeerConnection null, ${_pendingIceCandidates.length} candidats non flushés',
      );
      return;
    }

    debugPrint(
      '[WebRTC] 🧊 Application de ${_pendingIceCandidates.length} ICE candidate(s) bufferisé(s)...',
    );
    int successCount = 0;
    int failureCount = 0;

    final toFlush = List<_BufferedIce>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();

    for (int i = 0; i < toFlush.length; i++) {
      final b = toFlush[i];
      if (b.generation != _iceGeneration) {
        debugPrint('[WebRTC]   [$i] skip gen=${b.generation}');
        continue;
      }
      try {
        await _peerConnection!.addCandidate(b.candidate);
        successCount++;
      } catch (e) {
        debugPrint('[WebRTC]   [$i] ** Erreur: $e');
        failureCount++;
      }
    }

    debugPrint(
      '[WebRTC] 🧊 Flush terminé: $successCount réussis, $failureCount échoués',
    );
  }

  /// Remplace la track audio locale (fallback rare). Respecte [keepMuted].
  Future<bool> replaceAudioTrack({
    required bool keepMuted,
    CallType type = CallType.audio,
  }) async {
    if (_replaceAudioLock) {
      debugPrint('[WebRTC] replaceAudioTrack ignoré (lock)');
      return false;
    }
    if (_peerConnection == null) return false;
    _replaceAudioLock = true;
    try {
      final newStream = await _getUserMedia(
        type == CallType.video ? CallType.video : CallType.audio,
      );
      final newAudio = newStream.getAudioTracks();
      if (newAudio.isEmpty) {
        for (final t in newStream.getTracks()) {
          await t.stop();
        }
        return false;
      }
      final newTrack = newAudio.first;
      newTrack.enabled = !keepMuted;

      final senders = await _peerConnection!.getSenders();
      RTCRtpSender? audioSender;
      for (final s in senders) {
        if (s.track?.kind == 'audio') {
          audioSender = s;
          break;
        }
      }
      if (audioSender == null) {
        await newTrack.stop();
        return false;
      }

      final oldTracks = _localStream?.getAudioTracks() ?? [];
      await audioSender.replaceTrack(newTrack);

      if (_localStream != null) {
        for (final t in oldTracks) {
          try {
            await _localStream!.removeTrack(t);
            await t.stop();
          } catch (_) {}
        }
        await _localStream!.addTrack(newTrack);
      } else {
        _localStream = newStream;
      }

      // Stop video tracks from temporary stream if audio-only replace borrowed video getUserMedia
      if (type == CallType.audio) {
        for (final t in newStream.getVideoTracks()) {
          await t.stop();
        }
      }

      onLocalStream?.call(_localStream!);
      debugPrint('[WebRTC] replaceAudioTrack OK muted=$keepMuted');
      return true;
    } catch (e) {
      debugPrint('[WebRTC] ** replaceAudioTrack: $e');
      return false;
    } finally {
      _replaceAudioLock = false;
    }
  }

  Future<void> toggleMic() async {
    final tracks = _localStream?.getAudioTracks();
    if (tracks != null && tracks.isNotEmpty) {
      tracks.first.enabled = !tracks.first.enabled;
    }
  }

  Future<void> toggleCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      tracks.first.enabled = !tracks.first.enabled;
    }
  }

  Future<void> switchCamera() async {
    // `.first` sans garde, alors que toggleCamera juste au-dessus vérifie
    // `isNotEmpty` : permission caméra refusée sur un appel vidéo — `init()`
    // continue alors en audio — puis appui sur « changer de caméra », et
    // l'exception partait dans un Future ignoré par le callback.
    final tracks = _localStream?.getVideoTracks();
    if (tracks == null || tracks.isEmpty) {
      debugPrint('[WebRTC] switchCamera ignoré (aucune piste vidéo)');
      return;
    }
    try {
      await Helper.switchCamera(tracks.first);
    } catch (e) {
      debugPrint('[WebRTC] ** switchCamera: $e');
    }
  }

  Future<void> dispose() async {
    try {
      debugPrint('[WebRTC] == Nettoyage WebRTC...');
      clearPendingIce();
      _remoteDescriptionSet = false;
      _iceGeneration = 0;
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          try {
            debugPrint(
              '[WebRTC]   - Track local: ${track.kind} (id=${track.id})',
            );
            await track.stop();
          } catch (e) {
            debugPrint('[WebRTC]   ** Erreur arrêt track local: $e');
          }
        }
      }

      debugPrint('[WebRTC] ** Arrêt des tracks distants...');
      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          try {
            debugPrint(
              '[WebRTC]   - Track distant: ${track.kind} (id=${track.id})',
            );
            await track.stop();
          } catch (e) {
            debugPrint('[WebRTC]   ** Erreur arrêt track distant: $e');
          }
        }
      }

      debugPrint('[WebRTC] ** Fermeture PeerConnection...');
      try {
        await _peerConnection?.close();
      } catch (e) {
        debugPrint('[WebRTC] ** Erreur fermeture PeerConnection: $e');
      }

      debugPrint('[WebRTC] ** Disposition des streams...');
      try {
        await _localStream?.dispose();
        await _remoteStream?.dispose();
      } catch (e) {
        debugPrint('[WebRTC] ** Erreur disposition streams: $e');
      }

      _peerConnection = null;
      _localStream = null;
      _remoteStream = null;
      _remoteDescriptionSet = false;
      _pendingIceCandidates.clear();

      debugPrint('[WebRTC] !! Nettoyage complété avec succès');
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur dispose globale: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
    }
  }

  /// Détecte le mode de connexion ICE établi : 0 = relay/TURN, 1 = P2P (host/srflx).
  Future<int?> detectConnectionMode() async {
    final pc = _peerConnection;
    if (pc == null) return null;

    try {
      final reports = await pc.getStats();
      String? localCandidateId;

      for (final r in reports) {
        if (r.type != 'candidate-pair') continue;
        final values = r.values;
        final state = values['state']?.toString();
        final nominated = values['nominated'];
        if (state == 'succeeded' || nominated == true) {
          localCandidateId = values['localCandidateId']?.toString();
          break;
        }
      }

      if (localCandidateId == null) return null;

      for (final r in reports) {
        if (r.type != 'local-candidate' || r.id != localCandidateId) continue;
        final candidateType = r.values['candidateType']?.toString();
        if (candidateType == 'relay') return 0;
        if (candidateType == 'host' || candidateType == 'srflx') return 1;
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('[WebRTC] detectConnectionMode failed: $e');
      return null;
    }
  }
}
