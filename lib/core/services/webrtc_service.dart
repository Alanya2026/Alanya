import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallType { audio, video }

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCSessionDescription)? onOffer;
  Function(RTCSessionDescription)? onAnswer;

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Vérifier et demander les permissions microphone pour Android/iOS
  Future<bool> _requestMicrophonePermission() async {
    // Sur web, les permissions sont gérées par le navigateur via getUserMedia
    if (kIsWeb) return true;

    final status = await Permission.microphone.request();
    debugPrint('[WebRTC] Permission microphone: ${status.toString()}');

    return status.isGranted;
  }

  /// Vérifier et demander les permissions caméra pour Android/iOS
  Future<bool> _requestCameraPermission() async {
    // Sur web, les permissions sont gérées par le navigateur via getUserMedia
    if (kIsWeb) return true;

    final status = await Permission.camera.request();
    debugPrint('[WebRTC] Permission caméra: ${status.toString()}');

    return status.isGranted;
  }

  Future<void> init(CallType type) async {
    try {
      debugPrint('[WebRTC] ========== Initialisation WebRTC ==========');
      debugPrint('[WebRTC] isWeb: $kIsWeb, Platform: ${kIsWeb ? "WEB" : (Platform.isAndroid ? "ANDROID" : "iOS")}');
      debugPrint('[WebRTC] Call Type: $type');

      // ✅ Sur mobile, demander les permissions
      if (!kIsWeb) {
        final micGranted = await _requestMicrophonePermission();
        if (!micGranted) {
          throw Exception('Permission microphone refusée');
        }

        if (type == CallType.video) {
          final cameraGranted = await _requestCameraPermission();
          if (!cameraGranted) {
            debugPrint('[WebRTC] ⚠️ Permission caméra refusée — continuant avec audio uniquement');
          }
        }
      } else {
        debugPrint('[WebRTC] Plateforme WEB - Les permissions seront demandées par le navigateur via getUserMedia');
      }

      final configuration = {
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
        ]
      };

      debugPrint('[WebRTC] Création du PeerConnection...');
      _peerConnection = await createPeerConnection(configuration);
      debugPrint('[WebRTC] PeerConnection créé avec succès');

      _peerConnection!.onIceCandidate = (candidate) {
        debugPrint('[WebRTC] Nouveau ICE candidate');
        onIceCandidate?.call(candidate);
      };

      _peerConnection!.onTrack = (event) {
        debugPrint('[WebRTC] Track reçu: ${event.streams.length} streams');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint('[WebRTC] Remote stream assigné');
          debugPrint('[WebRTC] 📊 Remote stream tracks: Audio=${_remoteStream?.getAudioTracks().length}, Video=${_remoteStream?.getVideoTracks().length}');
          
          // Log détails des pistes audio
          _remoteStream?.getAudioTracks().forEach((track) {
            debugPrint('[WebRTC] 🎵 Audio track - kind=${track.kind}, enabled=${track.enabled}, label=${track.label}');
          });
          
          onRemoteStream?.call(_remoteStream!);
        }
      };

      debugPrint('[WebRTC] Appel à _getUserMedia...');
      _localStream = await _getUserMedia(type);
      debugPrint('[WebRTC] Local stream obtenu: ${_localStream?.getTracks().length} tracks');
      onLocalStream?.call(_localStream!);

      debugPrint('[WebRTC] Ajout des tracks au PeerConnection...');
      _localStream!.getTracks().forEach((track) {
        debugPrint('[WebRTC] Ajout track: ${track.kind} (enabled=${track.enabled}, label=${track.label})');
        _peerConnection!.addTrack(track, _localStream!);
      });
      debugPrint('[WebRTC] 📊 Local stream setup: Audio=${_localStream?.getAudioTracks().length}, Video=${_localStream?.getVideoTracks().length}');
      debugPrint('[WebRTC] ========== Initialisation WebRTC réussie ==========');
    } catch (e) {
      debugPrint('[WebRTC] ❌ Erreur lors de l\'initialisation: $e');
      debugPrint('[WebRTC] Type d\'erreur: ${e.runtimeType}');
      await dispose();
      rethrow;
    }
  }

  Future<MediaStream> _getUserMedia(CallType type) async {
    try {
      debugPrint('[WebRTC] _getUserMedia - Type: $type, isWeb: $kIsWeb');

      final constraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': type == CallType.video
            ? {
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
                'frameRate': {'ideal': 30},
              }
            : false,
      };

      debugPrint('[WebRTC] Contraintes: $constraints');

      return await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      debugPrint('[WebRTC] Erreur getUserMedia: $e');
      debugPrint('[WebRTC] Stack: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> handleOffer(RTCSessionDescription offer) async {
    debugPrint('[WebRTC] handleOffer: type=${offer.type}, sdp length=${offer.sdp?.length}');
    try {
      await _peerConnection!.setRemoteDescription(offer);
      debugPrint('[WebRTC] ✅ handleOffer success');
    } catch (e) {
      debugPrint('[WebRTC] ❌ handleOffer failed: $e');
      rethrow;
    }
  }

  Future<void> handleAnswer(RTCSessionDescription answer) async {
    debugPrint('[WebRTC] handleAnswer: type=${answer.type}, sdp length=${answer.sdp?.length}, pc=${_peerConnection != null}');
    try {
      await _peerConnection!.setRemoteDescription(answer);
      debugPrint('[WebRTC] ✅ handleAnswer success');
    } catch (e) {
      debugPrint('[WebRTC] ❌ handleAnswer failed: $e');
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  Future<void> toggleMic() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  Future<void> toggleCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
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
      debugPrint('[WebRTC] 🧹 Nettoyage WebRTC...');
      
      // ✅ Éteindre tous les tracks avant de disposer le stream
      _localStream?.getTracks().forEach((track) async {
        await track.stop();
      });
      
      _remoteStream?.getTracks().forEach((track) async {
        await track.stop();
      });
      
      // ✅ Fermer le PeerConnection
      await _peerConnection?.close();
      
      // ✅ Disposer les streams
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      
      // ✅ Réinitialiser les références
      _peerConnection = null;
      _localStream = null;
      _remoteStream = null;
      
      debugPrint('[WebRTC] ✅ Nettoyage complété');
    } catch (e) {
      debugPrint('[WebRTC] ❌ Erreur dispose: $e');
    }
  }
}
