import 'dart:io';
import 'dart:typed_data';

import 'package:alanya_coffre/core/exporter.dart';
import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';

SafeboxFile _fichier(int id, String nom, {int taille = 5}) => SafeboxFile(
      id: id,
      folderId: 1,
      name: nom,
      ext: nom.split('.').last,
      mime: null,
      family: SafeboxFamily.photos,
      plainBytes: taille,
      storedBytes: taille,
      originalBytes: null,
      compressed: false,
      cipherFormat: 'SBX1',
      key: Uint8List(32),
      previewUrl: null,
    );

SafeboxFolder _dossier(int id, String nom) =>
    SafeboxFolder(id: id, parentId: 1, root: SafeboxRoot.albums, name: nom, depth: 1);

/// Un coffre en mémoire : dossier 1 = deux fichiers de même nom + sous-dossier 2.
class _Api with SafeboxCalls {
  @override
  SafeboxHttp get safeboxHttp => throw UnimplementedError();

  @override
  Future<SafeboxFolderPage> fetchSafeboxFolder(int folderId, {int? cursor}) async => switch (folderId) {
        1 when cursor == null => SafeboxFolderPage(
            folder: _dossier(1, 'Kribi'),
            breadcrumbs: const [],
            folders: [_dossier(2, 'Plage')],
            files: [_fichier(10, 'a.jpg')],
            nextCursor: 99,
          ),
        1 => SafeboxFolderPage(folder: _dossier(1, 'Kribi'), breadcrumbs: const [], folders: const [], files: [_fichier(11, 'a.jpg')], nextCursor: null),
        _ => SafeboxFolderPage(folder: _dossier(2, 'Plage'), breadcrumbs: const [], folders: const [], files: [_fichier(12, 'b.jpg')], nextCursor: null),
      };
}

class _Transport implements SafeboxDownloadTransport {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Téléchargements simulés : écrit « contenu id » dans un cache temporaire.
class _Telechargements extends SafeboxDownloadManager {
  _Telechargements(this.cache) : super(transport: _Transport());
  final Directory cache;
  final evinces = <int>[];

  @override
  Future<File?> cached(SafeboxFile file) async {
    final f = File('${cache.path}/${file.id}');
    return f.existsSync() ? f : null;
  }

  @override
  Future<File> fetch(SafeboxFile file) async {
    final f = File('${cache.path}/${file.id}');
    await f.writeAsString('contenu ${file.id}');
    return f;
  }

  @override
  Future<void> evict(int fileId) async {
    evinces.add(fileId);
    final f = File('${cache.path}/$fileId');
    if (f.existsSync()) await f.delete();
  }
}

void main() {
  late Directory tmp;
  late Directory sortie;
  late _Telechargements telechargements;
  late Exporter exporter;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('coffre_export');
    sortie = Directory('${tmp.path}/Téléchargements')..createSync();
    telechargements = _Telechargements(Directory('${tmp.path}/cache')..createSync());
    exporter = Exporter(api: _Api(), downloads: telechargements, folder: () async => sortie);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('un dossier garde son arborescence, toutes pages lues, sans écraser un nom', () async {
    await exporter.saveFolder(1, 'Kribi');

    final t = exporter.task!;
    expect(t.state, ExportState.done);
    expect(t.filesTotal, 3);
    expect(t.filesDone, 3);
    expect(File('${sortie.path}/Kribi/a.jpg').readAsStringSync(), 'contenu 10');
    expect(File('${sortie.path}/Kribi/a (2).jpg').readAsStringSync(), 'contenu 11');
    expect(File('${sortie.path}/Kribi/Plage/b.jpg').readAsStringSync(), 'contenu 12');
  });

  test('un second enregistrement du même dossier va dans « Kribi (2) »', () async {
    await exporter.saveFolder(1, 'Kribi');
    await exporter.saveFolder(1, 'Kribi');
    expect(Directory('${sortie.path}/Kribi (2)/Plage').existsSync(), isTrue);
  });

  test('une copie téléchargée pour l’occasion quitte le cache, pas une copie déjà là', () async {
    File('${telechargements.cache.path}/10').writeAsStringSync('contenu 10');
    final chemin = await exporter.saveFile(_fichier(10, 'a.jpg'));
    await exporter.saveFile(_fichier(13, 'c.jpg'));

    expect(chemin, '${sortie.path}/a.jpg');
    expect(telechargements.evinces, [13]);
  });
}
