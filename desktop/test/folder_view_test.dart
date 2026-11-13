import 'dart:convert';
import 'dart:io';

import 'package:alanya_coffre/browse/actions.dart';
import 'package:alanya_coffre/browse/folder_view.dart';
import 'package:alanya_coffre/core/desktop_api.dart';
import 'package:alanya_coffre/core/session.dart';
import 'package:alanya_coffre/core/session_store.dart';
import 'package:alanya_coffre/core/settings.dart';
import 'package:alanya_coffre/core/vault.dart';
import 'package:alanya_coffre/l10n/app_localizations.dart';
import 'package:alanya_coffre/ui/common.dart';
import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Envois implements SafeboxJobStore {
  @override
  Future<List<SafeboxUploadJob>> loadJobs() async => const [];
  @override
  Future<void> saveJobs(List<SafeboxUploadJob> jobs) async {}
  @override
  Future<Uint8List?> loadKey(String jobId) async => null;
  @override
  Future<void> saveKey(String jobId, Uint8List key) async {}
  @override
  Future<void> deleteKey(String jobId) async {}
}

Map<String, dynamic> _fichier(int id, String nom, {List<Map<String, dynamic>> alsoIn = const []}) => {
      'id': id,
      'folderId': 10,
      'name': nom,
      'ext': 'pdf',
      'family': 'documents',
      'plainBytes': 1000,
      'storedBytes': 1016,
      'cipherFormat': 'SBX1',
      'createdAt': '2026-11-01T10:00:00Z',
      'alsoIn': alsoIn,
    };

final _page = {
  'folder': {'id': 10, 'parentId': 4, 'root': 'documents', 'name': 'Factures', 'depth': 1},
  'breadcrumbs': [],
  'folders': [
    {'id': 20, 'parentId': 10, 'root': 'documents', 'name': '2025', 'depth': 2, 'files': 3},
  ],
  'files': [
    _fichier(31, 'a.pdf'),
    _fichier(32, 'b.pdf', alsoIn: [
      {'fileId': 90, 'folderId': 70, 'root': 'albums', 'folderName': 'Maison'},
    ]),
    _fichier(33, 'c.pdf'),
  ],
  'nextCursor': null,
};

void main() {
  late List<String> appels;
  late Vault vault;
  late Directory tmp;
  late List<int> ouverts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('coffre_dossier');
    appels = [];
    ouverts = [];
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> monter(WidgetTester tester, {Map<String, dynamic>? page, SafeboxRoot root = SafeboxRoot.documents}) async {
    final api = DesktopApi(
      store: SessionStore(),
      client: MockClient((req) async {
        appels.add('${req.method} ${req.url.path}${req.url.query.isEmpty ? '' : '?${req.url.query}'}');
        if (req.method == 'GET' && req.url.path == '/api/safebox/folders/10') {
          return http.Response(jsonEncode(page ?? _page), 200);
        }
        if (req.method == 'DELETE') return http.Response('{}', 200);
        return http.Response(jsonEncode({'error': 'absent'}), 404);
      }),
    )..setTokens(access: 'a', refresh: 'r');
    final store = SessionStore();
    vault = Vault(api, baseDir: () async => tmp, jobStore: _Envois());
    final scope = AppScope(
      session: Session(api: api, store: store),
      locale: LocaleSetting(),
      vault: vault,
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: FolderView(root: root, folderId: 10, onOpenFolder: ouverts.add),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
  }

  Future<void> demonter(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    vault.dispose();
    await tester.pump(const Duration(seconds: 5));
  }

  /// Laisse passer les vraies entrées-sorties (cache sur le disque), que
  /// l'horloge simulée des tests n'attend pas.
  Future<void> attendre(WidgetTester tester) async {
    for (var i = 0; i < 10; i += 1) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> avecTouche(WidgetTester tester, LogicalKeyboardKey touche, Future<void> Function() action) async {
    await tester.sendKeyDownEvent(touche);
    await action();
    await tester.sendKeyUpEvent(touche);
  }

  testWidgets('clic, Ctrl + clic et Maj + clic sélectionnent comme un explorateur', (tester) async {
    await monter(tester);
    expect(find.text('a.pdf'), findsOneWidget);

    await tester.tap(find.text('a.pdf'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1 élément sélectionné'), findsOneWidget);

    await avecTouche(tester, LogicalKeyboardKey.controlLeft, () => tester.tap(find.text('c.pdf')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2 éléments sélectionnés'), findsOneWidget);

    // Maj + clic depuis c.pdf jusqu'au dossier 2025 : tout l'intervalle.
    await avecTouche(tester, LogicalKeyboardKey.shiftLeft, () => tester.tap(find.text('2025')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('4 éléments sélectionnés'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.textContaining('sélectionné'), findsNothing);

    await avecTouche(tester, LogicalKeyboardKey.controlLeft, () => tester.sendKeyEvent(LogicalKeyboardKey.keyA));
    await tester.pump();
    expect(find.text('4 éléments sélectionnés'), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('double-clic sur un dossier l’ouvre', (tester) async {
    await monter(tester);
    await tester.tap(find.text('2025'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('2025'));
    await tester.pump();
    expect(ouverts, [20]);
    await demonter(tester);
  });

  testWidgets('Suppr met la sélection à la corbeille ; un fichier rangé ailleurs demande « ici ou partout »', (tester) async {
    await monter(tester);
    await tester.tap(find.text('a.pdf'));
    await tester.pump(const Duration(seconds: 1));
    await avecTouche(tester, LogicalKeyboardKey.controlLeft, () => tester.tap(find.text('b.pdf')));
    await tester.pump(const Duration(seconds: 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Retirer de « Factures » seulement'), findsOneWidget);
    expect(find.text('Il reste dans « Maison ». Aucun espace libéré.'), findsOneWidget);

    await tester.tap(find.text('Supprimer partout'));
    await attendre(tester);
    expect(appels.where((a) => a.startsWith('DELETE')), [
      'DELETE /api/safebox/files/31?everywhere=1',
      'DELETE /api/safebox/files/32?everywhere=1',
    ]);
    expect(find.text('2 éléments mis à la corbeille'), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('Photos : « Avec commentaire » et le dossier d’origine filtrent comme sur le téléphone', (tester) async {
    Map<String, dynamic> photo(int id, String nom, String source, {String? note}) => {
          ..._fichier(id, nom),
          'ext': 'jpg',
          'family': 'photos',
          'meta': {'source': source},
          'note': ?(note == null ? null : {'text': note}),
        };
    await monter(tester, root: SafeboxRoot.photos, page: {
      'folder': {'id': 10, 'parentId': null, 'root': 'photos', 'name': null, 'depth': 0},
      'breadcrumbs': [],
      'folders': [],
      'files': [
        photo(41, 'plage.jpg', 'Camera', note: 'Kribi, août'),
        photo(42, 'gateau.jpg', 'Camera'),
        photo(43, 'meme.jpg', 'WhatsApp Images'),
      ],
      'nextCursor': null,
    });
    expect(find.text('Avec commentaire'), findsOneWidget);
    expect(find.text('Appareil photo · 2'), findsOneWidget);
    expect(find.text('WhatsApp Images · 1'), findsOneWidget);
    expect(find.byTooltip('meme.jpg'), findsOneWidget);

    await tester.tap(find.text('Avec commentaire'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('plage.jpg'), findsOneWidget);
    expect(find.byTooltip('gateau.jpg'), findsNothing);
    expect(find.byTooltip('meme.jpg'), findsNothing);

    await tester.tap(find.text('Avec commentaire'));
    await tester.tap(find.text('WhatsApp Images · 1'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('meme.jpg'), findsOneWidget);
    expect(find.byTooltip('plage.jpg'), findsNothing);
    await demonter(tester);
  });

  test('un fichier va dans la racine de son type, Albums ou Partager ; un dossier reste dans sa racine', () {
    SafeboxFile f(String famille) => SafeboxFile.fromJson({..._fichier(1, 'x'), 'family': famille});
    expect(destinationRoots(current: SafeboxRoot.albums, files: [f('photos'), f('photos')], withFolders: false),
        [SafeboxRoot.photos, SafeboxRoot.albums, SafeboxRoot.partager]);
    expect(destinationRoots(current: SafeboxRoot.albums, files: [f('photos'), f('videos')], withFolders: false),
        [SafeboxRoot.albums, SafeboxRoot.partager]);
    expect(destinationRoots(current: SafeboxRoot.albums, files: [f('photos')], withFolders: true), [SafeboxRoot.albums]);
  });
}
