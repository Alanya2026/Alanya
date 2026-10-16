import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_cipher.dart';

Uint8List _octets(int n, int graine) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + graine) & 0xff));

void main() {
  const mio = 1 << 20;
  final cle = Uint8List.fromList(List<int>.generate(32, (i) => i));
  // 2,5 morceaux ; blocs de 2 Mio, soit 2 morceaux par bloc → 2 blocs.
  final taille = kSafeboxChunkPlainBytes * 2 + kSafeboxChunkPlainBytes ~/ 2;
  final clair = _octets(taille, 7);
  const bloc = 2 * mio;

  group('géométrie', () {
    test('taille chiffrée = clair + 16 octets par morceau', () {
      expect(safeboxChunkCount(1), 1);
      expect(safeboxChunkCount(kSafeboxChunkPlainBytes), 1);
      expect(safeboxChunkCount(kSafeboxChunkPlainBytes + 1), 2);
      expect(safeboxEncryptedLength(10), 26);
      // 1 Go en clair : un peu plus de 16 Kio de surcoût, sous la tolérance du serveur.
      final go = 1 << 30;
      expect(safeboxEncryptedLength(go) - go, lessThan(64 * 1024));
    });

    test('un bloc de 8 Mio contient exactement 8 morceaux', () {
      expect(safeboxChunksPerBlock(8 * mio), 8);
      expect(() => safeboxChunksPerBlock(8 * mio + 1), throwsArgumentError);
      expect(safeboxBlockCount(kSafeboxChunkPlainBytes * 8, 8 * mio), 1);
      expect(safeboxBlockCount(kSafeboxChunkPlainBytes * 8 + 1, 8 * mio), 2);
    });

    test('les blocs se suivent et couvrent tout le fichier', () {
      final p1 = safeboxPlanBlock(1, plainSize: taille, blockSize: bloc);
      final p2 = safeboxPlanBlock(2, plainSize: taille, blockSize: bloc);
      expect(p1.plainStart, 0);
      expect(p1.plainEnd, p2.plainStart);
      expect(p2.plainEnd, taille);
      expect(p1.cipherLength, bloc);
      expect(p1.cipherLength + p2.cipherLength, safeboxEncryptedLength(taille));
      expect(() => safeboxPlanBlock(3, plainSize: taille, blockSize: bloc), throwsRangeError);
    });
  });

  group('aller-retour', () {
    test('chaque bloc se chiffre et se déchiffre seul', () {
      for (final n in [1, 2]) {
        final plan = safeboxPlanBlock(n, plainSize: taille, blockSize: bloc);
        final morceau = Uint8List.sublistView(clair, plan.plainStart, plan.plainEnd);
        final chiffre = safeboxEncryptBlockSync(cle, morceau, plan);
        expect(chiffre.length, plan.cipherLength);
        expect(safeboxDecryptBlockSync(cle, chiffre, plan), morceau);
      }
    });

    test('rechiffrer le même bloc donne les mêmes octets (reprise après coupure)', () {
      final plan = safeboxPlanBlock(2, plainSize: taille, blockSize: bloc);
      final morceau = Uint8List.sublistView(clair, plan.plainStart, plan.plainEnd);
      expect(safeboxEncryptBlockSync(cle, morceau, plan), safeboxEncryptBlockSync(cle, morceau, plan));
    });

    test('isolat : même résultat', () async {
      final plan = safeboxPlanBlock(2, plainSize: taille, blockSize: bloc);
      final morceau = Uint8List.sublistView(clair, plan.plainStart, plan.plainEnd);
      final chiffre = await safeboxEncryptBlock(cle, morceau, plan);
      expect(await safeboxDecryptBlock(cle, chiffre, plan), morceau);
    });
  });

  group('refus', () {
    final p1 = safeboxPlanBlock(1, plainSize: taille, blockSize: bloc);
    final c1 = safeboxEncryptBlockSync(cle, Uint8List.sublistView(clair, p1.plainStart, p1.plainEnd), p1);

    test('un octet altéré', () {
      final abime = Uint8List.fromList(c1);
      abime[100] ^= 1;
      expect(() => safeboxDecryptBlockSync(cle, abime, p1), throwsA(anything));
    });

    test('une autre clé', () {
      final autre = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
      expect(() => safeboxDecryptBlockSync(autre, c1, p1), throwsA(anything));
    });

    test('un bloc lu à la place d\'un autre', () {
      // Le bloc 1 présenté comme s'il commençait au morceau 2 : nonces faux.
      final decale = SafeboxBlockPlan(
        number: 2, plainStart: 0, plainEnd: p1.plainLength, firstChunk: 2, totalChunks: 4,
      );
      expect(() => safeboxDecryptBlockSync(cle, c1, decale), throwsA(anything));
    });

    test('un fichier coupé net après le bloc 1', () {
      // Sans le bloc 2, le dernier morceau du bloc 1 n'a pas été chiffré « comme dernier ».
      final coupe = SafeboxBlockPlan(
        number: 1, plainStart: 0, plainEnd: p1.plainLength, firstChunk: 0, totalChunks: 2,
      );
      expect(() => safeboxDecryptBlockSync(cle, c1, coupe), throwsA(anything));
    });

    test('une clé de mauvaise taille', () {
      expect(() => safeboxEncryptPreviewSync(Uint8List(16), _octets(10, 1)), throwsArgumentError);
    });
  });

  group('aperçu', () {
    test('aller-retour, et domaine distinct du contenu', () {
      final apercu = _octets(4000, 3);
      final c = safeboxEncryptPreviewSync(cle, apercu);
      expect(c.length, safeboxPreviewEncryptedLength(apercu.length));
      expect(safeboxDecryptPreviewSync(cle, c), apercu);
      // Le même contenu chiffré comme premier et unique morceau d'un fichier
      // ne donne pas les mêmes octets : les nonces ne se recoupent jamais.
      final plan = safeboxPlanBlock(1, plainSize: apercu.length, blockSize: bloc);
      expect(safeboxEncryptBlockSync(cle, apercu, plan), isNot(c));
    });
  });

  test('clé neuve : 32 octets, jamais deux fois la même', () {
    final a = safeboxNewFileKey();
    expect(a.length, 32);
    expect(a, isNot(safeboxNewFileKey()));
  });
}
