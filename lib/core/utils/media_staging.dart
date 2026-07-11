import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copie un média sélectionné vers un dossier outbox durable avant upload.
///
/// Les chemins renvoyés par le Photo Picker peuvent expirer ; cette copie
/// garantit que le fichier reste lisible pendant tout l'upload (séquentiel ou
/// parallèle).
///
/// [outboxDirectory] est réservé aux tests (évite path_provider en unit test).
Future<File> stageMediaFile(
  File source, {
  Directory? outboxDirectory,
}) async {
  if (!source.existsSync()) {
    throw MediaStagingException('Fichier source introuvable : ${source.path}');
  }

  final outboxDir = outboxDirectory ?? await _outboxDirectory();
  if (!outboxDir.existsSync()) {
    await outboxDir.create(recursive: true);
  }
  final ext = p.extension(source.path).toLowerCase();
  final safeExt = ext.isNotEmpty ? ext : '';
  final name =
      'outbox_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}$safeExt';
  final dest = File(p.join(outboxDir.path, name));

  try {
    await source.copy(dest.path);
  } on FileSystemException catch (e) {
    throw MediaStagingException('Copie impossible : ${e.message}');
  }

  if (!dest.existsSync()) {
    throw MediaStagingException('Copie échouée : ${dest.path}');
  }
  return dest;
}

/// Copie plusieurs fichiers en parallèle.
Future<List<File>> stageMediaFiles(List<File> sources) {
  return Future.wait(sources.map(stageMediaFile));
}

Future<Directory> _outboxDirectory() async {
  final base = await getTemporaryDirectory();
  final dir = Directory(p.join(base.path, 'talky_outbox'));
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return dir;
}

class MediaStagingException implements Exception {
  MediaStagingException(this.message);

  final String message;

  @override
  String toString() => 'MediaStagingException: $message';
}
