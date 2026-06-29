import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_hidden_store.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/common/common.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/typing_indicator.dart';
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

  @override
  void initState() {
    super.initState();
    // Rafraîchit depuis le serveur en arrière-plan (l'UI s'affiche déjà du cache).
    Provider.of<ChatProvider>(context, listen: false).refreshConversations();
  }

  @override
  void dispose() {
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
        title: Text('Discussions', style: context.text.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher',
            onPressed: _toggleSearch,
          ),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
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
                _buildFilterChip('Tous', 'all', Icons.apps_rounded),
                AppSpacing.hGapSm,
                _buildFilterChip('Discussions', 'discussions', Icons.person_outline),
                AppSpacing.hGapSm,
                _buildFilterChip('Groupes', 'groups', Icons.groups_rounded),
                AppSpacing.hGapSm,
                _buildFilterChip('Non lus', 'unread', Icons.mark_email_unread_outlined),
                AppSpacing.hGapSm,
                _buildFilterChip('Archivés', 'archived', Icons.archive_outlined),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LocalConversation>>(
              stream: chat.watchConversations(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const [];
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

                if (snapshot.connectionState == ConnectionState.waiting && all.isEmpty) {
                  return const LoadingState();
                }
                if (convs.isEmpty) {
                  return EmptyState(
                    icon: _filter == 'archived'
                        ? Icons.archive_outlined
                        : Icons.chat_bubble_outline_rounded,
                    title: _search.isNotEmpty
                        ? 'Aucun résultat'
                        : _filter == 'archived'
                            ? 'Aucune conversation archivée'
                            : 'Aucune discussion',
                    message: _search.isNotEmpty
                        ? 'Essayez un autre terme de recherche.'
                        : 'Démarrez une nouvelle discussion avec le bouton +.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => chat.refreshConversations(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
                    itemCount: convs.length,
                    itemBuilder: (context, index) =>
                        _buildTile(context, chat, convs[index], myId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<ConnectivityProvider>(
        builder: (context, conn, _) {
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
                      const SnackBar(
                        content: Text('Nouvelle discussion indisponible hors ligne'),
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      onLongPress: () => _showConversationActions(context, conv, myId),
      leading: Stack(
        children: [
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
                      conv.isGroup ? 'Quelqu\'un écrit…' : 'En train d\'écrire…',
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
                    child: Text(
                      conv.lastMessage ?? 'Aucun message',
                      style: context.text.bodyMedium?.copyWith(
                        color: hasUnread ? colors.onSurface : colors.onSurfaceVariant,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // Accusé affiché sur l'aperçu : ✓ envoyé · ✓✓ livré · ✓✓ bleu lu · horloge en attente · ! échec.
  Widget _previewStatusIcon(int? status) {
    final muted = context.colors.onSurfaceVariant;
    switch (status) {
      case 0:
        return Icon(Icons.schedule, size: 13, color: muted);
      case 2:
        return Icon(Icons.done_all, size: 14, color: muted);
      case 3:
        return Icon(Icons.done_all, size: 14, color: context.colors.primary);
      case 4:
        return Icon(Icons.error_outline, size: 14, color: context.colors.error);
      case 1:
      default:
        return Icon(Icons.check, size: 14, color: muted);
    }
  }

  Future<void> _openChatWithUser(User user) async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final result = await apiClient.createConversation(participantID: user.alanyaID);
      final conversationId = result['conversID'] as int?;

      if (conversationId != null && mounted) {
        // La conv vient d'être créée côté serveur : on relit la liste pour
        // qu'elle apparaisse aussitôt dans le `StreamBuilder` au retour.
        await chatProvider.refreshConversations();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              userName: user.nom.isNotEmpty ? user.nom : user.pseudo,
              conversationId: conversationId,
              userId: user.alanyaID,
              isGroup: false,
              avatarUrl: user.avatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'ouverture de la discussion')),
        );
      }
    }
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

  // ── Actions sur tuile (long press) ─────────────────────────────────

  Future<void> _showConversationActions(
    BuildContext context,
    LocalConversation conv,
    int myId,
  ) async {
    final repo = context.read<ChatProvider>().repository;
    final hidden = context.read<LocalHiddenStore>();
    final error = context.colors.error;
    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(conversationDisplayName(conv, myId), style: context.text.titleMedium),
            ),
            ListTile(
              leading: Icon(conv.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(conv.isPinned ? 'Désépingler' : 'Épingler'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(sheetCtx);
                try {
                  await repo.setConversationPinned(conv.conversID, !conv.isPinned);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Échec : $e')));
                }
              },
            ),
            ListTile(
              leading: Icon(conv.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
              title: Text(conv.isArchived ? 'Désarchiver' : 'Archiver'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(sheetCtx);
                try {
                  await repo.setConversationArchived(conv.conversID, !conv.isArchived);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Échec : $e')));
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: error),
              title: Text('Supprimer', style: TextStyle(color: error)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await hidden.hideConversation(conv.conversID);
              },
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }
}

