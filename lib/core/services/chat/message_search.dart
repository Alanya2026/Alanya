/// Filtre de la recherche de messages dans une conversation.
///
/// Logique pure, séparée de l'écran et de la base : elle se teste sans l'un ni
/// l'autre. La requête SQL ([ChatDao.searchCandidates]) écarte ce qui n'est pas
/// cherchable ; ici on ne fait que comparer du texte normalisé.
library;

import 'package:flutter/foundation.dart' show compute;

import '../../utils/search_normalizer.dart';

/// Types dont le contenu est de la prose cherchable.
///
/// **Liste blanche volontaire**, sur le modèle de `kTranslatableMessageTypes` :
/// 0 = texte, 1 / 2 / 4 = photo, vidéo, fichier (seule la légende compte).
/// L'audio (3) est exclu : son contenu est un nom de fichier, pas de la prose.
/// Les types 5 et suivants stockent du JSON (position, événement de groupe,
/// contact, trajet) que l'utilisateur ne tape jamais.
///
/// Une liste noire laisserait un futur type 10 devenir cherchable par défaut ;
/// ici il reste exclu tant que personne ne l'a explicitement autorisé.
const Set<int> kSearchableMessageTypes = {0, 1, 2, 4};

/// En deçà, presque tout le fil correspond : la recherche ne servirait à rien.
const int kMinSearchQueryLength = 2;

/// Au-delà, le filtrage passe dans un isolate pour ne pas geler l'écran. Une
/// conversation de groupe très active atteint ce volume en quelques mois.
const int _kSeuilIsolate = 5000;

/// Message réduit à ce que la recherche lit. Type léger : il traverse la
/// frontière d'un isolate, ce qu'un `LocalMessage` complet (vignettes,
/// réactions…) rendrait coûteux.
class CandidatRecherche {
  final int msgID;
  final String content;
  final DateTime sendAt;
  const CandidatRecherche({
    required this.msgID,
    required this.content,
    required this.sendAt,
  });
}

/// Requête normalisée et nettoyée des espaces de bord, ou `null` si elle est
/// trop courte pour lancer une recherche.
String? requeteValide(String requete) {
  final q = normaliserPourRecherche(requete).texte.trim();
  return q.length < kMinSearchQueryLength ? null : q;
}

/// `msgID` des candidats dont le contenu contient [requete], du plus récent au
/// plus ancien.
List<int> filtrerMessages(List<CandidatRecherche> candidats, String requete) {
  final q = requeteValide(requete);
  if (q == null) return const [];

  final trouves = candidats
      .where((c) => normaliserPourRecherche(c.content).texte.contains(q))
      .toList()
    // Égalité de date : le msgID départage, pour un ordre stable.
    ..sort((a, b) {
      final d = b.sendAt.compareTo(a.sendAt);
      return d != 0 ? d : b.msgID.compareTo(a.msgID);
    });
  return trouves.map((c) => c.msgID).toList();
}

Future<List<int>> rechercherMessages(
    List<CandidatRecherche> candidats, String requete) {
  if (candidats.length < _kSeuilIsolate) {
    return Future.value(filtrerMessages(candidats, requete));
  }
  return compute(_filtrerDansIsolate, (candidats, requete));
}

List<int> _filtrerDansIsolate((List<CandidatRecherche>, String) args) =>
    filtrerMessages(args.$1, args.$2);
