import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/profile_identity.dart';

/// Genre et âge : saisie unique, puis lecture seule une fois enregistrés côté
/// serveur. Partagé entre l'onboarding et Mon compte → Modifier le profil.
class ProfileIdentityFields extends StatelessWidget {
  const ProfileIdentityFields({
    super.key,
    required this.genre,
    required this.genreLocked,
    required this.onGenreSelected,
    required this.ageController,
    required this.ageLocked,
    this.ageError,
    this.enabled = true,
    this.showHeader = true,
    this.showSectionLabel = false,
    this.onAgeChanged,
  });

  final ProfileGender? genre;
  final bool genreLocked;
  final ValueChanged<ProfileGender?> onGenreSelected;
  final TextEditingController ageController;
  final bool ageLocked;
  final String? ageError;
  final bool enabled;
  final bool showHeader;
  /// Titre de section « Identité » (proposition A — Modifier le profil).
  final bool showSectionLabel;
  final VoidCallback? onAgeChanged;

  int? get _ageSaisi {
    final brut = ageController.text.trim();
    if (brut.isEmpty) return null;
    return int.tryParse(brut);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final age = _ageSaisi;
    final anneeNaissance = (age != null && age >= kAgeMin && age <= kAgeMax)
        ? DateTime.now().year - age
        : null;
    final showImmutableHint =
        showHeader || showSectionLabel || genreLocked || ageLocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Text(
            l10n.onboardingIdentityTitle,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vGapXs,
        ] else if (showSectionLabel) ...[
          Text(
            l10n.profileIdentitySection,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          AppSpacing.vGapXs,
        ],
        if (showImmutableHint)
          Text(
            l10n.onboardingIdentitySubtitle,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        if (showHeader || showSectionLabel || showImmutableHint)
          AppSpacing.vGapMd,
        Text(
          l10n.profileGenderLabel,
          style: context.text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        AppSpacing.vGapSm,
        GenderSegmentedControl(
          selected: genre,
          locked: genreLocked || !enabled,
          onSelected: onGenreSelected,
        ),
        AppSpacing.vGapLg,
        _AgeField(
          controller: ageController,
          locked: ageLocked || !enabled,
          ageError: ageError,
          birthYearHelper: anneeNaissance != null
              ? l10n.profileAgeBirthYear(anneeNaissance)
              : null,
          onChanged: onAgeChanged,
        ),
      ],
    );
  }
}

/// Barre segmentée 4 options — proposition A.
class GenderSegmentedControl extends StatelessWidget {
  const GenderSegmentedControl({
    super.key,
    required this.selected,
    required this.locked,
    required this.onSelected,
  });

  final ProfileGender? selected;
  final bool locked;
  final ValueChanged<ProfileGender?> onSelected;

  void _onTap(ProfileGender value) {
    if (locked) return;
    onSelected(selected == value ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final control = DecoratedBox(
      decoration: BoxDecoration(
        color: context.semantic.surfaceMuted,
        borderRadius: AppRadius.brSm,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.brSm,
        child: Row(
          children: [
            for (var i = 0; i < ProfileGender.values.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.colors.outline.withValues(alpha: 0.35),
                ),
              Expanded(
                child: _GenderSegment(
                  label: ProfileGender.values[i].segmentLabel(context),
                  selected: selected == ProfileGender.values[i],
                  locked: locked,
                  onTap: () => _onTap(ProfileGender.values[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (locked) {
      return AbsorbPointer(child: control);
    }
    return control;
  }
}

class _GenderSegment extends StatelessWidget {
  const _GenderSegment({
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.colors.primary : Colors.transparent;
    final fg = selected
        ? context.colors.onPrimary
        : context.colors.onSurface;

    return Material(
      color: bg,
      child: InkWell(
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.md,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}

/// Champ âge : `readOnly` plutôt que `enabled: false` pour conserver l'icône
/// indigo comme les autres champs du formulaire.
class _AgeField extends StatelessWidget {
  const _AgeField({
    required this.controller,
    required this.locked,
    this.ageError,
    this.birthYearHelper,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool locked;
  final String? ageError;
  final String? birthYearHelper;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      readOnly: locked,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: locked ? null : (_) => onChanged?.call(),
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        labelText: context.l10n.profileAgeLabel,
        prefixIcon: const Icon(Icons.cake_outlined),
        suffixText: context.l10n.profileAgeSuffix,
        errorText: ageError,
        helperText: birthYearHelper,
      ),
    );

    if (locked) {
      return AbsorbPointer(child: field);
    }
    return field;
  }
}
