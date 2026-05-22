import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';


//  Télécharge et conserve les médias reçus dans le dossier de l'app pour
//  une consultation hors-ligne.
class MediaCacheService {
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
  Future<String?> ensureCached(String url) async {
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, _fileName(url)));
      if (file.existsSync() && file.lengthSync() > 0) return file.path;

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      await file.writeAsBytes(res.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('[MediaCache] échec cache $url: $e');
      return null;
    }
  }

  String _fileName(String url) {
    final uri = Uri.tryParse(url);
    final last = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    if (last != null && last.isNotEmpty) return last;
    return '${url.hashCode}.bin';
  }
}
