/// Une seconde renégociation vidéo doit préserver l'état de la caméra locale.
bool shouldTurnLocalCameraOffForRemoteUpgrade({
  required bool alreadyInVideoMode,
}) => !alreadyInVideoMode;

/// La caméra s'ouvre dès la sonnerie pour un appel vidéo individuel, sauf si
/// l'utilisateur l'a coupée. Un groupe ou une conférence ouvre la sienne en
/// rejoignant la salle, avec son propre profil de capture.
bool shouldOpenCameraWhileRinging({
  required bool isVideo,
  required bool isGroup,
  required bool isConference,
  required bool cameraTurnedOff,
}) => isVideo && !isGroup && !isConference && !cameraTurnedOff;

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

bool isActiveVideoUpgradeSession({
  required bool isConnectedOrReconnecting,
  required String? activeCallId,
  required String? operationCallId,
  required int? activeRemoteUserId,
  required int? operationRemoteUserId,
  required String? activeTransitionId,
  required String operationTransitionId,
}) =>
    isConnectedOrReconnecting &&
    activeCallId == operationCallId &&
    activeRemoteUserId == operationRemoteUserId &&
    activeTransitionId == operationTransitionId;
