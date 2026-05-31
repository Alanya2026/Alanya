import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/common.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contacts',
              style: context.text.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            // Nombre de contacts dynamique à brancher — données factices pour l'instant
            const Text(
              '254 contacts',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: ListView.builder(
        itemCount: 20,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildActionTile(context, Icons.group_add, 'Nouveau groupe');
          }
          if (index == 1) {
            return _buildActionTile(context, Icons.person_add, 'Nouveau contact');
          }

          final contactIndex = index - 2;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
            leading: AppAvatar(
              name: 'C$contactIndex',
              size: AppSizes.avatarMd,
            ),
            title: Text(
              'Contact $contactIndex',
              style: context.text.titleSmall,
            ),
            subtitle: Text(
              'Hey there! I am using Talky.',
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            onTap: () => Navigator.pop(context),
          );
        },
      ),
    );
  }

  Widget _buildActionTile(
      BuildContext context, IconData icon, String text) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      leading: CircleAvatar(
        radius: AppSizes.avatarMd / 2,
        backgroundColor: AppColors.brandPrimary,
        child: Icon(icon, color: AppColors.white),
      ),
      title: Text(text, style: context.text.titleSmall),
      onTap: () {},
    );
  }
}
