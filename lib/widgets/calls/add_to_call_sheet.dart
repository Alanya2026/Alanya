import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/user_search.dart';
import '../../talky_models.dart';
import '../common/app_avatar.dart';

/// Feuille de sélection du participant à ajouter à un appel en cours.
///
/// Modale par-dessus l'appel, qui reste actif et audible derrière — un écran
/// plein en ferait perdre le contexte. Sélection unique : un appui lance
/// l'invitation et referme, sans bouton de validation.
class AddToCallSheet extends StatefulWidget {
  const AddToCallSheet({super.key, required this.excludedIds});

  /// Soi-même et l'autre participant : eux ne peuvent pas être ajoutés.
  final Set<int> excludedIds;

  /// Ouvre la feuille et renvoie l'utilisateur choisi, ou null.
  static Future<User?> show(BuildContext context, {required Set<int> excludedIds}) {
    return showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToCallSheet(excludedIds: excludedIds),
    );
  }

  @override
  State<AddToCallSheet> createState() => _AddToCallSheetState();
}

class _AddToCallSheetState extends State<AddToCallSheet> {
  final TextEditingController _search = TextEditingController();
  List<User> _all = [];
  List<User> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_onSearch);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Le cache local d'abord : la liste s'affiche sans attendre le réseau.
    try {
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      final local = await cache.getPreferredContactsOnce();
      if (!mounted) return;
      setState(() {
        _all = local.map(localUserToUser).toList();
        _filtered = _all;
        _loading = _all.isEmpty;
      });

      final updated = await cache.syncAndGetPreferredContacts();
      if (!mounted) return;
      setState(() {
        _all = updated.map(localUserToUser).toList();
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      // Une synchronisation qui échoue ne doit pas laisser un chargement sans
      // fin : on garde ce que le cache a pu donner.
      debugPrint('[AddToCall] ** chargement des contacts: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearch() => setState(_applyFilter);

  void _applyFilter() {
    final q = _search.text.trim();
    _filtered = q.isEmpty ? _all : filterUsersBySearch(_all, q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final visible =
        _filtered.where((u) => !widget.excludedIds.contains(u.alanyaID)).toList();
    final excluded =
        _filtered.where((u) => widget.excludedIds.contains(u.alanyaID)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.confAddSheetTitle,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: TextField(
                  controller: _search,
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.search,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              AppSpacing.vGapMd,
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (visible.isEmpty && excluded.isEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            l10n.noContactsToAdd,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: visible.length + excluded.length,
                        itemBuilder: (context, i) {
                          if (i < visible.length) {
                            return _ContactRow(
                              user: visible[i],
                              onTap: () =>
                                  Navigator.of(context).pop(visible[i]),
                            );
                          }
                          // Les déjà-présents restent visibles mais inertes :
                          // les masquer laisserait croire à une absence.
                          return _ContactRow(
                            user: excluded[i - visible.length],
                            trailing: l10n.confAlreadyInCall,
                            onTap: null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.user, this.onTap, this.trailing});

  final User user;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final name = user.nom.isNotEmpty ? user.nom : user.pseudo;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: ListTile(
        onTap: onTap,
        leading: AppAvatar(imageUrl: user.avatarUrl, name: name, size: 40),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing == null
            ? null
            : Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
