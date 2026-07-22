import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences utilisateur pour les médias reçus :
/// - [autoDownload] : cache app (affichage dans le chat, hors connexion).
/// - [mediaVisibility] : export vers le stockage interne (Galerie + Téléchargements).
class MediaDownloadPreferences extends ChangeNotifier {
  static const _kAutoDownloadKey = 'auto_download_media';
  static const _kMediaVisibilityKey = 'media_visibility';

  /// Instance liée au Provider (lecture synchrone depuis ChatRepository).
  static MediaDownloadPreferences? _bound;

  /// Valeurs lues depuis SharedPreferences (via [preload]) — évite le défaut
  /// `true` pendant la fenêtre avant que `load()` du Provider ne finisse,
  /// qui faisait préfetcher les médias malgré un réglage désactivé.
  static bool _prefsLoaded = false;
  static bool _cachedAutoDownload = true;
  static bool _cachedMediaVisibility = true;

  bool _autoDownload = true;
  bool _mediaVisibility = true;

  bool get autoDownload => _autoDownload;
  bool get mediaVisibility => _mediaVisibility;

  /// True seulement si l'utilisateur a activé l'auto-download (et prefs chargées).
  static bool get isAutoDownloadEnabled {
    if (_bound != null) return _bound!._autoDownload;
    return _cachedAutoDownload;
  }

  /// True si les médias reçus doivent être exportés vers le stockage interne.
  static bool get isMediaVisibilityEnabled {
    if (_bound != null) return _bound!._mediaVisibility;
    return _cachedMediaVisibility;
  }

  MediaDownloadPreferences() {
    _bound = this;
    if (_prefsLoaded) {
      _autoDownload = _cachedAutoDownload;
      _mediaVisibility = _cachedMediaVisibility;
    }
  }

  /// À appeler dans `main()` avant `runApp` pour que le prefetch socket/sync
  /// respecte tout de suite le choix persisté.
  static Future<void> preload() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cachedAutoDownload = prefs.getBool(_kAutoDownloadKey) ?? true;
    _cachedMediaVisibility = prefs.getBool(_kMediaVisibilityKey) ?? true;
    _prefsLoaded = true;
  }

  Future<void> load() async {
    await preload();
    final changed = _autoDownload != _cachedAutoDownload ||
        _mediaVisibility != _cachedMediaVisibility;
    _autoDownload = _cachedAutoDownload;
    _mediaVisibility = _cachedMediaVisibility;
    if (changed) notifyListeners();
  }

  Future<void> setAutoDownload(bool enabled) async {
    if (_autoDownload == enabled) return;
    _autoDownload = enabled;
    _cachedAutoDownload = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoDownloadKey, enabled);
  }

  Future<void> setMediaVisibility(bool enabled) async {
    if (_mediaVisibility == enabled) return;
    _mediaVisibility = enabled;
    _cachedMediaVisibility = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMediaVisibilityKey, enabled);
  }
}
