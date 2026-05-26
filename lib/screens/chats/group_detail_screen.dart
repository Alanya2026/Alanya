import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';
import '../../core/db/app_database.dart';
import '../calls/group_participants_picker_screen.dart';
import '../calls/ongoing_call_screen.dart';
import 'contact_detail_screen.dart';
import 'conversation_media_screen.dart';
import 'media_viewer_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final int conversationId;
  final String groupName;
  final String? groupAvatar;

  const GroupDetailScreen({
    super.key,
    required this.conversationId,
    required this.groupName,
    this.groupAvatar,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Conversation? _group;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      final chat = context.read<ChatProvider>();
      final conversations = await chat.repository.watchConversations().first;
      final localConv = conversations
          .where((c) => c.conversID == widget.conversationId)
          .firstOrNull;

      if (localConv != null) {
        _group = Conversation(
          conversID: localConv.conversID,
          isGroup: localConv.isGroup,
          groupName: localConv.groupName,
          groupPhoto: localConv.groupPhoto,
          lastMessage: localConv.lastMessage,
          lastMessageAt: localConv.lastMessageAt?.toIso8601String(),
          lastMessageSenderID: localConv.lastMessageSenderID,
          lastMessageType: localConv.lastMessageType,
          lastMessageStatus: localConv.lastMessageStatus,
          unreadCount: localConv.unreadCount,
          isPinned: localConv.isPinned,
          isArchived: localConv.isArchived,
          participants: _parseParticipants(localConv.participantsJson),
        );
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<User> _parseParticipants(String json) {
    try {
      final data = (jsonDecode(json) as List?)?.cast<Map<String, dynamic>>() ?? [];
      return data.map((j) => User.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _startGroupCall(bool isVideo) async {
    if (_group == null) return;
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser;
    if (me == null) return;

    final members = _group!.participants;
    final others =
        members.where((u) => u.alanyaID != me.alanyaID).toList();

    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun autre membre à appeler')),
      );
      return;
    }

    List<User> targets;
    if (others.length <= 9) {
      targets = others;
    } else {
      final picked = await Navigator.push<List<User>>(
        context,
        MaterialPageRoute(
          builder: (_) => GroupParticipantsPickerScreen(
            members: others,
            isVideo: isVideo,
          ),
        ),
      );
      if (picked == null || picked.isEmpty || !mounted) return;
      targets = picked;
    }

    final cs = context.read<CallService>();
    if (cs.status != CallStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un appel est déjà en cours')),
      );
      return;
    }

    final roster = targets
        .map((u) => GroupParticipantInfo(
              id: u.alanyaID.toString(),
              name: u.nom.isNotEmpty ? u.nom : u.pseudo,
              photo: u.avatarUrl,
            ))
        .toList();

    final roomId =
        'group_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}';

    await cs.createGroupCall(
      roomId: roomId,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
      targetUserIds: targets.map((u) => u.alanyaID).toList(),
      isVideo: isVideo,
      targets: roster,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: const Text('Vous ne verrez plus ce groupe dans votre liste de discussions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);
      await api.leaveGroup(widget.conversationId);
      if (!mounted) return;
      await chat.refreshConversations();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Infos du groupe',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: _group == null
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.videocam_outlined),
                  tooltip: 'Appel vidéo',
                  onPressed: () => _startGroupCall(true),
                ),
                IconButton(
                  icon: const Icon(Icons.call_outlined),
                  tooltip: 'Appel vocal',
                  onPressed: () => _startGroupCall(false),
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _group == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.group_off,
                        color: Colors.grey,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text('Groupe introuvable'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _Header(
                      groupName: widget.groupName,
                      groupAvatar: widget.groupAvatar,
                      groupPhoto: _group!.groupPhoto,
                      memberCount: _group!.participants.length,
                    ),
                    const SizedBox(height: 16),
                    _MediaCard(
                      conversationId: widget.conversationId,
                      conversationName: widget.groupName,
                    ),
                    const SizedBox(height: 16),
                    _MembersCard(
                      participants: _group?.participants ?? [],
                    ),
                    const SizedBox(height: 16),
                    _DangerCard(onLeave: _leaveGroup),
                  ],
                ),
    );
  }
}

// ── CARD CONTAINER ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String groupName;
  final String? groupAvatar;
  final String? groupPhoto;
  final int memberCount;

  const _Header({
    required this.groupName,
    this.groupAvatar,
    this.groupPhoto,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = groupAvatar ?? groupPhoto;
    final hasPhoto = hasValidAvatarUrl(avatarUrl ?? '');

    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: const Color(0xFFCBD0E8),
            backgroundImage: hasPhoto ? CachedNetworkImageProvider(avatarUrl!) : null,
            child: hasPhoto
                ? null
                : Text(
                    groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            groupName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Groupe • $memberCount membres',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── MEDIA CARD ────────────────────────────────────────────────────────

class _MediaCard extends StatefulWidget {
  final int conversationId;
  final String conversationName;

  const _MediaCard({
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  List<LocalMessage> _mediaMessages = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final chat = context.read<ChatProvider>();
    await chat.repository.syncMessages(widget.conversationId);
    chat.watchMessages(widget.conversationId).listen(_onMessages);
  }

  void _onMessages(List<LocalMessage> messages) {
    final media = <LocalMessage>[];
    for (final m in messages) {
      if ((m.type == 1 || m.type == 2 || m.type == 4) &&
          m.mediaUrl != null &&
          m.mediaUrl!.isNotEmpty) {
        media.add(m);
      }
    }
    if (!mounted) return;
    setState(() => _mediaMessages = media.reversed.take(4).toList());
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Médias, liens et docs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationMediaScreen(
                      conversationId: widget.conversationId,
                      conversationName: widget.conversationName,
                    ),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Text(
                        'Voir tout',
                        style: TextStyle(
                          color: Color(0xFF1E66D8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFF1E66D8),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _mediaMessages.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Aucun média partagé',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              : SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaMessages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final msg = _mediaMessages[index];
                      return GestureDetector(
                        onTap: msg.type == 4
                            ? () => _openDoc(msg)
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaViewerScreen(
                                    isVideo: msg.type == 2,
                                    localPath: msg.localMediaPath,
                                    networkUrl: msg.mediaUrl,
                                    title: msg.mediaName,
                                  ),
                                ),
                              ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildThumb(msg),
                                if (msg.type == 2)
                                  Container(
                                    color: Colors.black26,
                                    child: const Icon(
                                      CupertinoIcons.play_circle_fill,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildThumb(LocalMessage msg) {
    if (msg.type == 4) {
      final name = msg.mediaName ?? 'Document';
      final ext = name.contains('.')
          ? name.split('.').last.toUpperCase()
          : 'FILE';
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _docColor(ext),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                ext,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (msg.type == 2) {
      return Container(color: Colors.grey.shade200);
    }

    final hasLocal = msg.localMediaPath != null &&
        File(msg.localMediaPath!).existsSync();
    if (hasLocal) {
      return Image.file(
        File(msg.localMediaPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    }
    final url = msg.mediaUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(color: Colors.grey.shade200),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Color _docColor(String ext) {
    switch (ext) {
      case 'PDF':
        return Colors.red.shade400;
      case 'DOC':
      case 'DOCX':
        return Colors.blue.shade400;
      case 'XLS':
      case 'XLSX':
        return Colors.green.shade400;
      case 'PPT':
      case 'PPTX':
        return Colors.orange.shade400;
      case 'ZIP':
      case 'RAR':
        return Colors.purple.shade400;
      default:
        return Colors.grey.shade500;
    }
  }

  Future<void> _openDoc(LocalMessage msg) async {
    String? path = (msg.localMediaPath != null &&
            File(msg.localMediaPath!).existsSync())
        ? msg.localMediaPath
        : null;

    if (path == null) {
      if (msg.mediaUrl == null) return;
      _showLoading();
      final chat = context.read<ChatProvider>();
      path = await chat.repository.mediaCache.ensureCached(msg.mediaUrl!);
      if (path != null && msg.msgID != 0) {
        await chat.repository.dao.setLocalMediaPath(msg.msgID, path);
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de télécharger le fichier'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Aucune app pour ouvrir ce fichier (${res.message})'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ── MEMBERS CARD ──────────────────────────────────────────────────────

class _MembersCard extends StatelessWidget {
  final List<User> participants;

  const _MembersCard({required this.participants});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '${participants.length} membres',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          ...participants.map((member) {
            final isYou = member.alanyaID ==
                context.read<AuthProvider>().currentUser?.alanyaID;
            final hasPhoto = hasValidAvatarUrl(member.avatarUrl);

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFCBD0E8),
                backgroundImage:
                    hasPhoto ? CachedNetworkImageProvider(member.avatarUrl) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        member.nom.isNotEmpty
                            ? member.nom[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
              title: Text(
                isYou ? 'Vous' : (member.nom.isNotEmpty ? member.nom : member.pseudo),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black,
                ),
              ),
              subtitle: (!isYou && member.isOnline)
                  ? const Text(
                      'En ligne',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContactDetailScreen(
                    userId: member.alanyaID,
                    initialName: member.nom,
                    initialAvatar: member.avatarUrl,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── DANGER CARD ───────────────────────────────────────────────────────

class _DangerCard extends StatelessWidget {
  final VoidCallback onLeave;
  const _DangerCard({required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onLeave,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.exit_to_app, color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 12),
              const Text(
                'Quitter le groupe',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
