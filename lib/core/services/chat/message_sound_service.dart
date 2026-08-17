import 'package:audio_session/audio_session.dart' show AndroidAudioAttributes, AndroidAudioContentType, AndroidAudioUsage;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../ringtone_preferences.dart';

/// Retours sonores UI :
///  - envoi / réception de message,
///  - scan QR réussi (contact ou connexion appareil),
///  - fin d'un appel qui était en cours.
///
/// Les sons sont routés sur le canal **notification** Android
/// (`AndroidAudioUsage.notification`) : ils sont donc automatiquement coupés
/// quand le téléphone est en mode silencieux / vibreur, sans code natif.
/// (Le clic à la frappe est laissé au clavier système du téléphone.)
///
/// Singleton (pas de BuildContext) : appelable depuis l'UI comme depuis les
/// handlers socket.
class MessageSoundService {
  MessageSoundService._();
  static final MessageSoundService instance = MessageSoundService._();

  static const _sentAsset = 'assets/sounds/ui/message_sent.ogg';
  static const _receivedAsset = 'assets/sounds/ui/message_received.ogg';
  static const _qrScanSuccessAsset = 'assets/sounds/ui/qr_scan_success.ogg';
  static const _callEndAsset = 'assets/sounds/ui/call_end.ogg';

  // Attributs « notification » → coupés en silencieux/vibreur par l'OS.
  static const _uiAttributes = AndroidAudioAttributes(
    contentType: AndroidAudioContentType.sonification,
    usage: AndroidAudioUsage.notification,
  );

  AudioPlayer? _sentPlayer;
  AudioPlayer? _receivedPlayer;
  AudioPlayer? _qrScanSuccessPlayer;
  AudioPlayer? _callEndPlayer;
  bool _ready = false;

  /// Précharge les lecteurs (à appeler une fois au démarrage). Sans réseau :
  /// les sons sont des assets embarqués.
  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      // handleInterruptions:false → nos petits sons UI ne sont PAS mis en pause
      // quand le focus audio est pris ailleurs (caméra, galerie, visionneuse
      // vue-unique, lecture d'un vocal…) : sinon un son d'envoi/réception de
      // média ne jouait pas car on arrivait d'un contexte média.
      // handleAudioSessionActivation:false → on ne touche pas à la session
      // audio globale (partagée avec les appels).
      _sentPlayer = AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
      );
      _receivedPlayer = AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
      );
      _qrScanSuccessPlayer = AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
      );
      _callEndPlayer = AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
      );
      await _sentPlayer!.setAndroidAudioAttributes(_uiAttributes);
      await _receivedPlayer!.setAndroidAudioAttributes(_uiAttributes);
      await _qrScanSuccessPlayer!.setAndroidAudioAttributes(_uiAttributes);
      await _callEndPlayer!.setAndroidAudioAttributes(_uiAttributes);
      await _sentPlayer!.setAsset(_sentAsset);
      await _receivedPlayer!.setAsset(_receivedAsset);
      await _qrScanSuccessPlayer!.setAsset(_qrScanSuccessAsset);
      await _callEndPlayer!.setAsset(_callEndAsset);
      await _sentPlayer!.setVolume(0.55);
      await _receivedPlayer!.setVolume(0.7);
      // Accusés de scan / fin d'appel à plein volume : le canal notification
      // les atténue déjà (volume sonnerie du téléphone, souvent bas), donc on
      // ne réduit pas une deuxième fois côté lecteur.
      await _qrScanSuccessPlayer!.setVolume(1.0);
      await _callEndPlayer!.setVolume(1.0);
      _ready = true;
    } catch (e) {
      debugPrint('[MessageSound] init échoué: $e');
    }
  }

  /// Son d'envoi d'un message (feedback immédiat quand l'utilisateur envoie).
  void playSent() => _replay(_sentPlayer);

  /// Son de réception d'un nouveau message (à jouer app au premier plan ;
  /// en arrière-plan c'est la notification qui sonne — voir appelant).
  void playReceived({RingtoneOption? override}) {
    if (override == null || override.type == RingtoneSourceType.system) {
      _replay(_receivedPlayer);
      return;
    }
    _playOptionOnce(override);
  }

  Future<void> _playOptionOnce(RingtoneOption option) async {
    if (kIsWeb) return;
    final player = _receivedPlayer;
    if (player == null || !_ready) return;
    try {
      if (option.type == RingtoneSourceType.bundled) {
        await player.setAsset(option.assetPath!);
      } else {
        await player.setFilePath(option.filePath!);
      }
      await player.setLoopMode(LoopMode.off);
      await player.seek(Duration.zero);
      await player.play();
      // Le prochain message sans personnalisation retrouve le son standard.
      await player.setAsset(_receivedAsset);
    } catch (e) {
      debugPrint('[MessageSound] son de liste échoué: $e');
      try {
        await player.setAsset(_receivedAsset);
      } catch (_) {}
    }
  }

  /// Son de scan QR réussi : contact ajouté / déjà connu, ou code de connexion
  /// appareil reconnu. Pas d'erreur, pas son propre code.
  void playQrScanSuccess() => _replay(_qrScanSuccessPlayer);

  /// Son de fin d'appel : deux notes descendantes, joué seulement quand une
  /// conversation était réellement établie (pas sur un rejet ou un échec).
  void playCallEnd() => _replay(_callEndPlayer);

  void _replay(AudioPlayer? player) {
    if (kIsWeb || player == null || !_ready) return;
    // Rejoue depuis le début même si le son précédent n'est pas fini.
    player.seek(Duration.zero).then((_) => player.play()).catchError((e) {
      debugPrint('[MessageSound] lecture échouée: $e');
    });
  }

  Future<void> dispose() async {
    await _sentPlayer?.dispose();
    await _receivedPlayer?.dispose();
    await _qrScanSuccessPlayer?.dispose();
    await _callEndPlayer?.dispose();
    _sentPlayer = null;
    _receivedPlayer = null;
    _qrScanSuccessPlayer = null;
    _callEndPlayer = null;
    _ready = false;
  }
}
