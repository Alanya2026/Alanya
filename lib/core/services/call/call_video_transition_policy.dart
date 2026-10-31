/// Une seconde renégociation vidéo doit préserver l'état de la caméra locale.
bool shouldTurnLocalCameraOffForRemoteUpgrade({
  required bool alreadyInVideoMode,
}) => !alreadyInVideoMode;
