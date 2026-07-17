import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Accusé de réception unifié (liste + bulles).
/// 0=horloge, 1=✓, 2=✓✓, 3=✓✓ lu, 4=échec.
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({
    super.key,
    required this.status,
    this.deliveredAt,
    this.readAt,
    this.size = 12,
    this.onBubble = false,
    this.timeFormatter,
  });

  final int? status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final double size;
  /// Sur bulle sortante : teinte onPrimary pour 0/1/2.
  final bool onBubble;
  final String Function(DateTime dt)? timeFormatter;

  @override
  Widget build(BuildContext context) {
    final s = status ?? 1;
    final muted = onBubble
        ? context.colors.onPrimary.withAlpha(180)
        : context.colors.onSurfaceVariant;
    final readColor = context.semantic.info;
    final errorColor = context.colors.error;

    String? tip;
    Widget icon;
    switch (s) {
      case 0:
        tip = 'En attente';
        icon = Icon(Icons.schedule, size: size, color: muted);
      case 1:
        tip = 'Envoyé';
        icon = Icon(Icons.check, size: size, color: muted);
      case 2:
        tip = deliveredAt != null && timeFormatter != null
            ? 'Livré à ${timeFormatter!(deliveredAt!)}'
            : 'Livré';
        icon = Icon(Icons.done_all, size: size + (onBubble ? 0 : 2), color: muted);
      case 3:
        tip = readAt != null && timeFormatter != null
            ? 'Lu à ${timeFormatter!(readAt!)}'
            : 'Lu';
        icon = Icon(Icons.done_all, size: size + (onBubble ? 0 : 2), color: readColor);
      case 4:
        tip = 'Échec appui long pour réessayer';
        icon = Icon(Icons.error_outline, size: size + (onBubble ? 0 : 2), color: errorColor);
      default:
        return const SizedBox.shrink();
    }
    return Tooltip(message: tip, child: icon);
  }
}
