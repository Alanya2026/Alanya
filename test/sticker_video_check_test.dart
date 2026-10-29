// Vidéo → sticker animé (contrat §4d) : détection par octets, limites, fenêtre de
// découpe et drapeau `features.video`. Logique pure, aucun moteur vidéo.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/stickers/sticker_features.dart';
import 'package:talky_flutter/core/services/stickers/sticker_video_check.dart';

Uint8List _mp4(String brand, {int extra = 64}) => Uint8List.fromList([
  0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits, ...List.filled(extra, 7),
]);

void main() {
  group('octets magiques', () {
    test('MP4, MOV, 3GP et WebM reconnus', () {
      for (final b in ['isom', 'mp42', 'qt  ', 'M4V ', '3gp4', 'avc1']) {
        expect(StickerVideoCheck.kind(_mp4(b)), StickerVideoKind.mp4, reason: b);
      }
      expect(
        StickerVideoCheck.kind(Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3, ...List.filled(40, 1)])),
        StickerVideoKind.webm,
      );
    });

    test('images HEIC / AVIF (même conteneur ftyp), GIF, PNG, hasard : refusés', () {
      for (final b in ['heic', 'heix', 'avif', 'avis', 'mif1', 'msf1']) {
        expect(StickerVideoCheck.kind(_mp4(b)), isNull, reason: b);
      }
      expect(StickerVideoCheck.kind(Uint8List.fromList('GIF89a'.codeUnits + List.filled(30, 0))), isNull);
      expect(StickerVideoCheck.kind(Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, ...List.filled(30, 0)])), isNull);
      expect(StickerVideoCheck.kind(Uint8List(5)), isNull, reason: 'trop court');
      expect(StickerVideoCheck.kind(Uint8List(0)), isNull);
      expect(StickerVideoCheck.isVideo(_mp4('isom')), isTrue);
    });

    test('validate : 20 Mo exactement accepté, un octet de plus refusé', () {
      final pile = Uint8List(StickerVideoCheck.maxBytes)..setRange(0, 12, _mp4('isom').sublist(0, 12));
      expect(StickerVideoCheck.validate(pile), StickerVideoKind.mp4);
      final trop = Uint8List(StickerVideoCheck.maxBytes + 1)..setRange(0, 12, _mp4('isom').sublist(0, 12));
      expect(
        () => StickerVideoCheck.validate(trop),
        throwsA(isA<StickerVideoRejected>().having((e) => e.issue, 'issue', StickerVideoIssue.tooBig)),
      );
      expect(
        () => StickerVideoCheck.validate(Uint8List.fromList(List.filled(40, 3))),
        throwsA(isA<StickerVideoRejected>().having((e) => e.issue, 'issue', StickerVideoIssue.format)),
      );
    });

    test('types MIME et extensions envoyés au serveur', () {
      expect(StickerVideoKind.mp4.mime, 'video/mp4');
      expect(StickerVideoKind.mp4.extension, '.mp4');
      expect(StickerVideoKind.webm.mime, 'video/webm');
      expect(StickerVideoKind.webm.extension, '.webm');
    });
  });

  group('fenêtre de découpe', () {
    test('fenêtre initiale : le début, 3 s ou toute la vidéo si plus courte', () {
      expect(StickerVideoWindow.initial(60000), const StickerVideoWindow(startMs: 0, durationMs: 3000));
      expect(StickerVideoWindow.initial(3000), const StickerVideoWindow(startMs: 0, durationMs: 3000));
      expect(StickerVideoWindow.initial(1800), const StickerVideoWindow(startMs: 0, durationMs: 1800));
      expect(StickerVideoWindow.initial(500), const StickerVideoWindow(startMs: 0, durationMs: 500));
      expect(StickerVideoWindow.initial(499), isNull, reason: 'moins de 500 ms : refus');
      expect(StickerVideoWindow.initial(0), isNull);
    });

    test('jamais au-delà de la fin, durée 500 ms à 3 s : balayage de toutes les durées', () {
      for (var video = 500; video <= 70000; video += 37) {
        final init = StickerVideoWindow.initial(video)!;
        expect(init.endMs, lessThanOrEqualTo(video), reason: 'initiale, vidéo $video');
        for (final ask in [-5000, 0, 100, 499, 500, 777, 1500, 2999, 3000, 3001, 99999]) {
          final d = init.withDuration(ask, videoMs: video);
          expect(d.durationMs, inInclusiveRange(500, 3000), reason: 'durée $ask / vidéo $video');
          expect(d.durationMs, lessThanOrEqualTo(video), reason: 'durée > vidéo : $ask / $video');
          expect(d.startMs, greaterThanOrEqualTo(0));
          expect(d.endMs, lessThanOrEqualTo(video), reason: 'fin dépassée : durée $ask / vidéo $video');
          for (final st in [-100, 0, 1, 250, 1234, 5000, 59999, 99999999]) {
            final w = d.withStart(st, videoMs: video);
            expect(w.durationMs, d.durationMs, reason: 'la durée ne change pas en déplaçant');
            expect(w.startMs, greaterThanOrEqualTo(0));
            expect(w.endMs, lessThanOrEqualTo(video), reason: 'début $st / durée ${d.durationMs} / vidéo $video');
          }
        }
      }
    });

    test('exemples précis : arrondi vers le bas, recul du début quand la durée augmente', () {
      // 2 250 ms : le début maximal de 2 000 ms est 250 → 200 (jamais 300).
      final w = const StickerVideoWindow(startMs: 0, durationMs: 2000).withStart(5000, videoMs: 2250);
      expect(w.startMs, 200);
      // Vidéo de 10 s, fenêtre 8 000 → 10 000 ms : durée plafonnée à 3 s.
      final big = const StickerVideoWindow(startMs: 8000, durationMs: 1000).withDuration(3000, videoMs: 10000);
      expect(big, const StickerVideoWindow(startMs: 7000, durationMs: 3000), reason: 'le début recule');
      expect(const StickerVideoWindow(startMs: 0, durationMs: 1000).withDuration(50, videoMs: 10000).durationMs, 500);
    });
  });

  group('features.video', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('absent ou faux = fermé', () async {
      final f = StickerFeatures();
      await f.apply(null);
      expect(f.video.value, isFalse);
      await f.apply({'creation': true, 'animated': true});
      expect(f.video.value, isFalse, reason: 'champ absent');
      await f.apply({'creation': true, 'animated': true, 'video': 'oui'});
      expect(f.video.value, isFalse, reason: 'seul un vrai booléen ouvre');
    });

    test('ouvert seulement avec les animés', () async {
      final f = StickerFeatures();
      await f.apply({'creation': true, 'animated': true, 'video': true});
      expect(f.video.value, isTrue);
      await f.apply({'creation': true, 'animated': false, 'video': true});
      expect(f.video.value, isFalse, reason: 'animés fermés : pas de vidéo');
    });

    test('dernière valeur gardée hors ligne, effacée par la déconnexion', () async {
      final f = StickerFeatures();
      await f.apply({'creation': true, 'animated': true, 'video': true});
      final f2 = StickerFeatures();
      await f2.restore();
      expect(f2.video.value, isTrue);
      expect(StickerFeatures.prefKeys, contains(StickerFeatures.videoKey));
    });

    test('404 des animés : la vidéo se ferme aussi', () async {
      final f = StickerFeatures();
      await f.apply({'creation': true, 'animated': true, 'video': true});
      await f.animatedClosed();
      expect([f.animated.value, f.video.value], [false, false]);
    });
  });
}
