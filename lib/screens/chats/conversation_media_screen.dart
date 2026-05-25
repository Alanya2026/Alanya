import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../providers/chat_provider.dart';
import 'media_viewer_screen.dart';
/// Galerie 
 Voir tout 
 : m
dias (photos/vid
os), documents et liens
/// d'une conversation, regroup
s par onglets. Aliment
e par le cache local.
class ConversationMediaScreen extends StatelessWidget {
  const ConversationMediaScreen({
    super.key,
    required this.conversationId,
    this.title = 'M
dias, liens et docs',
  });
  final int conversationId;
  final String title;
  static final RegExp _urlRegex = RegExp(r'(https?://[^\s]+)', caseSensitive: false);
  @override
  Widget build(BuildContext context) {
    final chat = Provider.of<ChatProvider>(context, listen: false);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black),
          title: Text(title,
              style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.black45,
            indicatorColor: Colors.indigo,
            tabs: [
              Tab(text: 'M
dias'),
              Tab(text: 'Docs'),
              Tab(text: 'Liens'),
            ],
          ),
        ),
        body: StreamBuilder<List<LocalMessage>>(
          stream: chat.watchMessages(conversationId),
          builder: (context, snapshot) {
            final messages = (snapshot.data ?? const <LocalMessage>[])
                .where((m) => !m.isDeleted)
                .toList()
                .reversed
                .toList(); // plus r
cents d'abord
            final media = messages.where((m) => m.type == 1 || m.type == 2).toList();
            final docs = messages.where((m) => m.type == 4).toList();
            final links = <MapEntry<LocalMessage, String>>[];
            for (final m in messages.where((m) => m.type == 0 && m.content != null)) {
              for (final match in _urlRegex.allMatches(m.content!)) {
                links.add(MapEntry(m, match.group(0)!));
              }
            }
            return TabBarView(
              children: [
                _MediaGrid(media: media),
                _DocList(docs: docs, chat: chat),
                _LinkList(links: links),
              ],
            );
          },
        ),
      ),
    );
class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.media});
  final List<LocalMessage> media;
  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const _Empty(icon: Icons.photo_library_outlined, label: 'Aucun m
dia');
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: media.length,
      itemBuilder: (context, i) => _MediaTile(msg: media[i]),
    );
class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.msg});
  final LocalMessage msg;
  bool get _hasLocal => msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();
  @override
  Widget build(BuildContext context) {
    final isVideo = msg.type == 2;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            isVideo: isVideo,
            localPath: _hasLocal ? msg.localMediaPath : null,
            networkUrl: msg.mediaUrl,
            title: msg.mediaName,
          ),
        ),
      ),
      child: Container(
        color: Colors.black12,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isVideo)
              Container(
                color: Colors.black87,
                child: const Icon(Icons.videocam, color: Colors.white54, size: 30),
              )
            else if (_hasLocal)
              Image.file(File(msg.localMediaPath!), fit: BoxFit.cover)
            else
              CachedNetworkImage(
                imageUrl: msg.mediaUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (_, __) => const ColoredBox(color: Colors.black12),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54),
              ),
            if (isVideo)
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
              ),
          ],
        ),
      ),
    );
class _DocList extends StatelessWidget {
  const _DocList({required this.docs, required this.chat});
  final List<LocalMessage> docs;
  final ChatProvider chat;
  Future<void> _open(BuildContext context, LocalMessage msg) async {
    String? path = (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
        ? msg.localMediaPath
        : null;
    if (path == null && msg.mediaUrl != null) {
      path = await chat.repository.mediaCache.ensureCached(msg.mediaUrl!);
      if (path != null && msg.msgID != 0) {
        await chat.repository.dao.setLocalMediaPath(msg.msgID, path);
      }
    }
    if (path != null) {
      await OpenFilex.open(path);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le fichier'), backgroundColor: Colors.red),
      );
    }
  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const _Empty(icon: Icons.insert_drive_file_outlined, label: 'Aucun document');
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = docs[i];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFFF3E0),
            child: Icon(Icons.insert_drive_file, color: Colors.orange),
          ),
          title: Text(d.mediaName ?? 'Fichier', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.download_outlined, color: Colors.black38),
          onTap: () => _open(context, d),
        );
      },
    );
class _LinkList extends StatelessWidget {
  const _LinkList({required this.links});
  final List<MapEntry<LocalMessage, String>> links;
  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const _Empty(icon: Icons.link_off, label: 'Aucun lien');
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: links.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final url = links[i].value;
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE8EAF6),
            child: Icon(Icons.link, color: Colors.indigo),
          ),
          title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.indigo)),
          trailing: const Icon(Icons.copy, color: Colors.black38, size: 18),
          onTap: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lien copi
'), duration: Duration(seconds: 1)),
            );
          },
        );
      },
    );
class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ],
      ),
    );