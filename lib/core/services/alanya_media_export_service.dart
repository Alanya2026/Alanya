import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_log.dart';
import 'media_download_preferences.dart';

/// Exporte les médias reçus vers le stockage partagé, structure type WhatsApp :
///
/// ```
/// Download/Alanya/Alanya Images/
/// Download/Alanya/Alanya Videos/
/// Download/Alanya/Alanya Documents/
/// ```
///
/// Photos/vidéos sont aussi ajoutées à l'album galerie « Alanya ».
class AlanyaMediaExportService {
  AlanyaMediaExportService._();
  static final AlanyaMediaExportService instance = AlanyaMediaExportService._();

  static const _kExportedIdsKey = 'exported_media_msg_ids_v2';
  static const _albumName = 'Alanya';
  static const _rootFolder = 'Alanya';
  static const _imagesFolder = 'Alanya Images';
  static const _videosFolder = 'Alanya Videos';
  static const _documentsFolder = 'Alanya Documents';
  static const _channel = MethodChannel('com.alanya/media_export');

  final Set<int> _exportedIds = {};
  bool _idsLoaded = false;
  bool _accessRequested = false;

  Future<void> _ensureIdsLoaded() async {
    if (_idsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kExportedIdsKey) ?? const <String>[];
    for (final s in raw) {
      final id = int.tryParse(s);
      if (id != null) _exportedIds.add(id);
    }
    _idsLoaded = true;
  }

  Future<void> _markExported(int msgID) async {
    _exportedIds.add(msgID);
    final prefs = await SharedPreferences.getInstance();
    var list = _exportedIds.map((e) => e.toString()).toList();
    if (list.length > 2000) {
      list = list.sublist(list.length - 2000);
      _exportedIds
        ..clear()
        ..addAll(list.map(int.parse));
    }
    await prefs.setStringList(_kExportedIdsKey, list);
  }

  String _subdirForType(int type) {
    switch (type) {
      case 1:
        return '$_rootFolder/$_imagesFolder';
      case 2:
        return '$_rootFolder/$_videosFolder';
      case 4:
      default:
        return '$_rootFolder/$_documentsFolder';
    }
  }

  /// Copie le média vers le stockage appareil si applicable.
  /// No-op pour vues uniques, messages envoyés, types hors {1,2,4}, déjà exporté.
  Future<void> exportIfNeeded({
    required int msgID,
    required int type,
    required String localPath,
    required bool isViewOnce,
    required bool isMine,
    String? mediaName,
  }) async {
    if (!MediaDownloadPreferences.isMediaVisibilityEnabled) return;
    if (msgID == 0 || isViewOnce || isMine) return;
    if (type != 1 && type != 2 && type != 4) return;

    await _ensureIdsLoaded();
    if (_exportedIds.contains(msgID)) return;

    final file = File(localPath);
    if (!file.existsSync()) return;

    try {
      await _exportToAlanyaFolder(
        type: type,
        localPath: localPath,
        mediaName: mediaName,
      );
      // Galerie Photos (en plus de Downloads) pour images/vidéos.
      if (type == 1 || type == 2) {
        try {
          await _exportToGallery(type: type, localPath: localPath);
        } catch (e, st) {
          AppLog.w('AlanyaExport', 'Galerie secondaire échouée', e, st);
        }
      }
      await _markExported(msgID);
    } catch (e, st) {
      AppLog.w('AlanyaExport', 'Export échoué msgID=$msgID type=$type', e, st);
    }
  }

  Future<void> _ensureGalleryAccess() async {
    if (_accessRequested) return;
    _accessRequested = true;
    try {
      final has = await Gal.hasAccess(toAlbum: true);
      if (!has) {
        await Gal.requestAccess(toAlbum: true);
      }
    } catch (e, st) {
      AppLog.w('AlanyaExport', 'Demande accès galerie échouée', e, st);
    }
  }

  Future<void> _exportToGallery({
    required int type,
    required String localPath,
  }) async {
    await _ensureGalleryAccess();
    if (type == 1) {
      await Gal.putImage(localPath, album: _albumName);
    } else {
      await Gal.putVideo(localPath, album: _albumName);
    }
  }

  Future<void> _exportToAlanyaFolder({
    required int type,
    required String localPath,
    String? mediaName,
  }) async {
    var name = (mediaName != null && mediaName.trim().isNotEmpty)
        ? mediaName.trim()
        : p.basename(localPath);
    // URLs serveur sans extension lisible → forcer une extension selon le type.
    if (p.extension(name).isEmpty) {
      final ext = switch (type) {
        1 => '.jpg',
        2 => '.mp4',
        _ => '',
      };
      if (ext.isNotEmpty) name = '$name$ext';
    }

    final mime = lookupMimeType(name) ??
        lookupMimeType(localPath) ??
        switch (type) {
          1 => 'image/jpeg',
          2 => 'video/mp4',
          _ => 'application/octet-stream',
        };

    final subdir = _subdirForType(type);

    if (Platform.isAndroid) {
      await _channel.invokeMethod('saveToDownloads', {
        'path': localPath,
        'fileName': name,
        'mimeType': mime,
        'subdir': subdir,
      });
      return;
    }

    if (Platform.isIOS) {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, subdir));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final dest = File(p.join(dir.path, name));
      if (dest.existsSync()) {
        final stem = p.basenameWithoutExtension(name);
        final ext = p.extension(name);
        final unique = File(p.join(
          dir.path,
          '${stem}_${DateTime.now().millisecondsSinceEpoch}$ext',
        ));
        await File(localPath).copy(unique.path);
      } else {
        await File(localPath).copy(dest.path);
      }
      return;
    }

    debugPrint('[AlanyaExport] Plateforme non supportée');
  }
}
