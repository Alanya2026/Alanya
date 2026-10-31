//  Commentaire d'une photo du coffre (décision du 18/10/2026) : un texte de
//  200 caractères au plus, un audio de 5 minutes au plus, ou les deux.
//  Facultatif et privé : il ne part pas avec la photo quand on l'envoie.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/services/voice_record_config.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_widgets.dart';

String _duree(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Lecteur d'un audio de commentaire. Le fichier n'est chargé (téléchargé et
/// déchiffré) qu'au premier appui sur lecture ; s'il est temporaire, il est
/// supprimé quand le lecteur disparaît.
class SafeboxNotePlayer extends StatefulWidget {
  const SafeboxNotePlayer({
    super.key,
    required this.load,
    required this.durationMs,
    this.deleteOnDispose = true,
  });

  final Future<File> Function() load;
  final int durationMs;
  final bool deleteOnDispose;

  @override
  State<SafeboxNotePlayer> createState() => _SafeboxNotePlayerState();
}

class _SafeboxNotePlayerState extends State<SafeboxNotePlayer> {
  AudioPlayer? _lecteur;
  File? _fichier;
  bool _chargement = false;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _abonnementPosition;
  StreamSubscription<PlayerState>? _abonnementEtat;

  @override
  void dispose() {
    _abonnementPosition?.cancel();
    _abonnementEtat?.cancel();
    _lecteur?.dispose();
    final f = _fichier;
    if (widget.deleteOnDispose && f != null) {
      f.delete().ignore();
    }
    super.dispose();
  }

  Future<void> _basculer() async {
    final l = _lecteur;
    if (l != null) {
      l.playing ? await l.pause() : await l.play();
      return;
    }
    setState(() => _chargement = true);
    try {
      final f = await widget.load();
      _fichier = f;
      final lecteur = AudioPlayer();
      await lecteur.setFilePath(f.path);
      _abonnementPosition = lecteur.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _abonnementEtat = lecteur.playerStateStream.listen((e) {
        if (e.processingState == ProcessingState.completed) {
          lecteur.pause();
          lecteur.seek(Duration.zero);
        }
        if (mounted) setState(() {});
      });
      if (!mounted) {
        await lecteur.dispose();
        return;
      }
      _lecteur = lecteur;
      unawaited(lecteur.play());
    } catch (e) {
      if (mounted) safeboxSnack(context, context.l10n.safeboxNoteAudioFailed, error: true);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = Duration(milliseconds: widget.durationMs);
    final enLecture = _lecteur?.playing ?? false;
    final avance = total.inMilliseconds == 0 ? 0.0 : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Row(
      children: [
        _chargement
            ? const SizedBox(
                width: 48,
                height: 48,
                child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                onPressed: _basculer,
                icon: Icon(enLecture ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 36),
                color: context.colors.primary,
              ),
        Expanded(child: LinearProgressIndicator(value: avance)),
        AppSpacing.hGapSm,
        Text('${_duree(_position)} / ${_duree(total)}',
            style: context.text.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }
}

/// Résultat de l'éditeur : le commentaire tel qu'il est maintenant (null s'il
/// a été effacé). L'éditeur rend null tout court quand l'inscrit renonce.
class SafeboxNoteResult {
  const SafeboxNoteResult(this.note);
  final SafeboxNote? note;
}

/// La feuille remonte au-dessus du clavier et défile : on voit toujours ce
/// qu'on écrit.
Future<SafeboxNoteResult?> showSafeboxNoteEditor(BuildContext context, SafeboxFile file) =>
    showAppBottomSheet<SafeboxNoteResult>(
      context: context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(child: _EditeurCommentaire(file: file)),
      ),
    );

class _EditeurCommentaire extends StatefulWidget {
  const _EditeurCommentaire({required this.file});
  final SafeboxFile file;

  @override
  State<_EditeurCommentaire> createState() => _EditeurCommentaireState();
}

class _EditeurCommentaireState extends State<_EditeurCommentaire> {
  late final TextEditingController _texte = TextEditingController(text: widget.file.note?.text ?? '');
  final AudioRecorder _enregistreur = AudioRecorder();
  final Stopwatch _chrono = Stopwatch();
  Timer? _minuterie;
  bool _enregistrement = false;
  bool _occupe = false;
  bool _supprimerAudio = false;
  File? _nouveau;
  int _nouveauMs = 0;

  SafeboxController get _c => context.read<SafeboxController>();
  SafeboxNoteAudio? get _ancien => _supprimerAudio ? null : widget.file.note?.audio;

  @override
  void dispose() {
    _minuterie?.cancel();
    if (_enregistrement) unawaited(_enregistreur.stop().then(_effacer));
    _enregistreur.dispose();
    _texte.dispose();
    final n = _nouveau;
    if (n != null) _effacer(n.path);
    super.dispose();
  }

  void _effacer(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // Un temporaire qui survit est sans conséquence : le système le purge.
    }
  }

  Future<void> _demarrer() async {
    // Le clavier se range : la feuille redescend sur l'enregistrement.
    FocusScope.of(context).unfocus();
    if (!await _enregistreur.hasPermission()) {
      if (mounted) safeboxSnack(context, context.l10n.microphonePermissionDenied2, error: true);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/coffre_commentaire_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _enregistreur.start(kVoiceRecordConfig, path: path);
    if (!mounted) return;
    _chrono
      ..reset()
      ..start();
    setState(() => _enregistrement = true);
    _minuterie = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      // Le plafond s'applique tout seul : dépasser pour se faire refuser
      // ensuite par le serveur ferait perdre l'enregistrement.
      if (_chrono.elapsed.inSeconds >= SafeboxNote.audioMaxSeconds) unawaited(_arreter());
    });
  }

  Future<void> _arreter() async {
    if (!_enregistrement) return;
    _minuterie?.cancel();
    _chrono.stop();
    final path = await _enregistreur.stop();
    final ms = _chrono.elapsedMilliseconds.clamp(0, SafeboxNote.audioMaxSeconds * 1000);
    if (!mounted) return;
    setState(() => _enregistrement = false);
    if (path == null || ms < 1000) {
      _effacer(path);
      return;
    }
    final avant = _nouveau;
    setState(() {
      _nouveau = File(path);
      _nouveauMs = ms;
    });
    if (avant != null) _effacer(avant.path);
  }

  void _refaire() {
    final n = _nouveau;
    setState(() => _nouveau = null);
    if (n != null) _effacer(n.path);
  }

  Future<void> _enregistrer() async {
    final l10n = context.l10n;
    final texte = _texte.text.trim();
    // Même compte que le serveur : un émoji vaut un caractère.
    if (texte.runes.length > SafeboxNote.textMax) {
      safeboxSnack(context, l10n.safeboxNoteTooLong, error: true);
      return;
    }
    setState(() => _occupe = true);
    try {
      var note = widget.file.note;
      if (texte != (widget.file.note?.text ?? '')) {
        note = await _c.saveNoteText(widget.file, texte.isEmpty ? null : texte);
      }
      final nouveau = _nouveau;
      if (nouveau != null) {
        note = await _c.saveNoteAudio(widget.file, nouveau, _nouveauMs);
      } else if (_supprimerAudio && widget.file.note?.audio != null) {
        note = await _c.deleteNoteAudio(widget.file);
      }
      if (!mounted) return;
      safeboxSnack(context, l10n.safeboxNoteSaved);
      Navigator.pop(context, SafeboxNoteResult(note));
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final ancien = _ancien;
    final nouveau = _nouveau;
    return AppBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // La photo commentée : on sait où va le commentaire, même clavier ouvert.
          Row(
            children: [
              SafeboxFileThumb(file: widget.file, size: 48),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.file.note == null ? l10n.safeboxNoteAdd : l10n.safeboxNoteEdit,
                        style: context.text.titleMedium),
                    Text(widget.file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.vGapSm,
          Text(l10n.safeboxNotePrivate, style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          AppSpacing.vGapMd,
          TextField(
            controller: _texte,
            enabled: !_occupe,
            maxLength: SafeboxNote.textMax,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l10n.safeboxNoteHint, border: const OutlineInputBorder()),
          ),
          AppSpacing.vGapSm,
          if (_enregistrement) ...[
            Text(
              l10n.safeboxNoteRecording(_duree(_chrono.elapsed)),
              style: context.text.bodyMedium?.copyWith(color: colors.error, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            AppSpacing.vGapXs,
            LinearProgressIndicator(value: _chrono.elapsed.inMilliseconds / (SafeboxNote.audioMaxSeconds * 1000)),
            AppSpacing.vGapSm,
            FilledButton.icon(
              onPressed: _arreter,
              icon: const Icon(Icons.stop_rounded),
              label: Text(l10n.safeboxNoteStop),
            ),
          ] else if (nouveau != null) ...[
            SafeboxNotePlayer(
              key: ValueKey(nouveau.path),
              load: () async => nouveau,
              durationMs: _nouveauMs,
              deleteOnDispose: false,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _occupe ? null : _refaire,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.safeboxNoteRedo),
              ),
            ),
          ] else if (ancien != null) ...[
            Text(l10n.safeboxNoteAudio(ancien.durationLabel), style: context.text.labelLarge),
            SafeboxNotePlayer(
              load: () => _c.noteAudioFile(widget.file.id, ancien),
              durationMs: ancien.durationMs,
            ),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: _occupe ? null : _demarrer,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(l10n.safeboxNoteRedo),
                ),
                TextButton.icon(
                  onPressed: _occupe ? null : () => setState(() => _supprimerAudio = true),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.safeboxNoteDeleteAudio),
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                ),
              ],
            ),
          ] else
            OutlinedButton.icon(
              onPressed: _occupe ? null : _demarrer,
              icon: const Icon(Icons.mic_rounded),
              label: Text(l10n.safeboxNoteRecord),
            ),
          AppSpacing.vGapMd,
          FilledButton(
            onPressed: _occupe || _enregistrement ? null : _enregistrer,
            child: _occupe
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
