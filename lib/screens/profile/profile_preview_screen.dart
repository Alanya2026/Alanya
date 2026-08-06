import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../chats/contact_detail_screen.dart';

/// Aperçu lecture seule du profil connecté (comme fiche contact).
class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.accountHubProfilePreview)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ContactDetailScreen(
      userId: user.alanyaID,
      initialName: user.nom,
      initialAvatar: user.avatarUrl,
    );
  }
}
