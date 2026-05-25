import 'package:flutter/material.dart';

/// Action rapide circulaire avec libellé (favoris, recherche, effacer…).
/// Gère un état « actif » optionnel (ex. favori ajouté → étoile pleine).
class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor = Colors.amber,
    this.color = Colors.indigo,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color activeColor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effective = active ? activeColor : color;
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: effective.withAlpha(active ? 38 : 22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: effective, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
