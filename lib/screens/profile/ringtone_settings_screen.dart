import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/services/ringtone_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Réglages de la sonnerie d'appel : choix entre la sonnerie système,
/// les sonneries fournies avec l'app, ou une sonnerie personnalisée
/// importée par l'utilisateur.
class RingtoneSettingsScreen extends StatefulWidget {
  const RingtoneSettingsScreen({super.key});

  @override
  State<RingtoneSettingsScreen> createState() => _RingtoneSettingsScreenState();
}

class _RingtoneSettingsScreenState extends State<RingtoneSettingsScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingId;
  bool _importing = false;

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(RingtoneOption option) async {
    // La sonnerie système n'est pas prévisualisable via just_audio (elle
    // n'existe pas sous forme de fichier accessible à l'app) : seul le
    // libellé l'indique.
    if (option.type == RingtoneSourceType.system) return;

    if (_previewingId == option.id) {
      await _previewPlayer.stop();
      setState(() => _previewingId = null);
      return;
    }

    try {
      await _previewPlayer.stop();
      if (option.type == RingtoneSourceType.bundled) {
        await _previewPlayer.setAsset(option.assetPath!);
      } else {
        await _previewPlayer.setFilePath(option.filePath!);
      }
      setState(() => _previewingId = option.id);
      await _previewPlayer.play();
      // Coupe la prévisualisation après quelques secondes plutôt que de
      // laisser une boucle infinie pendant que l'utilisateur navigue.
      _previewPlayer.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .then((_) {
        if (mounted && _previewingId == option.id) {
          setState(() => _previewingId = null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.ringtonePreviewError)),
      );
    }
  }

  Future<void> _pickAndAddRingtone(RingtonePreferences prefs) async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: false,
      );
      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final suggestedLabel = result.files.single.name
          .replaceAll(RegExp(r'\.[^.]+$'), '');

      final added = await prefs.addCustomRingtone(
        sourcePath: path,
        label: suggestedLabel,
      );
      await prefs.select(added.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.ringtoneImportSuccess)),
      );
    } on RingtoneImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.ringtoneImportError)),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmDelete(RingtonePreferences prefs, RingtoneOption option) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ringtoneDeleteConfirmTitle),
        content: Text(l10n.ringtoneDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_previewingId == option.id) {
      await _previewPlayer.stop();
      _previewingId = null;
    }
    await prefs.removeCustomRingtone(option.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text(l10n.ringtoneScreenTitle, style: context.text.headlineSmall),
      ),
      body: Consumer<RingtonePreferences>(
        builder: (_, prefs, __) => ListView(
          children: [
            AppSpacing.vGapLg,
            _RingtoneGroup(
              title: l10n.ringtoneSectionSystem,
              children: [
                _RingtoneTile(
                  option: RingtoneOption.system,
                  labelOverride: l10n.ringtoneSystemDefaultLabel,
                  groupSelectedId: prefs.selectedId,
                  isPreviewing: false,
                  onSelect: () => prefs.select(RingtoneOption.systemId),
                  onPreview: null,
                ),
              ],
            ),
            AppSpacing.vGapXxl,
            _RingtoneGroup(
              title: l10n.ringtoneSectionApp,
              children: RingtoneOption.bundled
                  .map((o) => _RingtoneTile(
                        option: o,
                        groupSelectedId: prefs.selectedId,
                        isPreviewing: _previewingId == o.id,
                        onSelect: () => prefs.select(o.id),
                        onPreview: () => _togglePreview(o),
                      ))
                  .toList(),
            ),
            AppSpacing.vGapXxl,
            _RingtoneGroup(
              title: l10n.ringtoneSectionCustom,
              children: [
                ...prefs.customRingtones.map((o) => _RingtoneTile(
                      option: o,
                      groupSelectedId: prefs.selectedId,
                      isPreviewing: _previewingId == o.id,
                      onSelect: () => prefs.select(o.id),
                      onPreview: () => _togglePreview(o),
                      onDelete: () => _confirmDelete(prefs, o),
                    )),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.semantic.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: _importing
                        ? const SizedBox(
                            width: AppIconSize.md,
                            height: AppIconSize.md,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.add,
                            color: context.colors.primary,
                            size: AppIconSize.md,
                          ),
                  ),
                  title: Text(
                    l10n.ringtoneAddCustomAction,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.colors.primary,
                    ),
                  ),
                  subtitle: Text(
                    l10n.ringtoneAddCustomHint,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  onTap: _importing ? null : () => _pickAndAddRingtone(prefs),
                ),
              ],
            ),
            AppSpacing.vGapXxl,
          ],
        ),
      ),
    );
  }
}

class _RingtoneGroup extends StatelessWidget {
  const _RingtoneGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
        ),
        Container(color: context.colors.surface, child: Column(children: children)),
      ],
    );
  }
}

class _RingtoneTile extends StatelessWidget {
  const _RingtoneTile({
    required this.option,
    required this.groupSelectedId,
    required this.isPreviewing,
    required this.onSelect,
    required this.onPreview,
    this.onDelete,
    this.labelOverride,
  });

  final RingtoneOption option;
  final String? labelOverride;

  /// L'id actuellement sélectionné dans TOUT le groupe de sonneries (pas
  /// seulement pour cette tuile) — c'est ce que `RadioListTile` compare à
  /// `value` en interne pour décider s'il est coché.
  final String groupSelectedId;
  final bool isPreviewing;
  final VoidCallback onSelect;
  final VoidCallback? onPreview;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: option.id,
      groupValue: groupSelectedId,
      onChanged: (_) => onSelect(),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        labelOverride ?? option.label,
        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      secondary: onPreview == null && onDelete == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPreview != null)
                  IconButton(
                    icon: Icon(
                      isPreviewing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                      color: context.colors.onSurfaceVariant,
                    ),
                    onPressed: onPreview,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: context.colors.error),
                    onPressed: onDelete,
                  ),
              ],
            ),
    );
  }
}
