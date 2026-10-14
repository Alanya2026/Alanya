import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Noms personnalisés de mes contacts préférés — LE point central de
/// l'affichage d'un nom d'utilisateur.
///
/// Règle produit : la fiche d'un contact montre toujours le nom du profil et
/// le pseudo ; partout ailleurs on affiche le nom personnalisé s'il existe,
/// sinon le nom du profil. Tout écran passe par [nameFor] (ou par
/// `User.displayName`, qui s'appuie dessus) : aucun ne refait ce choix.
///
/// Le nom choisi vit dans le cache local (`local_users.preferred_name`). Ce
/// registre en est la copie en mémoire, pour répondre sans requête : le cache
/// le remplit à chaque lecture ou synchronisation des contacts préférés. Une
/// copie sur disque sert les isolates d'arrière-plan (push reçu app fermée),
/// qui n'ont pas la base ouverte.
class ContactAliases {
  ContactAliases._();

  static const _prefsKey = 'contact_aliases_v1';

  static final Map<int, String> _names = {};

  /// Vrai dès que le cache a rempli le registre dans cet isolate : la copie
  /// sur disque n'a alors plus rien à apprendre.
  static bool _filledFromCache = false;

  /// Incrémenté à chaque changement réel : les écrans qui affichent un nom
  /// de discussion s'y abonnent pour se redessiner.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Nom personnalisé de [alanyaID], ou null s'il n'en a pas.
  static String? of(int alanyaID) => _names[alanyaID];

  /// LE nom à afficher pour un utilisateur, partout sauf sur sa fiche : mon
  /// nom personnalisé s'il existe, sinon [profileName] (nom du profil, ou le
  /// repli que l'appelant avait déjà). Point d'entrée unique des écrans qui
  /// n'ont qu'un identifiant et une chaîne (appels, notifications, JSON).
  static String nameFor(int? alanyaID, String? profileName) {
    final alias = alanyaID == null ? null : _names[alanyaID];
    return alias ?? (profileName ?? '');
  }

  static void set(int alanyaID, String? name) {
    final clean = (name ?? '').trim();
    if ((_names[alanyaID] ?? '') == clean) return;
    if (clean.isEmpty) {
      _names.remove(alanyaID);
    } else {
      _names[alanyaID] = clean;
    }
    revision.value++;
    unawaited(_persist());
  }

  static void replaceAll(Map<int, String?> names) {
    _filledFromCache = true;
    final next = <int, String>{};
    names.forEach((id, name) {
      final clean = (name ?? '').trim();
      if (clean.isNotEmpty) next[id] = clean;
    });
    if (mapEquals(next, _names)) return;
    _names
      ..clear()
      ..addAll(next);
    revision.value++;
    unawaited(_persist());
  }

  /// Relit la copie sur disque tant que le cache n'a pas rempli le registre.
  /// À appeler avant d'afficher un nom hors de l'app ouverte (écran d'appel
  /// du système, notification) : sans effet dans l'isolate principal une
  /// fois les contacts lus.
  static Future<void> preload() async {
    if (_filledFromCache) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(_prefsKey);
      if (_filledFromCache) return;
      final next = <int, String>{};
      if (raw != null && raw.isNotEmpty) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((id, name) {
          final key = int.tryParse(id);
          final clean = name?.toString().trim() ?? '';
          if (key != null && clean.isNotEmpty) next[key] = clean;
        });
      }
      if (mapEquals(next, _names)) return;
      _names
        ..clear()
        ..addAll(next);
      revision.value++;
    } catch (e) {
      debugPrint('[ContactAliases] lecture de la copie disque échouée: $e');
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_names.map((id, name) => MapEntry('$id', name))),
      );
    } catch (e) {
      // Tests sans plugin, stockage indisponible : le registre en mémoire
      // reste juste, seul l'arrière-plan retombera sur le nom du profil.
      debugPrint('[ContactAliases] copie disque échouée: $e');
    }
  }
}
