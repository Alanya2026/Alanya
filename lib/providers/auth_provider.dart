import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../core/services/storage_service.dart';
import '../core/services/session_end_reason.dart';
import '../core/services/call/pending_call_reject_store.dart';
import '../core/services/onboarding_service.dart';
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
  bool _pendingOnboardingAfterRegister = false;

  AuthProvider({TalkyApiClient? apiClient, StorageService? storage})
      : _apiClient = apiClient ?? TalkyApiClient(),
        _storage = storage ?? StorageService();

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get pendingOnboardingAfterRegister => _pendingOnboardingAfterRegister;

  void clearPendingOnboardingAfterRegister() {
    _pendingOnboardingAfterRegister = false;
  }

  bool get sessionExpired =>
      currentSessionEndReason == SessionEndReason.tokenExpired;

  /// Restaure le cache local puis libère l'UI. La validation réseau part
  /// ensuite en arrière-plan : évite splash → spinner → Home.
  Future<void> init() async {
    try {
      await _storage.init();
      _currentUser = await _storage.getUser();
      await _hydrateTokensFromStorage();

      // Décision purement locale : profil sans tokens → pas de Home fantôme.
      final hasAccess = _apiClient.accessToken != null;
      final hasRefresh = _apiClient.currentRefreshToken != null;
      if (!hasAccess && !hasRefresh && _currentUser != null) {
        debugPrint('[AuthProvider] profil en cache mais tokens absents');
        await _invalidateSession(reason: SessionEndReason.tokenExpired);
      }
    } catch (e, st) {
      debugPrint('[AuthProvider] ** init() error: $e');
      AppLog.w('AuthProvider', 'init() error', e, st);
    } finally {
      _isInitialized = true;
      notifyListeners();
    }

    // Refresh / getMe hors chemin critique : l'UI est déjà sur Home ou Login.
    unawaited(_validateSessionInBackground());
  }

  /// Valide / rafraîchit la session sans bloquer le premier frame.
  Future<void> _validateSessionInBackground() async {
    final hasAccess = _apiClient.accessToken != null;
    final hasRefresh = _apiClient.currentRefreshToken != null;
    if (!hasAccess && !hasRefresh) return;

    try {
      await _restoreSessionAtLaunch();
    } catch (e, st) {
      debugPrint('[AuthProvider] ** validateSession background error: $e');
      AppLog.w('AuthProvider', 'validateSession background error', e, st);
    } finally {
      // User mis à jour ou session invalidée → AuthWrapper rebind / Login.
      notifyListeners();
    }
  }

  /// Valide la session au cold start (réseau). Appelé hors chemin UI.
  Future<void> _restoreSessionAtLaunch() async {
    final hasAccess = _apiClient.accessToken != null;
    final hasRefresh = _apiClient.currentRefreshToken != null;
    debugPrint(
      '[AuthProvider] restore launch: cachedUser=${_currentUser != null} '
      'access=$hasAccess refresh=$hasRefresh',
    );

    if (!hasAccess && !hasRefresh) {
      if (_currentUser != null) {
        debugPrint('[AuthProvider] profil en cache mais tokens absents');
        await _invalidateSession(reason: SessionEndReason.tokenExpired);
      }
      return;
    }

    if (hasRefresh) {
      if (await _tryRecoverSessionFromStorage()) {
        debugPrint(
          '[AuthProvider] session restaurée (userID=${_currentUser?.alanyaID})',
        );
        return;
      }
      debugPrint('[AuthProvider] refresh au lancement échoué → login');
      await _invalidateSession(reason: SessionEndReason.tokenExpired);
      return;
    }

    try {
      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      currentSessionEndReason = SessionEndReason.none;
    } on TalkyException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        debugPrint('[AuthProvider] session invalid (${e.statusCode}): ${e.message}');
        await _invalidateSession(reason: SessionEndReason.tokenExpired);
      } else {
        debugPrint('[AuthProvider] getMe offline, cache conservé: ${e.message}');
      }
    }
  }

  /// Charge access/refresh token depuis le stockage vers le client API.
  /// Ne connecte pas le socket : AuthWrapper le fait après `ChatProvider.bind`.
  Future<bool> _hydrateTokensFromStorage() async {
    final accessToken = await _storage.getAccessToken();
    final refreshToken = await _storage.getRefreshToken();
    if (accessToken == null && refreshToken == null) return false;
    if (accessToken != null) {
      _apiClient.setToken(accessToken);
    }
    if (refreshToken != null) {
      _apiClient.setRefreshToken(refreshToken);
    }
    // Miroir pour CallDeclineReceiver Android (refus app tuée).
    if (accessToken != null) {
      await PendingCallRejectStore.syncNativeCredentials(
        accessToken,
        refreshToken: refreshToken,
      );
    }
    return true;
  }

  /// Tente de restaurer la session depuis le stockage (refresh + getMe).
  /// Retourne true si la session est valide ou récupérée.
  Future<bool> _tryRecoverSessionFromStorage() async {
    try {
      if (!await _hydrateTokensFromStorage()) return false;
      if (_apiClient.currentRefreshToken != null) {
        final refreshed = await _apiClient.refreshSessionFromStorage();
        if (!refreshed) return false;
      }
      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      currentSessionEndReason = SessionEndReason.none;
      if (_apiClient.accessToken != null) {
        await PendingCallRejectStore.syncNativeCredentials(
          _apiClient.accessToken!,
          refreshToken: _apiClient.currentRefreshToken,
        );
      }
      return true;
    } on TalkyException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) return false;
      debugPrint('[AuthProvider] recoverSession transitoire, on garde le cache: ${e.message}');
      return _currentUser != null;
    } catch (e, st) {
      AppLog.w('AuthProvider', 'recoverSession error', e, st);
      return _currentUser != null;
    }
  }

  Future<void> _invalidateSession({required SessionEndReason reason}) async {
    currentSessionEndReason = reason;
    _apiClient.logout();
    _currentUser = null;
    _pendingOnboardingAfterRegister = false;
  }

  /// Au retour au premier plan : réhydrate et valide sans déconnecter offline.
  Future<void> refreshSessionOnResume() async {
    if (_currentUser == null) {
      _currentUser = await _storage.getUser();
    }
    await _hydrateTokensFromStorage();
    if (_currentUser == null &&
        _apiClient.accessToken == null &&
        _apiClient.currentRefreshToken == null) {
      return;
    }

    if (_apiClient.currentRefreshToken != null) {
      if (await _tryRecoverSessionFromStorage()) {
        notifyListeners();
        return;
      }
    }

    try {
      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      currentSessionEndReason = SessionEndReason.none;
      notifyListeners();
    } on TalkyException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        if (await _tryRecoverSessionFromStorage()) {
          notifyListeners();
          return;
        }
        debugPrint('[AuthProvider] session invalid au resume (${e.statusCode})');
        await _invalidateSession(reason: SessionEndReason.tokenExpired);
        notifyListeners();
        return;
      }
      debugPrint('[AuthProvider] refreshSessionOnResume offline: ${e.message}');
    } catch (e, st) {
      AppLog.w('AuthProvider', 'refreshSessionOnResume error', e, st);
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
        // `device_ID` reste l'UUID applicatif : c'est lui que le socket et le
        // registre push annoncent, et la déduplication push legacy les compare.
        // L'identifiant matériel part à part, pour la seule table `appareils`.
        deviceId: await _apiClient.ensureStableDeviceId(),
        hardwareId: await TalkyApiClient.currentHardwareId(),
      );

      await _storage.saveTokens(
        accessToken: _apiClient.accessToken!,
        refreshToken: _apiClient.currentRefreshToken!,
      );

      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      currentSessionEndReason = SessionEndReason.none;
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

  /// Finalise une session à partir de tokens déjà émis par le backend : la
  /// connexion par QR est autorisée depuis un autre appareil, il n'y a donc
  /// aucune requête de login à jouer ici, seulement la fin de [login].
  Future<void> loginWithQrTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _apiClient.setToken(accessToken);
      _apiClient.setRefreshToken(refreshToken);

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      final userData = await _apiClient.getMe();
      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      currentSessionEndReason = SessionEndReason.none;
      // Socket après ChatProvider.bind (AuthWrapper._syncSessionBindings).
    } on TalkyException catch (e) {
      _error = e.message;
      debugPrint('[AuthProvider] LoginQr TalkyException: ${e.message} (Status: ${e.statusCode})');
    } catch (e) {
      _error = LocaleController.instance.l10n.anErrorOccurred('$e');
      debugPrint('[AuthProvider] LoginQr Exception: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register({
    required String password,
    required String nom,
    required String pseudo,
    String? email,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final regData = await _apiClient.register(
        password: password,
        nom: nom,
        pseudo: pseudo,
        email: email,
        deviceId: await _apiClient.ensureStableDeviceId(),
        hardwareId: await TalkyApiClient.currentHardwareId(),
      );

      // Le code de récupération n'existe que dans CETTE réponse : ni getMe ni
      // aucun autre endpoint ne le renvoie sans le mot de passe. On le capte
      // avant tout appel susceptible d'échouer, sinon l'écran identifiants
      // n'aurait plus rien à afficher.
      final code = regData['recoveryCode']?.toString();
      OnboardingService.pendingRecoveryCode =
          (code != null && code.isNotEmpty) ? code : null;

      await _storage.saveTokens(
        accessToken: _apiClient.accessToken!,
        refreshToken: _apiClient.currentRefreshToken!,
      );

      Map<String, dynamic> userData;
      try {
        userData = await _apiClient.getMe();
      } catch (e) {
        debugPrint('[AuthProvider] getMe post-register échoué, fallback réponse register: $e');
        final raw = regData['user'];
        if (raw is! Map) rethrow;
        userData = Map<String, dynamic>.from(raw);
      }

      _currentUser = User.fromJson(userData);
      await _storage.saveUser(_currentUser!);
      _pendingOnboardingAfterRegister = true;
      // Drapeau persistant : survit à une fermeture de l'app en plein onboarding,
      // contrairement à `_pendingOnboardingAfterRegister` qui vit en mémoire.
      await OnboardingService().markStarted(_currentUser!.alanyaID);
      currentSessionEndReason = SessionEndReason.none;
      notifyListeners();
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

  /// Demande un OTP pour ajouter / remplacer l'email.
  Future<void> requestEmailChange(String email) async {
    await _apiClient.requestEmailChangeOtp(email);
  }

  /// Confirme l'OTP et rafraîchit le profil.
  Future<void> confirmEmailChange({
    required String email,
    required String otp,
  }) async {
    await _apiClient.confirmEmailChange(email: email, otp: otp);
    await refreshProfile();
  }

  /// Change le mot de passe (mot de passe actuel requis).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
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

  /// Met à jour le profil de l'utilisateur connecté.
  ///
  /// [genre] et [age] sont à écriture unique côté serveur : les renvoyer sur un
  /// compte qui les a déjà renseignés lève une [TalkyException] `409`.
  Future<void> updateProfile({
    String? nom,
    String? pseudo,
    String? bio,
    String? genre,
    int? age,
    int? idPays,
  }) async {
    await _apiClient.updateMe(
      nom: nom,
      pseudo: pseudo,
      bio: bio,
      genre: genre,
      age: age,
      idPays: idPays,
    );
    await refreshProfile();
  }

  /// Réaffiche le code de récupération (mot de passe requis).
  Future<String> revealRecoveryCode(String password) =>
      _apiClient.revealRecoveryCode(password);

  /// Valide un code de récupération et retourne le `resetToken` associé.
  /// Statique dans l'esprit : appelée hors session, avant toute connexion.
  Future<String> validateRecoveryCode({
    required String alanyaPhone,
    required String recoveryCode,
  }) async {
    final data = await _apiClient.validateRecoveryCode(
      alanyaPhone: alanyaPhone,
      recoveryCode: recoveryCode,
    );
    return data['resetToken']?.toString() ?? '';
  }

  /// Met à jour la bio de l'utilisateur connecté.
  Future<void> updateBio(String bio) async {
    await _apiClient.updateMe(bio: bio.trim());
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
    currentSessionEndReason = SessionEndReason.explicitLogout;
    _apiClient.logout();
    await _storage.clearAll();
    _currentUser = null;
    _pendingOnboardingAfterRegister = false;
    notifyListeners();
  }

  /// Cet appareil vient d'être déconnecté depuis un autre appareil du compte.
  ///
  /// `TalkyApiClient.logout()` n'efface que les tokens EN MÉMOIRE : sans ce
  /// passage par le stockage, le refresh token persisté relancerait la session
  /// au prochain démarrage, et l'UI resterait sur l'écran d'accueil avec un
  /// compte qui répond « non authentifié » à chaque action.
  Future<void> handleRemoteRevocation() async {
    if (_currentUser == null && _apiClient.accessToken == null) return;
    debugPrint('[AuthProvider] appareil révoqué à distance → session locale effacée');
    currentSessionEndReason = SessionEndReason.revokedRemotely;
    _apiClient.logout();
    await _storage.clearAll();
    _currentUser = null;
    _pendingOnboardingAfterRegister = false;
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
