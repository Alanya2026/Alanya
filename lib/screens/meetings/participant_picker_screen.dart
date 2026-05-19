import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';

class ParticipantPickerScreen extends StatefulWidget {
  final List<User> initialSelected;
  final String confirmLabel;
  // 9 invités max : l'organisateur occupe la 10e place
  final int maxSelectable;

  const ParticipantPickerScreen({
    super.key,
    this.initialSelected = const [],
    this.confirmLabel = 'Confirmer',
    this.maxSelectable = 9,
  });

  @override
  State<ParticipantPickerScreen> createState() => _ParticipantPickerScreenState();
}

class _ParticipantPickerScreenState extends State<ParticipantPickerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  late final List<User> _selected;
  List<User> _results = [];
  bool _isLoading = false;
  bool _showingContacts = true;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
    _searchController.addListener(_onSearchChanged);
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      if (!mounted) return;
      setState(() {
        _results = data
            .map((e) => e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
        _showingContacts = true;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.length >= 2) {
      _currentQuery = query;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_currentQuery == _searchController.text.trim() && mounted) {
          _searchUsers(query);
        }
      });
    } else if (query.isEmpty) {
      setState(() => _showingContacts = true);
      _loadContacts();
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isLoading = true;
      _showingContacts = false;
    });
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

  bool _isSelected(User user) => _selected.any((u) => u.alanyaID == user.alanyaID);

  bool get _atLimit => _selected.length >= widget.maxSelectable;

  void _toggle(User user) {
    if (!_isSelected(user) && _atLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum ${widget.maxSelectable} participants atteint (10 avec l\'organisateur)',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      if (_isSelected(user)) {
        _selected.removeWhere((u) => u.alanyaID == user.alanyaID);
      } else {
        _selected.add(user);
      }
    });
  }

  void _confirm() => Navigator.pop(context, List<User>.from(_selected));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajouter des participants',
              style: TextStyle(color: Colors.black, fontSize: 17, fontWeight: FontWeight.w600),
            ),
            Text(
              '${_selected.length}/${widget.maxSelectable} sélectionné${_selected.length > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: _atLimit ? Colors.orange.shade700 : Colors.grey,
                fontWeight: _atLimit ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text(
                widget.confirmLabel,
                style: const TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Chips des sélectionnés
          if (_selected.isNotEmpty) _SelectedChips(selected: _selected, onRemove: _toggle),

          // Banner limite atteinte
          if (_atLimit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Limite de ${widget.maxSelectable} participants atteinte (10 avec l\'organisateur). Retirez un participant pour en ajouter un autre.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, pseudo…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
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

          // Label section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _showingContacts ? 'Contacts' : 'Résultats',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
                : _results.isEmpty
                    ? _EmptyState(
                        isSearching: !_showingContacts,
                        query: _searchController.text,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final selected = _isSelected(user);
                          return _UserTile(
                            user: user,
                            selected: selected,
                            disabled: _atLimit && !selected,
                            onTap: () => _toggle(user),
                          );
                        },
                      ),
          ),
        ],
      ),
      // Bouton flottant si sélection
      bottomNavigationBar: _selected.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton(
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    '${widget.confirmLabel} · ${_selected.length} participant${_selected.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ─── Chips des participants sélectionnés ─────────────────────────────────────

class _SelectedChips extends StatelessWidget {
  const _SelectedChips({required this.selected, required this.onRemove});

  final List<User> selected;
  final void Function(User) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.indigo.shade50,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: selected.map((user) {
          final initial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
          return Chip(
            avatar: CircleAvatar(
              backgroundColor: Colors.indigo.shade300,
              child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            label: Text(
              user.nom.isNotEmpty ? user.nom : user.pseudo,
              style: const TextStyle(fontSize: 13),
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => onRemove(user),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.indigo.shade200),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Tuile d'un utilisateur ──────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final User user;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
    return InkWell(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.indigo.shade50,
                  backgroundImage:
                      user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(initial,
                          style: const TextStyle(
                              color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 16))
                      : null,
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
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Nom + pseudo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nom.isNotEmpty ? user.nom : user.pseudo,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (user.pseudo.isNotEmpty)
                    Text(
                      '@${user.pseudo}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                ],
              ),
            ),
            // Checkbox
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
      ),
    );
  }
}

// ─── État vide ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isSearching, required this.query});

  final bool isSearching;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (isSearching && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Aucun utilisateur trouvé pour "$query"',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Aucun contact pour le moment',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'Recherchez un utilisateur par nom ou pseudo',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
