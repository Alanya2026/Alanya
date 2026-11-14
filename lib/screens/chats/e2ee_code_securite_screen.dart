import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/e2ee/e2ee_code_securite.dart';
import '../../core/e2ee/e2ee_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// L'écran du code de sécurité d'une conversation chiffrée à deux.
///
/// Le code se compare HORS de l'application (de vive voix, en personne) :
/// le copier pour l'envoyer dans la même discussion ne prouverait rien. Il
/// n'y a donc ni bouton de copie ni partage.
class E2eeCodeSecuriteScreen extends StatefulWidget {
  const E2eeCodeSecuriteScreen({
    super.key,
    required this.conversationID,
    required this.moi,
    required this.nom,
  });

  final int conversationID;
  final int moi;
  final String nom;

  @override
  State<E2eeCodeSecuriteScreen> createState() => _E2eeCodeSecuriteScreenState();
}

class _E2eeCodeSecuriteScreenState extends State<E2eeCodeSecuriteScreen> {
  CodeSecurite? _code;
  bool _charge = true;
  bool _erreur = false;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger() async {
    setState(() {
      _charge = true;
      _erreur = false;
    });
    try {
      final code = await E2eeService.maybeInstance
          ?.codeSecurite(conversationID: widget.conversationID, moi: widget.moi);
      if (!mounted) return;
      setState(() {
        _code = code;
        _charge = false;
      });
    } catch (e) {
      debugPrint('[E2EE] code de sécurité : $e');
      if (!mounted) return;
      setState(() {
        _erreur = true;
        _charge = false;
      });
    }
  }

  Future<void> _basculerVerification() async {
    final code = _code;
    final service = E2eeService.maybeInstance;
    if (code == null || service == null) return;
    if (code.verifie) {
      await service.retirerVerification(widget.conversationID);
    } else {
      await service.marquerVerifie(widget.conversationID, code.empreinte);
    }
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final code = _code;

    Widget corps;
    if (_charge) {
      corps = const Center(child: CircularProgressIndicator());
    } else if (_erreur || code == null) {
      corps = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.e2eeCodeIndisponible, textAlign: TextAlign.center),
              if (_erreur) ...[
                AppSpacing.vGapMd,
                TextButton(onPressed: _charger, child: Text(l10n.commonRetry)),
              ],
            ],
          ),
        ),
      );
    } else {
      corps = ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Icon(
            code.verifie ? Icons.verified_user : Icons.lock_outline,
            size: 48,
            color: code.verifie ? Colors.green : theme.colorScheme.primary,
          ),
          AppSpacing.vGapLg,
          // Trois lignes de quatre groupes, chiffres à chasse fixe : on lit
          // un groupe, l'autre confirme.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.md,
            children: [
              for (final g in code.groupes)
                Text(
                  g,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
            ],
          ),
          AppSpacing.vGapLg,
          Text(l10n.e2eeCodeSecuriteExplication(widget.nom), textAlign: TextAlign.center),
          if (code.appareilsManquants > 0) ...[
            AppSpacing.vGapMd,
            Text(
              l10n.e2eeCodeSecuriteManquants,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (code.verifie) ...[
            AppSpacing.vGapMd,
            Text(
              l10n.e2eeVerifieExplication,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          AppSpacing.vGapLg,
          code.verifie
              ? OutlinedButton(
                  onPressed: _basculerVerification,
                  child: Text(l10n.e2eeRetirerVerification),
                )
              : FilledButton.icon(
                  onPressed: _basculerVerification,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: Text(l10n.e2eeMarquerVerifie),
                ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.e2eeCodeSecuriteTitre)),
      body: SafeArea(child: corps),
    );
  }
}

/// Bandeau d'une discussion chiffrée : une clé du correspondant a changé, ou
/// un appareil est apparu chez lui.
///
/// Les deux causes (réinstallation, interposition) ne se distinguent pas
/// d'ici : le bandeau ne bloque rien, il invite à comparer le code. Il reste
/// affiché jusqu'à ce que l'utilisateur l'ouvre ou le ferme.
class E2eeAlerteCleBandeau extends StatelessWidget {
  const E2eeAlerteCleBandeau({
    super.key,
    required this.nom,
    required this.onVerifier,
    required this.onFermer,
  });

  final String nom;
  final VoidCallback onVerifier;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.gpp_maybe_outlined, color: theme.colorScheme.onTertiaryContainer),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                context.l10n.e2eeAlerteCleChangee(nom),
                style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
            TextButton(onPressed: onVerifier, child: Text(context.l10n.e2eeAlerteVerifier)),
            IconButton(
              tooltip: context.l10n.commonClose,
              icon: const Icon(Icons.close),
              onPressed: onFermer,
            ),
          ],
        ),
      ),
    );
  }
}
