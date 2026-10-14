// Protège la requête `ChatDao.searchCandidates` : chacune des exclusions du
// brief doit tenir, sinon la recherche remonterait des messages supprimés, des
// contenus JSON ou des vues uniques non ouvertes.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/utils/media_album.dart';

void main() {
  late AppDatabase db;
  late ChatDao dao;
  var n = 0;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatDao(db);
  });
  tearDown(() => db.close());

  Future<void> ajoute({
    int conv = 1,
    int msgID = 1,
    String? content = 'bonjour',
    int type = 0,
    bool deleted = false,
    int? deletedFor,
    bool viewOnce = false,
    DateTime? viewedAt,
  }) {
    n++;
    return db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
          clientId: 'c$n',
          conversationID: conv,
          senderID: 5,
          sendAt: DateTime.utc(2026, 1, 1, 10, n % 60),
          msgID: Value(msgID),
          content: Value(content),
          type: Value(type),
          isDeleted: Value(deleted),
          deletedForID: Value(deletedFor),
          isViewOnce: Value(viewOnce),
          viewedAt: Value(viewedAt),
        ));
  }

  test('garde un message normal, une légende de photo, de vidéo et de fichier',
      () async {
    await ajoute(msgID: 1);
    await ajoute(msgID: 2, type: 1, content: 'légende');
    await ajoute(msgID: 3, type: 2);
    await ajoute(msgID: 4, type: 4);
    final r = await dao.searchCandidates(1, 99);
    expect(r.map((e) => e.msgID).toSet(), {1, 2, 3, 4});
  });

  test('exclut chaque cas non cherchable', () async {
    await ajoute(msgID: 10, conv: 2); // autre conversation
    await ajoute(msgID: 0); // pas confirmé
    await ajoute(msgID: 11, deleted: true);
    await ajoute(msgID: 12, deletedFor: 99); // supprimé pour moi
    await ajoute(msgID: 13, type: 3); // audio
    await ajoute(msgID: 14, type: 5, content: '{"lat":1}'); // JSON
    await ajoute(msgID: 15, type: 6, content: '{}');
    await ajoute(msgID: 16, viewOnce: true); // vue unique non ouverte
    await ajoute(msgID: 17, content: null);
    await ajoute(msgID: 18, content: '$albumMarkerPrefix|a|0|2|2|0');
    expect(await dao.searchCandidates(1, 99), isEmpty);
  });

  test('garde ce qui est supprimé pour un autre, et une vue unique ouverte',
      () async {
    await ajoute(msgID: 20, deletedFor: 7);
    await ajoute(
        msgID: 21, viewOnce: true, viewedAt: DateTime.utc(2026, 1, 2));
    final r = await dao.searchCandidates(1, 99);
    expect(r.map((e) => e.msgID).toSet(), {20, 21});
  });
}
