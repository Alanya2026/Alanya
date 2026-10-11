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
}
