import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:talky_flutter/core/errors/afficher_erreur.dart';
import 'package:talky_flutter/core/errors/app_error.dart';
import 'package:talky_flutter/core/errors/error_presenter.dart';
import 'package:talky_flutter/core/services/billing/entitlements.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';
import 'package:talky_flutter/widgets/billing/paywall_sheet.dart';

/// Un refus « réservé à Alanya Plus » n'est pas une panne : l'entonnoir
/// d'erreurs en fait le panneau de l'offre, sur la fonctionnalité demandée.
void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  TalkyException refus(String? feature) => TalkyException(
        'Fonctionnalité réservée à Alanya Plus',
        403,
        code: 'SUBSCRIPTION_REQUIRED',
        details: {
          'code': 'SUBSCRIPTION_REQUIRED',
          if (feature != null) 'feature': feature,
        },
      );

  group('refusAlanyaPlus', () {
    test('le refus d\'émettre (envoyer, appeler) se distingue d\'une fonctionnalité', () {
      final r = refusAlanyaPlus(refus('outgoing'))!;
      expect(r.outgoing, isTrue);
      // « outgoing » n'est pas au catalogue : aucune fonctionnalité visée.
      expect(r.feature, isNull);
      expect(refusAlanyaPlus(refus('backup'))!.outgoing, isFalse);
      expect(refusAlanyaPlus(refus(null))!.outgoing, isFalse);
    });

    test('reconnaît le refus et la fonctionnalité visée', () {
      expect(refusAlanyaPlus(refus('backup'))?.feature, PlusFeature.backup);
      expect(refusAlanyaPlus(refus('trusted_trips'))?.feature,
          PlusFeature.trustedTrips);
    });

    test('à travers AppError aussi', () {
      expect(refusAlanyaPlus(AppError.from(refus('translation')))?.feature,
          PlusFeature.translation);
    });

    test('fonctionnalité absente ou inconnue : refus générique', () {
      final r = refusAlanyaPlus(refus(null));
      expect(r, isNotNull);
      expect(r!.feature, isNull);
      expect(refusAlanyaPlus(refus('pas_encore_livree'))!.feature, isNull);
    });

    test('toute autre erreur suit le chemin habituel', () {
      expect(refusAlanyaPlus(TalkyException('x', 403, code: 'INSUFFICIENT_ROLE')),
          isNull);
      expect(refusAlanyaPlus(TalkyException('x', 0)), isNull);
      expect(refusAlanyaPlus(StateError('x')), isNull);
    });
  });

  group('afficherErreur', () {
    late BuildContext ctx;

    Widget host() => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: Scaffold(
            body: Builder(builder: (c) {
              ctx = c;
              return const SizedBox.expand();
            }),
          ),
        );

    testWidgets('SUBSCRIPTION_REQUIRED ouvre le panneau, pas une SnackBar',
        (tester) async {
      await tester.pumpWidget(host());
      afficherErreur(ctx, refus('backup'), domaine: ErrorDomain.generique);
      await tester.pumpAndSettle();

      expect(find.byType(PaywallSheet), findsOneWidget);
      expect(find.text(l10n.paywallBackupTitle), findsOneWidget);
      expect(find.text(l10n.paywallSeeOffer), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('une autre erreur reste une SnackBar', (tester) async {
      await tester.pumpWidget(host());
      afficherErreur(
        ctx,
        TalkyException('x', 400, code: 'INVALID_MSISDN'),
        domaine: ErrorDomain.abonnement,
      );
      await tester.pump();

      expect(find.byType(PaywallSheet), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Codes de l\'abonnement', () {
    String dire(String code) => presenterErreur(
          l10n,
          TalkyException('prose du serveur', 400, code: code),
          domaine: ErrorDomain.abonnement,
          journaliser: false,
          avecDiagnostic: false,
        );

    test('chaque code a sa phrase', () {
      expect(dire('INVALID_MSISDN'), l10n.errCodeInvalidMsisdn);
      expect(dire('PAYMENT_PENDING'), l10n.errCodePaymentPending);
      expect(dire('BILLING_NOT_ACTIVE'), l10n.errCodeBillingNotActive);
      expect(dire('PLAN_NOT_FOUND'), l10n.errCodePlanNotFound);
      expect(dire('PAYMENT_PROVIDER_ERROR'), l10n.errCodePaymentProviderError);
      expect(dire('SUBSCRIPTION_REQUIRED'), l10n.errCodeSubscriptionRequired);
    });

    test('codes d\'activation : chaque code a sa phrase, dans chaque langue', () {
      const codes = {
        'INVALID_CODE': 'errCodeInvalidCode',
        'INVALID_CODE_FORMAT': 'errCodeInvalidCodeFormat',
        'CODE_ALREADY_USED': 'errCodeCodeAlreadyUsed',
        'CODE_EXPIRED': 'errCodeCodeExpired',
        'CODE_REVOKED': 'errCodeCodeRevoked',
        'CODE_LOCKED': 'errCodeCodeLocked',
      };
      expect(dire('INVALID_CODE'), l10n.errCodeInvalidCode);
      expect(dire('INVALID_CODE_FORMAT'), l10n.errCodeInvalidCodeFormat);
      expect(dire('CODE_ALREADY_USED'), l10n.errCodeCodeAlreadyUsed);
      expect(dire('CODE_EXPIRED'), l10n.errCodeCodeExpired);
      expect(dire('CODE_REVOKED'), l10n.errCodeCodeRevoked);
      expect(dire('CODE_LOCKED'), l10n.errCodeCodeLocked);
      // Aucune de ces phrases n'est la phrase générique du domaine : chaque
      // code parle pour lui, et chaque langue a la sienne.
      final repli = presenterErreur(
        l10n,
        TalkyException('x', 500),
        domaine: ErrorDomain.abonnement,
        journaliser: false,
        avecDiagnostic: false,
      );
      for (final code in codes.keys) {
        expect(dire(code), isNot(repli), reason: code);
      }
      for (final locale in const ['en', 'zh']) {
        final other = lookupAppLocalizations(Locale(locale));
        String autre(String code) => presenterErreur(
              other,
              TalkyException('x', 400, code: code),
              domaine: ErrorDomain.abonnement,
              journaliser: false,
              avecDiagnostic: false,
            );
        expect(autre('CODE_ALREADY_USED'), other.errCodeCodeAlreadyUsed);
        expect(autre('CODE_ALREADY_USED'), isNot(l10n.errCodeCodeAlreadyUsed),
            reason: 'traduit en $locale');
        expect(autre('INVALID_CODE'), other.errCodeInvalidCode);
      }
    });

    test('vérification d\'identité : chaque code a sa phrase', () {
      expect(dire('VERIFICATION_UNAVAILABLE'), l10n.errCodeVerificationUnavailable);
      expect(dire('DOCUMENTS_REQUIRED'), l10n.errCodeDocumentsRequired);
      expect(dire('NAME_REQUIRED'), l10n.errCodeNameRequired);
      expect(dire('VERIFICATION_ALREADY_OPEN'), l10n.errCodeVerificationAlreadyOpen);
      expect(dire('VERIFICATION_ALREADY_APPROVED'),
          l10n.errCodeVerificationAlreadyApproved);
      expect(dire('REQUEST_NOT_PENDING'), l10n.errCodeRequestNotPending);
    });

    test('un refus d\'envoi garde son code (uploadHttpException)', () {
      final api = TalkyApiClient();
      final e = api.uploadHttpException(http.Response(
        '{"error":"Une demande est déjà en cours","code":"VERIFICATION_ALREADY_OPEN","requestId":9}',
        409,
      ));
      expect(e.code, 'VERIFICATION_ALREADY_OPEN');
      expect(e.details?['requestId'], 9);
      expect(dire('VERIFICATION_ALREADY_OPEN'), l10n.errCodeVerificationAlreadyOpen);
    });

    test('repli du domaine', () {
      expect(
        presenterErreur(l10n, TalkyException('x', 400),
            domaine: ErrorDomain.abonnement,
            journaliser: false,
            avecDiagnostic: false),
        isNotEmpty,
      );
    });
  });
}
