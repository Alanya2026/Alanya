import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/call_service.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'ongoing_call_screen.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  List<User> _contacts = [];
  bool _isLoading = false;
  String _currentQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.length >= 2) {
      _currentQuery = query;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_currentQuery == _searchController.text && mounted) {
          _searchUsers(query);
        }
      });
    } else {
      setState(() {
        _contacts = [];
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
      setState(() {
        _contacts = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initiateCall(User user, bool isVideo) async {
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final userData = await apiClient.getMe();
    final myId = userData['alanyaID'] ?? 0;
    final myPhoto = userData['avatar_url'];

    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: user.alanyaID,
      myId: myId,
      myName: userData['nom'] ?? userData['pseudo'] ?? '',
      myPhoto: myPhoto,
      targetUserName: user.nom,
      targetUserPhoto: user.avatarUrl,
      isVideo: isVideo,
    );
    if (context.mounted) {
      // Vérifier s'il y a eu une erreur (ex: permissions refusées)
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Call',
          style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, pseudo or phone...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _contacts.isEmpty && _searchController.text.length < 2
                    ? Center(
                        child: Text(
                          'Type at least 2 characters to search...',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final user = _contacts[index];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: CircleAvatar(
                              radius: 28,
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
                            subtitle: Text(
                              '@${user.pseudo} • ${user.alanyaPhone}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            trailing: Row(
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
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
