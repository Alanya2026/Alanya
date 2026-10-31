# Intégration de la transition audio → vidéo

La transition est implémentée derrière `CALL_AUDIO_TO_VIDEO=false` par défaut.
Le client mobile garde la `PeerConnection` et la piste audio existantes, ajoute
une piste caméra à la demande, puis négocie avec
`call_video_upgrade_offer` / `call_video_upgrade_answer`. Le serveur ne diffuse
qu'à l'appareil propriétaire du correspondant.

La caméra du correspondant reste éteinte. Après réception d'une offre réussie,
son bouton caméra peut acquérir sa propre piste et réutiliser le même protocole.
Une opération simultanée est sérialisée localement ; les réponses sont liées au
`transitionId` et au `callId`.

Le profil de capture indépendant est sélectionnable avec
`CALL_VIDEO_PROFILE=low`, sans effet par défaut. Les tests réels sur deux
appareils et la validation de la couverture des services Android/iOS restent
obligatoires avant activation.
