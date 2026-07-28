import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_colors.dart';

/// Rendu unique des QR d'Alanya — code d'identité comme code de connexion.
///
/// Le style vit ici et non dans chaque écran : les deux rendus avaient déjà
/// divergé (yeux ronds contre carrés, bicolore contre monochrome, et deux
/// fichiers de logo différents), donnant deux identités visuelles à la même
/// fonctionnalité.
class AlanyaQrView extends StatelessWidget {
  const AlanyaQrView({
    super.key,
    required this.payload,
    required this.size,
  });

  /// Chaîne encodée dans le code (URL fabriquée par le serveur).
  final String payload;

  /// Côté du carré, en pixels logiques.
  final double size;

  /// Logo incrusté au centre. Le même que celui du QR d'identité : la variante
  /// sans fond se confondrait avec les modules du code.
  static const _logoAsset = 'assets/images/alanyalogo.png';

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: payload,
      size: size,
      // Fond blanc même en thème sombre : les lecteurs attendent des modules
      // foncés sur fond clair, l'inverse ne scanne pas de façon fiable.
      backgroundColor: AppColors.white,
      // Niveau H obligatoire : le logo incrusté masque des modules, sans cette
      // redondance le code devient illisible.
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.circle,
        color: AppColors.brandPrimary,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.circle,
        color: AppColors.brandPrimaryDark,
      ),
      embeddedImage: const AssetImage(_logoAsset),
      embeddedImageStyle: QrEmbeddedImageStyle(
        size: Size(size * 0.18, size * 0.18),
      ),
    );
  }
}
