import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../authentification/login_screen.dart';
import '../../providers/auth_provider.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  List<User> _contacts = [];
  bool _isLoading = true;
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadContacts();
  }

  Future<void> _loadUser() async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getMe();
      if (!mounted) return;
      setState(() {
        _user = User.fromJson(data);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = data
            .map((e) => e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingContacts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _removeContact(User user) async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      await apiClient.removeContact(user.alanyaID);
      if (!mounted) return;
      setState(() => _contacts.removeWhere((u) => u.alanyaID == user.alanyaID));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression : $e')),
      );
    }
  }

  void _openAddContact() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddContactSheet(
        existingIds: _contacts.map((u) => u.alanyaID).toSet(),
        onAdded: (user) {
          setState(() => _contacts.add(user));
        },
      ),
    );
  }

  void _showContactOptions(User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
              title: Text(
                'Retirer ${user.nom.isNotEmpty ? user.nom : user.pseudo} des contacts préférés',
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeContact(user);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Avatar + nom
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.indigo.shade100,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text(
                            _user?.nom.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : Text(
                    _user?.nom ?? 'User',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
            const SizedBox(height: 4),
            if (!_isLoading)
              Text(
                _user?.alanyaPhone ?? '',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            const SizedBox(height: 32),

            // Menu principal
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildMenuItem(CupertinoIcons.person, 'Compte', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  }),
                  const Divider(height: 1),
                  _buildMenuItem(CupertinoIcons.chat_bubble, 'Discussions', () {}),
                  const Divider(height: 1),
                  _buildMenuItem(CupertinoIcons.bell, 'Notifications', () {}),
                  const Divider(height: 1),
                  _buildMenuItem(CupertinoIcons.settings, 'Paramètres', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  }),
                  const Divider(height: 1),
                  _buildMenuItem(Icons.logout, 'Déconnexion', _logout, isDestructive: true),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Section contacts préférés ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Contacts préférés',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _openAddContact,
                    icon: const Icon(Icons.add, size: 18, color: Colors.indigo),
                    label: const Text(
                      'Ajouter',
                      style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _loadingContacts
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Colors.indigo),
                  )
                : _contacts.isEmpty
                    ? _EmptyContacts(onAdd: _openAddContact)
                    : _ContactGrid(
                        contacts: _contacts,
                        onLongPress: _showContactOptions,
                      ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.shade50 : Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.indigo,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ─── Grille de contacts ───────────────────────────────────────────────────────

class _ContactGrid extends StatelessWidget {
  const _ContactGrid({required this.contacts, required this.onLongPress});

  final List<User> contacts;
  final void Function(User) onLongPress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 20,
        children: contacts.map((user) => _ContactChip(user: user, onLongPress: onLongPress)).toList(),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.user, required this.onLongPress});

  final User user;
  final void Function(User) onLongPress;

  @override
  Widget build(BuildContext context) {
    final initial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
    final displayName = user.nom.isNotEmpty ? user.nom : user.pseudo;
    final shortName = displayName.length > 8 ? '${displayName.substring(0, 7)}…' : displayName;

    return GestureDetector(
      onLongPress: () => onLongPress(user),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.indigo.shade50,
                  backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.indigo,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              shortName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(CupertinoIcons.person_2, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Aucun contact préféré',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ajoutez des contacts pour les retrouver\nrapidement lors de vos réunions',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline, color: Colors.indigo),
            label: const Text(
              'Ajouter un contact',
              style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom sheet : recherche + ajout ────────────────────────────────────────

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({required this.existingIds, required this.onAdded});

  final Set<int> existingIds;
  final void Function(User) onAdded;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _searchController = TextEditingController();
  List<User> _results = [];
  bool _isLoading = false;
  String _currentQuery = '';
  final Set<int> _adding = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _currentQuery = query;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_currentQuery == _searchController.text.trim() && mounted) {
          _search(query);
        }
      });
    } else {
      setState(() => _results = []);
    }
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = data
            .map((e) => e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addContact(User user) async {
    setState(() => _adding.add(user.alanyaID));
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      await apiClient.addContact(user.alanyaID);
      if (!mounted) return;
      widget.onAdded(user);
      setState(() => _adding.remove(user.alanyaID));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.nom.isNotEmpty ? user.nom : user.pseudo} ajouté aux contacts préférés'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _adding.remove(user.alanyaID));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  bool _isAlreadyContact(User user) =>
      widget.existingIds.contains(user.alanyaID);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajouter un contact préféré',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Champ de recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Rechercher par nom ou pseudo…',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Résultats
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                  : _results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _searchController.text.length >= 2
                                    ? Icons.person_search
                                    : CupertinoIcons.search,
                                size: 44,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.length < 2
                                    ? 'Tapez au moins 2 caractères'
                                    : 'Aucun résultat',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _results.length,
                          itemBuilder: (_, index) {
                            final user = _results[index];
                            final alreadyContact = _isAlreadyContact(user);
                            final isAdding = _adding.contains(user.alanyaID);
                            final initial =
                                user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.indigo.shade50,
                                backgroundImage: user.avatarUrl.isNotEmpty
                                    ? NetworkImage(user.avatarUrl)
                                    : null,
                                child: user.avatarUrl.isEmpty
                                    ? Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Colors.indigo,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                user.nom.isNotEmpty ? user.nom : user.pseudo,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: user.pseudo.isNotEmpty
                                  ? Text('@${user.pseudo}',
                                      style: TextStyle(color: Colors.grey.shade500))
                                  : null,
                              trailing: alreadyContact
                                  ? Chip(
                                      label: const Text(
                                        'Déjà ajouté',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.grey.shade100,
                                      padding: EdgeInsets.zero,
                                    )
                                  : isAdding
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.indigo,
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.person_add_outlined,
                                            color: Colors.indigo,
                                          ),
                                          onPressed: () => _addContact(user),
                                        ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
