//  Après un ajout au coffre depuis le téléphone (07/11/2026) : garder les
//  photos et vidéos sur le téléphone, demander à chaque fois, ou toujours les
//  retirer du téléphone une fois arrivées dans le coffre.
//
//  Jamais avant : l'envoi terminé, chaque original passe dans une liste
//  d'attente ([SafeboxPhoneTrash]) ; l'accueil du coffre la vide quand plus
//  rien de ce qui doit partir n'est en route, d'un seul coup (Android demande
//  une seule confirmation, puis place le lot dans sa corbeille, 30 jours).
//  La liste vit dans les préférences : la tâche de fond peut terminer un
//  envoi, seule l'application ouverte demande la confirmation.
//  La sauvegarde automatique ne supprime rien.

import 'package:shared_preferences/shared_preferences.dart';

enum SafeboxPhoneCleanup {
  /// Les photos et vidéos ajoutées restent sur le téléphone (par défaut).
  keep,

  /// Avant chaque ajout, l'application demande.
  ask,

  /// Chaque photo ou vidéo ajoutée quitte le téléphone une fois dans le coffre.
  always;

  static const _cle = 'safebox_phone_cleanup_v1';

  static Future<SafeboxPhoneCleanup> load() async {
    final prefs = await SharedPreferences.getInstance();
    final nom = prefs.getString(_cle);
    return values.firstWhere((v) => v.name == nom, orElse: () => keep);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, name);
  }
}

/// Les originaux (numéros de la galerie d'Android) dont la copie est arrivée
/// dans le coffre, en attente de partir à la corbeille du téléphone.
class SafeboxPhoneTrash {
  static const _cle = 'safebox_phone_trash_v1';

  static Future<List<String>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getStringList(_cle) ?? const [];
  }

  static Future<void> add(String mediaId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final liste = prefs.getStringList(_cle) ?? <String>[];
    if (!liste.contains(mediaId)) await prefs.setStringList(_cle, [...liste, mediaId]);
  }

  /// Oublie ceux-là : partis, ou l'inscrit a refusé dans la confirmation
  /// d'Android (on ne redemande pas).
  static Future<void> forget(Iterable<String> mediaIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final retires = mediaIds.toSet();
    await prefs.setStringList(_cle, [for (final id in prefs.getStringList(_cle) ?? const <String>[]) if (!retires.contains(id)) id]);
  }
}
