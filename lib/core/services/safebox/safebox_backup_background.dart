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

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../talky_api_client.dart';
import 'safebox_backup.dart';
import 'safebox_controller.dart';
import 'safebox_upload_manager.dart';

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
  final c = SafeboxController(api: api);
  try {
    await c.loadBackupSettings();
    await c.refreshOverview();
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
  }
}
