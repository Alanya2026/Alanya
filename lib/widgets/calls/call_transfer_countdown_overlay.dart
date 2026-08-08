import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Compte à rebours visuel du leave auto transfert (initiateur).
class CallTransferCountdownOverlay extends StatelessWidget {
  const CallTransferCountdownOverlay({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  final int remainingSeconds;
  final int totalSeconds;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final total = totalSeconds <= 0 ? 10 : totalSeconds;
    final progress = (remainingSeconds / total).clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      child: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: callUi.chipBackground.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: callUi.groupTileShadow,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!reduceMotion)
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                    color: AppColors.warning,
                  ),
                ),
              Text(
                '$remainingSeconds',
                style: TextStyle(
                  color: callUi.onBackground,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
