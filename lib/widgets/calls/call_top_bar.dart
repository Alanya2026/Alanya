import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/call_ui_theme.dart';

/// Barre supérieure des écrans d'appel : chevron, nom, durée/statut.
class CallTopBar extends StatelessWidget {
  const CallTopBar({
    super.key,
    required this.name,
    required this.status,
    required this.duration,
    required this.onMinimize,
    required this.useVideoChrome,
  });

  final String name;
  final String status;
  final String? duration;
  final VoidCallback onMinimize;
  final bool useVideoChrome;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final onSurface = useVideoChrome ? callUi.onVideoChrome : callUi.onBackground;
    final onSurfaceMuted =
        useVideoChrome ? callUi.onVideoChrome.withValues(alpha: 0.7) : callUi.onBackgroundMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      decoration: useVideoChrome
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: callUi.chromeScrimTop,
              ),
            )
          : null,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Réduire l\'appel',
            child: IconButton(
              icon: Icon(
                CupertinoIcons.chevron_down,
                color: onSurface,
                size: 28,
              ),
              onPressed: onMinimize,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.vGapXs,
                if (duration != null)
                  Text(
                    duration!,
                    style: TextStyle(
                      color: onSurfaceMuted,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                else
                  _StatusChip(
                    label: status,
                    callUi: callUi,
                    useVideoChrome: useVideoChrome,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.callUi,
    required this.useVideoChrome,
  });

  final String label;
  final CallUiColors callUi;
  final bool useVideoChrome;

  @override
  Widget build(BuildContext context) {
    final bg = useVideoChrome ? callUi.videoControlSurface : callUi.chipBackground;
    final fg = useVideoChrome ? callUi.onVideoChrome : callUi.chipOnBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}
