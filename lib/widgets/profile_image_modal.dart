import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/call_service.dart';
import '../talky_api_client.dart';
import '../screens/chats/fullscreen_profile_image_viewer.dart';
import '../screens/chats/contact_detail_screen.dart';
import '../screens/chats/group_detail_screen.dart';
import '../screens/chats/chat_detail_screen.dart';
import '../screens/calls/ongoing_call_screen.dart';

/// Modal pour afficher l'image de profil avec CTA
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
  late TalkyApiClient _apiClient;
  late CallService _callService;

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    _callService = Provider.of<CallService>(context, listen: false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () {}, // Empêche la fermeture au clic sur le modal
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
                            // Header avec nom - attaché au-dessus de l'image
                            Container(
                              width: 300,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Text(
                                widget.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _buildProfileImage(),
                            // Bande CTA directement attachée sous la photo
                            Container(
                              width: 300,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(20),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
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
                                        () =>
                                            _initiateCall(isVideo: false)),
                                    _buildCTAIcon(
                                        Icons.videocam_outlined,
                                        'Vidéo',
                                        () =>
                                            _initiateCall(isVideo: true)),
                                  ],
                                  _buildCTAIcon(Icons.info_outlined, 'Info',
                                      _openContactDetail),
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
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    final hasImage = (widget.imageUrl != null &&
            widget.imageUrl!.isNotEmpty) ||
        widget.localPath != null;

    if (!hasImage) {
      return _buildFallback();
    }

    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: _buildImageContent(),
      ),
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
        color: Colors.grey.shade300,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.indigo),
        ),
      ),
      errorWidget: (_, __, ___) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        color: Colors.indigo.shade100,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isGroup)
              const Icon(
                Icons.group,
                size: 80,
                color: Colors.indigo,
              )
            else
              Text(
                widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Pas de photo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.indigo.shade600,
              ),
            ),
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
          color: Colors.indigo,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _openChat() async {
    if (widget.isGroup) return;

    try {
      final result =
          await _apiClient.createConversation(participantID: widget.userId);
      final conversationId = result['conversID'] as int?;

      if (conversationId != null && mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              userName: widget.name,
              conversationId: conversationId,
              userId: widget.userId,
              isGroup: false,
              avatarUrl: widget.imageUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erreur lors de l\'ouverture du chat')),
        );
      }
    }
  }

  Future<void> _initiateCall({required bool isVideo}) async {
    if (widget.isGroup) return;

    try {
      final userData = await _apiClient.getMe();
      final myId = userData['alanyaID'] ?? 0;
      final myPhoto = userData['avatar_url'];

      if (!mounted) return;

      await _callService.initiateCall(
        targetUserId: widget.userId,
        myId: myId,
        myName: userData['nom'] ?? userData['pseudo'] ?? '',
        myPhoto: myPhoto,
        targetUserName: widget.name,
        targetUserPhoto: widget.imageUrl,
        isVideo: isVideo,
      );

      if (!mounted) return;

      if (_callService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_callService.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _openContactDetail() async {
    Navigator.pop(context);

    if (widget.isGroup) {
      // Ouvrir GroupDetailScreen pour les groupes
      if (widget.conversationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erreur : ID du groupe introuvable')),
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
      // Ouvrir ContactDetailScreen pour les contacts
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
