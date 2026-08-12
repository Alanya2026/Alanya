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
/// **Deux gestes pour partir, puis le silence.** Un bouton d'alarme qui se
/// déclenche en poche détruit la confiance du cercle en une fois ; un bouton
/// qui célèbre son envoi met en danger la personne qu'il devait protéger.
///
///  1. **maintien de 3 secondes** — une poche ne maintient pas ;
///  2. **décompte annulable de 5 secondes**, où « Annuler » est le plus gros
///     élément de l'écran ;
///  3. **mode discret** après l'envoi : aucun son, aucune vibration, un écran
///     qui ne dit rien à quelqu'un qui regarderait par-dessus l'épaule.
///
/// Fonctionne **sans trajet en cours** : exiger « démarrez d'abord un trajet »
/// rendrait le SOS inutile dans le seul cas où il compte.
class TripSosScreen extends StatefulWidget {
  const TripSosScreen({super.key});

  @override
  State<TripSosScreen> createState() => _TripSosScreenState();
}

enum _Phase { repos, maintien, decompte, envoye }

class _TripSosScreenState extends State<TripSosScreen>
    with SingleTickerProviderStateMixin {
  // 1,5 s de maintien puis 3 s de décompte, soit 4,5 s au lieu de 8.
  //
  // Le compromis reste tenu : une poche ne maintient pas un appui 1,5 s, et
  // « Annuler » — le plus gros élément de l'écran — reste largement atteignable
  // en 3 s. On raccourcit l'attente sans supprimer les deux gestes qui
  // protègent le cercle des fausses alertes.
  static const _maintien = Duration(milliseconds: 1500);
  static const _decompteS = 3;

  late final AnimationController _anneau =
      AnimationController(vsync: this, duration: _maintien)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _lancerDecompte();
        });

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
    _anneau.dispose();
    super.dispose();
  }

  // ── Geste 1 : le maintien ─────────────────────────────────────────

  void _debutAppui() {
    if (_phase != _Phase.repos) return;
    setState(() => _phase = _Phase.maintien);
    // Retour haptique : on doit sentir que le maintien a pris, sans regarder.
    HapticFeedback.mediumImpact();
    _anneau.forward(from: 0);
  }

  void _finAppui() {
    if (_phase != _Phase.maintien) return;
    _anneau.stop();
    _anneau.reset();
    setState(() => _phase = _Phase.repos);
  }

  // ── Geste 2 : le décompte ─────────────────────────────────────────

  void _lancerDecompte() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.decompte;
      _restant = _decompteS;
    });
    _tic = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_restant <= 1) {
        t.cancel();
        unawaited(_envoyer());
      } else {
        setState(() => _restant--);
      }
    });
  }

  void _annuler() {
    _tic?.cancel();
    _anneau.reset();
    setState(() {
      _phase = _Phase.repos;
      _restant = _decompteS;
    });
  }

  // ── L'envoi, puis le silence ──────────────────────────────────────

  Future<void> _envoyer() async {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_phase == _Phase.envoye ? l10n.trips : l10n.tripsSosTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: switch (_phase) {
            _Phase.envoye => _apresEnvoi(l10n),
            _Phase.decompte => _decompte(l10n),
            _ => _armement(l10n),
          },
        ),
      ),
    );
  }

  Widget _armement(AppLocalizations l10n) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTapDown: (_) => _debutAppui(),
            onTapUp: (_) => _finAppui(),
            onTapCancel: _finAppui,
            child: SizedBox(
              width: 176,
              height: 176,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // L'anneau montre la progression du maintien : on doit voir
                  // que ça part, et pouvoir relâcher avant.
                  SizedBox(
                    width: 172,
                    height: 172,
                    child: AnimatedBuilder(
                      animation: _anneau,
                      builder: (_, __) => CircularProgressIndicator(
                        value: _anneau.value,
                        strokeWidth: 4,
                        backgroundColor:
                            context.colors.error.withValues(alpha: 0.18),
                        color: context.colors.error,
                      ),
                    ),
                  ),
                  // Le bouton s'enfonce sous le doigt et son halo se resserre :
                  // le maintien doit se sentir aussi bien qu'il se voit, parce
                  // qu'on peut avoir à l'armer sans regarder l'écran.
                  AnimatedScale(
                    scale: _phase == _Phase.maintien ? 0.94 : 1,
                    duration: AppDurations.fast,
                    child: Container(
                      width: 148,
                      height: 148,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.4),
                          radius: 1.1,
                          colors: [
                            Color.lerp(
                                context.colors.error, Colors.white, 0.18)!,
                            context.colors.error,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.error.withValues(
                                alpha: _phase == _Phase.maintien ? 0.55 : 0.35),
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
                ],
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
          // Dire ce que le SOS ne fait pas vaut mieux qu'une promesse implicite
          // qu'on ne tient pas.
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

  /// Mode discret. Aucun rouge, aucune célébration : l'écran ne doit rien
  /// révéler à quelqu'un qui le regarderait par-dessus l'épaule. C'est le moment
  /// le plus dangereux du parcours.
  Widget _apresEnvoi(AppLocalizations l10n) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check, size: 40, color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.tripsSosSent,
              style: context.text.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.tripsSosDiscreet,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
              textAlign: TextAlign.center),
          const Spacer(),
          // Le démenti, en bouton bordé et non en action principale : il doit
          // être trouvable immédiatement par qui s'est trompé, sans jamais
          // attirer le pouce de qui ne s'est pas trompé.
          OutlinedButton.icon(
            onPressed: _dementiEnCours ? null : _dementir,
            icon: _dementiEnCours
                ? const SizedBox(
                    width: 16, height: 16,
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
