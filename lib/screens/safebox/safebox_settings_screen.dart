//  Les réglages du coffre (07/11/2026), ouverts par l'icône de l'accueil :
//  ce que deviennent sur le téléphone les photos et vidéos ajoutées au coffre,
//  et l'accès à la sauvegarde automatique. Chaque choix dit ce qu'il fait,
//  pour qu'aucune photo ne disparaisse du téléphone par surprise.

import 'package:flutter/material.dart';

import '../../core/services/safebox/safebox_phone_cleanup.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'safebox_backup_screens.dart';

Future<void> showSafeboxSettings(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeboxSettingsScreen()));

class SafeboxSettingsScreen extends StatefulWidget {
  const SafeboxSettingsScreen({super.key});

  @override
  State<SafeboxSettingsScreen> createState() => _SafeboxSettingsScreenState();
}

class _SafeboxSettingsScreenState extends State<SafeboxSettingsScreen> {
  SafeboxPhoneCleanup? _choix;

  @override
  void initState() {
    super.initState();
    SafeboxPhoneCleanup.load().then((c) {
      if (mounted) setState(() => _choix = c);
    });
  }

  Future<void> _choisir(SafeboxPhoneCleanup? c) async {
    if (c == null) return;
    setState(() => _choix = c);
    await c.save();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muet = context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant);
    Widget choix(SafeboxPhoneCleanup valeur, String titre, String detail) => RadioListTile<SafeboxPhoneCleanup>(
          value: valeur,
          title: Text(titre),
          subtitle: Text(detail),
        );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxSettingsTitle)),
      body: _choix == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                Padding(
                  padding: AppSpacing.screenH,
                  child: Text(l10n.safeboxCleanupSection.toUpperCase(),
                      style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant, letterSpacing: 0.8)),
                ),
                RadioGroup<SafeboxPhoneCleanup>(
                  groupValue: _choix,
                  onChanged: _choisir,
                  child: Column(
                    children: [
                      choix(SafeboxPhoneCleanup.keep, l10n.safeboxCleanupKeep, l10n.safeboxCleanupKeepHint),
                      choix(SafeboxPhoneCleanup.ask, l10n.safeboxCleanupAsk, l10n.safeboxCleanupAskHint),
                      choix(SafeboxPhoneCleanup.always, l10n.safeboxCleanupAlways, l10n.safeboxCleanupAlwaysHint),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
                  child: Text(l10n.safeboxCleanupNote, style: muet),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: Text(l10n.safeboxBackupTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showSafeboxBackupSetup(context),
                ),
              ],
            ),
    );
  }
}

/// « Me demander à chaque ajout » : rend vrai pour retirer du téléphone ces
/// [count] photos et vidéos une fois dans le coffre. [lighter] : elles partent
/// en HD ou Compressé, la version du coffre sera moins nette.
Future<bool> askSafeboxPhoneCleanup(BuildContext context, {required int count, required bool lighter}) async {
  final l10n = context.l10n;
  final oui = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.safeboxCleanupAskTitle),
      content: Text([
        l10n.safeboxCleanupAskBody(count),
        if (lighter) l10n.safeboxCleanupLighter,
      ].join('\n\n')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.safeboxCleanupKeep)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.safeboxCleanupDelete)),
      ],
    ),
  );
  return oui ?? false;
}
