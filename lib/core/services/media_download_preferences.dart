import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';

/// Le téléchargement automatique des médias reçus est ACTIF par défaut.
///
/// « Reçu » devient ainsi « conservé » sans que l'utilisateur ait à y penser.
/// C'est ce qui donne son sens à la rétention serveur : un média qu'il n'a
/// jamais ouvert disparaît au bout de la rétention, et personne ne récupère un
/// fichier qu'on n'a pas téléchargé à temps.
const bool kAutoDownloadParDefaut = true;

/// …mais restreint au Wi-Fi par défaut.
///
/// Activer le téléchargement automatique sans ce garde-fou reviendrait à
/// consommer le forfait de l'utilisateur sans qu'il l'ait demandé — inacceptable
/// là où les données mobiles coûtent cher. Les deux défauts vont ensemble : le
/// premier n'est défendable que parce que le second existe.
const bool kWifiOnlyParDefaut = true;

/// Préférences utilisateur pour les médias reçus :
/// - [autoDownload] : cache app (affichage dans le chat, hors connexion).
/// - [mediaVisibility] : export vers le stockage interne (Galerie + Téléchargements).
/// - [wifiOnly] / [dataSaver] : restreignent l'auto-téléchargement au Wi-Fi.
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
  static bool _cachedAutoDownload = kAutoDownloadParDefaut;
  static bool _cachedMediaVisibility = false;
  static bool _cachedWifiOnly = kWifiOnlyParDefaut;
  static bool _cachedDataSaver = false;

  bool _autoDownload = kAutoDownloadParDefaut;
  bool _mediaVisibility = false;
  bool _wifiOnly = kWifiOnlyParDefaut;
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

  static bool get _wifiOnlyEffectif {
    // `dataSaver` et `wifiOnly` expriment la même intention — ne pas dépenser
    // de données mobiles — donc l'un ou l'autre suffit à restreindre.
    if (_bound != null) return _bound!._wifiOnly || _bound!._dataSaver;
    return _cachedWifiOnly || _cachedDataSaver;
  }

  /// `true` si un média reçu doit être téléchargé automatiquement MAINTENANT.
  ///
  /// Contrairement à [isAutoDownloadEnabled], qui ne lit que la préférence,
  /// cette méthode consulte aussi le réseau courant. C'est elle qui rend le
  /// réglage « Wi-Fi uniquement » effectif : il s'affichait dans les réglages
  /// depuis toujours, mais n'était lu nulle part dans le chemin de
  /// téléchargement — l'interrupteur ne faisait rien.
  ///
  /// Asynchrone parce que l'état du réseau se demande à la plateforme. Les
  /// appelants sont déjà dans un contexte asynchrone.
  static Future<bool> shouldAutoDownloadNow({ConnectivityService? connectivity}) async {
    if (!isAutoDownloadEnabled) return false;
    if (!_wifiOnlyEffectif) return true;
    try {
      return await (connectivity ?? ConnectivityService()).currentIsUnmetered;
    } catch (e) {
      // Réseau indéterminable : on s'abstient. Une vignette manquante se
      // rattrape d'un appui ; du forfait consommé, non.
      debugPrint('[MediaDownload] type de réseau indéterminable, abstention: $e');
      return false;
    }
  }

  /// `true` si les vignettes d'un pack de stickers installé peuvent être
  /// préchargées MAINTENANT : **Wi-Fi (ou Ethernet) seulement**, quel que soit
  /// le réglage « Wi-Fi uniquement » — un préchargement que l'utilisateur n'a
  /// pas demandé ne consomme jamais de données mobiles. Respecte aussi
  /// l'extinction du téléchargement automatique. Les stickers complets, eux,
  /// se chargent à la demande, sur n'importe quel réseau.
  static Future<bool> shouldPrefetchStickersNow({
    ConnectivityService? connectivity,
  }) async {
    if (!isAutoDownloadEnabled) return false;
    try {
      return await (connectivity ?? ConnectivityService()).currentIsUnmetered;
    } catch (e) {
      debugPrint('[MediaDownload] préchargement stickers : réseau indéterminable, abstention: $e');
      return false;
    }
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
    _cachedAutoDownload = prefs.getBool(_kAutoDownloadKey) ?? kAutoDownloadParDefaut;
    _cachedMediaVisibility = prefs.getBool(_kMediaVisibilityKey) ?? false;
    _cachedWifiOnly = prefs.getBool(_kWifiOnlyKey) ?? kWifiOnlyParDefaut;
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
