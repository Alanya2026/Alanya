import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'profile_image_modal.dart';

/// Avatar carré réutilisable qui ouvre le modal au clic
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
    this.size = 60,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    final hasImage = (imageUrl != null && imageUrl!.isNotEmpty) ||
        localPath != null;

    if (!hasImage) {
      return _buildFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: _buildImageContent(),
    );
  }

  Widget _buildImageContent() {
    if (localPath != null) {
      return Image.file(
        File(localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl ?? '',
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: Colors.grey.shade200,
      ),
      errorWidget: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.indigo.shade100,
      ),
      child: Center(
        child: isGroup
            ? Icon(
                Icons.group,
                size: size * 0.5,
                color: Colors.indigo,
              )
            : Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
      ),
    );
  }
}
