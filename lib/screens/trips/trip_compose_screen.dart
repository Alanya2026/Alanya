import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/default_contact_lists.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/services/trip_repository.dart';
import '../../core/services/trip_session_guard.dart';
import '../../core/services/trip_socket_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../core/utils/location_payload.dart';
import '../chats/location_picker_screen.dart';
import '../../widgets/trips/trip_permission_sheet.dart';
import '../../widgets/trips/trip_rail.dart';
import '../../widgets/trips/trip_visuals.dart';
import '../../talky_models.dart';

/// Composition d'un trajet : destination, durée, note, puis le contrat et le
/// départ.
///
/// **Aucune sélection de destinataires.** Le cercle de confiance *est*
/// l'audience, en entier — c'est ce qui permet de partir en un appui. On
/// choisit qui reçoit en modifiant sa liste Confiance, à froid, ailleurs.
///
/// L'élément le plus important de l'écran n'est pas un champ, c'est la phrase
/// du contrat : « si vous n'avez pas confirmé à 21:55, vos proches seront
/// prévenus ». C'est le seul endroit qui garantit que la personne a compris ce
/// qu'elle déclenche, et les deux heures y sont écrites, jamais déduites. Elle
/// est donc traitée comme le sujet de l'écran : bloc dédié, heures en gras dans
/// la phrase, posée juste au-dessus du bouton qui l'engage.
class TripComposeScreen extends StatefulWidget {
  const TripComposeScreen({super.key, required this.kind});

  final String kind;

  @override
  State<TripComposeScreen> createState() => _TripComposeScreenState();
}

class _TripComposeScreenState extends State<TripComposeScreen> {
  static const _durees = [15, 30, 45, 60, 90];

  int _dureeMin = 30;
  final _note = TextEditingController();
  bool _envoi = false;

  /// Destination facultative. Avec elle, l'arrivée peut être détectée par le
  /// rayon en plus de l'heure — la première atteinte pose la question.
  LocationPayload? _destination;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  DateTime get _eta => DateTime.now().add(Duration(minutes: _dureeMin));

  /// L'heure d'alerte est dérivée de la grâce **servie par le serveur**, jamais
  /// d'une constante d'écran : c'est la même valeur que celle qui sera figée
  /// dans le trajet.
  DateTime _alerte(int graceMin) => _eta.add(Duration(minutes: graceMin));

  Future<void> _demarrer() async {
    if (_envoi) return;

    // AVANT la création du trajet, et non après : la boîte système ne se montre
    // qu'une fois, et une carte déjà partie au cercle sans autorisation
    // afficherait « position indisponible » dès la première seconde.
    await TripPermissionSheet.demander(context);
    if (!mounted) return;

    setState(() => _envoi = true);
    final l10n = context.l10n;
    final trips = context.read<TripRepository>();
    final socket = context.read<TripSocketService>();
    final api = context.read<TalkyApiClient>();
    try {
      final trajet = await trips.startTrip(
        kind: widget.kind,
        durationMin: _dureeMin,
        note: _note.text.trim(),
        destLat: _destination?.lat,
        destLng: _destination?.lng,
        destLabel: _destination?.name ?? _destination?.address,
        // Sans cet identifiant, `trip.owner_device` reste NULL et le verrou
        // « un seul appareil émet » ne s'applique jamais : deux téléphones du
        // même compte entrelaceraient leurs positions.
        deviceId: await api.ensureStableDeviceId(),
      );
      // Le suivi démarre tout de suite : le cercle vient de recevoir une carte,
      // elle ne doit pas rester sans position.
      await TripSessionGuard.instance.acquire(
        tripId: trajet.id,
        trips: trips,
        socket: socket,
        etaAt: trajet.etaAt,
        kind: trajet.kind,
      );
      if (mounted) Navigator.pop(context, true);
    } on TalkyException catch (e) {
      if (!mounted) return;
      setState(() => _envoi = false);
      // On distingue les cas par le code renvoyé par le serveur, jamais par le
      // texte du message — celui-ci peut changer sans prévenir.
      final message = switch (e.statusCode) {
        409 when e.message.contains('TRUST_LIST_EMPTY') =>
          l10n.tripsCircleEmptyTitle,
        409 => l10n.tripsAlreadyActive,
        501 => l10n.tripsSosUnavailable,
        _ => l10n.tripsStartFailed,
      };
      _erreur(message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _envoi = false);
      _erreur(l10n.tripsStartFailed);
    }
  }

  void _erreur(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cache = context.read<LocalCacheRepository>();
    final trips = context.read<TripRepository>();
    // La grâce vient du serveur : l'heure d'alerte affichée est la vraie,
    // même si TRIP_GRACE_MIN a été réglé depuis la dernière publication.
    final grace = trips.policy.graceMinutes;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.kind == TripKind.taxi
              ? l10n.tripsKindTaxi
              : l10n.tripsKindWalk,
        ),
      ),
      body: StreamBuilder<List<LocalContactList>>(
        stream: cache.watchContactLists(),
        builder: (context, snap) {
          final membres = _membresTrust(snap.data);

          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              const TripRail(state: TripState.active, composing: true),
              _titre(l10n.tripsDestination),
              _carteDestination(l10n),
              if (_destination != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Text(
                    l10n.tripsDestinationSafetyNet,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              _titre(l10n.tripsArrivalIn),
              _choixDuree(l10n),
              _titre(l10n.tripsNoteLabel),
              _champNote(l10n),
              _contrat(l10n, membres, grace),
              _avatarsCercle(cache, snap.data),
              _mentionCercle(l10n),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.lg),
        child: FilledButton.icon(
          onPressed: _envoi ? null : _demarrer,
          icon: _envoi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.shield_rounded),
          label: Text(
            l10n.tripsStart,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          ),
        ),
      ),
    );
  }

  // ── Destination ───────────────────────────────────────────────────

  /// Réutilise l'écran de choix de position existant — carte, pin central,
  /// recherche et géocodage inverse. Le libellé n'est résolu qu'ICI, une seule
  /// fois : le géocoder sur la trace enverrait tout le déplacement à un tiers.
  Future<void> _choisirDestination() async {
    final r = await Navigator.push<LocationSendResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerScreen(
          purpose: LocationPickerPurpose.destination,
        ),
      ),
    );
    if (r != null && mounted) setState(() => _destination = r.payload);
  }

  Widget _carteDestination(dynamic l10n) {
    final d = _destination;
    final choisie = d != null;
    final teinte = choisie
        ? context.colors.primary
        : context.colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        child: InkWell(
          borderRadius: AppRadius.brMd,
          onTap: _choisirDestination,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: AppRadius.brMd,
              border: Border.all(
                color: choisie
                    ? context.colors.primary.withValues(alpha: 0.35)
                    : context.colors.outlineVariant,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: choisie
                        ? context.semantic.brandContainer
                        : context.semantic.surfaceMuted,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    choisie
                        ? Icons.place_rounded
                        : Icons.add_location_alt_outlined,
                    color: teinte,
                    size: 21,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choisie
                            ? (d.name ?? d.address ?? l10n.tripsDestination)
                            : l10n.tripsDestinationOptional,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyLarge?.copyWith(
                          fontWeight: choisie
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: choisie
                              ? null
                              : context.colors.onSurfaceVariant,
                        ),
                      ),
                      if (choisie) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.tripsDestinationRadius,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (choisie)
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: AppIconSize.sm,
                    tooltip: l10n.commonCancel,
                    onPressed: () => setState(() => _destination = null),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    size: AppIconSize.sm,
                    color: context.colors.outlineVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Durée ─────────────────────────────────────────────────────────

  /// Les durées, et **sous elles l'heure que ça donne**.
  ///
  /// « 30 min » est un choix, « 21:45 » est ce que le cercle verra. Sans cette
  /// ligne, il faut faire l'addition de tête au moment précis où l'on est
  /// pressé de partir.
  Widget _choixDuree(dynamic l10n) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final d in _durees)
              ChoiceChip(
                label: Text(l10n.tripsMinutes(d)),
                selected: _dureeMin == d,
                showCheckmark: false,
                labelStyle: context.text.labelLarge?.copyWith(
                  fontWeight: _dureeMin == d
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: _dureeMin == d
                      ? context.colors.onPrimaryContainer
                      : context.colors.onSurfaceVariant,
                ),
                onSelected: (_) => setState(() => _dureeMin = d),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 15,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              l10n.tripsEtaAt(TripFormat.hhmm(_eta)),
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  // ── Note ──────────────────────────────────────────────────────────

  Widget _champNote(dynamic l10n) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: TextField(
      controller: _note,
      maxLength: 200,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: l10n.tripsNoteHint,
        filled: true,
        fillColor: context.semantic.surfaceMuted,
        prefixIcon: Icon(
          Icons.short_text,
          size: AppIconSize.sm,
          color: context.colors.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: context.colors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide(color: context.colors.outlineVariant),
        ),
      ),
    ),
  );

  // ── Le contrat ────────────────────────────────────────────────────

  int _membresTrust(List<LocalContactList>? listes) {
    if (listes == null) return 0;
    for (final l in listes) {
      if (l.kind == ContactListKind.trust) return l.memberCount;
    }
    return 0;
  }

  LocalContactList? _trustList(List<LocalContactList>? listes) {
    if (listes == null) return null;
    for (final l in listes) {
      if (l.kind == ContactListKind.trust) return l;
    }
    return null;
  }

  /// Visages du cercle au moment d'engager — lecture seule.
  Widget _avatarsCercle(
    LocalCacheRepository cache,
    List<LocalContactList>? listes,
  ) {
    final trust = _trustList(listes);
    if (trust == null) return const SizedBox.shrink();

    return StreamBuilder<List<User>>(
      stream: cache.watchListMembers(trust.idList),
      builder: (context, snap) {
        final users = snap.data ?? const <User>[];
        if (users.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, i) {
                final u = users[i];
                final nom = (u.pseudo.trim().isNotEmpty)
                    ? u.pseudo.trim()
                    : u.nom.trim();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: u.avatarUrl.isNotEmpty
                          ? NetworkImage(u.avatarUrl)
                          : null,
                      child: u.avatarUrl.isEmpty
                          ? Text(
                              nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        nom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _titre(String texte) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Text(
      texte.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: context.colors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );

  /// Le contrat, en toutes lettres. Les deux heures sont calculées, affichées —
  /// et **mises en gras dans la phrase** : ce sont les deux seuls nombres que la
  /// personne doit retenir en quittant cet écran, et les noyer dans un
  /// paragraphe gris reviendrait à ne pas les avoir écrits.
  Widget _contrat(dynamic l10n, int membres, int graceMin) {
    final heureEta = TripFormat.hhmm(_eta);
    final heureAlerte = TripFormat.hhmm(_alerte(graceMin));
    final phrase = l10n.tripsContract(membres, heureEta, heureAlerte);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.brandContainer,
        borderRadius: AppRadius.brMd,
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.handshake_outlined,
            size: AppIconSize.sm,
            color: context.colors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: context.text.bodyMedium?.copyWith(
                  color: context.semantic.onBrandContainer,
                  height: 1.45,
                ),
                children: _enGras(context, phrase, {heureEta, heureAlerte}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Découpe [phrase] pour rendre [jetons] en gras, quel que soit leur ordre
  /// d'apparition — la traduction n'est pas tenue de les placer comme le
  /// français.
  List<TextSpan> _enGras(
    BuildContext context,
    String phrase,
    Set<String> jetons,
  ) {
    final motif = jetons
        .where((j) => j.isNotEmpty)
        .map(RegExp.escape)
        .join('|');
    if (motif.isEmpty) return [TextSpan(text: phrase)];

    final spans = <TextSpan>[];
    var curseur = 0;
    for (final m in RegExp(motif).allMatches(phrase)) {
      if (m.start > curseur) {
        spans.add(TextSpan(text: phrase.substring(curseur, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.colors.primary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
      curseur = m.end;
    }
    if (curseur < phrase.length) {
      spans.add(TextSpan(text: phrase.substring(curseur)));
    }
    return spans;
  }

  Widget _mentionCercle(dynamic l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline,
          size: 14,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            l10n.tripsCircleFrozen,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
