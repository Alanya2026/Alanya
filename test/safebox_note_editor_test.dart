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
import 'package:talky_flutter/screens/safebox/safebox_note_widgets.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Le commentaire d'une photo : la feuille dit quelle photo, et le champ
/// reste visible au-dessus du clavier.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));

  testWidgets('clavier ouvert : la photo et le champ restent visibles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(api: TalkyApiClient(client: MockClient((_) async => http.Response('{}', 404))));
    addTearDown(c.dispose);
    const photo = SafeboxFile(
      id: 7, folderId: 11, name: 'Plage de Kribi.jpg', ext: 'jpg', mime: 'image/jpeg', family: SafeboxFamily.photos,
      plainBytes: 1000, storedBytes: 1016, originalBytes: null, compressed: false, cipherFormat: 'SBX1', key: null, previewUrl: null,
    );
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => showSafeboxNoteEditor(context, photo), child: const Text('ouvrir')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Plage de Kribi.jpg'), findsOneWidget, reason: 'on sait où va le commentaire');

    // Le clavier occupe le bas de l'écran (≈ 300 dp).
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2.75);
    addTearDown(tester.view.resetViewInsets);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Avec Lina, juste avant la pluie');
    await tester.pumpAndSettle();
    final hauteur = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final champ = tester.getRect(find.byType(TextField));
    expect(champ.bottom, lessThanOrEqualTo(hauteur - 300), reason: 'au-dessus du clavier');
    expect(find.text('Avec Lina, juste avant la pluie'), findsOneWidget);
    expect(find.text(fr.safeboxNoteAdd), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
