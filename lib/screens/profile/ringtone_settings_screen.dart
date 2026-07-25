import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/services/ringtone_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Réglages de la sonnerie d'appel : choix entre la sonnerie du téléphone,
/// les sonneries fournies avec l'app, ou une sonnerie importée par
/// l'utilisateur (10 max).
class RingtoneSettingsScreen extends StatefulWidget {
  const RingtoneSettingsScreen({super.key});

  @override
  State<RingtoneSettingsScreen> createState() => _RingtoneSettingsScreenState();
}

class _RingtoneSettingsScreenState extends State<RingtoneSettingsScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingId;
  bool _importing = false;

  /// Sections dépliées (clés : catégories fournies + 'custom'). Initialisé au
  /// premier build sur la section contenant la sonnerie sélectionnée.
  Set<String>? _expanded;

  Set<String> _initialExpanded(RingtonePreferences prefs) {
    if (prefs.selected.type == RingtoneSourceType.custom) return {'custom'};
    // Sonnerie fournie (défaut) OU système sélectionnée → ouvrir les préinstallées.
    return {'bundled'};
  }

  void _toggleSection(String key) {
    setState(() {
      final s = _expanded!;
      if (!s.remove(key)) s.add(key);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(RingtoneOption option) async {
    // La sonnerie système n'est pas prévisualisable via just_audio (elle
    // n'existe pas sous forme de fichier accessible à l'app).
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
      // Réinitialise l'état une fois la sonnerie jouée en entier (aperçu court).
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
      final suggestedLabel =
          result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), '');

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

  Future<void> _confirmDelete(
      RingtonePreferences prefs, RingtoneOption option) async {
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
        builder: (_, prefs, __) {
          _expanded ??= _initialExpanded(prefs);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              // --- Sonnerie du téléphone (épinglée, toujours visible) ---
              _CollapsibleSection(
                title: l10n.ringtoneSectionSystem,
                collapsible: false,
                expanded: true,
                onToggle: () {},
                tiles: [
                  _RingtoneTile(
                    option: RingtoneOption.system,
                    labelOverride: l10n.ringtoneSystemDefaultLabel,
                    selected: prefs.selectedId == RingtoneOption.systemId,
                    previewing: false,
                    onTap: () => prefs.select(RingtoneOption.systemId),
                    onPreview: null,
                  ),
                ],
              ),
              AppSpacing.vGapLg,

              // --- Sonneries préinstallées dans l'app (repliable) ---
              _CollapsibleSection(
                title: l10n.ringtoneSectionApp,
                trailing: _CountBadge(count: RingtoneOption.bundled.length),
                hasSelected:
                    prefs.selected.type == RingtoneSourceType.bundled,
                expanded: _expanded!.contains('bundled'),
                onToggle: () => _toggleSection('bundled'),
                tiles: RingtoneOption.bundled
                    .map((o) => _RingtoneTile(
                          option: o,
                          selected: prefs.selectedId == o.id,
                          previewing: _previewingId == o.id,
                          onTap: () => prefs.select(o.id),
                          onPreview: () => _togglePreview(o),
                        ))
                    .toList(),
              ),
              AppSpacing.vGapLg,

              // --- Sonneries importées par l'utilisateur (10 max, repliable) ---
              _CollapsibleSection(
                title: l10n.ringtoneSectionCustom,
                trailing: _CounterChip(
                  count: prefs.customCount,
                  max: prefs.customMax,
                ),
                hasSelected:
                    prefs.selected.type == RingtoneSourceType.custom,
                expanded: _expanded!.contains('custom'),
                onToggle: () => _toggleSection('custom'),
                tiles: [
                  if (prefs.customRingtones.isEmpty)
                    _EmptyHint(text: l10n.ringtoneCustomEmpty),
                  ...prefs.customRingtones.map((o) => _RingtoneTile(
                        option: o,
                        selected: prefs.selectedId == o.id,
                        previewing: _previewingId == o.id,
                        onTap: () => prefs.select(o.id),
                        onPreview: () => _togglePreview(o),
                        onDelete: () => _confirmDelete(prefs, o),
                      )),
                  _AddRingtoneTile(
                    enabled: prefs.canAddCustom && !_importing,
                    importing: _importing,
                    limitReached: !prefs.canAddCustom,
                    onTap: () => _pickAndAddRingtone(prefs),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

}

/// Section repliable (accordéon) : un en-tête tappable (titre + éventuel
/// compteur + chevron) au-dessus d'un bloc arrondi contenant les tuiles. Permet
/// de regrouper les sonneries par catégorie pour éviter une longue liste à
/// défiler. [collapsible] = false → toujours ouverte, sans chevron (ex. la
/// sonnerie système).
class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.tiles,
    required this.expanded,
    required this.onToggle,
    this.trailing,
    this.hasSelected = false,
    this.collapsible = true,
  });

  final String title;
  final List<Widget> tiles;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? trailing;

  /// Affiche une pastille indiquant que la sonnerie sélectionnée est dans cette
  /// section (utile quand elle est repliée).
  final bool hasSelected;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final open = expanded || !collapsible;

    final header = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasSelected && !open) ...[
            AppSpacing.hGapSm,
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
              ),
            ),
          ],
          const Spacer(),
          if (trailing != null) ...[trailing!, AppSpacing.hGapSm],
          if (collapsible)
            AnimatedRotation(
              turns: open ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.expand_more_rounded,
                  color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );

    final body = Column(
      children: [
        Divider(height: 1, thickness: 1, color: colors.outlineVariant),
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: 68,
              color: colors.outlineVariant,
            ),
          tiles[i],
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          collapsible
              ? Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onToggle, child: header),
                )
              : header,
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: body,
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

/// Petite pastille de comptage (nombre de sonneries d'une catégorie).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        '$count',
        style: context.text.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Une tuile de sonnerie sélectionnable, avec pastille de sélection, bouton
/// d'aperçu, et suppression (sonneries importées uniquement).
class _RingtoneTile extends StatelessWidget {
  const _RingtoneTile({
    required this.option,
    required this.selected,
    required this.previewing,
    required this.onTap,
    required this.onPreview,
    this.onDelete,
    this.labelOverride,
  });

  final RingtoneOption option;
  final bool selected;
  final bool previewing;
  final VoidCallback onTap;
  final VoidCallback? onPreview;
  final VoidCallback? onDelete;
  final String? labelOverride;

  IconData get _leadingIcon {
    switch (option.type) {
      case RingtoneSourceType.system:
        return Icons.smartphone_rounded;
      case RingtoneSourceType.bundled:
        return Icons.music_note_rounded;
      case RingtoneSourceType.custom:
        return Icons.library_music_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              // Pastille de sélection / icône
              Container(
                width: AppSizes.avatarSm,
                height: AppSizes.avatarSm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                ),
                child: Icon(
                  selected ? Icons.check_rounded : _leadingIcon,
                  size: AppIconSize.md,
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
              AppSpacing.hGapMd,
              // Libellé
              Expanded(
                child: Text(
                  labelOverride ?? option.label,
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colors.onSurface : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Aperçu
              if (onPreview != null)
                IconButton(
                  icon: Icon(
                    previewing
                        ? Icons.stop_circle_rounded
                        : Icons.play_circle_outline_rounded,
                    color: previewing ? colors.primary : colors.onSurfaceVariant,
                    size: AppIconSize.lg,
                  ),
                  onPressed: onPreview,
                ),
              // Suppression (importées)
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: colors.error, size: AppIconSize.md),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tuile « Ajouter une sonnerie » (désactivée quand la limite est atteinte).
class _AddRingtoneTile extends StatelessWidget {
  const _AddRingtoneTile({
    required this.enabled,
    required this.importing,
    required this.limitReached,
    required this.onTap,
  });

  final bool enabled;
  final bool importing;
  final bool limitReached;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final tint = limitReached ? colors.onSurfaceVariant : colors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.avatarSm,
                height: AppSizes.avatarSm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.12),
                ),
                child: importing
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        limitReached
                            ? Icons.block_rounded
                            : Icons.add_rounded,
                        color: tint,
                        size: AppIconSize.md,
                      ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ringtoneAddCustomAction,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tint,
                      ),
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      limitReached
                          ? l10n.ringtoneLimitReached
                          : l10n.ringtoneAddCustomHint,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille compteur « 3/10 » affichée à droite du titre de section.
class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final full = count >= max;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: full
            ? colors.error.withValues(alpha: 0.12)
            : colors.primary.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        '$count/$max',
        style: context.text.labelSmall?.copyWith(
          color: full ? colors.error : colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Message affiché quand aucune sonnerie n'a encore été importée.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: AppIconSize.sm, color: context.colors.onSurfaceVariant),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
