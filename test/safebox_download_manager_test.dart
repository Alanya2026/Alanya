import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_cipher.dart';
import 'package:talky_flutter/core/services/safebox/safebox_download_manager.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/talky_api_client.dart';

const _mio = 1 << 20;
final _cle = Uint8List.fromList(List<int>.generate(32, (i) => 3 * i));
final _taille = kSafeboxChunkPlainBytes * 2 + 777;
final _clair = Uint8List.fromList(List<int>.generate(_taille, (i) => (i * 7) & 0xff));

/// MEGA vu du téléphone : de vrais blocs chiffrés SBX1.
class _FauxMega implements SafeboxDownloadTransport {
  _FauxMega() {
    for (var n = 1; n <= safeboxBlockCount(_taille, _mio); n += 1) {
      final p = safeboxPlanBlock(n, plainSize: _taille, blockSize: _mio);
      blocs[n] = safeboxEncryptBlockSync(_cle, Uint8List.sublistView(_clair, p.plainStart, p.plainEnd), p);
    }
  }

  final Map<int, Uint8List> blocs = {};
  final List<String> appels = [];
  int planDemandes = 0;

  /// Coupe la prochaine lecture de ce bloc après la moitié.
  final Set<int> couper = {};

  /// Répond 403 à la prochaine lecture de ce bloc (adresse expirée).
  final Set<int> expirer = {};

  Uint8List? apercuChiffre;

  @override
  Future<SafeboxDownloadPlan> plan(int fileId) async {
    planDemandes += 1;
    return SafeboxDownloadPlan(
      file: _fichier(),
      key: _cle,
      blockSize: _mio,
      blockCount: blocs.length,
      blocks: [for (final n in blocs.keys) SafeboxSignedBlock(n: n, size: blocs[n]!.length, url: 'get:$n:$planDemandes')],
    );
  }

  @override
  Future<SafeboxDownloadPlan> sharePlan(int shareId) => plan(shareId);

  @override
  Future<void> getBlock(String url, {int from = 0, required void Function(List<int> bytes) onBytes}) async {
    final n = int.parse(url.split(':')[1]);
    appels.add('get $n depuis $from');
    if (expirer.remove(n)) throw TalkyException('expirée', 403);
    final b = blocs[n]!;
    if (couper.remove(n)) {
      onBytes(Uint8List.sublistView(b, from, from + (b.length - from) ~/ 2));
      throw TalkyException('coupure', 0);
    }
    onBytes(Uint8List.sublistView(b, from));
  }

  @override
  Future<Uint8List> getPreview(String url) async => apercuChiffre!;
}

SafeboxFile _fichier({String? previewUrl}) => SafeboxFile(
      id: 9, folderId: 1, name: 'Acte de naissance.pdf', ext: 'pdf', mime: 'application/pdf',
      family: SafeboxRoot.documents, plainBytes: _taille, storedBytes: safeboxEncryptedLength(_taille),
      originalBytes: null, compressed: false, cipherFormat: kSafeboxCipherFormat, key: _cle, previewUrl: previewUrl,
    );

void main() {
  late Directory base;
  late _FauxMega mega;
  final attentes = <Duration>[];

  setUp(() async {
    base = await Directory.systemTemp.createTemp('coffre_dl');
    mega = _FauxMega();
    attentes.clear();
  });
  tearDown(() => base.delete(recursive: true));

  SafeboxDownloadManager gestionnaire() => SafeboxDownloadManager(
        transport: mega,
        baseDir: () async => base,
        sleep: (d) async => attentes.add(d),
      );

  test('téléchargement complet : le fichier en clair est identique', () async {
    final f = await gestionnaire().fetch(_fichier());
    expect(await f.readAsBytes(), _clair);
    expect(f.path, endsWith('/files/9/Acte de naissance.pdf'));
    expect(await gestionnaire().cached(_fichier()), isNotNull);
  });

  test('coupure au milieu d\'un bloc : reprise à l\'octet près', () async {
    mega.couper.add(2);
    final f = await gestionnaire().fetch(_fichier());
    expect(await f.readAsBytes(), _clair);
    final lectures2 = mega.appels.where((a) => a.startsWith('get 2')).toList();
    expect(lectures2.length, 2);
    expect(lectures2.last, isNot('get 2 depuis 0'));
    expect(attentes, [const Duration(seconds: 2)]);
  });

  test('redémarrage : les blocs déjà déchiffrés ne sont pas relus', () async {
    final cible = File('${base.path}/files/9/Acte de naissance.pdf.part');
    await cible.parent.create(recursive: true);
    // Bloc 1 complet + un bout du bloc 2 : le bout est jeté.
    await cible.writeAsBytes(Uint8List.sublistView(_clair, 0, kSafeboxChunkPlainBytes + 100));
    final f = await gestionnaire().fetch(_fichier());
    expect(await f.readAsBytes(), _clair);
    expect(mega.appels.any((a) => a.startsWith('get 1')), isFalse);
  });

  test('adresse expirée : nouveau plan, une fois', () async {
    mega.expirer.add(3);
    final f = await gestionnaire().fetch(_fichier());
    expect(await f.readAsBytes(), _clair);
    expect(mega.planDemandes, 2);
  });

  test('bloc altéré chez MEGA : refusé, aucun fichier final', () async {
    mega.blocs[2]![10] ^= 1;
    await expectLater(gestionnaire().fetch(_fichier()), throwsA(anything));
    expect(await File('${base.path}/files/9/Acte de naissance.pdf').exists(), isFalse);
  });

  test('aperçu : déchiffré en mémoire, gardé chiffré sur le disque', () async {
    final apercu = Uint8List.fromList(List<int>.generate(3000, (i) => i & 0xff));
    mega.apercuChiffre = safeboxEncryptPreviewSync(_cle, apercu);
    final cache = SafeboxPreviewCache(transport: mega, baseDir: () async => base);
    expect(await cache.load(_fichier(previewUrl: 'apercu')), apercu);
    final disque = await File('${base.path}/previews/9.sbx').readAsBytes();
    expect(disque, isNot(apercu));
    expect(cache.peek(9), apercu);
    // Une autre instance relit le disque sans réseau.
    mega.apercuChiffre = null;
    expect(await SafeboxPreviewCache(transport: mega, baseDir: () async => base).load(_fichier(previewUrl: 'apercu')), apercu);
  });
}
