// Entrées d'appel entrant via push / CallKit (part of call_service.dart).
part of '../call_service.dart';

extension CallIncoming on CallService {
  Future<void> acceptIncomingCallFromPush({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
  }) async {
    debugPrint('[CallService] 📲 acceptIncomingCallFromPush callId=$callId caller=$callerId');

    if (!_apiClient.isSocketConnected) {
      _apiClient.connectSocket();
    }

    _remoteUserId = int.tryParse(callerId);
    _remoteUserName = callerName;
    _remoteUserPhoto = callerPhoto;
    _isVideo = isVideo;
    _currentCallId = callId.isNotEmpty ? callId : null;
    _autoAnswerOnNextIncoming = true;
    _autoAnswerCallerId = callerId;
    // Accepté depuis la notification/CallKit : on saute IncomingCallScreen et on
    // ouvre directement l'écran d'appel actif (voir HomeScreen + call_ui).
    _isAutoAnsweringFromPush = true;
    _status = CallStatus.incoming;
    notify();

    debugPrint('[CallService] !! Status = incoming, auto-answer armé (from push)');

    // Si l'offer est déjà arrivée, répondre immédiatement
    if (_pendingOffer != null) {
      debugPrint('[CallService] ⚡ Offer déjà présente → réponse immédiate');
      await answerCall();
    }
  }

  /// Prépare l'état d'appel entrant à partir d'un appel CallKit encore actif,
  /// SANS armer l'auto-réponse. Utilisé au démarrage à froid quand l'utilisateur
  /// a tapé le corps de la notif (pas le bouton « Accepter ») : on affiche l'écran
  /// d'appel entrant qui sonne et l'utilisateur décroche manuellement.
  void prepareIncomingFromCallKit({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
  }) {
    // Un appel est déjà en cours de traitement → ne pas écraser l'état.
    if (_status != CallStatus.idle) return;
    if (callId.startsWith('meeting_')) {
      debugPrint('[CallService] 🛡 ignore incoming CallKit meeting callId=$callId');
      return;
    }
    final isGroupCall = roomId != null && roomId.isNotEmpty;
    final parsedCallerId = int.tryParse(callerId);
    if (!isGroupCall && parsedCallerId == null) {
      debugPrint('[CallService] 🛡 ignore incoming CallKit invalide: callerId=$callerId');
      return;
    }
    if (callerName.trim().isEmpty && parsedCallerId == null) {
      debugPrint('[CallService] 🛡 ignore incoming CallKit sans identité exploitable');
      return;
    }
    debugPrint('[CallService] 📲 prepareIncomingFromCallKit callId=$callId caller=$callerId');

    _remoteUserId = parsedCallerId;
    _remoteUserName = callerName;
    _remoteUserPhoto = callerPhoto;
    _isVideo = isVideo;
    _currentCallId = callId.isNotEmpty ? callId : null;
    _groupRoomId = (roomId != null && roomId.isNotEmpty) ? roomId : null;
    _status = CallStatus.incoming;
    notify();
  }

  /// Appelée depuis main.dart quand l'utilisateur refuse un appel via CallKit.
  ///
  /// On coupe immédiatement CallKit + sonnerie, on mémorise le callId comme
  /// terminal (pour ignorer un éventuel rejeu `incoming_call`), puis on émet
  /// `reject_call`. Si le socket n'est pas encore prêt (cold start / app fermée),
  /// le refus est mis en file et rejoué à l'authentification du socket, ce qui
  /// évite d'ouvrir l'app inutilement tout en garantissant que l'appelant est
  /// bien averti.
  Future<void> rejectIncomingCallFromPush({
    required String callerId,
    String? callId,
  }) async {
    debugPrint('[CallService] 📲 rejectIncomingCallFromPush caller=$callerId callId=$callId');

    _markTerminalCallId(callId ?? _currentCallId);
    _autoAnswerOnNextIncoming = false;
    _autoAnswerCallerId = null;
    _isAutoAnsweringFromPush = false;

    await _ringtone.stop();
    await _callKit.endAll();

    final cid = int.tryParse(callerId);
    if (cid != null) {
      if (_apiClient.isSocketReady) {
        try {
          _apiClient.sendSocketEvent(SocketEvents.rejectCall, {'callerId': cid});
        } catch (e) {
          debugPrint('[CallService] rejectCall socket error: $e');
          _pendingRejectCallerIds.add(callerId);
        }
      } else {
        debugPrint('[CallService] ⏳ Socket non prêt → refus mis en file');
        _pendingRejectCallerIds.add(callerId);
        if (!_apiClient.isSocketConnected) {
          _apiClient.connectSocket();
        }
      }
    }

    if (_status == CallStatus.incoming) {
      _status = CallStatus.idle;
      notify();
    }
  }

  /// Rejoue les refus mis en file (voir [rejectIncomingCallFromPush]) une fois le
  /// socket authentifié. Appelé depuis le listener `auth:verified`.
  void _flushPendingRejects() {
    if (_pendingRejectCallerIds.isEmpty) return;
    if (!_apiClient.isSocketReady) return;
    final pending = List<String>.from(_pendingRejectCallerIds);
    _pendingRejectCallerIds.clear();
    for (final callerId in pending) {
      final cid = int.tryParse(callerId);
      if (cid == null) continue;
      debugPrint('[CallService] 🔁 Rejeu refus en file → reject_call caller=$cid');
      try {
        _apiClient.sendSocketEvent(SocketEvents.rejectCall, {'callerId': cid});
      } catch (e) {
        debugPrint('[CallService] rejeu reject_call échoué: $e');
        _pendingRejectCallerIds.add(callerId);
      }
    }
  }
}
