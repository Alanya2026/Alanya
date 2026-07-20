import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/user_search.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../chats/contact_detail_screen.dart';

/// Liste des utilisateurs bloqués par moi, avec déblocage.
class BlockedContactsScreen extends StatefulWidget {
  const BlockedContactsScreen({super.key});

  @override
  State<BlockedContactsScreen> createState() => _BlockedContactsScreenState();
}

class _BlockedContactsScreenState extends State<BlockedContactsScreen> {
  final _searchController = TextEditingController();
  List<User> _contacts = [];
  List<User> _filtered = [];
  bool _loading = true;
  final Set<int> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<TalkyApiClient>();
      final data = await api.getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _contacts = data
            .map((e) =>
                e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
        _syncFilter();
      });
    } catch (e, st) {
      AppLog.e('BlockedContacts', 'Chargement échoué', e, st);
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToLoadBlockedContacts)),
      );
    }
  }

  void _syncFilter() {
    final query = _searchController.text.trim();
    _filtered = query.isEmpty
        ? List<User>.from(_contacts)
        : filterUsersBySearch(_contacts, query);
  }

  void _onSearchChanged() {
    setState(_syncFilter);
  }

  Future<bool> _confirmUnblock(User user) async {
    final name = user.nom.isNotEmpty ? user.nom : user.pseudo;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.unblockThisContact),
        content: Text(context.l10n.canContactAgain(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.l10n.unblock,
              style: TextStyle(color: context.colors.primary),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _unblock(User user) async {
    if (_unblocking.contains(user.alanyaID)) return;
    if (!await _confirmUnblock(user)) return;
    if (!mounted) return;

    final api = context.read<TalkyApiClient>();
    setState(() => _unblocking.add(user.alanyaID));
    try {
      await api.unblockUser(user.alanyaID);
      if (!mounted) return;
      setState(() {
        _contacts =
            _contacts.where((u) => u.alanyaID != user.alanyaID).toList();
        _unblocking.remove(user.alanyaID);
        _syncFilter();
      });
    } catch (e, st) {
      AppLog.e('BlockedContacts', 'Déblocage échoué', e, st);
      if (!mounted) return;
      setState(() => _unblocking.remove(user.alanyaID));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToUnblockThisContact)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(
          context.l10n.settingsPrivacySubtitle,
          style: context.text.headlineSmall,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_contacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    child: AppSearchField(
                      controller: _searchController,
                      hintText: context.l10n.search,
                      fillColor: context.colors.surface,
                      borderColor: context.colors.outline,
                      onChanged: (_) {},
                      onClear: () => _searchController.clear(),
                    ),
                  ),
                Expanded(
                  child: _contacts.isEmpty
                      ? EmptyState(
                          icon: Icons.block,
                          title: context.l10n.noBlockedContacts,
                          message:
                              context.l10n.peopleYouBlockWillAppearHere,
                        )
                      : _filtered.isEmpty
                          ? EmptyState(
                              icon: hasQuery
                                  ? Icons.person_search
                                  : Icons.block,
                              title: hasQuery
                                  ? context.l10n.noResults
                                  : context.l10n.noBlockedContacts,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl,
                                vertical: AppSpacing.lg,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final user = _filtered[index];
                                return _BlockedTile(
                                  user: user,
                                  unblocking:
                                      _unblocking.contains(user.alanyaID),
                                  onUnblock: () => _unblock(user),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

class _BlockedTile extends StatelessWidget {
  const _BlockedTile({
    required this.user,
    required this.unblocking,
    required this.onUnblock,
  });

  final User user;
  final bool unblocking;
  final VoidCallback onUnblock;

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
                if (unblocking)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: onUnblock,
                    child: Text(
                      context.l10n.unblock,
                      style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
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
