import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/billing/entitlement_service.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/screens/billing/redeem_code_screen.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Un code valide, calculé par le serveur (voir activation_code_test.dart).
const _code = '7K2QX-M9P4B-T3VHN';

Map<String, dynamic> _entitlements({required bool outgoing}) => {
      'model': 2,
      'phase': 'paid',
      'trial': {'endsAt': '2026-01-01T00:00:00.000Z', 'active': false},
      'exempt': false,
      'features': {'outgoing': outgoing},
    };

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late List<Map<String, dynamic>> sent;
  late MockClient server;
  late http.Response Function(Map<String, dynamic> body) reply;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    reply = (_) => _json(200, {
          'startsAt': DateTime.now().toUtc().toIso8601String(),
          'endsAt': DateTime.now().toUtc().add(const Duration(days: 365)).toIso8601String(),
          'alreadyApplied': false,
          'entitlements': _entitlements(outgoing: true),
        });
    server = MockClient((request) async {
      if (request.url.path.endsWith('/billing/redeem')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        sent.add(body);
        return reply(body);
      }
      return _json(404, {'error': 'x', 'code': 'NOT_FOUND'});
    });
  });

  Future<EntitlementService> pump(WidgetTester tester) async {
    final api = TalkyApiClient(client: server);
    final service = EntitlementService(api: api);
    await service.apply(_entitlements(outgoing: false));
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<TalkyApiClient>.value(value: api),
        ChangeNotifierProvider<EntitlementService>.value(value: service),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: const RedeemCodeScreen(),
      ),
    ));
    await tester.pump();
    return service;
  }

  final submit = find.widgetWithText(FilledButton, 'Activer');
  bool enabled(WidgetTester tester) =>
      tester.widget<FilledButton>(submit).onPressed != null;

  testWidgets('le bouton reste fermé tant que le code n\'est pas complet et juste',
      (tester) async {
    await pump(tester);
    expect(enabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), '7k2qxm9p');
    await tester.pump();
    expect(enabled(tester), isFalse);
    // La saisie se met en forme au fil de la frappe.
    expect(find.text('7K2QX-M9P'), findsOneWidget);

    await tester.enterText(find.byType(TextField), _code);
    await tester.pump();
    expect(enabled(tester), isTrue);
    expect(sent, isEmpty, reason: 'rien n\'est envoyé avant de valider');
  });

  testWidgets('une faute de frappe est dite sur place, sans appeler le serveur',
      (tester) async {
    await pump(tester);
    // Dernier symbole changé : le contrôle échoue.
    await tester.enterText(find.byType(TextField), '7K2QX-M9P4B-T3VH5');
    await tester.pump();
    expect(find.text('Ce code ne semble pas correct. Vérifiez chaque caractère.'),
        findsOneWidget);
    expect(enabled(tester), isFalse);
    expect(sent, isEmpty);
  });

  testWidgets('un code accepté rouvre les droits et dit jusqu\'à quand',
      (tester) async {
    final service = await pump(tester);
    expect(service.canSend, isFalse);

    await tester.enterText(find.byType(TextField), _code);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Le code part sous sa forme canonique : sans tirets.
    expect(sent, [
      {'code': '7K2QXM9P4BT3VHN'}
    ]);
    expect(find.text('Abonnement activé'), findsOneWidget);
    expect(service.canSend, isTrue, reason: 'les droits rendus s\'appliquent tout de suite');
    expect(find.text('Terminé'), findsOneWidget);
  });

  testWidgets('un code qui commence plus tard dit quand', (tester) async {
    reply = (_) => _json(200, {
          'startsAt': DateTime.now().toUtc().add(const Duration(days: 40)).toIso8601String(),
          'endsAt': DateTime.now().toUtc().add(const Duration(days: 405)).toIso8601String(),
          'entitlements': _entitlements(outgoing: true),
        });
    await pump(tester);
    await tester.enterText(find.byType(TextField), _code);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Votre essai gratuit continue'), findsOneWidget);
  });

  testWidgets('un code déjà utilisé est refusé, avec la phrase du refus',
      (tester) async {
    reply = (_) => _json(409, {'error': 'x', 'code': 'CODE_ALREADY_USED'});
    final service = await pump(tester);
    await tester.enterText(find.byType(TextField), _code);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Ce code a déjà été utilisé.'), findsOneWidget);
    expect(find.text('Abonnement activé'), findsNothing);
    expect(service.canSend, isFalse);
    // On peut corriger et réessayer : le bouton se rouvre dès qu'on retouche.
    await tester.enterText(find.byType(TextField), 'ABCDE-FGHJK-MNPQ9');
    await tester.pump();
    expect(find.textContaining('Ce code a déjà été utilisé.'), findsNothing);
  });

  testWidgets('le verrou dit dans combien de minutes réessayer', (tester) async {
    reply = (_) => _json(429, {
          'error': 'x',
          'code': 'CODE_LOCKED',
          'retryAfterSeconds': 840,
        });
    await pump(tester);
    await tester.enterText(find.byType(TextField), _code);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Trop d\'essais. Réessayez dans 14 minutes.'), findsOneWidget);
  });

  testWidgets('un code inconnu est refusé', (tester) async {
    reply = (_) => _json(404, {'error': 'x', 'code': 'INVALID_CODE'});
    await pump(tester);
    await tester.enterText(find.byType(TextField), _code);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // En développement, le presenter ajoute son diagnostic entre crochets.
    expect(find.textContaining('Ce code n\'existe pas. Vérifiez-le.'), findsOneWidget);
  });

  testWidgets('une coupure réseau ne montre rien de technique', (tester) async {
    server = MockClient((_) async => throw Exception('Failed host lookup: pay.example'));
    await pump(tester);
    await tester.enterText(find.byType(TextField), _code);
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('Failed host lookup'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.text('Abonnement activé'), findsNothing);
  });
}
