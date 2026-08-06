import 'package:flutter/material.dart';

/// Logo Alanya (connexion, inscription) — fond transparent.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 120});

  /// Glyph transparent (écrans login / branding).
  static const assetPath = 'assets/images/new_alanya_logorbg.png';

  /// Logo pré-composé sur pastille blanche circulaire — réservé aux QR.
  ///
  /// Le PNG transparent se fond dans les modules ; ce fichier bake le fond
  /// blanc rond pour rester lisible une fois incrusté au centre du code.
  static const qrAssetPath = 'assets/images/new_alanya_logo_qr.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
