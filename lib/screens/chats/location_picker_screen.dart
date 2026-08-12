import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/utils/map_tiles.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location_payload.dart';

/// Résultat de l'écran de choix de position.
class LocationSendResult {
  const LocationSendResult(this.payload);
  final LocationPayload payload;
}

/// Écran plein écran façon WhatsApp : carte interactive + pin central.
/// - GPS (« Ma position »)
/// - Déplacer la carte pour choisir un autre point
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

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

  LatLng _center = const LatLng(48.8566, 2.3522); // Paris fallback
  bool _hasFix = false;
  bool _loadingGps = true;
  bool _sending = false;
  bool _permissionDenied = false;
  bool _serviceDisabled = false;
  String? _statusHint;

  @override
  void initState() {
    super.initState();
    _initGps();
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
        _statusHint =
            context.l10n.enableLocationToUseYourPosition;
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
        _statusHint =
            context.l10n.gpsUnavailableMoveTheMapTo;
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
      var payload = LocationPayload(lat: _center.latitude, lng: _center.longitude);
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
      setState(() {
        _resultats = const [];
        _chercheEnCours = false;
      });
      return;
    }
    setState(() => _chercheEnCours = true);
    _debounce = Timer(const Duration(milliseconds: 600), () => _lancerRecherche(texte));
  }

  Future<void> _lancerRecherche(String texte) async {
    // On recherche AUTOUR du centre courant : sans cela, « pharmacie » renvoie
    // des résultats à l'autre bout du monde.
    final hits = await searchPlaces(
      texte,
      near: LocationPayload(lat: _center.latitude, lng: _center.longitude),
    );
    if (!mounted) return;
    setState(() {
      _resultats = hits;
      _chercheEnCours = false;
    });
  }

  void _choisirResultat(PlaceHit hit) {
    _focusRecherche.unfocus();
    setState(() {
      _rechercheOuverte = false;
      _resultats = const [];
      _recherche.text = hit.name;
      _center = LatLng(hit.lat, hit.lng);
    });
    _mapCtrl.move(_center, 16);
  }

  void _fermerRecherche() {
    _focusRecherche.unfocus();
    _debounce?.cancel();
    setState(() {
      _rechercheOuverte = false;
      _resultats = const [];
      _recherche.clear();
    });
  }

  Widget _barreRecherche(BuildContext context) {
    return Material(
      color: AppColors.black.withValues(alpha: 0.55),
      borderRadius: AppRadius.brPill,
      child: TextField(
        controller: _recherche,
        focusNode: _focusRecherche,
        onTap: () => setState(() => _rechercheOuverte = true),
        onChanged: _surSaisie,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: AppColors.white),
        decoration: InputDecoration(
          isDense: true,
          hintText: context.l10n.locationSearchHint,
          hintStyle: TextStyle(color: AppColors.white.withValues(alpha: 0.7)),
          prefixIcon: const Icon(Icons.search, color: AppColors.white, size: 20),
          suffixIcon: _recherche.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, color: AppColors.white, size: 18),
                  tooltip: context.l10n.commonCancel,
                  onPressed: _fermerRecherche,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_recherche.text.trim().length < 3) return const SizedBox.shrink();
    if (_resultats.isEmpty) {
      // Ni erreur ni blocage : la carte reste utilisable, et on le dit.
      return _carteResultats(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(context.l10n.locationSearchEmpty,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant)),
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
            title: Text(h.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            // L'adresse complète lève l'ambiguïté entre deux lieux homonymes.
            subtitle: Text(h.address,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _choisirResultat(h),
          );
        },
      ),
    );
  }

  Widget _carteResultats({required Widget child}) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
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

    return Scaffold(
      backgroundColor: AppColors.immersiveBackground,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onPositionChanged: _onMapMoved,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              MapTiles.layer(context),
              MapTiles.attributionWidget(),
            ],
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
                    Shadow(blurRadius: 6, color: AppColors.black.withValues(alpha: 0.45)),
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
                        icon: const Icon(Icons.close, color: AppColors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.black.withValues(alpha: 0.45),
                        ),
                        tooltip: context.l10n.commonCancel,
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.sendALocation,
                          textAlign: TextAlign.center,
                          style: context.text.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 4, color: AppColors.black.withValues(alpha: 0.54)),
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
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  child: _barreRecherche(context),
                ),
                _listeResultats(context),
                if (_statusHint != null ||
                    _permissionDenied ||
                    _serviceDisabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Material(
                      color: AppColors.black.withValues(alpha: 0.72),
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
                                  color: AppColors.white,
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
                          child: _loadingGps
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(Icons.my_location, color: colors.primary),
                        ),
                      ),
                      AppSpacing.vGapMd,
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            _hasFix
                                ? context.l10n.sendThisLocation
                                : context.l10n.sendLocation,
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
