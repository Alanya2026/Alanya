import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';

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
    this.onRetry,
  });

  final int? status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final double size;
  /// Sur bulle sortante : teinte onPrimary pour 0/1/2.
  final bool onBubble;
  final String Function(DateTime dt)? timeFormatter;
  /// Tap sur l’icône d’échec → réessayer l’envoi (menu long-press conservé ailleurs).
  final VoidCallback? onRetry;

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
        tip = context.l10n.statusPending;
        icon = Icon(Icons.schedule, size: size, color: muted);
      case 1:
        tip = context.l10n.statusSent;
        icon = Icon(Icons.check, size: size, color: muted);
      case 2:
        tip = deliveredAt != null && timeFormatter != null
            ? LocaleController.instance.l10n.deliveredAtTime(timeFormatter!(deliveredAt!))
            : context.l10n.statusDelivered;
        icon = Icon(Icons.done_all, size: size + (onBubble ? 0 : 2), color: muted);
      case 3:
        tip = readAt != null && timeFormatter != null
            ? LocaleController.instance.l10n.readAtTime(timeFormatter!(readAt!))
            : context.l10n.statusRead;
        icon = Icon(Icons.done_all, size: size + (onBubble ? 0 : 2), color: readColor);
      case 4:
        tip = onRetry != null
            ? context.l10n.statusFailedRetry
            : context.l10n.longPressFailedTryAgain;
        icon = Icon(Icons.error_outline, size: size + (onBubble ? 0 : 2), color: errorColor);
      default:
        return const SizedBox.shrink();
    }

    final child = Tooltip(message: tip, child: icon);
    if (s == 4 && onRetry != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: child,
      );
    }
    return child;
  }
}
