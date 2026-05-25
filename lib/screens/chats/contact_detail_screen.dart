 import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'chat_detail_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final int userId;
  final int? conversationId;
  final String initialName;
  final String initialAvatar;

  const ContactDetailScreen({
    super.key,
    required this.userId,
    this.conversationId,
    this.initialName = '',
    this.initialAvatar = '',
  });

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  User? _contact;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  Future<void> _loadContact() async {
    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await api.getUserById(widget.userId);
      setState(() {
        _contact = User.fromJson(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat() async {
    if (_contact == null) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: _contact!.nom,
          userId: widget.userId,
          conversationId: widget.conversationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contact == null
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
                      const Text('Contact not found'),
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
                      // Header with avatar and basic info
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
                              backgroundImage: _contact!.avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(
                                      _contact!.avatarUrl)
                                  : null,
                              child: _contact!.avatarUrl.isEmpty
                                  ? Text(
                                      _contact!.nom.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _contact!.nom,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _contact!.alanyaPhone ?? 'No phone',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action button
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _startChat,
                            icon: const Icon(CupertinoIcons.chat_bubble_2),
                            label: const Text('Send Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),

                      // Details section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Information',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailItem(
                              'Alanya ID',
                              _contact!.alanyaID.toString(),
                            ),
                            _buildDetailItem(
                              'Email',
                              _contact!.email ?? 'Not provided',
                            ),
                            _buildDetailItem(
                              'Phone',
                              _contact!.alanyaPhone ?? 'Not provided',
                            ),
                            if (_contact!.createdAt != null)
                              _buildDetailItem(
                                'Joined',
                                _contact!.createdAt
                                    .toString()
                                    .split(' ')
                                    .first,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
