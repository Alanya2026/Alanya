//  Accueil du coffre-fort : l'espace, les quatre dossiers, la corbeille.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/services/safebox/safebox_upload_manager.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../widgets/billing/paywall_sheet.dart';
import 'safebox_folder_screen.dart';
import 'safebox_free_up_screen.dart';
import 'safebox_transfers_sheet.dart';
import 'safebox_trash_screen.dart';
import 'safebox_widgets.dart';

class SafeboxHomeScreen extends StatefulWidget {
  const SafeboxHomeScreen({super.key});

  @override
  State<SafeboxHomeScreen> createState() => _SafeboxHomeScreenState();
}

class _SafeboxHomeScreenState extends State<SafeboxHomeScreen> {
  @override
  void initState() {
    super.initState();
    final c = context.read<SafeboxController>();
    c.ensureStarted();
    c.refreshOverview();
  }

  Future<void> _ouvrir(SafeboxRoot r, int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SafeboxFolderScreen(folderId: id, root: r)));
    if (mounted) await context.read<SafeboxController>().refreshOverview();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.watch<SafeboxController>();
    final vue = c.overview;
    final enCours = c.uploads.jobs.where((j) => j.state != SafeboxUploadState.completed).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxTitle)),
      body: RefreshIndicator(
        onRefresh: c.refreshOverview,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            if (vue == null && c.overviewError != null)
              Padding(
                padding: AppSpacing.card,
                child: Text(
                  presenterErreur(l10n, c.overviewError, domaine: ErrorDomain.media),
                  style: context.text.bodyMedium?.copyWith(color: context.colors.error),
                ),
              )
            else if (vue == null)
              const Padding(padding: EdgeInsets.all(AppSpacing.xxxl), child: Center(child: CircularProgressIndicator()))
            else ...[
              Padding(
                padding: AppSpacing.screenH,
                child: Text(l10n.safeboxSubtitle,
                    style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ),
              AppSpacing.vGapLg,
              Container(
                margin: AppSpacing.screenH,
                padding: AppSpacing.card,
                decoration: BoxDecoration(color: context.colors.surface, borderRadius: AppRadius.brMd, boxShadow: AppShadows.subtle),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SafeboxQuotaBar(quota: vue.quota),
                    AppSpacing.vGapSm,
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeboxFreeUpScreen()));
                            if (context.mounted) await context.read<SafeboxController>().refreshOverview();
                          },
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: Text(l10n.safeboxFreeUpTitle),
                        ),
                        if (vue.quota.ratio >= 0.8)
                          TextButton.icon(
                            onPressed: () => showPaywall(context, null),
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: Text(l10n.safeboxGoPlus),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapLg,
              if (enCours > 0)
                Padding(
                  padding: AppSpacing.screenH,
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.cloud_upload_outlined),
                      title: Text(l10n.safeboxTransfersCount(enCours)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showSafeboxTransfers(context),
                    ),
                  ),
                ),
              Container(
                margin: AppSpacing.screenH,
                decoration: BoxDecoration(color: context.colors.surface, borderRadius: AppRadius.brMd, boxShadow: AppShadows.subtle),
                child: Column(
                  children: [
                    for (final r in SafeboxRoot.values) ...[
                      if (r != SafeboxRoot.albums) const Divider(height: 1),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(color: context.semantic.brandContainer, borderRadius: AppRadius.brSm),
                          child: Icon(safeboxRootIcon(r), color: context.colors.primary, size: AppIconSize.sm),
                        ),
                        title: Text(SafeboxController.rootLabel(r, l10n),
                            style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                        subtitle: Text(l10n.safeboxRootSummary(
                          vue.quota.byRoot[r]?.files ?? 0,
                          formatBytes(vue.quota.byRoot[r]?.bytes ?? 0, l10n),
                        )),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.colors.outlineVariant),
                        onTap: vue.rootIds[r] == null ? null : () => _ouvrir(r, vue.rootIds[r]!),
                      ),
                    ],
                  ],
                ),
              ),
              AppSpacing.vGapLg,
              Container(
                margin: AppSpacing.screenH,
                decoration: BoxDecoration(color: context.colors.surface, borderRadius: AppRadius.brMd, boxShadow: AppShadows.subtle),
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: context.colors.onSurfaceVariant),
                  title: Text(l10n.safeboxTrash),
                  subtitle: vue.quota.trashBytes > 0 ? Text(formatBytes(vue.quota.trashBytes, l10n)) : null,
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.colors.outlineVariant),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeboxTrashScreen()));
                    if (context.mounted) await context.read<SafeboxController>().refreshOverview();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
