import 'package:connectivity_plus/connectivity_plus.dart';

/// Wrapper léger autour de connectivity_plus.
/// Considère "online" toute interface autre que `none`.
class ConnectivityService {
  final Connectivity _c = Connectivity();

  Stream<bool> get hasNetwork => _c.onConnectivityChanged.map(_anyConnected);

  Future<bool> get currentNetwork async {
    final r = await _c.checkConnectivity();
    return _anyConnected(r);
  }

  static bool _anyConnected(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
