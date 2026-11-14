import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

/// Le code de sécurité d'une conversation à deux : 60 chiffres que les deux
/// personnes comparent hors de l'application.
///
/// ── Un code pour la conversation, pas un par appareil ──
///
/// Chaque appareil a sa propre clé d'identité. Un code par appareil obligerait
/// à comparer autant de codes qu'il y a de paires d'appareils, et personne ne
/// le fait. Le code couvre donc TOUTES les clés de chaque compte : celles de
/// mes appareils d'un côté, celles du correspondant de l'autre (format
/// « liste » de Signal, clés triées). Un appareil ajouté ou une clé changée,
/// d'un côté ou de l'autre, change le code.
///
/// ── D'où viennent les clés ──
///
/// De ce que CET appareil a utilisé pour chiffrer (le store), jamais de ce que
/// le serveur annonce : comparer les clés du serveur ne prouverait rien contre
/// le serveur.
///
/// Les deux téléphones obtiennent le même code s'ils voient les mêmes clés :
/// chacun place les siennes en « local », mais l'affichage trie les deux
/// moitiés, si bien que l'ordre ne dépend pas de qui regarde.
class CodeSecurite {
  const CodeSecurite({
    required this.chiffres,
    required this.empreinte,
    required this.verifie,
    required this.appareilsManquants,
  });

  /// Les 60 chiffres, sans espaces.
  final String chiffres;

  /// Résumé des clés couvertes : ce qu'on retient quand le code est vérifié.
  final String empreinte;

  /// Le code a été marqué vérifié et aucune clé n'a changé depuis.
  final bool verifie;

  /// Appareils annoncés dont cet appareil n'a pas (encore) la clé. Non nul,
  /// le code ne peut pas correspondre à celui de l'autre téléphone : l'écran
  /// le dit plutôt que de laisser croire à une interposition.
  final int appareilsManquants;

  /// Douze groupes de cinq chiffres, comme on les lit à voix haute.
  List<String> get groupes => [
        for (var i = 0; i < chiffres.length; i += 5) chiffres.substring(i, i + 5),
      ];
}

/// Itérations de Signal pour l'empreinte numérique.
const int _iterations = 5200;

/// Calcule les 60 chiffres et l'empreinte.
///
/// [moi] et [correspondant] sont les identifiants de compte : ils entrent
/// dans le calcul, si bien que deux comptes aux mêmes clés n'auraient pas le
/// même code. Lève [ArgumentError] si une des deux listes est vide.
({String chiffres, String empreinte}) calculerCodeSecurite({
  required int moi,
  required List<IdentityKey> mesCles,
  required int correspondant,
  required List<IdentityKey> sesCles,
}) {
  if (mesCles.isEmpty || sesCles.isEmpty) {
    throw ArgumentError('une conversation sans clé n\'a pas de code');
  }
  final empreinte = NumericFingerprintGenerator(_iterations).createListFor(
    2,
    Uint8List.fromList(utf8.encode('$moi')),
    mesCles,
    Uint8List.fromList(utf8.encode('$correspondant')),
    sesCles,
  );
  return (
    chiffres: empreinte.displayableFingerprint.getDisplayText(),
    empreinte: _resume(moi, mesCles, correspondant, sesCles),
  );
}

/// SHA-256 des deux comptes et de leurs clés triées. Ne dépend pas de l'ordre
/// dans lequel les clés ont été lues.
String _resume(int moi, List<IdentityKey> a, int lui, List<IdentityKey> b) {
  String cles(List<IdentityKey> l) =>
      (l.map((k) => base64Encode(k.serialize())).toList()..sort()).join(',');
  return sha256.convert(utf8.encode('$moi:${cles(a)}|$lui:${cles(b)}')).toString();
}
