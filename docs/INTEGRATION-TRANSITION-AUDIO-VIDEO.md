# Intégration de la transition audio → vidéo

La transition est active par défaut ; `--dart-define=CALL_AUDIO_TO_VIDEO=false`
la coupe.
Le client mobile garde la `PeerConnection` et la piste audio existantes, ajoute
une piste caméra à la demande, puis négocie avec
`call_video_upgrade_offer` / `call_video_upgrade_answer`. Le serveur ne diffuse
qu'à l'appareil propriétaire du correspondant.

La caméra du correspondant reste éteinte. Après réception d'une offre réussie,
son bouton caméra peut acquérir sa propre piste et réutiliser le même protocole.
Une opération simultanée est sérialisée localement ; les réponses sont liées au
`transitionId` et au `callId`.

La caméra ajoutée suit le réglage de qualité vidéo de l'utilisateur (voir
`PLAN-OPTIMISATION-VIDEO-ET-SWITCH.md`).
