import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/call_limits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';

class ParticipantPickerScreen extends StatefulWidget {
  final List<User> initialSelected;
  final String confirmLabel;
  final int? maxSelectable;
  final bool isVideo;
  final Set<int> excludeIds;

  const ParticipantPickerScreen({
    super.key,
    this.initialSelected = const [],
    this.confirmLabel = 'Confirmer',
    this.maxSelectable,
    this.isVideo = true,
    this.excludeIds = const {},
  });

  int get effectiveMaxSelectable =>
      maxSelectable ?? CallLimits.maxSelectable(isVideo: isVideo);

  int get maxTotal => CallLimits.maxParticipants(isVideo: isVideo);

  @override
  State<ParticipantPickerScreen> createState() =>
      _ParticipantPickerScreenState();
}

class _ParticipantPickerScreenState
    extends State<ParticipantPickerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  late final List<User> _selected;
  List<User> _results = [];
  bool _isLoading = false;
  bool _showingContacts = true;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _searchController.addListener(_onSearchChanged);
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      if (!mounted) return;
      setState(() {
        _results = data
            .map((e) =>
                e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .where((u) => !widget.excludeIds.contains(u.alanyaID))
            .toList();
        _isLoading = false;
        _showingContacts = true;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _currentQuery = query;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_currentQuery == _searchController.text.trim() && mounted) {
          _searchUsers(query);
        }
      });
    } else if (query.isEmpty) {
      setState(() => _showingContacts = true);
      _loadContacts();
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isLoading = true;
      _showingContacts = false;
    });
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = data
            .map((e) =>
                e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .where((u) => !widget.excludeIds.contains(u.alanyaID))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isSelected(User user) =>
      _selected.any((u) => u.alanyaID == user.alanyaID);

  bool get _atLimit => _selected.length >= widget.effectiveMaxSelectable;

  void _toggle(User user) {
    if (!_isSelected(user) && _atLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CallLimits.limitReachedMessage(isVideo: widget.isVideo),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      if (_isSelected(user)) {
        _selected.removeWhere((u) => u.alanyaID == user.alanyaID);
      } else {
        _selected.add(user);
      }
    });
  }

  void _confirm() => Navigator.pop(context, List<User>.from(_selected));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter des participants'),
            Text(
              '${_selected.length}/${widget.effectiveMaxSelectable} sélectionné${_selected.length > 1 ? 's' : ''}',
              style: context.text.labelSmall?.copyWith(
                color: _atLimit
                    ? context.semantic.warning
                    : context.colors.onSurfaceVariant,
                fontWeight:
                    _atLimit ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(
                widget.confirmLabel,
                style: TextStyle(
                  color: context.colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          AppSpacing.hGapSm,
        ],
      ),
      body: Column(
        children: [
          // Chips des sélectionnés
          if (_selected.isNotEmpty)
            _SelectedChips(selected: _selected, onRemove: _toggle),

          // Banner limite atteinte
          if (_atLimit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              color: AppColors.warningContainer,
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: AppIconSize.sm,
                      color: AppColors.warning),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      '${CallLimits.limitReachedMessage(isVideo: widget.isVideo)} '
                      'Retirez un participant pour en ajouter un autre.',
                      style: context.text.labelSmall
                          ?.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: AppSearchField(
              controller: _searchController,
              hintText: 'Rechercher par nom, pseudo…',
              onChanged: (_) {},
              onClear: () {
                _searchController.clear();
              },
            ),
          ),

          // Label section
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _showingContacts ? 'Contacts' : 'Résultats',
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _isLoading
                ? const LoadingState()
                : _results.isEmpty
                    ? EmptyState(
                        icon: _showingContacts
                            ? Icons.group_outlined
                            : Icons.person_search,
                        title: _showingContacts
                            ? 'Aucun contact pour le moment'
                            : 'Aucun résultat pour "${_searchController.text}"',
                        message: _showingContacts
                            ? 'Recherchez un utilisateur par nom ou pseudo'
                            : null,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.lg),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final selected = _isSelected(user);
                          return _UserTile(
                            user: user,
                            selected: selected,
                            disabled: _atLimit && !selected,
                            onTap: () => _toggle(user),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                    AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(AppSizes.buttonHeight + 4),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.brMd),
                    elevation: 0,
                  ),
                  child: Text(
                    '${widget.confirmLabel} · ${_selected.length} participant${_selected.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Chips des participants sélectionnés ─────────────────────────────────────

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({required this.selected, required this.onRemove});

  final List<User> selected;
  final void Function(User) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandContainer,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm - 2,
        children: selected.map((user) {
          final initial =
              user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
          return Chip(
            avatar: CircleAvatar(
              backgroundColor: context.colors.primary,
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
            ),
            label: Text(
              user.nom.isNotEmpty ? user.nom : user.pseudo,
              style: context.text.labelMedium,
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => onRemove(user),
            backgroundColor: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.brPill,
              side: BorderSide(color: context.colors.primaryContainer),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Tuile d'un utilisateur ──────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final User user;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Stack(
                children: [
                  AppAvatar(
                    imageUrl: user.avatarUrl.isNotEmpty
                        ? user.avatarUrl
                        : null,
                    name: user.nom.isNotEmpty ? user.nom : user.pseudo,
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
                              color: context.colors.surface, width: 1.5),
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
                    Text(
                      user.nom.isNotEmpty ? user.nom : user.pseudo,
                      style: context.text.titleSmall,
                    ),
                    if (user.pseudo.isNotEmpty)
                      Text(
                        '@${user.pseudo}',
                        style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant),
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
      ),
    );
  }
}
