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

/// Contenu d'un message de type 11 : un fichier, ou un lot (lot 9 : un album
/// ou une sélection en une seule carte).
class SafeboxSharePayload {
  const SafeboxSharePayload({
    required this.share,
    required this.name,
    required this.size,
    required this.family,
    this.mime,
    this.blur,
    this.meta,
    this.kind = SafeboxShareKind.file,
    this.count = 1,
    this.families = const {},
    this.mosaic = const [],
  });

  static const int currentVersion = 1;

  /// Plus longue mini-image d'une case de la mosaïque (base64), comme le serveur.
  static const int mosaicBlurMax = 3000;

  /// Numéro du partage côté serveur.
  final int share;

  /// Nom du fichier, ou titre du lot.
  final String name;

  /// Taille en clair ; pour un lot, la somme.
  final int size;
  final String? mime;

  /// Type du fichier ; pour un lot, le plus nombreux.
  final SafeboxFamily family;

  /// Mini-image floue (base64, quelques Ko), affichée tout de suite, même
  /// hors connexion, avant l'aperçu net.
  final String? blur;

  /// Durée, définition, pages… (relevés au dépôt) ; null pour un fichier
  /// déposé avant la migration 104.
  final SafeboxMeta? meta;

  final SafeboxShareKind kind;

  /// Lot : nombre d'éléments, et par type.
  final int count;
  final Map<SafeboxFamily, int> families;

  /// Lot : les mini-images des quatre premiers éléments, dans l'ordre (une
  /// chaîne vide pour une case sans image).
  final List<String> mosaic;

  bool get isBatch => kind == SafeboxShareKind.batch;

  static SafeboxSharePayload? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final d = jsonDecode(content);
      if (d is! Map) return null;
      final share = d['share'];
      if (share is! int || share <= 0) return null;
      final bs = d['bs'];
      return SafeboxSharePayload(
        share: share,
        name: d['name'] is String ? d['name'] as String : '',
        size: d['size'] is num ? (d['size'] as num).toInt() : 0,
        mime: d['mime'] as String?,
        family: SafeboxFamily.fromName(d['family'] as String?),
        blur: d['b'] is String ? d['b'] as String : null,
        meta: SafeboxMeta.fromJson(d['meta']),
        kind: SafeboxShareKind.fromName(d['kind'] as String?),
        count: d['count'] is num ? (d['count'] as num).toInt() : 1,
        families: safeboxFamilyCounts(d['families']),
        mosaic: bs is List ? [for (final x in bs.take(4)) x is String ? x : ''] : const [],
      );
    } catch (_) {
      return null;
    }
  }

  /// Ce qui part au serveur. Il ne lit que `share`, `b` et `bs` et réécrit le
  /// reste ; les autres champs servent à afficher la bulle avant sa réponse
  /// (et, dans une discussion chiffrée, à la carte elle-même).
  String encode() => jsonEncode({
        'v': currentVersion,
        'share': share,
        'name': name,
        'size': size,
        'mime': mime,
        'family': family.name,
        if (isBatch) ...{
          'kind': kind.name,
          'count': count,
          'families': {for (final e in families.entries) e.key.name: e.value},
        },
        if (meta != null) 'meta': meta!.toJson(),
        if (blur != null) 'b': blur,
        if (isBatch && mosaic.any((b) => b.isNotEmpty)) 'bs': mosaic,
      });

  String previewLabel(AppLocalizations l10n) =>
      name.isEmpty ? l10n.safeboxShareFallback : l10n.safeboxSharePreview(name);
}
