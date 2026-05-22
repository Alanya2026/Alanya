import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import 'ongoing_call_screen.dart';
import 'keypad_screen.dart';
import 'select_contact_screen.dart';
import '../shared/schedule_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initCurrentUser();
    _loadRecentCalls();
  }

  void _initCurrentUser() {
    // Récupérer l'ID depuis AuthProvider (déjà chargé, pas d'appel réseau)
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _myId = auth.currentUser?.alanyaID ?? 0;
  }

  Future<void> _loadRecentCalls() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final raw = await apiClient.getCallHistory();
      final calls = raw
          .map((item) => item is Call
              ? item
              : Call.fromJson(item as Map<String, dynamic>))
          .toList();
      setState(() {
        _recentCalls = calls;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
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
            icon: const Icon(Icons.calendar_month, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScheduleScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_call, color: Colors.black),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SelectContactScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentCalls.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun appel récent',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRecentCalls,
                  child: ListView.builder(
                    itemCount: _recentCalls.length,
                    itemBuilder: (context, index) {
                      final call = _recentCalls[index];
                      // !! Calcul direct — pas de FutureBuilder
                      final otherUser = call.idCaller != _myId ? call.caller : call.receiver;
                      final isMissed = call.isMissed;
                      final isVideo = call.isVideo;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.indigo.shade50,
                          backgroundImage: (otherUser?.avatarUrl != null &&
                                  otherUser!.avatarUrl.isNotEmpty)
                              ? NetworkImage(otherUser.avatarUrl)
                              : null,
                          child: (otherUser?.avatarUrl == null ||
                                  otherUser!.avatarUrl.isEmpty)
                              ? Text(
                                  (otherUser?.nom.isNotEmpty == true)
                                      ? otherUser!.nom[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.indigo,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
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
                            Text(
                              '${_formatDate(call.createdAt)} • ${isVideo ? "Vidéo" : "Audio"}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if (call.duree != null && call.duree! > 0) ...[
                              Text(' • ${call.formattedDuration}',
                                  style: TextStyle(color: Colors.grey.shade600)),
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
                      );
                    },
                  ),
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