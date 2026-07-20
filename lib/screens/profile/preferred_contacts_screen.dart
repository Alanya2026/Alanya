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
          final filteredContacts = hasQuery
              ? filterUsersBySearch(contacts, _searchQuery)
              : contacts;
          final existingIds = contacts.map((u) => u.alanyaID).toSet();

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
                        hintText: context.l10n.searchByNameUsernameOrPhone,
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
              Expanded(
                child: contacts.isEmpty
                    ? EmptyState(
                        icon: CupertinoIcons.person_2,
                        title: context.l10n.noPreferredContacts,
                        action: FilledButton.icon(
                          onPressed: () => _openAddContact(existingIds),
                          icon: const Icon(Icons.add, size: AppIconSize.sm),
                          label: Text(context.l10n.add),
                        ),
                      )
                    : filteredContacts.isEmpty
                        ? EmptyState(
                            icon: hasQuery
                                ? Icons.person_search
                                : CupertinoIcons.person_2,
                            title: hasQuery
                                ? context.l10n.noResults
                                : context.l10n.noPreferredContacts,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                              vertical: AppSpacing.lg,
                            ),
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final user = filteredContacts[index];
                              return _ContactTile(
                                user: user,
                                onRemove: () => _showRemoveOptions(user),
                              );
                            },
                          ),
              ),
            ],
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
