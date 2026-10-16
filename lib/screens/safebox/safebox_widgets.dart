//  Éléments communs des écrans du coffre-fort.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';

IconData safeboxRootIcon(SafeboxRoot r) => switch (r) {
      SafeboxRoot.albums => Icons.photo_library_outlined,
      SafeboxRoot.videos => Icons.video_library_outlined,
      SafeboxRoot.audios => Icons.library_music_outlined,
      SafeboxRoot.documents => Icons.description_outlined,
    };

/// Icône d'un fichier sans aperçu, selon son extension.
IconData safeboxFileIcon(SafeboxFile f) {
  switch (f.ext) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'doc':
    case 'docx':
    case 'odt':
    case 'rtf':
    case 'txt':
      return Icons.article_outlined;
    case 'xls':
    case 'xlsx':
    case 'ods':
    case 'csv':
      return Icons.table_chart_outlined;
    case 'ppt':
    case 'pptx':
    case 'odp':
      return Icons.slideshow_outlined;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip_outlined;
    case 'apk':
      return Icons.android;
  }
  return switch (f.family) {
    SafeboxRoot.albums => Icons.image_outlined,
    SafeboxRoot.videos => Icons.movie_outlined,
    SafeboxRoot.audios => Icons.music_note_outlined,
    SafeboxRoot.documents => Icons.insert_drive_file_outlined,
  };
}

String safeboxDate(BuildContext context, DateTime? d) =>
    d == null ? '' : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d.toLocal());

/// Aperçu d'un fichier : l'image déchiffrée si elle existe, sinon une icône.
class SafeboxFileThumb extends StatefulWidget {
  const SafeboxFileThumb({super.key, required this.file, this.size = 48, this.fill = false});

  final SafeboxFile file;
  final double size;

  /// Remplit sa case (grille) au lieu d'un carré de [size].
  final bool fill;

  @override
  State<SafeboxFileThumb> createState() => _SafeboxFileThumbState();
}

class _SafeboxFileThumbState extends State<SafeboxFileThumb> {
  Uint8List? _octets;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void didUpdateWidget(covariant SafeboxFileThumb old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) _charger();
  }

  void _charger() {
    final cache = context.read<SafeboxController>().previews;
    _octets = cache.peek(widget.file.id);
    if (_octets != null || widget.file.previewUrl == null) return;
    cache.load(widget.file).then((b) {
      if (mounted && b != null) setState(() => _octets = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fond = Container(
      width: widget.fill ? null : widget.size,
      height: widget.fill ? null : widget.size,
      decoration: BoxDecoration(color: context.semantic.brandContainer, borderRadius: AppRadius.brSm),
      child: _octets == null
          ? Icon(safeboxFileIcon(widget.file), color: context.colors.primary, size: widget.fill ? AppIconSize.lg : AppIconSize.md)
          : ClipRRect(
              borderRadius: AppRadius.brSm,
              child: Image.memory(_octets!, fit: BoxFit.cover, gaplessPlayback: true),
            ),
    );
    if (widget.file.family != SafeboxRoot.videos || _octets == null) return fond;
    return Stack(
      fit: widget.fill ? StackFit.expand : StackFit.loose,
      alignment: Alignment.center,
      children: [
        fond,
        const Icon(Icons.play_circle_fill, color: Colors.white70, size: 28),
      ],
    );
  }
}

/// « 7,4 Go utilisés sur 10 Go », avec la barre.
class SafeboxQuotaBar extends StatelessWidget {
  const SafeboxQuotaBar({super.key, required this.quota});
  final SafeboxQuota quota;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ratio = quota.ratio;
    final couleur = ratio >= 0.95
        ? context.colors.error
        : ratio >= 0.8
            ? context.semantic.warning
            : context.colors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.safeboxQuotaUsed(formatBytes(quota.usedBytes, l10n), formatBytes(quota.quotaBytes, l10n)),
          style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        AppSpacing.vGapSm,
        ClipRRect(
          borderRadius: AppRadius.brPill,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            color: couleur,
            backgroundColor: context.colors.surfaceContainerHighest,
          ),
        ),
        AppSpacing.vGapXs,
        Text(
          [
            l10n.safeboxFreeSpace(formatBytes(quota.freeBytes, l10n)),
            if (quota.trashBytes > 0) l10n.safeboxQuotaTrash(formatBytes(quota.trashBytes, l10n)),
          ].join(' · '),
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Demande un nom (dossier ou fichier). Rend null si l'inscrit annule.
Future<String?> safeboxAskName(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String initial = '',
  int maxLength = 80,
}) {
  final champ = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: champ,
        autofocus: true,
        maxLength: maxLength,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, champ.text.trim()), child: Text(action)),
      ],
    ),
  ).then((v) => v == null || v.isEmpty ? null : v);
}

Future<bool> safeboxConfirm(BuildContext context, {required String message, required String action, bool danger = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: ctx.colors.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

void safeboxSnack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? context.colors.error : null,
  ));
}

void safeboxShowError(BuildContext context, Object e) =>
    safeboxSnack(context, presenterErreur(context.l10n, e, domaine: ErrorDomain.media), error: true);
