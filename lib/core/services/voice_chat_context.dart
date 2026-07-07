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

  const VoicePlaybackSource({
    required this.messageId,
    this.localPath,
    this.networkUrl,
    this.fallbackDuration = Duration.zero,
  });
}
