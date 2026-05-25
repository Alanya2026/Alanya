import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';
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
      setState(() => _filteredUsers = _contacts);
    } else {
      _searchAllUsers(query);
    }
  }

  Future<void> _searchAllUsers(String query) async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (mounted) {
        setState(() {
          _filteredUsers = (data as List)
              .map((json) => User.fromJson(json as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() {});
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

  void _clearSearch() {
    _searchController.clear();
    setState(() => _filteredUsers = _contacts);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selected.isEmpty ? 'Nouveau groupe' : '${_selected.length} sélectionné',
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _goToCreate,
              child: const Text(
                'Suivant',
                style: TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, pseudo ou téléphone…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: hasQuery
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
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
                ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasQuery ? Icons.person_search : Icons.people_outline,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hasQuery ? 'Aucun résultat' : 'Aucun contact',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (_, idx) {
                          final user = _filteredUsers[idx];
                          final selected = _selected.contains(user.alanyaID);
                          final initial = user.nom.isNotEmpty
                              ? user.nom[0].toUpperCase()
                              : '?';
                          return InkWell(
                            onTap: () => _toggle(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.indigo.shade50,
                                        backgroundImage: avatarImage(user.avatarUrl),
                                        child: hasValidAvatarUrl(user.avatarUrl)
                                            ? null
                                            : Text(initial,
                                                style: const TextStyle(
                                                    color: Colors.indigo,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                      ),
                                      if (user.isOnline)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white, width: 1.5),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.nom.isNotEmpty ? user.nom : user.pseudo,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 15),
                                        ),
                                        if (user.pseudo.isNotEmpty)
                                          Text(
                                            '@${user.pseudo}',
                                            style: TextStyle(
                                                color: Colors.grey.shade500, fontSize: 13),
                                          ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: selected ? Colors.indigo : Colors.transparent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected ? Colors.indigo : Colors.grey.shade400,
                                        width: 2,
                                      ),
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
