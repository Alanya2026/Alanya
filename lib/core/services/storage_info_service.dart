import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'media_cache_service.dart';

/// Répartition du stockage local (cache médias, base, temporaire…).
class StorageBreakdown {
  final int mediaCacheBytes;
  final int databaseBytes;
  final int temporaryBytes;
  final int otherBytes;

  const StorageBreakdown({
    this.mediaCacheBytes = 0,
    this.databaseBytes = 0,
    this.temporaryBytes = 0,
    this.otherBytes = 0,
  });

  int get totalBytes =>
      mediaCacheBytes + databaseBytes + temporaryBytes + otherBytes;
}

/// Mesure les tailles de cache et de données locales pour l'écran stockage.
class StorageInfoService extends ChangeNotifier {
  StorageBreakdown _breakdown = const StorageBreakdown();
  bool _loading = false;

  StorageBreakdown get breakdown => _breakdown;
  bool get isLoading => _loading;

  Future<StorageBreakdown> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      final mediaCache = await MediaCacheService().currentSizeBytes();
      final docsDir = await getApplicationDocumentsDirectory();
      final tmpDir = await getTemporaryDirectory();

      final databaseBytes = await _dirSizeWhere(
        docsDir,
        (name) => name.endsWith('.sqlite') || name.endsWith('.db'),
      );
      final otherDocs = await _dirSizeWhere(
        docsDir,
        (name) =>
            !name.endsWith('.sqlite') &&
            !name.endsWith('.db') &&
            name != 'media_cache',
        excludeDirs: {'media_cache'},
      );
      final temporaryBytes = await _directorySize(tmpDir);

      _breakdown = StorageBreakdown(
        mediaCacheBytes: mediaCache,
        databaseBytes: databaseBytes,
        temporaryBytes: temporaryBytes,
        otherBytes: otherDocs,
      );
      return _breakdown;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<int> clearMediaCache() async {
    await MediaCacheService().clearAll();
    return refresh().then((b) => b.mediaCacheBytes);
  }

  Future<int> clearTemporaryFiles() async {
    final tmpDir = await getTemporaryDirectory();
    await _clearDirectory(tmpDir);
    return refresh().then((b) => b.temporaryBytes);
  }

  Future<int> _directorySize(Directory dir) async {
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (e) {
          debugPrint('[StorageInfoService] taille fichier: $e');
        }
      }
    }
    return total;
  }

  Future<int> _dirSizeWhere(
    Directory root,
    bool Function(String name) include, {
    Set<String> excludeDirs = const {},
  }) async {
    if (!root.existsSync()) return 0;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is Directory) {
        if (excludeDirs.contains(p.basename(entity.path))) continue;
      }
      if (entity is! File) continue;
      if (!include(p.basename(entity.path))) continue;
      try {
        total += await entity.length();
      } catch (e) {
        debugPrint('[StorageInfoService] taille fichier: $e');
      }
    }
    return total;
  }

  Future<void> _clearDirectory(Directory dir) async {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(followLinks: false)) {
      try {
        if (entity is File) {
          entity.deleteSync();
        } else if (entity is Directory) {
          entity.deleteSync(recursive: true);
        }
      } catch (e) {
        debugPrint('[StorageInfoService] suppression: $e');
      }
    }
  }
}
