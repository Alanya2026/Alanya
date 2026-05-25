import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../talky_models.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<User> _userFuture;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AdminProvider>();
    _userFuture = _loadUser(provider);
  }

  Future<User> _loadUser(AdminProvider provider) async {
    final data = await provider.api.adminGetUserById(widget.userId);
    return User.fromJson(data);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final user = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            child: Text(user.nom.substring(0, 1).toUpperCase()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nom,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.alanyaPhone ?? 'N/A',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(label: 'ID', value: '${user.alanyaID}'),
                      _InfoRow(label: 'Email', value: user.email ?? 'N/A'),
                      _InfoRow(
                        label: 'Status',
                        value: user.exclus == 0 ? 'Active' : 'Banned',
                      ),
                      _InfoRow(
                        label: 'Type',
                        value: user.typeCompte >= 1 ? 'Admin' : 'User',
                      ),
                      _InfoRow(
                        label: 'Created',
                        value: user.createdAt ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Text(
                'Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (user.exclus == 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await provider.toggleBan(user.alanyaID, ban: true);
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(CupertinoIcons.nosign),
                    label: const Text('Ban User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await provider.toggleBan(user.alanyaID, ban: false);
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(CupertinoIcons.checkmark_circle),
                    label: const Text('Unban User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (user.typeCompte < 1)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await provider.makeAdmin(user.alanyaID);
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(CupertinoIcons.shield_fill),
                    label: const Text('Make Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
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
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(CupertinoIcons.trash),
                  label: const Text('Delete User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade900,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
