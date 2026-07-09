import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/app_log.dart';
import '../utils/backend_url.dart';

//  Télécharge et conserve les médias reçus dans le dossier de l'app pour
//  une consultation hors-ligne. Évince les plus vieux fichiers (LRU) quand
//  le cache dépasse [kMaxCacheBytes].
class MediaCacheService {
  /// Plafond dur du cache (octets). Au-delà, on évince jusqu'à
  /// [kTargetCacheBytes] pour éviter de re-évincer constamment.
  static const int kMaxCacheBytes = 500 * 1024 * 1024;
  static const int kTargetCacheBytes = 400 * 1024 * 1024;

  Directory? _dir;

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'media_cache'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Chemin local si déjà en cache, sinon null (sans télécharger).
  Future<String?> cachedPathFor(String url) async {
    final resolved = _resolvedUrl(url);
    final dir = await _cacheDir();
    final file = File(p.join(dir.path, _fileName(resolved)));
    return file.existsSync() ? file.path : null;
  }

  /// Télécharge un média vers un fichier TEMPORAIRE (hors du cache persistant)
  /// et renvoie son chemin. Utilisé pour les médias à vue unique : on lit
  /// depuis ce fichier local (les lecteurs natifs vidéo/audio ignorent le
  /// cert pinning et échouent sur une URL réseau directe), puis l'appelant
  /// supprime le fichier immédiatement après visionnage.
  Future<String?> downloadToTemp(String url) async {
    final resolved = _resolvedUrl(url);
    try {
      final res = await http.get(Uri.parse(resolved)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      final tmp = await getTemporaryDirectory();
      final path = p.join(
        tmp.path,
        'vo_${DateTime.now().microsecondsSinceEpoch}_${_fileName(resolved)}',
      );
      final file = File(path);
      await file.writeAsBytes(res.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('[MediaCache] downloadToTemp échoué $resolved: $e');
      return null;
    }
  }

  /// Télécharge le média avec progression (0.0–1.0) ou `null` si taille inconnue.
  Future<String?> downloadWithProgress(
    String url, {
    void Function(double? progress)? onProgress,
    int? maxBytes,
  }) async {
    final resolved = _resolvedUrl(url);
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, _fileName(resolved)));
      if (file.existsSync() && file.lengthSync() > 0) {
        onProgress?.call(1.0);
        try {
          file.setLastAccessedSync(DateTime.now());
        } catch (e, st) {
          AppLog.w('MediaCache', 'Touch LRU (setLastAccessed) échoué', e, st);
        }
        return file.path;
      }

      final uri = Uri.parse(resolved);
      final client = http.Client();
      try {
        if (maxBytes != null) {
          try {
            final head =
                await client.head(uri).timeout(const Duration(seconds: 5));
            final len = int.tryParse(head.headers['content-length'] ?? '');
            if (len != null && len > maxBytes) {
              debugPrint('[MediaCache] skip $resolved : taille $len > $maxBytes');
              return null;
            }
          } catch (_) {}
        }

        final request = http.Request('GET', uri);
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 60));
        if (streamed.statusCode != 200) return null;

        final int? total = streamed.contentLength;
        final hasKnownSize = total != null && total > 0;
        if (hasKnownSize) {
          onProgress?.call(0.0);
        } else {
          onProgress?.call(null);
        }

        final tmp = File('${file.path}.part');
        final sink = tmp.openWrite();
        var received = 0;
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (hasKnownSize) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        }
        await sink.close();

        if (hasKnownSize && received < total) return null;
        if (maxBytes != null && received > maxBytes) {
          await tmp.delete();
          return null;
        }

        if (file.existsSync()) await file.delete();
        await tmp.rename(file.path);
        onProgress?.call(1.0);
        unawaited(evictIfNeeded());
        return file.path;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[MediaCache] downloadWithProgress échoué $resolved: $e');
      return null;
    }
  }

  /// Télécharge le média s'il n'est pas déjà en cache et renvoie le chemin local.
  /// Si [maxBytes] est fourni, vérifie d'abord la taille via HEAD et abandonne
  /// si trop gros (utile pour ne pas auto-cacher des fichiers énormes).
  Future<String?> ensureCached(String url, {int? maxBytes}) async {
    final resolved = _resolvedUrl(url);
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, _fileName(resolved)));
      if (file.existsSync() && file.lengthSync() > 0) {
        // Touch pour LRU
        try {
          file.setLastAccessedSync(DateTime.now());
        } catch (e, st) {
          AppLog.w('MediaCache', 'Touch LRU (setLastAccessed) échoué', e, st);
        }
        return file.path;
      }

      if (maxBytes != null) {
        try {
          final head = await http.head(Uri.parse(resolved)).timeout(const Duration(seconds: 5));
          final len = int.tryParse(head.headers['content-length'] ?? '');
          if (len != null && len > maxBytes) {
            debugPrint('[MediaCache] skip $resolved : taille $len > $maxBytes');
            return null;
          }
        } catch (_) {
          // HEAD échoue → on tente quand même (mieux vaut un cache best-effort)
        }
      }

      final res = await http.get(Uri.parse(resolved)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      await file.writeAsBytes(res.bodyBytes);
      // Éviction post-write : non-bloquante pour le caller.
      unawaited(evictIfNeeded());
      return file.path;
    } catch (e) {
      debugPrint('[MediaCache] échec cache $resolved: $e');
      return null;
    }
  }

  /// Taille actuelle du cache (octets). Scanne le dossier — appeler avec
  /// parcimonie.
  Future<int> currentSizeBytes() async {
    try {
      final dir = await _cacheDir();
      final files = dir.listSync(followLinks: false).whereType<File>();
      var total = 0;
      for (final f in files) {
        try {
          total += f.lengthSync();
        } catch (e, st) {
          AppLog.w('MediaCache', 'Lecture taille fichier cache échouée', e, st);
        }
      }
      return total;
    } catch (e) {
      debugPrint('[MediaCache] currentSizeBytes échoué: $e');
      return 0;
    }
  }

  /// Vide entièrement le cache média (logout / changement de compte).
  Future<void> clearAll() async {
    try {
      final dir = await _cacheDir();
      if (!dir.existsSync()) return;
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        try {
          entity.deleteSync();
        } catch (e, st) {
          AppLog.w('MediaCache', 'Suppression fichier cache échouée', e, st);
        }
      }
      debugPrint('[MediaCache] cache vidé');
    } catch (e) {
      debugPrint('[MediaCache] clearAll échoué: $e');
    }
  }

  /// Évince les fichiers les plus anciens (par `accessed` puis `modified`)
  /// si le cache dépasse [kMaxCacheBytes], jusqu'à redescendre à
  /// [kTargetCacheBytes]. Idempotent et best-effort (erreurs ignorées).
  Future<void> evictIfNeeded() async {
    try {
      final size = await currentSizeBytes();
      if (size <= kMaxCacheBytes) return;
      final dir = await _cacheDir();
      final entries = dir
          .listSync(followLinks: false)
          .whereType<File>()
          .map((f) {
        DateTime ts;
        int length;
        try {
          final st = f.statSync();
          ts = st.accessed.isAfter(st.modified) ? st.modified : st.accessed;
          length = st.size;
        } catch (_) {
          ts = DateTime.fromMillisecondsSinceEpoch(0);
          length = 0;
        }
        return _CacheEntry(f, ts, length);
      }).toList()
        ..sort((a, b) => a.ts.compareTo(b.ts));

      var running = size;
      var evicted = 0;
      for (final e in entries) {
        if (running <= kTargetCacheBytes) break;
        try {
          e.file.deleteSync();
          running -= e.length;
          evicted++;
        } catch (err, st) {
          AppLog.w('MediaCache', 'Éviction fichier cache échouée', err, st);
        }
      }
      if (evicted > 0) {
        debugPrint('[MediaCache] LRU évincé $evicted fichier(s), '
            'taille ${(size / 1024 / 1024).toStringAsFixed(1)}MB → '
            '${(running / 1024 / 1024).toStringAsFixed(1)}MB');
      }
    } catch (e) {
      debugPrint('[MediaCache] evictIfNeeded échoué: $e');
    }
  }

  String _resolvedUrl(String url) => normalizeBackendUrl(url) ?? url;

  String _fileName(String url) {
    final uri = Uri.tryParse(url);
    final last = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    if (last != null && last.isNotEmpty) return last;
    return '${url.hashCode}.bin';
  }
}

class _CacheEntry {
  final File file;
  final DateTime ts;
  final int length;
  _CacheEntry(this.file, this.ts, this.length);
}
