import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/user_search.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/add_contact_sheet.dart';
import '../../widgets/common/common.dart';
import 'chat_detail_screen.dart';
import 'select_members_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  List<User> _contacts = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);
    final local = await cache.getPreferredContactsOnce();
    if (!mounted) return;
    if (local.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() {
        _contacts = local.map(localUserToUser).toList();
        _filteredUsers = _contacts;
      });
    }

    unawaited(_refreshPreferredFromServer(cache));
  }

  Future<void> _refreshPreferredFromServer(LocalCacheRepository cache) async {
    final updated = await cache.syncAndGetPreferredContacts();
    if (!mounted) return;
    setState(() {
      _contacts = updated.map(localUserToUser).toList();
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        _filteredUsers = _contacts;
      } else if (query.isNotEmpty) {
        _filteredUsers = filterUsersBySearch(_contacts, query);
      }
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _filteredUsers = _contacts);
      return;
    }

    _currentQuery = query;
    final localMatches = filterUsersBySearch(_contacts, query);
    setState(() {
      _filteredUsers = localMatches;
      _isLoading = false;
    });

    if (localMatches.isEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_currentQuery == _searchController.text.trim() && mounted) {
          _searchRemote(query);
        }
      });
    }
  }

  Future<void> _searchRemote(String query) async {
    final localMatches = filterUsersBySearch(_contacts, query);
    if (localMatches.isNotEmpty) {
      if (mounted) {
        setState(() => _filteredUsers = localMatches);
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (mounted) {
        // Le serveur ne m'exclut pas de ses résultats : sans ce filtre, chercher
        // mon propre numéro afficherait deux lignes (l'épinglée + le résultat).
        final myId = context.read<AuthProvider>().currentUser?.alanyaID;
        setState(() {
          _filteredUsers = data
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .where((u) => u.alanyaID != myId)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _filteredUsers = _contacts);
  }

  /// Moi-même, à épingler en tête de liste — ou null s'il ne faut pas l'y
  /// montrer. Avec une recherche en cours, uniquement si elle me correspond.
  User? _selfUser(bool hasQuery) {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return null;
    if (!hasQuery) return me;
    return userMatchesSearch(me, _searchController.text) ? me : null;
  }

  /// Entrée « M'envoyer un message », façon WhatsApp.
  ///
  /// Renvoie l'utilisateur courant via le même `Navigator.pop` que les autres
  /// lignes : les trois écrans appelants fonctionnent donc sans modification.
  Widget _buildSelfRow(User me) {
    final name = me.nom.isNotEmpty ? me.nom : me.pseudo;
    return InkWell(
      onTap: () => Navigator.pop(context, me),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: me.avatarUrl.isNotEmpty ? me.avatarUrl : null,
              name: name,
              size: AppSizes.avatarMd,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.selfChatTitle(name),
                    style: context.text.titleSmall,
                  ),
                  Text(
                    context.l10n.selfChatSubtitle,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final selfUser = _selfUser(hasQuery);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.newContact),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: AppSearchField(
              controller: _searchController,
              hintText: context.l10n.searchByNameUsernameOrPhone,
              onChanged: (_) {},
              onClear: _clearSearch,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm - 2),
            child: Row(
              children: [
                _buildActionTile(
                  Icons.group_outlined,
                  context.l10n.newGroup,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SelectMembersScreen()),
                  ),
                ),
                AppSpacing.hGapMd,
                _buildActionTile(
                  Icons.person_add_alt_1,
                  context.l10n.add,
                  _showAddContactSheet,
                ),
              ],
            ),
          ),
          if (selfUser != null) _buildSelfRow(selfUser),
          Expanded(
            child: _isLoading
                ? const LoadingState()
                : _filteredUsers.isEmpty
                    // Ne pas afficher « Aucun résultat » sous la ligne épinglée
                    // quand celle-ci est justement le résultat.
                    ? (selfUser != null
                        ? const SizedBox.shrink()
                        : EmptyState(
                            icon: hasQuery
                                ? Icons.person_search
                                : Icons.people_outline,
                            title: hasQuery
                                ? context.l10n.noResults
                                : context.l10n.noContacts,
                          ))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (hasQuery) _buildGroupsSection(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.md,
                                AppSpacing.xl,
                                AppSpacing.xs),
                            child: Text(
                              hasQuery ? context.l10n.results : context.l10n.preferredContacts,
                              style: context.text.labelMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredUsers.length,
                              itemBuilder: (_, idx) {
                                final user = _filteredUsers[idx];
                                return InkWell(
                                  onTap: () => Navigator.pop(context, user),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg,
                                        vertical: AppSpacing.sm),
                                    child: Row(
                                      children: [
                                        Stack(
                                          children: [
                                            AppAvatar(
                                              imageUrl: user.avatarUrl
                                                      .isNotEmpty
                                                  ? user.avatarUrl
                                                  : null,
                                              name: user.nom.isNotEmpty
                                                  ? user.nom
                                                  : user.pseudo,
                                              size: AppSizes.avatarMd,
                                              qrBadge: user.addedViaQr == true,
                                            ),
                                            if (user.isOnline)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.online,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                        color: context
                                                            .colors.surface,
                                                        width: 1.5),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        AppSpacing.hGapMd,
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user.nom.isNotEmpty
                                                    ? user.nom
                                                    : user.pseudo,
                                                style: context.text.titleSmall,
                                              ),
                                              if (user.pseudo.isNotEmpty)
                                                Text(
                                                  '@${user.pseudo}',
                                                  style: context.text.bodySmall
                                                      ?.copyWith(
                                                          color: context.colors
                                                              .onSurfaceVariant),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddContactSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0x00000000),
      builder: (_) => AddContactSheet(
        existingIds: _contacts.map((u) => u.alanyaID).toSet(),
        onAdded: (_) => _loadContacts(),
      ),
    );
  }

  Widget _buildGroupsSection() {
    final chat = context.read<ChatProvider>();
    final query = _searchController.text.trim().toLowerCase();
    return StreamBuilder<List<LocalConversation>>(
      stream: chat.watchConversations(),
      builder: (_, snap) {
        final groups = (snap.data ?? const <LocalConversation>[])
            .where((c) =>
                c.isGroup &&
                (c.groupName ?? '').toLowerCase().contains(query))
            .toList();
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xs),
              child: Text(
                context.l10n.groupsFilter,
                style: context.text.labelMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            for (final g in groups)
              InkWell(
                onTap: () => _openGroup(g),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: g.groupPhoto?.isNotEmpty == true
                            ? g.groupPhoto
                            : null,
                        name: g.groupName ?? context.l10n.groupFallback,
                        isGroup: true,
                        size: AppSizes.avatarMd,
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Text(
                          g.groupName ?? context.l10n.groupFallback,
                          style: context.text.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 1),
          ],
        );
      },
    );
  }

  void _openGroup(LocalConversation g) {
    final navigator = Navigator.of(context);
    final groupName = g.groupName ?? context.l10n.groupFallback;
    navigator.pop();
    navigator.push(MaterialPageRoute(
      builder: (_) => ChatDetailScreen(
        userName: groupName,
        conversationId: g.conversID,
        userId: null,
        isGroup: true,
        avatarUrl: g.groupPhoto,
      ),
    ));
  }

  Widget _buildActionTile(
      IconData icon, String text, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: context.colors.primaryContainer,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          borderRadius: AppRadius.brMd,
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: context.colors.primary, size: 26),
                AppSpacing.vGapXs,
                Text(
                  text,
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
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
