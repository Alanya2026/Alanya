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
import 'audio_helper.dart' as audio;
import 'callkit_service.dart';
import 'ringtone_service.dart';
import 'webrtc_service.dart';

enum CallStatus { idle, outgoing, joining, incoming, connecting, connected, ended }

class CallService extends ChangeNotifier {
  final TalkyApiClient _apiClient;
  final WebRTCService _webrtc = WebRTCService();
  final RingtoneService _ringtone = RingtoneService.instance;
  final CallKitService _callKit = CallKitService.instance;

  CallStatus _status = CallStatus.idle;

  // Données de l'appel en cours (1-à-1)
  int? _remoteUserId;       // targetUserId ou callerId selon le sens
  String? _remoteUserName;
  String? _remoteUserPhoto;
  bool _isVideo = false;
  Map<String, dynamic>? _pendingOffer; // offer reçu avant réponse
  String? _currentCallId;   // callId backend, utilisé pour synchroniser CallKit

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

  // ICE candidates bufferisés tant que la remote description n'est pas définie.
  final Map<String, List<RTCIceCandidate>> _groupPendingIce = {};
  final Set<String> _groupRemoteDescSet = <String>{};

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

  // Flag : l'utilisateur a accepté l'appel via CallKit avant que l'event
  // socket `incoming_call` (avec l'offer SDP) n'arrive. Quand l'offer arrive,
  // on déclenche automatiquement answerCall().
  bool _autoAnswerOnNextIncoming = false;
  String? _autoAnswerCallerId;

  CallService({required TalkyApiClient apiClient}) : _apiClient = apiClient {
    _initRingtone();
    _setupSocketListeners();
  }

  /// Appelée depuis main.dart quand l'utilisateur accepte un appel via l'écran
  /// CallKit (push FCM). Deux cas :
  /// - L'event `incoming_call` est déjà arrivé et `_pendingOffer` est rempli
  ///   → on appelle directement `answerCall()`.
  /// - L'offer n'est pas encore là → on arme un flag pour répondre dès qu'elle
  ///   arrive (le socket peut prendre quelques secondes à se reconnecter).
  Future<void> acceptIncomingCallFromPush({
    required String callId,
    required String callerId,
    required String callerName,
    String? callerPhoto,
    required bool isVideo,
    String? roomId,
  }) async {
    debugPrint('[CallService] 📲 acceptIncomingCallFromPush callId=$callId caller=$callerId');

    _remoteUserId = int.tryParse(callerId);
    _remoteUserName = callerName;
    _remoteUserPhoto = callerPhoto;
    _isVideo = isVideo;
    _currentCallId = callId.isNotEmpty ? callId : null;
    _autoAnswerOnNextIncoming = true;
    _autoAnswerCallerId = callerId;
    
    // ✅ Fixer le statut à incoming IMMÉDIATEMENT pour que HomeScreen navigue
    // vers IncomingCallScreen, même avant que l'offer socket ne soit reçue.
    _status = CallStatus.incoming;
    notifyListeners();
    
    debugPrint('[CallService] ✅ Status = incoming, auto-answer armé');

    // Si l'offer est déjà arrivée, répondre immédiatement (rare mais possible)
    if (_pendingOffer != null) {
      debugPrint('[CallService] ⚡ Offer déjà présente → réponse immédiate');
      await answerCall();
    }
  }

  /// Appelée depuis main.dart quand l'utilisateur refuse un appel via CallKit.
  Future<void> rejectIncomingCallFromPush({required String callerId}) async {
    debugPrint('[CallService] 📲 rejectIncomingCallFromPush caller=$callerId');
    final cid = int.tryParse(callerId);
    if (cid != null) {
      try {
        _apiClient.sendSocketEvent(SocketEvents.rejectCall, {'callerId': cid});
      } catch (e) {
        debugPrint('[CallService] rejectCall socket error: $e');
      }
    }
    _autoAnswerOnNextIncoming = false;
    _autoAnswerCallerId = null;
    if (_status == CallStatus.incoming) {
      _status = CallStatus.idle;
      notifyListeners();
    }
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
      final incomingCallerId = data['callerId'].toString();
      _remoteUserId = int.tryParse(incomingCallerId);
      _remoteUserName = data['callerName'] as String?;
      _remoteUserPhoto = data['callerPhoto'] as String?;
      _isVideo = data['isVideo'] == true;
      _pendingOffer = data['offer'] as Map<String, dynamic>?;
      _currentCallId = data['callId']?.toString();
      _status = CallStatus.incoming;
      debugPrint('[CallService] ✅ Statut changé à INCOMING. Caller: $_remoteUserName ($_remoteUserId), Vidéo: $_isVideo');

      notifyListeners();

      // Si l'utilisateur a déjà accepté via CallKit pour ce caller, on répond
      // automatiquement maintenant que l'offer est arrivée.
      if (_autoAnswerOnNextIncoming && _autoAnswerCallerId == incomingCallerId) {
        debugPrint('[CallService] ⚡ Auto-answer en 500ms (CallKit pré-accepté)');
        _autoAnswerOnNextIncoming = false;
        _autoAnswerCallerId = null;
        
        // ✅ Attendre 500ms pour que l'app soit bien initialisée avant d'auto-répondre
        await Future.delayed(const Duration(milliseconds: 500));
        
        try {
          await answerCall();
        } catch (e) {
          debugPrint('[CallService] ⚠️ Auto-answer failed: $e');
        }
        return;
      }

      // Sonnerie système (téléphone par défaut de l'utilisateur).
      _ringtone.startIncomingRingtone().catchError((e) {
        debugPrint('[CallService] ⚠️ Erreur sonnerie (non-bloquante): $e');
      });
    });

    // Appel accepté par l'autre
    _apiClient.onSocketEvent(SocketEvents.callAnswered, (data) async {
      debugPrint('[CallService] 📞 call_answered reçu: $data');

      if (_status != CallStatus.connecting) {
        debugPrint('[CallService] ⚠️ call_answered ignoré : statut=$_status');
        return;
      }

      // 🛑 Arrêter le ringback dès que le destinataire décroche
      await _ringtone.stop();

      if (data is! Map || data['answer'] == null) {
        debugPrint('[CallService] ❌ Données call_answered invalides');
        return;
      }

      try {
        final answer = data['answer'] as Map;
        await _webrtc.handleAnswer(
          RTCSessionDescription(answer['sdp'] as String, 'answer'),
        );
        debugPrint('[CallService] ✅ Answer acceptée → CONNECTED');
        _status = CallStatus.connected;
        _startDurationTimer();
      } catch (e) {
        debugPrint('[CallService] ❌ Erreur handleAnswer: $e');
        _status = CallStatus.idle;
      }
      notifyListeners();
    });

    // Appel rejeté par le destinataire
    _apiClient.onSocketEvent(SocketEvents.callRejected, (_) async {
      debugPrint('[CallService] 📞 Appel rejeté');
      await _terminateCall();
    });

    // Appel terminé par l'autre côté
    _apiClient.onSocketEvent(SocketEvents.callEnded, (_) async {
      debugPrint('[CallService] 📞 Appel terminé par l\'autre côté');
      await _terminateCall();
    });

    // Appel échoué (destinataire hors-ligne)
    _apiClient.onSocketEvent(SocketEvents.callFailed, (data) async {
      debugPrint('[CallService] Appel échoué: ${data?['reason']}');
      await _terminateCall();
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
        _groupRemoteDescSet.add(fromUserId);
        await _flushGroupPendingIce(fromUserId);
      }
    });

    // WebRTC groupe : ICE candidate reçu
    _apiClient.onSocketEvent(SocketEvents.groupIceCandidate, (data) async {
      if (data is! Map) return;
      final fromUserId = data['fromUserId'].toString();
      final c = data['candidate'] as Map?;
      if (c == null) return;
      final candidate = RTCIceCandidate(
        c['candidate'] as String,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      );
      final pc = _groupPeerConnections[fromUserId];
      if (pc == null || !_groupRemoteDescSet.contains(fromUserId)) {
        _groupPendingIce.putIfAbsent(fromUserId, () => []).add(candidate);
        return;
      }
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('[CallService] group addCandidate échoué $fromUserId: $e');
      }
    });
  }

  Future<void> _flushGroupPendingIce(String userId) async {
    final pc = _groupPeerConnections[userId];
    final pending = _groupPendingIce.remove(userId);
    if (pc == null || pending == null || pending.isEmpty) return;
    for (final c in pending) {
      try {
        await pc.addCandidate(c);
      } catch (e) {
        debugPrint('[CallService] group addCandidate (flush) échoué $userId: $e');
      }
    }
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
      final iceServers = await _apiClient.fetchIceServers(force: true);
      await _webrtc.init(isVideo ? CallType.video : CallType.audio, iceServers: iceServers);
      _webrtc.onLocalStream  = (_) { notifyListeners(); };
      _webrtc.onRemoteStream = (_) { notifyListeners(); };

      // ✅ Initialiser le routage audio (mobile uniquement)
      if (!kIsWeb) {
        _isSpeakerOn = true;
        await audio.AudioHelper.setSpeakerphoneOn(true);
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

      // Connection failure handler
      _webrtc.onConnectionFailure = () {
        debugPrint('[CallService] ⚠️ Peer connection failed, ending call');
        _terminateCall();
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

      // Ringback côté appelant (tonalité jusqu'à décrochage du destinataire).
      _ringtone.startOutgoingRingback();

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
  ///
  /// Gardes :
  /// - Status doit être `incoming` (sinon return). Le passage immédiat à
  ///   `connecting` empêche les appels concurrents (Accept depuis l'UI ET
  ///   auto-answer depuis CallKit en parallèle).
  /// - L'offer doit être présente. Sinon on arme `_autoAnswerOnNextIncoming`
  ///   pour répondre dès que l'event socket `incoming_call` arrive.
  Future<void> answerCall() async {
    if (_status != CallStatus.incoming || _remoteUserId == null) {
      debugPrint('[CallService] ⚠️ answerCall ignoré: status=$_status');
      return;
    }
    if (_pendingOffer == null) {
      debugPrint('[CallService] ⏳ answerCall: offer pas encore reçue, auto-answer armé');
      _autoAnswerOnNextIncoming = true;
      _autoAnswerCallerId = _remoteUserId.toString();
      return;
    }

    // Verrouille immédiatement pour bloquer un éventuel double-appel.
    _status = CallStatus.connecting;
    notifyListeners();

    await _ringtone.stop();
    _errorMessage = null;

    // ✅ Attendre que le socket soit connecté/authentifié avant d'envoyer l'answer
    // (important après app redémarrage depuis push CallKit)
    int retries = 0;
    while (!_apiClient.isSocketConnected && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
    if (!_apiClient.isSocketConnected) {
      debugPrint('[CallService] ❌ Socket not connected après 2s');
      _errorMessage = 'Socket non connecté';
      _status = CallStatus.idle;
      notifyListeners();
      return;
    }
    debugPrint('[CallService] ✅ Socket connecté, envoi answer');

    final offer = _pendingOffer!;
    _pendingOffer = null;

    try {
      final iceServers = await _apiClient.fetchIceServers(force: true);
      await _webrtc.init(_isVideo ? CallType.video : CallType.audio, iceServers: iceServers);
      _webrtc.onLocalStream  = (_) { notifyListeners(); };
      _webrtc.onRemoteStream = (_) { notifyListeners(); };

      if (!kIsWeb) {
        _isSpeakerOn = true;
        await audio.AudioHelper.setSpeakerphoneOn(true);
      }

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

      // Connection failure handler
      _webrtc.onConnectionFailure = () {
        debugPrint('[CallService] ⚠️ Peer connection failed, ending call');
        _terminateCall();
      };

      await _webrtc.handleOffer(
        RTCSessionDescription(offer['sdp'] as String, 'offer'),
      );

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
      // Synchronise la notif CallKit (passe en mode "appel en cours").
      if (_currentCallId != null && _currentCallId!.isNotEmpty) {
        await _callKit.setConnected(_currentCallId!);
      }
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

    await _ringtone.stop();
    await _callKit.endAll();

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
    await _ringtone.stop();
    await _callKit.endAll();
    await _webrtc.dispose();
    _durationTimer?.cancel();
    _resetCallState();
    // Passe d'abord par 'ended' pour que OngoingCallScreen/IncomingCallScreen
    // détectent la fin et pop, puis revient à 'idle' immédiatement.
    _status = CallStatus.ended;
    notifyListeners();
    _status = CallStatus.idle;
    await Future.microtask(() {});
    notifyListeners();
  }

  void _resetCallState() {
    _remoteUserId = null;
    _remoteUserName = null;
    _remoteUserPhoto = null;
    _pendingOffer = null;
    _currentCallId = null;
    _callDuration = 0;
    _isMuted = false;
    _isVideoOn = true;
    _isSpeakerOn = false;
    _durationTimer?.cancel();
    _callEndedByUs = false;
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
    _groupPendingIce.clear();
    _groupRemoteDescSet.clear();
    await _webrtc.dispose();
    _durationTimer?.cancel();
    _groupRoomId = null;
    _callDuration = 0;
    _status = CallStatus.idle;
    notifyListeners();
  }

  Future<void> _initLocalStream(bool isVideo) async {
    final iceServers = await _apiClient.fetchIceServers();
    await _webrtc.init(isVideo ? CallType.video : CallType.audio, iceServers: iceServers);

    // ✅ Initialiser le routage audio pour les appels de groupe aussi (mobile uniquement)
    if (!kIsWeb) {
      _isSpeakerOn = true;
      await audio.AudioHelper.setSpeakerphoneOn(true);
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
    _groupRemoteDescSet.add(fromUserId);
    await _flushGroupPendingIce(fromUserId);

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

    final iceServers = await _apiClient.fetchIceServers();
    final iceConfig = {'iceServers': iceServers};

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

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        debugPrint('[CallService] ⚠️ Group peer $userId connection failed: $state');
        _removeGroupPeer(userId);
      }
    };

    _groupPeerConnections[userId] = pc;
    return pc;
  }

  void _removeGroupPeer(String userId) {
    _groupPeerConnections[userId]?.close();
    _groupPeerConnections.remove(userId);
    _groupRemoteStreams.remove(userId);
    _groupParticipants.remove(userId);
    _groupPendingIce.remove(userId);
    _groupRemoteDescSet.remove(userId);
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
    await audio.AudioHelper.setSpeakerphoneOn(_isSpeakerOn);
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
  void dispose() {
    _durationTimer?.cancel();
    _webrtc.dispose();
    // RingtoneService est singleton — on ne le dispose pas globalement, juste
    // s'assurer qu'aucun son ne traîne.
    _ringtone.stop();
    for (final pc in _groupPeerConnections.values) {
      pc.close();
    }
    super.dispose();
  }
}