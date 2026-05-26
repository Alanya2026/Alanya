import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../core/db/chat_dao.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../home/glass_nav_bar.dart' show kGlassNavBarSpace;
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  int _myId = 0;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID ?? 0;
    // Rafraîchit depuis le serveur en arrière-plan (l'UI s'affiche déjà du cache).
    Provider.of<ChatProvider>(context, listen: false).refreshConversations();
  }

  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LocalConversation>>(
              stream: chat.watchConversations(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const [];
                final convs = _search.isEmpty
                    ? all
                    : all.where((c) => _displayName(c).toLowerCase().contains(_search)).toList();

                if (snapshot.connectionState == ConnectionState.waiting && all.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (convs.isEmpty) {
                  return Center(
                    child: Text('No conversations yet', style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => chat.refreshConversations(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
                    itemCount: convs.length,
                    itemBuilder: (context, index) => _buildTile(context, chat, convs[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NewChatScreen()));
        },
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  Widget _buildTile(BuildContext context, ChatProvider chat, LocalConversation conv) {
    final other = _otherParticipant(conv);
    final displayName = _displayName(conv);
    final displayAvatar = conv.isGroup ? conv.groupPhoto : other?['avatar_url'] as String?;
    final otherId = other?['alanyaID'] as int?;

    // Présence : event temps réel prioritaire, sinon valeur du cache.
    final live = otherId != null ? chat.presenceOf(otherId) : null;
    final isOnline = live?.online ?? (other?['is_online'] == 1 || other?['is_online'] == true);

    final hasAvatar = displayAvatar != null && displayAvatar.isNotEmpty;
    final Widget? avatarFallback = !hasAvatar
        ? (conv.isGroup
            ? const Icon(CupertinoIcons.group, color: Colors.indigo)
            : Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ))
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.indigo.shade100,
            backgroundImage: hasAvatar ? NetworkImage(displayAvatar) : null,
            child: avatarFallback,
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
          if (conv.lastMessageSenderID == _myId && conv.lastMessage != null) ...[
            _previewStatusIcon(conv.lastMessageStatus),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              conv.lastMessage ?? 'No messages yet',
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

  Map<String, dynamic>? _otherParticipant(LocalConversation conv) {
    final parts = decodeParticipants(conv.participantsJson);
    for (final p in parts) {
      if (p['alanyaID'] != _myId) return p;
    }
    return parts.isNotEmpty ? parts.first : null;
  }

  String _displayName(LocalConversation conv) {
    if (conv.isGroup) return conv.groupName ?? 'Groupe';
    final other = _otherParticipant(conv);
    return (other?['nom'] as String?) ?? 'Inconnu';
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

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.day == now.day && local.month == now.month && local.year == now.year) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month}';
  }
}
