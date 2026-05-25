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
                    'Statistics',
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
                        label: 'Total Users',
                        value: '${provider.stats.totalUsers}',
                        icon: CupertinoIcons.person_2_fill,
                        color: Colors.blue,
                      ),
                      _StatCard(
                        label: 'Online',
                        value: '${provider.stats.onlineUsers}',
                        icon: CupertinoIcons.circle_fill,
                        color: Colors.green,
                      ),
                      _StatCard(
                        label: 'Banned',
                        value: '${provider.stats.bannedUsers}',
                        icon: CupertinoIcons.nosign,
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: 'Messages (7d)',
                        value: '${provider.stats.messagesPeriod}',
                        icon: CupertinoIcons.chat_bubble_fill,
                        color: Colors.cyan,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Search section
                  Text(
                    'Users',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
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
                  if (provider.users.isEmpty && !provider.isLoadingUsers)
                    const Center(child: Text('No users found'))
                  else if (provider.isLoadingUsers)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
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
                          title: Text(user.nom),
                          subtitle: Text(user.alanyaPhone ?? ''),
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

                  // Pagination
                  if (provider.pageCount > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: provider.canPreviousPage
                              ? () {
                                  provider.previousPage();
                                  _refresh();
                                }
                              : null,
                          icon: const Icon(CupertinoIcons.chevron_left),
                          label: const Text('Previous'),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Page ${provider.currentPage} of ${provider.pageCount}',
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: provider.canNextPage
                              ? () {
                                  provider.nextPage();
                                  _refresh();
                                }
                              : null,
                          icon: const Icon(CupertinoIcons.chevron_right),
                          label: const Text('Next'),
                        ),
                      ],
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
        if (user.exclus == 0)
          PopupMenuItem(
            child: const Text('Ban User'),
            onTap: () async {
              await provider.toggleBan(user.alanyaID, ban: true);
            },
          )
        else
          PopupMenuItem(
            child: const Text('Unban User'),
            onTap: () async {
              await provider.toggleBan(user.alanyaID, ban: false);
            },
          ),
        PopupMenuItem(
          child: const Text('Make Admin'),
          onTap: () async {
            await provider.makeAdmin(user.alanyaID);
          },
        ),
        PopupMenuItem(
          child: const Text('Delete User'),
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete User?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete'),
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
