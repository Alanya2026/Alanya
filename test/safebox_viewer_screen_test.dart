import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_note_widgets.dart';
import 'package:talky_flutter/screens/safebox/safebox_viewer_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// La visionneuse d'un dossier : d'un fichier à l'autre d'un glissement,
/// avec les commentaires, et sans télécharger une grosse vidéo en passant.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));

  SafeboxFile fichier(int id, String nom, SafeboxFamily famille, {int taille = 1000, SafeboxNote? note}) => SafeboxFile(
        id: id, folderId: 30, name: nom, ext: nom.split('.').last, mime: null, family: famille,
        plainBytes: taille, storedBytes: taille + 16, originalBytes: null, compressed: false,
        cipherFormat: 'SBX1', key: null, previewUrl: null, note: note,
      );

  /// Fait avancer l'animation et les lectures de fichiers réelles. Pas de
  /// pumpAndSettle : une barre de téléchargement tourne sans fin.
  Future<void> laisserFaire(WidgetTester tester) async {
    for (var i = 0; i < 8; i += 1) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> monter(WidgetTester tester, List<SafeboxFile> files, {int depart = 0, Future<List<SafeboxFile>> Function()? suite}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(api: TalkyApiClient(client: MockClient((_) async => http.Response('{}', 404))));
    addTearDown(c.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: SafeboxViewerScreen(files: files, initialIndex: depart, loadMore: suite),
      ),
    ));
    await laisserFaire(tester);
  }

  Future<void> glisser(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await laisserFaire(tester);
  }

  testWidgets('d\'un fichier à l\'autre : position, commentaires, et rien sous une vidéo', (tester) async {
    await monter(tester, [
      fichier(1, 'Plage.jpg', SafeboxFamily.photos, note: const SafeboxNote(text: 'Avant la pluie')),
      fichier(2, 'Danse.mp4', SafeboxFamily.videos, taille: 200 << 20),
      fichier(3, 'Coucher.jpg', SafeboxFamily.photos),
    ]);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Plage.jpg'), findsOneWidget);
    expect(find.text('Avant la pluie'), findsOneWidget);
    expect(find.text(fr.safeboxNoteEdit), findsOneWidget);

    // Une grosse vidéo attend qu'on la demande ; pas de commentaire sur une vidéo.
    await glisser(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Avant la pluie'), findsNothing);
    expect(find.text(fr.safeboxNoteAdd), findsNothing);
    expect(find.text(fr.safeboxVideoPlay('200 Mo')), findsOneWidget);

    await glisser(tester);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text(fr.safeboxNoteAdd), findsOneWidget, reason: 'une photo sans commentaire invite à en ajouter');
    expect(tester.takeException(), isNull);
  });

  testWidgets('commentaire audio : son lecteur s\'affiche sous la photo', (tester) async {
    await monter(tester, [
      fichier(1, 'Plage.jpg', SafeboxFamily.photos,
          note: SafeboxNote.fromJson({
            'text': 'Avec Paul',
            'audio': {'durationMs': 5000, 'plainBytes': 984, 'storedBytes': 1000, 'url': 'https://s4/a', 'key': 'AAAA'},
          })),
    ]);
    expect(find.text('Avec Paul'), findsOneWidget);
    expect(find.byType(SafeboxNotePlayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en approchant de la fin : la page suivante du dossier s\'ajoute', (tester) async {
    final deux = [fichier(1, 'a.jpg', SafeboxFamily.photos), fichier(2, 'b.jpg', SafeboxFamily.photos)];
    await monter(tester, deux, suite: () async => [...deux, fichier(3, 'c.jpg', SafeboxFamily.photos)]);
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('une vraie photo : elle s\'affiche dans son zoom, et le glissement passe à la suivante', (tester) async {
    final dossier = await tester.runAsync(() => Directory.systemTemp.createTemp('coffre_visionneuse'));
    addTearDown(() => dossier!.deleteSync(recursive: true));
    const chemins = MethodChannel('plugins.flutter.io/path_provider');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(chemins, (_) async => dossier!.path);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(chemins, null));
    await tester.runAsync(() async {
      final f = File('${dossier!.path}/safebox/files/1/Plage.jpg');
      await f.create(recursive: true);
      await f.writeAsBytes(Uint8List(1000));
    });
    await monter(tester, [fichier(1, 'Plage.jpg', SafeboxFamily.photos), fichier(2, 'Danse.mp4', SafeboxFamily.videos, taille: 200 << 20)]);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await glisser(tester);
    expect(find.text('2 / 2'), findsOneWidget);
    tester.takeException(); // les octets vides ne sont pas une image : seul le geste compte ici
  });
}
