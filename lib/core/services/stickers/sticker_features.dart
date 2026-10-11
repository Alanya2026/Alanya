import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fonctionnalités que le serveur ouvre à ce compte (`GET /me` →
/// `features: {creation, animated}`, contrat §4c).
///
/// **Le serveur tranche** : l'application ne fait que refléter. Un champ absent
/// vaut « fermé » (ancien serveur, module fermé). La dernière valeur connue est
/// gardée dans SharedPreferences, pour que l'option « Sticker animé » ne
/// disparaisse pas parce que le réseau manque ; une préférence plutôt qu'une
/// colonne Drift : une valeur booléenne par compte, aucune migration.
///
/// Un seul objet est partagé par `StickerRepository` (qui lit `/me`) et
/// `StickerCreationRepository` (qui masque l'option sur un `404 NOT_FOUND` de
/// la création animée).
class StickerFeatures {
  StickerFeatures();

  static const String creationKey = 'stickers_feature_creation';
  static const String animatedKey = 'stickers_feature_animated';

  /// Clés à oublier à la déconnexion (`clearSession`).
  static const List<String> prefKeys = [creationKey, animatedKey];

  /// La création de stickers est ouverte (information de `/me` ; l'interface
  /// de création se règle, elle, sur `GET /me/created`).
  final ValueNotifier<bool> creation = ValueNotifier<bool>(false);

  /// La création **et** la lecture des stickers animés sont ouvertes
  /// (`animated_enabled`). Faux : aucune option « animé » n'apparaît.
  final ValueNotifier<bool> animated = ValueNotifier<bool>(false);

  bool _restored = false;

  /// Relit les dernières valeurs connues (une seule fois par instance).
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final prefs = await SharedPreferences.getInstance();
    // Une valeur déjà posée par `/me` pendant l'attente l'emporte.
    if (!creation.value) creation.value = prefs.getBool(creationKey) ?? false;
    if (!animated.value) animated.value = prefs.getBool(animatedKey) ?? false;
  }

  /// Applique le champ `features` d'une réponse `/me` ; absent ou illisible =
  /// fermé (contrat §4c : « absent = faux pour l'app »).
  Future<void> apply(Object? raw) async {
    final map = raw is Map ? raw : const {};
    _restored = true;
    await _set(creation: map['creation'] == true, animated: map['animated'] == true);
  }

  /// Le serveur a répondu `404 NOT_FOUND` à la création animée : les animés
  /// sont fermés, l'option disparaît.
  Future<void> animatedClosed() => _set(animated: false);

  Future<void> _set({bool? creation, bool? animated}) async {
    final prefs = await SharedPreferences.getInstance();
    if (creation != null) {
      this.creation.value = creation;
      await prefs.setBool(creationKey, creation);
    }
    if (animated != null) {
      this.animated.value = animated;
      await prefs.setBool(animatedKey, animated);
    }
  }
}
