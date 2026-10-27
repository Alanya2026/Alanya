import 'dart:convert';
import 'dart:math';

import 'package:mime/mime.dart';

/// LE DESCRIPTEUR D'UN DOCUMENT SENSIBLE (plan : PLAN-DOCUMENTS-SENSIBLES.md,
/// repris d'Alanya Work).
///
/// Un document sensible s'ouvre seulement dans la visionneuse protégée ; il ne
/// se transfère ni ne se partage, et la seule copie qui sort (« Enregistrer »)
/// est signée au nom de qui l'a fait sortir.
///
/// 🔴 MÊMES CLÉS JSON que le descripteur chiffré d'Alanya Work (`sensible`,
/// `protection`). Tant que les médias ne sont pas chiffrés de bout en bout, il
/// voyage dans `message.mediaProtection`, que le serveur stocke sans le lire ;
/// le jour où ils le seront, il entrera tel quel dans l'enveloppe.
class DescripteurSensible {
  const DescripteurSensible({this.protection});

  /// La protection de la copie d'un PDF, `null` pour tout autre document.
  final ProtectionPdf? protection;

  Map<String, dynamic> toJson() => {
        'sensible': true,
        if (protection != null) 'protection': protection!.toJson(),
      };

  String encoder() => jsonEncode(toJson());

  /// Lit un descripteur — une chaîne JSON (colonne locale) ou un objet déjà
  /// parsé (colonne JSON relayée par le serveur). Le REFUSE s'il est mal
  /// formé : jamais de valeur par défaut pour une protection.
  static DescripteurSensible depuisJson(Object? brut) {
    final objet = brut is String ? jsonDecode(brut) : brut;
    if (objet is! Map || objet['sensible'] != true) {
      throw const FormatException('descripteur sensible mal formé');
    }
    return DescripteurSensible(
      protection: objet['protection'] == null
          ? null
          : ProtectionPdf.depuisJson(objet['protection']),
    );
  }

  /// Le descripteur d'un message : celui qu'il porte, ou un descripteur nu si
  /// le message est sensible sans en porter (ou n'en porte qu'un illisible :
  /// il reste sensible, mais sans protection de PDF). `null` pour un message
  /// ordinaire.
  static DescripteurSensible? duMessage({
    required bool isSensitive,
    Object? mediaProtection,
  }) {
    if (!isSensitive) return null;
    if (mediaProtection == null) return const DescripteurSensible();
    try {
      return depuisJson(mediaProtection);
    } on FormatException {
      return const DescripteurSensible();
    }
  }
}

/// LA PROTECTION D'UN PDF SENSIBLE (reprise d'Alanya Work, 24/10/2026).
///
/// L'expéditeur la règle une fois, à l'envoi : autoriser l'impression ou non,
/// mettre un mot de passe ou non — et s'il en met un, il en saisit DEUX :
///
/// * [ouverture] : celui qu'il faut pour ouvrir la copie téléchargée. Montré
///   en clair à l'expéditeur, en VUE UNIQUE au destinataire ;
/// * [proprietaire] : celui qui lève les restrictions (l'impression). Montré à
///   l'expéditeur seulement.
///
/// Sans mot de passe mais sans impression, [proprietaire] est tiré au hasard
/// par l'appareil qui envoie : une restriction de PDF n'existe qu'avec un mot
/// de passe propriétaire. Personne ne le voit.
///
/// Elle s'applique à la COPIE qui sort d'Alanya ; dans l'application, le
/// document reste lisible dans la visionneuse protégée.
class ProtectionPdf {
  const ProtectionPdf({
    required this.imprimer,
    required this.proprietaire,
    this.ouverture,
  });

  /// La copie peut-elle s'imprimer sans le mot de passe propriétaire ?
  final bool imprimer;

  /// Le mot de passe d'ouverture, `null` sans mot de passe.
  final String? ouverture;

  /// Le mot de passe propriétaire, toujours présent.
  final String proprietaire;

  bool get avecMotDePasse => ouverture != null;

  /// Un mot de passe propriétaire que personne ne saisit : 24 caractères tirés
  /// par le générateur sûr du système.
  static String proprietaireAuHasard([Random? hasard]) {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final r = hasard ?? Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < 24; i++)
        alphabet.codeUnitAt(r.nextInt(alphabet.length)),
    ]);
  }

  Map<String, dynamic> toJson() => {
        'imprimer': imprimer,
        if (ouverture != null) 'ouverture': ouverture,
        'proprietaire': proprietaire,
      };

  static ProtectionPdf depuisJson(Object? brut) {
    if (brut is! Map) throw const FormatException('protection mal formée');
    final imprimer = brut['imprimer'];
    final ouverture = brut['ouverture'];
    final proprietaire = brut['proprietaire'];
    if (imprimer is! bool ||
        proprietaire is! String ||
        proprietaire.isEmpty ||
        (ouverture != null && (ouverture is! String || ouverture.isEmpty))) {
      throw const FormatException('protection mal formée');
    }
    return ProtectionPdf(
      imprimer: imprimer,
      ouverture: ouverture as String?,
      proprietaire: proprietaire,
    );
  }
}

/// Le type de message d'un document sensible, d'après son nom : image (1),
/// vidéo (2), audio (3), sinon document (4). C'est ce type qui dit à la
/// visionneuse protégée comment l'afficher.
int typeMessagePourFichier(String nom) {
  final mime = lookupMimeType(nom) ?? '';
  if (mime.startsWith('image/')) return 1;
  if (mime.startsWith('video/')) return 2;
  if (mime.startsWith('audio/')) return 3;
  return 4;
}
