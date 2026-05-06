// call_service.dart — aligné sur le backend Node.js
//
// Événements corrects (backend/src/socket/handlers/calls.js) :
//
// Flutter → Backend
//   call_user        { targetUserId, callerId, callerName, callerPhoto, isVideo, offer:{sdp,type} }
//   answer_call      { callerId, answer:{sdp,type} }
//   reject_call      { callerId }
//   end_call         { targetUserId }
//   ice_candidate    { targetUserId, candidate:{candidate,sdpMid,sdpMLineIndex} }
//
// Backend → Flutter
//   incoming_call    { callerId, callerName, callerPhoto, isVideo, offer:{sdp,type} }
//   call_answered    { answer:{sdp,type} }
//   call_rejected    {}
//   call_ended       {}
//   call_failed      { reason }
//   ice_candidate    { candidate:{candidate,sdpMid,sdpMLineIndex} }
//
// Appels groupe :
//   Flutter → Backend
//     create_group_call  { roomId, callerId, callerName, callerPhoto, isVideo, targetUserIds:[] }
//     join_group_call    { roomId, userId, userName, userPhoto }
//     leave_group_call   { roomId }
//     end_group_call     { roomId }
//     group_offer        { roomId, fromUserId, toUserId, offer }
//     group_answer       { roomId, fromUserId, toUserId, answer }
//     group_ice_candidate{ roomId, fromUserId, toUserId, candidate }
//
//   Backend → Flutter
//     group_call_invite  { callerId, callerName, callerPhoto, isVideo, roomId }
//     group_user_joined  { roomId, userId, userName, userPhoto }
//     group_participants { roomId, participants:[] }
//     group_call_ended   {}
//     group_user_left    { roomId, userId }
//     group_offer        { fromUserId, offer, roomId }
//     group_answer       { fromUserId, answer, roomId }
//     group_ice_candidate{ fromUserId, candidate, roomId }

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'webrtc_service.dart';
import 'ringtone_service.dart';

enum CallStatus { idle, outgoing, joining, incoming, connecting, connected, ended }

class CallService extends ChangeNotifier {
  final TalkyApiClient _apiClient;
  final WebRTCService _webrtc = WebRTCService();
  final RingtoneService _ringtone = RingtoneService();

  CallStatus _status = CallStatus.idle;

  // Données de l'appel en cours (1-à-1)
  int? _remoteUserId;       // targetUserId ou callerId selon le sens
  String? _remoteUserName;
  String? _remoteUserPhoto;
  bool _isVideo = false;
  Map<String, dynamic>? _pendingOffer; // offer reçu avant réponse

  // ✅ Flag pour savoir si on a volontairement terminé l'appel
  bool _callEndedByUs = false;

  // Contrôles médias
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = true;

  // Erreurs
  String? _errorMessage;

  // Durée
  Timer? _durationTimer;
  int _callDuration = 0;

  // ── Appels de groupe ───────────────────────────────────────────────
  String? _groupRoomId;
  final Map<String, RTCPeerConnection> _groupPeerConnections = {};
  final Map<String, MediaStream> _groupRemoteStreams = {};
  List<String> _groupParticipants = [];

  // ── Getters ────────────────────────────────────────────────────────
  CallStatus get status => _status;
  int? get remoteUserId => _remoteUserId;
  String? get remoteUserName => _remoteUserName;
  String? get remoteUserPhoto => _remoteUserPhoto;
  bool get isVideo => _isVideo;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoOn => _isVideoOn;
  int get callDuration => _callDuration;
  String? get errorMessage => _errorMessage;
  bool get callEndedByUs => _callEndedByUs;
  MediaStream? get localStream => _webrtc.localStream;
  MediaStream? get remoteStream => _webrtc.remoteStream;

  String? get groupRoomId => _groupRoomId;
  Map<String, MediaStream> get groupRemoteStreams => _groupRemoteStreams;
  List<String> get groupParticipants => _groupParticipants;

  Call? get currentCall {
    if (_remoteUserId == null && _remoteUserName == null) return null;
    return Call(
      idCall: 0,
      idCaller: _remoteUserId ?? 0,
      idReceiver: 0,
      type: _isVideo ? 1 : 0,
      status: _status == CallStatus.incoming ? 0 : 1,
      createdAt: '',
      caller: _remoteUserId != null
          ? User(
              alanyaID: _remoteUserId!,
              nom: _remoteUserName ?? '',
              pseudo: '',
              alanyaPhone: '',
              email: '',
              idPays: 1,
              avatarUrl: _remoteUserPhoto ?? '',
              typeCompte: 0,
              isOnline: false,
              lastSeen: '',
            )
          : null,
    );
  }

  CallService({required TalkyApiClient apiClient}) : _apiClient = apiClient {
    _initRingtone();
    _setupSocketListeners();
  }

  Future<void> _initRingtone() async {
    try {
      await _ringtone.init();
      debugPrint('[CallService] ✅ RingtoneService initialisé');
    } catch (e) {
      debugPrint('[CallService] ⚠️ Erreur init ringtone: $e');
    }
  }

  // ── SETUP LISTENERS ────────────────────────────────────────────────

  void _setupSocketListeners() {
    // ── Appels 1-à-1 ──────────────────────────────────────────────

    // Appel entrant
    _apiClient.onSocketEvent(SocketEvents.incomingCall, (data) async {
      debugPrint('[CallService] 📞 Appel entrant reçu: $data');
      if (data is! Map) {
        debugPrint('[CallService] ❌ Données invalides pour incoming_call');
        return;
      }
      _remoteUserId = int.tryParse(data['callerId'].toString());
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = data['callerPhoto'] as String?;
      _isVideo = data['isVideo'] == true;
      _pendingOffer = data['offer'] as Map<String, dynamic>?;
      _status = CallStatus.incoming;
      debugPrint('[CallService] ✅ Statut changé à INCOMING. Caller: $_remoteUserName ($_remoteUserId), Vidéo: $_isVideo');
      
      // 🔔 Démarrer la sonnerie d'appel entrant
      await _ringtone.playIncomingCallRingtone();
      
      notifyListeners();
    });

    // Appel accepté par l'autre
    _apiClient.onSocketEvent(SocketEvents.callAnswered, (data) async {
      debugPrint('[CallService] 📞 call_answered reçu: $data');
      
      // ✅ GARDE : Ne traiter que si on est en status "connecting" (en attente de réponse)
      if (_status != CallStatus.connecting) {
        debugPrint('[CallService] ⚠️ call_answered ignoré : statut=${_status}, attendu=connecting');
        return;
      }
      
      if (data is! Map || data['answer'] == null) {
        debugPrint('[CallService] ❌ Données call_answered invalides');
        return;
      }
      
      try {
        final answer = data['answer'] as Map;
        debugPrint('[CallService] 🔄 handleAnswer: ${answer['type']}');
        await _webrtc.handleAnswer(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
        debugPrint('[CallService] ✅ Answer acceptée, statut → CONNECTED');
        _status = CallStatus.connected;
        _startDurationTimer();
      } catch (e) {
        debugPrint('[CallService] ❌ Erreur handleAnswer: $e');
        _status = CallStatus.idle;
      }
      notifyListeners();
    });

    // Appel rejeté
    _apiClient.onSocketEvent(SocketEvents.callRejected, (_) {
      _resetCallState();
      _status = CallStatus.idle;
      notifyListeners();
    });

    // Appel terminé par l'autre
    _apiClient.onSocketEvent(SocketEvents.callEnded, (_) {
      debugPrint('[CallService] 📞 Appel terminé par l\'autre côté');
      // ✅ Ne PAS activer _callEndedByUs ici — c'est l'autre qui a terminé
      _terminateCall();
    });

    // Appel échoué (destinataire non disponible)
    _apiClient.onSocketEvent(SocketEvents.callFailed, (data) {
      debugPrint('[CallService] Appel échoué: ${data?['reason']}');
      _resetCallState();
      _status = CallStatus.idle;
      notifyListeners();
    });

    // ICE candidate 1-à-1
    _apiClient.onSocketEvent(SocketEvents.iceCandidate, (data) {
      if (data is! Map || data['candidate'] == null) return;
      final c = data['candidate'] as Map;
      _webrtc.addIceCandidate(RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ));
    });

    // ── Appels de groupe ──────────────────────────────────────────

    // Invitation à un appel de groupe
    _apiClient.onSocketEvent(SocketEvents.groupCallInvite, (data) {
      if (data is! Map) return;
      _remoteUserId = int.tryParse(data['callerId'].toString());
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = data['callerPhoto'] as String?;
      _isVideo = data['isVideo'] == true;
      _groupRoomId = data['roomId'] as String?;
      _status = CallStatus.incoming;
      notifyListeners();
    });

    // Nouveau participant dans le groupe
    _apiClient.onSocketEvent(SocketEvents.groupUserJoined, (data) async {
      if (data is! Map) return;
      final userId = data['userId'].toString();
      if (_groupPeerConnections.containsKey(userId)) return;
      await _createGroupPeerAndOffer(userId);
    });

    // Liste des participants existants (reçu après join)
    _apiClient.onSocketEvent(SocketEvents.groupParticipants, (data) {
      if (data is! Map) return;
      final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _groupParticipants = participants;
      notifyListeners();
    });

    // Participant quitte le groupe
    _apiClient.onSocketEvent(SocketEvents.groupUserLeft, (data) {
      if (data is! Map) return;
      final userId = data['userId'].toString();
      _removeGroupPeer(userId);
    });

    // Appel de groupe terminé
    _apiClient.onSocketEvent(SocketEvents.groupCallEnded, (_) {
      _terminateGroupCall();
    });

    // WebRTC groupe : offer reçue
    _apiClient.onSocketEvent(SocketEvents.groupOffer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final offer = data['offer'] as Map?;
      if (offer == null) return;
      await _handleGroupOffer(fromUserId, offer);
    });

    // WebRTC groupe : answer reçue
    _apiClient.onSocketEvent(SocketEvents.groupAnswer, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final answer = data['answer'] as Map?;
      if (answer == null) return;
      final pc = _groupPeerConnections[fromUserId];
      if (pc != null) {
        await pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
      }
    });

    // WebRTC groupe : ICE candidate reçu
    _apiClient.onSocketEvent(SocketEvents.groupIceCandidate, (data) {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final c = data['candidate'] as Map?;
      if (c == null) return;
      _groupPeerConnections[fromUserId]?.addCandidate(RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ));
    });
  }

  // ── APPELS 1-À-1 ──────────────────────────────────────────────────

  /// Lance un appel vers [targetUserId].
  /// [myId] et [myName] sont nécessaires pour le payload backend.
  Future<void> initiateCall({
    required int targetUserId,
    required int myId,
    required String myName,
    String? myPhoto,
    required bool isVideo,
    String? targetUserName,
    String? targetUserPhoto,
  }) async {
    if (_status != CallStatus.idle) return;
    _errorMessage = null; // Réinitialiser les erreurs
    _status = CallStatus.outgoing;
    _remoteUserId = targetUserId;
    _remoteUserName = targetUserName;
    _remoteUserPhoto = targetUserPhoto;
    _isVideo = isVideo;
    notifyListeners();

    try {
      await _webrtc.init(isVideo ? CallType.video : CallType.audio);

      // ✅ Initialiser le routage audio (mobile uniquement)
      if (!kIsWeb) {
        _isSpeakerOn = true;
        await Helper.setSpeakerphoneOn(true);
        debugPrint('[CallService] 🔊 Routage audio initialisé (haut-parleur ON)');
      }

      // ICE candidates → envoyés au destinataire
      _webrtc.onIceCandidate = (candidate) {
        _apiClient.sendSocketEvent(SocketEvents.iceCandidate, {
          'targetUserId': targetUserId.toString(),
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      final offer = await _webrtc.createOffer();

      // ✅ Payload exact attendu par le backend
      _apiClient.sendSocketEvent(SocketEvents.callUser, {
        'targetUserId': targetUserId.toString(),
        'callerId': myId.toString(),
        'callerName': myName,
        'callerPhoto': myPhoto,
        'isVideo': isVideo,
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
      });

      _status = CallStatus.connecting;
      
      // 📞 Démarrer la sonnerie ringback (tonalité d'appel pour l'appelant)
      _ringtone.playRingbackTone();
      
      notifyListeners();
    } catch (e) {
      debugPrint('[CallService] Erreur initiateCall: $e');
      debugPrint('[CallService] Type d\'erreur: ${e.runtimeType}');
      
      // Déterminer le type d'erreur pour afficher un message clair
      String errorMsg = 'Erreur lors du démarrage de l\'appel';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('permission')) {
        errorMsg = 'Permission refusée. Veuillez autoriser le microphone/caméra.';
      } else if (errorStr.contains('microphone') || errorStr.contains('audio')) {
        errorMsg = 'Erreur microphone. Veuillez vérifier vos permissions et votre matériel audio.';
      } else if (errorStr.contains('camera') || errorStr.contains('video')) {
        errorMsg = 'Erreur caméra. Veuillez vérifier vos permissions et votre caméra.';
      } else if (errorStr.contains('navigator') || errorStr.contains('getusermedia')) {
        errorMsg = 'Erreur d\'accès aux médias. Vérifiez que HTTPS est activé ou que vous êtes sur localhost.';
      } else if (errorStr.contains('notfounderror')) {
        errorMsg = 'Aucun appareil microphone/caméra trouvé sur votre système.';
      } else if (errorStr.contains('notreadableerror')) {
        errorMsg = 'Impossible d\'accéder au microphone/caméra. Vérifiez que l\'application a les permissions.';
      } else {
        errorMsg = 'Erreur: ${e.toString()}';
      }
      
      _errorMessage = errorMsg;
      await _webrtc.dispose();
      _resetCallState();
      _status = CallStatus.idle;
      notifyListeners();
    }
  }

  /// Accepte l'appel entrant.
  Future<void> answerCall() async {
    if (_status != CallStatus.incoming || _remoteUserId == null) {
      debugPrint('[CallService] ⚠️ answerCall ignoré: status=${_status}, remoteUserId=${_remoteUserId}');
      return;
    }

    // 🛑 Arrêter la sonnerie
    await _ringtone.stopRingtone();
    
    _errorMessage = null; // Réinitialiser les erreurs
    debugPrint('[CallService] 📞 answerCall START - Caller: $_remoteUserId');

    try {
      debugPrint('[CallService] 🔧 _webrtc.init($_isVideo ? CallType.video : CallType.audio)');
      await _webrtc.init(_isVideo ? CallType.video : CallType.audio);
      debugPrint('[CallService] ✅ WebRTC initialisé');

      // ✅ Initialiser le routage audio (mobile uniquement)
      if (!kIsWeb) {
        _isSpeakerOn = true;
        await Helper.setSpeakerphoneOn(true);
        debugPrint('[CallService] 🔊 Routage audio initialisé (haut-parleur ON)');
      }

      // ICE candidates → envoyés à l'appelant
      _webrtc.onIceCandidate = (candidate) {
        _apiClient.sendSocketEvent(SocketEvents.iceCandidate, {
          'targetUserId': _remoteUserId.toString(),
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      if (_pendingOffer != null) {
        await _webrtc.handleOffer(
          RTCSessionDescription(_pendingOffer!['sdp'] as String, 'offer'),
        );
      }

      final answer = await _webrtc.createAnswer();

      // ✅ Payload exact attendu par le backend
      _apiClient.sendSocketEvent(SocketEvents.answerCall, {
        'callerId': _remoteUserId.toString(),
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallService] Erreur answerCall: $e');
      debugPrint('[CallService] Type d\'erreur: ${e.runtimeType}');
      
      // Déterminer le type d'erreur pour afficher un message clair
      String errorMsg = 'Erreur lors de l\'acceptation de l\'appel';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('permission')) {
        errorMsg = 'Permission refusée. Veuillez autoriser le microphone/caméra.';
      } else if (errorStr.contains('microphone') || errorStr.contains('audio')) {
        errorMsg = 'Erreur microphone. Veuillez vérifier vos permissions et votre matériel audio.';
      } else if (errorStr.contains('camera') || errorStr.contains('video')) {
        errorMsg = 'Erreur caméra. Veuillez vérifier vos permissions et votre caméra.';
      } else if (errorStr.contains('navigator') || errorStr.contains('getusermedia')) {
        errorMsg = 'Erreur d\'accès aux médias. Vérifiez que HTTPS est activé ou que vous êtes sur localhost.';
      } else {
        errorMsg = 'Erreur: ${e.toString()}';
      }
      
      _errorMessage = errorMsg;
      await rejectCall();
    }
  }

  /// Rejette l'appel entrant.
  Future<void> rejectCall() async {
    if (_remoteUserId == null) return;

    // 🛑 Arrêter la sonnerie
    await _ringtone.stopRingtone();

    // ✅ Payload exact attendu par le backend
    _apiClient.sendSocketEvent(SocketEvents.rejectCall, {
      'callerId': _remoteUserId.toString(),
    });

    _resetCallState();
    _status = CallStatus.idle;
    notifyListeners();
  }

  /// Termine l'appel en cours.
  Future<void> endCall() async {
    _callEndedByUs = true; // ✅ Marquer qu'on a terminé volontairement
    debugPrint('[CallService] 📞 endCall() - Appel terminé par nous');
    if (_remoteUserId != null) {
      // ✅ Payload exact attendu par le backend
      _apiClient.sendSocketEvent(SocketEvents.endCall, {
        'targetUserId': _remoteUserId.toString(),
      });
    }
    await _terminateCall();
  }

  Future<void> _terminateCall() async {
    // 🛑 Arrêter la sonnerie
    await _ringtone.stopRingtone();
    
    await _webrtc.dispose();
    _durationTimer?.cancel();
    _resetCallState();
    _status = CallStatus.idle;
    notifyListeners();
  }

  void _resetCallState() {
    _remoteUserId = null;
    _remoteUserName = null;
    _remoteUserPhoto = null;
    _pendingOffer = null;
    _callDuration = 0;
    _isMuted = false;
    _isVideoOn = true;
    _isSpeakerOn = false;
    _durationTimer?.cancel();
    _callEndedByUs = false; // ✅ Réinitialiser le flag
  }

  // ── APPELS DE GROUPE ───────────────────────────────────────────────

  /// Crée un appel de groupe et invite [targetUserIds].
  Future<void> createGroupCall({
    required String roomId,
    required int myId,
    required String myName,
    String? myPhoto,
    required List<int> targetUserIds,
    required bool isVideo,
  }) async {
    if (_status != CallStatus.idle) return;
    _groupRoomId = roomId;
    _status = CallStatus.outgoing;
    notifyListeners();

    try {
      await _initLocalStream(isVideo);

      // ✅ Payload exact attendu par le backend
      _apiClient.sendSocketEvent(SocketEvents.createGroupCall, {
        'roomId': roomId,
        'callerId': myId.toString(),
        'callerName': myName,
        'callerPhoto': myPhoto,
        'isVideo': isVideo,
        'targetUserIds': targetUserIds.map((id) => id.toString()).toList(),
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallService] Erreur createGroupCall: $e');
      _status = CallStatus.idle;
      notifyListeners();
    }
  }

  /// Rejoint un appel de groupe existant (après invitation).
  Future<void> joinGroupCall({
    required String roomId,
    required int myId,
    required String myName,
    String? myPhoto,
    required bool isVideo,
  }) async {
    _groupRoomId = roomId;
    _status = CallStatus.joining;
    notifyListeners();

    try {
      await _initLocalStream(isVideo);

      // ✅ Payload exact attendu par le backend
      _apiClient.sendSocketEvent(SocketEvents.joinGroupCall, {
        'roomId': roomId,
        'userId': myId.toString(),
        'userName': myName,
        'userPhoto': myPhoto,
      });

      _status = CallStatus.connected;
      _startDurationTimer();
      notifyListeners();
    } catch (e) {
      debugPrint('[CallService] Erreur joinGroupCall: $e');
      _status = CallStatus.idle;
      notifyListeners();
    }
  }

  Future<void> leaveGroupCall() async {
    if (_groupRoomId == null) return;

    _apiClient.sendSocketEvent(SocketEvents.leaveGroupCall, {
      'roomId': _groupRoomId,
    });

    await _terminateGroupCall();
  }

  Future<void> endGroupCall() async {
    if (_groupRoomId == null) return;

    _apiClient.sendSocketEvent(SocketEvents.endGroupCall, {
      'roomId': _groupRoomId,
    });

    await _terminateGroupCall();
  }

  Future<void> _terminateGroupCall() async {
    for (final pc in _groupPeerConnections.values) {
      await pc.close();
    }
    _groupPeerConnections.clear();
    _groupRemoteStreams.clear();
    _groupParticipants.clear();
    await _webrtc.dispose();
    _durationTimer?.cancel();
    _groupRoomId = null;
    _callDuration = 0;
    _status = CallStatus.idle;
    notifyListeners();
  }

  Future<void> _initLocalStream(bool isVideo) async {
    await _webrtc.init(isVideo ? CallType.video : CallType.audio);

    // ✅ Initialiser le routage audio pour les appels de groupe aussi (mobile uniquement)
    if (!kIsWeb) {
      _isSpeakerOn = true;
      await Helper.setSpeakerphoneOn(true);
      debugPrint('[CallService] 🔊 Routage audio initialisé (haut-parleur ON)');
    }
  }

  Future<void> _createGroupPeerAndOffer(String userId) async {
    final pc = await _createGroupPeerConnection(userId);

    _webrtc.localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _webrtc.localStream!);
    });

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    // ✅ Payload exact attendu par le backend
    _apiClient.sendSocketEvent(SocketEvents.groupOffer, {
      'roomId': _groupRoomId,
      'fromUserId': '', // rempli par socket.alanyaID côté serveur
      'toUserId': userId,
      'offer': {'sdp': offer.sdp, 'type': offer.type},
    });
  }

  Future<void> _handleGroupOffer(String fromUserId, Map offer) async {
    final pc = await _createGroupPeerConnection(fromUserId);

    await pc.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, 'offer'),
    );

    _webrtc.localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _webrtc.localStream!);
    });

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    // ✅ Payload exact attendu par le backend
    _apiClient.sendSocketEvent(SocketEvents.groupAnswer, {
      'roomId': _groupRoomId,
      'fromUserId': '',
      'toUserId': fromUserId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<RTCPeerConnection> _createGroupPeerConnection(String userId) async {
    if (_groupPeerConnections.containsKey(userId)) {
      return _groupPeerConnections[userId]!;
    }

    const iceConfig = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {
          'urls': [
            'turn:global.relay.metered.ca:80',
            'turn:global.relay.metered.ca:80?transport=tcp',
            'turn:global.relay.metered.ca:443',
            'turns:global.relay.metered.ca:443?transport=tcp',
          ],
          'username': '4ccd30e6211751522c93c044',
          'credential': 'iB+/hPI3lLayZAKn',
        },
      ],
    };

    final pc = await createPeerConnection(iceConfig);

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _groupRemoteStreams[userId] = event.streams[0];
        notifyListeners();
      }
    };

    pc.onIceCandidate = (candidate) {
      // ✅ Payload exact attendu par le backend
      _apiClient.sendSocketEvent(SocketEvents.groupIceCandidate, {
        'roomId': _groupRoomId,
        'fromUserId': '',
        'toUserId': userId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    _groupPeerConnections[userId] = pc;
    return pc;
  }

  void _removeGroupPeer(String userId) {
    _groupPeerConnections[userId]?.close();
    _groupPeerConnections.remove(userId);
    _groupRemoteStreams.remove(userId);
    _groupParticipants.remove(userId);
    notifyListeners();
  }

  // ── CONTRÔLES MÉDIAS ──────────────────────────────────────────────

  Future<void> toggleMute() async {
    await _webrtc.toggleMic();
    _isMuted = !_isMuted;
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    await _webrtc.toggleCamera();
    _isVideoOn = !_isVideoOn;
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _webrtc.switchCamera();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    debugPrint('[CallService] Haut-parleur: ${_isSpeakerOn ? "ON" : "OFF"}');
    notifyListeners();
  }

  // ── TIMER ─────────────────────────────────────────────────────────

  void _startDurationTimer() {
    _callDuration = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration++;
      notifyListeners();
    });
  }

  String get formattedDuration {
    final m = _callDuration ~/ 60;
    final s = _callDuration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  @override
  void dispose() {
    _durationTimer?.cancel();
    _webrtc.dispose();
    _ringtone.dispose();
    for (final pc in _groupPeerConnections.values) {
      pc.close();
    }
    super.dispose();
  }
}