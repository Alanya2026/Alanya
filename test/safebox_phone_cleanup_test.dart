import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_backup.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/services/safebox/safebox_phone_cleanup.dart';
import 'package:talky_flutter/core/services/safebox/safebox_upload_manager.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/safebox/safebox_settings_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Le téléphone : seule la corbeille sert ici. [refus] : l'inscrit refuse la
/// confirmation d'Android.
class _Telephone implements SafeboxDeviceSource {
  final appels = <List<String>>[];
  bool refus = false;

  @override
  Future<Set<String>> trashMedia(List<String> mediaIds) async {
    appels.add(mediaIds);
    return refus ? {} : mediaIds.toSet();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Après un ajout depuis le téléphone : garder, demander, ou retirer les
/// originaux, jamais avant qu'ils soient dans le coffre.
void main() {
  setUpAll(LocaleController.new);
  final fr = lookupAppLocalizations(const Locale('fr'));

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('le réglage : « garder » par défaut, puis gardé d\'une ouverture à l\'autre', () async {
    expect(await SafeboxPhoneCleanup.load(), SafeboxPhoneCleanup.keep);
    await SafeboxPhoneCleanup.always.save();
    expect(await SafeboxPhoneCleanup.load(), SafeboxPhoneCleanup.always);
  });

  test('seules les photos et vidéos de la galerie peuvent quitter le téléphone', () async {
    // Les extensions de chaque type viennent du serveur.
    final serveur = MockClient((_) async => http.Response(
          jsonEncode({
            'quota': {'quotaBytes': 1 << 30, 'usedBytes': 0, 'pendingBytes': 0, 'trashBytes': 0, 'byRoot': {}},
            'roots': [],
            'limits': {
              'maxFileBytes': 1 << 30,
              'extensions': {'photos': ['jpg'], 'videos': ['mp4'], 'audios': ['mp3'], 'documents': ['pdf']},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ));
    final c = SafeboxController(api: TalkyApiClient(client: serveur), deviceSource: _Telephone());
    addTearDown(c.dispose);
    await c.refreshOverview();
    SafeboxPick choix(String nom, {String? media}) => SafeboxPick(path: '/x/$nom', name: nom, size: 1, phoneMediaId: media);
    expect(c.phoneTrashable(choix('Plage.jpg', media: '12')), isTrue);
    expect(c.phoneTrashable(choix('Danse.mp4', media: '13')), isTrue);
    expect(c.phoneTrashable(choix('Contrat.pdf', media: '14')), isFalse);
    expect(c.phoneTrashable(choix('Plage.jpg')), isFalse, reason: 'hors de la galerie : on ne sait pas le retirer');
  });

  test('l\'envoi garde l\'original à retirer, même après un redémarrage', () {
    final j = SafeboxUploadJob(
      id: 'p', folderId: 1, name: 'Plage.jpg', mime: null, sourcePath: '/x', sourceSize: 1,
      sourceModifiedMs: 0, ownsSource: false, plainSize: 1, originalSize: null, compressed: false, phoneMediaId: '12',
    );
    expect(SafeboxUploadJob.fromJson(j.toJson()).phoneMediaId, '12');
  });

  test('la liste d\'attente part en un seul lot ; refusée dans Android, elle est oubliée', () async {
    final tel = _Telephone();
    final c = SafeboxController(api: TalkyApiClient(client: MockClient((_) async => http.Response('{}', 404))), deviceSource: tel);
    addTearDown(c.dispose);
    expect(await c.emptyPhoneTrash(), isNull, reason: 'rien à faire');
    await SafeboxPhoneTrash.add('12');
    await SafeboxPhoneTrash.add('13');
    await SafeboxPhoneTrash.add('12');
    expect(await c.emptyPhoneTrash(), 2);
    expect(tel.appels, [['12', '13']], reason: 'une seule confirmation pour tout le lot');
    expect(await SafeboxPhoneTrash.pending(), isEmpty);

    tel.refus = true;
    await SafeboxPhoneTrash.add('14');
    expect(await c.emptyPhoneTrash(), 0);
    expect(await SafeboxPhoneTrash.pending(), isEmpty, reason: 'on ne redemande pas');
  });

  Future<void> monter(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final c = SafeboxController(api: TalkyApiClient(client: MockClient((_) async => http.Response('{}', 404))), deviceSource: _Telephone());
    addTearDown(c.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<SafeboxController>.value(
      value: c,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('réglages : les trois choix expliqués, le choix gardé', (tester) async {
    await monter(tester, const SafeboxSettingsScreen());
    expect(find.text(fr.safeboxCleanupKeepHint), findsOneWidget);
    expect(find.text(fr.safeboxCleanupAskHint), findsOneWidget);
    expect(find.text(fr.safeboxCleanupAlwaysHint), findsOneWidget);
    expect(find.text(fr.safeboxCleanupNote), findsOneWidget);
    await tester.tap(find.text(fr.safeboxCleanupAlways));
    await tester.pumpAndSettle();
    expect(await SafeboxPhoneCleanup.load(), SafeboxPhoneCleanup.always);
    expect(tester.takeException(), isNull);
  });

  testWidgets('« me demander » : la question dit où elles vont, et prévient en HD ou Compressé', (tester) async {
    bool? reponse;
    await monter(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => reponse = await askSafeboxPhoneCleanup(context, count: 3, lighter: true),
          child: const Text('ajouter'),
        ),
      ),
    );
    await tester.tap(find.text('ajouter'));
    await tester.pumpAndSettle();
    expect(find.textContaining(fr.safeboxCleanupAskBody(3)), findsOneWidget);
    expect(find.textContaining(fr.safeboxCleanupLighter), findsOneWidget);
    await tester.tap(find.text(fr.safeboxCleanupDelete));
    await tester.pumpAndSettle();
    expect(reponse, isTrue);
    await tester.tap(find.text('ajouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(fr.safeboxCleanupKeep));
    await tester.pumpAndSettle();
    expect(reponse, isFalse);
  });
}
