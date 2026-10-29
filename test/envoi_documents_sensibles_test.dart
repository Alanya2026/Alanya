import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:talky_flutter/core/db/app_database.dart';
import 'package:talky_flutter/core/db/chat_dao.dart';
import 'package:talky_flutter/core/services/chat/chat_api.dart';
import 'package:talky_flutter/core/services/chat/message_sender.dart';
import 'package:talky_flutter/core/services/documents_sensibles/descripteur_sensible.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/media_album.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/chats/apercu_documents_sensibles.dart';
import 'package:talky_flutter/widgets/documents_sensibles/dialogue_protection_pdf.dart';

/// L'API du serveur, réduite à ce que l'envoi de fichiers touche.
class _Api implements ChatApi {
  final emis = <Map<String, dynamic>>[];

  @override
  bool get isSocketReady => true;

  @override
  void sendSocketEvent(String event, dynamic data) =>
      emis.add(Map<String, dynamic>.from(data as Map));

  @override
  Future<Map<String, dynamic>> uploadMedia(
    File file, {
    void Function(double progress)? onProgress,
  }) async =>
      {'url': 'https://serveur/uploads/${file.path.split('/').last}'};

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Envoi de plusieurs documents sensibles, comme Alanya Work : sélection
/// multiple, protection PDF réglée une fois, aperçu avec légende.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // L'envoi lit des libellés hors de l'arbre (type de document).
  LocaleController();

  group('envoi de plusieurs fichiers', () {
    late Directory dossier;
    late AppDatabase db;
    late _Api api;
    late MessageSender sender;

    setUp(() {
      // `talky_outbox` dans le chemin : le fichier est déjà « en file »,
      // l'envoi ne le recopie pas (pas de path_provider dans les tests).
      dossier = Directory.systemTemp.createTempSync('talky_outbox_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      api = _Api();
      sender = MessageSender(
        api: api,
        dao: ChatDao(db),
        db: db,
        myId: () => 7,
        recompute: (_) async {},
        uploadProgress: ValueNotifier(const {}),
        inFlightUploads: <String>{},
      );
    });
    tearDown(() async {
      await db.close();
      dossier.deleteSync(recursive: true);
    });

    test('légende sur le premier, descripteur par fichier, aucune vignette',
        () async {
      final photo = File('${dossier.path}/photo.jpg')
        ..writeAsBytesSync(img.encodeJpg(img.Image(width: 64, height: 64)));
      final note = File('${dossier.path}/note.docx')..writeAsStringSync('x');
      final copie = File('${dossier.path}/copie.docx')..writeAsStringSync('y');
      const protege = DescripteurSensible(
        protection: ProtectionPdf(imprimer: false, proprietaire: 'patron'),
      );

      await sender.sendMediaFiles(
        conversationID: 3,
        content: '  Pour signature  ',
        items: [
          AlbumSendItem(
              file: photo, type: 1, mediaName: 'photo.jpg',
              sensible: const DescripteurSensible()),
          AlbumSendItem(
              file: note, type: 4, mediaName: 'note.docx', sensible: protege),
          // Une copie déjà signée, renvoyée en ordinaire.
          AlbumSendItem(file: copie, type: 4, mediaName: 'copie.docx'),
        ],
      );

      final lignes = await (db.select(db.localMessages)
            ..orderBy([(m) => OrderingTerm.asc(m.sendAt)]))
          .get();
      expect(lignes.map((m) => m.mediaName),
          ['photo.jpg', 'note.docx', 'copie.docx']);
      expect(lignes.map((m) => m.content), ['Pour signature', null, null]);
      expect(lignes.map((m) => m.isSensitive), [true, true, false]);
      expect(lignes[0].mediaThumb, isNull,
          reason: 'aucun aperçu d\'un document sensible ne part');
      expect(jsonDecode(lignes[1].mediaProtection!)['protection']['imprimer'],
          isFalse);
      expect(lignes[2].mediaProtection, isNull);

      expect(api.emis, hasLength(3));
      final parNom = {for (final e in api.emis) e['mediaName']: e};
      expect(parNom['photo.jpg']!['content'], 'Pour signature');
      expect(parNom['photo.jpg']!['isSensitive'], 1);
      expect(parNom['photo.jpg']!.containsKey('mediaThumb'), isFalse);
      expect(parNom['photo.jpg']!.containsKey('mediaProtection'), isFalse);
      expect(parNom['note.docx']!['mediaProtection'], protege.toJson());
      expect(parNom['copie.docx']!.containsKey('isSensitive'), isFalse);
    });

    test('un seul fichier : légende et descripteur gardés', () async {
      final f = File('${dossier.path}/a.docx')..writeAsStringSync('a');
      await sender.sendMediaFiles(
        conversationID: 3,
        content: 'Seul',
        items: [
          AlbumSendItem(
              file: f, type: 4, mediaName: 'a.docx',
              sensible: const DescripteurSensible()),
        ],
      );
      final m = (await db.select(db.localMessages).get()).single;
      expect(m.content, 'Seul');
      expect(m.isSensitive, isTrue);
      expect(api.emis.single['isSensitive'], 1);
    });
  });

  Widget appli(Widget enfant) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: enfant,
      );

  testWidgets('l\'aperçu : retirer un fichier, légende, envoi', (tester) async {
    final d = Directory.systemTemp.createTempSync('apercu_');
    addTearDown(() => d.deleteSync(recursive: true));
    final items = [
      AlbumSendItem(
          file: File('${d.path}/a.docx')..writeAsStringSync('a'),
          type: 4,
          mediaName: 'a.docx',
          sensible: const DescripteurSensible()),
      AlbumSendItem(
          file: File('${d.path}/b.mp3')..writeAsStringSync('b'),
          type: 3,
          mediaName: 'b.mp3'),
    ];
    ApercuDocumentsResult? r;
    await tester.pumpWidget(appli(Builder(
      builder: (context) => TextButton(
        onPressed: () async => r = await Navigator.push<ApercuDocumentsResult>(
          context,
          MaterialPageRoute(builder: (_) => ApercuDocumentsSensibles(items: items)),
        ),
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('2 documents sensibles'), findsOneWidget);
    expect(find.textContaining('visionneuse protégée'), findsOneWidget);

    // Deuxième fichier : une copie déjà signée, qui part en ordinaire.
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('document ordinaire'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('apercu-sensible-retirer')));
    await tester.pumpAndSettle();
    expect(find.text('Document sensible'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('apercu-sensible-legende')), '  Contrat  ');
    await tester.tap(find.byKey(const ValueKey('apercu-sensible-envoyer')));
    await tester.pumpAndSettle();
    expect(r!.items.map((i) => i.mediaName), ['a.docx']);
    expect(r!.caption, 'Contrat');
  });

  testWidgets('retirer le dernier fichier, c\'est renoncer', (tester) async {
    final d = Directory.systemTemp.createTempSync('apercu_');
    addTearDown(() => d.deleteSync(recursive: true));
    var rendu = 'pas encore';
    await tester.pumpWidget(appli(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final x = await Navigator.push<ApercuDocumentsResult>(
            context,
            MaterialPageRoute(
              builder: (_) => ApercuDocumentsSensibles(items: [
                AlbumSendItem(
                    file: File('${d.path}/a.docx')..writeAsStringSync('a'),
                    type: 4,
                    mediaName: 'a.docx',
                    sensible: const DescripteurSensible()),
              ]),
            ),
          );
          rendu = '$x';
        },
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apercu-sensible-retirer')));
    await tester.pumpAndSettle();
    expect(rendu, 'null');
  });

  testWidgets('la protection PDF se règle une fois pour plusieurs PDF',
      (tester) async {
    await tester.pumpWidget(appli(Builder(
      builder: (context) => TextButton(
        onPressed: () => demanderProtectionPdf(context, nombre: 3),
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('les 3 PDF de cet envoi'), findsOneWidget);
  });
}
