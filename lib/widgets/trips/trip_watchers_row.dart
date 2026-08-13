import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/trip_repository.dart';
import '../../core/services/trip_socket_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_models.dart';
import '../common/common.dart';

/// Les destinataires d'un trajet, vus par la personne suivie.
///
/// Elle répond à la seule question que se pose quelqu'un qui vient de partager
/// sa position : **est-ce que quelqu'un regarde ?**
///
/// « Maman a vu » est le seul retour qu'un membre du cercle puisse donner — il
/// ne peut ni clore le trajet, ni consulter l'historique. Le serveur l'émettait
/// déjà (`trip:watcher_seen`) et personne ne l'écoutait : la personne suivie
/// n'avait aucun moyen de savoir si elle partageait dans le vide.
///
/// C'est aussi d'ici que l'on **révoque** un destinataire. Le cercle est figé au
/// départ : retirer quelqu'un de sa liste Confiance ne le sort pas d'un trajet
/// déjà lancé. Ce geste est le seul qui le fasse, et il vit là où l'on voit qui
/// regarde — pas dans un écran de réglages qu'on n'ouvrira pas en chemin.
class TripWatchersRow extends StatefulWidget {
  const TripWatchersRow({super.key, required this.tripId});

  final int tripId;

  @override
  State<TripWatchersRow> createState() => _TripWatchersRowState();
}

class _TripWatchersRowState extends State<TripWatchersRow> {
  List<TripWatcher> _destinataires = const [];
  StreamSubscription<({int tripId, int alanyaID})>? _vus;
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());

    // Le flux temps réel évite de re-interroger le réseau à chaque accusé : un
    // membre qui ouvre la carte doit apparaître « vu » immédiatement, sans que
    // la personne suivie ait à rafraîchir quoi que ce soit.
    _vus = context.read<TripSocketService>().watcherSeen.listen((e) {
      if (!mounted || e.tripId != widget.tripId) return;
      setState(() {
        _destinataires = [
          for (final w in _destinataires)
            if (w.alanyaID == e.alanyaID && w.seenAt == null)
              TripWatcher(
                alanyaID: w.alanyaID,
                nom: w.nom,
                avatarUrl: w.avatarUrl,
                seenAt: DateTime.now(),
              )
            else
              w,
        ];
      });
    });
  }

  @override
  void dispose() {
    _vus?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    final liste = await context.read<TripRepository>().loadWatchers(widget.tripId);
    if (mounted) setState(() => _destinataires = liste);
  }

  /// Retirer quelqu'un est irréversible et se voit : on demande.
  ///
  /// C'est l'inverse d'« Arrêter le partage », qui reste sans confirmation. Là,
  /// le moindre frein rendrait l'arrêt coûteux donc punissable ; ici, un
  /// retrait accidentel ferait perdre un témoin sans que personne ne s'en
  /// aperçoive.
  Future<void> _revoquer(TripWatcher w) async {
    if (_occupe) return;
    final l10n = context.l10n;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.tripsRevokeTitle(w.nom)),
        content: Text(l10n.tripsRevokeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(c).colorScheme.error,
            ),
            child: Text(l10n.tripsRevokeAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _occupe = true);
    try {
      await context.read<TripRepository>().revokeWatcher(widget.tripId, w.alanyaID);
      if (!mounted) return;
      setState(() {
        _destinataires =
            _destinataires.where((x) => x.alanyaID != w.alanyaID).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.tripsActionFailed)));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_destinataires.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final vus = _destinataires.where((w) => w.seenAt != null).length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // « 2 sur 5 ont vu » plutôt que « 5 personnes suivent » : le nombre
            // de destinataires est une promesse, le nombre de vus est un fait.
            vus == 0
                ? l10n.tripsWatchersNoneSeen
                : l10n.tripsWatchersSeenCount(vus, _destinataires.length),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _destinataires.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) => _visage(_destinataires[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visage(TripWatcher w) {
    final vu = w.seenAt != null;
    final sem = context.semantic;

    return Semantics(
      label: vu ? '${w.nom} — ${context.l10n.tripsWatcherSeen}' : w.nom,
      child: GestureDetector(
        // Appui long, pas un bouton : révoquer doit être atteignable sans être
        // à portée de pouce distrait pendant un trajet.
        onLongPress: _occupe ? null : () => _revoquer(w),
        child: SizedBox(
          width: 44,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    // Pas encore vu : atténué, sans être barré. Ne pas avoir
                    // ouvert la carte n'est pas un manquement.
                    opacity: vu ? 1 : 0.45,
                    child: AppAvatar(
                      imageUrl: w.avatarUrl,
                      name: w.nom,
                      size: 34,
                    ),
                  ),
                  if (vu)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: sem.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: context.colors.surface, width: 1.5),
                        ),
                        padding: const EdgeInsets.all(1.5),
                        child: Icon(Icons.check,
                            size: 9, color: sem.onSuccess),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _prenom(w.nom),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  fontSize: 9.5,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _prenom(String nom) {
    final t = nom.trim();
    final espace = t.indexOf(' ');
    return espace <= 0 ? t : t.substring(0, espace);
  }
}
