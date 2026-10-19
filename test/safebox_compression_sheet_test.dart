import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_compression_sheet.dart';

/// La feuille de compression du coffre : un fichier déjà léger (vidéo reçue
/// par WhatsApp, image réduite) ne se voit pas proposer une compression vaine.
void main() {
  setUpAll(LocaleController.new);

  Future<void> ouvrir(WidgetTester tester, {required int original, required int compresse}) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showSafeboxCompressionSheet(context, originalBytes: original, compressedBytes: compresse),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  RadioListTile<bool> choix(WidgetTester tester, bool compresser) => tester
      .widgetList<RadioListTile<bool>>(find.byType(RadioListTile<bool>))
      .firstWhere((r) => r.value == compresser);

  testWidgets('déjà léger : « Compressé » grisé, et la feuille le dit', (tester) async {
    await ouvrir(tester, original: 25 << 20, compresse: 25 << 20);
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(find.text(fr.safeboxCompressNothingToGain), findsOneWidget);
    expect(choix(tester, true).enabled, isFalse);
  });

  testWidgets('gain réel : les deux choix ouverts, le gain affiché', (tester) async {
    await ouvrir(tester, original: 100 << 20, compresse: 30 << 20);
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(find.text(fr.safeboxCompressNothingToGain), findsNothing);
    expect(choix(tester, true).enabled, isNot(false));
  });
}
