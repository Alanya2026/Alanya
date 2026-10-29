import 'dart:io';

import '../../db/chat_dao.dart';
import '../media_expiry_policy.dart';
import 'export_index_html.dart';
import 'export_manifest.dart';
import 'export_scan.dart';
import 'export_zip_builder.dart';

/// Étape courante, pour l'affichage et la notification.
enum ExportPhase {
  /// Inventaire : mesure au disque, classement des absents.
  scanning,

  /// Récupération réseau des manquants, **uniquement si l'inscrit l'a
  /// acceptée**. C'est la seule phase qui consomme de la bande passante.
  recovering,

  /// Assemblage de l'archive.
  assembling,

  done,
}

/// État observable du travail d'export.
class ExportStatus {
  final ExportPhase phase;

  /// Éléments traités et total de la phase courante.
  final int done;
  final int total;

  /// Octets déjà écrits dans l'archive.
  final int bytesWritten;

  const ExportStatus({
    required this.phase,
    this.done = 0,
    this.total = 0,
    this.bytesWritten = 0,
  });

  double get ratio => total == 0 ? 0 : done / total;
}

/// Ce que l'export a produit.
class ExportResult {
  final File archive;
  final ExportManifest manifest;

  const ExportResult(this.archive, this.manifest);
}

/// Récupère un média absent depuis le serveur et retourne son chemin local,
/// ou `null` si l'opération échoue.
///
/// Signature volontairement minimale : le travail d'export n'a pas à connaître
/// le dépôt, le cache ni le client HTTP. C'est aussi ce qui le rend testable
/// sans réseau.
typedef MediaRecoverer = Future<String?> Function(String clientId);

/// Orchestre une exportation de période, de l'inventaire à l'archive.
///
/// ── Le découpage en trois phases n'est pas cosmétique ──
///
/// Il répond à la question « que se passe-t-il si ça s'interrompt ? », et la
/// réponse diffère selon la phase :
///
/// | Phase        | Ressource | Reprise |
/// |--------------|-----------|---------|
/// | Récupération | réseau    | gratuite : les fichiers déjà descendus sont
/// |              |           | dans le cache, la phase les saute |
/// | Assemblage   | disque    | recommencée d'un trait, sans réseau, donc
/// |              |           | rapide — un zip ne se reprend pas au milieu |
/// | Dépôt        | réseau    | native, l'API de destination la gère |
///
/// Les deux phases coûteuses sont donc reprenables, et la seule qui ne l'est
/// pas ne coûte pas de réseau. C'est ce qui permet de tenir la promesse d'une
/// tâche de fond reprenable sans construire de machinerie maison.
///
/// **À usage unique** : une instance mène un export, et [cancel] la retire
/// définitivement du service. En créer une par export.
class MediaExportJob {
  final ChatDao dao;
  final ExportZipBuilder builder;

  /// Résout le fichier d'un sticker (cache dédié). Optionnel : absent, un
  /// sticker est déclaré manquant plutôt qu'omis. Voir [StickerFileResolver].
  final StickerFileResolver? stickerFile;

  MediaExportJob(this.dao, {ExportZipBuilder? builder, this.stickerFile})
      : builder = builder ?? ExportZipBuilder();

  bool _cancelled = false;

  /// Demande l'arrêt. Pris en compte entre deux fichiers, jamais au milieu de
  /// l'un d'eux : interrompre une écriture en cours produirait une entrée
  /// d'archive corrompue.
  ///
  /// **L'annulation est définitive.** Un travail annulé le reste, et un
  /// nouvel export demande une nouvelle instance — elles ne coûtent rien.
  /// L'alternative, remettre le drapeau à zéro au début de [run], perdrait
  /// silencieusement une annulation arrivée juste avant le démarrage, et
  /// laisserait deux exécutions se disputer le même drapeau.
  void cancel() => _cancelled = true;

  bool get isCancelled => _cancelled;

  /// Inventaire seul, pour la feuille d'export : elle doit annoncer le nombre,
  /// le poids et ce qui manque **avant** que l'inscrit ne s'engage.
  Future<ExportScanResult> preview(
    int myId, {
    bool? mineOnly,
    int? conversationID,
    DateTime? from,
    DateTime? until,
    List<int> types = kExportMediaTypes,
  }) {
    return ExportScanner(dao, stickerFile: stickerFile).scan(
      myId,
      mineOnly: mineOnly,
      conversationID: conversationID,
      from: from,
      until: until,
      types: types,
    );
  }

  /// Exécute l'export complet.
  ///
  /// [recoverMissing] n'est fourni que si l'inscrit a explicitement accepté la
  /// dépense réseau, après avoir vu le nombre d'éléments et les octets en jeu.
  /// Sans lui, **aucun octet ne transite** : c'est le mode par défaut, et la
  /// règle du produit.
  Future<ExportResult> run({
    required int myId,
    required File destination,
    bool? mineOnly,
    int? conversationID,
    String? conversationName,
    DateTime? from,
    DateTime? until,
    List<int> types = kExportMediaTypes,
    int? availableBytes,
    MediaRecoverer? recoverMissing,
    void Function(ExportStatus)? onStatus,
  }) async {
    _throwIfCancelled();
    onStatus?.call(const ExportStatus(phase: ExportPhase.scanning));

    var scan = await ExportScanner(dao, stickerFile: stickerFile).scan(
      myId,
      mineOnly: mineOnly,
      conversationID: conversationID,
      from: from,
      until: until,
      types: types,
    );
    _throwIfCancelled();

    if (recoverMissing != null && scan.recoverable.isNotEmpty) {
      await _recover(scan, recoverMissing, onStatus);
      _throwIfCancelled();
      // Un second inventaire plutôt qu'une mise à jour en place : les fichiers
      // récupérés doivent être mesurés, nommés et numérotés exactement comme
      // les autres. Rejouer le scan est bien moins risqué que de rejouer sa
      // logique à la main.
      scan = await ExportScanner(dao, stickerFile: stickerFile).scan(
        myId,
        mineOnly: mineOnly,
        conversationID: conversationID,
        from: from,
        until: until,
        types: types,
      );
    }

    onStatus?.call(ExportStatus(
      phase: ExportPhase.assembling,
      total: scan.present.length,
    ));

    final manifest = await builder.build(
      destination: destination,
      scan: scan,
      alanyaID: myId,
      periodFrom: from,
      // `until` est la borne exclusive du lendemain minuit ; l'archive doit
      // afficher le dernier jour réellement couvert.
      periodTo: until?.subtract(const Duration(days: 1)),
      conversationID: conversationID,
      conversationName: conversationName,
      retentionDaysKnown: MediaExpiryPolicy.retentionDays,
      availableBytes: availableBytes,
      isCancelled: () => _cancelled,
      indexHtmlBuilder: buildExportIndexHtml,
      onProgress: (p) => onStatus?.call(ExportStatus(
        phase: ExportPhase.assembling,
        done: p.done,
        total: p.total,
        bytesWritten: p.bytesWritten,
      )),
    );

    onStatus?.call(ExportStatus(
      phase: ExportPhase.done,
      done: manifest.items.length,
      total: manifest.items.length,
      bytesWritten: manifest.totalBytes,
    ));
    return ExportResult(destination, manifest);
  }

  /// Télécharge les manquants récupérables, un par un.
  ///
  /// Un échec isolé n'arrête pas la phase : le média restera simplement
  /// déclaré absent dans le manifeste. Renoncer à toute l'archive parce qu'une
  /// photo sur quarante-sept n'est pas revenue serait absurde.
  Future<void> _recover(
    ExportScanResult scan,
    MediaRecoverer recover,
    void Function(ExportStatus)? onStatus,
  ) async {
    final targets = scan.recoverable;
    for (var i = 0; i < targets.length; i++) {
      if (_cancelled) return;
      onStatus?.call(ExportStatus(
        phase: ExportPhase.recovering,
        done: i,
        total: targets.length,
      ));
      try {
        final path = await recover(targets[i].clientId);
        if (path != null && path.isNotEmpty) {
          // Un sticker vit dans son cache dédié, indexé par URL : il n'a pas
          // de `localMediaPath` à renseigner, et le lui écrire ferait pointer
          // la base vers un fichier qui n'est pas du cache média. Le scan le
          // retrouve de toute façon par le résolveur de vignettes.
          if (!targets[i].isSticker) {
            await dao.setLocalMediaPathByClientId(targets[i].clientId, path);
          }
        }
      } catch (_) {
        // Réseau coupé, serveur indisponible, média finalement purgé : on
        // passe au suivant.
      }
    }
    onStatus?.call(ExportStatus(
      phase: ExportPhase.recovering,
      done: targets.length,
      total: targets.length,
    ));
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const ExportCancelled();
  }
}
