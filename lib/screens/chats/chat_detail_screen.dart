import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../../core/db/app_database.dart';
import '../../core/call_limits.dart';
import '../../core/db/chat_dao.dart' show decodeParticipants;
import '../../core/services/call_service.dart';
import '../../core/services/chat_repository.dart';
import '../../core/utils/forward_message.dart';
import '../../core/utils/media_album.dart';
import '../../core/utils/media_viewer_items.dart';
import '../../core/utils/rich_text_parser.dart';
import 'package:screen_protector/screen_protector.dart';
import 'view_once_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/typing_indicator.dart';
import '../calls/group_participants_picker_screen.dart';
import 'contact_detail_screen.dart';
import 'group_detail_screen.dart';
import 'forward_message_screen.dart';
import 'album_media_list_screen.dart';
import 'media_viewer_screen.dart';
import 'voice_message_bubble.dart';

// Écran réparti par responsabilité (même librairie / membres privés partagés) :
part 'chat/chat_actions.dart';  // handlers : envoi, médias, vocal, appels
part 'chat/chat_bubbles.dart';  // rendu des bulles & médias
part 'chat/chat_input.dart';    // barre de saisie, emoji, bandeau réponse

// Limite alignée sur multer (50 Mo) côté backend.
const int _maxMediaBytes = 50 * 1024 * 1024;
const Duration _messageEditWindow = Duration(minutes: 30);

class ChatDetailScreen extends StatefulWidget {
  final String userName;
  final int? conversationId;
  final int? userId;
  final bool isGroup;
  final String? avatarUrl;
  const ChatDetailScreen({
    super.key,
    required this.userName,
    this.conversationId,
    this.userId,
    this.isGroup = false,
    this.avatarUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = RichTextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final TalkyApiClient _apiClient;
  late final ChatProvider _chat;
  int? _myId;
  bool _hasText = false;
  bool _showEmoji = false;
  bool _showFormatBar = false;
  bool _pendingViewOnce = false;
  bool _voiceViewOnce = false;
  int _pinnedIndex = 0;
  LocalMessage? _replyTo;
  final FocusNode _inputFocus = FocusNode();
  Timer? _typingTimer;

  bool _loadingOlder = false;
  bool _atBottom = true;
  bool _firstLoad = true;
  bool _suppressAutoScroll = false;
  int? _highlightMsgId;
  int? _pendingScrollMsgId;
  Timer? _highlightTimer;
  final Map<int, GlobalKey> _messageKeys = {};

  final ImagePicker _picker = ImagePicker();

  // ── Messages vocaux ────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  bool _isBlocked = false;
  bool _blockedByThem = false;

  /// Pont public vers `setState()` (lui-même `@protected`), afin que les
  /// extensions de cette librairie puissent déclencher un rebuild.
  void rebuild(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    _chat = Provider.of<ChatProvider>(context, listen: false);
    _myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID;
    _scrollController.addListener(_onScroll);
    _init();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    _atBottom = pos.pixels >= pos.maxScrollExtent - 150;

    // Près du haut → charger une page d'anciens messages.
    if (pos.pixels <= 80 && !_loadingOlder) {
      final convId = widget.conversationId;
      if (convId == null) return;
      _loadingOlder = true;
      _chat.repository.loadOlderMessages(convId).whenComplete(() {
        if (mounted) _loadingOlder = false;
      });
    }
  }

  Future<void> _init() async {
    final convId = widget.conversationId;
    if (convId == null) return;

    if (!widget.isGroup && widget.userId != null) {
      await _loadBlockStatus();
    }

    // 1. Synchronise l'historique depuis le serveur (l'UI affiche déjà le cache).
    _chat.repository.syncMessages(convId);

    // 2. Rejoint la room temps réel + marque comme lu. On signale aussi la
    //    conversation active : tout message reçu pendant qu'elle est ouverte
    //    sera marqué lu en direct (pas de badge non-lu fantôme).
    _apiClient.sendSocketEvent(SocketEvents.joinConversation, {'conversationID': convId});
    _chat.repository.setActiveConversation(convId);
    _chat.repository.markAsRead(convId);
  }

  Future<void> _loadBlockStatus() async {
    final userId = widget.userId;
    if (userId == null) return;
    try {
      final status = await _apiClient.getBlockStatus(userId);
      if (!mounted) return;
      setState(() {
        _isBlocked = status.isBlocked;
        _blockedByThem = status.blockedByThem;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _unblockContact() async {
    final userId = widget.userId;
    if (userId == null) return;
    try {
      await _apiClient.unblockUser(userId);
      if (!mounted) return;
      setState(() {
        _isBlocked = false;
        _blockedByThem = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact débloqué')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de débloquer : $e')),
      );
    }
  }

  bool get _callsDisabled =>
      !widget.isGroup && (_isBlocked || _blockedByThem);

  bool get _inputBlocked => !widget.isGroup && _isBlocked;

  GlobalKey _keyForMessage(int msgID) =>
      _messageKeys.putIfAbsent(msgID, GlobalKey.new);

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _highlightTimer?.cancel();
    _recorder.dispose();
    final convId = widget.conversationId;
    if (convId != null) _chat.repository.clearActiveConversation(convId);
    _stopTyping();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild sur changement de présence / typing (header + bulle).
    final chat = Provider.of<ChatProvider>(context);
    final convId = widget.conversationId;
    final partnerTyping = convId != null &&
        chat.isPartnerTyping(
          convId,
          partnerUserId: widget.isGroup ? null : widget.userId,
        );
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: InkWell(
          onTap: widget.isGroup
              ? (widget.conversationId != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(
                            conversationId: widget.conversationId!,
                            groupName: widget.userName,
                            groupAvatar: widget.avatarUrl,
                          ),
                        ),
                      )
                  : null)
              : (widget.userId != null
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContactDetailScreen(
                            userId: widget.userId!,
                            conversationId: widget.conversationId,
                            initialName: widget.userName,
                            initialAvatar: widget.avatarUrl ?? '',
                          ),
                        ),
                      );
                      if (mounted) _loadBlockStatus();
                    }
                  : null),
          child: Row(
            children: [
              ProfileAvatar(
                imageUrl: widget.avatarUrl,
                name: widget.userName,
                userId: widget.userId ?? 0,
                isGroup: widget.isGroup,
                conversationId: widget.conversationId,
                hidePhoto: !widget.isGroup && _blockedByThem,
                size: 40,
                borderRadius: 20,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.userName,
                      style: context.text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Builder(builder: (_) {
                      // Groupes : on n'affiche jamais une présence (ça n'a pas
                      // de sens pour N membres). On liste les noms des autres
                      // participants avec ellipsis automatique si ça déborde.
                      if (widget.isGroup) {
                        if (partnerTyping) {
                          return Text(
                            'En train d\'écrire…',
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.primary,
                            ),
                          );
                        }
                        return _buildGroupMembersLine();
                      }
                      final label = partnerTyping ? 'en train d\'écrire…' : _presenceLabel();
                      if (label.isEmpty) return const SizedBox.shrink();
                      final online = !partnerTyping && label == 'En ligne';
                      return Text(
                        label,
                        style: context.text.bodySmall?.copyWith(
                          color: partnerTyping
                              ? context.colors.primary
                              : (online ? context.semantic.online : context.colors.onSurfaceVariant),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!_callsDisabled) ...[
            IconButton(
              icon: const Icon(Icons.videocam_rounded),
              color: context.colors.primary,
              onPressed: () => _initiateCall(isVideo: true),
            ),
            IconButton(
              icon: const Icon(Icons.call_rounded),
              color: context.colors.primary,
              onPressed: () => _initiateCall(isVideo: false),
            ),
            AppSpacing.hGapSm,
          ],
        ],
      ),
      body: Column(
        children: [
          _buildPinnedBanner(),
          Expanded(
            child: convId == null
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Conversation introuvable',
                  )
                : StreamBuilder<List<LocalMessage>>(
                    stream: _chat.watchMessages(convId),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const [];
                      if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                        return const LoadingState();
                      }
                      if (messages.isEmpty && !partnerTyping) {
                        return const EmptyState(
                          icon: Icons.waving_hand_outlined,
                          title: 'Aucun message',
                          message: 'Dites bonjour pour démarrer la conversation !',
                        );
                      }
                      // Auto-scroll au 1er chargement, si déjà en bas, ou quand
                      // l'indicateur de frappe apparaît.
                      if (!_suppressAutoScroll && (_firstLoad || _atBottom)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                          _firstLoad = false;
                        });
                      }
                      final displayItems = groupMessagesForDisplay(messages);
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: displayItems.length + 1,
                        itemBuilder: (context, index) {
                          if (index == displayItems.length) {
                            return TypingBubbleSlot(visible: partnerTyping);
                          }
                          final item = displayItems[index];
                          final msg = switch (item) {
                            ChatListSingle(:final message) => message,
                            ChatListAlbum(:final messages) => messages.last,
                          };
                          final prev = index > 0
                              ? switch (displayItems[index - 1]) {
                                  ChatListSingle(:final message) => message,
                                  ChatListAlbum(:final messages) => messages.last,
                                }
                              : null;
                          final showDate = prev == null ||
                              !_sameDay(prev.sendAt.toLocal(), msg.sendAt.toLocal());
                          if (msg.msgID == _pendingScrollMsgId) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _tryRevealMessage(msg.msgID);
                            });
                          }
                          return Column(
                            key: msg.msgID != 0 ? _keyForMessage(msg.msgID) : null,
                            children: [
                              if (showDate) _buildDateSeparator(msg.sendAt.toLocal()),
                              switch (item) {
                                ChatListSingle(:final message) =>
                                  _buildMessageBubble(message, message.senderID == _myId),
                                ChatListAlbum(:final messages) =>
                                  _buildAlbumBubble(messages, messages.first.senderID == _myId),
                              },
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_replyTo != null) _buildReplyBanner(),
          if (_inputBlocked) _buildBlockedBanner(),
          if (_showFormatBar && !_inputBlocked) _buildFormatBar(),
          _buildInputBar(),
          if (_showEmoji) _buildEmojiPicker(),
        ],
      ),
    );
  }
}

/// Bouton circulaire indigo en relief (50 px) — utilisé pour mic / send.
class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.primary,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: context.colors.onPrimary, size: AppIconSize.sm + 2),
        ),
      ),
    );
  }
}

/// Pastille rouge qui pulse pendant l'enregistrement.
class _RecordingDot extends StatefulWidget {
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
      ),
    );
  }
}
