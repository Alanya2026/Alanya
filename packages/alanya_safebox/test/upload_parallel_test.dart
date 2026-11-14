// Plusieurs petits fichiers partent ensemble (3 au plus) ; un gros fichier
// passe seul.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';

class _Magasin implements SafeboxJobStore {
  final cles = <String, Uint8List>{};
  @override
  Future<List<SafeboxUploadJob>> loadJobs() async => const [];
  @override
  Future<void> saveJobs(List<SafeboxUploadJob> jobs) async {}
  @override
  Future<Uint8List?> loadKey(String jobId) async => cles[jobId];
  @override
  Future<void> saveKey(String jobId, Uint8List key) async => cles[jobId] = key;
  @override
  Future<void> deleteKey(String jobId) async => cles.remove(jobId);
}

/// Un stockage qui note, à chaque bloc, quels fichiers sont en cours.
class _Stockage implements SafeboxTransport {
  var _prochain = 1;
  final enCours = <int>{};
  final ensemble = <Set<int>>[];
  final noms = <int, String>{};

  @override
  Future<SafeboxUploadTicket> reserve({
    required int folderId,
    required String name,
    required String? mime,
    required int size,
    required int plainSize,
    required String cipherFormat,
    int? originalSize,
    bool compressed = false,
    String? quality,
    int previewSize = 0,
    Map<String, dynamic>? meta,
    String? sourceFp,
  }) async {
    final id = _prochain++;
    noms[id] = name;
    final n = safeboxBlockCount(plainSize, 8 << 20);
    return SafeboxUploadTicket(
      fileId: id,
      blockSize: 8 << 20,
      blockCount: n,
      size: size,
      blocks: [for (var i = 1; i <= n; i += 1) SafeboxSignedBlock(n: i, size: 0, url: 'f$id/b$i')],
      preview: null,
      urlTtlSeconds: 3600,
    );
  }

  @override
  Future<void> putBlock(String url, Uint8List bytes, {void Function(int sent)? onProgress, Future<void>? cancel}) async {
    final id = int.parse(url.substring(1, url.indexOf('/')));
    enCours.add(id);
    ensemble.add({...enCours});
    await Future<void>.delayed(const Duration(milliseconds: 60));
    onProgress?.call(bytes.length);
    enCours.remove(id);
  }

  @override
  Future<SafeboxFile> complete(int fileId, Uint8List key) async => SafeboxFile.fromJson({
        'id': fileId,
        'folderId': 1,
        'name': noms[fileId],
        'family': 'documents',
        'plainBytes': 1,
        'storedBytes': 1,
        'cipherFormat': 'SBX1',
      });

  @override
  Future<SafeboxUploadStatus> status(int fileId) async =>
      const SafeboxUploadStatus(blockCount: 0, received: [], missing: [], previewMissing: false);

  @override
  Future<({List<SafeboxSignedBlock> blocks, SafeboxSignedBlock? preview})> urls(int fileId,
          {List<int> blocks = const [], bool preview = false}) async =>
      (blocks: [for (final n in blocks) SafeboxSignedBlock(n: n, size: 0, url: 'f$fileId/b$n')], preview: null);

  @override
  Future<void> cancel(int fileId) async {}
}

void main() {
  test('3 petits fichiers ensemble au plus ; le gros passe seul', () async {
    final tmp = Directory.systemTemp.createTempSync('coffre_paralleles');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final stockage = _Stockage();
    final m = SafeboxUploadManager(transport: stockage, store: _Magasin());
    final termines = <String>[];
    m.completed.listen((f) => termines.add(f.name));

    Future<void> ajouter(String nom, int octets) async {
      final f = File('${tmp.path}/$nom')..writeAsBytesSync(Uint8List(octets));
      final st = f.statSync();
      await m.enqueue(
        SafeboxUploadJob(
          id: nom,
          folderId: 1,
          name: nom,
          mime: null,
          sourcePath: f.path,
          sourceSize: st.size,
          sourceModifiedMs: st.modified.millisecondsSinceEpoch,
          ownsSource: false,
          plainSize: st.size,
          originalSize: null,
          compressed: false,
        ),
        safeboxNewFileKey(),
      );
    }

    for (var i = 1; i <= 4; i += 1) {
      await ajouter('petit$i.jpg', 1024);
    }
    await ajouter('gros.mp4', (8 << 20) + 1024); // 2 blocs
    await ajouter('petit5.jpg', 1024);

    while (termines.length < 6) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final plusGrand = stockage.ensemble.map((e) => e.length).reduce((a, b) => a > b ? a : b);
    expect(plusGrand, 3, reason: 'trois petits fichiers ensemble au plus');
    final gros = stockage.noms.entries.firstWhere((e) => e.value == 'gros.mp4').key;
    expect(stockage.ensemble.where((e) => e.contains(gros)).every((e) => e.length == 1), isTrue,
        reason: 'le gros fichier passe seul');
    // L'ordre est gardé : le petit ajouté après le gros part après lui.
    expect(termines.indexOf('petit5.jpg'), greaterThan(termines.indexOf('gros.mp4')));
    m.dispose();
  });
}
