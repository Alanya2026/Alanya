import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../calls/ongoing_call_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String userName;
  final int? conversationId;
  final int? userId;
  const ChatDetailScreen({
    super.key,
    required this.userName,
    this.conversationId,
    this.userId,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final TalkyApiClient _apiClient;
  int? _myId;
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _partnerIsTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    _myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID;
    _init();
  }

  Future<void> _init() async {
    if (widget.conversationId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final raw = await _apiClient.getMessages(widget.conversationId!);
      if (!mounted) return;
      setState(() {
        _messages = raw
            .whereType<Map<String, dynamic>>()
            .map(Message.fromJson)
            .toList();
        _isLoading = false;
      });
      _scrollToBottom();

      _apiClient.sendSocketEvent(SocketEvents.joinConversation, {
        'conversationID': widget.conversationId,
      });
      _apiClient.markConversationAsRead(widget.conversationId!).ignore();

      _apiClient.onSocketEvent(SocketEvents.messageReceived, _onMessageReceived);
      _apiClient.onSocketEvent(SocketEvents.messageSent, _onMessageSent);
      _apiClient.onSocketEvent(SocketEvents.typingStarted, _onTypingStarted);
      _apiClient.onSocketEvent(SocketEvents.typingStopped, _onTypingStopped);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur chargement: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _onMessageReceived(dynamic data) {
    if (data is! Map) return;
    final msg = Message.fromJson(Map<String, dynamic>.from(data));
    if (msg.conversationID != widget.conversationId) return;
    if (msg.senderID == _myId) return; // affiché en optimiste
    if (!mounted) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _onMessageSent(dynamic data) {
    if (data is! Map || !mounted) return;
    final realId = data['msgID'];
    final realMsgID = realId is int ? realId : int.tryParse(realId.toString()) ?? 0;
    if (realMsgID == 0) return;
    setState(() {
      final idx = _messages.lastIndexWhere((m) => m.msgID == 0 && m.senderID == _myId);
      if (idx != -1) {
        final old = _messages[idx];
        _messages[idx] = Message(
          msgID: realMsgID,
          senderID: old.senderID,
          conversationID: old.conversationID,
          content: old.content,
          type: old.type,
          status: 1,
          sendAt: old.sendAt,
          isEdited: false,
          isDeleted: false,
          isStatusReply: 0,
        );
      }
    });
  }

  // Le backend envoie typing:started sans conversationID dans le payload,
  // on affiche donc l'indicateur dès qu'un partenaire tape dans cette room.
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

    _apiClient.sendSocketEvent(SocketEvents.messageSend, {
      'conversationID': widget.conversationId,
      'content': text,
      'type': 0,
    });

    setState(() {
      _messages.add(Message(
        msgID: 0,
        senderID: _myId!,
        conversationID: widget.conversationId!,
        content: text,
        type: 0,
        status: 1,
        sendAt: DateTime.now().toIso8601String(),
        isEdited: false,
        isDeleted: false,
        isStatusReply: 0,
      ));
    });

    _messageController.clear();
    _stopTyping();
    _scrollToBottom();
  }

  void _onTextChanged(String value) {
    if (widget.conversationId == null) return;
    if (value.isEmpty) {
      _stopTyping();
      return;
    }
    _apiClient.sendSocketEvent(SocketEvents.typingStart, {
      'conversationID': widget.conversationId,
    });
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (widget.conversationId == null) return;
    _apiClient.sendSocketEvent(SocketEvents.typingStop, {
      'conversationID': widget.conversationId,
    });
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

  String _formatTime(String sendAt) {
    try {
      final dt = DateTime.parse(sendAt).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
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
    _stopTyping();
    _apiClient.offSocketEvent(SocketEvents.messageReceived);
    _apiClient.offSocketEvent(SocketEvents.messageSent);
    _apiClient.offSocketEvent(SocketEvents.typingStarted);
    _apiClient.offSocketEvent(SocketEvents.typingStopped);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                widget.userName[0],
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _partnerIsTyping ? 'en train d\'écrire...' : 'En ligne',
                  style: TextStyle(
                    color: _partnerIsTyping ? Colors.indigo : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.indigo),
            onPressed: () => _initiateCall(isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.indigo),
            onPressed: () => _initiateCall(isVideo: false),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(color: Colors.indigo),
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? const Center(
                    child: Text(
                      'Aucun message. Dites bonjour !',
                      style: TextStyle(color: Colors.black45),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_partnerIsTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_partnerIsTyping && index == _messages.length) {
                        return _buildTypingBubble();
                      }
                      final msg = _messages[index];
                      return _buildMessageBubble(msg, msg.senderID == _myId);
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.isDeleted)
              Text(
                'Message supprimé',
                style: TextStyle(
                  color: isMe ? Colors.white60 : Colors.black38,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Text(
                msg.content ?? msg.displayContent,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.sendAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black45,
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.msgID == 0 ? Icons.schedule : Icons.check,
                    size: 10,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
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
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          '• • •',
          style: TextStyle(color: Colors.black45, fontSize: 16, letterSpacing: 4),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Colors.grey),
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
