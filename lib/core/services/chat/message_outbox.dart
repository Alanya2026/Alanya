/// Outbox / retry d'envoi hors-ligne.
///
/// Implémentation : [ChatRepository.flushOutbox], `retryMessage`, uploads
/// pending (`_uploadAndEmit`, `_inFlightUploads`).
library;
