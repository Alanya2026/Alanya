import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../core/db/chat_dao.dart' show decodeParticipants;
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import 'contact_detail_screen.dart';
/// Fiche d
taill
e d'un groupe : photo, nom, membres, et action 
 Quitter 
class GroupDetailScreen extends StatefulWidget {
  final int conversationId;
  const GroupDetailScreen({super.key, required this.conversationId});
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
class _GroupDetailScreenState extends State<GroupDetailScreen> {
  late final TalkyApiClient _api;
  late final ChatProvider _chat;
  int? _myId;
  bool _leaving = false;
  @override
  void initState() {
    super.initState();
    _api = Provider.of<TalkyApiClient>(context, listen: false);
    _chat = Provider.of<ChatProvider>(context, listen: false);
    _myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID;
  Future<void> _leaveGroup() async {
    if (_leaving) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Vous ne recevrez plus les messages de ce groupe. Continuer ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _leaving = true);
    try {
      await _api.leaveGroup(widget.conversationId);
      await _chat.repository.dao.deleteConversation(widget.conversationId);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() => _leaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  @override
  Widget build(BuildContext context) {
    // Rebuild sur changement de pr
sence des membres.
    Provider.of<ChatProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Infos du groupe', style: TextStyle(color: Colors.black, fontSize: 18)),
      ),
      body: StreamBuilder<LocalConversation?>(
        stream: _chat.watchConversation(widget.conversationId),
        builder: (context, snapshot) {
          final conv = snapshot.data;
          if (conv == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }
          final name = conv.groupName ?? 'Groupe';
          final photo = conv.groupPhoto;
          final members = decodeParticipants(conv.participantsJson);
          return ListView(
            children: [
              _buildHeader(name, photo, members.length),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('${members.length} membres',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              ...members.map(_buildMemberTile),
              const SizedBox(height: 16),
              _buildLeaveButton(),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  Widget _buildHeader(String name, String? photo, int count) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.indigo.shade100,
            backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
            child: (photo == null || photo.isEmpty)
                ? const Icon(Icons.group, color: Colors.indigo, size: 48)
                : null,
          ),
          const SizedBox(height: 12),
          Text(name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Groupe 
 $count membres', style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  Widget _buildMemberTile(Map<String, dynamic> member) {
    final id = _toInt(member['alanyaID']);
    final nom = (member['nom'] as String?) ?? 'Membre';
    final avatar = member['avatar_url'] as String?;
    final isMe = id == _myId;
    final presence = isMe ? 'Vous' : _chat.presenceLabel(id);
    final hasPhoto = avatar != null && avatar.isNotEmpty;
    return Material(
      child: InkWell(
        onTap: isMe
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactDetailScreen(
                      userId: id,
                      initialName: nom,
                      initialAvatar: avatar ?? '',
                    ),
                  ),
                ),
        child: ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.indigo.shade50,
            backgroundImage: hasPhoto ? NetworkImage(avatar) : null,
            child: hasPhoto
                ? null
                : Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
          ),
          title: Text(isMe ? '$nom (vous)' : nom,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: presence.isNotEmpty
              ? Text(presence, style: const TextStyle(color: Colors.grey, fontSize: 13))
              : null,
          trailing: !isMe ? const Icon(Icons.chevron_right, color: Colors.grey) : null,
        ),
      ),
    );
  Widget _buildLeaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _leaving ? null : _leaveGroup,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: _leaving
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
              : const Icon(Icons.exit_to_app),
          label: const Text('Quitter le groupe', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;