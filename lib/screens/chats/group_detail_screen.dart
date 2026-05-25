import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'conversation_media_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final int conversationId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.conversationId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Conversation? _group;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
  }

  Future<void> _loadGroup() async {
    try {
      // Load from provider's watchConversations stream
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    if (_group == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);
      await api.leaveGroup(widget.conversationId);
      await chat.refreshConversations();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _group == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_circle,
                        color: Colors.grey,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text('Group not found'),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header
                      Container(
                        color: Colors.indigo.shade50,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.indigo.shade100,
                              backgroundImage: _group!.groupPhoto != null &&
                                      _group!.groupPhoto!.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      _group!.groupPhoto!)
                                  : null,
                              child:
                                  _group!.groupPhoto == null ||
                                          _group!.groupPhoto!.isEmpty
                                      ? const Icon(
                                          CupertinoIcons.group,
                                          size: 32,
                                          color: Colors.indigo,
                                        )
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _group!.groupName ?? 'Group',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_group!.participants.length} members',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Options
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          spacing: 8,
                          children: [
                            ListTile(
                              leading: const Icon(CupertinoIcons.photo),
                              title: const Text('View Media'),
                              trailing: const Icon(
                                CupertinoIcons.chevron_right,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ConversationMediaScreen(
                                      conversationId:
                                          widget.conversationId,
                                      conversationName:
                                          widget.groupName,
                                    ),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(CupertinoIcons.person_3),
                              title: const Text('Members'),
                              trailing: const Icon(
                                CupertinoIcons.chevron_right,
                              ),
                              onTap: () {
                                // TODO: Show members screen
                              },
                            ),
                            ListTile(
                              leading: const Icon(CupertinoIcons.bell),
                              title: const Text('Notifications'),
                              trailing: const Icon(
                                CupertinoIcons.chevron_right,
                              ),
                              onTap: () {
                                // TODO: Show notification settings
                              },
                            ),
                          ],
                        ),
                      ),

                      // Danger zone
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _leaveGroup,
                            icon:
                                const Icon(CupertinoIcons.xmark_circle),
                            label: const Text('Leave Group'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade100,
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
