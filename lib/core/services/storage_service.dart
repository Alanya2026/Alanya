import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../talky_models.dart';
import 'call/pending_call_reject_store.dart';
import 'notifications/notification_native_credentials_store.dart';

/// Stockage chiffré session (tokens + profil). Instance unique pour garantir
/// que AuthProvider et TalkyApiClient lisent/écrivent le même fichier.
class StorageService {
  StorageService._({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? _defaultSecureStorage;

  static final StorageService instance = StorageService._();

  factory StorageService({FlutterSecureStorage? secureStorage}) {
    if (secureStorage != null) {
      return StorageService._(secureStorage: secureStorage);
    }
    return instance;
  }

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  static const String _deviceIdKey = 'talky_device_id';

  static const FlutterSecureStorage _defaultSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  final FlutterSecureStorage _secureStorage;

  Future<void> init() async {}

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await PendingCallRejectStore.syncNativeCredentials(
      accessToken,
      refreshToken: refreshToken,
    );
    // Le trio call_reject_* ci-dessus est désormais le seul miroir natif ;
    // l'ancien access token en clair de notif_action_* est retiré du disque.
    await NotificationNativeCredentialsStore.purgeLegacyKeys();
  }

  Future<String?> getAccessToken() => _secureStorage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _secureStorage.read(key: _refreshTokenKey);

  Future<void> saveUser(User user) async {
    await _secureStorage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<User?> getUser() async {
    final userStr = await _secureStorage.read(key: _userKey);
    if (userStr == null) return null;
    try {
      return User.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[StorageService] getUser parse error: $e\n$st');
      }
      return null;
    }
  }

  Future<void> clearAll() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userKey);
    await PendingCallRejectStore.clearNativeCredentials();
    await NotificationNativeCredentialsStore.purgeLegacyKeys();
  }

  Future<bool> isLoggedIn() async => (await getAccessToken()) != null;

  /// Identifiant stable de l'installation (multi-device FCM / socket auth).
  Future<String> getOrCreateDeviceId() async {
    var id = await _secureStorage.read(key: _deviceIdKey);
    if (id != null && id.isNotEmpty) return id;
    id = _generateDeviceId();
    await _secureStorage.write(key: _deviceIdKey, value: id);
    return id;
  }

  String _generateDeviceId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
