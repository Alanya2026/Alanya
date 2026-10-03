import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/billing/activation_code.dart';
import '../../core/services/billing/billing_models.dart';
import '../../core/services/billing/entitlement_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../widgets/billing/plus_visuals.dart';

/// Saisie d'un code d'abonnement.
///
/// Le code a été remis sur le site de paiement, après le paiement : il vaut une
/// année, pour n'importe quel compte, une seule fois. Une faute de frappe est
/// refusée ici même (le contrôle est celui du serveur) — elle ne compte pas
/// comme un essai, et ne coûte aucun aller-retour.
///
/// Rend `true` à la fermeture si un code a été activé.
class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({super.key});

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  RedeemResult? _done;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  ActivationCodeParse get _parsed => parseActivationCode(_controller.text);

  /// Le message du champ : la faute de frappe, dite dès que le code est complet.
  String? _fieldError(BuildContext context) {
    if (_error != null) return _error;
    final text = _controller.text;
    final formatted = formatActivationInput(text);
    if (formatted.replaceAll('-', '').length < kActivationCodeLength) return null;
    return _parsed.issue == ActivationCodeIssue.checksum
        ? context.l10n.redeemChecksumError
        : null;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    _setText(text);
  }

  void _setText(String raw) {
    final formatted = formatActivationInput(raw);
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() => _error = null);
  }

  Future<void> _submit() async {
    final canonical = _parsed.canonical;
    if (canonical == null || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<TalkyApiClient>();
    final service = context.read<EntitlementService>();
    try {
      final raw = await api.redeemActivationCode(canonical);
      final result = RedeemResult.fromJson(raw);
      // Les droits rendus par le serveur s'appliquent tout de suite : l'écran
      // suivant, et les envois, n'attendent aucun événement.
      await service.apply(result.entitlements);
      if (!mounted) return;
      setState(() {
        _done = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _messageFor(context, e);
      });
    }
  }

  /// Le texte d'un refus. `CODE_LOCKED` dit dans combien de temps réessayer.
  String _messageFor(BuildContext context, Object e) {
    final l10n = context.l10n;
    final cause = e is AppError ? e.cause : e;
    if (cause is TalkyException && cause.code == 'CODE_LOCKED') {
      final seconds = (cause.details?['retryAfterSeconds'] as num?)?.toInt();
      if (seconds != null && seconds > 0) {
        return l10n.redeemLocked((seconds / 60).ceil());
      }
    }
    return presenterErreur(l10n, e, domaine: ErrorDomain.abonnement);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final done = _done;
    return PopScope<bool>(
      canPop: done == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && done != null) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: context.semantic.surfaceMuted,
        appBar: AppBar(title: Text(l10n.redeemTitle)),
        body: SafeArea(
          child: done != null ? _success(context, done) : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    final error = _fieldError(context);
    final ready = _parsed.canonical != null && !_busy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          l10n.redeemIntro,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        AppSpacing.vGapXl,
        TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          enabled: !_busy,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            TextInputFormatter.withFunction((old, value) {
              final formatted = formatActivationInput(value.text);
              return TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }),
          ],
          style: context.text.titleLarge?.copyWith(
            fontFamily: 'monospace',
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.redeemFieldLabel,
            hintText: l10n.redeemFieldHint,
            errorText: error,
            errorMaxLines: 3,
            suffixIcon: IconButton(
              tooltip: l10n.redeemPaste,
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: _busy ? null : _paste,
            ),
          ),
        ),
        AppSpacing.vGapXl,
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
          ),
          onPressed: ready ? _submit : null,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.redeemSubmit,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _success(BuildContext context, RedeemResult result) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final end = result.endsAt;
    final start = result.startsAt;
    final text = end == null
        ? ''
        : (result.startsLater(now) && start != null
            ? l10n.redeemSuccessScheduled(
                formatPlusDate(context, start),
                formatPlusDate(context, end),
              )
            : l10n.redeemSuccessActive(formatPlusDate(context, end)));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.check_circle_rounded,
              size: 72, color: context.semantic.success),
          AppSpacing.vGapLg,
          Text(
            l10n.redeemSuccessTitle,
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (text.isNotEmpty) ...[
            AppSpacing.vGapSm,
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.redeemDone,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
