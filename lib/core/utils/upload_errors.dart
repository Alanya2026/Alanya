import '../../talky_api_client.dart';

/// Erreurs d'upload retentables automatiquement (outbox / backoff).
bool isTransientUploadError(Object e) {
  if (e is TalkyException) {
    return e.statusCode == 0 ||
        e.statusCode == 429 ||
        (e.statusCode >= 500 && e.statusCode < 600);
  }
  return true;
}
