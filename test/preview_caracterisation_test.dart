// Caractérisation de `ConversationMerge.previewForMedia` pour les types 0-9,
// écrite AVANT l'ajout du type 10 (stickers). Elle fige le comportement
// actuel : un libellé qui change ici est une régression.
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/chat/conversation_merge.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String p(int type, String? content, {String? name, bool vu = false}) =>
      ConversationMerge.previewForMedia(type, content, name, isViewOnce: vu);

  late final dynamic l;
  setUpAll(() {
    LocaleController(); // enregistre l'instance utilisée par previewForMedia
    l = LocaleController.instance.l10n;
  });

  test('0 — texte : le contenu tel quel', () {
    expect(p(0, 'salut'), 'salut');
  });

  test('1, 2, 3, 4 — médias sans contenu : libellé localisé', () {
    expect(p(1, ''), l.photo);
    expect(p(1, '', vu: true), l.photoViewOnce);
    expect(p(2, ''), l.video);
    expect(p(2, '', vu: true), l.videoViewOnce);
    expect(p(3, ''), l.audio);
    expect(p(3, '', vu: true), l.audioViewOnce);
    expect(p(4, '', name: 'cv.pdf'), l.fileWithName('cv.pdf'));
    expect(p(4, ''), l.file);
  });

  test('5, 6, 7, 9 — JSON : jamais exposé, même cassé', () {
    for (final t in [5, 6, 7, 9]) {
      for (final c in ['{cassé', '{"x":1}']) {
        expect(p(t, c), isNot(contains('{')), reason: 'type $t, contenu $c');
      }
    }
  });

  test('8 — bienvenue : libellés des boutons', () {
    expect(p(8, '{"buttons":[{"label":"A","action":"route","target":"/x"}]}'), contains('A'));
  });

  test('10 — sticker : « 😂 Sticker », jamais le JSON (inversé en T3)', () {
    const valide =
        '{"v":1,"pack":"mboa","sid":4812,"emoji":"😂","w":512,"h":512,"a":0}';
    expect(p(10, valide, name: 'Sticker 😂'), l.stickerPreview('😂'));
    for (final c in ['{"v":1}', '{cassé', '', '{"v":7,"emoji":"🔥","x":{}}']) {
      expect(p(10, c, name: 'Sticker 😂'), isNot(contains('{')),
          reason: 'contenu $c');
    }
    expect(p(10, '{"v":7,"emoji":"🔥"}'), l.stickerPreview('🔥'));
    expect(p(10, '{cassé'), l.stickerWord);
  });
}
