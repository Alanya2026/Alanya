/// États de traduction d'un message, miroir de `LocalMessages.translationState`.
///
/// Fichier feuille, sans dépendance : le DAO comme le service de traduction
/// s'en servent, et faire dépendre le DAO du service inverserait les couches.
///
/// La valeur n'est jamais envoyée au serveur ni reçue de lui — elle décrit
/// l'avancement d'un traitement purement local.
class MessageTranslationState {
  const MessageTranslationState._();

  /// Jamais examiné, ou à réexaminer. Valeur par défaut en base.
  static const int pending = 0;

  /// Traduit : `translatedContent` et `sourceLang` sont renseignés.
  static const int done = 1;

  /// Rien à faire, et c'est définitif tant que le message ne change pas :
  /// contenu non traduisible (JSON de localisation, de trajet, marqueur
  /// d'album…), texte trop court pour être identifié, langue indéterminée,
  /// langue source non supportée, ou message déjà dans la langue de lecture.
  ///
  /// C'est cet état qui évite de ré-identifier la langue de tout l'historique
  /// à chaque lancement de l'app.
  static const int skipped = 2;

  /// Traduisible, mais le modèle de langue manque sur l'appareil. L'interface
  /// propose le téléchargement ; une fois le modèle installé, ces lignes
  /// repassent en [pending].
  static const int missingModel = 3;

  /// Échec technique de la traduction. Non réessayé automatiquement pour ne pas
  /// boucler ; l'utilisateur peut forcer via le menu du message.
  static const int failed = 4;
}
