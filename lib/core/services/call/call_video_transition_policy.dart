/// Une seconde renégociation vidéo doit préserver l'état de la caméra locale.
bool shouldTurnLocalCameraOffForRemoteUpgrade({
  required bool alreadyInVideoMode,
}) => !alreadyInVideoMode;

bool isCurrentVideoUpgradeSession({
  required String? activeCallId,
  required String? operationCallId,
  required int? activeRemoteUserId,
  required int? operationRemoteUserId,
  required String? activeTransitionId,
  required String operationTransitionId,
  required bool isConnected,
}) =>
    isConnected &&
    activeCallId == operationCallId &&
    activeRemoteUserId == operationRemoteUserId &&
    activeTransitionId == operationTransitionId;
