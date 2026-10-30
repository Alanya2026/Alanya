import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:talky_flutter/screens/safebox/safebox_folder_screen.dart';
import 'package:talky_flutter/screens/safebox/safebox_grid.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// L'écran d'un dossier (lot 8) : filtres par type dans un album, sélection
/// par appui long et sa barre d'actions, feuille « Télécharger », photos par jour.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));

  Map<String, dynamic> fichier(int id, String name, String family, String quand, {Map<String, dynamic>? meta}) => {
        'id': id,
        'folderId': 30,
        'name': name,
        'ext': name.split('.').last,
        'family': family,
        'plainBytes': 1000 * id,
        'storedBytes': 1000 * id + 16,
        'compressed': false,
        'quality': 'original',
        'cipherFormat': 'SBX1',
        'createdAt': quand,
        'alsoIn': [],
        'meta': ?meta,
      };

  final album = [
    fichier(1, 'Plage.jpg', 'photos', '2025-03-03T10:00:00Z'),
    fichier(2, 'Coucher.jpg', 'photos', '2025-03-03T09:00:00Z'),
    fichier(3, 'Danse.mp4', 'videos', '2025-03-02T10:00:00Z', meta: {'durationMs': 84000}),
    fichier(4, 'Hotel.pdf', 'documents', '2025-03-01T10:00:00Z'),
  ];

  /// Avec [suite], une deuxième page (curseur 999) : le dossier se charge par pages.
  http.Client serveur(String root, List<Map<String, dynamic>> files, {List<Map<String, dynamic>>? suite}) =>
      MockClient((req) async {
        final corps = req.url.path.endsWith('/safebox')
            ? {
                'quota': {'quotaBytes': 1 << 30, 'usedBytes': 0, 'pendingBytes': 0, 'trashBytes': 0, 'byRoot': {}},
                'roots': [
                  for (final (i, r) in ['photos', 'videos', 'audios', 'documents', 'albums', 'partager'].indexed)
                    {'id': 11 + i, 'root': r},
                ],
                'limits': {'maxFileBytes': 1 << 30, 'extensions': {}},
              }
            : {
                'folder': {'id': 30, 'parentId': 15, 'root': root, 'name': 'Kribi 2026', 'depth': 1},
                'breadcrumbs': [],
                'folders': [],
                'files': req.url.queryParameters['cursor'] == null ? files : (suite ?? const []),
                'nextCursor': suite != null && req.url.queryParameters['cursor'] == null ? 999 : null,
              };
        return http.Response(jsonEncode(corps), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

  Future<void> monter(WidgetTester tester, SafeboxRoot root, List<Map<String, dynamic>> files,
      {List<Map<String, dynamic>>? suite}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(api: TalkyApiClient(client: serveur(root.name, files, suite: suite)));
    await c.refreshOverview();
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: SafeboxFolderScreen(folderId: 30, root: root),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('album : filtre par type, durée d\'une vidéo, nom d\'un document', (tester) async {
    await monter(tester, SafeboxRoot.albums, album);
    expect(find.byType(SafeboxGridTile), findsNWidgets(4));
    expect(find.text('1:24'), findsOneWidget);
    expect(find.text('Hotel.pdf'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, fr.safeboxRootVideos));
    await tester.pumpAndSettle();
    expect(find.byType(SafeboxGridTile), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, fr.safeboxFilterAll));
    await tester.pumpAndSettle();
    expect(find.byType(SafeboxGridTile), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('appui long : sélection, barre d\'actions, « Tout sélectionner », feuille Télécharger', (tester) async {
    await monter(tester, SafeboxRoot.albums, album);
    await tester.longPress(find.byType(SafeboxGridTile).first);
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxSelectedCount(1)), findsOneWidget);
    expect(find.text(fr.safeboxDownload), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.tap(find.text(fr.safeboxSelectAll));
    await tester.pumpAndSettle();
    expect(find.textContaining(fr.safeboxSelectedCount(4)), findsWidgets);
    await tester.tap(find.text(fr.safeboxDownload));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxDownloadGallery), findsOneWidget);
    expect(find.text(fr.safeboxDownloadFolder('Kribi 2026')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Tout sélectionner » prend aussi les pages suivantes ; « Envoyer l\'album » au menu', (tester) async {
    await monter(tester, SafeboxRoot.albums, album.take(2).toList(), suite: album.skip(2).toList());
    expect(find.byType(SafeboxGridTile), findsNWidgets(2), reason: 'première page seulement');
    await tester.longPress(find.byType(SafeboxGridTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(fr.safeboxSelectAll));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxSelectedCount(4)), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxSendAlbum), findsOneWidget);
    expect(find.text(fr.safeboxDownloadFolderAction), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photos : groupées par jour', (tester) async {
    await monter(tester, SafeboxRoot.photos, album.take(2).toList() + [
      fichier(5, 'Hier.jpg', 'photos', '2025-03-02T08:00:00Z'),
    ]);
    expect(find.text('3 mars 2025'), findsOneWidget);
    expect(find.text('2 mars 2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
