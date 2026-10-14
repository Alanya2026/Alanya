// Le texte en cours de saisie survit à la fermeture de la discussion.
//
// Il disparaissait dès qu'on quittait la discussion (signalement du groupe
// 3GI 2029, bug A10).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/chat/chat_draft_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enregistré puis relu', () async {
    await ChatDraftStore.save(7, 316, 'Bonjour à\ntous');
    expect(await ChatDraftStore.load(7, 316), 'Bonjour à\ntous');
  });

  test('un brouillon par conversation et par compte', () async {
    await ChatDraftStore.save(7, 316, 'groupe');
    expect(await ChatDraftStore.load(7, 488), isNull);
    expect(await ChatDraftStore.load(8, 316), isNull);
  });

  test('texte vide ou blanc : brouillon effacé', () async {
    await ChatDraftStore.save(7, 316, 'à envoyer');
    await ChatDraftStore.save(7, 316, '   ');
    expect(await ChatDraftStore.load(7, 316), isNull);
    await ChatDraftStore.save(7, 316, 'à envoyer');
    await ChatDraftStore.clear(7, 316);
    expect(await ChatDraftStore.load(7, 316), isNull);
  });
}
