import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'create_group_screen.dart';
/// S
lection multiple de contacts pour cr
er un groupe.
/// 
 Suivant 
 encha
ne vers [CreateGroupScreen] avec les membres choisis.
class SelectMembersScreen extends StatefulWidget {
  const SelectMembersScreen({super.key});
  @override
  State<SelectMembersScreen> createState() => _SelectMembersScreenState();
class _SelectMembersScreenState extends State<SelectMembersScreen> {
  List<User> _preferredContacts = [];
  List<User> _filteredUsers = [];
  final Map<int, User> _selected = {};
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      final users = data
          .map((item) => item is User ? item : User.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _preferredContacts = users;
        _filteredUsers = users;
        _isLoading = false;
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      final users = data
          .map((item) => item is User ? item : User.fromJson(item as Map<String, dynamic>))
          .toList();
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
  void _toggle(User user) {
    setState(() {
      if (_selected.containsKey(user.alanyaID)) {
        _selected.remove(user.alanyaID);
      } else {
        _selected[user.alanyaID] = user;
      }
    });
  void _goToCreate() {
    if (_selected.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(members: _selected.values.toList()),
      ),
    );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter des membres',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            if (_selected.isNotEmpty)
              Text('${_selected.length} s
lectionn
(s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
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
                hintText: 'Rechercher un nom ou un num
ro...',
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
          if (_selected.isNotEmpty) _buildSelectedStrip(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            _isSearching ? 'Aucun utilisateur trouv
' : 'Pas de contacts pr
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      )
                    : ListView(
                        children: _filteredUsers.map(_buildContactTile).toList(),
                      ),
          ),
        ],
      ),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              onPressed: _goToCreate,
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              label: const Text('Suivant', style: TextStyle(color: Colors.white)),
            ),
    );
  Widget _buildSelectedStrip() {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.indigo.shade50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _selected.values.map((u) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                Stack(
                  children: [
                    _avatar(u, 24),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _toggle(u),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    u.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  Widget _buildContactTile(User user) {
    final selected = _selected.containsKey(user.alanyaID);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: _avatar(user, 24),
      title: Text(user.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(user.alanyaPhone, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected ? Colors.indigo : Colors.grey,
      ),
      onTap: () => _toggle(user),
    );
  Widget _avatar(User user, double radius) {
    final hasPhoto = user.avatarUrl.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.indigo.shade50,
      backgroundImage: hasPhoto ? NetworkImage(user.avatarUrl) : null,
      child: hasPhoto
          ? null
          : Text(
              user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
            ),
    );