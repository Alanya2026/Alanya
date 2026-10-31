//  Le coffre-fort côté application : ce que les écrans voient et font.
//
//  Vit au niveau de l'application (MultiProvider de main.dart) : un envoi
//  continue quand l'inscrit quitte l'écran du coffre.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/locale_controller.dart';
import '../local_notification_helper.dart';
import '../image_thumbnail_service.dart';
import '../video_codec_policy.dart';
import '../../utils/safebox_share_payload.dart';
import '../../../talky_api_client.dart';
import '../connectivity_service.dart';
import 'safebox_backup.dart';
import 'safebox_backup_background.dart';
import 'safebox_cipher.dart';
import 'safebox_device_media.dart';
import 'safebox_download_manager.dart';
import 'safebox_export.dart';
import 'safebox_foreground.dart';
import 'safebox_media_prep.dart';
import 'safebox_models.dart';
import 'safebox_quality.dart';
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

/// Ce que pèserait un lot de fichiers dans chacun des trois formats, pour la
/// feuille « Qualité d'envoi ».
class SafeboxQualityEstimate {
  const SafeboxQualityEstimate({
    required this.totals,
    required this.tooLarge,
    required this.counts,
    required this.compressible,
    required this.hevc,
  });

  /// Poids total du lot dans chaque format.
  final Map<SafeboxQuality, int> totals;

  /// Le premier fichier qui dépasserait la limite d'un fichier dans ce format.
  final Map<SafeboxQuality, ({String name, int bytes})> tooLarge;

  /// Nombre de fichiers par type, pour le sous-titre (« 3 vidéos et 2 photos »).
  final Map<SafeboxFamily, int> counts;

  /// Au moins un fichier du lot se compresse : sinon, pas de question.
  final bool compressible;

  /// Les vidéos partiraient en H.265.
  final bool hevc;

  bool fits(SafeboxQuality q) => !tooLarge.containsKey(q);

  /// Gain par rapport à l'original, en pour cent (0 à 100).
  int gainPercent(SafeboxQuality q) {
    final o = totals[SafeboxQuality.original] ?? 0;
    final t = totals[q] ?? o;
    return o <= 0 ? 0 : ((o - t) * 100 / o).round().clamp(0, 100);
  }

  /// Moins de 5 % de gain : rien qui vaille une perte de qualité.
  bool nothingToGain(SafeboxQuality q) => q != SafeboxQuality.original && gainPercent(q) < 5;
}

class SafeboxController extends ChangeNotifier {
  SafeboxController({
    required TalkyApiClient api,
    SafeboxForeground? foreground,
    Future<void> Function(int level)? quotaAlert,
    @visibleForTesting SafeboxUploadManager? uploadManager,
    @visibleForTesting SafeboxDeviceSource? deviceSource,
    @visibleForTesting SafeboxBackupStore? backupStore,
    @visibleForTesting Future<bool> Function()? charging,
  })  : _api = api,
        device = deviceSource ?? PhoneSafeboxDeviceSource(),
        _enCharge = charging ?? _batterieEnCharge,
        _premierPlan = foreground ?? SafeboxForeground(),
        _alertes = SafeboxQuotaAlerter(quotaAlert ?? _notifierEspace),
        uploads = uploadManager ?? SafeboxUploadManager(transport: ApiSafeboxTransport(api)),
        downloads = SafeboxDownloadManager(transport: ApiSafeboxDownloadTransport(api)),
        previews = SafeboxPreviewCache(transport: ApiSafeboxDownloadTransport(api)) {
    exports = SafeboxExporter(
      fetch: _pourExport,
      cached: downloads.cached,
      evict: downloads.evict,
      progressOf: downloads.progressOf,
    );
    // Les aperçus du téléphone ramenés sous leur plafond, une fois par démarrage.
    unawaited(previews.prune());
    uploads.addListener(notifyListeners);
    uploads.addListener(_suivrePremierPlan);
    // Le progrès d'un téléchargement groupé suit celui du fichier en cours.
    downloads.addListener(exports.refresh);
    downloads.addListener(notifyListeners);
    exports.addListener(notifyListeners);
    _abonnement = uploads.completed.listen((_) => unawaited(refreshOverview()));
    backup = SafeboxBackupEngine(
      device: device,
      api: _ApiSauvegarde(api),
      enqueue: _envoyerSauvegarde,
      freeSpace: _espaceLibre,
      maxFileBytes: () => _overview?.limits.maxFileBytes ?? (1 << 30),
      charging: _enCharge,
      store: backupStore,
    );
    _abonnementPartages = uploads.completedJobs.listen((e) {
      final cle = e.job.backupKey;
      if (cle != null) unawaited(backup.markSaved(cle));
      final conv = e.job.shareConversationId;
      if (conv == null) return;
      final groupe = e.job.shareGroup;
      unawaited(groupe == null ? _partagerApresEnvoi(e.file, conv) : _ajouterAuGroupe(groupe, e.file, conv));
    });
    uploads.addListener(_surveillerGroupes);
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

  /// Téléchargements groupés vers la galerie ou un ZIP (lot 8).
  late final SafeboxExporter exports;
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
    // L'application ouverte envoie ; la tâche de fond s'efface (lot 10).
    _battement = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(SafeboxRunLock.beat(SafeboxRunLock.app));
    });
    unawaited(() async {
      await SafeboxRunLock.beat(SafeboxRunLock.app);
      // Un passage de fond en cours s'arrête dans les secondes qui suivent.
      for (var i = 0; i < 20 && await SafeboxRunLock.held(SafeboxRunLock.background); i += 1) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      await uploads.reload();
      unawaited(uploads.resumeAll());
      // Déjà en Wi-Fi à l'ouverture : Android ne signale que les changements.
      if (await _surWifi()) unawaited(uploads.resumeWaitingWifi());
      unawaited(_lireGroupes().then((_) => _verifierGroupes()));
      // Sauvegarde automatique : un passage au démarrage, au retour du Wi-Fi,
      // et toutes les 30 minutes tant que l'application est ouverte.
      await loadBackupSettings();
      unawaited(scheduleSafeboxBackgroundBackup(_reglages));
      unawaited(runBackup());
    }());
    _reseau = Connectivity().onConnectivityChanged.listen((r) {
      if (r.any((x) => x == ConnectivityResult.wifi || x == ConnectivityResult.ethernet)) {
        unawaited(uploads.resumeWaitingWifi());
        unawaited(runBackup());
      }
    }, onError: (Object e) => debugPrint('[Sauvegarde] réseau illisible : $e'));
    _minuterie = Timer.periodic(const Duration(minutes: 30), (_) => unawaited(runBackup()));
  }

  static Future<bool> _surWifi() async {
    try {
      return await ConnectivityService().currentIsUnmetered;
    } catch (_) {
      return false;
    }
  }

  StreamSubscription<List<ConnectivityResult>>? _reseau;
  Timer? _minuterie;
  Timer? _battement;

  /// Le réseau revient : les envois qui l'attendaient repartent.
  void onNetworkBack() {
    if (!_demarre) return;
    unawaited(uploads.resumeAll());
    unawaited(() async {
      if (await _surWifi()) await uploads.resumeWaitingWifi();
    }());
    unawaited(runBackup());
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

  // ── Format d'envoi (décision du 24/10/2026) ──────────────────────────────

  /// Le choix « Retenir mon choix ». La clé change avec les trois formats :
  /// l'ancien « compressé » (720p) ne veut plus dire la même chose.
  static const _cleChoix = 'safebox_quality_choice_v2';

  /// Le format retenu, ou null : poser la question.
  Future<SafeboxQuality?> rememberedQuality() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_cleChoix);
    return v == null ? null : SafeboxQuality.fromName(v);
  }

  Future<void> rememberQuality(SafeboxQuality q) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleChoix, q.name);
  }

  /// Les vidéos peuvent-elles partir en H.265 ? Il faut que ce téléphone
  /// l'encode, et que les destinataires le lisent : ceux de la discussion
  /// quand on l'envoie, aucun d'inconnu sinon. Déposée dans Partager sans
  /// destinataire connu, une vidéo part en H.264, que tout le monde lit.
  Future<bool> _hevcPermis(SafeboxFolder folder, int? conversationId) async {
    if (!(await VideoCodecSupport.detect()).hevcEncoder) return false;
    if (conversationId != null) return hevcAllowedFor(conversationId);
    return folder.root != SafeboxRoot.partager;
  }

  /// Une vidéo en H.265 de mon coffre, envoyée dans des discussions dont un
  /// membre ne lit pas ce format : l'écran prévient avant l'envoi (elle n'est
  /// pas reconvertie). Faux dans le doute, pour ne pas alarmer à tort.
  Future<bool> hevcUnreadableIn(SafeboxFile file, List<int> conversationIds) async {
    if (file.family != SafeboxFamily.videos || !(file.meta?.isHevc ?? false)) return false;
    final politique = VideoCodecPolicy.maybeInstance;
    if (politique == null) return false;
    for (final conv in conversationIds) {
      if (await politique.membersReadHevc(conv) == false) return true;
    }
    return false;
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
      // Trop lourd tel quel : refusé seulement s'il ne se compresse pas. Sinon
      // la feuille des formats dit lesquels passent sous la limite.
      if (limites != null && pick.size > limites.maxFileBytes && !SafeboxMediaPrep.canCompress(famille, pick.name)) {
        refuses.add(SafeboxRejection(pick, SafeboxRejectReason.tooLarge));
        continue;
      }
      ok.add(pick);
    }
    return (ok: ok, rejected: refuses);
  }

  /// Ce que pèserait le lot dans chacun des trois formats, chaque fichier
  /// selon son type (un lot pour Albums ou Partager les mélange), avec le
  /// codec qu'auraient ses vidéos à cette destination.
  Future<SafeboxQualityEstimate> estimateQualities(
    List<SafeboxPick> picks, {
    required SafeboxFolder folder,
    int? conversationId,
  }) async {
    final hevc = await _hevcPermis(folder, conversationId);
    final limite = _overview?.limits.maxFileBytes ?? 0;
    final prep = await _prep();
    final totaux = {for (final q in SafeboxQuality.values) q: 0};
    final tropLourds = <SafeboxQuality, ({String name, int bytes})>{};
    final nombres = <SafeboxFamily, int>{};
    var compressible = false;
    for (final pick in picks) {
      final famille = familyOf(pick.name);
      nombres[famille] = (nombres[famille] ?? 0) + 1;
      final peut = SafeboxMediaPrep.canCompress(famille, pick.name);
      compressible = compressible || peut;
      final faits = peut ? await prep.facts(pick.path, famille, pick.size) : SafeboxMediaFacts(sizeBytes: pick.size);
      for (final q in SafeboxQuality.values) {
        final octets = SafeboxMediaPrep.estimateFrom(faits, famille, pick.name, q, hevc: hevc);
        totaux[q] = totaux[q]! + octets;
        if (limite > 0 && octets > limite) tropLourds.putIfAbsent(q, () => (name: pick.name, bytes: octets));
      }
    }
    return SafeboxQualityEstimate(
      totals: totaux,
      tooLarge: tropLourds,
      counts: nombres,
      compressible: compressible,
      hevc: hevc,
    );
  }

  /// Prépare chaque fichier (compression dans le format [quality], aperçu
  /// chiffré) et le confie au gestionnaire d'envoi. Les fichiers partent un
  /// par un.
  ///
  /// Envoyés ensemble dans une discussion ([shareConversationId]), plusieurs
  /// fichiers y partent en un seul message, titré [shareTitle], quand le
  /// dernier est arrivé (lot 9).
  Future<void> addFiles(
    List<SafeboxPick> picks,
    SafeboxFolder folder, {
    required SafeboxQuality quality,
    int? shareConversationId,
    String? shareTitle,
  }) async {
    final prep = await _prep();
    await prep.workDir.create(recursive: true);
    final maxApercu = (_overview?.limits.maxPreviewBytes ?? 256 * 1024) - kSafeboxTagBytes;
    final hevc = quality == SafeboxQuality.original ? false : await _hevcPermis(folder, shareConversationId);
    String? groupe;
    if (shareConversationId != null && picks.length > 1) {
      groupe = 'g${DateTime.now().microsecondsSinceEpoch}';
      (await _lireGroupes())[groupe] = _GroupeEnvoi(conversationId: shareConversationId, title: shareTitle ?? '');
      _groupesEnPreparation.add(groupe);
      await _ecrireGroupes();
    }
    try {
      await _preparer(picks, folder, prep, quality: quality, hevc: hevc, maxApercu: maxApercu,
          shareConversationId: shareConversationId, shareGroup: groupe);
    } finally {
      if (groupe != null) {
        _groupesEnPreparation.remove(groupe);
        unawaited(_verifierGroupes());
      }
    }
  }

  Future<void> _preparer(
    List<SafeboxPick> picks,
    SafeboxFolder folder,
    SafeboxMediaPrep prep, {
    required SafeboxQuality quality,
    required bool hevc,
    required int maxApercu,
    int? shareConversationId,
    String? shareGroup,
  }) async {
    for (final pick in picks) {
      // L'empreinte de l'original : la sauvegarde automatique ne renverra pas
      // une photo déjà ajoutée à la main (lot 10).
      String? empreinte;
      try {
        empreinte = await safeboxSourceFingerprint(pick.path);
      } catch (e) {
        debugPrint('[Coffre] empreinte de ${pick.name} impossible : $e');
      }
      await _preparerUn(
        pick,
        folder,
        prep,
        quality: quality,
        hevc: hevc,
        maxApercu: maxApercu,
        shareConversationId: shareConversationId,
        shareGroup: shareGroup,
        sourceFp: empreinte,
      );
    }
  }

  /// Prépare un fichier (compression, aperçu chiffré, détails) et le confie
  /// au gestionnaire d'envoi ; rend l'identifiant de l'envoi, ou null.
  Future<String?> _preparerUn(
    SafeboxPick pick,
    SafeboxFolder folder,
    SafeboxMediaPrep prep, {
    required SafeboxQuality quality,
    required bool hevc,
    required int maxApercu,
    int? shareConversationId,
    String? shareGroup,
    String? sourceFp,
    bool wifiOnly = false,
    String? backupKey,
    String? source,
  }) async {
    try {
      var chemin = pick.path;
      var nom = pick.name;
      var possede = false;
      final famille = familyOf(pick.name);
      final c = await prep.compress(pick.path, pick.name, famille, quality, hevc: hevc);
      if (c != null) {
        chemin = c.path;
        nom = c.name;
        possede = true;
      }
      final st = await File(chemin).stat();
      if (st.size <= 0) return null;
      final cle = safeboxNewFileKey();
      String? cheminApercu;
      var tailleApercu = 0;
      final apercu = await prep.preview(chemin, famille, nom);
      if (apercu != null && apercu.isNotEmpty && apercu.length <= maxApercu) {
        final chiffre = safeboxEncryptPreviewSync(cle, Uint8List.fromList(apercu));
        cheminApercu = '${prep.workDir.path}/apercu_${DateTime.now().microsecondsSinceEpoch}.sbx';
        await File(cheminApercu).writeAsBytes(chiffre, flush: true);
        tailleApercu = chiffre.length;
      }
      final details = await prep.meta(chemin, famille, nom);
      final id = '${DateTime.now().microsecondsSinceEpoch}_${pick.name.hashCode}';
      await uploads.enqueue(
        SafeboxUploadJob(
          id: id,
          folderId: folder.id,
          name: nom,
          mime: null,
          sourcePath: chemin,
          sourceSize: st.size,
          sourceModifiedMs: st.modified.millisecondsSinceEpoch,
          ownsSource: possede,
          plainSize: st.size,
          originalSize: possede ? pick.size : null,
          compressed: possede,
          // Un fichier déjà plus léger que le format part tel quel : il
          // reste un original (utile pour « Libérer la mémoire du téléphone »).
          quality: (possede ? quality : SafeboxQuality.original).name,
          previewPath: cheminApercu,
          previewSize: tailleApercu,
          shareConversationId: shareConversationId,
          shareGroup: shareGroup,
          meta: {...?details?.toJson(), 'source': ?source},
          sourceFp: sourceFp,
          wifiOnly: wifiOnly,
          backupKey: backupKey,
        ),
        cle,
      );
      return id;
    } catch (e) {
      debugPrint('[Coffre] préparation de ${pick.name} impossible : $e');
      return null;
    }
  }

  // ── Sauvegarde automatique (lot 10) ──────────────────────────────────────

  /// La galerie, les dossiers de documents et la mémoire du téléphone.
  final SafeboxDeviceSource device;
  late final SafeboxBackupEngine backup;
  final Future<bool> Function() _enCharge;

  static Future<bool> _batterieEnCharge() async {
    try {
      final etat = await Battery().batteryState;
      return etat == BatteryState.charging || etat == BatteryState.full;
    } catch (_) {
      return false;
    }
  }

  SafeboxBackupSettings _reglages = const SafeboxBackupSettings();
  SafeboxBackupSettings get backupSettings => _reglages;
  SafeboxBackupReport? _dernierPassage;

  /// Ce qu'a fait le dernier passage (espace plein, attente de la charge…).
  SafeboxBackupReport? get lastBackup => _dernierPassage;
  int _restants = 0;

  /// Fichiers du téléphone retenus que la sauvegarde n'a pas encore pris.
  int get backupRemaining => _restants;
  SafeboxMediaAccess? _acces;
  SafeboxMediaAccess? get mediaAccess => _acces;

  Future<void> loadBackupSettings() async {
    _reglages = await SafeboxBackupSettings.load();
    notifyListeners();
  }

  /// Enregistre les réglages (écrans d'activation, réglages) et lance un passage.
  Future<void> saveBackupSettings(SafeboxBackupSettings s) async {
    _reglages = s;
    await s.save();
    notifyListeners();
    unawaited(scheduleSafeboxBackgroundBackup(s));
    unawaited(runBackup());
  }

  /// Un passage de sauvegarde, si elle est activée.
  Future<SafeboxBackupReport?> runBackup() async {
    if (!_reglages.enabled) return null;
    try {
      _acces = await device.access();
      if (_overview == null) await refreshOverview();
      final r = await backup.run(_reglages);
      if (r.stop == SafeboxBackupStop.busy) return r;
      _dernierPassage = r;
      _restants = (await backup.pending(_reglages)).length;
      notifyListeners();
      return r;
    } catch (e) {
      debugPrint('[Sauvegarde] passage impossible : $e');
      return null;
    }
  }

  /// Envois de la sauvegarde qui attendent le Wi-Fi.
  int get backupWaitingWifi => uploads.jobs.where((j) => j.backupKey != null && j.state == SafeboxUploadState.waitingWifi).length;

  /// Envois de la sauvegarde en route.
  int get backupUploading => uploads.jobs.where((j) => j.backupKey != null && _envoiActif(j)).length;

  /// Espace libre du coffre, envois pas encore réservés déduits.
  Future<int?> _espaceLibre() async {
    final q = _overview?.quota;
    if (q == null) return null;
    final enAttente = uploads.jobs
        .where((j) => j.fileId == null && _envoiActif(j))
        .fold<int>(0, (s, j) => s + j.storedSize);
    return q.quotaBytes - q.usedBytes - enAttente;
  }

  /// Un fichier choisi par la sauvegarde part vers le dossier de son type.
  Future<String?> _envoyerSauvegarde(SafeboxBackupUpload u) async {
    final famille = familyOf(u.item.name);
    final racine = _overview?.rootIds[famille.root];
    if (racine == null) return null;
    final dossier = SafeboxFolder(id: racine, parentId: null, root: famille.root, name: null, depth: 0);
    final prep = await _prep();
    await prep.workDir.create(recursive: true);
    final maxApercu = (_overview?.limits.maxPreviewBytes ?? 256 * 1024) - kSafeboxTagBytes;
    final hevc = u.quality == SafeboxQuality.original ? false : await _hevcPermis(dossier, null);
    return _preparerUn(
      SafeboxPick(path: u.file.path, name: u.item.name, size: u.item.size),
      dossier,
      prep,
      quality: u.quality,
      hevc: hevc,
      maxApercu: maxApercu,
      sourceFp: u.fp,
      wifiOnly: _reglages.wifiOnly,
      backupKey: u.item.key,
      source: u.item.folder,
    );
  }

  /// « Envoyer avec les données mobiles ».
  Future<void> allowMobileData() => uploads.allowMobileData();

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

  // ── Partage dans une discussion (lots 3 et 9) ───────────────────────────

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

  Future<void> _publier(int conversationId, SafeboxSharePayload payload) async {
    final envoyer = _envoyeur;
    if (envoyer != null) {
      await envoyer(conversationId, payload);
    } else {
      _partagesEnAttente.add((conversationId, payload));
    }
  }

  /// Mini-image floue tirée de l'aperçu d'un fichier de mon coffre (base64).
  Future<String?> _flou(SafeboxFile file, {required int maxWidth, required int max}) async {
    try {
      final apercu = await previews.load(file);
      if (apercu == null) return null;
      final b64 = await ImageThumbnailService.base64ForBytes(apercu, maxWidth: maxWidth);
      return b64 != null && b64.length <= max ? b64 : null;
    } catch (e) {
      debugPrint('[Coffre] mini-image du partage : $e');
      return null;
    }
  }

  /// Crée le partage — un fichier, plusieurs en un lot ([ids], titrés
  /// [title]), ou un album — et rend le contenu du message : la mini-image
  /// floue d'un fichier, la mosaïque des quatre premiers éléments d'un lot,
  /// tirées des aperçus de [known] (mes fichiers déjà en mémoire).
  Future<SafeboxSharePayload> _creerPartage(
    int conversationId, {
    List<int> ids = const [],
    SafeboxFolder? album,
    String? title,
    Map<int, SafeboxFile> known = const {},
  }) async {
    final cree = album != null
        ? await _api.createSafeboxShare(conversationId: conversationId, folderId: album.id)
        : ids.length == 1
            ? await _api.createSafeboxShare(conversationId: conversationId, fileId: ids.first)
            : await _api.createSafeboxShare(
                conversationId: conversationId,
                fileIds: ids,
                title: title == null || title.isEmpty ? null : title,
              );
    if (cree.kind == SafeboxShareKind.batch) {
      final mosaique = <String>[];
      for (final id in cree.cover.take(4)) {
        final f = known[id];
        mosaique.add(f == null ? '' : await _flou(f, maxWidth: 16, max: SafeboxSharePayload.mosaicBlurMax) ?? '');
      }
      return SafeboxSharePayload(
        share: cree.shareId,
        name: cree.name,
        size: cree.plainBytes,
        mime: cree.mime,
        family: cree.family,
        kind: SafeboxShareKind.batch,
        count: cree.count,
        families: cree.families,
        mosaic: mosaique,
      );
    }
    final f = cree.cover.isEmpty ? null : known[cree.cover.first];
    return SafeboxSharePayload(
      share: cree.shareId,
      name: cree.name,
      size: cree.plainBytes,
      mime: cree.mime,
      family: cree.family,
      blur: f == null ? null : await _flou(f, maxWidth: 24, max: 6000),
      meta: cree.meta ?? f?.meta,
    );
  }

  /// Partage un fichier de mon coffre dans une discussion et rend le contenu
  /// du message, mini-image floue comprise (tirée de l'aperçu).
  Future<SafeboxSharePayload> shareFile(SafeboxFile file, int conversationId) =>
      _creerPartage(conversationId, ids: [file.id], known: {file.id: file});

  /// Envoie des fichiers de mon coffre dans plusieurs discussions : un seul,
  /// une sélection en un seul message (titrée [title]), ou tout un [album].
  /// Rend le nombre de discussions où ils sont partis.
  Future<int> sendToConversations(
    List<SafeboxFile> files,
    List<int> conversationIds, {
    String? title,
    SafeboxFolder? album,
  }) =>
      _envoyerPartout(
        conversationIds,
        (conv) => _creerPartage(conv,
            ids: [for (final f in files) f.id], album: album, title: title, known: {for (final f in files) f.id: f}),
      );

  /// « Envoyer ailleurs », depuis le suivi : les mêmes fichiers, sous le même titre.
  Future<int> sendShareElsewhere(SafeboxShareInfo info, List<int> conversationIds) =>
      _envoyerPartout(conversationIds, (conv) => _creerPartage(conv, ids: info.fileIds, title: info.name));

  Future<int> _envoyerPartout(List<int> conversationIds, Future<SafeboxSharePayload> Function(int conv) creer) async {
    var reussis = 0;
    Object? premiereErreur;
    for (final conv in conversationIds) {
      try {
        await _publier(conv, await creer(conv));
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
      await _publier(conversationId, await shareFile(file, conversationId));
    } catch (e) {
      debugPrint('[Coffre] partage après envoi impossible : $e');
    }
  }

  // ── Plusieurs fichiers du téléphone, un seul message (lot 9) ─────────────
  //
  // Envoyés ensemble depuis une discussion, ils partent en un lot quand plus
  // aucun d'eux n'est en cours d'envoi : ceux qui sont arrivés dans le coffre
  // (un envoi en échec ne retient pas les autres ; relancé plus tard, il part
  // seul). Gardé dans les préférences : un redémarrage n'y change rien.

  static const _cleGroupes = 'safebox_share_groups_v1';
  Map<String, _GroupeEnvoi>? _groupes;
  final Set<String> _groupesEnPreparation = {};

  /// Mes fichiers arrivés, pour la mosaïque floue du message.
  final Map<int, SafeboxFile> _fichiersDesGroupes = {};

  /// Fichiers déjà partis dans leur lot : leur annonce tardive ne les renvoie pas seuls.
  final Set<int> _partisEnLot = {};
  bool _verificationEnCours = false;
  bool _aRevoir = false;

  Future<Map<String, _GroupeEnvoi>> _lireGroupes() async {
    final deja = _groupes;
    if (deja != null) return deja;
    final lus = <String, _GroupeEnvoi>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final d = jsonDecode(prefs.getString(_cleGroupes) ?? '{}');
      if (d is Map) {
        for (final e in d.entries) {
          final g = _GroupeEnvoi.fromJson(e.value);
          if (g != null) lus['${e.key}'] = g;
        }
      }
    } catch (e) {
      debugPrint('[Coffre] groupes d\'envoi illisibles : $e');
    }
    return _groupes ??= lus;
  }

  Future<void> _ecrireGroupes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleGroupes, jsonEncode({
      for (final e in (_groupes ?? const <String, _GroupeEnvoi>{}).entries) e.key: e.value.toJson(),
    }));
  }

  Future<void> _ajouterAuGroupe(String groupe, SafeboxFile file, int conversationId) async {
    final g = (await _lireGroupes())[groupe];
    if (g == null) {
      // Déjà parti avec son lot ; sinon (envoi relancé après coup), il part seul.
      if (!_partisEnLot.contains(file.id)) await _partagerApresEnvoi(file, conversationId);
      return;
    }
    _fichiersDesGroupes[file.id] = file;
    if (!g.fileIds.contains(file.id)) g.fileIds.add(file.id);
    await _ecrireGroupes();
    await _verifierGroupes();
  }

  void _surveillerGroupes() {
    if (_groupes?.isNotEmpty ?? false) unawaited(_verifierGroupes());
  }

  static bool _envoiActif(SafeboxUploadJob j) => switch (j.state) {
        SafeboxUploadState.queued ||
        SafeboxUploadState.running ||
        SafeboxUploadState.waitingNetwork ||
        SafeboxUploadState.waitingWifi ||
        SafeboxUploadState.paused =>
          true,
        SafeboxUploadState.failed || SafeboxUploadState.completed => false,
      };

  bool _groupePret(String cle) => !uploads.jobs.any((j) => j.shareGroup == cle && _envoiActif(j));

  Future<void> _verifierGroupes() async {
    if (_verificationEnCours) {
      _aRevoir = true;
      return;
    }
    _verificationEnCours = true;
    try {
      do {
        _aRevoir = false;
        final groupes = await _lireGroupes();
        final prets = [
          for (final e in groupes.entries)
            if (!_groupesEnPreparation.contains(e.key) && _groupePret(e.key)) e,
        ];
        for (final e in prets) {
          groupes.remove(e.key);
          // Un envoi passe à « terminé » un peu avant que son fichier soit
          // annoncé : ses fichiers sont aussi pris dans les envois terminés.
          final g = e.value;
          for (final j in uploads.jobs) {
            final id = j.fileId;
            if (j.shareGroup == e.key && j.state == SafeboxUploadState.completed && id != null && !g.fileIds.contains(id)) {
              g.fileIds.add(id);
            }
          }
          // Avant toute attente : une annonce qui arrive pendant l'envoi
          // ne doit pas repartir seule.
          _partisEnLot.addAll(g.fileIds);
          await _ecrireGroupes();
          await _envoyerGroupe(g);
        }
      } while (_aRevoir);
    } finally {
      _verificationEnCours = false;
    }
  }

  Future<void> _envoyerGroupe(_GroupeEnvoi g) async {
    if (g.fileIds.isEmpty) return;
    try {
      await _publier(
        g.conversationId,
        await _creerPartage(g.conversationId, ids: g.fileIds, title: g.title, known: _fichiersDesGroupes),
      );
    } catch (e) {
      debugPrint('[Coffre] envoi groupé dans la discussion ${g.conversationId} impossible : $e');
    } finally {
      g.fileIds.forEach(_fichiersDesGroupes.remove);
    }
  }

  // ── Ce que l'on reçoit (lots 3 et 9) ─────────────────────────────────────

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

  /// Les éléments reçus par un partage, enregistrés pour le téléchargement groupé.
  final Map<int, SafeboxShareItem> _elementsRecus = {};

  /// Tous les éléments d'un partage (500 au plus, par pages de 100).
  Future<List<SafeboxShareItem>> shareItems(int shareId) async {
    final out = <SafeboxShareItem>[];
    int? curseur;
    do {
      final page = await _api.fetchSafeboxShareItems(shareId, cursor: curseur);
      out.addAll(page.items);
      curseur = page.nextCursor;
    } while (curseur != null);
    for (final i in out) {
      _elementsRecus[i.localId] = i;
    }
    return out;
  }

  /// Le téléchargement groupé (galerie, ZIP) prend aussi les éléments reçus.
  Future<File> _pourExport(SafeboxFile f) {
    final element = f.id < 0 ? _elementsRecus[f.id] : null;
    return element != null ? downloads.fetchShareItem(element) : downloads.fetch(f);
  }

  /// Télécharge un fichier reçu (compte un téléchargement), puis relit la carte.
  Future<File> downloadShare(SafeboxShareInfo info) => _telechargerElement(info.asItem());

  Future<File> _telechargerElement(SafeboxShareItem item) async {
    final f = await downloads.fetchShareItem(item);
    unawaited(shareInfo(item.shareId, refresh: true));
    return f;
  }

  /// L'onglet « Reçus ».
  Future<SafeboxReceivedPage> receivedShares({int? cursor}) => _api.fetchReceivedSafeboxShares(cursor: cursor);

  /// Le suivi d'un partage, pour son expéditeur.
  Future<SafeboxShareRecipients> shareRecipients(int shareId) => _api.fetchSafeboxShareRecipients(shareId);

  /// « Retirer le partage » ; la carte le dit ensuite.
  Future<void> revokeShare(int shareId) async {
    await _api.revokeSafeboxShare(shareId);
    await shareInfo(shareId, refresh: true);
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
  Future<({String location, bool published, bool saveFailed})> fetchReceived(SafeboxShareInfo info) =>
      fetchReceivedItem(info.asItem());

  /// Pareil pour un élément reçu : un fichier seul (élément 0) ou un élément d'un lot.
  Future<({String location, bool published, bool saveFailed})> fetchReceivedItem(SafeboxShareItem item) async {
    final cle = -item.localId;
    final deja = await received.location(cle);
    if (deja != null) return (location: deja, published: false, saveFailed: false);
    final f = await _telechargerElement(item);
    final loc = await received.publish(f, shareId: cle, name: item.name, mime: item.mime, family: item.family);
    if (loc == null) return (location: f.path, published: false, saveFailed: true);
    await downloads.evict(item.localId);
    return (location: loc, published: true, saveFailed: false);
  }

  /// Le fichier reçu est-il déjà sur le téléphone (Téléchargements, ou
  /// dossier de l'application si la copie avait échoué) ?
  Future<bool> hasReceived(SafeboxShareInfo info) => hasReceivedItem(info.asItem());

  Future<bool> hasReceivedItem(SafeboxShareItem item) async =>
      await received.location(-item.localId) != null || await downloads.cached(item.asFile()) != null;

  /// Garde dans mon coffre un fichier reçu, ou un élément d'un lot ([itemId]).
  Future<SafeboxFile> saveShare(int shareId, {int itemId = 0}) async {
    final f = await _api.saveSafeboxShare(shareId, itemId: itemId);
    await shareInfo(shareId, refresh: true);
    unawaited(refreshOverview());
    return f;
  }

  /// Garde un lot entier : il devient un album dans mes Albums.
  Future<SafeboxFolder> saveShareBatch(int shareId) async {
    final album = await _api.saveSafeboxShareBatch(shareId);
    await shareInfo(shareId, refresh: true);
    unawaited(refreshOverview());
    return album;
  }

  @override
  void dispose() {
    _reseau?.cancel();
    _minuterie?.cancel();
    _battement?.cancel();
    uploads.removeListener(_surveillerGroupes);
    _abonnementPartages.cancel();
    _abonnement.cancel();
    uploads.removeListener(notifyListeners);
    uploads.removeListener(_suivrePremierPlan);
    unawaited(_premierPlan.stop());
    downloads.removeListener(exports.refresh);
    downloads.removeListener(notifyListeners);
    exports.removeListener(notifyListeners);
    exports.dispose();
    uploads.dispose();
    downloads.dispose();
    super.dispose();
  }
}

/// Le serveur vu par la sauvegarde automatique.
class _ApiSauvegarde implements SafeboxBackupApi {
  _ApiSauvegarde(this._api);
  final TalkyApiClient _api;

  @override
  Future<Map<String, SafeboxBackupCheck>> check(List<String> fps, {bool link = true}) async {
    final r = await _api.checkSafeboxBackup(fps, link: link);
    return {
      for (final e in r.entries)
        e.key: switch (e.value) {
          'saved' => SafeboxBackupCheck.saved,
          'elsewhere' => SafeboxBackupCheck.elsewhere,
          'uploading' => SafeboxBackupCheck.uploading,
          'skip' => SafeboxBackupCheck.skip,
          _ => SafeboxBackupCheck.unknown,
        },
    };
  }

  @override
  Future<void> skip(List<String> fps) => _api.skipSafeboxBackup(fps);
}

/// Plusieurs fichiers du téléphone en route vers une même discussion : la
/// discussion, le titre du lot, et ceux déjà arrivés dans le coffre.
class _GroupeEnvoi {
  _GroupeEnvoi({required this.conversationId, required this.title, List<int>? fileIds}) : fileIds = fileIds ?? [];

  static _GroupeEnvoi? fromJson(dynamic j) {
    if (j is! Map || j['conv'] is! int) return null;
    return _GroupeEnvoi(
      conversationId: j['conv'] as int,
      title: j['title'] is String ? j['title'] as String : '',
      fileIds: [for (final v in (j['files'] is List ? j['files'] as List : const [])) if (v is int) v],
    );
  }

  final int conversationId;
  final String title;
  final List<int> fileIds;

  Map<String, dynamic> toJson() => {'conv': conversationId, 'title': title, 'files': fileIds};
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
