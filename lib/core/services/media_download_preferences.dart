import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences utilisateur pour les médias reçus :
/// - [autoDownload] : cache app (affichage dans le chat, hors connexion).
/// - [mediaVisibility] : export vers le stockage interne (Galerie + Téléchargements).
class MediaDownloadPreferences extends ChangeNotifier {
  static const _kAutoDownloadKey = 'auto_download_media';
  static const _kMediaVisibilityKey = 'media_visibility';
  static const _kWifiOnlyKey = 'media_wifi_only';
  static const _kDataSaverKey = 'media_data_saver';

  /// Instance liée au Provider (lecture synchrone depuis ChatRepository).
  static MediaDownloadPreferences? _bound;

  /// Valeurs lues depuis SharedPreferences (via [preload]) — évite un défaut
  /// incorrect pendant la fenêtre avant que `load()` du Provider ne finisse.
  static bool _prefsLoaded = false;
  static bool _cachedAutoDownload = false;
  static bool _cachedMediaVisibility = false;
  static bool _cachedWifiOnly = false;
  static bool _cachedDataSaver = false;

  bool _autoDownload = false;
  bool _mediaVisibility = false;
  bool _wifiOnly = false;
  bool _dataSaver = false;

  bool get autoDownload => _autoDownload;
  bool get mediaVisibility => _mediaVisibility;
  bool get wifiOnly => _wifiOnly;
  bool get dataSaver => _dataSaver;

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
      _wifiOnly = _cachedWifiOnly;
      _dataSaver = _cachedDataSaver;
    }
  }

  /// À appeler dans `main()` avant `runApp` pour que le prefetch socket/sync
  /// respecte tout de suite le choix persisté.
  static Future<void> preload() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cachedAutoDownload = prefs.getBool(_kAutoDownloadKey) ?? false;
    _cachedMediaVisibility = prefs.getBool(_kMediaVisibilityKey) ?? false;
    _cachedWifiOnly = prefs.getBool(_kWifiOnlyKey) ?? false;
    _cachedDataSaver = prefs.getBool(_kDataSaverKey) ?? false;
    _prefsLoaded = true;
  }

  Future<void> load() async {
    await preload();
    final changed = _autoDownload != _cachedAutoDownload ||
        _mediaVisibility != _cachedMediaVisibility ||
        _wifiOnly != _cachedWifiOnly ||
        _dataSaver != _cachedDataSaver;
    _autoDownload = _cachedAutoDownload;
    _mediaVisibility = _cachedMediaVisibility;
    _wifiOnly = _cachedWifiOnly;
    _dataSaver = _cachedDataSaver;
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

  Future<void> setWifiOnly(bool enabled) async {
    if (_wifiOnly == enabled) return;
    _wifiOnly = enabled;
    _cachedWifiOnly = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWifiOnlyKey, enabled);
  }

  Future<void> setDataSaver(bool enabled) async {
    if (_dataSaver == enabled) return;
    _dataSaver = enabled;
    _cachedDataSaver = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDataSaverKey, enabled);
  }
}
