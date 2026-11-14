//  La sauvegarde automatique en tâche de fond (lot 10) : WorkManager d'Android
//  réveille l'application toutes les heures environ (réseau non facturé si
//  « Seulement en Wi-Fi », batterie pas faible) pour un passage, comme celui
//  que l'application fait à son ouverture et au retour du Wi-Fi.
//
//  L'application ouverte et la tâche de fond n'envoient jamais en même temps :
//  chacune marque sa présence toutes les minutes ([SafeboxRunLock]). La tâche
//  de fond s'efface si l'application tourne ; l'application ouverte attend la
//  fin d'un passage de fond avant de reprendre les envois.
//
//  WorkManager laisse une dizaine de minutes à chaque passage : un gros envoi
//  reprend au suivant, par blocs (section 04).

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../talky_api_client.dart';
import '../local_notification_helper.dart' show kNotificationIcon;
import 'safebox_controller.dart';
import 'safebox_foreground.dart';

const String kSafeboxBackupTask = 'alanya.coffre.sauvegarde';

/// Qui envoie en ce moment : l'application ouverte ou la tâche de fond.
class SafeboxRunLock {
  static const app = 'safebox_lock_app_v1';
  static const background = 'safebox_lock_background_v1';

  /// Une présence plus vieille ne compte plus (l'autre partie s'est arrêtée).
  static const fresh = Duration(minutes: 2);

  static Future<void> beat(String who) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(who, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> release(String who) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(who);
  }

  static Future<bool> held(String who, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final t = prefs.getInt(who);
    if (t == null) return false;
    return (now ?? DateTime.now()).millisecondsSinceEpoch - t < fresh.inMilliseconds;
  }
}

/// La notification de la tâche de fond (11/11/2026) : le service de premier
/// plan de l'application n'existe qu'avec elle ouverte, et l'inscrit ne
/// voyait rien pendant que la sauvegarde tournait. Même canal que ce service
/// (`alanya_safebox`, discret). Retirée à la fin du passage ; si Android
/// coupe le passage, elle s'efface seule au bout de 12 minutes.
class SafeboxBackgroundNotice extends SafeboxForeground {
  SafeboxBackgroundNotice({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int _id = 7311;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _pret = false;
  bool _affichee = false;
  String? _dernier;

  @override
  Future<void> show({
    required String channelName,
    required String title,
    required String text,
    required int percent,
  }) async {
    final cle = '$title|$text|$percent';
    if (_affichee && cle == _dernier) return;
    _dernier = cle;
    try {
      if (!_pret) {
        await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings(kNotificationIcon)));
        _pret = true;
      }
      await _plugin.show(
        _id,
        title,
        text,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'alanya_safebox',
            channelName,
            importance: Importance.low,
            priority: Priority.low,
            icon: kNotificationIcon,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            playSound: false,
            enableVibration: false,
            showProgress: true,
            maxProgress: 100,
            progress: percent.clamp(0, 100),
            indeterminate: percent < 0,
            timeoutAfter: const Duration(minutes: 12).inMilliseconds,
          ),
        ),
      );
      _affichee = true;
    } catch (e) {
      debugPrint('[Sauvegarde] notification de fond impossible : $e');
    }
  }

  Future<void>? _retrait;

  /// Rend le retrait en cours s'il y en a un : la fin du passage l'attend.
  @override
  Future<void> stop() {
    if (!_affichee) return _retrait ?? Future<void>.value();
    _affichee = false;
    _dernier = null;
    return _retrait = _plugin.cancel(_id).catchError((Object _) {});
  }
}

/// À appeler une fois au démarrage de l'application (Android).
Future<void> initSafeboxBackgroundBackup() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await Workmanager().initialize(safeboxBackupDispatcher);
  } catch (e) {
    debugPrint('[Sauvegarde] WorkManager indisponible : $e');
  }
}

/// Programme (ou retire) le passage de fond selon les réglages.
Future<void> scheduleSafeboxBackgroundBackup(SafeboxBackupSettings s) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    if (!s.enabled) {
      await Workmanager().cancelByUniqueName(kSafeboxBackupTask);
      return;
    }
    await Workmanager().registerPeriodicTask(
      kSafeboxBackupTask,
      kSafeboxBackupTask,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: s.wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (e) {
    debugPrint('[Sauvegarde] programmation impossible : $e');
  }
}

@pragma('vm:entry-point')
void safeboxBackupDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != kSafeboxBackupTask) return true;
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await runSafeboxBackgroundPass();
    } catch (e) {
      debugPrint('[Sauvegarde] passage de fond interrompu : $e');
    }
    return true;
  });
}

/// Un passage de fond : la session de l'application, un passage de
/// sauvegarde, puis les envois jusqu'à la fin du temps accordé.
Future<void> runSafeboxBackgroundPass({Duration budget = const Duration(minutes: 9)}) async {
  final reglages = await SafeboxBackupSettings.load();
  if (!reglages.enabled) return;
  if (await SafeboxRunLock.held(SafeboxRunLock.app)) return;
  final api = TalkyApiClient();
  // Renouveler la session ici ne gêne pas l'application : le serveur ne
  // retire pas l'ancien jeton de renouvellement.
  if (!await api.refreshSessionFromStorage()) return;
  final fin = DateTime.now().add(budget);
  await SafeboxRunLock.beat(SafeboxRunLock.background);
  final battement = Timer.periodic(const Duration(minutes: 1), (_) {
    unawaited(SafeboxRunLock.beat(SafeboxRunLock.background));
  });
  final avis = SafeboxBackgroundNotice();
  final c = SafeboxController(api: api, foreground: avis);
  try {
    await c.loadBackupSettings();
    await c.refreshOverview();
    // Les envois gardés chargés avant le passage, qui les consulte.
    await c.uploads.reload();
    unawaited(c.uploads.resumeAll());
    // WorkManager ne lance ce passage que sur un réseau permis par les réglages.
    unawaited(c.uploads.resumeWaitingWifi());
    await c.runBackup();
    while (DateTime.now().isBefore(fin)) {
      final actifs = c.uploads.jobs.where((j) =>
          j.state == SafeboxUploadState.queued || j.state == SafeboxUploadState.running);
      if (actifs.isEmpty) break;
      // L'application vient de s'ouvrir : elle prend la suite.
      if (await SafeboxRunLock.held(SafeboxRunLock.app)) break;
      await Future<void>.delayed(const Duration(seconds: 5));
    }
    // Un envoi coupé ici reprend au passage suivant, ou à l'ouverture de
    // l'application, par blocs.
  } finally {
    battement.cancel();
    await SafeboxRunLock.release(SafeboxRunLock.background);
    c.dispose();
    // Retirée avant que le processus s'arrête (dispose ne l'attend pas).
    await avis.stop();
  }
}
