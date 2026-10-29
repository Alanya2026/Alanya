import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:talky_flutter/core/services/documents_sensibles/descripteur_sensible.dart';
import 'package:talky_flutter/core/services/documents_sensibles/detecteur_copie_signee.dart';
import 'package:talky_flutter/core/services/documents_sensibles/signature_document.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/widgets/documents_sensibles/dialogue_protection_pdf.dart';
import 'package:talky_flutter/widgets/documents_sensibles/infos_protection_pdf.dart';

extension on PdfPermissions {
  List<PdfPermissionsFlags> get liste {
    final l = <PdfPermissionsFlags>[];
    forEach(l.add);
    return l;
  }
}

/// Lot 6 : la copie protégée d'un PDF sensible, et ce qui l'entoure.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final signature = SignatureSortie(
    geste: GesteSortie.telechargement,
    alanyaId: '67641599',
    appareil: 'samsung SM-A515F',
    quand: DateTime(2026, 10, 22, 9, 5),
    code: '3f9a0c1e5b7d2a4c6e8f0a1b2c3d4e5f',
  );

  group('copie protégée', () {
    late Directory dossier;
    late File source;
    setUp(() {
      dossier = Directory.systemTemp.createTempSync('protection_');
      final doc = PdfDocument();
      doc.pages.add().graphics.drawString(
          'Contrat', PdfStandardFont(PdfFontFamily.helvetica, 20),
          bounds: const Offset(50, 50) & const Size(200, 40));
      source = File('${dossier.path}/s.pdf')..writeAsBytesSync(doc.saveSync());
      doc.dispose();
    });
    tearDown(() => dossier.deleteSync(recursive: true));

    Future<CopieSignee> signer(ProtectionPdf p, {File? depuis}) =>
        SignatureDocument.signer(
          source: depuis ?? source,
          nom: 'Contrat.pdf',
          mime: 'application/pdf',
          signature: signature,
          cache: dossier,
          protection: p,
        );

    test('avec mot de passe : chiffrée, l\'empreinte au coin, reconnaissable',
        () async {
      final copie = await signer(const ProtectionPdf(
          imprimer: false, ouverture: 'ouvre', proprietaire: 'patron'));
      expect(copie.signee, isTrue);
      final octets = copie.fichier.readAsBytesSync();

      expect(() => PdfDocument(inputBytes: octets).dispose(), throwsA(anything),
          reason: 'sans mot de passe, la copie ne s\'ouvre pas');
      // Le NOM du champ n'est jamais chiffré : la copie reste reconnue.
      expect(DetecteurCopieSignee.contientSignature(octets), isTrue);

      final ouverte = PdfDocument(inputBytes: octets, password: 'ouvre');
      addTearDown(ouverte.dispose);
      final texte = PdfTextExtractor(ouverte).extractText();
      expect(texte, contains('3F9A 0C1E 5B7D'));
      expect(texte, isNot(contains('samsung')), reason: 'plus de bords');
      expect(ouverte.security.permissions.liste,
          isNot(contains(PdfPermissionsFlags.print)));
    });

    test('sans mot de passe, sans impression : bords et restriction', () async {
      final copie = await signer(ProtectionPdf(
          imprimer: false, proprietaire: ProtectionPdf.proprietaireAuHasard()));
      final doc = PdfDocument(inputBytes: copie.fichier.readAsBytesSync());
      addTearDown(doc.dispose);
      expect(PdfTextExtractor(doc).extractText(), contains('samsung SM-A515F'));
      expect(doc.security.permissions.liste,
          isNot(contains(PdfPermissionsFlags.print)));
    });

    test('impression permise : elle reste permise', () async {
      final copie = await signer(const ProtectionPdf(
          imprimer: true, ouverture: 'abcd', proprietaire: 'wxyz'));
      final doc =
          PdfDocument(inputBytes: copie.fichier.readAsBytesSync(), password: 'abcd');
      addTearDown(doc.dispose);
      expect(doc.security.permissions.liste, contains(PdfPermissionsFlags.print));
    });

    test('si la protection échoue, rien ne sort', () async {
      final abime = File('${dossier.path}/abime.pdf')
        ..writeAsStringSync('%PDF-1.7');
      await expectLater(
        signer(const ProtectionPdf(imprimer: false, proprietaire: 'x'),
            depuis: abime),
        throwsA(isA<ProtectionImpossible>()),
      );
      expect(
        dossier
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('/Contrat.pdf')),
        isEmpty,
      );
    });
  });

  Widget appli(Widget enfant) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('fr'),
        home: Scaffold(body: enfant),
      );

  testWidgets('le dialogue refuse un mot de passe trop court, puis rend la protection',
      (tester) async {
    ChoixProtectionPdf? choix;
    await tester.pumpWidget(appli(Builder(
      builder: (context) => TextButton(
        onPressed: () async => choix = await demanderProtectionPdf(context),
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pdfp_imprimer')));
    await tester.tap(find.byKey(const Key('pdfp_mot_de_passe')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pdfp_ouverture')), 'abc');
    await tester.enterText(find.byKey(const Key('pdfp_proprietaire')), 'patron');
    await tester.tap(find.byKey(const Key('pdfp_valider')));
    await tester.pumpAndSettle();
    expect(find.text('4 caractères au moins.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('pdfp_ouverture')), 'ouvre');
    await tester.tap(find.byKey(const Key('pdfp_valider')));
    await tester.pumpAndSettle();
    expect(choix?.protection?.imprimer, isFalse);
    expect(choix?.protection?.ouverture, 'ouvre');
    expect(choix?.protection?.proprietaire, 'patron');
  });

  testWidgets('sans mot de passe ni impression : un propriétaire tiré au hasard',
      (tester) async {
    ChoixProtectionPdf? choix;
    await tester.pumpWidget(appli(Builder(
      builder: (context) => TextButton(
        onPressed: () async => choix = await demanderProtectionPdf(context),
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pdfp_imprimer')));
    await tester.tap(find.byKey(const Key('pdfp_valider')));
    await tester.pumpAndSettle();
    expect(choix?.protection?.avecMotDePasse, isFalse);
    expect(choix?.protection?.proprietaire.length, 24);
  });

  const p = ProtectionPdf(imprimer: false, ouverture: 'ouvre', proprietaire: 'patron');

  testWidgets('l\'expéditeur voit les deux mots de passe', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(appli(const InfosProtectionPdf(
        protection: p, idMessage: 'm1', isMe: true, couleurDiscrete: Colors.grey)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdfp_mdp_expediteur')), findsOneWidget);
    expect(find.textContaining('patron', findRichText: true), findsOneWidget);
    expect(find.text('Impression interdite'), findsOneWidget);
  });

  testWidgets('le destinataire voit l\'ouverture une seule fois, jamais le propriétaire',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(appli(const InfosProtectionPdf(
        protection: p, idMessage: 'm2', isMe: false, couleurDiscrete: Colors.grey)));
    await tester.pumpAndSettle();
    expect(find.textContaining('patron', findRichText: true), findsNothing);
    await tester.tap(find.byKey(const Key('pdfp_voir')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdfp_mdp_revele')), findsOneWidget);
    await tester.tap(find.text("J'ai noté"));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdfp_voir')), findsNothing);

    // Rouvert plus tard : déjà vu.
    await tester.pumpWidget(appli(const SizedBox()));
    await tester.pumpWidget(appli(const InfosProtectionPdf(
        protection: p, idMessage: 'm2', isMe: false, couleurDiscrete: Colors.grey)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pdfp_voir')), findsNothing);
    expect(find.text('Mot de passe déjà affiché'), findsOneWidget);
  });
}
