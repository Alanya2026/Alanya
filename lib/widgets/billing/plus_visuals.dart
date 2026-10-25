import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/billing/billing_models.dart';
import '../../core/services/billing/entitlements.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Vocabulaire visuel partagé des écrans Alanya Plus : couleurs de la carte,
/// icônes et noms des fonctionnalités, montants et dates.

/// Couleurs de la carte qui « vend » : l'indigo profond de la marque.
///
/// Réservé aux états où il y a quelque chose à proposer. Un abonné retrouve
/// une surface neutre — on ne fait pas la publicité de ce qu'il a déjà.
class PlusPalette {
  const PlusPalette._({
    required this.background,
    required this.ink,
    required this.inkMuted,
    required this.chip,
    required this.button,
    required this.onButton,
  });

  final Color background;
  final Color ink;
  final Color inkMuted;
  final Color chip;
  final Color button;
  final Color onButton;

  static PlusPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PlusPalette._(
      // indigo 900 en clair ; indigo 800 en sombre, pour se détacher du fond.
      background: dark ? const Color(0xFF283593) : const Color(0xFF1A237E),
      ink: Colors.white,
      inkMuted: const Color(0xFFC5CAE9),
      chip: const Color(0x1FFFFFFF),
      button: Colors.white,
      onButton: const Color(0xFF1A237E),
    );
  }
}

IconData plusFeatureIcon(PlusFeature feature) => switch (feature) {
      PlusFeature.translation => Icons.translate_rounded,
      PlusFeature.backup => Icons.cloud_upload_outlined,
      PlusFeature.trustedTrips => Icons.shield_outlined,
      PlusFeature.listRingtones => Icons.music_note_outlined,
      PlusFeature.style => Icons.palette_outlined,
      PlusFeature.verifiedBadge => Icons.verified_outlined,
      PlusFeature.stickersPremium => Icons.emoji_emotions_outlined,
    };

/// Nom court, pour les pastilles de la carte et les listes.
String plusFeatureName(AppLocalizations l10n, PlusFeature feature) =>
    switch (feature) {
      PlusFeature.translation => l10n.plusFeatureTranslation,
      PlusFeature.backup => l10n.plusFeatureBackup,
      PlusFeature.trustedTrips => l10n.plusFeatureTrips,
      PlusFeature.listRingtones => l10n.plusFeatureRingtones,
      PlusFeature.style => l10n.plusFeatureStyle,
      PlusFeature.verifiedBadge => l10n.plusFeatureBadge,
      PlusFeature.stickersPremium => l10n.plusFeatureStickers,
    };

/// Les fonctionnalités livrées, dans l'ordre où l'offre les présente.
const List<PlusFeature> kPlusShowcase = [
  PlusFeature.translation,
  PlusFeature.backup,
  PlusFeature.trustedTrips,
  PlusFeature.listRingtones,
  PlusFeature.verifiedBadge,
];

String _localeTag(BuildContext context) =>
    Localizations.localeOf(context).toString();

/// « 2 000 F » : montant en francs CFA, groupé à la manière de la langue.
String formatPlusAmount(BuildContext context, int amount) =>
    context.l10n.plusAmount(
      NumberFormat.decimalPattern(_localeTag(context)).format(amount),
    );

/// « / mois », « / an », « / 3 mois ».
String plusPeriodSuffix(AppLocalizations l10n, int months) => switch (months) {
      1 => l10n.plusPerMonth,
      12 => l10n.plusPerYear,
      _ => l10n.plusPerNMonths(months),
    };

/// « 10 octobre 2027 ».
String formatPlusDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMMd(_localeTag(context)).format(date.toLocal());

/// « 10 oct. 2027 », pour les lignes d'historique.
String formatPlusShortDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(_localeTag(context)).format(date.toLocal());

/// Nom d'un plan à partir de son code, pour les droits (qui ne portent que le
/// code). L'offre, quand elle est connue, donne le nom saisi en
/// administration ; sinon on retombe sur la durée lisible dans le code.
String plusPlanName(
  BuildContext context,
  String? code, {
  PlusOffer? offer,
}) {
  final plan = offer?.planByCode(code);
  if (plan != null) {
    final name = plan.nameFor(Localizations.localeOf(context).languageCode);
    if (name.isNotEmpty) return name;
    if (plan.durationMonths == 12) return context.l10n.plusPlanYearly;
    if (plan.durationMonths == 1) return context.l10n.plusPlanMonthly;
  }
  final c = code ?? '';
  if (c.contains('annuel') || c.contains('year')) return context.l10n.plusPlanYearly;
  if (c.contains('mensuel') || c.contains('month')) return context.l10n.plusPlanMonthly;
  return context.l10n.plusBrand;
}

/// Petite étiquette « ALANYA PLUS » en capitales espacées.
class PlusTag extends StatelessWidget {
  const PlusTag({super.key, this.color, this.text});

  final Color? color;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Text(
      (text ?? context.l10n.plusBrand).toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: color ?? context.colors.primary,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Chiffres alignés : montants, dates et décomptes.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

/// Titre de section en petites capitales, au-dessus d'un groupe.
class PlusSectionLabel extends StatelessWidget {
  const PlusSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onSurfaceVariant,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Bouton radio dessiné : anneau, plein quand [selected].
class PlusChoiceDot extends StatelessWidget {
  const PlusChoiceDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? context.colors.primary : context.colors.outline;
    return AnimatedContainer(
      duration: AppDurations.fast,
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: AnimatedScale(
        duration: AppDurations.fast,
        scale: selected ? 1 : 0,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.primary,
          ),
        ),
      ),
    );
  }
}

enum PlusStepState { done, current, todo }

/// Une étape d'une frise verticale (paiement, vérification) : pastille, trait
/// vers la suivante, titre et précision.
class PlusTimelineStep extends StatelessWidget {
  const PlusTimelineStep({
    super.key,
    required this.state,
    required this.title,
    required this.subtitle,
    this.last = false,
  });

  final PlusStepState state;
  final String title;
  final String subtitle;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final dot = switch (state) {
      PlusStepState.done => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.semantic.success,
          ),
          child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
        ),
      PlusStepState.current => Container(
          width: 18,
          height: 18,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primary, width: 2),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: primary),
          ),
        ),
      PlusStepState.todo => Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.outline, width: 2),
          ),
        ),
    };
    final muted = state == PlusStepState.todo;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              dot,
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: state == PlusStepState.done
                        ? context.semantic.success.withValues(alpha: 0.5)
                        : context.colors.outlineVariant,
                  ),
                ),
            ],
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: muted
                          ? context.colors.onSurfaceVariant
                          : context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastille ronde d'une fonctionnalité (icône sur fond teinté).
class PlusFeatureGlyph extends StatelessWidget {
  const PlusFeatureGlyph({
    super.key,
    required this.feature,
    this.size = 40,
    this.background,
    this.foreground,
    this.radius,
  });

  final PlusFeature feature;
  final double size;
  final Color? background;
  final Color? foreground;

  /// Nul : cercle.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? context.semantic.brandContainer,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
      ),
      child: Icon(
        plusFeatureIcon(feature),
        size: size * 0.5,
        color: foreground ?? context.colors.primary,
      ),
    );
  }
}
