// `GET /me` → `features: {creation, animated}` (contrat §4c) et création animée
// côté dépôt : drapeau persistant, option masquée sur un 404, refus locaux,
// erreurs du serveur, annulation. Client factice sur les fixtures.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/stickers/sticker_animated_check.dart';
import 'package:talky_flutter/core/services/stickers/sticker_creation_repository.dart';
import 'package:talky_flutter/core/services/stickers/sticker_features.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/talky_api_client.dart';

import 'support/sticker_creation_fakes.dart';

final Uint8List _anime =
    File('test/fixtures/stickers/images/anime-5x50ms.webp').readAsBytesSync();
final Uint8List _gifFixe =
    File('test/fixtures/stickers/images/statique-32x32.gif').readAsBytesSync();

/// `/me` à la demande : fixture avec ou sans `features`, ou panne réseau.
class _MeApi extends OfficialStickerApi {
  _MeApi(this.me);
  Object? me;
  Object? fail;

  @override
  Future<StickerHttpResult> getMe() async {
    final f = fail;
    if (f != null) throw f;
    return StickerHttpResult(200, body: me);
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  group('GET /me → features', () {
    test('animated:true : l\'option s\'ouvre et se mémorise', () async {
      final api = _MeApi(fx('me-features.json'));
      final repo = StickerRepository(db: db, api: api);
      expect(repo.features.animated.value, isFalse, reason: 'fermé par défaut');
      await repo.syncMe();
      expect(repo.features.animated.value, isTrue);
      expect(repo.features.creation.value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(StickerFeatures.animatedKey), isTrue);
      // Les ids de `/me` sont lus comme avant (champ additif).
      expect((await repo.watchInstalled().first).length, 2);
    });

    test('animated:false : fermé', () async {
      final repo = StickerRepository(db: db, api: _MeApi(fx('me-features-fermes.json')));
      await repo.syncMe();
      expect(repo.features.animated.value, isFalse);
      expect(repo.features.creation.value, isTrue);
    });

    test('`features` absent (ancien serveur) : tout est faux', () async {
      final repo = StickerRepository(db: db, api: _MeApi(fx('me.json')));
      await repo.syncMe();
      expect(repo.features.animated.value, isFalse);
      expect(repo.features.creation.value, isFalse);
    });

    test('`features` hostile (chaîne, liste, valeurs "true") : fermé', () async {
      for (final bad in ['x', <Object?>[], {'animated': 'true', 'creation': 1}]) {
        final me = Map<String, dynamic>.from(fx('me.json') as Map)
          ..['features'] = bad;
        final repo = StickerRepository(db: db, api: _MeApi(me));
        await repo.syncMe();
        expect(repo.features.animated.value, isFalse, reason: '$bad');
        expect(repo.features.creation.value, isFalse, reason: '$bad');
      }
    });

    test('le serveur ferme les animés : l\'option disparaît à la synchro suivante',
        () async {
      final api = _MeApi(fx('me-features.json'));
      final repo = StickerRepository(db: db, api: api);
      await repo.syncMe();
      expect(repo.features.animated.value, isTrue);
      api.me = fx('me-features-fermes.json');
      await repo.syncMe();
      expect(repo.features.animated.value, isFalse);
      expect((await SharedPreferences.getInstance()).getBool(StickerFeatures.animatedKey),
          isFalse);
    });

    test('hors ligne : la dernière valeur connue reste (relue au démarrage)',
        () async {
      final api = _MeApi(fx('me-features.json'));
      await StickerRepository(db: db, api: api).syncMe();
      // Nouvelle session : instance neuve, réseau en panne.
      final offline = _MeApi(fx('me-features.json'))
        ..fail = TalkyException('hors ligne', 0);
      final repo = StickerRepository(db: db, api: offline);
      expect(repo.features.animated.value, isFalse);
      await repo.refresh();
      expect(repo.features.animated.value, isTrue,
          reason: 'une panne réseau ne masque pas l\'option');
    });

    test('un `/me` reçu pendant la restauration l\'emporte sur la préférence',
        () async {
      SharedPreferences.setMockInitialValues({StickerFeatures.animatedKey: true});
      final features = StickerFeatures();
      await features.apply({'animated': false, 'creation': true});
      await features.restore();
      expect(features.animated.value, isFalse);
    });
  });

  group('création animée (dépôt)', () {
    late FakeCreationApi api;
    late StickerFeatures features;
    late StickerCreationRepository repo;

    setUp(() async {
      api = FakeCreationApi();
      features = StickerFeatures();
      await features.apply({'creation': true, 'animated': true});
      repo = StickerCreationRepository(db: db, api: api, features: features);
    });

    test('succès : fichier tel quel, forme envoyée, réponse lue, pack relu',
        () async {
      await repo.syncCreated();
      final r = await repo.addAnimatedSticker(41, _anime,
          filename: 'mon.gif.webp', shape: StickerAnimatedShape.cercle);
      expect(api.calls, contains('animated:41:mon.gif.webp:cercle:${_anime.length}'));
      expect(r.upload.assetId, 9004);
      expect(r.upload.stickerId, 504);
      expect(r.upload.packId, 41);
      expect(r.upload.reused, isFalse);
      expect(r.animated, isTrue);
      expect((r.bytes, r.frames, r.durationMs), (120000, 24, 2400));
      // Le pack est relu : le sticker animé est dans Drift avec son drapeau.
      final st = await repo.watchStickers(41).first;
      final anim = st.firstWhere((s) => s.stickerId == 504);
      expect(anim.animated, isTrue);
      expect(anim.assetId, 9004);
    });

    test('valeurs `shape` du contrat', () {
      expect(StickerAnimatedShape.values.map((s) => s.wire),
          ['cercle', 'carre-arrondi', 'carre']);
    });

    test('nom de fichier d\'après le contenu (.gif / .webp)', () async {
      final gif = File('test/fixtures/stickers/images/anime.gif').readAsBytesSync();
      await repo.addAnimatedSticker(41, gif,
          filename: 'IMG_1', shape: StickerAnimatedShape.carre);
      await repo.addAnimatedSticker(41, _anime,
          filename: 'x', shape: StickerAnimatedShape.carreArrondi);
      expect(api.calls.where((c) => c.startsWith('animated:')), [
        'animated:41:sticker.gif:carre:${gif.length}',
        'animated:41:sticker.webp:carre-arrondi:${_anime.length}',
      ]);
    });

    test('refus local avant tout envoi : > 3 Mo, format, GIF fixe', () async {
      for (final (data, issue) in [
        (Uint8List(StickerAnimatedCheck.maxBytes + 1), StickerAnimatedIssue.tooBig),
        (Uint8List.fromList('pas une image'.codeUnits), StickerAnimatedIssue.format),
        (_gifFixe, StickerAnimatedIssue.notAnimated),
      ]) {
        await expectLater(
          repo.addAnimatedSticker(41, data,
              filename: 'a.gif', shape: StickerAnimatedShape.carre),
          throwsA(isA<StickerAnimatedRejected>().having((e) => e.issue, 'issue', issue)),
        );
      }
      expect(api.calls.where((c) => c.startsWith('animated:')), isEmpty);
    });

    test('STICKER_ASSET_INVALID, quota, débit, 503 : remontent tels quels, option intacte',
        () async {
      for (final e in [
        TalkyException('trop lourd', 422, code: 'STICKER_ASSET_INVALID'),
        TalkyException('quota', 429, code: 'STICKER_QUOTA_EXCEEDED'),
        TalkyException('débit', 429, code: 'RATE_LIMITED'),
        TalkyException('occupé', 503, code: 'SERVICE_UNAVAILABLE'),
      ]) {
        api.failNext = e;
        await expectLater(
          repo.addAnimatedSticker(41, _anime,
              filename: 'a.webp', shape: StickerAnimatedShape.carre),
          throwsA(same(e)),
        );
        expect(features.animated.value, isTrue, reason: '${e.code}');
        expect(repo.creationAvailable.value, isFalse,
            reason: 'un refus n\'est pas une fermeture de la création');
      }
    });

    test('404 NOT_FOUND (animés fermés) : l\'option disparaît, la création reste',
        () async {
      await repo.syncCreated();
      expect(repo.creationAvailable.value, isTrue);
      api.failNext = TalkyException('nope', 404, code: 'NOT_FOUND');
      await expectLater(
        repo.addAnimatedSticker(41, _anime,
            filename: 'a.webp', shape: StickerAnimatedShape.carre),
        throwsA(isA<TalkyException>()),
      );
      expect(features.animated.value, isFalse);
      expect((await SharedPreferences.getInstance()).getBool(StickerFeatures.animatedKey),
          isFalse);
      // `GET /me/created` répond encore : la création n'est pas masquée.
      expect(repo.creationAvailable.value, isTrue);
    });

    test('404 parce que TOUTE la création est fermée : relue et masquée aussi',
        () async {
      await repo.syncCreated();
      api.closed = true;
      await expectLater(
        repo.addAnimatedSticker(41, _anime,
            filename: 'a.webp', shape: StickerAnimatedShape.carre),
        throwsA(isA<TalkyException>()),
      );
      expect(features.animated.value, isFalse);
      expect(repo.creationAvailable.value, isFalse);
    });

    test('annulation : la requête reçoit le signal, l\'erreur remonte', () async {
      final cancel = Completer<void>();
      api.holdAnimated = Completer<void>();
      final f = repo.addAnimatedSticker(41, _anime,
          filename: 'a.webp',
          shape: StickerAnimatedShape.carre,
          cancel: cancel.future);
      final done = expectLater(f, throwsA(isA<TalkyException>()));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(api.calls.where((c) => c == 'animated-aborted'), isEmpty);
      cancel.complete();
      await done;
      expect(api.calls, contains('animated-aborted'));
      expect(features.animated.value, isTrue);
    });
  });
}
