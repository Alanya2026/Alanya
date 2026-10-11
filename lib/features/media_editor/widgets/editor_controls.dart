import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Une couleur de la palette de dessin et de texte. Les teintes viennent de
/// `AppColors` (source unique) ; ce sont des couleurs de **contenu** (ce qu'on
/// dessine), elles ne changent pas avec le thème.
class EditorSwatch {
  const EditorSwatch(this.color, this.name);
  final Color color;
  final String Function(AppLocalizations l10n) name;
}

final List<EditorSwatch> kEditorPalette = [
  EditorSwatch(AppColors.black, (l) => l.mediaEditorColorBlack),
  EditorSwatch(AppColors.white, (l) => l.mediaEditorColorWhite),
  EditorSwatch(AppColors.error, (l) => l.mediaEditorColorRed),
  EditorSwatch(AppColors.warning, (l) => l.mediaEditorColorOrange),
  EditorSwatch(AppColors.success, (l) => l.mediaEditorColorGreen),
  EditorSwatch(AppColors.info, (l) => l.mediaEditorColorBlue),
  EditorSwatch(AppColors.brandPrimary, (l) => l.mediaEditorColorIndigo),
];

/// Rangée de pastilles de couleur (cible tactile 48 dp, nom lu par
/// l'accessibilité, sélection signalée par un anneau).
class EditorColorPalette extends StatelessWidget {
  const EditorColorPalette({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color? selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in kEditorPalette)
            Semantics(
              button: true,
              selected: s.color == selected,
              onTap: () => onSelected(s.color),
              label: '${l10n.mediaEditorColor} : ${s.name(l10n)}',
              child: ExcludeSemantics(
                child: InkResponse(
                  key: ValueKey('editor-color-${s.color.toARGB32()}'),
                  onTap: () => onSelected(s.color),
                  radius: AppSizes.minTapTarget / 2,
                  child: SizedBox(
                    width: AppSizes.minTapTarget,
                    height: AppSizes.minTapTarget,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.color == selected
                                ? colors.primary
                                : colors.outlineVariant,
                            width: s.color == selected ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bouton d'outil : icône + libellé, au moins 48 dp de haut et de large,
/// annoncé comme bouton sélectionné ou non.
class EditorToolButton extends StatelessWidget {
  const EditorToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = onTap == null
        ? colors.onSurface.withValues(alpha: 0.38)
        : selected
        ? colors.primary
        : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      onTap: onTap,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: AppRadius.brSm,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTapTarget,
              minHeight: AppSizes.minTapTarget,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? context.semantic.brandContainer : null,
                borderRadius: AppRadius.brSm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: AppIconSize.md),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Curseur avec libellé lu par l'accessibilité, hauteur ≥ 48 dp.
class EditorSlider extends StatelessWidget {
  const EditorSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final VoidCallback onChangeStart;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              label: label,
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChangeStart: (_) => onChangeStart(),
                onChanged: onChanged,
                onChangeEnd: (_) => onChangeEnd(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
