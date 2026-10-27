import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
// Le dictionnaire Info d'un PDF n'a pas d'accès public pour des champs
// libres : on passe par l'aide interne de la bibliothèque (voir
// [_ecrireMetaPdf]), comme Alanya Work.
// ignore: implementation_imports
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/pdf_document/pdf_document_information.dart'
    show PdfDocumentInformationHelper;
// ignore: implementation_imports
import 'package:syncfusion_flutter_pdf/src/pdf/implementation/primitives/pdf_dictionary.dart'
    show PdfDictionary;

import '../../utils/alanya_phone_formatter.dart';
import 'audio_metadonnees.dart';
import 'descripteur_sensible.dart' show ProtectionPdf;
import 'mp4_metadonnees.dart';

/// Ce qu'on fait sortir d'Alanya : le geste noté par le serveur.
enum GesteSortie {
  telechargement('TELECHARGEMENT'),
  partage('PARTAGE'),
  transfert('TRANSFERT');

  const GesteSortie(this.code);

  /// La valeur attendue par `POST /api/documents-sensibles/consultations`.
  final String code;
}

/// LA SIGNATURE D'UNE COPIE QUI SORT (reprise d'Alanya Work ; plan :
/// PLAN-DOCUMENTS-SENSIBLES.md).
///
/// La copie d'un document sensible qui sort de l'application porte de quoi
/// remonter à qui l'a fait sortir :
///
/// * aux QUATRE BORDS (PDF, images) ;
/// * dans les MÉTADONNÉES (PDF, images, vidéos, audio) : [metadonnees] —
///   application, Alanya ID, appareil, date, geste, expéditeur et EMPREINTE.
///
/// L'empreinte est tirée ici, au hasard, et envoyée au serveur avec le geste :
/// un fichier retrouvé ailleurs renvoie, par elle, à la ligne
/// `document_consultation` de celui qui l'a fait sortir — même si l'on a
/// effacé le nom écrit dans le fichier.
///
/// Le texte des bords ne contient AUCUN MOT d'une langue : seulement des noms,
/// des chiffres et l'empreinte. Il reste lisible quelle que soit la langue de
/// l'application (les polices d'un PDF ne couvrent pas toutes les écritures).
class SignatureSortie {
  SignatureSortie({
    required this.geste,
    required String alanyaId,
    required this.appareil,
    required this.quand,
    required this.code,
    String? expediteurId,
    this.mediaId,
  })  : alanyaId = AlanyaPhoneFormatter.formatDisplay(alanyaId),
        expediteurId = (expediteurId == null || expediteurId.trim().isEmpty)
            ? null
            : AlanyaPhoneFormatter.formatDisplay(expediteurId);

  /// Une signature neuve, avec une empreinte tirée au hasard.
  factory SignatureSortie.nouvelle({
    required GesteSortie geste,
    required String alanyaId,
    required String appareil,
    String? expediteurId,
    String? mediaId,
  }) =>
      SignatureSortie(
        geste: geste,
        alanyaId: alanyaId,
        appareil: appareil,
        quand: DateTime.now(),
        code: nouveauCode(),
        expediteurId: expediteurId,
        mediaId: mediaId,
      );

  static const application = 'Alanya';

  final GesteSortie geste;

  /// L'Alanya ID de qui fait sortir la copie, formaté (« 67 64 15 99 »).
  final String alanyaId;

  /// Marque et modèle (« samsung SM-A515F »).
  final String appareil;
  final DateTime quand;

  /// L'empreinte : 32 caractères hexadécimaux minuscules.
  final String code;

  /// L'Alanya ID de qui a envoyé le document — renseigné seulement quand
  /// c'est l'expéditeur lui-même qui enregistre sa copie (Alanya Work,
  /// 26/10/2026 : le destinataire n'apprend pas le numéro de l'expéditeur).
  final String? expediteurId;
  final String? mediaId;

  /// 128 bits tirés par le générateur sûr du système.
  static String nouveauCode([Random? hasard]) {
    final r = hasard ?? Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// « 3F9A 0C1E 5B7D … » : l'empreinte telle qu'on la recopie d'une photo.
  String get codeLisible {
    final m = code.toUpperCase();
    return [
      for (var i = 0; i < m.length; i += 4)
        m.substring(i, min(i + 4, m.length)),
    ].join(' ');
  }

  static String _deux(int n) => n.toString().padLeft(2, '0');

  String get dateLisible =>
      '${_deux(quand.day)}/${_deux(quand.month)}/${quand.year} '
      '${_deux(quand.hour)}:${_deux(quand.minute)}';

  /// ISO 8601 avec le décalage horaire local (« 2026-10-22T21:40:00+01:00 »).
  String get dateIso {
    final d = quand.timeZoneOffset;
    final signe = d.isNegative ? '-' : '+';
    final a = d.abs();
    return '${quand.year.toString().padLeft(4, '0')}-${_deux(quand.month)}-'
        '${_deux(quand.day)}T${_deux(quand.hour)}:${_deux(quand.minute)}:'
        '${_deux(quand.second)}$signe${_deux(a.inHours)}:${_deux(a.inMinutes % 60)}';
  }

  /// PHOTOS : UN CHAMP PAR BORD — haut, bas, gauche, droite : l'application
  /// et l'Alanya ID, la date, l'appareil, l'empreinte.
  List<String> get bordsVisuels => [
        '$application · $alanyaId',
        dateLisible,
        appareil,
        codeLisible,
      ];

  /// PDF : l'EMPREINTE à la place de l'Alanya ID, qui reste dans les
  /// métadonnées.
  String get texteBordsPdf => [
        application,
        codeLisible,
        appareil,
        dateLisible,
      ].join(' · ');

  /// La chaîne complète (titre d'une vidéo).
  String get texteBords => [
        application,
        'Alanya $alanyaId',
        appareil,
        dateLisible,
        codeLisible,
      ].join(' · ');

  /// Les métadonnées, sous des noms courts et lisibles : propriétés d'un PDF,
  /// EXIF d'une image, éléments libres d'une vidéo.
  Map<String, String> get metadonnees => {
        CleMeta.application: application,
        CleMeta.alanyaId: alanyaId,
        CleMeta.appareil: appareil,
        CleMeta.dateCreation: dateIso,
        CleMeta.empreinte: code,
        CleMeta.geste: geste.code,
        if (expediteurId != null) CleMeta.expediteur: expediteurId!,
        if (mediaId != null) CleMeta.document: mediaId!,
      };

  /// Les métadonnées en une ligne ASCII « Clé=valeur; … » : là où un format
  /// n'a qu'un champ texte (EXIF, propriétés d'un PDF). C'est aussi ce que
  /// cherche `DetecteurCopieSignee` (« Empreinte numerique »).
  String get ligneMetadonnees => asciiStrict(
      [for (final e in metadonnees.entries) '${e.key}=${e.value}'].join('; '));

  /// Les mêmes informations pour une vidéo (`moov/udta/meta/ilst`) : en
  /// éléments libres, et en toutes lettres dans le commentaire (`©cmt`), que
  /// l'Explorateur de Windows affiche.
  ElementsMp4 get elementsMp4 => ElementsMp4(
        standard: {
          '©nam': texteBords,
          'desc': texteBords,
          '©too': application,
          '©ART': 'Alanya $alanyaId',
          '©cmt': ligneMetadonnees,
          '©day': dateIso,
          'cprt': application,
        },
        libres: metadonnees,
      );
}

/// Les noms des champs de métadonnées (les mêmes qu'Alanya Work).
class CleMeta {
  CleMeta._();

  static const application = 'Application';
  static const alanyaId = 'Alanya ID';
  static const appareil = 'Appareil';
  static const dateCreation = 'Date Creation';

  /// L'empreinte, notée aussi par le serveur avec le geste.
  static const empreinte = 'Empreinte numerique';
  static const geste = 'Geste';
  static const expediteur = 'Expediteur';
  static const document = 'Document';
}

/// Les champs texte de l'EXIF et des propriétés d'un PDF sont de l'ASCII :
/// le séparateur « · » devient « | », les accents tombent, le reste devient
/// « ? » — même règle qu'Alanya Work.
String asciiStrict(String s) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
    'ç': 'c',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ÿ': 'y', 'ñ': 'n',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (c == '·') {
      b.write('|');
    } else if (r >= 0x20 && r < 0x7f) {
      b.write(c);
    } else {
      final bas = c.toLowerCase();
      final sans = accents[bas];
      if (sans == null) {
        b.write('?');
      } else {
        b.write(c == bas ? sans : sans.toUpperCase());
      }
    }
  }
  return b.toString();
}

/// Ce que la signature sait faire d'un fichier.
enum NatureSignature {
  /// Texte aux quatre bords de chaque page, et propriétés.
  pdf,

  /// Texte aux quatre bords, et EXIF (JPEG) ou texte PNG.
  image,

  /// Métadonnées MP4 (MP4, MOV, 3GP).
  video,

  /// L'empreinte seule dans les métadonnées (MP3, WAV, M4A).
  audio,

  /// Rien : la copie sort telle quelle (le serveur note quand même le geste).
  aucune,
}

String _extension(String nom) {
  final point = nom.lastIndexOf('.');
  return point < 0 ? '' : nom.substring(point + 1).toLowerCase();
}

/// Ce que le paquet `image` sait relire : HEIC n'en est pas, il sort tel quel.
const _imagesSignables = {'jpg', 'jpeg', 'png', 'webp', 'bmp'};
const _audios = {
  'mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'flac', 'amr', '3ga', 'weba',
};

NatureSignature natureSignature(String mime, String nom) {
  final m = mime.toLowerCase();
  final ext = _extension(nom);
  if (m == 'application/pdf' || ext == 'pdf') return NatureSignature.pdf;
  // Un GIF animé perdrait son animation, un SVG n'est pas une image en
  // points : ils sortent tels quels.
  if (_imagesSignables.contains(ext)) return NatureSignature.image;
  // L'audio AVANT la vidéo : un M4A est un MP4.
  if (m.startsWith('audio/') || _audios.contains(ext)) {
    return NatureSignature.audio;
  }
  if (Mp4Metadonnees.prisEnCharge(m, nom)) return NatureSignature.video;
  return NatureSignature.aucune;
}

/// La copie prête à sortir.
class CopieSignee {
  const CopieSignee({
    required this.fichier,
    required this.nom,
    required this.signee,
  });

  final File fichier;

  /// Le nom à donner (une image BMP ou WebP devient un JPEG).
  final String nom;

  /// Faux : le format n'est pas pris en charge, ou la signature a échoué —
  /// la copie sort telle quelle.
  final bool signee;
}

/// Fabrique la copie signée d'un document sensible.
class SignatureDocument {
  SignatureDocument._();

  /// Signe une copie de [source] dans le cache.
  ///
  /// Ne lève jamais : un échec rend la copie telle quelle, avec
  /// `signee: false` — le geste a été demandé, il n'est pas refusé.
  ///
  /// 🔴 SAUF POUR UN PDF PROTÉGÉ ([protection]) : là, un échec LÈVE
  /// [ProtectionImpossible]. Rendre la copie telle quelle ferait sortir sans
  /// mot de passe ni restriction un document que l'expéditeur a voulu
  /// protéger — l'enregistrement échoue plutôt.
  static Future<CopieSignee> signer({
    required File source,
    required String nom,
    required String mime,
    required SignatureSortie signature,
    Directory? cache,
    ProtectionPdf? protection,
  }) async {
    final base = cache ?? await getTemporaryDirectory();
    // Un dossier par empreinte : la copie garde son nom d'origine.
    final dossier = Directory('${base.path}/sorties/${signature.code}');
    await dossier.create(recursive: true);
    final cible = File('${dossier.path}/$nom');
    final nature = natureSignature(mime, nom);
    if (protection != null && nature == NatureSignature.pdf) {
      try {
        final octets = await compute(
          signerPdf,
          _travailPdf(await source.readAsBytes(), signature, protection),
        );
        await cible.writeAsBytes(octets, flush: true);
        return CopieSignee(fichier: cible, nom: nom, signee: true);
      } catch (e) {
        debugPrint('[Alanya] PDF non protégé ($nom) : $e');
        if (await cible.exists()) await cible.delete();
        throw ProtectionImpossible(e);
      }
    }
    try {
      switch (nature) {
        case NatureSignature.pdf:
          final octets = await compute(
            signerPdf,
            _travailPdf(await source.readAsBytes(), signature, null),
          );
          await cible.writeAsBytes(octets, flush: true);
          return CopieSignee(fichier: cible, nom: nom, signee: true);
        case NatureSignature.image:
          final r = await compute(
            signerImage,
            TravailImage(
              octets: await source.readAsBytes(),
              png: _extension(nom) == 'png',
              bords: signature.bordsVisuels.map(asciiStrict).toList(),
              meta: signature.metadonnees
                  .map((k, v) => MapEntry(k, asciiStrict(v))),
              ligne: signature.ligneMetadonnees,
              artiste: asciiStrict('Alanya ${signature.alanyaId}'),
              code: signature.code,
            ),
          );
          if (r == null) break;
          final nomFinal = _extension(nom) == 'png' || _estJpeg(nom)
              ? nom
              : '${_racine(nom)}.jpg';
          final fichier = File('${dossier.path}/$nomFinal');
          await fichier.writeAsBytes(r, flush: true);
          return CopieSignee(fichier: fichier, nom: nomFinal, signee: true);
        case NatureSignature.video:
          await Mp4Metadonnees.ecrire(source, cible, signature.elementsMp4);
          return CopieSignee(fichier: cible, nom: nom, signee: true);
        case NatureSignature.audio:
          final ok = await _empreinteAudio(source, cible, signature.code);
          if (!ok) break;
          return CopieSignee(fichier: cible, nom: nom, signee: true);
        case NatureSignature.aucune:
          break;
      }
    } catch (e) {
      debugPrint('[Alanya] Signature impossible ($nom) : $e');
    }
    if (await cible.exists()) await cible.delete();
    final copie = await source.copy(cible.path);
    return CopieSignee(fichier: copie, nom: nom, signee: false);
  }

  static TravailPdf _travailPdf(
    Uint8List octets,
    SignatureSortie signature,
    ProtectionPdf? protection,
  ) =>
      TravailPdf(
        octets: octets,
        bords: signature.texteBordsPdf,
        coin: signature.codeLisible,
        auteur: asciiStrict('Alanya ${signature.alanyaId}'),
        sujet: asciiStrict(signature.texteBordsPdf),
        motsCles: signature.ligneMetadonnees,
        meta: signature.metadonnees.map((k, v) => MapEntry(k, asciiStrict(v))),
        protection: protection,
      );

  static bool _estJpeg(String nom) =>
      const {'jpg', 'jpeg'}.contains(_extension(nom));

  static String _racine(String nom) {
    final point = nom.lastIndexOf('.');
    return point > 0 ? nom.substring(0, point) : nom;
  }

  /// L'empreinte SEULE dans un fichier audio. Rend faux si le format n'est
  /// pas pris en charge.
  static Future<bool> _empreinteAudio(File source, File cible, String code) async {
    final debut = await source
        .openRead(0, 16)
        .fold<List<int>>([], (a, b) => a..addAll(b));
    switch (formatAudio(Uint8List.fromList(debut))) {
      case FormatAudio.mp4:
        await Mp4Metadonnees.ecrire(
          source,
          cible,
          ElementsMp4(standard: const {}, libres: {CleMeta.empreinte: code}),
        );
        return true;
      case FormatAudio.mp3:
        await cible.writeAsBytes(
            avecEmpreinteMp3(await source.readAsBytes(), code),
            flush: true);
        return true;
      case FormatAudio.wav:
        await cible.writeAsBytes(
            avecEmpreinteWav(await source.readAsBytes(), code),
            flush: true);
        return true;
      case null:
        return false;
    }
  }
}

// ── PDF (Syncfusion, dans un isolat) ────────────────────────────────────────

/// Ce que l'isolat reçoit pour signer un PDF : tout est déjà calculé, il n'a
/// besoin d'aucun service de l'application.
class TravailPdf {
  const TravailPdf({
    required this.octets,
    required this.bords,
    required this.coin,
    required this.auteur,
    required this.sujet,
    required this.motsCles,
    required this.meta,
    this.protection,
  });

  final Uint8List octets;
  final String bords;

  /// L'empreinte lisible, écrite seule en haut à droite d'un PDF protégé par
  /// mot de passe.
  final String coin;
  final String auteur;
  final String sujet;
  final String motsCles;

  /// Les champs libres du dictionnaire Info (`CleMeta`), en ASCII.
  final Map<String, String> meta;
  final ProtectionPdf? protection;
}

/// Gris de la signature aux bords ; rouge de l'empreinte seule au coin.
final _gris = PdfColor(110, 110, 110);
final _rouge = PdfColor(0xE5, 0x39, 0x35);

/// La copie signée d'un PDF, en une passe.
///
/// * Sans protection, ou protégé SANS mot de passe (impression interdite) :
///   texte aux quatre bords de chaque page.
/// * Protégé AVEC mot de passe : plus de texte aux bords, seulement
///   l'empreinte en haut à droite (Alanya Work, 24–25/10/2026).
/// * Toujours : les propriétés et les champs libres du dictionnaire Info.
/// * Protégé : chiffré en AES-256, impression permise ou non.
///
/// 🔴 LES CHAMPS RESTENT RECONNAISSABLES. `DetecteurCopieSignee` cherche le
/// NOM de champ « Empreinte#20numerique » : un nom de PDF n'est jamais
/// chiffré (seules les chaînes le sont), et la table de références classique
/// garde le dictionnaire Info hors des flux compressés.
///
/// Un PDF chiffré ou illisible lève : l'appelant décide.
Uint8List signerPdf(TravailPdf t) {
  final doc = PdfDocument(inputBytes: t.octets);
  try {
    final protection = t.protection;
    final auCoin = protection != null && protection.avecMotDePasse;
    for (var i = 0; i < doc.pages.count; i++) {
      if (auCoin) {
        _ecrireCoin(doc.pages[i], t.coin);
      } else {
        _ecrireBords(doc.pages[i], t.bords);
      }
    }
    final info = doc.documentInformation;
    info.author = t.auteur;
    info.creator = SignatureSortie.application;
    info.producer = SignatureSortie.application;
    info.subject = t.sujet;
    info.keywords = t.motsCles;
    _ecrireMetaPdf(doc, t.meta);

    doc.fileStructure
      ..incrementalUpdate = false
      ..crossReferenceType = PdfCrossReferenceType.crossReferenceTable;

    if (protection != null) {
      final s = doc.security
        ..algorithm = PdfEncryptionAlgorithm.aesx256BitRevision6
        ..ownerPassword = protection.proprietaire
        ..userPassword = protection.ouverture ?? '';
      s.permissions.clear();
      s.permissions.addAll([
        // Les lecteurs d'écran gardent l'accès au texte.
        PdfPermissionsFlags.accessibilityCopyContent,
        if (protection.imprimer) ...[
          PdfPermissionsFlags.print,
          PdfPermissionsFlags.fullQualityPrint,
        ],
      ]);
    }
    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

void _ecrireBords(PdfPage page, String texte) {
  final brosse = PdfSolidBrush(_gris);
  final format = PdfStringFormat(
    alignment: PdfTextAlignment.center,
    lineAlignment: PdfVerticalAlignment.middle,
  );
  final taille = page.getClientSize();
  final l = taille.width;
  final h = taille.height;
  // Assez petit pour tenir sur la largeur, pas plus grand que 8 pt.
  final corps = min(8.0, max(4.0, min(l, h) / 75));
  final police = PdfStandardFont(PdfFontFamily.helvetica, corps);
  final bande = corps * 1.6;
  final g = page.graphics;

  g.drawString(texte, police,
      brush: brosse,
      bounds: Rect.fromLTWH(bande, 0, l - 2 * bande, bande),
      format: format);
  g.drawString(texte, police,
      brush: brosse,
      bounds: Rect.fromLTWH(bande, h - bande, l - 2 * bande, bande),
      format: format);
  // Les côtés laissent libres, à leurs deux bouts, la bande du texte
  // perpendiculaire : les coins ne se chevauchent pas.
  g.save();
  g.translateTransform(0, h - bande);
  g.rotateTransform(-90);
  g.drawString(texte, police,
      brush: brosse,
      bounds: Rect.fromLTWH(0, 0, h - 2 * bande, bande),
      format: format);
  g.restore();
  g.save();
  g.translateTransform(l, bande);
  g.rotateTransform(90);
  g.drawString(texte, police,
      brush: brosse,
      bounds: Rect.fromLTWH(0, 0, h - 2 * bande, bande),
      format: format);
  g.restore();
}

/// L'empreinte en haut à droite de la page, par-dessus le contenu.
void _ecrireCoin(PdfPage page, String texte) {
  final taille = page.getClientSize();
  final court = min(taille.width, taille.height);
  final corps = (court / 50).clamp(7.0, 12.0);
  final police =
      PdfStandardFont(PdfFontFamily.helvetica, corps, style: PdfFontStyle.bold);
  final mesure = police.measureString(texte);
  final marge = corps * 1.2;
  page.graphics.drawString(
    texte,
    police,
    brush: PdfSolidBrush(_rouge),
    bounds: Rect.fromLTWH(
      taille.width - marge - mesure.width,
      marge,
      mesure.width + 1,
      mesure.height,
    ),
  );
}

/// Les champs libres du dictionnaire Info, sous les noms de `CleMeta`.
void _ecrireMetaPdf(PdfDocument doc, Map<String, String> meta) {
  if (meta.isEmpty) return;
  final info =
      PdfDocumentInformationHelper.getHelper(doc.documentInformation).element;
  if (info is! PdfDictionary) return;
  meta.forEach(info.setString);
}

/// La copie protégée d'un PDF n'a pas pu être faite : rien ne sort.
class ProtectionImpossible implements Exception {
  const ProtectionImpossible(this.cause);
  final Object cause;

  @override
  String toString() => 'ProtectionImpossible($cause)';
}

// ── Images (paquet `image`, dans un isolat) ─────────────────────────────────

class TravailImage {
  const TravailImage({
    required this.octets,
    required this.png,
    required this.bords,
    required this.meta,
    required this.ligne,
    required this.artiste,
    required this.code,
  });

  final Uint8List octets;

  /// Un PNG reste un PNG (transparence) ; tout le reste devient un JPEG.
  final bool png;

  /// Haut, bas, gauche, droite — déjà en ASCII (polices bitmap).
  final List<String> bords;
  final Map<String, String> meta;
  final String ligne;
  final String artiste;
  final String code;
}

/// L'image signée, ou `null` si elle est illisible (HEIC, fichier abîmé).
Uint8List? signerImage(TravailImage t) {
  final lue = img.decodeImage(t.octets);
  if (lue == null) return null;
  // L'orientation EXIF appliquée aux pixels : sinon la signature serait
  // dessinée de travers sur une photo prise en portrait.
  final image = img.bakeOrientation(lue);
  final w = image.width;
  final h = image.height;

  final police = _policePour(min(w, h));
  final bande = police.lineHeight + 4;

  _ligneImage(image, t.bords[0], police, 0, 0, w);
  _ligneImage(image, t.bords[1], police, 0, h - bande, w);
  for (final (texte, angle, x) in [
    (t.bords[2], -90, 0),
    (t.bords[3], 90, w - bande),
  ]) {
    final longueur = max<int>(1, h - 2 * bande);
    final bandeau = img.Image(width: longueur, height: bande, numChannels: 4);
    _ligneImage(bandeau, texte, police, 0, 0, longueur);
    img.compositeImage(image, img.copyRotate(bandeau, angle: angle),
        dstX: x, dstY: bande);
  }

  if (t.png) {
    image.textData = {...t.meta};
    return img.encodePng(image);
  }
  final exif = img.ExifData();
  exif.imageIfd['ImageDescription'] = t.ligne;
  exif.imageIfd['Artist'] = t.artiste;
  exif.imageIfd['Software'] = SignatureSortie.application;
  exif.imageIfd['ImageUniqueID'] = img.IfdValueAscii(t.code);
  image.exif = exif;
  return img.encodeJpg(image, quality: 92);
}

img.BitmapFont _policePour(int cote) {
  if (cote >= 1600) return img.arial48;
  if (cote >= 700) return img.arial24;
  return img.arial14;
}

int _largeur(String texte, img.BitmapFont police) {
  var l = 0;
  for (final r in texte.runes) {
    l += police.characters[r]?.xAdvance ?? police.base ~/ 2;
  }
  return l;
}

/// Une ligne centrée dans une bande de [largeur] : blanc cerné de noir,
/// lisible sur une photo claire comme sombre.
void _ligneImage(img.Image cible, String texte, img.BitmapFont police, int x0,
    int y0, int largeur) {
  final x = x0 + max<int>(0, (largeur - _largeur(texte, police)) ~/ 2);
  final y = y0 + 2;
  final noir = img.ColorRgba8(0, 0, 0, 200);
  for (final (dx, dy) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
    img.drawString(cible, texte, font: police, x: x + dx, y: y + dy, color: noir);
  }
  img.drawString(cible, texte,
      font: police, x: x, y: y, color: img.ColorRgba8(255, 255, 255, 220));
}
