import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/trip_repository.dart';
import '../../core/services/trip_session_guard.dart';
import '../../core/services/trip_socket_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../talky_api_client.dart';
import '../../widgets/trips/trip_visuals.dart';

/// Déclenchement d'un SOS.
///
/// Un simple appui démarre le compte à rebours et laisse l'utilisateur annuler
/// avant l'envoi. Le mode discret reste conservé après l'envoi pour éviter tout
/// signal visible à qui regarderait par-dessus l'épaule.
///
/// Fonctionne **sans trajet en cours** : exiger « démarrez d'abord un trajet »
/// rendrait le SOS inutile dans le seul cas où il compte.
class TripSosScreen extends StatefulWidget {
  const TripSosScreen({super.key});

  @override
  State<TripSosScreen> createState() => _TripSosScreenState();
}

enum _Phase { repos, decompte, envoi, envoye }

class _TripSosScreenState extends State<TripSosScreen> {
  static const _decompteS = 3;

  _Phase _phase = _Phase.repos;
  int _restant = _decompteS;
  Timer? _tic;

  /// Trajet créé par le SOS. Retenu pour une seule raison : permettre le
  /// démenti sans avoir à retrouver le trajet ouvert.
  int? _tripId;
  bool _dementiEnCours = false;

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  // ── Déclenchement immédiat du compte à rebours ───────────────────

  void _lancerDecompte() {
    if (_phase != _Phase.repos || !mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.decompte;
      _restant = _decompteS;
    });
    _tic = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_restant <= 1) {
        t.cancel();
        // Quitter le décompte AVANT l'appel réseau : sinon « 1 » reste affiché
        // pendant tout le RTT et Annuler reste cliquable pendant l'envoi.
        unawaited(_envoyer());
      } else {
        setState(() => _restant--);
      }
    });
  }

  void _annuler() {
    _tic?.cancel();
    setState(() {
      _phase = _Phase.repos;
      _restant = _decompteS;
    });
  }

  // ── L'envoi, puis le silence ──────────────────────────────────────

  Future<void> _envoyer() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.envoi);

    final l10n = context.l10n;
    final trips = context.read<TripRepository>();
    final socket = context.read<TripSocketService>();
    final api = context.read<TalkyApiClient>();

    try {
      final trajet = await trips.triggerSos(
        deviceId: await api.ensureStableDeviceId(),
      );
      // La position devient la donnée la plus utile de la journée : on passe en
      // cadence d'alerte immédiatement.
      await TripSessionGuard.instance.acquire(
        tripId: trajet.id,
        trips: trips,
        socket: socket,
        kind: trajet.kind,
      );
      if (!mounted) return;
      setState(() {
        _tripId = trajet.id;
        _phase = _Phase.envoye;
      });
    } on TalkyException catch (e) {
      if (!mounted) return;
      _annuler();
      _erreur(switch (e.statusCode) {
        429 => l10n.tripsSosTooMany,
        409 => l10n.tripsCircleEmptyTitle,
        _ => l10n.tripsActionFailed,
      });
    } catch (_) {
      if (!mounted) return;
      _annuler();
      _erreur(l10n.tripsActionFailed);
    }
  }

  // ── Le démenti ────────────────────────────────────────────────────

  /// « Fausse alerte, je vais bien ».
  ///
  /// Sans cette sortie, un SOS parti par erreur ne se répare qu'en allant
  /// chercher « Arrêter le partage » dans un autre écran — et le cercle lit
  /// alors « a arrêté le partage » après avoir reçu une alarme, c'est-à-dire la
  /// pire phrase possible. Ici, le démenti est à un appui et le cercle reçoit
  /// une carte qui dit exactement ce qui s'est passé.
  ///
  /// Ce qu'il ne fait **pas** : effacer l'incident. La ligne système reste dans
  /// le fil de chaque destinataire. Une alerte émise se résout, elle ne
  /// s'efface pas — et c'est aussi ce qui empêche quelqu'un de forcer
  /// l'effacement d'un SOS qu'il aurait provoqué.
  Future<void> _dementir() async {
    final id = _tripId;
    if (id == null || _dementiEnCours) return;
    setState(() => _dementiEnCours = true);

    final l10n = context.l10n;
    final trips = context.read<TripRepository>();
    try {
      await trips.declareFalseAlarm(id);
      await TripSessionGuard.instance.release();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.tripsSosFalseAlarmSent)));
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dementiEnCours = false);
      _erreur(l10n.tripsActionFailed);
    }
  }

  void _erreur(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ── Rendu ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titreDiscret =
        _phase == _Phase.envoye || _phase == _Phase.envoi;
    return Scaffold(
      appBar: AppBar(
        title: Text(titreDiscret ? l10n.trips : l10n.tripsSosTitle),
        // Pendant l'envoi, on ne quitte pas par accident le flux.
        automaticallyImplyLeading: _phase != _Phase.envoi,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: AnimatedSwitcher(
            duration: AppDurations.normal,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_phase),
              child: switch (_phase) {
                _Phase.envoye => _apresEnvoi(l10n),
                _Phase.envoi => _envoiEnCours(l10n),
                _Phase.decompte => _decompte(l10n),
                _ => _armement(l10n),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _armement(AppLocalizations l10n) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _lancerDecompte,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  radius: 1.1,
                  colors: [
                    Color.lerp(context.colors.error, Colors.white, 0.18)!,
                    context.colors.error,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.error.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'SOS',
                style: context.text.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.tripsSosHold,
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.tripsSosHoldBody,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center),
          const Spacer(),
          Text(l10n.tripsSosNotEmergency,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      );

  Widget _decompte(AppLocalizations l10n) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$_restant',
              style: context.text.displayLarge?.copyWith(
                color: TripVisual.encre(context, context.colors.error),
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.tripsSosSending(_restant),
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xxl),
          // Le plus gros élément de l'écran, délibérément.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _annuler,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                side: BorderSide(color: context.colors.outlineVariant, width: 2),
              ),
              child: Text(l10n.commonCancel,
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );

  /// Attente réseau après le décompte.
  ///
  /// Même cercle neutre que le mode discret : pas de rouge, spinner petit au
  /// centre (pas un anneau quasi plein qui « mange » le disque). Sans
  /// [Spacer] : avec `MainAxisAlignment.center`, un Spacer poussait tout en
  /// haut et laissait un vide absurde sous le texte.
  Widget _envoiEnCours(AppLocalizations l10n) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.colors.onSurfaceVariant
                          .withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.tripsSosSendingNow,
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.tripsSosSendingNowBody,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  /// Mode discret. Aucun rouge, aucune célébration : l'écran ne doit rien
  /// révéler à quelqu'un qui le regarderait par-dessus l'épaule. C'est le moment
  /// le plus dangereux du parcours.
  Widget _apresEnvoi(AppLocalizations l10n) => Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.check,
                        size: 40, color: context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.tripsSosActive,
                    style: context.text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.tripsSosActiveBody,
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // Le démenti, en bouton bordé et non en action principale : il doit
          // être trouvable immédiatement par qui s'est trompé, sans jamais
          // attirer le pouce de qui ne s'est pas trompé.
          OutlinedButton.icon(
            onPressed: _dementiEnCours ? null : _dementir,
            icon: _dementiEnCours
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: AppIconSize.sm),
            label: Text(l10n.tripsSosFalseAlarm),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonClose),
          ),
        ],
      );
}
