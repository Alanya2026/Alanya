import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'create_group_screen.dart';

class SelectMembersScreen extends StatefulWidget {
  const SelectMembersScreen({super.key});

  @override
  State<SelectMembersScreen> createState() => _SelectMembersScreenState();
}

class _SelectMembersScreenState extends State<SelectMembersScreen> {
  final _searchController = TextEditingController();
  List<User> _contacts = [];
  List<User> _filteredUsers = [];
  Set<int> _selected = {};
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

  void _toggle(User user) {
    setState(() {
      if (_selected.contains(user.alanyaID)) {
        _selected.remove(user.alanyaID);
      } else {
        _selected.add(user.alanyaID);
      }
    });
  }

  void _goToCreate() {
    final selectedUsers =
        _contacts.where((u) => _selected.contains(u.alanyaID)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(members: selectedUsers),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Members'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_selected.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selected.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members...',
                prefixIcon: const Icon(CupertinoIcons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
                    : ListView.separated(
                        itemCount: _filteredUsers.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (_, idx) {
                          final user = _filteredUsers[idx];
                          final isSelected = _selected.contains(user.alanyaID);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggle(user),
                            title: Text(user.nom),
                            subtitle: Text(user.alanyaPhone ?? ''),
                            secondary: CircleAvatar(
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
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _selected.isNotEmpty
          ? FloatingActionButton(
              onPressed: _goToCreate,
              backgroundColor: Colors.indigo,
              child: const Icon(CupertinoIcons.arrow_right),
            )
          : null,
    );
  }
}
