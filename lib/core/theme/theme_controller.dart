import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contrôleur de thème persistant.
///
/// Appeler [load] au démarrage pour restaurer le choix de l'utilisateur.
/// Passer [mode] à `MaterialApp.themeMode`.
class ThemeController extends ChangeNotifier {
  static const _kKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Restaure le mode depuis SharedPreferences (no-op si aucune valeur).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_kKey);
    if (index != null && index < ThemeMode.values.length) {
      _mode = ThemeMode.values[index];
      notifyListeners();
    }
  }

  /// Applique et persiste un nouveau [ThemeMode].
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kKey, mode.index);
  }
}
