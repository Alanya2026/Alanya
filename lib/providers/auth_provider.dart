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
    await _storage.init();
    await _checkAuthStatus();
    _isInitialized = true;
    notifyListeners();
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
    } catch (_) {
      await _storage.clearAll();
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
