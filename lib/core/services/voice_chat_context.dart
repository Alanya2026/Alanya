import '../utils/audio_message_kind.dart';

/// Contexte de conversation pour le mini-lecteur vocal.
class VoiceChatContext {
  final int conversationId;
  final String title;
  final int? userId;
  final bool isGroup;
  final String? avatarUrl;

  const VoiceChatContext({
    required this.conversationId,
    required this.title,
    this.userId,
    this.isGroup = false,
    this.avatarUrl,
  });
}

/// Source audio mémorisée pour reprendre la lecture hors du chat.
class VoicePlaybackSource {
  final String messageId;
  final String? localPath;
  final String? networkUrl;
  final Duration fallbackDuration;

  /// Libellé affiché par le mini-lecteur : titre du morceau, ou
  /// « Message vocal · contact ». Le nom de la conversation seul ne suffit pas
  /// à savoir ce qui joue.
  final String? title;

  /// Vocal ou musique — décide de la préférence de vitesse appliquée.
  final AudioMessageKind kind;

  /// Id serveur du message, pour que le mini-lecteur ramène jusqu'à la bulle
  /// et pas seulement jusqu'à la conversation. `0` si pas encore envoyé.
  final int serverMsgId;

  const VoicePlaybackSource({
    required this.messageId,
    this.localPath,
    this.networkUrl,
    this.fallbackDuration = Duration.zero,
    this.title,
    this.kind = AudioMessageKind.voiceNote,
    this.serverMsgId = 0,
  });
}
