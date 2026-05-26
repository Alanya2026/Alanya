import 'dart:io';

import 'package:flutter/material.dart';
import '../core/services/storage_service.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';

class AuthProvider extends ChangeNotifier {
  final TalkyApiClient _apiClient;
  final StorageService _storage;

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  AuthProvider({TalkyApiClient? apiClient, StorageService? storage})
      : _apiClient = apiClient ?? TalkyApiClient(),
        _storage = storage ?? StorageService();

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    try {
      await _storage.init();
      await _checkAuthStatus();
    } catch (e) {
      debugPrint('[AuthProvider] ** init() error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      final accessToken = await _storage.getAccessToken();
      final refreshToken = await _storage.getRefreshToken();
      if (accessToken == null) return;

      _apiClient.setToken(accessToken);
      if (refreshToken != null) {
        _apiClient.setRefreshToken(refreshToken);
      }
      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      _apiClient.connectSocket();
    } catch (e) {
      debugPrint('[AuthProvider] ** _checkAuthStatus error: $e');
      try { await _storage.clearAll(); } catch (_) {}
      _apiClient.logout();
    }
  }

  Future<void> login({
    required String alanyaPhone,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiClient.login(
        alanyaPhone: alanyaPhone,
        password: password,
      );

      await _storage.saveTokens(
        accessToken: _apiClient.accessToken!,
        refreshToken: _apiClient.currentRefreshToken!,
      );

      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      _apiClient.connectSocket();
    } on TalkyException catch (e) {
      _error = e.message;
      debugPrint('[AuthProvider] Login TalkyException: ${e.message} (Status: ${e.statusCode})');
    } catch (e) {
      _error = 'Une erreur est survenue: $e';
      debugPrint('[AuthProvider] Login Exception: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String nom,
    required String pseudo,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiClient.register(
        email: email,
        password: password,
        nom: nom,
        pseudo: pseudo,
      );

      await _storage.saveTokens(
        accessToken: _apiClient.accessToken!,
        refreshToken: _apiClient.currentRefreshToken!,
      );

      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      _apiClient.connectSocket();
    } on TalkyException catch (e) {
      _error = e.message;
      debugPrint('[AuthProvider] Register TalkyException: ${e.message} (Status: ${e.statusCode})');
    } catch (e) {
      _error = 'Une erreur est survenue: $e';
      debugPrint('[AuthProvider] Register Exception: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Upload une nouvelle photo de profil puis rafraîchit le user.
  /// Retourne l'URL servie par le backend. Lève en cas d'échec.
  Future<String> updateAvatar(File file) async {
    final res = await _apiClient.uploadAvatar(file);
    final url = (res['url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      throw TalkyException('Réponse upload invalide', 0);
    }
    await _refreshCurrentUser();
    return url;
  }

  /// Supprime la photo de profil (remet la valeur sentinelle backend).
  Future<void> removeAvatar() async {
    await _apiClient.updateMe(avatarUrl: 'NON DEFINI');
    await _refreshCurrentUser();
  }

  Future<void> _refreshCurrentUser() async {
    try {
      final data = await _apiClient.getMe();
      _currentUser = User.fromJson(data);
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] _refreshCurrentUser error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    _apiClient.logout();
    await _storage.clearAll();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
