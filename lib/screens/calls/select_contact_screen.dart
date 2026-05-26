import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'ongoing_call_screen.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  static const int _maxSelection = 9;

  List<User> _allContacts = [];
  List<User> _filteredContacts = [];
  bool _isLoading = false;
  String _currentQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Mode multi-select (activé par long-press)
  bool _selecting = false;
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      setState(() {
        _allContacts = (data as List?)?.map((json) => User.fromJson(json as Map<String, dynamic>)).toList() ?? [];
        _filteredContacts = _allContacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _filteredContacts = _allContacts);
    } else if (query.length >= 2) {
      _currentQuery = query;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_currentQuery == _searchController.text && mounted) {
          _searchUsers(query);
        }
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() => _isLoading = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      final users = data.map((item) {
        if (item is User) return item;
        return User.fromJson(item as Map<String, dynamic>);
      }).toList();
      if (mounted) {
        setState(() {
          _filteredContacts = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _filteredContacts = _allContacts);
  }

  // ── Mode multi-select ──────────────────────────────────────────────

  void _enterSelectMode(User user) {
    setState(() {
      _selecting = true;
      _selectedIds.add(user.alanyaID);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(User user) {
    setState(() {
      if (_selectedIds.contains(user.alanyaID)) {
        _selectedIds.remove(user.alanyaID);
        if (_selectedIds.isEmpty) _selecting = false;
      } else {
        if (_selectedIds.length >= _maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Maximum 9 participants'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        _selectedIds.add(user.alanyaID);
      }
    });
  }

  // ── Appels ─────────────────────────────────────────────────────────

  Future<void> _initiateCall(User user, bool isVideo) async {
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final callService = Provider.of<CallService>(context, listen: false);
    final userData = await apiClient.getMe();
    final myId = userData['alanyaID'] ?? 0;
    final myPhoto = userData['avatar_url'];

    if (!mounted) return;
    await callService.initiateCall(
      targetUserId: user.alanyaID,
      myId: myId,
      myName: userData['nom'] ?? userData['pseudo'] ?? '',
      myPhoto: myPhoto,
      targetUserName: user.nom,
      targetUserPhoto: user.avatarUrl,
      isVideo: isVideo,
    );
    if (!mounted) return;
    if (callService.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(callService.errorMessage!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OngoingCallScreen()),
    );
  }

  Future<void> _initiateGroupCall(bool isVideo) async {
    if (_selectedIds.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final me = auth.currentUser;
    if (me == null) return;

    final cs = context.read<CallService>();
    if (cs.status != CallStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Un appel est déjà en cours')),
      );
      return;
    }

    final targets = _allContacts
        .where((u) => _selectedIds.contains(u.alanyaID))
        .toList();
    // Sécurité : si la sélection vient d'une recherche, repli sur _filteredContacts
    if (targets.length != _selectedIds.length) {
      final byId = {for (final u in _filteredContacts) u.alanyaID: u};
      for (final id in _selectedIds) {
        if (targets.any((u) => u.alanyaID == id)) continue;
        final u = byId[id];
        if (u != null) targets.add(u);
      }
    }

    final roster = targets
        .map((u) => GroupParticipantInfo(
              id: u.alanyaID.toString(),
              name: u.nom.isNotEmpty ? u.nom : u.pseudo,
              photo: u.avatarUrl,
            ))
        .toList();

    final roomId =
        'gcall_${me.alanyaID}_${DateTime.now().millisecondsSinceEpoch}';

    await cs.createGroupCall(
      roomId: roomId,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
      targetUserIds: targets.map((u) => u.alanyaID).toList(),
      isVideo: isVideo,
      targets: roster,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OngoingCallScreen()),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _selecting ? Icons.close : Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: _selecting ? _exitSelectMode : () => Navigator.pop(context),
        ),
        title: Text(
          _selecting
              ? '${_selectedIds.length} / $_maxSelection'
              : 'Nouvel appel',
          style: const TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              enabled: !_selecting,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, pseudo ou téléphone…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
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
                : _filteredContacts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _searchController.text.isNotEmpty ? Icons.person_search : Icons.people_outline,
                              size: 48,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty ? 'Aucun résultat' : 'Aucun contact',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Text(
                              _selecting
                                  ? 'Appui long pour quitter la sélection'
                                  : (_searchController.text.isNotEmpty
                                      ? 'Résultats'
                                      : 'Contacts préférés'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final user = _filteredContacts[index];
                                return _buildContactTile(user);
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _selecting ? _buildSelectionBar() : null,
    );
  }

  Widget _buildContactTile(User user) {
    final initial =
        user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
    final isSelected = _selectedIds.contains(user.alanyaID);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
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
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          if (_selecting && isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
      title: Text(
        user.nom.isNotEmpty ? user.nom : user.pseudo,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        '@${user.pseudo} • ${user.alanyaPhone}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      trailing: _selecting
          ? Checkbox(
              value: isSelected,
              activeColor: Colors.indigo,
              onChanged: (_) => _toggleSelection(user),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.videocam, color: Colors.indigo),
                  onPressed: () => _initiateCall(user, true),
                ),
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _initiateCall(user, false),
                ),
              ],
            ),
      onTap: _selecting ? () => _toggleSelection(user) : null,
      onLongPress: _selecting ? null : () => _enterSelectMode(user),
    );
  }

  Widget _buildSelectionBar() {
    final disabled = _selectedIds.isEmpty;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : () => _initiateGroupCall(false),
                icon: const Icon(Icons.call, color: Colors.green),
                label: const Text(
                  'Appel vocal',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: disabled ? null : () => _initiateGroupCall(true),
                icon: const Icon(Icons.videocam),
                label: const Text(
                  'Appel vidéo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
