import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/add_contact_sheet.dart';
import 'chat_detail_screen.dart';
import 'select_members_screen.dart';
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
class _NewChatScreenState extends State<NewChatScreen> {
  List<User> _preferredContacts = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      final users = data.map((item) {
        if (item is User) return item;
        return User.fromJson(item as Map<String, dynamic>);
      }).toList();
      setState(() {
        _preferredContacts = users;
        _filteredUsers = users;
        _isLoading = false;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _preferredContacts;
        _isSearching = false;
      });
    } else {
      _searchAllUsers(query);
    }
  Future<void> _searchAllUsers(String query) async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      final users = data.map((item) {
        if (item is User) return item;
        return User.fromJson(item as Map<String, dynamic>);
      }).toList();
      
      if (mounted) {
        setState(() {
          _filteredUsers = users;
          _isSearching = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _filteredUsers = [];
          _isSearching = true;
        });
      }
    }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Chat',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search names or numbers...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (!_isSearching) ...[
                        _buildActionTile(Icons.group_add, 'Nouveau groupe ', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SelectMembersScreen()),
                          );
                        }),
                        _buildActionTile(Icons.person_add, 'Nouveau contact pr
', _showAddContactDialog),
                      ],
                      if (_filteredUsers.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Text(
                              _isSearching ? 'Aucun utilisateur trouv
' : 'Pas de contacts pr
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 8),
                          child: Text(
                            _isSearching ? 'Resultats de la recherche' : 'Contacts pr
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        ..._filteredUsers.map((user) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.indigo.shade50,
                              child: Text(
                                user.nom[0].toUpperCase(),
                                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              user.nom,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.alanyaPhone,
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                                Text(
                                  user.isOnline ? 'En ligne' : 'Hors ligne',
                                  style: TextStyle(
                                    color: user.isOnline ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () async {
                              final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
                              try {
                                final conv = await apiClient.createConversation(
                                  participantID: user.alanyaID,
                                );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatDetailScreen(
                                        userName: user.nom,
                                        conversationId: conv['conversID'],
                                        userId: user.alanyaID,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  Widget _buildActionTile(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey.shade100,
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      onTap: onTap,
    );
  void _showAddContactDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddContactSheet(
        existingIds: _preferredContacts.map((u) => u.alanyaID).toSet(),
        onAdded: (user) {
          setState(() => _preferredContacts.add(user));
        },
      ),
    );
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();