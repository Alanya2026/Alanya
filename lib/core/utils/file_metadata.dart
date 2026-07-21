import 'dart:io';

import 'package:pdfx/pdfx.dart';

import 'document_file_style.dart';

/// Formate une taille en octets (Ko / Mo).
String formatFileSize(int bytes) {
  if (bytes < 0) return '';
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) {
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} Ko';
  }
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} Mo';
}

/// Taille du fichier sur disque (0 si absent).
int fileSizeOnDisk(String? path) {
  if (path == null || path.isEmpty) return 0;
  final f = File(path);
  if (!f.existsSync()) return 0;
  return f.lengthSync();
}

/// Nombre de pages d'un PDF local ; null si non-PDF ou échec de lecture.
Future<int?> pdfPageCountForFile(String path) async {
  if (!DocumentFileStyle.fromFileName(path).isPdf) return null;
  try {
    final doc = await PdfDocument.openFile(path);
    final count = doc.pagesCount;
    await doc.close();
    return count;
  } catch (_) {
    return null;
  }
}

/// Métadonnées fichier pour l'envoi (taille + pages PDF).
Future<({int size, int? pageCount})> fileMetadataForSend(
  File file, {
  String? mediaName,
}) async {
  final size = file.existsSync() ? file.lengthSync() : 0;
  final name = mediaName ?? file.path.split('/').last;
  int? pageCount;
  if (DocumentFileStyle.fromMessage(mediaName: name).isPdf) {
    pageCount = await pdfPageCountForFile(file.path);
  }
  return (size: size, pageCount: pageCount);
}
