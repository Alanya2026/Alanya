import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../core/db/chat_dao.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/profile_avatar.dart';
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
  String _filter = 'all'; // 'all', 'discussions', 'groups', 'unread'
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Discussions',
          style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search, color: Colors.black),
            tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher',
            onPressed: _toggleSearch,
          ),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black), onPressed: () {}),
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                _buildFilterChip('Tous', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Discussions', 'discussions'),
                const SizedBox(width: 8),
                _buildFilterChip('Groupes', 'groups'),
                const SizedBox(width: 8),
                _buildFilterChip('Non lus', 'unread'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LocalConversation>>(
              stream: chat.watchConversations(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const [];
                var convs = _search.isEmpty
                    ? all
                    : all.where((c) => _displayName(c, myId).toLowerCase().contains(_search)).toList();
                
                // Appliquer le filtre
                convs = _applyFilter(convs);

                if (snapshot.connectionState == ConnectionState.waiting && all.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (convs.isEmpty) {
                  return Center(
                    child: Text('Aucune discussion', style: TextStyle(color: Colors.grey.shade600)),
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
            backgroundColor: online ? Colors.indigo : Colors.grey.shade400,
            child: const Icon(Icons.chat, color: Colors.white),
          );
        },
      ),
    );
  }

  Widget _buildTile(
      BuildContext context, ChatProvider chat, LocalConversation conv, int myId) {
    final other = _otherParticipant(conv, myId);
    final displayName = _displayName(conv, myId);
    final displayAvatar = conv.isGroup ? conv.groupPhoto : other?['avatar_url'] as String?;
    final otherId = other?['alanyaID'] as int?;

    // Présence : event temps réel prioritaire, sinon valeur du cache.
    final live = otherId != null ? chat.presenceOf(otherId) : null;
    final isOnline = live?.online ?? (other?['is_online'] == 1 || other?['is_online'] == true);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Stack(
        children: [
          ProfileAvatar(
            imageUrl: displayAvatar,
            name: displayName,
            userId: otherId ?? 0,
            isGroup: conv.isGroup,
            conversationId: conv.conversID,
            size: 56,
            borderRadius: 28,
          ),
          if (isOnline && !conv.isGroup)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Row(
        children: [
          // Accusé (✓ / ✓✓ / ✓✓ bleu) si le dernier message est le mien.
          if (conv.lastMessageSenderID == myId && conv.lastMessage != null) ...[
            _previewStatusIcon(conv.lastMessageStatus),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              conv.lastMessage ?? 'Aucun message',
              style: TextStyle(
                color: conv.unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
                fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conv.lastMessageAt),
            style: TextStyle(
              fontSize: 12,
              color: conv.unreadCount > 0 ? Colors.indigo : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          if (conv.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                '${conv.unreadCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
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

  Map<String, dynamic>? _otherParticipant(LocalConversation conv, int myId) {
    final parts = decodeParticipants(conv.participantsJson);
    for (final p in parts) {
      // Conversion explicite : le JSON peut sérialiser alanyaID en string.
      final id = _toInt(p['alanyaID']);
      if (myId != 0 && id != 0 && id != myId) return p;
    }
    return null;
  }

  String _displayName(LocalConversation conv, int myId) {
    if (conv.isGroup) return conv.groupName ?? 'Groupe';
    final other = _otherParticipant(conv, myId);
    return (other?['nom'] as String?) ?? 'Inconnu';
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  // Accusé affiché sur l'aperçu : ✓ envoyé · ✓✓ livré · ✓✓ bleu lu · horloge en attente · ! échec.
  Widget _previewStatusIcon(int? status) {
    switch (status) {
      case 0:
        return Icon(Icons.schedule, size: 13, color: Colors.grey.shade500);
      case 2:
        return Icon(Icons.done_all, size: 14, color: Colors.grey.shade500);
      case 3:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF4FC3F7));
      case 4:
        return const Icon(Icons.error_outline, size: 14, color: Colors.redAccent);
      case 1:
      default:
        return Icon(Icons.check, size: 14, color: Colors.grey.shade500);
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

  Widget _buildFilterChip(String label, String value) {
    final isActive = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.indigo.shade50,
      labelStyle: TextStyle(
        color: isActive ? Colors.indigo : Colors.black87,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isActive ? Colors.indigo : Colors.transparent,
        width: 1.5,
      ),
    );
  }

  List<LocalConversation> _applyFilter(List<LocalConversation> convs) {
    switch (_filter) {
      case 'discussions':
        return convs.where((c) => !c.isGroup).toList();
      case 'groups':
        return convs.where((c) => c.isGroup).toList();
      case 'unread':
        return convs.where((c) => c.unreadCount > 0).toList();
      case 'all':
      default:
        return convs;
    }
  }
}

