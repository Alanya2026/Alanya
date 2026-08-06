import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/welcome_cta_payload.dart';

/// Boutons d'action sous un message de bienvenue officiel (type 8).
class WelcomeCtaButtons extends StatelessWidget {
  const WelcomeCtaButtons({
    super.key,
    required this.payload,
    required this.onRoute,
    this.isMe = false,
  });

  final WelcomeCtaPayload payload;
  final void Function(String route) onRoute;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final btn in payload.buttons)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: TextButton(
              onPressed: () => _handleTap(context, btn),
              style: TextButton.styleFrom(
                foregroundColor: isMe
                    ? context.colors.onPrimary
                    : context.colors.primary,
                backgroundColor: isMe
                    ? context.colors.onPrimary.withValues(alpha: 0.12)
                    : context.colors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.brSm,
                ),
              ),
              child: Text(
                btn.label,
                style: context.text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleTap(BuildContext context, WelcomeCtaButton btn) async {
    if (btn.isRoute) {
      onRoute(btn.target);
      return;
    }
    final uri = Uri.tryParse(btn.target);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
