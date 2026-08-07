import 'package:flutter/material.dart';

import '../db/app_database.dart';

/// Couleurs des listes de contacts (le dossier coloré et les puces).
///
/// Palette de la maquette `docs/architecture/maquettes/listes-contacts-acces.html` :
/// huit teintes profondes de valeur voisine, qui tiennent sur fond clair comme
/// sur fond sombre. Les quatre premières sont celles des listes par défaut
/// (Famille, Amis, Bureau, Confiance — doc liste-contacts.pdf).
const List<String> kContactListColors = [
  '#C2185B', // Famille — framboise / rouge
  '#00796B', // Amis — sarcelle / vert
  '#3949AB', // Bureau — indigo / bleu
  '#B7791F', // Confiance — ocre / or
  '#5E35B1', // violet
  '#2E7D32', // vert forêt
  '#C62828', // brique
  '#455A64', // ardoise
];

/// `#RRGGBB` / `#RRGGBBAA` → [Color]. Null si vide ou illisible.
Color? parseListColor(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  if (s.length == 8) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(v);
  }
  return null;
}

bool _hasColor(String? raw) => parseListColor(raw) != null;

/// Couleur effective de chaque liste : `idList → hex`.
///
/// Une liste sans couleur en base (créée avant l'attribution automatique) en
/// reçoit une ici : **la première teinte encore libre**, les listes étant
/// parcourues dans leur ordre de création (`idList` croissant). Le résultat ne
/// dépend que de l'ensemble des listes, donc l'affichage est le même partout —
/// puces, dossiers, feuille — et le même que ce que la synchro finira par
/// écrire en base.
Map<int, String> resolveListColors(Iterable<LocalContactList> lists) {
  final ordered = lists.toList()..sort((a, b) => a.idList.compareTo(b.idList));
  final taken = <String>{
    for (final l in ordered)
      if (_hasColor(l.color)) l.color!.toUpperCase(),
  };

  final resolved = <int, String>{};
  for (final list in ordered) {
    if (_hasColor(list.color)) {
      resolved[list.idList] = list.color!;
      continue;
    }
    final hex = nextFreeContactListColor(taken);
    taken.add(hex.toUpperCase());
    resolved[list.idList] = hex;
  }
  return resolved;
}

/// Première teinte de la palette qu'aucune liste n'utilise déjà. Si les huit
/// sont prises, on recommence au début : mieux vaut un doublon qu'une liste
/// sans couleur.
String nextFreeContactListColor(Set<String> takenUpperCase) {
  for (final hex in kContactListColors) {
    if (!takenUpperCase.contains(hex.toUpperCase())) return hex;
  }
  return kContactListColors[takenUpperCase.length % kContactListColors.length];
}
