import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/billing/entitlement_service.dart';
import 'package:talky_flutter/core/services/billing/entitlements.dart';
import 'package:talky_flutter/core/services/privacy_prefs_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/profile/privacy_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/talky_models.dart';
import 'package:talky_flutter/widgets/billing/paywall_sheet.dart';
import 'package:talky_flutter/widgets/billing/plus_visuals.dart';

/// Filtre d'appels : ce que le téléphone lit, et ce que l'écran de
/// confidentialité en fait. La règle elle-même est appliquée par le serveur
/// (`callFilter.test.js`, côté backend).
void main() {
  const titre = "Seuls mes contacts peuvent m'appeler";

  group('PrivacyPrefs', () {
    test('un serveur qui n\'en parle pas : filtre éteint', () {
      expect(PrivacyPrefs.fromJson(const {}).callsFromContactsOnly, isFalse);
    });

    test('lit le booléen et le 1 de la base', () {
      expect(
        PrivacyPrefs.fromJson(const {'callsFromContactsOnly': true})
            .callsFromContactsOnly,
        isTrue,
      );
      expect(
        PrivacyPrefs.fromJson(const {'callsFromContactsOnly': 1})
            .callsFromContactsOnly,
        isTrue,
      );
    });

    test('survit au cache local et à copyWith', () {
      final relu = PrivacyPrefs.fromJson(
        const PrivacyPrefs(callsFromContactsOnly: true).toJson(),
      );
      expect(relu.callsFromContactsOnly, isTrue);
      expect(relu.copyWith().callsFromContactsOnly, isTrue);
      expect(
        relu.copyWith(callsFromContactsOnly: false).callsFromContactsOnly,
        isFalse,
      );
    });
  });

  group('offre', () {
    test('le code est celui du catalogue serveur (migration 115)', () {
      expect(PlusFeature.callFilter.code, 'call_filter');
      expect(PlusFeature.fromCode('call_filter'), PlusFeature.callFilter);
    });

    test('présenté dans l\'offre', () {
      expect(kPlusShowcase, contains(PlusFeature.callFilter));
    });
  });

  group('écran de confidentialité', () {
    /// Ouvre l'écran avec le réglage et le droit voulus. Rend les corps des PATCH
    /// reçus ; [refusServeur] les fait refuser, comme un droit expiré.
    Future<List<Map<String, dynamic>>> ouvrir(
      WidgetTester tester, {
      bool reglage = false,
      bool droit = true,
      bool refusServeur = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final patchs = <Map<String, dynamic>>[];
      const entetes = {'content-type': 'application/json; charset=utf-8'};
      final api = TalkyApiClient(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/privacy-prefs')) {
            if (request.method == 'PATCH') {
              final corps = Map<String, dynamic>.from(
                jsonDecode(request.body) as Map,
              );
              patchs.add(corps);
              if (refusServeur) {
                return http.Response(
                  jsonEncode({
                    'code': 'SUBSCRIPTION_REQUIRED',
                    'feature': 'call_filter',
                    'error': 'Fonctionnalité réservée à Alanya Plus',
                  }),
                  403,
                  headers: entetes,
                );
              }
              return http.Response(jsonEncode(corps), 200, headers: entetes);
            }
            return http.Response(
              jsonEncode({'callsFromContactsOnly': reglage}),
              200,
              headers: entetes,
            );
          }
          if (request.url.path.endsWith('/billing/me')) {
            return http.Response(
              jsonEncode({
                'phase': 'paid',
                'features': {'call_filter': false},
              }),
              200,
              headers: entetes,
            );
          }
          return http.Response('[]', 200, headers: entetes);
        }),
      );
      final droits = EntitlementService(api: api);
      await droits.apply({
        'phase': droit ? 'free' : 'paid',
        'features': {'call_filter': droit},
      });
      final privacy = PrivacyPrefsService(api: api);
      await privacy.syncFromServer();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TalkyApiClient>.value(value: api),
            ChangeNotifierProvider<EntitlementService>.value(value: droits),
            ChangeNotifierProvider<PrivacyPrefsService>.value(value: privacy),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fr'),
            home: const PrivacyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return patchs;
    }

    /// `SettingsGroup` peint un fond sous ses tuiles, ce que Flutter signale en
    /// mode debug sur tous les écrans de réglages. Seule cette assertion-là est
    /// ignorée, le temps du test : toute autre erreur le fait échouer.
    void testEcran(String nom, Future<void> Function(WidgetTester) corps) {
      testWidgets(nom, (tester) async {
        final precedent = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exceptionAsString().contains('ListTile background')) {
            return;
          }
          precedent?.call(details);
        };
        try {
          await corps(tester);
        } finally {
          FlutterError.onError = precedent;
        }
      });
    }

    SwitchListTile tuile(WidgetTester tester) => tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, titre),
        );

    Future<void> basculer(WidgetTester tester) async {
      await tester.tap(find.text(titre));
      await tester.pumpAndSettle();
    }

    /// Un panneau resté ouvert en fin de test garderait fermé le suivant : il
    /// n'en existe qu'un à la fois, et ce verrou survit au test.
    Future<void> fermerOffre(WidgetTester tester) async {
      Navigator.of(tester.element(find.byType(PaywallSheet))).pop();
      await tester.pumpAndSettle();
    }

    testEcran('abonné : allumer enregistre le réglage', (tester) async {
      final patchs = await ouvrir(tester);
      expect(tuile(tester).value, isFalse);

      await basculer(tester);

      expect(patchs, [
        {'callsFromContactsOnly': true},
      ]);
      expect(tuile(tester).value, isTrue);
      expect(find.byType(PaywallSheet), findsNothing);
    });

    testEcran('abonné : éteindre enregistre le réglage', (tester) async {
      final patchs = await ouvrir(tester, reglage: true);
      expect(tuile(tester).value, isTrue);

      await basculer(tester);

      expect(patchs, [
        {'callsFromContactsOnly': false},
      ]);
      expect(tuile(tester).value, isFalse);
    });

    testEcran('sans le droit : l\'offre s\'ouvre, rien n\'est envoyé',
        (tester) async {
      final patchs = await ouvrir(tester, droit: false);

      await basculer(tester);

      expect(patchs, isEmpty);
      expect(find.byType(PaywallSheet), findsOneWidget);
      expect(tuile(tester).value, isFalse);
      await fermerOffre(tester);
    });

    testEcran('droit perdu : interrupteur éteint et bandeau d\'explication',
        (tester) async {
      await ouvrir(tester, reglage: true, droit: false);

      expect(
        tuile(tester).value,
        isFalse,
        reason: 'le serveur ne filtre pas : l\'écran ne doit pas dire le contraire',
      );
      expect(find.byType(PlusLockedBanner), findsOneWidget);
    });

    testEcran('jamais abonné : pas de bandeau', (tester) async {
      await ouvrir(tester, droit: false);
      expect(find.byType(PlusLockedBanner), findsNothing);
    });

    testEcran('droits en cache périmés : le refus serveur ouvre l\'offre',
        (tester) async {
      final patchs = await ouvrir(tester, refusServeur: true);

      await basculer(tester);

      expect(patchs, hasLength(1));
      expect(find.byType(PaywallSheet), findsOneWidget);
      expect(tuile(tester).value, isFalse);
      await fermerOffre(tester);
    });
  });
}
