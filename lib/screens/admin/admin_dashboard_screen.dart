import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../talky_models.dart';
import 'admin_user_detail_screen.dart';

enum _UserFilter { all, online, banned }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchCtrl = TextEditingController();
  _UserFilter _filter = _UserFilter.all;

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
    await Future.wait([p.loadStats(), p.loadUsers(search: _searchCtrl.text)]);
  }

  List<User> _filteredUsers(List<User> users) {
    final q = _searchCtrl.text.trim().toLowerCase();
    Iterable<User> base = users;
    switch (_filter) {
      case _UserFilter.online:
        base = base.where((u) => u.isOnline && !u.exclus);
        break;
      case _UserFilter.banned:
        base = base.where((u) => u.exclus);
        break;
      case _UserFilter.all:
        break;
    }
    if (q.isNotEmpty) {
      base = base.where((u) {
        return u.nom.toLowerCase().contains(q) ||
            u.pseudo.toLowerCase().contains(q) ||
            u.alanyaPhone.toLowerCase().contains(q) ||
            u.alanyaID.toString().contains(q);
      });
    }
    return base.toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final stats = provider.stats;
    final users = _filteredUsers(provider.users);

    final onlinePct = stats.totalUsers > 0
        ? (stats.onlineUsers * 100 / stats.totalUsers)
        : 0.0;
    final bannedPct = stats.totalUsers > 0
        ? (stats.bannedUsers * 100 / stats.totalUsers)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          'Tableau de bord',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
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
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text(
                    'Bienvenue',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gérez les utilisateurs et surveillance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Vue d'ensemble",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
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
                  const SizedBox(height: 20),

                  // Filter chips
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          label: 'Tous',
                          icon: CupertinoIcons.person_2,
                          selected: _filter == _UserFilter.all,
                          onTap: () => setState(() => _filter = _UserFilter.all),
                          showCheck: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FilterChip(
                          label: 'En ligne',
                          icon: CupertinoIcons.circle_fill,
                          selected: _filter == _UserFilter.online,
                          onTap: () =>
                              setState(() => _filter = _UserFilter.online),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _FilterChip(
                          label: 'Bannis',
                          icon: CupertinoIcons.nosign,
                          selected: _filter == _UserFilter.banned,
                          onTap: () =>
                              setState(() => _filter = _UserFilter.banned),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, pseudo ou ...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  CupertinoIcons.xmark_circle_fill,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  provider.setSearchQuery('');
                                  provider.loadUsers();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {});
                        provider.setSearchQuery(val);
                        provider.loadUsers(search: val);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Users list
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  if (users.isEmpty && !provider.isLoadingUsers)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Aucun utilisateur trouvé')),
                    )
                  else if (provider.isLoadingUsers && users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: Colors.grey.shade200,
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (ctx, idx) {
                          final user = users[idx];
                          return _UserTile(
                            user: user,
                            provider: provider,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Pagination
                  if (_filter == _UserFilter.all &&
                      _searchCtrl.text.isEmpty &&
                      provider.totalUsers > provider.limit)
                    _Pagination(
                      page: provider.page,
                      limit: provider.limit,
                      total: provider.totalUsers,
                      isLoading: provider.isLoadingUsers,
                      onChangePage: (p) => provider.loadUsers(
                        search: _searchCtrl.text,
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
        borderRadius: BorderRadius.circular(20),
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
          // Decorative bubble
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
            child: Icon(
              icon,
              size: 80,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
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
                const SizedBox(height: 2),
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
    final bg = selected ? const Color(0xFFE3EEFE) : Colors.white;
    final border = selected ? const Color(0xFFBFD6FB) : const Color(0xFFE5E7EB);
    final fg = selected ? const Color(0xFF1E66D8) : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showCheck && selected) ...[
              Icon(Icons.check, size: 16, color: fg),
              const SizedBox(width: 4),
            ],
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminUserDetailScreen(userId: user.alanyaID),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFEDEDED),
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? NetworkImage(user.avatarUrl)
                      : null,
                  child: user.avatarUrl.isEmpty
                      ? Text(
                          user.nom.isNotEmpty
                              ? user.nom[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3FA45F),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nom.isNotEmpty ? user.nom : '—',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.exclus) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Banni',
                            style: TextStyle(
                              color: Color(0xFFD8453E),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (user.typeCompte >= 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3EEFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              color: Color(0xFF1E66D8),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.pseudo.isNotEmpty ? '@${user.pseudo}' : user.alanyaPhone,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.alanyaID}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
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

class _UserActions extends StatelessWidget {
  final User user;
  final AdminProvider provider;

  const _UserActions({required this.user, required this.provider});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(Icons.more_vert, color: Colors.grey.shade500),
      itemBuilder: (context) => [
        if (!user.exclus)
          PopupMenuItem(
            child: const Text('Bannir'),
            onTap: () async {
              await provider.toggleBan(user);
            },
          )
        else
          PopupMenuItem(
            child: const Text('Débannir'),
            onTap: () async {
              await provider.toggleBan(user);
            },
          ),
        if (user.typeCompte < 1)
          PopupMenuItem(
            child: const Text('Rendre admin'),
            onTap: () async {
              await provider.setAccountType(user.alanyaID, 1);
            },
          )
        else
          PopupMenuItem(
            child: const Text('Rétrograder'),
            onTap: () async {
              await provider.setAccountType(user.alanyaID, 0);
            },
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
                      style: TextStyle(color: Colors.red),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          _PageBtn(
            icon: CupertinoIcons.chevron_left,
            enabled: canPrev,
            onTap: () => onChangePage(page - 1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Page $page / $pageCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$from–$to sur $total',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
    final color = enabled ? const Color(0xFF1E66D8) : Colors.grey.shade400;
    final bg = enabled ? const Color(0xFFE3EEFE) : const Color(0xFFF3F4F6);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
