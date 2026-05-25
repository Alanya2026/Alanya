import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'chat_detail_screen.dart';
/// Derni
tape de cr
ation d'un groupe : nom, photo optionnelle, membres.
class CreateGroupScreen extends StatefulWidget {
  final List<User> members;
  const CreateGroupScreen({super.key, required this.members});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  late List<User> _members;
  File? _photoFile;
  bool _creating = false;
  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
    _nameController.addListener(() => setState(() {}));
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x != null) setState(() => _photoFile = File(x.path));
  void _removeMember(User u) {
    setState(() => _members.removeWhere((m) => m.alanyaID == u.alanyaID));
  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _members.isEmpty || _creating) return;
    setState(() => _creating = true);
    final api = Provider.of<TalkyApiClient>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);
    try {
      String? photoUrl;
      if (_photoFile != null) {
        final res = await api.uploadAvatar(_photoFile!);
        photoUrl = res['url'] as String?;
      }
      final conv = await api.createGroup(
        participantIDs: _members.map((m) => m.alanyaID).toList(),
        groupName: name,
        groupPhoto: photoUrl,
      );
      await chat.refreshConversations();
      if (!mounted) return;
      // Revient 
 la liste des chats puis ouvre le groupe cr
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: name,
            conversationId: conv['conversID'] as int?,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  @override
  Widget build(BuildContext context) {
    final canCreate = _nameController.text.trim().isNotEmpty && !_creating;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nouveau groupe',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          Container(
            color: Colors.indigo,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                    child: _photoFile == null
                        ? const Icon(Icons.add_a_photo, color: Colors.indigo)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    cursorColor: Colors.white,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Nom du groupe',
                      hintStyle: TextStyle(color: Colors.white70),
                      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Membres : ${_members.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ..._members.map((u) {
            final hasPhoto = u.avatarUrl.isNotEmpty;
            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.indigo.shade50,
                backgroundImage: hasPhoto ? NetworkImage(u.avatarUrl) : null,
                child: hasPhoto
                    ? null
                    : Text(u.nom.isNotEmpty ? u.nom[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
              ),
              title: Text(u.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(u.alanyaPhone, style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => _removeMember(u),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: canCreate ? Colors.indigo : Colors.grey,
        onPressed: canCreate ? _create : null,
        icon: _creating
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check, color: Colors.white),
        label: const Text('Cr
er', style: TextStyle(color: Colors.white)),
      ),
    );