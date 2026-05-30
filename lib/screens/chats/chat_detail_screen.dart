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
import '../../core/db/chat_dao.dart' show decodeParticipants;
import '../../core/services/call_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/profile_avatar.dart';
import '../calls/group_participants_picker_screen.dart';
import '../calls/ongoing_call_screen.dart';
import 'contact_detail_screen.dart';
import 'group_detail_screen.dart';
import 'media_viewer_screen.dart';
import 'voice_message_bubble.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final TalkyApiClient _apiClient;
  late final ChatProvider _chat;
  int? _myId;
  bool _partnerIsTyping = false;
  bool _hasText = false;
  bool _showEmoji = false;
  LocalMessage? _replyTo;
  final FocusNode _inputFocus = FocusNode();
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    _chat = Provider.of<ChatProvider>(context, listen: false);
    _myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID;
    _scrollController.addListener(_onScroll);
    _init();
  }

  bool _loadingOlder = false;
  bool _atBottom = true;
  bool _firstLoad = true;

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

    // 1. Synchronise l'historique depuis le serveur (l'UI affiche déjà le cache).
    _chat.repository.syncMessages(convId);

    // 2. Rejoint la room temps réel + marque comme lu. On signale aussi la
    //    conversation active : tout message reçu pendant qu'elle est ouverte
    //    sera marqué lu en direct (pas de badge non-lu fantôme).
    _apiClient.sendSocketEvent(SocketEvents.joinConversation, {'conversationID': convId});
    _chat.repository.setActiveConversation(convId);
    _chat.repository.markAsRead(convId);

    // 3. Écoute les indicateurs "en train d'écrire". On garde les références
    //    précises afin de pouvoir n'enlever QUE ces callbacks au dispose
    //    (sinon on évincerait aussi d'éventuels listeners globaux).
    _apiClient.onSocketEvent(SocketEvents.typingStarted, _onTypingStarted);
    _apiClient.onSocketEvent(SocketEvents.typingStopped, _onTypingStopped);
  }

  void _onTypingStarted(dynamic data) {
    if (!mounted) return;
    setState(() => _partnerIsTyping = true);
  }

  void _onTypingStopped(dynamic data) {
    if (!mounted) return;
    setState(() => _partnerIsTyping = false);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.conversationId == null || _myId == null) return;

    _chat.repository.sendText(
      conversationID: widget.conversationId!,
      content: text,
      replyToID: _replyTo?.msgID,
      replyToContent: _replyTo == null ? null : _previewOf(_replyTo!),
    );

    _messageController.clear();
    setState(() {
      _hasText = false;
      _replyTo = null;
    });
    _stopTyping();
    _scrollToBottom();
  }

  String _previewOf(LocalMessage m) {
    if (m.content != null && m.content!.isNotEmpty) return m.content!;
    return _mediaLabel(m.type);
  }

  // ── Menu contextuel sur un message (appui long) ────────────────────
  void _showMessageMenu(LocalMessage msg, bool isMe) {
    final isText = msg.type == 0;
    final primary = context.colors.primary;
    final error = context.colors.error;
    final muted = context.colors.onSurfaceVariant;
    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Si le message est en échec d'envoi, on propose en priorité le retry.
            if (isMe && msg.status == 4)
              ListTile(
                leading: Icon(Icons.refresh, color: primary),
                title: const Text('Réessayer l\'envoi'),
                onTap: () {
                  Navigator.pop(context);
                  _chat.repository.retryMessage(msg.clientId);
                },
              ),
            ListTile(
              leading: Icon(Icons.reply, color: primary),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = msg);
                _inputFocus.requestFocus();
              },
            ),
            if (isText && msg.content != null)
              ListTile(
                leading: Icon(Icons.copy, color: primary),
                title: const Text('Copier'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.content!));
                  Navigator.pop(context);
                },
              ),
            if (isMe && isText && !msg.isDeleted)
              ListTile(
                leading: Icon(Icons.edit, color: primary),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(msg);
                },
              ),
            if (isMe && !msg.isDeleted)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: const Text('Supprimer pour tout le monde'),
                onTap: () {
                  Navigator.pop(context);
                  if (msg.msgID != 0) _chat.repository.deleteMessage(msg.msgID, forAll: true);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: const Text('Supprimer pour moi'),
              onTap: () {
                Navigator.pop(context);
                if (msg.msgID != 0) _chat.repository.deleteMessage(msg.msgID, forAll: false);
              },
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  void _showEditDialog(LocalMessage msg) {
    final ctrl = TextEditingController(text: msg.content ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty && msg.msgID != 0) _chat.repository.editMessage(msg.msgID, t);
              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ── Médias ─────────────────────────────────────────────────────────
  void _showAttachSheet() {
    final sem = context.semantic;
    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _attachOption(Icons.photo_library, 'Galerie', sem.info, _pickImageFromGallery),
            _attachOption(Icons.camera_alt, 'Caméra', context.colors.primary, _pickImageFromCamera),
            _attachOption(Icons.videocam, 'Vidéo', context.colors.error, _pickVideo),
            _attachOption(Icons.insert_drive_file, 'Fichier', sem.warning, _pickFile),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 28, backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)),
            AppSpacing.vGapSm,
            Text(label, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImageFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null) _sendMediaFile(File(x.path), type: 1);
  }

  Future<void> _pickImageFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (x != null) _sendMediaFile(File(x.path), type: 1);
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    final file = File(x.path);
    // Extraction de la durée pour peupler `mediaDuration` (sinon les vidéos
    // arrivent côté serveur sans length → impossible d'afficher 00:23 dans
    // la liste des médias d'une conv ou dans la bulle).
    int? durSec;
    final ctrl = VideoPlayerController.file(file);
    try {
      await ctrl.initialize();
      durSec = ctrl.value.duration.inSeconds;
    } catch (e) {
      debugPrint('[ChatDetail] _pickVideo: durée non lue ($e)');
    } finally {
      await ctrl.dispose();
    }
    _sendMediaFile(file, type: 2, duration: durSec);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    final path = res?.files.single.path;
    if (path != null) _sendMediaFile(File(path), type: 4, name: res!.files.single.name);
  }

  // Limite alignée sur multer (50 Mo) côté backend.
  static const int _maxMediaBytes = 50 * 1024 * 1024;

  void _sendMediaFile(File file, {required int type, String? name, int? duration}) {
    if (widget.conversationId == null || _myId == null) return;

    final size = file.existsSync() ? file.lengthSync() : 0;
    if (size > _maxMediaBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Fichier trop volumineux ($mb Mo). Limite : 50 Mo.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    _chat.repository.sendMediaFile(
      conversationID: widget.conversationId!,
      type: type,
      file: file,
      mediaName: name,
      mediaDuration: duration,
    );
    _scrollToBottom();
  }

  // ── Messages vocaux ────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final seconds = _recordSeconds;
    if (mounted) setState(() => _isRecording = false);

    if (send && path != null && seconds >= 1) {
      _sendMediaFile(File(path), type: 3, name: 'Message vocal', duration: seconds);
    } else if (path != null) {
      // Annulé ou trop court → supprimer le fichier temporaire.
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  }

  void _onTextChanged(String value) {
    final has = value.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (widget.conversationId == null) return;
    if (value.isEmpty) {
      _stopTyping();
      return;
    }
    _apiClient.sendSocketEvent(SocketEvents.typingStart, {'conversationID': widget.conversationId});
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (widget.conversationId == null) return;
    _apiClient.sendSocketEvent(SocketEvents.typingStop, {'conversationID': widget.conversationId});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime sendAt) {
    final dt = sendAt.toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _initiateCall({required bool isVideo}) async {
    if (widget.isGroup) {
      await _initiateGroupCall(isVideo: isVideo);
      return;
    }
    if (widget.userId == null) return;
    final callService = Provider.of<CallService>(context, listen: false);
    final userData = await _apiClient.getMe();
    if (!mounted) return;
    final myId = userData['alanyaID'] ?? 0;
    await callService.initiateCall(
      targetUserId: widget.userId!,
      myId: myId,
      myName: userData['nom'] ?? userData['pseudo'] ?? '',
      myPhoto: userData['avatar_url'],
      targetUserName: widget.userName,
      isVideo: isVideo,
    );
    if (!mounted) return;
    if (callService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(callService.errorMessage!),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OngoingCallScreen()));
  }

  Future<void> _initiateGroupCall({required bool isVideo}) async {
    final convId = widget.conversationId;
    if (convId == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) return;

    final conversation = await _chat.repository.watchConversation(convId).first;
    if (!mounted || conversation == null || !conversation.isGroup) return;

    final parts = decodeParticipants(conversation.participantsJson);
    final others = parts
        .where((participant) => participant['alanyaID'].toString() != me.alanyaID.toString())
        .map((participant) => User.fromJson(Map<String, dynamic>.from(participant)))
        .toList();

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

    final callService = Provider.of<CallService>(context, listen: false);
    if (callService.status != CallStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un appel est déjà en cours')),
      );
      return;
    }

    final roster = targets
        .map((user) => GroupParticipantInfo(
              id: user.alanyaID.toString(),
              name: user.nom.isNotEmpty ? user.nom : user.pseudo,
              photo: user.avatarUrl,
            ))
        .toList();

    final roomId = 'group_${convId}_${DateTime.now().millisecondsSinceEpoch}';

    await callService.createGroupCall(
      roomId: roomId,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
      targetUserIds: targets.map((user) => user.alanyaID).toList(),
      isVideo: isVideo,
      targets: roster,
    );

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OngoingCallScreen()));
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    final convId = widget.conversationId;
    if (convId != null) _chat.repository.clearActiveConversation(convId);
    _stopTyping();
    // On retire UNIQUEMENT nos callbacks (les autres écrans/services restent
    // abonnés). offSocketEvent vidait l'event entier → régression critique.
    _apiClient.removeSocketListener(SocketEvents.typingStarted, _onTypingStarted);
    _apiClient.removeSocketListener(SocketEvents.typingStopped, _onTypingStopped);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild sur changement de présence (header).
    Provider.of<ChatProvider>(context);
    final convId = widget.conversationId;
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
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContactDetailScreen(
                            userId: widget.userId!,
                            conversationId: widget.conversationId,
                            initialName: widget.userName,
                            initialAvatar: widget.avatarUrl ?? '',
                          ),
                        ),
                      )
                  : null),
          child: Row(
            children: [
              ProfileAvatar(
                imageUrl: widget.avatarUrl,
                name: widget.userName,
                userId: widget.userId ?? 0,
                isGroup: widget.isGroup,
                conversationId: widget.conversationId,
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
                        return _buildGroupMembersLine();
                      }
                      final label = _partnerIsTyping ? 'en train d\'écrire...' : _presenceLabel();
                      if (label.isEmpty) return const SizedBox.shrink();
                      final online = !_partnerIsTyping && label == 'En ligne';
                      return Text(
                        label,
                        style: context.text.bodySmall?.copyWith(
                          color: _partnerIsTyping
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
      ),
      body: Column(
        children: [
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
                      if (messages.isEmpty) {
                        return const EmptyState(
                          icon: Icons.waving_hand_outlined,
                          title: 'Aucun message',
                          message: 'Dites bonjour pour démarrer la conversation !',
                        );
                      }
                      // Auto-scroll uniquement au 1er chargement ou si l'on
                      // est déjà en bas (évite de sauter en chargeant l'historique).
                      if (_firstLoad || _atBottom) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                          _firstLoad = false;
                        });
                      }
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: messages.length + (_partnerIsTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_partnerIsTyping && index == messages.length) {
                            return _buildTypingBubble();
                          }
                          final msg = messages[index];
                          final prev = index > 0 ? messages[index - 1] : null;
                          final showDate = prev == null ||
                              !_sameDay(prev.sendAt.toLocal(), msg.sendAt.toLocal());
                          return Column(
                            children: [
                              if (showDate) _buildDateSeparator(msg.sendAt.toLocal()),
                              _buildMessageBubble(msg, msg.senderID == _myId),
                            ],
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_replyTo != null) _buildReplyBanner(),
          _buildInputBar(),
          if (_showEmoji) _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 0),
      color: context.semantic.surfaceMuted,
      child: Row(
        children: [
          Container(width: 3, height: 36, color: colors.primary),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Réponse', style: context.text.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w700)),
                Text(
                  _previewOf(_replyTo!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            color: colors.onSurfaceVariant,
            onPressed: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 280,
      child: EmojiPicker(
        textEditingController: _messageController,
        onEmojiSelected: (category, emoji) {
          if (!_hasText) setState(() => _hasText = true);
        },
        config: const Config(height: 280),
      ),
    );
  }

  String _presenceLabel() {
    final uid = widget.userId;
    if (uid == null) return '';
    return _chat.presenceLabel(uid);
  }

  /// Sous-titre groupe : liste des noms des autres participants, séparés
  /// par des virgules. L'`overflow: ellipsis` du `Text` rajoute '…'
  /// automatiquement quand la ligne dépasse la largeur disponible.
  Widget _buildGroupMembersLine() {
    final convId = widget.conversationId;
    if (convId == null) return const SizedBox.shrink();
    return StreamBuilder<LocalConversation?>(
      stream: _chat.repository.watchConversation(convId),
      builder: (context, snap) {
        final conv = snap.data;
        if (conv == null) return const SizedBox.shrink();
        final parts = decodeParticipants(conv.participantsJson);
        final names = <String>[];
        for (final p in parts) {
          final id = p['alanyaID'];
          // Exclure soi-même (qu'il soit stocké en int ou en string).
          if (_myId != null && id.toString() == _myId.toString()) continue;
          final nom = (p['nom'] as String?)?.trim();
          if (nom != null && nom.isNotEmpty) names.add(nom);
        }
        if (names.isEmpty) return const SizedBox.shrink();
        return Text(
          names.join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall,
        );
      },
    );
  }

  Widget _buildMessageBubble(LocalMessage msg, bool isMe) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Show sender name in group chats for other people's messages
        if (widget.isGroup && !isMe)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.xs),
            child: Text(
              msg.senderNom ?? msg.senderPseudo ?? 'Unknown',
              style: context.text.labelSmall?.copyWith(color: context.colors.primary),
            ),
          ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showMessageMenu(msg, isMe),
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? context.colors.primary : context.colors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: isMe ? const Radius.circular(AppRadius.lg) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(AppRadius.lg),
                ),
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg.isStatusReply != 0)
                    _buildStatusReplyChip(isMe),
                  if (msg.replyToContent != null && msg.replyToContent!.isNotEmpty)
                    _buildReplyQuote(msg.replyToContent!, isMe),
                  if (msg.isDeleted)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block,
                            size: 14,
                            color: _bubbleMuted(isMe)),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Ce message a été supprimé',
                          style: context.text.bodyMedium?.copyWith(
                            color: _bubbleMuted(isMe),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    if (msg.type != 0) _buildMedia(msg, isMe),
                    if (msg.content != null && msg.content!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: msg.type != 0 ? 6 : 0),
                        child: Text(
                          msg.content!,
                          style: context.text.bodyLarge?.copyWith(color: _bubbleText(isMe)),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.sendAt),
                        style: context.text.labelSmall?.copyWith(
                          color: _bubbleMuted(isMe),
                          fontSize: 10,
                        ),
                      ),
                      if (msg.isEdited && !msg.isDeleted) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Tooltip(
                          message: msg.editedAt != null
                              ? 'Modifié à ${_formatTime(msg.editedAt!)}'
                              : 'Modifié',
                          child: Text(
                            '· modifié',
                            style: context.text.labelSmall?.copyWith(
                              color: _bubbleMuted(isMe),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      if (isMe && !msg.isDeleted) ...[
                        const SizedBox(width: 4),
                        _statusIcon(msg.status, deliveredAt: msg.deliveredAt, readAt: msg.readAt),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Couleur du texte principal dans une bulle (selon expéditeur).
  Color _bubbleText(bool isMe) =>
      isMe ? context.colors.onPrimary : context.colors.onSurface;

  /// Couleur du texte atténué dans une bulle (horodatage, mentions discrètes).
  Color _bubbleMuted(bool isMe) => isMe
      ? context.colors.onPrimary.withAlpha(180)
      : context.colors.onSurfaceVariant;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final yest = now.subtract(const Duration(days: 1));
    String label;
    if (_sameDay(date, now)) {
      label = "Aujourd'hui";
    } else if (_sameDay(date, yest)) {
      label = 'Hier';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md - 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: AppRadius.brSm,
      ),
      child: Text(label, style: context.text.labelSmall),
    );
  }

  Widget _buildReplyQuote(String content, bool isMe) {
    final accent = isMe ? context.colors.onPrimary : context.colors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withAlpha(30),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(
          color: _bubbleMuted(isMe),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ✓ envoyé · ✓✓ livré · ✓✓ bleu lu · horloge en attente · ! échec.
  // Tooltips remontent l'heure exacte via deliveredAt/readAt quand dispos.
  Widget _statusIcon(int status, {DateTime? deliveredAt, DateTime? readAt}) {
    Widget wrap(String tooltip, Widget child) =>
        Tooltip(message: tooltip, child: child);
    // Les accusés ne s'affichent que sur mes propres bulles (fond primary).
    final onBubble = context.colors.onPrimary.withAlpha(180);
    switch (status) {
      case 0:
        return wrap('En attente',
            Icon(Icons.schedule, size: 11, color: onBubble));
      case 1:
        return wrap('Envoyé',
            Icon(Icons.check, size: 12, color: onBubble));
      case 2:
        return wrap(
            deliveredAt != null
                ? 'Livré à ${_formatTime(deliveredAt)}'
                : 'Livré',
            Icon(Icons.done_all, size: 12, color: onBubble));
      case 3:
        return wrap(
            readAt != null ? 'Lu à ${_formatTime(readAt)}' : 'Lu',
            Icon(Icons.done_all, size: 12, color: context.semantic.info));
      case 4:
        return wrap('Échec — appui long pour réessayer',
            Icon(Icons.error_outline, size: 12, color: context.colors.error));
      default:
        return const SizedBox.shrink();
    }
  }

  // Chip "Réponse à un statut" affichée au sommet du bubble.
  Widget _buildStatusReplyChip(bool isMe) {
    final fg = isMe ? context.colors.onPrimary.withAlpha(200) : context.colors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_motion, size: 12, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Réponse à un statut',
            style: context.text.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Rendu média selon le type ──────────────────────────────────────
  Widget _buildMedia(LocalMessage msg, bool isMe) {
    switch (msg.type) {
      case 1:
        return _buildImageMedia(msg);
      case 2:
        return _buildVideoMedia(msg);
      case 3:
        return VoiceMessageBubble(
          localPath: msg.localMediaPath,
          networkUrl: msg.mediaUrl,
          durationSeconds: msg.mediaDuration ?? 0,
          isMe: isMe,
        );
      case 4:
        return _buildFileMedia(msg, isMe);
      default:
        return Text(_mediaLabel(msg.type),
            style: context.text.bodyLarge?.copyWith(color: _bubbleText(isMe)));
    }
  }

  bool _hasLocal(LocalMessage msg) =>
      msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();

  Future<void> _openViewer(LocalMessage msg, {required bool isVideo}) async {
    String? localPath =
        (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
            ? msg.localMediaPath
            : null;

    // Vidéo : télécharger en local d'abord (lecture fichier = plus fiable que
    // le streaming, et fonctionne ensuite hors-ligne).
    if (isVideo && localPath == null && msg.mediaUrl != null) {
      _showLoading();
      localPath = await _chat.repository.mediaCache.ensureCached(msg.mediaUrl!);
      if (localPath != null && msg.msgID != 0) {
        await _chat.repository.dao.setLocalMediaPath(msg.msgID, localPath);
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // ferme le loader
    }
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          isVideo: isVideo,
          localPath: localPath,
          networkUrl: msg.mediaUrl,
          title: msg.mediaName,
        ),
      ),
    );
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  // Télécharge si besoin puis ouvre le fichier avec l'app système (PDF, doc…).
  Future<void> _openFile(LocalMessage msg) async {
    String? path =
        (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
            ? msg.localMediaPath
            : null;

    if (path == null) {
      if (msg.mediaUrl == null) return;
      _showLoading();
      path = await _chat.repository.mediaCache.ensureCached(msg.mediaUrl!);
      if (path != null && msg.msgID != 0) {
        await _chat.repository.dao.setLocalMediaPath(msg.msgID, path);
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de télécharger le fichier'), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune application pour ouvrir ce fichier (${res.message})'), backgroundColor: AppColors.error),
      );
    }
  }

  Widget _buildImageMedia(LocalMessage msg) {
    final uploading = msg.status == 0;
    return GestureDetector(
      onTap: () => _openViewer(msg, isVideo: false),
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
              child: _hasLocal(msg)
                  ? Image.file(File(msg.localMediaPath!), fit: BoxFit.cover)
                  : CachedNetworkImage(
                      imageUrl: msg.mediaUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox(
                          height: 160, width: 200, child: Center(child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) =>
                          Icon(Icons.broken_image, size: 48, color: context.colors.onSurfaceVariant),
                    ),
            ),
            if (uploading) const CircularProgressIndicator(color: AppColors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMedia(LocalMessage msg) {
    final uploading = msg.status == 0;
    return GestureDetector(
      onTap: () => _openViewer(msg, isVideo: true),
      child: Container(
        height: 160,
        width: 240,
        decoration: const BoxDecoration(
          color: AppColors.immersiveBackground,
          borderRadius: AppRadius.brSm,
        ),
        child: Center(
          child: uploading
              ? const CircularProgressIndicator(color: AppColors.white)
              : Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(color: AppColors.white.withAlpha(50), shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: AppColors.white, size: 36),
                ),
        ),
      ),
    );
  }

  Widget _buildFileMedia(LocalMessage msg, bool isMe) {
    final color = isMe ? context.colors.onPrimary : context.colors.primary;
    return GestureDetector(
      onTap: msg.status == 0 ? null : () => _openFile(msg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(msg.status == 0 ? Icons.upload_file : Icons.insert_drive_file, color: color),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              msg.mediaName ?? 'Fichier',
              style: context.text.bodyLarge?.copyWith(
                color: _bubbleText(isMe),
                decoration: TextDecoration.underline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _mediaLabel(int type) {
    switch (type) {
      case 1:
        return '📷 Photo';
      case 2:
        return '🎥 Vidéo';
      case 3:
        return '🎵 Audio';
      case 4:
        return '📎 Fichier';
      default:
        return '';
    }
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
          boxShadow: AppShadows.subtle,
        ),
        child: Text('• • •',
            style: TextStyle(color: context.colors.onSurfaceVariant, fontSize: 16, letterSpacing: 4)),
      ),
    );
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _inputFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus(); // ferme le clavier système
      setState(() => _showEmoji = true);
    }
  }

  String _fmtRec(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _buildInputBar() {
    // Conteneur transparent : les bulles défilent en dessous pour donner
    // l'effet « flottant » WhatsApp. Le SafeArea pose la marge système.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, AppSpacing.sm, AppSpacing.sm),
        child: _isRecording ? _buildRecordingBar() : _buildComposeBar(),
      ),
    );
  }

  Widget _buildComposeBar() {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Capsule blanche flottante : emoji · TextField · pièce jointe.
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.brPill,
              boxShadow: AppShadows.medium,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    color: colors.onSurfaceVariant,
                    size: AppIconSize.md,
                  ),
                  onPressed: _toggleEmoji,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputFocus,
                    onChanged: _onTextChanged,
                    onTap: () {
                      if (_showEmoji) setState(() => _showEmoji = false);
                    },
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                    minLines: 1,
                    scrollPhysics: const ClampingScrollPhysics(),
                    style: context.text.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: context.text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md + 2),
                    ),
                  ),
                ),
                IconButton(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.attach_file, color: colors.onSurfaceVariant, size: AppIconSize.sm + 2),
                  onPressed: _showAttachSheet,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Bouton rond séparé : micro (champ vide) ou envoyer (champ rempli).
        _RoundActionButton(
          icon: _hasText ? Icons.send : Icons.mic,
          onTap: _hasText ? _sendMessage : _startRecording,
        ),
      ],
    );
  }

  Widget _buildRecordingBar() {
    final colors = context.colors;
    return Row(
      children: [
        // Capsule rouge flottante : annuler · timer · libellé.
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadius.brPill,
              boxShadow: AppShadows.medium,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.delete_outline, color: colors.error, size: AppIconSize.md),
                  onPressed: () => _stopRecording(send: false),
                ),
                const SizedBox(width: AppSpacing.sm),
                _RecordingDot(),
                const SizedBox(width: AppSpacing.sm + 2),
                Text(
                  _fmtRec(_recordSeconds),
                  style: context.text.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Enregistrement…',
                    style: context.text.bodySmall?.copyWith(color: colors.error),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _RoundActionButton(
          icon: Icons.send,
          onTap: () => _stopRecording(send: true),
        ),
      ],
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
