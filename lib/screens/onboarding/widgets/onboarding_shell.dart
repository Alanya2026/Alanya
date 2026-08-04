import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';

/// Chrome commun aux étapes d'onboarding.
///
/// Tout ce fichier suit une seule règle : ne rien inventer visuellement. Les
/// tailles de texte descendent de celles des écrans d'auth qui précèdent
/// immédiatement (`headlineLarge` 30 → `headlineMedium` 26 ici), les libellés de
/// section reprennent le style de `SettingsGroup`, et les champs de saisie
/// s'appuient sur l'`inputDecorationTheme` global plutôt que sur une décoration
/// maison — l'onboarding est une continuation de l'inscription, pas un univers
/// à part.

/// En-tête : retour, « configurer plus tard », et progression.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.current,
    required this.total,
    this.onBack,
    this.onSkipAll,
  });

  final int current;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onSkipAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: l10n.back,
                )
              else
                const SizedBox(width: AppSizes.minTapTarget),
              Expanded(
                child: Text(
                  l10n.onboardingStepOf(current + 1, total),
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (onSkipAll != null)
                TextButton(
                  onPressed: onSkipAll,
                  child: Text(l10n.onboardingSkipAll),
                )
              else
                const SizedBox(width: AppSizes.minTapTarget),
            ],
          ),
          AppSpacing.vGapSm,
          // Barre segmentée plutôt que des points : à trois étapes, la part
          // parcourue se lit d'un coup d'œil, et l'ensemble occupe moins de
          // place verticale que le couple compteur + pastilles.
          Padding(
            padding: AppSpacing.screenH,
            child: Row(
              children: List.generate(total, (i) {
                final done = i <= current;
                return Expanded(
                  child: AnimatedContainer(
                    duration: AppDurations.normal,
                    curve: Curves.easeOutCubic,
                    height: 4,
                    margin: EdgeInsets.only(right: i == total - 1 ? 0 : AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: done
                          ? context.colors.primary
                          : context.colors.outlineVariant,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre + sous-titre, corps défilant, CTA épinglé en bas.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onContinue,
    this.continueLabel,
    this.continueLoading = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onContinue;
  final String? continueLabel;
  final bool continueLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screenH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.headlineMedium),
              AppSpacing.vGapSm,
              Text(
                subtitle,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vGapXl,
        Expanded(
          child: SingleChildScrollView(
            padding: AppSpacing.screenH.copyWith(bottom: AppSpacing.xxl),
            child: child,
          ),
        ),
        // Filet de séparation : sans lui, un corps défilant passe sous le bouton
        // sans qu'on voie où il s'arrête.
        const Divider(height: 1),
        Padding(
          padding: AppSpacing.screenH.copyWith(
            top: AppSpacing.lg,
            bottom: AppSpacing.lg,
          ),
          child: FilledButton(
            onPressed: continueLoading ? null : onContinue,
            child: continueLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onPrimary,
                    ),
                  )
                : Text(continueLabel ?? l10n.onboardingContinue),
          ),
        ),
      ],
    );
  }
}

/// Libellé de section — même style que `SettingsGroup`, la grammaire de section
/// déjà installée dans les écrans de réglages.
class OnboardingSectionLabel extends StatelessWidget {
  const OnboardingSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final texte = Text(
      label,
      style: context.text.labelMedium?.copyWith(
        color: context.colors.primary,
        fontWeight: FontWeight.w700,
      ),
    );
    if (trailing == null) return texte;
    return Row(
      children: [
        texte,
        AppSpacing.hGapSm,
        trailing!,
      ],
    );
  }
}

/// Carte blanche standard de l'app (cf. `account_hub_screen`, `SectionCard`).
class OnboardingCard extends StatelessWidget {
  const OnboardingCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? AppSpacing.card,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: AppShadows.subtle,
      ),
      child: child,
    );
  }
}
