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
      replyToID: _replyTo != null && _replyTo!.msgID > 0 ? _replyTo!.msgID : null,
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
    // Vue unique : ne jamais exposer la légende hors de la visionneuse.
    if (m.isViewOnce) return _mediaLabel(m.type);
    // Item d'album : aperçu du média seul (pas du groupe).
    if (isAlbumMarkerContent(m.content)) return _mediaLabel(m.type);
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
                title: const Text('Supprimer pour tous'),
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
            if (msg.msgID != 0)
              ListTile(
                leading: Icon(Icons.info_outline, color: primary),
                title: const Text('Infos'),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(msg);
                },
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  /// Feuille « Détails du message » : horodatages d'envoi (clic + serveur),
  /// de remise et de lecture, plus le fuseau horaire pour mes propres messages.
  void _showMessageInfo(LocalMessage msg) {
    final isMe = msg.senderID == _myId;

    String fmt(DateTime? d) {
      if (d == null) return '—';
      final l = d.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(l.day)}/${two(l.month)}/${l.year} à '
          '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
    }

    String tzLabel() {
      final now = DateTime.now();
      final off = now.timeZoneOffset;
      final sign = off.isNegative ? '-' : '+';
      final h = off.inHours.abs().toString().padLeft(2, '0');
      final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
      return '${now.timeZoneName} (UTC$sign$h:$m)';
    }

    Widget line(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: context.colors.onSurfaceVariant),
              AppSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: context.text.labelSmall
                            ?.copyWith(color: context.colors.onSurfaceVariant)),
                    Text(value, style: context.text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );

    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('Détails du message', style: context.text.titleSmall),
            ),
            // Heure du clic : connue uniquement pour mes propres messages.
            if (isMe && msg.clickSentAt != null)
              line(Icons.touch_app_outlined, 'Envoyé (appui sur envoyer)',
                  fmt(msg.clickSentAt)),
            line(Icons.send_outlined, 'Envoyé à', fmt(msg.sendAt)),
            line(Icons.visibility_outlined, 'Lu',
                msg.readAt != null ? fmt(msg.readAt) : 'Non lu'),
            if (isMe) line(Icons.public, 'Fuseau horaire', tzLabel()),
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
                title: const Text('Supprimer pour tous'),
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
    _pendingViewOnce = false;
    showAppBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => AppBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Vue unique : réservée aux discussions 1-1 (pas les groupes).
              if (!widget.isGroup) ...[
                SwitchListTile(
                  value: _pendingViewOnce,
                  onChanged: (v) => setSheet(() => _pendingViewOnce = v),
                  secondary: Icon(
                    _pendingViewOnce ? Icons.timer : Icons.timer_outlined,
                    color: context.colors.primary,
                  ),
                  title: const Text('Vue unique'),
                  subtitle: const Text('Ouvrable une seule fois, puis inaccessible'),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                AppSpacing.vGapSm,
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(Icons.photo_library, 'Galerie', sem.info, _pickImageFromGallery),
                  _attachOption(Icons.camera_alt, 'Caméra', context.colors.primary, _pickImageFromCamera),
                  _attachOption(Icons.videocam, 'Vidéo', context.colors.error, _pickVideo),
                  _attachOption(Icons.insert_drive_file, 'Fichier', sem.warning, _pickFile),
                ],
              ),
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
    final viewOnce = _pendingViewOnce;

    if (viewOnce) {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (x != null) {
        await _composeAndSendMedia(
          [AlbumSendItem(file: File(x.path), type: 1)],
          viewOnce: true,
        );
      }
      return;
    }

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

    final items = picked
        .take(ChatRepository.maxAlbumItems)
        .map((x) => AlbumSendItem(file: File(x.path), type: 1))
        .toList();

    await _composeAndSendMedia(items);
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
    final viewOnce = _pendingViewOnce;
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (x != null) {
      await _composeAndSendMedia(
        [AlbumSendItem(file: File(x.path), type: 1)],
        viewOnce: viewOnce,
      );
    }
  }

  Future<void> _pickVideo() async {
    final viewOnce = _pendingViewOnce;

    if (viewOnce) {
      final x = await _picker.pickVideo(source: ImageSource.gallery);
      if (x == null) return;
      final file = File(x.path);
      final durSec = await _readVideoDuration(file);
      await _composeAndSendMedia(
        [AlbumSendItem(file: file, type: 2, duration: durSec)],
        viewOnce: true,
      );
      return;
    }

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
    final items = <AlbumSendItem>[];
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
      final durSec = await _readVideoDuration(file);
      items.add(AlbumSendItem(file: file, type: 2, duration: durSec));
    }
    if (items.isEmpty) return;

    await _composeAndSendMedia(items);
  }

  /// Ouvre l'aperçu avec légende, puis envoie le(s) média(s).
  Future<void> _composeAndSendMedia(
    List<AlbumSendItem> items, {
    bool viewOnce = false,
  }) async {
    if (items.isEmpty || widget.conversationId == null || _myId == null) return;
    if (!mounted) return;

    final result = await Navigator.push<MediaSendResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaSendScreen(items: items, isViewOnce: viewOnce),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;
    if (widget.conversationId == null || _myId == null) return;

    if (items.length == 1) {
      final item = items.first;
      _sendMediaFile(
        item.file,
        type: item.type,
        name: item.mediaName,
        duration: item.duration,
        viewOnce: viewOnce,
        content: result.caption,
      );
      return;
    }

    _chat.repository.sendMediaAlbum(
      conversationID: widget.conversationId!,
      items: items,
      content: result.caption,
    );
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    final path = res?.files.single.path;
    if (path != null) _sendMediaFile(File(path), type: 4, name: res!.files.single.name);
  }

  void _sendMediaFile(
    File file, {
    required int type,
    String? name,
    int? duration,
    bool viewOnce = false,
    String? content,
  }) {
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
      content: content,
      isViewOnce: viewOnce,
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
      _voiceViewOnce = false;
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
      _sendMediaFile(File(path), type: 3, name: 'Message vocal', duration: seconds, viewOnce: _voiceViewOnce);
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
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
    final feedIndex = messages.length - 1 - index;
    for (var i = 0; i <= feedIndex; i++) {
      final msgIdx = messages.length - 1 - i;
      final m = messages[msgIdx];
      if (i < messages.length - 1) {
        final olderAbove = messages[messages.length - 2 - i];
        if (!_sameDay(olderAbove.sendAt.toLocal(), m.sendAt.toLocal())) {
          offset += dateH;
        }
      }
      if (widget.isGroup && m.senderID != _myId) offset += 22;
      offset += _estimateBubbleHeight(m);
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

  /// Propose de rappeler suite à un tap sur une entrée du journal d'appels.
  /// Affiche une option correspondant au type de l'appel du log (vocal ou
  /// vidéo), avec la possibilité de basculer vers l'autre type avant de
  /// lancer l'appel.
  void _showCallBackOptions(LocalCall call) {
    final callWasVideo = call.type == 1;
    final name = widget.userName;
    final primary = context.colors.primary;

    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                'Rappeler $name',
                style: context.text.titleSmall,
              ),
            ),
            ListTile(
              leading: Icon(
                callWasVideo ? Icons.videocam_rounded : Icons.call_rounded,
                color: primary,
              ),
              title: Text(callWasVideo ? 'Appel vidéo' : 'Appel vocal'),
              onTap: () {
                Navigator.pop(context);
                _initiateCall(isVideo: callWasVideo);
              },
            ),
            ListTile(
              leading: Icon(
                callWasVideo ? Icons.call_rounded : Icons.videocam_rounded,
                color: context.colors.onSurfaceVariant,
              ),
              title: Text(callWasVideo ? 'Appel vocal' : 'Appel vidéo'),
              onTap: () {
                Navigator.pop(context);
                _initiateCall(isVideo: !callWasVideo);
              },
            ),
          ],
        ),
      ),
    );
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil non disponible, réessayez')),
      );
      return;
    }
    final callService = Provider.of<CallService>(context, listen: false);
    if (!mounted) return;
    await callService.initiateCall(
      targetUserId: widget.userId!,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
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
    var loaderShown = false;
    final prepared = await buildMediaViewerItems(
      items,
      _chat.repository,
      loadingForIndex: initialIndex,
      onLoadingVideo: () {
        if (!mounted || loaderShown) return;
        loaderShown = true;
        _showLoading();
      },
      onLoadingDone: () {
        if (mounted && loaderShown) {
          Navigator.of(context, rootNavigator: true).pop();
          loaderShown = false;
        }
      },
    );

    if (!mounted) return;
    if (loaderShown) {
      Navigator.of(context, rootNavigator: true).pop();
    }

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

  void _openAlbumMediaList(List<LocalMessage> items, {required int initialIndex}) {
    final sorted = sortAlbumMessages(items);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumMediaListScreen(
          messages: sorted,
          initialIndex: initialIndex.clamp(0, sorted.length - 1),
          excludeConversationId: widget.conversationId,
        ),
      ),
    );
  }

  /// Ouvre un média à vue unique. Le média n'est jamais mis en cache : on
  /// l'affiche en flux depuis le réseau, puis on le « consomme » à la fermeture
  /// de la visionneuse (marque vu + efface toute trace locale ; le serveur
  /// supprime le fichier une fois que tous les destinataires ont vu).
  Future<void> _openViewOnce(LocalMessage msg) async {
    if (msg.viewedAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce média a déjà été ouvert')),
      );
      return;
    }
    if (msg.senderID == _myId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Média à vue unique — visible une seule fois par le destinataire')),
      );
      return;
    }
    if (msg.mediaUrl == null || msg.mediaUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce média n\'est plus disponible')),
      );
      return;
    }

    // Bloque les captures d'écran (Android FLAG_SECURE + iOS) le temps de
    // l'affichage. Best-effort : n'empêche jamais l'ouverture en cas d'échec.
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (_) {/* non supporté sur la plateforme — ignoré */}

    final caption = msg.content?.trim();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewOnceViewerScreen(
          type: msg.type,
          mediaUrl: msg.mediaUrl!,
          caption: caption != null && caption.isNotEmpty ? caption : null,
        ),
      ),
    );

    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (_) {/* ignoré */}

    // Consommé à la fermeture : marque vu localement + notifie le serveur.
    await _chat.repository.markViewed(msg.msgID);
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

    // PDF → visionneuse intégrée (lue depuis le fichier local déjà téléchargé).
    if (_isPdf(msg)) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            path: path!,
            title: msg.mediaName ?? 'Document PDF',
          ),
        ),
      );
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
