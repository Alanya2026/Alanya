//  La visionneuse d'un dossier du coffre (02/11/2026) : les photos et vidéos
//  du dossier, l'une après l'autre d'un glissement, au lieu d'ouvrir et de
//  refermer chaque fichier. Sous une photo, son commentaire (texte et audio,
//  privé), à lire, ajouter ou modifier. « Ouvrir avec… » reste en haut.
//
//  Chaque fichier se télécharge quand on arrive dessus, et la photo suivante
//  est préparée d'avance. Une vidéo déjà sur le téléphone, ou de 100 Mo au
//  plus, se lance seule ; au-delà, un bouton « Lire · 568 Mo » évite de
//  consommer des données en passant simplement dessus.

import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import 'safebox_note_widgets.dart';
import 'safebox_widgets.dart';

/// Au-delà, une vidéo attend qu'on demande sa lecture.
const int kSafeboxViewerAutoVideoBytes = 100 << 20;

/// Une photo ou une vidéo : ce que la visionneuse sait montrer.
bool safeboxViewable(SafeboxFile f) => f.family == SafeboxFamily.photos || f.family == SafeboxFamily.videos;

/// Ouvre la visionneuse sur [files], à la position [initialIndex].
/// [loadMore] : la liste complétée par la page suivante du dossier.
/// [onNoteChanged] : un commentaire a changé, le dossier est à relire.
Future<void> showSafeboxViewer(
  BuildContext context, {
  required List<SafeboxFile> files,
  required int initialIndex,
  Future<List<SafeboxFile>> Function()? loadMore,
  VoidCallback? onNoteChanged,
}) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SafeboxViewerScreen(
          files: files,
          initialIndex: initialIndex,
          loadMore: loadMore,
          onNoteChanged: onNoteChanged,
        ),
      ),
    );

class SafeboxViewerScreen extends StatefulWidget {
  const SafeboxViewerScreen({
    super.key,
    required this.files,
    required this.initialIndex,
    this.loadMore,
    this.onNoteChanged,
  });

  final List<SafeboxFile> files;
  final int initialIndex;
  final Future<List<SafeboxFile>> Function()? loadMore;
  final VoidCallback? onNoteChanged;

  @override
  State<SafeboxViewerScreen> createState() => _SafeboxViewerScreenState();
}

class _SafeboxViewerScreenState extends State<SafeboxViewerScreen> {
  late List<SafeboxFile> _fichiers = widget.files;
  late int _position = widget.initialIndex;
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  bool _zoom = false;
  bool _barres = true;
  bool _chargeSuite = false;

  SafeboxController get _c => context.read<SafeboxController>();
  SafeboxFile get _actuel => _fichiers[_position];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _anticiper();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Prépare la photo suivante, et la page suivante du dossier en approchant de la fin.
  void _anticiper() {
    final suivant = _position + 1;
    if (suivant < _fichiers.length) {
      final f = _fichiers[suivant];
      if (f.family == SafeboxFamily.photos && !f.lost) {
        unawaited(_c.downloads.fetch(f).then<void>((_) {}, onError: (Object _) {}));
      }
    }
    final charger = widget.loadMore;
    if (charger == null || _chargeSuite || _position < _fichiers.length - 3) return;
    _chargeSuite = true;
    charger().then((liste) {
      // Le dossier relu entre-temps peut être plus court : la liste affichée reste.
      if (mounted && liste.length > _fichiers.length) setState(() => _fichiers = liste);
    }, onError: (Object _) {}).whenComplete(() => _chargeSuite = false);
  }

  Future<void> _ouvrirAvec() async {
    final l10n = context.l10n;
    final messager = ScaffoldMessenger.of(context);
    try {
      final f = await _c.downloads.fetch(_actuel);
      final r = await OpenFilex.open(f.path);
      if (r.type != ResultType.done) messager.showSnackBar(SnackBar(content: Text(l10n.safeboxOpenFailed)));
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    }
  }

  Future<void> _modifierCommentaire() async {
    final i = _position;
    final r = await showSafeboxNoteEditor(context, _fichiers[i]);
    if (r == null || !mounted) return;
    setState(() {
      _fichiers = [..._fichiers]..[i] = _fichiers[i].withNote(r.note);
    });
    widget.onNoteChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final f = _actuel;
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pages,
                // Une photo agrandie se déplace au doigt : pas de changement de page.
                physics: _zoom ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                itemCount: _fichiers.length,
                onPageChanged: (i) {
                  setState(() {
                    _position = i;
                    _zoom = false;
                  });
                  _anticiper();
                },
                itemBuilder: (_, i) => _PageMedia(
                  key: ValueKey(_fichiers[i].id),
                  file: _fichiers[i],
                  active: i == _position,
                  onZoom: (z) {
                    if (z != _zoom) setState(() => _zoom = z);
                  },
                  onTap: () => setState(() => _barres = !_barres),
                ),
              ),
            ),
            if (_barres) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(color: Colors.white)),
                      Text('${_position + 1} / ${_fichiers.length}',
                          style: context.text.bodySmall?.copyWith(color: Colors.white70)),
                    ],
                  ),
                  actions: [
                    IconButton(
                      tooltip: context.l10n.safeboxOpenWith,
                      onPressed: f.lost ? null : _ouvrirAvec,
                      icon: const Icon(Icons.open_in_new),
                    ),
                  ],
                ),
              ),
              if (f.family == SafeboxFamily.photos && !f.lost)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _Commentaire(key: ValueKey(f.id), file: f, onEdit: _modifierCommentaire),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le commentaire d'une photo, sur fond sombre, sous la photo.
class _Commentaire extends StatelessWidget {
  const _Commentaire({super.key, required this.file, required this.onEdit});
  final SafeboxFile file;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final note = file.note;
    return ColoredBox(
      color: Colors.black54,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (note?.text != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: Text(note!.text!, style: context.text.bodyLarge?.copyWith(color: Colors.white)),
                  ),
                ),
              if (note?.audio != null)
                SafeboxNotePlayer(
                  key: ValueKey(note!.audio!.url),
                  load: () => context.read<SafeboxController>().noteAudioFile(file.id, note.audio!),
                  durationMs: note.audio!.durationMs,
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: Icon(note == null ? Icons.add_comment_outlined : Icons.edit_outlined, size: 18),
                  label: Text(note == null ? l10n.safeboxNoteAdd : l10n.safeboxNoteEdit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageMedia extends StatefulWidget {
  const _PageMedia({
    super.key,
    required this.file,
    required this.active,
    required this.onZoom,
    required this.onTap,
  });

  final SafeboxFile file;
  final bool active;
  final ValueChanged<bool> onZoom;
  final VoidCallback onTap;

  @override
  State<_PageMedia> createState() => _PageMediaState();
}

class _PageMediaState extends State<_PageMedia> {
  final TransformationController _transformation = TransformationController();
  File? _local;
  Object? _erreur;
  bool _telechargement = false;
  bool _rechercheFaite = false;
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _videoIllisible = false;

  SafeboxFile get _f => widget.file;
  bool get _estVideo => _f.family == SafeboxFamily.videos;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_suivreZoom);
    if (!_f.lost) unawaited(_preparer());
  }

  @override
  void didUpdateWidget(_PageMedia old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active || !_estVideo) return;
    if (widget.active) {
      unawaited(_preparer());
    } else {
      // Quitter une vidéo la met en pause.
      _video?.pause();
    }
  }

  @override
  void dispose() {
    _transformation.dispose();
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  void _suivreZoom() {
    if (widget.active) widget.onZoom(_transformation.value.getMaxScaleOnAxis() > 1.01);
  }

  /// Le fichier s'il est déjà là ; sinon le téléchargement, sauf pour une
  /// grosse vidéo ou une vidéo qu'on ne regarde pas.
  Future<void> _preparer() async {
    if (!_rechercheFaite) {
      _rechercheFaite = true;
      File? deja;
      try {
        deja = await context.read<SafeboxController>().downloads.cached(_f);
      } catch (_) {}
      if (!mounted) return;
      if (deja != null) {
        setState(() => _local = deja);
        if (_estVideo && widget.active) await _lancerVideo();
        return;
      }
    }
    if (_local != null) {
      if (_estVideo && widget.active && _video == null) await _lancerVideo();
      return;
    }
    if (_estVideo && (!widget.active || _f.plainBytes > kSafeboxViewerAutoVideoBytes)) {
      if (mounted) setState(() {});
      return;
    }
    await _telecharger();
  }

  Future<void> _telecharger() async {
    if (_telechargement) return;
    setState(() {
      _telechargement = true;
      _erreur = null;
    });
    try {
      final f = await context.read<SafeboxController>().downloads.fetch(_f);
      if (!mounted) return;
      setState(() => _local = f);
      if (_estVideo && widget.active) await _lancerVideo();
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _telechargement = false);
    }
  }

  Future<void> _lancerVideo() async {
    final local = _local;
    if (local == null || _video != null) return;
    final video = VideoPlayerController.file(local);
    _video = video;
    try {
      await video.initialize();
      if (!mounted) return;
      setState(() {
        _chewie = ChewieController(
          videoPlayerController: video,
          autoPlay: widget.active,
          aspectRatio: video.value.aspectRatio,
        );
      });
    } catch (e) {
      debugPrint('[Coffre] vidéo illisible : $e');
      if (mounted) setState(() => _videoIllisible = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_f.lost) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(l10n.safeboxFileLostBody, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    final local = _local;
    if (local != null && !_estVideo) {
      return GestureDetector(
        onTap: widget.onTap,
        child: InteractiveViewer(
          transformationController: _transformation,
          maxScale: 6,
          child: SizedBox.expand(
            child: Image.file(
              local,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Center(child: SafeboxFileThumb(file: _f, size: 160)),
            ),
          ),
        ),
      );
    }
    if (_videoIllisible) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SafeboxFileThumb(file: _f, size: 160),
              AppSpacing.vGapMd,
              Text(l10n.safeboxVideoUnreadable, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    final chewie = _chewie;
    if (chewie != null) {
      // Ses commandes restent loin de l'encoche et de la barre de navigation.
      return SafeArea(child: Chewie(controller: chewie));
    }
    final progres = context.watch<SafeboxController>().downloads.progressOf(_f.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SafeboxFileThumb(file: _f, size: 160),
            AppSpacing.vGapMd,
            if (_erreur != null)
              TextButton(onPressed: _telecharger, child: Text(l10n.safeboxRetry))
            else if (_telechargement || local != null)
              SizedBox(width: 160, child: LinearProgressIndicator(value: progres))
            else if (_estVideo && _rechercheFaite)
              FilledButton.icon(
                onPressed: _telecharger,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.safeboxVideoPlay(formatBytes(_f.plainBytes, l10n))),
              ),
          ],
        ),
      ),
    );
  }
}
