import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../media_download_preferences.dart';

/// Cache disque **dédié** aux stickers (instance séparée, plafonnée).
///
/// Séparé du cache d'images général pour deux raisons : un sticker est
/// immuable (l'empreinte est dans le nom du fichier) donc il se garde
/// longtemps, et un plateau de plusieurs centaines de vignettes ne doit pas
/// évincer les avatars ni les médias de la conversation.
///
/// Budget : 600 objets au plus — vignettes de 3 à 6 Ko, stickers complets
/// d'au plus 100 Ko (300 Ko animés) — soit quelques dizaines de Mo dans le pire
/// cas. Au-delà, les moins récemment lus sont évincés (LRU).
class StickerCache {
  StickerCache({
    CacheManager? manager,
    Future<bool> Function()? canPrefetch,
  })  : _manager = manager ?? _defaultManager(),
        _canPrefetch = canPrefetch ?? MediaDownloadPreferences.shouldPrefetchStickersNow;

  /// Plafond d'objets conservés.
  static const int maxObjects = 600;

  /// Un sticker non lu depuis 60 jours est purgé.
  static const Duration stalePeriod = Duration(days: 60);

  static StickerCache? _shared;

  /// Instance de l'application.
  static StickerCache get instance => _shared ??= StickerCache();

  /// Remplace l'instance partagée (tests de widgets : gestionnaire factice).
  @visibleForTesting
  static set shared(StickerCache? cache) => _shared = cache;

  static CacheManager _defaultManager() => CacheManager(
        Config(
          'stickerCache',
          maxNrOfCacheObjects: maxObjects,
          stalePeriod: stalePeriod,
        ),
      );

  final CacheManager _manager;
  final Future<bool> Function() _canPrefetch;

  /// Gestionnaire à passer à `CachedNetworkImage(cacheManager: …)`.
  CacheManager get manager => _manager;

  /// Fichier d'un sticker (télécharge si absent). `null` si le fichier a été
  /// retiré (404/410) ou si le réseau échoue : l'appelant affiche alors le
  /// repli « Sticker retiré » ou réessaie.
  Future<File?> fileFor(String url) async {
    try {
      return await _manager.getSingleFile(url);
    } catch (e) {
      debugPrint('[StickerCache] $url indisponible: $e');
      return null;
    }
  }

  /// Fichier déjà en cache, sans réseau.
  Future<File?> cachedFile(String url) async =>
      (await _manager.getFileFromCache(url))?.file;

  /// Précharge les [urls] de vignettes d'un pack installé — **Wi-Fi
  /// seulement**. Renvoie le nombre de fichiers demandés (0 si le réseau n'est
  /// pas éligible). Les échecs unitaires sont ignorés.
  Future<int> prefetchThumbs(Iterable<String> urls) async {
    if (!await _canPrefetch()) return 0;
    var n = 0;
    for (final url in urls) {
      if (url.isEmpty) continue;
      n++;
      try {
        if (await _manager.getFileFromCache(url) != null) continue;
        await _manager.downloadFile(url);
      } catch (_) {/* une vignette manquante se rattrape à l'affichage */}
    }
    return n;
  }

  Future<void> clear() => _manager.emptyCache();
}
