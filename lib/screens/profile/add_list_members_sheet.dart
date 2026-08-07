import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/user_search.dart';
import '../../widgets/common/common.dart';

/// Feuille de multi-sélection de membres, partagée par la **création** d'une
/// liste (avant qu'elle n'existe côté serveur) et par son **écran détail**.
///
/// Elle ne propose que des **contacts préférés** : être un favori est le
/// prérequis pour appartenir à une liste, le backend refuse le reste.
///
/// [alreadyIn] : membres déjà dans la liste, retirés du vivier.
/// [initialSelection] : cases déjà cochées (reprise d'une sélection en cours de
/// création). [confirmLabel] : « Ajouter » depuis l'écran détail, « Enregistrer »
/// quand on ajuste une sélection existante. Retourne les ids retenus, ou null
/// si l'utilisateur ferme la feuille.
Future<Set<int>?> showAddListMembersSheet(
  BuildContext context, {
  Set<int> alreadyIn = const {},
  Set<int> initialSelection = const {},
  String? confirmLabel,
  int? maxSelection,
}) {
  return showAppBottomSheet<Set<int>>(
    context: context,
    builder: (_) => _AddListMembersSheet(
      alreadyIn: alreadyIn,
      initialSelection: initialSelection,
      confirmLabel: confirmLabel,
      maxSelection: maxSelection,
    ),
  );
}

class _AddListMembersSheet extends StatefulWidget {
  const _AddListMembersSheet({
    required this.alreadyIn,
    required this.initialSelection,
    required this.confirmLabel,
    this.maxSelection,
  });

  final Set<int> alreadyIn;
  final Set<int> initialSelection;
  final String? confirmLabel;
  final int? maxSelection;

  @override
  State<_AddListMembersSheet> createState() => _AddListMembersSheetState();
}

class _AddListMembersSheetState extends State<_AddListMembersSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<int> _selectedIds = {...widget.initialSelection};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.read<LocalCacheRepository>();
    // Hauteur fixe (comme `share_preferred_contact_sheet`) : un Expanded n'a
    // de sens que sous une contrainte bornée.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return AppBottomSheet(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.addToList,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_selectedIds.isNotEmpty)
                  Text(
                    context.l10n.addMembersSelected(_selectedIds.length),
                    style: context.text.labelLarge?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
              ],
            ),
            AppSpacing.vGapMd,
            AppSearchField(
              controller: _searchController,
              hintText: context.l10n.searchByNameUsernameOrPhone,
              fillColor: context.semantic.surfaceMuted,
              borderColor: context.colors.outline,
              onChanged: (_) {},
              onClear: () => _searchController.clear(),
            ),
            AppSpacing.vGapMd,
            Expanded(
              child: StreamBuilder<List<LocalUser>>(
                stream: cache.watchPreferredContacts(),
                builder: (context, snapshot) {
                  final candidates = (snapshot.data ?? const <LocalUser>[])
                      .map(localUserToUser)
                      .where((u) => !widget.alreadyIn.contains(u.alanyaID))
                      .toList();
                  final shown = _searchQuery.isEmpty
                      ? candidates
                      : filterUsersBySearch(candidates, _searchQuery);

                  if (candidates.isEmpty) {
                    return EmptyState(
                      icon: CupertinoIcons.person_2,
                      title: context.l10n.noContactToAddToList,
                    );
                  }
                  if (shown.isEmpty) {
                    return EmptyState(
                      icon: Icons.person_search,
                      title: context.l10n.noResults,
                    );
                  }

                  return ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final user = shown[index];
                      final name =
                          user.nom.isNotEmpty ? user.nom : user.pseudo;
                      final selected = _selectedIds.contains(user.alanyaID);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) {
                          if (!selected &&
                              widget.maxSelection != null &&
                              _selectedIds.length >= widget.maxSelection!) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.listMemberLimitReached(
                                    widget.maxSelection!,
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(user.alanyaID);
                            } else {
                              _selectedIds.add(user.alanyaID);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: AppAvatar(
                          imageUrl:
                              user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                          name: name,
                          size: AppSizes.avatarSm,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            AppSpacing.vGapSm,
            FilledButton(
              // Confirmer une sélection vide reste permis : c'est ainsi qu'on
              // décoche tout avant de créer la liste. L'appelant traite le
              // cas « rien de sélectionné » comme un non-événement.
              onPressed: () => Navigator.pop(context, _selectedIds),
              child: Text(widget.confirmLabel ?? context.l10n.add),
            ),
          ],
        ),
      ),
    );
  }
}
