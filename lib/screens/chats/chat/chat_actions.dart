// Handlers & logique de l'écran de chat : envoi, médias, vocal, appels.
// part of chat_detail_screen.dart.
part of '../chat_detail_screen.dart';

extension _ChatActions on _ChatDetailScreenState {
  bool _isSelectableMessage(LocalMessage msg) => msg.msgID > 0 && !msg.isDeleted;

  List<LocalMessage> _albumSiblings(LocalMessage msg) {
    final marker = parseAlbumMarker(msg.content);
    if (marker == null) return [msg];
    return _currentMessages
        .where((m) => parseAlbumMarker(m.content)?.albumId == marker.albumId)
        .toList();
  }

  bool _isMessageSelected(LocalMessage msg) {
    final siblings = _albumSiblings(msg);
    if (siblings.length > 1) {
      return siblings.every((m) => _selectedMsgIDs.contains(m.msgID));
    }
    return _selectedMsgIDs.contains(msg.msgID);
  }

  List<LocalMessage> _resolveSelectedMessages() {
    return _currentMessages
        .where((m) => _selectedMsgIDs.contains(m.msgID))
        .toList()
      ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
  }

  void _enterSelectionMode(LocalMessage seed) {
    if (!_isSelectableMessage(seed)) return;
    final ids = _albumSiblings(seed)
        .map((m) => m.msgID)
        .where((id) => id > 0)
        .toSet();
    if (ids.isEmpty) return;
    rebuild(() {
      _selectionMode = true;
      _selectedMsgIDs
        ..clear()
        ..addAll(ids);
    });
  }

  void _enterSelectionModeAlbum(List<LocalMessage> items) {
    final ids = items
        .where(_isSelectableMessage)
        .map((m) => m.msgID)
        .toSet();
    if (ids.isEmpty) return;
    rebuild(() {
      _selectionMode = true;
      _selectedMsgIDs
        ..clear()
        ..addAll(ids);
    });
  }

  void _exitSelectionMode() {
    rebuild(() {
      _selectionMode = false;
      _selectedMsgIDs.clear();
    });
  }

  void _toggleSelection(LocalMessage msg) {
    if (!_selectionMode || !_isSelectableMessage(msg)) return;
    final ids = _albumSiblings(msg)
        .map((m) => m.msgID)
        .where((id) => id > 0)
        .toList();
    final allSelected = ids.every(_selectedMsgIDs.contains);

    if (allSelected) {
      rebuild(() {
        _selectedMsgIDs.removeAll(ids);
        if (_selectedMsgIDs.isEmpty) _selectionMode = false;
      });
      return;
    }

    final newIds = ids.where((id) => !_selectedMsgIDs.contains(id)).toList();
    if (_selectedMsgIDs.length + newIds.length > _maxSelectionCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.maxMessages(_maxSelectionCount))),
      );
      return;
    }

    rebuild(() => _selectedMsgIDs.addAll(newIds));
  }

  Future<void> _deleteSelected({required bool forAll}) async {
    final ids = _selectedMsgIDs.toList();
    if (ids.isEmpty) return;
    await _chat.repository.deleteMessages(
      ids,
      forAll: forAll,
      conversationID: _convId,
    );
    if (!mounted) return;
    _exitSelectionMode();
  }

  void _showDeleteSelectedMenu() {
    final selected = _resolveSelectedMessages();
    if (selected.isEmpty) return;
    final canDeleteForAll =
        selected.every((m) => m.senderID == _myId);
    final muted = context.colors.onSurfaceVariant;
    final error = context.colors.error;

    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: Text(context.l10n.deleteForMe),
              onTap: () {
                Navigator.pop(context);
                _deleteSelected(forAll: false);
              },
            ),
            if (canDeleteForAll)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: Text(context.l10n.deleteForEveryone),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSelected(forAll: true);
                },
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  Future<void> _forwardSelected() async {
    final selected = _resolveSelectedMessages();
    if (selected.isEmpty) return;
    if (!selected.every(canForwardMessage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.oneOrMoreMessagesCannotBe),
        ),
      );
      return;
    }

    final bool? ok;
    if (selected.length == 1) {
      ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ForwardMessageScreen(
            message: selected.first,
            excludeConversationId: _convId,
          ),
        ),
      );
    } else {
      ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ForwardMessageScreen(
            messages: selected,
            excludeConversationId: _convId,
          ),
        ),
      );
    }

    if (ok == true && mounted) _exitSelectionMode();
  }

  Future<void> _sendMessage() async {
    if (_inputBlocked) return;
    final text = _messageController.text.trim();
    if (text.isEmpty || _myId == null) return;

    final convId = await _ensureConversation();
    if (convId == null) return;

    // Résoudre un msgID frais : le snapshot `_replyTo` peut encore avoir
    // msgID=0 si la vidéo était en cours d'ack au moment du long-press.
    final reply = _replyTo;
    int? replyId;
    String? replyContent;
    if (reply != null) {
      replyContent = _previewOf(reply);
      replyId = reply.msgID > 0 ? reply.msgID : null;
      if (replyId == null) {
        for (final m in _currentMessages) {
          if (m.clientId == reply.clientId && m.msgID > 0) {
            replyId = m.msgID;
            break;
          }
        }
      }
    }

    _chat.repository.sendText(
      conversationID: convId,
      content: text,
      replyToID: replyId,
      replyToContent: replyContent,
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
    // Localisation : JSON lat/lng — ne jamais exposer le content brut.
    if (m.type == 5) return locationPreviewLabel(m.content);
    // Contact : JSON — ne jamais exposer le content brut.
    if (m.type == 7) return contactPreviewLabel(m.content);
    // Item d'album : aperçu du média seul (pas du groupe).
    if (isAlbumMarkerContent(m.content)) return _mediaLabel(m.type);
    // Conserver les marqueurs (*gras*, etc.) : la citation les rend via parseRichSpans.
    if (m.content != null && m.content!.isNotEmpty) return m.content!;
    // Fichier : préférer le nom (ex. document.pdf) au libellé générique.
    if (m.type == 4) {
      final name = m.mediaName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return _mediaLabel(m.type);
  }

  Future<void> _pickLocation() async {
    final convId = await _ensureConversation();
    if (convId == null || !mounted) return;

    final result = await Navigator.push<LocationSendResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result == null || !mounted) return;

    await _chat.repository.sendLocation(
      conversationID: convId,
      location: result.payload,
    );
    _scrollToBottom();
  }

  Future<void> _pickContact() async {
    final convId = await _ensureConversation();
    if (convId == null || !mounted) return;

    final payload = await showAppBottomSheet<ContactPayload>(
      context: context,
      builder: (_) => const SharePreferredContactSheet(),
    );
    if (payload == null || !mounted) return;

    await _chat.repository.sendContact(
      conversationID: convId,
      contact: payload,
    );
    _scrollToBottom();
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
            if (_isSelectableMessage(msg))
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: primary),
                title: Text(context.l10n.select),
                onTap: () {
                  Navigator.pop(context);
                  _enterSelectionMode(msg);
                },
              ),
            // Si le message est en échec d'envoi, on propose en priorité le retry.
            if (isMe && msg.status == 4)
              ListTile(
                leading: Icon(Icons.refresh, color: primary),
                title: Text(context.l10n.retrySending),
                onTap: () {
                  Navigator.pop(context);
                  _chat.repository.retryMessage(msg.clientId);
                },
              ),
            ListTile(
              leading: Icon(Icons.reply, color: primary),
              title: Text(context.l10n.reply),
              onTap: () {
                Navigator.pop(context);
                rebuild(() => _replyTo = msg);
                _inputFocus.requestFocus();
              },
            ),
            if (canForwardMessage(msg))
              ListTile(
                leading: Icon(Icons.forward, color: primary),
                title: Text(context.l10n.forward),
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
                title: Text(msg.isPinned ? context.l10n.unpin2 : context.l10n.pin),
                onTap: () {
                  Navigator.pop(context);
                  _togglePin(msg);
                },
              ),
            if (isText && msg.content != null)
              ListTile(
                leading: Icon(Icons.copy, color: primary),
                title: Text(context.l10n.copy),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.content!));
                  Navigator.pop(context);
                },
              ),
            if (isMe && isText && !msg.isDeleted && _canEditMessage(msg))
              ListTile(
                leading: Icon(Icons.edit, color: primary),
                title: Text(context.l10n.edit),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(msg);
                },
              ),
            if (isMe && !msg.isDeleted)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: Text(context.l10n.deleteForEveryone),
                onTap: () {
                  Navigator.pop(context);
                  _chat.repository.deleteMessage(
                    msg.msgID,
                    forAll: true,
                    conversationID: _convId,
                    clientId: msg.msgID == 0 ? msg.clientId : null,
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: Text(context.l10n.deleteForMe),
              onTap: () {
                Navigator.pop(context);
                _chat.repository.deleteMessage(
                  msg.msgID,
                  forAll: false,
                  conversationID: _convId,
                  clientId: msg.msgID == 0 ? msg.clientId : null,
                );
              },
            ),
            if (msg.msgID != 0)
              ListTile(
                leading: Icon(Icons.info_outline, color: primary),
                title: Text(context.l10n.infoAction),
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

  /// Feuille « Détails du message ».
  ///
  /// Vue EXPÉDITEUR (mes messages) : Livré à (deliveredAt), Lu à (readAt)
  /// — context.l10n.sentAt retiré (peu utile pour l'expéditeur).
  ///
  /// Vue DESTINATAIRE (messages reçus) : Appui sur envoyer (clickSentAt) et
  /// Envoyé à (sendAt).
  ///
  /// Vue DESTINATAIRE (messages reçus) : Appui sur envoyer (clickSentAt)
  /// uniquement — context.l10n.sentAt retiré (redondant, peu utile pour le destinataire).
  void _showMessageInfo(LocalMessage msg) {
    final isMe = msg.senderID == _myId;

    String fmt(DateTime? d) {
      if (d == null) return '—';
      final l = d.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return context.l10n.dateAtTimeFull(l.day, l.month, l.year, '${two(l.hour)}:${two(l.minute)}:${two(l.second)}');
    }

    // Fuseau horaire lisible à partir du nom (pays de l'expéditeur, ex.
    // "Africa/Douala") et du décalage en heures renvoyés par le serveur
    // (dérivés via jointure `users` → `pays`, jamais stockés par message).
    // Si l'info n'est pas encore disponible (ancien message / hors-ligne),
    // on retombe sur le fuseau de CET appareil.
    String tzLabel(String? name, int? offsetHours) {
      String tzName;
      int offMin;
      if (name != null && name.isNotEmpty && offsetHours != null) {
        tzName = name;
        offMin = offsetHours * 60;
      } else {
        final now = DateTime.now();
        tzName = now.timeZoneName;
        offMin = now.timeZoneOffset.inMinutes;
      }
      final sign = offMin.isNegative ? '-' : '+';
      final h = (offMin.abs() ~/ 60).toString().padLeft(2, '0');
      final m = (offMin.abs() % 60).toString().padLeft(2, '0');
      return '$tzName (UTC$sign$h:$m)';
    }

    Widget line(IconData icon, String label, String value, {String? tz}) => Padding(
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
                    if (tz != null)
                      Text(tz,
                          style: context.text.labelSmall
                              ?.copyWith(color: context.colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );

    final rows = <Widget>[];
    // Fuseau horaire unique du message (celui de l'expéditeur, capturé une
    // seule fois à l'envoi) — affiché à côté de chaque horodatage.
    final tz = tzLabel(msg.messageTz, msg.messageTzOffset);
    if (isMe) {
      rows.add(line(
        Icons.done_all_outlined,
        context.l10n.deliveredAt,
        msg.deliveredAt != null ? fmt(msg.deliveredAt) : context.l10n.notDeliveredYet,
      ));
      rows.add(line(
        Icons.visibility_outlined,
        context.l10n.readAt,
        msg.readAt != null ? fmt(msg.readAt) : context.l10n.notYetRead,
      ));
    } else {
      rows.add(line(
        Icons.touch_app_outlined,
        context.l10n.sentOnTapSend,
        msg.clickSentAt != null ? fmt(msg.clickSentAt) : '—',
      ));
      rows.add(line(Icons.send_outlined, context.l10n.sentAt, fmt(msg.sendAt)));
    }
    rows.add(line(Icons.public, context.l10n.timeZoneLabel, tz));

    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(context.l10n.messageDetails, style: context.text.titleSmall),
            ),
            ...rows,
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  void _openForwardPicker(LocalMessage msg) {
    if (!canForwardMessage(msg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.thisMessageCannotBeForwardedRight),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardMessageScreen(
          message: msg,
          excludeConversationId: _convId,
        ),
      ),
    );
  }

  void _openForwardAlbumPicker(List<LocalMessage> items) {
    if (!canForwardAlbum(items)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.thisAlbumCannotBeForwardedRight),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardMessageScreen(
          albumItems: items,
          excludeConversationId: _convId,
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
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: primary),
              title: Text(context.l10n.selectCount(items.length)),
              onTap: () {
                Navigator.pop(context);
                _enterSelectionModeAlbum(items);
              },
            ),
            if (canForwardAlbum(items))
              ListTile(
                leading: Icon(Icons.forward, color: primary),
                title: Text(context.l10n.forwardAlbumCount(items.length)),
                onTap: () {
                  Navigator.pop(context);
                  _openForwardAlbumPicker(items);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: muted),
              title: Text(context.l10n.deleteForMe),
              onTap: () {
                Navigator.pop(context);
                final ids = items
                    .map((m) => m.msgID)
                    .where((id) => id > 0)
                    .toList();
                if (ids.isNotEmpty) {
                  _chat.repository.deleteMessages(
                    ids,
                    forAll: false,
                    conversationID: _convId,
                  );
                }
              },
            ),
            if (isMe)
              ListTile(
                leading: Icon(Icons.delete_forever, color: error),
                title: Text(context.l10n.deleteForEveryone),
                onTap: () {
                  Navigator.pop(context);
                  final ids = items
                      .map((m) => m.msgID)
                      .where((id) => id > 0)
                      .toList();
                  if (ids.isNotEmpty) {
                    _chat.repository.deleteMessages(
                      ids,
                      forAll: true,
                      conversationID: _convId,
                    );
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
        SnackBar(content: Text(context.l10n.actionFailedPleaseTryAgain)),
      );
    }
  }

  void _showEditDialog(LocalMessage msg) {
    if (!_canEditMessage(msg)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.editingIsOnlyPossibleWithin30),
        ),
      );
      return;
    }
    final ctrl = TextEditingController(text: msg.content ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.editMessage),
        content: TextField(controller: ctrl, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty && msg.msgID != 0) _chat.repository.editMessage(msg.msgID, t);
              Navigator.pop(context);
            },
            child: Text(context.l10n.commonSave),
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
                  title: Text(context.l10n.viewOnce),
                  subtitle: Text(context.l10n.canBeOpenedOnlyOnceThen),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                AppSpacing.vGapSm,
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(Icons.photo_library, context.l10n.gallery, sem.info, _pickImageFromGallery),
                  _attachOption(Icons.camera_alt, context.l10n.camera, context.colors.primary, _pickImageFromCamera),
                  _attachOption(Icons.videocam, context.l10n.video2, context.colors.error, _pickVideo),
                  _attachOption(Icons.insert_drive_file, context.l10n.file2, sem.warning, _pickFile),
                ],
              ),
              AppSpacing.vGapMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(
                    Icons.location_on,
                    context.l10n.location2,
                    sem.success,
                    _pickLocation,
                  ),
                  _attachOption(
                    Icons.person,
                    context.l10n.contact2,
                    sem.info,
                    _pickContact,
                  ),
                  const SizedBox(width: 72),
                  const SizedBox(width: 72),
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
              '${context.l10n.maxPhotos(ChatRepository.maxAlbumItems)} '
              '${context.l10n.albumFirstOnly(ChatRepository.maxAlbumItems)}',
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
    final result = await Navigator.push<CameraResult>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result == null || !mounted) return;

    final type = result.isVideo ? 2 : 1;
    int? durSec;
    if (result.isVideo) {
      durSec = await _readVideoDuration(File(result.file.path));
    }
    await _composeAndSendMedia(
      [AlbumSendItem(file: File(result.file.path), type: type, duration: durSec)],
      viewOnce: viewOnce,
    );
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
            '${context.l10n.maxVideos(ChatRepository.maxAlbumItems)} '
            '${context.l10n.albumFirstOnly(ChatRepository.maxAlbumItems)}',
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
            content: Text(context.l10n.videoTooLarge('$mb')),
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
    if (items.isEmpty || _myId == null) return;
    if (!mounted) return;

    final result = await Navigator.push<MediaSendResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaSendScreen(items: items, isViewOnce: viewOnce),
        fullscreenDialog: true,
      ),
    );
    if (result == null || !mounted) return;
    if (_myId == null) return;

    final convId = await _ensureConversation();
    if (convId == null) return;

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
      conversationID: convId,
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

  Future<void> _sendMediaFile(
    File file, {
    required int type,
    String? name,
    int? duration,
    bool viewOnce = false,
    String? content,
  }) async {
    if (_myId == null) return;

    final convId = await _ensureConversation();
    if (convId == null) return;

    final size = file.existsSync() ? file.lengthSync() : 0;
    if (size > _maxMediaBytes) {
      final mb = (size / (1024 * 1024)).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.fileTooLarge(mb)),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    await _chat.repository.sendMediaFile(
      conversationID: convId,
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
      _sendMediaFile(File(path), type: 3, name: context.l10n.voiceMessage, duration: seconds, viewOnce: _voiceViewOnce);
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
    if (_convId == null) return;
    if (value.isEmpty) {
      _stopTyping();
      return;
    }
    _apiClient.sendSocketEvent(SocketEvents.typingStart, {'conversationID': _convId});
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _typingTimer?.cancel();
    if (_convId == null) return;
    _apiClient.sendSocketEvent(SocketEvents.typingStop, {'conversationID': _convId});
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final pixels = _scrollController.position.pixels;
    // Loin dans l'historique : saut immédiat (évite d'animer des milliers de px).
    if (pixels > 800) {
      _scrollController.jumpTo(0);
      if (mounted && !_atBottom) rebuild(() => _atBottom = true);
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Widget _buildScrollToBottomButton() {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _scrollToBottom,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colors.onSurfaceVariant,
            size: AppIconSize.md,
          ),
        ),
      ),
    );
  }

  Future<void> _scrollToReply(int replyToID) async {
    final convId = _convId;
    if (convId == null || replyToID <= 0) return;

    _suppressAutoScroll = true;
    _atBottom = false;

    try {
      final found = await _ensureMessageLoaded(convId, replyToID);
      if (!mounted) return;
      if (!found) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.messageNotFoundInThisConversation)),
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
          SnackBar(content: Text(context.l10n.unableToDisplayTheMessage)),
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
                context.l10n.callBackName(name),
                style: context.text.titleSmall,
              ),
            ),
            ListTile(
              leading: Icon(
                callWasVideo ? Icons.videocam_rounded : Icons.call_rounded,
                color: primary,
              ),
              title: Text(callWasVideo ? context.l10n.videoCall : context.l10n.voiceCall),
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
              title: Text(callWasVideo ? context.l10n.voiceCall : context.l10n.videoCall),
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
        SnackBar(content: Text(context.l10n.cannotCallThisContact)),
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
        SnackBar(content: Text(context.l10n.profileUnavailableTryAgain)),
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
      targetUserPhoto: widget.avatarUrl,
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
    final convId = _convId;
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

    final callService = Provider.of<CallService>(context, listen: false);
    if (callService.status != CallStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aCallIsAlreadyInProgress)),
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

  /// Média reçu non view-once sans fichier local → téléchargement manuel requis.
  bool _needsMediaDownload(LocalMessage msg) {
    if (msg.isViewOnce) return false;
    if (_myId != null && msg.senderID == _myId) return false;
    if (_hasLocal(msg)) return false;
    if (msg.type != 1 && msg.type != 2 && msg.type != 4) return false;
    final url = msg.mediaUrl;
    return url != null && url.isNotEmpty;
  }

  Future<String?> _downloadReceivedMedia(LocalMessage msg) async {
    final url = msg.mediaUrl;
    if (url == null || url.isEmpty || msg.msgID == 0) return null;
    if (_mediaDownloadingIds.contains(msg.msgID)) return null;

    rebuild(() => _mediaDownloadingIds.add(msg.msgID));
    try {
      final isMine = _myId != null && msg.senderID == _myId;
      final path = await _chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: url,
        type: msg.type,
        isMine: isMine,
        isViewOnce: msg.isViewOnce,
        mediaName: msg.mediaName,
      );
      if (path == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.unableToDownloadTheMedia),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return path;
    } finally {
      if (mounted) {
        rebuild(() => _mediaDownloadingIds.remove(msg.msgID));
      } else {
        _mediaDownloadingIds.remove(msg.msgID);
      }
    }
  }

  Widget _mediaDownloadBadge({required bool downloading}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: downloading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              )
            : const Icon(Icons.download_rounded, color: AppColors.white, size: 26),
      ),
    );
  }

  Future<void> _openViewer(LocalMessage msg, {required bool isVideo}) async {
    await _openAlbumViewer([msg], initialIndex: 0);
  }

  Future<void> _openAlbumViewer(
    List<LocalMessage> items, {
    required int initialIndex,
  }) async {
    if (_selectionMode && items.isNotEmpty) {
      _toggleSelection(items[initialIndex.clamp(0, items.length - 1)]);
      return;
    }

    final target = items.isEmpty
        ? null
        : items[initialIndex.clamp(0, items.length - 1)];
    if (target != null && _needsMediaDownload(target)) {
      final path = await _downloadReceivedMedia(target);
      if (path == null) return;
    }

    var loaderShown = false;
    final prepared = await buildMediaViewerItems(
      items,
      _chat.repository,
      myId: _myId,
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
    if (_selectionMode && sorted.isNotEmpty) {
      _toggleSelection(sorted[initialIndex.clamp(0, sorted.length - 1)]);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumMediaListScreen(
          messages: sorted,
          initialIndex: initialIndex.clamp(0, sorted.length - 1),
          excludeConversationId: _convId,
        ),
      ),
    );
  }

  /// Ouvre un média à vue unique. Le média n'est jamais mis en cache : on
  /// l'affiche en flux depuis le réseau, puis on le « consomme » à la fermeture
  /// de la visionneuse (marque vu + efface toute trace locale ; le serveur
  /// supprime le fichier une fois que tous les destinataires ont vu).
  Future<void> _openViewOnce(LocalMessage msg) async {
    if (_selectionMode) {
      _toggleSelection(msg);
      return;
    }
    if (msg.viewedAt != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.thisMediaHasAlreadyBeenOpened)),
      );
      return;
    }
    if (msg.senderID == _myId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.viewOnceMediaVisibleOnlyOnce)),
      );
      return;
    }
    if (msg.mediaUrl == null || msg.mediaUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.thisMediaIsNoLongerAvailable)),
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
    if (_selectionMode) {
      _toggleSelection(msg);
      return;
    }
    String? path =
        (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
            ? msg.localMediaPath
            : null;

    if (path == null) {
      if (msg.mediaUrl == null) return;
      if (_needsMediaDownload(msg)) {
        path = await _downloadReceivedMedia(msg);
      } else {
        _showLoading();
        final isMine = _myId != null && msg.senderID == _myId;
        path = await _chat.repository.ensureReceivedMediaLocal(
          msgID: msg.msgID,
          mediaUrl: msg.mediaUrl!,
          type: msg.type,
          isMine: isMine,
          isViewOnce: msg.isViewOnce,
          mediaName: msg.mediaName,
        );
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    } else if (!msg.isViewOnce && msg.msgID != 0) {
      final isMine = _myId != null && msg.senderID == _myId;
      await _chat.repository.ensureReceivedMediaLocal(
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
          SnackBar(content: Text(context.l10n.unableToDownloadTheFile), backgroundColor: AppColors.error),
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
            title: msg.mediaName ?? context.l10n.pdfDocument,
          ),
        ),
      );
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cannotOpenFileAppAlt(res.message)), backgroundColor: AppColors.error),
      );
    }
  }

  String _mediaLabel(int type) {
    switch (type) {
      case 1:
        return context.l10n.photo;
      case 2:
        return context.l10n.video;
      case 3:
        return context.l10n.audio;
      case 4:
        return context.l10n.file;
      case 5:
        return context.l10n.location;
      case 7:
        return context.l10n.contact;
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
