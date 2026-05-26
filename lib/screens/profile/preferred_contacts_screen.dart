import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';
import '../chats/contact_detail_screen.dart';

class PreferredContactsScreen extends StatelessWidget {
  const PreferredContactsScreen({
    super.key,
    required this.contacts,
    required this.onLongPress,
  });

  final List<User> contacts;
  final void Function(User) onLongPress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Contacts préférés',
          style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.person_2, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun contact préféré',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final user = contacts[index];
                return _ContactTile(user: user, onLongPress: () => onLongPress(user));
              },
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.user, required this.onLongPress});

  final User user;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = hasValidAvatarUrl(user.avatarUrl);
    final initial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
    final displayName = user.nom.isNotEmpty ? user.nom : user.pseudo;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContactDetailScreen(
                  userId: user.alanyaID,
                  initialName: user.nom,
                  initialAvatar: user.avatarUrl,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFCBD0E8),
                      backgroundImage: hasPhoto ? avatarImage(user.avatarUrl) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                    if (user.isOnline)
                      Positioned(
                        right: 1,
                        bottom: 1,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (user.pseudo.isNotEmpty)
                        Text(
                          '@${user.pseudo}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      Text(
                        user.alanyaPhone,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onLongPress,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_remove_outlined, color: Colors.red, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
