import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_invite_models.dart';
import '../../../talky_api_client.dart';
import '../../../widgets/common/common.dart';
import '../group_invite/group_invite_preview_sheet.dart';

/// Carte « Invitation à un groupe » sous un message qui contient un lien
/// `…/g/<jeton>` — à la place de l'aperçu Open Graph générique.
///
/// L'aperçu est demandé au serveur (connecté) et gardé en mémoire le temps de
/// la session : une discussion qui défile ne relance pas la requête à chaque
/// reconstruction. Un lien mort affiche quand même la carte, sans nom : la
/// feuille ouverte au toucher dira pourquoi.
class GroupInviteCard extends StatefulWidget {
  final String token;
  final bool isMe;

  const GroupInviteCard({super.key, required this.token, required this.isMe});

  @override
  State<GroupInviteCard> createState() => _GroupInviteCardState();
}

class _GroupInviteCardState extends State<GroupInviteCard> {
  static final Map<String, Future<GroupInvitePreview?>> _cache = {};

  late Future<GroupInvitePreview?> _future = _charger();

  Future<GroupInvitePreview?> _charger() {
    final api = Provider.of<TalkyApiClient>(context, listen: false);
    return _cache.putIfAbsent(widget.token, () async {
      try {
        return await api.previewGroupInvite(widget.token);
      } catch (_) {
        // Rien en cache : un nouvel essai aura lieu à la prochaine carte.
        _cache.remove(widget.token);
        return null;
      }
    });
  }

  @override
  void didUpdateWidget(covariant GroupInviteCard old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token) _future = _charger();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onBubble = widget.isMe ? colors.onPrimary : colors.onSurface;
    final bg = widget.isMe
        ? colors.onPrimary.withAlpha(32)
        : colors.surfaceContainerHighest.withAlpha(140);
    final border = widget.isMe
        ? colors.onPrimary.withAlpha(40)
        : colors.outlineVariant.withAlpha(160);
    final accent = widget.isMe ? colors.onPrimary : colors.primary;

    return FutureBuilder<GroupInvitePreview?>(
      future: _future,
      builder: (context, snap) {
        final a = snap.data;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: SizedBox(
            width: 260,
            child: Material(
              color: bg,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.brMd,
                side: BorderSide(color: border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => GroupInviteFlow.open(context, widget.token, preview: a),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          AppAvatar(
                            imageUrl: a?.photo,
                            name: a?.name ?? '#',
                            isGroup: true,
                            size: 48,
                          ),
                          AppSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (a?.name.isNotEmpty ?? false)
                                      ? a!.name
                                      : context.l10n.groupInviteCardLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium?.copyWith(
                                      color: onBubble, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a == null
                                      ? context.l10n.groupInviteCardLabel
                                      : '${context.l10n.groupInviteCardLabel} · ${context.l10n.groupMembersCount(a.memberCount)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodySmall
                                      ?.copyWith(color: onBubble.withAlpha(180)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: border),
                    SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          context.l10n.groupInviteCardView,
                          style: context.text.labelLarge?.copyWith(color: accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
