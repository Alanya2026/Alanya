# Appels vidéo : profil de capture et transition audio → vidéo

## Qualité vidéo des appels

Réglage « Appels vidéo » dans Profil › Réseau et données :

| Niveau | Capture | Cadence | Plafond encodeur | Accès |
|---|---|---|---|---|
| Basse résolution | 640 × 360 | 20 i/s | 600 kbit/s | tous |
| Standard (défaut) | 848 × 480 | 30 i/s | 1,2 Mbit/s | tous |
| Haute définition | 1280 × 720 | 30 i/s | 2,5 Mbit/s | Alanya Plus (`video_hd`) |
| Full HD | 1920 × 1080 | 30 i/s | 5 Mbit/s | Alanya Plus (`video_hd`) |

La cadence du niveau vaut pour la caméra et pour le plafond de l'encodeur.
`degradationPreference: maintain-framerate` : quand le débit manque, l'image
perd en résolution, pas en fluidité. Sous ces plafonds, WebRTC s'adapte seul à
la connexion.

Les contraintes `getUserMedia` sont des entiers : flutter_webrtc 0.14 ignore
les maps `{ideal, min, max}` sur Android (repli 1280 × 720 à 30 i/s) et ne lit
`ideal` qu'en texte sur iOS. Les paramètres de l'encodeur sont rejoués après
chaque description locale (`WebRTCService._applyVideoSendParameters`).

Appels de groupe et réunions : capture standard fixe (848 × 480) à 24 i/s, sans
plafond d'encodeur pour l'instant. Ils sont en maillage, avec un encodage par
participant : 30 i/s y pèserait trop. Sans le droit `video_hd`, un choix HD ou
Full HD part en standard et reprend dès l'abonnement.

## Sonnerie d'un appel vidéo

L'appelant ouvre sa caméra et son micro avant que la ligne ne sonne. L'appelé
ouvre sa caméra dès la sonnerie, quand l'écran d'appel de l'application est
affiché et que la permission est déjà accordée : aperçu en fond d'écran, bouton
pour la couper avant de décrocher, reprise de la même capture au décrochage.

- **Rien ne sort avant le décrochage** : aucune PeerConnection n'existe encore.
- **Le micro attend le décrochage** : `getUserMedia` audio prend le focus audio
  et couperait la sonnerie. Il reste la première chose ouverte après le tap.
- **Application en arrière-plan ou écran système** : Android refuse la caméra,
  elle s'ouvre au décrochage.
- **Décroché caméra coupée** : l'appel reste vidéo sans piste locale, le bouton
  caméra l'ajoute par la renégociation de la transition audio → vidéo.

## Transition audio → vidéo

La transition est active par défaut ; `--dart-define=CALL_AUDIO_TO_VIDEO=false`
la coupe. Elle est limitée aux appels individuels déjà connectés :

1. l'appelant confirme localement puis acquiert uniquement sa caméra ;
2. une offre/réponse SDP dédiée est relayée sur l'appel existant ;
3. l'appel audio, le micro, le `callId` et la durée sont conservés ; le son passe
   de l'écouteur au haut-parleur, un casque reste en place ;
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
