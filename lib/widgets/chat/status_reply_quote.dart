import 'package:flutter/material.dart';

import '../../core/navigation/open_status.dart';
import '../../core/utils/status_reply_payload.dart';
import 'reply_quote_bar.dart';
import 'status_reply_thumb.dart';

/// Citation compacte cliquable d'une réponse à un statut (direction A).
class StatusReplyQuote extends StatelessWidget {
  const StatusReplyQuote({
    super.key,
    required this.payload,
    required this.accent,
    required this.textColor,
  });

  final StatusReplyPayload payload;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final thumb = payload.hasVisualThumb
        ? StatusReplyThumb(payload: payload, size: 40)
        : null;
    return ReplyQuoteBar(
      accent: accent,
      body: payload.preview,
      bodyColor: textColor,
      thumb: thumb,
      onTap: payload.canOpenStatus
          ? () => openStatusById(context, payload.statusId!)
          : null,
    );
  }
}
