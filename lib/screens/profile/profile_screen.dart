import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../core/utils/app_log.dart';
import '../../talky_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/user_search.dart';
import '../authentification/login_screen.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../core/utils/alanya_phone_formatter.dart';
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
  @override
  void initState() {
    super.initState();
    unawaited(context.read<AuthProvider>().refreshProfile());
    unawaited(context.read<LocalCacheRepository>().syncPreferredContacts());
  }

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
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      await cache.upsertKnownUser(user, preferred: false);
    } catch (e, st) {
      AppLog.e('ProfileScreen', 'Suppression contact préféré échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.unableToRemoveThisContactTry)),
      );
    }
  }

  void _openPreferredContacts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PreferredContactsScreen()),
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
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AppSpacing.vGapLg,
            ListTile(
              leading: Icon(Icons.person_remove_outlined,
                  color: context.colors.error),
              title: Text(
                context.l10n.removePreferredContact(user.nom.isNotEmpty ? user.nom : user.pseudo),
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
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isLoading = user == null && !auth.isInitialized;
    final cache = context.read<LocalCacheRepository>();

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(context.l10n.navProfile, style: context.text.headlineLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
        child: Column(
          children: [
            AppSpacing.vGapXl,
            _ProfileHeader(
              user: user,
              isLoading: isLoading,
            ),
            if (!isLoading &&
                user != null &&
                user.email.trim().isEmpty) ...[
              AppSpacing.vGapMd,
              Padding(
                padding: AppSpacing.screenH,
                child: Material(
                  color: context.colors.errorContainer,
                  borderRadius: AppRadius.brSm,
                  child: InkWell(
                    borderRadius: AppRadius.brSm,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: AppIconSize.sm,
                            color: context.colors.onErrorContainer,
                          ),
                          AppSpacing.hGapSm,
                          Expanded(
                            child: Text(
                              context.l10n.profileNoEmailChip,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onErrorContainer,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: AppIconSize.sm,
                            color: context.colors.onErrorContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            AppSpacing.vGapXl,

            StreamBuilder<List<LocalUser>>(
              stream: cache.watchPreferredContacts(),
              builder: (context, snapshot) {
                final contacts =
                    (snapshot.data ?? []).map(localUserToUser).toList();
                final loadingContacts =
                    snapshot.connectionState == ConnectionState.waiting &&
                        contacts.isEmpty;

                return Column(
                  children: [
                    Padding(
                      padding: AppSpacing.screenH,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.preferredContacts,
                            style: context.text.titleMedium,
                          ),
                          if (contacts.length > 4)
                            GestureDetector(
                              onTap: _openPreferredContacts,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '+${contacts.length - 4}',
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
                    if (loadingContacts)
                      Padding(
                        padding: AppSpacing.card,
                        child: const CircularProgressIndicator(),
                      )
                    else if (contacts.isEmpty)
                      _EmptyContacts(onAdd: _openPreferredContacts)
                    else
                      _ContactGrid(
                        contacts: contacts,
                        onLongPress: _showContactOptions,
                      ),
                  ],
                );
              },
            ),

            AppSpacing.vGapXl,

            Container(
              margin: AppSpacing.screenH,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.brMd,
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                children: [
                  _buildMenuItem(CupertinoIcons.person, context.l10n.accountLabel, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    );
                  }),
                  const Divider(height: 1),
                  _buildMenuItem(CupertinoIcons.settings, context.l10n.settingsTitle, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  }),
                  if (!isLoading &&
                      user != null &&
                      user.typeCompte >= 1) ...[
                    const Divider(height: 1),
                    _buildMenuItem(Icons.admin_panel_settings,
                        context.l10n.adminDashboard, () {
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
                    color: context.colors.errorContainer,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(Icons.logout,
                      color: context.colors.error,
                      size: AppIconSize.sm),
                ),
                title: Text(
                  context.l10n.signOut,
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
          color: context.semantic.brandContainer,
          borderRadius: AppRadius.brSm,
        ),
        child: Icon(icon, color: context.colors.primary, size: AppIconSize.sm),
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

  const _ProfileHeader({
    required this.user,
    required this.isLoading,
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
                              Container(color: context.semantic.brandContainer),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm - 2),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: context.colors.onPrimary,
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
              user?.nom ?? context.l10n.userFallback,
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
                  AlanyaPhoneText(
                    phone,
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
                                Container(color: context.semantic.brandContainer),
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
                        color: context.semantic.online,
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
              AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone),
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
            context.l10n.noPreferredContacts,
            style: context.text.titleSmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.vGapSm,
          Text(
            context.l10n.addContactsToFindThemQuickly,
            textAlign: TextAlign.center,
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.outlineVariant),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(
              context.l10n.addAContact,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
    final superAdminAccent = const Color(0xFF7C4DFF);
    final (label, icon, fg, bg) = typeCompte >= 2
        ? (
            context.l10n.superAdmin,
            Icons.shield,
            superAdminAccent,
            superAdminAccent.withValues(alpha: 0.16),
          )
        : (context.l10n.admin, Icons.verified_user, context.colors.primary,
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
      color: context.semantic.brandContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: context.colors.primary,
        ),
      ),
    );
  }
}
