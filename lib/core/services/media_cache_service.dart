import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
    final dir = await _cacheDir();
    final file = File(p.join(dir.path, _fileName(url)));
    return file.existsSync() ? file.path : null;
  }

  /// Télécharge le média s'il n'est pas déjà en cache et renvoie le chemin local.
  /// Si [maxBytes] est fourni, vérifie d'abord la taille via HEAD et abandonne
  /// si trop gros (utile pour ne pas auto-cacher des fichiers énormes).
  Future<String?> ensureCached(String url, {int? maxBytes}) async {
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, _fileName(url)));
      if (file.existsSync() && file.lengthSync() > 0) {
        // Touch pour LRU
        try {
          file.setLastAccessedSync(DateTime.now());
        } catch (_) {}
        return file.path;
      }

      if (maxBytes != null) {
        try {
          final head = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 5));
          final len = int.tryParse(head.headers['content-length'] ?? '');
          if (len != null && len > maxBytes) {
            debugPrint('[MediaCache] skip $url : taille $len > $maxBytes');
            return null;
          }
        } catch (_) {
          // HEAD échoue → on tente quand même (mieux vaut un cache best-effort)
        }
      }

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      await file.writeAsBytes(res.bodyBytes);
      // Éviction post-write : non-bloquante pour le caller.
      unawaited(evictIfNeeded());
      return file.path;
    } catch (e) {
      debugPrint('[MediaCache] échec cache $url: $e');
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
        } catch (_) {}
      }
      return total;
    } catch (e) {
      debugPrint('[MediaCache] currentSizeBytes échoué: $e');
      return 0;
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
        } catch (_) {}
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
