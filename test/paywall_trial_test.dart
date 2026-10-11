import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/billing/entitlement_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/widgets/billing/paywall_sheet.dart';

/// Le panneau d'abonnement du régime essai : combien, où payer, où saisir le
/// code. Il ne propose jamais de payer dans l'application.
void main() {
  Map<String, dynamic> offer({String? payUrl}) => {
        'model': 2,
        'phase': 'paid',
        'purchasable': true,
        if (payUrl != null) 'payUrl': payUrl,
        'plans': [
          {
            'code': 'plus_annuel',
            'name': {'fr': 'Annuel', 'en': 'Yearly', 'zh': '年度'},
            'durationMonths': 12,
            'price': 1000,
            'currency': 'XAF',
            'featured': true,
            'features': <String>[],
          },
        ],
        'features': <dynamic>[],
        'entitlements': {
          'model': 2,
          'phase': 'paid',
          'trial': {'endsAt': '2026-01-01T00:00:00.000Z', 'active': false},
          'exempt': false,
          'features': {'outgoing': false},
        },
      };

  Future<void> pump(
    WidgetTester tester, {
    String? payUrl,
    bool outgoing = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final api = TalkyApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/billing/offer')) {
          return http.Response(jsonEncode(offer(payUrl: payUrl)), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 404);
      }),
    );
    final service = EntitlementService(api: api);
    await service.loadOffer();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: Scaffold(body: SingleChildScrollView(child: PaywallSheet(outgoing: outgoing))),
    ));
    await tester.pump();
  }

  Finder pay() => find.widgetWithText(FilledButton, 'Payer en ligne');

  testWidgets('essai fini : on reçoit toujours, il faut s\'abonner pour envoyer',
      (tester) async {
    await pump(tester, payUrl: 'https://pay.alanya237.com/abonnement');
    expect(find.text('Abonnez-vous pour continuer'), findsOneWidget);
    expect(find.textContaining('Vous recevez toujours vos messages et vos appels'),
        findsOneWidget);
    // Le prix vient de l'offre : jamais écrit en dur dans l'application.
    expect(find.textContaining('1'), findsWidgets);
    expect(find.textContaining('/ an'), findsOneWidget);
  });

  testWidgets('sans site de paiement, le bouton est grisé et le code reste saisissable',
      (tester) async {
    await pump(tester);
    expect(pay(), findsOneWidget);
    expect(tester.widget<FilledButton>(pay()).onPressed, isNull);
    expect(find.textContaining('pas encore disponible'), findsOneWidget);
    expect(find.text('J\'ai un code'), findsOneWidget);
  });

  testWidgets('avec un site de paiement, le bouton s\'ouvre', (tester) async {
    await pump(tester, payUrl: 'https://pay.alanya237.com/abonnement');
    expect(tester.widget<FilledButton>(pay()).onPressed, isNotNull);
    expect(find.textContaining('Vous paierez sur notre site'), findsOneWidget);
    expect(find.text('J\'ai un code'), findsOneWidget);
  });

  testWidgets('une adresse qui n\'est pas en https ne donne pas de bouton actif',
      (tester) async {
    await pump(tester, payUrl: 'http://pay.alanya237.com/');
    expect(tester.widget<FilledButton>(pay()).onPressed, isNull);
  });

  testWidgets('aucun paiement mobile money n\'est proposé dans l\'application',
      (tester) async {
    await pump(tester, payUrl: 'https://pay.alanya237.com/');
    expect(find.textContaining('Orange'), findsNothing);
    expect(find.textContaining('MTN'), findsNothing);
    expect(find.text('Voir l\'offre'), findsNothing);
  });
}
