import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallType { audio, video }

class WebRTCService {
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCSessionDescription)? onOffer;
  Function(RTCSessionDescription)? onAnswer;
  Function()? onConnectionFailure;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Exposé pour `SpeakingDetector` (lecture de `getStats()` afin de
  /// détecter qui parle). Ne pas utiliser pour modifier l'état du PC depuis
  /// l'extérieur de ce service.
  RTCPeerConnection? get peerConnection => _peerConnection;

  Future<bool> _requestMicrophonePermission() async {
    // Sur web, les permissions sont gérées par le navigateur
    if (kIsWeb) return true;

    final status = await Permission.microphone.request();
    debugPrint('[WebRTC] Permission microphone: ${status.toString()}');

    return status.isGranted;
  }

  /// Vérifier et demander les permissions caméra pour Android/iOS
  Future<bool> _requestCameraPermission() async {
    // Sur web, les permissions sont gérées par le navigateur  
    if (kIsWeb) return true;

    final status = await Permission.camera.request();
    debugPrint('[WebRTC] Permission caméra: ${status.toString()}');

    return status.isGranted;
  }
 
  Future<void> init(CallType type, {List<Map<String, dynamic>>? iceServers}) async {
    try {
      debugPrint('[WebRTC] ========== Initialisation WebRTC ==========');
      debugPrint('[WebRTC] isWeb: $kIsWeb, Platform: ${kIsWeb ? "WEB" : (_isAndroid ? "ANDROID" : "iOS")}');
      debugPrint('[WebRTC] Call Type: $type');

      // !! Sur mobile, demander les permissions
      if (!kIsWeb) {
        final micGranted = await _requestMicrophonePermission();
        if (!micGranted) {
          throw Exception('Permission microphone refusée');
        }

        if (type == CallType.video) {
          final cameraGranted = await _requestCameraPermission();
          if (!cameraGranted) {
            debugPrint('[WebRTC] ** Permission caméra refusée — continuant avec audio uniquement');
          }
        }
      } else {
        debugPrint('[WebRTC] Plateforme WEB - Les permissions seront demandées par le navigateur via getUserMedia');
      }

      final configuration = {
        'iceServers': iceServers ??
            const [
              {'urls': 'stun:stun.l.google.com:19302'},
              {'urls': 'stun:stun1.l.google.com:19302'},
            ],
      };

      debugPrint('[WebRTC] Création du PeerConnection avec ${(configuration['iceServers'] as List).length} iceServer(s)...');
      _peerConnection = await createPeerConnection(configuration);
      debugPrint('[WebRTC] PeerConnection créé avec succès');

      _peerConnection!.onIceCandidate = (candidate) {
        // Type host = LAN, srflx = via STUN, relay = via TURN.
        final c = candidate.candidate ?? '';
        final type = c.contains(' typ relay ')
            ? 'relay/TURN'
            : c.contains(' typ srflx ')
                ? 'srflx/STUN'
                : c.contains(' typ host ')
                    ? 'host/LAN'
                    : 'unknown';
        debugPrint('[WebRTC] 🧊 ICE candidate généré (type=$type, candidate=${c.split(' ').first}) cb=${onIceCandidate != null}');
        onIceCandidate?.call(candidate);
      };

      _peerConnection!.onIceConnectionState = (state) {
        debugPrint('[WebRTC] 🔗 ICE connection state: $state');
      };

      _peerConnection!.onConnectionState = (state) {
        debugPrint('[WebRTC] 🔌 Peer connection state: $state');
        
        // Detect connection failures and notify
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          debugPrint('[WebRTC] ** Peer connection failed/disconnected: $state');
          onConnectionFailure?.call();
        }
      };

      _peerConnection!.onIceGatheringState = (state) {
        debugPrint('[WebRTC] 🧊 ICE gathering state: $state');
      };

      _peerConnection!.onTrack = (event) {
        debugPrint('[WebRTC] 🎥 Track reçu: ${event.streams.length} stream(s), kind=${event.track.kind}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint('[WebRTC] !! Remote stream assigné (ID=${_remoteStream?.id})');
          debugPrint('[WebRTC]  Remote stream tracks: Audio=${_remoteStream?.getAudioTracks().length}, Video=${_remoteStream?.getVideoTracks().length}');
          
          // Log détails des pistes
          _remoteStream?.getAudioTracks().forEach((track) {
            debugPrint('[WebRTC] 🎵 Audio track: kind=${track.kind}, enabled=${track.enabled}, label="${track.label}", id=${track.id}');
          });
          _remoteStream?.getVideoTracks().forEach((track) {
            debugPrint('[WebRTC]  Video track: kind=${track.kind}, enabled=${track.enabled}, label="${track.label}", id=${track.id}');
          });
          
          onRemoteStream?.call(_remoteStream!);
        } else {
          debugPrint('[WebRTC] ** Track reçu sans streams!');
        }
      };

      debugPrint('[WebRTC] Appel à _getUserMedia...');
      _localStream = await _getUserMedia(type);
      debugPrint('[WebRTC] !! Local stream obtenu: ${_localStream?.getTracks().length} track(s), ID=${_localStream?.id}');
      onLocalStream?.call(_localStream!);

      debugPrint('[WebRTC] Ajout des tracks au PeerConnection...');
      _localStream!.getTracks().forEach((track) {
        debugPrint('[WebRTC] ➕ Ajout track: kind=${track.kind}, enabled=${track.enabled}, label="${track.label}", id=${track.id}');
        _peerConnection!.addTrack(track, _localStream!);
      });
      debugPrint('[WebRTC] Local stream setup: Audio=${_localStream?.getAudioTracks().length}, Video=${_localStream?.getVideoTracks().length}');
       
      if (_isAndroid) {
        debugPrint('[WebRTC] Configuration des transceivers pour Android...');
        try { 
          final audioTransceivers = await _peerConnection!.getTransceivers(); 
          for (final t in audioTransceivers) {
            debugPrint('[WebRTC]   - mid=${t.mid}');
          }
        } catch (e) {
          debugPrint('[WebRTC] ** Erreur vérification transceivers: $e');
        }
      }
      
      // !! Log des transceivers (diagnostic Android)
      if (_isAndroid) {
        try {
          final transceivers = await _peerConnection!.getTransceivers();
          debugPrint('[WebRTC] 📡 Transceivers finaux: ${transceivers.length}');
          for (int i = 0; i < transceivers.length; i++) {
            final t = transceivers[i];
            debugPrint('[WebRTC]   [$i] mid=${t.mid}');
          }
        } catch (e) {
          debugPrint('[WebRTC] ** Erreur lecture des transceivers: $e');
        }
      }
      
      debugPrint('[WebRTC] ========== Initialisation WebRTC réussie ==========');
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur lors de l\'initialisation: $e');
      debugPrint('[WebRTC] Type d\'erreur: ${e.runtimeType}');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      await dispose();
      rethrow;
    }
  }

  Future<MediaStream> _getUserMedia(CallType type) async {
    try {
      debugPrint('[WebRTC] _getUserMedia - Type: $type, isWeb: $kIsWeb, Platform: ${_isAndroid ? "ANDROID" : "iOS/WEB"}');

      final dynamic audioConstraints;

      if (_isAndroid) {
        // Format compatible avec Android et flutter_webrtc
        audioConstraints = {
          'mandatory': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
        };
      } else if (kIsWeb) {
        // Format WebRTC standard pour le web
        audioConstraints = {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        };
      } else {
        // iOS et autres : accepter n'importe quel audio
        audioConstraints = true;
      }

      final constraints = <String, dynamic>{
        'audio': audioConstraints,
        'video': type == CallType.video
            ? {
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
              }
            : false,
      };

      debugPrint('[WebRTC] Contraintes: $constraints');

      try {
        return await navigator.mediaDevices.getUserMedia(constraints);
      } catch (e1) {
        debugPrint('[WebRTC] ** getUserMedia avec contraintes échouée: $e1');
        
        // Fallback avec contraintes minimales sur Android
        if (_isAndroid) {
          debugPrint('[WebRTC] 📍 Tentative fallback Android avec contraintes minimales...');
          final fallbackConstraints = <String, dynamic>{
            'audio': true,
            'video': type == CallType.video
                ? {
                    'width': {'ideal': 720},
                    'height': {'ideal': 480},
                  }
                : false,
          };
          debugPrint('[WebRTC] Contraintes fallback: $fallbackConstraints');
          return await navigator.mediaDevices.getUserMedia(fallbackConstraints);
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur getUserMedia: $e');
      debugPrint('[WebRTC] Type d\'erreur: ${e.runtimeType}');
      debugPrint('[WebRTC] Stack: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    debugPrint('[WebRTC]  Création offre SDP...');
    try {
      final offer = await _peerConnection!.createOffer();
      debugPrint('[WebRTC] !! Offre créée: type=${offer.type}, sdp_length=${offer.sdp?.length}');
      
      // Log les codecs dans l'offre (diagnostic)
      if (offer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(r'a=rtpmap:\d+ (\w+)').allMatches(offer.sdp!);
        debugPrint('[WebRTC]  Codecs dans l\'offre:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }
      
      await _peerConnection!.setLocalDescription(offer);
      debugPrint('[WebRTC] !! LocalDescription définie');
      return offer;
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur createOffer: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    debugPrint('[WebRTC]  Création réponse SDP...');
    try {
      final answer = await _peerConnection!.createAnswer();
      debugPrint('[WebRTC] !! Réponse créée: type=${answer.type}, sdp_length=${answer.sdp?.length}');
      
      // Log les codecs dans la réponse (diagnostic)
      if (answer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(r'a=rtpmap:\d+ (\w+)').allMatches(answer.sdp!);
        debugPrint('[WebRTC] Codecs dans la réponse:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }
      
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('[WebRTC] !! LocalDescription définie');
      return answer;
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur createAnswer: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> handleOffer(RTCSessionDescription offer) async {
    debugPrint('[WebRTC] 📥 Traitement offre reçue: type=${offer.type}, sdp_length=${offer.sdp?.length}');
    try {
      // Log les codecs dans l'offre reçue (diagnostic)
      if (offer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(r'a=rtpmap:\d+ (\w+)').allMatches(offer.sdp!);
        debugPrint('[WebRTC] 📋 Codecs dans l\'offre reçue:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }
      
      await _peerConnection!.setRemoteDescription(offer);
      debugPrint('[WebRTC] !! RemoteDescription (offre) définie');
      
      _remoteDescriptionSet = true;
      await _flushPendingIceCandidates();
      debugPrint('[WebRTC] !! handleOffer succès');
    } catch (e) {
      debugPrint('[WebRTC] ** handleOffer échoué: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> handleAnswer(RTCSessionDescription answer) async {
    debugPrint('[WebRTC] ... Traitement réponse reçue: type=${answer.type}, sdp_length=${answer.sdp?.length}');
    try {
      // Log les codecs dans la réponse reçue (diagnostic)
      if (answer.sdp != null && _isAndroid) {
        final audioCodecMatch = RegExp(r'a=rtpmap:\d+ (\w+)').allMatches(answer.sdp!);
        debugPrint('[WebRTC] 📋 Codecs dans la réponse reçue:');
        for (final match in audioCodecMatch) {
          debugPrint('[WebRTC]   - ${match.group(1)}');
        }
      }
      
      await _peerConnection!.setRemoteDescription(answer);
      debugPrint('[WebRTC] !! RemoteDescription (réponse) définie');
      
      _remoteDescriptionSet = true;
      await _flushPendingIceCandidates();
      debugPrint('[WebRTC] !! handleAnswer succès');
    } catch (e) {
      debugPrint('[WebRTC] ** handleAnswer échoué: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) { 
      _pendingIceCandidates.add(candidate);
      debugPrint('[WebRTC] 🧊 ICE candidate bufferisé (PC null, ${_pendingIceCandidates.length} en attente): ${candidate.candidate?.split(' ').first ?? "?"} | sdpMid=${candidate.sdpMid}');
      return;
    }
    
    if (!_remoteDescriptionSet) {
      _pendingIceCandidates.add(candidate);
      debugPrint('[WebRTC] 🧊 ICE candidate bufferisé (pas de remote desc, ${_pendingIceCandidates.length} en attente): ${candidate.candidate?.split(' ').first ?? "?"} | sdpMid=${candidate.sdpMid}');
      return;
    }
    
    try {
      debugPrint('[WebRTC] ++ Application ICE candidate: ${candidate.candidate?.split(' ').first ?? "?"} | sdpMid=${candidate.sdpMid} | sdpMLineIndex=${candidate.sdpMLineIndex}');
      await _peerConnection!.addCandidate(candidate);
      debugPrint('[WebRTC] !! ICE candidate ajouté avec succès');
    } catch (e) {
      debugPrint('[WebRTC]  addCandidate échoué: $e');
    }
  }

  Future<void> _flushPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) {
      debugPrint('[WebRTC] 🧊 Pas de candidates en attente');
      return;
    }
    
    if (_peerConnection == null) {
      debugPrint('[WebRTC] 🧊 PeerConnection null, ${_pendingIceCandidates.length} candidats non flushés');
      return;
    }
    
    debugPrint('[WebRTC] 🧊 Application de ${_pendingIceCandidates.length} ICE candidate(s) bufferisé(s)...');
    int successCount = 0;
    int failureCount = 0;
    
    for (int i = 0; i < _pendingIceCandidates.length; i++) {
      final c = _pendingIceCandidates[i];
      try {
        debugPrint('[WebRTC]   [$i] ${c.candidate?.split(' ').first ?? "?"} | sdpMid=${c.sdpMid}');
        await _peerConnection!.addCandidate(c);
        successCount++;
      } catch (e) {
        debugPrint('[WebRTC]   [$i] ** Erreur: $e');
        failureCount++;
      }
    }
    
    debugPrint('[WebRTC] 🧊 Flush terminé: $successCount réussis, $failureCount échoués');
    _pendingIceCandidates.clear();
  }

  Future<void> toggleMic() async {
    final tracks = _localStream?.getAudioTracks();
    if (tracks != null && tracks.isNotEmpty) {
      tracks.first.enabled = !tracks.first.enabled;
    }
  }

  Future<void> toggleCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      tracks.first.enabled = !tracks.first.enabled;
    }
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  Future<void> dispose() async {
    try {
      debugPrint('[WebRTC] == Nettoyage WebRTC...'); 
      debugPrint('[WebRTC] ** Arrêt des tracks locaux...');
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          try {
            debugPrint('[WebRTC]   - Track local: ${track.kind} (id=${track.id})');
            await track.stop();
          } catch (e) {
            debugPrint('[WebRTC]   ** Erreur arrêt track local: $e');
          }
        }
      }
      
      debugPrint('[WebRTC] ** Arrêt des tracks distants...');
      if (_remoteStream != null) {
        for (final track in _remoteStream!.getTracks()) {
          try {
            debugPrint('[WebRTC]   - Track distant: ${track.kind} (id=${track.id})');
            await track.stop();
          } catch (e) {
            debugPrint('[WebRTC]   ** Erreur arrêt track distant: $e');
          }
        }
      }
      
      debugPrint('[WebRTC] ** Fermeture PeerConnection...');
      try {
        await _peerConnection?.close();
      } catch (e) {
        debugPrint('[WebRTC] ** Erreur fermeture PeerConnection: $e');
      }
      
      debugPrint('[WebRTC] ** Disposition des streams...');
      try {
        await _localStream?.dispose();
        await _remoteStream?.dispose();
      } catch (e) {
        debugPrint('[WebRTC] ** Erreur disposition streams: $e');
      }
      
      _peerConnection = null;
      _localStream = null;
      _remoteStream = null;
      _remoteDescriptionSet = false;
      _pendingIceCandidates.clear();

      debugPrint('[WebRTC] !! Nettoyage complété avec succès');
    } catch (e) {
      debugPrint('[WebRTC] ** Erreur dispose globale: $e');
      debugPrint('[WebRTC] Stack trace: ${StackTrace.current}');
    }
  }
}