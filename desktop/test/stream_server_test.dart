import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:alanya_coffre/core/stream_server.dart';
import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un coffre qui garde un fichier chiffré en blocs SBX1, et compte les blocs lus.
class _Coffre with SafeboxCalls {
  _Coffre(this.clair, this.cle);
  final Uint8List clair;
  final Uint8List cle;
  final chiffres = <int, Uint8List>{};
  final lus = <int>[];
  var plans = 0;

  int get nbBlocs => safeboxBlockCount(clair.length, 8 << 20);

  Future<void> chiffrer() async {
    for (var n = 1; n <= nbBlocs; n += 1) {
      final geo = safeboxPlanBlock(n, plainSize: clair.length, blockSize: 8 << 20);
      chiffres[n] = await safeboxEncryptBlock(cle, Uint8List.sublistView(clair, geo.plainStart, geo.plainEnd), geo);
    }
  }

  @override
  SafeboxHttp get safeboxHttp => throw UnimplementedError();

  @override
  Future<SafeboxDownloadPlan> fetchSafeboxDownload(int fileId) async {
    plans += 1;
    return SafeboxDownloadPlan(
      file: _fichier,
      key: cle,
      blockSize: 8 << 20,
      blockCount: nbBlocs,
      blocks: [for (var n = 1; n <= nbBlocs; n += 1) SafeboxSignedBlock(n: n, size: 0, url: 'b$n')],
    );
  }

  @override
  Future<void> getSafeboxBlock(String url, {int from = 0, required void Function(List<int> bytes) onBytes}) async {
    final n = int.parse(url.substring(1));
    lus.add(n);
    onBytes(Uint8List.sublistView(chiffres[n]!, from));
  }

  SafeboxFile get _fichier => SafeboxFile.fromJson({
        'id': 7,
        'folderId': 1,
        'name': 'film.mp4',
        'family': 'videos',
        'plainBytes': clair.length,
        'storedBytes': safeboxEncryptedLength(clair.length),
        'cipherFormat': 'SBX1',
      });
}

Future<(int, List<int>, HttpHeaders)> _lire(Uri url, {String? plage}) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    if (plage != null) req.headers.set(HttpHeaders.rangeHeader, plage);
    final res = await req.close();
    final octets = <int>[];
    await for (final m in res) {
      octets.addAll(m);
    }
    return (res.statusCode, octets, res.headers);
  } finally {
    client.close();
  }
}

void main() {
  test('sert en clair les octets demandés, en ne lisant que les blocs utiles', () async {
    final hasard = Random(1);
    final clair = Uint8List.fromList(List.generate(20 << 20, (_) => hasard.nextInt(256))); // 3 blocs
    final coffre = _Coffre(clair, safeboxNewFileKey());
    await coffre.chiffrer();
    final serveur = VaultStreamServer(coffre);
    addTearDown(serveur.close);
    final url = await serveur.open(coffre._fichier);
    expect(url.host, '127.0.0.1');

    // Le lecteur saute au milieu du film (troisième bloc) : seul ce bloc
    // (et le suivant, s'il existe) est lu.
    final debut = (18 << 20) + 123;
    final (statut, octets, entetes) = await _lire(url, plage: 'bytes=$debut-${debut + 999}');
    expect(statut, HttpStatus.partialContent);
    expect(entetes.value(HttpHeaders.contentRangeHeader), 'bytes $debut-${debut + 999}/${clair.length}');
    expect(octets, clair.sublist(debut, debut + 1000));
    expect(coffre.lus, [3]);

    // Une plage à cheval sur deux blocs.
    final frontiere = safeboxPlanBlock(2, plainSize: clair.length, blockSize: 8 << 20).plainStart;
    final (_, aCheval, _) = await _lire(url, plage: 'bytes=${frontiere - 10}-${frontiere + 9}');
    expect(aCheval, clair.sublist(frontiere - 10, frontiere + 10));

    // Tout le fichier, sans plage.
    final (tout, complet, _) = await _lire(url);
    expect(tout, HttpStatus.ok);
    expect(complet.length, clair.length);
    expect(complet.sublist(clair.length - 50), clair.sublist(clair.length - 50));
    expect(coffre.plans, 1, reason: 'un seul plan pour toutes les demandes');
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('une adresse inconnue ou relâchée ne sert rien', () async {
    final coffre = _Coffre(Uint8List(10), safeboxNewFileKey());
    await coffre.chiffrer();
    final serveur = VaultStreamServer(coffre);
    addTearDown(serveur.close);
    final url = await serveur.open(coffre._fichier);
    final autre = url.replace(pathSegments: ['mauvais-secret', ...url.pathSegments.skip(1)]);
    expect((await _lire(autre)).$1, HttpStatus.notFound);
    serveur.release(url);
    expect((await _lire(url)).$1, HttpStatus.notFound);
  });
}
