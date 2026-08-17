import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/default_contact_lists.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/contact_list_display.dart';
import '../../core/utils/user_search.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../chats/contact_detail_screen.dart';
import '../chats/create_group_screen.dart';
import 'list_ringtone_screen.dart';

/// Détail d'une liste : ses membres **et** les autres favoris, dans la même
/// liste, chacun avec une case à cocher.
///
/// Montrer les non-membres en grisé au lieu de les cacher derrière une feuille
/// de sélection évite un aller-retour : on voit d'un coup qui est dedans et qui
/// pourrait y être, et on ajoute ou retire au même endroit.
class ContactListDetailScreen extends StatefulWidget {
  const ContactListDetailScreen({
    super.key,
    required this.idList,
    required this.initialName,
  });

  final int idList;

  /// Nom connu à l'ouverture — évite un écran sans titre le temps du stream.
  final String initialName;

  @override
  State<ContactListDetailScreen> createState() =>
      _ContactListDetailScreenState();
}

class _ContactListDetailScreenState extends State<ContactListDetailScreen> {
  /// Contacts dont l'appartenance est en cours de bascule — la case reste
  /// inerte le temps de l'aller-retour réseau (double tap sans effet).
  final Set<int> _pending = {};

  @override
  void initState() {
    super.initState();
    final cache = context.read<LocalCacheRepository>();
    unawaited(cache.syncListMembers(widget.idList));
    // Les non-membres affichés en grisé viennent des favoris : ils doivent
    // être à jour même si l'on arrive ici sans passer par leur écran.
    unawaited(cache.syncPreferredContacts());
  }

  Future<void> _toggleMember(
    User user, {
    required bool isMember,
    int? memberLimit,
    required int memberCount,
  }) async {
    if (_pending.contains(user.alanyaID)) return;
    final l10n = context.l10n;
    final cache = context.read<LocalCacheRepository>();

    if (!isMember &&
        memberLimit != null &&
        memberCount >= memberLimit) {
      _showError(l10n.listMemberLimitReached(memberLimit));
      return;
    }

    setState(() => _pending.add(user.alanyaID));
    try {
      if (isMember) {
        await cache.removeListMember(widget.idList, user.alanyaID);
      } else {
        await cache.addListMember(widget.idList, user.alanyaID);
      }
    } on TalkyException catch (e) {
      if (e.statusCode == 409 &&
          e.message.toLowerCase().contains('limit')) {
        _showError(l10n.listMemberLimitReached(memberLimit ?? kTrustMemberLimit));
      } else {
        AppLog.e('ContactListDetail', 'Bascule d\'appartenance échouée', e);
        _showError(l10n.listMembersUpdateFailed);
      }
    } catch (e, st) {
      AppLog.e('ContactListDetail', 'Bascule d\'appartenance échouée', e, st);
      _showError(l10n.listMembersUpdateFailed);
    } finally {
      if (mounted) setState(() => _pending.remove(user.alanyaID));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Chat de groupe avec toute la liste : on réutilise l'écran de création
  /// habituel (photo, description, réglages), nom pré-rempli et éditable.
  void _createGroup(String listName, List<User> members) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(
          members: members,
          initialName: listName,
        ),
      ),
    );
  }

  void _openContact(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(
          userId: user.alanyaID,
          initialName: user.nom,
          initialAvatar: user.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.read<LocalCacheRepository>();

    return StreamBuilder<List<LocalContactList>>(
      stream: cache.watchContactLists(),
      builder: (context, listsSnapshot) {
        final list = (listsSnapshot.data ?? const <LocalContactList>[])
            .where((l) => l.idList == widget.idList)
            .firstOrNull;
        final name = list != null
            ? list.displayName(context.l10n)
            : widget.initialName;
        final memberLimit = list?.memberLimit ??
            memberLimitForContactListKind(list?.kind);

        return StreamBuilder<List<User>>(
          stream: cache.watchListMembers(widget.idList),
          builder: (context, membersSnapshot) {
            final members = membersSnapshot.data ?? const <User>[];
            final memberIds = members.map((u) => u.alanyaID).toSet();

            return StreamBuilder<List<LocalUser>>(
              stream: cache.watchPreferredContacts(),
              builder: (context, favSnapshot) {
                // Membres d'abord, puis les autres favoris : l'ordre reflète
                // l'appartenance, pas l'alphabet global.
                final others = (favSnapshot.data ?? const <LocalUser>[])
                    .map(localUserToUser)
                    .where((u) => !memberIds.contains(u.alanyaID))
                    .toList();

                return Scaffold(
                  backgroundColor: context.semantic.surfaceMuted,
                  appBar: AppBar(
                    title: Text(name, style: context.text.headlineSmall),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      if (list != null)
                        IconButton(
                          tooltip: 'Sonneries de la liste',
                          icon: const Icon(Icons.notifications_active_outlined),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListRingtoneScreen(
                                list: list,
                                allLists: listsSnapshot.data ??
                                    const <LocalContactList>[],
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.lg),
                        child: Center(
                          child: Text(
                            list?.memberLimit != null
                                ? context.l10n.listMembersCountLimited(
                                    members.length,
                                    list!.memberLimit!,
                                  )
                                : '${members.length}',
                            style: context.text.titleMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      Expanded(
                        child: members.isEmpty && others.isEmpty
                            ? EmptyState(
                                icon: CupertinoIcons.person_2,
                                title: context.l10n.noContactToAddToList,
                                message: context.l10n.contactListsHint,
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xl,
                                  vertical: AppSpacing.lg,
                                ),
                                itemCount: members.length + others.length,
                                itemBuilder: (context, index) {
                                  final isMember = index < members.length;
                                  final user = isMember
                                      ? members[index]
                                      : others[index - members.length];
                                  final atLimit = !isMember &&
                                      memberLimit != null &&
                                      members.length >= memberLimit;
                                  return _MemberTile(
                                    user: user,
                                    isMember: isMember,
                                    busy: _pending.contains(user.alanyaID),
                                    atLimit: atLimit,
                                    memberLimit: memberLimit,
                                    onToggle: () => _toggleMember(
                                      user,
                                      isMember: isMember,
                                      memberLimit: memberLimit,
                                      memberCount: members.length,
                                    ),
                                    onOpen: () => _openContact(user),
                                  );
                                },
                              ),
                      ),
                      if (members.isNotEmpty)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.sm,
                              AppSpacing.xl,
                              AppSpacing.lg,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => _createGroup(name, members),
                                icon: const Icon(Icons.group_add_outlined,
                                    size: AppIconSize.sm),
                                label:
                                    Text(context.l10n.createGroupNamed(name)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Ligne de contact dans le détail d'une liste. Les non-membres sont posés en
/// retrait (opacité) : présents, proposés, mais visiblement hors de la liste.
class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.user,
    required this.isMember,
    required this.busy,
    required this.atLimit,
    this.memberLimit,
    required this.onToggle,
    required this.onOpen,
  });

  final User user;
  final bool isMember;
  final bool busy;
  final bool atLimit;
  final int? memberLimit;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  /// « En ligne », « Vu à 12:04 », « Vu hier à … » — comme la fiche contact.
  String _presenceLabel(BuildContext context) {
    if (user.isOnline) return context.l10n.online;
    final seen = DateTime.tryParse(user.lastSeen)?.toLocal();
    if (seen == null) return context.l10n.offline;
    final now = DateTime.now();
    final hm = '${seen.hour.toString().padLeft(2, '0')}:'
        '${seen.minute.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(seen, now)) return context.l10n.seenAt(hm);
    if (sameDay(seen, yesterday)) return context.l10n.seenYesterdayAt(hm);
    return context.l10n.seenOnDate(seen.day, seen.month);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user.nom.isNotEmpty ? user.nom : user.pseudo;
    final subtitle =
        isMember ? _presenceLabel(context) : context.l10n.notInThisList;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Opacity(
        opacity: isMember ? 1 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.brSm,
          ),
          child: InkWell(
            borderRadius: AppRadius.brSm,
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl:
                        user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                    name: displayName,
                    size: AppSizes.avatarMd,
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: context.text.titleSmall),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isMember
                        ? context.l10n.removeFromList
                        : (atLimit && memberLimit != null
                            ? context.l10n.listMemberLimitReached(memberLimit!)
                            : context.l10n.addToList),
                    onPressed: busy || atLimit ? null : onToggle,
                    icon: busy
                        ? const SizedBox(
                            width: AppIconSize.sm,
                            height: AppIconSize.sm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isMember
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isMember
                                ? context.colors.primary
                                : (atLimit
                                    ? context.colors.outline.withValues(
                                        alpha: 0.35)
                                    : context.colors.outline),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
