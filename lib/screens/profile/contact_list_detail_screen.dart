import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/app_log.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../chats/contact_detail_screen.dart';
import '../chats/create_group_screen.dart';
import 'add_list_members_sheet.dart';

/// Membres d'une liste de contacts : ajout depuis les contacts préférés,
/// retrait, et création d'un groupe avec toute la liste.
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
  @override
  void initState() {
    super.initState();
    final cache = context.read<LocalCacheRepository>();
    unawaited(cache.syncListMembers(widget.idList));
    unawaited(cache.syncPreferredContacts());
  }

  Future<void> _addMembers(Set<int> alreadyIn) async {
    final l10n = context.l10n;
    final cache = context.read<LocalCacheRepository>();

    final selected =
        await showAddListMembersSheet(context, alreadyIn: alreadyIn);
    if (selected == null || selected.isEmpty || !mounted) return;

    try {
      await cache.addListMembers(widget.idList, selected);
    } catch (e, st) {
      AppLog.e('ContactListDetail', 'Ajout de membres échoué', e, st);
      _showError(l10n.listMembersUpdateFailed);
    }
  }

  Future<void> _removeMember(User user) async {
    final l10n = context.l10n;
    final cache = context.read<LocalCacheRepository>();
    try {
      await cache.removeListMember(widget.idList, user.alanyaID);
    } catch (e, st) {
      AppLog.e('ContactListDetail', 'Retrait de membre échoué', e, st);
      _showError(l10n.listMembersUpdateFailed);
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

  @override
  Widget build(BuildContext context) {
    final cache = context.read<LocalCacheRepository>();

    return StreamBuilder<List<LocalContactList>>(
      stream: cache.watchContactLists(),
      builder: (context, listsSnapshot) {
        final list = (listsSnapshot.data ?? const <LocalContactList>[])
            .where((l) => l.idList == widget.idList)
            .firstOrNull;
        final name = list?.name ?? widget.initialName;

        return StreamBuilder<List<User>>(
          stream: cache.watchListMembers(widget.idList),
          builder: (context, snapshot) {
            final members = snapshot.data ?? const <User>[];
            final memberIds = members.map((u) => u.alanyaID).toSet();

            return Scaffold(
              backgroundColor: context.semantic.surfaceMuted,
              appBar: AppBar(
                title: Text(name, style: context.text.headlineSmall),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    tooltip: context.l10n.addToList,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    onPressed: () => _addMembers(memberIds),
                  ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: members.isEmpty
                        ? EmptyState(
                            icon: CupertinoIcons.person_2,
                            title: context.l10n.noListMembers,
                            action: FilledButton.icon(
                              onPressed: () => _addMembers(memberIds),
                              icon: const Icon(Icons.add,
                                  size: AppIconSize.sm),
                              label: Text(context.l10n.addToList),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                              vertical: AppSpacing.lg,
                            ),
                            itemCount: members.length,
                            itemBuilder: (context, index) => _MemberTile(
                              user: members[index],
                              onRemove: () => _removeMember(members[index]),
                            ),
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
                            label: Text(context.l10n.createGroupFromList),
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
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.user, required this.onRemove});

  final User user;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final displayName = user.nom.isNotEmpty ? user.nom : user.pseudo;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.brSm,
        ),
        child: InkWell(
          borderRadius: AppRadius.brSm,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactDetailScreen(
                userId: user.alanyaID,
                initialName: user.nom,
                initialAvatar: user.avatarUrl,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                  name: displayName,
                  size: AppSizes.avatarMd,
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: context.text.titleSmall),
                      Text(
                        AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone),
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.removeFromList,
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: context.colors.error,
                    size: AppIconSize.md,
                  ),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
