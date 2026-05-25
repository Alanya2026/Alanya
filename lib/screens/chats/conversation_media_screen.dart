import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../talky_models.dart';

class ConversationMediaScreen extends StatefulWidget {
  final int conversationId;
  final String conversationName;

  const ConversationMediaScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<ConversationMediaScreen> createState() =>
      _ConversationMediaScreenState();
}

class _ConversationMediaScreenState extends State<ConversationMediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Message> _mediaMessages = [];
  List<Message> _linkMessages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    // TODO: Load media and links from API
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.conversationName} - Media'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          tabs: const [
            Tab(text: 'Photos & Videos'),
            Tab(text: 'Links'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMediaGrid(),
                _buildLinksList(),
              ],
            ),
    );
  }

  Widget _buildMediaGrid() {
    if (_mediaMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.photo,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No media shared',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _mediaMessages.length,
      itemBuilder: (context, index) {
        final msg = _mediaMessages[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: msg.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) =>
                      const Icon(CupertinoIcons.photo),
                )
              : const Icon(CupertinoIcons.photo),
        );
      },
    );
  }

  Widget _buildLinksList() {
    if (_linkMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.link,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No links shared',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _linkMessages.length,
      itemBuilder: (context, index) {
        final msg = _linkMessages[index];
        return ListTile(
          leading: const Icon(
            CupertinoIcons.link,
            color: Colors.blue,
          ),
          title: Text(msg.content ?? 'Link'),
          subtitle: Text(msg.sendAt),
          trailing: Icon(
            CupertinoIcons.chevron_right,
            color: Colors.grey.shade400,
          ),
        );
      },
    );
  }
}
