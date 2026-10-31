import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/services/safebox/safebox_upload_manager.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_transfers_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Les envois gardés d'une session à l'autre, en mémoire.
class _Memoire implements SafeboxJobStore {
  _Memoire(this.jobs);
  List<SafeboxUploadJob> jobs;
  @override
  Future<List<SafeboxUploadJob>> loadJobs() async => jobs;
  @override
  Future<void> saveJobs(List<SafeboxUploadJob> j) async => jobs = j;
  @override
  Future<Uint8List?> loadKey(String jobId) async => null;
  @override
  Future<void> saveKey(String jobId, Uint8List key) async {}
  @override
  Future<void> deleteKey(String jobId) async {}
}

/// Annuler un envoi : possible en cours, en attente ou en pause, après confirmation.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));

  testWidgets('envoi en pause : « Reprendre » et « Annuler », qui demande confirmation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final job = SafeboxUploadJob(
      id: 'p', folderId: 11, name: 'Film.mkv', mime: null, sourcePath: '/x', sourceSize: 1,
      sourceModifiedMs: 0, ownsSource: false, plainSize: 1 << 20, originalSize: null, compressed: false,
    )..state = SafeboxUploadState.paused;
    final api = TalkyApiClient(client: MockClient((_) async => http.Response('{}', 404)));
    final envois = SafeboxUploadManager(transport: ApiSafeboxTransport(api), store: _Memoire([job]));
    await envois.resumeAll();
    final c = SafeboxController(api: api, uploadManager: envois);
    addTearDown(c.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: const SafeboxTransfersView(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip(fr.safeboxResume), findsOneWidget);
    await tester.tap(find.byTooltip(fr.safeboxCancelUpload));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxCancelUploadConfirm('Film.mkv')), findsOneWidget);
    // Un faux geste : on renonce, l'envoi reste.
    await tester.tap(find.text(MaterialLocalizations.of(tester.element(find.byType(AlertDialog))).cancelButtonLabel));
    await tester.pumpAndSettle();
    expect(envois.jobs, hasLength(1));
    await tester.tap(find.byTooltip(fr.safeboxCancelUpload));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(fr.safeboxCancelUpload)));
    await tester.pumpAndSettle();
    expect(envois.jobs, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
