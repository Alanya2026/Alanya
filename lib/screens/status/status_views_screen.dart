import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';

class StatusViewsScreen extends StatefulWidget {
  final int statusId;

  const StatusViewsScreen({super.key, required this.statusId});

  @override
  State<StatusViewsScreen> createState() => _StatusViewsScreenState();
}

class _StatusViewsScreenState extends State<StatusViewsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<StatusProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vues'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<List<StatutView>>(
        future: provider.getViews(widget.statusId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return Center(child: Text('Aucune vue', style: TextStyle(color: Colors.grey.shade600)));
          }

          final views = snapshot.data!;
          // Trier du plus récent au plus ancien
          views.sort((a, b) => b.seenAt.compareTo(a.seenAt));

          return ListView.separated(
            itemCount: views.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, idx) {
              final v = views[idx];
              final initial = v.nom.isNotEmpty ? v.nom[0].toUpperCase() : '?';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  backgroundImage: hasValidAvatarUrl(v.avatarUrl)
                      ? CachedNetworkImageProvider(v.avatarUrl!)
                      : null,
                  child: !hasValidAvatarUrl(v.avatarUrl)
                      ? Text(initial,
                          style: const TextStyle(
                              color: Colors.indigo, fontWeight: FontWeight.bold))
                      : null,
                ),
                title: Text(v.nom),
                subtitle: Text(v.pseudo),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (v.liked)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.favorite, color: Colors.red, size: 18),
                      ),
                    Text(
                      _formatSeenAt(v.seenAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatSeenAt(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final hm = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      return 'vu à $hm';
    }

    return 'vu hier à $hm';
  }
}
