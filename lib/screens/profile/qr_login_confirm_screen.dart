import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/utils/app_log.dart';
import '../../models/qr_models.dart';
import '../../talky_api_client.dart';
import '../../widgets/account/warning_banner.dart';

/// Confirmation d'une connexion, sur l'appareil DÉJÀ connecté qui vient de
/// scanner un code de session.
///
/// C'est le seul rempart contre le « quishing » : un code de connexion affiché
/// sur un site tiers et scanné par mégarde ne doit rien déclencher tant que
/// l'utilisateur n'a pas lu qui il autorise et appuyé sur Confirmer. Rien n'est
/// approuvé à l'affichage, ni au retour, ni par un raccourci.
class QrLoginConfirmScreen extends StatefulWidget {
  const QrLoginConfirmScreen({
    super.key,
    required this.session,
    required this.scanSecret,
  });

  final QrLoginSessionInfo session;
  final String scanSecret;

  @override
  State<QrLoginConfirmScreen> createState() => _QrLoginConfirmScreenState();
}

/// Décision en cours d'envoi — sert aussi à savoir quel bouton doit afficher
/// son indicateur de progression.
enum _Decision { aucune, approbation, refus }

class _QrLoginConfirmScreenState extends State<QrLoginConfirmScreen> {
  static const Duration _intervalleExpiration = Duration(seconds: 1);

  _Decision _enCours = _Decision.aucune;

  /// Une décision a abouti : l'écran ne peut plus rien envoyer, même si un
  /// appui tardif arrive avant la fermeture.
  bool _decidee = false;

  bool _expiree = false;
  Timer? _timerExpiration;

  @override
  void initState() {
    super.initState();
    _expiree = widget.session.isExpired;
    if (!_expiree && widget.session.expiresAt != null) {
      _timerExpiration =
          Timer.periodic(_intervalleExpiration, (_) => _verifierExpiration());
    }
  }

  @override
  void dispose() {
    _timerExpiration?.cancel();
    super.dispose();
  }

  /// Une demande morte ne doit pas rester approuvable sous les yeux de
  /// l'utilisateur : le serveur la refuserait, autant le dire avant l'appui.
  void _verifierExpiration() {
    if (!widget.session.isExpired) return;
    _timerExpiration?.cancel();
    _timerExpiration = null;
    if (!mounted || _decidee) return;
    setState(() => _expiree = true);
  }

  // ── DÉCISION ──────────────────────────────────────────────────────

  bool get _verrouille =>
      _decidee || _expiree || _enCours != _Decision.aucune;

  Future<void> _approuver() => _envoyer(_Decision.approbation);

  Future<void> _refuser() => _envoyer(_Decision.refus);

  /// Un seul appel réseau à la fois, et un seul au total : le verrou est posé
  /// avant tout `await` pour qu'un double appui ne puisse pas approuver deux
  /// fois la même session.
  Future<void> _envoyer(_Decision decision) async {
    if (_verrouille) return;
    setState(() => _enCours = decision);

    final api = Provider.of<TalkyApiClient>(context, listen: false);
    final sessionId = widget.session.sessionId;
    try {
      if (decision == _Decision.approbation) {
        await api.approveQrSession(sessionId, widget.scanSecret);
      } else {
        await api.denyQrSession(sessionId, widget.scanSecret);
      }
      if (!mounted) return;
      setState(() {
        _decidee = true;
        _enCours = _Decision.aucune;
      });
      _afficher(
        decision == _Decision.approbation
            ? context.l10n.qrApproveDone
            : context.l10n.qrApproveRejectDone,
        decision == _Decision.approbation
            ? AppColors.success
            : AppColors.brandPrimary,
      );
      Navigator.pop(context);
    } on TalkyException catch (e) {
      if (!mounted) return;
      setState(() => _enCours = _Decision.aucune);
      // 404 : session inconnue ou TTL dépassé. 409 : déjà traitée ailleurs.
      // Dans les deux cas il n'y a plus rien à décider ici.
      if (e.statusCode == 404 || e.statusCode == 409 || e.statusCode == 410) {
        setState(() => _expiree = true);
        _afficher(context.l10n.qrApproveSessionExpired, AppColors.warning);
        return;
      }
      _afficher(e.message, AppColors.error);
    } catch (e, st) {
      AppLog.e('QrLoginConfirm', 'Décision de connexion échouée', e, st);
      if (!mounted) return;
      setState(() => _enCours = _Decision.aucune);
      _afficher(context.l10n.qrLoginNetworkError, AppColors.error);
    }
  }

  void _afficher(String message, Color fond) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: fond,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── RENDU ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.qrApproveTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.qrApproveIntro,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              AppSpacing.vGapLg,
              _ficheAppareil(),
              AppSpacing.vGapXl,
              WarningBanner(message: l10n.qrApproveSecurityWarning),
              if (_expiree) ...[
                AppSpacing.vGapMd,
                WarningBanner(
                  message: l10n.qrApproveSessionExpired,
                  variant: WarningBannerVariant.info,
                ),
              ],
              AppSpacing.vGapXxl,
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ficheAppareil() {
    final l10n = context.l10n;
    final session = widget.session;

    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.semantic.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icone(session.platform),
                  color: context.colors.primary,
                  size: AppIconSize.lg,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Text(
                  session.deviceName ?? l10n.qrDevicesUnknownDevice,
                  style: context.text.titleMedium,
                ),
              ),
            ],
          ),
          AppSpacing.vGapLg,
          _ligne(l10n.qrApproveDeviceLabel,
              session.deviceName ?? l10n.qrDevicesUnknownDevice),
          if (session.platform != null)
            _ligne(l10n.qrApprovePlatformLabel, session.platform!),
          if (session.createdAt != null)
            _ligne(l10n.qrApproveRequestedLabel, _moment(session.createdAt!)),
          // Seule donnée non falsifiable de cette fiche : elle est constatée
          // par le serveur, là où le nom et la plateforme sont déclarés par
          // l'appareil demandeur. On la montre sous sa forme lisible dès que la
          // géolocalisation a abouti — « Douala, Cameroun » permet de trancher
          // d'un coup d'œil, là où une adresse brute n'apprend rien.
          if (session.location != null)
            _ligne(l10n.qrApproveLocationLabel, session.location!)
          else if (session.ipAddress != null)
            _ligne(l10n.qrApproveIpLabel, session.ipAddress!),
          AppSpacing.vGapSm,
          // Sans cet avertissement, un attaquant qui ouvre une session nommée
          // « Alanya — Vérification de sécurité » emprunterait l'autorité de
          // l'app sur l'écran même censé s'en prémunir.
          Text(
            l10n.qrApproveDeclaredNotice,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              libelle,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(valeur, style: context.text.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final l10n = context.l10n;
    final refusEnCours = _enCours == _Decision.refus;
    final approbationEnCours = _enCours == _Decision.approbation;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _verrouille ? null : _refuser,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              foregroundColor: context.colors.error,
              side: BorderSide(color: context.colors.error),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.brMd,
              ),
            ),
            child: refusEnCours
                ? const _Progression()
                : Text(l10n.qrApproveReject),
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: ElevatedButton(
            // Jamais le bouton par défaut : approuver doit être un geste visé,
            // pas la conséquence d'un appui sur « Entrée » ou d'un focus initial.
            autofocus: false,
            onPressed: _verrouille ? null : _approuver,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.brMd,
              ),
              elevation: 0,
            ),
            child: approbationEnCours
                ? const _Progression()
                : Text(l10n.qrApproveConfirm),
          ),
        ),
      ],
    );
  }

  /// Heure du jour pour une demande du jour, date complète sinon — la demande
  /// a 90 s de vie, mais l'écran peut rester ouvert plus longtemps.
  String _moment(DateTime date) {
    final locale = LocaleController.instance.resolvedLocale.toLanguageTag();
    final local = date.toLocal();
    final maintenant = DateTime.now();
    final memeJour = local.year == maintenant.year &&
        local.month == maintenant.month &&
        local.day == maintenant.day;
    return memeJour
        ? DateFormat.Hm(locale).format(local)
        : DateFormat.yMMMd(locale).add_Hm().format(local);
  }

  IconData _icone(String? plateforme) {
    final valeur = plateforme?.toLowerCase() ?? '';
    if (valeur.contains('android')) return Icons.phone_android;
    if (valeur.contains('ios')) return Icons.phone_iphone;
    if (valeur.contains('web')) return Icons.language;
    if (valeur.contains('mac') ||
        valeur.contains('windows') ||
        valeur.contains('linux')) {
      return Icons.computer;
    }
    return Icons.devices_other;
  }
}

/// Indicateur de progression aux dimensions d'un libellé de bouton.
class _Progression extends StatelessWidget {
  const _Progression();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
