// Enregistrer des fichiers du coffre sur l'ordinateur (dossier des
// téléchargements), un à un, avec l'avancement. Un dossier garde son
// arborescence.

import 'dart:async';
import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Le dossier où vont les fichiers enregistrés.
class DownloadFolder {
  static const _cle = 'coffre_download_dir';

  static Future<Directory> get() async {
    final prefs = await SharedPreferences.getInstance();
    final choisi = prefs.getString(_cle);
    if (choisi != null && choisi.isNotEmpty) return Directory(choisi);
    final base = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    return Directory('${base.path}${Platform.pathSeparator}Alanya');
  }

  static Future<void> set(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, path);
  }
}

enum ExportState { running, done, failed, cancelled }

class ExportTask {
  ExportTask({required this.label, required this.destination});

  /// Nom du fichier ou du dossier enregistré.
  final String label;

  /// Où il arrive (le fichier, ou le dossier pour un dossier).
  String destination;
  int filesTotal = 0;
  int filesDone = 0;
  int bytesTotal = 0;
  int bytesDone = 0;
  ExportState state = ExportState.running;
  Object? error;

  double get progress => bytesTotal <= 0 ? 0 : (bytesDone / bytesTotal).clamp(0.0, 1.0);
}

class Exporter extends ChangeNotifier {
  Exporter({required this.api, required this.downloads, Future<Directory> Function()? folder})
      : _dossier = folder ?? DownloadFolder.get;

  final SafeboxCalls api;
  final SafeboxDownloadManager downloads;
  final Future<Directory> Function() _dossier;

  ExportTask? _tache;
  bool _arret = false;
  final List<Future<void> Function()> _file = [];
  bool _enCours = false;

  /// La tâche en cours, ou la dernière terminée (jusqu'à ce qu'on la ferme).
  ExportTask? get task => _tache;

  void dismiss() {
    if (_tache?.state == ExportState.running) return;
    _tache = null;
    notifyListeners();
  }

  /// Arrête après le fichier en cours.
  void cancel() => _arret = true;

  /// Enregistre un fichier ; rend le chemin écrit.
  Future<String?> saveFile(SafeboxFile file) {
    final c = Completer<String?>();
    _ajouter(() async {
      final dossier = await _dossier();
      final t = ExportTask(label: file.name, destination: dossier.path)
        ..filesTotal = 1
        ..bytesTotal = file.plainBytes;
      await _executer(t, () async {
        final chemin = await _enregistrer(t, file, dossier);
        t.destination = chemin;
        c.complete(chemin);
      });
      if (!c.isCompleted) c.complete(null);
    });
    return c.future;
  }

  /// Enregistre un dossier entier, sous-dossiers compris, sous [name].
  Future<void> saveFolder(int folderId, String name) {
    final c = Completer<void>();
    _ajouter(() async {
      final base = await _dossier();
      final racine = Directory(_libre('${base.path}${Platform.pathSeparator}${safeboxLocalName(name)}', dossier: true));
      final t = ExportTask(label: name, destination: racine.path);
      await _executer(t, () async {
        final liste = <(SafeboxFile, Directory)>[];
        await _lister(folderId, racine, liste);
        t
          ..filesTotal = liste.length
          ..bytesTotal = liste.fold(0, (s, e) => s + e.$1.plainBytes);
        notifyListeners();
        for (final (f, d) in liste) {
          if (_arret) {
            t.state = ExportState.cancelled;
            return;
          }
          await _enregistrer(t, f, d);
        }
      });
      c.complete();
    });
    return c.future;
  }

  void _ajouter(Future<void> Function() travail) {
    _file.add(travail);
    if (!_enCours) _suivant();
  }

  Future<void> _suivant() async {
    _enCours = true;
    while (_file.isNotEmpty) {
      await _file.removeAt(0)();
    }
    _enCours = false;
  }

  Future<void> _executer(ExportTask t, Future<void> Function() travail) async {
    _arret = false;
    _tache = t;
    notifyListeners();
    try {
      await travail();
      if (t.state == ExportState.running) t.state = ExportState.done;
    } catch (e) {
      debugPrint('[Coffre] enregistrement de ${t.label} : $e');
      t
        ..state = ExportState.failed
        ..error = e;
    }
    notifyListeners();
  }

  Future<void> _lister(int folderId, Directory ici, List<(SafeboxFile, Directory)> out) async {
    int? curseur;
    final sousDossiers = <SafeboxFolder>[];
    do {
      final p = await api.fetchSafeboxFolder(folderId, cursor: curseur);
      if (curseur == null) sousDossiers.addAll(p.folders);
      for (final f in p.files) {
        if (!f.lost) out.add((f, ici));
      }
      curseur = p.nextCursor;
    } while (curseur != null);
    for (final s in sousDossiers) {
      await _lister(s.id, Directory('${ici.path}${Platform.pathSeparator}${safeboxLocalName(s.name ?? '${s.id}')}'), out);
    }
  }

  /// Télécharge (ou reprend la copie déjà là) puis copie dans [dossier].
  /// Une copie faite pour l'occasion quitte le cache aussitôt : un gros
  /// fichier n'occupe pas deux fois le disque.
  Future<String> _enregistrer(ExportTask t, SafeboxFile f, Directory dossier) async {
    final avant = t.bytesDone;
    final dejaLa = await downloads.cached(f) != null;
    void suivre() {
      final p = downloads.progressOf(f.id);
      if (p != null) {
        t.bytesDone = avant + (p * f.plainBytes).round();
        notifyListeners();
      }
    }

    downloads.addListener(suivre);
    try {
      final source = await downloads.fetch(f);
      await dossier.create(recursive: true);
      final cible = _libre('${dossier.path}${Platform.pathSeparator}${safeboxLocalName(f.name)}');
      await source.copy(cible);
      if (!dejaLa) await downloads.evict(f.id);
      t
        ..bytesDone = avant + f.plainBytes
        ..filesDone += 1;
      notifyListeners();
      return cible;
    } finally {
      downloads.removeListener(suivre);
    }
  }

  /// « photo.jpg », sinon « photo (2).jpg », « photo (3).jpg »…
  static String _libre(String chemin, {bool dossier = false}) {
    bool existe(String c) => dossier ? Directory(c).existsSync() : File(c).existsSync() || Directory(c).existsSync();
    if (!existe(chemin)) return chemin;
    final sep = chemin.lastIndexOf(Platform.pathSeparator);
    final nom = chemin.substring(sep + 1);
    final point = dossier ? -1 : nom.lastIndexOf('.');
    final base = point > 0 ? nom.substring(0, point) : nom;
    final ext = point > 0 ? nom.substring(point) : '';
    for (var i = 2;; i++) {
      final c = '${chemin.substring(0, sep + 1)}$base ($i)$ext';
      if (!existe(c)) return c;
    }
  }
}
