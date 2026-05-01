import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../talky_models.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_accessTokenKey, accessToken);
    await _prefs.setString(_refreshTokenKey, refreshToken);
  }

  String? getAccessToken() => _prefs.getString(_accessTokenKey);
  String? getRefreshToken() => _prefs.getString(_refreshTokenKey);

  Future<void> saveUser(User user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  User? getUser() {
    final userStr = _prefs.getString(_userKey);
    if (userStr == null) return null;
    try {
      return User.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _prefs.remove(_accessTokenKey);
    await _prefs.remove(_refreshTokenKey);
    await _prefs.remove(_userKey);
  }

  bool isLoggedIn() => getAccessToken() != null;
}
