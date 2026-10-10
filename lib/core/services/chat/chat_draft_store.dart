import 'package:shared_preferences/shared_preferences.dart';

/// Brouillon du champ de saisie, par conversation.
///
/// Le texte en cours de saisie vivait dans le contrôleur de l'écran de
/// discussion : il disparaissait dès qu'on quittait la discussion, ou que
/// l'application était tuée en arrière-plan (groupe 3GI 2029, bug A10).
///
/// La clé porte l'identifiant du compte : un brouillon ne doit jamais
/// réapparaître sous un autre compte connecté sur le même téléphone.
class ChatDraftStore {
  ChatDraftStore._();

  static const _prefix = 'chat_draft_';

  static String keyFor(int myId, int conversationId) =>
      '$_prefix${myId}_$conversationId';

  static Future<String?> load(int myId, int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString(keyFor(myId, conversationId));
    return (draft == null || draft.trim().isEmpty) ? null : draft;
  }

  /// Un texte vide (ou blanc) efface le brouillon.
  static Future<void> save(int myId, int conversationId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(myId, conversationId);
    if (text.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, text);
    }
  }

  static Future<void> clear(int myId, int conversationId) =>
      save(myId, conversationId, '');
}
