//  Choisir des fichiers du téléphone à ajouter au coffre (31/10/2026).
//
//  Sur Android, le sélecteur du système rend le document choisi ; une photo,
//  une vidéo ou un audio que l'application peut lire tel quel (autorisation
//  de la galerie) part de l'original : rien n'est copié. Le reste (un PDF…)
//  est copié pour l'envoi, avec « Préparation du fichier… », et la copie est
//  effacée une fois envoyée. Le sélecteur de file_picker recopiait tout
//  fichier choisi : 12 s d'attente sans rien à l'écran pour une vidéo de
//  568 Mo, et la copie restait dans le cache.
//
//  Lire l'original demande l'autorisation de la galerie (celle de la
//  sauvegarde automatique) : elle est demandée au premier choix
//  ([askGalleryAccess]). Refusée, le fichier est copié comme avant.
//
//  Ailleurs qu'Android : file_picker, comme avant.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/safebox/safebox_backup.dart';
import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_device_media.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'safebox_widgets.dart';

const _canal = MethodChannel('com.alanya/safebox_documents');

/// Les fichiers choisis, ou null si l'inscrit renonce. [askGalleryAccess] :
/// demander d'abord l'autorisation de la galerie, pour lire les photos,
/// vidéos et audios sans les copier (inutile pour des documents).
Future<List<SafeboxPick>?> pickSafeboxPhoneFiles(
  BuildContext context, {
  FileType type = FileType.any,
  bool multiple = true,
  bool askGalleryAccess = true,
}) async {
  if (!Platform.isAndroid) {
    final res = await FilePicker.platform.pickFiles(allowMultiple: multiple, type: type, withData: false);
    if (res == null) return null;
    return [
      for (final f in res.files)
        if (f.path != null) SafeboxPick(path: f.path!, name: f.name, size: f.size),
    ];
  }
  if (askGalleryAccess) {
    final galerie = PhoneSafeboxDeviceSource();
    try {
      // Une seule fois : déjà accordée ou refusée pour de bon, rien ne s'affiche.
      if (await galerie.access() == SafeboxMediaAccess.denied) await galerie.requestAccess();
    } catch (_) {}
    if (!context.mounted) return null;
  }
  final choisis = await _canal.invokeListMethod<Map<dynamic, dynamic>>('pickFiles', {
    'mimeTypes': switch (type) {
      FileType.image => ['image/*'],
      FileType.video => ['video/*'],
      FileType.audio => ['audio/*'],
      _ => ['*/*'],
    },
  });
  if (choisis == null || choisis.isEmpty || !context.mounted) return null;
  final retenus = multiple ? choisis : choisis.take(1).toList();
  final aCopier = [for (final d in retenus) if (d['path'] == null) d];
  final copies = <String, String>{};
  if (aCopier.isNotEmpty) {
    final ok = await _copier(context, aCopier, copies);
    if (!ok) {
      for (final chemin in copies.values) {
        try {
          File(chemin).deleteSync();
        } catch (_) {}
      }
      return null;
    }
  }
  return [
    for (final d in retenus)
      if (d['path'] != null || copies.containsKey(d['uri']))
        SafeboxPick(
          path: (d['path'] as String?) ?? copies[d['uri']]!,
          name: '${d['name']}',
          size: (d['size'] as num?)?.toInt() ?? -1,
          temporary: d['path'] == null,
        ),
  ];
}

/// Copie les documents illisibles tels quels, sous « Préparation du fichier… ».
Future<bool> _copier(BuildContext context, List<Map<dynamic, dynamic>> docs, Map<String, String> copies) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/coffre_choix');
  await dir.create(recursive: true);
  if (!context.mounted) return false;
  final nav = Navigator.of(context, rootNavigator: true);
  var ouvert = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
            AppSpacing.hGapMd,
            Expanded(child: Text(ctx.l10n.safeboxPreparingFile(docs.length))),
          ],
        ),
      ),
    ),
  ).whenComplete(() => ouvert = false);
  try {
    for (final d in docs) {
      final uri = '${d['uri']}';
      final cible = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${d['name']}';
      final ok = await _canal.invokeMethod<bool>('copy', {'uri': uri, 'path': cible});
      if (ok != true) throw StateError('copie impossible');
      copies[uri] = cible;
    }
    return true;
  } catch (e) {
    if (context.mounted) safeboxShowError(context, e);
    return false;
  } finally {
    if (ouvert) nav.pop();
  }
}
