import 'dart:async';
import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';

import 'desktop_api.dart';
import 'exporter.dart';
import 'importer.dart';
import 'photo_preview.dart';

/// L'état du coffre pour les écrans : espace, dossiers racines, albums
/// récents, aperçus, fichiers ouverts et enregistrés, envois.
class Vault extends ChangeNotifier {
  Vault(this.api, {Future<Directory> Function()? baseDir, SafeboxJobStore? jobStore})
      : _baseDir = baseDir ?? safeboxLocalDir,
        _magasin = _MagasinFerme(jobStore ?? PrefsSafeboxJobStore()),
        previews = SafeboxPreviewCache(transport: ApiSafeboxDownloadTransport(api), baseDir: baseDir),
        downloads = SafeboxDownloadManager(transport: ApiSafeboxDownloadTransport(api), baseDir: baseDir) {
    exporter = Exporter(api: api, downloads: downloads);
    uploads = SafeboxUploadManager(transport: ApiSafeboxTransport(api), store: _magasin);
    importer = Importer(
      api: api,
      enqueue: uploads.enqueue,
      workDir: () async => Directory('${(await _baseDir()).path}${Platform.pathSeparator}work'),
      photoPreview: makePhotoPreview,
    );
    _fin = uploads.completed.listen(_arrive);
    // Les envois gardés d'une session précédente repartent ; ceux qui
    // attendaient le réseau sont relancés de temps en temps.
    unawaited(uploads.resumeAll());
    _relance = Timer.periodic(const Duration(minutes: 1), (_) {
      if (uploads.jobs.any((j) => j.state == SafeboxUploadState.waitingNetwork)) unawaited(uploads.resumeAll());
    });
  }

  final DesktopApi api;
  final Future<Directory> Function() _baseDir;
  final SafeboxPreviewCache previews;

  /// Les fichiers ouverts dans la visionneuse : copies en clair gardées dans
  /// le dossier de l'application, jusqu'à « Vider » ou la déconnexion.
  final SafeboxDownloadManager downloads;
  late final Exporter exporter;

  /// Les envois vers le coffre (paquet commun, comme le téléphone).
  late final SafeboxUploadManager uploads;
  late final Importer importer;
  final _MagasinFerme _magasin;
  late final StreamSubscription<SafeboxFile> _fin;
  late final Timer _relance;
  Timer? _rafraichir;

  final StreamController<int> _changes = StreamController<int>.broadcast();

  /// Un dossier a reçu des fichiers (envoi terminé, ajout sans copie) : son
  /// écran se recharge.
  Stream<int> get folderChanges => _changes.stream;

  void folderChanged(int folderId) {
    if (!_changes.isClosed) _changes.add(folderId);
    _rafraichirBientot();
  }

  void _arrive(SafeboxFile f) => folderChanged(f.folderId);

  /// L'espace utilisé change : un seul rafraîchissement pour une rafale.
  void _rafraichirBientot() {
    _rafraichir?.cancel();
    _rafraichir = Timer(const Duration(seconds: 2), refresh);
  }

  SafeboxOverview? _overview;
  List<SafeboxRecentAlbum> _albums = const [];
  Object? _error;
  bool _loading = false;

  SafeboxOverview? get overview => _overview;
  List<SafeboxRecentAlbum> get recentAlbums => _albums;
  Object? get error => _error;
  bool get loading => _loading;

  int? rootId(SafeboxRoot r) => _overview?.rootIds[r];

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final o = await api.fetchSafebox();
      _overview = o;
      _error = null;
      try {
        _albums = await api.fetchSafeboxRecentAlbums(limit: 4);
      } catch (_) {
        _albums = const [];
      }
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SafeboxFolderPage> folder(int id, {int? cursor}) => api.fetchSafeboxFolder(id, cursor: cursor);

  /// Le commentaire d'un fichier change (le serveur rend le nouveau).
  Future<SafeboxNote?> setNoteText(int fileId, String? text) => api.setSafeboxNoteText(fileId, text);

  /// L'audio d'un commentaire, déchiffré dans le dossier de l'application.
  Future<File> noteAudioFile(int fileId, SafeboxNoteAudio audio) async {
    final f = File('${(await _baseDir()).path}/notes/$fileId-${audio.plainBytes}.m4a');
    if (await f.exists() && await f.length() == audio.plainBytes) return f;
    final clair = await api.fetchSafeboxNoteAudio(audio);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(clair, flush: true);
    return f;
  }

  Iterable<Directory> _gardes(Directory base) => [Directory('${base.path}/files'), Directory('${base.path}/notes')];

  /// La place prise par les fichiers gardés pour la visionneuse.
  Future<int> keptBytes() async {
    final base = await _baseDir();
    var total = 0;
    for (final d in _gardes(base)) {
      if (!await d.exists()) continue;
      await for (final e in d.list(recursive: true)) {
        if (e is File) total += await e.length();
      }
    }
    return total;
  }

  /// « Vider » : les copies en clair partent ; elles se retéléchargent au besoin.
  Future<void> clearKept() async {
    final base = await _baseDir();
    for (final d in _gardes(base)) {
      if (await d.exists()) await d.delete(recursive: true);
    }
  }

  /// Déconnexion : les envois s'arrêtent et la liste gardée sur l'ordinateur
  /// ne se réécrit plus (elle va être effacée).
  Future<void> close() async {
    if (_magasin.closed) return;
    _relance.cancel();
    await uploads.pauseAll();
    _magasin.closed = true;
  }

  @override
  void dispose() {
    _magasin.closed = true;
    _relance.cancel();
    _rafraichir?.cancel();
    unawaited(_fin.cancel());
    unawaited(_changes.close());
    unawaited(uploads.pauseAll());
    importer.dispose();
    exporter.dispose();
    downloads.dispose();
    super.dispose();
  }
}

/// Le magasin des envois, muet une fois le coffre fermé.
class _MagasinFerme implements SafeboxJobStore {
  _MagasinFerme(this._s);
  final SafeboxJobStore _s;
  bool closed = false;

  @override
  Future<List<SafeboxUploadJob>> loadJobs() async => closed ? const [] : _s.loadJobs();
  @override
  Future<void> saveJobs(List<SafeboxUploadJob> jobs) async {
    if (!closed) await _s.saveJobs(jobs);
  }

  @override
  Future<Uint8List?> loadKey(String jobId) async => closed ? null : _s.loadKey(jobId);
  @override
  Future<void> saveKey(String jobId, Uint8List key) async {
    if (!closed) await _s.saveKey(jobId, key);
  }

  @override
  Future<void> deleteKey(String jobId) async {
    if (!closed) await _s.deleteKey(jobId);
  }
}
