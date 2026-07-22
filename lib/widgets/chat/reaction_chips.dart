import 'package:flutter/material.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Une réaction agrégée : un emoji, son nombre d'occurrences, et si
/// l'utilisateur courant en fait partie (pour la mise en évidence + le tap
/// « toggle »).
class ReactionGroup {
  const ReactionGroup({required this.emoji, required this.count, required this.mine});

  final String emoji;
  final int count;
  final bool mine;
}

/// Regroupe les réactions brutes par emoji, dans l'ordre de première
/// apparition (comme Telegram/Discord — pas de tri par popularité, pour éviter
/// que les pastilles ne « sautent » de place à chaque nouvelle réaction).
List<ReactionGroup> groupReactions(List<LocalMessageReaction> reactions, int myId) {
  if (reactions.isEmpty) return const [];
  final order = <String>[];
  final counts = <String, int>{};
  final mine = <String, bool>{};
  for (final r in reactions) {
    if (!counts.containsKey(r.emoji)) order.add(r.emoji);
    counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    if (r.userID == myId) mine[r.emoji] = true;
  }
  return order
      .map((e) => ReactionGroup(emoji: e, count: counts[e]!, mine: mine[e] ?? false))
      .toList();
}

/// Rangée de pastilles de réaction, pensée pour chevaucher légèrement le bord
/// inférieur d'une bulle de message (voir `chat_bubbles.dart`).
///
/// Un tap sur une pastille bascule ma propre réaction : je rejoins ce groupe
/// si je n'y suis pas, ou je retire ma réaction si j'en fais déjà partie.
class ReactionChipsRow extends StatelessWidget {
  const ReactionChipsRow({
    super.key,
    required this.groups,
    required this.onToggle,
  });

  final List<ReactionGroup> groups;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final g in groups)
          _ReactionChip(group: g, onTap: () => onToggle(g.emoji)),
      ],
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.group, required this.onTap});

  final ReactionGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = group.mine ? colors.primaryContainer : colors.surface;
    final border = group.mine ? colors.primary : colors.outlineVariant;
    final label = group.count > 1 ? '${group.emoji} ${group.count}' : group.emoji;

    return Semantics(
      button: true,
      label: context.l10n.reactionChipLabel(group.emoji, group.count),
      child: Material(
        color: background,
        shape: StadiumBorder(side: BorderSide(color: border, width: group.mine ? 1.5 : 1)),
        elevation: 1,
        shadowColor: colors.shadow.withAlpha(40),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs / 2),
            child: Text(label, style: const TextStyle(fontSize: 13, height: 1.2)),
          ),
        ),
      ),
    );
  }
}
