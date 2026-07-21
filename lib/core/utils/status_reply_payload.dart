/// Métadonnées d'une réponse à un statut, encodées dans [LocalMessage.replyToContent].
///
/// Format :
/// `__talky_status_reply__|<type>|<url>|<bg>|<statusId>|<authorId>\n<preview>`
///
/// `statusId` / `authorId` optionnels (messages legacy sans navigation).
const statusReplyMarkerPrefix = '__talky_status_reply__';

class StatusReplyPayload {
  const StatusReplyPayload({
    required this.type,
    required this.preview,
    this.mediaUrl,
    this.backgroundColor,
    this.statusId,
    this.authorId,
  });

  /// 0=texte, 1=image, 2=vidéo, 3=audio
  final int type;
  final String preview;
  final String? mediaUrl;
  final String? backgroundColor;
  final int? statusId;
  final int? authorId;

  bool get hasVisualThumb =>
      type == 0 || type == 1 || type == 2 || type == 3;

  bool get canOpenStatus => statusId != null && statusId! > 0;
}

String encodeStatusReplyContent({
  required int type,
  required String preview,
  String? mediaUrl,
  String? backgroundColor,
  int? statusId,
  int? authorId,
}) {
  final url = Uri.encodeComponent(mediaUrl?.trim() ?? '');
  final bg = Uri.encodeComponent(backgroundColor?.trim() ?? '');
  final sid = (statusId != null && statusId > 0) ? '$statusId' : '';
  final aid = (authorId != null && authorId > 0) ? '$authorId' : '';
  final text = preview.trim().isEmpty ? ' ' : preview.trim();
  return '$statusReplyMarkerPrefix|$type|$url|$bg|$sid|$aid\n$text';
}

StatusReplyPayload? parseStatusReplyContent(String? raw) {
  if (raw == null || !raw.startsWith(statusReplyMarkerPrefix)) return null;
  final nl = raw.indexOf('\n');
  final header = nl >= 0 ? raw.substring(0, nl) : raw;
  final preview = nl >= 0 ? raw.substring(nl + 1).trim() : '';
  final parts = header.split('|');
  if (parts.length < 2) return null;

  final type = int.tryParse(parts[1]) ?? 0;

  String? mediaUrl;
  if (parts.length > 2 && parts[2].isNotEmpty) {
    mediaUrl = Uri.decodeComponent(parts[2]);
    if (mediaUrl.isEmpty) mediaUrl = null;
  }

  String? backgroundColor;
  if (parts.length > 3 && parts[3].isNotEmpty) {
    backgroundColor = Uri.decodeComponent(parts[3]);
    if (backgroundColor.isEmpty) backgroundColor = null;
  }

  int? statusId;
  if (parts.length > 4 && parts[4].isNotEmpty) {
    statusId = int.tryParse(parts[4]);
    if (statusId != null && statusId <= 0) statusId = null;
  }

  int? authorId;
  if (parts.length > 5 && parts[5].isNotEmpty) {
    authorId = int.tryParse(parts[5]);
    if (authorId != null && authorId <= 0) authorId = null;
  }

  return StatusReplyPayload(
    type: type,
    preview: preview,
    mediaUrl: mediaUrl,
    backgroundColor: backgroundColor,
    statusId: statusId,
    authorId: authorId,
  );
}

String statusReplyDisplayText(String? raw) {
  final parsed = parseStatusReplyContent(raw);
  if (parsed != null) return parsed.preview;
  return raw ?? '';
}
