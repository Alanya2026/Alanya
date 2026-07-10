import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Espace réservé en bas du body pour que les contenus scrollables
/// puissent dépasser jusqu'au-dessus de la nav flottante (le scroll
/// passe visuellement derrière le glass, et le dernier item reste
/// accessible). À utiliser comme `padding: EdgeInsets.only(bottom: kGlassNavBarSpace)`
/// sur les ListView/SingleChildScrollView racine de chaque onglet.
const double kGlassNavBarSpace = 96.0;

class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  final int selectedIndex;
  final void Function(int) onItemTapped;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.xl, 6, AppSpacing.xl, AppSpacing.md),
      decoration: const BoxDecoration(boxShadow: AppShadows.strong),
      child: ClipRRect(
        borderRadius: AppRadius.brPill,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: semantic.navGlass,
              borderRadius: AppRadius.brPill,
              border: Border.all(
                color: semantic.navGlassBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) => _NavItem(
                index: i,
                isSelected: selectedIndex == i,
                onTap: () => onItemTapped(i),
              )),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icons = const [
      CupertinoIcons.chat_bubble_2,
      CupertinoIcons.phone,
      CupertinoIcons.flame,
      CupertinoIcons.video_camera,
      CupertinoIcons.person,
    ];

    final activeIcons = const [
      CupertinoIcons.chat_bubble_2_fill,
      CupertinoIcons.phone_fill,
      CupertinoIcons.flame_fill,
      CupertinoIcons.video_camera_solid,
      CupertinoIcons.person_fill,
    ];

    const labels = ['Chats', 'Appels', 'Statuts', 'Réunions', 'Profil'];

    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withAlpha(25) : Colors.transparent,
          borderRadius: AppRadius.brSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcons[index] : icons[index],
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
              size: AppIconSize.sm + 2,
            ),
            const SizedBox(height: 2),
            Text(
              labels[index],
              style: context.text.labelSmall?.copyWith(
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
