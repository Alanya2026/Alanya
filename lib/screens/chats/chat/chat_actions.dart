// Handlers & logique de l'écran de chat : envoi, médias, vocal, appels.
// part of chat_detail_screen.dart.
part of '../chat_detail_screen.dart';

extension _ChatActions on _ChatDetailScreenState {
  void _sendMessage() {
    if (_inputBlocked) return;
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.conversationId == null || _myId == null) return;

    _chat.repository.sendText(
      conversationID: widget.conversationId!,
      content: text,
      replyToID: _replyTo?.msgID,
      replyToContent: _replyTo == null ? null : _previewOf(_replyTo!),
    );

    _messageController.clear();
    rebuild(() {
      _hasText = false;
      _replyTo = null;
    });
    _stopTyping();
    _scrollToBottom();
  }

  String _previewOf(LocalMessage m) {
    if (isAlbumMarkerContent(m.content)) {
      final marker = parseAlbumMarker(m.content);
      if (marker != null) return 'Album · ${marker.total} médias';
    }
    if (m.content != null && m.content!.isNotEmpty) return stripMarkers(m.content!);
    return _mediaLabel(m.type);
  }

  bool _canEditMessage(LocalMessage msg) {
    final sent = msg.sendAt.toUtc();
    return DateTime.now().toUtc().difference(sent) <= _messageEditWindow;
  }

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
                rebuild(() => _replyTo = msg);
                _inputFocus.requestFocus();
              },
            ),
            if (canForwardMessage(msg))
              ListTile(
                leading: Icon(Icons.forward, color: primary),
                title: const Text('Transférer'),
                onTap: () {
                  Navigator.pop(context);
                  _openForwardPicker(msg);
                },
              ),
            if (msg.msgID != 0 && !msg.isDeleted)
              ListTile(
                leading: Icon(
                  msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: primary,
                ),
                title: Text(msg.isPinned ? 'Détacher' : 'Épingler'),
                onTap: () {
                  Navigator.pop(context);
                  _togglePin(msg);
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
            if (isMe && isText && !msg.isDeleted && _canEditMessage(msg))
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

  void _openForwardPicker(LocalMessage msg) {
    if (!canForwardMessage(msg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce message ne peut pas être transféré pour le moment'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardMessageScreen(
          message: msg,
          excludeConversationId: widget.conversationId,
        ),
      ),
    );
  }

  void _openForwardAlbumPicker(List<LocalMessage> items) {
    if (!canForwardAlbum(items)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cet album ne peut pas être transféré pour le moment'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardMessageScreen(
          albumItems: items,
          excludeConversationId: widget.conversationId,
        ),
      ),
    );
  }

  void _showAlbumMenu(List<LocalMessage> items, bool isMe) {
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
            if (canForwardAlbum(items))
              ListTile(
                leading: Icon(Icons.forward, color: primary),
                title: Text('Transférer l\'album (${items.length})'),
                onTap: () {
                  Navigator.pop(context);
                  _openForwardAlbumPicker(items);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: const Text('Supprimer pour moi'),
              onTap: () {
                Navigator.pop(context);
                for (final msg in items) {
                  if (msg.msgID != 0) {
                    _chat.repository.deleteMessage(msg.msgID, forAll: false);
                  }
                }
              },
            ),
            if (isMe)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: const Text('Supprimer pour tout le monde'),
                onTap: () {
                  Navigator.pop(context);
                  for (final msg in items) {
                    if (msg.msgID != 0) {
                      _chat.repository.deleteMessage(msg.msgID, forAll: true);
                    }
                  }
                },
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(LocalMessage msg) async {
    if (msg.msgID == 0) return;
    try {
      await _chat.repository.setMessagePinned(msg.msgID, !msg.isPinned);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action impossible, réessayez')),
      );
    }
  }

  void _showEditDialog(LocalMessage msg) {
    if (!_canEditMessage(msg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La modification n\'est possible que dans les 30 minutes suivant l\'envoi'),
        ),
      );
      return;
    }
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

  Future<void> _pickImageFromGallery() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 80,
      limit: ChatRepository.maxAlbumItems,
    );
    if (picked.isEmpty) return;

    if (picked.length > ChatRepository.maxAlbumItems) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Maximum ${ChatRepository.maxAlbumItems} photos. '
              'Seules les ${ChatRepository.maxAlbumItems} premières seront envoyées.',
            ),
          ),
        );
      }
    }

    final limited = picked.take(ChatRepository.maxAlbumItems).toList();
    if (limited.length == 1) {
      _sendMediaFile(File(limited.first.path), type: 1);
      return;
    }

    final items = limited
        .map((x) => AlbumSendItem(file: File(x.path), type: 1))
        .toList();

    if (widget.conversationId == null || _myId == null) return;
    _chat.repository.sendMediaAlbum(
      conversationID: widget.conversationId!,
      items: items,
    );
    _scrollToBottom();
  }

  Future<int?> _readVideoDuration(File file) async {
    final ctrl = VideoPlayerController.file(file);
    try {
      await ctrl.initialize();
      return ctrl.value.duration.inSeconds;
    } catch (e) {
      debugPrint('[ChatDetail] durée vidéo non lue ($e)');
      return null;
    } finally {
      await ctrl.dispose();
    }
  }

  Future<void> _pickImageFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (x != null) _sendMediaFile(File(x.path), type: 1);
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickMultiVideo(
      limit: ChatRepository.maxAlbumItems,
    );
    if (picked.isEmpty) return;

    if (picked.length > ChatRepository.maxAlbumItems && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum ${ChatRepository.maxAlbumItems} vidéos. '
            'Seules les ${ChatRepository.maxAlbumItems} premières seront envoyées.',
          ),
        ),
      );
    }

    final limited = picked.take(ChatRepository.maxAlbumItems).toList();
    final valid = <XFile>[];
    for (final x in limited) {
      final file = File(x.path);
      final size = file.existsSync() ? file.lengthSync() : 0;
      if (size > _maxMediaBytes) {
        if (mounted) {
          final mb = (size / (1024 * 1024)).toStringAsFixed(1);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Vidéo ignorée ($mb Mo). Limite : 50 Mo.'),
            backgroundColor: AppColors.error,
          ));
        }
        continue;
      }
      valid.add(x);
    }
    if (valid.isEmpty) return;

    if (valid.length == 1) {
      final file = File(valid.first.path);
      final durSec = await _readVideoDuration(file);
      _sendMediaFile(file, type: 2, duration: durSec);
      return;
    }

    final items = <AlbumSendItem>[];
    for (final x in valid) {
      final file = File(x.path);
      final durSec = await _readVideoDuration(file);
      items.add(AlbumSendItem(file: file, type: 2, duration: durSec));
    }

    if (widget.conversationId == null || _myId == null) return;
    _chat.repository.sendMediaAlbum(
      conversationID: widget.conversationId!,
      items: items,
    );
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    final path = res?.files.single.path;
    if (path != null) _sendMediaFile(File(path), type: 4, name: res!.files.single.name);
  }

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
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    rebuild(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) rebuild(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final seconds = _recordSeconds;
    if (mounted) rebuild(() => _isRecording = false);

    if (send && path != null && seconds >= 1) {
      _sendMediaFile(File(path), type: 3, name: 'Message vocal', duration: seconds);
    } else if (path != null) {
      // Annulé ou trop court → supprimer le fichier temporaire.
      try {
        File(path).deleteSync();
      } catch (_) { /* fichier temporaire déjà absent — ignoré */ }
    }
  }

  void _onTextChanged(String value) {
    final has = value.trim().isNotEmpty;
    if (has != _hasText) rebuild(() => _hasText = has);
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

  Future<void> _scrollToReply(int replyToID) async {
    final convId = widget.conversationId;
    if (convId == null || replyToID <= 0) return;

    _suppressAutoScroll = true;
    _atBottom = false;

    try {
      final found = await _ensureMessageLoaded(convId, replyToID);
      if (!mounted) return;
      if (!found) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message introuvable dans cette conversation')),
        );
        return;
      }

      final messages = await _chat.watchMessages(convId).first;
      final index = messages.indexWhere((m) => m.msgID == replyToID);
      if (index < 0) return;

      rebuild(() => _pendingScrollMsgId = replyToID);
      await WidgetsBinding.instance.endOfFrame;

      if (await _tryRevealMessage(replyToID)) return;

      final estimated = _estimateScrollOffset(index, messages);
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        await _scrollController.animateTo(
          estimated.clamp(0.0, max),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }

      for (var i = 0; i < 12; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (await _tryRevealMessage(replyToID)) return;

        if (!_scrollController.hasClients) break;
        final max = _scrollController.position.maxScrollExtent;
        final nudge = (i + 1) * 150.0;
        final target = i.isEven
            ? (estimated - nudge).clamp(0.0, max)
            : (estimated + nudge * 0.5).clamp(0.0, max);
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'afficher le message')),
        );
      }
    } finally {
      if (mounted) {
        rebuild(() => _pendingScrollMsgId = null);
        _suppressAutoScroll = false;
      }
    }
  }

  Future<bool> _tryRevealMessage(int msgID) async {
    if (!mounted) return false;
    final ctx = _messageKeys[msgID]?.currentContext;
    if (ctx == null) return false;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.35,
    );
    _highlightMessage(msgID);
    if (mounted) rebuild(() => _pendingScrollMsgId = null);
    return true;
  }

  double _estimateScrollOffset(int index, List<LocalMessage> messages) {
    const dateH = 42.0;
    var offset = AppSpacing.lg.toDouble();
    for (var i = 0; i < index; i++) {
      final prev = i > 0 ? messages[i - 1] : null;
      if (prev == null ||
          !_sameDay(prev.sendAt.toLocal(), messages[i].sendAt.toLocal())) {
        offset += dateH;
      }
      if (widget.isGroup && messages[i].senderID != _myId) offset += 22;
      offset += _estimateBubbleHeight(messages[i]);
    }
    return offset;
  }

  double _estimateBubbleHeight(LocalMessage m) {
    var h = 56.0;
    if (m.replyToContent != null && m.replyToContent!.isNotEmpty) h += 36;
    switch (m.type) {
      case 1:
      case 2:
        return h + 130;
      case 3:
        return h + 8;
      case 4:
        return h - 4;
      default:
        final lines = ((m.content?.length ?? 0) / 38).ceil().clamp(1, 8);
        return h + lines * 18;
    }
  }

  Future<bool> _ensureMessageLoaded(int convId, int msgID) async {
    for (var i = 0; i < 50; i++) {
      final messages = await _chat.watchMessages(convId).first;
      if (messages.any((m) => m.msgID == msgID)) return true;
      final loaded = await _chat.repository.loadOlderMessages(convId);
      if (loaded == 0) return false;
    }
    return false;
  }

  void _highlightMessage(int msgID) {
    _highlightTimer?.cancel();
    rebuild(() => _highlightMsgId = msgID);
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) rebuild(() => _highlightMsgId = null);
    });
  }

  String _formatTime(DateTime sendAt) {
    final dt = sendAt.toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _initiateCall({required bool isVideo}) async {
    if (_callsDisabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appel impossible avec ce contact')),
      );
      return;
    }
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
    await callService.navigateToCallUi(context);
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
    await callService.navigateToCallUi(context);
  }

  String _presenceLabel() {
    if (_blockedByThem) return '';
    final uid = widget.userId;
    if (uid == null) return '';
    return _chat.presenceLabel(uid);
  }

  bool _hasLocal(LocalMessage msg) =>
      msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();

  Future<void> _openViewer(LocalMessage msg, {required bool isVideo}) async {
    await _openAlbumViewer([msg], initialIndex: 0);
  }

  Future<void> _openAlbumViewer(
    List<LocalMessage> items, {
    required int initialIndex,
  }) async {
    final prepared = <MediaViewerItem>[];
    for (final msg in items) {
      String? localPath =
          (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
              ? msg.localMediaPath
              : null;

      final isVideo = msg.type == 2;
      if (isVideo && localPath == null && msg.mediaUrl != null) {
        if (prepared.isEmpty && initialIndex == items.indexOf(msg)) {
          _showLoading();
        }
        localPath = await _chat.repository.mediaCache.ensureCached(msg.mediaUrl!);
        if (localPath != null && msg.msgID != 0) {
          await _chat.repository.dao.setLocalMediaPath(msg.msgID, localPath);
        }
        if (mounted && prepared.isEmpty && initialIndex == items.indexOf(msg)) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      prepared.add(MediaViewerItem(
        isVideo: isVideo,
        localPath: localPath,
        networkUrl: msg.mediaUrl,
        title: msg.mediaName,
      ));
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          items: prepared,
          initialIndex: initialIndex.clamp(0, prepared.length - 1),
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

  void _toggleEmoji() {
    if (_showEmoji) {
      rebuild(() => _showEmoji = false);
      _inputFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus(); // ferme le clavier système
      rebuild(() => _showEmoji = true);
    }
  }

  String _fmtRec(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
