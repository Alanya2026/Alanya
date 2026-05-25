import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/contact_action_button.dart';
import '../chats/chat_detail_screen.dart';
import 'ongoing_call_screen.dart';

/// Fiche d'un appel récent : récap de l'appel + raccourcis rapides
/// (appel audio, vidéo, message, contact préféré).
class CallDetailScreen extends StatefulWidget {
  const CallDetailScreen({
    super.key,
    required this.user,
    required this.call,
  });

  /// Le correspondant (l'autre participant de l'appel).
  final User user;

  /// L'appel sélectionné (pour le récapitulatif).
  final Call call;

  @override
  State<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends State<CallDetailScreen> {
  late final TalkyApiClient _api;
  String _phone = '';
  bool _isFavorite = false;
  bool _busy = false;

  int get _userId => widget.user.alanyaID;
  String get _displayName =>
      widget.user.nom.isNotEmpty ? widget.user.nom : widget.user.pseudo;

  @override
  void initState() {
    super.initState();
    _api = Provider.of<TalkyApiClient>(context, listen: false);
    _phone = widget.user.alanyaPhone;
    _load();
  }

  Future<void> _load() async {
    final favorite = await _api.checkIsContact(_userId).catchError((_) => false);
    final full = await _api.getUserById(_userId).catchError((_) => <String, dynamic>{});
    if (!mounted) return;
    setState(() {
      _isFavorite = favorite;
      if (full['alanyaPhone'] != null) _phone = full['alanyaPhone'];
    });
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _initiateCall({required bool isVideo}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: _userId,
      myId: auth.currentUser?.alanyaID ?? 0,
      myName: auth.currentUser?.nom ?? '',
      myPhoto: auth.currentUser?.avatarUrl,
      targetUserName: _displayName,
      targetUserPhoto: widget.user.avatarUrl,
      isVideo: isVideo,
    );
    if (!mounted) return;
    if (callService.errorMessage != null) {
      _snack(callService.errorMessage!, error: true);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OngoingCallScreen()));
  }

  Future<void> _openMessage() async {
    try {
      final conv = await _api.createConversation(participantID: _userId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: _displayName,
            conversationId: conv['conversID'],
            userId: _userId,
          ),
        ),
      );
    } catch (e) {
      _snack('Impossible d\'ouvrir la discussion : $e', error: true);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;
    setState(() => _busy = true);
    final next = !_isFavorite;
    try {
      if (next) {
        await _api.addContact(_userId);
      } else {
        await _api.removeContact(_userId);
      }
      if (mounted) setState(() => _isFavorite = next);
    } catch (e) {
      _snack('Action impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
    final avatar = widget.user.avatarUrl;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // En-tête : photo + nom + identifiants
          Column(
            children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? Text(initial,
                        style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold, color: Colors.indigo))
                    : null,
              ),
              const SizedBox(height: 14),
              Text(_displayName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (widget.user.pseudo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('@${widget.user.pseudo}',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
              ],
              if (_phone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_iphone, size: 15, color: Colors.indigo.shade300),
                    const SizedBox(width: 4),
                    Text('AlanyaPhone $_phone',
                        style: const TextStyle(fontSize: 14, color: Colors.indigo)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          // Raccourcis rapides
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ContactActionButton(
                    icon: Icons.call,
                    label: 'Appel',
                    onTap: () => _initiateCall(isVideo: false)),
                const SizedBox(width: 10),
                ContactActionButton(
                    icon: Icons.videocam,
                    label: 'Vidéo',
                    onTap: () => _initiateCall(isVideo: true)),
                const SizedBox(width: 10),
                ContactActionButton(
                    icon: Icons.sms_outlined, label: 'Message', onTap: _openMessage),
                const SizedBox(width: 10),
                ContactActionButton(
                  icon: _isFavorite ? Icons.star : Icons.star_border,
                  label: _isFavorite ? 'Favori' : 'Ajouter',
                  color: _isFavorite ? Colors.amber.shade700 : Colors.indigo,
                  onTap: _toggleFavorite,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildCallInfo(),
        ],
      ),
    );
  }

  Widget _buildCallInfo() {
    final c = widget.call;
    final missed = c.isMissed;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dernier appel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          _infoRow(
            icon: missed ? Icons.call_missed : Icons.call_made,
            iconColor: missed ? Colors.red : Colors.green,
            label: c.statusLabel,
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: c.isVideo ? Icons.videocam : Icons.call,
            iconColor: Colors.indigo,
            label: c.isVideo ? 'Appel vidéo' : 'Appel audio',
          ),
          const SizedBox(height: 8),
          _infoRow(
            icon: Icons.schedule,
            iconColor: Colors.black45,
            label: _formatDate(c.createdAt),
          ),
          if (c.duree != null && c.duree! > 0) ...[
            const SizedBox(height: 8),
            _infoRow(
              icon: Icons.timer_outlined,
              iconColor: Colors.black45,
              label: 'Durée ${c.formattedDuration}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final hm = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        return "Aujourd'hui à $hm";
      }
      return '${date.day}/${date.month}/${date.year} à $hm';
    } catch (_) {
      return 'Récemment';
    }
  }
}
