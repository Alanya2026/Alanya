import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/storage_info_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/profile/settings_group.dart';

/// Répartition du stockage et actions de vidage du cache.
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    context.read<StorageInfoService>().refresh();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }

  Future<void> _clearMediaCache() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.storageClearMediaCache),
        content: Text(l10n.storageClearCacheConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await context.read<StorageInfoService>().clearMediaCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.storageClearCacheDone)),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _clearTemp() async {
    setState(() => _clearing = true);
    try {
      await context.read<StorageInfoService>().clearTemporaryFiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.storageClearTempDone)),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storage = context.watch<StorageInfoService>();
    final b = storage.breakdown;
    final total = b.totalBytes;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.storageTitle)),
      body: storage.isLoading && total == 0
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: storage.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppSpacing.vGapLg,
                  Padding(
                    padding: AppSpacing.screenH,
                    child: Container(
                      padding: AppSpacing.card,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: AppRadius.brMd,
                        boxShadow: AppShadows.subtle,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.storageUsed,
                            style: context.text.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          AppSpacing.vGapXs,
                          Text(
                            _formatBytes(total),
                            style: context.text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (total > 0) ...[
                            AppSpacing.vGapMd,
                            ClipRRect(
                              borderRadius: AppRadius.brPill,
                              child: SizedBox(
                                height: 8,
                                child: Row(
                                  children: [
                                    if (b.mediaCacheBytes > 0)
                                      Expanded(
                                        flex: b.mediaCacheBytes,
                                        child: ColoredBox(
                                          color: context.colors.primary,
                                        ),
                                      ),
                                    if (b.databaseBytes > 0)
                                      Expanded(
                                        flex: b.databaseBytes,
                                        child: ColoredBox(
                                          color: context.semantic.warning,
                                        ),
                                      ),
                                    if (b.temporaryBytes > 0)
                                      Expanded(
                                        flex: b.temporaryBytes,
                                        child: ColoredBox(
                                          color: context.semantic.info,
                                        ),
                                      ),
                                    if (b.otherBytes > 0)
                                      Expanded(
                                        flex: b.otherBytes,
                                        child: ColoredBox(
                                          color: context.colors.outline,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.vGapXxl,
                  SettingsGroup(
                    title: l10n.storageBreakdownTitle,
                    child: Column(
                      children: [
                        _SizeTile(
                          icon: Icons.perm_media_outlined,
                          color: context.colors.primary,
                          title: l10n.storageMediaCache,
                          size: _formatBytes(b.mediaCacheBytes),
                        ),
                        _SizeTile(
                          icon: Icons.storage_outlined,
                          color: context.semantic.warning,
                          title: l10n.storageDatabase,
                          size: _formatBytes(b.databaseBytes),
                        ),
                        _SizeTile(
                          icon: Icons.folder_outlined,
                          color: context.semantic.info,
                          title: l10n.storageTempFiles,
                          size: _formatBytes(b.temporaryBytes),
                        ),
                        _SizeTile(
                          icon: Icons.insert_drive_file_outlined,
                          color: context.colors.outline,
                          title: l10n.storageOther,
                          size: _formatBytes(b.otherBytes),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.vGapXxl,
                  Padding(
                    padding: AppSpacing.screenH,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: _clearing ? null : _clearMediaCache,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l10n.storageClearMediaCache),
                        ),
                        AppSpacing.vGapMd,
                        OutlinedButton.icon(
                          onPressed: _clearing ? null : _clearTemp,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: Text(l10n.storageClearTemp),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.vGapXxl,
                ],
              ),
            ),
    );
  }
}

class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String size;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: Text(
        size,
        style: context.text.bodyMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
