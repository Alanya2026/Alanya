import 'dart:async';
import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';

import 'desktop_api.dart';
import 'exporter.dart';
import 'importer.dart';
import 'pc_backup.dart';
import 'photo_preview.dart';

/// L'état du coffre pour les écrans : espace, dossiers racines, albums
/// récents, aperçus, fichiers ouverts et enregistrés, envois.
class Vault extends ChangeNotifier {
  Vault(this.api, {Future<Directory> Function()? baseDir, SafeboxJobStore? jobStore, SafeboxBackupStore? backupStore})
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
    pcBackup = PcBackup(
      api: _ApiSauvegarde(api),
      enqueue: _envoyerSauvegarde,
      freeSpace: _espaceLibre,
      limits: () => _overview?.limits,
      jobAlive: (id) async => uploads.jobs.any((j) => j.id == id && _enRoute(j)),
      discardJob: uploads.cancel,
      refreshOverview: refresh,
      store: backupStore,
      calls: api,
      albumsRoot: () => _overview?.rootIds[SafeboxRoot.albums],
    );
    _fin = uploads.completed.listen(_arrive);
    _finSauvegarde = uploads.completedJobs.listen((e) {
      final cle = e.job.backupKey;
      if (cle != null) unawaited(pcBackup.markSaved(cle));
    });
    unawaited(pcBackup.start());
    // Les fichiers ouverts dans la visionneuse : ramenés sous la limite au
    // démarrage, puis un peu après chaque téléchargement.
    downloads.addListener(_trierBientot);
    unawaited(trimKept());
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

  /// La sauvegarde des dossiers du PC (D6).
  late final PcBackup pcBackup;
  late final StreamSubscription<({SafeboxUploadJob job, SafeboxFile file})> _finSauvegarde;

  static bool _enRoute(SafeboxUploadJob j) =>
      j.state != SafeboxUploadState.failed && j.state != SafeboxUploadState.completed;

  /// Place libre du coffre, envois en cours déduits ; null si inconnue.
  Future<int?> _espaceLibre() async {
    final q = _overview?.quota;
    if (q == null) return null;
    final enRoute = uploads.jobs.where(_enRoute).fold<int>(0, (s, j) => s + (j.storedSize - j.sentBytes).clamp(0, 1 << 62));
    return (q.quotaBytes - q.usedBytes - enRoute).clamp(0, 1 << 62);
  }

  /// Un fichier de la sauvegarde du PC part dans la racine de son type.
  Future<String?> _envoyerSauvegarde(SafeboxBackupUpload u) async {
    // L'ordinateur ne compresse pas : ce que le moteur voudrait en HD (vidéo
    // plus lourde que la limite) attend.
    if (u.quality != SafeboxQuality.original) return null;
    final o = _overview;
    final dossier = o?.rootIds[u.item.family.root];
    if (o == null || dossier == null) return null;
    try {
      return await importer.enqueueFile(
        path: u.file.path,
        name: u.item.name,
        family: u.item.family,
        folderId: dossier,
        limits: o.limits,
        source: u.item.folder,
        fp: u.fp,
        backupKey: u.item.key,
      );
    } catch (e) {
      debugPrint('[Sauvegarde PC] ${u.item.name} non confié : $e');
      return null;
    }
  }
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

  Future<void>? _lecture;

  /// Relit l'espace et les racines ; pendant une lecture, rend celle-ci.
  Future<void> refresh() => _lecture ??= _relire().whenComplete(() => _lecture = null);

  Future<void> _relire() async {
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

  /// Au-delà, les fichiers gardés pour la visionneuse les moins récents sont
  /// effacés (ils se retéléchargent au besoin) : un disque presque plein ne
  /// doit pas se remplir de copies oubliées (14/11/2026).
  static const int kKeptMaxBytes = 1 << 30;

  Timer? _triTimer;
  Future<void>? _tri;

  void _trierBientot() {
    _triTimer ??= Timer(const Duration(seconds: 20), () {
      _triTimer = null;
      unawaited(trimKept());
    });
  }

  /// Ramène les fichiers gardés sous [maxBytes] (aux trois quarts, pour ne
  /// pas recommencer à chaque ouverture), les plus anciens d'abord. Un
  /// téléchargement en cours (fichier .part) n'est jamais touché.
  Future<void> trimKept({int maxBytes = kKeptMaxBytes}) => _tri ??= _trierGardes(maxBytes).whenComplete(() => _tri = null);

  Future<void> _trierGardes(int maxBytes) async {
    try {
      final dir = Directory('${(await _baseDir()).path}${Platform.pathSeparator}files');
      if (!await dir.exists()) return;
      final gardes = <({int id, int octets, DateTime quand})>[];
      var total = 0;
      await for (final e in dir.list()) {
        final id = int.tryParse(e.uri.pathSegments.where((x) => x.isNotEmpty).last);
        if (e is! Directory || id == null) continue;
        var octets = 0;
        var quand = DateTime.fromMillisecondsSinceEpoch(0);
        var enCours = false;
        await for (final f in e.list(recursive: true)) {
          if (f is! File) continue;
          if (f.path.endsWith('.part')) enCours = true;
          final st = await f.stat();
          octets += st.size;
          if (st.modified.isAfter(quand)) quand = st.modified;
        }
        total += octets;
        if (!enCours) gardes.add((id: id, octets: octets, quand: quand));
      }
      if (total <= maxBytes) return;
      gardes.sort((a, b) => a.quand.compareTo(b.quand));
      final cible = maxBytes * 3 ~/ 4;
      for (final g in gardes) {
        if (total <= cible) break;
        try {
          await downloads.evict(g.id);
          total -= g.octets;
        } catch (_) {
          // Ouvert ailleurs (Windows) : il restera jusqu'au prochain tri.
        }
      }
    } catch (e) {
      debugPrint('[Coffre] tri des fichiers gardés impossible : $e');
    }
  }

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
    pcBackup.close();
    await uploads.pauseAll();
    _magasin.closed = true;
  }

  @override
  void dispose() {
    _magasin.closed = true;
    _relance.cancel();
    _rafraichir?.cancel();
    _triTimer?.cancel();
    downloads.removeListener(_trierBientot);
    unawaited(_fin.cancel());
    unawaited(_finSauvegarde.cancel());
    pcBackup.dispose();
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

/// Le serveur vu par la sauvegarde du PC (comme sur le téléphone).
class _ApiSauvegarde implements SafeboxBackupApi {
  _ApiSauvegarde(this._api);
  final DesktopApi _api;

  @override
  Future<Map<String, SafeboxBackupStatus>> check(List<String> fps, {bool link = true}) async {
    final r = await _api.checkSafeboxBackupQuality(fps, link: link);
    return {
      for (final e in r.entries)
        e.key: SafeboxBackupStatus(
          switch (e.value.state) {
            'saved' => SafeboxBackupCheck.saved,
            'elsewhere' => SafeboxBackupCheck.elsewhere,
            'uploading' => SafeboxBackupCheck.uploading,
            'skip' => SafeboxBackupCheck.skip,
            _ => SafeboxBackupCheck.unknown,
          },
          original: e.value.original,
        ),
    };
  }

  @override
  Future<void> skip(List<String> fps) => _api.skipSafeboxBackup(fps);
}
