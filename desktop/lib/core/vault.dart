import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';

import 'desktop_api.dart';
import 'exporter.dart';

/// L'état du coffre pour les écrans : espace, dossiers racines, albums
/// récents, aperçus, fichiers ouverts et enregistrés.
class Vault extends ChangeNotifier {
  Vault(this.api, {Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? safeboxLocalDir,
        previews = SafeboxPreviewCache(transport: ApiSafeboxDownloadTransport(api), baseDir: baseDir),
        downloads = SafeboxDownloadManager(transport: ApiSafeboxDownloadTransport(api), baseDir: baseDir) {
    exporter = Exporter(api: api, downloads: downloads);
  }

  final DesktopApi api;
  final Future<Directory> Function() _baseDir;
  final SafeboxPreviewCache previews;

  /// Les fichiers ouverts dans la visionneuse : copies en clair gardées dans
  /// le dossier de l'application, jusqu'à « Vider » ou la déconnexion.
  final SafeboxDownloadManager downloads;
  late final Exporter exporter;

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

  @override
  void dispose() {
    exporter.dispose();
    downloads.dispose();
    super.dispose();
  }
}
