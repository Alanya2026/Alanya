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
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchCtrl = TextEditingController();
  String _filterType = 'all'; // all, online, banned, admins
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AdminProvider>();
      provider.loadStats();
      provider.loadUsers();
    });
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  Future<void> _refresh() async {
    final p = context.read<AdminProvider>();
    await Future.wait([p.loadStats(), p.loadUsers(search: _searchCtrl.text)]);
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: _buildAppBar(provider),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            _headerSection(),
            const SizedBox(height: 24),
            _statsSection(provider),
            const SizedBox(height: 28),
            _filterSection(),
            const SizedBox(height: 16),
            _searchBar(provider),
            const SizedBox(height: 16),
            _usersList(provider),
          ],
        ),
      ),
    );
  PreferredSizeWidget _buildAppBar(AdminProvider provider) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: const Text(
        'Tableau de bord',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      actions: [
        IconButton(
          tooltip: 'Rafra
chir',
          onPressed: provider.isLoadingUsers || provider.isLoadingStats
              ? null
              : _refresh,
          icon: const Icon(CupertinoIcons.refresh),
        ),
        const SizedBox(width: 8),
      ],
    );
  Widget _headerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bienvenue',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'G
rez les utilisateurs et surveillance',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  Widget _filterSection() {
    final filters = [
      ('all', 'Tous', CupertinoIcons.person_2_fill),
      ('online', 'En ligne', CupertinoIcons.circle_fill),
      ('banned', 'Bannis', CupertinoIcons.nosign),
      ('admins', 'Admins', CupertinoIcons.shield_fill),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final (value, label, icon) = filter;
          final isSelected = _filterType == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filterType = value);
              },
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
              backgroundColor: Colors.white,
              selectedColor: Colors.blue.shade100,
              side: BorderSide(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
              ),
            ),
          );
        }).toList(),
      ),
    );
  // 
 Stats cards 
  Widget _statsSection(AdminProvider provider) {
    final s = provider.stats;
    if (provider.isLoadingStats && s.totalUsers == 0) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final onlinePercentage = s.totalUsers > 0
        ? ((s.onlineUsers / s.totalUsers) * 100).toStringAsFixed(1)
        : '0';
    final bannedPercentage = s.totalUsers > 0
        ? ((s.bannedUsers / s.totalUsers) * 100).toStringAsFixed(1)
        : '0';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _EnhancedStatCard(
              icon: CupertinoIcons.person_2_fill,
              gradient: LinearGradient(
                colors: [Colors.indigo.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              label: 'Utilisateurs',
              value: '${s.totalUsers}',
              subtitle: 'Total',
            ),
            _EnhancedStatCard(
              icon: CupertinoIcons.circle_fill,
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              label: 'En ligne',
              value: '${s.onlineUsers}',
              subtitle: '$onlinePercentage%',
            ),
            _EnhancedStatCard(
              icon: CupertinoIcons.chat_bubble_2_fill,
              gradient: LinearGradient(
                colors: [Colors.cyan.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              label: 'Messages (7j)',
              value: '${s.messagesPeriod}',
              subtitle: 'Derni
re semaine',
            ),
            _EnhancedStatCard(
              icon: CupertinoIcons.phone_fill,
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.red.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              label: 'Appels (7j)',
              value: '${s.callsPeriod}',
              subtitle: 'Derni
re semaine',
            ),
            _EnhancedStatCard(
              icon: CupertinoIcons.sparkles,
              gradient: LinearGradient(
                colors: [Colors.pink.shade400, Colors.purple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              label: 'Statuts (7j)',
              value: '${s.statusesPeriod}',
              subtitle: 'Derni
re semaine',
            ),
            _EnhancedStatCard(
              icon: CupertinoIcons.nosign,
              gradient: LinearGradient(
                colors: [Colors.red.shade400, Colors.red.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              label: 'Bannis',
              value: '${s.bannedUsers}',
              subtitle: '$bannedPercentage%',
            ),
          ],
        ),
      ],
    );
  // 
 Search bar 
  Widget _searchBar(AdminProvider provider) {
    return TextField(
      controller: _searchCtrl,
      onChanged: (value) {
        provider.setSearchQuery(value);
        provider.loadUsers(search: value);
      },
      decoration: InputDecoration(
        hintText: 'Rechercher par nom, pseudo ou t
phone
        prefixIcon: const Icon(CupertinoIcons.search),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(CupertinoIcons.clear_circled_solid),
                onPressed: () {
                  _searchCtrl.clear();
                  provider.setSearchQuery('');
                  provider.loadUsers();
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  // 
 Users list 
  Widget _usersList(AdminProvider provider) {
    if (provider.isLoadingUsers && provider.users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final filteredUsers = _getFilteredUsers(provider.users);
    if (filteredUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              Icon(
                CupertinoIcons.person_solid,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'Aucun utilisateur trouv
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < filteredUsers.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _UserTile(user: filteredUsers[i], provider: provider),
          ],
        ],
      ),
    );
  List<User> _getFilteredUsers(List<User> users) {
    return users.where((user) {
      switch (_filterType) {
        case 'online':
          return user.isOnline;
        case 'banned':
          return user.exclus;
        case 'admins':
          return user.typeCompte >= 1;
        default:
          return true;
      }
    }).toList();
class _EnhancedStatCard extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final String label;
  final String value;
  final String subtitle;
  const _EnhancedStatCard({
    required this.icon,
    required this.gradient,
    required this.label,
    required this.value,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
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
            child: Icon(icon,
                size: 80,
                color: Colors.white.withAlpha(30),
                fill: 1.0),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(51),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withAlpha(179),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
class _UserTile extends StatelessWidget {
  final User user;
  final AdminProvider provider;
  const _UserTile({required this.user, required this.provider});
  @override
  Widget build(BuildContext context) {
    final isAdmin = user.typeCompte >= 1;
    final isSuper = user.typeCompte >= 2;
    
    return Material(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminUserDetailScreen(userId: user.alanyaID),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: user.avatarUrl.isNotEmpty
                        ? NetworkImage(user.avatarUrl)
                        : null,
                    child: user.avatarUrl.isEmpty
                        ? Text(
                            user.nom.isNotEmpty
                                ? user.nom[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  if (user.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green.shade500,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withAlpha(51),
                              blurRadius: 4,
                            ),
                          ],
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.nom,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isSuper)
                          const _Badge(label: 'Super', color: Colors.deepPurple),
                        if (isAdmin && !isSuper)
                          const _Badge(label: 'Admin', color: Colors.indigo),
                        if (user.exclus)
                          const _Badge(label: 'Banni', color: Colors.red),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.pseudo}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.alanyaPhone,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'ban') {
                    _confirmToggleBan(context, user, provider);
                  } else if (action == 'view') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminUserDetailScreen(userId: user.alanyaID),
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.eye, size: 16),
                        const SizedBox(width: 8),
                        const Text('D
tails'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'ban',
                    child: Row(
                      children: [
                        Icon(
                          user.exclus
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.nosign,
                          size: 16,
                          color: user.exclus ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(user.exclus ? 'D
bannir' : 'Bannir'),
                      ],
                    ),
                  ),
                ],
                child: Icon(
                  CupertinoIcons.ellipsis_vertical,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  Future<void> _confirmToggleBan(
    BuildContext context,
    User user,
    AdminProvider provider,
  ) async {
    final ban = !user.exclus;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          ban ? 'Bannir cet utilisateur ?' : 'D
bannir cet utilisateur ?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          ban
              ? '${user.nom} ne pourra plus se connecter 
 l\'application.'
              : '${user.nom} pourra 
 nouveau se connecter 
 l\'application.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ban ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(ban ? 'Bannir' : 'D
bannir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.toggleBan(user);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.exclus
                  ? '${user.nom} a 
banni'
                  : '${user.nom} a 
 banni',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );