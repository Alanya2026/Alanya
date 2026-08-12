import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/default_contact_lists.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/services/trip_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/contact_list_colors.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/trips/trip_visuals.dart';
import '../profile/contact_list_detail_screen.dart';
import 'trip_compose_screen.dart';
import 'trip_live_screen.dart';
import 'trip_sos_screen.dart';
import 'trips_history_screen.dart';

/// Accueil des trajets de confiance : le cercle, le trajet en cours s'il y en
/// a un, et le point de départ d'un nouveau.
///
/// Trois états, dans cet ordre de priorité :
///   1. un trajet est ouvert → on le montre, on n'en propose pas un second ;
///   2. le cercle est vide → écran d'amorçage, qui renvoie vers la liste ;
///   3. le cercle est prêt → on peut partir.
///
/// L'écran s'ouvre sur le cercle et non sur les boutons de départ, et ce n'est
/// pas un choix de mise en page : **le cercle est la promesse**. Voir les
/// visages avant de voir « Taxi » rappelle à qui l'on s'apprête à confier son
/// trajet — c'est la question qu'on doit se poser en dernier avant de partir,
/// pas celle qu'on doit aller chercher dans un écran de réglages.
class TripsHubScreen extends StatefulWidget {
  const TripsHubScreen({super.key});

  @override
  State<TripsHubScreen> createState() => _TripsHubScreenState();
}

class _TripsHubScreenState extends State<TripsHubScreen> {
  /// Évite de relancer la synchro des membres à chaque reconstruction du flux.
  int? _membresSynchronises;

  @override
  void initState() {
    super.initState();
    final trips = context.read<TripRepository>();
    final cache = context.read<LocalCacheRepository>();
    unawaited(trips.syncActiveTrips());
    // Filet : aucun trajet suivi et clos ne doit traîner dans le cache, même
    // après un plantage en plein trajet.
    unawaited(trips.pruneClosedWatched());
    // Le cercle vient des listes de contacts : sans cette synchro, l'écran
    // d'amorçage s'afficherait à tort au premier lancement.
    unawaited(cache.syncContactLists());
  }

  Future<void> _openTrustList(LocalContactList? liste) async {
    if (liste == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactListDetailScreen(
          idList: liste.idList,
          initialName: liste.name,
        ),
      ),
    );
    if (!mounted) return;
    unawaited(context.read<LocalCacheRepository>().syncContactLists());
  }

  Future<void> _compose(String kind) async {
    final demarre = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TripComposeScreen(kind: kind)),
    );
    if (demarre == true && mounted) {
      unawaited(context.read<TripRepository>().syncActiveTrips());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trips = context.read<TripRepository>();
    final cache = context.read<LocalCacheRepository>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trips),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.tripsHistory,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TripsHistoryScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<LocalTrip?>(
        stream: trips.watchMyOpenTrip(),
        builder: (context, snapTrip) {
          final enCours = snapTrip.data;

          return StreamBuilder<List<LocalContactList>>(
            stream: cache.watchContactLists(),
            builder: (context, snapListes) {
              final trust = _trustList(snapListes.data);
              final membres = trust?.memberCount ?? 0;

              // Les visages ne sont pas décoratifs : ils remplacent « 5 / 5 »
              // par une réponse à « qui, exactement ». On les charge donc
              // vraiment, une fois par ouverture d'écran.
              if (trust != null && _membresSynchronises != trust.idList) {
                _membresSynchronises = trust.idList;
                unawaited(cache.syncListMembers(trust.idList));
              }

              // Le cercle vide est bloquant, mais utile : il renvoie là où on
              // le remplit plutôt que de se contenter de refuser.
              if (enCours == null && membres == 0) {
                return _amorcage(l10n, trust);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    0, AppSpacing.sm, 0, AppSpacing.xxxl),
                children: [
                  _carteCercle(l10n, cache, trust, membres),
                  if (enCours != null)
                    _carteTrajet(l10n, enCours)
                  else ...[
                    _entete(l10n.tripsNew, l10n.tripsNone),
                    _carteType(
                      Icons.local_taxi_rounded,
                      l10n.tripsKindTaxi,
                      l10n.tripsKindTaxiHint,
                      TripKind.taxi,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _carteType(
                      Icons.place_rounded,
                      l10n.tripsKindMeeting,
                      l10n.tripsKindMeetingHint,
                      TripKind.meeting,
                    ),
                  ],
                  // Le SOS est atteignable SANS trajet en cours : le danger
                  // n'attend pas un trajet planifié, et l'exiger rendrait le
                  // bouton inutile dans le seul cas où il compte.
                  if (membres > 0) _boutonSos(l10n),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Ossature ──────────────────────────────────────────────────────

  Widget _entete(String titre, String sous) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre.toUpperCase(),
              style: context.text.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sous,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      );

  /// Conteneur commun des trois cartes de l'écran. Une seule définition : trois
  /// rayons différents sur un même écran se voient, même sans savoir pourquoi.
  Widget _coque({
    required Widget child,
    VoidCallback? onTap,
    Color? bordure,
    double bordureEpaisseur = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Material(
          color: context.colors.surface,
          borderRadius: AppRadius.brMd,
          child: InkWell(
            borderRadius: AppRadius.brMd,
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: AppRadius.brMd,
                border: Border.all(
                  color: bordure ?? context.colors.outlineVariant,
                  width: bordureEpaisseur,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ),
          ),
        ),
      );

  // ── Le cercle ─────────────────────────────────────────────────────

  Widget _carteCercle(dynamic l10n, LocalCacheRepository cache,
      LocalContactList? trust, int membres) {
    final teinte =
        parseListColor(trust?.color) ?? parseListColor(kContactListColors[3])!;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: _coque(
        onTap: () => _openTrustList(trust),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: teinte,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 21),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tripsMyCircle,
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$membres / $kTrustMemberLimit',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: AppIconSize.sm, color: context.colors.onSurfaceVariant),
              ],
            ),
            if (trust != null && membres > 0)
              _visages(cache, trust.idList, teinte),
          ],
        ),
      ),
    );
  }

  /// Les visages du cercle, et leurs prénoms en clair dessous.
  ///
  /// Les deux ensemble, pas l'un ou l'autre : une pile d'avatars est jolie et
  /// illisible pour qui n'a pas mis de photo, une liste de prénoms se lit mais
  /// ne se reconnaît pas d'un coup d'œil.
  Widget _visages(LocalCacheRepository cache, int idList, Color teinte) {
    return StreamBuilder<List<User>>(
      stream: cache.watchListMembers(idList),
      builder: (context, snap) {
        final gens = snap.data ?? const <User>[];
        if (gens.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 32,
                child: Stack(
                  children: [
                    for (var i = 0; i < gens.length && i < 5; i++)
                      Positioned(
                        // 22 px de pas pour 32 de diamètre : les avatars se
                        // chevauchent d'un tiers, assez pour lire une pile,
                        // assez peu pour distinguer chaque visage.
                        left: i * 22.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.colors.surface, width: 2),
                          ),
                          child: AppAvatar(
                            imageUrl: gens[i].avatarUrl,
                            name: gens[i].nom,
                            size: 32,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                gens.map((u) => _prenom(u.nom)).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _prenom(String nom) {
    final t = nom.trim();
    if (t.isEmpty) return t;
    final espace = t.indexOf(' ');
    return espace <= 0 ? t : t.substring(0, espace);
  }

  // ── Départ ────────────────────────────────────────────────────────

  Widget _carteType(IconData icone, String titre, String sous, String kind) {
    return _coque(
      onTap: () => _compose(kind),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.semantic.brandContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icone, color: context.colors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(sous,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded,
              size: AppIconSize.sm, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _boutonSos(dynamic l10n) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg, AppSpacing.sm),
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripSosScreen()),
              ),
              icon: Icon(Icons.warning_amber_rounded,
                  color: context.colors.error),
              label: Text(
                l10n.tripsSosButton,
                style: TextStyle(
                    color: context.colors.error, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                side:
                    BorderSide(color: context.colors.error.withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Dire ce que le SOS ne fait pas vaut mieux qu'une promesse
            // implicite qu'on ne tiendrait pas.
            Text(
              l10n.tripsSosNotEmergency,
              textAlign: TextAlign.center,
              style:
                  context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      );

  LocalContactList? _trustList(List<LocalContactList>? listes) {
    if (listes == null) return null;
    for (final l in listes) {
      if (l.kind == ContactListKind.trust) return l;
    }
    return null;
  }

  Widget _amorcage(dynamic l10n, LocalContactList? trust) {
    return EmptyState(
      icon: Icons.group_outlined,
      title: l10n.tripsCircleEmptyTitle,
      message: l10n.tripsCircleEmptyBody,
      action: FilledButton.icon(
        onPressed: () => _openTrustList(trust),
        icon: const Icon(Icons.add),
        label: Text(l10n.tripsComposeCircle),
      ),
    );
  }

  // ── Le trajet ouvert ──────────────────────────────────────────────

  /// Le trajet ouvert prend toute la largeur et porte sa couleur : c'est la
  /// seule chose de l'écran qui demande une action, elle ne se range pas dans
  /// une liste avec les autres.
  Widget _carteTrajet(dynamic l10n, LocalTrip t) {
    final v = TripVisual.resolve(context, state: t.state, stale: t.stale);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: _coque(
        bordure: v.color.withValues(alpha: 0.45),
        bordureEpaisseur: 1.5,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripLiveScreen(tripId: t.id, isOwner: true),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TripCrest(visual: v, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TripPulse(color: v.ink, size: 7, animate: v.pulses),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              v.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: v.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        t.destLabel ?? l10n.tripsInProgress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    size: AppIconSize.sm, color: v.ink),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (t.etaAt != null)
                  TripFactChip(
                    icon: Icons.schedule,
                    label: l10n.tripsEtaAt(TripFormat.hhmm(t.etaAt!)),
                    tint: v.tone == TripTone.awaiting ? v.ink : null,
                  ),
                TripFactChip(
                  icon: Icons.group_outlined,
                  label: l10n.tripsWatcherCount(t.watcherCount),
                ),
                if (t.lastAt != null)
                  TripFactChip(
                    icon: Icons.my_location,
                    label: TripFormat.depuis(t.lastAt!),
                    // Une position ancienne est l'information : elle prend la
                    // couleur de l'état plutôt que de se fondre dans le gris.
                    tint: t.stale ? v.ink : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
