import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/local_cache_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';
import '../core/utils/app_log.dart';
import 'common/common.dart';

class AddContactSheet extends StatefulWidget {
  const AddContactSheet({
    super.key,
    required this.existingIds,
    required this.onAdded,
  });

  final Set<int> existingIds;
  final void Function(User) onAdded;

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final _searchController = TextEditingController();
  List<User> _results = [];
  bool _isLoading = false;
  String _currentQuery = '';
  final Set<int> _adding = {};
  late Set<int> _existingIds;

  @override
  void initState() {
    super.initState();
    _existingIds = Set<int>.from(widget.existingIds);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _currentQuery = query;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_currentQuery == _searchController.text.trim() && mounted) {
          _search(query);
        }
      });
    } else {
      setState(() => _results = []);
    }
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = data
            .map((e) =>
                e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addContact(User user) async {
    setState(() => _adding.add(user.alanyaID));
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      await apiClient.addContact(user.alanyaID);
      if (!mounted) return;
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      await cache.upsertKnownUser(user, preferred: true);
      if (!mounted) return;
      widget.onAdded(user);
      setState(() {
        _adding.remove(user.alanyaID);
        _existingIds.add(user.alanyaID);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${user.nom.isNotEmpty ? user.nom : user.pseudo} ajouté aux contacts préférés'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      AppLog.e('AddContact', 'Ajout contact préféré échoué', e, st);
      if (!mounted) return;
      setState(() => _adding.remove(user.alanyaID));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ajouter ce contact, réessayez')),
      );
    }
  }

  bool _isAlreadyContact(User user) =>
      _existingIds.contains(user.alanyaID);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.sheetTop,
        ),
        child: Column(
          children: [
            AppSpacing.vGapSm,
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AppSpacing.vGapLg,
            Text(
              'Ajouter un contact préféré',
              style: context.text.titleLarge,
            ),
            AppSpacing.vGapLg,
            Padding(
              padding: AppSpacing.screenH,
              child: AppSearchField(
                controller: _searchController,
                hintText: 'Rechercher par nom, pseudo ou téléphone…',
                autofocus: true,
                onChanged: (_) {},
                onClear: () {
                  _searchController.clear();
                  setState(() => _results = []);
                },
              ),
            ),
            AppSpacing.vGapMd,

            Expanded(
              child: _isLoading
                  ? const LoadingState()
                  : _results.isEmpty
                      ? EmptyState(
                          icon: _searchController.text.length < 2
                              ? CupertinoIcons.search
                              : Icons.person_search,
                          title: _searchController.text.length < 2
                              ? 'Tapez au moins 2 caractères'
                              : 'Aucun résultat',
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.lg),
                          itemCount: _results.length,
                          itemBuilder: (_, index) {
                            final user = _results[index];
                            return AddContactItem(
                              user: user,
                              alreadyContact: _isAlreadyContact(user),
                              isAdding: _adding.contains(user.alanyaID),
                              onAdd: () => _addContact(user),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget réutilisable pour afficher un élément de contact dans la liste.
class AddContactItem extends StatelessWidget {
  const AddContactItem({
    super.key,
    required this.user,
    required this.alreadyContact,
    required this.isAdding,
    required this.onAdd,
  });

  final User user;
  final bool alreadyContact;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
      leading: AppAvatar(
        imageUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
        name: user.nom.isNotEmpty ? user.nom : user.pseudo,
        size: AppSizes.avatarMd,
      ),
      title: Text(
        user.nom.isNotEmpty ? user.nom : user.pseudo,
        style: context.text.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.pseudo.isNotEmpty)
            Text(
              '@${user.pseudo}',
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          Text(
            user.alanyaPhone,
            style: context.text.labelSmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
      trailing: alreadyContact
          ? Chip(
              label: const Text('Déjà ajouté', style: TextStyle(fontSize: 12)),
              backgroundColor: AppColors.surfaceMuted,
              padding: EdgeInsets.zero,
            )
          : isAdding
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.primary,
                  ),
                )
              : IconButton(
                  icon: Icon(
                    Icons.person_add_outlined,
                    color: context.colors.primary,
                  ),
                  onPressed: onAdd,
                ),
    );
  }
}
