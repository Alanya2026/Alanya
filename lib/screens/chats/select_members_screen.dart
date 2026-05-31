import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'create_group_screen.dart';

class SelectMembersScreen extends StatefulWidget {
  const SelectMembersScreen({super.key});

  @override
  State<SelectMembersScreen> createState() => _SelectMembersScreenState();
}

class _SelectMembersScreenState extends State<SelectMembersScreen> {
  final _searchController = TextEditingController();
  List<User> _contacts = [];
  List<User> _filteredUsers = [];
  final Set<int> _selected = {};
  bool _isLoading = false;

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
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      setState(() {
        _contacts = data
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
        _filteredUsers = _contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _filteredUsers = _contacts);
    } else {
      _searchAllUsers(query);
    }
  }

  Future<void> _searchAllUsers(String query) async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (mounted) {
        setState(() {
          _filteredUsers = data
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  void _toggle(User user) {
    setState(() {
      if (_selected.contains(user.alanyaID)) {
        _selected.remove(user.alanyaID);
      } else {
        _selected.add(user.alanyaID);
      }
    });
  }

  void _goToCreate() {
    final selectedUsers =
        _contacts.where((u) => _selected.contains(u.alanyaID)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(members: selectedUsers),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _filteredUsers = _contacts);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty
              ? 'Nouveau groupe'
              : '${_selected.length} sélectionné',
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _goToCreate,
              child: Text(
                'Suivant',
                style: TextStyle(
                  color: context.colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: AppSearchField(
              controller: _searchController,
              hintText: 'Rechercher par nom, pseudo ou téléphone…',
              onChanged: (_) {},
              onClear: _clearSearch,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingState()
                : _filteredUsers.isEmpty
                    ? EmptyState(
                        icon: hasQuery
                            ? Icons.person_search
                            : Icons.people_outline,
                        title: hasQuery ? 'Aucun résultat' : 'Aucun contact',
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (_, idx) {
                          final user = _filteredUsers[idx];
                          final selected =
                              _selected.contains(user.alanyaID);
                          return InkWell(
                            onTap: () => _toggle(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      AppAvatar(
                                        imageUrl: user.avatarUrl.isNotEmpty
                                            ? user.avatarUrl
                                            : null,
                                        name: user.nom.isNotEmpty
                                            ? user.nom
                                            : user.pseudo,
                                        size: AppSizes.avatarMd,
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
                                                  color: context.colors.surface,
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
                                  AnimatedContainer(
                                    duration: AppDurations.fast,
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? context.colors.primary
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected
                                            ? context.colors.primary
                                            : context.colors.outline,
                                        width: 2,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check,
                                            color: Colors.white, size: 16)
                                        : null,
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
    );
  }
}
