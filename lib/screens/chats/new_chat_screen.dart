import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../providers/auth_provider.dart';
import 'select_members_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  List<User> _contacts = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      setState(() {
        _contacts = (data as List)
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
        _filteredUsers = _contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _contacts;
        _isSearching = false;
      });
    } else {
      _searchAllUsers(query);
    }
  }

  Future<void> _searchAllUsers(String query) async {
    setState(() => _isSearching = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (mounted) {
        setState(() {
          _filteredUsers = (data as List)
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Contact'),
        content: const Text('Feature coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(CupertinoIcons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildActionTile(
                  CupertinoIcons.plus_circle,
                  'New Group',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelectMembersScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _buildActionTile(
                  CupertinoIcons.person_add,
                  'Add Contact',
                  _showAddContactDialog,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _isSearching ? 'No users found' : 'No contacts',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              _searchController.text.trim().isEmpty
                                  ? 'Contacts préférés'
                                  : 'Résultats',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _filteredUsers.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (_, idx) {
                                final user = _filteredUsers[idx];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.indigo.shade50,
                                    backgroundImage: user.avatarUrl.isNotEmpty
                                        ? NetworkImage(user.avatarUrl)
                                        : null,
                                    child: user.avatarUrl.isEmpty
                                        ? Text(
                                            user.nom.isNotEmpty
                                                ? user.nom[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: Colors.indigo,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Text(user.nom),
                                  subtitle: Text(user.alanyaPhone),
                                  onTap: () {
                                    Navigator.pop(context, user);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String text,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.indigo),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
