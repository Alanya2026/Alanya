import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/services/connectivity_service.dart';
import '../core/utils/app_log.dart';
import '../talky_api_client.dart';

/// État de connectivité combiné : "online" = OS réseau disponible.
/// Le socket peut être en cours de reconnexion sans que l'utilisateur soit
/// considéré comme offline (réseau OS = ground truth).
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service;
  final TalkyApiClient _api;

  bool _hasNetwork = true;
  StreamSubscription<bool>? _sub;

  /// Callbacks externes notifiés (à part de notifyListeners) quand on passe
  /// de false → true. Utile pour déclencher un flushOutbox côté chat.
  final List<VoidCallback> _onBackOnline = [];

  ConnectivityProvider({
    required TalkyApiClient api,
    ConnectivityService? service,
  })  : _api = api,
        _service = service ?? ConnectivityService() {
    _init();
  }

  bool get isOnline => _hasNetwork;
  bool get isSocketConnected => _api.isSocketConnected;

  /// Vrai online "fort" : réseau OS + socket connecté.
  bool get isFullyConnected => _hasNetwork && _api.isSocketConnected;

  Future<void> _init() async {
    try {
      _hasNetwork = await _service.currentNetwork;
      notifyListeners();
    } catch (e, st) {
      AppLog.w('Connectivity', 'Lecture état réseau initial échouée', e, st);
    }
    _sub = _service.hasNetwork.listen((v) {
      final wasOnline = _hasNetwork;
      _hasNetwork = v;
      notifyListeners();
      if (!wasOnline && v) {
        for (final cb in List<VoidCallback>.from(_onBackOnline)) {
          try {
            cb();
          } catch (e) {
            debugPrint('[ConnectivityProvider] onBackOnline callback failed: $e');
          }
        }
      }
    });
  }

  void addBackOnlineListener(VoidCallback cb) => _onBackOnline.add(cb);
  void removeBackOnlineListener(VoidCallback cb) => _onBackOnline.remove(cb);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
