import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/app_database.dart';
import '../../core/services/trip_repository.dart';
import '../../core/services/trip_session_guard.dart';
import '../../core/services/trip_socket_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'trip_visuals.dart';

/// « Trajet en cours sur votre autre appareil ».
///
/// Un seul appareil porte un trajet — `trip.owner_device` en décide côté
/// serveur, qui rejette les positions des autres. Sans cet écran, le téléphone
/// dépossédé affichait « trajet en cours », faisait tourner son service en
/// avant-plan et envoyait des positions systématiquement refusées : toute la
/// dépense, aucun des bénéfices, et pas un mot pour l'expliquer.
///
/// **La reprise est explicite dans les deux sens.** Reprendre bascule
/// `owner_device` ; l'ancien porteur reçoit `trip:device_revoked` et s'arrête de
/// lui-même. Personne ne perd le rôle sans le savoir, et personne ne le prend
/// par accident — c'est ce qui empêche deux téléphones de se le disputer à
/// chaque redémarrage, avec une trace qui saute de l'un à l'autre.
class TripOtherDeviceBanner extends StatefulWidget {
  const TripOtherDeviceBanner({super.key, required this.trip});

  final LocalTrip trip;

  @override
  State<TripOtherDeviceBanner> createState() => _TripOtherDeviceBannerState();
}

class _TripOtherDeviceBannerState extends State<TripOtherDeviceBanner> {
  static const _prefsPrefix = 'trip_other_device_dismissed_';

  StreamSubscription<int>? _cessions;
  bool _occupe = false;
  bool _masque = false;
  bool _prefsChargees = false;

  String get _prefsKey => '$_prefsPrefix${widget.trip.id}';

  @override
  void initState() {
    super.initState();
    unawaited(_chargerMasque());
    // La cession peut survenir alors que l'écran est déjà ouvert : l'autre
    // téléphone réclame le trajet pendant qu'on le regarde. Une nouvelle
    // cession annule le dismiss : la question redevient pertinente.
    _cessions = TripSessionGuard.instance.ceded.listen((id) {
      if (!mounted || id != widget.trip.id) return;
      unawaited(_oublierMasque());
    });
  }

  @override
  void dispose() {
    _cessions?.cancel();
    super.dispose();
  }

  Future<void> _chargerMasque() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _masque = prefs.getBool(_prefsKey) == true;
      _prefsChargees = true;
    });
  }

  Future<void> _masquer() async {
    setState(() => _masque = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  Future<void> _oublierMasque() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    if (!mounted) return;
    setState(() => _masque = false);
  }

  Future<void> _reprendre() async {
    if (_occupe) return;
    setState(() => _occupe = true);
    try {
      await TripSessionGuard.instance.reprendre(
        tripId: widget.trip.id,
        trips: context.read<TripRepository>(),
        socket: context.read<TripSocketService>(),
        etaAt: widget.trip.etaAt,
        kind: widget.trip.kind,
      );
      await _oublierMasque();
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsChargees ||
        _masque ||
        !TripSessionGuard.instance.cedeSur(widget.trip.id)) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final sem = context.semantic;
    // Ton informatif, pas d'alerte : rien ne va mal. La position part bien,
    // simplement depuis un autre téléphone.
    final encre = TripVisual.encre(context, sem.info);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: sem.info.withValues(alpha: 0.10),
        borderRadius: AppRadius.brSm,
        border: Border.all(color: sem.info.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phonelink_ring, size: AppIconSize.sm, color: encre),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tripsOtherDeviceTitle,
                        style: context.text.labelLarge?.copyWith(
                            color: encre, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(l10n.tripsOtherDeviceBody,
                        style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                            height: 1.35)),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                onPressed: _occupe ? null : _masquer,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close,
                    size: 18, color: context.colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Un seul CTA : « rester en lecture seule » est déjà l'état courant ;
          // un second bouton no-op sous stress n'apporte que de l'incertitude.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _occupe ? null : _reprendre,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                foregroundColor: encre,
                side: BorderSide(color: sem.info.withValues(alpha: 0.45)),
              ),
              child: Text(l10n.tripsOtherDeviceTake,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}
