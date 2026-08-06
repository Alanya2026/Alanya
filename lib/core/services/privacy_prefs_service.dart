import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'notifications/notification_prefs_cache.dart';

/// Préférences de confidentialité : cache local + synchronisation serveur.
class PrivacyPrefsService extends ChangeNotifier {
  static const _cacheKey = 'privacy_prefs_json_v1';

  final TalkyApiClient _api;

  PrivacyPrefs _prefs = const PrivacyPrefs();
  bool _loaded = false;
  bool _syncing = false;

  PrivacyPrefsService({TalkyApiClient? api})
      : _api = api ?? TalkyApiClient();

  PrivacyPrefs get prefs => _prefs;
  bool get isLoaded => _loaded;
  bool get isSyncing => _syncing;

  Future<void> loadFromCache() async {
    final stored = await SharedPreferences.getInstance();
    final raw = stored.getString(_cacheKey);
    if (raw == null) return;
    try {
      _prefs = PrivacyPrefs.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[PrivacyPrefsService] cache illisible: $e');
    }
  }

  Future<void> syncFromServer() async {
    _syncing = true;
    notifyListeners();
    try {
      final remote = await _api.getPrivacyPrefs();
      await _apply(remote, persist: true);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<PrivacyPrefs> update(PrivacyPrefs next) async {
    final patch = _diffPatch(_prefs, next);
    if (patch.isEmpty) return _prefs;
    final remote = await _api.patchPrivacyPrefs(patch);
    await _apply(remote, persist: true);
    return _prefs;
  }

  Future<void> patchField(String key, dynamic value) async {
    final remote = await _api.patchPrivacyPrefs({key: value});
    await _apply(remote, persist: true);
  }

  Future<void> clear() async {
    _prefs = const PrivacyPrefs();
    _loaded = false;
    final stored = await SharedPreferences.getInstance();
    await stored.remove(_cacheKey);
    notifyListeners();
  }

  Future<void> _apply(PrivacyPrefs next, {required bool persist}) async {
    _prefs = next;
    _loaded = true;
    if (persist) {
      final stored = await SharedPreferences.getInstance();
      await stored.setString(_cacheKey, jsonEncode(next.toJson()));
      await NotificationPrefsCache.applyFromServer(next.toJson());
    }
    notifyListeners();
  }

  Map<String, dynamic> _diffPatch(PrivacyPrefs current, PrivacyPrefs next) {
    final patch = <String, dynamic>{};
    if (current.lastSeenVisibility != next.lastSeenVisibility) {
      patch['lastSeenVisibility'] = next.lastSeenVisibility;
    }
    if (current.onlineVisibility != next.onlineVisibility) {
      patch['onlineVisibility'] = next.onlineVisibility;
    }
    if (current.readReceiptsEnabled != next.readReceiptsEnabled) {
      patch['readReceiptsEnabled'] = next.readReceiptsEnabled;
    }
    if (current.profilePhotoVisibility != next.profilePhotoVisibility) {
      patch['profilePhotoVisibility'] = next.profilePhotoVisibility;
    }
    if (current.addMePolicy != next.addMePolicy) {
      patch['addMePolicy'] = next.addMePolicy;
    }
    if (current.previewMode != next.previewMode) {
      patch['previewMode'] = next.previewMode;
    }
    return patch;
  }
}
