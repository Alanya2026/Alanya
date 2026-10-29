// StickerCreationRepository contre les fixtures V1b (contrat §4b), client API
// injecté : packs perso, ajout, copie, signalement, partage, quotas.
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/services/stickers/sticker_creation_repository.dart';
import 'package:talky_flutter/core/services/stickers/sticker_image_check.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/talky_api_client.dart';

import 'support/sticker_creation_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeCreationApi api;
  late StickerCreationRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeCreationApi();
    repo = StickerCreationRepository(db: db, api: api);
  });
  tearDown(() => db.close());

  group('GET /me/created', () {
    test('packs, stickers, jeton de partage et assetId dans Drift', () async {
      await repo.syncCreated();
      expect(repo.creationAvailable.value, isTrue);
      final packs = await repo.watchCreated().first;
      expect(packs.map((p) => p.code), ['u_7_ab12cd34', 'u_7_ef56ab78']);
      expect(packs[0].owned, isTrue);
      expect(packs[0].shareToken, kToken);
      expect(packs[0].stickerCount, 2);
      expect(packs[1].shareToken, isNull);
      final st = await repo.watchStickers(41).first;
      expect(st.map((s) => (s.stickerId, s.assetId)), [(501, 9001), (502, 9002)]);
      expect(await repo.assetIdOf(502), 9002);
      expect(await repo.assetIdOf(999), isNull);
    });

    test('nom résolu par le serveur, jamais l\'objet i18n brut', () async {
      await repo.syncCreated();
      final p = (await repo.watchCreated().first).first;
      expect(p.name, 'Mes stickers');
      expect(p.name, isNot(contains('{')));
    });

    test('un pack archivé ailleurs disparaît (pack et stickers)', () async {
      await repo.syncCreated();
      final one = Map<String, dynamic>.from(fx('created.json') as Map);
      one['packs'] = [(one['packs'] as List).last];
      api.created = one;
      await repo.syncCreated();
      expect((await repo.watchCreated().first).map((p) => p.packId), [42]);
      expect(await repo.watchStickers(41).first, isEmpty);
    });

    test('lien révoqué ailleurs : le jeton local est effacé', () async {
      await repo.syncCreated();
      final c = Map<String, dynamic>.from(fx('created.json') as Map);
      final first = Map<String, dynamic>.from((c['packs'] as List).first as Map)
        ..['shared'] = false
        ..['shareToken'] = null;
      c['packs'] = [first];
      api.created = c;
      await repo.syncCreated();
      expect((await repo.watchCreated().first).single.shareToken, isNull);
    });

    test('404 NOT_FOUND : création fermée, entrées masquées, cache purgé', () async {
      await repo.syncCreated();
      expect(repo.creationAvailable.value, isTrue);
      api.closed = true;
      await repo.syncCreated();
      expect(repo.creationAvailable.value, isFalse);
      expect(await repo.watchCreated().first, isEmpty);
      expect(await db.select(db.localStickers).get(), isEmpty);
    });

    test('hors ligne : le dernier état « ouvert » est conservé', () async {
      await repo.syncCreated();
      final offline = StickerCreationRepository(db: db, api: _Offline());
      await offline.syncCreated();
      expect(offline.creationAvailable.value, isTrue);
      expect((await offline.watchCreated().first), hasLength(2));
    });

    test('jamais ouvert + hors ligne : fermé', () async {
      final offline = StickerCreationRepository(db: db, api: _Offline());
      await offline.syncCreated();
      expect(offline.creationAvailable.value, isFalse);
    });
  });

  group('coexistence avec le catalogue et les packs installés', () {
    late StickerRepository official;
    setUp(() async {
      official = StickerRepository(db: db, api: OfficialStickerApi());
      await official.refresh();
      await repo.syncCreated();
    });

    test('mes packs ne sont ni dans le catalogue ni dans « installés »', () async {
      expect((await official.watchCatalog().first).map((p) => p.code), ['alanya', 'mboa', 'royal']);
      expect((await official.watchInstalled().first).map((p) => p.code), ['alanya', 'mboa']);
    });

    test('mais ils sont dans le plateau, après les packs installés', () async {
      final tray = await official.watchTray().first;
      expect(tray.map((p) => p.code),
          ['alanya', 'mboa', 'u_7_ab12cd34', 'u_7_ef56ab78']);
    });

    test('une synchro du catalogue ne supprime pas mes packs', () async {
      await official.syncCatalog();
      expect(await repo.watchCreated().first, hasLength(2));
    });

    test('syncInstalledPacks ne va pas chercher mes packs sur /packs/:code', () async {
      final o = OfficialStickerApi();
      final r = StickerRepository(db: db, api: o);
      await r.syncInstalledPacks(force: true);
      expect(o.packCalls, isNot(contains('u_7_ab12cd34')));
    });

    test('afterSync : appelé à la fin de refresh()', () async {
      var n = 0;
      official.afterSync = () async => n++;
      await official.refresh();
      expect(n, 1);
    });
  });

  group('actions sur les packs', () {
    test('créer : POST /packs, puis nom dans les trois langues, puis relecture', () async {
      final id = await repo.createPack('  Les copains ');
      expect(id, 43);
      expect(api.calls, ['create', 'patch:43', 'created']);
      final names = (api.patchBody as Map)['nameI18n'] as Map;
      expect(names, {'fr': 'Les copains', 'en': 'Les copains', 'zh': 'Les copains'});
    });

    test('nom plafonné à 60 caractères', () async {
      await repo.createPack('x' * 100);
      final names = (api.patchBody as Map)['nameI18n'] as Map;
      expect((names['fr'] as String).length, 60);
    });

    test('créer : STICKER_PACK_LIMIT (20 packs) remonte tel quel', () async {
      api.failNext = TalkyException('', 409, code: 'STICKER_PACK_LIMIT');
      await expectLater(
          repo.createPack('x'),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'STICKER_PACK_LIMIT')));
      expect(api.calls, isEmpty);
    });

    test('créer : le nommage échoue mais le pack existe, il est relu', () async {
      var first = true;
      final a = _PatchFails(api, () {
        if (!first) return;
        first = false;
        throw TalkyException('', 429, code: 'RATE_LIMITED');
      });
      final r = StickerCreationRepository(db: db, api: a);
      await expectLater(r.createPack('x'), throwsA(isA<TalkyException>()));
      expect(api.calls, contains('created'));
    });

    test('renommer : trois langues, relecture', () async {
      await repo.renamePack(41, 'Nouveau nom');
      expect(api.calls, ['patch:41', 'created']);
      expect((api.patchBody as Map)['nameI18n'], containsPair('zh', 'Nouveau nom'));
    });

    test('renommer avec un nom vide : rien n\'est envoyé', () async {
      await repo.renamePack(41, '   ');
      expect(api.calls, isEmpty);
    });

    test('couverture : un sticker, ou null = premier', () async {
      await repo.setCover(41, 502);
      expect((api.patchBody as Map)['cover'], 502);
      await repo.setCover(41, null);
      expect((api.patchBody as Map)['reset'], isTrue);
    });

    test('archiver : le pack et ses stickers partent de Drift', () async {
      await repo.syncCreated();
      await repo.archivePack(41);
      expect(api.calls, contains('archive:41'));
      expect((await repo.watchCreated().first).map((p) => p.packId), [42]);
      expect(await repo.watchStickers(41).first, isEmpty);
    });
  });

  group('ajout depuis la galerie', () {
    test('PNG 512×512 transparent : envoyé avec le pack', () async {
      final r = await repo.addStickerFromImage(41, png512(), filename: 'a.png');
      expect(api.calls.first, startsWith('upload:41:a.png:'));
      expect((r.assetId, r.stickerId, r.packId, r.reused), (9003, 503, 41, false));
    });

    test('mauvaise taille : refus local, aucun appel réseau', () async {
      await expectLater(
          repo.addStickerFromImage(41, png(400, 400), filename: 'a.png'),
          throwsA(isA<StickerImageRejected>()
              .having((e) => e.issue, 'issue', StickerImageIssue.size)));
      expect(api.calls, isEmpty);
    });

    test('pas du tout une image : refus de format', () async {
      await expectLater(
          repo.addStickerFromImage(41, Uint8List.fromList([1, 2, 3]), filename: 'a.jpg'),
          throwsA(isA<StickerImageRejected>()));
      expect(api.calls, isEmpty);
    });

    test('quota de 200 stickers : STICKER_QUOTA_EXCEEDED remonte', () async {
      api.failNext = TalkyException('', 429, code: 'STICKER_QUOTA_EXCEEDED');
      await expectLater(
          repo.addStickerFromImage(41, png512(), filename: 'a.png'),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'STICKER_QUOTA_EXCEEDED')));
    });

    test('retirer : appel serveur, ligne locale supprimée', () async {
      await repo.syncCreated();
      await repo.removeSticker(41, 501);
      expect(api.calls, contains('remove:41:501'));
    });

    test('réordonner : local d\'abord, serveur ensuite', () async {
      await repo.syncCreated();
      await repo.reorderStickers(41, [502, 501]);
      expect(api.calls.last, 'order:41:[502, 501]');
      expect((await repo.watchStickers(41).first).map((s) => s.stickerId), [502, 501]);
    });

    test('réordonner refusé : l\'état serveur est relu', () async {
      await repo.syncCreated();
      api.failNext = TalkyException('', 500);
      await expectLater(repo.reorderStickers(41, [502, 501]), throwsA(isA<TalkyException>()));
      expect((await repo.watchStickers(41).first).map((s) => s.stickerId), [501, 502]);
    });
  });

  group('copie d\'un sticker reçu, signalement', () {
    test('copyToPack : par id de sticker (sid), puis relecture', () async {
      final r = await repo.copyToPack(777, packId: 41);
      expect(api.calls, ['copy:777:41', 'created']);
      expect((r.assetId, r.copied, r.reused), (9100, true, false));
    });

    test('copie : STICKER_ASSET_BLOCKED / PACK_LIMIT remontent', () async {
      api.failNext = TalkyException('', 422, code: 'STICKER_ASSET_BLOCKED');
      await expectLater(repo.copyToPack(777),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'STICKER_ASSET_BLOCKED')));
      api.failNext = TalkyException('', 409, code: 'STICKER_PACK_LIMIT');
      await expectLater(repo.copyToPack(777),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'STICKER_PACK_LIMIT')));
    });

    test('copie : 404 STICKER_NOT_FOUND (inaccessible/retiré) remonte, rien relu',
        () async {
      await repo.syncCreated(); // création ouverte
      api.calls.clear();
      api.failNext = TalkyException('', 404, code: 'STICKER_NOT_FOUND');
      await expectLater(repo.copyToPack(777),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'STICKER_NOT_FOUND')));
      expect(api.calls, isEmpty);
      // Un 404 « sticker retiré » n'est pas un module fermé.
      expect(repo.creationAvailable.value, isTrue);
    });

    test('copie d\'un sticker d\'un pack Plus : 403 SUBSCRIPTION_REQUIRED', () async {
      api.failNext = TalkyException('', 403,
          code: 'SUBSCRIPTION_REQUIRED', details: {'feature': 'stickers_premium'});
      await expectLater(
          repo.copyToPack(777),
          throwsA(isA<TalkyException>()
              .having((e) => e.code, 'code', 'SUBSCRIPTION_REQUIRED')
              .having((e) => e.details?['feature'], 'feature', 'stickers_premium')));
    });

    test('signaler : 404 STICKER_NOT_FOUND remonte', () async {
      api.failNext = TalkyException('', 404, code: 'STICKER_NOT_FOUND');
      await expectLater(repo.report(777, StickerReportReason.spam),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'STICKER_NOT_FOUND')));
    });

    test('signaler : le motif part tel quel, deja = faux puis vrai', () async {
      expect(await repo.report(777, StickerReportReason.inapproprie), isFalse);
      api.reportDeja = true;
      expect(await repo.report(777, StickerReportReason.droits), isTrue);
      expect(api.calls, ['report:777:inapproprie', 'report:777:droits']);
    });

    test('les quatre motifs du contrat', () {
      expect(StickerReportReason.values.map((e) => e.name),
          ['inapproprie', 'spam', 'droits', 'autre']);
    });
  });

  group('partage', () {
    test('partager : jeton mémorisé localement', () async {
      await repo.syncCreated();
      // Le pack 42 n'est pas partagé : on obtient le jeton de la fixture.
      final token = await repo.sharePack(42);
      expect(token, kToken);
      expect((await repo.packById(42))!.shareToken, kToken);
    });

    test('jeton mal formé dans la réponse : refusé', () async {
      final a = _BadToken(api);
      final r = StickerCreationRepository(db: db, api: a);
      await expectLater(r.sharePack(41), throwsA(isA<TalkyException>()));
    });

    test('révoquer : jeton effacé localement', () async {
      await repo.syncCreated();
      await repo.unsharePack(41);
      expect(api.calls, contains('unshare:41'));
      expect((await repo.packById(41))!.shareToken, isNull);
    });

    test('limites de débit : RATE_LIMITED remonte', () async {
      api.failNext = TalkyException('', 429, code: 'RATE_LIMITED');
      await expectLater(repo.sharePack(41),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'RATE_LIMITED')));
    });

    test('résoudre : fiche en lecture seule', () async {
      final p = await repo.resolveShare(kToken);
      expect(p.name, 'Les copains');
      expect(p.count, 2);
      expect(p.stickers.map((s) => s.id), [701, 702]);
      expect((p.mine, p.added, p.alreadyHere), (false, false, false));
    });

    test('résoudre : « déjà ajouté » et « c\'est mon pack »', () async {
      api.sharePreview = Map.of(fx('share-preview-deja.json') as Map).cast();
      var p = await repo.resolveShare(kToken);
      expect((p.added, p.addedPackId, p.alreadyHere), (true, 55, true));
      api.sharePreview = {...api.sharePreview, 'added': false, 'addedPackId': null, 'mine': true};
      p = await repo.resolveShare(kToken);
      expect((p.mine, p.alreadyHere), (true, true));
    });

    test('résoudre : lien révoqué = STICKER_PACK_UNAVAILABLE (404 avec code)', () async {
      api.failNext = TalkyException('', 404, code: 'STICKER_PACK_UNAVAILABLE');
      await expectLater(repo.resolveShare(kToken),
          throwsA(isA<TalkyException>().having((e) => e.code, 'code', 'STICKER_PACK_UNAVAILABLE')));
      // …et ce n'est PAS « création fermée » : les entrées restent visibles.
      await repo.syncCreated();
      expect(repo.creationAvailable.value, isTrue);
    });

    test('installer = copier : 201, packId, comptes et images ignorées', () async {
      final r = await repo.addShared(kToken);
      expect((r.packId, r.already, r.stickers, r.ignored), (55, false, 2, 1));
      expect(api.calls, ['addShare:$kToken', 'created']);
    });

    test('installer : déjà installé (200 deja) : rien de nouveau, pas de relecture', () async {
      api.shareAdd = Map.of(fx('share-add-deja.json') as Map).cast();
      final r = await repo.addShared(kToken);
      expect((r.already, r.mine, r.packId), (true, false, 55));
      expect(api.calls, ['addShare:$kToken']);
    });

    test('installer : STICKER_QUOTA_EXCEEDED et STICKER_PACK_LIMIT', () async {
      for (final (status, code) in [(429, 'STICKER_QUOTA_EXCEEDED'), (409, 'STICKER_PACK_LIMIT')]) {
        api.failNext = TalkyException('', status, code: code);
        await expectLater(repo.addShared(kToken),
            throwsA(isA<TalkyException>().having((e) => e.code, 'code', code)));
      }
    });

    test('un 404 NOT_FOUND générique sur une action ferme les entrées', () async {
      await repo.syncCreated();
      api.closed = true;
      await expectLater(repo.sharePack(41), throwsA(isA<TalkyException>()));
      expect(repo.creationAvailable.value, isFalse);
    });
  });

  test('tolérance : champs inconnus et JSON incomplet ignorés', () async {
    api.created = {
      'packs': [
        {'id': 'x', 'code': 'u_1_a'},
        {'id': 9, 'code': 'u_9_ok', 'futur': true, 'stickers': [
          {'id': 1, 'url': null},
          {'id': 2, 'url': 'https://<bucket>/stickers/u/9/a_b.webp', 'inconnu': 1},
        ]},
        'n\'importe quoi',
      ],
    };
    await repo.syncCreated();
    final p = await repo.watchCreated().first;
    expect(p.single.packId, 9);
    expect((await repo.watchStickers(9).first).single.stickerId, 2);
  });

  test('colonne Drift : insertion directe d\'un pack owned', () async {
    await db.into(db.localStickerPacks).insert(LocalStickerPacksCompanion.insert(
        packId: const Value(5), code: 'u_1_z', owned: const Value(true)));
    expect((await repo.watchCreated().first).single.code, 'u_1_z');
  });
}

class _Offline extends FakeCreationApi {
  @override
  Future<StickerHttpResult> getCreated() async =>
      throw TalkyException('réseau', 0);
}

class _PatchFails extends FakeCreationApi {
  _PatchFails(this.inner, this.onPatch);
  final FakeCreationApi inner;
  final void Function() onPatch;
  @override
  Future<StickerHttpResult> createPack() => inner.createPack();
  @override
  Future<StickerHttpResult> getCreated() => inner.getCreated();
  @override
  Future<void> patchPack(int packId,
      {Map<String, String>? nameI18n, int? coverStickerId, bool resetCover = false}) async {
    onPatch();
  }
}

class _BadToken extends FakeCreationApi {
  _BadToken(this.inner);
  final FakeCreationApi inner;
  @override
  Future<StickerHttpResult> sharePack(int packId) async =>
      const StickerHttpResult(201, body: {'token': 'court'});
  @override
  Future<StickerHttpResult> getCreated() => inner.getCreated();
}

