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
import '../../core/db/app_database.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../calls/ongoing_call_screen.dart';
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

    // 3. Écoute les indicateurs "en train d'écrire".
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.indigo),
              title: const Text('Répondre'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyTo = msg);
                _inputFocus.requestFocus();
              },
            ),
            if (isText && msg.content != null)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.indigo),
                title: const Text('Copier'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.content!));
                  Navigator.pop(context);
                },
              ),
            if (isMe && isText)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.indigo),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(msg);
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Supprimer pour tout le monde'),
                onTap: () {
                  Navigator.pop(context);
                  if (msg.msgID != 0) _chat.repository.deleteMessage(msg.msgID, forAll: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.black54),
              title: const Text('Supprimer pour moi'),
              onTap: () {
                Navigator.pop(context);
                if (msg.msgID != 0) _chat.repository.deleteMessage(msg.msgID, forAll: false);
              },
            ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _attachOption(Icons.photo_library, 'Galerie', Colors.purple, _pickImageFromGallery),
              _attachOption(Icons.camera_alt, 'Caméra', Colors.indigo, _pickImageFromCamera),
              _attachOption(Icons.videocam, 'Vidéo', Colors.red, _pickVideo),
              _attachOption(Icons.insert_drive_file, 'Fichier', Colors.orange, _pickFile),
            ],
          ),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 28, backgroundColor: color.withAlpha(30), child: Icon(icon, color: color)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
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
    if (x != null) _sendMediaFile(File(x.path), type: 2);
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
        backgroundColor: Colors.red,
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
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ));
      return;
    }
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
    _apiClient.offSocketEvent(SocketEvents.typingStarted);
    _apiClient.offSocketEvent(SocketEvents.typingStopped);
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo.shade100,
              backgroundImage:
                  (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                      ? CachedNetworkImageProvider(widget.avatarUrl!)
                      : null,
              child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
                  ? (widget.isGroup
                      ? const Icon(Icons.group, color: Colors.indigo, size: 20)
                      : Text(
                          widget.userName.isNotEmpty
                              ? widget.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Builder(builder: (_) {
                    final label = _partnerIsTyping ? 'en train d\'écrire...' : _presenceLabel();
                    if (label.isEmpty) return const SizedBox.shrink();
                    final online = !_partnerIsTyping && label == 'En ligne';
                    return Text(
                      label,
                      style: TextStyle(
                        color: _partnerIsTyping
                            ? Colors.indigo
                            : (online ? Colors.green : Colors.black45),
                        fontSize: 12,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam, color: Colors.indigo), onPressed: () => _initiateCall(isVideo: true)),
          IconButton(icon: const Icon(Icons.call, color: Colors.indigo), onPressed: () => _initiateCall(isVideo: false)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: convId == null
                ? const Center(child: Text('Conversation introuvable', style: TextStyle(color: Colors.black45)))
                : StreamBuilder<List<LocalMessage>>(
                    stream: _chat.watchMessages(convId),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? const [];
                      if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                        return const Center(child: CircularProgressIndicator(color: Colors.indigo));
                      }
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text('Aucun message. Dites bonjour !', style: TextStyle(color: Colors.black45)),
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
                        padding: const EdgeInsets.all(16),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Container(width: 3, height: 36, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Réponse', style: TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  _previewOf(_replyTo!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black45),
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

  Widget _buildMessageBubble(LocalMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(msg, isMe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? Colors.indigo : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.replyToContent != null && msg.replyToContent!.isNotEmpty)
                _buildReplyQuote(msg.replyToContent!, isMe),
              if (msg.type != 0) _buildMedia(msg, isMe),
              if (msg.content != null && msg.content!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: msg.type != 0 ? 6 : 0),
                  child: Text(
                    msg.content!,
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.sendAt),
                    style: TextStyle(color: isMe ? Colors.white70 : Colors.black45, fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _statusIcon(msg.status),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
    );
  }

  Widget _buildReplyQuote(String content, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isMe ? Colors.white : Colors.indigo).withAlpha(30),
        border: Border(left: BorderSide(color: isMe ? Colors.white : Colors.indigo, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isMe ? Colors.white70 : Colors.black54,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ✓ envoyé · ✓✓ livré · ✓✓ bleu lu · horloge en attente · ! échec
  Widget _statusIcon(int status) {
    switch (status) {
      case 0:
        return const Icon(Icons.schedule, size: 11, color: Colors.white70);
      case 1:
        return const Icon(Icons.check, size: 12, color: Colors.white70);
      case 2:
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
      case 3:
        return const Icon(Icons.done_all, size: 12, color: Color(0xFF4FC3F7));
      case 4:
        return const Icon(Icons.error_outline, size: 12, color: Colors.redAccent);
      default:
        return const SizedBox.shrink();
    }
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
            style: TextStyle(color: isMe ? Colors.white : Colors.black87));
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
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
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
          const SnackBar(content: Text('Impossible de télécharger le fichier'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune app pour ouvrir ce fichier (${res.message})'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildImageMedia(LocalMessage msg) {
    final uploading = msg.status == 0;
    return GestureDetector(
      onTap: () => _openViewer(msg, isVideo: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
                          const Icon(Icons.broken_image, size: 48, color: Colors.white70),
                    ),
            ),
            if (uploading) const CircularProgressIndicator(color: Colors.white),
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
        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: uploading
              ? const CircularProgressIndicator(color: Colors.white)
              : Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
        ),
      ),
    );
  }

  Widget _buildFileMedia(LocalMessage msg, bool isMe) {
    final color = isMe ? Colors.white : Colors.indigo;
    return GestureDetector(
      onTap: msg.status == 0 ? null : () => _openFile(msg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(msg.status == 0 ? Icons.upload_file : Icons.insert_drive_file, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              msg.mediaName ?? 'Fichier',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 5, offset: const Offset(0, 2)),
          ],
        ),
        child: const Text('• • •', style: TextStyle(color: Colors.black45, fontSize: 16, letterSpacing: 4)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: _isRecording ? _buildRecordingBar() : _buildComposeBar(),
      ),
    );
  }

  Widget _buildComposeBar() {
    return Row(
      children: [
        IconButton(
          icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.grey),
          onPressed: _toggleEmoji,
        ),
        IconButton(
          icon: const Icon(Icons.attach_file, color: Colors.grey),
          onPressed: _showAttachSheet,
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
            decoration: InputDecoration(
              hintText: 'Type a message...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Champ vide → micro (tap pour démarrer) ; sinon → envoyer.
        Container(
          decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
          child: IconButton(
            icon: Icon(_hasText ? Icons.send : Icons.mic, color: Colors.white, size: 22),
            onPressed: _hasText ? _sendMessage : _startRecording,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        // Annuler
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 26),
          onPressed: () => _stopRecording(send: false),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _RecordingDot(),
                const SizedBox(width: 10),
                Text(
                  _fmtRec(_recordSeconds),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Text('Enregistrement…', style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Envoyer
        Container(
          decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.send, color: Colors.white, size: 22),
            onPressed: () => _stopRecording(send: true),
          ),
        ),
      ],
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
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }
}
