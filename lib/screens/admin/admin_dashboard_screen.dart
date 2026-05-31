import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'admin_user_detail_screen.dart';

enum _UserFilter { all, online, banned, admin }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchCtrl = TextEditingController();
  _UserFilter _filter = _UserFilter.all;

  String? get _statusFilter => switch (_filter) {
        _UserFilter.online => 'online',
        _UserFilter.banned => 'banned',
        _UserFilter.admin => 'admin',
        _UserFilter.all => null,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      provider.loadStats();
      provider.loadUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final p = context.read<AdminProvider>();
    await Future.wait([
      p.loadStats(),
      p.loadUsers(search: _searchCtrl.text, status: _statusFilter),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final stats = provider.stats;
    final users = provider.users;

    final onlinePct = stats.totalUsers > 0
        ? (stats.onlineUsers * 100 / stats.totalUsers)
        : 0.0;
    final bannedPct = stats.totalUsers > 0
        ? (stats.bannedUsers * 100 / stats.totalUsers)
        : 0.0;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Tableau de bord'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: provider.isLoadingUsers || provider.isLoadingStats
                ? null
                : _refresh,
            icon: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.isLoadingStats && provider.users.isEmpty
            ? const LoadingState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
                children: [
                  Text('Bienvenue', style: context.text.headlineLarge),
                  AppSpacing.vGapSm,
                  Text(
                    'Gérez les utilisateurs et surveillance',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  AppSpacing.vGapXxl,
                  Text(
                    "Vue d'ensemble",
                    style: context.text.titleSmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  AppSpacing.vGapMd,
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.05,
                    children: [
                      _GradientStatCard(
                        label: 'Utilisateurs',
                        value: '${stats.totalUsers}',
                        sub: 'Total',
                        icon: CupertinoIcons.person_2_fill,
                        colors: const [Color(0xFF5B8DEF), Color(0xFF4A6FD0)],
                      ),
                      _GradientStatCard(
                        label: 'En ligne',
                        value: '${stats.onlineUsers}',
                        sub: '${onlinePct.toStringAsFixed(1)}%',
                        icon: CupertinoIcons.circle_fill,
                        colors: const [Color(0xFF5DBE7A), Color(0xFF3FA45F)],
                      ),
                      _GradientStatCard(
                        label: 'Messages (7j)',
                        value: '${stats.messagesPeriod}',
                        sub: 'Dernière semaine',
                        icon: CupertinoIcons.chat_bubble_2_fill,
                        colors: const [Color(0xFF4FC3D8), Color(0xFF2BA5BD)],
                      ),
                      _GradientStatCard(
                        label: 'Appels (7j)',
                        value: '${stats.callsPeriod}',
                        sub: 'Dernière semaine',
                        icon: CupertinoIcons.phone_fill,
                        colors: const [Color(0xFFFFA552), Color(0xFFE9803D)],
                      ),
                      _GradientStatCard(
                        label: 'Statuts (7j)',
                        value: '${stats.statusesPeriod}',
                        sub: 'Dernière semaine',
                        icon: CupertinoIcons.sparkles,
                        colors: const [Color(0xFFE94BA0), Color(0xFFB23DBF)],
                      ),
                      _GradientStatCard(
                        label: 'Bannis',
                        value: '${stats.bannedUsers}',
                        sub: '${bannedPct.toStringAsFixed(1)}%',
                        icon: CupertinoIcons.nosign,
                        colors: const [Color(0xFFEC5C5C), Color(0xFFD8453E)],
                      ),
                    ],
                  ),
                  AppSpacing.vGapXl,

                  // Filter chips
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          label: 'Tous',
                          icon: CupertinoIcons.person_2,
                          selected: _filter == _UserFilter.all,
                          onTap: () {
                            setState(() => _filter = _UserFilter.all);
                            context.read<AdminProvider>().loadUsers(
                                  search: _searchCtrl.text,
                                  status: _statusFilter,
                                  page: 1,
                                );
                          },
                          showCheck: true,
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: _FilterChip(
                          label: 'En ligne',
                          icon: CupertinoIcons.circle_fill,
                          selected: _filter == _UserFilter.online,
                          onTap: () {
                            setState(() => _filter = _UserFilter.online);
                            context.read<AdminProvider>().loadUsers(
                                  search: _searchCtrl.text,
                                  status: _statusFilter,
                                  page: 1,
                                );
                          },
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: _FilterChip(
                          label: 'Bannis',
                          icon: CupertinoIcons.nosign,
                          selected: _filter == _UserFilter.banned,
                          onTap: () {
                            setState(() => _filter = _UserFilter.banned);
                            context.read<AdminProvider>().loadUsers(
                                  search: _searchCtrl.text,
                                  status: _statusFilter,
                                  page: 1,
                                );
                          },
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: _FilterChip(
                          label: 'Admins',
                          icon: CupertinoIcons.shield_lefthalf_fill,
                          selected: _filter == _UserFilter.admin,
                          onTap: () {
                            setState(() => _filter = _UserFilter.admin);
                            context.read<AdminProvider>().loadUsers(
                                  search: _searchCtrl.text,
                                  status: _statusFilter,
                                  page: 1,
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vGapMd,

                  // Search bar
                  AppSearchField(
                    controller: _searchCtrl,
                    hintText: 'Rechercher par nom, pseudo ou ...',
                    onChanged: (val) {
                      setState(() {});
                      provider.setSearchQuery(val);
                      provider.loadUsers(
                          search: val, status: _statusFilter);
                    },
                    onClear: () {
                      _searchCtrl.clear();
                      provider.setSearchQuery('');
                      provider.loadUsers(status: _statusFilter);
                      setState(() {});
                    },
                  ),
                  AppSpacing.vGapLg,

                  // Users list
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        provider.error!,
                        style: TextStyle(
                            color: context.colors.error, fontSize: 13),
                      ),
                    ),
                  if (users.isEmpty && !provider.isLoadingUsers)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(
                          child: Text('Aucun utilisateur trouvé')),
                    )
                  else if (provider.isLoadingUsers && users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: AppRadius.brSm,
                        border: Border.all(color: context.colors.outline),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: context.colors.outline,
                          indent: AppSpacing.lg,
                          endIndent: AppSpacing.lg,
                        ),
                        itemBuilder: (ctx, idx) {
                          final user = users[idx];
                          return _UserTile(
                              user: user, provider: provider);
                        },
                      ),
                    ),
                  AppSpacing.vGapLg,

                  // Pagination
                  if (provider.totalUsers > provider.limit)
                    _Pagination(
                      page: provider.page,
                      limit: provider.limit,
                      total: provider.totalUsers,
                      isLoading: provider.isLoadingUsers,
                      onChangePage: (p) => provider.loadUsers(
                        search: _searchCtrl.text,
                        status: _statusFilter,
                        page: p,
                        limit: provider.limit,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _GradientStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final List<Color> colors;

  const _GradientStatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.brLg,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: -10,
            child: Icon(icon, size: 80,
                color: Colors.white.withValues(alpha: 0.10)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                AppSpacing.vGapXs,
                Text(
                  sub,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheck;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.showCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? context.colors.primaryContainer
        : context.colors.surface;
    final border = selected
        ? context.colors.primaryContainer
        : context.colors.outline;
    final fg = selected
        ? context.colors.primary
        : context.colors.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.brSm,
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showCheck && selected) ...[
              Icon(Icons.check, size: 16, color: fg),
              AppSpacing.hGapXs,
            ],
            Icon(icon, size: 16, color: fg),
            AppSpacing.hGapSm,
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final AdminProvider provider;

  const _UserTile({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AdminUserDetailScreen(userId: user.alanyaID),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Stack(
              children: [
                AppAvatar(
                  imageUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                  name: user.nom.isNotEmpty ? user.nom : '?',
                  size: AppSizes.avatarMd,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.colors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nom.isNotEmpty ? user.nom : '—',
                          style: context.text.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.exclus) ...[
                        AppSpacing.hGapSm,
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm - 2, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: _kBrXs,
                          ),
                          child: Text(
                            'Banni',
                            style: TextStyle(
                              color: context.colors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (user.typeCompte >= 1) ...[
                        AppSpacing.hGapSm,
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm - 2, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.primaryContainer,
                            borderRadius: _kBrXs,
                          ),
                          child: Text(
                            'Admin',
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    user.pseudo.isNotEmpty
                        ? '@${user.pseudo}'
                        : user.alanyaPhone,
                    style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    '${user.alanyaID}',
                    style: context.text.labelSmall
                        ?.copyWith(color: context.colors.outlineVariant),
                  ),
                ],
              ),
            ),
            _UserActions(user: user, provider: provider),
          ],
        ),
      ),
    );
  }
}

// Petit rayon pour les badges inline — non défini dans AppRadius.
const _kBrXs = BorderRadius.all(Radius.circular(6));

class _UserActions extends StatelessWidget {
  final User user;
  final AdminProvider provider;

  const _UserActions({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.more_vert, color: context.colors.onSurfaceVariant),
      itemBuilder: (context) => [
        if (!user.exclus)
          PopupMenuItem(
            child: const Text('Bannir'),
            onTap: () async => await provider.toggleBan(user),
          )
        else
          PopupMenuItem(
            child: const Text('Débannir'),
            onTap: () async => await provider.toggleBan(user),
          ),
        if (user.typeCompte < 1)
          PopupMenuItem(
            child: const Text('Rendre admin'),
            onTap: () async =>
                await provider.setAccountType(user.alanyaID, 1),
          )
        else
          PopupMenuItem(
            child: const Text('Rétrograder'),
            onTap: () async =>
                await provider.setAccountType(user.alanyaID, 0),
          ),
        PopupMenuItem(
          child: const Text('Supprimer'),
          onTap: () async {
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
            if (confirmed == true) {
              await provider.deleteUser(user.alanyaID);
            }
          },
        ),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final int limit;
  final int total;
  final bool isLoading;
  final ValueChanged<int> onChangePage;

  const _Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.isLoading,
    required this.onChangePage,
  });

  @override
  Widget build(BuildContext context) {
    final pageCount = (total / limit).ceil().clamp(1, 1 << 30);
    final canPrev = page > 1 && !isLoading;
    final canNext = page < pageCount && !isLoading;
    final from = (page - 1) * limit + 1;
    final to = (page * limit).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: context.colors.outline),
      ),
      child: Row(
        children: [
          _PageBtn(
            icon: CupertinoIcons.chevron_left,
            enabled: canPrev,
            onTap: () => onChangePage(page - 1),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              children: [
                Text(
                  'Page $page / $pageCount',
                  style: context.text.labelMedium,
                ),
                AppSpacing.vGapXs,
                Text(
                  '$from–$to sur $total',
                  style: context.text.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          AppSpacing.hGapSm,
          _PageBtn(
            icon: CupertinoIcons.chevron_right,
            enabled: canNext,
            onTap: () => onChangePage(page + 1),
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? context.colors.primary : context.colors.outline;
    final bg = enabled
        ? context.colors.primaryContainer
        : context.semantic.surfaceMuted;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.brSm,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.brSm,
        ),
        child: Icon(icon, color: color, size: AppIconSize.sm),
      ),
    );
  }
}
