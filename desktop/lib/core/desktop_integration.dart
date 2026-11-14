// L'application sans fenêtre (14/11/2026) : la sauvegarde du PC continue
// quand la fenêtre est fermée.
//
//  - Une icône près de l'horloge (tray_manager) : Ouvrir, Sauvegarder
//    maintenant, Quitter.
//  - Fermer la fenêtre la range près de l'horloge (réglage, activé par
//    défaut, seulement connecté et si l'icône existe) ; « Quitter » quitte.
//  - Lancement au démarrage de la session (launch_at_startup), caché :
//    l'exécutable reçoit --hidden, et le code natif ne montre pas la fenêtre
//    (linux/runner/my_application.cc, windows/runner/flutter_window.cpp).
//  - Une seule instance : relancer l'application remontre la fenêtre (code
//    natif), il n'y a jamais deux sauvegardes en même temps.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/app_localizations.dart';

class DesktopIntegration extends ChangeNotifier with WindowListener, TrayListener {
  static const _cleFond = 'coffre_keep_running';

  /// Fermer la fenêtre la range près de l'horloge.
  bool keepRunning = true;

  /// Lancée au démarrage de la session.
  bool autostart = false;

  /// L'icône près de l'horloge existe (sous Linux, il faut l'extension des
  /// indicateurs, présente sur Ubuntu).
  bool trayAvailable = false;

  /// Connecté : sans session, rien ne tourne en fond, fermer quitte.
  bool Function() signedIn = () => false;

  /// « Sauvegarder maintenant » depuis l'icône.
  VoidCallback? onBackupNow;

  bool _quitter = false;
  String _menu = '';

  Future<void> start({required bool hidden}) async {
    await windowManager.ensureInitialized();
    try {
      final prefs = await SharedPreferences.getInstance();
      keepRunning = prefs.getBool(_cleFond) ?? true;
    } catch (_) {}
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    try {
      launchAtStartup.setup(
        appName: 'Alanya Coffre-fort',
        // Une AppImage se monte ailleurs à chaque lancement : c'est le
        // fichier .AppImage lui-même qu'il faut relancer.
        appPath: Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable,
        args: const ['--hidden'],
      );
      autostart = await launchAtStartup.isEnabled();
    } catch (e) {
      debugPrint('[Bureau] démarrage automatique indisponible : $e');
    }
    try {
      await trayManager.setIcon(Platform.isWindows ? 'assets/tray/tray.ico' : 'assets/tray/tray.png');
      trayManager.addListener(this);
      trayAvailable = true;
    } catch (e) {
      debugPrint('[Bureau] icône près de l\'horloge indisponible : $e');
    }
    // Caché sans moyen de revenir (pas d'icône), ou sans session (il faut le
    // code QR) : la fenêtre s'ouvre.
    if (hidden && (!trayAvailable || !signedIn())) await show();
    notifyListeners();
  }

  /// Le menu de l'icône, dans la langue de l'application.
  Future<void> setMenu(AppLocalizations l, {required bool backup}) async {
    if (!trayAvailable) return;
    final cle = '${l.localeName}|$backup';
    if (cle == _menu) return;
    _menu = cle;
    try {
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'open', label: l.trayOpen),
        if (backup) MenuItem(key: 'backup', label: l.trayBackupNow),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: l.trayQuit),
      ]));
      if (!Platform.isLinux) await trayManager.setToolTip(l.appTitle);
    } catch (e) {
      debugPrint('[Bureau] menu de l\'icône : $e');
    }
  }

  Future<void> setKeepRunning(bool oui) async {
    keepRunning = oui;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cleFond, oui);
    } catch (_) {}
  }

  Future<void> setAutostart(bool oui) async {
    try {
      final ok = oui ? await launchAtStartup.enable() : await launchAtStartup.disable();
      if (ok) autostart = oui;
    } catch (e) {
      debugPrint('[Bureau] démarrage automatique : $e');
    }
    autostart = await launchAtStartup.isEnabled().catchError((_) => autostart);
    notifyListeners();
  }

  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Quitte vraiment : la sauvegarde s'arrête avec l'application.
  Future<void> quit() async {
    _quitter = true;
    try {
      if (trayAvailable) await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (!_quitter && keepRunning && trayAvailable && signedIn()) {
      unawaited(windowManager.hide());
    } else {
      unawaited(quit());
    }
  }

  // Windows : un clic sur l'icône ouvre, un clic droit montre le menu. Sous
  // Linux, l'icône n'a qu'un menu.
  @override
  void onTrayIconMouseDown() => unawaited(show());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(show());
      case 'backup':
        onBackupNow?.call();
      case 'quit':
        unawaited(quit());
    }
  }
}
