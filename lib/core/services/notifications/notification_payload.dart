/// Contrat de payload notification v2, rétrocompatible avec le format legacy.
class NotificationPayload {
  const NotificationPayload({
    required this.schemaVersion,
    required this.type,
    this.eventId = '',
    this.msgID = 0,
    this.clientId = '',
    this.conversationId = 0,
    this.senderId = 0,
    this.senderName = '',
    this.senderAvatar = '',
    this.title = '',
    this.body = '',
    this.msgType = 0,
    this.isGroup = false,
    this.groupName = '',
    this.groupAvatar = '',
    this.sentAt,
    this.unreadTotal = 0,
    this.legacyCallerId = 0,
    this.raw = const {},
  });

  static const schemaV2 = '2';

  final String schemaVersion;
  final String type;
  final String eventId;
  final int msgID;
  final String clientId;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String senderAvatar;
  final String title;
  final String body;
  final int msgType;
  final bool isGroup;
  final String groupName;
  final String groupAvatar;
  final DateTime? sentAt;
  final int unreadTotal;

  /// Alias legacy `callerId` (peer / expéditeur).
  final int legacyCallerId;

  /// Données brutes normalisées (toutes les clés en String).
  final Map<String, String> raw;

  bool get isV2 => schemaVersion == schemaV2;

  /// Parse un payload FCM / socket / local sans exception fatale.
  factory NotificationPayload.fromMap(Map<String, dynamic>? source) {
    if (source == null || source.isEmpty) {
      return const NotificationPayload(
        schemaVersion: '1',
        type: 'message',
      );
    }

    final normalized = <String, String>{
      for (final e in source.entries)
        e.key: e.value?.toString() ?? '',
    };

    final type = normalized['type']?.trim().isNotEmpty == true
        ? normalized['type']!
        : 'message';

    final schemaVersion = normalized['schemaVersion']?.trim().isNotEmpty == true
        ? normalized['schemaVersion']!
        : '1';

    final conversationId =
        _parseInt(normalized['conversationId'] ?? normalized['conversationID']);
    final senderId = _parseInt(normalized['senderId'] ?? normalized['senderID']);
    final legacyCallerId = _parseInt(normalized['callerId'] ?? normalized['callerID']);
    final msgID = _parseInt(normalized['msgID'] ?? normalized['msgId']);
    final msgType = _parseInt(normalized['msgType'] ?? normalized['type']);
    final isGroup =
        normalized['isGroup'] == '1' || normalized['isGroup']?.toLowerCase() == 'true';

    var eventId = normalized['eventId'] ?? '';
    if (eventId.isEmpty && msgID > 0) {
      eventId = 'legacy_msg_$msgID';
    }

    final sentAtRaw = normalized['sentAt'] ?? normalized['createdAt'];
    final sentAt = sentAtRaw != null && sentAtRaw.isNotEmpty
        ? DateTime.tryParse(sentAtRaw)
        : null;

    return NotificationPayload(
      schemaVersion: schemaVersion,
      type: type,
      eventId: eventId,
      msgID: msgID,
      clientId: normalized['clientId'] ?? normalized['clientID'] ?? '',
      conversationId: conversationId,
      senderId: senderId > 0 ? senderId : legacyCallerId,
      senderName: normalized['senderName'] ?? normalized['title'] ?? '',
      senderAvatar: normalized['senderAvatar'] ?? normalized['photo'] ?? '',
      title: normalized['title'] ?? '',
      body: normalized['body'] ?? '',
      msgType: _mediaMsgType(normalized, msgType),
      isGroup: isGroup,
      groupName: normalized['groupName'] ?? '',
      groupAvatar: normalized['groupAvatar'] ?? '',
      sentAt: sentAt,
      unreadTotal: _parseInt(normalized['unreadTotal']),
      legacyCallerId: legacyCallerId,
      raw: normalized,
    );
  }

  /// Convertit en map pour encodage payload local / navigation.
  Map<String, String> toDataMap() => Map<String, String>.from(raw);

  static int _parseInt(String? value) {
    if (value == null || value.isEmpty) return 0;
    return int.tryParse(value) ?? 0;
  }

  /// Évite de confondre `type: message` avec `msgType` média en legacy.
  static int _mediaMsgType(Map<String, String> normalized, int parsedMsgType) {
    if (normalized.containsKey('msgType')) return parsedMsgType;
    final typeVal = normalized['type'] ?? '';
    if (typeVal == 'message' || typeVal.isEmpty) return 0;
    final asInt = int.tryParse(typeVal);
    if (asInt != null && asInt >= 0 && asInt <= 10) return asInt;
    return parsedMsgType;
  }
}
