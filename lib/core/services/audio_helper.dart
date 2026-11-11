import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call/call_audio_routes.dart';

/// Ce que le natif rapporte après une demande de sortie audio.
///
/// [routeName] est la sortie **réellement** appliquée par Telecom, quand il la
/// connaît ; [supportedMask] la liste des sorties qu'il déclare atteignables.
/// Les deux sont nuls quand aucune connexion Telecom ne tient l'appel.
class AppliedAudioRoute {
  const AppliedAudioRoute({
    this.routeName,
    this.supportedMask,
    this.routeBeforeName,
  });

  final String? routeName;
  final int? supportedMask;

  /// Sortie que Telecom tenait juste avant la demande.
  final String? routeBeforeName;
}

/// Routage audio WebRTC et session audio « appel » (voiceChat / videoChat).
class AudioHelper {
  static AudioSession? _session;
  static bool _callAudioActive = false;
  static bool _subscribed = false;

  /// Active la session audio pour un appel ou une réunion en cours.
  /// [isVideo] : mode iOS `videoChat` (sinon `voiceChat`).
  static Future<void> configureCallAudio({bool isVideo = false}) async {
    if (kIsWeb) return;
    try {
      _session ??= await AudioSession.instance;
      await _session!.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: isVideo
            ? AVAudioSessionMode.videoChat
            : AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
      await _session!.setActive(true);
      _callAudioActive = true;
      _ensureEventSubscriptions();
      debugPrint(
        '[AudioHelper] Session audio appel activée '
        '(${isVideo ? "videoChat" : "voiceChat"})',
      );
    } catch (e) {
      debugPrint('[AudioHelper] ** configureCallAudio: $e');
    }
  }

  /// Relâche la session audio à la fin d'un appel/réunion.
  static Future<void> releaseCallAudio() async {
    if (kIsWeb) return;
    _callAudioActive = false;
    try {
      await _session?.setActive(false);
      debugPrint('[AudioHelper] Session audio appel relâchée');
    } catch (e) {
      debugPrint('[AudioHelper] ** releaseCallAudio: $e');
    }
  }

  /// Réactive la session après retour au premier plan.
  static Future<void> reactivateCallAudio() async {
    if (kIsWeb || _session == null || !_callAudioActive) return;
    try {
      await _session!.setActive(true);
    } catch (e) {
      debugPrint('[AudioHelper] ** reactivateCallAudio: $e');
    }
  }

  static void _ensureEventSubscriptions() {
    if (_subscribed || _session == null) return;
    _subscribed = true;

    _session!.interruptionEventStream.listen((event) {
      if (!_callAudioActive) return;
      if (event.begin) {
        debugPrint(
          '[AudioHelper] Interruption début type=${event.type}',
        );
        return;
      }
      // Fin d'interruption pendant un appel : reprendre le focus audio.
      debugPrint('[AudioHelper] Interruption fin → setActive(true)');
      _session?.setActive(true).then((_) {}, onError: (Object e) {
        debugPrint('[AudioHelper] ** setActive après interruption: $e');
      });
    });

    _session!.becomingNoisyEventStream.listen((_) {
      if (!_callAudioActive) return;
      // Appel : on ne coupe pas l'audio (contrairement à un lecteur média).
      debugPrint('[AudioHelper] becomingNoisy pendant appel (ignoré)');
    });

    _session!.devicesChangedEventStream.listen((event) {
      if (!_callAudioActive) return;
      debugPrint(
        '[AudioHelper] devicesChanged '
        '+${event.devicesAdded.length} -${event.devicesRemoved.length}',
      );
      _outputsChanged.add(null);
    });
  }

  /// Émet à chaque branchement ou débranchement pendant un appel.
  static final StreamController<void> _outputsChanged =
      StreamController<void>.broadcast();

  /// Un casque appairé en cours d'appel doit se voir sans que l'utilisateur
  /// ait à toucher quoi que ce soit.
  static Stream<void> get audioOutputsChanged => _outputsChanged.stream;

  /// Familles de sorties audio actuellement disponibles.
  ///
  /// La liste plateforme est réduite aux quatre familles qui comptent pour un
  /// appel ; voir `call/call_audio_routes.dart` pour la correspondance.
  static Future<Set<AudioOutputKind>> availableOutputKinds() async {
    if (kIsWeb) return {};
    try {
      _session ??= await AudioSession.instance;
      final devices = await _session!.getDevices(includeInputs: false);
      final kinds = <AudioOutputKind>{};
      for (final device in devices) {
        final kind = audioOutputKindFromTypeName(device.type.name);
        if (kind != AudioOutputKind.other) kinds.add(kind);
      }
      return kinds;
    } catch (e) {
      debugPrint('[AudioHelper] ** availableOutputKinds: $e');
      return {};
    }
  }

  static const _callAudioChannel =
      MethodChannel('com.alanya237.alanya/call_audio');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Applique une sortie, et rend ce que le natif en dit.
  ///
  /// Depuis que chaque appel est déclaré à Telecom, c'est le système qui
  /// possède la route : les demandes adressées à `AudioManager` — ce que fait
  /// la couche WebRTC — sont ignorées, et le bouton ne changeait plus rien. On
  /// s'adresse donc à la connexion Telecom quand il y en a une.
  ///
  /// Le repli WebRTC reste nécessaire : réunion ou appel sans connexion
  /// Telecom, Android antérieur à 8, iOS, tests. Là aussi, chaque sortie se
  /// demande par son nom sur Android — l'ancien couple « haut-parleur oui/non »
  /// renvoyait « écouteur » vers le casque Bluetooth dès qu'il y en avait un.
  /// Sur iOS, seule la bascule haut-parleur existe, et `selectAudioOutput` n'y
  /// comprend rien d'autre : on garde le chemin d'avant.
  static Future<AppliedAudioRoute> applyAudioRoute(
    CallAudioRoute route, {
    String? telecomCallId,
  }) async {
    if (kIsWeb) return const AppliedAudioRoute();

    final parTelecom = await _applyViaTelecom(route, telecomCallId);
    if (parTelecom != null) {
      debugPrint(
        '[AudioHelper] 🔊 Sortie audio (Telecom): '
        '${parTelecom.routeName ?? route.name}',
      );
      return parTelecom;
    }

    try {
      if (_isAndroid) {
        await Helper.selectAudioOutput(webrtcDeviceId(route));
      } else if (route == CallAudioRoute.bluetooth) {
        await Helper.setSpeakerphoneOnButPreferBluetooth();
      } else {
        await Helper.setSpeakerphoneOn(speakerphoneForRoute(route));
      }
      debugPrint('[AudioHelper] 🔊 Sortie audio: ${route.name}');
    } catch (e) {
      debugPrint('[AudioHelper] ** applyAudioRoute(${route.name}): $e');
    }
    return const AppliedAudioRoute();
  }

  /// Demande la sortie à la connexion Telecom de [callId].
  ///
  /// Rend `null` dès qu'il n'y a pas de connexion — c'est le signal de repli.
  static Future<AppliedAudioRoute?> _applyViaTelecom(
    CallAudioRoute route,
    String? callId,
  ) async {
    final id = callId?.trim() ?? '';
    if (id.isEmpty || !_isAndroid) return null;
    try {
      final reponse = await _callAudioChannel.invokeMapMethod<String, dynamic>(
        'setRoute',
        {'callId': id, 'route': telecomRouteName(route)},
      );
      if (reponse == null) return null;
      return AppliedAudioRoute(
        routeName: reponse['route'] as String?,
        supportedMask: (reponse['available'] as num?)?.toInt(),
        routeBeforeName: reponse['before'] as String?,
      );
    } on MissingPluginException {
      // Build sans le pont natif (tests, ancienne version) : le repli suffit.
      return null;
    } catch (e) {
      debugPrint('[AudioHelper] ** route Telecom (${route.name}): $e');
      return null;
    }
  }

  /// Relit la sortie réellement appliquée, sans rien demander.
  ///
  /// Sert quand la liste des périphériques change en cours d'appel : Telecom a
  /// pu rebasculer tout seul, et l'interface doit suivre.
  static Future<AppliedAudioRoute?> readAppliedRoute(String? callId) async {
    final id = callId?.trim() ?? '';
    if (id.isEmpty || !_isAndroid) return null;
    try {
      final reponse = await _callAudioChannel.invokeMapMethod<String, dynamic>(
        'readRoute',
        {'callId': id},
      );
      if (reponse == null) return null;
      return AppliedAudioRoute(
        routeName: reponse['route'] as String?,
        supportedMask: (reponse['available'] as num?)?.toInt(),
      );
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('[AudioHelper] ** lecture de la route Telecom: $e');
      return null;
    }
  }

  /// Attend que Telecom tienne l'appel [callId] et connaisse sa sortie audio.
  ///
  /// Telecom crée sa connexion après coup : mesuré à 500 ms après `startCall`
  /// sur un Xiaomi sous Android 16. Rend `false` sans attendre s'il n'y a pas de
  /// pont natif, et à l'échéance si la connexion ne vient pas.
  static Future<bool> waitForTelecomConnection(
    String? callId, {
    Duration timeout = const Duration(seconds: 3),
    Duration interval = const Duration(milliseconds: 150),
  }) async {
    final id = callId?.trim() ?? '';
    if (id.isEmpty || !_isAndroid) return false;
    final echeance = DateTime.now().add(timeout);
    while (true) {
      try {
        final reponse = await _callAudioChannel
            .invokeMapMethod<String, dynamic>('readRoute', {'callId': id});
        if (reponse != null) return true;
      } on MissingPluginException {
        return false;
      } catch (e) {
        debugPrint('[AudioHelper] ** attente de la connexion Telecom: $e');
        return false;
      }
      if (!DateTime.now().isBefore(echeance)) return false;
      await Future<void>.delayed(interval);
    }
  }

  static Future<void> setSpeakerphoneOn(bool on) async {
    if (kIsWeb) return;
    try {
      await Helper.setSpeakerphoneOn(on);
      debugPrint('[AudioHelper] Speaker phone: $on');
    } catch (e) {
      debugPrint('[AudioHelper] ** setSpeakerphoneOn: $e');
    }
  }

  static Future<void> switchCamera(MediaStreamTrack videoTrack) async {
    if (kIsWeb) return;
    try {
      await Helper.switchCamera(videoTrack);
    } catch (e) {
      debugPrint('[AudioHelper] ** switchCamera: $e');
    }
  }
}
