import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/chat_provider.dart';

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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(130),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withAlpha(150),
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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconWithBadge(
              icon: isSelected ? activeIcons[index] : icons[index],
              color: isSelected ? Colors.indigo : Colors.grey.shade400,
              // Badge orange "outbox" uniquement sur l'onglet Chats.
              badgeStream: index == 0
                  ? context.select<ChatProvider, Stream<int>>(
                      (c) => c.pendingMessagesCount())
                  : null,
            ),
            const SizedBox(height: 2),
            Text(
              labels[index],
              style: TextStyle(
                color: isSelected ? Colors.indigo : Colors.grey.shade500,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.color,
    this.badgeStream,
  });

  final IconData icon;
  final Color color;
  final Stream<int>? badgeStream;

  @override
  Widget build(BuildContext context) {
    final base = Icon(icon, color: color, size: 22);
    if (badgeStream == null) return base;
    return StreamBuilder<int>(
      stream: badgeStream,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (count <= 0) return base;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            base,
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
