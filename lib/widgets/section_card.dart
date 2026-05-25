import 'package:flutter/material.dart';
/// Carte blanche arrondie r
utilisable, avec titre optionnel et action
/// 
 Voir tout 
 (>) 
 droite. Sert de conteneur aux sections de la fiche.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.onSeeAll,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final String? title;
  final VoidCallback? onSeeAll;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (onSeeAll != null)
                    TextButton(
                      onPressed: onSeeAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Voir tout',
                              style: TextStyle(color: Colors.indigo, fontSize: 13)),
                          Icon(Icons.chevron_right, color: Colors.indigo, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );