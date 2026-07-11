import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../core/services/call_service.dart';
import '../core/utils/app_log.dart';
import '../providers/auth_provider.dart';
import '../screens/chats/fullscreen_profile_image_viewer.dart';
import '../screens/chats/contact_detail_screen.dart';
import '../screens/chats/group_detail_screen.dart';
import '../screens/chats/chat_detail_screen.dart';

/// Modal pour afficher l'image de profil avec CTA.
class ProfileImageModal extends StatefulWidget {
  final String? imageUrl;
  final String? localPath;
  final String name;
  final int userId;
  final bool isGroup;
  final int? conversationId;

  const ProfileImageModal({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.name,
    required this.userId,
    required this.isGroup,
    this.conversationId,
  });

  @override
  State<ProfileImageModal> createState() => _ProfileImageModalState();
}

class _ProfileImageModalState extends State<ProfileImageModal> {
  late CallService _callService;

  @override
  void initState() {
    super.initState();
    _callService = Provider.of<CallService>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {},
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullscreenProfileImageViewer(
                                imageUrl: widget.imageUrl,
                                localPath: widget.localPath,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header nom
                            Container(
                              width: 300,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(AppRadius.md),
                                  topRight: Radius.circular(AppRadius.md),
                                ),
                              ),
                              child: Text(
                                widget.name,
                                textAlign: TextAlign.center,
                                style: context.text.titleLarge,
                              ),
                            ),
                            _buildProfileImage(),
                            // Bande CTA
                            Container(
                              width: 300,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(AppRadius.md),
                                  bottomRight: Radius.circular(AppRadius.md),
                                ),
                                boxShadow: AppShadows.medium,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!widget.isGroup) ...[
                                    _buildCTAIcon(Icons.message_outlined,
                                        'Message', _openChat),
                                    _buildCTAIcon(
                                        Icons.call,
                                        'Audio',
                                        () => _initiateCall(isVideo: false)),
                                    _buildCTAIcon(
                                        Icons.videocam_outlined,
                                        'Vidéo',
                                        () => _initiateCall(isVideo: true)),
                                  ],
                                  _buildCTAIcon(
                                      Icons.info_outlined, 'Info', _openContactDetail),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl + 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    final hasImage =
        (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ||
            widget.localPath != null;

    if (!hasImage) return _buildFallback();

    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRect(child: _buildImageContent()),
    );
  }

  Widget _buildImageContent() {
    if (widget.localPath != null) {
      return Image.file(
        File(widget.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.imageUrl ?? '',
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: AppColors.surfaceSubtle,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.brandPrimary),
        ),
      ),
      errorWidget: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: 300,
      height: 300,
      color: AppColors.brandContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isGroup)
              const Icon(
                Icons.group,
                size: 80,
                color: AppColors.brandPrimary,
              )
            else
              Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            AppSpacing.vGapLg,
          ],
        ),
      ),
    );
  }

  Widget _buildCTAIcon(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.brandPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: AppIconSize.sm),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────

  Future<void> _openChat() async {
    if (widget.isGroup) return;
    if (!mounted) return;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: widget.name,
          userId: widget.userId,
          isGroup: false,
          avatarUrl: widget.imageUrl,
        ),
      ),
    );
  }

  Future<void> _initiateCall({required bool isVideo}) async {
    if (widget.isGroup) return;
    try {
      final me = context.read<AuthProvider>().currentUser;
      if (me == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil non disponible, réessayez')),
        );
        return;
      }
      if (!mounted) return;

      await _callService.initiateCall(
        targetUserId: widget.userId,
        myId: me.alanyaID,
        myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
        myPhoto: me.avatarUrl,
        targetUserName: widget.name,
        targetUserPhoto: widget.imageUrl,
        isVideo: isVideo,
      );
      if (!mounted) return;

      if (_callService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_callService.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        await _callService.navigateToCallUi(context);
      }
    } catch (e, st) {
      AppLog.e('ProfileImageModal', 'Lancement de l\'appel échoué', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l\'appel, réessayez')),
        );
      }
    }
  }

  Future<void> _openContactDetail() async {
    Navigator.pop(context);
    if (widget.isGroup) {
      if (widget.conversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur : ID du groupe introuvable')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(
            conversationId: widget.conversationId!,
            groupName: widget.name,
            groupAvatar: widget.imageUrl,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailScreen(
            userId: widget.userId,
            conversationId: widget.conversationId,
            initialName: widget.name,
            initialAvatar: widget.imageUrl ?? '',
          ),
        ),
      );
    }
  }
}
