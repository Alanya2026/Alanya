import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/avatar_utils.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // 1) Hydrate immédiatement depuis le cache AuthProvider (offline-safe).
    final cached = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    // 2) Rafraîchit depuis l'API ; en cas d'échec on garde le cache.
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getMe();
      if (!mounted) return;
      setState(() {
        _user = User.fromJson(data);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted && _user == null) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Paramètres',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // User Info Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.indigo.shade100,
                            backgroundImage:
                                hasValidAvatarUrl(_user?.avatarUrl)
                                    ? avatarImage(_user!.avatarUrl)
                                    : null,
                            child: hasValidAvatarUrl(_user?.avatarUrl)
                                ? null
                                : Text(
                                    _user?.nom.isNotEmpty == true
                                        ? _user!.nom
                                            .substring(0, 1)
                                            .toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user?.nom ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${_user?.pseudo ?? 'pseudo'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.indigo, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Téléphone Alanya',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  _user?.alanyaPhone ?? 'Non défini',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          _buildSettingsGroup(
            title: 'Général',
            items: [
              _buildSettingsItem(Icons.chat, 'Discussions', 'Thème, fonds d\'écran, historique des discussions'),
              _buildSettingsItem(Icons.notifications, 'Notifications', 'Sonneries de message, groupe et appel'),
              _buildSettingsItem(Icons.data_usage, 'Stockage et données', 'Utilisation du réseau, téléchargement auto'),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsGroup(
            title: 'Compte',
            items: [
              _buildSettingsItem(Icons.security, 'Sécurité', 'Vérification en deux étapes'),
              _buildSettingsItem(Icons.lock, 'Confidentialité', 'Bloquer les contacts, messages éphémères'),
              _buildSettingsItem(Icons.delete_outline, 'Supprimer le compte', '', isDestructive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.shade50 : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.grey.shade700,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.grey),
            )
          : null,
      onTap: () {},
    );
  }
}
