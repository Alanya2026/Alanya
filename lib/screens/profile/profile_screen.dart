import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';
import '../../core/utils/country_utils.dart';
import '../authentification/login_screen.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/add_contact_sheet.dart';
import '../chats/contact_detail_screen.dart';
import '../home/glass_nav_bar.dart' show kGlassNavBarSpace;
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'preferred_contacts_screen.dart';
import '../admin/admin_dashboard_screen.dart';

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
      final user = User.fromJson(data);
      final full = await apiClient.getUserById(user.alanyaID).catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      final paysLibelle = full['pays_libelle'] as String? ?? user.paysLibelle;
      setState(() {
        _user = User(
          alanyaID: user.alanyaID,
          nom: user.nom,
          pseudo: user.pseudo,
          alanyaPhone: full['alanyaPhone'] as String? ?? user.alanyaPhone,
          email: user.email,
          idPays: user.idPays,
          avatarUrl: user.avatarUrl,
          typeCompte: user.typeCompte,
          isOnline: user.isOnline,
          lastSeen: user.lastSeen,
          paysLibelle: paysLibelle,
        );
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
      builder: (_) => AddContactSheet(
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
        padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // ── En-tête profil ───────────────────────────────────────────
            _ProfileHeader(
              user: _user,
              isLoading: _isLoading,
              onEdited: _loadUser,
            ),

            const SizedBox(height: 20),

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
                  if (_contacts.length > 4)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreferredContactsScreen(
                              contacts: _contacts,
                              onLongPress: _showContactOptions,
                              onAddContact: _openAddContact,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+${_contacts.length - 4}',
                            style: const TextStyle(
                              color: Colors.indigo,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.indigo),
                        ],
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
                    ? _EmptyContacts(onAdd: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreferredContactsScreen(
                              contacts: _contacts,
                              onLongPress: _showContactOptions,
                              onAddContact: _openAddContact,
                            ),
                          ),
                        );
                      })
                    : _ContactGrid(
                        contacts: _contacts,
                        onLongPress: _showContactOptions,
                      ),

            const SizedBox(height: 20),

            // ── Menu paramètres ─────────────────────────────────────────
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
                  _buildMenuItem(CupertinoIcons.person, 'Compte', () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                    if (mounted) _loadUser();
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
                  if (!_isLoading && _user != null && _user!.typeCompte >= 1) ...[
                    const Divider(height: 1),
                    _buildMenuItem(Icons.admin_panel_settings, 'Dashboard Admin', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Déconnexion ─────────────────────────────────────────────
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
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.logout,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Déconnexion',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: _logout,
              ),
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
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Colors.indigo,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ─── En-tête profil ─────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final User? user;
  final bool isLoading;
  final VoidCallback? onEdited;

  const _ProfileHeader({
    required this.user,
    required this.isLoading,
    this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user != null && hasValidAvatarUrl(user!.avatarUrl);
    final initial = user?.nom.isNotEmpty == true ? user!.nom[0].toUpperCase() : 'U';
    final pseudo = user?.pseudo ?? '';
    final phone = user?.alanyaPhone ?? '';
    final pays = user?.paysLibelle ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
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
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFCBD0E8),
                backgroundImage: hasPhoto
                    ? avatarImage(user!.avatarUrl)
                    : null,
                child: hasPhoto
                    ? null
                    : Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                    onEdited?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.indigo,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const CircularProgressIndicator()
          else ...[
            Text(
              user?.nom ?? 'User',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if ((user?.typeCompte ?? 0) >= 1) ...[
              const SizedBox(height: 6),
              _RoleBadge(typeCompte: user!.typeCompte),
            ],
            if (pseudo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '@$pseudo',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ],
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_iphone, size: 16, color: Colors.indigo.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'AlanyaPhone $phone',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E66D8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (pays.isNotEmpty) ...[
              const SizedBox(height: 4),
              CountryRow(country: pays),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Grille de contacts ─────────────────────────────────────────────────

class _ContactGrid extends StatelessWidget {
  const _ContactGrid({required this.contacts, required this.onLongPress});

  final List<User> contacts;
  final void Function(User) onLongPress;

  @override
  Widget build(BuildContext context) {
    final displayed = contacts.take(4).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: displayed.map((user) => _ContactChip(user: user, onLongPress: onLongPress)).toList(),
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
    final hasPhoto = hasValidAvatarUrl(user.avatarUrl);
    final initial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
    final displayName = user.nom.isNotEmpty ? user.nom : user.pseudo;
    final shortName = displayName.length > 8 ? '${displayName.substring(0, 7)}…' : displayName;

    return GestureDetector(
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
      onLongPress: () => onLongPress(user),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFCBD0E8),
                  backgroundImage: hasPhoto ? avatarImage(user.avatarUrl) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
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
            const SizedBox(height: 3),
            Text(
              user.alanyaPhone,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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

// ─── État vide ──────────────────────────────────────────────────────────

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

// ─── Badge de rôle (admin / super admin) ────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final int typeCompte;
  const _RoleBadge({required this.typeCompte});

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = typeCompte >= 2
        ? ('Super Admin', Icons.shield, const Color(0xFF6B3CD2), const Color(0xFFEDE3FC))
        : ('Admin', Icons.verified_user, const Color(0xFF1E66D8), const Color(0xFFE3EEFE));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
