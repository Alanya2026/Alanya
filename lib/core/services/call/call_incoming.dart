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

    _remoteUserId = int.tryParse(callerId);
    _remoteUserName = callerName;
    _remoteUserPhoto = callerPhoto;
    _isVideo = isVideo;
    _currentCallId = callId.isNotEmpty ? callId : null;
    _autoAnswerOnNextIncoming = true;
    _autoAnswerCallerId = callerId;
    _status = CallStatus.incoming;
    notify();

    debugPrint('[CallService] !! Status = incoming, auto-answer armé');

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
  Future<void> rejectIncomingCallFromPush({required String callerId}) async {
    debugPrint('[CallService] 📲 rejectIncomingCallFromPush caller=$callerId');
    final cid = int.tryParse(callerId);
    if (cid != null) {
      try {
        _apiClient.sendSocketEvent(SocketEvents.rejectCall, {'callerId': cid});
      } catch (e) {
        debugPrint('[CallService] rejectCall socket error: $e');
      }
    }
    _autoAnswerOnNextIncoming = false;
    _autoAnswerCallerId = null;
    if (_status == CallStatus.incoming) {
      _status = CallStatus.idle;
      notify();
    }
  }
}
