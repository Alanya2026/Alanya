/// Helpers purs pour le routage cold-start / merge / ready des conférences.
/// Extraite pour tests unitaires sans CallService complet.

/// True si l'appel entrant est une invitation conférence (join/transfer).
bool isConferenceCallIncoming({
  String? sessionKind,
  String? callId,
  String? roomId,
}) {
  if (sessionKind == 'conference') return true;
  if (callId != null && callId.startsWith('conf_')) return true;
  if (roomId != null && roomId.startsWith('conf_')) return true;
  return false;
}

/// True si call_conf_invite doit être fusionné (même session déjà incoming).
bool shouldMergeConfInvite({
  required String callStatusName,
  String? confSessionId,
  String? currentCallId,
  required String incomingSessionId,
}) {
  if (callStatusName != 'incoming') return false;
  return confSessionId == incomingSessionId || currentCallId == incomingSessionId;
}

/// Clé idempotente pour call_conf_ready (sessionId|peerId).
String confReadyKey(String sessionId, String peerId) => '$sessionId|$peerId';

/// Décide si un ready peut être mis en file / émis côté client restant.
///
/// [transferTargetId] = C (cible du transfert). Sans match exact, aucun ready :
/// évite d'armer le leaveTimer serveur sur une PC A↔B déjà connected.
bool canLocalEmitConfReady({
  required String confMode,
  required bool isTransferInitiator,
  required bool isConfInvitee,
  required String peerId,
  int? localUserId,
  String? transferTargetId,
}) {
  if (confMode != 'transfer') return false;
  if (isTransferInitiator) return false;
  if (isConfInvitee) return false;
  if (localUserId != null && peerId == localUserId.toString()) return false;
  if (transferTargetId == null || transferTargetId.isEmpty) return false;
  if (peerId != transferTargetId) return false;
  return true;
}

/// Décide si un join/ready en file doit être droppé au flush.
enum ConfQueueFlushResult { emit, drop, keep }

ConfQueueFlushResult confJoinFlushDecision({
  required String? pendingSessionId,
  required String? confSessionId,
  required bool isTerminal,
  required String callStatusName,
  required bool socketReady,
}) {
  if (pendingSessionId == null) return ConfQueueFlushResult.drop;
  if (confSessionId != pendingSessionId) return ConfQueueFlushResult.drop;
  if (isTerminal) return ConfQueueFlushResult.drop;
  if (callStatusName != 'joining' &&
      callStatusName != 'incoming' &&
      callStatusName != 'connected') {
    return ConfQueueFlushResult.drop;
  }
  if (!socketReady) return ConfQueueFlushResult.keep;
  return ConfQueueFlushResult.emit;
}

ConfQueueFlushResult confReadyFlushDecision({
  required String keySessionId,
  required String? confSessionId,
  required bool isTerminal,
  required String confMode,
  required bool isTransferInitiator,
  required String callStatusName,
  required bool socketReady,
}) {
  if (confSessionId != keySessionId) return ConfQueueFlushResult.drop;
  if (isTerminal) return ConfQueueFlushResult.drop;
  if (confMode != 'transfer' || isTransferInitiator) {
    return ConfQueueFlushResult.drop;
  }
  if (callStatusName != 'connected' &&
      callStatusName != 'joining' &&
      callStatusName != 'incoming') {
    return ConfQueueFlushResult.drop;
  }
  if (!socketReady) return ConfQueueFlushResult.keep;
  return ConfQueueFlushResult.emit;
}
