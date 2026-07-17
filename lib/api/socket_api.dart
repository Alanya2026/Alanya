// Connexion et gestion des events Socket.IO (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension SocketApi on TalkyApiClient {
  void connectSocket() {
    if (_accessToken == null) return;
    if (_socket?.connected == true) return;

    _socket = io.io(TalkyApiClient.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 2000,
      'reconnectionAttempts': 10,
    });

    _socket!.onConnect((_) {
      debugPrint('[Socket] Connecté — envoi auth:login');
      // !! AUTH SOCKET obligatoire — sinon tous les handlers ignorent les events
      _socket!.emit(SocketEvents.authLogin, {'token': _accessToken});
    });

    _socket!.on(SocketEvents.authVerified, (data) {
      debugPrint('[Socket] Authentifié: ${data['alanyaID']}');
      _isSocketAuthVerified = true;
      final external = _socketListeners[SocketEvents.authVerified];
      if (external == null || external.isEmpty) {
        debugPrint('[Socket] ⚠ auth:verified sans listeners externes enregistrés');
      }
      // Signaler présence en ligne
      _socket!.emit(SocketEvents.presenceOnline, {'userID': data['alanyaID']});
    });

    _socket!.on(SocketEvents.authError, (data) {
      final code = data is Map ? data['code']?.toString() : null;
      debugPrint('[Socket] Erreur auth: ${data is Map ? data['message'] : data} (code=$code)');
      _isSocketAuthVerified = false;
      // Token d'accès expiré : rafraîchir le JWT puis ré-émettre `auth:login`.
      // Sans ça, après une reconnexion avec un token périmé le socket reste
      // connecté mais NON authentifié → plus aucun `message:received` (temps
      // réel mort jusqu'à un appel HTTP qui rafraîchit le token par hasard).
      if (code == 'TOKEN_EXPIRED' && _refreshToken != null) {
        _refreshSocketAuth();
      }
    });

    _socket!.on(SocketEvents.authConflict, (data) {
      debugPrint('[Socket] Conflit connexion: ${data['message']}');
      _isSocketAuthVerified = false;
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Déconnecté');
      _isSocketAuthVerified = false;
    });
    _socket!.onError((err) => debugPrint('[Socket] Erreur: $err'));
    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnecté — ré-auth');
      _isSocketAuthVerified = false;
      _socket!.emit(SocketEvents.authLogin, {'token': _accessToken});
    });

    // Ré-attache au socket fraîchement créé les listeners externes déjà
    // enregistrés via `onSocketEvent` (utile après un logout/login : les modules
    // clients gardent leurs callbacks via _socketListeners, mais le _socket a
    // été détruit puis recréé).
    _socketListeners.forEach((event, callbacks) {
      for (final cb in callbacks) {
        _socket!.on(event, cb);
      }
    });

    _socket!.connect();
  }

  /// Rafraîchit le JWT (refresh token) suite à un `auth:error` TOKEN_EXPIRED,
  /// puis ré-authentifie le socket. `_refreshAccessToken` appelle déjà
  /// `reauthSocketIfConnected()` en cas de succès (ré-émet `auth:login`).
  Future<void> _refreshSocketAuth() async {
    if (_socketReauthInFlight) return;
    _socketReauthInFlight = true;
    try {
      await _refreshAccessToken();
    } catch (e) {
      debugPrint('[Socket] refresh auth (TOKEN_EXPIRED) échoué: $e');
    } finally {
      _socketReauthInFlight = false;
    }
  }

  /// Ré-authentifie le socket après renouvellement du token JWT.
  void reauthSocketIfConnected() {
    if (_socket?.connected == true && _accessToken != null) {
      debugPrint('[Socket] Re-auth après refresh token');
      _isSocketAuthVerified = false;
      _socket!.emit(SocketEvents.authLogin, {'token': _accessToken});
    }
  }

  void disconnectSocket() {
    _isSocketAuthVerified = false;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _socketListeners.clear();
  }

  void sendSocketEvent(String event, dynamic data) {
    if (!isSocketReady) {
      debugPrint('[Socket] ** emit "$event" différé (socket non prêt — connected=$isSocketConnected, auth=$_isSocketAuthVerified)');
      return;
    }
    _socket!.emit(event, data);
  }

  void onSocketEvent(String event, Function(dynamic) callback) {
    // Registre pour ré-attacher au prochain `connectSocket()` (cas logout/login
    // où `_socket` est recréé). socket.io conserve ses listeners au travers des
    // reconnexions auto donc on n'a pas besoin de re-binder à chaque fois.
    final listeners = _socketListeners.putIfAbsent(event, () => []);
    if (listeners.contains(callback)) return;
    listeners.add(callback);
    debugPrint('[Socket] 📌 Listener enregistré pour "$event"');

    // Attache directement au socket s'il existe : `.on` accepte avant connect
    // et la livraison se déclenche dès qu'un event arrive (post auth:verified).
    _socket?.on(event, callback);
  }

  void offSocketEvent(String event) {
    _socketListeners.remove(event);
    _socket?.off(event);
  }

  /// Retire un callback précis pour un event donné, sans détruire les autres
  /// listeners du même event. Utilisé par les écrans (chat_detail) qui ne
  /// doivent pas évincer les listeners globaux (chat_repository, etc.) en se
  /// fermant.
  void removeSocketListener(String event, Function(dynamic) callback) {
    final list = _socketListeners[event];
    if (list != null) {
      list.remove(callback);
      if (list.isEmpty) _socketListeners.remove(event);
    }
    _socket?.off(event, callback);
  }
}
