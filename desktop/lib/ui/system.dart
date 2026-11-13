import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Ouvre un fichier avec le logiciel choisi par l'ordinateur pour son type.
Future<bool> openWithSystem(String path) async {
  try {
    return await launchUrl(Uri.file(path));
  } catch (_) {
    return false;
  }
}

/// Ouvre le dossier dans le gestionnaire de fichiers.
Future<bool> showInFolder(String path) async {
  final dossier = FileSystemEntity.isDirectorySync(path) ? path : File(path).parent.path;
  return openWithSystem(dossier);
}

/// Ouvre une adresse web dans le navigateur.
Future<bool> openUrl(String url) async {
  try {
    return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
