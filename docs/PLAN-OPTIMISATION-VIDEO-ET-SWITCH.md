# Appels vidéo : profil de capture et transition audio → vidéo

## Profil de capture expérimental

`videoCaptureConstraints` conserve par défaut la préférence 1280 × 720 à
30 fps. Le profil `low`, activé uniquement avec
`--dart-define=CALL_VIDEO_PROFILE=low`, vise 640 × 480 à 24 fps. Ce sont des
préférences `ideal`, pas des limites garanties ; le profil concerne les appels
et les réunions et ne modifie ni l'audio, ni ICE, ni le codec.

## Transition audio → vidéo

La première version est protégée par `CALL_AUDIO_TO_VIDEO`, désactivé par
défaut. Elle est limitée aux appels individuels déjà connectés :

1. l'appelant confirme localement puis acquiert uniquement sa caméra ;
2. une offre/réponse SDP dédiée est relayée sur l'appel existant ;
3. l'appel audio, le micro, la route, le `callId` et la durée sont conservés ;
4. le correspondant reçoit la vidéo sans ouvrir sa caméra ;
5. un échec, un timeout ou un refus conserve l'audio et arrête la piste
   nouvellement acquise.

Le backend vérifie l'appel actif, `callId`, le pair et l'appareil propriétaire
des deux côtés. Le canal est distinct de `call_rejoin` et les clients anciens
ignorent l'événement ; leur appel audio n'est pas interrompu.

## Validation restante

Les appareils Android et iOS réels doivent encore valider permissions, réseau
Wi-Fi/4G/TURN, arrière-plan, PiP, verrouillage, caméra occupée et fin d'appel
pendant la transition avant activation du drapeau en production.
