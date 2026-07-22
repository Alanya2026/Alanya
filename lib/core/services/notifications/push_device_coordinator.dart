import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../../../talky_api_client.dart';

/// Synchronise l'état push de l'appareil avec le backend (throttle).
class PushDeviceCoordinator {
  PushDeviceCoordinator(this._api);

  final TalkyApiClient _api;

  Timer? _stateDebounce;
  String? _lastAppState;
  int? _lastActiveConversationId;
  DateTime? _lastStateSentAt;

  static const _minStateInterval = Duration(seconds: 15);

  String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  Future<void> registerToken(String fcmToken) async {
    try {
      await _api.registerPushDevice(
        fcmToken: fcmToken,
        platform: _platform,
      );
    } catch (e) {
      debugPrint('[PushDevice] registerToken failed: $e');
    }
  }

  void scheduleStateUpdate({
    required bool appInForeground,
    int? activeConversationId,
  }) {
    _stateDebounce?.cancel();
    _stateDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(
        syncState(
          appInForeground: appInForeground,
          activeConversationId: activeConversationId,
        ),
      );
    });
  }

  Future<void> syncState({
    required bool appInForeground,
    int? activeConversationId,
  }) async {
    final appState = appInForeground ? 'foreground' : 'background';
    if (_lastAppState == appState &&
        _lastActiveConversationId == activeConversationId &&
        _lastStateSentAt != null &&
        DateTime.now().difference(_lastStateSentAt!) < _minStateInterval) {
      return;
    }

    try {
      await _api.updatePushDeviceState(
        appState: appState,
        activeConversationId: activeConversationId,
      );
      _lastAppState = appState;
      _lastActiveConversationId = activeConversationId;
      _lastStateSentAt = DateTime.now();
    } catch (e) {
      debugPrint('[PushDevice] syncState failed: $e');
    }
  }

  Future<void> onLogout() async {
    try {
      await _api.deletePushDevice();
    } catch (e) {
      debugPrint('[PushDevice] delete on logout failed: $e');
    }
  }

  void dispose() {
    _stateDebounce?.cancel();
  }
}
