import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/db/app_database.dart';
import '../core/services/local_cache_repository.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/contact_list_colors.dart';
import '../screens/profile/contact_list_detail_screen.dart';
import '../screens/profile/contact_lists_screen.dart';
import 'common/common.dart';

/// Feuille des listes de contacts, ouverte depuis le menu ⋮ des discussions.
///
/// Depuis l'écran des discussions l'intention est d'**écrire**, pas
/// d'administrer : la feuille pose donc les listes directement sous le pouce et
/// relègue « Gérer les listes » en pied. L'écran de gestion complet reste
/// accessible depuis le profil et depuis la puce « Gérer » des favoris.
Future<void> showContactListsSheet(BuildContext context) {
  // La feuille lit le cache : une synchro en tâche de fond suffit à la tenir
  // à jour sans la faire attendre.
  unawaited(context.read<LocalCacheRepository>().syncContactLists());
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => const _ContactListsSheet(),
  );
}

class _ContactListsSheet extends StatelessWidget {
  const _ContactListsSheet();

  void _openList(BuildContext context, LocalContactList list) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactListDetailScreen(
          idList: list.idList,
          initialName: list.name,
        ),
      ),
    );
  }

  void _openManagement(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactListsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.read<LocalCacheRepository>();

    return AppBottomSheet(
      padding: EdgeInsets.zero,
      child: StreamBuilder<List<LocalContactList>>(
        stream: cache.watchContactLists(),
        builder: (context, snapshot) {
          final lists = snapshot.data ?? const <LocalContactList>[];
          final couleurs = resolveListColors(lists);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.contactLists,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      lists.isEmpty
                          ? context.l10n.noListsHint
                          : context.l10n.contactListsSheetSubtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Une feuille ne défile pas comme un écran : au-delà de quelques
              // listes on borne la hauteur et on laisse glisser le contenu.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final list in lists)
                      ListTile(
                        leading: ContactListFolder(
                          color: parseListColor(couleurs[list.idList]) ??
                              context.colors.primary,
                          size: AppSizes.avatarSm,
                        ),
                        title: Text(list.name),
                        subtitle:
                            Text(context.l10n.listMembersCount(list.memberCount)),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.colors.onSurfaceVariant,
                        ),
                        onTap: () => _openList(context, list),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.tune, color: context.colors.primary),
                title: Text(
                  lists.isEmpty
                      ? context.l10n.createList
                      : context.l10n.manageLists,
                  style: TextStyle(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _openManagement(context),
              ),
              AppSpacing.vGapSm,
            ],
          );
        },
      ),
    );
  }
}
