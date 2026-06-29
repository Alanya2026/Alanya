// Rendu des bulles de message et des médias. part of chat_detail_screen.dart.
part of '../chat_detail_screen.dart';

extension _ChatBubbles on _ChatDetailScreenState {
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
                border: _highlightMsgId == msg.msgID
                    ? Border.all(
                        color: isMe ? context.colors.onPrimary : context.colors.primary,
                        width: 2,
                      )
                    : null,
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (msg.isStatusReply != 0)
                    _buildStatusReplyChip(isMe),
                  if (msg.isForwarded)
                    _buildForwardedChip(isMe),
                  if (msg.replyToContent != null &&
                      msg.replyToContent!.isNotEmpty &&
                      msg.replyToID != null &&
                      msg.replyToID! > 0)
                    _buildReplyQuote(msg.replyToContent!, isMe, replyToID: msg.replyToID!),
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

  Widget _buildReplyQuote(String content, bool isMe, {required int replyToID}) {
    final accent = isMe ? context.colors.onPrimary : context.colors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _scrollToReply(replyToID),
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
}
