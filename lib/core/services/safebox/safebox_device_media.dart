//  Le téléphone vu par la sauvegarde automatique (lot 10) : la galerie par
//  photo_manager (photos, vidéos, audios, par dossier), les dossiers de
//  documents choisis par l'inscrit (canal com.alanya/safebox_documents,
//  SafeboxDocumentFolders.kt) et la mémoire du téléphone.
//
//  Android seulement pour l'instant : sur iOS, la galerie se sauvegarderait
//  par PhotoKit, sans dossiers de documents, et rien n'a pu être essayé sans
//  Mac.

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import 'safebox_backup.dart';
import 'safebox_models.dart';

class PhoneSafeboxDeviceSource implements SafeboxDeviceSource {
  static const _canal = MethodChannel('com.alanya/safebox_documents');

  /// L'original avec sa localisation (ACCESS_MEDIA_LOCATION) : sans elle,
  /// Android la retire du fichier lu.
  static const _demande = PermissionRequestOption(
    androidPermission: AndroidPermission(type: RequestType.all, mediaLocation: true),
  );

  /// Les sons du système ne sont pas de la musique.
  static final _sonsDuSysteme = RegExp(r'(^|/)(notifications|ringtones|alarms|ui)/', caseSensitive: false);

  static SafeboxMediaAccess _acces(PermissionState p) => switch (p) {
        PermissionState.authorized => SafeboxMediaAccess.full,
        PermissionState.limited => SafeboxMediaAccess.limited,
        _ => SafeboxMediaAccess.denied,
      };

  @override
  Future<SafeboxMediaAccess> access() async {
    if (!Platform.isAndroid) return SafeboxMediaAccess.denied;
    try {
      return _acces(await PhotoManager.getPermissionState(requestOption: _demande));
    } catch (e) {
      debugPrint('[Sauvegarde] autorisation illisible : $e');
      return SafeboxMediaAccess.denied;
    }
  }

  @override
  Future<SafeboxMediaAccess> requestAccess() async {
    if (!Platform.isAndroid) return SafeboxMediaAccess.denied;
    return _acces(await PhotoManager.requestPermissionExtend(requestOption: _demande));
  }

  @override
  Future<List<SafeboxDeviceFolder>> galleryFolders() async {
    if (await access() == SafeboxMediaAccess.denied) return const [];
    final chemins = await PhotoManager.getAssetPathList(type: RequestType.common, hasAll: false);
    final out = <SafeboxDeviceFolder>[];
    for (final c in chemins) {
      final n = await c.assetCountAsync;
      if (n > 0) out.add(SafeboxDeviceFolder(id: c.id, name: c.name, count: n));
    }
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  FilterOptionGroup _filtre(DateTime? depuis) => FilterOptionGroup(
        updateTimeCond: depuis == null
            ? DateTimeCond.def().copyWith(ignore: true)
            : DateTimeCond(min: depuis, max: DateTime.now().add(const Duration(days: 1))),
      );

  @override
  Future<List<SafeboxDeviceItem>> galleryItems({
    required Set<String> folderIds,
    required Set<SafeboxFamily> families,
    DateTime? since,
    bool withSizes = false,
  }) async {
    // Sans accès à la galerie, les dossiers de documents se sauvegardent quand même.
    if (await access() == SafeboxMediaAccess.denied) return const [];
    final out = <SafeboxDeviceItem>[];
    final images = families.contains(SafeboxFamily.photos), videos = families.contains(SafeboxFamily.videos);
    if ((images || videos) && folderIds.isNotEmpty) {
      final type = images && videos ? RequestType.common : (images ? RequestType.image : RequestType.video);
      final chemins = await PhotoManager.getAssetPathList(type: type, hasAll: false, filterOption: _filtre(since));
      for (final c in chemins.where((c) => folderIds.contains(c.id))) {
        await _lire(c, out, withSizes: withSizes);
      }
    }
    if (families.contains(SafeboxFamily.audios)) {
      final chemins = await PhotoManager.getAssetPathList(
        type: RequestType.audio,
        hasAll: true,
        onlyAll: true,
        filterOption: _filtre(since),
      );
      for (final c in chemins) {
        await _lire(c, out, withSizes: withSizes, sansSons: true);
      }
    }
    return out;
  }

  Future<void> _lire(AssetPathEntity c, List<SafeboxDeviceItem> out, {required bool withSizes, bool sansSons = false}) async {
    const page = 500;
    for (var p = 0;; p += 1) {
      final lot = await c.getAssetListPaged(page: p, size: page);
      for (final a in lot) {
        if (sansSons && _sonsDuSysteme.hasMatch(a.relativePath ?? '')) continue;
        final famille = switch (a.type) {
          AssetType.image => SafeboxFamily.photos,
          AssetType.video => SafeboxFamily.videos,
          AssetType.audio => SafeboxFamily.audios,
          AssetType.other => null,
        };
        if (famille == null) continue;
        var taille = -1;
        if (withSizes) {
          final f = await a.originFile;
          taille = f == null ? 0 : await f.length();
        }
        out.add(SafeboxDeviceItem(
          key: 'g:${a.id}',
          name: a.title ?? await a.titleAsync,
          family: famille,
          size: taille,
          modified: a.modifiedDateTime,
          folder: famille == SafeboxFamily.audios ? null : c.name,
          width: a.width > 0 ? a.width : null,
          height: a.height > 0 ? a.height : null,
          durationMs: a.duration > 0 ? a.duration * 1000.0 : null,
        ));
      }
      if (lot.length < page) return;
    }
  }

  @override
  Future<SafeboxDocumentFolder?> pickDocumentFolder() async {
    final r = await _canal.invokeMapMethod<String, dynamic>('pickFolder');
    return r == null ? null : SafeboxDocumentFolder.fromJson(r);
  }

  @override
  Future<List<SafeboxDeviceItem>> documentItems(SafeboxDocumentFolder folder, {DateTime? since}) async {
    final r = await _canal.invokeListMethod<Map<dynamic, dynamic>>('list', {
      'uri': folder.uri,
      'sinceMs': since?.millisecondsSinceEpoch ?? 0,
    });
    return [
      for (final d in r ?? const <Map<dynamic, dynamic>>[])
        SafeboxDeviceItem(
          key: 'd:${d['uri']}',
          name: '${d['name']}',
          family: SafeboxFamily.documents,
          size: (d['size'] as num?)?.toInt() ?? 0,
          modified: DateTime.fromMillisecondsSinceEpoch((d['modified'] as num?)?.toInt() ?? 0),
          folder: folder.name,
        ),
    ];
  }

  @override
  Future<File?> open(SafeboxDeviceItem item) async {
    if (item.fromGallery) {
      final a = await AssetEntity.fromId(item.key.substring(2));
      return a?.originFile;
    }
    // Un document se lit par son adresse : copié le temps de l'envoi.
    final dir = Directory('${(await getTemporaryDirectory()).path}/coffre_documents');
    await dir.create(recursive: true);
    final nom = '${sha1.convert(item.key.codeUnits).toString().substring(0, 12)}_${item.name}';
    final cible = File('${dir.path}/$nom');
    final ok = await _canal.invokeMethod<bool>('copy', {'uri': item.key.substring(2), 'path': cible.path});
    return ok == true ? cible : null;
  }

  @override
  Future<Set<String>> delete(List<SafeboxDeviceItem> items) async {
    final ids = [for (final it in items) if (it.fromGallery) it.key.substring(2)];
    if (ids.isEmpty) return {};
    final retires = await PhotoManager.editor.deleteWithIds(ids);
    return {for (final id in retires) 'g:$id'};
  }

  @override
  Future<({int free, int total})?> storage() async {
    try {
      final r = await _canal.invokeMapMethod<String, dynamic>('storage');
      if (r == null) return null;
      return (free: (r['free'] as num).toInt(), total: (r['total'] as num).toInt());
    } catch (_) {
      return null;
    }
  }

  /// L'inscrit retire un dossier de documents : Android oublie le droit de le lire.
  Future<void> releaseDocumentFolder(SafeboxDocumentFolder folder) async {
    try {
      await _canal.invokeMethod<bool>('release', {'uri': folder.uri});
    } catch (_) {}
  }
}
