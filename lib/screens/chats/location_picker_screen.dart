import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/utils/map_tiles.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location_payload.dart';

/// Résultat de l'écran de choix de position.
class LocationSendResult {
  const LocationSendResult(this.payload);
  final LocationPayload payload;
}

/// La carte est commune aux discussions et aux trajets, mais leur action de
/// confirmation n'a pas le même sens.
enum LocationPickerPurpose { share, destination }

/// Écran plein écran façon WhatsApp : carte interactive + pin central.
/// - GPS (« Ma position »)
/// - Déplacer la carte pour choisir un autre point
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.purpose = LocationPickerPurpose.share,
  });

  final LocationPickerPurpose purpose;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapCtrl = MapController();

  // ── Recherche de lieu ───────────────────────────────────────────────
  final _recherche = TextEditingController();
  final _focusRecherche = FocusNode();
  Timer? _debounce;
  List<PlaceHit> _resultats = const [];
  bool _chercheEnCours = false;
  bool _rechercheOuverte = false;
  bool _rechercheIndisponible = false;
  int _rechercheId = 0;

  LatLng _center = const LatLng(48.8566, 2.3522); // Paris fallback
  bool _hasFix = false;
  bool _loadingGps = false;
  bool _sending = false;
  bool _permissionDenied = false;
  bool _serviceDisabled = false;
  String? _statusHint;

  @override
  void initState() {
    super.initState();
    // La position ne doit être consultée qu'après une action explicite.
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _recherche.dispose();
    _focusRecherche.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _initGps() async {
    setState(() {
      _loadingGps = true;
      _permissionDenied = false;
      _serviceDisabled = false;
      _statusHint = null;
    });

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      if (!mounted) return;
      setState(() {
        _loadingGps = false;
        _serviceDisabled = true;
        _statusHint = context.l10n.enableLocationToUseYourPosition;
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _loadingGps = false;
        _permissionDenied = true;
        _statusHint = permission == LocationPermission.deniedForever
            ? context.l10n.permissionDeniedOpenSettingsOrPick
            : context.l10n.permissionDeniedYouCanStillPick;
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = point;
        _hasFix = true;
        _loadingGps = false;
        _statusHint = null;
      });
      _mapCtrl.move(point, 16);
    } catch (_) {
      // Dernière position connue si dispo.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && mounted) {
          final point = LatLng(last.latitude, last.longitude);
          setState(() {
            _center = point;
            _hasFix = true;
            _loadingGps = false;
            _statusHint = context.l10n.approximateGpsSlow;
          });
          _mapCtrl.move(point, 15);
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _loadingGps = false;
        _statusHint = context.l10n.gpsUnavailableMoveTheMapTo;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() => _loadingGps = true);
    await _initGps();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      var payload = LocationPayload(
        lat: _center.latitude,
        lng: _center.longitude,
      );
      payload = await enrichLocationWithAddress(payload);
      if (!mounted) return;
      Navigator.pop(context, LocationSendResult(payload));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    setState(() {
      _center = camera.center;
      _hasFix = true;
    });
  }

  // ── Recherche de lieu ─────────────────────────────────────────────

  /// Temporisation obligatoire : Nominatim n'accepte qu'une requête par
  /// seconde. Sans elle, taper « boulangerie » enverrait onze requêtes et
  /// ferait bannir l'adresse IP de l'application.
  void _surSaisie(String texte) {
    _debounce?.cancel();
    if (texte.trim().length < 3) {
      _rechercheId++;
      setState(() {
        _resultats = const [];
        _chercheEnCours = false;
        _rechercheIndisponible = false;
      });
      return;
    }
    final id = ++_rechercheId;
    setState(() {
      _chercheEnCours = true;
      _rechercheIndisponible = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _lancerRecherche(texte, id),
    );
  }

  Future<void> _lancerRecherche(String texte, int id) async {
    // On recherche AUTOUR du centre courant : sans cela, « pharmacie » renvoie
    // des résultats à l'autre bout du monde.
    final resultat = await searchPlaces(
      texte,
      // Le repli visuel de la carte n'est pas la localisation de la personne.
      near: _hasFix
          ? LocationPayload(lat: _center.latitude, lng: _center.longitude)
          : null,
    );
    if (!mounted || id != _rechercheId || _recherche.text != texte) return;
    setState(() {
      _resultats = resultat.hits;
      _chercheEnCours = false;
      _rechercheIndisponible = resultat.failed;
    });
  }

  void _reessayerRecherche() {
    final texte = _recherche.text;
    if (texte.trim().length < 3) return;
    final id = ++_rechercheId;
    setState(() {
      _chercheEnCours = true;
      _rechercheIndisponible = false;
    });
    _lancerRecherche(texte, id);
  }

  void _choisirResultat(PlaceHit hit) {
    _focusRecherche.unfocus();
    setState(() {
      _rechercheOuverte = false;
      _resultats = const [];
      _recherche.text = hit.name;
      _center = LatLng(hit.lat, hit.lng);
      _hasFix = true;
    });
    _mapCtrl.move(_center, 16);
  }

  void _fermerRecherche() {
    _focusRecherche.unfocus();
    _debounce?.cancel();
    _rechercheId++;
    setState(() {
      _rechercheOuverte = false;
      _resultats = const [];
      _rechercheIndisponible = false;
      _recherche.clear();
    });
  }

  Widget _barreRecherche(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface.withValues(alpha: 0.94),
      borderRadius: AppRadius.brPill,
      child: TextField(
        controller: _recherche,
        focusNode: _focusRecherche,
        onTap: () => setState(() => _rechercheOuverte = true),
        onChanged: _surSaisie,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: colors.onSurface),
        decoration: InputDecoration(
          isDense: true,
          hintText: context.l10n.locationSearchHint,
          hintStyle: TextStyle(color: colors.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: colors.onSurface, size: 20),
          suffixIcon: _recherche.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: colors.onSurface, size: 18),
                  tooltip: context.l10n.commonCancel,
                  onPressed: _fermerRecherche,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }

  Widget _listeResultats(BuildContext context) {
    if (!_rechercheOuverte) return const SizedBox.shrink();
    if (_chercheEnCours) {
      return _carteResultats(
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_recherche.text.trim().length < 3) return const SizedBox.shrink();
    if (_rechercheIndisponible) {
      return _carteResultats(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.locationSearchUnavailable,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _reessayerRecherche,
                icon: const Icon(Icons.refresh, size: AppIconSize.sm),
                label: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_resultats.isEmpty) {
      // Ni erreur ni blocage : la carte reste utilisable, et on le dit.
      return _carteResultats(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            context.l10n.locationSearchEmpty,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return _carteResultats(
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _resultats.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final h = _resultats[i];
          return ListTile(
            dense: true,
            leading: Icon(Icons.place_outlined, color: context.colors.primary),
            title: Text(
              h.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            // L'adresse complète lève l'ambiguïté entre deux lieux homonymes.
            subtitle: Text(
              h.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _choisirResultat(h),
          );
        },
      ),
    );
  }

  Widget _carteResultats({required Widget child}) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.sm,
      0,
    ),
    child: Material(
      color: context.colors.surface,
      borderRadius: AppRadius.brMd,
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDestination = widget.purpose == LocationPickerPurpose.destination;
    final title = isDestination
        ? context.l10n.locationPickerChooseDestination
        : context.l10n.sendALocation;
    final action = isDestination
        ? context.l10n.locationPickerUseDestination
        : context.l10n.sendThisLocation;

    return Scaffold(
      backgroundColor: MapTiles.background(context),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              maxZoom: MapTiles.maxDisplayZoom,
              minZoom: MapTiles.minDisplayZoom,
              backgroundColor: MapTiles.background(context),
              onPositionChanged: _onMapMoved,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [MapTiles.layer(context), MapTiles.attributionWidget()],
          ),
          // Pin fixe au centre (la carte bouge sous le pin).
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 36),
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color: colors.primary,
                  shadows: [
                    Shadow(
                      blurRadius: 6,
                      color: colors.shadow.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: colors.onSurface),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surface.withValues(
                            alpha: 0.94,
                          ),
                        ),
                        tooltip: context.l10n.commonCancel,
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: context.text.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: colors.shadow.withValues(alpha: 0.16),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: _barreRecherche(context),
                ),
                _listeResultats(context),
                if (_statusHint != null ||
                    _permissionDenied ||
                    _serviceDisabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Material(
                      color: colors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_statusHint != null)
                              Text(
                                _statusHint!,
                                style: context.text.bodySmall?.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            if (_permissionDenied) ...[
                              AppSpacing.vGapSm,
                              TextButton(
                                onPressed: _openAppSettings,
                                child: Text(context.l10n.openSettings),
                              ),
                            ],
                            if (_serviceDisabled) ...[
                              AppSpacing.vGapSm,
                              TextButton(
                                onPressed: _openLocationSettings,
                                child: Text(context.l10n.enableLocation),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: FloatingActionButton.small(
                          heroTag: 'loc_my_pos',
                          onPressed: _loadingGps ? null : _goToMyLocation,
                          backgroundColor: colors.surface,
                          tooltip: context.l10n.locationUseMyPosition,
                          child: _loadingGps
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.my_location, color: colors.primary),
                        ),
                      ),
                      AppSpacing.vGapMd,
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending || !_hasFix ? null : _send,
                          icon: _sending
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _hasFix
                                ? action
                                : context.l10n.locationPickerInstruction,
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.lg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
