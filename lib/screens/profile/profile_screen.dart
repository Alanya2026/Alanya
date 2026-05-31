import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/country_utils.dart';
import '../authentification/login_screen.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/add_contact_sheet.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
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
    final cached =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getMe();
      if (!mounted) return;
      final user = User.fromJson(data);
      final full = await apiClient
          .getUserById(user.alanyaID)
          .catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      final paysLibelle =
          full['pays_libelle'] as String? ?? user.paysLibelle;
      setState(() {
        _user = User(
          alanyaID: user.alanyaID,
          nom: user.nom,
          pseudo: user.pseudo,
          alanyaPhone:
              full['alanyaPhone'] as String? ?? user.alanyaPhone,
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
      if (mounted && _user == null) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContacts() async {
    try {
      final cache =
          Provider.of<LocalCacheRepository>(context, listen: false);
      final local = await cache.watchPreferredContacts().first;
      if (!mounted) return;
      if (local.isNotEmpty) {
        setState(() {
          _contacts = local.map(_localToUser).toList();
          _loadingContacts = false;
        });
      } else {
        setState(() => _loadingContacts = true);
      }
    } catch (_) {}

    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = data
            .map((e) =>
                e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingContacts = false;
      });
      if (mounted) {
        final cache =
            Provider.of<LocalCacheRepository>(context, listen: false);
        cache.syncPreferredContacts();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  User _localToUser(LocalUser u) => User(
        alanyaID: u.alanyaID,
        nom: u.nom,
        pseudo: u.pseudo,
        alanyaPhone: u.alanyaPhone,
        email: u.email,
        idPays: u.idPays,
        avatarUrl: u.avatarUrl,
        typeCompte: u.typeCompte,
        isOnline: u.isOnline,
        lastSeen: u.lastSeen?.toIso8601String() ?? '',
        paysLibelle: u.paysLibelle,
      );

  Future<void> _logout() async {
    final authProvider =
        Provider.of<AuthProvider>(context, listen: false);
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
      setState(
          () => _contacts.removeWhere((u) => u.alanyaID == user.alanyaID));
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
        onAdded: (user) => setState(() => _contacts.add(user)),
      ),
    );
  }

  void _showContactOptions(User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.sheetTop),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.vGapSm,
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AppSpacing.vGapLg,
            ListTile(
              leading: Icon(Icons.person_remove_outlined,
                  color: context.colors.error),
              title: Text(
                'Retirer ${user.nom.isNotEmpty ? user.nom : user.pseudo} des contacts préférés',
                style: TextStyle(color: context.colors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _removeContact(user);
              },
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text('Profil', style: context.text.headlineLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
        child: Column(
          children: [
            AppSpacing.vGapXl,
            _ProfileHeader(
              user: _user,
              isLoading: _isLoading,
              onEdited: _loadUser,
            ),
            AppSpacing.vGapXl,

            // Section contacts préférés
            Padding(
              padding: AppSpacing.screenH,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contacts préférés',
                    style: context.text.titleMedium,
                  ),
                  if (_contacts.length > 4)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PreferredContactsScreen(
                            contacts: _contacts,
                            onLongPress: _showContactOptions,
                            onAddContact: _openAddContact,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+${_contacts.length - 4}',
                            style: context.text.labelMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: AppIconSize.sm,
                              color: context.colors.primary),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            AppSpacing.vGapMd,

            _loadingContacts
                ? Padding(
                    padding: AppSpacing.card,
                    child: const CircularProgressIndicator(),
                  )
                : _contacts.isEmpty
                    ? _EmptyContacts(
                        onAdd: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreferredContactsScreen(
                              contacts: _contacts,
                              onLongPress: _showContactOptions,
                              onAddContact: _openAddContact,
                            ),
                          ),
                        ),
                      )
                    : _ContactGrid(
                        contacts: _contacts,
                        onLongPress: _showContactOptions,
                      ),

            AppSpacing.vGapXl,

            // Menu paramètres
            Container(
              margin: AppSpacing.screenH,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.brMd,
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                children: [
                  _buildMenuItem(CupertinoIcons.person, 'Compte',
                      () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    );
                    if (mounted) _loadUser();
                  }),
                  const Divider(height: 1),
                  _buildMenuItem(
                      CupertinoIcons.chat_bubble, 'Discussions', () {}),
                  const Divider(height: 1),
                  _buildMenuItem(
                      CupertinoIcons.bell, 'Notifications', () {}),
                  const Divider(height: 1),
                  _buildMenuItem(CupertinoIcons.settings, 'Paramètres',
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  }),
                  if (!_isLoading &&
                      _user != null &&
                      _user!.typeCompte >= 1) ...[
                    const Divider(height: 1),
                    _buildMenuItem(Icons.admin_panel_settings,
                        'Tableau de bord Admin', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const AdminDashboardScreen()),
                      );
                    }),
                  ],
                ],
              ),
            ),

            AppSpacing.vGapXl,

            // Déconnexion
            Container(
              margin: AppSpacing.screenH,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.brMd,
                boxShadow: AppShadows.subtle,
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(Icons.logout,
                      color: context.colors.error,
                      size: AppIconSize.sm),
                ),
                title: Text(
                  'Déconnexion',
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colors.error,
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: context.colors.outlineVariant),
                onTap: _logout,
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
      IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.brandContainer,
          borderRadius: AppRadius.brSm,
        ),
        child: Icon(icon, color: AppColors.brandPrimary, size: AppIconSize.sm),
      ),
      title: Text(
        title,
        style: context.text.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 16, color: context.colors.outlineVariant),
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
    final hasPhoto = user != null && (user!.avatarUrl.isNotEmpty);
    final initial =
        user?.nom.isNotEmpty == true ? user!.nom[0].toUpperCase() : 'U';
    final pseudo = user?.pseudo ?? '';
    final phone = user?.alanyaPhone ?? '';
    final pays = user?.paysLibelle ?? '';

    return Container(
      margin: AppSpacing.screenH,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxxl, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: hasPhoto
                      ? CachedNetworkImage(
                          imageUrl: user!.avatarUrl.trim(),
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.brandContainer),
                          errorWidget: (_, __, ___) =>
                              _AvatarFallback(initial: initial, fontSize: 40),
                        )
                      : _AvatarFallback(initial: initial, fontSize: 40),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    );
                    onEdited?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm - 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.white,
                      size: AppIconSize.sm,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vGapLg,
          if (isLoading)
            const CircularProgressIndicator()
          else ...[
            Text(
              user?.nom ?? 'User',
              style: context.text.headlineSmall,
            ),
            if ((user?.typeCompte ?? 0) >= 1) ...[
              AppSpacing.vGapSm,
              _RoleBadge(typeCompte: user!.typeCompte),
            ],
            if (pseudo.isNotEmpty) ...[
              AppSpacing.vGapXs,
              Text(
                '@$pseudo',
                style: context.text.bodyLarge?.copyWith(
                    color: context.colors.onSurfaceVariant),
              ),
            ],
            if (phone.isNotEmpty) ...[
              AppSpacing.vGapSm,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_iphone,
                      size: AppIconSize.sm,
                      color: context.colors.primary),
                  AppSpacing.hGapXs,
                  Text(
                    'AlanyaPhone $phone',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (pays.isNotEmpty) ...[
              AppSpacing.vGapXs,
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
      margin: AppSpacing.screenH,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: displayed
            .map((user) =>
                _ContactChip(user: user, onLongPress: onLongPress))
            .toList(),
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
    final hasPhoto = user.avatarUrl.isNotEmpty;
    final initial =
        user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
    final displayName = user.nom.isNotEmpty ? user.nom : user.pseudo;
    final shortName = displayName.length > 8
        ? '${displayName.substring(0, 7)}…'
        : displayName;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContactDetailScreen(
            userId: user.alanyaID,
            initialName: user.nom,
            initialAvatar: user.avatarUrl,
          ),
        ),
      ),
      onLongPress: () => onLongPress(user),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: AppSizes.avatarLg,
                    height: AppSizes.avatarLg,
                    child: hasPhoto
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl.trim(),
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppColors.brandContainer),
                            errorWidget: (_, __, ___) =>
                                _AvatarFallback(initial: initial, fontSize: 18),
                          )
                        : _AvatarFallback(initial: initial, fontSize: 18),
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
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.colors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.vGapSm,
            Text(
              shortName,
              style: context.text.labelSmall
                  ?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.vGapXs,
            Text(
              user.alanyaPhone,
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
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
      margin: AppSpacing.screenH,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxl + 4, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: context.colors.outline),
      ),
      child: Column(
        children: [
          Icon(CupertinoIcons.person_2,
              size: 44, color: context.colors.outline),
          AppSpacing.vGapMd,
          Text(
            'Aucun contact préféré',
            style: context.text.titleSmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.vGapSm,
          Text(
            'Ajoutez des contacts pour les retrouver\nrapidement lors de vos réunions',
            textAlign: TextAlign.center,
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.outlineVariant),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text(
              'Ajouter un contact',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge de rôle ────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final int typeCompte;
  const _RoleBadge({required this.typeCompte});

  @override
  Widget build(BuildContext context) {
    // Couleurs spécifiques aux badges admin — pas de token car design intentionnel.
    final (label, icon, fg, bg) = typeCompte >= 2
        ? ('Super Admin', Icons.shield, const Color(0xFF6B3CD2),
            const Color(0xFFEDE3FC))
        : ('Admin', Icons.verified_user, context.colors.primary,
            context.colors.primaryContainer);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          AppSpacing.hGapXs,
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

class _AvatarFallback extends StatelessWidget {
  final String initial;
  final double fontSize;
  const _AvatarFallback({required this.initial, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }
}
