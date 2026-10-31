import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, ChangeNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'call/call_terminal_guards.dart';
import 'call/video_capture_profile.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../screens/meetings/ongoing_meet_screen.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'call/session_video_renderers.dart';
import 'call/speaking_detector.dart';
import 'call/system_pip.dart';
import 'call_session_guard.dart';
import 'callkit_service.dart';
import '../navigation/app_navigator.dart';
import '../theme/locale_controller.dart';
import '../errors/app_error.dart';
import '../errors/error_kind.dart';
import 'billing/entitlement_service.dart';

enum MeetingStatus { idle, joining, connected, ended }

class ChatMessage {
  final String userId;
  final String message;
  final DateTime sendAt;

  ChatMessage({
    required this.userId,
    required this.message,
    required this.sendAt,
  });
}

class MeetingService extends ChangeNotifier {
  final TalkyApiClient _apiClient;

  // État de la réunion
  MeetingStatus _status = MeetingStatus.idle;
  Meeting? _currentMeeting;

  /// Numéro de la session en cours, incrémenté à chaque fin de réunion.
  ///
  /// L'écran de réunion s'ouvre désormais **avant** que la réunion existe :
  /// entre le clic et l'entrée dans la salle, le bouton « raccrocher » est déjà
  /// là. Une création encore en vol s'en sert pour constater qu'elle est
  /// devenue sans objet, plutôt que de ressusciter ce que le nettoyage vient de
  /// solder — une réunion sans écran, tenant caméra et micro.
  int _generation = 0;

  /// Ce qu'on sait de la réunion dès le clic, avant la réponse du serveur :
  /// sa nature média, et qui l'organise.
  ///
  /// L'écran s'ouvre pendant que le POST est en vol. Sans ces deux-là, il
  /// déciderait des commandes caméra et du bouton « terminer pour tous » sur
  /// une réunion qu'il ne connaît pas encore — et les verrait changer sous lui
  /// à l'arrivée de la réponse.
  int? _typeMediaVoulu;
  int? _idOrganiseurVoulu;

  // Médias locaux & WebRTC peers
  MediaStream? _localStream;
  /// Acquisition caméra/micro en vol, partagée par ceux qui l'attendent.
  Future<MediaStream?>? _mediasEnVol;
  final Map<String, RTCPeerConnection> _peerConnections = {};

  // Streams distants 
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, List<RTCIceCandidate>> _pendingIceByPeer = {};
  final Set<String> _remoteDescSetForPeer = <String>{};

  /// Pairs à qui les pistes locales ont déjà été attachées.
  final Set<String> _tracksAddedForPeer = <String>{};

  // Contrôles
  bool _isMuted = false;
  bool _isVideoOff = false;

  // États mute des participants distants (userId → isMuted)
  final Map<String, bool> _remoteMutedStates = {};

  // États caméra des participants distants (userId → isVideoOff)
  final Map<String, bool> _remoteVideoStates = {};

  // ID local pendant la réunion + attente confirmation room_joined
  String? _myId;
  Completer<void>? _roomJoinCompleter;

  // Timer de durée
  Timer? _durationTimer;
  int _meetingDuration = 0;

  // Messages in-meeting
  final List<ChatMessage> _chatMessages = [];
  int _unreadChatCount = 0;
  bool _isMeetingChatOpen = false;

  // Noms des participants connectés (alanyaID → nom affiché).
  final Map<String, String> _participantRoster = {};

  /// Qui est réellement dans la salle, moi compris.
  ///
  /// La feuille des participants croisait les clés de `remoteStreams` avec un
  /// `connecte` figé, rechargé seulement à l'occasion d'une invitation : un
  /// arrivant dont le flux n'était pas encore négocié passait pour absent, et
  /// un flux mort survivait à son propriétaire. Ni l'un ni l'autre ne dit qui
  /// est là — la salle, elle, le sait.
  final Set<String> _presents = {};

  // UI minimisée (bannière flottante active).
  bool _isMeetingUiMinimized = false;
  bool _isMeetingUiRouteOpen = false;

  // Détection locale du locuteur actif (mesh meeting).
  final SpeakingDetector speakingDetector = SpeakingDetector();

  // Getters 
  MeetingStatus get status => _status;
  Meeting? get currentMeeting => _currentMeeting;
  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  Map<String, bool> get remoteMutedStates => Map.unmodifiable(_remoteMutedStates);
  bool isParticipantMuted(String userId) => _remoteMutedStates[_participantId(userId)] ?? false;
  Map<String, bool> get remoteVideoStates => Map.unmodifiable(_remoteVideoStates);
  bool isParticipantVideoOff(String userId) => _remoteVideoStates[_participantId(userId)] ?? false;
  int get meetingDuration => _meetingDuration;
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  int get unreadChatCount => _unreadChatCount;
  Map<String, String> get participantRoster => Map.unmodifiable(_participantRoster);

  /// Identifiants des participants présents dans la salle, moi compris.
  Set<String> get presentIds => Set.unmodifiable(_presents);

  /// Résout le nom affiché d'un participant (liste API + roster temps réel).
  String participantDisplayName(String userId) {
    final participant = _currentMeeting?.participants
        .where((p) => p.participantID.toString() == userId)
        .firstOrNull;
    final fromList = participant?.displayNom;
    if (fromList != null && fromList.isNotEmpty) return fromList;
    final fromRoster = _participantRoster[userId];
    if (fromRoster != null && fromRoster.isNotEmpty) return fromRoster;
    return 'User $userId';
  }

  /// URL d'avatar d'un participant (liste API + organisateur).
  String? participantAvatarUrl(String userId) {
    final meeting = _currentMeeting;
    if (meeting == null) return null;
    if (meeting.idOrganiser.toString() == userId) {
      return meeting.organiserAvatar;
    }
    final participant = meeting.participants
        .where((p) => p.participantID.toString() == userId)
        .firstOrNull;
    return participant?.avatarUrl;
  }

  /// Notre identifiant pendant la réunion.
  ///
  /// C'est la clé qui corrèle socket et WebRTC — celle de `_participantId`, donc
  /// celle des tuiles. `AuthProvider` en donne une autre, prise du compte : elle
  /// coïncide en pratique, mais divergerait si le compte changeait en cours de
  /// session. L'écran d'appel expose déjà l'équivalent (`localUserId`).
  String? get myId => _myId;

  Set<String> get activeSpeakers => speakingDetector.activeSpeakers;
  bool get amISpeaking => speakingDetector.amISpeaking;
  bool isUserSpeaking(String userId) => speakingDetector.isSpeaking(userId);

  bool get isMeetingActive =>
      _status == MeetingStatus.joining || _status == MeetingStatus.connected;

  /// La réunion est-elle encore en train de s'ouvrir ?
  bool get isJoining => _status == MeetingStatus.joining;

  /// `type_media` de la réunion : celui du serveur dès qu'il est connu, sinon
  /// celui qu'on a demandé. Null quand aucune réunion n'est en cours.
  int? get typeMediaEnCours => _currentMeeting?.typeMedia ?? _typeMediaVoulu;

  /// Organisateur de la réunion, connu dès la création pour la même raison.
  int? get idOrganiseurEnCours =>
      _currentMeeting?.idOrganiser ?? _idOrganiseurVoulu;

  bool get isMeetingUiMinimized => _isMeetingUiMinimized;

  bool get isMeetingUiRouteOpen => _isMeetingUiRouteOpen;

  bool get shouldShowMeetingBanner =>
      isMeetingActive && _isMeetingUiMinimized;

  void markMeetingUiVisible() {
    _isMeetingUiRouteOpen = true;
    _isMeetingUiMinimized = false;
    notifyListeners();
  }

  void markMeetingUiMinimized() {
    _isMeetingUiRouteOpen = false;
    _isMeetingUiMinimized = true;
    notifyListeners();
  }

  void markMeetingUiClosed() {
    _isMeetingUiRouteOpen = false;
    notifyListeners();
  }

  /// Ouvre le chat meeting : remet le compteur non-lu à zéro.
  void markMeetingChatOpen() {
    _isMeetingChatOpen = true;
    markChatRead();
  }

  /// Referme le chat meeting (sheet fermée).
  void markMeetingChatClosed() {
    if (!_isMeetingChatOpen) return;
    _isMeetingChatOpen = false;
    notifyListeners();
  }

  /// Remet à zéro les messages non lus du chat meeting.
  void markChatRead() {
    if (_unreadChatCount == 0) return;
    _unreadChatCount = 0;
    notifyListeners();
  }

  /// Clé canonique pour corréler WebRTC (fromUserID) et socket (userId).
  String _participantId(String userId) {
    final parsed = int.tryParse(userId);
    return parsed?.toString() ?? userId;
  }

  Future<void> showMeetingScreen() async {
    if (!isMeetingActive || _isMeetingUiRouteOpen) return;

    final navigator = appNavigator;
    if (navigator == null) return;

    await navigator.push(
      MaterialPageRoute(builder: (_) => const OngoingMeetScreen()),
    );

    markMeetingUiClosed();
    if (isMeetingActive && !_isMeetingUiMinimized) {
      markMeetingUiMinimized();
    }
  }

  Future<void> navigateToMeetingUi([BuildContext? context]) async {
    if (context != null && !context.mounted) return;
    if (!isMeetingActive || _isMeetingUiRouteOpen) return;
    await showMeetingScreen();
  }

  MeetingService({required TalkyApiClient apiClient}) : _apiClient = apiClient {
    _setupSocketListeners();
    // Le détecteur est un ChangeNotifier séparé : on relaie ses
    // changements pour que les écrans (Consumer<MeetingService>) se
    // reconstruisent quand le locuteur actif change.
    speakingDetector.addListener(notifyListeners);
  }


  void _setupSocketListeners() {
    // Reprise après une coupure réseau.
    //
    // À l'authentification, le serveur ne remet la socket que dans `user_<id>`
    // et dans la room de son appareil : celle de la réunion meurt avec la
    // socket tombée. Les relais média restent adressés à l'utilisateur et
    // continuent de passer, ce qui donne le change — mais arrivées, départs,
    // micro, caméra, messages et fin de réunion sont diffusés à la salle, et
    // n'atteignaient plus personne. Pendant ce temps la grâce de quinze
    // secondes armée côté serveur expirait, et les autres voyaient partir
    // quelqu'un qui se croyait toujours là.
    _apiClient.onSocketEvent(SocketEvents.authVerified, (_) {
      _rejoinMeetingRoomIfNeeded();
    });

    // Confirmation que la room a été rejointe (inclut snapshot muteStates)
    _apiClient.onSocketEvent(SocketEvents.meetingRoomJoined, (data) {
      debugPrint('[MeetingService] Room rejointe: $data');
      if (data is Map) {
        _applyMuteStatesSnapshot(data['muteStates']);
        _applyVideoStatesSnapshot(data['videoStates']);
        // Les instantanés micro/caméra sont l'annuaire de la salle : le serveur
        // purge l'entrée d'un partant (`meeting:leave` comme expiration de la
        // grâce), donc leurs clés sont exactement les présents, moi excepté.
        _seedPresentsFromSnapshot(data['muteStates']);
        _seedPresentsFromSnapshot(data['videoStates']);
        notifyListeners();
      }
      if (_roomJoinCompleter != null && !_roomJoinCompleter!.isCompleted) {
        _roomJoinCompleter!.complete();
      }
    });

    _apiClient.onSocketEvent(SocketEvents.meetingJoinDenied, (data) async {
      final code = (data is Map ? data['code'] : null)?.toString();
      debugPrint('[MeetingService] join_denied code=$code');
      if (_roomJoinCompleter != null && !_roomJoinCompleter!.isCompleted) {
        _roomJoinCompleter!.completeError(
          StateError(code ?? 'ACCOUNT_ALREADY_IN_MEETING'),
        );
      }
      // Ne pas emit leave (jamais entré) — cleanup local seulement.
      await _terminateMeeting(emitLeave: false);
    });

    // Un nouveau participant vient de rejoindre → enrichir le roster + WebRTC
    _apiClient.onSocketEvent(SocketEvents.meetingUserJoined, (data) async {
      if (data is! Map) return;
      final userId = data['userID']?.toString();
      if (userId == null) return;

      var changed = false;
      if (_presents.add(_participantId(userId))) changed = true;
      final displayName = data['userName']?.toString() ??
          data['nom']?.toString() ??
          data['pseudo']?.toString();
      if (displayName != null && displayName.isNotEmpty) {
        _participantRoster[userId] = displayName;
        changed = true;
      }

      if (data.containsKey('isMuted')) {
        _applyRemoteMuteState(userId, data['isMuted'] == true);
        changed = true;
      }

      if (data.containsKey('isVideoOff')) {
        _remoteVideoStates[_participantId(userId)] = data['isVideoOff'] == true;
        changed = true;
      }

      if (changed) notifyListeners();

      // Informer le nouvel arrivant de nos états micro/caméra actuels
      _broadcastMuteState();
      _broadcastVideoState();

      if (_peerConnections.containsKey(userId)) return;
      await _createPeerAndOffer(userId);
    });

    // Un participant quitte
    _apiClient.onSocketEvent(SocketEvents.meetingUserLeft, (data) {
      if (data is! Map) return;
      final userId = data['userID']?.toString();
      if (userId != null) {
        _participantRoster.remove(userId);
        _presents.remove(_participantId(userId));
        _removePeer(userId);
      }
    });

    // Réunion terminée par l'organisateur
    _apiClient.onSocketEvent(SocketEvents.meetingEnded, (data) {
      final recu = data is Map ? data['meetingID'] : null;
      if (!endsCurrentMeeting(
        currentMeetingId: _currentMeeting?.idMeeting,
        eventMeetingId: recu,
        meetingStatusName: _status.name,
      )) {
        debugPrint('[MeetingService] 🛡 meeting:ended ignoré: reçu=$recu '
            'courante=${_currentMeeting?.idMeeting} status=$_status');
        return;
      }
      _terminateMeeting(emitLeave: false);
    });

    // Message chat in-meeting
    _apiClient.onSocketEvent(SocketEvents.meetingMessage, (data) {
      if (data is! Map) return;
      final userId = data['userID']?.toString() ?? '';
      _chatMessages.add(ChatMessage(
        userId: userId,
        message: data['message']?.toString() ?? '',
        sendAt: DateTime.tryParse(data['sendAt']?.toString() ?? '') ?? DateTime.now(),
      ));
      final isFromMe = _myId != null && userId == _myId;
      if (!isFromMe && !_isMeetingChatOpen) {
        _unreadChatCount++;
      }
      notifyListeners();
    });

    // WebRTC : offer reçue d'un pair
    _apiClient.onSocketEvent(SocketEvents.meetingOffer, (data) async {
      if (data is! Map) return;
      // !! Champ correct du backend : fromUserID
      final fromUserId = data['fromUserID']?.toString();
      final offer = data['offer'] as Map?;
      if (fromUserId == null || offer == null) return;
      await _handleOffer(fromUserId, offer);
    });

    // WebRTC : answer reçue d'un pair
    _apiClient.onSocketEvent(SocketEvents.meetingAnswer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserID']?.toString();
      final answer = data['answer'] as Map?;
      if (fromUserId == null || answer == null) return;
      final pc = _peerConnections[fromUserId];
      if (pc != null) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
        _remoteDescSetForPeer.add(fromUserId);
        await _flushPendingIce(fromUserId);
      }
    });

    // WebRTC : ICE candidate reçu
    _apiClient.onSocketEvent(SocketEvents.meetingIceCandidate, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserID']?.toString();
      final c = data['candidate'] as Map?;
      if (fromUserId == null || c == null) return;
      final candidate = RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      );
      final pc = _peerConnections[fromUserId];
      if (pc == null || !_remoteDescSetForPeer.contains(fromUserId)) { 
        _pendingIceByPeer.putIfAbsent(fromUserId, () => []).add(candidate);
        return;
      }
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('[MeetingService] addCandidate échoué pour $fromUserId: $e');
      }
    });

    // Mute state : un participant a coupé/réactivé son micro
    _apiClient.onSocketEvent(SocketEvents.meetingMuteState, (data) {
      if (data is! Map) return;
      final userId = data['userId']?.toString();
      final isMuted = data['isMuted'] == true;
      if (userId == null) return;
      debugPrint('[MeetingService] 🎙 Mute state: userId=$userId isMuted=$isMuted');
      _applyRemoteMuteState(userId, isMuted);
      notifyListeners();
    });

    // Video state : un participant a coupé/réactivé sa caméra
    _apiClient.onSocketEvent(SocketEvents.meetingVideoState, (data) {
      debugPrint('[MeetingService] 📷 RAW video_state reçu: $data');
      if (data is! Map) return;
      final rawId = data['userId']?.toString() ?? data['userID']?.toString();
      if (rawId == null || rawId.isEmpty) return;
      final userId = _participantId(rawId);
      final isVideoOff = data['isVideoOff'] == true;
      _remoteVideoStates[userId] = isVideoOff;
      debugPrint(
        '[MeetingService] 📷 Video state appliqué: userId=$userId '
        'isVideoOff=$isVideoOff | peers=${_remoteStreams.keys.toList()} '
        'states=$_remoteVideoStates',
      );
      notifyListeners();
    });
  }

  /// Redemande sa place dans la salle après une reconnexion.
  ///
  /// Rejouer `meeting:join_room` est le geste attendu par le serveur : il
  /// annule la grâce encore armée, ou reprend la place si elle a déjà expiré,
  /// et prévient les autres par `meeting:user_joined` — ceux qui avaient déjà
  /// retiré le partant refont alors leur lien avec lui.
  void _rejoinMeetingRoomIfNeeded() {
    final reunion = _currentMeeting;
    final myId = _myId;
    if (reunion == null || myId == null) return;
    if (_status != MeetingStatus.connected && _status != MeetingStatus.joining) {
      return;
    }
    debugPrint('[MeetingService] 🔄 socket revenu → rejoin réunion ${reunion.idMeeting}');
    _apiClient.sendSocketEvent(SocketEvents.meetingJoinRoom, {
      'meetingID': reunion.idMeeting,
      'userID': int.tryParse(myId) ?? myId,
      'userName': _participantRoster[myId] ?? '',
      'isMuted': _isMuted,
      'isVideoOff': _isVideoOff,
    });
  }

  void _applyRemoteMuteState(String userId, bool isMuted) {
    _remoteMutedStates[_participantId(userId)] = isMuted;
    speakingDetector.setSpeakerMuted(userId, isMuted);
  }

  void _applyMuteStatesSnapshot(dynamic muteStates) {
    if (muteStates is! Map) return;
    muteStates.forEach((key, value) {
      _applyRemoteMuteState(key.toString(), value == true);
    });
  }

  /// Ajoute aux présents les identifiants d'un instantané d'état.
  ///
  /// Limite connue : un participant qui n'aurait jamais annoncé ses états
  /// micro/caméra n'y figurerait pas. Le client les envoie toujours, dans le
  /// `join_room` lui-même — le cas n'existe pas aujourd'hui, mais il existerait
  /// avec un autre client. La correction robuste serait une liste de présents
  /// dans le payload `meeting:room_joined`, côté serveur.
  void _seedPresentsFromSnapshot(dynamic states) {
    if (states is! Map) return;
    for (final key in states.keys) {
      final id = _participantId(key.toString());
      if (id.isNotEmpty) _presents.add(id);
    }
  }

  void _applyVideoStatesSnapshot(dynamic videoStates) {
    if (videoStates is! Map) return;
    videoStates.forEach((key, value) {
      _remoteVideoStates[_participantId(key.toString())] = value == true;
    });
  }

  void _syncLocalMediaFromTracks() {
    if (_localStream == null) return;
    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isNotEmpty) {
      _isMuted = !audioTracks.first.enabled;
      speakingDetector.setSpeakerMuted(SpeakingDetector.localKey, _isMuted);
    }
    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isNotEmpty) {
      _isVideoOff = !videoTracks.first.enabled;
    }
  }

  void _broadcastMuteState() {
    if (_currentMeeting == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingMuteState, {
      'meetingId': _currentMeeting!.idMeeting,
      'isMuted': _isMuted,
    });
  }

  void _broadcastVideoState() {
    if (_currentMeeting == null) return;
    debugPrint(
      '[MeetingService] 📷 Broadcast video state: isVideoOff=$_isVideoOff '
      'meeting=${_currentMeeting!.idMeeting}',
    );
    _apiClient.sendSocketEvent(SocketEvents.meetingVideoState, {
      'meetingId': _currentMeeting!.idMeeting,
      'isVideoOff': _isVideoOff,
    });
  }

  Future<void> _flushPendingIce(String userId) async {
    final pc = _peerConnections[userId];
    final pending = _pendingIceByPeer.remove(userId);
    if (pc == null || pending == null || pending.isEmpty) return;
    for (final c in pending) {
      try {
        await pc.addCandidate(c);
      } catch (e) {
        debugPrint('[MeetingService] addCandidate (flush) échoué pour $userId: $e');
      }
    }
  }

  Future<List<Meeting>> getMeetings() async {
    final data = await _apiClient.getMeetings();
    return data
        .whereType<Map<String, dynamic>>()
        .map(Meeting.fromJson)
        .toList();
  }

  /// Recharge les détails de la réunion en cours (participants avec noms).
  Future<void> refreshCurrentMeeting() async {
    final id = _currentMeeting?.idMeeting;
    if (id == null) return;
    await _reloadCurrentMeeting(id);
  }

  /// Invite des participants puis rafraîchit la liste locale.
  Future<void> inviteParticipants(List<int> participantIds) async {
    final id = _currentMeeting?.idMeeting;
    if (id == null || participantIds.isEmpty) return;
    await _apiClient.inviteParticipants(id, participantIds);
    await _reloadCurrentMeeting(id);
  }

  Future<void> _reloadCurrentMeeting(int idMeeting) async {
    try {
      final data = await _apiClient.getMeeting(idMeeting);
      _currentMeeting = Meeting.fromJson(data);
      _seedRosterFromMeeting();
      notifyListeners();
    } catch (e) {
      debugPrint('[MeetingService] Erreur reload meeting: $e');
    }
  }

  void _seedRosterFromMeeting() {
    final meeting = _currentMeeting;
    if (meeting == null) return;

    final organiserName = meeting.organiserNom ?? meeting.organiserPseudo;
    if (organiserName != null && organiserName.isNotEmpty) {
      _participantRoster[meeting.idOrganiser.toString()] = organiserName;
    }

    for (final p in meeting.participants) {
      final name = p.displayNom;
      if (name != null && name.isNotEmpty) {
        _participantRoster[p.participantID.toString()] = name;
      }
    }
  }

  Future<void> createAndJoin({
    required String objet,
    required String startTime, 
    required String room,
    required int myId,
    required String myName,
    int duree = 60,
    int typeMedia = 0,
  }) async {
    _status = MeetingStatus.joining;
    _typeMediaVoulu = typeMedia;
    _idOrganiseurVoulu = myId;
    final generation = _generation;
    notifyListeners();

    // La caméra et le micro s'ouvrent **pendant** les allers-retours HTTP, pas
    // après : c'est le poste le plus long des deux — permissions, ouverture du
    // capteur, première trame — et rien dans `getUserMedia` n'a besoin de
    // connaître la réunion. `_joinRoom` récupère la même acquisition au lieu
    // d'en lancer une seconde.
    final medias = prepareLocalMedia(video: typeMedia == 0);

    /// Solde une réunion créée puis quittée avant qu'on y soit entré.
    ///
    /// Elle existe côté serveur et rien ne l'a terminée : sans ce geste, elle
    /// resterait « en cours » dans la liste sans que personne n'y ait jamais
    /// mis les pieds.
    Future<void> abandonner(int idReunion) async {
      unawaited(_fermerReunionAbandonnee(idReunion));
      await medias;
      // Sans effet si une autre réunion a démarré depuis : elle a repris ce
      // flux, et `releaseLocalMediaIfNotJoined` refuse de le lui retirer.
      await releaseLocalMediaIfNotJoined();
    }

    try {
      final data = await _apiClient.createMeeting(
        objet: objet,
        startTime: startTime,
        room: room,
        duree: duree,
        typeMedia: typeMedia,
      );
      // Gardée hors de `_currentMeeting` : quand la génération a tourné, ce
      // champ appartient au nettoyage — ou déjà à une autre réunion.
      final reunion = Meeting.fromJson(data);
      if (generation != _generation) {
        await abandonner(reunion.idMeeting);
        return;
      }
      _currentMeeting = reunion;
      _seedRosterFromMeeting();
      // La réunion est connue : l'écran peut afficher son objet et ses
      // commandes sans attendre l'entrée dans la salle.
      notifyListeners();
      await _apiClient.joinMeetingHttp(reunion.idMeeting);
      if (generation != _generation) {
        await abandonner(reunion.idMeeting);
        return;
      }
      await _reloadCurrentMeeting(reunion.idMeeting);
      if (generation != _generation) {
        await abandonner(reunion.idMeeting);
        return;
      }
      await _joinRoom(myId: myId, myName: myName);
    } catch (e) {
      debugPrint('[MeetingService] Erreur createAndJoin: $e');
      // La réunion a pu être quittée pendant l'échec : ne pas repasser au
      // statut terminal d'une session qui n'est plus la nôtre.
      if (generation == _generation) {
        _status = MeetingStatus.ended;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Solde côté serveur une réunion créée puis abandonnée avant l'entrée.
  ///
  /// Silencieux à dessein : personne n'attend ce résultat, et l'écran est déjà
  /// refermé quand il arrive.
  Future<void> _fermerReunionAbandonnee(int idMeeting) async {
    try {
      await _apiClient.updateMeetingEnd(idMeeting);
      debugPrint('[MeetingService] réunion abandonnée refermée: $idMeeting');
    } catch (e) {
      debugPrint('[MeetingService] fermeture réunion abandonnée échouée: $e');
    }
  }

  /// Prépare le stream local (caméra/micro) avant de rejoindre.
  ///
  /// Deux appelants peuvent la réclamer en même temps — la création lance
  /// l'acquisition en parallèle des appels HTTP, `_joinRoom` la réclame
  /// ensuite. Ils attendent alors la même, plutôt que d'ouvrir deux fois le
  /// capteur.
  Future<MediaStream?> prepareLocalMedia({required bool video}) {
    if (_localStream != null) return Future.value(_localStream);
    return _mediasEnVol ??= _ouvrirMediasLocaux(video: video)
        .whenComplete(() => _mediasEnVol = null);
  }

  Future<MediaStream?> _ouvrirMediasLocaux({required bool video}) async {
    try {
      if (!kIsWeb) {
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          throw Exception(LocaleController.instance.l10n.microphonePermissionDenied);
        }
        if (video) {
          await Permission.camera.request();
        }
      }

      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        if (video)
          'video': videoCaptureConstraints(),
      };

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _isVideoOff = !video;
      debugPrint('[MeetingService] !! prepareLocalMedia: ${_localStream?.getTracks().length} tracks');
      notifyListeners();
      return _localStream;
    } catch (e) {
      debugPrint('[MeetingService] ** prepareLocalMedia: $e');
      return null;
    }
  }

  /// Libère le stream préparé si l'utilisateur quitte le lobby sans rejoindre.
  Future<void> releaseLocalMediaIfNotJoined() async {
    if (_status == MeetingStatus.connected || _status == MeetingStatus.joining) {
      return; 
    }
    if (_localStream != null) {
      for (final t in _localStream!.getTracks()) {
        await t.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }
    _isVideoOff = false;
    notifyListeners();
  }

  /// Rejoint une réunion existante par son [idMeeting].
  /// [myId] est le alanyaID de l'utilisateur connecté.
  /// Si [prepareLocalMedia] a déjà été appelé, le stream existant est réutilisé.
  Future<void> joinMeeting({
    required int idMeeting,
    required int myId,
    required String myName,
  }) async {
    _status = MeetingStatus.joining;
    notifyListeners();

    try {
      // Récupérer les détails de la réunion
      final data = await _apiClient.getMeeting(idMeeting);
      _currentMeeting = Meeting.fromJson(data);
      _seedRosterFromMeeting();

      // Rejoindre en DB
      await _apiClient.joinMeetingHttp(idMeeting);

      // Rejoindre la room socket
      await _joinRoom(myId: myId, myName: myName);
    } catch (e) {
      debugPrint('[MeetingService] Erreur joinMeeting: $e');
      _status = MeetingStatus.ended;
      notifyListeners();
      rethrow;
    }
  }

  // `joinByRoom` a été retirée : aucun écran n'offrait d'entrer par code de
  // salon, et elle était le seul appelant de `getMeetingByRoom`. La route
  // serveur subsiste, réservée aux participants depuis le durcissement des
  // autorisations — elle servira si un lien d'invitation voit le jour.

  Future<void> _joinRoom({required int myId, required String myName}) async {
    // Une acquisition lancée en parallèle de la création est probablement déjà
    // finie ; sinon on l'attend, on n'en ouvre pas une seconde.
    final enVol = _mediasEnVol;
    if (_localStream == null && enVol != null) {
      await enVol;
    }
    if (_localStream == null) {
      await _initLocalStream();
    }

    _myId = myId.toString();
    _presents.add(_participantId(_myId!));
    _syncLocalMediaFromTracks();

    if (myName.isNotEmpty) {
      _participantRoster[_myId!] = myName;
    }

    _roomJoinCompleter = Completer<void>();
    _apiClient.sendSocketEvent(SocketEvents.meetingJoinRoom, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': myId,
      'userName': myName,
      'isMuted': _isMuted,
      'isVideoOff': _isVideoOff,
    });

    try {
      await _roomJoinCompleter!.future.timeout(const Duration(seconds: 10));
    } on StateError catch (e) {
      debugPrint('[MeetingService] join denied: $e');
      rethrow;
    } catch (_) {
      debugPrint('[MeetingService] Timeout attente room_joined');
    } finally {
      _roomJoinCompleter = null;
    }

    _broadcastMuteState();
    _broadcastVideoState();

    _status = MeetingStatus.connected;
    _startDurationTimer();
    speakingDetector.start(() => _peerConnections);

    if (!kIsWeb && _currentMeeting != null) {
      final isVideo = _currentMeeting!.typeMedia == 0;
      final pris = await CallSessionGuard.instance.acquire(
        mode: isVideo ? SessionMode.video : SessionMode.audio,
        callId: 'meeting_${_currentMeeting!.idMeeting}',
        displayName: _currentMeeting!.objet,
        handle: _currentMeeting!.room,
        isVideo: isVideo,
        getLocalStream: () => _localStream,
        isVideoOn: () => !_isVideoOff,
        isMuted: () => _isMuted,
        // Dans une réunion, « Raccrocher » veut dire la quitter — surtout pas
        // terminer un appel, qui n'existe pas ici.
        onHangUp: () => leaveMeeting(),
      );
      if (pris) {
        await CallSessionGuard.instance.markConnected();
        await _bindSessionRenderers(isVideo: isVideo);
      } else {
        // Un appel tient déjà la session média. La réunion se poursuivait quand
        // même : sans entrée CallKit, sans focus audio, sans fenêtre flottante
        // (`_bindSessionRenderers` n'était pas appelé) — et sans un mot à
        // l'utilisateur, un `debugPrint` pour tout signal.
        //
        // On refuse d'entrer plutôt que d'offrir une réunion amputée. Ce n'est
        // PAS un endroit où libérer les rendus : `SessionVideoRenderers` est un
        // singleton partagé avec l'appel, et la garde `holdsSession` du cleanup
        // existe précisément pour ne pas démonter la fenêtre d'un appel bien
        // vivant. La fuite disparaît parce qu'on n'entre pas, pas parce qu'on
        // nettoie derrière soi.
        debugPrint(
          '[MeetingService] ⛔ session média refusée — un appel est en cours',
        );
        await _terminateMeeting(emitLeave: true);
        throw StateError('SESSION_BUSY');
      }
    }

    notifyListeners();
  }
 

  /// Envoie un message chat dans la réunion.
  void sendChatMessage(String message, int myId) {
    if (_currentMeeting == null) return;
    // On rejoint une réunion sur invitation sans abonnement, on n'y écrit pas.
    // Le serveur refuserait sans accusé : le refus se dit ici.
    if (!EntitlementService.allowsOutgoing) {
      EntitlementService.maybeInstance?.reportOutgoingBlocked();
      return;
    }

    // !! Champs corrects : meetingID, userID
    _apiClient.sendSocketEvent(SocketEvents.meetingChat, {
      'meetingID': _currentMeeting!.idMeeting,
      'userID': myId.toString(),
      'message': message,
    });
  }

  /// Termine la réunion pour tout le monde (organisateur seulement).
  Future<void> endMeetingForAll() async {
    final reunion = _currentMeeting;
    if (reunion == null) return;
    _apiClient.sendSocketEvent(SocketEvents.meetingEnd, {
      'meetingID': reunion.idMeeting,
    });
    // Repli : la fin pour tous n'existait que par socket, et l'écran se fermait
    // dans tous les cas. Socket tombée — ce qui arrive sans que rien ne le dise,
    // voir `shouldRebuildSocketDuringReconnect` —, `isEnd` restait 0 : la
    // réunion réapparaissait « en cours » au chargement suivant, et restait
    // rejoignable. L'échec est silencieux à dessein : le chemin socket a
    // probablement déjà fait le travail.
    try {
      await _apiClient.updateMeetingEnd(reunion.idMeeting);
    } catch (e) {
      debugPrint('[MeetingService] repli HTTP isEnd échoué: $e');
    }
    await _terminateMeeting(emitLeave: false);
  }

  /// Quitte la réunion (côté participant).
  Future<void> leaveMeeting() async {
    await _terminateMeeting(emitLeave: true);
  }

  Future<void> _terminateMeeting({required bool emitLeave}) async {
    // Avant tout `await` : une création encore en vol doit constater sa
    // péremption au premier point de reprise, pas trois requêtes plus tard.
    _generation++;

    if (emitLeave && _currentMeeting != null) {
      // !! Payload exact : meetingID
      _apiClient.sendSocketEvent(SocketEvents.meetingLeave, {
        'meetingID': _currentMeeting!.idMeeting,
      });
      // Mettre à jour l'état en DB
      try {
        await _apiClient.leaveMeetingHttp(_currentMeeting!.idMeeting);
      } catch (e) {
        debugPrint('[MeetingService] leaveMeetingHttp error: $e');
      }
    }

    // Le statut DOIT passer à `ended` même si un imprévu survient dans le
    // cleanup, sinon l'écran de réunion ne se referme jamais (le listener et le
    // bouton dépendent de MeetingStatus.ended pour faire le pop()).
    try {
      await _cleanup();
    } catch (e) {
      debugPrint('[MeetingService] _cleanup error: $e');
    } finally {
      _status = MeetingStatus.ended;
      notifyListeners();
      // Puis `idle`, comme `CallService` le fait depuis toujours
      // (call_one_to_one.dart). Le service s'arrêtait à `ended`, et `idle`
      // n'était plus jamais écrit après la déclaration du champ : la bannière
      // de session, qui attend précisément ce statut pour annoncer « Réunion
      // terminée », ne l'annonçait donc jamais quand la réunion était minimisée.
      //
      // Les deux notifications sont nécessaires : la première ferme l'écran
      // (voir shouldPopMeetingScreen, qui accepte les deux statuts), la seconde
      // laisse la bannière constater la fin. La microtâche garantit que la
      // première a été traitée avant que la seconde parte.
      _status = MeetingStatus.idle;
      await Future.microtask(() {});
      notifyListeners();
    }
  }

  // WEBRTC
  
  Future<void> _initLocalStream() async {
    try {
      debugPrint('[MeetingService] Initialisation du stream local...');
      debugPrint('[MeetingService] isWeb: $kIsWeb');

      final isVideoMeeting = _currentMeeting?.typeMedia == 0;

      // Demander les permissions si mobile
      if (!kIsWeb) {
        final micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          throw Exception(LocaleController.instance.l10n.microphonePermissionDenied);
        }

        if (isVideoMeeting) {
          final cameraStatus = await Permission.camera.request();
          if (!cameraStatus.isGranted) {
            debugPrint('[MeetingService] ** Permission caméra refusée');
          }
        }
      }

      // Obtenir le media stream avec constraints
      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
      };

      if (isVideoMeeting) {
        constraints['video'] = {
          ...videoCaptureConstraints(),
        };
      }

      debugPrint('[MeetingService] Appel getUserMedia avec contraintes: $constraints');
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      if (!isVideoMeeting) _isVideoOff = true;
      debugPrint('[MeetingService] !! Stream local obtenu: ${_localStream?.getTracks().length} tracks');
      notifyListeners();
    } catch (e) {
      debugPrint('[MeetingService] ** Erreur _initLocalStream: $e');
      debugPrint('[MeetingService] Type: ${e.runtimeType}');

      // Ce bloc classait la panne sur cinq branches, écrivait le message dans
      // un `debugPrint`… puis faisait `rethrow`. Le message était donc calculé
      // pour rien, et c'est l'exception nue qui remontait au lobby, lequel
      // l'affichait : « Impossible de rejoindre : NotReadableError: Could not
      // start video source ». La classification voyage désormais avec elle.
      throw AppError(kind: kindPourException(e), cause: e);
    }
  }

  Future<void> _createPeerAndOffer(String userId) async {
    final pc = await _createPeerConnection(userId);

    _addLocalTracksOnce(pc, userId);

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // !! Champs corrects : meetingID, toUserID
    _apiClient.sendSocketEvent(SocketEvents.meetingOffer, {
      'meetingID': _currentMeeting!.idMeeting,
      'toUserID': userId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  /// Ajoute les pistes locales une seule fois par pair.
  ///
  /// `_createPeerConnection` rend la connexion existante quand il y en a une :
  /// une renégociation — offre reçue d'un pair qui, lui, est reparti d'une
  /// connexion neuve — repassait alors ici et rajoutait micro et caméra à des
  /// émetteurs qui les portaient déjà. La réponse partait avec des `m=` en
  /// double et la piste distante changeait d'index en cours de réunion.
  void _addLocalTracksOnce(RTCPeerConnection pc, String userId) {
    if (!_tracksAddedForPeer.add(userId)) return;
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });
  }

  Future<void> _handleOffer(String fromUserId, Map offer) async {
    final pc = await _createPeerConnection(fromUserId);

    await pc.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, 'offer'),
    );
    _remoteDescSetForPeer.add(fromUserId);
    await _flushPendingIce(fromUserId);

    _addLocalTracksOnce(pc, fromUserId);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    // !! Champs corrects : meetingID, toUserID
    _apiClient.sendSocketEvent(SocketEvents.meetingAnswer, {
      'meetingID': _currentMeeting!.idMeeting,
      'toUserID': fromUserId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String userId) async {
    if (_peerConnections.containsKey(userId)) {
      return _peerConnections[userId]!;
    }

    final iceServers = await _apiClient.fetchIceServers();
    final pc = await createPeerConnection({'iceServers': iceServers});

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[userId] = event.streams[0];
        notifyListeners();
      }
    };

    pc.onIceCandidate = (candidate) {
      // !! Champs corrects : meetingID, toUserID
      _apiClient.sendSocketEvent(SocketEvents.meetingIceCandidate, {
        'meetingID': _currentMeeting!.idMeeting,
        'toUserID': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onConnectionState = (state) {
      debugPrint('[MeetingService] Peer $userId connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _removePeer(userId);
      }
    };

    _peerConnections[userId] = pc;
    return pc;
  }

  void _removePeer(String userId) {
    _peerConnections[userId]?.close();
    _peerConnections.remove(userId);
    _tracksAddedForPeer.remove(userId);
    _remoteStreams.remove(userId);
    _pendingIceByPeer.remove(userId);
    _remoteDescSetForPeer.remove(userId);
    _remoteMutedStates.remove(_participantId(userId));
    _remoteVideoStates.remove(_participantId(userId));
    notifyListeners();
  }

  // MÉDIAS 

  Future<void> toggleMute() async {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final track = _localStream!.getAudioTracks().first;
      track.enabled = !track.enabled;
      _isMuted = !track.enabled;
      speakingDetector.setSpeakerMuted(SpeakingDetector.localKey, _isMuted);
      // Notifier les autres participants
      if (_currentMeeting != null) {
        _broadcastMuteState();
      }
      notifyListeners();
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final track = _localStream!.getVideoTracks().first;
      _isVideoOff = !_isVideoOff;
      track.enabled = !_isVideoOff;
      if (_currentMeeting != null) {
        _broadcastVideoState();
      }
      notifyListeners();
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final track = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(track);
    }
  }

  // TIMER 
  void _startDurationTimer() {
    _meetingDuration = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _meetingDuration++;
      notifyListeners();
    });
  }

  String get formattedDuration {
    final m = _meetingDuration ~/ 60;
    final s = _meetingDuration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Ouvre les rendus vidéo pour la durée de la réunion.
  ///
  /// Même bascule que pour les appels : ils appartenaient à
  /// `_OngoingMeetScreenState` et mouraient avec lui, ce qui interdisait toute
  /// fenêtre survivant à l'écran.
  Future<void> _bindSessionRenderers({required bool isVideo}) async {
    if (!isVideo) return;
    final renderers = SessionVideoRenderers.instance;
    await renderers.ensureInitialized();
    renderers.bind(this, () {
      renderers.syncMain(localStream: _localStream);
      unawaited(renderers.syncGroup(Map.of(_remoteStreams)));
    });
    await SystemPip.instance.setEligible(true);
  }

  // CLEANUP
  Future<void> _cleanup() async {
    speakingDetector.stop();
    final meetingCallId = _currentMeeting != null ? 'meeting_${_currentMeeting!.idMeeting}' : null;
    if (!kIsWeb) {
      // Même garde que du côté appel : si la session média appartient à un
      // appel — parce que notre acquisition avait été refusée —, la rendre ici
      // démonterait SON service au premier plan, SON focus audio et SON entrée
      // CallKit, sur une communication toujours vivante.
      if (CallSessionGuard.instance.holdsSession(meetingCallId)) {
        // Avant le garde : la fenêtre flottante disparaît avec la réunion, et
        // rien ne doit rester branché sur des rendus en cours de libération.
        await SystemPip.instance.reset();
        await SessionVideoRenderers.instance.release();
        await CallSessionGuard.instance.release(callId: meetingCallId);
      } else {
        debugPrint(
          '[MeetingService] session média non tenue par $meetingCallId — '
          'rien à rendre',
        );
      }
      if (meetingCallId != null) {
        try {
          await CallKitService.instance.endCall(meetingCallId);
          debugPrint('[MeetingService] CallKit meeting fermé: $meetingCallId');
        } catch (e) {
          debugPrint('[MeetingService] endCall meeting error: $e');
        }
      }
    }
    // On copie puis on vide la map AVANT de fermer les connexions : pc.close()
    // déclenche onConnectionState -> _removePeer() qui modifie _peerConnections.
    // Itérer directement sur la map lèverait une ConcurrentModificationError et
    // interromprait le cleanup (d'où l'ancien bug du double-appui pour sortir).
    final peers = _peerConnections.values.toList();
    _peerConnections.clear();
    for (final pc in peers) {
      try {
        await pc.close();
      } catch (e) {
        debugPrint('[MeetingService] pc.close error: $e');
      }
    }
    _remoteStreams.clear();
    _pendingIceByPeer.clear();
    _remoteDescSetForPeer.clear();
    _tracksAddedForPeer.clear();
    _chatMessages.clear();
    _unreadChatCount = 0;
    _isMeetingChatOpen = false;
    // Arrêter les pistes avant de disposer le flux : `dispose()` seul rend le
    // flux, pas la caméra ni le micro, qui restaient capturés après la réunion.
    // Le motif correct est celui de `releaseLocalMediaIfNotJoined` ci-dessus.
    final pistes = _localStream?.getTracks() ?? const [];
    for (final t in pistes) {
      try {
        await t.stop();
      } catch (e) {
        debugPrint('[MeetingService] arrêt de piste échoué: $e');
      }
    }
    await _localStream?.dispose();
    _localStream = null;
    _durationTimer?.cancel();
    _durationTimer = null;
    _meetingDuration = 0;
    _currentMeeting = null;
    _typeMediaVoulu = null;
    _idOrganiseurVoulu = null;
    _participantRoster.clear();
    // Sans ce vidage, la réunion suivante hériterait des présents de la
    // précédente.
    _presents.clear();
    _myId = null;
    _roomJoinCompleter = null;
    _isMuted = false;
    _isVideoOff = false;
    _remoteMutedStates.clear();
    _remoteVideoStates.clear();
    _isMeetingUiMinimized = false;
    _isMeetingUiRouteOpen = false;
  }

  @override
  void dispose() {
    _cleanup();
    speakingDetector.dispose();
    super.dispose();
  }
}