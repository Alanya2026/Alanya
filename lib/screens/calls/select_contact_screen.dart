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
  List<dynamic> _contacts = [];
  List<dynamic> _filteredContacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final contacts = await apiClient.getPreferredContacts();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        final user = contact is User ? contact : User.fromJson(contact as Map<String, dynamic>);
        return user.nom.toLowerCase().contains(query) ||
            user.pseudo.toLowerCase().contains(query) ||
            user.alanyaPhone.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _initiateCall(User user, bool isVideo) async {
    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      receiverId: user.alanyaID,
      isVideo: isVideo,
    );
    if (context.mounted) {
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
                : ListView.builder(
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final user = contact is User ? contact : User.fromJson(contact as Map<String, dynamic>);

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
