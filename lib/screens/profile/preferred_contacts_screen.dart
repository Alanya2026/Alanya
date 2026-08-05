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
import '../../core/utils/user_search.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/add_contact_sheet.dart';
import '../../widgets/common/common.dart';
import '../chats/contact_detail_screen.dart';
import 'contact_lists_screen.dart';

class PreferredContactsScreen extends StatefulWidget {
  const PreferredContactsScreen({super.key});

  @override
  State<PreferredContactsScreen> createState() =>
      _PreferredContactsScreenState();
}

class _PreferredContactsScreenState extends State<PreferredContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    unawaited(context.read<LocalCacheRepository>().syncContactLists());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim());
  }

  void _clearSearch() {
    _searchController.clear();
  }

  void _openAddContact(Set<int> existingIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddContactSheet(
        existingIds: existingIds,
        onAdded: (_) {},
      ),
    );
  }

  Future<void> _removeContact(User user) async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      await apiClient.removeContact(user.alanyaID);
      if (!mounted) return;
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      await cache.upsertKnownUser(user, preferred: false);
    } catch (e, st) {
      AppLog.e('PreferredContacts', 'Suppression contact préféré échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.unableToRemoveThisContactTry),
        ),
      );
    }
  }

  void _showRemoveOptions(User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.vGapSm,
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AppSpacing.vGapLg,
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: context.colors.error,
              ),
              title: Text(
                context.l10n.removePreferredContact(user.nom.isNotEmpty ? user.nom : user.pseudo),
                style: TextStyle(color: context.colors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeContact(user);
              },
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  /// Filtre d'origine : false = tous, true = seulement les ajoutés par QR.
  bool _filtreQr = false;

  /// Liste de contacts active (null = toutes). Se compose avec [_filtreQr] et
  /// la recherche : les trois filtres s'appliquent en ET.
  int? _selectedListId;

  void _openContactLists() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactListsScreen()),
    );
  }

  /// Rangée de puces : « Tous », « Par QR », une par liste, puis « Gérer ».
  Widget _buildFilterChips(
    List<LocalContactList> lists,
    int? activeListId,
    int totalCount,
    int qrCount,
  ) {
    final allSelected = !_filtreQr && activeListId == null;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: [
          ChoiceChip(
            label: Text('${context.l10n.qrContactsFilterAll} · $totalCount'),
            selected: allSelected,
            showCheckmark: false,
            onSelected: (_) => setState(() {
              _filtreQr = false;
              _selectedListId = null;
            }),
          ),
          AppSpacing.hGapSm,
          ChoiceChip(
            avatar: Icon(
              Icons.qr_code_2,
              size: AppIconSize.sm,
              color: _filtreQr
                  ? context.colors.onPrimary
                  : context.colors.onSurfaceVariant,
            ),
            label: Text('${context.l10n.qrContactsFilterQr} · $qrCount'),
            selected: _filtreQr,
            showCheckmark: false,
            selectedColor: context.colors.primary,
            labelStyle: TextStyle(
              color: _filtreQr
                  ? context.colors.onPrimary
                  : context.colors.onSurface,
            ),
            onSelected: (_) => setState(() => _filtreQr = !_filtreQr),
          ),
          for (final list in lists) ...[
            AppSpacing.hGapSm,
            Builder(builder: (context) {
              final selected = activeListId == list.idList;
              final tint =
                  parseListColor(list.color) ?? context.colors.primary;
              return ChoiceChip(
                label: Text('${list.name} · ${list.memberCount}'),
                selected: selected,
                showCheckmark: false,
                selectedColor: tint,
                labelStyle: TextStyle(
                  color: selected
                      ? context.colors.onPrimary
                      : context.colors.onSurface,
                ),
                onSelected: (_) => setState(
                  () => _selectedListId = selected ? null : list.idList,
                ),
              );
            }),
          ],
          AppSpacing.hGapSm,
          ActionChip(
            avatar: Icon(
              Icons.tune,
              size: AppIconSize.sm,
              color: context.colors.onSurfaceVariant,
            ),
            label: Text(context.l10n.contactListsManage),
            onPressed: _openContactLists,
          ),
        ],
      ),
    );
  }

  /// Liste (ou état vide) des contacts déjà réduits par les puces ; la
  /// recherche s'applique en dernier.
  Widget _buildContactList(List<User> scoped, bool hasQuery) {
    final shown =
        hasQuery ? filterUsersBySearch(scoped, _searchQuery) : scoped;

    if (shown.isEmpty) {
      return EmptyState(
        icon: hasQuery ? Icons.person_search : CupertinoIcons.person_2,
        title: hasQuery
            ? context.l10n.noResults
            : context.l10n.noPreferredContacts,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      itemCount: shown.length,
      itemBuilder: (context, index) {
        final user = shown[index];
        return _ContactTile(
          user: user,
          onRemove: () => _showRemoveOptions(user),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.read<LocalCacheRepository>();
    final hasQuery = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(
          context.l10n.preferredContacts,
          style: context.text.headlineSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<LocalUser>>(
        stream: cache.watchPreferredContacts(),
        builder: (context, snapshot) {
          final contacts =
              (snapshot.data ?? []).map(localUserToUser).toList();
          final qrCount =
              contacts.where((u) => u.addedViaQr == true).length;
          final scoped = _filtreQr
              ? contacts.where((u) => u.addedViaQr == true).toList()
              : contacts;
          final existingIds = contacts.map((u) => u.alanyaID).toSet();

          return StreamBuilder<List<LocalContactList>>(
            stream: cache.watchContactLists(),
            builder: (context, listsSnapshot) {
              final lists = listsSnapshot.data ?? const <LocalContactList>[];
              // Une liste supprimée ailleurs ne doit pas laisser un filtre
              // fantôme : on retombe sur « Tous ». Dérivé à chaque build plutôt
              // qu'écrit dans l'état — on ne mute rien pendant un build.
              final activeListId =
                  lists.any((l) => l.idList == _selectedListId)
                      ? _selectedListId
                      : null;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppSearchField(
                            controller: _searchController,
                            hintText:
                                context.l10n.searchByNameUsernameOrPhone,
                            fillColor: context.colors.surface,
                            borderColor: context.colors.outline,
                            onChanged: (_) {},
                            onClear: _clearSearch,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _openAddContact(existingIds),
                          icon: Icon(
                            Icons.add,
                            size: AppIconSize.sm,
                            color: context.colors.primary,
                          ),
                          label: Text(
                            context.l10n.add,
                            style: TextStyle(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildFilterChips(
                    lists,
                    activeListId,
                    contacts.length,
                    qrCount,
                  ),
                  AppSpacing.vGapSm,
                  Expanded(
                    child: contacts.isEmpty
                        ? EmptyState(
                            icon: CupertinoIcons.person_2,
                            title: context.l10n.noPreferredContacts,
                            action: FilledButton.icon(
                              onPressed: () => _openAddContact(existingIds),
                              icon: const Icon(Icons.add,
                                  size: AppIconSize.sm),
                              label: Text(context.l10n.add),
                            ),
                          )
                        : activeListId == null
                            ? _buildContactList(scoped, hasQuery)
                            : StreamBuilder<Set<int>>(
                                stream:
                                    cache.watchListMemberIds(activeListId),
                                builder: (context, memberSnapshot) {
                                  final ids =
                                      memberSnapshot.data ?? const <int>{};
                                  return _buildContactList(
                                    scoped
                                        .where(
                                            (u) => ids.contains(u.alanyaID))
                                        .toList(),
                                    hasQuery,
                                  );
                                },
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.user, required this.onRemove});

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
                Stack(
                  children: [
                    AppAvatar(
                      imageUrl:
                          user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                      name: displayName,
                      size: AppSizes.avatarMd,
                      qrBadge: user.addedViaQr == true,
                    ),
                    if (user.isOnline)
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: context.semantic.online,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: context.text.titleSmall),
                      if (user.pseudo.isNotEmpty)
                        Text(
                          '@${user.pseudo}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      Text(
                        AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone),
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm - 2),
                    decoration: BoxDecoration(
                      color: context.colors.errorContainer,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Icon(
                      Icons.person_remove_outlined,
                      color: context.colors.error,
                      size: AppIconSize.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
