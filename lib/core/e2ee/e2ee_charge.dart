import 'dart:convert';

/// Ce que porte un message chiffré : la « charge v2 » (docs/e2ee, chapitres
/// 23, 26, 28 et 29).
///
/// Format : le préfixe `"\u0000A2"` puis un objet JSON.
///
/// ```
/// "\u0000A2" + {"v":2,"id":"<clientId>","conv":12,"texte":"…","genre":5,"reponseA":"…"}
/// ```
///
/// ── Pourquoi un préfixe qui commence par un caractère nul ──
///
/// Il ne se tape pas. Quelqu'un qui écrirait littéralement `{"v":2,…}` envoie
/// un texte, jamais une charge : la reconnaissance ne peut pas être trompée par
/// ce qu'on écrit.
///
/// ── Pourquoi `id` et `conv` sont DANS le chiffré ──
///
/// Le serveur rattache chaque corps chiffré à une ligne de message. Hors du
/// chiffré, il pourrait recoller le texte de Bob sur un autre message de Bob,
/// ou dans un autre fil. Dedans, il ne le peut plus : il ne réécrit pas ce
/// qu'il ne lit pas, et le destinataire refuse une charge dont `id` ou `conv`
/// ne correspond pas à la ligne. `id` est le `clientId` — connu AVANT l'envoi,
/// contrairement au `msgID` : l'envoi reste un seul `message:send`.
///
/// ── Faire grandir le format sans casser ──
///
/// Champs facultatifs, ABSENTS quand ils sont vides, IGNORÉS quand ils sont
/// inconnus. Une valeur inattendue d'un champ connu est écartée, pas refusée :
/// perdre tout le message pour un détail serait pire. Seuls `id` et `conv` sont
/// vérifiés strictement.
class ChargeE2ee {
  const ChargeE2ee({
    required this.id,
    required this.conv,
    this.texte,
    this.genre,
    this.reponseA,
  });

  static const String prefixe = '\u0000A2';
  static const int version = 2;

  /// `clientId` du message.
  final String id;

  /// `conversationID`.
  final int conv;

  /// Le texte, la légende d'un média, ou la fiche JSON d'un contact ou d'une
  /// position (selon [genre]).
  final String? texte;

  /// Type du message quand [texte] n'est pas un texte simple (5 position,
  /// 7 contact…). Absent pour un texte ou une légende.
  final int? genre;

  /// `msgID` du message cité, en texte. Le texte cité, lui, ne voyage pas :
  /// chaque appareil l'a déjà dans son cache (chapitre 28).
  final String? reponseA;

  String encoder() {
    final objet = <String, Object>{'v': version, 'id': id, 'conv': conv};
    if (texte != null && texte!.isNotEmpty) objet['texte'] = texte!;
    if (genre != null) objet['genre'] = genre!;
    if (reponseA != null && reponseA!.isNotEmpty) objet['reponseA'] = reponseA!;
    return '$prefixe${jsonEncode(objet)}';
  }

  /// Lit une charge et vérifie qu'elle appartient bien à CETTE ligne.
  ///
  /// Lève [ChargeRefusee] si le préfixe, la version, `id` ou `conv` ne
  /// correspondent pas.
  static ChargeE2ee lire(
    String brut, {
    required String clientIdAttendu,
    required int convAttendue,
  }) {
    if (!brut.startsWith(prefixe)) {
      throw const ChargeRefusee('préfixe absent');
    }
    final Object? objet;
    try {
      objet = jsonDecode(brut.substring(prefixe.length));
    } on FormatException {
      throw const ChargeRefusee('JSON illisible');
    }
    if (objet is! Map) throw const ChargeRefusee('pas un objet');
    if (objet['v'] != version) throw const ChargeRefusee('version inconnue');
    final id = objet['id'];
    final conv = objet['conv'];
    if (id is! String || id != clientIdAttendu) {
      throw const ChargeRefusee('rattachée à un autre message');
    }
    if (conv is! int || conv != convAttendue) {
      throw const ChargeRefusee('rattachée à une autre conversation');
    }
    final texte = objet['texte'];
    final genre = objet['genre'];
    final reponseA = objet['reponseA'];
    return ChargeE2ee(
      id: id,
      conv: conv,
      texte: texte is String ? texte : null,
      genre: genre is int ? genre : null,
      reponseA: reponseA is String ? reponseA : null,
    );
  }
}

/// La charge ne s'applique pas à cette ligne.
class ChargeRefusee implements Exception {
  const ChargeRefusee(this.raison);
  final String raison;
  @override
  String toString() => 'ChargeRefusee($raison)';
}
