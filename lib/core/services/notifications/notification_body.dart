/// Corps de notification groupe : le serveur préfixe déjà `Nom: ` pour iOS / FCM
/// système. MessagingStyle affiche le nom via [Person]. Re-préfixer côté client
/// produisait « Nom: Nom: Nom: message ».
class NotificationBody {
  NotificationBody._();

  /// Retire jusqu'à [maxStrips] préfixes `sender: ` en tête.
  ///
  /// [maxStrips] = 2 : un pour le contrat serveur, un pour l'ancien préfixe
  /// client encore présent dans le buffer local.
  static String stripLeadingSenderPrefix(
    String sender,
    String body, {
    int maxStrips = 2,
  }) {
    final name = sender.trim();
    if (name.isEmpty || body.isEmpty || maxStrips <= 0) return body;
    final prefix = '$name: ';
    var out = body;
    var n = 0;
    while (n < maxStrips && out.startsWith(prefix)) {
      out = out.substring(prefix.length);
      n++;
    }
    return out;
  }

  /// Expéditeur réel. En groupe, `title` est le nom du groupe — ne pas s'en
  /// servir comme Person MessagingStyle.
  static String resolveSenderName({
    required Map<String, dynamic> data,
    String? title,
    required bool isGroup,
    required String fallback,
  }) {
    final fromData = data['senderName']?.toString().trim() ?? '';
    if (fromData.isNotEmpty) return fromData;
    if (!isGroup) {
      final fromTitle = (title ?? data['title']?.toString() ?? '').trim();
      if (fromTitle.isNotEmpty) return fromTitle;
    }
    return fallback;
  }
}
