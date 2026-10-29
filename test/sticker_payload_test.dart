// StickerPayload : lit les fixtures du contrat telles quelles.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/sticker_payload.dart';

Map<String, dynamic> _fixture(String nom) =>
    jsonDecode(File('test/fixtures/stickers/$nom').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('kStickerMessageType vaut 10', () {
    expect(kStickerMessageType, 10);
  });

  test('valide : sortie serveur canonique', () {
    final f = _fixture('message-sticker-valide.json');
    final p = StickerPayload.tryParse(f['sortie_serveur']['content'] as String);
    expect(p, isNotNull);
    expect(p!.isRenderable, isTrue);
    expect(p.pack, 'mboa');
    expect(p.sid, 4812);
    expect(p.emoji, '😂');
    expect((p.w, p.h, p.animated), (512, 512, false));
  });

  test('valide : entrée client (w/h/a fantaisistes) reste lisible', () {
    final f = _fixture('message-sticker-valide.json');
    final p = StickerPayload.tryParse(f['entree_client']['content'] as String);
    expect(p!.sid, 4812);
    expect(p.animated, isTrue);
  });

  test('encode produit la forme canonique relisible', () {
    final p = StickerPayload.tryParse(
        _fixture('message-sticker-valide.json')['sortie_serveur']['content']
            as String)!;
    final again = StickerPayload.tryParse(p.encode())!;
    expect((again.pack, again.sid, again.emoji), ('mboa', 4812, '😂'));
    expect(p.encode(), _fixture('message-sticker-valide.json')['sortie_serveur']['content']);
  });

  test('version future : repli, emoji lisible, jamais de JSON', () {
    final f = _fixture('message-sticker-version-future.json');
    final att = f['attendu_client'] as Map;
    final p = StickerPayload.tryParse(f['content'] as String);
    expect(p, isNotNull);
    expect(p!.isRenderable, isFalse);
    expect(p.emoji, att['emoji']);
    expect(att['jamais_afficher_json'], isTrue);
    expect(p.labelWith('Sticker'), '😂 Sticker');
  });

  test('hostile : aucun cas ne lève ni ne devient affichable', () {
    final f = _fixture('message-sticker-hostile.json');
    for (final c in (f['cas'] as List).cast<Map>()) {
      final nom = c['nom'] as String;
      final content = c.containsKey('content')
          ? c['content'] as String
          : 'x' * (c['content_longueur'] as int);
      final p = StickerPayload.tryParse(content);
      if (nom == 'proto') {
        expect(p, isNotNull, reason: nom);
        expect(p!.sid, 1);
      } else {
        expect(p?.isRenderable ?? false, isFalse, reason: nom);
      }
    }
  });

  test('sid : zéro, négatif, énorme, décimal refusés', () {
    for (final s in ['0', '-1', '9007199254740993', '1.5', 'null', 'true']) {
      expect(
        StickerPayload.tryParse('{"v":1,"pack":"a","sid":$s,"emoji":"x"}'),
        isNull,
        reason: s,
      );
    }
  });

  test('null / vide', () {
    expect(StickerPayload.tryParse(null), isNull);
    expect(StickerPayload.tryParse(''), isNull);
  });

  group('a : sticker animé (V1c, contrat §4c)', () {
    String c(String a) =>
        '{"v":1,"pack":"u_7_ab12cd34","sid":504,"emoji":"😀","w":512,"h":512$a}';

    test('fixture serveur : a = 1 → animé, affichable, emoji et pack lus', () {
      final f = _fixture('message-sticker-anime.json');
      final p =
          StickerPayload.tryParse(f['sortie_serveur']['content'] as String)!;
      expect(p.animated, isTrue);
      expect(p.isRenderable, isTrue);
      expect((p.pack, p.sid, p.emoji), ('u_7_ab12cd34', 504, '😀'));
    });

    test('a = 0 ou absent : fixe', () {
      expect(StickerPayload.tryParse(c(',"a":0'))!.animated, isFalse);
      expect(StickerPayload.tryParse(c(''))!.animated, isFalse);
    });

    test('a hostile : seul 1 (ou true) vaut animé, jamais une chaîne ni 2', () {
      for (final v in ['"1"', '2', '-1', '"true"', 'null', '[]', '{}', '1.5']) {
        final p = StickerPayload.tryParse(c(',"a":$v'));
        expect(p, isNotNull, reason: v);
        expect(p!.animated, isFalse, reason: v);
        expect(p.isRenderable, isTrue, reason: v);
      }
      expect(StickerPayload.tryParse(c(',"a":1.0'))!.animated, isTrue);
    });

    test('un client ne décide pas : le serveur réécrit `a` d\'après l\'actif', () {
      // Entrée client avec a = 0 pour un actif animé : le payload relu côté
      // client reste celui du serveur (a = 1). Ici : le parseur lit ce qu'on
      // lui donne, et `encode` ne fait que reproduire (le serveur ignore `a`).
      final f = _fixture('message-sticker-anime.json');
      final client =
          StickerPayload.tryParse(f['entree_client_a_fantaisiste']['content'] as String)!;
      expect(client.animated, isFalse);
      expect(client.encode(), contains('"a":0'));
      final server =
          StickerPayload.tryParse(f['sortie_serveur']['content'] as String)!;
      expect(server.encode(), f['sortie_serveur']['content']);
    });

    test('version future avec a = 1 : jamais affichable, pas animé à l\'écran', () {
      final p = StickerPayload.tryParse(
          '{"v":2,"pack":"x","sid":9,"emoji":"😀","a":1}')!;
      expect(p.isRenderable, isFalse);
    });
  });
}
