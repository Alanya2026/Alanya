import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Bouton d'action circulaire pour l'écran d'appel entrant (Refuser / Accepter).
class CallActionButton extends StatefulWidget {
  const CallActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  State<CallActionButton> createState() => _CallActionButtonState();
}

class _CallActionButtonState extends State<CallActionButton> {
  bool _pressed = false;

  void _handleTap() {
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final labelColor = widget.labelColor ?? callUi.onBackground.withValues(alpha: 0.75);

    return Semantics(
      button: true,
      label: widget.label,
      child: Column(
        children: [
          GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: _handleTap,
            child: AnimatedScale(
              scale: _pressed ? 0.94 : 1.0,
              duration: AppDurations.fast,
              curve: Curves.easeOutCubic,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 34),
              ),
            ),
          ),
          AppSpacing.vGapMd,
          Text(
            widget.label,
            style: TextStyle(
              color: labelColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
