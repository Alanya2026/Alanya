import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import 'common/app_avatar.dart';
import 'profile_image_modal.dart';

/// Avatar carré réutilisable qui ouvre le modal de profil au clic.
///
/// Le rendu (image réseau/locale + fallback initiales) est délégué à
/// [AppAvatar] ; ce widget ne gère plus que l'ouverture du modal.
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? localPath;
  final String name;
  final int userId;
  final bool isGroup;
  final int? conversationId;
  final double size;
  final double borderRadius;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.name,
    required this.userId,
    this.isGroup = false,
    this.conversationId,
    this.size = AppSizes.avatarLg,
    this.borderRadius = AppRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      imageUrl: imageUrl,
      localPath: localPath,
      name: name,
      isGroup: isGroup,
      size: size,
      shape: AppAvatarShape.squircle,
      cornerRadius: borderRadius,
      showShadow: true,
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => ProfileImageModal(
            imageUrl: imageUrl,
            localPath: localPath,
            name: name,
            userId: userId,
            isGroup: isGroup,
            conversationId: conversationId,
          ),
        );
      },
    );
  }
}
