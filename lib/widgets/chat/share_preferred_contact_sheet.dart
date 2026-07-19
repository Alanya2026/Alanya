import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/contact_payload.dart';
import '../../core/utils/user_search.dart';
import '../../providers/auth_provider.dart';
import '../../talky_models.dart';
import '../add_contact_sheet.dart';
import '../common/common.dart';

/// Bottom sheet : choisir un contact préféré à partager dans le chat.
class SharePreferredContactSheet extends StatefulWidget {
  const SharePreferredContactSheet({super.key});

  @override
  State<SharePreferredContactSheet> createState() =>
      _SharePreferredContactSheetState();
}

class _SharePreferredContactSheetState
    extends State<SharePreferredContactSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final cache = context.read<LocalCacheRepository>();
    final myId =
        context.read<AuthProvider>().currentUser?.alanyaID ?? 0;
    final hasQuery = _searchQuery.isNotEmpty;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return AppBottomSheet(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Partager un contact',
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vGapMd,
            AppSearchField(
              controller: _searchController,
              hintText: 'Rechercher…',
              fillColor: context.semantic.surfaceMuted,
              borderColor: context.colors.outline,
              onChanged: (_) {},
              onClear: () => _searchController.clear(),
            ),
            AppSpacing.vGapMd,
            Expanded(
              child: StreamBuilder<List<LocalUser>>(
                stream: cache.watchPreferredContacts(),
                builder: (context, snapshot) {
                  final all = (snapshot.data ?? [])
                      .where((u) => u.alanyaID != myId)
                      .map(localUserToUser)
                      .toList();
                  final filtered = hasQuery
                      ? filterUsersBySearch(all, _searchQuery)
                      : all;
                  final existingIds = all.map((u) => u.alanyaID).toSet();

                  if (all.isEmpty) {
                    return EmptyState(
                      icon: CupertinoIcons.person_2,
                      title: 'Aucun contact préféré',
                      action: FilledButton.icon(
                        onPressed: () => _openAddContact(existingIds),
                        icon: const Icon(Icons.add, size: AppIconSize.sm),
                        label: const Text('Ajouter'),
                      ),
                    );
                  }

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.person_search,
                      title: 'Aucun résultat',
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return _ShareContactTile(
                        user: user,
                        onTap: () {
                          Navigator.pop(
                            context,
                            ContactPayload(
                              alanyaID: user.alanyaID,
                              nom: user.nom,
                              pseudo: user.pseudo.isNotEmpty
                                  ? user.pseudo
                                  : null,
                              alanyaPhone: user.alanyaPhone.isNotEmpty
                                  ? user.alanyaPhone
                                  : null,
                              avatarUrl: user.avatarUrl.isNotEmpty
                                  ? user.avatarUrl
                                  : null,
                            ),
                          );
                        },
                      );
                    },
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

class _ShareContactTile extends StatelessWidget {
  const _ShareContactTile({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = user.nom.isNotEmpty ? user.nom : user.pseudo;
    final phone = AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone);

    return Material(
      color: context.semantic.surfaceMuted,
      borderRadius: AppRadius.brSm,
      child: InkWell(
        borderRadius: AppRadius.brSm,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
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
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
