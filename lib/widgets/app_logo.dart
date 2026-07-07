import 'package:flutter/material.dart';

/// Logo Alanya (connexion, inscription) — fond transparent.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 120});

  static const assetPath = 'assets/images/alanyalogorbg.png';

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
