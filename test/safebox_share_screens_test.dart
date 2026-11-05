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
import 'package:talky_flutter/core/utils/safebox_share_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_folder_screen.dart';
import 'package:talky_flutter/screens/safebox/safebox_grid.dart';
import 'package:talky_flutter/screens/safebox/safebox_share_card.dart';
import 'package:talky_flutter/screens/safebox/safebox_shared_screens.dart';
import 'package:talky_flutter/screens/safebox/safebox_viewer_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Lot 9 sur un faux serveur : la carte (reçue, envoyée, retirée), l'album
/// ouvert depuis la carte, le suivi, et les onglets du dossier Partager.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));
  const go = 1 << 30;

  Map<String, dynamic> element(int id, int position, String name, String family) => {
        'id': id, 'position': position, 'name': name, 'ext': name.split('.').last, 'family': family,
        'plainBytes': 1000, 'storedBytes': 1016, 'available': true, 'quality': 'original',
      };

  final album = {
    'id': 9, 'conversationId': 50, 'senderId': 3, 'kind': 'batch', 'name': 'Kribi 2026', 'family': 'photos',
    'plainBytes': 4000, 'count': 4, 'families': {'photos': 2, 'videos': 1, 'documents': 1},
    'available': true, 'isSender': false, 'availableCount': 4, 'savedCount': 0,
    'sender': {'id': 3, 'name': 'Clarisse'},
    'cover': [element(91, 0, 'Plage.jpg', 'photos'), element(92, 1, 'Danse.mp4', 'videos')],
  };
  final elements = [
    element(91, 0, 'Plage.jpg', 'photos'),
    element(92, 1, 'Danse.mp4', 'videos'),
    element(93, 2, 'Hotel.pdf', 'documents'),
    element(94, 3, 'Coucher.jpg', 'photos'),
  ];
  final envoye = {
    'id': 7, 'conversationId': 50, 'senderId': 1, 'kind': 'file', 'name': 'Photos_chantier.zip', 'family': 'documents',
    'plainBytes': 640 << 20, 'available': true, 'isSender': true, 'quality': 'original', 'fileIds': [21],
    'tracking': {'members': 7, 'downloaded': 2, 'saved': 1}, 'sender': {'id': 1, 'name': 'Moi'},
  };
  final retire = {
    'id': 8, 'conversationId': 50, 'senderId': 3, 'kind': 'file', 'name': 'Anniversaire.mp4', 'family': 'videos',
    'plainBytes': 640 << 20, 'available': false, 'isSender': false, 'revokedBySender': true,
  };
  Map<String, dynamic> fichier(int id, String name, Map<String, dynamic>? sent) => {
        'id': id, 'folderId': 16, 'name': name, 'ext': name.split('.').last, 'family': 'documents',
        'plainBytes': 1000 * id, 'storedBytes': 1000 * id + 16, 'quality': 'original', 'cipherFormat': 'SBX1',
        'createdAt': '2026-10-25T10:00:00Z', 'alsoIn': [], 'sent': ?sent,
      };

  http.Client serveur() => MockClient((req) async {
        final chemin = req.url.path;
        Object? corps;
        if (chemin.endsWith('/safebox')) {
          corps = {
            'quota': {'quotaBytes': 10 * go, 'usedBytes': 0, 'pendingBytes': 0, 'trashBytes': 0, 'byRoot': {}},
            'roots': [
              for (final (i, r) in ['photos', 'videos', 'audios', 'documents', 'albums', 'partager'].indexed)
                {'id': 11 + i, 'root': r},
            ],
            'limits': {'maxFileBytes': go, 'extensions': {}},
          };
        } else if (chemin.endsWith('/shares/9')) {
          corps = album;
        } else if (chemin.endsWith('/shares/9/save')) {
          corps = fichier(95, 'Plage.jpg', null);
        } else if (chemin.endsWith('/shares/9/items')) {
          corps = {'items': elements, 'nextCursor': null};
        } else if (chemin.endsWith('/shares/7')) {
          corps = envoye;
        } else if (chemin.endsWith('/shares/8')) {
          corps = retire;
        } else if (chemin.endsWith('/shares/7/recipients')) {
          corps = {
            'members': [
              {'alanyaID': 4, 'name': 'Lina', 'state': 'saved', 'at': '2026-10-26T09:25:00Z'},
              {'alanyaID': 5, 'name': 'Paul', 'state': 'downloaded', 'at': '2026-10-26T09:30:00Z'},
              {'alanyaID': 6, 'name': 'Rose', 'state': 'pending'},
            ],
            'tracking': {'members': 7, 'downloaded': 2, 'saved': 1},
          };
        } else if (chemin.endsWith('/shares/received')) {
          corps = {'shares': [album, retire], 'nextCursor': null};
        } else if (chemin.endsWith('/safebox/folders/16')) {
          corps = {
            'folder': {'id': 16, 'parentId': null, 'root': 'partager', 'name': null, 'depth': 0},
            'breadcrumbs': [],
            'folders': [],
            'files': [
              fichier(1, 'Rapport.pdf', null),
              fichier(2, 'Plans.zip', {'shares': 1, 'recipients': 3, 'received': 3, 'lastConversationId': 50}),
              fichier(3, 'Devis.pdf', {'shares': 1, 'recipients': 8, 'received': 5, 'lastConversationId': 50}),
            ],
            'nextCursor': null,
          };
        }
        if (corps == null) return http.Response('{"error":"absent","code":"NOT_FOUND"}', 404);
        return http.Response(jsonEncode(corps), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

  Future<SafeboxController> monter(WidgetTester tester, Widget ecran, {bool settle = true}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(api: TalkyApiClient(client: serveur()));
    await c.refreshOverview();
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: ecran,
      ),
    ));
    if (settle) await tester.pumpAndSettle();
    return c;
  }

  Widget carte(SafeboxSharePayload p, {bool moi = false}) => Scaffold(
        body: Center(
          child: SafeboxShareCard(payload: p, isMe: moi, textColor: Colors.black, mutedColor: Colors.grey),
        ),
      );

  testWidgets('carte d\'un album reçu, puis l\'album ouvert', (tester) async {
    await monter(
      tester,
      carte(const SafeboxSharePayload(
        share: 9, name: 'Kribi 2026', size: 4000, family: SafeboxFamily.photos,
        kind: SafeboxShareKind.batch, count: 42,
        families: {SafeboxFamily.photos: 35, SafeboxFamily.videos: 6, SafeboxFamily.documents: 1},
      )),
    );
    expect(find.text('Kribi 2026'), findsOneWidget);
    expect(find.textContaining(fr.safeboxShareItems(42)), findsOneWidget);
    expect(find.text('35 photos, 6 vidéos, 1 document'), findsOneWidget);
    expect(find.text('+38'), findsOneWidget);
    expect(find.text(fr.safeboxShareBadge), findsOneWidget);
    await tester.tap(find.text(fr.safeboxShareSeeAlbum));
    await tester.pumpAndSettle();
    expect(find.byType(SafeboxGridTile), findsNWidgets(4));
    expect(find.text('${fr.safeboxFilterAll} · 4'), findsOneWidget);
    expect(find.text(fr.safeboxSharedAvailableWhile('Clarisse')), findsOneWidget);
    expect(find.text(fr.safeboxShareSave), findsOneWidget);
    expect(find.text(fr.safeboxSharedDownloadAll), findsOneWidget);
    final videos = find.widgetWithText(ChoiceChip, '${fr.safeboxRootVideos} · 1');
    await tester.ensureVisible(videos);
    await tester.pumpAndSettle();
    await tester.tap(videos);
    await tester.pumpAndSettle();
    expect(find.byType(SafeboxGridTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// Fait avancer l'écran : une barre de téléchargement tourne sans fin.
  Future<void> laisserFaire(WidgetTester tester) async {
    for (var i = 0; i < 8; i += 1) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('album reçu : photos et vidéos dans la visionneuse, sans commentaire, avec Télécharger et Garder', (tester) async {
    await monter(tester, const SafeboxSharedAlbumScreen(shareId: 9, title: 'Kribi 2026'));
    await tester.tap(find.byType(SafeboxGridTile).first);
    await laisserFaire(tester);
    final v = tester.widget<SafeboxViewerScreen>(find.byType(SafeboxViewerScreen));
    expect(v.files.map((f) => f.name), ['Plage.jpg', 'Danse.mp4', 'Coucher.jpg'], reason: 'le PDF reste sur sa fiche');
    expect(v.showNotes, isFalse);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text(fr.safeboxNoteAdd), findsNothing);
    expect(find.text(fr.safeboxDownload), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'les actions tiennent dans la largeur de l\'écran');
    await tester.tap(find.text(fr.safeboxShareSave));
    await laisserFaire(tester);
    expect(find.text(fr.safeboxShareSaved), findsOneWidget);
    // Masquer puis rouvrir les barres n'oublie pas ce qui est gardé (au-dessus
    // du centre : ici, le téléchargement échoue et « Réessayer » s'y trouve).
    await tester.tapAt(tester.getCenter(find.byType(PageView)) - const Offset(0, 200));
    await laisserFaire(tester);
    expect(find.text(fr.safeboxShareSaved), findsNothing);
    await tester.tapAt(tester.getCenter(find.byType(PageView)) - const Offset(0, 200));
    await laisserFaire(tester);
    expect(find.text(fr.safeboxShareSaved), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.takeException(); // le téléchargement réel n'a pas de disque ici
  });

  testWidgets('album reçu : un document garde sa fiche, sans « Voir »', (tester) async {
    await monter(tester, const SafeboxSharedAlbumScreen(shareId: 9, title: 'Kribi 2026'));
    await tester.tap(find.byType(SafeboxGridTile).at(2));
    await tester.pumpAndSettle();
    expect(find.byType(SafeboxViewerScreen), findsNothing);
    expect(find.text(fr.safeboxSharedDownloadPlay), findsOneWidget);
    expect(find.text(fr.safeboxSharedView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo reçue seule : « Voir » ouvre la visionneuse, « Télécharger » reste à part', (tester) async {
    await monter(
      tester,
      SafeboxSharedFileScreen(shareId: 9, item: SafeboxShareItem.fromJson(9, element(91, 0, 'Plage.jpg', 'photos'))),
      settle: false,
    );
    await laisserFaire(tester);
    expect(find.text(fr.safeboxDownload), findsOneWidget);
    await tester.tap(find.text(fr.safeboxSharedView));
    await laisserFaire(tester);
    expect(find.byType(SafeboxViewerScreen), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.takeException();
  });

  testWidgets('carte chez l\'expéditeur, puis le suivi', (tester) async {
    await monter(
      tester,
      carte(const SafeboxSharePayload(share: 7, name: 'Photos_chantier.zip', size: 640 << 20, family: SafeboxFamily.documents),
          moi: true),
    );
    expect(find.text(fr.safeboxShareFromVault), findsOneWidget);
    expect(find.text(fr.safeboxShareDownloadedBy(3, 7)), findsOneWidget);
    await tester.tap(find.text(fr.safeboxShareSeeTracking));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxTrackingOutOf(3, 7)), findsOneWidget);
    expect(find.text('Lina'), findsOneWidget);
    expect(find.text(fr.safeboxTrackingSavedState), findsOneWidget);
    expect(find.text(fr.safeboxTrackingPending), findsOneWidget);
    expect(find.text(fr.safeboxTrackingSendElsewhere), findsOneWidget);
    expect(find.text(fr.safeboxTrackingRevoke), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carte d\'un fichier retiré par l\'expéditeur : pas de bouton', (tester) async {
    await monter(
      tester,
      carte(const SafeboxSharePayload(share: 8, name: 'Anniversaire.mp4', size: 640 << 20, family: SafeboxFamily.videos)),
    );
    expect(find.text(fr.safeboxShareRevoked), findsOneWidget);
    expect(find.text(fr.safeboxOpen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Partager : « Mes envois » avec leur état, puis « Reçus »', (tester) async {
    await monter(tester, const SafeboxFolderScreen(folderId: 16, root: SafeboxRoot.partager));
    expect(find.text(fr.safeboxShareTabSent), findsOneWidget);
    expect(find.text(fr.safeboxShareNotSent), findsOneWidget);
    expect(find.widgetWithText(FilledButton, fr.safeboxSend), findsOneWidget);
    expect(find.text(fr.safeboxShareStatusAll(fr.safeboxShareConvFallback)), findsOneWidget);
    expect(find.text(fr.safeboxShareStatusSome(fr.safeboxShareConvFallback, 5, 8)), findsOneWidget);
    expect(find.text(fr.safeboxShareAllReceived(1)), findsOneWidget);
    await tester.tap(find.text(fr.safeboxShareTabReceived));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxShareReceivedInfo), findsOneWidget);
    expect(find.text('Kribi 2026'), findsOneWidget);
    expect(find.text(fr.safeboxSharedUnavailable), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing, reason: 'pas d\'ajout dans « Reçus »');
    expect(tester.takeException(), isNull);
  });
}
