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

  Map<String, dynamic> fichier(int id, String name, String family, String quand,
          {Map<String, dynamic>? meta, Map<String, dynamic>? note}) => {
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
        'note': ?note,
      };

  /// Les demandes reçues par le faux serveur : « DELETE /folders/31 »…
  final demandes = <String>[];
  setUp(demandes.clear);

  final album = [
    fichier(1, 'Plage.jpg', 'photos', '2025-03-03T10:00:00Z'),
    fichier(2, 'Coucher.jpg', 'photos', '2025-03-03T09:00:00Z'),
    fichier(3, 'Danse.mp4', 'videos', '2025-03-02T10:00:00Z', meta: {'durationMs': 84000}),
    fichier(4, 'Hotel.pdf', 'documents', '2025-03-01T10:00:00Z'),
  ];

  /// Avec [suite], une deuxième page (curseur 999) : le dossier se charge par pages.
  /// [sousDossiers] : les sous-dossiers du dossier 30 ; le 32 est vide, les autres contiennent [album].
  http.Client serveur(String root, List<Map<String, dynamic>> files,
          {List<Map<String, dynamic>>? suite, List<Map<String, dynamic>> sousDossiers = const []}) =>
      MockClient((req) async {
        demandes.add('${req.method} ${req.url.path.replaceFirst(RegExp(r'^.*/safebox'), '')}');
        if (req.method == 'DELETE') {
          return http.Response(jsonEncode({'ok': true, 'trashed': 1}), 200, headers: {'content-type': 'application/json'});
        }
        final sous = RegExp(r'/folders/(\d+)$').firstMatch(req.url.path);
        if (sous != null && sous.group(1) != '30') {
          final corps = {
            'folder': {'id': int.parse(sous.group(1)!), 'parentId': 30, 'root': root, 'name': 'Plage', 'depth': 2},
            'breadcrumbs': [],
            'folders': [],
            'files': sous.group(1) == '32' ? [] : album,
            'nextCursor': null,
          };
          return http.Response(jsonEncode(corps), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
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
                'folders': req.url.queryParameters['cursor'] == null ? sousDossiers : [],
                'files': req.url.queryParameters['cursor'] == null ? files : (suite ?? const []),
                'nextCursor': suite != null && req.url.queryParameters['cursor'] == null ? 999 : null,
              };
        return http.Response(jsonEncode(corps), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

  Future<void> monter(WidgetTester tester, SafeboxRoot root, List<Map<String, dynamic>> files,
      {List<Map<String, dynamic>>? suite, List<Map<String, dynamic>> sousDossiers = const []}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(
        api: TalkyApiClient(client: serveur(root.name, files, suite: suite, sousDossiers: sousDossiers)));
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

  testWidgets('⋮ d\'un sous-dossier : son menu, « Envoyer l\'album » en tête', (tester) async {
    await monter(tester, SafeboxRoot.albums, const [], sousDossiers: [
      {'id': 32, 'parentId': 30, 'root': 'albums', 'name': 'Vide', 'depth': 2},
    ]);
    await tester.tap(find.descendant(of: find.widgetWithText(ListTile, 'Vide'), matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxSendAlbum), findsOneWidget);
    expect(find.text(fr.safeboxRename), findsOneWidget);
    await tester.tap(find.text(fr.safeboxSendAlbum));
    await tester.pumpAndSettle();
    // Son contenu a été chargé : vide, il le dit au lieu de ne rien faire.
    expect(find.text(fr.safeboxFolderEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plusieurs dossiers sélectionnés : envoyer, déplacer, supprimer ensemble', (tester) async {
    await monter(tester, SafeboxRoot.albums, album, sousDossiers: [
      {'id': 31, 'parentId': 30, 'root': 'albums', 'name': 'Plage', 'depth': 2},
      {'id': 32, 'parentId': 30, 'root': 'albums', 'name': 'Vide', 'depth': 2},
    ]);
    await tester.longPress(find.text('Plage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vide'));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxSelectedCount(2)), findsOneWidget);
    expect(find.text(fr.safeboxFoldersCount(2)), findsOneWidget);
    // Avec des dossiers : ni « Télécharger », ni « Album ».
    expect(find.text(fr.safeboxDownload), findsNothing);
    expect(find.text(fr.safeboxAddToAlbum), findsNothing);
    expect(find.text(fr.safeboxSendToChat), findsOneWidget);
    expect(find.text(fr.safeboxMove), findsOneWidget);
    // Un fichier en plus dans la même sélection.
    await tester.tap(find.byType(SafeboxGridTile).first);
    await tester.pumpAndSettle();
    expect(find.text('${fr.safeboxFoldersCount(2)} · ${fr.safeboxFilesCount(1)}'), findsOneWidget);
    // Les deux dossiers à la corbeille d'un coup (le fichier retiré : sa
    // suppression touche au disque du téléphone, absent ici).
    await tester.tap(find.byType(SafeboxGridTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(fr.safeboxDelete));
    await tester.pumpAndSettle();
    expect(demandes, containsAll(['DELETE /folders/31', 'DELETE /folders/32']));
    expect(find.text(fr.safeboxSelectedCount(2)), findsNothing, reason: 'la sélection est quittée');
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Avec commentaire » : une bulle sur la vignette, et le filtre', (tester) async {
    await monter(tester, SafeboxRoot.albums, [
      fichier(1, 'Plage.jpg', 'photos', '2025-03-03T10:00:00Z', note: {'text': 'Avant la pluie'}),
      ...album.skip(1),
    ]);
    expect(find.byIcon(Icons.chat_bubble), findsOneWidget, reason: 'un texte : une bulle, pas un micro');
    expect(find.byType(SafeboxGridTile), findsNWidgets(4));
    await tester.tap(find.widgetWithText(FilterChip, fr.safeboxFilterWithNote));
    await tester.pumpAndSettle();
    expect(find.byType(SafeboxGridTile), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, fr.safeboxFilterWithNote));
    await tester.pumpAndSettle();
    expect(find.byType(SafeboxGridTile), findsNWidgets(4));
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
