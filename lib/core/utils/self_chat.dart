/// Marqueur serveur d'une conversation « avec soi-même », porté par `GroupName`.
///
/// Voir `Alanya-Backend/src/utils/directConversation.js` : la colonne `GroupName`
/// est inutilisée pour `isGroup = 0` (écrite seulement à la création et au
/// renommage d'un groupe), ce qui évite une migration des deux côtés.
///
/// Ne JAMAIS déduire le self-chat de « 1-1 sans autre participant » :
/// `deleteConversation` ne retire que la ligne du partant, si bien qu'une conv
/// 1-1 dont le pair a supprimé son côté — ou dont le compte a été supprimé —
/// présente exactement la même forme sans en être une.
///
/// Fichier feuille volontairement sans import : il est partagé par le modèle
/// réseau (`talky_models.dart`) et la couche locale (`conversation_display.dart`),
/// qui ne doivent pas dépendre l'un de l'autre.
library;

const kSelfChatMarker = '__self__';
