import 'package:flutter/material.dart';
import '../theme/locale_controller.dart';

/// Identité visuelle d'un document (icône, couleur, label) selon l'extension.
class DocumentFileStyle {
  const DocumentFileStyle({
    required this.extension,
    required this.family,
    required this.color,
    required this.icon,
    required this.label,
  });

  /// Extension en majuscules (ex. `PDF`), ou `FILE` si absente.
  final String extension;

  /// Famille logique (pdf, word, excel, …).
  final String family;

  final Color color;
  final IconData icon;

  /// Libellé court affiché sous le nom (ex. `PDF`, `Excel`).
  final String label;

  /// Sous-titre bulle : `{label} · appuyer pour ouvrir`.
  String get openHint => LocaleController.instance.l10n.tapToOpenLabel(label);

  bool get isPdf => family == 'pdf';

  static DocumentFileStyle fromMessage({String? mediaName, String? mediaUrl}) {
    final fromName = _extensionOf(mediaName);
    if (fromName != null) return fromExtension(fromName);
    final fromUrl = _extensionOf(_urlPath(mediaUrl));
    if (fromUrl != null) return fromExtension(fromUrl);
    return fromExtension(null);
  }

  static DocumentFileStyle fromFileName(String? name) {
    return fromExtension(_extensionOf(name));
  }

  static DocumentFileStyle fromExtension(String? ext) {
    final e = (ext ?? '').toLowerCase().trim();
    switch (e) {
      case 'pdf':
        return DocumentFileStyle(
          extension: 'PDF',
          family: 'pdf',
          color: Colors.red.shade400,
          icon: Icons.picture_as_pdf,
          label: 'PDF',
        );
      case 'doc':
      case 'docx':
        return DocumentFileStyle(
          extension: e.toUpperCase(),
          family: 'word',
          color: Colors.blue.shade400,
          icon: Icons.description,
          label: 'Word',
        );
      case 'xls':
      case 'xlsx':
        return DocumentFileStyle(
          extension: e.toUpperCase(),
          family: 'excel',
          color: Colors.green.shade400,
          icon: Icons.table_chart,
          label: 'Excel',
        );
      case 'csv':
        return DocumentFileStyle(
          extension: 'CSV',
          family: 'excel',
          color: Colors.green.shade400,
          icon: Icons.table_chart,
          label: 'CSV',
        );
      case 'ppt':
      case 'pptx':
        return DocumentFileStyle(
          extension: e.toUpperCase(),
          family: 'powerpoint',
          color: Colors.orange.shade400,
          icon: Icons.slideshow,
          label: 'PowerPoint',
        );
      case 'odt':
      case 'ods':
      case 'odp':
        return DocumentFileStyle(
          extension: e.toUpperCase(),
          family: 'opendocument',
          color: Colors.teal.shade400,
          icon: Icons.article_outlined,
          label: 'OpenDocument',
        );
      case 'zip':
      case 'rar':
      case '7z':
        return DocumentFileStyle(
          extension: e.toUpperCase(),
          family: 'archive',
          color: Colors.purple.shade400,
          icon: Icons.folder_zip,
          label: LocaleController.instance.l10n.fileArchive,
        );
      case 'apk':
        return DocumentFileStyle(
          extension: 'APK',
          family: 'apk',
          color: Colors.lightGreen.shade700,
          icon: Icons.android,
          label: 'APK',
        );
      case 'txt':
      case 'rtf':
        return DocumentFileStyle(
          extension: e.toUpperCase(),
          family: 'text',
          color: Colors.blueGrey.shade400,
          icon: Icons.text_snippet,
          label: LocaleController.instance.l10n.text2,
        );
      default:
        return DocumentFileStyle(
          extension: e.isEmpty ? 'FILE' : e.toUpperCase(),
          family: 'other',
          color: Colors.grey.shade500,
          icon: Icons.insert_drive_file,
          label: LocaleController.instance.l10n.file2,
        );
    }
  }

  static String? _extensionOf(String? name) {
    if (name == null || name.isEmpty) return null;
    final base = name.split('/').last.split('?').first;
    final dot = base.lastIndexOf('.');
    if (dot < 0 || dot >= base.length - 1) return null;
    return base.substring(dot + 1);
  }

  static String? _urlPath(String? url) {
    if (url == null || url.isEmpty) return null;
    return url.split('?').first;
  }
}
