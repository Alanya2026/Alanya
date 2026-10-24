//  Le coffre-fort côté application : ce que les écrans voient et font.
//
//  Vit au niveau de l'application (MultiProvider de main.dart) : un envoi
//  continue quand l'inscrit quitte l'écran du coffre.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/locale_controller.dart';
import '../local_notification_helper.dart';
import '../image_thumbnail_service.dart';
import '../../utils/safebox_share_payload.dart';
import '../../../talky_api_client.dart';
import 'safebox_cipher.dart';
import 'safebox_download_manager.dart';
import 'safebox_foreground.dart';
import 'safebox_media_prep.dart';
import 'safebox_models.dart';
import 'safebox_received_files.dart';
import 'safebox_upload_manager.dart';

/// Un fichier choisi par l'inscrit, pas encore préparé.
class SafeboxPick {
  const SafeboxPick({required this.path, required this.name, required this.size});
  final String path;
  final String name;
  final int size;
}

/// Pourquoi un fichier choisi n'est pas parti.
enum SafeboxRejectReason { wrongFamily, tooLarge, empty, unreadable }

class SafeboxRejection {
  const SafeboxRejection(this.pick, this.reason, {this.expectedFamily});
  final SafeboxPick pick;
  final SafeboxRejectReason reason;

  /// Le type du fichier refusé, pour nommer le dossier où il va.
  final SafeboxFamily? expectedFamily;
}

/// Choix de compression retenu par l'inscrit (« Retenir mon choix »).
enum SafeboxCompressionChoice { ask, original, compressed }

class SafeboxController extends ChangeNotifier {
  SafeboxController({
    required TalkyApiClient api,
    SafeboxForeground? foreground,
    Future<void> Function(int level)? quotaAlert,
  })  : _api = api,
        _premierPlan = foreground ?? SafeboxForeground(),
        _alertes = SafeboxQuotaAlerter(quotaAlert ?? _notifierEspace),
        uploads = SafeboxUploadManager(transport: ApiSafeboxTransport(api)),
        downloads = SafeboxDownloadManager(transport: ApiSafeboxDownloadTransport(api)),
        previews = SafeboxPreviewCache(transport: ApiSafeboxDownloadTransport(api)) {
    uploads.addListener(notifyListeners);
    uploads.addListener(_suivrePremierPlan);
    downloads.addListener(notifyListeners);
    _abonnement = uploads.completed.listen((_) => unawaited(refreshOverview()));
    _abonnementPartages = uploads.completedJobs.listen((e) {
      final conv = e.job.shareConversationId;
      if (conv != null) unawaited(_partagerApresEnvoi(e.file, conv));
    });
  }

  late final StreamSubscription<({SafeboxUploadJob job, SafeboxFile file})> _abonnementPartages;

  final SafeboxForeground _premierPlan;

  /// Service de premier plan tant qu'un envoi tourne ou attend son tour ; la
  /// notification montre l'avancement de l'ensemble.
  void _suivrePremierPlan() {
    final actifs = uploads.jobs
        .where((j) => j.state == SafeboxUploadState.running || j.state == SafeboxUploadState.queued)
        .toList();
    if (actifs.isEmpty) {
      unawaited(_premierPlan.stop());
      return;
    }
    final total = actifs.fold<int>(0, (s, j) => s + j.storedSize);
    final envoye = actifs.fold<int>(0, (s, j) => s + j.sentBytes);
    final pct = total <= 0 ? 0 : (envoye * 100 ~/ total).clamp(0, 100);
    final l10n = resolveL10n();
    unawaited(_premierPlan.show(
      channelName: l10n.safeboxNotifChannel,
      title: l10n.safeboxTransfersCount(actifs.length),
      text: l10n.safeboxUploadRunning(pct),
      percent: pct,
    ));
  }

  final TalkyApiClient _api;
  final SafeboxUploadManager uploads;
  final SafeboxDownloadManager downloads;
  final SafeboxPreviewCache previews;

  /// Fichiers reçus, enregistrés dans Téléchargements/Alanya.
  final SafeboxReceivedFiles received = SafeboxReceivedFiles();
  late final StreamSubscription<SafeboxFile> _abonnement;

  SafeboxOverview? _overview;
  Object? _overviewError;
  bool _demarre = false;

  SafeboxOverview? get overview => _overview;
  Object? get overviewError => _overviewError;
  TalkyApiClient get api => _api;

  /// À l'ouverture du coffre : reprend les envois laissés en plan.
  void ensureStarted() {
    if (_demarre) return;
    _demarre = true;
    unawaited(uploads.resumeAll());
  }

  /// Le réseau revient : les envois qui l'attendaient repartent.
  void onNetworkBack() {
    if (_demarre) unawaited(uploads.resumeAll());
  }

  Future<SafeboxOverview?> refreshOverview() async {
    try {
      _overview = await _api.fetchSafebox();
      _overviewError = null;
    } catch (e) {
      _overviewError = e;
    }
    notifyListeners();
    final vue = _overview;
    if (vue != null) unawaited(_alertes.check(vue.quota));
    return _overview;
  }

  // ── Alertes d'espace ─────────────────────────────────────────────────────

  final SafeboxQuotaAlerter _alertes;

  static Future<void> _notifierEspace(int niveau) async {
    final l10n = resolveL10n();
    final titre = switch (niveau) {
      100 => l10n.safeboxAlert100Title,
      95 => l10n.safeboxAlert95Title,
      _ => l10n.safeboxAlert80Title,
    };
    try {
      // Le même type remplace la notification précédente : une seule à la fois.
      // Un appui ouvre « Libérer de l'espace » (home_screen.dart).
      await LocalNotificationHelper.showGenericNotification(
        const {'type': 'safebox_quota'},
        title: titre,
        body: l10n.safeboxAlertBody,
      );
    } catch (e) {
      debugPrint('[Coffre] alerte d\'espace non affichée : $e');
    }
  }

  static String rootLabel(SafeboxRoot r, AppLocalizations l10n) => switch (r) {
        SafeboxRoot.photos => l10n.safeboxRootPhotos,
        SafeboxRoot.videos => l10n.safeboxRootVideos,
        SafeboxRoot.audios => l10n.safeboxRootAudios,
        SafeboxRoot.documents => l10n.safeboxRootDocuments,
        SafeboxRoot.albums => l10n.safeboxRootAlbums,
        SafeboxRoot.partager => l10n.safeboxRootShare,
      };

  static String folderLabel(SafeboxFolder f, AppLocalizations l10n) =>
      f.isRoot ? rootLabel(f.root, l10n) : (f.name ?? '');

  /// Nom d'un autre endroit du même contenu : son dossier, ou sa racine traduite.
  static String placeLabel(SafeboxPlace p, AppLocalizations l10n) => p.folderName ?? rootLabel(p.root, l10n);

  /// Le type d'un fichier d'après son nom, comme le serveur (« documents »
  /// tant que les réglages du coffre ne sont pas chargés).
  SafeboxFamily familyOf(String name) => _overview?.limits.familyOf(name) ?? SafeboxFamily.documents;

  // ── Choix de compression ─────────────────────────────────────────────────

  static const _cleChoix = 'safebox_compression_choice_v1';

  Future<SafeboxCompressionChoice> rememberedChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_cleChoix);
    return SafeboxCompressionChoice.values.firstWhere((c) => c.name == v, orElse: () => SafeboxCompressionChoice.ask);
  }

  Future<void> rememberChoice(SafeboxCompressionChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleChoix, choice.name);
  }

  // ── Dépôt ────────────────────────────────────────────────────────────────

  Future<SafeboxMediaPrep> _prep() async =>
      SafeboxMediaPrep(workDir: Directory('${(await safeboxLocalDir()).path}/outbox'));

  /// Trie les fichiers choisis : ceux qui peuvent partir dans [folder], et les
  /// autres avec la raison (mauvais dossier, trop gros, vide). Albums et
  /// Partager acceptent tous les types.
  ({List<SafeboxPick> ok, List<SafeboxRejection> rejected}) triage(List<SafeboxPick> picks, SafeboxFolder folder) {
    final limites = _overview?.limits;
    final ok = <SafeboxPick>[];
    final refuses = <SafeboxRejection>[];
    for (final pick in picks) {
      if (pick.size <= 0) {
        refuses.add(SafeboxRejection(pick, SafeboxRejectReason.empty));
        continue;
      }
      final famille = limites?.familyOf(pick.name) ?? folder.root.family ?? SafeboxFamily.documents;
      if (!folder.root.accepts(famille)) {
        refuses.add(SafeboxRejection(pick, SafeboxRejectReason.wrongFamily, expectedFamily: famille));
        continue;
      }
      if (limites != null && pick.size > limites.maxFileBytes) {
        refuses.add(SafeboxRejection(pick, SafeboxRejectReason.tooLarge));
        continue;
      }
      ok.add(pick);
    }
    return (ok: ok, rejected: refuses);
  }

  /// Poids total et poids compressé estimé, pour la feuille de choix. Null
  /// quand rien de ce lot ne se compresse (documents, audios, GIF…). Chaque
  /// fichier selon son type : un lot pour Albums ou Partager mélange les types.
  Future<({int original, int compressed})?> estimate(List<SafeboxPick> picks) async {
    bool compressible(SafeboxPick p) => SafeboxMediaPrep.canCompress(familyOf(p.name), p.name);
    if (!picks.any(compressible)) return null;
    final prep = await _prep();
    var original = 0;
    var compresse = 0;
    for (final p in picks) {
      original += p.size;
      compresse += compressible(p) ? await prep.estimate(p.path, familyOf(p.name), p.size) : p.size;
    }
    return (original: original, compressed: compresse);
  }

  /// Prépare chaque fichier (compression au besoin, aperçu chiffré) et le
  /// confie au gestionnaire d'envoi. Les fichiers partent un par un.
  Future<void> addFiles(
    List<SafeboxPick> picks,
    SafeboxFolder folder, {
    required bool compress,
    int? shareConversationId,
  }) async {
    final prep = await _prep();
    await prep.workDir.create(recursive: true);
    final maxApercu = (_overview?.limits.maxPreviewBytes ?? 256 * 1024) - kSafeboxTagBytes;
    for (final pick in picks) {
      try {
        var source = pick.path;
        var nom = pick.name;
        var possede = false;
        final famille = familyOf(pick.name);
        if (compress) {
          final c = await prep.compress(pick.path, pick.name, famille);
          if (c != null) {
            source = c.path;
            nom = c.name;
            possede = true;
          }
        }
        final st = await File(source).stat();
        if (st.size <= 0) continue;
        final cle = safeboxNewFileKey();
        String? cheminApercu;
        var tailleApercu = 0;
        final apercu = await prep.preview(source, famille, nom);
        if (apercu != null && apercu.isNotEmpty && apercu.length <= maxApercu) {
          final chiffre = safeboxEncryptPreviewSync(cle, Uint8List.fromList(apercu));
          cheminApercu = '${prep.workDir.path}/apercu_${DateTime.now().microsecondsSinceEpoch}.sbx';
          await File(cheminApercu).writeAsBytes(chiffre, flush: true);
          tailleApercu = chiffre.length;
        }
        final details = await prep.meta(source, famille, nom);
        await uploads.enqueue(
          SafeboxUploadJob(
            id: '${DateTime.now().microsecondsSinceEpoch}_${pick.name.hashCode}',
            folderId: folder.id,
            name: nom,
            mime: null,
            sourcePath: source,
            sourceSize: st.size,
            sourceModifiedMs: st.modified.millisecondsSinceEpoch,
            ownsSource: possede,
            plainSize: st.size,
            originalSize: possede ? pick.size : null,
            compressed: possede,
            previewPath: cheminApercu,
            previewSize: tailleApercu,
            shareConversationId: shareConversationId,
            meta: details?.toJson(),
          ),
          cle,
        );
      } catch (e) {
        debugPrint('[Coffre] préparation de ${pick.name} impossible : $e');
      }
    }
  }

  // ── Un même contenu à plusieurs endroits (décision du 24/10/2026) ───────

  /// Ajoute des fichiers du coffre à un album, sans copie : l'espace ne
  /// change pas.
  Future<List<SafeboxFile>> addToAlbum(List<SafeboxFile> files, int albumId) =>
      _api.addSafeboxFilesToFolder(albumId, [for (final f in files) f.id]);

  /// À la corbeille : cet exemplaire, ou tous ceux du même contenu
  /// ([everywhere]), seul moyen de libérer sa place.
  Future<void> trashFile(SafeboxFile f, {bool everywhere = false}) async {
    await _api.trashSafeboxFile(f.id, everywhere: everywhere);
    await downloads.evict(f.id);
    if (everywhere) {
      for (final p in f.alsoIn) {
        await downloads.evict(p.fileId);
      }
    }
    unawaited(refreshOverview());
  }

  // ── Partage dans une discussion (lot 3) ──────────────────────────────────

  /// Publie un message dans une discussion. Posé par l'écran d'accueil, qui a
  /// accès aux discussions ; un partage prêt avant lui attend dans
  /// [_partagesEnAttente].
  Future<void> Function(int conversationId, SafeboxSharePayload payload)? _envoyeur;
  final List<(int, SafeboxSharePayload)> _partagesEnAttente = [];

  set shareSender(Future<void> Function(int conversationId, SafeboxSharePayload payload)? f) {
    _envoyeur = f;
    if (f == null) return;
    final attente = List.of(_partagesEnAttente);
    _partagesEnAttente.clear();
    for (final (conv, payload) in attente) {
      unawaited(f(conv, payload));
    }
  }

  /// Partage un fichier de mon coffre dans une discussion et rend le contenu
  /// du message, mini-image floue comprise (tirée de l'aperçu).
  Future<SafeboxSharePayload> shareFile(SafeboxFile file, int conversationId) async {
    final cree = await _api.createSafeboxShare(fileId: file.id, conversationId: conversationId);
    String? flou;
    try {
      final apercu = await previews.load(file);
      if (apercu != null) {
        final b64 = await ImageThumbnailService.base64ForBytes(apercu, maxWidth: 24);
        if (b64 != null && b64.length <= 6000) flou = b64;
      }
    } catch (e) {
      debugPrint('[Coffre] mini-image du partage : $e');
    }
    return SafeboxSharePayload(
      share: cree.shareId,
      name: cree.name,
      size: cree.plainBytes,
      mime: cree.mime,
      family: cree.family,
      blur: flou,
      meta: cree.meta ?? file.meta,
    );
  }

  /// Envoie un fichier de mon coffre dans plusieurs discussions (bouton
  /// « Envoyer dans une discussion » du coffre). Rend le nombre de
  /// discussions où il est parti.
  Future<int> sendToConversations(SafeboxFile file, List<int> conversationIds) async {
    var reussis = 0;
    Object? premiereErreur;
    for (final conv in conversationIds) {
      try {
        final payload = await shareFile(file, conv);
        final envoyer = _envoyeur;
        if (envoyer != null) {
          await envoyer(conv, payload);
        } else {
          _partagesEnAttente.add((conv, payload));
        }
        reussis += 1;
      } catch (e) {
        premiereErreur ??= e;
        debugPrint('[Coffre] envoi dans la discussion $conv impossible : $e');
      }
    }
    if (reussis == 0 && premiereErreur != null) throw premiereErreur;
    return reussis;
  }

  /// Fichier déposé depuis une discussion : une fois dans le coffre, il part.
  Future<void> _partagerApresEnvoi(SafeboxFile file, int conversationId) async {
    try {
      final payload = await shareFile(file, conversationId);
      final envoyer = _envoyeur;
      if (envoyer != null) {
        await envoyer(conversationId, payload);
      } else {
        _partagesEnAttente.add((conversationId, payload));
      }
    } catch (e) {
      debugPrint('[Coffre] partage après envoi impossible : $e');
    }
  }

  final Map<int, SafeboxShareInfo> _cartes = {};
  final Map<int, Future<SafeboxShareInfo?>> _cartesEnCours = {};

  /// État connu d'une carte, sans réseau.
  SafeboxShareInfo? shareInfoCached(int shareId) => _cartes[shareId];

  /// État d'une carte (disponible, aperçu, clé…). Null si le partage n'est pas
  /// visible (plus membre de la discussion, partage inconnu).
  Future<SafeboxShareInfo?> shareInfo(int shareId, {bool refresh = false}) {
    if (!refresh && _cartes.containsKey(shareId)) return Future.value(_cartes[shareId]);
    return _cartesEnCours.putIfAbsent(shareId, () async {
      try {
        final info = await _api.fetchSafeboxShare(shareId);
        _cartes[shareId] = info;
        notifyListeners();
        return info;
      } on TalkyException catch (e) {
        if (e.statusCode == 404) return null;
        rethrow;
      } finally {
        _cartesEnCours.remove(shareId);
      }
    });
  }

  /// Télécharge un fichier reçu (compte un téléchargement), puis relit la carte.
  Future<File> downloadShare(SafeboxShareInfo info) async {
    final f = await downloads.fetchShare(info);
    unawaited(shareInfo(info.id, refresh: true));
    return f;
  }

  // ── Commentaire d'une photo (privé) ──────────────────────────────────────

  /// Bloc de stockage de l'audio : un seul, l'audio fait au plus 6 Mio.
  static const int _blocAudio = 8 << 20;

  Future<SafeboxNote?> saveNoteText(SafeboxFile file, String? text) => _api.setSafeboxNoteText(file.id, text);

  /// Chiffre l'audio sur le téléphone (clé neuve, format SBX1), l'envoie
  /// directement chez MEGA, puis le fait vérifier par le serveur.
  Future<SafeboxNote?> saveNoteAudio(SafeboxFile file, File audio, int durationMs) async {
    final clair = await audio.readAsBytes();
    final cle = safeboxNewFileKey();
    final plan = safeboxPlanBlock(1, plainSize: clair.length, blockSize: _blocAudio);
    final chiffre = await safeboxEncryptBlock(cle, clair, plan);
    final url = await _api.reserveSafeboxNoteAudio(
      file.id,
      size: chiffre.length,
      plainSize: clair.length,
      durationMs: durationMs,
    );
    await _api.putSafeboxBlock(url, chiffre);
    final note = await _api.completeSafeboxNoteAudio(file.id, cle);
    unawaited(refreshOverview());
    return note;
  }

  Future<SafeboxNote?> deleteNoteAudio(SafeboxFile file) async {
    final note = await _api.deleteSafeboxNoteAudio(file.id);
    unawaited(refreshOverview());
    return note;
  }

  /// L'audio déchiffré dans un fichier temporaire, pour l'écouter. Le
  /// lecteur le supprime en se fermant.
  Future<File> noteAudioFile(int fileId, SafeboxNoteAudio audio) async {
    final recu = BytesBuilder(copy: false);
    await _api.getSafeboxBlock(audio.url, onBytes: recu.add);
    final plan = safeboxPlanBlock(1, plainSize: audio.plainBytes, blockSize: _blocAudio);
    final clair = await safeboxDecryptBlock(audio.key, recu.takeBytes(), plan);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/coffre_commentaire_${fileId}_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await f.writeAsBytes(clair, flush: true);
    return f;
  }

  /// Le fichier reçu sur le téléphone : déjà dans Téléchargements, sinon
  /// téléchargé puis copié dans Téléchargements/Alanya (la copie privée est
  /// alors supprimée). `published` dit si la copie vient d'être faite ; si
  /// elle échoue, le fichier reste dans l'application (`saveFailed`).
  Future<({String location, bool published, bool saveFailed})> fetchReceived(SafeboxShareInfo info) async {
    final deja = await received.location(info.id);
    if (deja != null) return (location: deja, published: false, saveFailed: false);
    final f = await downloadShare(info);
    final loc = await received.publish(f, shareId: info.id, name: info.name, mime: info.mime, family: info.family);
    if (loc == null) return (location: f.path, published: false, saveFailed: true);
    await downloads.evict(info.localId);
    return (location: loc, published: true, saveFailed: false);
  }

  /// Le fichier reçu est-il déjà sur le téléphone (Téléchargements, ou
  /// dossier de l'application si la copie avait échoué) ?
  Future<bool> hasReceived(SafeboxShareInfo info) async =>
      await received.location(info.id) != null || await downloads.cached(info.asFile()) != null;

  /// Enregistre un fichier reçu dans mon coffre.
  Future<SafeboxFile> saveShare(int shareId) async {
    final f = await _api.saveSafeboxShare(shareId);
    await shareInfo(shareId, refresh: true);
    unawaited(refreshOverview());
    return f;
  }

  @override
  void dispose() {
    _abonnementPartages.cancel();
    _abonnement.cancel();
    uploads.removeListener(notifyListeners);
    uploads.removeListener(_suivrePremierPlan);
    unawaited(_premierPlan.stop());
    downloads.removeListener(notifyListeners);
    uploads.dispose();
    downloads.dispose();
    super.dispose();
  }
}

/// Alertes d'espace du coffre : une fois par palier (80, 95, 100 %) franchi en
/// montant. Redescendre (fichiers supprimés, Alanya Plus) réarme le palier.
class SafeboxQuotaAlerter {
  SafeboxQuotaAlerter(this.notify);

  final Future<void> Function(int level) notify;
  static const _cle = 'safebox_quota_alert_level_v1';

  /// Palier atteint : 0, 80, 95 ou 100.
  static int levelOf(SafeboxQuota q) {
    if (q.quotaBytes <= 0) return 100;
    final r = q.usedBytes / q.quotaBytes;
    if (r >= 1) return 100;
    if (r >= 0.95) return 95;
    if (r >= 0.8) return 80;
    return 0;
  }

  Future<void> check(SafeboxQuota q) async {
    final prefs = await SharedPreferences.getInstance();
    final niveau = levelOf(q);
    final dernier = prefs.getInt(_cle) ?? 0;
    if (niveau == dernier) return;
    await prefs.setInt(_cle, niveau);
    if (niveau > dernier) await notify(niveau);
  }
}
