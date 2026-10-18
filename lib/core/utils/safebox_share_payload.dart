import 'dart:convert';

import '../../l10n/app_localizations.dart';
import '../services/safebox/safebox_models.dart';

/// Type de message « fichier du coffre-fort » (backend :
/// utils/safeboxShareMessage.js). Les types 0 à 9 sont ceux de l'application,
/// le 10 est le sticker (web) : le 11 est le premier libre.
///
/// Le message ne porte que le numéro du partage : le fichier ne passe jamais
/// par les médias de discussion. Le serveur réécrit `content` à partir du
/// partage, et `mediaName` sert de repli lisible aux applications qui ne
/// connaissent pas ce type (« 📦 Mariage.mp4 · 840 Mo »).
const int kSafeboxShareMessageType = 11;

/// Contenu d'un message de type 11.
class SafeboxSharePayload {
  const SafeboxSharePayload({
    required this.share,
    required this.name,
    required this.size,
    required this.family,
    this.mime,
    this.blur,
    this.meta,
  });

  static const int currentVersion = 1;

  /// Numéro du partage côté serveur.
  final int share;
  final String name;

  /// Taille en clair.
  final int size;
  final String? mime;
  final SafeboxRoot family;

  /// Mini-image floue (base64, quelques Ko), affichée tout de suite, même
  /// hors connexion, avant l'aperçu net.
  final String? blur;

  /// Durée, définition, pages… (relevés au dépôt) ; null pour un fichier
  /// déposé avant la migration 104.
  final SafeboxMeta? meta;

  static SafeboxSharePayload? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final d = jsonDecode(content);
      if (d is! Map) return null;
      final share = d['share'];
      if (share is! int || share <= 0) return null;
      return SafeboxSharePayload(
        share: share,
        name: d['name'] is String ? d['name'] as String : '',
        size: d['size'] is num ? (d['size'] as num).toInt() : 0,
        mime: d['mime'] as String?,
        family: SafeboxRoot.fromName(d['family'] as String?) ?? SafeboxRoot.documents,
        blur: d['b'] is String ? d['b'] as String : null,
        meta: SafeboxMeta.fromJson(d['meta']),
      );
    } catch (_) {
      return null;
    }
  }

  /// Ce qui part au serveur. Il ne lit que `share` et `b` et réécrit le reste ;
  /// les autres champs servent à afficher la bulle avant sa réponse.
  String encode() => jsonEncode({
        'v': currentVersion,
        'share': share,
        'name': name,
        'size': size,
        'mime': mime,
        'family': family.name,
        if (meta != null) 'meta': meta!.toJson(),
        if (blur != null) 'b': blur,
      });

  String previewLabel(AppLocalizations l10n) =>
      name.isEmpty ? l10n.safeboxShareFallback : l10n.safeboxSharePreview(name);
}
