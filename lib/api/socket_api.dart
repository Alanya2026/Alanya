// Connexion et gestion des events Socket.IO (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension SocketApi on TalkyApiClient {
  static const Duration _socketReadyPollInterval = Duration(milliseconds: 100);
  static const int _socketReadyMaxPolls = 50;
  static const Duration _disconnectReconnectDebounce = Duration(seconds: 2);
  static const Duration _healthCheckStaleGrace = Duration(seconds: 15);
  static const Duration _healthCheckInterval = Duration(seconds: 30);

  DateTime? get lastEventReceivedAt => _lastEventReceivedAt;

  /// Événements d'authentification du compte remontés à l'UI. Statiques faute
  /// de pouvoir déclarer un champ d'instance depuis une extension ; l'app
  /// n'instancie qu'un seul [TalkyApiClient] (main.dart). Diffusion, car
  /// plusieurs écrans peuvent écouter, et jamais fermés : leur durée de vie est
  /// celle du processus, un logout ne doit pas les condamner.
  static final StreamController<AccountDeviceLogin> _accountLoginsController =
      StreamController<AccountDeviceLogin>.broadcast();
  static final StreamController<void> _deviceRevokedController =
      StreamController<void>.broadcast();
  static final StreamController<QrContactScan> _qrContactScansController =
      StreamController<QrContactScan>.broadcast();

  /// Scan arrivé avant qu'AuthWrapper ne soit abonné (tap sur une notification
  /// à froid) : le flux broadcast n'a pas de mémoire, on garde le dernier.
  static QrContactScan? _pendingQrScan;

  /// Une session vient de s'ouvrir ailleurs sur le compte (mot de passe,
  /// inscription ou QR). Purement informatif : de quoi afficher un bandeau.
  Stream<AccountDeviceLogin> get accountLogins =>
      SocketApi._accountLoginsController.stream;

  /// CET appareil vient d'être déconnecté depuis un autre appareil du compte.
  ///
  /// Seuls les tokens EN MÉMOIRE sont effacés à l'émission ; le stockage
  /// sécurisé, lui, contient encore le refresh token. C'est
  /// `AuthProvider.handleRemoteRevocation()`, branché sur ce flux dans
  /// `AuthWrapper`, qui termine la déconnexion et vide le stockage.
  Stream<void> get thisDeviceRevoked =>
      SocketApi._deviceRevokedController.stream;

  /// Mon code contact éphémère vient d'être scanné : le jeton est à usage
  /// unique, l'écran « Mon code » régénère à la réception, et AuthWrapper
  /// propose d'ajouter le scanneur en retour (dialogue oui/non).
  Stream<QrContactScan> get qrContactScans =>
      SocketApi._qrContactScansController.stream;

  /// Fait entrer un scan dans le flux, d'où qu'il vienne — événement socket ou
  /// tap sur la notification push (app fermée au moment du scan, l'événement
  /// socket est perdu ; la push transporte l'identité et la rejoue ici).
  void injectQrContactScan(QrContactScan scan) {
    if (scan.alanyaID == 0) return;
    if (SocketApi._qrContactScansController.hasListener) {
      SocketApi._qrContactScansController.add(scan);
    } else {
      SocketApi._pendingQrScan = scan;
    }
  }

  /// Scan mis en attente faute d'abonné — se lit une seule fois, après que
  /// AuthWrapper s'est abonné (démarrage à froid via notification).
  QrContactScan? consumePendingQrContactScan() {
    final scan = SocketApi._pendingQrScan;
    SocketApi._pendingQrScan = null;
    return scan;
  }

  void setPendingMessagesCallback(Future<bool> Function() callback) {
    _pendingMessagesCallback = callback;
    if (_accessToken != null) _startConditionalHealthCheck();
  }

  /// Détermine la présence annoncée à chaque `auth:verified`.
  ///
  /// Sans ce callback, toute (re)connexion socket déclarerait l'utilisateur en
  /// ligne — y compris quand l'app se reconnecte en arrière-plan, réveillée par
  /// une push. Passer `null` restaure ce comportement historique.
  void setPresenceOnlineCallback(bool Function()? callback) {
    _presenceOnlineCallback = callback;
  }

  /// Déclare la présence courante au serveur. Sans effet si le socket n'est pas
  /// prêt : l'état sera réémis au prochain `auth:verified`.
  void sendPresence({required bool online}) {
    sendSocketEvent(
      online ? SocketEvents.presenceOnline : SocketEvents.presenceOffline,
      const <String, dynamic>{},
    );
  }

  void _recordEvent() {
    _lastEventReceivedAt = DateTime.now();
  }

  void _stopConditionalHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  void _startConditionalHealthCheck() {
    _stopConditionalHealthCheck();
    if (_accessToken == null) return;
    _healthCheckTimer = Timer.periodic(SocketApi._healthCheckInterval, (_) async {
      final hasPending = await _pendingMessagesCallback?.call() ?? false;
      if (!hasPending) return;

      if (!isSocketReady) {
        debugPrint('[Socket] Health check → reconnect (socket non prêt, outbox pending)');
        _teardownSocketInstance();
        connectSocket();
        return;
      }

      final lastEvent = _lastEventReceivedAt;
      final noRecent = lastEvent == null ||
          DateTime.now().difference(lastEvent) >
              SocketApi._healthCheckInterval + _healthCheckStaleGrace;

      if (noRecent) {
        debugPrint('[Socket] Health check → reconnect (aucun event récent, outbox pending)');
        _teardownSocketInstance();
        connectSocket();
      }
    });
  }

  void _cancelSocketReconnectWatchdog() {
    _socketReconnectWatchdog?.cancel();
    _socketReconnectWatchdog = null;
  }

  void _scheduleSocketReconnectWatchdog() {
    if (_accessToken == null) return;
    _cancelSocketReconnectWatchdog();
    _socketReconnectWatchdog = Timer(_disconnectReconnectDebounce, () {
      _socketReconnectWatchdog = null;
      if (_accessToken == null || isSocketReady) return;
      debugPrint('[Socket] Watchdog → ensureSocketReady après disconnect');
      unawaited(ensureSocketReady());
    });
  }

  /// Détruit l'instance socket sans vider les listeners externes.
  void _teardownSocketInstance() {
    _cancelSocketReconnectWatchdog();
    _stopConditionalHealthCheck();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isSocketAuthVerified = false;
  }

  void connectSocket() {
    if (_accessToken == null) return;
    if (_socket != null) {
      // Une socket peut être en cours de handshake : `connected` est encore
      // false jusqu'à `auth:verified`. Ne pas la détruire lorsqu'un second
      // appel arrive pendant ce court intervalle (notamment accept CallKit au
      // cold start puis bind des providers), sinon le signaling entrant est
      // retardé par un nouveau handshake. Les sockets réellement mortes sont
      // déjà recréées explicitement par ensureSocketReady/forceReconnect.
      return;
    }

    _socket = io.io(TalkyApiClient.socketUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionDelay': 2000,
      'reconnectionDelayMax': 30000,
      'reconnectionAttempts': 999999,
    });

    _socket!.onConnect((_) {
      _recordEvent();
      unawaited(_emitSocketAuthLogin());
    });

    _socket!.on(SocketEvents.authVerified, (data) {
      _recordEvent();
      debugPrint('[Socket] Authentifié: ${data['alanyaID']}');
      _isSocketAuthVerified = true;
      _cancelSocketReconnectWatchdog();
      // Avant tout listener externe : une answer retenue pendant la ré-auth
      // doit repartir au plus tôt, l'appelant étant en attente.
      _flushPendingSocketEmits();
      final external = _socketListeners[SocketEvents.authVerified];
      if (external == null || external.isEmpty) {
        debugPrint('[Socket] ⚠ auth:verified sans listeners externes enregistrés');
      }
      // Déclarer la présence réelle : « en ligne » seulement si l'app est au
      // premier plan (ou en appel). Le serveur ignore désormais le userID du
      // payload et s'appuie sur le JWT du socket.
      final online = _presenceOnlineCallback?.call() ?? true;
      _socket!.emit(
        online ? SocketEvents.presenceOnline : SocketEvents.presenceOffline,
        const <String, dynamic>{},
      );
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

    // Émis à chaque nouvelle connexion du compte, sur tous les autres appareils.
    _socket!.on(SocketEvents.authConflict, (data) {
      _recordEvent();
      final login = AccountDeviceLogin.fromEvent(data);
      debugPrint(
        '[Socket] Nouvelle connexion sur le compte: '
        '${login.deviceName ?? '?'} (${login.loginMethod ?? '?'})',
      );
      SocketApi._accountLoginsController.add(login);
    });

    _socket!.on(SocketEvents.authDeviceRevoked, (data) {
      _recordEvent();
      unawaited(_handleDeviceRevoked(data));
    });

    _socket!.on(SocketEvents.qrContactScanned, (data) {
      _recordEvent();
      if (data is! Map) return;
      final scan = QrContactScan.fromJson(Map<String, dynamic>.from(data));
      debugPrint('[Socket] Code QR scanné par ${scan.displayName}');
      injectQrContactScan(scan);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] Déconnecté');
      _isSocketAuthVerified = false;
      _scheduleSocketReconnectWatchdog();
    });
    _socket!.onError((err) => debugPrint('[Socket] Erreur: $err'));
    _socket!.onReconnect((_) {
      debugPrint('[Socket] Reconnecté — ré-auth');
      _isSocketAuthVerified = false;
      unawaited(_emitSocketAuthLogin());
    });

    // Ré-attache au socket fraîchement créé les listeners externes déjà
    // enregistrés via `onSocketEvent` (utile après un logout/login : les modules
    // clients gardent leurs callbacks via _socketListeners, mais le _socket a
    // été détruit puis recréé).
    _socketListeners.forEach((event, callbacks) {
      for (final cb in callbacks) {
        final wrapped = _socketCallbackWrappers[cb];
        _socket!.on(event, wrapped ?? cb);
      }
    });

    _socket!.connect();
    _startConditionalHealthCheck();
  }

  Future<bool> _waitUntilSocketReady() async {
    if (isSocketReady) return true;
    for (var i = 0; i < _socketReadyMaxPolls; i++) {
      if (isSocketReady) return true;
      await Future<void>.delayed(_socketReadyPollInterval);
    }
    return isSocketReady;
  }

  /// Connecte / recrée le socket si besoin et attend `auth:verified` (court délai).
  Future<bool> ensureSocketReady() async {
    if (_accessToken == null) return false;
    if (isSocketReady) return true;

    if (_socket != null && !isSocketConnected) {
      debugPrint('[Socket] Instance morte → recreate');
      _teardownSocketInstance();
    }

    if (!isSocketConnected) {
      connectSocket();
    }

    final ready = await _waitUntilSocketReady();
    if (!ready) {
      debugPrint(
        '[Socket] ensureSocketReady échoué '
        '(connected=$isSocketConnected, auth=$_isSocketAuthVerified)',
      );
    }
    return ready;
  }

  /// Teardown + reconnect même si [isSocketReady] est true (socket zombie TCP).
  /// Un seul appel concurrent à la fois.
  Future<bool> forceReconnect() {
    if (_accessToken == null) return Future.value(false);
    return _forceReconnectInFlight ??= () async {
      try {
        debugPrint('[Socket] forceReconnect → teardown + connect');
        _teardownSocketInstance();
        connectSocket();
        final ready = await _waitUntilSocketReady();
        if (!ready) {
          debugPrint(
            '[Socket] forceReconnect échoué '
            '(connected=$isSocketConnected, auth=$_isSocketAuthVerified)',
          );
        }
        return ready;
      } finally {
        _forceReconnectInFlight = null;
      }
    }();
  }

  /// La révocation est diffusée à TOUT le compte : seul l'appareil dont
  /// l'identifiant matériel correspond doit se déconnecter, les autres ignorent.
  /// Le `logout()` local n'intervient qu'après l'`await` — détruire le socket
  /// depuis l'intérieur d'un de ses propres handlers n'est pas sûr.
  Future<void> _handleDeviceRevoked(dynamic data) async {
    final revokedDeviceId =
        (data is Map ? data['deviceId']?.toString().trim() : null) ?? '';
    // 'INDEFINI' est le repli quand l'identifiant matériel est indisponible :
    // deux appareils le partageraient et se déconnecteraient l'un l'autre.
    if (revokedDeviceId.isEmpty || revokedDeviceId == 'INDEFINI') return;

    if (revokedDeviceId != await TalkyApiClient.currentHardwareId()) return;

    debugPrint('[Socket] Appareil révoqué à distance → session locale invalidée');
    logout();
    SocketApi._deviceRevokedController.add(null);
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
      unawaited(_emitSocketAuthLogin());
    }
  }

  Future<void> _emitSocketAuthLogin() async {
    if (_socket == null || _accessToken == null) return;
    debugPrint('[Socket] Connecté — envoi auth:login');
    final deviceId = await ensureStableDeviceId();
    _socket!.emit(SocketEvents.authLogin, {
      'token': _accessToken,
      'deviceId': deviceId,
    });
  }

  void disconnectSocket() {
    _cancelSocketReconnectWatchdog();
    _stopConditionalHealthCheck();
    _isSocketAuthVerified = false;
    _pendingMessagesCallback = null;
    // Déconnexion explicite (logout / changement de compte) : la signalisation
    // retenue n'a plus de destinataire valide, elle ne doit pas survivre.
    _pendingSocketEmits.clear();
    _socketCallbackWrappers.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _socketListeners.clear();
  }

  /// Événements de signalisation d'appel rejoués après ré-authentification.
  /// Volontairement restreint : rejouer tout le trafic socket remettrait en vol
  /// des accusés de lecture ou des indicateurs de frappe périmés. Une
  /// signalisation d'appel, elle, est soit encore utile quelques secondes, soit
  /// écartée par les garde-fous de génération / callId côté récepteur.
  static const Set<String> _replayableSocketEvents = {
    SocketEvents.callUser,
    SocketEvents.answerCall,
    SocketEvents.iceCandidate,
    SocketEvents.groupOffer,
    SocketEvents.groupAnswer,
    SocketEvents.groupIceCandidate,
    SocketEvents.meetingOffer,
    SocketEvents.meetingAnswer,
    SocketEvents.meetingIceCandidate,
  };

  static const int _maxPendingSocketEmits = 96;

  /// Au-delà, l'appel a de toute façon échoué côté appelant (timeout no-answer) :
  /// rejouer une answer périmée ressusciterait un appel déjà soldé.
  static const Duration _pendingSocketEmitTtl = Duration(seconds: 20);

  void sendSocketEvent(String event, dynamic data) {
    if (!isSocketReady) {
      if (_replayableSocketEvents.contains(event)) {
        if (_pendingSocketEmits.length >= _maxPendingSocketEmits) {
          _pendingSocketEmits.removeAt(0);
        }
        _pendingSocketEmits.add({
          'event': event,
          'data': data,
          'at': DateTime.now(),
        });
        debugPrint(
          '[Socket] 📥 emit "$event" mis en file pour rejeu '
          '(${_pendingSocketEmits.length} en attente — connected=$isSocketConnected, auth=$_isSocketAuthVerified)',
        );
        return;
      }
      debugPrint('[Socket] ** emit "$event" abandonné (socket non prêt — connected=$isSocketConnected, auth=$_isSocketAuthVerified)');
      return;
    }
    _socket!.emit(event, data);
  }

  /// Rejoue les émissions de signalisation retenues, dans l'ordre d'origine.
  /// Appelé dès que `auth:verified` repasse le socket en état prêt.
  void _flushPendingSocketEmits() {
    if (_pendingSocketEmits.isEmpty) return;
    final queued = List<Map<String, dynamic>>.from(_pendingSocketEmits);
    _pendingSocketEmits.clear();
    final now = DateTime.now();
    var sent = 0;
    var expired = 0;
    for (final item in queued) {
      final at = item['at'] as DateTime;
      if (now.difference(at) > _pendingSocketEmitTtl) {
        expired++;
        continue;
      }
      if (!isSocketReady) {
        // Le socket est retombé pendant le rejeu : on remet le reste en file.
        _pendingSocketEmits.add(item);
        continue;
      }
      _socket!.emit(item['event'] as String, item['data']);
      sent++;
    }
    debugPrint(
      '[Socket] 📤 rejeu signalisation: $sent envoyé(s), $expired périmé(s), '
      '${_pendingSocketEmits.length} restant(s)',
    );
  }

  void onSocketEvent(String event, void Function(dynamic) callback) {
    // Registre pour ré-attacher au prochain `connectSocket()` (cas logout/login
    // où `_socket` est recréé). socket.io conserve ses listeners au travers des
    // reconnexions auto donc on n'a pas besoin de re-binder à chaque fois.
    final listeners = _socketListeners.putIfAbsent(event, () => []);
    if (listeners.contains(callback)) return;

    void wrapped(dynamic data) {
      _recordEvent();
      callback(data);
    }
    _socketCallbackWrappers[callback] = wrapped;

    listeners.add(callback);
    debugPrint('[Socket] 📌 Listener enregistré pour "$event"');

    // Attache directement au socket s'il existe : `.on` accepte avant connect
    // et la livraison se déclenche dès qu'un event arrive (post auth:verified).
    _socket?.on(event, wrapped);

    // Si auth:verified est déjà passé (connectSocket avant bind, appel, etc.),
    // rejouer le catch-up pour ce listener — sinon flush/resync ne tournent
    // qu'au prochain reconnect.
    if (event == SocketEvents.authVerified && isSocketReady) {
      debugPrint('[Socket] Replay auth:verified pour listener tardif');
      scheduleMicrotask(() {
        try {
          callback({'replay': true});
        } catch (e) {
          debugPrint('[Socket] Replay auth:verified échoué: $e');
        }
      });
    }
  }

  void offSocketEvent(String event) {
    _socketListeners.remove(event);
    _socket?.off(event);
  }

  /// Retire un callback précis pour un event donné, sans détruire les autres
  /// listeners du même event. Utilisé par les écrans (chat_detail) qui ne
  /// doivent pas évincer les listeners globaux (chat_repository, etc.) en se
  /// fermant.
  void removeSocketListener(String event, void Function(dynamic) callback) {
    final list = _socketListeners[event];
    if (list != null) {
      list.remove(callback);
      if (list.isEmpty) _socketListeners.remove(event);
    }
    final wrapped = _socketCallbackWrappers.remove(callback);
    _socket?.off(event, wrapped ?? callback);
  }
}

/// Connexion d'un appareil au compte, telle qu'annoncée aux AUTRES appareils
/// par `auth:conflict`. Aucun champ n'est garanti : le backend renvoie
/// 'INDEFINI' quand l'appareil n'a pas su se nommer.
class AccountDeviceLogin {
  final String? deviceName;
  final String? platform;

  /// 'password' | 'register' | 'qr'
  final String? loginMethod;
  final DateTime? at;

  const AccountDeviceLogin({
    this.deviceName,
    this.platform,
    this.loginMethod,
    this.at,
  });

  factory AccountDeviceLogin.fromEvent(dynamic data) {
    if (data is! Map) return const AccountDeviceLogin();
    return AccountDeviceLogin(
      deviceName: _renseigne(data['deviceName']),
      platform: _renseigne(data['platform']),
      loginMethod: _renseigne(data['loginMethod']),
      at: DateTime.tryParse(data['at']?.toString() ?? ''),
    );
  }

  /// 'INDEFINI' est une absence d'information, pas un libellé à afficher.
  static String? _renseigne(Object? value) {
    final texte = value?.toString().trim() ?? '';
    return texte.isEmpty || texte == 'INDEFINI' ? null : texte;
  }
}
