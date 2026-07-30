import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Pastille « contact ajouté par QR » posée en coin d'avatar.
///
/// Coin bas-GAUCHE par convention : le bas-droit appartient au point de
/// présence en ligne, les deux doivent pouvoir cohabiter. Le liseré reprend le
/// fond porteur, sans quoi la pastille se confond avec les avatars sombres.
class QrPin extends StatelessWidget {
  const QrPin({super.key, this.size = 19, this.ringColor});

  final double size;

  /// Couleur du liseré — par défaut la surface du thème, à surcharger quand la
  /// ligne porteuse repose sur un autre fond.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.qrContactAddedViaQr,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.brandPrimary,
          shape: BoxShape.circle,
          border: Border.all(
            color: ringColor ?? context.colors.surface,
            width: 2,
          ),
        ),
        child: Icon(
          Icons.qr_code_2,
          size: size * 0.62,
          color: AppColors.white,
        ),
      ),
    );
  }
}
