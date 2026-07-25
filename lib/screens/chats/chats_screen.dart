import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_hidden_store.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/rich_text_parser.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../talky_models.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/common/common.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/status_ringed_avatar.dart';
import '../../providers/status_provider.dart';
import '../status/status_viewer_screen.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/chat/message_status_icon.dart';
import '../home/glass_nav_bar.dart' show kGlassNavBarSpace;
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _search = '';
  String _filter = 'all'; // 'all', 'discussions', 'groups', 'unread', 'archived'
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _selectionMode = false;
  final Set<int> _selectedConversationIDs = {};
  List<LocalConversation> _latestConversations = const [];
  /// True tant que le premier sync serveur (via [ChatProvider.bind]) n'a
  /// pas fini. Drift émet `[]` immédiatement (active) → sans ce flag,
  /// l'empty state s'affiche pendant que le sync HTTP tourne encore.
  bool _awaitingInitialConversations = true;
  ChatProvider? _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (_chatProvider!.initialSyncComplete) {
      _awaitingInitialConversations = false;
    } else {
      _chatProvider!.addListener(_onChatProviderChanged);
    }
    // Rafraîchit les statuts pour que les anneaux autour des avatars (1v1)
    // reflètent l'état courant dès l'ouverture de la liste des chats.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StatusProvider>().refresh();
    });
  }

  void _onChatProviderChanged() {
    final chat = _chatProvider;
    if (chat == null) return;
    if (!mounted) {
      chat.removeListener(_onChatProviderChanged);
      return;
    }
    if (!chat.initialSyncComplete) return;
    chat.removeListener(_onChatProviderChanged);
    setState(() => _awaitingInitialConversations = false);
  }

  @override
  void dispose() {
    _chatProvider?.removeListener(_onChatProviderChanged);
    _chatProvider = null;
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _search = '';
      }
    });
  }

  void _enterSelectionMode(LocalConversation conv) {
    setState(() {
      _selectionMode = true;
      _selectedConversationIDs
        ..clear()
        ..add(conv.conversID);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedConversationIDs.clear();
    });
  }

  void _toggleConversationSelection(LocalConversation conv) {
    setState(() {
      if (_selectedConversationIDs.contains(conv.conversID)) {
        _selectedConversationIDs.remove(conv.conversID);
        if (_selectedConversationIDs.isEmpty) _selectionMode = false;
      } else {
        _selectedConversationIDs.add(conv.conversID);
      }
    });
  }

  List<LocalConversation> _selectedConversations() {
    if (_selectedConversationIDs.isEmpty) return const [];
    return _latestConversations
        .where((c) => _selectedConversationIDs.contains(c.conversID))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);
    // Lecture réactive de l'ID courant : si AuthProvider notifie un changement
    // (ex: hydratation tardive du cache), le rendu reconnaît immédiatement
    // qui est « moi » dans la liste des conversations.
    final myId = context.select<AuthProvider, int>(
      (a) => a.currentUser?.alanyaID ?? 0,
    );
    // Réactif : si une conv est masquée/affichée localement, la liste se met
    // à jour automatiquement.
    final hidden = context.watch<LocalHiddenStore>();

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        title: Text(
          _selectionMode
              ? context.l10n.selectedFeminineCount(_selectedConversationIDs.length)
              : context.l10n.chats,
          style: _selectionMode
              ? context.text.titleLarge?.copyWith(fontWeight: FontWeight.w600)
              : context.text.headlineLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_selectionMode) ...[
            Builder(
              builder: (_) {
                final selected = _selectedConversations();
                final hasSelection = selected.isNotEmpty;
                final pinnedCount = selected.where((c) => c.isPinned).length;
                final archivedCount = selected.where((c) => c.isArchived).length;
                final mixedPinned =
                    hasSelection && pinnedCount > 0 && pinnedCount < selected.length;
                final mixedArchived = hasSelection &&
                    archivedCount > 0 &&
                    archivedCount < selected.length;
                final hasConflict = mixedPinned || mixedArchived;
                final allPinned = hasSelection && pinnedCount == selected.length;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasConflict) ...[
                      if (_filter == 'archived')
                        IconButton(
                          tooltip: context.l10n.unarchive,
                          icon: const Icon(Icons.unarchive_outlined),
                          onPressed: () => _applyBatchArchive(false),
                        )
                      else ...[
                        IconButton(
                          tooltip: allPinned ? context.l10n.unpin : context.l10n.pin,
                          icon: Icon(
                            allPinned ? Icons.push_pin_outlined : Icons.push_pin,
                          ),
                          onPressed: () => _applyBatchPin(!allPinned),
                        ),
                        IconButton(
                          tooltip: context.l10n.archiveAction,
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => _applyBatchArchive(true),
                        ),
                      ],
                    ],
                    IconButton(
                      tooltip: context.l10n.commonDelete,
                      icon: Icon(Icons.delete_outline, color: context.colors.error),
                      onPressed: _applyBatchDelete,
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            IconButton(
              icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
              tooltip: _searchOpen ? context.l10n.closeSearch : context.l10n.commonSearch,
              onPressed: _toggleSearch,
            ),
            IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
          ],
        ],
      ),
      body: Column(
        children: [
          AnimatedSearchBar(
            open: _searchOpen,
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            onClose: _toggleSearch,
          ),
          // Filtres
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _buildFilterChip(context.l10n.allFilter, 'all', Icons.apps_rounded),
                AppSpacing.hGapSm,
                _buildFilterChip(context.l10n.chats, 'discussions', Icons.person_outline),
                AppSpacing.hGapSm,
                _buildFilterChip(context.l10n.groupsFilter, 'groups', Icons.groups_rounded),
                AppSpacing.hGapSm,
                _buildFilterChip(context.l10n.unread, 'unread', Icons.mark_email_unread_outlined),
                AppSpacing.hGapSm,
                _buildFilterChip(context.l10n.archived, 'archived', Icons.archive_outlined),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LocalConversation>>(
              stream: chat.watchConversations(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const [];
                _latestConversations = all;
                // Toujours masquer les conversations supprimées localement
                // (jusqu'à ce qu'un nouveau message les fasse réapparaître).
                var convs = all
                    .where((c) => !hidden.isConversationHidden(c.conversID, c.lastMessageAt))
                    .toList();
                if (_search.isNotEmpty) {
                  convs = convs
                      .where((c) =>
                          conversationDisplayName(c, myId).toLowerCase().contains(_search))
                      .toList();
                }
                // Appliquer le filtre (chips). Le chip « Archivés » est seul à
                // afficher les conv archivées ; les autres chips les excluent.
                convs = _applyFilter(convs);

                // Skeleton seulement si le cache local est vide ET que le
                // premier sync n'a pas encore répondu. Si Drift a déjà des
                // données, on affiche la liste tout de suite (cache-first).
                if (all.isEmpty &&
                    (_awaitingInitialConversations ||
                        snapshot.connectionState == ConnectionState.waiting)) {
                  return const ConversationSkeletonList();
                }
                if (convs.isEmpty) {
                  return EmptyState(
                    icon: _filter == 'archived'
                        ? Icons.archive_outlined
                        : Icons.chat_bubble_outline_rounded,
                    title: _search.isNotEmpty
                        ? context.l10n.noResults
                        : _filter == 'archived'
                            ? context.l10n.noArchivedConversations
                            : context.l10n.noChats,
                    message: _search.isNotEmpty
                        ? context.l10n.tryAnotherSearchTerm
                        : context.l10n.startANewChatWithThe,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => chat.refreshConversations(force: true),
                  child: SlidableAutoCloseBehavior(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
                      itemCount: convs.length,
                      itemBuilder: (context, index) {
                        final conv = convs[index];
                        final tile = _buildTile(context, chat, conv, myId);
                        if (_selectionMode) return tile;
                        return SwipeableConversationTile(
                          conversation: conv,
                          enabled: !_selectionMode,
                          onArchive: () => _swipeArchive(chat, conv),
                          onPin: () => _swipePin(chat, conv),
                          onDelete: () => _swipeDelete(chat, conv),
                          onMarkRead: () => _swipeMarkRead(chat, conv),
                          child: tile,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<ConnectivityProvider>(
        builder: (context, conn, _) {
          if (_selectionMode) return const SizedBox.shrink();
          final online = conn.isOnline;
          return FloatingActionButton(
            onPressed: online
                ? () async {
                    final result = await Navigator.push<User>(
                      context,
                      MaterialPageRoute(builder: (_) => const NewChatScreen()),
                    );
                    if (result != null && mounted) {
                      _openChatWithUser(result);
                    }
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.l10n.newChatUnavailableOffline),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
            backgroundColor: online ? null : context.colors.outlineVariant,
            child: const Icon(Icons.chat_rounded),
          );
        },
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, ChatProvider chat, LocalConversation conv, int myId) {
    final other = otherParticipant(conv, myId);
    final displayName = conversationDisplayName(conv, myId);
    final displayAvatar = conversationDisplayAvatar(conv, myId);
    final otherId = conversationOtherUserId(conv, myId);

    // Présence : event temps réel prioritaire, sinon valeur du cache.
    final cachedOnline = other?['is_online'] == 1 || other?['is_online'] == true;
    final presenceHidden = !conv.isGroup &&
        other != null &&
        !cachedOnline &&
        other['last_seen'] == null;
    final live = otherId != null && !presenceHidden ? chat.presenceOf(otherId) : null;
    final isOnline =
        !presenceHidden && (live?.online ?? cachedOnline);

    final colors = context.colors;
    final hasUnread = conv.unreadCount > 0;
    final isTyping = chat.isPartnerTyping(
      conv.conversID,
      partnerUserId: conv.isGroup ? null : otherId,
    );

    // Anneau de statut (1v1 uniquement pour l'instant) : le contact a-t-il des
    // statuts en cours ? Si oui, l'avatar est encadré et le tap ouvre le statut.
    final statusProv = context.watch<StatusProvider>();
    final hasStatus =
        !conv.isGroup && otherId != null && statusProv.totalCount(otherId) > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      selected: _selectedConversationIDs.contains(conv.conversID),
      selectedTileColor: context.colors.primary.withValues(alpha: 0.08),
      onLongPress: () {
        if (_selectionMode) {
          _toggleConversationSelection(conv);
          return;
        }
        _enterSelectionMode(conv);
      },
      leading: Stack(
        children: [
          if (hasStatus)
            StatusRingedAvatar(
              avatarUrl: displayAvatar,
              name: displayName,
              totalCount: statusProv.totalCount(otherId),
              unseenCount: statusProv.unseenCount(otherId),
              size: AppSizes.avatarLg,
              onTap: () => _openContactStatus(context, statusProv, otherId),
            )
          else
            ProfileAvatar(
              imageUrl: displayAvatar,
              name: displayName,
              userId: otherId ?? 0,
              isGroup: conv.isGroup,
              conversationId: conv.conversID,
              size: AppSizes.avatarLg,
              borderRadius: AppSizes.avatarLg / 2,
            ),
          if (isOnline && !conv.isGroup)
            const Positioned(
              right: 0,
              bottom: 0,
              child: PresenceDot(online: true, size: 14),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: context.text.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: isTyping
            ? Row(
                children: [
                  TypingIndicator(
                    color: colors.primary,
                    dotSize: 5,
                    spacing: 3,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      conv.isGroup ? context.l10n.someoneIsTyping : context.l10n.typing2,
                      style: context.text.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  // Accusé (✓ / ✓✓ / ✓✓ bleu) si le dernier message est le mien.
                  if (conv.lastMessageSenderID == myId && conv.lastMessage != null) ...[
                    _previewStatusIcon(conv.lastMessageStatus),
                    AppSpacing.hGapXs,
                  ],
                  Expanded(
                    child: conv.lastMessage != null
                        ? Text.rich(
                            TextSpan(
                              children: parseRichSpans(
                                displayConversationPreview(
                                  conv.lastMessage!,
                                  context.l10n,
                                ),
                                context.text.bodyMedium!.copyWith(
                                  color: hasUnread ? colors.onSurface : colors.onSurfaceVariant,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            context.l10n.noMessages,
                            style: context.text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                  ),
                ],
              ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conv.lastMessageAt),
            style: context.text.labelSmall?.copyWith(
              color: hasUnread ? colors.primary : colors.onSurfaceVariant,
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          AppSpacing.vGapXs,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conv.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
                  child: Icon(Icons.push_pin, size: 14, color: colors.onSurfaceVariant),
                ),
              if (hasUnread) CountBadge(count: conv.unreadCount),
            ],
          ),
        ],
      ),
      onTap: () {
        if (_selectionMode) {
          _toggleConversationSelection(conv);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              userName: displayName,
              conversationId: conv.conversID,
              userId: otherId,
              isGroup: conv.isGroup,
              avatarUrl: displayAvatar,
            ),
          ),
        );
      },
    );
  }

  // Accusé affiché sur l'aperçu : ✓ envoyé · ✓✓ livré · ✓✓ bleu lu · horloge · !
  Widget _previewStatusIcon(int? status) {
    return MessageStatusIcon(status: status, size: 13, onBubble: false);
  }

  /// Ouvre la visionneuse sur les statuts du contact [authorId] (démarre au
  /// premier non-vu, façon WhatsApp). Appelé au tap sur l'avatar encadré.
  void _openContactStatus(
      BuildContext context, StatusProvider prov, int authorId) {
    final statuses = prov.byAuthor[authorId] ?? const <Statut>[];
    if (statuses.isEmpty) return;
    final firstUnseen = statuses.indexWhere((s) => !s.seenByMe);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          contactGroups: [statuses],
          startContactIndex: 0,
          startItemIndex: firstUnseen >= 0 ? firstUnseen : 0,
          isMine: false,
        ),
      ),
    );
  }

  void _openChatWithUser(User user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: user.nom.isNotEmpty ? user.nom : user.pseudo,
          userId: user.alanyaID,
          isGroup: false,
          avatarUrl: user.avatarUrl,
        ),
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.day == now.day && local.month == now.month && local.year == now.year) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month}';
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final colors = context.colors;
    final isActive = _filter == value;
    final fg = isActive ? colors.onPrimary : colors.onSurfaceVariant;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: AppSpacing.sm + 1,
        ),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : context.semantic.surfaceMuted,
          borderRadius: AppRadius.brPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            AppSpacing.hGapSm,
            Text(
              label,
              style: context.text.labelMedium?.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }

  List<LocalConversation> _applyFilter(List<LocalConversation> convs) {
    if (_filter == 'archived') {
      return convs.where((c) => c.isArchived).toList();
    }
    // Pour tous les autres chips, on exclut les conversations archivées.
    final visible = convs.where((c) => !c.isArchived);
    switch (_filter) {
      case 'discussions':
        return visible.where((c) => !c.isGroup).toList();
      case 'groups':
        return visible.where((c) => c.isGroup).toList();
      case 'unread':
        return visible.where((c) => c.unreadCount > 0).toList();
      case 'all':
      default:
        return visible.toList();
    }
  }

  Future<void> _applyBatchPin(bool pinned) async {
    if (_selectedConversationIDs.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final convs = await context.read<ChatProvider>().watchConversations().first;
    final selected = convs
        .where((c) => _selectedConversationIDs.contains(c.conversID))
        .toList();
    if (selected.isEmpty) return;
    if (pinned && selected.every((c) => c.isPinned)) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.selectedChatsAreAlreadyPinned)),
      );
      return;
    }
    try {
      await context
          .read<ChatProvider>()
          .setConversationsPinned(_selectedConversationIDs.toList(), pinned);
      if (!mounted) return;
      _exitSelectionMode();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.errorWithDetails('$e'))));
    }
  }

  Future<void> _applyBatchArchive(bool archived) async {
    if (_selectedConversationIDs.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final convs = await context.read<ChatProvider>().watchConversations().first;
    final selected = convs
        .where((c) => _selectedConversationIDs.contains(c.conversID))
        .toList();
    if (selected.isEmpty) return;
    if (archived && selected.every((c) => c.isArchived)) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.selectedChatsAreAlreadyArchived)),
      );
      return;
    }
    if (!archived && selected.every((c) => !c.isArchived)) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.selectedChatsAreNotArchived)),
      );
      return;
    }
    try {
      await context
          .read<ChatProvider>()
          .setConversationsArchived(_selectedConversationIDs.toList(), archived);
      if (!mounted) return;
      _exitSelectionMode();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.errorWithDetails('$e'))));
    }
  }

  Future<void> _applyBatchDelete() async {
    if (_selectedConversationIDs.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context
          .read<ChatProvider>()
          .deleteConversations(_selectedConversationIDs.toList());
      if (!mounted) return;
      _exitSelectionMode();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.errorWithDetails('$e'))));
    }
  }

  Future<void> _swipeArchive(ChatProvider chat, LocalConversation conv) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await chat.setConversationsArchived([conv.conversID], !conv.isArchived);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.errorWithDetails('$e'))),
      );
    }
  }

  Future<void> _swipePin(ChatProvider chat, LocalConversation conv) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await chat.setConversationsPinned([conv.conversID], !conv.isPinned);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.errorWithDetails('$e'))),
      );
    }
  }

  Future<void> _swipeDelete(ChatProvider chat, LocalConversation conv) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await chat.deleteConversations([conv.conversID]);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.errorWithDetails('$e'))),
      );
    }
  }

  Future<void> _swipeMarkRead(ChatProvider chat, LocalConversation conv) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await chat.repository.markAsRead(conv.conversID);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.errorWithDetails('$e'))),
      );
    }
  }
}

