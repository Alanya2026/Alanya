import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/app_settings_sync_service.dart';
import '../../../core/services/biometric_lock_service.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/locale_controller.dart';
import '../../../core/theme/theme_controller.dart';
import '../widgets/onboarding_shell.dart';

/// Étape 3 : thème, langue, biométrie, puis entrée dans l'app.
class PersonalizeStep extends StatefulWidget {
  const PersonalizeStep({
    super.key,
    required this.onFinish,
    required this.loading,
  });

  final VoidCallback onFinish;
  final bool loading;

  @override
  State<PersonalizeStep> createState() => _PersonalizeStepState();
}

class _PersonalizeStepState extends State<PersonalizeStep> {
  ThemeMode _theme = ThemeMode.system;
  AppLocalePreference _locale = AppLocalePreference.system;
  bool _saving = false;
  bool _bioBusy = false;

  @override
  void initState() {
    super.initState();
    _theme = context.read<ThemeController>().mode;
    _locale = context.read<LocaleController>().preference;
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_bioBusy) return;
    setState(() => _bioBusy = true);
    try {
      final bio = context.read<BiometricLockService>();
      if (value) {
        await bio.setEnabled(
          true,
          confirmationReason: context.l10n.biometricLockEnableConfirm,
        );
      } else {
        await bio.setEnabled(false);
      }
    } catch (_) {
      // Matériel indisponible → skip silencieux.
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _saveAndFinish() async {
    if (widget.loading || _saving) return;
    setState(() => _saving = true);
    try {
      final sync = context.read<AppSettingsSyncService>();
      final theme = context.read<ThemeController>();
      final locale = context.read<LocaleController>();
      await sync.patchAndSync(
        {
          'themeMode': sync.themeModeToString(_theme),
          'locale': sync.localeToString(_locale),
        },
        theme: theme,
        locale: locale,
      );
      if (mounted) widget.onFinish();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.onboardingSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bio = context.watch<BiometricLockService>();
    final available = bio.hasBiometricHardware;
    final busy = widget.loading || _saving;

    return OnboardingShell(
      title: l10n.onboardingPersonalizeTitle,
      subtitle: l10n.onboardingPersonalizeSubtitle,
      onContinue: _saveAndFinish,
      continueLabel: l10n.onboardingCompleteCta,
      continueLoading: busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingSectionLabel(l10n.onboardingThemeLabel),
          AppSpacing.vGapMd,
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.settingsThemeLight),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.settingsThemeDark),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.settingsThemeSystem),
                icon: const Icon(Icons.brightness_auto_outlined),
              ),
            ],
            selected: {_theme},
            onSelectionChanged:
                busy ? null : (s) => setState(() => _theme = s.first),
          ),
          AppSpacing.vGapXxl,
          OnboardingSectionLabel(l10n.onboardingLanguageLabel),
          AppSpacing.vGapMd,
          SegmentedButton<AppLocalePreference>(
            segments: [
              ButtonSegment(
                value: AppLocalePreference.french,
                label: Text(l10n.settingsLangFr),
              ),
              ButtonSegment(
                value: AppLocalePreference.english,
                label: Text(l10n.settingsLangEn),
              ),
              ButtonSegment(
                value: AppLocalePreference.system,
                label: Text(l10n.settingsLangSystem),
              ),
            ],
            selected: {_locale},
            onSelectionChanged:
                busy ? null : (s) => setState(() => _locale = s.first),
          ),
          AppSpacing.vGapXxl,
          OnboardingSectionLabel(l10n.onboardingBiometricTitle),
          AppSpacing.vGapMd,
          if (available)
            _BiometricFriendlyTile(
              enabled: bio.isEnabled,
              busy: _bioBusy || busy,
              onToggle: _toggleBiometric,
            )
          else
            Text(
              l10n.onboardingBiometricUnavailable,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _BiometricFriendlyTile extends StatelessWidget {
  const _BiometricFriendlyTile({
    required this.enabled,
    required this.busy,
    required this.onToggle,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.colors.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
      child: InkWell(
        onTap: busy ? null : () => onToggle(!enabled),
        borderRadius: AppRadius.brMd,
        child: Ink(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.brMd,
            boxShadow: AppShadows.subtle,
          ),
          child: Padding(
            padding: AppSpacing.card,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.semantic.brandContainer,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    size: AppIconSize.lg,
                    color: context.colors.primary,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.onboardingBiometricFriendlyTitle,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.vGapXs,
                      Text(
                        l10n.onboardingBiometricFriendlyBody,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.hGapSm,
                Switch(
                  value: enabled,
                  onChanged: busy ? null : onToggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
