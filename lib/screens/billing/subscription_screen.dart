import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/billing/billing_models.dart';
import '../../core/services/billing/entitlement_service.dart';
import '../../core/services/billing/entitlements.dart';
import '../../core/services/billing/plus_status.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../widgets/billing/open_plus_offer.dart';
import '../../widgets/billing/plus_card.dart' show lapsedBody;
import '../../widgets/billing/plus_visuals.dart';

/// « Mon abonnement » : l'état, le renouvellement, l'historique.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  PlusHistory? _history;
  Object? _historyError;
  bool _savingAutoRenew = false;

  @override
  void initState() {
    super.initState();
    final service = context.read<EntitlementService>();
    unawaited(service.ensureOffer());
    unawaited(service.refresh());
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    try {
      final raw = await context.read<TalkyApiClient>().getPlusHistory();
      if (!mounted) return;
      setState(() {
        _history = PlusHistory.fromJson(raw);
        _historyError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _historyError = e);
    }
  }

  Future<void> _refreshAll() async {
    await context.read<EntitlementService>().refresh();
    await _loadHistory();
  }

  Future<void> _openOffer({String? planCode}) async {
    final paid = await openPlusOffer(context, planCode: planCode);
    if (paid && mounted) unawaited(_loadHistory());
  }

  Future<void> _setAutoRenew(bool value) async {
    setState(() => _savingAutoRenew = true);
    final service = context.read<EntitlementService>();
    try {
      final raw = await context
          .read<TalkyApiClient>()
          .updatePlusPreferences(autoRenew: value);
      await service.apply(raw);
    } catch (e) {
      if (mounted) afficherErreur(context, e, domaine: ErrorDomain.abonnement);
    } finally {
      if (mounted) setState(() => _savingAutoRenew = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final service = context.watch<EntitlementService>();
    final e = service.current;
    final offer = service.offer;
    final status = plusStatusOf(e);
    final period = e.period;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.subscriptionTitle)),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _StatusCard(entitlements: e, offer: offer),
            ..._actions(context, status, period, offer),
            // Régime essai : pas de renouvellement automatique, un nouveau code
            // chaque année.
            if (status == PlusStatus.active && period != null && !e.isTrialModel) ...[
              AppSpacing.vGapXl,
              Material(
                color: context.colors.surface,
                borderRadius: AppRadius.brMd,
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  value: period.autoRenew,
                  onChanged: _savingAutoRenew ? null : _setAutoRenew,
                  title: Text(l10n.subscriptionAutoRenew,
                      style: context.text.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(l10n.subscriptionAutoRenewHint),
                ),
              ),
            ],
            // Régime essai : on ne paie pas dans l'application, la liste des
            // paiements n'aurait rien à dire.
            if (!e.isTrialModel) ...[
              AppSpacing.vGapXl,
              PlusSectionLabel(l10n.subscriptionPayments),
              _payments(context),
            ],
            if ((_history?.periods ?? const []).isNotEmpty) ...[
              AppSpacing.vGapXl,
              PlusSectionLabel(l10n.subscriptionPeriods),
              _periods(context, _history!.periods, offer),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    PlusStatus status,
    PlusPeriod? period,
    PlusOffer? offer,
  ) {
    final l10n = context.l10n;
    final trialModel = EntitlementService.maybeInstance?.current.isTrialModel ?? false;
    final (String? label, String? plan) = trialModel
        ? switch (status) {
            PlusStatus.trial || PlusStatus.restricted => (l10n.plusCardSubscribe, null),
            PlusStatus.lapsed => (l10n.plusResubscribe, null),
            PlusStatus.active
                when period != null && plusEndsSoon(period, DateTime.now()) =>
              (l10n.plusRenew, null),
            _ => (null, null),
          }
        : switch (status) {
            PlusStatus.active => (
                offer?.planByCode(period?.plan) != null
                    ? l10n.subscriptionRenewAmount(formatPlusAmount(
                        context, offer!.planByCode(period?.plan)!.price))
                    : l10n.plusRenew,
                period?.plan,
              ),
            PlusStatus.lapsed => (l10n.plusResubscribe, null),
            PlusStatus.upgrade || PlusStatus.grace => (l10n.plusCardDiscover, null),
            _ => (null, null),
          };
    if (label == null) return const [];
    return [
      AppSpacing.vGapMd,
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
        ),
        onPressed: () => _openOffer(planCode: plan),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ];
  }

  Widget _payments(BuildContext context) {
    final l10n = context.l10n;
    final history = _history;
    if (history == null) {
      return _historyError == null
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          : _Box(
              child: Text(
                presenterErreur(l10n, _historyError,
                    domaine: ErrorDomain.abonnement),
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            );
    }
    // L'achat d'un numéro passe par le même paiement mais n'est pas un
    // abonnement : il n'a rien à faire dans l'historique d'Alanya Plus.
    final payments = [
      for (final p in history.payments)
        if (!p.isPhone) p,
    ];
    if (payments.isEmpty) {
      return _Box(
        child: Text(
          l10n.subscriptionNoPayments,
          style: context.text.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      );
    }
    return _Rows(
      children: [
        for (final p in payments)
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (p.createdAt != null)
                      formatPlusShortDate(context, p.createdAt!),
                    formatPlusAmount(context, p.amount),
                    if (p.channel != null) p.channel!.brand,
                  ].join(' · '),
                  style: context.text.bodySmall
                      ?.copyWith(fontFeatures: kTabularFigures),
                ),
              ),
              AppSpacing.hGapSm,
              Text(
                _statusLabel(context, p.status),
                style: context.text.labelMedium?.copyWith(
                  color: _statusColor(context, p.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _periods(
    BuildContext context,
    List<PlusPeriod> periods,
    PlusOffer? offer,
  ) {
    final l10n = context.l10n;
    return _Rows(
      children: [
        for (final p in periods)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${plusPlanName(context, p.plan, offer: offer)} · '
                  '${p.startsAt == null ? '' : formatPlusShortDate(context, p.startsAt!)}'
                  ' → '
                  '${p.endsAt == null ? '' : formatPlusShortDate(context, p.endsAt!)}',
                  style: context.text.bodySmall
                      ?.copyWith(fontFeatures: kTabularFigures),
                ),
              ),
              AppSpacing.hGapSm,
              Text(
                switch (p.source) {
                  1 => l10n.subscriptionSourceTrial,
                  2 => l10n.subscriptionSourceGift,
                  3 => l10n.subscriptionSourceCompensation,
                  4 => l10n.subscriptionSourceCode,
                  _ => l10n.subscriptionSourcePaid,
                },
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }

  static String _statusLabel(BuildContext context, PaymentStatus s) {
    final l10n = context.l10n;
    return switch (s) {
      PaymentStatus.succeeded => l10n.paymentStatusSucceeded,
      PaymentStatus.failed => l10n.paymentStatusFailed,
      PaymentStatus.expired => l10n.paymentStatusExpired,
      PaymentStatus.refunded => l10n.paymentStatusRefunded,
      PaymentStatus.created || PaymentStatus.pending => l10n.paymentStatusPending,
    };
  }

  static Color _statusColor(BuildContext context, PaymentStatus s) =>
      switch (s) {
        PaymentStatus.succeeded => context.semantic.success,
        PaymentStatus.failed || PaymentStatus.expired => context.colors.error,
        PaymentStatus.created || PaymentStatus.pending => context.semantic.warning,
        PaymentStatus.refunded => context.colors.onSurfaceVariant,
      };
}

/// L'état du compte, en tête de l'écran.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.entitlements, required this.offer});

  final Entitlements entitlements;
  final PlusOffer? offer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = entitlements;
    final now = DateTime.now();
    final status = plusStatusOf(e);

    String kicker = l10n.plusBrand;
    Color? accent;
    String title;
    String? body;
    Color? strip;

    switch (status) {
      case PlusStatus.active:
        final p = e.period!;
        final end = p.endsAt ?? now;
        final plan = offer?.planByCode(p.plan);
        kicker = [
          plusPlanName(context, p.plan, offer: offer),
          if (plan != null) formatPlusAmount(context, plan.price),
        ].join(' · ');
        if (plusEndsSoon(p, now)) {
          strip = accent = context.semantic.warning;
          title = l10n.plusCardEndsOn(formatPlusDate(context, end));
          body = l10n.subscriptionEndsIn(plusDaysLeft(end, now));
        } else {
          title = l10n.plusCardActiveUntil(formatPlusDate(context, end));
          body = e.isTrialModel
              ? l10n.plusCardRenewByCode
              : (p.autoRenew
                  ? l10n.plusCardAutoRenewOn
                  : l10n.plusCardAutoRenewOff);
        }
      case PlusStatus.scheduled:
        final p = e.upcoming!;
        kicker = plusPlanName(context, p.plan, offer: offer);
        title = l10n.plusCardStartsOn(formatPlusDate(context, p.startsAt ?? now));
        body = e.isTrialModel
            ? l10n.plusCardScheduledTrialBody
            : l10n.plusCardScheduledBody;
      case PlusStatus.lapsed:
        strip = accent = context.colors.error;
        kicker = l10n.plusCardLapsedKicker(
            formatPlusDate(context, e.lapsedAt ?? now));
        title = e.isTrialModel
            ? l10n.plusCardRestrictedTitle
            : l10n.plusCardLapsedTitle;
        body = lapsedBody(context, e);
      case PlusStatus.grace:
        final date = formatPlusDate(context, e.graceUntil ?? now);
        title = l10n.plusCardGraceTitle(date);
        body = l10n.plusCardGraceBody(date);
      case PlusStatus.trial:
        kicker = l10n.plusCardTrialKicker;
        title = l10n.plusCardTrialTitle(formatPlusDate(context, e.trial!.endsAt));
        body = l10n.plusCardTrialBody;
      case PlusStatus.restricted:
        strip = accent = context.colors.error;
        kicker = l10n.plusCardRestrictedKicker;
        title = l10n.plusCardRestrictedTitle;
        body = l10n.plusCardRestrictedBody;
      case PlusStatus.upgrade:
        title = l10n.subscriptionNoneTitle;
        body = l10n.subscriptionNoneBody;
      case PlusStatus.hidden:
        title = e.exempt
            ? l10n.subscriptionExemptTitle
            : l10n.plusOfferUnavailable;
        body = null;
    }

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: accent ?? context.colors.primary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body,
              style: context.text.bodyMedium?.copyWith(
                color: accent == context.semantic.warning
                    ? accent
                    : context.colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: strip == null
          ? content
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: strip),
                  Expanded(child: content),
                ],
              ),
            ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.surface,
        borderRadius: AppRadius.brSm,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
}

class _Rows extends StatelessWidget {
  const _Rows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: context.colors.surface,
        borderRadius: AppRadius.brSm,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, color: context.colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                child: children[i],
              ),
            ],
          ],
        ),
      );
}
