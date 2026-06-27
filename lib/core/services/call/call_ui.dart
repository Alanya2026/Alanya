// Navigation et état UI minimisée pour les appels (part of call_service.dart).
part of '../call_service.dart';

extension CallUi on CallService {
  bool get isCallActive =>
      _status == CallStatus.connecting ||
      _status == CallStatus.connected ||
      _status == CallStatus.joining;

  bool get isCallUiMinimized => _isCallUiMinimized;

  bool get isCallUiRouteOpen => _isCallUiRouteOpen;

  bool get shouldShowCallBanner => isCallActive && _isCallUiMinimized;

  /// L'écran plein est affiché (push effectué).
  void markCallUiVisible() {
    _isCallUiRouteOpen = true;
    _isCallUiMinimized = false;
    notify();
  }

  /// L'utilisateur a quitté l'écran sans raccrocher → bannière.
  void markCallUiMinimized() {
    _isCallUiRouteOpen = false;
    _isCallUiMinimized = true;
    notify();
  }

  /// Route fermée (pop terminé).
  void markCallUiClosed() {
    _isCallUiRouteOpen = false;
    notify();
  }

  void _resetCallUiState() {
    _isCallUiMinimized = false;
    _isCallUiRouteOpen = false;
  }

  Future<void> showCallScreen() async {
    if (!isCallActive || _isCallUiRouteOpen) return;

    final navigator = appNavigator;
    if (navigator == null) return;

    await navigator.push(
      MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
    );

    markCallUiClosed();
    if (isCallActive && !_isCallUiMinimized) {
      markCallUiMinimized();
    }
  }

  /// Ouvre l'écran plein (depuis n'importe quel contexte, y compris la bannière).
  Future<void> navigateToCallUi([BuildContext? context]) async {
    if (context != null && !context.mounted) return;
    if (!isCallActive || _isCallUiRouteOpen) return;
    await showCallScreen();
  }
}
