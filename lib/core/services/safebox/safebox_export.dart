//  Télécharger depuis le coffre vers le téléphone (lot 8) : une sélection ou
//  un dossier entier, vers la galerie ou dans un seul fichier ZIP.
//
//  - Galerie : les photos et vidéos vont dans l'album « Alanya » de la
//    galerie ; les autres fichiers (musique, documents), qui n'y ont pas leur
//    place, dans Téléchargements/Alanya, rangés comme les médias reçus.
//  - ZIP : un seul fichier dans Téléchargements/Alanya, médias en mode stocké
//    (déjà compressés, voir export_zip_builder.dart).
//
//  Les fichiers sont déchiffrés sur le téléphone, un par un ; la copie
//  déchiffrée faite pour l'occasion est effacée aussitôt copiée, pour ne pas
//  doubler la place prise. Un téléchargement à la fois : les suivants
//  attendent leur tour.

import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'safebox_models.dart';
import 'safebox_received_files.dart';

enum SafeboxExportTarget { gallery, zip }

enum SafeboxExportState { queued, running, done, failed, cancelled }

/// Copie un fichier déchiffré dans la galerie (album « Alanya »).
typedef SafeboxSaveToGallery = Future<void> Function(String path, SafeboxFamily family);

class SafeboxExportTask {
  SafeboxExportTask({required this.id, required this.title, required this.files, required this.target});

  final String id;

  /// Ce que l'inscrit a demandé : « 5 photos », « Kribi 2026 ».
  final String title;
  final List<SafeboxFile> files;
  final SafeboxExportTarget target;

  SafeboxExportState state = SafeboxExportState.queued;
  int done = 0;
  int bytesDone = 0;

  /// Part du fichier en cours, entre 0 et 1.
  double current = 0;

  /// Fichiers qui n'ont pas pu être copiés (contenu perdu, erreur).
  int skipped = 0;
  bool _annule = false;

  int get totalBytes => files.fold(0, (s, f) => s + f.plainBytes);

  double get progress {
    final total = totalBytes;
    if (total <= 0) return done >= files.length ? 1 : 0;
    final enCours = done < files.length ? files[done].plainBytes * current : 0;
    return ((bytesDone + enCours) / total).clamp(0.0, 1.0);
  }

  bool get finished =>
      state == SafeboxExportState.done || state == SafeboxExportState.failed || state == SafeboxExportState.cancelled;
}

class SafeboxExporter extends ChangeNotifier {
  SafeboxExporter({
    required Future<File> Function(SafeboxFile file) fetch,
    required Future<File?> Function(SafeboxFile file) cached,
    required Future<void> Function(int fileId) evict,
    required double? Function(int fileId) progressOf,
    SafeboxSaveToGallery? toGallery,
    SafeboxPublish? toDownloads,
    Future<Directory> Function()? workDir,
  })  : _fetch = fetch,
        _cached = cached,
        _evict = evict,
        _progressOf = progressOf,
        _versGalerie = toGallery ?? _galerieDuTelephone,
        _versTelechargements = toDownloads ?? SafeboxReceivedFiles.saveToDownloads,
        _dossier = workDir ?? getTemporaryDirectory;

  final Future<File> Function(SafeboxFile) _fetch;
  final Future<File?> Function(SafeboxFile) _cached;
  final Future<void> Function(int) _evict;
  final double? Function(int) _progressOf;
  final SafeboxSaveToGallery _versGalerie;
  final SafeboxPublish _versTelechargements;
  final Future<Directory> Function() _dossier;

  final List<SafeboxExportTask> _taches = [];
  Future<void> _file = Future<void>.value();
  static int _seq = 0;

  List<SafeboxExportTask> get tasks => List.unmodifiable(_taches);

  /// Lance un téléchargement ; il démarre quand les précédents sont finis.
  SafeboxExportTask start(List<SafeboxFile> files, {required SafeboxExportTarget target, required String title}) {
    final t = SafeboxExportTask(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_seq++}',
      title: title,
      files: files.where((f) => !f.lost).toList(),
      target: target,
    );
    _taches.add(t);
    notifyListeners();
    _file = _file.then((_) => _executer(t));
    return t;
  }

  /// Arrête un téléchargement : entre deux fichiers, ce qui est copié reste.
  void cancel(SafeboxExportTask t) {
    t._annule = true;
    if (t.state == SafeboxExportState.queued) {
      t.state = SafeboxExportState.cancelled;
      notifyListeners();
    }
  }

  void clearFinished() {
    _taches.removeWhere((t) => t.finished);
    notifyListeners();
  }

  /// Le progrès du fichier en cours suit celui du gestionnaire de téléchargements.
  void refresh() {
    for (final t in _taches.where((t) => t.state == SafeboxExportState.running)) {
      if (t.done < t.files.length) t.current = _progressOf(t.files[t.done].id) ?? t.current;
    }
  }

  Future<void> _executer(SafeboxExportTask t) async {
    if (t._annule) return;
    t.state = SafeboxExportState.running;
    notifyListeners();
    ZipFileEncoder? zip;
    File? archive;
    final noms = <String>{};
    var fin = SafeboxExportState.failed;
    try {
      if (t.target == SafeboxExportTarget.zip) {
        final d = await _dossier();
        archive = File(p.join(d.path, 'coffre_${t.id}.zip'));
        zip = ZipFileEncoder()..create(archive.path);
      }
      for (final f in t.files) {
        if (t._annule) break;
        t.current = 0;
        final deja = await _cached(f);
        try {
          final clair = deja ?? await _fetch(f);
          if (zip != null) {
            await _ajouterAuZip(zip, clair, _nomUnique(f.name, noms));
          } else if (f.family == SafeboxFamily.photos || f.family == SafeboxFamily.videos) {
            await _versGalerie(clair.path, f.family);
          } else {
            final loc = await _versTelechargements(
              clair.path,
              f.name,
              SafeboxReceivedFiles.mimeFor(f.name, f.mime),
              SafeboxReceivedFiles.subdirFor(f.family),
            );
            if (loc == null) throw StateError('copie refusée');
          }
          // La copie déchiffrée faite pour l'occasion ne reste pas.
          if (deja == null) await _evict(f.id);
        } catch (e) {
          debugPrint('[Coffre] ${f.name} non téléchargé : $e');
          t.skipped += 1;
        }
        t
          ..done += 1
          ..bytesDone += f.plainBytes
          ..current = 0;
        notifyListeners();
      }
      if (zip != null) {
        await zip.close();
        zip = null;
        if (!t._annule && t.done > t.skipped) {
          final loc = await _versTelechargements(archive!.path, '${_nomFichier(t.title)}.zip', 'application/zip', 'Alanya');
          if (loc == null) throw StateError('copie du ZIP refusée');
        }
      }
      fin = t._annule
          ? SafeboxExportState.cancelled
          : (t.skipped == t.files.length && t.files.isNotEmpty ? SafeboxExportState.failed : SafeboxExportState.done);
    } catch (e) {
      debugPrint('[Coffre] téléchargement « ${t.title} » arrêté : $e');
    } finally {
      try {
        await zip?.close();
      } catch (_) {}
      // L'archive temporaire part avant d'annoncer la fin.
      try {
        if (archive != null && await archive.exists()) await archive.delete();
      } catch (_) {}
      t.state = fin;
      notifyListeners();
    }
  }

  /// Contenu lu en flux, en mode stocké.
  Future<void> _ajouterAuZip(ZipFileEncoder zip, File file, String nom) async {
    final flux = InputFileStream(file.path);
    try {
      zip.addArchiveFile(ArchiveFile.stream(nom, flux)
        ..compression = CompressionType.none
        ..lastModTime = (await file.lastModified()).millisecondsSinceEpoch ~/ 1000);
    } finally {
      await flux.close();
    }
  }

  static Future<void> _galerieDuTelephone(String path, SafeboxFamily family) async {
    if (!await Gal.hasAccess(toAlbum: true)) await Gal.requestAccess(toAlbum: true);
    if (family == SafeboxFamily.videos) {
      await Gal.putVideo(path, album: 'Alanya');
    } else {
      await Gal.putImage(path, album: 'Alanya');
    }
  }
}

/// Deux fichiers du même nom dans un ZIP : « Plage (2).jpg ».
String _nomUnique(String nom, Set<String> pris) {
  var candidat = nom;
  final base = p.basenameWithoutExtension(nom);
  final ext = p.extension(nom);
  for (var i = 2; pris.contains(candidat.toLowerCase()); i += 1) {
    candidat = '$base ($i)$ext';
  }
  pris.add(candidat.toLowerCase());
  return candidat;
}

/// Un titre en nom de fichier : sans séparateurs ni caractères interdits.
String _nomFichier(String titre) {
  final propre = titre.replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return propre.isEmpty ? 'Coffre-fort' : propre;
}

@visibleForTesting
String safeboxZipEntryName(String nom, Set<String> pris) => _nomUnique(nom, pris);

@visibleForTesting
String safeboxZipFileName(String titre) => _nomFichier(titre);
