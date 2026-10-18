//  Une photo du coffre ouverte dans l'application, avec son commentaire
//  (texte et/ou audio, facultatif et privé) en dessous. Avant, une photo
//  s'ouvrait dans une autre application : il n'y avait nulle part où montrer
//  son commentaire. « Ouvrir avec… » reste dans la barre du haut.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'safebox_note_widgets.dart';
import 'safebox_widgets.dart';

class SafeboxPhotoScreen extends StatefulWidget {
  const SafeboxPhotoScreen({super.key, required this.file});
  final SafeboxFile file;

  @override
  State<SafeboxPhotoScreen> createState() => _SafeboxPhotoScreenState();
}

class _SafeboxPhotoScreenState extends State<SafeboxPhotoScreen> {
  File? _local;
  Object? _erreur;
  late SafeboxNote? _note = widget.file.note;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    if (!widget.file.lost) _charger();
  }

  Future<void> _charger() async {
    setState(() => _erreur = null);
    try {
      final f = await _c.downloads.fetch(widget.file);
      if (mounted) setState(() => _local = f);
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  Future<void> _ouvrirAvec() async {
    final f = _local;
    if (f == null) return;
    final r = await OpenFilex.open(f.path);
    if (r.type != ResultType.done && mounted) safeboxSnack(context, context.l10n.safeboxOpenFailed, error: true);
  }

  Future<void> _modifierCommentaire() async {
    final r = await showSafeboxNoteEditor(context, _avecNote());
    if (r != null && mounted) setState(() => _note = r.note);
  }

  /// Le fichier avec le commentaire tel qu'il est maintenant.
  SafeboxFile _avecNote() {
    final f = widget.file;
    return SafeboxFile(
      id: f.id, folderId: f.folderId, name: f.name, ext: f.ext, mime: f.mime, family: f.family,
      plainBytes: f.plainBytes, storedBytes: f.storedBytes, originalBytes: f.originalBytes,
      compressed: f.compressed, cipherFormat: f.cipherFormat, key: f.key, previewUrl: f.previewUrl,
      createdAt: f.createdAt, updatedAt: f.updatedAt, folderName: f.folderName, meta: f.meta,
      sent: f.sent, lost: f.lost, note: _note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = widget.file;
    final progres = context.watch<SafeboxController>().downloads.progressOf(f.id);
    final note = _note;
    return Scaffold(
      appBar: AppBar(
        title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.safeboxOpenWith,
            onPressed: _local == null ? null : _ouvrirAvec,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: f.lost
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(l10n.safeboxFileLostBody, textAlign: TextAlign.center),
                    ),
                  )
                : _local != null
                    ? InteractiveViewer(
                        maxScale: 6,
                        child: Image.file(_local!, fit: BoxFit.contain),
                      )
                    : _erreur != null
                        ? Center(child: TextButton(onPressed: _charger, child: Text(l10n.safeboxRetry)))
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 160,
                                  child: LinearProgressIndicator(value: progres),
                                ),
                                AppSpacing.vGapSm,
                                SafeboxFileThumb(file: f, size: 96),
                              ],
                            ),
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.card,
              child: note == null
                  ? OutlinedButton.icon(
                      onPressed: _modifierCommentaire,
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(l10n.safeboxNoteAdd),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (note.text != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 120),
                            child: SingleChildScrollView(child: Text(note.text!, style: context.text.bodyLarge)),
                          ),
                        if (note.audio != null)
                          SafeboxNotePlayer(
                            key: ValueKey(note.audio!.url),
                            load: () => _c.noteAudioFile(f.id, note.audio!),
                            durationMs: note.audio!.durationMs,
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _modifierCommentaire,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(l10n.safeboxNoteEdit),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
