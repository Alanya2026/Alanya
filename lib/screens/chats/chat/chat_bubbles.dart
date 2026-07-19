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
          color: selected ? context.colors.primary : Colors.transparent,
          border: Border.all(
            color: selected
                ? context.colors.primary
                : context.colors.outline,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
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
              msg.senderNom ?? msg.senderPseudo ?? 'Unknown',
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
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg.isStatusReply != 0)
                    _buildStatusReplyChip(isMe),
                  if (msg.isForwarded)
                    _buildForwardedChip(isMe),
                  if (msg.replyToContent != null &&
                      msg.replyToContent!.isNotEmpty)
                    _buildReplyQuote(
                      msg.replyToContent!,
                      isMe,
                      replyToID: msg.replyToID,
                    ),
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
                      if (msg.isPinned && !msg.isDeleted) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.push_pin, size: 11, color: _bubbleMuted(isMe)),
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

    final kind = isVideo ? 'Appel vidéo' : 'Appel vocal';
    final direction = outgoing ? 'sortant' : 'entrant';
    final statusLabel = answered
        ? 'Répondu'
        : (missed ? 'Sans réponse' : (rejected ? 'Rejeté' : 'Manqué'));
    final label = '$kind $direction';

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (replyToID != null && replyToID > 0)
            ? () => _scrollToReply(replyToID)
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
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
        ),
      ),
    );
  }

  // ✓ envoyé · ✓✓ livré · ✓✓ bleu lu · horloge en attente · ! échec.
  Widget _statusIcon(int status, {DateTime? deliveredAt, DateTime? readAt}) {
    return MessageStatusIcon(
      status: status,
      deliveredAt: deliveredAt,
      readAt: readAt,
      size: status == 0 ? 11 : 12,
      onBubble: true,
      timeFormatter: _formatTime,
    );
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
            'Transféré',
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
    // Localisation : le content est du JSON, affiché via la bulle carte.
    if (msg.type == 5) return null;
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
      default:
        return Text(_mediaLabel(msg.type),
            style: context.text.bodyLarge?.copyWith(color: _bubbleText(isMe)));
    }
  }

  Widget _buildLocationMedia(LocalMessage msg, bool isMe) {
    final loc = LocationPayload.tryParse(msg.content);
    final label = loc?.displayLabel ?? 'Position';
    final textColor = _bubbleText(isMe);
    final muted = _bubbleMuted(isMe);

    return GestureDetector(
      onTap: loc == null ? null : () => _openLocationInMaps(loc),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 240,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (loc != null)
                    CachedNetworkImage(
                      imageUrl: loc.staticMapUrl(width: 480, height: 280),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => ColoredBox(
                        color: context.semantic.surfaceMuted,
                        child: Center(
                          child: Icon(Icons.map_outlined, color: muted),
                        ),
                      ),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: context.semantic.surfaceMuted,
                        child: Center(
                          child: Icon(Icons.map_outlined, color: muted, size: 36),
                        ),
                      ),
                    )
                  else
                    ColoredBox(
                      color: context.semantic.surfaceMuted,
                      child: Center(
                        child: Icon(Icons.location_off, color: muted, size: 36),
                      ),
                    ),
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.location_on,
                      size: 36,
                      color: context.colors.primary,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black45),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 16, color: textColor),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (loc?.address != null &&
              loc!.address!.isNotEmpty &&
              loc.address != label)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                loc.address!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openLocationInMaps(LocationPayload loc) async {
    try {
      final maps = loc.mapsOpenUri();
      if (await canLaunchUrl(maps)) {
        await launchUrl(maps, mode: LaunchMode.externalApplication);
        return;
      }
      final geo = loc.geoUri();
      if (await canLaunchUrl(geo)) {
        await launchUrl(geo, mode: LaunchMode.externalApplication);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Maps')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Maps')),
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
      label = 'Envoi…';
      icon = Icons.timer_outlined;
    } else if (opened) {
      label = 'Ouvert';
      icon = Icons.visibility_off_outlined;
    } else {
      final kind = msg.type == 1
          ? 'Photo'
          : msg.type == 2
              ? 'Vidéo'
              : msg.type == 3
                  ? 'Audio'
                  : 'Média';
      label = isMe ? '$kind · Vue unique' : '$kind · Appuyer pour voir';
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
          color: Colors.black26,
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
                          fontSize: 11,
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
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
              child: _hasLocal(msg)
                  ? Image.file(File(msg.localMediaPath!), fit: BoxFit.cover)
                  : (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty)
                      // Preview réseau (cache UI) même si auto-download OFF —
                      // ce n'est PAS le téléchargement Alanya / localMediaPath.
                      ? CachedNetworkImage(
                          imageUrl: msg.mediaUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(
                              height: 160,
                              width: 200,
                              child: Center(child: CircularProgressIndicator())),
                          errorWidget: (_, __, ___) => Icon(
                              Icons.broken_image,
                              size: 48,
                              color: context.colors.onSurfaceVariant),
                        )
                      : Container(
                          height: 160,
                          width: 200,
                          color: Colors.black26,
                          child: Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
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
            localPath: msg.localMediaPath,
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

  Widget _buildFileMedia(LocalMessage msg, bool isMe) {
    final style = _docStyle(msg);
    final color = isMe ? context.colors.onPrimary : context.colors.primary;
    final iconColor = msg.status != 0 ? style.color : color;
    final needsDl = _needsMediaDownload(msg);
    final downloading = _mediaDownloadingIds.contains(msg.msgID);

    final row = Row(
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
                msg.mediaName ?? 'Fichier',
                style: context.text.bodyLarge?.copyWith(
                  color: _bubbleText(isMe),
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (msg.status != 0)
                Text(
                  needsDl ? 'Appuyer pour télécharger' : style.openHint,
                  style: context.text.labelSmall?.copyWith(
                    color: _bubbleText(isMe).withAlpha(170),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      onTap: msg.status == 0 ? null : () => _openFile(msg),
      child: (style.isPdf && msg.status != 0 && !needsDl)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPdfThumbnail(msg),
                row,
              ],
            )
          : row,
    );
  }

  /// Vignette de la première page du PDF (si générable), au-dessus de la carte.
  /// Tant qu'elle n'est pas prête (ou en cas d'échec), rien ne s'affiche.
  Widget _buildPdfThumbnail(LocalMessage msg) {
    return FutureBuilder<Uint8List?>(
      future: PdfThumbnailService.forMessage(
        localPath: msg.localMediaPath,
        url: msg.mediaUrl,
      ),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: AppRadius.brSm,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240, maxHeight: 300),
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
        );
      },
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
    final selected = _isMessageSelected(first);
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
              first.senderNom ?? first.senderPseudo ?? 'Unknown',
              style: context.text.labelSmall?.copyWith(color: context.colors.primary),
            ),
          ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: _wrapSelectableBubble(
            isMe: isMe,
            selected: selected,
            selectable: selectable,
            onLongPress: () => _showAlbumMenu(sorted, isMe),
            onTap: () => _toggleSelection(sorted.first),
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
                          'Ce message a été supprimé',
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

    return GestureDetector(
      onTap: () async {
        if (needsDl) {
          final path = await _downloadReceivedMedia(msg);
          if (path == null) return;
        }
        if (!mounted) return;
        _openAlbumMediaList(all, initialIndex: index);
      },
      onLongPress: () => _showMessageMenu(msg, isMe),
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              VideoMessagePreview(
                pendingPath: msg.pendingUploadPath,
                localPath: msg.localMediaPath,
                thumbBase64: msg.mediaThumb,
                durationSeconds: msg.mediaDuration,
                playIconSize: 24,
                playPadding: 6,
                borderRadius: BorderRadius.zero,
                expandToFill: true,
                hidePlayIcon: needsDl,
              )
            else
              _hasLocal(msg)
                  ? Image.file(File(msg.localMediaPath!), fit: BoxFit.cover)
                  : (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: msg.mediaUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: context.semantic.surfaceMuted),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.broken_image,
                            color: context.colors.onSurfaceVariant,
                          ),
                        )
                      : ColoredBox(
                          color: context.semantic.surfaceMuted,
                          child: Icon(
                            Icons.image_outlined,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
            if (needsDl)
              Center(child: _mediaDownloadBadge(downloading: downloading)),
            if (uploading) _buildUploadProgressOverlay(msg),
            if (overlayExtra != null && overlayExtra > 0)
              Container(
                color: Colors.black54,
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
          ],
        ),
      ),
    );
  }
}
