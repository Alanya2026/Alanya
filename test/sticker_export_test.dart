import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/services/export/export_index_html.dart';
import 'package:talky_flutter/core/services/export/export_manifest.dart';
import 'package:talky_flutter/core/services/export/export_scan.dart';
import 'package:talky_flutter/core/services/export/export_zip_builder.dart';
import 'package:talky_flutter/core/services/media_expiry_policy.dart';
import 'package:talky_flutter/core/utils/sticker_payload.dart';

/// Un sticker (type 10) dans l'archive : **référence + vignette**, jamais le
/// JSON brut du message, et jamais absent en silence.
///
/// Ces tests visent les deux promesses du point 10 de §7.3 : quand l'image est
/// là, elle part dans « Alanya Stickers » avec de quoi la référencer ; quand
/// elle n'y est pas, l'archive le dit — elle n'oublie pas et n'invente pas.
void main() {
  late AppDatabase db;
  late ChatDao dao;
  late Directory tmp;
  late Directory cache;

  const myId = 42;
  final march = DateTime.utc(2026, 3, 14, 9);

  // Pack, identifiant et emoji : la référence minimale d'un sticker.
  const content = '{"v":1,"pack":"royal","sid":7,"emoji":"😂"}';
  const stickerUrl = 'https://cdn.alanya.app/uploads/official/stickers/'
      'royal/royal_7.webp';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ChatDao(db);
    tmp = await Directory.systemTemp.createTemp('alanya_sticker_export');
    cache = Directory(p.join(tmp.path, 'sticker_cache'))..createSync();
    MediaExpiryPolicy.resetForTests();
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// Insère un message de type 10 et, si [cached], écrit un fichier dans le
  /// cache dédié — **sans extension**, comme le fait `flutter_cache_manager`,
  /// pour que le repli d'extension via l'URL soit réellement exercé.
  Future<File?> addSticker({
    String clientId = 'sticker',
    String emoji = '😂',
    String url = stickerUrl,
    bool cached = true,
    DateTime? sendAt,
    int msgID = 700,
  }) async {
    final file = File(p.join(cache.path, '${clientId}_asset'));
    if (cached) await file.writeAsString('webp-bytes-$clientId');
    await db.into(db.localMessages).insert(LocalMessagesCompanion.insert(
          clientId: clientId,
          msgID: Value(msgID),
          conversationID: 1,
          senderID: 7,
          sendAt: sendAt ?? march,
          type: const Value(kStickerMessageType),
          content: const Value(content),
          mediaName: const Value('Sticker 😂'),
          mediaUrl: const Value(stickerUrl),
          // Un sticker ne renseigne jamais `localMediaPath` : son image vit
          // dans le cache dédié, indexé par URL.
          syncPending: const Value(false),
        ));
    return cached ? file : null;
  }

  /// Résolveur de vignette : rend le fichier écrit pour l'URL donnée.
  StickerFileResolver resolverFor(Map<String, File> files) =>
      (msg) async => files[msg.mediaUrl];

  test('kExportMediaTypes emporte le type 10, kMyMediaTypes non', () {
    expect(kExportMediaTypes, contains(kStickerMessageType));
    expect(kMyMediaTypes, isNot(contains(kStickerMessageType)));
  });

  test('un sticker caché entre dans « Alanya Stickers » avec sa référence',
      () async {
    final file = (await addSticker())!;

    final scan = await ExportScanner(
      dao,
      stickerFile: resolverFor({stickerUrl: file}),
    ).scan(myId, now: DateTime.utc(2026, 3, 20));

    expect(scan.present, hasLength(1));
    expect(scan.missing, isEmpty);
    final media = scan.present.single;
    expect(p.dirname(media.archivePath), 'Alanya Stickers');
    // Le nom d'archive n'a pas de nom d'origine exploitable : l'extension est
    // reprise de l'URL (`…webp`), à défaut d'un `bin` générique.
    expect(media.archivePath, endsWith('.webp'));

    final manifest = await ExportZipBuilder().build(
      destination: File(p.join(tmp.path, 'export.zip')),
      scan: scan,
      alanyaID: myId,
      indexHtmlBuilder: buildExportIndexHtml,
    );

    final item = manifest.items.single;
    expect(item.type, kStickerMessageType);
    expect(item.isSticker, isTrue);
    expect(item.stickerPack, 'royal');
    expect(item.stickerSid, 7);
    expect(item.stickerEmoji, '😂');
    expect(item.sha256, isNotEmpty);
    expect(item.originalName, 'Sticker 😂');

    // L'archive porte le fichier, le manifeste et l'index.
    final archive = ZipDecoder().decodeBytes(
      File(p.join(tmp.path, 'export.zip')).readAsBytesSync(),
    );
    final names = archive.files.map((f) => f.name).toList();
    expect(names.any((n) => n.startsWith('Alanya Stickers/')), isTrue);

    // Jamais le JSON brut : ni la charge du message, ni ses clés internes.
    final manifestRaw = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'manifest.json').readBytes()!,
    );
    expect(manifestRaw, isNot(contains(content)));
    expect(manifestRaw, isNot(contains('"sid"')));
    expect(manifestRaw, isNot(contains('"v":')));

    // L'index HTML prévisualise le sticker comme une image, chemin relatif
    // (les espaces du dossier sont encodés pour le navigateur).
    final html = utf8.decode(
      archive.files.firstWhere((f) => f.name == 'index.html').readBytes()!,
    );
    expect(html, contains('Alanya%20Stickers/'));
    expect(html, contains('<img'));
  });

  test('un sticker sans vignette en cache est déclaré, jamais omis', () async {
    await addSticker(cached: false);

    // Aucun résolveur : le sticker est manquant, pas silencieusement absent.
    final scan = await ExportScanner(dao).scan(myId);
    expect(scan.present, isEmpty);
    final missing = scan.missing.single;
    expect(missing.reason, MissingReason.neverDownloaded);
    expect(missing.isSticker, isTrue);
    // Il est sur le serveur : il reste récupérable côté client.
    expect(scan.recoverable, hasLength(1));
    expect(scan.lost, isEmpty);

    final manifest = await ExportZipBuilder().build(
      destination: File(p.join(tmp.path, 'export.zip')),
      scan: scan,
      alanyaID: myId,
    );
    expect(manifest.items, isEmpty);
    expect(manifest.missing.single.isSticker, isTrue);
    expect(manifest.missing.single.type, kStickerMessageType);
  });

  test('le verdict serveur ne classe pas un sticker absent comme perdu',
      () async {
    await addSticker(cached: false, msgID: 701);
    final scan = await ExportScanner(dao).scan(myId);
    expect(scan.recoverable.single.isSticker, isTrue);

    // Le serveur ne connaît pas la partition média d'un sticker : sa réponse
    // ne le liste donc pas. Sans précaution, il serait déclaré « perdu ».
    final refined = scan.withServerVerdict(available: const {}, sizes: const {});
    expect(refined.recoverable, hasLength(1));
    expect(refined.recoverable.single.isSticker, isTrue);
    expect(refined.lost, isEmpty);
  });

  test('un sticker de plus de 100 jours s\'affiche encore', () async {
    // Rétention apprise : 30 jours. Le sticker a été échangé il y a plus de
    // 100 jours — un média ordinaire de la même date serait, lui, expiré.
    MediaExpiryPolicy.resetForTests(retentionDays: 30);
    final oldDay = DateTime.utc(2025, 11, 1, 10); // ~ 139 jours avant mars.
    final file = (await addSticker(sendAt: oldDay))!;

    // L'URL d'un sticker n'est pas dans une partition média : jamais expirée.
    expect(MediaExpiryPolicy.isExpired(stickerUrl), isFalse);

    final scan = await ExportScanner(
      dao,
      stickerFile: resolverFor({stickerUrl: file}),
    ).scan(myId);
    expect(scan.present, hasLength(1));
    expect(scan.missing, isEmpty);
  });

  test('un média ordinaire de la même date reste soumis à la rétention',
      () async {
    // Contre-épreuve : la rétention est bien active, seul le sticker y échappe.
    MediaExpiryPolicy.resetForTests(retentionDays: 30);
    expect(
      MediaExpiryPolicy.isExpired(
        'https://cdn.alanya.app/uploads/media/2025-11-01/photo_1.jpg',
      ),
      isTrue,
    );
  });
}
