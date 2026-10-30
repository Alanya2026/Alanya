import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_home_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Le coffre à onglets (lot 8) s'affiche sur un faux serveur : accueil, puis
/// Fichiers, Partager et Transferts, sans erreur de mise en page.
void main() {
  setUpAll(LocaleController.new);
  const go = 1 << 30;
  final fr = lookupAppLocalizations(const Locale('fr'));

  http.Response json(Object body, [int code = 200]) =>
      http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});

  Map<String, dynamic> dossier(int id, String root, {List<Map<String, dynamic>> folders = const []}) => {
        'folder': {'id': id, 'parentId': null, 'root': root, 'name': null, 'depth': 0},
        'breadcrumbs': [],
        'folders': folders,
        'files': [],
        'nextCursor': null,
      };

  final serveur = MockClient((req) async {
    final chemin = req.url.path;
    if (chemin.endsWith('/safebox')) {
      return json({
        'quota': {
          'quotaBytes': 10 * go,
          'usedBytes': 7 * go,
          'pendingBytes': 0,
          'trashBytes': 0,
          'plus': false,
          'baseQuotaBytes': 10 * go,
          'byRoot': {
            'photos': {'bytes': 3 * go, 'files': 1240},
            'videos': {'bytes': 2 * go, 'files': 86},
            'audios': {'bytes': 0, 'files': 0},
            'documents': {'bytes': go ~/ 4, 'files': 64},
            'albums': {'bytes': go ~/ 2, 'files': 12},
            'partager': {'bytes': go, 'files': 7},
          },
        },
        'roots': [
          for (final (i, r) in ['photos', 'videos', 'audios', 'documents', 'albums', 'partager'].indexed)
            {'id': 11 + i, 'root': r},
        ],
        'limits': {'maxFileBytes': go, 'blockBytes': 8 << 20, 'maxPreviewBytes': 262144, 'extensions': {}},
      });
    }
    if (chemin.endsWith('/safebox/folders/15')) {
      return json(dossier(15, 'albums', folders: [
        {'id': 30, 'parentId': 15, 'root': 'albums', 'name': 'Kribi 2026', 'depth': 1},
      ]));
    }
    final m = RegExp(r'/safebox/folders/(\d+)$').firstMatch(chemin);
    if (m != null) return json(dossier(int.parse(m.group(1)!), 'partager'));
    return json({'error': 'inconnu', 'code': 'NOT_FOUND'}, 404);
  });

  /// Démonte l'écran puis ferme le contrôleur : ses minuteries (sauvegarde
  /// automatique, présence de l'application) s'arrêtent avec lui.
  Future<void> demonter(WidgetTester tester, SafeboxController c) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }

  Future<SafeboxController> monter(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(api: TalkyApiClient(client: serveur));
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: const SafeboxHomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('un seul écran : espace, une carte d\'état, six dossiers, albums récents, pas d\'onglets', (tester) async {
    final c = await monter(tester);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text(fr.safeboxSpaceTitle), findsOneWidget);
    // Une seule carte : les envois, puis la sauvegarde automatique.
    expect(find.text(fr.safeboxStatusSafe), findsOneWidget);
    expect(find.text(fr.safeboxBackupTitle), findsOneWidget);
    expect(find.text(fr.safeboxBackupActivate), findsOneWidget);
    await tester.scrollUntilVisible(find.text(fr.safeboxNewAlbum), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text(fr.safeboxMyFolders.toUpperCase()), findsOneWidget);
    for (final r in [fr.safeboxRootPhotos, fr.safeboxRootVideos, fr.safeboxRootAudios, fr.safeboxRootDocuments, fr.safeboxRootAlbums, fr.safeboxRootShare]) {
      expect(find.text(r), findsWidgets, reason: r);
    }
    expect(find.text('Kribi 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await demonter(tester, c);
  });

  testWidgets('les transferts par l\'icône de la barre, Partager comme un dossier', (tester) async {
    final c = await monter(tester);
    await tester.tap(find.byTooltip(fr.safeboxTabTransfers));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxNoTransfers), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    // La carte d'état ouvre aussi les transferts.
    await tester.tap(find.text(fr.safeboxStatusSafe));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxNoTransfers), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    final tuile = find.descendant(of: find.byType(GridView), matching: find.text(fr.safeboxRootShare));
    await tester.scrollUntilVisible(tuile, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(tuile);
    await tester.pumpAndSettle();
    await tester.tap(tuile);
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxShareTabSent(0)), findsOneWidget, reason: 'Mes envois et Reçus');
    expect(find.text(fr.safeboxFolderEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
    await demonter(tester, c);
  });
}
