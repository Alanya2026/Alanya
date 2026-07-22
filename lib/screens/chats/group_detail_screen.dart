import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import '../../core/utils/document_file_style.dart';
import '../../core/db/app_database.dart';
import '../../widgets/common/common.dart';
import '../../widgets/image_message_preview.dart';
import '../../widgets/video_message_preview.dart';
import '../calls/group_participants_picker_screen.dart';
import '../meetings/participant_picker_screen.dart';
import 'contact_detail_screen.dart';
import 'conversation_media_screen.dart';
import 'media_viewer_screen.dart';
import '../../widgets/conversation_mute_sheet.dart';

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

  // Conservé pour réactivation des appels de groupe.
  // ignore: unused_element
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
        SnackBar(content: Text(context.l10n.noOtherMembersToCall)),
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
        SnackBar(content: Text(context.l10n.aCallIsAlreadyInProgress)),
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
    final errorColor = context.colors.error;
    final api = Provider.of<TalkyApiClient>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    final excludeIds =
        _group!.participants.map((u) => u.alanyaID).toSet();

    final picked = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantPickerScreen(
          confirmLabel: context.l10n.add,
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
        content: Text(context.l10n.participantsAdded(picked.length)),
      ));
    } catch (e, st) {
      AppLog.e('GroupDetail', context.l10n.failedToAddParticipants, e, st);
      messenger.showSnackBar(SnackBar(
        content: Text(context.l10n.unableToAddParticipantsTryAgain),
        backgroundColor: errorColor,
      ));
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.leaveGroup),
        content: Text(
            context.l10n.youWillNoLongerSeeThis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.leave,
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
      AppLog.e('GroupDetail', context.l10n.failedToLeaveGroup, e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.unableToLeaveTheGroupTry),
              backgroundColor: context.colors.error),
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
        title: Text(context.l10n.groupInfo),
        // Appels de groupe audio/vidéo — masqués temporairement, à remettre plus tard.
        // actions: _group == null
        //     ? null
        //     : [
        //         IconButton(
        //           icon: const Icon(Icons.videocam_outlined),
        //           tooltip: context.l10n.videoCall,
        //           onPressed: () => _startGroupCall(true),
        //         ),
        //         IconButton(
        //           icon: const Icon(Icons.call_outlined),
        //           tooltip: context.l10n.voiceCall,
        //           onPressed: () => _startGroupCall(false),
        //         ),
        //       ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _group == null
              ? EmptyState(
                  icon: Icons.group_off,
                  title: context.l10n.groupNotFound,
                  message: context.l10n.thisGroupIsNoLongerAccessible,
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
                    _Card(
                      padding: EdgeInsets.zero,
                      child: ConversationMuteListTile(
                        conversationId: widget.conversationId,
                        conversationName: widget.groupName,
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        // En sombre, `surface` est plus foncé que `surfaceMuted` (fond page) :
        // on élève la carte pour garder le contraste carte / fond.
        color: isDark
            ? context.colors.surfaceContainerHigh
            : context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: isDark ? null : AppShadows.subtle,
        border: isDark
            ? Border.all(color: context.colors.outline.withValues(alpha: 0.55))
            : null,
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
            context.l10n.groupMembersCount(memberCount),
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
  StreamSubscription<List<LocalMessage>>? _messagesSub;
  List<LocalMessage> _mediaMessages = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }

  void _init() {
    final chat = context.read<ChatProvider>();
    // Local-first : Drift immédiat, sync réseau en fond.
    _messagesSub =
        chat.watchMessages(widget.conversationId).listen(_onMessages);
    unawaited(chat.repository.syncMessages(widget.conversationId));
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
                  context.l10n.mediaLinksAndDocs,
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
                        context.l10n.seeAll,
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
                      context.l10n.noSharedMedia,
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
      final style = DocumentFileStyle.fromMessage(
        mediaName: msg.mediaName,
        mediaUrl: msg.mediaUrl,
      );
      return Container(
        color: placeholder,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.color,
              borderRadius: AppRadius.brSm,
            ),
            child: Center(
              child: Text(
                style.extension,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    }
    if (msg.type == 2) {
      return VideoMessagePreview(
        pendingPath: msg.pendingUploadPath,
        localPath: msg.localMediaPath,
        thumbBase64: msg.mediaThumb,
        durationSeconds: msg.mediaDuration,
        borderRadius: BorderRadius.zero,
        expandToFill: true,
        playIconSize: 22,
        playPadding: 5,
        showDuration: false,
        fallbackColor: placeholder,
      );
    }

    final hasLocal = msg.localMediaPath != null &&
        File(msg.localMediaPath!).existsSync();
    final myId = context.read<ChatProvider>().repository.myId;
    final needsDl = !msg.isViewOnce &&
        msg.senderID != myId &&
        !hasLocal &&
        msg.mediaUrl != null &&
        msg.mediaUrl!.isNotEmpty;

    return ImageMessagePreview(
      localPath: msg.localMediaPath,
      networkUrl: msg.mediaUrl,
      thumbBase64: msg.mediaThumb,
      useBlurredThumb: needsDl,
      borderRadius: BorderRadius.zero,
      expandToFill: true,
      fallbackColor: placeholder,
    );
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
      final isMine = msg.senderID == chat.repository.myId;
      path = await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl!,
        type: msg.type,
        isMine: isMine,
        isViewOnce: msg.isViewOnce,
        mediaName: msg.mediaName,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } else if (!msg.isViewOnce && msg.msgID != 0) {
      final chat = context.read<ChatProvider>();
      final isMine = msg.senderID == chat.repository.myId;
      await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl ?? '',
        type: msg.type,
        isMine: isMine,
        isViewOnce: false,
        mediaName: msg.mediaName,
        existingLocalPath: path,
      );
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.unableToDownloadTheFile),
              backgroundColor: context.colors.error),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.l10n.cannotOpenFileApp(res.message)),
          backgroundColor: context.colors.error,
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
              context.l10n.membersOnlyCount(participants.length),
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
                context.l10n.addParticipants,
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
                    ? context.l10n.youLabel
                    : (member.nom.isNotEmpty ? member.nom : member.pseudo),
                style: context.text.titleSmall,
              ),
              subtitle: (!isYou && member.isOnline)
                  ? Text(
                      context.l10n.online,
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
                context.l10n.leaveGroup2,
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
