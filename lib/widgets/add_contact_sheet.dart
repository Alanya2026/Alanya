import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../talky_api_client.dart';
import '../talky_models.dart';

class AddContactSheet extends StatefulWidget {
  const AddContactSheet({
    required this.existingIds,
    required this.onAdded,
  });

  final Set<int> existingIds;
  final void Function(User) onAdded;

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
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
        SnackBar(content: Text('Erreur: $e')),
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
                  hintText: 'Rechercher par nom, pseudo ou téléphone…',
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

                            return AddContactItem(
                              user: user,
                              alreadyContact: alreadyContact,
                              isAdding: isAdding,
                              onAdd: () => _addContact(user),
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

/// Widget réutilisable pour afficher un élément de contact dans la liste
class AddContactItem extends StatelessWidget {
  const AddContactItem({
    required this.user,
    required this.alreadyContact,
    required this.isAdding,
    required this.onAdd,
  });

  final User user;
  final bool alreadyContact;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.pseudo.isNotEmpty)
            Text(
              '@${user.pseudo}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          Text(
            user.alanyaPhone,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
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
                  onPressed: onAdd,
                ),
    );
  }
}
