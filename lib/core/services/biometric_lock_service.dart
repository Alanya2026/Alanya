import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verrou biométrique local (empreinte / visage) pour protéger l'accès à l'app.
class BiometricLockService extends ChangeNotifier {
  static const _enabledKey = 'biometric_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _enabled = false;
  bool _deviceSupported = false;
  bool _canCheck = false;
  bool _isAuthenticating = false;
  List<BiometricType> _available = const [];
  Future<void>? _loadFuture;

  bool get isEnabled => _enabled;
  bool get deviceSupported => _deviceSupported;
  bool get canCheckBiometrics => _canCheck;
  bool get isAuthenticating => _isAuthenticating;
  List<BiometricType> get availableBiometrics => _available;

  /// Matériel biométrique présent et au moins une empreinte / visage enregistré(e).
  bool get hasBiometricHardware =>
      _deviceSupported && (_canCheck || _available.isNotEmpty);

  /// Attend la fin du chargement SharedPreferences (évite la course au cold start).
  Future<void> ensureLoaded() {
    _loadFuture ??= load();
    return _loadFuture!;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    await refreshAvailability();
    notifyListeners();
  }

  Future<void> refreshAvailability() async {
    try {
      _deviceSupported = await _auth.isDeviceSupported();
      _canCheck = await _auth.canCheckBiometrics;
      _available = await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('[BiometricLockService] disponibilité: $e');
      _deviceSupported = false;
      _canCheck = false;
      _available = const [];
    }
    notifyListeners();
  }

  /// Demande biométrique si le verrou est actif (cold start / resume).
  Future<bool> authenticate({
    String reason = 'Déverrouillez Alanya',
    bool biometricOnly = true,
  }) async {
    if (!_enabled) return true;
    return _promptBiometric(reason: reason, biometricOnly: biometricOnly);
  }

  Future<bool> _promptBiometric({
    required String reason,
    bool biometricOnly = true,
  }) async {
    _isAuthenticating = true;
    notifyListeners();
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: biometricOnly,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[BiometricLockService] auth échouée: $e');
      return false;
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> setEnabled(
    bool enabled, {
    String confirmationReason = 'Confirmez pour activer le verrou biométrique',
  }) async {
    if (enabled) {
      await refreshAvailability();
      if (!hasBiometricHardware) {
        throw StateError('Biométrie indisponible sur cet appareil');
      }
      // Toujours afficher le prompt à l'activation, même si _enabled est encore false.
      final ok = await _promptBiometric(
        reason: confirmationReason,
        biometricOnly: false,
      );
      if (!ok) {
        throw StateError('Authentification biométrique refusée');
      }
    }

    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    notifyListeners();
  }

  Future<void> clear() async {
    _enabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    notifyListeners();
  }
}
