import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<_UserDetailData> _future;
  String _appBarName = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_UserDetailData> _load() async {
    final provider = context.read<AdminProvider>();
    final api = context.read<TalkyApiClient>();
    final user = await provider.getUserById(widget.userId);
    if (mounted) {
      setState(() {
        _appBarName =
            user.nom.isNotEmpty ? user.nom : 'Utilisateur';
      });
    }
    Map<String, dynamic> activity = const {};
    List<dynamic> logins = const [];
    try {
      activity = await api.adminGetUserActivity(widget.userId);
    } catch (_) {}
    try {
      logins =
          await api.adminGetUserLogins(widget.userId, limit: 10);
    } catch (_) {}
    return _UserDetailData(
        user: user, activity: activity, logins: logins);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        centerTitle: true,
        title: Text(_appBarName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: FutureBuilder<_UserDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState();
          }
          if (!snapshot.hasData) {
            return Center(
              child: Padding(
                padding: AppSpacing.card,
                child: Text(
                  'Erreur: ${snapshot.error ?? "données indisponibles"}',
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurface),
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final user = data.user;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                _ProfileCard(user: user),
                AppSpacing.vGapLg,
                _ActivityCard(activity: data.activity),
                AppSpacing.vGapLg,
                _LoginsCard(logins: data.logins),
                AppSpacing.vGapLg,
                _ActionsCard(user: user, onChanged: _reload),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserDetailData {
  final User user;
  final Map<String, dynamic> activity;
  final List<dynamic> logins;
  _UserDetailData({
    required this.user,
    required this.activity,
    required this.logins,
  });
}

// ── PROFILE CARD ──────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final User user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.sm),
      child: Column(
        children: [
          AppAvatar(
            imageUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
            name: user.nom.isNotEmpty ? user.nom : '?',
            size: 112,
          ),
          AppSpacing.vGapMd,
          Text(
            user.nom.isNotEmpty ? user.nom : '—',
            style: context.text.headlineSmall,
          ),
          AppSpacing.vGapXs,
          if (user.pseudo.isNotEmpty)
            Text(
              '@${user.pseudo}',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          AppSpacing.vGapSm,
          _RoleBadge(typeCompte: user.typeCompte, banned: user.exclus),
          AppSpacing.vGapLg,
          Divider(color: context.colors.outline, height: 1),
          AppSpacing.vGapSm,
          _InfoRow(label: 'ID', value: '${user.alanyaID}'),
          _InfoRow(label: 'Téléphone', value: user.alanyaPhone),
          _InfoRow(label: 'Email', value: user.email),
          if ((user.paysLibelle ?? '').isNotEmpty)
            _InfoRow(label: 'Pays', value: user.paysLibelle!),
          _InfoRow(
              label: 'Inscrit(e) le',
              value: _formatDate(user.createdAt)),
          _InfoRow(
              label: 'Dernière vue',
              value: _formatDate(user.lastSeen)),
          if (user.exclus &&
              (user.excludeReason ?? '').isNotEmpty)
            _InfoRow(
                label: 'Motif ban', value: user.excludeReason!),
          AppSpacing.vGapSm,
        ],
      ),
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _RoleBadge extends StatelessWidget {
  final int typeCompte;
  final bool banned;
  const _RoleBadge({required this.typeCompte, required this.banned});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = banned
        ? ('Banni', context.colors.error, context.colors.errorContainer)
        : typeCompte >= 2
            ? ('Super Admin', const Color(0xFF7C4DFF),
                Color(0xFF7C4DFF).withValues(alpha: 0.16))
            : typeCompte >= 1
                ? ('Admin', context.colors.primary,
                    context.colors.primaryContainer)
                : ('Utilisateur', context.colors.onSurfaceVariant,
                    context.semantic.surfaceMuted);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm - 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: TextStyle(
            color: fg, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.text.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ACTIVITY CARD ─────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityCard({required this.activity});

  int _i(String key) {
    final v = activity[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs sémantiques intentionnelles pour les métriques d'activité.
    final items = [
      _ActivityItem(
        label: 'Messages',
        value: _i('messagesSent'),
        icon: CupertinoIcons.chat_bubble_2_fill,
        iconColor: const Color(0xFF3B82F6),
      ),
      _ActivityItem(
        label: 'Conversations',
        value: _i('conversations'),
        icon: CupertinoIcons.chat_bubble_2,
        iconColor: const Color(0xFF14B8A6),
      ),
      _ActivityItem(
        label: 'Appels émis',
        value: _i('callsMade'),
        icon: Icons.phone_forwarded,
        iconColor: AppColors.warning,
      ),
      _ActivityItem(
        label: 'Appels reçus',
        value: _i('callsReceived'),
        icon: Icons.phone_callback,
        iconColor: AppColors.error,
      ),
      _ActivityItem(
        label: 'Statuts',
        value: _i('statusesPublished'),
        icon: CupertinoIcons.sparkles,
        iconColor: const Color(0xFFEC4899),
      ),
    ];
    return _Card(
      padding: AppSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activité', style: context.text.titleLarge),
          AppSpacing.vGapMd,
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.4,
            children: items,
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  const _ActivityItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.10),
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: context.text.titleSmall
                      ?.copyWith(height: 1.15),
                ),
                Text(
                  label,
                  style: context.text.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      height: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── LOGINS CARD ───────────────────────────────────────────────────────

class _LoginsCard extends StatelessWidget {
  final List<dynamic> logins;
  const _LoginsCard({required this.logins});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: AppSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connexions récentes', style: context.text.titleLarge),
          AppSpacing.vGapMd,
          if (logins.isEmpty)
            Text(
              'Aucune connexion enregistrée',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            )
          else
            ...logins.take(5).map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return _LoginRow(
                date: m['dateLogin']?.toString() ?? '',
                device: m['device']?.toString() ?? '',
                ip: m['ipAdress']?.toString() ?? '',
                os: m['os_system']?.toString() ?? '',
              );
            }),
        ],
      ),
    );
  }
}

class _LoginRow extends StatelessWidget {
  final String date;
  final String device;
  final String ip;
  final String os;
  const _LoginRow({
    required this.date,
    required this.device,
    required this.ip,
    required this.os,
  });

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (os.isNotEmpty) os,
      if (device.isNotEmpty) device,
      if (ip.isNotEmpty) ip,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.colors.primaryContainer,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(
              CupertinoIcons.device_phone_portrait,
              size: 16,
              color: context.colors.primary,
            ),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmt(date),
                    style: context.text.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ACTIONS CARD ──────────────────────────────────────────────────────

class _ActionsCard extends StatelessWidget {
  final User user;
  final Future<void> Function() onChanged;
  const _ActionsCard({required this.user, required this.onChanged});

  Future<void> _toggleBan(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    await provider.toggleBan(user);
    await onChanged();
  }

  Future<void> _toggleAdmin(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    final newType = user.typeCompte >= 1 ? 0 : 1;
    await provider.setAccountType(user.alanyaID, newType);
    await onChanged();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final provider = context.read<AdminProvider>();
    await provider.deleteUser(user.alanyaID);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                right: AppSpacing.sm, bottom: AppSpacing.xs),
            child: Text('Actions', style: context.text.titleLarge),
          ),
          _ActionRow(
            icon: user.exclus
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.nosign,
            label: user.exclus ? 'Débannir' : 'Bannir',
            iconColor:
                user.exclus ? AppColors.success : AppColors.error,
            iconBg: user.exclus
                ? context.semantic.successContainer
                : context.colors.errorContainer,
            labelColor:
                user.exclus ? AppColors.success : AppColors.error,
            onTap: () => _toggleBan(context),
          ),
          _ActionRow(
            icon: user.typeCompte >= 1
                ? CupertinoIcons.shield_slash_fill
                : CupertinoIcons.shield_fill,
            label: user.typeCompte >= 1
                ? 'Rétrograder'
                : 'Rendre admin',
            iconColor: context.colors.primary,
            iconBg: context.colors.primaryContainer,
            onTap: () => _toggleAdmin(context),
          ),
          _ActionRow(
            icon: CupertinoIcons.trash_fill,
            label: 'Supprimer',
            iconColor: AppColors.error,
            iconBg: context.colors.errorContainer,
            labelColor: AppColors.error,
            onTap: () => _delete(context),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final Color? labelColor;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: AppRadius.brSm,
              ),
              child: Icon(icon, color: iconColor, size: AppIconSize.sm),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                label,
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? context.colors.onSurface,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: context.colors.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ── CARD CONTAINER ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
