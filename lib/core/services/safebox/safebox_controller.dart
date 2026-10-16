//  Le coffre-fort côté application : ce que les écrans voient et font.
//
//  Vit au niveau de l'application (MultiProvider de main.dart) : un envoi
//  continue quand l'inscrit quitte l'écran du coffre.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/locale_controller.dart';
import '../local_notification_helper.dart';
import '../../../talky_api_client.dart';
import 'safebox_cipher.dart';
import 'safebox_download_manager.dart';
import 'safebox_foreground.dart';
import 'safebox_media_prep.dart';
import 'safebox_models.dart';
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
  const SafeboxRejection(this.pick, this.reason, {this.expectedRoot});
  final SafeboxPick pick;
  final SafeboxRejectReason reason;
  final SafeboxRoot? expectedRoot;
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
  }

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
        SafeboxRoot.albums => l10n.safeboxRootAlbums,
        SafeboxRoot.videos => l10n.safeboxRootVideos,
        SafeboxRoot.audios => l10n.safeboxRootAudios,
        SafeboxRoot.documents => l10n.safeboxRootDocuments,
      };

  static String folderLabel(SafeboxFolder f, AppLocalizations l10n) =>
      f.isRoot ? rootLabel(f.root, l10n) : (f.name ?? '');

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
  /// autres avec la raison (mauvais dossier, trop gros, vide).
  ({List<SafeboxPick> ok, List<SafeboxRejection> rejected}) triage(List<SafeboxPick> picks, SafeboxFolder folder) {
    final limites = _overview?.limits;
    final ok = <SafeboxPick>[];
    final refuses = <SafeboxRejection>[];
    for (final pick in picks) {
      if (pick.size <= 0) {
        refuses.add(SafeboxRejection(pick, SafeboxRejectReason.empty));
        continue;
      }
      final famille = limites?.familyOf(pick.name) ?? folder.root;
      if (famille != folder.root) {
        refuses.add(SafeboxRejection(pick, SafeboxRejectReason.wrongFamily, expectedRoot: famille));
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
  /// quand rien de ce lot ne se compresse (documents, audios, GIF…).
  Future<({int original, int compressed})?> estimate(List<SafeboxPick> picks, SafeboxRoot root) async {
    if (!picks.any((p) => SafeboxMediaPrep.canCompress(root, p.name))) return null;
    final prep = await _prep();
    var original = 0;
    var compresse = 0;
    for (final p in picks) {
      original += p.size;
      compresse += SafeboxMediaPrep.canCompress(root, p.name) ? await prep.estimate(p.path, root, p.size) : p.size;
    }
    return (original: original, compressed: compresse);
  }

  /// Prépare chaque fichier (compression au besoin, aperçu chiffré) et le
  /// confie au gestionnaire d'envoi. Les fichiers partent un par un.
  Future<void> addFiles(List<SafeboxPick> picks, SafeboxFolder folder, {required bool compress}) async {
    final prep = await _prep();
    await prep.workDir.create(recursive: true);
    final maxApercu = (_overview?.limits.maxPreviewBytes ?? 256 * 1024) - kSafeboxTagBytes;
    for (final pick in picks) {
      try {
        var source = pick.path;
        var nom = pick.name;
        var possede = false;
        if (compress) {
          final c = await prep.compress(pick.path, pick.name, folder.root);
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
        final apercu = await prep.preview(source, folder.root, nom);
        if (apercu != null && apercu.isNotEmpty && apercu.length <= maxApercu) {
          final chiffre = safeboxEncryptPreviewSync(cle, Uint8List.fromList(apercu));
          cheminApercu = '${prep.workDir.path}/apercu_${DateTime.now().microsecondsSinceEpoch}.sbx';
          await File(cheminApercu).writeAsBytes(chiffre, flush: true);
          tailleApercu = chiffre.length;
        }
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
          ),
          cle,
        );
      } catch (e) {
        debugPrint('[Coffre] préparation de ${pick.name} impossible : $e');
      }
    }
  }

  @override
  void dispose() {
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
