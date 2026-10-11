import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/billing/billing_models.dart';
import '../../core/services/billing/entitlement_service.dart';
import '../../core/services/billing/entitlements.dart';
import '../../core/services/billing/plus_status.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/billing/subscription_screen.dart';
import '../common/account_badge.dart' show VerifiedSeal;
import 'open_plus_offer.dart';
import 'plus_visuals.dart';

/// La carte Alanya Plus du profil, juste sous l'en-tête.
///
/// Une seule carte, un message par situation ([PlusStatus]), déduit des
/// droits déjà reçus : afficher le profil ne coûte aucun appel. Elle vend sur
/// fond indigo tant qu'il y a quelque chose à proposer ; l'abonné retrouve une
/// surface neutre, qui mène à « Mon abonnement ».
class PlusCard extends StatefulWidget {
  const PlusCard({super.key, this.verified = false});

  /// Identité vérifiée : la coche est affichée à côté du nom.
  final bool verified;

  @override
  State<PlusCard> createState() => _PlusCardState();
}

enum _Tone { promo, soft, alert }

class _PlusCardState extends State<PlusCard> {
  @override
  void initState() {
    super.initState();
    // Les prix viennent de l'offre : chargée une fois, gardée en cache.
    unawaited(context.read<EntitlementService>().ensureOffer());
  }

  void _openOffer() => unawaited(openPlusOffer(context));

  void _openSubscription() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final service = context.watch<EntitlementService>();
    final e = service.current;
    final status = plusStatusOf(e);
    if (status == PlusStatus.hidden) return const SizedBox.shrink();
    // La coche arrive avec les droits ; un serveur antérieur ne l'y met pas,
    // le profil fait alors foi.
    final verified = e.verificationStatus != null ? e.isVerified : widget.verified;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: switch (status) {
        PlusStatus.grace => _grace(context, e, service.offer),
        PlusStatus.upgrade => _upgrade(context, service.offer),
        PlusStatus.active => _active(context, e, service.offer, verified),
        PlusStatus.scheduled => _scheduled(context, e, service.offer),
        PlusStatus.lapsed => _lapsed(context, e),
        PlusStatus.trial => _trial(context, e),
        PlusStatus.restricted => _restricted(context),
        PlusStatus.hidden => const SizedBox.shrink(),
      },
    );
  }

  // ── Les messages ────────────────────────────────────────────────────

  Widget _grace(BuildContext context, Entitlements e, PlusOffer? offer) {
    final l10n = context.l10n;
    final until = e.graceUntil ?? DateTime.now();
    final date = formatPlusDate(context, until);
    final days = plusDaysLeft(until, DateTime.now());
    final palette = PlusPalette.of(context);
    return _Frame(
      tone: _Tone.promo,
      kicker: l10n.plusBrand,
      title: l10n.plusCardGraceTitle(date),
      body: l10n.plusCardGraceBody(date),
      extra: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: palette.chip,
            borderRadius: AppRadius.brPill,
          ),
          child: Text(
            l10n.plusCardGraceDaysLeft(days),
            style: context.text.labelSmall?.copyWith(
              color: palette.ink,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
      ],
      action: l10n.paywallSeeOffer,
      onAction: _openOffer,
    );
  }

  Widget _upgrade(BuildContext context, PlusOffer? offer) {
    final l10n = context.l10n;
    final palette = PlusPalette.of(context);
    final lowest = offer?.lowestMonthly;
    final featured = offer?.defaultPlan;
    return _Frame(
      tone: _Tone.promo,
      kicker: l10n.plusBrand,
      title: l10n.plusCardUpgradeTitle,
      extra: [
        Row(
          children: [
            for (final f in kPlusShowcase)
              Expanded(
                child: Column(
                  children: [
                    PlusFeatureGlyph(
                      feature: f,
                      size: 34,
                      background: palette.chip,
                      foreground: palette.ink,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Cinq colonnes sur 360 dp : « Sauvegarde » n'y tient
                    // pas entier. Réduire le corps plutôt que tronquer le mot.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          plusFeatureName(l10n, f),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: context.text.labelSmall
                              ?.copyWith(color: palette.inkMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (lowest != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatPlusAmount(context, lowest),
                style: context.text.titleLarge?.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabularFigures,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                l10n.plusPerMonth,
                style: context.text.bodySmall
                    ?.copyWith(color: palette.inkMuted),
              ),
              const Spacer(),
              if (featured != null && featured.durationMonths != 1)
                Text(
                  '${formatPlusAmount(context, featured.price)} '
                  '${plusPeriodSuffix(l10n, featured.durationMonths)}',
                  style: context.text.bodySmall?.copyWith(
                    color: palette.inkMuted,
                    fontFeatures: kTabularFigures,
                  ),
                ),
            ],
          ),
      ],
      action: l10n.plusCardDiscover,
      onAction: _openOffer,
    );
  }

  Widget _active(
    BuildContext context,
    Entitlements e,
    PlusOffer? offer,
    bool verified,
  ) {
    final l10n = context.l10n;
    final period = e.period!;
    final end = period.endsAt ?? DateTime.now();
    final date = formatPlusDate(context, end);
    final soon = plusEndsSoon(period, DateTime.now());
    final plan = plusPlanName(context, period.plan, offer: offer);
    return _Frame(
      tone: _Tone.soft,
      onTap: _openSubscription,
      kicker: '${l10n.plusBrand} · $plan',
      kickerColor: soon ? context.semantic.warning : null,
      chevron: true,
      title: soon
          ? l10n.plusCardEndsOn(date)
          : l10n.plusCardActiveUntil(date),
      body: soon
          ? l10n.plusCardEndsSoonBody(plusDaysLeft(end, DateTime.now()))
          : (e.isTrialModel
              // Régime essai : pas de renouvellement automatique, un nouveau
              // code chaque année.
              ? l10n.plusCardRenewByCode
              : (period.autoRenew
                  ? l10n.plusCardAutoRenewOn
                  : l10n.plusCardAutoRenewOff)),
      extra: [
        // Abonné : on cesse de vendre ; la coche suit l'abonnement.
        _BadgeRow(verified: verified),
      ],
      action: soon ? l10n.plusRenew : null,
      onAction: soon ? _openOffer : null,
    );
  }

  Widget _scheduled(BuildContext context, Entitlements e, PlusOffer? offer) {
    final l10n = context.l10n;
    final upcoming = e.upcoming!;
    final start = upcoming.startsAt ?? DateTime.now();
    final plan = plusPlanName(context, upcoming.plan, offer: offer);
    return _Frame(
      tone: _Tone.soft,
      onTap: _openSubscription,
      kicker: '${l10n.plusBrand} · $plan',
      chevron: true,
      title: l10n.plusCardStartsOn(formatPlusDate(context, start)),
      body: e.isTrialModel
          ? l10n.plusCardScheduledTrialBody
          : l10n.plusCardScheduledBody,
    );
  }

  Widget _lapsed(BuildContext context, Entitlements e) {
    final l10n = context.l10n;
    final ended = e.lapsedAt ?? DateTime.now();
    return _Frame(
      tone: _Tone.alert,
      onTap: _openSubscription,
      kicker: l10n.plusCardLapsedKicker(formatPlusDate(context, ended)),
      kickerIcon: Icons.error_outline_rounded,
      kickerColor: context.colors.error,
      title: e.isTrialModel
          ? l10n.plusCardRestrictedTitle
          : l10n.plusCardLapsedTitle,
      body: lapsedBody(context, e),
      action: l10n.plusResubscribe,
      onAction: _openOffer,
    );
  }

  /// Régime essai : l'essai court, tout est ouvert.
  Widget _trial(BuildContext context, Entitlements e) {
    final l10n = context.l10n;
    final end = e.trial!.endsAt;
    final days = plusDaysLeft(end, DateTime.now());
    final palette = PlusPalette.of(context);
    return _Frame(
      tone: _Tone.promo,
      kicker: l10n.plusCardTrialKicker,
      title: l10n.plusCardTrialTitle(formatPlusDate(context, end)),
      body: l10n.plusCardTrialBody,
      extra: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: palette.chip,
            borderRadius: AppRadius.brPill,
          ),
          child: Text(
            l10n.plusCardTrialDaysLeft(days),
            style: context.text.labelSmall?.copyWith(
              color: palette.ink,
              fontFeatures: kTabularFigures,
            ),
          ),
        ),
      ],
      action: l10n.plusCardSubscribe,
      onAction: _openOffer,
    );
  }

  /// Régime essai : l'essai est fini, aucun abonnement n'a pris le relais. Le
  /// compte reçoit, il ne peut ni envoyer ni appeler.
  Widget _restricted(BuildContext context) {
    final l10n = context.l10n;
    return _Frame(
      tone: _Tone.alert,
      kicker: l10n.plusCardRestrictedKicker,
      kickerIcon: Icons.error_outline_rounded,
      kickerColor: context.colors.error,
      title: l10n.plusCardRestrictedTitle,
      body: l10n.plusCardRestrictedBody,
      action: l10n.plusCardSubscribe,
      onAction: _openOffer,
    );
  }
}

/// La ligne de la coche dans la carte : affichée ou absente — plus de
/// dossier à instruire pour les comptes personnels.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.semantic.brandContainer,
        borderRadius: AppRadius.brSm,
      ),
      child: Row(
        children: [
          verified
              ? const VerifiedSeal(size: 20)
              : Icon(
                  Icons.verified_outlined,
                  size: 20,
                  color: context.colors.primary,
                ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              verified
                  ? l10n.plusCardBadgeActive
                  : l10n.plusCardBadgeMissing,
              style: context.text.bodySmall?.copyWith(
                color: context.semantic.onBrandContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ce que devient le compte après l'échéance : conservé jusqu'au…, puis
/// effacé. Partagé avec « Mon abonnement ».
String lapsedBody(BuildContext context, Entitlements e) {
  final l10n = context.l10n;
  // Régime essai : ce qui compte est que le compte ne fait plus que recevoir.
  if (e.isTrialModel) return l10n.plusCardLapsedTrialBody;
  if (e.purgedAt != null) return l10n.plusCardPurgedBody;
  final until = e.purgeAfter;
  if (until != null) return l10n.plusCardLapsedBodyUntil(formatPlusDate(context, until));
  return l10n.plusCardLapsedBody;
}

/// La coque commune : fond, bordure, typographie et bouton, selon le ton.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.tone,
    required this.kicker,
    required this.title,
    this.body,
    this.kickerIcon,
    this.kickerColor,
    this.chevron = false,
    this.extra = const [],
    this.action,
    this.onAction,
    this.onTap,
  });

  final _Tone tone;
  final String kicker;
  final IconData? kickerIcon;
  final Color? kickerColor;
  final bool chevron;
  final String title;
  final String? body;
  final List<Widget> extra;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final promo = tone == _Tone.promo;
    final palette = PlusPalette.of(context);
    final ink = promo ? palette.ink : context.colors.onSurface;
    final muted = promo ? palette.inkMuted : context.colors.onSurfaceVariant;
    final accent = kickerColor ?? (promo ? palette.inkMuted : context.colors.primary);

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (kickerIcon != null) ...[
                Icon(kickerIcon, size: 15, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  kicker.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(
                    color: accent,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (chevron)
                Icon(Icons.chevron_right_rounded, size: 20, color: muted),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              style: context.text.bodyMedium?.copyWith(
                color: muted,
                height: 1.45,
              ),
            ),
          ],
          for (final w in extra) ...[AppSpacing.vGapMd, w],
          if (action != null) ...[
            AppSpacing.vGapLg,
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                style: promo
                    ? FilledButton.styleFrom(
                        backgroundColor: palette.button,
                        foregroundColor: palette.onButton,
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.brSm),
                      )
                    : FilledButton.styleFrom(
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.brSm),
                      ),
                onPressed: onAction,
                child: Text(action!,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: promo ? palette.background : context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: promo
            ? BorderSide.none
            : BorderSide(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: tone == _Tone.alert
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3, color: context.colors.error),
                    Expanded(child: content),
                  ],
                ),
              )
            : content,
      ),
    );
  }
}
