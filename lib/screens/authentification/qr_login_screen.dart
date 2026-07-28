import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../models/qr_models.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/alanya_qr_view.dart';
import '../home/home_screen.dart';

/// Étapes vues par l'appareil qui AFFICHE le code, c'est-à-dire celui qui n'est
/// pas encore connecté. C'est toujours l'autre appareil qui décide.
enum _EtatQr {
  creation,
  attente,
  scanne,
  refuse,
  expire,
  echecReseau,
  connexion,
}

/// Connexion d'un nouvel appareil : il affiche un code de session que l'appareil
/// déjà connecté doit scanner puis confirmer. Aucune socket ici — le statut se
/// lit par interrogation REST, décision produit assumée pour la v1 mobile.
class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  static const Duration _intervallePoll = Duration(seconds: 2);
  static const Duration _intervalleCompteARebours = Duration(seconds: 1);
  static const double _tailleQr = 216;

  QrLoginCreated? _session;
  _EtatQr _etat = _EtatQr.creation;
  Duration _restant = Duration.zero;

  Timer? _timerPoll;
  Timer? _timerCompteARebours;

  /// Empêche l'empilement des requêtes quand le réseau met plus de 2 s à répondre.
  bool _pollEnCours = false;

  /// Interrogation en vol, pour pouvoir l'attendre avant de renouveler le code :
  /// les tokens ne sont livrés qu'une fois, une réponse jetée les perd.
  Future<void>? _pollEnVol;

  /// Instant de réception de la session, origine du décompte. On ne compare
  /// jamais l'horloge de l'appareil à celle du serveur.
  DateTime? _recueA;

  /// Échec ponctuel d'interrogation : le code reste valide, on le signale sans
  /// interrompre le cycle.
  bool _reseauDegrade = false;

  /// Discrimine les réponses tardives d'une session déjà remplacée (expiration
  /// pendant qu'une création ou une interrogation était en vol).
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _creerSession();
  }

  @override
  void dispose() {
    _arreterTimers();
    super.dispose();
  }

  void _arreterTimers() {
    _timerPoll?.cancel();
    _timerPoll = null;
    _timerCompteARebours?.cancel();
    _timerCompteARebours = null;
  }

  // ── CYCLE DE VIE DE LA SESSION ────────────────────────────────────

  /// Ouvre une session côté serveur et démarre les deux horloges.
  /// [apresExpiration] distingue la régénération automatique d'un premier appel,
  /// pour choisir le message d'échec.
  Future<void> _creerSession({bool apresExpiration = false}) async {
    _arreterTimers();
    // Sans cette remise à zéro, le drapeau reste armé jusqu'au timeout de la
    // requête abandonnée (15 s) et tous les polls de la nouvelle session
    // sortent immédiatement : une approbation faite pendant cette fenêtre
    // passerait inaperçue.
    _pollEnCours = false;
    _pollEnVol = null;
    final generation = ++_generation;
    setState(() {
      _etat = _EtatQr.creation;
      _reseauDegrade = false;
      _session = null;
      _recueA = null;
      _restant = Duration.zero;
    });

    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final session = await api.createQrSession(
        deviceId: await TalkyApiClient.currentHardwareId(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _session = session;
        _recueA = DateTime.now();
        _etat = _EtatQr.attente;
        _restant = _dureeRestante(session);
      });
      _demarrerTimers();
    } catch (e, st) {
      AppLog.e('QrLogin', 'Création de session QR échouée', e, st);
      if (!mounted || generation != _generation) return;
      setState(() {
        _etat = apresExpiration ? _EtatQr.expire : _EtatQr.echecReseau;
      });
    }
  }

  void _demarrerTimers() {
    _timerCompteARebours =
        Timer.periodic(_intervalleCompteARebours, (_) => _tick());
    _timerPoll = Timer.periodic(_intervallePoll, (_) => _interroger());
  }

  /// Temps restant mesuré depuis la RÉCEPTION de la session, jamais par
  /// comparaison d'horloges : une horloge d'appareil en avance de plus de 90 s
  /// rendrait autrement le code expiré dès son affichage, et le ferait
  /// régénérer en boucle sans jamais devenir scannable.
  Duration _dureeRestante(QrLoginCreated session) {
    final origine = _recueA;
    if (origine == null) return session.ttl;
    final restant = session.ttl - DateTime.now().difference(origine);
    return restant.isNegative ? Duration.zero : restant;
  }

  Future<void> _tick() async {
    final session = _session;
    if (session == null) return;
    final restant = _dureeRestante(session);
    if (restant > Duration.zero) {
      setState(() => _restant = restant);
      return;
    }

    // Un code mort ne doit jamais rester sous les yeux de l'utilisateur — mais
    // on ne renouvelle pas avant d'avoir laissé retomber l'interrogation en
    // vol. Une approbation survenue dans la dernière seconde y est peut-être
    // déjà, et les tokens ne sont livrés qu'une seule fois : les jeter au
    // motif que la génération a changé les perdrait définitivement.
    _arreterTimers();
    final generation = _generation;
    await _pollEnVol;
    if (!mounted || generation != _generation) return;
    await _interroger();
    if (!mounted || generation != _generation) return;

    // Le dernier poll a pu conclure (approuvé, refusé, connexion en cours) :
    // dans ce cas il a déjà changé d'état et il n'y a rien à renouveler.
    if (_etat == _EtatQr.attente || _etat == _EtatQr.scanne) {
      await _creerSession(apresExpiration: true);
    }
  }

  /// Lance une interrogation, ou rend celle déjà en vol — jamais deux à la fois.
  Future<void> _interroger() {
    final session = _session;
    if (session == null) return Future<void>.value();
    if (_pollEnCours) return _pollEnVol ?? Future<void>.value();
    _pollEnCours = true;
    final futur = _executerInterrogation(session, _generation);
    _pollEnVol = futur;
    return futur;
  }

  Future<void> _executerInterrogation(QrLoginCreated session, int generation) async {
    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final resultat = await api.pollQrSession(session.sessionId, session.pollToken);
      if (!mounted || generation != _generation) return;

      if (_reseauDegrade) setState(() => _reseauDegrade = false);

      if (resultat.isApproved && resultat.hasTokens) {
        await _finaliserConnexion(resultat);
        return;
      }
      if (resultat.isDenied) {
        _arreterTimers();
        setState(() => _etat = _EtatQr.refuse);
        return;
      }
      // Session disparue : le serveur répond 200 { status: 'expired' }, pas un
      // 404. Sans cette branche l'écran interrogerait un code mort jusqu'à ce
      // que le compte à rebours local le rattrape.
      if (resultat.isExpired) {
        await _creerSession(apresExpiration: true);
        return;
      }
      if (resultat.isScanned && _etat != _EtatQr.scanne) {
        setState(() => _etat = _EtatQr.scanne);
      }
    } on TalkyException catch (e) {
      if (!mounted || generation != _generation) return;
      // 404 : la session n'existe plus côté serveur (TTL dépassé), on en ouvre
      // une nouvelle plutôt que d'afficher un code sans interlocuteur.
      if (e.statusCode == 404 || e.statusCode == 410) {
        await _creerSession(apresExpiration: true);
        return;
      }
      setState(() => _reseauDegrade = true);
    } catch (e, st) {
      AppLog.w('QrLogin', 'Interrogation de session QR échouée', e, st);
      if (!mounted || generation != _generation) return;
      setState(() => _reseauDegrade = true);
    } finally {
      _pollEnCours = false;
    }
  }

  /// Les tokens ne sont livrés qu'une seule fois : on arrête tout et on les
  /// consomme immédiatement.
  Future<void> _finaliserConnexion(QrLoginPollResult resultat) async {
    _arreterTimers();
    setState(() => _etat = _EtatQr.connexion);

    final auth = context.read<AuthProvider>();
    await auth.loginWithQrTokens(
      accessToken: resultat.accessToken!,
      refreshToken: resultat.refreshToken!,
    );
    if (!mounted) return;

    if (auth.isLoggedIn) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    // Session perdue alors que les tokens étaient à usage unique : il faut
    // repartir d'un nouveau code.
    setState(() => _etat = _EtatQr.echecReseau);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.error ?? context.l10n.qrLoginNetworkError),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── RENDU ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.qrLoginTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.qrLoginExplanation,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              AppSpacing.vGapXxl,
              Center(child: _cadreQr()),
              AppSpacing.vGapXl,
              Center(child: _pilluleStatut()),
              if ((_etat == _EtatQr.attente || _etat == _EtatQr.scanne) &&
                  _session?.expiresAt != null) ...[
                AppSpacing.vGapSm,
                Center(
                  child: Text(
                    context.l10n.qrLoginExpiresIn(_formaterRestant(_restant)),
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ),
              ],
              if (_reseauDegrade) ...[
                AppSpacing.vGapSm,
                Center(
                  child: Text(
                    context.l10n.qrLoginNetworkError,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.error),
                  ),
                ),
              ],
              AppSpacing.vGapXxl,
              if (_peutRegenerer)
                ElevatedButton(
                  onPressed: () => _creerSession(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.brMd),
                    elevation: 0,
                  ),
                  child: Text(
                    context.l10n.qrLoginRegenerate,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              AppSpacing.vGapSm,
              TextButton(
                onPressed: _etat == _EtatQr.connexion
                    ? null
                    : () => Navigator.pop(context),
                child: Text(context.l10n.qrLoginUsePassword),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _peutRegenerer =>
      _etat == _EtatQr.refuse ||
      _etat == _EtatQr.expire ||
      _etat == _EtatQr.echecReseau;

  Widget _cadreQr() {
    final session = _session;
    final afficheQr = session != null && !_peutRegenerer;
    final cote = _tailleQr + AppSpacing.xxl;

    return Container(
      width: cote,
      height: cote,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Fond blanc même en thème sombre : les lecteurs de QR attendent des
        // modules foncés sur fond clair, l'inverse n'est pas fiable.
        color: AppColors.white,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.subtle,
      ),
      child: afficheQr
          ? AlanyaQrView(payload: session.payload, size: _tailleQr)
          : _etat == _EtatQr.creation || _etat == _EtatQr.connexion
              ? const CircularProgressIndicator(
                  color: AppColors.brandPrimary,
                )
              : const Icon(
                  Icons.qr_code_2_rounded,
                  size: 96,
                  color: AppColors.textTertiary,
                ),
    );
  }

  Widget _pilluleStatut() {
    final (String libelle, Color teinte) = switch (_etat) {
      _EtatQr.creation => (context.l10n.qrLoginStatusWaiting, AppColors.textSecondary),
      _EtatQr.attente => (context.l10n.qrLoginStatusWaiting, AppColors.textSecondary),
      _EtatQr.scanne => (context.l10n.qrLoginStatusScanned, AppColors.brandPrimary),
      _EtatQr.connexion => (context.l10n.qrLoginStatusScanned, AppColors.brandPrimary),
      _EtatQr.refuse => (context.l10n.qrLoginStatusRejected, AppColors.error),
      _EtatQr.expire => (context.l10n.qrLoginStatusExpired, AppColors.warning),
      _EtatQr.echecReseau => (context.l10n.qrLoginNetworkError, AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: teinte.withValues(alpha: 0.10),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: teinte, shape: BoxShape.circle),
          ),
          AppSpacing.hGapSm,
          Flexible(
            child: Text(
              libelle,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium
                  ?.copyWith(color: teinte, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Compte à rebours en mm:ss — neutre pour toutes les langues, contrairement
  /// à des unités écrites en dur.
  String _formaterRestant(Duration restant) {
    final secondes = restant.inSeconds.clamp(0, 5999);
    final minutes = (secondes ~/ 60).toString().padLeft(2, '0');
    final reste = (secondes % 60).toString().padLeft(2, '0');
    return '$minutes:$reste';
  }
}
