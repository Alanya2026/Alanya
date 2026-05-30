import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Pastille de comptage (messages non lus, notifications).
///
/// Gère le débordement (`99+`) et s'adapte aux comptes à 1/2/3 chiffres.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.color,
    this.textColor,
    this.borderColor,
  });

  final int count;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      decoration: BoxDecoration(
        color: color ?? colors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: context.text.labelSmall?.copyWith(
          color: textColor ?? colors.onPrimary,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// Point de présence « en ligne » (vert) avec liseré pour le détacher du fond.
class PresenceDot extends StatelessWidget {
  const PresenceDot({
    super.key,
    required this.online,
    this.size = 12,
    this.borderColor,
  });

  final bool online;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: online ? context.semantic.online : colors.outlineVariant,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? colors.surface,
          width: 2,
        ),
      ),
    );
  }
}
