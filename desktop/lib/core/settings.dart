import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La langue choisie dans les réglages ; null : celle du système.
class LocaleSetting extends ChangeNotifier {
  static const _cle = 'coffre_locale';
  static const supported = ['fr', 'en'];

  Locale? _locale;
  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_cle);
    _locale = supported.contains(code) ? Locale(code!) : null;
    notifyListeners();
  }

  Future<void> set(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_cle);
      _locale = null;
    } else {
      await prefs.setString(_cle, code);
      _locale = Locale(code);
    }
    notifyListeners();
  }
}
