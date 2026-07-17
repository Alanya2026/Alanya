/// Envoi de messages (texte, média, album).
///
/// L'implémentation vit encore dans [ChatRepository] (`sendText`, `sendMedia`,
/// `sendMediaFile`, `sendMediaAlbum`, `_emitSend`, `_uploadAndEmit`) car elle
/// partage l'outbox et l'upsert socket. Ce fichier documente la frontière
/// de responsabilité et expose les helpers d'aperçu média.
library;

export 'conversation_merge.dart' show ConversationMerge;
