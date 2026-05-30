import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/profile_avatar.dart';
import '../home/glass_nav_bar.dart' show kGlassNavBarSpace;
import 'call_detail_screen.dart';
import 'ongoing_call_screen.dart';
import 'keypad_screen.dart';
import 'select_contact_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<Call> _recentCalls = [];
  bool _isLoading = true;
  // !! ID mis en cache — pas de FutureBuilder dans chaque ListTile
  int _myId = 0;
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _initCurrentUser();
    _loadRecentCalls();
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

  void _initCurrentUser() {
    // Récupérer l'ID depuis AuthProvider (déjà chargé, pas d'appel réseau)
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _myId = auth.currentUser?.alanyaID ?? 0;
  }

  Future<void> _loadRecentCalls() async {
    // 1) Hydrate immédiatement depuis le cache local (instantané, offline-safe).
    try {
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      final localCalls = await cache.watchCalls().first;
      if (!mounted) return;
      if (localCalls.isNotEmpty) {
        setState(() {
          _recentCalls = localCalls.map(_localToCall).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = true);
      }
    } catch (_) {}

    // 2) Rafraîchit depuis l'API (best-effort, écrase le cache si succès).
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final raw = await apiClient.getCallHistory();
      final calls = raw
          .map((item) => item is Call
              ? item
              : Call.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _recentCalls = calls;
        _isLoading = false;
      });
      // Sync background → met aussi à jour le cache local pour la prochaine fois.
      if (mounted && _myId != 0) {
        final cache = Provider.of<LocalCacheRepository>(context, listen: false);
        cache.syncCalls(myId: _myId);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Call _localToCall(LocalCall c) {
    return Call(
      idCall: c.idCall,
      idCaller: c.idCaller,
      idReceiver: c.idReceiver,
      type: c.type,
      status: c.status,
      createdAt: c.createdAt.toIso8601String(),
      duree: c.duration,
      caller: c.idCaller != _myId
          ? User(
              alanyaID: c.idCaller,
              nom: c.otherNom ?? '',
              pseudo: '',
              alanyaPhone: '',
              email: '',
              idPays: 0,
              avatarUrl: c.otherAvatar ?? '',
              typeCompte: 0,
              isOnline: false,
              lastSeen: '',
            )
          : null,
      receiver: c.idReceiver != _myId
          ? User(
              alanyaID: c.idReceiver,
              nom: c.otherNom ?? '',
              pseudo: '',
              alanyaPhone: '',
              email: '',
              idPays: 0,
              avatarUrl: c.otherAvatar ?? '',
              typeCompte: 0,
              isOnline: false,
              lastSeen: '',
            )
          : null,
    );
  }

  Future<void> _callFromHistory(Call call, bool isVideo) async {
    // Déterminer l'autre participant
    final otherUser = call.idCaller != _myId ? call.caller : call.receiver;
    if (otherUser == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myName = auth.currentUser?.nom ?? '';
    final myPhoto = auth.currentUser?.avatarUrl;

    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: otherUser.alanyaID,
      myId: _myId,
      myName: myName,
      myPhoto: myPhoto,
      targetUserName: otherUser.nom,
      targetUserPhoto: otherUser.avatarUrl,
      isVideo: isVideo,
    );

    if (context.mounted) {
      // Vérifier s'il y a eu une erreur (ex: permissions refusées)
      if (callService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(callService.errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Appels',
          style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search, color: Colors.black),
            tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher',
            onPressed: _toggleSearch,
          ),
          // IconButton(
          //   icon: const Icon(Icons.calendar_month, color: Colors.black),
          //   onPressed: () => Navigator.push(
          //     context,
          //     MaterialPageRoute(builder: (_) => const ScheduleScreen()),
          //   ),
          // ),
          IconButton(
            icon: const Icon(Icons.add_call, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SelectContactScreen()),
            ),
          ),
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
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KeypadScreen()),
        ),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.dialpad, color: Colors.white),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _search.isEmpty
        ? _recentCalls
        : _recentCalls.where((call) {
            final otherUser = call.idCaller != _myId ? call.caller : call.receiver;
            return (otherUser?.nom ?? '').toLowerCase().contains(_search);
          }).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _search.isEmpty ? 'Aucun appel récent' : 'Aucun résultat',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRecentCalls,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final call = filtered[index];
          // !! Calcul direct — pas de FutureBuilder
          final otherUser = call.idCaller != _myId ? call.caller : call.receiver;
          final isMissed = call.isMissed;
          final isVideo = call.isVideo;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: ProfileAvatar(
                          imageUrl: otherUser?.avatarUrl,
                          name: otherUser?.nom ?? 'Inconnu',
                          userId: otherUser?.alanyaID ?? 0,
                          isGroup: false,
                          size: 56,
                          borderRadius: 28,
                        ),
                        title: Text(
                          otherUser?.nom ?? 'Inconnu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isMissed ? Colors.red : Colors.black87,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Icon(
                              isMissed ? Icons.call_missed : Icons.call_made,
                              size: 16,
                              color: isMissed ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${_formatDate(call.createdAt)} • ${isVideo ? "Vidéo" : "Audio"}',
                                style: TextStyle(color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (call.duree != null && call.duree! > 0) ...[
                              Text(' • ${call.formattedDuration}',
                                  style: TextStyle(color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isVideo ? Icons.videocam : Icons.call,
                            color: Colors.indigo,
                          ),
                          onPressed: () => _callFromHistory(call, isVideo),
                        ),
                        onTap: otherUser == null
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CallDetailScreen(
                                      user: otherUser,
                                      call: call,
                                    ),
                                  ),
                                ),
          );
        },
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return 'Aujourd\'hui ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Récemment';
    }
  }
}