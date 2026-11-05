/// Sorties audio d'un appel : ce qui est disponible, ce qu'on choisit, et ce
/// vers quoi bascule le bouton. Logique pure, testable sans appareil.
///
/// Le bouton de la barre de contrôle ne connaissait que deux états, haut-parleur
/// allumé ou éteint. Avec un casque Bluetooth appairé, l'utilisateur n'avait
/// donc aucun moyen de savoir où sortait le son, ni de le rediriger.
library;

/// Ce que la plateforme rapporte, réduit à ce qui nous concerne.
///
/// `audio_session` distingue une dizaine de types d'appareils ; pour un appel,
/// seules comptent les quatre familles ci-dessous.
enum AudioOutputKind { earpiece, speaker, wired, bluetooth, other }

/// Sortie effectivement sélectionnable.
enum CallAudioRoute { earpiece, speaker, wired, bluetooth }

/// Traduit un `AudioDeviceType` (par son nom) en famille.
///
/// Passer par le nom plutôt que par le type garde ce fichier sans dépendance,
/// donc testable ; et le tableau de correspondance — l'endroit où l'on se
/// trompe — devient lui aussi vérifiable.
AudioOutputKind audioOutputKindFromTypeName(String typeName) {
  switch (typeName) {
    case 'builtInEarpiece':
      return AudioOutputKind.earpiece;
    case 'builtInSpeaker':
      return AudioOutputKind.speaker;
    case 'wiredHeadset':
    case 'wiredHeadphones':
    case 'headsetMic':
    case 'lineAnalog':
    case 'lineDigital':
    case 'usbHeadset':
      return AudioOutputKind.wired;
    case 'bluetoothSco':
    case 'bluetoothA2dp':
    case 'bluetoothLe':
      return AudioOutputKind.bluetooth;
    default:
      return AudioOutputKind.other;
  }
}

/// Routes proposables, dans l'ordre d'affichage.
///
/// L'écouteur et le haut-parleur existent toujours sur un téléphone, même
/// quand la plateforme ne les énumère pas — c'est le cas sur certains Android
/// dès qu'un périphérique externe est branché. Les deux sont donc toujours
/// offerts ; seuls le filaire et le Bluetooth dépendent de ce qui est présent.
List<CallAudioRoute> availableAudioRoutes(Set<AudioOutputKind> kinds) {
  return [
    CallAudioRoute.earpiece,
    CallAudioRoute.speaker,
    if (kinds.contains(AudioOutputKind.wired)) CallAudioRoute.wired,
    if (kinds.contains(AudioOutputKind.bluetooth)) CallAudioRoute.bluetooth,
  ];
}

/// Sortie retenue à l'ouverture de l'appel.
///
/// Un périphérique branché gagne : on ne renvoie pas le son dans le haut-parleur
/// du téléphone quand l'utilisateur porte un casque. À défaut, la vidéo passe au
/// haut-parleur et la voix à l'écouteur, comme avant.
CallAudioRoute defaultAudioRoute({
  required Set<AudioOutputKind> kinds,
  required bool isVideo,
}) {
  if (kinds.contains(AudioOutputKind.bluetooth)) return CallAudioRoute.bluetooth;
  if (kinds.contains(AudioOutputKind.wired)) return CallAudioRoute.wired;
  return isVideo ? CallAudioRoute.speaker : CallAudioRoute.earpiece;
}

/// Sortie à demander quand un appel passe en vidéo, ou `null` s'il n'y a rien à
/// changer.
///
/// Une vidéo se regarde à distance : le son ne peut pas rester sur l'écouteur.
/// Un casque reste en place, et un appel déjà vidéo garde le choix de
/// l'utilisateur : rallumer sa caméra ne doit pas lui imposer le haut-parleur.
CallAudioRoute? routeForVideoUpgrade({
  required CallAudioRoute current,
  required bool wasAlreadyVideo,
}) => !wasAlreadyVideo && current == CallAudioRoute.earpiece
    ? CallAudioRoute.speaker
    : null;

/// Sortie suivante quand on appuie sur le bouton.
///
/// Simple rotation dans l'ordre d'affichage : avec deux routes le bouton reste
/// la bascule d'avant, avec trois ou quatre il fait le tour.
CallAudioRoute nextAudioRoute({
  required CallAudioRoute current,
  required List<CallAudioRoute> available,
}) {
  if (available.isEmpty) return current;
  final index = available.indexOf(current);
  if (index < 0) return available.first;
  return available[(index + 1) % available.length];
}

/// Sortie à retenir quand la liste change — un casque qu'on débranche, par
/// exemple. Conserve le choix de l'utilisateur tant qu'il reste possible.
CallAudioRoute resolveAudioRouteAfterChange({
  required CallAudioRoute current,
  required Set<AudioOutputKind> kinds,
  required bool isVideo,
}) {
  if (availableAudioRoutes(kinds).contains(current)) return current;
  return defaultAudioRoute(kinds: kinds, isVideo: isVideo);
}

/// Identifiant de sortie attendu par flutter_webrtc sous Android.
///
/// Quatre sorties n'étaient demandées que par deux appels booléens : « mets le
/// haut-parleur » et « enlève-le ». Or côté Android, enlever le haut-parleur
/// signifie « prends le premier appareil disponible parmi Bluetooth, filaire,
/// écouteur » : avec un casque appairé, demander l'écouteur renvoyait le son au
/// casque, et l'écouteur devenait inatteignable.
///
/// Ces quatre chaînes sont celles qu'attend `AudioDeviceKind.fromTypeName` ;
/// toute autre valeur y est ignorée en silence.
String webrtcDeviceId(CallAudioRoute route) {
  switch (route) {
    case CallAudioRoute.earpiece:
      return 'earpiece';
    case CallAudioRoute.speaker:
      return 'speaker';
    case CallAudioRoute.wired:
      return 'wired-headset';
    case CallAudioRoute.bluetooth:
      return 'bluetooth';
  }
}

/// Nom transmis au pont natif pour demander une sortie à Telecom.
String telecomRouteName(CallAudioRoute route) => route.name;

/// Sortie désignée par le natif, ou `null` si le nom ne dit rien.
CallAudioRoute? routeFromTelecomName(String? name) {
  switch (name?.trim()) {
    case 'earpiece':
      return CallAudioRoute.earpiece;
    case 'speaker':
      return CallAudioRoute.speaker;
    case 'wired':
      return CallAudioRoute.wired;
    case 'bluetooth':
      return CallAudioRoute.bluetooth;
    default:
      return null;
  }
}

/// Sorties réellement disponibles, d'après le masque que tient Telecom.
///
/// `CallAudioState.getSupportedRouteMask` : 1 écouteur, 2 Bluetooth, 4 filaire,
/// 8 haut-parleur. Source plus sûre que l'énumération des périphériques audio,
/// qui n'annonce pas toujours l'écouteur — c'est d'ailleurs pourquoi
/// [availableAudioRoutes] offre l'écouteur et le haut-parleur d'office.
///
/// L'ordre rendu est celui d'affichage, pour que le bouton tourne toujours dans
/// le même sens.
List<CallAudioRoute> routesFromSupportedMask(int mask) {
  return [
    if (mask & 1 != 0) CallAudioRoute.earpiece,
    if (mask & 8 != 0) CallAudioRoute.speaker,
    if (mask & 4 != 0) CallAudioRoute.wired,
    if (mask & 2 != 0) CallAudioRoute.bluetooth,
  ];
}

/// Sortie à afficher : celle que le natif rapporte, à défaut celle demandée.
///
/// Pour une lecture **non sollicitée** — un casque qu'on branche, Telecom qui
/// rebascule seul. Après une demande, c'est [routeApresDemande] qui décide.
CallAudioRoute resolveAppliedRoute({
  required CallAudioRoute requested,
  String? reportedName,
}) =>
    routeFromTelecomName(reportedName) ?? requested;

/// Sortie à retenir après avoir demandé [demandee].
///
/// Une relecture qui annonce encore la sortie [precedente] est périmée, pas
/// contradictoire : Telecom applique la route de façon asynchrone, et l'aller-
/// retour vers un casque Bluetooth demande plus d'une seconde — bien plus que
/// le délai avant relecture. L'adopter figeait le bouton : la sortie courante
/// ne bougeait pas, l'appui suivant recalculait donc la même cible, et il en
/// fallait deux pour changer de sortie.
///
/// Une relecture qui annonce une TROISIÈME sortie, elle, est un vrai arbitrage
/// — un casque filaire qui impose sa loi — et doit être suivie.
CallAudioRoute routeApresDemande({
  required CallAudioRoute precedente,
  required CallAudioRoute demandee,
  String? rapportee,
}) {
  final lue = routeFromTelecomName(rapportee);
  if (lue == null || lue == precedente) return demandee;
  return lue;
}

/// True si le son sort par le haut-parleur du téléphone.
///
/// C'est le seul réglage que la couche WebRTC expose directement ; le Bluetooth
/// a son propre appel, et le filaire se sélectionne tout seul dès que le
/// haut-parleur est coupé.
bool speakerphoneForRoute(CallAudioRoute route) =>
    route == CallAudioRoute.speaker;

/// True si l'écran doit s'éteindre quand le téléphone approche du visage.
///
/// Le critère est la **sortie audio**, pas le type d'appel : c'est l'écouteur
/// interne qui dit qu'on tient le téléphone contre l'oreille. Sur haut-parleur,
/// sur casque filaire ou en Bluetooth, on le regarde à distance — éteindre
/// l'écran parce qu'une main passe devant le capteur serait un défaut.
///
/// Fonder la règle sur `isVideo` aurait le même effet dans le cas courant, la
/// vidéo s'ouvrant sur le haut-parleur, mais raterait les deux bascules que
/// l'utilisateur peut faire en cours d'appel : une vidéo basculée sur l'écouteur
/// doit éteindre, une voix passée en haut-parleur doit rallumer.
bool proximityBlankingApplies({
  required CallAudioRoute route,
  required bool callActive,
}) =>
    callActive && route == CallAudioRoute.earpiece;

/// True si le wakelock doit tenir l'écran allumé.
///
/// Il existe pour la vidéo, qu'on regarde sans toucher l'écran et qui s'éteignait
/// donc toute seule. Il s'oppose frontalement au capteur de proximité : l'un
/// force l'écran allumé pendant que l'autre veut l'éteindre. Quand les deux
/// s'appliqueraient, la proximité gagne — un téléphone porté à l'oreille n'est
/// plus un téléphone qu'on regarde.
bool screenWakelockApplies({
  required bool isVideo,
  required CallAudioRoute route,
  required bool callActive,
}) =>
    callActive &&
    isVideo &&
    !proximityBlankingApplies(route: route, callActive: callActive);
