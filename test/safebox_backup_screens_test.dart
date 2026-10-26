import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_backup.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_backup_screens.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Lot 10 : l'activation de la sauvegarde automatique, avec un faux téléphone.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));
  const go = 1 << 30;

  final serveur = MockClient((req) async {
    if (req.url.path.endsWith('/safebox')) {
      return http.Response(
        jsonEncode({
          'quota': {'quotaBytes': 10 * go, 'usedBytes': go, 'pendingBytes': 0, 'trashBytes': 0, 'byRoot': {}},
          'roots': [
            for (final (i, r) in ['photos', 'videos', 'audios', 'documents', 'albums', 'partager'].indexed)
              {'id': 11 + i, 'root': r},
          ],
          'limits': {'maxFileBytes': go, 'extensions': {}},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('{"error":"absent","code":"NOT_FOUND"}', 404);
  });

  Future<SafeboxController> monter(WidgetTester tester, _Telephone tel) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(api: TalkyApiClient(client: serveur), deviceSource: tel);
    await c.refreshOverview();
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: const SafeboxBackupSetupScreen(),
      ),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    return c;
  }

  testWidgets('activation : dossiers cochés d\'office, estimation, Original présélectionné', (tester) async {
    final c = await monter(tester, _Telephone(SafeboxMediaAccess.full));
    expect(find.text(fr.safeboxBackupStep1), findsOneWidget);
    expect(find.text(fr.safeboxBackupGranted), findsOneWidget);
    expect(find.text(fr.safeboxBackupPhotosDesc(2, '4 Mo')), findsOneWidget);
    final camera = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, fr.safeboxFolderCamera));
    final captures = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, fr.safeboxFolderScreenshots));
    expect([camera.value, captures.value], [true, false]);
    await tester.tap(find.text(fr.safeboxBackupContinue));
    await tester.pumpAndSettle();
    expect(find.text(fr.safeboxBackupStep2), findsOneWidget);
    expect(find.textContaining(fr.safeboxBackupFits('').split(' ').first), findsOneWidget);
    expect(find.text(fr.safeboxBackupWifiOnly), findsOneWidget);
    await tester.tap(find.text(fr.safeboxBackupEnable));
    await tester.pumpAndSettle();
    final r = c.backupSettings;
    expect(r.enabled, isTrue);
    expect(r.galleryFolders, {'camera'});
    expect(r.qualityOf(SafeboxFamily.photos), SafeboxQuality.original, reason: 'tout tient : Original');
    expect(r.wifiOnly && r.chargingOnly, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('sans autorisation : l\'écran la demande d\'abord', (tester) async {
    final tel = _Telephone(SafeboxMediaAccess.denied);
    final c = await monter(tester, tel);
    expect(find.text(fr.safeboxBackupPermissionTitle), findsOneWidget);
    tel.acces = SafeboxMediaAccess.full;
    await tester.tap(find.text(fr.safeboxBackupAllow));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text(fr.safeboxBackupStep1), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}

class _Telephone implements SafeboxDeviceSource {
  _Telephone(this.acces);
  SafeboxMediaAccess acces;

  @override
  Future<SafeboxMediaAccess> access() async => acces;
  @override
  Future<SafeboxMediaAccess> requestAccess() async => acces;
  @override
  Future<List<SafeboxDeviceFolder>> galleryFolders() async => const [
        SafeboxDeviceFolder(id: 'camera', name: 'Camera', count: 2),
        SafeboxDeviceFolder(id: 'screenshots', name: 'Screenshots', count: 1),
      ];

  @override
  Future<List<SafeboxDeviceItem>> galleryItems({
    required Set<String> folderIds,
    required Set<SafeboxFamily> families,
    DateTime? since,
    bool withSizes = false,
  }) async =>
      [
        if (folderIds.contains('camera') && families.contains(SafeboxFamily.photos))
          for (final i in [1, 2])
            SafeboxDeviceItem(
              key: 'g:$i', name: 'p$i.jpg', family: SafeboxFamily.photos, size: 2 << 20,
              modified: DateTime(2026), folder: 'Camera', width: 4000, height: 3000,
            ),
      ];

  @override
  Future<SafeboxDocumentFolder?> pickDocumentFolder() async => null;
  @override
  Future<List<SafeboxDeviceItem>> documentItems(SafeboxDocumentFolder folder, {DateTime? since}) async => const [];
  @override
  Future<File?> open(SafeboxDeviceItem item) async => null;
  @override
  Future<Set<String>> delete(List<SafeboxDeviceItem> items) async => {};
  @override
  Future<({int free, int total})?> storage() async => null;
}
