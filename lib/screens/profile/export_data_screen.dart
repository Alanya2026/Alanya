import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/profile/settings_group.dart';
import 'delete_account_screen.dart';

/// Export RGPD phase 1 (sync) et phase 2 (async avec messages).
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  bool _exportingPhase1 = false;
  bool _exportingPhase2 = false;
  bool _downloading = false;
  ExportJob? _activeJob;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _exportPhase1() async {
    setState(() => _exportingPhase1 = true);
    final l10n = context.l10n;
    try {
      final data =
          await context.read<TalkyApiClient>().requestExport(includeMessages: false);
      if (!mounted) return;
      final encoded = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/alanya-export-${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(encoded);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: l10n.exportPhase1ShareSubject,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _exportingPhase1 = false);
    }
  }

  Future<void> _exportPhase2() async {
    setState(() => _exportingPhase2 = true);
    final l10n = context.l10n;
    try {
      final data =
          await context.read<TalkyApiClient>().requestExport(includeMessages: true);
      if (!mounted) return;
      final job = ExportJob.fromJson(data);
      setState(() => _activeJob = job);
      if (job.isPending && job.jobId > 0) {
        _startPolling(job.jobId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportPhase2Started)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _exportingPhase2 = false);
    }
  }

  void _startPolling(int jobId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final job = await context.read<TalkyApiClient>().getExportJob(jobId);
        if (!mounted) return;
        setState(() => _activeJob = job);
        if (!job.isPending) {
          _pollTimer?.cancel();
          if (job.isReady && job.downloadUrl != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.exportReady)),
            );
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _downloadExport() async {
    final job = _activeJob;
    if (job == null || !job.isReady || job.jobId <= 0) return;
    setState(() => _downloading = true);
    final l10n = context.l10n;
    try {
      final bytes =
          await context.read<TalkyApiClient>().downloadExportBytes(job.jobId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/alanya-export-${job.jobId}.zip');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: l10n.exportPhase2Title,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final job = _activeJob;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.exportDataTitle)),
      body: ListView(
        children: [
          AppSpacing.vGapLg,
          SettingsGroup(
            title: l10n.exportSectionYourData,
            child: Padding(
              padding: AppSpacing.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.exportPhase1Title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vGapSm,
                  Text(
                    l10n.exportPhase1Subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.vGapMd,
                  FilledButton(
                    onPressed: _exportingPhase1 ? null : _exportPhase1,
                    child: _exportingPhase1
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.onPrimary,
                            ),
                          )
                        : Text(l10n.exportRequestPhase1),
                  ),
                  AppSpacing.vGapXxl,
                  const Divider(),
                  AppSpacing.vGapLg,
                  Text(
                    l10n.exportPhase2Title,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vGapSm,
                  Text(
                    l10n.exportPhase2Subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.vGapMd,
                  FilledButton(
                    onPressed: _exportingPhase2 ? null : _exportPhase2,
                    child: _exportingPhase2
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.onPrimary,
                            ),
                          )
                        : Text(l10n.exportRequestPhase2),
                  ),
                  if (job != null && (job.isPending || job.isReady)) ...[
                    AppSpacing.vGapLg,
                    Material(
                      color: context.semantic.successContainer,
                      borderRadius: AppRadius.brSm,
                      child: Padding(
                        padding: AppSpacing.card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.isReady
                                  ? l10n.exportReady
                                  : l10n.exportInProgress,
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (job.isPending) ...[
                              AppSpacing.vGapXs,
                              Text(
                                l10n.exportInProgressHint,
                                style: context.text.bodySmall,
                              ),
                            ],
                            if (job.isReady && job.downloadUrl != null) ...[
                              AppSpacing.vGapSm,
                              TextButton(
                                onPressed: _downloading ? null : _downloadExport,
                                child: _downloading
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: context.colors.primary,
                                        ),
                                      )
                                    : Text(l10n.exportDownload),
                              ),
                            ],
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
            title: l10n.exportSectionDanger,
            child: SettingsNavTile(
              icon: Icons.delete_forever_outlined,
              title: l10n.deleteAccountTitle,
              subtitle: l10n.deleteAccountEntrySubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
            ),
          ),
          AppSpacing.vGapXxl,
        ],
      ),
    );
  }
}
