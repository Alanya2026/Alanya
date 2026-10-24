import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/media_editor/editor_controller.dart' show EditorTool;
import '../../features/media_editor/media_editor_screen.dart';
import '../../features/media_editor/model/editor_document.dart' show EditorDoc;
import '../../features/media_editor/photo_tool_screen.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Ce qu'on retouche : une photo à envoyer (cadre libre) ou une photo de
/// profil / de groupe (cadre carré imposé, aperçu rond, rognage d'office).
enum PhotoEditTarget { photo, avatar }

/// Ouvre l'éditeur sur [source] (injectable pour les tests).
typedef MediaEditorOpener =
    Future<MediaEditorResult?> Function(
      BuildContext context,
      MediaEditorSource source,
      PhotoEditTarget target,
    );

/// Retouche facultative d'une photo avant envoi : rend le **fichier** à envoyer
/// à la place de [source], ou `null` si l'utilisateur abandonne (ou si la
/// préparation échoue : l'original reste alors utilisable, intact).
typedef PhotoEditor =
    Future<File?> Function(
      BuildContext context,
      File source, {
      PhotoEditTarget target,
    });

/// Une retouche avant envoi : le JPEG à envoyer et le document qui l'a
/// produit, rouvert à la retouche suivante (textes et traits restent
/// modifiables, on repart toujours de l'original).
class PhotoRetouch {
  const PhotoRetouch({required this.file, required this.doc});
  final File file;
  final EditorDoc doc;
}

/// Ouvre l'écran d'un outil de retouche (injectable pour les tests).
typedef PhotoToolOpener =
    Future<MediaEditorResult?> Function(
      BuildContext context,
      MediaEditorSource source,
      EditorTool tool,
      EditorDoc? initialDoc,
    );

/// Retouche d'une photo avant envoi, un outil à la fois : rend la nouvelle
/// retouche, ou `null` si rien n'a changé (abandon, ou échec signalé).
typedef PhotoRetoucher =
    Future<PhotoRetouch?> Function(
      BuildContext context,
      File original,
      EditorTool tool,
      EditorDoc? previous,
    );

/// Encodeur JPEG injectable (les tests évitent l'isolat).
typedef JpegEncoder =
    Future<Uint8List> Function(Uint8List rgba, int width, int height, int quality);

class PhotoEditException implements Exception {
  const PhotoEditException(this.message);
  final String message;
  @override
  String toString() => 'PhotoEditException($message)';
}

/// Fait passer une photo retouchée par le circuit d'envoi habituel.
///
/// L'éditeur rend du PNG (sans perte, 3 à 10 fois plus lourd qu'un JPEG de
/// photo) : on le **recompresse en JPEG** avant tout envoi, comme le
/// sélecteur d'images le faisait (`imageQuality` 80–85). Le fichier obtenu
/// devient celui que l'envoi met en outbox (`pendingUploadPath`), rien de
/// plus : même staging, même vignette, même upload qu'une photo non retouchée.
///
/// Le JPEG est neuf : aucune métadonnée de l'original (position GPS, appareil,
/// date) n'y est copiée ; l'orientation EXIF a déjà été appliquée au décodage
/// de l'éditeur.
abstract final class PhotoEditService {
  /// Dossier des photos retouchées (dans le dossier temporaire).
  static const String directoryName = 'alanya_edited';

  /// Qualité JPEG : celle des sélecteurs d'images qu'on remplace.
  static const int photoQuality = 80;
  static const int avatarQuality = 85;

  /// Paliers de repli quand le JPEG dépasse l'original (jamais plus lourd).
  static const List<int> _fallbackQualities = [70, 60];

  /// Les retouches de plus d'un jour sont purgées à la prochaine retouche.
  static const Duration staleAfter = Duration(days: 1);

  /// Ouverture par défaut : éditeur d'image, mode photo.
  static Future<MediaEditorResult?> openEditor(
    BuildContext context,
    MediaEditorSource source,
    PhotoEditTarget target,
  ) {
    final avatar = target == PhotoEditTarget.avatar;
    return MediaEditorScreen.open(
      context,
      source: source,
      mode: MediaEditorMode.photo,
      fixedAspect: avatar ? EditorAspect.square : null,
      roundFrame: avatar,
    );
  }

  /// Ouvre l'éditeur sur [source], recompresse le résultat en JPEG et le
  /// range dans un fichier neuf. `null` si l'utilisateur abandonne ; lève
  /// [PhotoEditException] si la préparation échoue.
  static Future<File?> edit(
    BuildContext context,
    File source, {
    PhotoEditTarget target = PhotoEditTarget.photo,
    MediaEditorOpener opener = openEditor,
    Directory? outputDirectory,
    JpegEncoder encode = encodeJpegInIsolate,
  }) async {
    final result = await opener(
      context,
      MediaEditorSource.file(source.path),
      target,
    );
    if (result == null) return null;
    final originalBytes = await _lengthOrNull(source);
    final jpeg = await recompress(
      result,
      quality: target == PhotoEditTarget.avatar ? avatarQuality : photoQuality,
      maxBytes: originalBytes,
      encode: encode,
    );
    return _write(jpeg, outputDirectory);
  }

  static Future<MediaEditorResult?> openTool(
    BuildContext context,
    MediaEditorSource source,
    EditorTool tool,
    EditorDoc? initialDoc,
  ) => PhotoToolScreen.open(
    context,
    source: source,
    tool: tool,
    initialDoc: initialDoc,
  );

  /// Ouvre l'outil [tool] sur [original] avec la retouche [previous] (ses
  /// calques restent modifiables), recompresse le résultat en JPEG et le
  /// range dans un fichier neuf. `null` si rien n'a changé ; lève
  /// [PhotoEditException] si la préparation échoue.
  static Future<PhotoRetouch?> retouch(
    BuildContext context,
    File original,
    EditorTool tool,
    EditorDoc? previous, {
    PhotoToolOpener opener = openTool,
    Directory? outputDirectory,
    JpegEncoder encode = encodeJpegInIsolate,
  }) async {
    final result = await opener(
      context,
      MediaEditorSource.file(original.path),
      tool,
      previous,
    );
    final doc = result?.doc;
    if (result == null || doc == null) return null;
    final jpeg = await recompress(
      result,
      quality: photoQuality,
      maxBytes: await _lengthOrNull(original),
      encode: encode,
    );
    return PhotoRetouch(file: await _write(jpeg, outputDirectory), doc: doc);
  }

  static Future<File> _write(Uint8List jpeg, Directory? outputDirectory) async {
    final dir = outputDirectory ?? await _outputDirectory();
    await _purgeStale(dir);
    final name = 'edited_${DateTime.now().microsecondsSinceEpoch}_'
        '${Random().nextInt(999999)}.jpg';
    final out = File(p.join(dir.path, name));
    try {
      await out.writeAsBytes(jpeg, flush: true);
    } on FileSystemException catch (e) {
      throw PhotoEditException('écriture impossible: ${e.message}');
    }
    return out;
  }

  /// PNG de l'éditeur → JPEG. Si le résultat dépasse [maxBytes] (poids de
  /// l'original), on réessaie à qualité moindre ; au pire on garde le dernier
  /// essai (l'image est de toute façon bornée par l'image de travail).
  @visibleForTesting
  static Future<Uint8List> recompress(
    MediaEditorResult result, {
    required int quality,
    int? maxBytes,
    JpegEncoder encode = encodeJpegInIsolate,
  }) async {
    final rgba = await _pngToRgba(result.png);
    var best = await encode(rgba.bytes, rgba.width, rgba.height, quality);
    if (maxBytes != null) {
      for (final q in _fallbackQualities) {
        if (best.length <= maxBytes || q >= quality) continue;
        best = await encode(rgba.bytes, rgba.width, rgba.height, q);
      }
    }
    return best;
  }

  /// Supprime une retouche **à nous** (jamais un fichier de l'utilisateur).
  static Future<void> discard(File? file) async {
    if (file == null || !isEdited(file)) return;
    try {
      await FileImage(file).evict();
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Fichier temporaire déjà absent : sans importance.
    }
  }

  /// Ce fichier est-il une retouche produite par ce service ?
  static bool isEdited(File file) =>
      p.basename(p.dirname(file.path)) == directoryName &&
      p.basename(file.path).startsWith('edited_');

  static Future<int?> _lengthOrNull(File f) async {
    try {
      return await f.length();
    } catch (_) {
      return null;
    }
  }

  static Future<({Uint8List bytes, int width, int height})> _pngToRgba(
    Uint8List png,
  ) async {
    ui.Codec? codec;
    ui.Image? image;
    try {
      codec = await ui.instantiateImageCodec(png);
      image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw const PhotoEditException('pixels illisibles');
      return (
        bytes: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        width: image.width,
        height: image.height,
      );
    } on PhotoEditException {
      rethrow;
    } catch (e) {
      throw PhotoEditException('décodage impossible: $e');
    } finally {
      image?.dispose();
      codec?.dispose();
    }
  }

  static Future<Directory> _outputDirectory() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, directoryName));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _purgeStale(Directory dir) async {
    try {
      if (!dir.existsSync()) await dir.create(recursive: true);
      final limit = DateTime.now().subtract(staleAfter);
      await for (final e in dir.list()) {
        if (e is File && e.lastModifiedSync().isBefore(limit)) {
          await e.delete();
        }
      }
    } catch (_) {
      // Purge opportuniste : un échec ne bloque jamais la retouche.
    }
  }

  /// Encode en JPEG dans un isolat (l'encodeur du paquet `image` est du Dart
  /// pur : ~100 à 300 ms pour 1024 px, hors du fil de l'interface).
  static Future<Uint8List> encodeJpegInIsolate(
    Uint8List rgba,
    int width,
    int height,
    int quality,
  ) => compute(
    _encodeJob,
    _JpegJob(rgba: rgba, width: width, height: height, quality: quality),
  );

  /// Version synchrone, pour les tests.
  @visibleForTesting
  static Uint8List encodeJpegSync(
    Uint8List rgba,
    int width,
    int height,
    int quality,
  ) => _encodeJob(
    _JpegJob(rgba: rgba, width: width, height: height, quality: quality),
  );
}

class _JpegJob {
  const _JpegJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.quality,
  });
  final Uint8List rgba;
  final int width;
  final int height;
  final int quality;
}

/// RGBA → JPEG. Le JPEG n'a pas de transparence : les zones transparentes
/// (cadre « Ajuster » plus grand que l'image) sont posées sur du blanc.
Uint8List _encodeJob(_JpegJob job) {
  final n = job.width * job.height;
  final rgb = Uint8List(n * 3);
  final src = job.rgba;
  for (var i = 0, s = 0, d = 0; i < n; i++, s += 4, d += 3) {
    final a = src[s + 3];
    if (a == 255) {
      rgb[d] = src[s];
      rgb[d + 1] = src[s + 1];
      rgb[d + 2] = src[s + 2];
    } else {
      final inv = 255 - a;
      rgb[d] = (src[s] * a + 255 * inv) ~/ 255;
      rgb[d + 1] = (src[s + 1] * a + 255 * inv) ~/ 255;
      rgb[d + 2] = (src[s + 2] * a + 255 * inv) ~/ 255;
    }
  }
  final image = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: rgb.buffer,
    numChannels: 3,
  );
  return img.encodeJpg(
    image,
    quality: job.quality,
    chroma: img.JpegChroma.yuv420,
  );
}

/// [PhotoEditor] des écrans : ouvre l'éditeur et, si la préparation échoue,
/// le dit à l'utilisateur (l'original reste en place, l'envoi reste possible).
Future<File?> editPhotoWithFeedback(
  BuildContext context,
  File source, {
  PhotoEditTarget target = PhotoEditTarget.photo,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final AppLocalizations l10n = context.l10n;
  try {
    return await PhotoEditService.edit(context, source, target: target);
  } on PhotoEditException catch (e) {
    debugPrint('[PhotoEdit] préparation échouée: $e');
    messenger?.showSnackBar(SnackBar(content: Text(l10n.mediaEditorEditFailed)));
    return null;
  }
}

/// [PhotoRetoucher] de l'écran d'envoi : si la préparation échoue, le dit à
/// l'utilisateur (la retouche précédente reste en place).
Future<PhotoRetouch?> retouchPhotoWithFeedback(
  BuildContext context,
  File original,
  EditorTool tool,
  EditorDoc? previous,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final AppLocalizations l10n = context.l10n;
  try {
    return await PhotoEditService.retouch(context, original, tool, previous);
  } on PhotoEditException catch (e) {
    debugPrint('[PhotoEdit] préparation échouée: $e');
    messenger?.showSnackBar(SnackBar(content: Text(l10n.mediaEditorEditFailed)));
    return null;
  }
}
