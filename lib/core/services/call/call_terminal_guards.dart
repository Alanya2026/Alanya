/// Helpers purs décidant si un événement reçu du serveur concerne bien l'appel
/// en cours. Extraits pour tests unitaires sans CallService complet.
///
/// Le serveur émet ses événements terminaux depuis une douzaine d'endroits —
/// fin, refus, grâce de déconnexion, `resume_ack_timeout`, transfert — et rien
/// ne garantit qu'ils arrivent avant que l'appel suivant ait commencé. Sans
/// garde, un événement en retard raccroche un appel auquel il ne se rapportait
/// pas. Le modèle de référence est `call_busy` / `call_no_answer`, qui vérifient
/// depuis toujours le statut avant d'agir.
library;

/// True si ce statut décrit un appel encore vivant.
///
/// `reconnecting` en fait partie : l'appel n'est pas perdu, il se rétablit.
/// L'omettre faisait disparaître la bannière d'appel minimisé et rendait
/// l'écran impossible à rouvrir pendant toute la reconnexion — au moment
/// précis où l'utilisateur veut voir ce qui se passe.
bool isActiveCallStatus(String callStatusName) {
  switch (callStatusName) {
    case 'outgoing':
    case 'connecting':
    case 'connected':
    case 'reconnecting':
    case 'joining':
      return true;
    default:
      return false;
  }
}

/// `call_ended` ordinaire : ne termine que l'appel qu'il désigne.
///
/// Un identifiant absent vaut acceptation — c'est le comportement historique,
/// et certains chemins serveur n'en portent pas.
bool endsCurrentCall({
  required String? eventCallId,
  String? currentCallId,
  String? confSessionId,
  String? groupRoomId,
}) {
  if (eventCallId == null || eventCallId.isEmpty) return true;
  return eventCallId == currentCallId ||
      eventCallId == confSessionId ||
      eventCallId == groupRoomId;
}

/// `call_rejected`, `call_failed`, `call_error` : événements terminaux d'un
/// appel **sortant**. Ils n'ont de sens que pendant qu'on en passe un, et que
/// pour celui-là.
///
/// [currentCallIdIsLocal] dit que `currentCallId` est l'horodatage fabriqué par
/// `_ensureCallId()`, et non l'identifiant du serveur. Comparer les deux ne peut
/// alors qu'échouer, et l'échec coûtait l'appel : un refus arrivé pendant la
/// sonnerie — avant `call_answered`, seul endroit où l'appelant adoptait
/// l'identifiant serveur — était systématiquement jeté. L'appelant continuait
/// d'entendre sa sonnerie de retour jusqu'au filet des 45 secondes, qui
/// annonçait « pas de réponse » sur un appel pourtant refusé.
///
/// Le serveur annonce désormais son identifiant dès la sonnerie (`call_ringing`)
/// et ce cas ne se présente plus ; il reste pour le parc encore servi par une
/// instance plus ancienne. Il n'y a jamais qu'un seul appel sortant à la fois :
/// le statut suffit à le désigner.
bool acceptsOutgoingTerminalEvent({
  required String callStatusName,
  String? eventCallId,
  String? currentCallId,
  bool currentCallIdIsLocal = false,
}) {
  if (callStatusName != 'outgoing' && callStatusName != 'connecting') {
    return false;
  }
  if (eventCallId == null || eventCallId.isEmpty) return true;
  if (currentCallId == null || currentCallId.isEmpty) return true;
  if (currentCallIdIsLocal) return true;
  return eventCallId == currentCallId;
}

/// `group_call_ended` : ne démonte le maillage que s'il désigne la salle où
/// l'on se trouve, et seulement si l'on y est encore.
bool endsGroupCall({
  required String? groupRoomId,
  String? eventRoomId,
  required String callStatusName,
}) {
  if (groupRoomId == null || groupRoomId.isEmpty) return false;
  if (callStatusName == 'idle' || callStatusName == 'ended') return false;
  if (eventRoomId == null || eventRoomId.isEmpty) return true;
  return eventRoomId == groupRoomId;
}

/// Rôle de restart après une reprise.
///
/// `call_resume` porte déjà le bon rôle — `entry.lastAnswer != null ? 'caller'
/// : 'callee'` — mais il n'était jamais lu : le drapeau était posé à `true`
/// même sur le device qui **reçoit** l'offre de rejoin. Les deux côtés se
/// croyaient alors initiateurs, et le protocole est « caller-only ».
/// Sans rôle transmis, on conserve ce qu'on savait.
bool resolveOutgoingCaller({
  String? serverRole,
  required bool current,
}) {
  if (serverRole == 'caller') return true;
  if (serverRole == 'callee') return false;
  return current;
}

/// Vrai si [candidate] désigne l'appel en cours, quel que soit celui de ses
/// deux identifiants qu'on présente.
///
/// Un appel sortant en porte deux : celui fabriqué localement pour ouvrir la
/// session CallKit, et celui du serveur, adopté au décrochage. CallKit et la
/// couche native ne connaissent que le premier ; le serveur et l'isolate FCM
/// ne parlent que du second. Ne comparer qu'un seul rendait faux, selon le
/// sens, soit la fin d'appel venue du push, soit la restauration après kill.
bool matchesCallIdentity({
  required String? candidate,
  String? currentCallId,
  String? callKitCallId,
}) {
  if (candidate == null || candidate.isEmpty) return false;
  return candidate == currentCallId || candidate == callKitCallId;
}

/// Vrai si [candidate] désigne l'appel sortant encore en cours — la garde de
/// `shouldPreserveOutgoingCallKit` et de `restoreOutgoingFromColdStart`, qui
/// reçoivent toutes deux l'identifiant porté par l'entrée CallKit.
bool matchesActiveOutgoingCall({
  required String? candidate,
  required String callStatusName,
  String? currentCallId,
  String? callKitCallId,
}) {
  if (!matchesCallIdentity(
    candidate: candidate,
    currentCallId: currentCallId,
    callKitCallId: callKitCallId,
  )) {
    return false;
  }
  // `joining` est exclu : c'est une entrée en conférence, pas un sortant 1-à-1
  // dont on aurait un instantané à restaurer.
  return callStatusName == 'outgoing' ||
      callStatusName == 'connecting' ||
      callStatusName == 'connected' ||
      callStatusName == 'reconnecting';
}

/// Vrai s'il faut adopter l'identifiant que le serveur renvoie au décrochage.
///
/// Sans adoption, `_currentCallId` reste l'horodatage fabriqué côté appelant et
/// aucune comparaison avec un événement serveur ne peut aboutir. Un identifiant
/// vide n'apprend rien : on garde le local.
bool shouldAdoptServerCallId({
  required String? serverCallId,
  String? currentCallId,
}) {
  if (serverCallId == null || serverCallId.trim().isEmpty) return false;
  return serverCallId != currentCallId;
}

/// `meeting:ended` : ne termine que la réunion qu'il désigne.
///
/// Le handler ne lisait pas son payload et raccrochait quel que soit le
/// statut. Même famille que `group_call_ended` avant sa garde : un événement
/// tardif — une réunion précédente soldée pendant qu'on vient d'en rejoindre
/// une autre — détruisait le média de celle en cours.
///
/// Un identifiant absent vaut acceptation, comme partout ailleurs ici : le
/// serveur en porte un aujourd'hui, mais une instance plus ancienne peut ne
/// pas le faire.
bool endsCurrentMeeting({
  required Object? currentMeetingId,
  Object? eventMeetingId,
  required String meetingStatusName,
}) {
  if (currentMeetingId == null) return false;
  if (meetingStatusName == 'idle' || meetingStatusName == 'ended') return false;
  final attendu = currentMeetingId.toString();
  if (attendu.isEmpty) return false;
  final recu = eventMeetingId?.toString();
  if (recu == null || recu.isEmpty) return true;
  return recu == attendu;
}


/// Sous quel identifiant enregistrer l'instantané d'un appel sortant.
///
/// C'est celui de CallKit, et pas l'autre. Ses deux lecteurs —
/// `shouldPreserveOutgoingCallKit` et `restoreOutgoingFromColdStart` — reçoivent
/// l'identifiant que porte l'entrée CallKit au démarrage à froid, et le
/// comparent à `clientCallId`.
///
/// Depuis que `_currentCallId` adopte l'identifiant serveur au décrochage,
/// enregistrer `_currentCallId` y écrivait l'identifiant serveur : plus aucune
/// correspondance possible, et un appel vivant voyait sa session CallKit
/// démontée au redémarrage. L'identifiant serveur a son propre champ.
String? outgoingSnapshotIdentity({
  String? callKitCallId,
  String? currentCallId,
}) {
  final kit = callKitCallId?.trim();
  if (kit != null && kit.isNotEmpty) return kit;
  final courant = currentCallId?.trim();
  if (courant != null && courant.isNotEmpty) return courant;
  return null;
}

/// Le statut local autorise-t-il à confirmer une reprise d'appel ?
///
/// `incoming` en fait partie, et son absence coûtait cher : au démarrage à
/// froid sur un appel déjà en communication, le point d'entrée CallKit repose
/// l'état à `incoming` en armant l'auto-réponse — le serveur, lui, n'envoie plus
/// `incoming_call` mais `call_resume`. Le statut n'étant pas reconnu, le client
/// répondait `call_resume_reject`, c'est-à-dire qu'il demandait lui-même au
/// serveur de raccrocher un appel parfaitement vivant. L'application tuée puis
/// rouverte en pleine conversation coupait donc la communication des deux côtés.
bool acceptsResumeForLocalStatus({
  required String callStatusName,
  bool awaitingAutoAnswer = false,
}) {
  switch (callStatusName) {
    case 'connecting':
    case 'connected':
    case 'reconnecting':
    case 'outgoing':
      return true;
    case 'incoming':
      // Seulement si une entrée CallKit acceptée nous a remis dans cet état :
      // un entrant qui sonne encore n'a rien à reprendre.
      return awaitingAutoAnswer;
    default:
      return false;
  }
}

/// Faut-il reconstruire le socket pendant qu'un appel est en reconnexion ?
///
/// Un socket peut être mort sans que rien ne le dise : le TCP est tombé, mais
/// Socket.IO ne le constate qu'au bout de son ping — 25 s d'intervalle, 20 s de
/// patience. Pendant ces quarante-cinq secondes, `isSocketReady` répond `true`,
/// les offres de reprise partent dans le vide, et l'appel reste sur
/// « Reconnexion… » jusqu'au délai global, où il se coupe tout seul. C'est le
/// symptôme exact rapporté sur les appels longs — plus l'appel dure, plus la
/// connexion a de temps pour mourir sans le dire.
///
/// Le signal retenu est le **silence** : pendant une reconnexion, le socket est
/// normalement le canal le plus bavard qui soit — candidats ICE, offres et
/// réponses de reprise. S'il n'a plus rien apporté depuis [silenceThreshold],
/// il ne sert plus à rien et le démonter ne coûte rien. À l'inverse, un socket
/// qui livre encore des événements est peut-être notre seule chance de reprise :
/// on n'y touche pas, même si le média, lui, est à terre.
///
/// **Une seule fois par épisode.** Reconstruire en boucle relancerait la
/// signalisation toutes les huit secondes et aucune négociation n'aurait jamais
/// le temps d'aboutir.
bool shouldRebuildSocketDuringReconnect({
  required bool stillReconnecting,
  required bool alreadyRebuilt,
  required Duration? sinceLastSocketEvent,
  required Duration silenceThreshold,
}) {
  if (!stillReconnecting || alreadyRebuilt) return false;
  // Jamais rien reçu : il n'y a rien à préserver.
  if (sinceLastSocketEvent == null) return true;
  return sinceLastSocketEvent >= silenceThreshold;
}

/// L'application est-elle au premier plan ?
///
/// [lifecycleStateName] est `WidgetsBinding.instance.lifecycleState?.name`, et
/// `null` signifie qu'**aucun événement de cycle de vie n'est encore arrivé**.
/// Le getter rendait alors `true`, en traitant cet inconnu comme un premier
/// plan. C'est précisément le cas d'un réveil par push derrière l'écran
/// verrouillé : l'application revendiquait la présentation Flutter et lançait
/// sa propre sonnerie pendant que la notification CallKit sonnait nativement.
/// Une des causes directes des doubles sonneries et des doubles écrans.
///
/// L'inconnu est donc traité comme un arrière-plan : c'est CallKit qui
/// présente, et il rendra la main dès que l'accueil sera monté. Le prix est une
/// courte fenêtre au lancement normal où un appel serait présenté par CallKit
/// plutôt que par l'écran Flutter — l'accueil bascule aussitôt.
///
/// La chaîne est passée en nom plutôt qu'en `AppLifecycleState` pour garder ce
/// fichier sans dépendance à Flutter, comme le reste de ses gardes.
bool appIsForeground(String? lifecycleStateName) =>
    lifecycleStateName == 'resumed';

/// Une invitation de groupe est-elle assez complète pour être présentée ?
///
/// Sans identifiant de salon, il n'y a rien à présenter et rien à rejoindre —
/// mais poser quand même le statut « entrant » suffisait à **rendre l'appareil
/// sourd** : la revendication de présentation était refusée faute
/// d'identifiant, aucune interface ne s'ouvrait, aucun filet temporel n'était
/// armé, et tous les points d'entrée refusent un entrant tant que le statut
/// n'est pas `idle`. Plus aucun appel ne pouvait arriver, et la seule sortie
/// était un `call_ended` de forme 1-à-1 venu du serveur.
///
/// La règle générale dont ceci est un cas : ne jamais poser un statut dont
/// aucune horloge locale ne peut répondre.
bool groupInviteIsPresentable(String? roomId) =>
    (roomId?.trim() ?? '').isNotEmpty;

/// Sous quel identifiant un appel entrant est-il présenté ?
///
/// Un appel à deux porte un `callId` ; une invitation de groupe n'en a pas — le
/// handler `group_call_invite` ne pose que `_groupRoomId`. Tout code qui vise
/// l'entrant par son seul `callId` sort donc **à vide** pour un groupe, sans un
/// mot.
///
/// C'est ce qui produisait les deux sonneries : le retrait de l'entrée CallKit
/// visait `_currentCallId`, nul, et ne retirait rien ; la sonnerie Flutter,
/// elle, raisonnait sur le salon et partait bien. Les deux moitiés du même geste
/// ne parlaient pas du même appel.
String? incomingPresentationId({String? callId, String? groupRoomId}) {
  final id = callId?.trim();
  if (id != null && id.isNotEmpty) return id;
  final salon = groupRoomId?.trim();
  if (salon != null && salon.isNotEmpty) return salon;
  return null;
}

/// Faut-il adopter un décrochage que le natif a enregistré sans nous ?
///
/// Depuis que `MainActivity` lit le décrochage dans son intent de lancement,
/// l'entrée CallKit peut passer à « acceptée » pendant que Flutter n'écoutait
/// pas — application en arrière-plan, moteur vivant mais endormi. Au retour au
/// premier plan, l'application reprenait alors l'entrant : elle revendiquait la
/// présentation et relançait sa sonnerie sur un appel que l'utilisateur venait
/// de décrocher. C'est le symptôme rapporté.
///
/// La question se pose donc **avant** toute reprise, et elle exige que l'entrée
/// active désigne bien l'appel qu'on présente : une entrée résiduelle d'un autre
/// appel ne doit pas faire décrocher celui-ci.
bool shouldAdoptNativeAccept({
  required bool statusIsIncoming,
  required bool autoAnsweringFromPush,
  required String? presentationId,
  required String? activeCallId,
  required bool activeAccepted,
}) {
  if (!statusIsIncoming || autoAnsweringFromPush) return false;
  if (!activeAccepted) return false;
  final presente = presentationId?.trim() ?? '';
  final actif = activeCallId?.trim() ?? '';
  if (presente.isEmpty || actif.isEmpty) return false;
  return presente == actif;
}

/// Faut-il reprendre, au retour au premier plan, l'entrant que seule la
/// notification native connaît ?
///
/// Uniquement si Dart n'a aucun appel en main (statut `idle`, aucune
/// auto-réponse en vol) et que l'entrée CallKit est un entrant qui sonne
/// encore : ni acceptée — c'est alors `shouldAdoptNativeAccept` qui décroche —,
/// ni un appel sortant que nous avons nous-mêmes posé.
bool shouldAdoptNativeIncoming({
  required bool statusIsIdle,
  required bool autoAnswering,
  required String? activeCallId,
  required bool activeAccepted,
  required bool activeOutgoing,
}) {
  if (!statusIsIdle || autoAnswering) return false;
  if (activeAccepted || activeOutgoing) return false;
  final actif = activeCallId?.trim() ?? '';
  if (actif.isEmpty || actif.startsWith('meeting_')) return false;
  return true;
}

/// Ce qu'une action CallKit terminale doit rapporter au serveur.
enum TerminalCallReport {
  /// Un refus explicite de l'utilisateur : le serveur l'inscrit « rejeté ».
  refus,

  /// Rien. Le minuteur serveur de 45 secondes classe l'appel « sans réponse »,
  /// et lui seul sait le faire.
  rien,
}

/// Faut-il signaler un refus au serveur pour cette action CallKit ?
///
/// L'expiration de la notification — 40 secondes, posées délibérément avant les
/// 45 secondes du serveur — était rapportée comme un refus explicite. Le
/// serveur écrivait alors `status = 2` cinq secondes avant que son propre
/// minuteur n'ait écrit `status = 3`, et l'`UPDATE` étant inconditionnel, il
/// écrasait même un « sans réponse » déjà correct quand un retard sous Doze
/// inversait l'ordre.
///
/// Un appel qu'on n'a simplement pas entendu, téléphone dans la poche,
/// s'inscrivait donc « Rejeté » dans le journal des DEUX correspondants.
///
/// Le même choix était fait des deux côtés de la frontière — ici et dans
/// l'écouteur `ACTIVE_CALLS` natif. Les corriger séparément aurait créé une
/// incohérence entre application vivante et application tuée.
TerminalCallReport reportForTerminalAction(String actionName) {
  switch (actionName) {
    case 'decline':
      return TerminalCallReport.refus;
    // `timeout` : la sonnerie a expiré, personne n'a rien décidé.
    // `ended` : retrait par le système ou nettoyage local — un autre appareil
    // peut encore sonner, ou avoir déjà décroché.
    default:
      return TerminalCallReport.rien;
  }
}

/// Ce refus doit-il être posté au serveur sur le chemin 1-à-1 ?
///
/// Un salon de groupe (`group_<conv>_<ms>`) et une session de conférence
/// (`conf_…`) ne sont pas des appels à deux. Postés sur `/calls/reject`, le
/// serveur n'en tirait aucun identifiant, sautait sa garde de refus tardif —
/// un invité de groupe n'a pas d'entrée d'état — et retombait sur « le dernier
/// appel entre ces deux comptes », qu'il passait à « Rejeté ». Un appel abouti,
/// parfois vieux de plusieurs jours, se trouvait réécrit chez les DEUX.
///
/// Le refus d'un groupe est purement local : `rejectGroupCall` le documente
/// depuis toujours — « le backend n'expose pas de reject_group_call ».
///
/// Le serveur se garde désormais aussi de son côté, pour le parc déjà
/// installé ; ce test-ci évite l'aller-retour et dit l'intention.
bool shouldPostRejectToServer(String? callId) {
  final id = callId?.trim() ?? '';
  // Sans identifiant, on laisse le serveur trancher avec ce qu'il sait.
  if (id.isEmpty) return true;
  return RegExp(r'^\d+$').hasMatch(id);
}

/// La réponse en cours porte-t-elle toujours sur l'appel qu'on a commencé à
/// décrocher ?
///
/// `answerCall` enchaîne quatre attentes — capture du micro, socket prêt,
/// PeerConnection, accusé de réception — sans jamais revérifier entre deux que
/// l'appel existe encore. Quand un aperçu CallKit le faisait refuser en plein
/// milieu, la méthode continuait sur un état remis à zéro : elle envoyait sa
/// réponse à un appel que le serveur ne connaissait plus — d'où son
/// `CALL_NOT_RINGING` —, se déclarait connectée, et ouvrait une session CallKit
/// sous un identifiant fabriqué. C'est l'écran « Appel » au chronomètre, avec
/// personne en face.
///
/// Trois conditions : le décrochage est encore en cours (`connecting`), aucune
/// fin d'appel n'a été engagée, et l'appel visé est toujours celui du départ.
bool answerStillValid({
  required String callStatusName,
  required String? callIdAtStart,
  String? currentCallId,
  bool endingCall = false,
}) {
  if (endingCall) return false;
  if (callStatusName != 'connecting') return false;
  return (callIdAtStart?.trim() ?? '') == (currentCallId?.trim() ?? '');
}

/// Cet aperçu CallKit désigne-t-il l'appel que l'on est déjà en train de mener ?
///
/// Le plugin réaffiche l'entrant dans des cas parfaitement ordinaires — c'est ce
/// que faisait la bascule vers CallKit au retour au premier plan. L'aperçu
/// revenait alors à `handleIncomingCallKitPreview`, qui le prenait pour un appel
/// étranger : « occupé », donc on ferme. Or fermer marque l'appel terminé, fait
/// émettre un refus par le plugin, et le décrochage en cours est perdu.
///
/// Un aperçu qui porte l'identifiant de l'appel courant n'apprend rien : il
/// s'ignore, sans rien fermer ni marquer. Les quatre identifiants comptent — un
/// appel à deux en porte deux, celui du serveur et celui sous lequel CallKit a
/// été ouvert ; un groupe a son salon ; une session à trois la sienne.
///
/// Hors appel (`idle`, `ended`), il n'y a rien à protéger : le nettoyage
/// habituel reprend la main.
bool previewTargetsCurrentCall({
  required String? previewCallId,
  required String callStatusName,
  String? currentCallId,
  String? callKitCallId,
  String? groupRoomId,
  String? confSessionId,
}) {
  final id = previewCallId?.trim() ?? '';
  if (id.isEmpty) return false;
  if (callStatusName == 'idle' || callStatusName == 'ended') return false;
  for (final connu in [
    currentCallId,
    callKitCallId,
    groupRoomId,
    confSessionId,
  ]) {
    final candidat = connu?.trim() ?? '';
    if (candidat.isNotEmpty && candidat == id) return true;
  }
  return false;
}

/// Ce changement d'état du cycle de vie est-il un vrai départ en arrière-plan ?
///
/// Flutter ne saute jamais d'un état à l'autre : il rejoue tous les états
/// intermédiaires. Revenir au premier plan depuis `paused` fait donc passer par
/// `hidden`, puis `inactive`, puis `resumed`. L'accueil prenait ce `hidden` pour
/// un départ et rebasculait l'appel entrant vers CallKit à l'instant précis où
/// l'utilisateur venait de décrocher : le plugin réaffichait l'entrant, l'app
/// prenait alors son propre appel pour un autre, le refusait au serveur, et le
/// décrochage était perdu — écran fermé d'un côté, appel coupé de l'autre.
///
/// `paused` et `detached` sont des départs sans ambiguïté. `inactive` n'en est
/// jamais un : volet de notifications, changeur d'applications ou boîte de
/// dialogue système laissent l'application à l'écran.
///
/// `hidden`, lui, se lit à sa provenance : il ne remonte que lorsqu'il vient de
/// `paused`, et c'est exactement le cas qui coûtait l'appel. Un `hidden` dont on
/// ignore d'où il vient — premier événement reçu après l'installation de
/// l'observateur — reste un départ : le comportement d'avant est conservé là où
/// il était juste.
bool isBackgroundDeparture({
  required String stateName,
  String? previousStateName,
}) {
  switch (stateName) {
    case 'paused':
    case 'detached':
      return true;
    case 'hidden':
      return previousStateName != 'paused';
    default:
      return false;
  }
}

/// Cette offre de reprise peut-elle être appliquée dans l'état local courant ?
///
/// Le sort du destinataire après une mort de processus tenait à cette garde.
/// Seul l'appelant persiste un instantané : au redémarrage à froid en pleine
/// communication, l'appelé lit son entrée CallKit acceptée, repasse par
/// `acceptIncomingCallFromPush` et se retrouve en « entrant » avec
/// l'auto-réponse armée. Il confirme pourtant la reprise au serveur — ce qui
/// annule la grâce de déconnexion, l'appel est officiellement vivant — mais la
/// restauration s'arrête là, faute d'instantané.
///
/// L'appelant, lui, voit son lien tomber, entre en reconnexion et émet son
/// offre de rejointe. Elle arrivait ici et était jetée : `incoming` ne figurait
/// pas dans les états autorisés. L'appelé restait figé sur « connexion en
/// cours » trente secondes puis « Échec », et le correspondant attendait les
/// quarante-cinq secondes du délai global. La restauration après mort de
/// processus ne fonctionnait que pour celui qui avait passé l'appel.
///
/// Recevoir l'offre suffit : la branche « pas de PeerConnection » reconstruit
/// toute la pile en `asOutgoingCaller: false`, ce qui est exactement le rôle
/// d'un appelé de restart.
bool acceptsRejoinOfferForLocalStatus({
  required String callStatusName,
  required bool isRestoringOutgoing,
  required bool peerMatchesRemote,
  required bool awaitingAutoAnswer,
}) {
  if (isRestoringOutgoing) return true;
  switch (callStatusName) {
    case 'connected':
    case 'reconnecting':
      return true;
    case 'connecting':
      return peerMatchesRemote;
    case 'incoming':
      // Appelé restauré après une mort de processus : il n'a pas d'instantané,
      // mais il sait qu'il était en train de décrocher.
      return awaitingAutoAnswer && peerMatchesRemote;
    default:
      return false;
  }
}
