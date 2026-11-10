/// Le coffre-fort Alanya, commun à l'application mobile et à l'application
/// de bureau : chiffrement SBX1, modèles, API, envois, téléchargements,
/// sauvegarde et empreintes. Sans écran.
///
/// Chaque application fournit un [SafeboxHttp] (jeton, renouvellement,
/// erreurs) et ajoute [SafeboxCalls] à son client.
library;

export 'src/api.dart';
export 'src/backup.dart';
export 'src/cipher.dart';
export 'src/download_manager.dart';
export 'src/http.dart';
export 'src/models.dart';
export 'src/quality.dart';
export 'src/upload_manager.dart';
export 'src/upload_stall_guard.dart';
