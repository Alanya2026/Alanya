import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/app_badge.dart';

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
    this.badges = const [0, 0, 0, 0, 0],
  });

  final int selectedIndex;
  final void Function(int) onItemTapped;
  /// Compteurs par onglet (Chats, Appels, Statuts, Réunions, Profil).
  final List<int> badges;

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
                badgeCount: i < badges.length ? badges[i] : 0,
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
    this.badgeCount = 0,
  });

  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

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

    final l10n = context.l10n;
    final labels = [
      l10n.navChats,
      l10n.navCalls,
      l10n.navStatuses,
      l10n.navMeetings,
      l10n.navProfile,
    ];

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
          color: isSelected ? colors.primary.withAlpha(25) : const Color(0x00000000),
          borderRadius: AppRadius.brSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcons[index] : icons[index],
                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                  size: AppIconSize.sm + 2,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -10,
                    top: -8,
                    child: CountBadge(count: badgeCount),
                  ),
              ],
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
