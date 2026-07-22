// Rendu des bulles de message et des médias. part of chat_detail_screen.dart.
part of '../chat_detail_screen.dart';

extension _ChatBubbles on _ChatDetailScreenState {
  BoxDecoration _bubbleDecoration({
    required bool isMe,
    required bool selected,
    required BorderRadius borderRadius,
    required Color baseColor,
    bool highlighted = false,
  }) {
    final bg = baseColor;

    Border? border;
    if (_selectionMode) {
      border = Border.all(
        color: selected
            ? (isMe ? context.colors.onPrimary : context.colors.primary)
            : context.colors.outline.withValues(alpha: 0.65),
        width: selected ? 2.5 : 1,
      );
    } else if (highlighted) {
      border = Border.all(
        color: isMe ? context.colors.onPrimary : context.colors.primary,
        width: 2,
      );
    }

    return BoxDecoration(
      color: bg,
      borderRadius: borderRadius,
      border: border,
      boxShadow: AppShadows.subtle,
    );
  }

  Widget _selectionCheckbox(bool selected) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.xs,
        right: AppSpacing.xs,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? context.colors.primary : const Color(0x00000000),
          border: Border.all(
            color: selected
                ? context.colors.primary
                : context.colors.outline,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: AppColors.white)
            : null,
      ),
    );
  }

  Widget _wrapSelectableBubble({
    required Widget bubble,
    required bool isMe,
    required bool selected,
    required bool selectable,
    required VoidCallback? onLongPress,
    required VoidCallback? onTap,
  }) {
    if (!_selectionMode) {
      return GestureDetector(
        onLongPress: onLongPress,
        child: bubble,
      );
    }

    return GestureDetector(
      onTap: selectable ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && selectable) _selectionCheckbox(selected),
          Flexible(child: bubble),
          if (isMe && selectable) _selectionCheckbox(selected),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(LocalMessage msg, bool isMe) {
    final selected = _isMessageSelected(msg);
    final selectable = _isSelectableMessage(msg);
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Show sender name in group chats for other people's messages
        if (widget.isGroup && !isMe)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.xs),
            child: Text(
              msg.senderNom ?? msg.senderPseudo ?? (AppLocalizations.of(context)?.unknownSender ?? context.l10n.unknownSender),
              style: context.text.labelSmall?.copyWith(color: context.colors.primary),
            ),
          ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: _wrapSelectableBubble(
            isMe: isMe,
            selected: selected,
            selectable: selectable,
            onLongPress: () => _showMessageMenu(msg, isMe),
            onTap: () => _toggleSelection(msg),
            bubble: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: _bubbleDecoration(
                isMe: isMe,
                selected: selected,
                highlighted: _highlightMsgId == msg.msgID,
                baseColor: isMe ? context.colors.primary : context.colors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: isMe ? const Radius.circular(AppRadius.lg) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(AppRadius.lg),
                ),
              ),
              // Largeur = max(citation, corps), plafonnée par maxWidth du Container.
              child: IntrinsicWidth(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (msg.isStatusReply != 0)
                    _buildStatusReplyChip(isMe),
                  if (msg.isForwarded)
                    _buildForwardedChip(isMe),
                  if (msg.replyToContent != null &&
                      msg.replyToContent!.isNotEmpty) ...[
                    if (parseStatusReplyContent(msg.replyToContent)
                        case final statusPayload?)
                      StatusReplyQuote(
                        payload: statusPayload,
                        accent: isMe
                            ? context.colors.onPrimary
                            : context.colors.primary,
                        textColor: _bubbleMuted(isMe),
                      )
                    else
                      _buildReplyQuote(
                        msg.replyToContent!,
                        isMe,
                        replyToID: msg.replyToID,
                      ),
                  ],
                  if (msg.isDeleted)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block,
                            size: 14,
                            color: _bubbleMuted(isMe)),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          context.l10n.thisMessageWasDeleted,
                          style: context.text.bodyMedium?.copyWith(
                            color: _bubbleMuted(isMe),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    if (msg.type != 0) _buildMedia(msg, isMe),
                    // Vue unique : la légende n'apparaît que dans la visionneuse.
                    if (!msg.isViewOnce) ...[
                      if (_captionText(msg) case final caption?)
                        Padding(
                          padding: EdgeInsets.only(top: msg.type != 0 ? 6 : 0),
                          child: Text.rich(
                            TextSpan(
                              children: parseRichSpans(
                                caption,
                                (context.text.bodyLarge ?? const TextStyle())
                                    .copyWith(color: _bubbleText(isMe)),
                                linkColor: isMe
                                    ? context.colors.onPrimary
                                    : context.colors.primary,
                              ),
                            ),
                          ),
                        ),
                      // Carte d'aperçu du premier lien du message (si le site
                      // expose des métadonnées Open Graph).
                      if (_captionText(msg) case final caption?
                          when firstUrlIn(caption) != null)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: LinkPreviewCard(
                            url: firstUrlIn(caption)!,
                            isMe: isMe,
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
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
                              ? context.l10n.editedAt(_formatTime(msg.editedAt!))
                              : context.l10n.edited2,
                          child: Text(
                            context.l10n.edited,
                            style: context.text.labelSmall?.copyWith(
                              color: _bubbleMuted(isMe),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                      if (msg.isPinned && !msg.isDeleted) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin, size: 11, color: _bubbleMuted(isMe)),
                      ],
                      if (isMe && !msg.isDeleted) ...[
                        const SizedBox(width: 4),
                        _statusIcon(msg.status, deliveredAt: msg.deliveredAt, readAt: msg.readAt, retryClientId: msg.clientId),
                      ],
                    ],
                  ),
                  ),
                ],
              ),
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

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final yest = now.subtract(const Duration(days: 1));
    String label;
    if (_sameDay(date, now)) {
      label = context.l10n.today;
    } else if (_sameDay(date, yest)) {
      label = context.l10n.yesterday;
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

  // ── Journal d'appels intégré au fil (style WhatsApp, 1-1) ─────────────
  /// Date de tri d'un élément du fil (message, album ou appel).
  DateTime _feedTime(Object item) {
    if (item is LocalCall) return item.createdAt;
    if (item is ChatListSingle) return item.message.sendAt;
    if (item is ChatListAlbum) return item.messages.first.sendAt;
    return DateTime.now();
  }

  String _fmtCallDuration(int? seconds) {
    final s = seconds ?? 0;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
  }

  /// Bulle d'appel alignée selon la direction, tappable pour rappeler.
  /// Reprend exactement le style visuel des bulles de message (couleur
  /// selon expéditeur, coins arrondis avec "queue", ombre) pour que le
  /// journal d'appels s'intègre au fil comme un message classique.
  Widget _buildCallBubble(LocalCall call) {
    final outgoing = call.idCaller == _myId;
    final status = call.status;
    final answered = status == 1;
    final missed = status == 0;
    final rejected = status == 2;
    final isVideo = call.type == 1;
    final colors = context.colors;
    final titleColor = outgoing ? colors.onPrimaryContainer : colors.onSurface;
    final metaColor = outgoing
        ? colors.onPrimaryContainer.withAlpha(170)
        : colors.onSurfaceVariant;
    final bubbleColor = outgoing
        ? colors.primaryContainer.withAlpha(190)
        : context.semantic.surfaceMuted;

    final dirIcon = !answered
        ? (outgoing ? Icons.call_missed_outgoing : Icons.call_missed)
        : (outgoing ? Icons.call_made : Icons.call_received);
    final dirColor = answered ? context.semantic.success : colors.error;

    final l10n = context.l10n;
    final label = isVideo
        ? (outgoing ? l10n.videoCallOutgoing : l10n.videoCallIncoming)
        : (outgoing ? l10n.voiceCallOutgoing : l10n.voiceCallIncoming);
    final statusLabel = answered
        ? l10n.answered
        : (missed ? l10n.noAnswer2 : (rejected ? l10n.rejected : l10n.missed));

    final t = call.createdAt.toLocal();
    two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(t.hour)}:${two(t.minute)}';
    final meta = (answered && (call.duration ?? 0) > 0)
        ? '$time · ${_fmtCallDuration(call.duration)}'
        : time;

    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Material(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: outgoing ? const Radius.circular(AppRadius.lg) : Radius.zero,
              bottomRight: outgoing ? Radius.zero : const Radius.circular(AppRadius.lg),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showCallBackOptions(call),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.surface.withAlpha(190),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium
                                ?.copyWith(color: titleColor, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(dirIcon, size: 16, color: dirColor),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$statusLabel · $meta',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelSmall?.copyWith(color: metaColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyQuote(String content, bool isMe, {int? replyToID}) {
    final accent = isMe ? context.colors.onPrimary : context.colors.primary;
    final target = _messageById(replyToID);
    final thumb = target != null ? _buildReplyMediaThumb(target, size: 40) : null;
    final title = target == null
        ? null
        : (target.senderNom?.trim().isNotEmpty == true
            ? target.senderNom!.trim()
            : target.senderPseudo?.trim());
    return ReplyQuoteBar(
      accent: accent,
      title: title,
      titleColor: accent,
      body: content,
      bodyColor: _bubbleMuted(isMe),
      thumb: thumb,
      onTap: (replyToID != null && replyToID > 0)
          ? () => _scrollToReply(replyToID)
          : null,
    );
  }

  LocalMessage? _messageById(int? msgID) {
    if (msgID == null || msgID <= 0) return null;
    for (final m in _currentMessages) {
      if (m.msgID == msgID) return m;
    }
    return null;
  }

  bool _canShowReplyThumb(LocalMessage msg) =>
      !msg.isViewOnce && (msg.type == 1 || msg.type == 2 || msg.type == 4);

  Widget? _buildReplyMediaThumb(LocalMessage msg, {double size = 40}) {
    if (!_canShowReplyThumb(msg)) return null;

    final fallback = context.colors.surfaceContainerHighest;
    final Widget child;
    if (msg.type == 4) {
      final style = DocumentFileStyle.fromMessage(
        mediaName: msg.mediaName,
        mediaUrl: msg.mediaUrl,
      );
      if (style.isPdf) {
        child = FutureBuilder<Uint8List?>(
          future: PdfThumbnailService.forMessage(
            localPath: msg.localMediaPath ?? msg.pendingUploadPath,
            url: msg.mediaUrl,
          ),
          builder: (context, snap) {
            final bytes = snap.data;
            if (bytes != null) {
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: size,
                height: size,
                gaplessPlayback: true,
              );
            }
            return _replyDocBadge(style, size);
          },
        );
      } else {
        child = _replyDocBadge(style, size);
      }
    } else if (msg.type == 2) {
      child = VideoMessagePreview(
        pendingPath: msg.pendingUploadPath,
        localPath: msg.localMediaPath,
        thumbBase64: msg.mediaThumb,
        borderRadius: BorderRadius.zero,
        expandToFill: true,
        showDuration: false,
        hidePlayIcon: true,
        fallbackColor: fallback,
      );
    } else {
      final hasLocal =
          msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();
      final myId = _chat.repository.myId;
      final needsDl = msg.senderID != myId &&
          !hasLocal &&
          msg.mediaUrl != null &&
          msg.mediaUrl!.isNotEmpty;
      child = ImageMessagePreview(
        localPath: msg.localMediaPath,
        networkUrl: msg.mediaUrl,
        thumbBase64: msg.mediaThumb,
        useBlurredThumb: needsDl,
        borderRadius: BorderRadius.zero,
        expandToFill: true,
        fallbackColor: fallback,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (msg.type == 2)
            const Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 18,
                color: Color(0xE6FFFFFF),
              ),
            ),
        ],
      ),
    );
  }

  Widget _replyDocBadge(DocumentFileStyle style, double size) {
    return ColoredBox(
      color: style.color.withAlpha(28),
      child: Center(
        child: Icon(style.icon, size: size * 0.45, color: style.color),
      ),
    );
  }

  // ✓ envoyé · ✓✓ livré · ✓✓ bleu lu · horloge en attente · ! échec.
  Widget _statusIcon(
    int status, {
    DateTime? deliveredAt,
    DateTime? readAt,
    String? retryClientId,
  }) {
    return MessageStatusIcon(
      status: status,
      deliveredAt: deliveredAt,
      readAt: readAt,
      size: status == 0 ? 11 : 12,
      onBubble: true,
      timeFormatter: _formatTime,
      onRetry: status == 4 && retryClientId != null
          ? () => _chat.repository.retryMessage(retryClientId)
          : null,
    );
  }

  // Chip « Réponse à un statut » + icône (conservée, direction A).
  Widget _buildStatusReplyChip(bool isMe) {
    final fg = isMe ? context.colors.onPrimary.withAlpha(200) : context.colors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_motion, size: 12, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.statusReply,
            style: context.text.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForwardedChip(bool isMe) {
    final fg = _bubbleMuted(isMe);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forward, size: 12, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.forwarded,
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

  /// Texte affiché sous un média : légende utilisateur, hors marqueur album.
  String? _captionText(LocalMessage msg) {
    // Localisation / contact : le content est du JSON, affiché via la bulle carte.
    if (msg.type == 5 || msg.type == 7) return null;
    final content = msg.content;
    if (content == null || content.isEmpty) return null;
    if (isAlbumMarkerContent(content)) {
      return albumCaptionFromContent(content);
    }
    return content;
  }

  // ── Rendu média selon le type ──────────────────────────────────────
  Widget _buildMedia(LocalMessage msg, bool isMe) {
    if (msg.isViewOnce) return _buildViewOnceMedia(msg, isMe);
    switch (msg.type) {
      case 1:
        return _buildImageMedia(msg);
      case 2:
        return _buildVideoMedia(msg);
      case 3:
        return VoiceMessageBubble(
          messageId: msg.clientId,
          serverMsgId: msg.msgID,
          isMe: isMe,
          localPath: msg.localMediaPath,
          pendingPath: isMe ? msg.pendingUploadPath : null,
          networkUrl: msg.mediaUrl,
          durationSeconds: msg.mediaDuration ?? 0,
          foregroundColor: isMe
              ? context.colors.onPrimary
              : context.colors.primary,
          chatContext: _convId != null
              ? VoiceChatContext(
                  conversationId: _convId!,
                  title: widget.userName,
                  userId: widget.userId,
                  isGroup: widget.isGroup,
                  avatarUrl: widget.avatarUrl,
                )
              : null,
        );
      case 4:
        return _buildFileMedia(msg, isMe);
      case 5:
        return _buildLocationMedia(msg, isMe);
      case 7:
        return _buildContactMedia(msg, isMe);
      default:
        return Text(_mediaLabel(msg.type),
            style: context.text.bodyLarge?.copyWith(color: _bubbleText(isMe)));
    }
  }

  Widget _buildLocationMedia(LocalMessage msg, bool isMe) {
    final loc = LocationPayload.tryParse(msg.content);
    final muted = _bubbleMuted(isMe);

    if (loc == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off, size: 18, color: muted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.positionUnavailable,
            style: context.text.bodyMedium?.copyWith(color: muted),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openLocationInMaps(loc),
      child: LocationMessagePreview(location: loc),
    );
  }

  Widget _buildContactMedia(LocalMessage msg, bool isMe) {
    final contact = ContactPayload.tryParse(msg.content);
    final muted = _bubbleMuted(isMe);

    if (contact == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 18, color: muted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            context.l10n.contactUnavailable,
            style: context.text.bodyMedium?.copyWith(color: muted),
          ),
        ],
      );
    }

    return ContactMessagePreview(
      contact: contact,
      isMe: isMe,
      onOpenDetail: () {
        // Ne pas passer la conv courante (souvent l'expéditeur) :
        // la fiche résout la 1-1 avec le contact partagé.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContactDetailScreen(
              userId: contact.alanyaID,
              initialName: contact.displayLabel,
              initialAvatar: contact.avatarUrl ?? '',
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLocationInMaps(LocationPayload loc) async {
    try {
      final maps = loc.mapsOpenUri();
      final launched = await launchUrl(
        maps,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;

      final geo = loc.geoUri();
      final geoLaunched = await launchUrl(
        geo,
        mode: LaunchMode.externalApplication,
      );
      if (geoLaunched) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToOpenMaps)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToOpenMaps)),
      );
    }
  }

  /// Bulle d'un média à vue unique : jamais l'aperçu réel.
  /// - Destinataire non ouvert → pastille tappable qui lance l'ouverture unique.
  /// - Déjà ouvert (par moi, ou signalé « vu ») → « Ouvert », non tappable.
  /// - Expéditeur → libellé « Vue unique », non ré-ouvrable.
  Widget _buildViewOnceMedia(LocalMessage msg, bool isMe) {
    final opened = msg.viewedAt != null;
    final uploading = msg.status == 0;
    final color = _bubbleText(isMe);

    final String label;
    final IconData icon;
    if (uploading) {
      label = context.l10n.sending;
      icon = Icons.timer_outlined;
    } else if (opened) {
      label = context.l10n.viewOnceOpened;
      icon = Icons.visibility_off_outlined;
    } else {
      final kind = msg.type == 1
          ? context.l10n.photo2
          : msg.type == 2
              ? context.l10n.video2
              : msg.type == 3
                  ? context.l10n.audio2
                  : context.l10n.mediaFallback;
      label = isMe
          ? context.l10n.kindViewOnce(kind)
          : context.l10n.tapToViewKind(kind);
      icon = Icons.timer;
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color.withAlpha(opened ? 140 : 255)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            style: context.text.bodyLarge?.copyWith(
              color: color.withAlpha(opened ? 140 : 255),
              fontStyle: opened ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    // Tappable uniquement pour le destinataire, pas encore ouvert, non en envoi.
    if (opened || isMe || uploading) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openViewOnce(msg),
      child: content,
    );
  }

  /// Overlay spinner ou barre de progression pendant l'envoi d'un média.
  Widget _buildUploadProgressOverlay(LocalMessage msg) {
    if (msg.status != 0) return const SizedBox.shrink();

    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: _chat.repository.uploadProgress,
      builder: (context, progressMap, _) {
        final progress = progressMap[msg.clientId];
        return Container(
          color: AppColors.black.withValues(alpha: 0.26),
          alignment: Alignment.center,
          child: progress != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: AppColors.white.withValues(alpha: 0.25),
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${(progress * 100).round()} %',
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildImageMedia(LocalMessage msg) {
    final uploading = msg.status == 0;
    final needsDl = _needsMediaDownload(msg);
    final downloading = _mediaDownloadingIds.contains(msg.msgID);
    return GestureDetector(
      onTap: () async {
        if (needsDl) {
          final path = await _downloadReceivedMedia(msg);
          if (path == null) return;
        }
        await _openViewer(msg, isVideo: false);
      },
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ImageMessagePreview(
              localPath: _effectiveLocalPath(msg),
              networkUrl: msg.mediaUrl,
              thumbBase64: msg.mediaThumb,
              useBlurredThumb: needsDl,
              borderRadius: BorderRadius.zero,
              fallbackColor: AppColors.black.withValues(alpha: 0.26),
            ),
            if (needsDl) _mediaDownloadBadge(downloading: downloading),
            if (uploading) _buildUploadProgressOverlay(msg),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMedia(LocalMessage msg) {
    final uploading = msg.status == 0;
    final needsDl = _needsMediaDownload(msg);
    final downloading = _mediaDownloadingIds.contains(msg.msgID);
    return GestureDetector(
      onTap: () async {
        if (needsDl) {
          final path = await _downloadReceivedMedia(msg);
          if (path == null) return;
        }
        await _openViewer(msg, isVideo: true);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoMessagePreview(
            pendingPath: msg.pendingUploadPath,
            localPath: _effectiveLocalPath(msg),
            thumbBase64: msg.mediaThumb,
            durationSeconds: msg.mediaDuration,
            width: 240,
            height: 160,
            playIconSize: 30,
            playPadding: 8,
            // Masque le play natif si download requis (badge download à la place).
            hidePlayIcon: needsDl,
          ),
          if (needsDl) _mediaDownloadBadge(downloading: downloading),
          if (uploading) _buildUploadProgressOverlay(msg),
        ],
      ),
    );
  }

  DocumentFileStyle _docStyle(LocalMessage msg) => DocumentFileStyle.fromMessage(
        mediaName: msg.mediaName,
        mediaUrl: msg.mediaUrl,
      );

  bool _isPdf(LocalMessage msg) => _docStyle(msg).isPdf;

  /// Sous-titre méta fichier : pages (PDF) · taille (sans hint ouvrir/télécharger).
  String? _fileMetaLine(LocalMessage msg, DocumentFileStyle style, bool needsDl) {
    final parts = <String>[];

    if (style.isPdf && msg.mediaPageCount != null && msg.mediaPageCount! > 0) {
      parts.add(context.l10n.pdfPageCount(msg.mediaPageCount!));
    }

    final showSize = style.isPdf || needsDl;
    if (showSize) {
      var bytes = msg.mediaSize;
      if ((bytes == null || bytes <= 0) && style.isPdf && !needsDl) {
        final local = fileSizeOnDisk(msg.localMediaPath);
        if (local > 0) bytes = local;
      }
      if (bytes != null && bytes > 0) {
        parts.add(formatFileSize(bytes));
      }
    }

    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// Sous-titre bulle fichier classique : méta + hint télécharger/ouvrir.
  String? _fileMediaSubtitle(LocalMessage msg, DocumentFileStyle style, bool needsDl) {
    final parts = <String>[];
    final meta = _fileMetaLine(msg, style, needsDl);
    if (meta != null) parts.add(meta);

    if (msg.status != 0) {
      parts.add(needsDl ? context.l10n.tapToDownload : style.openHint);
    }

    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Widget _buildFileMedia(LocalMessage msg, bool isMe) {
    final style = _docStyle(msg);
    final needsDl = _needsMediaDownload(msg);
    final localPath = msg.localMediaPath ?? msg.pendingUploadPath;
    final hasLocal = localPath != null && File(localPath).existsSync();
    final hasThumb =
        msg.mediaThumb != null && msg.mediaThumb!.isNotEmpty;
    // Layout A (carte document) dès qu'une source d'aperçu est dispo.
    final showPdfCard =
        style.isPdf && (hasLocal || hasThumb || !needsDl);

    if (showPdfCard) {
      return _buildPdfFileCard(
        msg,
        isMe: isMe,
        style: style,
        needsDl: needsDl,
        blurThumb: needsDl && !hasLocal,
      );
    }

    return _buildGenericFileRow(msg, isMe: isMe, style: style, needsDl: needsDl);
  }

  /// Fichier non-PDF (ou PDF sans aperçu) : ligne icône + nom + sous-titre.
  Widget _buildGenericFileRow(
    LocalMessage msg, {
    required bool isMe,
    required DocumentFileStyle style,
    required bool needsDl,
  }) {
    final color = isMe ? context.colors.onPrimary : context.colors.primary;
    final iconColor = msg.status != 0 ? style.color : color;
    final downloading = _mediaDownloadingIds.contains(msg.msgID);
    final fileSubtitle = _fileMediaSubtitle(msg, style, needsDl);

    return GestureDetector(
      onTap: msg.status == 0 ? null : () => _openFile(msg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needsDl)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: downloading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: color,
                      ),
                    )
                  : Icon(Icons.download_rounded, color: color, size: 26),
            )
          else
            Icon(
              msg.status == 0 ? Icons.upload_file : style.icon,
              color: iconColor,
            ),
          if (!needsDl) const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.mediaName ?? context.l10n.file2,
                  style: context.text.bodyLarge?.copyWith(
                    color: _bubbleText(isMe),
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSubtitle != null)
                  Text(
                    fileSubtitle,
                    style: context.text.labelSmall?.copyWith(
                      color: _bubbleText(isMe).withAlpha(170),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Layout A — carte document (style WhatsApp) :
  /// preview page 1 coupée en haut + badge PDF, pied icône + nom + méta.
  Widget _buildPdfFileCard(
    LocalMessage msg, {
    required bool isMe,
    required DocumentFileStyle style,
    required bool needsDl,
    required bool blurThumb,
  }) {
    final textColor = _bubbleText(isMe);
    final accent = isMe ? context.colors.onPrimary : context.colors.primary;
    final downloading = _mediaDownloadingIds.contains(msg.msgID);
    final uploading = msg.status == 0;
    final meta = _fileMetaLine(msg, style, needsDl);
    final hint = uploading
        ? null
        : (needsDl ? context.l10n.tapToDownload : style.openHint);
    final subtitleParts = <String>[
      if (meta != null) meta,
      if (hint != null) hint,
    ];
    final subtitle =
        subtitleParts.isEmpty ? null : subtitleParts.join(' · ');

    return GestureDetector(
      onTap: uploading ? null : () => _openFile(msg),
      child: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPdfPreviewBanner(
              msg,
              style: style,
              blur: blurThumb,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _pdfFooterIcon(
                  style: style,
                  uploading: uploading,
                  needsDl: needsDl,
                  downloading: downloading,
                  accent: accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg.mediaName ?? context.l10n.file2,
                        style: context.text.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: context.text.labelSmall?.copyWith(
                            color: textColor.withAlpha(170),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfFooterIcon({
    required DocumentFileStyle style,
    required bool uploading,
    required bool needsDl,
    required bool downloading,
    required Color accent,
  }) {
    if (uploading || (needsDl && downloading)) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: accent,
          ),
        ),
      );
    }
    if (needsDl) {
      return Icon(Icons.download_rounded, color: accent, size: 28);
    }
    return Icon(style.icon, color: style.color, size: 28);
  }

  Widget _pdfTypeBadge(DocumentFileStyle style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        style.extension,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Bandeau preview : haut de page (crop), badge PDF en overlay.
  Widget _buildPdfPreviewBanner(
    LocalMessage msg, {
    required DocumentFileStyle style,
    bool blur = false,
  }) {
    const height = 148.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brSm,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Uint8List?>(
                future: PdfThumbnailService.forMessage(
                  localPath: msg.localMediaPath ?? msg.pendingUploadPath,
                  url: blur ? null : msg.mediaUrl,
                  thumbBase64: msg.mediaThumb,
                ),
                builder: (context, snap) {
                  final bytes = snap.data;
                  if (bytes == null) {
                    return ColoredBox(
                      color: context.colors.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.picture_as_pdf,
                          size: 36,
                          color: style.color,
                        ),
                      ),
                    );
                  }
                  Widget image = Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    width: double.infinity,
                    height: height,
                    gaplessPlayback: true,
                  );
                  if (blur) {
                    image = ImageFiltered(
                      imageFilter:
                          ui.ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                      child: image,
                    );
                  }
                  return ColoredBox(color: Colors.white, child: image);
                },
              ),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: _pdfTypeBadge(style),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumBubble(List<LocalMessage> items, bool isMe) {
    final sorted = List<LocalMessage>.from(items)
      ..sort((a, b) {
        final ma = parseAlbumMarker(a.content);
        final mb = parseAlbumMarker(b.content);
        return (ma?.index ?? 0).compareTo(mb?.index ?? 0);
      });
    final first = sorted.first;
    final last = sorted.last;
    final selected = _isAlbumPartiallySelected(sorted);
    final selectable = sorted.any(_isSelectableMessage);
    final anyDeleted = sorted.any((m) => m.isDeleted);
    // Pire statut de l'album (min) : pas de ✓✓ bleu tant que tous ne le sont pas.
    final worstStatus = sorted.map((m) => m.status).reduce((a, b) => a < b ? a : b);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: isMe ? const Radius.circular(AppRadius.lg) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(AppRadius.lg),
    );

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (widget.isGroup && !isMe)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.xs),
            child: Text(
              first.senderNom ?? first.senderPseudo ?? (AppLocalizations.of(context)?.unknownSender ?? context.l10n.unknownSender),
              style: context.text.labelSmall?.copyWith(color: context.colors.primary),
            ),
          ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: _wrapSelectableBubble(
            isMe: isMe,
            selected: selected,
            selectable: _selectionMode ? false : selectable,
            onLongPress: () => _showAlbumMenu(sorted, isMe),
            onTap: _selectionMode ? null : () => _toggleSelection(sorted.first),
            bubble: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: _bubbleDecoration(
                isMe: isMe,
                selected: selected,
                baseColor: isMe ? context.colors.primary : context.colors.surface,
                borderRadius: borderRadius,
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (first.isForwarded) _buildForwardedChip(isMe),
                  if (anyDeleted)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 14, color: _bubbleMuted(isMe)),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          context.l10n.thisMessageWasDeleted,
                          style: context.text.bodyMedium?.copyWith(
                            color: _bubbleMuted(isMe),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildAlbumGrid(sorted, isMe),
                    if (albumCaptionFromMessages(sorted) case final caption?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm,
                          AppSpacing.sm,
                          AppSpacing.sm,
                          0,
                        ),
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: parseRichSpans(
                                caption,
                                (context.text.bodyLarge ?? const TextStyle())
                                    .copyWith(color: _bubbleText(isMe)),
                                linkColor: isMe
                                    ? context.colors.onPrimary
                                    : context.colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(last.sendAt),
                        style: context.text.labelSmall?.copyWith(
                          color: _bubbleMuted(isMe),
                          fontSize: 10,
                        ),
                      ),
                      if (isMe && !anyDeleted) ...[
                        const SizedBox(width: 4),
                        _statusIcon(
                          worstStatus,
                          deliveredAt: last.deliveredAt,
                          readAt: last.readAt,
                          retryClientId: sorted
                              .where((m) => m.status == 4)
                              .map((m) => m.clientId)
                              .firstOrNull,
                        ),
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

  Widget _buildAlbumGrid(List<LocalMessage> items, bool isMe) {
    final count = items.length;
    const gap = 2.0;
    const cellSize = 110.0;
    final gridWidth = count >= 2 ? cellSize * 2 + gap : cellSize;

    if (count == 2) {
      return SizedBox(
        width: gridWidth,
        height: cellSize,
        child: Row(
          children: [
            Expanded(child: _albumCell(items[0], isMe, 0, items)),
            const SizedBox(width: gap),
            Expanded(child: _albumCell(items[1], isMe, 1, items)),
          ],
        ),
      );
    }

    if (count == 3) {
      return SizedBox(
        width: gridWidth,
        height: cellSize * 2 + gap,
        child: Column(
          children: [
            SizedBox(
              height: cellSize,
              child: Row(
                children: [
                  Expanded(child: _albumCell(items[0], isMe, 0, items)),
                  const SizedBox(width: gap),
                  Expanded(child: _albumCell(items[1], isMe, 1, items)),
                ],
              ),
            ),
            const SizedBox(height: gap),
            SizedBox(
              height: cellSize,
              child: _albumCell(items[2], isMe, 2, items),
            ),
          ],
        ),
      );
    }

    // 4+ : grille 2×2, overlay +N sur la 4e si > 4
    final displayCount = count > 4 ? 4 : count;
    return SizedBox(
      width: gridWidth,
      height: cellSize * 2 + gap,
      child: Column(
        children: [
          SizedBox(
            height: cellSize,
            child: Row(
              children: [
                Expanded(child: _albumCell(items[0], isMe, 0, items)),
                const SizedBox(width: gap),
                Expanded(child: _albumCell(items[1], isMe, 1, items)),
              ],
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: cellSize,
            child: Row(
              children: [
                Expanded(
                  child: displayCount > 2
                      ? _albumCell(items[2], isMe, 2, items)
                      : const SizedBox.shrink(),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: displayCount > 3
                      ? _albumCell(
                          items[3],
                          isMe,
                          3,
                          items,
                          overlayExtra: count > 4 ? count - 4 : null,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _albumCellSelectionBadge(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? context.colors.primary : AppColors.black.withValues(alpha: 0.45),
        border: Border.all(color: AppColors.white, width: 2),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: AppColors.white)
          : null,
    );
  }

  Widget _albumCell(
    LocalMessage msg,
    bool isMe,
    int index,
    List<LocalMessage> all, {
    int? overlayExtra,
  }) {
    final uploading = msg.status == 0;
    final isVideo = msg.type == 2;
    final needsDl = _needsMediaDownload(msg);
    final downloading = _mediaDownloadingIds.contains(msg.msgID);
    final cellSelected = _isMessageSelected(msg);
    final cellSelectable = _isSelectableMessage(msg);

    return GestureDetector(
      onTap: () async {
        if (_selectionMode) {
          if (!cellSelectable) return;
          if (overlayExtra != null && overlayExtra > 0) {
            _openAlbumMediaList(all, initialIndex: index);
            return;
          }
          _toggleSelection(msg);
          return;
        }
        if (needsDl) {
          final path = await _downloadReceivedMedia(msg);
          if (path == null) return;
        }
        if (!mounted) return;
        _openAlbumMediaList(all, initialIndex: index);
      },
      onLongPress: () {
        if (_selectionMode) {
          if (cellSelectable) _toggleSelection(msg);
          return;
        }
        _showMessageMenu(msg, isMe);
      },
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              VideoMessagePreview(
                pendingPath: msg.pendingUploadPath,
                localPath: _effectiveLocalPath(msg),
                thumbBase64: msg.mediaThumb,
                durationSeconds: msg.mediaDuration,
                playIconSize: 24,
                playPadding: 6,
                borderRadius: BorderRadius.zero,
                expandToFill: true,
                hidePlayIcon: needsDl,
              )
            else
              ImageMessagePreview(
                localPath: _effectiveLocalPath(msg),
                networkUrl: msg.mediaUrl,
                thumbBase64: msg.mediaThumb,
                useBlurredThumb: needsDl,
                borderRadius: BorderRadius.zero,
                expandToFill: true,
                fallbackColor: context.semantic.surfaceMuted,
              ),
            if (needsDl)
              Center(child: _mediaDownloadBadge(downloading: downloading)),
            if (uploading) _buildUploadProgressOverlay(msg),
            if (_selectionMode && cellSelected)
              Container(
                color: context.colors.primary.withValues(alpha: 0.28),
              ),
            if (overlayExtra != null && overlayExtra > 0 && !_selectionMode)
              Container(
                color: AppColors.black.withValues(alpha: 0.54),
                alignment: Alignment.center,
                child: Text(
                  '+$overlayExtra',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_selectionMode && cellSelectable)
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: _albumCellSelectionBadge(cellSelected),
              ),
          ],
        ),
      ),
    );
  }
}
