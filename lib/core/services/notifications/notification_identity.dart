/// Identifiants déterministes pour notifications par conversation (Android tag/id).
class NotificationIdentity {
  NotificationIdentity._();

  static const _convTagPrefix = 'conv_';

  /// Tag Android stable par conversation.
  static String tagForConversation(int conversationId) =>
      '$_convTagPrefix$conversationId';

  /// ID notification Android/iOS dérivé de conversationId (FNV-1a 31 bits).
  /// Documenté et stable entre exécutions Dart (contrairement à hashCode).
  static int notificationIdForConversation(int conversationId) {
    if (conversationId <= 0) return 0;
    return _fnv1a31(conversationId.toString()) & 0x7fffffff;
  }

  /// FNV-1a 32-bit réduit à 31 bits positifs.
  static int _fnv1a31(String input) {
    const fnvPrime = 0x01000193;
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash;
  }
}
