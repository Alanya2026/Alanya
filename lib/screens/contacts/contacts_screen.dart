import 'package:flutter/material.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Contact',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '254 contacts',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 20,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildActionTile(Icons.group_add, 'New Group');
          }
          if (index == 1) {
            return _buildActionTile(Icons.person_add, 'New Contact');
          }
          
          final contactIndex = index - 2;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.indigo.shade50,
              child: Text(
                'C$contactIndex',
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              'Contact $contactIndex',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: const Text(
              'Hey there! I am using Talky.',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              Navigator.pop(context); // Would navigate to chat detail with this user
            },
          );
        },
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String text) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.indigo,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      onTap: () {},
    );
  }
}
