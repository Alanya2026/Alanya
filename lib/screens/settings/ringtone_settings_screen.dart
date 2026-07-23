import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/services/ringtone_preferences.dart';
import '../../core/services/ringtone_service.dart';

/// Écran de gestion des sonneries d'appel.
/// Accessible depuis Paramètres > Sonnerie.
class RingtoneSettingsScreen extends StatelessWidget {
  const RingtoneSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.ringtoneSettingsTitle),
      ),
      body: Consumer<RingtonePreferences>(
        builder: (context, prefs, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            // Section: Type de sonnerie
            _SectionTitle(title: l10n.ringtoneSource),
            _SourceSelector(prefs: prefs),
            const SizedBox(height: AppSpacing.xxl),

            // Section: Sonneries par défaut
            if (prefs.source == RingtoneSource.custom) ...[
              _SectionTitle(title: l10n.ringtoneDefaultRingtones),
              _DefaultRingtonesList(prefs: prefs),
              const SizedBox(height: AppSpacing.xxl),

              // Section: Sonneries personnalisées
              _SectionTitle(title: l10n.ringtoneCustomRingtones),
              _CustomRingtonesList(prefs: prefs),
              const SizedBox(height: AppSpacing.lg),

              // Bouton Ajouter une sonnerie
              Padding(
                padding: AppSpacing.card,
                child: _AddRingtoneButton(prefs: prefs),
              ),
            ],

            // Section: Sonneries par défaut (quand système sélectionné)
            if (prefs.source == RingtoneSource.system) ...[
              Padding(
                padding: AppSpacing.card,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.ringtoneSystemInfo,
                          style: context.text.bodyMedium,
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
    );
  }
}

/// Titre de section stylisé
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: context.text.labelMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Sélecteur entre sonnerie système et personnalisée
class _SourceSelector extends StatelessWidget {
  const _SourceSelector({required this.prefs});

  final RingtonePreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      color: context.colors.surface,
      child: Column(
        children: [
          RadioListTile<RingtoneSource>(
            title: Text(l10n.ringtoneSourceSystem),
            subtitle: Text(l10n.ringtoneSourceSystemDesc),
            value: RingtoneSource.system,
            groupValue: prefs.source,
            onChanged: (value) {
              if (value != null) {
                prefs.setSource(value);
              }
            },
            secondary: const Icon(Icons.phone_android),
          ),
          const Divider(height: 1, indent: 72),
          RadioListTile<RingtoneSource>(
            title: Text(l10n.ringtoneSourceCustom),
            subtitle: Text(l10n.ringtoneSourceCustomDesc),
            value: RingtoneSource.custom,
            groupValue: prefs.source,
            onChanged: (value) {
              if (value != null) {
                prefs.setSource(value);
              }
            },
            secondary: const Icon(Icons.music_note),
          ),
        ],
      ),
    );
  }
}

/// Liste des sonneries par défaut
class _DefaultRingtonesList extends StatelessWidget {
  const _DefaultRingtonesList({required this.prefs});

  final RingtonePreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      color: context.colors.surface,
      child: Column(
        children: [
          for (int i = 0; i < RingtonePreferences.defaultRingtones.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            _RingtoneListTile(
              title: RingtonePreferences.defaultRingtones[i].name,
              subtitle: l10n.ringtoneDefaultBadge,
              isSelected: prefs.source == RingtoneSource.custom &&
                  prefs.defaultRingtoneIndex == i &&
                  prefs.customRingtonePath == null,
              onTap: () {
                prefs.setDefaultRingtoneIndex(i);
                prefs.setCustomRingtone('');
              },
              onPreview: () {
                final ringtone = RingtonePreferences.defaultRingtones[i];
                RingtoneService.instance.playPreview(assetPath: ringtone.assetPath);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Liste des sonneries personnalisées
class _CustomRingtonesList extends StatelessWidget {
  const _CustomRingtonesList({required this.prefs});

  final RingtonePreferences prefs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (prefs.customRingtones.isEmpty) {
      return Container(
        margin: AppSpacing.card,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 48,
              color: context.colors.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.ringtoneNoCustom,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      color: context.colors.surface,
      child: Column(
        children: [
          for (int i = 0; i < prefs.customRingtones.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            Dismissible(
              key: Key(prefs.customRingtones[i].id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: context.colors.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.xl),
                child: Icon(
                  Icons.delete_outline,
                  color: context.colors.onError,
                ),
              ),
              confirmDismiss: (direction) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.ringtoneDeleteConfirmTitle),
                    content: Text(l10n.ringtoneDeleteConfirmMessage(prefs.customRingtones[i].name)),
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
              },
              onDismissed: (direction) {
                prefs.removeCustomRingtone(prefs.customRingtones[i].id);
              },
              child: _RingtoneListTile(
                title: prefs.customRingtones[i].name,
                subtitle: prefs.customRingtones[i].formattedSize,
                isSelected: prefs.customRingtonePath == prefs.customRingtones[i].filePath,
                onTap: () {
                  prefs.setCustomRingtone(prefs.customRingtones[i].filePath);
                },
                onPreview: () {
                  RingtoneService.instance.playPreview(
                    customPath: prefs.customRingtones[i].filePath,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tuile de sonnerie avec aperçu et sélection
class _RingtoneListTile extends StatelessWidget {
  const _RingtoneListTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.onPreview,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isSelected ? context.colors.primary : context.colors.outline,
      ),
      title: Text(
        title,
        style: context.text.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.play_circle_outline),
        onPressed: onPreview,
        tooltip: context.l10n.ringtonePreview,
      ),
      onTap: onTap,
    );
  }
}

/// Bouton pour ajouter une sonnerie personnalisée
class _AddRingtoneButton extends StatelessWidget {
  const _AddRingtoneButton({required this.prefs});

  final RingtonePreferences prefs;

  Future<void> _pickAndAddRingtone(BuildContext context) async {
    final l10n = context.l10n;

    try {
      // Demander les permissions
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.ringtonePermissionDenied)),
          );
        }
        return;
      }

      // Ouvrir le sélecteur de fichiers
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      // Ajouter la sonnerie
      final name = file.name.replaceAll(RegExp(r'\.[^.]+$'), ''); // Enlever l'extension
      final customRingtone = await prefs.addCustomRingtone(
        File(file.path!),
        name,
      );

      if (context.mounted) {
        if (customRingtone != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.ringtoneAdded(customRingtone.name))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.ringtoneAddError)),
          );
        }
      }
    } catch (e) {
      debugPrint('[RingtoneSettings] Erreur ajout sonnerie: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.ringtoneAddError)),
        );
      }
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.audio.request();
      if (status.isGranted) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FilledButton.icon(
      onPressed: () => _pickAndAddRingtone(context),
      icon: const Icon(Icons.add),
      label: Text(l10n.ringtoneAddCustom),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
      ),
    );
  }
}
