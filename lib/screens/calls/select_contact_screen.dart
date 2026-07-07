import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/call_limits.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/user_search.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  static int get _maxSelection => CallLimits.maxSelectable(isVideo: false);

  List<User> _allContacts = [];
  List<User> _filteredContacts = [];
  bool _isLoading = false;
  String _currentQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Mode multi-select (activé par long-press)
  bool _selecting = false;
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadContacts() async {
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);
    final local = await cache.getPreferredContactsOnce();
    if (!mounted) return;
    if (local.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() {
        _allContacts = local.map(localUserToUser).toList();
        _filteredContacts = _allContacts;
      });
    }

    unawaited(_refreshPreferredFromServer(cache));
  }

  Future<void> _refreshPreferredFromServer(LocalCacheRepository cache) async {
    final updated = await cache.syncAndGetPreferredContacts();
    if (!mounted) return;
    setState(() {
      _allContacts = updated.map(localUserToUser).toList();
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else if (query.isNotEmpty) {
        _filteredContacts = filterUsersBySearch(_allContacts, query);
      }
      _isLoading = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _filteredContacts = _allContacts);
      return;
    }

    _currentQuery = query;
    final localMatches = filterUsersBySearch(_allContacts, query);
    setState(() {
      _filteredContacts = localMatches;
      _isLoading = false;
    });

    if (localMatches.isEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_currentQuery == _searchController.text.trim() && mounted) {
          _searchUsersRemote(query);
        }
      });
    }
  }

  Future<void> _searchUsersRemote(String query) async {
    final localMatches = filterUsersBySearch(_allContacts, query);
    if (localMatches.isNotEmpty) {
      if (mounted) {
        setState(() {
          _filteredContacts = localMatches;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      final users = data.map((item) {
        if (item is User) return item;
        return User.fromJson(item as Map<String, dynamic>);
      }).toList();
      if (mounted) {
        setState(() {
          _filteredContacts = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _filteredContacts = _allContacts);
  }

  // ── Mode multi-select ──────────────────────────────────────────────

  // Conservé pour réactivation des appels de groupe.
  // ignore: unused_element
  void _enterSelectMode(User user) {
    setState(() {
      _selecting = true;
      _selectedIds.add(user.alanyaID);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(User user) {
    setState(() {
      if (_selectedIds.contains(user.alanyaID)) {
        _selectedIds.remove(user.alanyaID);
        if (_selectedIds.isEmpty) _selecting = false;
      } else {
        if (_selectedIds.length >= _maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Maximum $_maxSelection participants (appel audio). '
                'Vidéo : ${CallLimits.maxSelectable(isVideo: true)} max.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedIds.add(user.alanyaID);
      }
    });
  }

  // ── Appels ─────────────────────────────────────────────────────────

  Future<void> _initiateCall(User user, bool isVideo) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil non disponible, réessayez')),
      );
      return;
    }
    final callService = Provider.of<CallService>(context, listen: false);

    if (!mounted) return;
    await callService.initiateCall(
      targetUserId: user.alanyaID,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
      targetUserName: user.nom,
      targetUserPhoto: user.avatarUrl,
      isVideo: isVideo,
    );
    if (!mounted) return;
    if (callService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(callService.errorMessage!),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    await callService.navigateToCallUi(context);
  }

  // Conservé pour réactivation des appels de groupe.
  // ignore: unused_element
  Future<void> _initiateGroupCall(bool isVideo) async {
    if (_selectedIds.isEmpty) return;

    final maxOthers = CallLimits.maxSelectable(isVideo: isVideo);
    if (_selectedIds.length > maxOthers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(CallLimits.limitReachedMessage(isVideo: isVideo)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final me = auth.currentUser;
    if (me == null) return;

    final cs = context.read<CallService>();
    if (cs.status != CallStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un appel est déjà en cours')),
      );
      return;
    }

    final targets = _allContacts
        .where((u) => _selectedIds.contains(u.alanyaID))
        .toList();
    // Sécurité : si la sélection vient d'une recherche, repli sur _filteredContacts
    if (targets.length != _selectedIds.length) {
      final byId = {for (final u in _filteredContacts) u.alanyaID: u};
      for (final id in _selectedIds) {
        if (targets.any((u) => u.alanyaID == id)) continue;
        final u = byId[id];
        if (u != null) targets.add(u);
      }
    }

    final roster = targets
        .map((u) => GroupParticipantInfo(
              id: u.alanyaID.toString(),
              name: u.nom.isNotEmpty ? u.nom : u.pseudo,
              photo: u.avatarUrl,
            ))
        .toList();

    final roomId =
        'gcall_${me.alanyaID}_${DateTime.now().millisecondsSinceEpoch}';

    await cs.createGroupCall(
      roomId: roomId,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
      targetUserIds: targets.map((u) => u.alanyaID).toList(),
      isVideo: isVideo,
      targets: roster,
    );

    if (!mounted) return;
    await cs.navigateToCallUi(context);
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(_selecting ? Icons.close : Icons.arrow_back),
          onPressed:
              _selecting ? _exitSelectMode : () => Navigator.pop(context),
        ),
        title: Text(
          _selecting
              ? '${_selectedIds.length} / $_maxSelection'
              : 'Nouvel appel',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: IgnorePointer(
              ignoring: _selecting,
              child: Opacity(
                opacity: _selecting ? 0.45 : 1.0,
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Rechercher par nom, pseudo ou téléphone…',
                  onChanged: (_) {},
                  onClear: _clearSearch,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingState()
                : _filteredContacts.isEmpty
                    ? EmptyState(
                        icon: _searchController.text.isNotEmpty
                            ? Icons.person_search
                            : Icons.people_outline,
                        title: _searchController.text.isNotEmpty
                            ? 'Aucun résultat'
                            : 'Aucun contact',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.xl,
                                AppSpacing.md,
                                AppSpacing.xl,
                                AppSpacing.xs),
                            child: Text(
                              _selecting
                                  ? 'Appui long pour quitter la sélection'
                                  : (_searchController.text.isNotEmpty
                                      ? 'Résultats'
                                      : 'Contacts préférés'),
                              style: context.text.labelMedium?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final user = _filteredContacts[index];
                                return _buildContactTile(user);
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
      // Barre d'appel de groupe (sélection multiple) — masquée temporairement.
      // bottomNavigationBar: _selecting ? _buildSelectionBar() : null,
    );
  }

  Widget _buildContactTile(User user) {
    final isSelected = _selectedIds.contains(user.alanyaID);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      leading: Stack(
        children: [
          AppAvatar(
            imageUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
            name: user.nom.isNotEmpty ? user.nom : user.pseudo,
            size: AppSizes.avatarMd,
          ),
          if (_selecting && isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
      title: Text(
        user.nom.isNotEmpty ? user.nom : user.pseudo,
        style: context.text.titleSmall,
      ),
      subtitle: Text(
        '@${user.pseudo} • ${AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone)}',
        style: context.text.bodySmall
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
      trailing: _selecting
          ? Checkbox(
              value: isSelected,
              activeColor: context.colors.primary,
              onChanged: (_) => _toggleSelection(user),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.videocam, color: context.colors.primary),
                  onPressed: () => _initiateCall(user, true),
                ),
                IconButton(
                  icon: Icon(Icons.call, color: context.semantic.online),
                  onPressed: () => _initiateCall(user, false),
                ),
              ],
            ),
      onTap: _selecting ? () => _toggleSelection(user) : null,
      // Sélection multiple (appel de groupe) — masquée temporairement.
      // onLongPress: _selecting ? null : () => _enterSelectMode(user),
    );
  }

  // Conservé pour réactivation des appels de groupe.
  // ignore: unused_element
  Widget _buildSelectionBar() {
    final disabled = _selectedIds.isEmpty;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: AppShadows.medium,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : () => _initiateGroupCall(false),
                icon: Icon(Icons.call, color: context.semantic.success),
                label: Text(
                  'Appel vocal',
                  style: TextStyle(
                      color: context.semantic.success,
                      fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  side: BorderSide(color: context.semantic.success),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.brSm),
                ),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: ElevatedButton.icon(
                onPressed: disabled ? null : () => _initiateGroupCall(true),
                icon: const Icon(Icons.videocam),
                label: const Text(
                  'Appel vidéo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.brSm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
