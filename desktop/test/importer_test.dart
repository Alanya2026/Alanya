import 'dart:io';
import 'dart:typed_data';

import 'package:alanya_coffre/core/importer.dart';
import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';

const _racines = {
  SafeboxRoot.photos: 1,
  SafeboxRoot.videos: 2,
  SafeboxRoot.audios: 3,
  SafeboxRoot.documents: 4,
  SafeboxRoot.albums: 5,
  SafeboxRoot.partager: 6,
};

SafeboxOverview _apercu({int libre = 1 << 30, int maxFichier = 1 << 30}) => SafeboxOverview.fromJson({
      'quota': {'usedBytes': 0, 'quotaBytes': libre},
      'roots': [for (final e in _racines.entries) {'id': e.value, 'root': e.key.name}],
      'limits': {
        'maxFileBytes': maxFichier,
        'blockBytes': 8 << 20,
        'maxPreviewBytes': 256 * 1024,
        'maxDepth': 8,
        'maxFolders': 1000,
        'folderNameMax': 80,
        'fileNameMax': 120,
        'extensions': {
          'photos': ['jpg', 'png'],
          'videos': ['mp4'],
          'audios': ['mp3'],
        },
      },
    });

SafeboxFolder _cible(int id, SafeboxRoot root) => SafeboxFolder(id: id, parentId: null, root: root, name: null, depth: 0);

/// Un coffre en mémoire : empreintes connues, dossiers créés, ajouts sans copie.
class _Api with SafeboxCalls {
  final etats = <String, ({String state, int? fileId})>{};
  final liens = <bool>[];
  final crees = <(int parent, String nom, int id)>[];
  final ajouts = <int, List<int>>{};
  var _prochain = 100;

  @override
  SafeboxHttp get safeboxHttp => throw UnimplementedError();

  @override
  Future<Map<String, ({String state, int? fileId})>> checkSafeboxSources(List<String> fps, {bool link = false}) async {
    liens.add(link);
    return {for (final fp in fps) fp: etats[fp] ?? (state: 'new', fileId: null)};
  }

  @override
  Future<SafeboxFolderPage> fetchSafeboxFolder(int folderId, {int? cursor}) async => SafeboxFolderPage(
        folder: _cible(folderId, SafeboxRoot.albums),
        breadcrumbs: const [],
        folders: [
          for (final c in crees.where((c) => c.$1 == folderId))
            SafeboxFolder(id: c.$3, parentId: folderId, root: SafeboxRoot.albums, name: c.$2, depth: 1),
        ],
        files: const [],
        nextCursor: null,
      );

  @override
  Future<SafeboxFolder> createSafeboxFolder({required int parentId, required String name}) async {
    final id = _prochain++;
    crees.add((parentId, name, id));
    return SafeboxFolder(id: id, parentId: parentId, root: SafeboxRoot.albums, name: name, depth: 1);
  }

  @override
  Future<List<SafeboxFile>> addSafeboxFilesToFolder(int folderId, List<int> fileIds) async {
    ajouts.putIfAbsent(folderId, () => []).addAll(fileIds);
    return const [];
  }
}

void main() {
  late Directory tmp;
  late _Api api;
  late List<SafeboxUploadJob> confies;
  late Importer importer;

  void ecrire(String chemin, String contenu) {
    File('${tmp.path}/$chemin')
      ..createSync(recursive: true)
      ..writeAsStringSync(contenu);
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('coffre_import');
    api = _Api();
    confies = [];
    importer = Importer(
      api: api,
      enqueue: (job, key) async => confies.add(job),
      workDir: () async => Directory('${tmp.path}/work'),
      photoPreview: (_) async => (jpeg: Uint8List.fromList([1, 2, 3]), width: 4000, height: 3000),
      // Empreinte = contenu : deux fichiers identiques ont la même.
      fingerprints: (chemins) async => [for (final p in chemins) 'fp:${File(p).readAsStringSync()}'],
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('dans Photos : chaque fichier va dans la racine de son type, le dossier devient la source', () async {
    ecrire('Kribi/plage.jpg', 'a');
    ecrire('Kribi/notes.pdf', 'b');
    ecrire('Kribi/sous/film.mp4', 'c');
    ecrire('Kribi/.cache', 'x');
    ecrire('Kribi/vide.jpg', '');

    final plan = await importer.plan(['${tmp.path}/Kribi'], _cible(1, SafeboxRoot.photos), _apercu());

    expect([for (final c in plan.send) (c.name, c.folderId, c.source)], [
      ('notes.pdf', 4, 'Kribi'),
      ('plage.jpg', 1, 'Kribi'),
      ('film.mp4', 2, 'Kribi'),
    ]);
    expect(plan.diverted, {SafeboxRoot.documents: 1, SafeboxRoot.videos: 1});
    expect(plan.ignored, 2); // caché + vide
    expect(api.liens, [true]); // ce qui n'est que dans un album rejoint Photos sans copie
  });

  test('déjà dans le coffre ou en cours d’envoi : rien ne repart', () async {
    ecrire('a.jpg', 'a');
    ecrire('b.jpg', 'b');
    ecrire('c.jpg', 'c');
    ecrire('copie-de-c.jpg', 'c');
    api.etats['fp:a'] = (state: 'saved', fileId: 9);
    api.etats['fp:b'] = (state: 'uploading', fileId: null);

    final plan = await importer.plan(
      [for (final n in ['a.jpg', 'b.jpg', 'c.jpg', 'copie-de-c.jpg']) '${tmp.path}/$n'],
      _cible(1, SafeboxRoot.photos),
      _apercu(),
    );

    expect(plan.send.map((c) => c.name), ['c.jpg']);
    expect(plan.already, 3);
  });

  test('dans un album : l’arborescence est recréée, le déjà-là ajouté sans copie', () async {
    ecrire('Mariage/mairie.jpg', 'm');
    ecrire('Mariage/Soirée/danse.mp4', 'd');
    ecrire('Mariage/Soirée/gateau.jpg', 'g');
    api.etats['fp:g'] = (state: 'saved', fileId: 42);

    final plan = await importer.plan(['${tmp.path}/Mariage'], _cible(5, SafeboxRoot.albums), _apercu());
    expect(api.liens, [false]);
    expect(plan.send.map((c) => c.name), ['mairie.jpg', 'danse.mp4']);
    expect(plan.link.single.existingFileId, 42);

    final n = await importer.run(plan, _apercu().limits);
    expect(n, 3);
    expect([for (final c in api.crees) (c.$1, c.$2)], [(5, 'Mariage'), (100, 'Soirée')]);
    expect(api.ajouts, {101: [42]});
    expect([for (final j in confies) (j.name, j.folderId)], [('mairie.jpg', 100), ('danse.mp4', 101)]);

    final photo = confies.first;
    expect(photo.ownsSource, isFalse);
    expect(photo.quality, 'original');
    expect(photo.sourceFp, 'fp:m');
    expect(photo.meta, {'width': 4000, 'height': 3000});
    expect(photo.previewSize, 3 + kSafeboxTagBytes);
    expect(File(photo.previewPath!).existsSync(), isTrue);
    expect(confies.last.previewPath, isNull); // vidéo : une icône
  });

  test('Partager reçoit tout, sans vérifier ; trop lourd et place libre comptés', () async {
    ecrire('gros.mp4', 'x' * 50);
    ecrire('petit.pdf', 'y' * 10);
    final plan = await importer.plan(
      ['${tmp.path}/gros.mp4', '${tmp.path}/petit.pdf'],
      _cible(6, SafeboxRoot.partager),
      _apercu(libre: 20, maxFichier: 40),
    );
    expect(api.liens, isEmpty);
    expect(plan.tooLarge.single.name, 'gros.mp4');
    expect(plan.send.single.name, 'petit.pdf');
    expect(plan.sendBytes, safeboxEncryptedLength(10));
    expect(plan.fits, isFalse);
  });

  test('un nom trop long garde son extension', () {
    expect(shortenFileName('${'a' * 20}.jpeg', 10), 'aaaaa.jpeg');
    expect(shortenFileName('court.jpg', 10), 'court.jpg');
  });
}
