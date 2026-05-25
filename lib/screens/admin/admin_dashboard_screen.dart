import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../talky_models.dart';
import 'admin_user_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
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
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats section
                  Text(
                    'Statistiques',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _StatCard(
                        label: 'Total utilisateurs',
                        value: '${provider.stats.totalUsers}',
                        icon: CupertinoIcons.person_2_fill,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        label: 'En ligne',
                        value: '${provider.stats.onlineUsers}',
                        icon: CupertinoIcons.circle_fill,
                        color: Colors.green,
                      ),
                      _StatCard(
                        label: 'Bannis',
                        value: '${provider.stats.bannedUsers}',
                        icon: CupertinoIcons.nosign,
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: 'Messages (7j)',
                        value: '${provider.stats.messagesPeriod}',
                        icon: CupertinoIcons.chat_bubble_fill,
                        color: Colors.cyan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search section
                  Text(
                    'Utilisateurs',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un utilisateur...',
                      prefixIcon: const Icon(CupertinoIcons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                provider.loadUsers();
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
                  if (provider.users.isEmpty && !provider.isLoadingUsers)
                    const Center(child: Text('Aucun utilisateur trouvé'))
                  else if (provider.isLoadingUsers)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.users.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, idx) {
                        final user = provider.users[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            backgroundImage: user.avatarUrl.isNotEmpty
                                ? NetworkImage(user.avatarUrl)
                                : null,
                            child: user.avatarUrl.isEmpty
                                ? Text(
                                    user.nom.isNotEmpty
                                        ? user.nom[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(color: Colors.indigo),
                                  )
                                : null,
                          ),
                          title: Text(user.nom),
                          subtitle: Text(user.alanyaPhone),
                          trailing: _UserActions(
                            user: user,
                            provider: provider,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminUserDetailScreen(
                                  userId: user.alanyaID,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),

                  // Load more
                  if (provider.users.length < provider.totalUsers &&
                      !provider.isLoadingUsers)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => provider.loadUsers(
                          search: _searchCtrl.text,
                          page: provider.page + 1,
                          limit: provider.limit,
                        ),
                        icon: const Icon(CupertinoIcons.arrow_down_circle),
                        label: const Text('Charger plus'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
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
                    child: const Text('Supprimer',
                        style: TextStyle(color: Colors.red)),
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
