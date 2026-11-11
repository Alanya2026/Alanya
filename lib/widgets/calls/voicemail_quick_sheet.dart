import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/billing/entitlements.dart';
import '../../core/services/call/voicemail_provider.dart';
import '../../core/services/call/voicemail_rules.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/profile/voicemail_schedule_screen.dart';
import '../billing/paywall_sheet.dart';
import '../common/app_bottom_sheet.dart';

/// Activation rapide du répondeur, depuis l'onglet Appels.
///
/// **Aucune option sans échéance, et c'est le cœur du dispositif.** Un
/// répondeur qu'on oublie d'éteindre est pire que pas de répondeur du tout :
/// son propriétaire croit son téléphone joignable et ne comprend pas pourquoi
/// plus personne ne le rappelle. Chaque entrée ci-dessous écrit donc une date
/// de fin, et le bandeau permanent rappelle cette date tant qu'elle court.
///
/// Qui veut une indisponibilité durable passe par la règle récurrente de
/// l'écran de réglage — elle s'éteint d'elle-même chaque jour.
Future<void> showVoicemailQuickSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => const _VoicemailQuickSheet(),
  );
}

class _VoicemailQuickSheet extends StatelessWidget {
  const _VoicemailQuickSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<VoicemailProvider>();

    return AppBottomSheet(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.voicemailScheduleTitle,
                  style: context.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                AppSpacing.vGapXs,
                Text(
                  vm.isActive
                      ? (vm.deadline == null
                          ? l10n.voicemailBannerActive
                          : l10n.voicemailBannerUntil(vm.deadline!))
                      : l10n.voicemailQuickHint,
                  style: context.text.bodySmall?.copyWith(
                    color: vm.isActive
                        ? context.colors.primary
                        : context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (vm.isActive)
            ListTile(
              leading: Icon(Icons.notifications_active_outlined,
                  color: context.colors.primary),
              title: Text(l10n.voicemailBannerDisable),
              onTap: vm.isSaving ? null : () => _eteindre(context, vm),
            )
          else
            for (final d in VoicemailQuickDuration.values)
              ListTile(
                leading: Icon(Icons.schedule,
                    color: context.colors.onSurfaceVariant),
                title: Text(_libelle(l10n, d)),
                // L'heure de fin est affichée, jamais seulement la durée :
                // « 4 heures » demande un calcul mental, « jusqu'à 18:30 » non.
                trailing: Text(
                  _heureDeFin(d),
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: vm.isSaving ? null : () => _armer(context, vm, d),
              ),
          if (!vm.isActive)
            ListTile(
              leading: Icon(Icons.event_outlined,
                  color: context.colors.onSurfaceVariant),
              title: Text(l10n.voicemailUntilCustom),
              onTap: vm.isSaving ? null : () => _armerSurMesure(context, vm),
            ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.tune, color: context.colors.primary),
            title: Text(
              l10n.voicemailQuickSchedule,
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const VoicemailScheduleScreen()),
              );
            },
          ),
          AppSpacing.vGapSm,
        ],
      ),
    );
  }

  String _libelle(AppLocalizations l10n, VoicemailQuickDuration d) => switch (d) {
        VoicemailQuickDuration.oneHour => l10n.voicemailForOneHour,
        VoicemailQuickDuration.fourHours => l10n.voicemailForFourHours,
        VoicemailQuickDuration.nextMorning => l10n.voicemailUntilMorning,
      };

  String _heureDeFin(VoicemailQuickDuration d) {
    final fin = quickDeadline(d, now: DateTime.now());
    return '${fin.hour.toString().padLeft(2, '0')}:'
        '${fin.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _armer(
    BuildContext context,
    VoicemailProvider vm,
    VoicemailQuickDuration d,
  ) async {
    if (!guardPlus(context, PlusFeature.voicemail)) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await vm.activateUntil(quickDeadline(d, now: DateTime.now()));
      navigator.pop();
      final fin = vm.deadline;
      messenger.showSnackBar(SnackBar(
        content: Text(fin == null
            ? l10n.voicemailBannerActive
            : l10n.voicemailBannerUntil(fin)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!context.mounted) return;
      afficherErreur(context, e, domaine: ErrorDomain.appel);
    }
  }

  /// Échéance choisie à la main : date puis heure, avec les sélecteurs natifs.
  ///
  /// Bornée à un an : au-delà, c'est une activation sans fin déguisée, et c'est
  /// précisément ce que cette feuille refuse de proposer.
  Future<void> _armerSurMesure(
      BuildContext context, VoicemailProvider vm) async {
    if (!guardPlus(context, PlusFeature.voicemail)) return;
    final maintenant = DateTime.now();
    final jour = await showDatePicker(
      context: context,
      initialDate: maintenant,
      firstDate: maintenant,
      lastDate: maintenant.add(const Duration(days: 365)),
    );
    if (jour == null || !context.mounted) return;

    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(maintenant),
    );
    if (heure == null || !context.mounted) return;

    final fin =
        DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
    // Une échéance déjà passée n'activerait rien du tout : on le dit plutôt
    // que de laisser l'utilisateur croire son répondeur armé.
    if (!fin.isAfter(maintenant)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.voicemailDeadlinePast)),
      );
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await vm.activateUntil(fin);
      navigator.pop();
      final libelle = vm.deadline;
      messenger.showSnackBar(SnackBar(
        content: Text(libelle == null
            ? l10n.voicemailBannerActive
            : l10n.voicemailBannerUntil(libelle)),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!context.mounted) return;
      afficherErreur(context, e, domaine: ErrorDomain.appel);
    }
  }

  Future<void> _eteindre(BuildContext context, VoicemailProvider vm) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await vm.disable();
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.voicemailDisabled),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!context.mounted) return;
      afficherErreur(context, e, domaine: ErrorDomain.appel);
    }
  }
}
