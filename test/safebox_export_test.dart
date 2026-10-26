import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_export.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';

/// Télécharger depuis le coffre (lot 8) : galerie ou ZIP, un fichier à la fois.
void main() {
  late Directory dossier;
  late List<String> galerie;
  late List<({String name, String mime, String subdir})> telechargements;
  late List<int> effaces;
  late Map<int, File> cache;
  Map<String, List<int>>? contenuZip;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('coffre_export_');
    galerie = [];
    telechargements = [];
    effaces = [];
    cache = {};
    contenuZip = null;
  });
  tearDown(() => dossier.delete(recursive: true));

  SafeboxFile fichier(int id, String name, SafeboxFamily family, {bool lost = false}) => SafeboxFile(
        id: id,
        folderId: 1,
        name: name,
        ext: name.split('.').last,
        mime: null,
        family: family,
        plainBytes: 10,
        storedBytes: 26,
        originalBytes: null,
        compressed: false,
        cipherFormat: 'SBX1',
        key: null,
        previewUrl: null,
        lost: lost,
      );

  SafeboxExporter exportateur({Set<int> enEchec = const {}}) => SafeboxExporter(
        fetch: (f) async {
          if (enEchec.contains(f.id)) throw StateError('réseau');
          final d = File('${dossier.path}/clair_${f.id}_${f.name}');
          await d.writeAsString('contenu ${f.id}');
          return d;
        },
        cached: (f) async => cache[f.id],
        evict: (id) async => effaces.add(id),
        progressOf: (_) => null,
        toGallery: (path, family) async => galerie.add('${family.name}:${path.split('/').last}'),
        toDownloads: (path, name, mime, subdir) async {
          telechargements.add((name: name, mime: mime, subdir: subdir));
          if (name.endsWith('.zip')) {
            final a = ZipDecoder().decodeBytes(await File(path).readAsBytes());
            contenuZip = {for (final e in a.files) e.name: e.content as List<int>};
          }
          return 'content://telechargements/$name';
        },
        workDir: () async => dossier,
      );

  Future<SafeboxExportTask> finir(SafeboxExporter e, SafeboxExportTask t) async {
    for (var i = 0; i < 200 && !t.finished; i += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(t.finished, isTrue, reason: 'téléchargement jamais fini');
    return t;
  }

  test('galerie : photos et vidéos dans l\'album, documents dans Téléchargements, copies effacées', () async {
    final e = exportateur();
    cache[3] = File('${dossier.path}/deja.pdf')..writeAsStringSync('déjà là');
    final t = await finir(e, e.start([
      fichier(1, 'Plage.jpg', SafeboxFamily.photos),
      fichier(2, 'Danse.mp4', SafeboxFamily.videos),
      fichier(3, 'Contrat.pdf', SafeboxFamily.documents),
    ], target: SafeboxExportTarget.gallery, title: '3 fichiers'));
    expect(t.state, SafeboxExportState.done);
    expect(galerie, ['photos:clair_1_Plage.jpg', 'videos:clair_2_Danse.mp4']);
    expect(telechargements.single.subdir, 'Alanya/Alanya Documents');
    expect(effaces, [1, 2], reason: 'la copie déjà en cache reste');
    expect(t.progress, 1.0);
  });

  test('ZIP : un seul fichier, noms en double renommés, archive temporaire effacée', () async {
    final e = exportateur();
    final t = await finir(e, e.start([
      fichier(1, 'Plage.jpg', SafeboxFamily.photos),
      fichier(2, 'plage.jpg', SafeboxFamily.photos),
      fichier(3, 'Acte.pdf', SafeboxFamily.documents),
    ], target: SafeboxExportTarget.zip, title: 'Kribi: 2026'));
    expect(t.state, SafeboxExportState.done);
    expect(telechargements.single.name, 'Kribi 2026.zip');
    expect(telechargements.single.mime, 'application/zip');
    expect(contenuZip!.keys, ['Plage.jpg', 'plage (2).jpg', 'Acte.pdf']);
    expect(String.fromCharCodes(contenuZip!['Acte.pdf']!), 'contenu 3');
    expect(galerie, isEmpty);
    expect(dossier.listSync().whereType<File>().where((f) => f.path.endsWith('.zip')), isEmpty);
  });

  test('un fichier en échec ou perdu ne bloque pas les autres', () async {
    final e = exportateur(enEchec: {2});
    final t = await finir(e, e.start([
      fichier(1, 'a.jpg', SafeboxFamily.photos),
      fichier(2, 'b.jpg', SafeboxFamily.photos),
      fichier(3, 'c.jpg', SafeboxFamily.photos, lost: true),
    ], target: SafeboxExportTarget.gallery, title: 'lot'));
    expect(t.files.length, 2, reason: 'le fichier perdu est écarté d\'emblée');
    expect(t.skipped, 1);
    expect(t.state, SafeboxExportState.done);
    expect(galerie, ['photos:clair_1_a.jpg']);
  });

  test('un à la fois ; annuler un téléchargement en attente', () async {
    final e = exportateur();
    final premier = e.start([fichier(1, 'a.jpg', SafeboxFamily.photos)], target: SafeboxExportTarget.gallery, title: 'un');
    final second = e.start([fichier(2, 'b.jpg', SafeboxFamily.photos)], target: SafeboxExportTarget.gallery, title: 'deux');
    e.cancel(second);
    await finir(e, premier);
    expect(second.state, SafeboxExportState.cancelled);
    expect(galerie, ['photos:clair_1_a.jpg']);
    e.clearFinished();
    expect(e.tasks, isEmpty);
  });

  test('noms de fichier', () {
    final pris = <String>{};
    expect(safeboxZipEntryName('a.jpg', pris), 'a.jpg');
    expect(safeboxZipEntryName('A.JPG', pris), 'A (2).JPG');
    expect(safeboxZipFileName('  /  '), 'Coffre-fort');
  });
}
