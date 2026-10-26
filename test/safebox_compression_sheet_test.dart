import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/byte_format.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_compression_sheet.dart';

/// La feuille « Qualité d'envoi » (décision du 24/10/2026) : trois formats, un
/// format qui dépasserait la limite est grisé avec le fichier en cause, un
/// format qui ne gagnerait rien aussi.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));
  const mo = 1 << 20;
  const go = 1 << 30;

  Future<void> ouvrir(WidgetTester tester, SafeboxQualityEstimate est) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showSafeboxQualitySheet(
              context,
              estimate: est,
              maxFileBytes: go,
              freeBytes: 10 * go,
              destination: 'Partager',
              fileCount: 5,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Radio<SafeboxQuality> radio(WidgetTester tester, SafeboxQuality q) => tester
      .widgetList<Radio<SafeboxQuality>>(find.byType(Radio<SafeboxQuality>))
      .firstWhere((r) => r.value == q);

  final mariage = SafeboxQualityEstimate(
    totals: {
      SafeboxQuality.original: 2365 * mo,
      SafeboxQuality.hd: 180 * mo,
      SafeboxQuality.compressed: 90 * mo,
    },
    tooLarge: {SafeboxQuality.original: (name: 'Mariage_complet.mp4', bytes: 1638 * mo)},
    counts: {SafeboxFamily.videos: 3, SafeboxFamily.photos: 2},
    compressible: true,
    hevc: true,
  );

  testWidgets('Original au-delà de 1 Go : grisé avec le fichier en cause, HD présélectionné', (tester) async {
    await ouvrir(tester, mariage);
    expect(radio(tester, SafeboxQuality.original).enabled, isFalse);
    expect(find.textContaining('Mariage_complet.mp4'), findsOneWidget);
    expect(radio(tester, SafeboxQuality.hd).enabled, isNot(false));
    expect(find.text(fr.safeboxQualityAddCount(5, formatBytes(180 * mo, fr))), findsOneWidget);
    expect(find.text('−92 %'), findsOneWidget);
    expect(find.text('−96 %'), findsOneWidget);
  });

  testWidgets('description selon le lot : vidéo et photo, sans musique', (tester) async {
    await ouvrir(tester, mariage);
    expect(find.text('${fr.safeboxQualityVideoPart('720p')} · ${fr.safeboxQualityPhotoPart('2560')}'), findsOneWidget);
    expect(find.text('${fr.safeboxQualityVideoPart('480p')} · ${fr.safeboxQualityPhotoPart('1600')}'), findsOneWidget);
    expect(find.text('${fr.safeboxCountVideos(3)} · ${fr.safeboxCountPhotos(2)} · ${fr.safeboxQualityTo('Partager')}'),
        findsOneWidget);
  });

  testWidgets('déjà léger : HD et Compressé grisés, Original choisi', (tester) async {
    await ouvrir(
      tester,
      SafeboxQualityEstimate(
        totals: {for (final q in SafeboxQuality.values) q: 25 * mo},
        tooLarge: const {},
        counts: {SafeboxFamily.videos: 1},
        compressible: true,
        hevc: false,
      ),
    );
    expect(radio(tester, SafeboxQuality.hd).enabled, isFalse);
    expect(radio(tester, SafeboxQuality.compressed).enabled, isFalse);
    expect(find.text(fr.safeboxCompressNothingToGain), findsNWidgets(2));
    expect(find.text(fr.safeboxQualityAddCount(5, formatBytes(25 * mo, fr))), findsOneWidget);
  });
}
