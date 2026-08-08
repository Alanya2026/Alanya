import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'call_participant_tile.dart';

/// Overlay « spotlight » : agrandit une tuile conf sur fond assombri.
///
/// Les contrôles d'appel restent visibles (overlay s'arrête au-dessus de la barre).
class CallParticipantFocusOverlay extends StatelessWidget {
  const CallParticipantFocusOverlay({
    super.key,
    required this.userId,
    required this.name,
    required this.onDismiss,
    this.stream,
    this.photoUrl,
    this.isMuted = false,
    this.isVideoOn = true,
    this.isSpeaking = false,
    this.mirror = false,
  });

  final String userId;
  final String name;
  final MediaStream? stream;
  final String? photoUrl;
  final bool isMuted;
  final bool isVideoOn;
  final bool isSpeaking;
  final bool mirror;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 160;
    final topPad = MediaQuery.paddingOf(context).top + 72;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Scrim : réutilise le noir déjà présent dans chromeScrim / surfaces vidéo.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: ColoredBox(
                color: AppColors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: topPad,
            bottom: bottomPad,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: context.l10n.commonClose,
                    child: IconButton(
                      onPressed: onDismiss,
                      icon: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: callUi.onVideoChrome.withValues(alpha: 0.9),
                        size: 32,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedScale(
                    scale: 1,
                    duration: AppDurations.normal,
                    child: CallParticipantTile(
                      userId: userId,
                      stream: stream,
                      name: name,
                      photoUrl: photoUrl,
                      isMuted: isMuted,
                      isVideoOn: isVideoOn,
                      isSpeaking: isSpeaking,
                      mirror: mirror,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
