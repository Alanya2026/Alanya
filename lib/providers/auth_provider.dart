import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../core/services/storage_service.dart';
import '../core/services/call/pending_call_reject_store.dart';
import '../core/utils/app_log.dart';
import '../core/utils/alanya_phone_formatter.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';
import '../core/theme/locale_controller.dart';

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
      // Hydrate immédiatement depuis le cache : si on a un user, on marque
      // l'app initialisée TOUT DE SUITE pour éviter le spinner pendant le
      // getMe réseau (jusqu'à 15s). Le rafraîchissement serveur tourne en
      // tâche de fond et notifyListeners() rebuilde la UI si le user a changé.
      try {
        final cached = await _storage.getUser();
        if (cached != null) {
          _currentUser = cached;
          // Tokens avant bind → connectSocket (sinon connect no-op sans JWT).
          await _hydrateTokensFromStorage();
          _isInitialized = true;
          notifyListeners();
          unawaited(_checkAuthStatus());
          return;
        }
      } catch (e, st) {
        AppLog.w('AuthProvider', 'Hydratation user (cache) échouée', e, st);
      }
      // Pas de cache → on doit attendre la décision réseau pour savoir si
      // on affiche le Login ou le Home.
      await _checkAuthStatus();
    } catch (e) {
      debugPrint('[AuthProvider] ** init() error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Charge access/refresh token depuis le stockage vers le client API.
  /// Ne connecte pas le socket : AuthWrapper le fait après `ChatProvider.bind`.
  Future<bool> _hydrateTokensFromStorage() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();
    if (accessToken == null) return false;
    _apiClient.setToken(accessToken);
    if (refreshToken != null) {
      _apiClient.setRefreshToken(refreshToken);
    }
    // Miroir pour CallDeclineReceiver Android (refus app tuée).
    await PendingCallRejectStore.syncNativeCredentials(accessToken);
    return true;
  }

  Future<void> _checkAuthStatus() async {
    try {
      if (!await _hydrateTokensFromStorage()) return;

      try {
        final userData = await _apiClient.getMe();
        _currentUser = User.fromJson(userData);
        await _storage.saveUser(_currentUser!);
      } on TalkyException catch (e) {
        // Offline ou erreur transitoire : on garde le user caché.
        // 401/403 après échec refresh = session réellement expirée.
        if (e.statusCode == 401 || e.statusCode == 403) {
          debugPrint('[AuthProvider] session invalid (${e.statusCode}): ${e.message}');
          try {
            await _storage.clearAll();
          } catch (e2, st) {
            AppLog.w('AuthProvider', 'clearAll après session expirée échoué', e2, st);
          }
          _apiClient.logout();
          _currentUser = null;
        } else {
          debugPrint('[AuthProvider] getMe offline, on garde le cache: ${e.message}');
        }
      }
      // Pas de connectSocket ici : les listeners chat doivent être bindés
      // avant, sinon `message:received` / `auth:verified` sont perdus.
    } catch (e) {
      debugPrint('[AuthProvider] ** _checkAuthStatus error: $e');
      // Erreur inattendue (storage, etc.) — ne pas effacer la session.
    } finally {
      notifyListeners();
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
        alanyaPhone: AlanyaPhoneFormatter.normalize(alanyaPhone),
        password: password,
      );

      await _storage.saveTokens(
        accessToken: _apiClient.accessToken!,
        refreshToken: _apiClient.currentRefreshToken!,
      );

      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      // Socket après ChatProvider.bind (AuthWrapper._syncSessionBindings).
    } on TalkyException catch (e) {
      _error = e.message;
      debugPrint('[AuthProvider] Login TalkyException: ${e.message} (Status: ${e.statusCode})');
    } catch (e) {
      _error = LocaleController.instance.l10n.anErrorOccurred('$e');
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
    required int idPays,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiClient.register(
        email: email,
        password: password,
        nom: nom,
        pseudo: pseudo,
        idPays: idPays,
      );

      await _storage.saveTokens(
        accessToken: _apiClient.accessToken!,
        refreshToken: _apiClient.currentRefreshToken!,
      );

      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      // Socket après ChatProvider.bind (AuthWrapper._syncSessionBindings).
    } on TalkyException catch (e) {
      _error = e.message;
      debugPrint('[AuthProvider] Register TalkyException: ${e.message} (Status: ${e.statusCode})');
    } catch (e) {
      _error = LocaleController.instance.l10n.anErrorOccurred('$e');
      debugPrint('[AuthProvider] Register Exception: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Upload une nouvelle photo de profil puis rafraîchit le user.
  /// Retourne l'URL servie par le backend. Lève en cas d'échec.
  Future<String> updateAvatar(File file) async {
    final res = await _apiClient.uploadImage(file);
    final url = (res['url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      throw TalkyException(LocaleController.instance.l10n.invalidUploadResponse, 0);
    }
    // L'upload ne fait qu'héberger l'image : on doit définir explicitement
    // l'avatar de l'utilisateur connecté (sinon aucune photo n'est appliquée).
    await _apiClient.updateMe(avatarUrl: url);
    await refreshProfile();
    return url;
  }

  /// Met à jour le pays de l'utilisateur connecté.
  Future<void> updateCountry(int idPays) async {
    await _apiClient.updateMe(idPays: idPays);
    await refreshProfile();
  }

  /// Met à jour le nom et/ou le pseudo de l'utilisateur connecté.
  Future<void> updateProfile({String? nom, String? pseudo}) async {
    await _apiClient.updateMe(nom: nom, pseudo: pseudo);
    await refreshProfile();
  }

  /// Supprime la photo de profil (remet la valeur sentinelle backend).
  Future<void> removeAvatar() async {
    await _apiClient.updateMe(avatarUrl: 'NON DEFINI');
    await refreshProfile();
  }

  /// Rafraîchit le profil depuis le réseau et persiste en cache.
  /// En cas d'erreur transitoire, conserve le user en mémoire.
  Future<void> refreshProfile() async {
    try {
      final data = await _apiClient.getMe();
      _currentUser = User.fromJson(data);
      await _storage.saveUser(_currentUser!);
      notifyListeners();
    } on TalkyException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) rethrow;
      debugPrint('[AuthProvider] refreshProfile offline, on garde le cache: ${e.message}');
    } catch (e) {
      debugPrint('[AuthProvider] refreshProfile error: $e');
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
