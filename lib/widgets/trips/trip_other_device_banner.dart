import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  StreamSubscription<int>? _cessions;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    // La cession peut survenir alors que l'écran est déjà ouvert : l'autre
    // téléphone réclame le trajet pendant qu'on le regarde.
    _cessions = TripSessionGuard.instance.ceded.listen((id) {
      if (mounted && id == widget.trip.id) setState(() {});
    });
  }

  @override
  void dispose() {
    _cessions?.cancel();
    super.dispose();
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
      );
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!TripSessionGuard.instance.cedeSur(widget.trip.id)) {
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
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
              const SizedBox(width: AppSpacing.sm),
              // « Rester en lecture seule » n'est pas un bouton d'action : c'est
              // déjà l'état courant. Il ne fait que refermer la question.
              Expanded(
                child: TextButton(
                  onPressed: _occupe ? null : () => setState(() {}),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                  ),
                  child: Text(l10n.tripsOtherDeviceKeep,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
