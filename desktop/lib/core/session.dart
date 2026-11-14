import 'package:flutter/foundation.dart';

import 'desktop_api.dart';
import 'session_store.dart';

enum SessionPhase { starting, signedOut, signedIn }

/// Connecté ou non, et qui. Une session qui prend fin côté serveur
/// (ordinateur retiré depuis le téléphone) ramène à l'écran de connexion et
/// efface tout ce qui était gardé.
class Session extends ChangeNotifier {
  Session({required this.api, required this.store}) {
    api.onSessionEnded = () => signOut(remote: false);
  }

  final DesktopApi api;
  final SessionStore store;

  SessionPhase _phase = SessionPhase.starting;
  Map<String, dynamic> _user = const {};
  DateTime? _connectedAt;

  /// Vrai quand la dernière déconnexion venait du serveur (et non d'un clic).
  bool endedRemotely = false;

  SessionPhase get phase => _phase;
  Map<String, dynamic> get user => _user;
  DateTime? get connectedAt => _connectedAt;

  String get displayName {
    for (final k in ['pseudo', 'nom']) {
      final v = '${_user[k] ?? ''}'.trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String get phone => '${_user['alanyaPhone'] ?? ''}'.trim();

  Future<void> start() async {
    final s = await store.load();
    if (s == null) {
      _phase = SessionPhase.signedOut;
    } else {
      api.setTokens(access: s.access, refresh: s.refresh);
      _user = s.user;
      _connectedAt = await store.connectedAt();
      _phase = SessionPhase.signedIn;
    }
    notifyListeners();
  }

  Future<void> signIn(QrPoll approved) async {
    if (!approved.hasTokens) return;
    api.setTokens(access: approved.accessToken!, refresh: approved.refreshToken!);
    _user = approved.user ?? const {};
    await store.saveSession(access: approved.accessToken!, refresh: approved.refreshToken!, user: _user);
    _connectedAt = DateTime.now();
    endedRemotely = false;
    _phase = SessionPhase.signedIn;
    notifyListeners();
  }

  /// [remote] : prévenir le serveur (clic sur « Se déconnecter »). Faux quand
  /// c'est le serveur qui a mis fin à la session.
  /// Appelé avant d'effacer la session : le coffre ouvert arrête d'écrire
  /// (envois en cours) dans ce qui va être effacé.
  Future<void> Function()? beforeWipe;

  Future<void> signOut({bool remote = true}) async {
    if (_phase == SessionPhase.signedOut) return;
    if (remote) await api.logout();
    api.clearTokens();
    await beforeWipe?.call();
    await store.wipe();
    _user = const {};
    _connectedAt = null;
    endedRemotely = !remote;
    _phase = SessionPhase.signedOut;
    notifyListeners();
  }
}
