// Écran 5 : la visionneuse. Fond sombre, le fichier au centre, son
// commentaire en bas. ← → pour passer d'un fichier à l'autre, molette pour
// zoomer, Échap pour fermer.
//
// Les photos s'affichent ici ; vidéos et audios se lisent ici aussi, en
// continu, sans attendre la fin du téléchargement (media_kit, servi par
// VaultStreamServer, 14/11/2026) ; les documents s'ouvrent avec le logiciel
// de l'ordinateur.

import 'dart:async';
import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../core/vault.dart';
import '../ui/common.dart';
import '../ui/system.dart';

Future<void> openViewer(BuildContext context, List<SafeboxFile> files, int index) => Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => ViewerScreen(files: files, initialIndex: index),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.files, required this.initialIndex});
  final List<SafeboxFile> files;
  final int initialIndex;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final List<SafeboxFile> _fichiers = List.of(widget.files);
  late int _i = widget.initialIndex;
  final _focus = FocusNode();

  SafeboxFile get _f => _fichiers[_i];

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _aller(int delta) {
    final n = _i + delta;
    if (n < 0 || n >= _fichiers.length) return;
    setState(() => _i = n);
  }

  Future<void> _telecharger() async {
    final l = context.l;
    final messager = ScaffoldMessenger.of(context);
    final chemin = await context.vault.exporter.saveFile(_f);
    if (!mounted) return;
    messager.showSnackBar(SnackBar(
      content: Text(chemin == null ? l.downloadFailed : l.downloadSaved(chemin)),
      action: chemin == null ? null : SnackBarAction(label: l.showInFolder, onPressed: () => showInFolder(chemin)),
    ));
  }

  Future<void> _ouvrirAvec() async {
    final l = context.l;
    final messager = ScaffoldMessenger.of(context);
    try {
      final f = await context.vault.downloads.fetch(_f);
      final ok = await openWithSystem(f.path);
      if (!ok && mounted) messager.showSnackBar(SnackBar(content: Text(l.openFailed)));
    } catch (e) {
      if (mounted) messager.showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  Future<void> _modifierCommentaire() async {
    final l = context.l;
    final vault = context.vault;
    final messager = ScaffoldMessenger.of(context);
    final controle = TextEditingController(text: _f.note?.text ?? '');
    final texte = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.noteEditTitle),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controle,
            autofocus: true,
            maxLength: SafeboxNote.textMax,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(hintText: l.noteHint, border: const OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controle.text.trim()), child: Text(l.save)),
        ],
      ),
    );
    controle.dispose();
    if (texte == null) return;
    final fichier = _f;
    try {
      final note = await vault.setNoteText(fichier.id, texte.isEmpty ? null : texte);
      if (!mounted) return;
      setState(() {
        final i = _fichiers.indexWhere((x) => x.id == fichier.id);
        if (i >= 0) _fichiers[i] = fichier.withNote(note);
      });
    } catch (e) {
      if (mounted) messager.showSnackBar(SnackBar(content: Text(errorText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final f = _f;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = f.createdAt == null ? null : DateFormat.yMMMMd(locale).format(f.createdAt!);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _aller(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _aller(1),
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF0E0F13),
          body: Column(children: [
            Container(
              color: const Color(0xFF16171D),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                IconButton(
                  tooltip: l.close,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(
                      [l.viewerPosition(_i + 1, _fichiers.length), formatBytes(context, f.plainBytes), ?date].join(' · '),
                      style: const TextStyle(color: Color(0xFFB8BBC8), fontSize: 13),
                    ),
                  ]),
                ),
                _BoutonSombre(icon: Icons.download_outlined, label: l.download, onPressed: f.lost ? null : _telecharger),
                const SizedBox(width: 8),
                _BoutonSombre(icon: Icons.open_in_new, label: l.openWith, onPressed: f.lost ? null : _ouvrirAvec),
              ]),
            ),
            Expanded(
              child: Row(children: [
                _Fleche(icon: Icons.chevron_left, tooltip: l.previous, onPressed: _i > 0 ? () => _aller(-1) : null),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _Contenu(key: ValueKey(f.id), file: f, onOpenWith: _ouvrirAvec),
                  ),
                ),
                _Fleche(icon: Icons.chevron_right, tooltip: l.next, onPressed: _i < _fichiers.length - 1 ? () => _aller(1) : null),
              ]),
            ),
            _Pied(file: f, onEdit: _modifierCommentaire),
          ]),
        ),
      ),
    );
  }
}

/// Le fichier lui-même : la photo (zoom à la molette), sinon son aperçu et
/// « Ouvrir avec… ».
class _Contenu extends StatefulWidget {
  const _Contenu({super.key, required this.file, required this.onOpenWith});
  final SafeboxFile file;
  final VoidCallback onOpenWith;

  @override
  State<_Contenu> createState() => _ContenuState();
}

class _ContenuState extends State<_Contenu> {
  Uint8List? _apercu;
  File? _complet;
  Object? _erreur;
  bool _illisible = false;
  late Vault _vault;

  bool get _photo => widget.file.family == SafeboxFamily.photos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vault = context.vault;
    if (_apercu == null) _charger();
  }

  Future<void> _charger() async {
    final f = widget.file;
    _apercu = _vault.previews.peek(f.id);
    if (_apercu == null && f.previewUrl != null) {
      _vault.previews.load(f).then((b) {
        if (mounted && b != null) setState(() => _apercu = b);
      });
    }
    if (!_photo || f.lost) return;
    try {
      final complet = await _vault.downloads.fetch(f);
      if (mounted) setState(() => _complet = complet);
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final f = widget.file;
    if (f.lost) return _Message(icon: Icons.report_outlined, text: l.fileLost);
    if (f.family == SafeboxFamily.videos || f.family == SafeboxFamily.audios) {
      return _Lecteur(key: ValueKey('lecteur-${f.id}'), file: f, apercu: _apercu, onOpenWith: widget.onOpenWith);
    }
    if (_photo) {
      final complet = _complet;
      if (complet != null && !_illisible) {
        return InteractiveViewer(
          maxScale: 8,
          child: Center(
            child: Image.file(
              complet,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                // Format que l'ordinateur ne sait pas afficher (HEIC…).
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _illisible = true);
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      }
      return Stack(alignment: Alignment.center, children: [
        if (_apercu != null) Center(child: Image.memory(_apercu!, fit: BoxFit.contain, gaplessPlayback: true)),
        if (_illisible)
          _Message(icon: Icons.image_not_supported_outlined, text: l.viewerCannotShow, action: l.openWith, onAction: widget.onOpenWith)
        else if (_erreur != null)
          _Message(icon: Icons.cloud_off_outlined, text: errorText(context, _erreur), action: l.retry, onAction: () {
            setState(() => _erreur = null);
            _charger();
          })
        else
          ListenableBuilder(
            listenable: _vault.downloads,
            builder: (context, _) {
              final p = _vault.downloads.progressOf(f.id);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(40)),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(value: p, color: Colors.white, strokeWidth: 3),
                ),
              );
            },
          ),
      ]);
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 320,
          height: 240,
          child: _apercu != null
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_apercu!, fit: BoxFit.cover))
              : Icon(familyIcon(f.family), size: 96, color: const Color(0xFF9FA8DA)),
        ),
        const SizedBox(height: 20),
        Text(
          switch (f.family) {
            SafeboxFamily.videos => l.viewerVideoHint,
            SafeboxFamily.audios => l.viewerAudioHint,
            _ => l.viewerDocumentHint,
          },
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB8BBC8)),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _vault.downloads,
          builder: (context, _) {
            final p = _vault.downloads.progressOf(f.id);
            if (p != null) {
              return SizedBox(width: 240, child: LinearProgressIndicator(value: p, color: Colors.white, backgroundColor: const Color(0xFF3A3D4A)));
            }
            return FilledButton.icon(
              onPressed: widget.onOpenWith,
              icon: Icon(f.family == SafeboxFamily.documents ? Icons.open_in_new : Icons.play_arrow),
              label: Text(f.family == SafeboxFamily.documents ? l.openWith : l.viewerPlay),
            );
          },
        ),
      ]),
    );
  }
}

class _Pied extends StatelessWidget {
  const _Pied({required this.file, required this.onEdit});
  final SafeboxFile file;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final note = file.note;
    return Container(
      color: const Color(0xFF16171D),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (note?.text != null)
                Text(note!.text!, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5))
              else if (note?.audio == null)
                Text(l.noteNone, style: const TextStyle(color: Color(0xFF9396A3))),
              if (note?.audio != null) ...[
                const SizedBox(height: 8),
                _AudioCommentaire(key: ValueKey('audio-${file.id}'), fileId: file.id, audio: note!.audio!),
              ],
            ]),
          ),
          const SizedBox(width: 16),
          _BoutonSombre(icon: Icons.edit_outlined, label: note?.text == null ? l.noteAdd : l.noteEdit, onPressed: onEdit),
        ]),
        const SizedBox(height: 10),
        Text(l.viewerKeys, style: const TextStyle(color: Color(0xFF9396A3), fontSize: 12)),
      ]),
    );
  }
}

/// L'audio d'un commentaire : déchiffré à la demande, écouté ici.
class _AudioCommentaire extends StatefulWidget {
  const _AudioCommentaire({super.key, required this.fileId, required this.audio});
  final int fileId;
  final SafeboxNoteAudio audio;

  @override
  State<_AudioCommentaire> createState() => _AudioCommentaireState();
}

class _AudioCommentaireState extends State<_AudioCommentaire> {
  bool _charge = false;
  Player? _lecteur;
  bool _enLecture = false;
  StreamSubscription<bool>? _suivi;

  @override
  void dispose() {
    _suivi?.cancel();
    _lecteur?.dispose();
    super.dispose();
  }

  Future<void> _ecouter() async {
    final lecteur = _lecteur;
    if (lecteur != null) {
      await lecteur.playOrPause();
      return;
    }
    final messager = ScaffoldMessenger.of(context);
    setState(() => _charge = true);
    try {
      final f = await context.vault.noteAudioFile(widget.fileId, widget.audio);
      if (!mounted) return;
      final p = Player();
      _lecteur = p;
      _suivi = p.stream.playing.listen((oui) {
        if (mounted) setState(() => _enLecture = oui);
      });
      await p.open(Media(f.path));
    } catch (e) {
      if (mounted) messager.showSnackBar(SnackBar(content: Text(errorText(context, e))));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _charge
            ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            : IconButton.filled(
                tooltip: context.l.noteListen,
                style: IconButton.styleFrom(backgroundColor: Palette.brand),
                onPressed: _ecouter,
                icon: Icon(_enLecture ? Icons.pause : Icons.play_arrow, color: Colors.white),
              ),
        const SizedBox(width: 10),
        Text('${context.l.noteAudio} · ${widget.audio.durationLabel}', style: const TextStyle(color: Color(0xFFB8BBC8), fontSize: 13)),
      ]);
}

/// Une vidéo ou un audio, lu en continu depuis le coffre (VaultStreamServer) :
/// la lecture commence dès le premier bloc, on peut avancer sans attendre.
class _Lecteur extends StatefulWidget {
  const _Lecteur({super.key, required this.file, required this.apercu, required this.onOpenWith});
  final SafeboxFile file;
  final Uint8List? apercu;
  final VoidCallback onOpenWith;

  @override
  State<_Lecteur> createState() => _LecteurState();
}

class _LecteurState extends State<_Lecteur> {
  late final Player _lecteur = Player();
  late final VideoController _video = VideoController(_lecteur);
  Uri? _adresse;
  late Vault _vault;
  Object? _erreur;
  StreamSubscription<String>? _erreurs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_adresse == null && _erreur == null) {
      _vault = context.vault;
      unawaited(_ouvrir());
    }
  }

  Future<void> _ouvrir() async {
    try {
      final adresse = await _vault.streams.open(widget.file);
      if (!mounted) {
        _vault.streams.release(adresse);
        return;
      }
      _adresse = adresse;
      _erreurs = _lecteur.stream.error.listen((e) {
        if (mounted) setState(() => _erreur = e);
      });
      await _lecteur.open(Media(adresse.toString()));
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  @override
  void dispose() {
    _erreurs?.cancel();
    unawaited(_lecteur.dispose());
    final a = _adresse;
    if (a != null) _vault.streams.release(a);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    if (_erreur != null) {
      return _Message(icon: Icons.play_disabled_outlined, text: l.viewerCannotShow, action: l.openWith, onAction: widget.onOpenWith);
    }
    final audio = widget.file.family == SafeboxFamily.audios;
    return Stack(fit: StackFit.expand, children: [
      // Un audio n'a pas d'image : sa pochette (l'aperçu) sous les commandes.
      if (audio)
        Center(
          child: widget.apercu != null
              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(widget.apercu!, width: 320, height: 320, fit: BoxFit.cover))
              : const Icon(Icons.music_note, size: 120, color: Color(0xFF9FA8DA)),
        ),
      Video(controller: _video, fill: audio ? Colors.transparent : Colors.black),
    ]);
  }
}

class _BoutonSombre extends StatelessWidget {
  const _BoutonSombre({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF5B5F6E),
          side: const BorderSide(color: Color(0xFF3A3D4A)),
          minimumSize: const Size(0, 40),
        ),
      );
}

class _Fleche extends StatelessWidget {
  const _Fleche({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IconButton.filled(
          tooltip: tooltip,
          onPressed: onPressed,
          iconSize: 28,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF22242C),
            disabledBackgroundColor: const Color(0x0022242C),
            foregroundColor: Colors.white,
            disabledForegroundColor: const Color(0x00FFFFFF),
            minimumSize: const Size(52, 52),
          ),
          icon: Icon(icon),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action, this.onAction});
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xCC16171D), borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: const Color(0xFF9FA8DA)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ]),
      );
}
