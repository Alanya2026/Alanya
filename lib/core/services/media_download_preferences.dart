import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférence utilisateur : téléchargement automatique des médias reçus
/// (photos, vidéos, fichiers) vers le cache app + album/dossier Alanya.
class MediaDownloadPreferences extends ChangeNotifier {
  static const _kKey = 'auto_download_media';

  /// Instance liée au Provider (lecture synchrone depuis ChatRepository).
  static MediaDownloadPreferences? _bound;

  /// Valeur lue depuis SharedPreferences (via [preload]) — évite le défaut
  /// `true` pendant la fenêtre avant que `load()` du Provider ne finisse,
  /// qui faisait préfetcher les médias malgré un réglage désactivé.
  static bool _prefsLoaded = false;
  static bool _cachedAutoDownload = true;

  bool _autoDownload = true;

  bool get autoDownload => _autoDownload;

  /// True seulement si l'utilisateur a activé l'auto-download (et prefs chargées).
  static bool get isAutoDownloadEnabled {
    if (_bound != null) return _bound!._autoDownload;
    return _cachedAutoDownload;
  }

  MediaDownloadPreferences() {
    _bound = this;
    if (_prefsLoaded) {
      _autoDownload = _cachedAutoDownload;
    }
  }

  /// À appeler dans `main()` avant `runApp` pour que le prefetch socket/sync
  /// respecte tout de suite le choix persisté.
  static Future<void> preload() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cachedAutoDownload = prefs.getBool(_kKey) ?? true;
    _prefsLoaded = true;
  }

  Future<void> load() async {
    await preload();
    if (_autoDownload != _cachedAutoDownload) {
      _autoDownload = _cachedAutoDownload;
      notifyListeners();
    } else {
      _autoDownload = _cachedAutoDownload;
    }
  }

  Future<void> setAutoDownload(bool enabled) async {
    if (_autoDownload == enabled) return;
    _autoDownload = enabled;
    _cachedAutoDownload = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, enabled);
  }
}
