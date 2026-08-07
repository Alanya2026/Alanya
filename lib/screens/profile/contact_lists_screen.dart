import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/default_contact_lists.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/contact_list_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/contact_list_display.dart';
import '../../talky_api_client.dart';
import '../../widgets/common/common.dart';
import 'add_list_members_sheet.dart';
import 'contact_list_detail_screen.dart';

/// Gestion des listes de contacts (Famille, Amis, Bureau…) : création,
/// renommage, recoloration, suppression. Les membres se gèrent dans
/// [ContactListDetailScreen].
class ContactListsScreen extends StatefulWidget {
  const ContactListsScreen({super.key});

  @override
  State<ContactListsScreen> createState() => _ContactListsScreenState();
}

class _ContactListsScreenState extends State<ContactListsScreen> {
  @override
  void initState() {
    super.initState();
    final cache = context.read<LocalCacheRepository>();
    unawaited(cache.syncContactLists());
    // Le vivier de la feuille « ajouter des membres » : on peut arriver ici
    // sans être passé par l'écran des contacts préférés.
    unawaited(cache.syncPreferredContacts());
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final cacheLecture = context.read<LocalCacheRepository>();
    // La liste naît colorée : on propose la première teinte encore libre.
    final proposee = nextFreeContactListColor({
      for (final l in await cacheLecture.getContactListsOnce())
        if (parseListColor(l.color) != null) l.color!.toUpperCase(),
    });
    if (!mounted) return;
    final result = await showListEditorSheet(context, initialColor: proposee);
    if (result == null || !mounted) return;
    final cache = context.read<LocalCacheRepository>();
    try {
      await cache.createContactList(
        result.name,
        color: result.color,
        memberIds: result.memberIds,
      );
    } on TalkyException catch (e) {
      _showError(e.statusCode == 409
          ? l10n.listNameAlreadyExists
          : l10n.listSaveFailed);
    } catch (e, st) {
      AppLog.e('ContactLists', 'Création de liste échouée', e, st);
      _showError(l10n.listSaveFailed);
    }
  }

  Future<void> _rename(LocalContactList list) async {
    final l10n = context.l10n;
    final cacheLecture = context.read<LocalCacheRepository>();
    // Une liste sans couleur en base en affiche déjà une : l'éditeur doit
    // ouvrir sur la même pastille cochée, pas sur rien.
    final couleurs = resolveListColors(await cacheLecture.getContactListsOnce());
    if (!mounted) return;
    final result = await showListEditorSheet(
      context,
      initialName: list.displayName(l10n),
      initialColor: couleurs[list.idList] ?? kContactListColors.first,
      nameReadOnly: isSystemContactListKind(list.kind),
    );
    if (result == null || !mounted) return;
    final cache = context.read<LocalCacheRepository>();
    try {
      await cache.updateContactList(
        list.idList,
        name: isSystemContactListKind(list.kind) ? null : result.name,
        color: result.color,
      );
    } on TalkyException catch (e) {
      _showError(e.statusCode == 409
          ? l10n.listNameAlreadyExists
          : l10n.listSaveFailed);
    } catch (e, st) {
      AppLog.e('ContactLists', 'Renommage de liste échoué', e, st);
      _showError(l10n.listSaveFailed);
    }
  }

  Future<void> _delete(LocalContactList list) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteList),
        content: Text(dialogContext.l10n.deleteListConfirm(list.displayName(l10n))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              dialogContext.l10n.commonDelete,
              style: TextStyle(color: dialogContext.colors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cache = context.read<LocalCacheRepository>();
    try {
      await cache.deleteContactList(list.idList);
    } catch (e, st) {
      AppLog.e('ContactLists', 'Suppression de liste échouée', e, st);
      _showError(l10n.listSaveFailed);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openList(LocalContactList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactListDetailScreen(
          idList: list.idList,
          initialName: list.displayName(context.l10n),
        ),
      ),
    );
  }

  void _showListOptions(LocalContactList list) {
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (sheetContext) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(sheetContext.l10n.renameList),
              onTap: () {
                Navigator.pop(sheetContext);
                _rename(list);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: sheetContext.colors.error),
              title: Text(
                sheetContext.l10n.deleteList,
                style: TextStyle(color: sheetContext.colors.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _delete(list);
              },
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.read<LocalCacheRepository>();

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(context.l10n.contactLists, style: context.text.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.newList),
      ),
      body: StreamBuilder<List<LocalContactList>>(
        stream: cache.watchContactLists(),
        builder: (context, snapshot) {
          final lists = snapshot.data ?? const <LocalContactList>[];
          final couleurs = resolveListColors(lists);
          if (lists.isEmpty) {
            return EmptyState(
              icon: Icons.folder_outlined,
              title: context.l10n.noLists,
              message: context.l10n.noListsHint,
              action: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: AppIconSize.sm),
                label: Text(context.l10n.createList),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              // Laisse passer le FAB étendu sous le dernier élément.
              AppSpacing.xxxl * 3,
            ),
            children: [
              for (final list in lists)
                _ContactListTile(
                  list: list,
                  color: couleurs[list.idList] ?? kContactListColors.first,
                  onTap: () => _openList(list),
                  onOptions: () => _showListOptions(list),
                ),
              AppSpacing.vGapLg,
              // Rappel des deux règles qui surprennent : on ne range que des
              // favoris, et un contact peut être dans plusieurs listes.
              Text(
                context.l10n.contactListsHint,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ContactListTile extends StatelessWidget {
  const _ContactListTile({
    required this.list,
    required this.color,
    required this.onTap,
    required this.onOptions,
  });

  final LocalContactList list;

  /// Teinte effective, résolue pour l'ensemble des listes.
  final String color;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final tint = parseListColor(color) ?? context.colors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.brSm,
        ),
        child: InkWell(
          borderRadius: AppRadius.brSm,
          onTap: onTap,
          onLongPress: onOptions,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                // Dossier plein, glyphe blanc : c'est la couleur qui identifie
                // la liste d'un coup d'œil, pas l'icône.
                ContactListFolder(color: tint, size: AppSizes.avatarMd),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(list.displayName(context.l10n),
                          style: context.text.titleSmall),
                      Text(
                        context.l10n.listMembersCount(list.memberCount),
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  color: context.colors.onSurfaceVariant,
                  onPressed: onOptions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Éditeur de liste (création / renommage) ──────────────────────────

/// Résultat de l'éditeur. La couleur n'est jamais nulle — une liste est
/// toujours colorée. [memberIds] est vide en renommage (les membres se gèrent
/// alors depuis l'écran détail).
class ContactListDraft {
  const ContactListDraft(this.name, this.color, {this.memberIds = const {}});

  final String name;
  final String color;
  final Set<int> memberIds;
}

/// Éditeur de liste. En **création** ([initialName] null), il propose aussi de
/// choisir les membres tout de suite : une liste vide n'a aucun intérêt, et
/// obliger à créer puis rouvrir l'écran détail était un aller-retour de trop.
Future<ContactListDraft?> showListEditorSheet(
  BuildContext context, {
  String? initialName,
  required String initialColor,
  bool nameReadOnly = false,
}) {
  return showAppBottomSheet<ContactListDraft>(
    context: context,
    builder: (_) => _ListEditorSheet(
      initialName: initialName,
      initialColor: initialColor,
      nameReadOnly: nameReadOnly,
    ),
  );
}

class _ListEditorSheet extends StatefulWidget {
  const _ListEditorSheet({
    this.initialName,
    required this.initialColor,
    this.nameReadOnly = false,
  });

  final String? initialName;
  final String initialColor;
  final bool nameReadOnly;

  @override
  State<_ListEditorSheet> createState() => _ListEditorSheetState();
}

class _ListEditorSheetState extends State<_ListEditorSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName ?? '');
  late String _color = widget.initialColor;

  /// Membres choisis à la création (vide en renommage).
  final Set<int> _memberIds = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickMembers() async {
    // Le clavier masquerait la feuille de sélection empilée par-dessus.
    FocusScope.of(context).unfocus();
    final picked = await showAddListMembersSheet(
      context,
      initialSelection: _memberIds,
      confirmLabel: context.l10n.commonSave,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _memberIds
        ..clear()
        ..addAll(picked);
    });
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty && !widget.nameReadOnly) return;
    Navigator.pop(
      context,
      ContactListDraft(
        widget.nameReadOnly ? (widget.initialName ?? name) : name,
        _color,
        memberIds: {..._memberIds},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialName != null;
    final isColorOnlyEdit = isEdit && widget.nameReadOnly;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isColorOnlyEdit
                  ? context.l10n.listColor
                  : (isEdit ? context.l10n.renameList : context.l10n.createList),
              style: context.text.titleMedium,
            ),
            AppSpacing.vGapLg,
            if (!widget.nameReadOnly)
              TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 60,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: context.l10n.listName,
                  hintText: context.l10n.listNameHint,
                  counterText: '',
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.brSm,
                  ),
                ),
              )
            else
              Text(
                widget.initialName ?? '',
                style: context.text.titleSmall,
              ),
            if (!widget.nameReadOnly) AppSpacing.vGapLg else AppSpacing.vGapMd,
            Text(
              context.l10n.listColor,
              style: context.text.labelLarge?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            AppSpacing.vGapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final hex in kContactListColors)
                  _ColorDot(
                    color: parseListColor(hex)!,
                    selected: _color.toUpperCase() == hex,
                    onTap: () => setState(() => _color = hex),
                  ),
              ],
            ),
            if (!isEdit) ...[
              AppSpacing.vGapLg,
              // Choix des membres dès la création — le renommage, lui, se fait
              // depuis l'écran détail où les membres sont déjà sous les yeux.
              Material(
                color: context.semantic.surfaceMuted,
                borderRadius: AppRadius.brSm,
                child: InkWell(
                  borderRadius: AppRadius.brSm,
                  onTap: _pickMembers,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_alt_1_outlined,
                          size: AppIconSize.md,
                          color: context.colors.primary,
                        ),
                        AppSpacing.hGapMd,
                        Expanded(
                          child: Text(
                            context.l10n.addToList,
                            style: context.text.bodyLarge,
                          ),
                        ),
                        Text(
                          context.l10n.listMembersCount(_memberIds.length),
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: AppIconSize.sm,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            AppSpacing.vGapXl,
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _controller.text.trim().isEmpty ? null : _submit,
                child: Text(
                  isEdit ? context.l10n.commonSave : context.l10n.create,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSpacing.xxl,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? context.colors.onSurface : context.colors.outline,
            width: selected ? 2.5 : 1,
          ),
        ),
        // La coche évite de devoir deviner la teinte sélectionnée au seul
        // liseré, peu lisible sur les couleurs sombres de la palette.
        child: selected
            ? const Icon(Icons.check, size: AppIconSize.sm, color: Colors.white)
            : null,
      ),
    );
  }
}
