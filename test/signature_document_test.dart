import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:talky_flutter/core/services/documents_sensibles/detecteur_copie_signee.dart';
import 'package:talky_flutter/core/services/documents_sensibles/signature_document.dart';

/// La copie signée d'un document sensible (lot 3) : ce qui est écrit aux
/// bords et dans les métadonnées, et la règle « le geste n'est jamais refusé ».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SignatureSortie signature({String? expediteur}) => SignatureSortie(
        geste: GesteSortie.telechargement,
        alanyaId: '67641599',
        appareil: 'samsung SM-A515F',
        quand: DateTime(2026, 10, 22, 9, 5, 7),
        code: '3f9a0c1e5b7d2a4c6e8f0a1b2c3d4e5f',
        expediteurId: expediteur,
        mediaId: '42',
      );

  test('les bords : application, ID formaté, appareil, date, empreinte', () {
    expect(signature().bordsVisuels, [
      'Alanya · 67 64 15 99',
      '22/10/2026 09:05',
      'samsung SM-A515F',
      '3F9A 0C1E 5B7D 2A4C 6E8F 0A1B 2C3D 4E5F',
    ]);
    final pdf = signature().texteBordsPdf;
    expect(pdf, contains('3F9A 0C1E'));
    expect(pdf, isNot(contains('67 64')), reason: 'PDF : l\'empreinte, pas l\'ID');
  });

  test('les métadonnées, sous leurs noms courts', () {
    final m = signature(expediteur: '67641599').metadonnees;
    expect(m.keys, [
      'Application',
      'Alanya ID',
      'Appareil',
      'Date Creation',
      'Empreinte numerique',
      'Geste',
      'Expediteur',
      'Document',
    ]);
    expect(m['Alanya ID'], '67 64 15 99');
    expect(m['Date Creation'], startsWith('2026-10-22T09:05:07'));
    expect(m['Empreinte numerique'], '3f9a0c1e5b7d2a4c6e8f0a1b2c3d4e5f');
    expect(m['Geste'], 'TELECHARGEMENT');
    expect(signature().metadonnees.containsKey('Expediteur'), isFalse);
  });

  test('ASCII strict : « · » devient « | », les accents tombent', () {
    expect(asciiStrict('Alanya · Téléphone Ü 中'), 'Alanya | Telephone U ?');
    expect(signature().ligneMetadonnees, contains('Empreinte numerique=3f9a'));
  });

  test('une empreinte neuve : 32 caractères hexadécimaux, jamais la même', () {
    final codes = {for (var i = 0; i < 200; i++) SignatureSortie.nouveauCode()};
    expect(codes, hasLength(200));
    for (final c in codes) {
      expect(c, matches(RegExp(r'^[0-9a-f]{32}$')));
    }
    expect(SignatureSortie.nouveauCode(Random(1)),
        SignatureSortie.nouveauCode(Random(1)));
  });

  test('ce que chaque type reçoit', () {
    expect(natureSignature('application/octet-stream', 'Contrat.PDF'),
        NatureSignature.pdf);
    expect(natureSignature('image/jpeg', 'a.jpg'), NatureSignature.image);
    expect(natureSignature('image/heic', 'a.heic'), NatureSignature.aucune);
    expect(natureSignature('image/gif', 'a.gif'), NatureSignature.aucune);
    expect(natureSignature('video/mp4', 'a.mp4'), NatureSignature.video);
    expect(natureSignature('audio/mp4', 'voix.m4a'), NatureSignature.audio);
    expect(natureSignature('', 'son.wav'), NatureSignature.audio);
    expect(natureSignature('video/webm', 'a.webm'), NatureSignature.aucune);
    expect(natureSignature('', 'a.docx'), NatureSignature.aucune);
  });

  group('signer', () {
    late Directory dossier;
    setUp(() => dossier = Directory.systemTemp.createTempSync('signature_'));
    tearDown(() => dossier.deleteSync(recursive: true));

    Future<CopieSignee> signer(File source, String nom, String mime) =>
        SignatureDocument.signer(
          source: source,
          nom: nom,
          mime: mime,
          signature: signature(),
          cache: dossier,
        );

    test('un PDF : texte aux bords de chaque page, propriétés, détectable',
        () async {
      final doc = PdfDocument();
      for (var i = 0; i < 2; i++) {
        doc.pages.add().graphics.drawString(
            'Page $i', PdfStandardFont(PdfFontFamily.helvetica, 20),
            bounds: const Offset(50, 50) & const Size(200, 40));
      }
      final source = File('${dossier.path}/s.pdf')
        ..writeAsBytesSync(doc.saveSync());
      doc.dispose();

      final copie = await signer(source, 'Contrat.pdf', 'application/pdf');
      expect(copie.signee, isTrue);
      expect(copie.nom, 'Contrat.pdf');
      final octets = copie.fichier.readAsBytesSync();
      expect(DetecteurCopieSignee.contientSignature(octets), isTrue);

      final relu = PdfDocument(inputBytes: octets);
      addTearDown(relu.dispose);
      expect(relu.pages.count, 2);
      expect(relu.documentInformation.keywords,
          contains('Empreinte numerique=3f9a0c1e5b7d2a4c6e8f0a1b2c3d4e5f'));
      expect(relu.documentInformation.author, 'Alanya 67 64 15 99');
      final texte = PdfTextExtractor(relu).extractText(startPageIndex: 1);
      expect(texte, contains('3F9A 0C1E 5B7D'),
          reason: 'la dernière page porte aussi la signature');
    });

    test('un PDF illisible sort tel quel, sans exception', () async {
      final source = File('${dossier.path}/s.pdf')..writeAsStringSync('%PDF-1.7');
      final copie = await signer(source, 'Contrat.pdf', 'application/pdf');
      expect(copie.signee, isFalse);
      expect(copie.fichier.readAsStringSync(), '%PDF-1.7');
    });

    test('une photo : bords peints, EXIF, détectable ; un WebP devient JPEG',
        () async {
      final photo = img.Image(width: 400, height: 300)
        ..clear(img.ColorRgb8(30, 90, 160));
      final source = File('${dossier.path}/p.jpg')
        ..writeAsBytesSync(img.encodeJpg(photo));

      final copie = await signer(source, 'photo.jpg', 'image/jpeg');
      expect(copie.signee, isTrue);
      final octets = copie.fichier.readAsBytesSync();
      expect(DetecteurCopieSignee.contientSignature(octets), isTrue);
      final relue = img.decodeJpg(octets)!;
      expect([relue.width, relue.height], [400, 300]);
      expect(relue.exif.imageIfd['Artist']?.toString(), 'Alanya 67 64 15 99');
      // Le bord haut n'est plus uni : la signature y est peinte.
      final couleurs = {
        for (var x = 0; x < 400; x++) relue.getPixel(x, 8).r.toInt() ~/ 40,
      };
      expect(couleurs.length, greaterThan(1));

      final bmp = File('${dossier.path}/p.bmp')
        ..writeAsBytesSync(img.encodeBmp(photo));
      final convertie = await signer(bmp, 'scan.bmp', 'image/bmp');
      expect(convertie.nom, 'scan.jpg');
      expect(convertie.signee, isTrue);
    });

    test('un PNG reste un PNG, l\'empreinte en texte', () async {
      final source = File('${dossier.path}/p.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 200, height: 200)));
      final copie = await signer(source, 'capture.png', 'image/png');
      expect(copie.nom, 'capture.png');
      final relue = img.decodePng(copie.fichier.readAsBytesSync())!;
      expect(relue.textData?['Empreinte numerique'],
          '3f9a0c1e5b7d2a4c6e8f0a1b2c3d4e5f');
    });

    test('un format sans signature sort tel quel, sous son nom', () async {
      final source = File('${dossier.path}/source.docx')
        ..writeAsStringSync('contenu');
      final copie = await signer(source, 'Rapport.docx', 'application/msword');
      expect(copie.signee, isFalse);
      expect(copie.nom, 'Rapport.docx');
      expect(copie.fichier.readAsStringSync(), 'contenu');
    });

    test('une vidéo illisible sort telle quelle, sans exception', () async {
      final source = File('${dossier.path}/v.mp4')
        ..writeAsStringSync('pas une vidéo');
      final copie = await signer(source, 'v.mp4', 'video/mp4');
      expect(copie.signee, isFalse);
      expect(copie.fichier.readAsStringSync(), 'pas une vidéo');
    });

    test('un WAV reçoit l\'empreinte, et se reconnaît', () async {
      // En-tête RIFF/WAVE minimal : fmt + data vides.
      final wav = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add([36, 0, 0, 0])
        ..add('WAVE'.codeUnits)
        ..add('fmt '.codeUnits)
        ..add([16, 0, 0, 0, 1, 0, 1, 0, 0x40, 0x1f, 0, 0, 0x80, 0x3e, 0, 0, 2, 0, 16, 0])
        ..add('data'.codeUnits)
        ..add([0, 0, 0, 0]);
      final source = File('${dossier.path}/s.wav')..writeAsBytesSync(wav.toBytes());
      final copie = await signer(source, 'note.wav', 'audio/wav');
      expect(copie.signee, isTrue);
      expect(
          DetecteurCopieSignee.contientSignature(copie.fichier.readAsBytesSync()),
          isTrue);
    });
  });
}
