// Barre de saisie, sélecteur d'emoji, bandeau de réponse, sous-titre groupe.
// part of chat_detail_screen.dart.
part of '../chat_detail_screen.dart';

extension _ChatInput on _ChatDetailScreenState {
  Widget _buildBlockedBanner() {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: context.semantic.brandContainer,
      child: Row(
        children: [
          Icon(Icons.block, size: 18, color: colors.onSurfaceVariant),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              'Vous avez bloqué cet utilisateur',
              style: context.text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: _unblockContact,
            child: const Text('Débloquer'),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBanner() {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 0),
      color: context.semantic.brandContainer,
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
            onPressed: () => rebuild(() => _replyTo = null),
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
          if (!_hasText) rebuild(() => _hasText = true);
        },
        config: const Config(height: 280),
      ),
    );
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

  Widget _buildInputBar() {
    if (_inputBlocked) {
      return const SafeArea(top: false, child: SizedBox.shrink());
    }
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
                      if (_showEmoji) rebuild(() => _showEmoji = false);
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
