import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_colors.dart';
import 'app_logo.dart';

/// Côté de l'image incrustée / côté du QR.
///
/// ~22 % : assez large pour lire le logo, dans la marge safe de la correction H
/// (~30 % de redondance). Augmenter si le logo paraît trop petit ; ne pas
/// dépasser ~0.28.
const double _kEmbeddedLogoRatio = 0.22;

/// Rendu unique des QR d'Alanya — code d'identité comme code de connexion.
///
/// Le style vit ici et non dans chaque écran : les deux rendus avaient déjà
/// divergé (yeux ronds contre carrés, bicolore contre monochrome, et deux
/// fichiers de logo différents), donnant deux identités visuelles à la même
/// fonctionnalité.
///
/// L'image incrustée est [`AppLogo.qrAssetPath`] : logo sur pastille blanche
/// circulaire (extérieur transparent). Le glyph transparent seul
/// (`new_alanya_logorbg.png`) se fondait dans les modules ; le PNG carré opaque
/// (`new_alanya_logo.png`) laisserait un rectangle visible. La pastille ronde
/// bake le contraste nécessaire sans casser la cohérence avec les modules
/// ronds. Correction H obligatoire : l'image masque des modules.
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

  @override
  Widget build(BuildContext context) {
    final embeddedSide = size * _kEmbeddedLogoRatio;

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
      embeddedImage: const AssetImage(AppLogo.qrAssetPath),
      embeddedImageStyle: QrEmbeddedImageStyle(
        size: Size(embeddedSide, embeddedSide),
      ),
    );
  }
}
