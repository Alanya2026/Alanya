import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';

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
      appBar: AppBar(title: const Text('Vues')),
      body: FutureBuilder<List<StatutView>>(
        future: provider.getViews(widget.statusId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingState();
          }
          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            return const EmptyState(
              icon: Icons.visibility_off_outlined,
              title: 'Aucune vue',
            );
          }

          final views = snapshot.data!;
          views.sort((a, b) => b.seenAt.compareTo(a.seenAt));

          return ListView.separated(
            itemCount: views.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (_, idx) {
              final v = views[idx];
              return ListTile(
                leading: AppAvatar(
                  imageUrl: v.avatarUrl,
                  name: v.nom,
                  size: AppSizes.avatarMd,
                ),
                title: Text(v.nom, style: context.text.titleSmall),
                subtitle: Text(
                  v.pseudo,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (v.liked)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: Icon(Icons.favorite,
                            color: AppColors.error, size: AppIconSize.sm),
                      ),
                    Text(
                      _formatSeenAt(v.seenAt),
                      style: context.text.labelSmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
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
    final hm =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    if (local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      return 'vu à $hm';
    }

    return 'vu hier à $hm';
  }
}
