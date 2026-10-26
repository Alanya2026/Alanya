import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_grid.dart';

/// La grille d'un dossier (lot 8) : photos et vidéos par jour.
void main() {
  setUpAll(LocaleController.new);

  SafeboxFile fichier(int id, DateTime quand) => SafeboxFile(
        id: id,
        folderId: 1,
        name: 'p$id.jpg',
        ext: 'jpg',
        mime: null,
        family: SafeboxFamily.photos,
        plainBytes: 1,
        storedBytes: 17,
        originalBytes: null,
        compressed: false,
        cipherFormat: 'SBX1',
        key: null,
        previewUrl: null,
        createdAt: quand,
      );

  test('par jour, dans l\'ordre reçu (du plus récent au plus ancien)', () {
    final g = safeboxGroupByDay([
      fichier(5, DateTime(2026, 10, 26, 18)),
      fichier(4, DateTime(2026, 10, 26, 9)),
      fichier(3, DateTime(2026, 10, 25, 23, 59)),
      fichier(2, DateTime(2026, 10, 12, 8)),
      fichier(1, DateTime(2025, 3, 3)),
    ]);
    expect(g.map((x) => x.day), [DateTime(2026, 10, 26), DateTime(2026, 10, 25), DateTime(2026, 10, 12), DateTime(2025, 3, 3)]);
    expect(g.first.files.map((f) => f.id), [5, 4]);
    expect(safeboxGroupByDay(const []), isEmpty);
  });

  testWidgets('« Aujourd\'hui », « Hier », la date sans l\'année cette année', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    final maintenant = DateTime(2026, 10, 26, 10);
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(safeboxDayLabel(ctx, DateTime(2026, 10, 26), now: maintenant), fr.safeboxToday);
    expect(safeboxDayLabel(ctx, DateTime(2026, 10, 25), now: maintenant), fr.safeboxYesterday);
    expect(safeboxDayLabel(ctx, DateTime(2026, 10, 12), now: maintenant), '12 octobre');
    expect(safeboxDayLabel(ctx, DateTime(2025, 3, 3), now: maintenant), '3 mars 2025');
  });
}
