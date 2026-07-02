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

  /// Bannière en haut du chat listant le message épinglé le plus récent.
  /// Tap → défile jusqu'au message. Bouton croix → détache.
  /// Barre compacte des messages épinglés (façon Telegram) : une seule ligne,
  /// un compteur « i/N », un appui qui défile vers l'épingle courante puis passe
  /// à la suivante.
  Widget _buildPinnedBanner() {
    final convId = widget.conversationId;
    if (convId == null) return const SizedBox.shrink();
    final colors = context.colors;
    return StreamBuilder<List<LocalMessage>>(
      stream: _chat.repository.watchPinnedMessages(convId),
      builder: (context, snap) {
        final pinned = snap.data ?? const <LocalMessage>[];
        if (pinned.isEmpty) return const SizedBox.shrink();

        // Ordre chronologique stable pour un défilement cohérent.
        final list = [...pinned]..sort((a, b) => a.sendAt.compareTo(b.sendAt));
        final idx = _pinnedIndex % list.length;
        final msg = list[idx];

        return Material(
          color: context.semantic.brandContainer,
          child: InkWell(
            onTap: () {
              _scrollToReply(msg.msgID);
              if (list.length > 1) {
                rebuild(() => _pinnedIndex = (idx + 1) % list.length);
              }
            },
            onLongPress: list.length > 1 ? () => _showPinnedList(convId) : null,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: colors.primary, width: 3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.push_pin, size: 15, color: colors.primary),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      _previewOf(msg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ),
                  if (list.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Text(
                        '${idx + 1}/${list.length}',
                        style: context.text.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () => _togglePin(msg),
                    borderRadius: AppRadius.brPill,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.push_pin_outlined, size: 17, color: colors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Feuille listant tous les messages épinglés : défiler vers l'un, ou en
  /// retirer un précis. Réactive : se met à jour en direct et se ferme à vide.
  void _showPinnedList(int convId) {
    showAppBottomSheet(
      context: context,
      builder: (_) => AppBottomSheet(
        child: StreamBuilder<List<LocalMessage>>(
          stream: _chat.repository.watchPinnedMessages(convId),
          builder: (context, snap) {
            final pinned = snap.data ?? const <LocalMessage>[];
            if (pinned.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) Navigator.pop(context);
              });
              return const SizedBox.shrink();
            }
            final list = [...pinned]..sort((a, b) => a.sendAt.compareTo(b.sendAt));
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text('Messages épinglés (${list.length})',
                      style: context.text.titleSmall),
                ),
                ...list.map((m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.push_pin, size: 18, color: context.colors.primary),
                      title: Text(_previewOf(m),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 20, color: context.colors.onSurfaceVariant),
                        onPressed: () => _togglePin(m),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToReply(m.msgID);
                      },
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Mise en forme du texte (marqueurs inline) ──────────────────────
  // Bascule l'affichage de la barre de formatage (B, I, U, S, manuscrit).
  void _toggleFormatBar() {
    rebuild(() => _showFormatBar = !_showFormatBar);
    if (_showFormatBar) _inputFocus.requestFocus();
  }

  /// Barre de boutons de mise en forme, posée au-dessus de la capsule.
  Widget _buildFormatBar() {
    final colors = context.colors;
    Widget btn(IconData icon, String marker, String tip) => Tooltip(
          message: tip,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(icon, size: AppIconSize.sm + 2, color: colors.onSurfaceVariant),
            onPressed: () => _applyFormat(marker),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, 6),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadius.brPill,
          boxShadow: AppShadows.subtle,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(Icons.format_bold, '*', 'Gras'),
            btn(Icons.format_italic, '_', 'Italique'),
            btn(Icons.format_underlined, '=', 'Souligné'),
            btn(Icons.strikethrough_s, '~', 'Barré'),
            btn(Icons.gesture, '#', 'Manuscrit'),
          ],
        ),
      ),
    );
  }

  /// Applique un marqueur à la sélection courante. Si rien n'est sélectionné,
  /// insère une paire de marqueurs et place le curseur au milieu pour que
  /// l'utilisateur tape directement le texte stylé.
  void _applyFormat(String marker) {
    final text = _messageController.text;
    final sel = _messageController.selection;

    String newText;
    int caret;
    if (!sel.isValid) {
      newText = '$text$marker$marker';
      caret = newText.length - marker.length;
    } else if (sel.isCollapsed) {
      final pos = sel.start;
      newText = text.replaceRange(pos, pos, '$marker$marker');
      caret = pos + marker.length;
    } else {
      final selected = text.substring(sel.start, sel.end);
      newText = text.replaceRange(sel.start, sel.end, '$marker$selected$marker');
      caret = sel.end + marker.length * 2;
    }

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
    if (!_hasText) rebuild(() => _hasText = true);
    _inputFocus.requestFocus();
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
                  icon: Icon(
                    Icons.text_format,
                    color: _showFormatBar ? colors.primary : colors.onSurfaceVariant,
                    size: AppIconSize.md,
                  ),
                  onPressed: _toggleFormatBar,
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
                    _voiceViewOnce ? 'Vocal · vue unique' : 'Enregistrement…',
                    style: context.text.bodySmall?.copyWith(
                      color: _voiceViewOnce ? colors.primary : colors.error,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!widget.isGroup)
                  Tooltip(
                    message: 'Vue unique',
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _voiceViewOnce ? Icons.timer : Icons.timer_outlined,
                        color: _voiceViewOnce ? colors.primary : colors.onSurfaceVariant,
                        size: AppIconSize.md,
                      ),
                      onPressed: () => rebuild(() => _voiceViewOnce = !_voiceViewOnce),
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
