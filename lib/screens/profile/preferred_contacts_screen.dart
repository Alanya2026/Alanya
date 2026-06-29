import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../chats/contact_detail_screen.dart';

class PreferredContactsScreen extends StatelessWidget {
  const PreferredContactsScreen({
    super.key,
    required this.contacts,
    required this.onLongPress,
    required this.onAddContact,
  });

  final List<User> contacts;
  final void Function(User) onLongPress;
  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(
          'Contacts préférés',
          style: context.text.headlineSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: onAddContact,
            icon: Icon(Icons.add, size: AppIconSize.sm,
                color: context.colors.primary),
            label: Text(
              'Ajouter',
              style: TextStyle(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: contacts.isEmpty
          ? EmptyState(
              icon: CupertinoIcons.person_2,
              title: 'Aucun contact préféré',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final user = contacts[index];
                return _ContactTile(
                    user: user, onLongPress: () => onLongPress(user));
              },
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.user, required this.onLongPress});

  final User user;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final displayName =
        user.nom.isNotEmpty ? user.nom : user.pseudo;

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
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Stack(
                  children: [
                    AppAvatar(
                      imageUrl: user.avatarUrl.isNotEmpty
                          ? user.avatarUrl
                          : null,
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
                      Text(displayName, style: context.text.titleSmall),
                      if (user.pseudo.isNotEmpty)
                        Text(
                          '@${user.pseudo}',
                          style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant),
                        ),
                      Text(
                        AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone),
                        style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onLongPress,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm - 2),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Icon(Icons.person_remove_outlined,
                        color: context.colors.error,
                        size: AppIconSize.sm),
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
