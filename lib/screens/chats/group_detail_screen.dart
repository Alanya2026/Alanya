import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_log.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/call_service.dart';
import '../../core/call_limits.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';
import '../../core/db/app_database.dart';
import '../../widgets/common/common.dart';
import '../calls/group_participants_picker_screen.dart';
import '../meetings/participant_picker_screen.dart';
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
      final conversations =
          await chat.repository.watchConversations().first;
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
      final data =
          (jsonDecode(json) as List?)?.cast<Map<String, dynamic>>() ?? [];
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
    final maxOthers = CallLimits.maxSelectable(isVideo: isVideo);
    if (others.length <= maxOthers) {
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
    await cs.navigateToCallUi(context);
  }

  Future<void> _addParticipants() async {
    if (_group == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final api = Provider.of<TalkyApiClient>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    final excludeIds =
        _group!.participants.map((u) => u.alanyaID).toSet();

    final picked = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantPickerScreen(
          confirmLabel: 'Ajouter',
          excludeIds: excludeIds,
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    try {
      await api.addParticipants(
        widget.conversationId,
        picked.map((u) => u.alanyaID).toList(),
      );
      await chat.refreshConversations();
      if (!mounted) return;
      await _loadGroup();
      messenger.showSnackBar(SnackBar(
        content: Text('${picked.length} participant(s) ajouté(s)'),
      ));
    } catch (e, st) {
      AppLog.e('GroupDetail', 'Ajout de participants échoué', e, st);
      messenger.showSnackBar(const SnackBar(
        content: Text('Impossible d\'ajouter les participants, réessayez'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: const Text(
            'Vous ne verrez plus ce groupe dans votre liste de discussions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Quitter',
                style: TextStyle(color: context.colors.error)),
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
    } catch (e, st) {
      AppLog.e('GroupDetail', 'Quitter le groupe échoué', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Impossible de quitter le groupe, réessayez'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        centerTitle: true,
        title: const Text('Infos du groupe'),
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
          ? const LoadingState()
          : _group == null
              ? EmptyState(
                  icon: Icons.group_off,
                  title: 'Groupe introuvable',
                  message: 'Ce groupe n\'est plus accessible.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                  children: [
                    _Header(
                      groupName: widget.groupName,
                      groupAvatar: widget.groupAvatar,
                      groupPhoto: _group!.groupPhoto,
                      memberCount: _group!.participants.length,
                    ),
                    AppSpacing.vGapLg,
                    _MediaCard(
                      conversationId: widget.conversationId,
                      conversationName: widget.groupName,
                    ),
                    AppSpacing.vGapLg,
                    _MembersCard(
                      participants: _group?.participants ?? [],
                      onAddParticipants: _addParticipants,
                    ),
                    AppSpacing.vGapLg,
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
  const _Card(
      {required this.child,
      this.padding = const EdgeInsets.all(AppSpacing.lg)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: AppShadows.subtle,
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

    return _Card(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxxl, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          AppAvatar(
            imageUrl: avatarUrl?.isNotEmpty == true ? avatarUrl : null,
            name: groupName,
            isGroup: true,
            size: 120,
          ),
          AppSpacing.vGapLg,
          Text(
            groupName,
            style: context.text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          AppSpacing.vGapSm,
          Text(
            'Groupe • $memberCount membres',
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
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
              Expanded(
                child: Text(
                  'Médias, liens et docs',
                  style: context.text.titleSmall,
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
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Row(
                    children: [
                      Text(
                        'Voir tout',
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: context.colors.primary, size: AppIconSize.sm),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vGapLg,
          _mediaMessages.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'Aucun média partagé',
                      style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant),
                    ),
                  ),
                )
              : SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaMessages.length,
                    separatorBuilder: (_, __) => AppSpacing.hGapSm,
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
                          borderRadius: AppRadius.brSm,
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
    final placeholder = context.colors.surfaceContainerHighest;
    if (msg.type == 4) {
      final name = msg.mediaName ?? 'Document';
      final ext =
          name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
      return Container(
        color: placeholder,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _docColor(ext),
              borderRadius: AppRadius.brSm,
            ),
            child: Center(
              child: Text(
                ext,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    }
    if (msg.type == 2) return Container(color: placeholder);

    final hasLocal = msg.localMediaPath != null &&
        File(msg.localMediaPath!).existsSync();
    if (hasLocal) {
      return Image.file(File(msg.localMediaPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: placeholder));
    }
    final url = msg.mediaUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: placeholder),
        errorWidget: (context, url, error) => Container(color: placeholder),
      );
    }
    return Container(color: placeholder);
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
              backgroundColor: AppColors.error),
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
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
          child: CircularProgressIndicator(color: context.colors.primary)),
    );
  }
}

// ── MEMBERS CARD ──────────────────────────────────────────────────────

class _MembersCard extends StatelessWidget {
  final List<User> participants;
  final VoidCallback? onAddParticipants;

  const _MembersCard({
    required this.participants,
    this.onAddParticipants,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg, AppSpacing.xs),
            child: Text(
              '${participants.length} membres',
              style: context.text.titleSmall,
            ),
          ),
          if (onAddParticipants != null)
            ListTile(
              leading: Container(
                width: AppSizes.avatarMd,
                height: AppSizes.avatarMd,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add_alt_1,
                    color: context.colors.primary),
              ),
              title: Text(
                'Ajouter des participants',
                style: context.text.titleSmall
                    ?.copyWith(color: context.colors.primary),
              ),
              onTap: onAddParticipants,
            ),
          ...participants.map((member) {
            final isYou = member.alanyaID ==
                context.read<AuthProvider>().currentUser?.alanyaID;

            return ListTile(
              leading: AppAvatar(
                imageUrl: hasValidAvatarUrl(member.avatarUrl)
                    ? member.avatarUrl
                    : null,
                name: member.nom.isNotEmpty ? member.nom : member.pseudo,
                size: AppSizes.avatarMd,
              ),
              title: Text(
                isYou
                    ? 'Vous'
                    : (member.nom.isNotEmpty ? member.nom : member.pseudo),
                style: context.text.titleSmall,
              ),
              subtitle: (!isYou && member.isOnline)
                  ? Text(
                      'En ligne',
                      style: context.text.bodySmall?.copyWith(
                          color: context.semantic.online),
                    )
                  : null,
              trailing: Icon(Icons.chevron_right,
                  color: context.colors.outlineVariant),
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
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg + 2),
          child: Row(
            children: [
              Icon(Icons.exit_to_app,
                  color: context.colors.error, size: AppIconSize.md),
              AppSpacing.hGapMd,
              Text(
                'Quitter le groupe',
                style: context.text.bodyLarge?.copyWith(
                  color: context.colors.error,
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
