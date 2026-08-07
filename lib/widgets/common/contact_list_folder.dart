import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// Dossier d'une liste de contacts : carré arrondi **plein**, glyphe blanc.
///
/// C'est la couleur qui identifie la liste d'un coup d'œil — d'où le fond plein
/// plutôt qu'une pastille pâle. Même composant partout (écran de gestion,
/// feuille des discussions) pour que les quatre dossiers se reconnaissent d'un
/// écran à l'autre.
class ContactListFolder extends StatelessWidget {
  const ContactListFolder({
    super.key,
    required this.color,
    this.size = AppSizes.avatarMd,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.brSm,
      ),
      child: Icon(
        Icons.folder_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}
