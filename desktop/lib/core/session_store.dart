// Ce que l'application garde sur l'ordinateur : jetons dans le coffre du
// système (Windows : gestionnaire d'identifiants ; Linux : libsecret),
// réglages dans les préférences, fichiers dans le dossier de l'application.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredSession {
  StoredSession({required this.access, required this.refresh, required this.user});
  final String access;
  final String refresh;
  final Map<String, dynamic> user;
}

class SessionStore {
  SessionStore({FlutterSecureStorage? secure}) : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _access = 'coffre_access_token';
  static const _refresh = 'coffre_refresh_token';
  static const _user = 'coffre_user';
  static const _deviceId = 'coffre_device_id';
  static const _connecteLe = 'coffre_connected_at';

  Future<StoredSession?> load() async {
    try {
      final a = await _secure.read(key: _access);
      final r = await _secure.read(key: _refresh);
      if (a == null || r == null) return null;
      final prefs = await SharedPreferences.getInstance();
      final u = prefs.getString(_user);
      return StoredSession(
        access: a,
        refresh: r,
        user: u == null ? const {} : Map<String, dynamic>.from(jsonDecode(u) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _secure.write(key: _access, value: access);
    await _secure.write(key: _refresh, value: refresh);
  }

  Future<void> saveSession({required String access, required String refresh, required Map<String, dynamic> user}) async {
    await saveTokens(access: access, refresh: refresh);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_user, jsonEncode(user));
    await prefs.setString(_connecteLe, DateTime.now().toIso8601String());
  }

  Future<DateTime?> connectedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString(_connecteLe) ?? '');
  }

  /// Identifiant stable de cet ordinateur pour le serveur (un appareil par
  /// installation) ; survit à la déconnexion.
  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final deja = prefs.getString(_deviceId);
    if (deja != null) return deja;
    final r = Random.secure();
    final id = 'pc-${List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    await prefs.setString(_deviceId, id);
    return id;
  }

  /// « Se déconnecter » : jetons, compte, réglages et fichiers gardés
  /// (aperçus, copies pour la visionneuse). Seul l'identifiant de
  /// l'ordinateur reste.
  Future<void> wipe() async {
    try {
      await _secure.deleteAll();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_deviceId);
    await prefs.clear();
    if (id != null) await prefs.setString(_deviceId, id);
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/safebox');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Nom de cet ordinateur, montré dans « Appareils connectés » sur le téléphone.
String computerName() {
  final nom = Platform.localHostname.trim();
  final systeme = Platform.isWindows ? 'Windows' : 'Linux';
  return nom.isEmpty ? systeme : '$nom · $systeme';
}
