import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/trip_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/trips/trip_visuals.dart';

/// Historique des trajets — **du propriétaire uniquement**.
///
/// Un membre du cercle n'a pas d'historique : il n'existe aucun écran pour
/// consulter « tous les trajets passés d'untel ». C'est ce qui empêche la
/// fonctionnalité de devenir un outil de contrôle a posteriori, et c'est aussi
/// pour cela que la liste se lit en ligne plutôt que depuis le cache — garder
/// ces trajets localement ferait de l'appareil un registre de déplacements.
class TripsHistoryScreen extends StatefulWidget {
  const TripsHistoryScreen({super.key});

  @override
  State<TripsHistoryScreen> createState() => _TripsHistoryScreenState();
}

class _TripsHistoryScreenState extends State<TripsHistoryScreen> {
  final _trajets = <Trip>[];
  int? _curseur;
  bool _charge = true;
  bool _fini = false;
  Object? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger({bool suite = false}) async {
    if (!suite) setState(() { _charge = true; _erreur = null; });
    try {
      final page = await context
          .read<TripRepository>()
          .loadHistory(cursor: suite ? _curseur : null);
      if (!mounted) return;
      setState(() {
        if (!suite) _trajets.clear();
        _trajets.addAll(page.trips);
        _curseur = page.nextCursor;
        _fini = page.nextCursor == null;
        _charge = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _erreur = e; _charge = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripsHistory)),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: _corps(l10n),
      ),
    );
  }

  Widget _corps(dynamic l10n) {
    if (_charge && _trajets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null && _trajets.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: l10n.tripsHistoryUnavailable,
        message: l10n.tripsHistoryOnline,
        action: FilledButton(
          onPressed: _charger,
          child: Text(l10n.retry),
        ),
      );
    }
    if (_trajets.isEmpty) {
      // L'état vide explique la fonctionnalité plutôt que de constater le vide.
      return ListView(
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.shield_outlined,
            title: l10n.tripsHistoryEmpty,
            message: l10n.tripsHistoryEmptyBody,
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: _trajets.length + (_fini ? 1 : 2),
      // Filet en retrait, aligné sur le texte : à pleine largeur il découpait
      // la liste en tranches au lieu de séparer des lignes.
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: AppSpacing.lg + 40 + AppSpacing.md,
        endIndent: AppSpacing.lg,
        color: context.colors.outlineVariant,
      ),
      itemBuilder: (context, i) {
        if (i == _trajets.length) {
          return _fini
              ? _mentionRetention(l10n)
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: TextButton(
                      onPressed: () => _charger(suite: true),
                      child: Text(l10n.loadMore),
                    ),
                  ),
                );
        }
        if (i > _trajets.length) return _mentionRetention(l10n);
        return _ligne(l10n, _trajets[i]);
      },
    );
  }

  /// La rétention est écrite dans l'écran, pas seulement dans les réglages :
  /// c'est ici qu'on se demande pourquoi un vieux trajet a disparu.
  Widget _mentionRetention(dynamic l10n) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(l10n.tripsRetentionNote,
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant)),
      );

  /// Une ligne d'historique. L'issue se lit à l'écusson avant de lire le texte,
  /// et les faits — durée, destinataires — sont en puces plutôt qu'en phrase :
  /// on parcourt cette liste du regard, on ne la lit pas.
  Widget _ligne(dynamic l10n, Trip t) {
    // Un trajet expiré a réveillé le cercle : ici, chez son propriétaire, cela
    // doit rester visible. C'est l'inverse du choix fait dans la conversation
    // d'un membre, où un trajet clos est clos.
    final v = TripVisual.resolve(
      context,
      state: t.state,
      alerte: t.alertedAt != null || t.state == TripState.closedExpired,
    );
    final duree = t.closedAt?.difference(t.startedAt).inMinutes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TripCrest(visual: v, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.destLabel ?? v.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  // La date reste en clair : c'est la clé de lecture d'un
                  // historique, elle ne se met pas en puce avec le reste.
                  '${_dateCourte(t.startedAt)} · ${v.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: v.tone == TripTone.alerted
                        ? v.ink
                        : context.colors.onSurfaceVariant,
                    fontWeight: v.tone == TripTone.alerted
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (duree != null)
                      TripFactChip(
                        icon: Icons.timelapse,
                        label: l10n.tripsMinutes(duree),
                        dense: true,
                      ),
                    TripFactChip(
                      icon: Icons.group_outlined,
                      label: l10n.tripsWatcherCount(t.watcherCount),
                      dense: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            iconSize: AppIconSize.sm,
            color: context.colors.onSurfaceVariant,
            tooltip: l10n.commonDelete,
            onPressed: () => _supprimer(l10n, t),
          ),
        ],
      ),
    );
  }

  /// La suppression échoue volontairement sur un trajet clos par une alerte,
  /// pendant trente jours. Ce n'est pas un bug : c'est une mesure
  /// anti-coercition, et le message doit l'expliquer plutôt que la faire subir.
  Future<void> _supprimer(dynamic l10n, Trip t) async {
    // Action irréversible : on demande. C'est l'inverse d'« Arrêter le
    // partage », qui reste sans confirmation — là, le moindre frein rendrait
    // l'arrêt coûteux, donc punissable par quelqu'un qui regarde.
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.tripsDeleteTitle),
        content: Text(l10n.tripsDeleteBody),
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
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<TripRepository>().deleteTrip(t.id);
      if (!mounted) return;
      setState(() => _trajets.removeWhere((x) => x.id == t.id));
    } on TalkyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.statusCode == 423
            ? l10n.tripsDeleteLocked
            : l10n.tripsActionFailed),
      ));
    }
  }

  String _dateCourte(DateTime d) =>
      '${d.day}/${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
