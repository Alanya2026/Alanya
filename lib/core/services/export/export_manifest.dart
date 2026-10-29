import 'dart:convert';

import '../../utils/sticker_payload.dart';

/// Version du format d'archive. Toute évolution incompatible l'incrémente :
/// la restauration doit pouvoir refuser proprement une archive qu'elle ne sait
/// pas lire, plutôt que d'en tirer des conclusions fausses.
const String kExportFormat = 'alanya-export/1';

/// Pourquoi un média de la période n'est pas dans l'archive.
///
/// La distinction n'est pas cosmétique : elle décide de ce que l'écran a le
/// droit de promettre. Proposer un téléchargement pour un média purgé du
/// serveur serait promettre un échec.
enum MissingReason {
  /// Reçu mais jamais téléchargé — auto-téléchargement coupé, échec réseau.
  /// Encore sur le serveur, donc récupérable, à un coût qu'on sait annoncer.
  neverDownloaded,

  /// Plus vieux que la rétention serveur. Le serveur répond `410`. Aucune
  /// action ne le ramènera : il n'existe plus qu'ici, ou nulle part.
  expired,

  /// La base annonçait un fichier local qui n'est plus sur le disque —
  /// effacé hors de l'app (nettoyage système, gestionnaire de fichiers). Le
  /// serveur l'a peut-être encore : traité comme récupérable si sa partition
  /// n'est pas expirée, sinon comme perdu.
  fileGone,
}

/// Une entrée présente dans l'archive.
class ExportItem {
  /// `msgID` serveur. Vaut 0 tant que le message n'est pas confirmé — ce qui
  /// n'arrive pas pour un média téléchargé, mais on ne s'y fie pas seul.
  final int msgID;

  /// Clé primaire du message, stable dès l'origine. C'est **elle** que la
  /// restauration utilise pour remettre un fichier en face de son message ;
  /// [msgID] ne sert que de confirmation.
  final String clientId;

  final int conversationID;
  final String? conversationName;
  final int senderID;
  final String? senderName;
  final bool isMine;

  /// 1=image 2=vidéo 3=audio 4=fichier, 10=sticker.
  final int type;

  /// Référence d'un sticker (type 10) : son pack, son identifiant et l'emoji.
  ///
  /// Un sticker n'a pas de fichier à lui sur le disque (juste une image mise en
  /// cache) : l'archive emporte donc de quoi le **référencer** et le
  /// réafficher, jamais le JSON brut du message. `null` pour tout autre type, et
  /// aussi pour un payload illisible ou d'une version future — l'archive reste
  /// alors lisible, elle sait seulement moins de choses.
  final String? stickerPack;
  final int? stickerSid;
  final String? stickerEmoji;

  /// Ce média est-il un sticker (type 10) ?
  bool get isSticker => type == kStickerMessageType;

  final DateTime? sentAt;

  /// Chemin dans l'archive, ex. `Alanya Images/2026-03-14_ama-nguema_0001.jpg`.
  final String path;

  /// Nom d'origine du fichier, quand le message le portait.
  final String? originalName;

  /// Poids mesuré sur le disque, jamais lu depuis `mediaSize` : la colonne est
  /// nulle pour tous les médias antérieurs à la collecte des tailles.
  final int bytes;

  /// Empreinte du contenu. Rend la restauration idempotente — rejouer une
  /// archive déjà restaurée ne duplique rien — et détecte un fichier tronqué
  /// par une coupure au lieu de l'installer.
  final String sha256;

  /// URL serveur d'origine, pour retrouver la partition et donc l'expiration.
  final String mediaUrl;

  const ExportItem({
    required this.msgID,
    required this.clientId,
    required this.conversationID,
    this.conversationName,
    required this.senderID,
    this.senderName,
    required this.isMine,
    required this.type,
    this.stickerPack,
    this.stickerSid,
    this.stickerEmoji,
    this.sentAt,
    required this.path,
    this.originalName,
    required this.bytes,
    required this.sha256,
    required this.mediaUrl,
  });

  Map<String, dynamic> toJson() => {
        'msgID': msgID,
        'clientId': clientId,
        'conversationID': conversationID,
        if (conversationName != null) 'conversationName': conversationName,
        'senderID': senderID,
        if (senderName != null) 'senderName': senderName,
        'isMine': isMine,
        'type': type,
        if (stickerPack != null) 'stickerPack': stickerPack,
        if (stickerSid != null) 'stickerSid': stickerSid,
        if (stickerEmoji != null) 'stickerEmoji': stickerEmoji,
        if (sentAt != null) 'sentAt': sentAt!.toUtc().toIso8601String(),
        'path': path,
        if (originalName != null) 'originalName': originalName,
        'bytes': bytes,
        'sha256': sha256,
        'mediaUrl': mediaUrl,
      };

  factory ExportItem.fromJson(Map<String, dynamic> json) => ExportItem(
        msgID: _asInt(json['msgID']) ?? 0,
        clientId: json['clientId']?.toString() ?? '',
        conversationID: _asInt(json['conversationID']) ?? 0,
        conversationName: json['conversationName']?.toString(),
        senderID: _asInt(json['senderID']) ?? 0,
        senderName: json['senderName']?.toString(),
        isMine: json['isMine'] == true,
        type: _asInt(json['type']) ?? 0,
        stickerPack: json['stickerPack']?.toString(),
        stickerSid: _asInt(json['stickerSid']),
        stickerEmoji: json['stickerEmoji']?.toString(),
        sentAt: _asDate(json['sentAt']),
        path: json['path']?.toString() ?? '',
        originalName: json['originalName']?.toString(),
        bytes: _asInt(json['bytes']) ?? 0,
        sha256: json['sha256']?.toString() ?? '',
        mediaUrl: json['mediaUrl']?.toString() ?? '',
      );
}

/// Un média de la période qui n'a pas pu entrer dans l'archive.
class ExportMissing {
  final int msgID;
  final String clientId;
  final DateTime? sentAt;
  final MissingReason reason;

  /// Type du message. Sert à traiter les stickers (type 10) à part : ils ne se
  /// récupèrent pas comme un média ordinaire — leur image vit dans le cache
  /// dédié ([StickerCache]), et l'archive ne renseigne pas `localMediaPath`.
  /// `0` pour une archive ancienne ou un type non précisé.
  final int type;

  const ExportMissing({
    required this.msgID,
    required this.clientId,
    this.sentAt,
    required this.reason,
    this.type = 0,
  });

  /// Ce média est-il un sticker (type 10) ?
  bool get isSticker => type == kStickerMessageType;

  /// Le serveur peut encore le rendre — sous réserve d'accepter la dépense.
  bool get recoverable => reason != MissingReason.expired;

  Map<String, dynamic> toJson() => {
        'msgID': msgID,
        'clientId': clientId,
        if (sentAt != null) 'sentAt': sentAt!.toUtc().toIso8601String(),
        'reason': reason.name,
        if (type != 0) 'type': type,
      };

  factory ExportMissing.fromJson(Map<String, dynamic> json) => ExportMissing(
        msgID: _asInt(json['msgID']) ?? 0,
        clientId: json['clientId']?.toString() ?? '',
        sentAt: _asDate(json['sentAt']),
        reason: MissingReason.values.firstWhere(
          (r) => r.name == json['reason'],
          // Un motif inconnu vient d'une version plus récente. Le supposer
          // récupérable ferait promettre un téléchargement qui échouerait ;
          // le supposer perdu est le pessimisme sûr.
          orElse: () => MissingReason.expired,
        ),
        type: _asInt(json['type']) ?? 0,
      );
}

/// Le `manifest.json` de l'archive.
///
/// C'est ce qui distingue une archive utile d'un tas de fichiers. Un an plus
/// tard, un nom de fichier ne dit ni qui a envoyé la photo, ni dans quelle
/// conversation, ni quand — le manifeste porte tout cela. Et il porte les
/// identifiants dont la restauration a besoin pour remettre chaque fichier en
/// face du bon message : l'archive sert donc l'humain **et** la machine, sans
/// que l'un gêne l'autre.
class ExportManifest {
  final String format;
  final int alanyaID;
  final DateTime generatedAt;

  /// Bornes de la période, inclusives à la journée, telles que l'inscrit les a
  /// choisies.
  final DateTime? periodFrom;
  final DateTime? periodTo;

  /// Filtres appliqués, pour que l'archive dise de quoi elle est l'extrait.
  final int? conversationID;
  final String? conversationName;

  /// Rétention serveur connue au moment de l'export, ou `null` si le client ne
  /// l'avait pas encore apprise. Explique pourquoi certains éléments sont
  /// déclarés perdus.
  final int? retentionDaysKnown;

  final List<ExportItem> items;
  final List<ExportMissing> missing;

  const ExportManifest({
    this.format = kExportFormat,
    required this.alanyaID,
    required this.generatedAt,
    this.periodFrom,
    this.periodTo,
    this.conversationID,
    this.conversationName,
    this.retentionDaysKnown,
    required this.items,
    required this.missing,
  });

  int get totalBytes => items.fold(0, (sum, i) => sum + i.bytes);

  Map<String, dynamic> toJson() => {
        'format': format,
        'alanyaID': alanyaID,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'period': {
          if (periodFrom != null) 'from': _day(periodFrom!),
          if (periodTo != null) 'to': _day(periodTo!),
        },
        'filters': {
          if (conversationID != null) 'conversationID': conversationID,
          if (conversationName != null) 'conversationName': conversationName,
        },
        if (retentionDaysKnown != null)
          'retentionDaysKnown': retentionDaysKnown,
        'items': items.map((i) => i.toJson()).toList(),
        'missing': missing.map((m) => m.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory ExportManifest.decode(String source) =>
      ExportManifest.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory ExportManifest.fromJson(Map<String, dynamic> json) {
    final period = (json['period'] as Map?)?.cast<String, dynamic>();
    final filters = (json['filters'] as Map?)?.cast<String, dynamic>();
    return ExportManifest(
      format: json['format']?.toString() ?? kExportFormat,
      alanyaID: _asInt(json['alanyaID']) ?? 0,
      generatedAt: _asDate(json['generatedAt']) ?? DateTime.now().toUtc(),
      periodFrom: _asDate(period?['from']),
      periodTo: _asDate(period?['to']),
      conversationID: _asInt(filters?['conversationID']),
      conversationName: filters?['conversationName']?.toString(),
      retentionDaysKnown: _asInt(json['retentionDaysKnown']),
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => ExportItem.fromJson(m.cast<String, dynamic>()))
          .toList(),
      missing: ((json['missing'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => ExportMissing.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// L'archive est-elle lisible par cette version du code ?
  ///
  /// On compare la famille de format, pas la chaîne entière : `alanya-export/2`
  /// doit être refusé explicitement plutôt que lu de travers.
  bool get isSupported => format == kExportFormat;
}

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}
