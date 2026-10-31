//  Modèles du coffre-fort, tels que les rend l'API `/api/safebox`
//  (backend : src/services/safebox/service.js).

import 'dart:convert';
import 'dart:typed_data';

import 'safebox_quality.dart';

export 'safebox_quality.dart' show SafeboxQuality;

/// Les quatre types de fichiers (la « famille »), décidés par l'extension.
enum SafeboxFamily {
  photos,
  videos,
  audios,
  documents;

  /// Le type rendu par le serveur ; « documents » si inconnu. « albums » est
  /// l'ancien nom des photos (avant le 24/10/2026, migration 108) : les
  /// messages déjà reçus le portent encore.
  static SafeboxFamily fromName(String? name) {
    if (name == 'albums') return photos;
    for (final f in values) {
      if (f.name == name) return f;
    }
    return documents;
  }

  /// Le dossier racine qui n'accepte que ce type.
  SafeboxRoot get root => switch (this) {
        photos => SafeboxRoot.photos,
        videos => SafeboxRoot.videos,
        audios => SafeboxRoot.audios,
        documents => SafeboxRoot.documents,
      };
}

/// Les six dossiers racines, dans l'ordre d'affichage (décision du
/// 24/10/2026). Les quatre premiers se remplissent depuis le téléphone, un
/// type chacun ; Albums et Partager se remplissent à la main et acceptent tout.
enum SafeboxRoot {
  photos,
  videos,
  audios,
  documents,
  albums,
  partager;

  static SafeboxRoot? fromName(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// Le seul type accepté ; null pour Albums et Partager, qui acceptent tout.
  SafeboxFamily? get family => switch (this) {
        photos => SafeboxFamily.photos,
        videos => SafeboxFamily.videos,
        audios => SafeboxFamily.audios,
        documents => SafeboxFamily.documents,
        albums || partager => null,
      };

  bool accepts(SafeboxFamily f) => family == null || family == f;
}

/// Un autre endroit du coffre où se trouve le même contenu (Photos et un
/// album) : la feuille de suppression le nomme.
class SafeboxPlace {
  const SafeboxPlace({required this.fileId, required this.folderId, required this.root, this.folderName});

  factory SafeboxPlace.fromJson(Map<String, dynamic> j) => SafeboxPlace(
        fileId: _int(j['fileId']),
        folderId: _int(j['folderId']),
        root: SafeboxRoot.fromName(j['root'] as String?) ?? SafeboxRoot.documents,
        folderName: j['folderName'] as String?,
      );

  final int fileId;
  final int folderId;
  final SafeboxRoot root;

  /// Nul pour un dossier racine : l'application affiche son nom traduit.
  final String? folderName;
}

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const {};
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class SafeboxRootUsage {
  const SafeboxRootUsage({required this.bytes, required this.files});
  final int bytes;
  final int files;
}

class SafeboxQuota {
  const SafeboxQuota({
    required this.quotaBytes,
    required this.usedBytes,
    required this.pendingBytes,
    required this.trashBytes,
    required this.byRoot,
    this.plus = false,
    this.baseQuotaBytes,
  });

  factory SafeboxQuota.fromJson(Map<String, dynamic> j) {
    final par = _map(j['byRoot']);
    return SafeboxQuota(
      quotaBytes: _int(j['quotaBytes']),
      usedBytes: _int(j['usedBytes']),
      pendingBytes: _int(j['pendingBytes']),
      trashBytes: _int(j['trashBytes']),
      plus: j['plus'] == true,
      baseQuotaBytes: _intOrNull(j['baseQuotaBytes']),
      byRoot: {
        for (final r in SafeboxRoot.values)
          r: SafeboxRootUsage(
            bytes: _int(_map(par[r.name])['bytes']),
            files: _int(_map(par[r.name])['files']),
          ),
      },
    );
  }

  final int quotaBytes;

  /// Tout ce qui compte : fichiers, corbeille et envois en cours.
  final int usedBytes;
  final int pendingBytes;
  final int trashBytes;
  final Map<SafeboxRoot, SafeboxRootUsage> byRoot;

  /// L'espace vient d'Alanya Plus (lot 4).
  final bool plus;

  /// L'espace offert à tous ; null avec un ancien serveur.
  final int? baseQuotaBytes;

  /// Au-delà de l'espace : plus de dépôt possible (fin d'Alanya Plus).
  bool get overQuota => usedBytes > quotaBytes;

  int get freeBytes => quotaBytes > usedBytes ? quotaBytes - usedBytes : 0;

  /// Part utilisée, entre 0 et 1.
  double get ratio => quotaBytes <= 0 ? 1 : (usedBytes / quotaBytes).clamp(0.0, 1.0);
}

class SafeboxLimits {
  const SafeboxLimits({
    required this.maxFileBytes,
    required this.blockBytes,
    required this.maxPreviewBytes,
    required this.maxDepth,
    required this.maxFolders,
    required this.folderNameMax,
    required this.fileNameMax,
    required this.extensions,
  });

  factory SafeboxLimits.fromJson(Map<String, dynamic> j) {
    final ext = _map(j['extensions']);
    return SafeboxLimits(
      maxFileBytes: _int(j['maxFileBytes']),
      blockBytes: _int(j['blockBytes']),
      maxPreviewBytes: _int(j['maxPreviewBytes']),
      maxDepth: _int(j['maxDepth']),
      maxFolders: _int(j['maxFolders']),
      folderNameMax: _int(j['folderNameMax']),
      fileNameMax: _int(j['fileNameMax']),
      extensions: {
        for (final f in SafeboxFamily.values)
          f: (ext[f.name] is List ? (ext[f.name] as List).map((e) => '$e'.toLowerCase()).toList() : <String>[]),
      },
    );
  }

  final int maxFileBytes;
  final int blockBytes;
  final int maxPreviewBytes;
  final int maxDepth;
  final int maxFolders;
  final int folderNameMax;
  final int fileNameMax;
  final Map<SafeboxFamily, List<String>> extensions;

  /// Même règle que le serveur : la première famille qui connaît l'extension,
  /// sinon « documents ».
  SafeboxFamily familyOf(String fileName) {
    final ext = safeboxExtensionOf(fileName);
    for (final f in const [SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.audios]) {
      if (ext.isNotEmpty && (extensions[f] ?? const []).contains(ext)) return f;
    }
    return SafeboxFamily.documents;
  }
}

/// Extension en minuscules, sans le point (même règle que le serveur).
String safeboxExtensionOf(String name) {
  final point = name.lastIndexOf('.');
  if (point <= 0 || point == name.length - 1) return '';
  final ext = name.substring(point + 1).toLowerCase();
  return RegExp(r'^[a-z0-9]{1,10}$').hasMatch(ext) ? ext : '';
}

class SafeboxOverview {
  const SafeboxOverview({required this.quota, required this.rootIds, required this.limits});

  factory SafeboxOverview.fromJson(Map<String, dynamic> j) => SafeboxOverview(
        quota: SafeboxQuota.fromJson(_map(j['quota'])),
        rootIds: {
          for (final r in _list(j['roots']))
            if (SafeboxRoot.fromName(r['root'] as String?) != null)
              SafeboxRoot.fromName(r['root'] as String?)!: _int(r['id']),
        },
        limits: SafeboxLimits.fromJson(_map(j['limits'])),
      );

  final SafeboxQuota quota;
  final Map<SafeboxRoot, int> rootIds;
  final SafeboxLimits limits;
}

class SafeboxFolder {
  const SafeboxFolder({
    required this.id,
    required this.parentId,
    required this.root,
    required this.name,
    required this.depth,
    this.createdAt,
    this.updatedAt,
    this.trashedAt,
    this.purgeAt,
    this.storedBytes,
    this.fileCount,
  });

  factory SafeboxFolder.fromJson(Map<String, dynamic> j) => SafeboxFolder(
        id: _int(j['id']),
        parentId: _intOrNull(j['parentId']),
        root: SafeboxRoot.fromName(j['root'] as String?) ?? SafeboxRoot.documents,
        name: j['name'] as String?,
        depth: _int(j['depth']),
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        trashedAt: _date(j['trashedAt']),
        purgeAt: _date(j['purgeAt']),
        storedBytes: _intOrNull(j['storedBytes']),
        fileCount: _intOrNull(j['files']),
      );

  final int id;
  final int? parentId;
  final SafeboxRoot root;

  /// Nul pour un dossier racine : l'application affiche son nom traduit.
  final String? name;
  final int depth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? trashedAt;
  final DateTime? purgeAt;
  final int? storedBytes;
  final int? fileCount;

  bool get isRoot => parentId == null;
}

/// Détails d'un fichier relevés par le téléphone au dépôt (migration 104) :
/// durée et définition d'une vidéo, pages d'un PDF, titre, artiste et durée
/// d'un audio. Ils décorent la carte d'un fichier partagé, rien de plus.
class SafeboxMeta {
  const SafeboxMeta({
    this.durationMs,
    this.width,
    this.height,
    this.pages,
    this.title,
    this.artist,
    this.codec,
    this.source,
  });

  /// Null quand il n'y a rien d'utile.
  static SafeboxMeta? fromJson(dynamic j) {
    if (j is! Map) return null;
    int? entier(dynamic v) => v is num && v > 0 ? v.toInt() : null;
    String? texte(dynamic v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final m = SafeboxMeta(
      durationMs: entier(j['durationMs']),
      width: entier(j['width']),
      height: entier(j['height']),
      pages: entier(j['pages']),
      title: texte(j['title']),
      artist: texte(j['artist']),
      codec: j['codec'] == 'hevc' || j['codec'] == 'avc' ? j['codec'] as String : null,
      source: texte(j['source']),
    );
    return m.isEmpty ? null : m;
  }

  final int? durationMs;
  final int? width;
  final int? height;
  final int? pages;
  final String? title;
  final String? artist;

  /// Format d'une vidéo : « hevc » (H.265) ou « avc » (H.264).
  final String? codec;

  /// Le dossier du téléphone d'où vient le fichier (« Camera », « WhatsApp
  /// Images »), posé par la sauvegarde automatique (lot 10).
  final String? source;

  bool get isHevc => codec == 'hevc';

  bool get isEmpty =>
      durationMs == null &&
      (width == null || height == null) &&
      pages == null &&
      title == null &&
      artist == null &&
      codec == null &&
      source == null;

  Map<String, dynamic> toJson() => {
        if (durationMs != null) 'durationMs': durationMs,
        if (width != null && height != null) ...{'width': width, 'height': height},
        if (pages != null) 'pages': pages,
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        if (codec != null) 'codec': codec,
        if (source != null) 'source': source,
      };

  /// « 12:47 », « 1:02:03 ».
  String? get durationLabel {
    final ms = durationMs;
    if (ms == null) return null;
    final t = Duration(milliseconds: ms);
    final s = (t.inSeconds % 60).toString().padLeft(2, '0');
    if (t.inHours > 0) return '${t.inHours}:${(t.inMinutes % 60).toString().padLeft(2, '0')}:$s';
    return '${t.inMinutes}:$s';
  }

  /// « 1080p », « 4K », d'après le petit côté (une vidéo verticale reste 1080p).
  String? get definitionLabel {
    final w = width, h = height;
    if (w == null || h == null) return null;
    final c = w < h ? w : h;
    if (c >= 2160) return '4K';
    for (final p in const [1440, 1080, 720, 480, 360]) {
      if (c >= p * 0.95) return '${p}p';
    }
    return '${c}p';
  }
}

/// Ce que sont devenus les partages d'un fichier de mon coffre : le badge
/// « reçu par 3 destinataires sur 4 ».
class SafeboxSent {
  const SafeboxSent({required this.shares, required this.recipients, this.received, this.lastConversationId});

  static SafeboxSent? fromJson(dynamic j) {
    if (j is! Map) return null;
    final shares = _int(j['shares']);
    if (shares <= 0) return null;
    return SafeboxSent(
      shares: shares,
      recipients: _int(j['recipients']),
      received: _intOrNull(j['received']),
      lastConversationId: _intOrNull(j['lastConversationId']),
    );
  }

  /// La discussion du dernier partage (« Famille Ngono · téléchargé par 5
  /// sur 8 ») ; nulle avec un serveur d'avant le lot 9.
  final int? lastConversationId;

  /// Partages actifs (une discussion chacun).
  final int shares;

  /// Membres actuels de ces discussions, moi exclu.
  final int recipients;

  /// Ceux d'entre eux qui l'ont reçu ; null si le serveur ne le sait pas.
  final int? received;

  /// Tout le monde l'a : on peut le supprimer sans priver personne.
  bool get receivedByAll => received != null && recipients > 0 && received! >= recipients;
}

/// Commentaire d'une photo (décision du 18/10/2026) : un texte de 200
/// caractères au plus, un audio de 5 minutes au plus, ou les deux. Privé : il
/// ne part pas avec la photo quand on l'envoie dans une discussion.
class SafeboxNote {
  const SafeboxNote({this.text, this.audio});

  static const int textMax = 200;
  static const int audioMaxSeconds = 5 * 60;

  /// Null quand il n'y a ni texte ni audio.
  static SafeboxNote? fromJson(dynamic j) {
    if (j is! Map) return null;
    final texte = j['text'] is String && (j['text'] as String).trim().isNotEmpty ? j['text'] as String : null;
    final audio = SafeboxNoteAudio.fromJson(j['audio']);
    if (texte == null && audio == null) return null;
    return SafeboxNote(text: texte, audio: audio);
  }

  final String? text;
  final SafeboxNoteAudio? audio;
}

/// L'audio d'un commentaire : un petit objet chiffré avec sa propre clé.
class SafeboxNoteAudio {
  const SafeboxNoteAudio({
    required this.durationMs,
    required this.plainBytes,
    required this.storedBytes,
    required this.url,
    required this.key,
  });

  static SafeboxNoteAudio? fromJson(dynamic j) {
    if (j is! Map || j['url'] is! String || j['key'] is! String) return null;
    return SafeboxNoteAudio(
      durationMs: _int(j['durationMs']),
      plainBytes: _int(j['plainBytes']),
      storedBytes: _int(j['storedBytes']),
      url: j['url'] as String,
      key: base64Decode(j['key'] as String),
    );
  }

  final int durationMs;
  final int plainBytes;
  final int storedBytes;

  /// Adresse signée de lecture, valable une heure.
  final String url;
  final Uint8List key;

  /// « 1:23 ».
  String get durationLabel {
    final t = Duration(milliseconds: durationMs);
    return '${t.inMinutes}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

class SafeboxFile {
  const SafeboxFile({
    required this.id,
    required this.folderId,
    required this.name,
    required this.ext,
    required this.mime,
    required this.family,
    required this.plainBytes,
    required this.storedBytes,
    required this.originalBytes,
    required this.compressed,
    required this.cipherFormat,
    required this.key,
    required this.previewUrl,
    this.createdAt,
    this.updatedAt,
    this.trashedAt,
    this.purgeAt,
    this.folderName,
    this.folderRoot,
    this.meta,
    this.sent,
    this.lost = false,
    this.note,
    this.alsoIn = const [],
    this.quality = SafeboxQuality.original,
  });

  factory SafeboxFile.fromJson(Map<String, dynamic> j) => SafeboxFile(
        id: _int(j['id']),
        folderId: _int(j['folderId']),
        name: '${j['name'] ?? ''}',
        ext: '${j['ext'] ?? ''}',
        mime: j['mime'] as String?,
        family: SafeboxFamily.fromName(j['family'] as String?),
        plainBytes: _int(j['plainBytes']),
        storedBytes: _int(j['storedBytes']),
        originalBytes: _intOrNull(j['originalBytes']),
        compressed: j['compressed'] == true,
        cipherFormat: '${j['cipherFormat'] ?? ''}',
        key: j['key'] is String ? base64Decode(j['key'] as String) : null,
        previewUrl: j['previewUrl'] as String?,
        createdAt: _date(j['createdAt']),
        updatedAt: _date(j['updatedAt']),
        trashedAt: _date(j['trashedAt']),
        purgeAt: _date(j['purgeAt']),
        folderName: j['folderName'] as String?,
        folderRoot: SafeboxRoot.fromName(j['folderRoot'] as String?),
        meta: SafeboxMeta.fromJson(j['meta']),
        sent: SafeboxSent.fromJson(j['sent']),
        lost: j['lost'] == true,
        note: SafeboxNote.fromJson(j['note']),
        alsoIn: _list(j['alsoIn']).map(SafeboxPlace.fromJson).toList(),
        // Un serveur d'avant le 24/10/2026 ne dit que `compressed`.
        quality: j['quality'] is String
            ? SafeboxQuality.fromName(j['quality'] as String)
            : (j['compressed'] == true ? SafeboxQuality.hd : SafeboxQuality.original),
      );

  final int id;
  final int folderId;
  final String name;
  final String ext;
  final String? mime;
  final SafeboxFamily family;

  /// Les autres endroits du coffre où se trouve le même contenu, sans copie
  /// (décision du 24/10/2026) ; vide s'il n'est qu'ici.
  final List<SafeboxPlace> alsoIn;

  /// Le format dans lequel il a été déposé ; Original s'il est tel quel.
  final SafeboxQuality quality;

  /// Taille en clair : celle que l'inscrit retrouvera.
  final int plainBytes;

  /// Ce qui compte dans l'espace (chiffré, aperçu compris).
  final int storedBytes;
  final int? originalBytes;
  final bool compressed;
  final String cipherFormat;

  /// Clé du fichier ; le serveur ne la rend qu'à son propriétaire.
  final Uint8List? key;

  /// Adresse signée de l'aperçu chiffré, valable une heure.
  final String? previewUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? trashedAt;
  final DateTime? purgeAt;

  /// Nom de son dossier, rendu par « Libérer de l'espace » ; nul pour un
  /// dossier racine (nom traduit par l'application).
  final String? folderName;

  /// Racine de son dossier, rendue avec [folderName] ; nulle ailleurs.
  final SafeboxRoot? folderRoot;

  final SafeboxMeta? meta;

  /// Ses partages dans des discussions ; null s'il n'a jamais été envoyé.
  final SafeboxSent? sent;

  /// Contenu introuvable chez l'hébergeur au dernier contrôle : ne se
  /// télécharge plus, ne se récupère pas.
  final bool lost;

  /// Commentaire privé d'une photo ; null s'il n'y en a pas.
  final SafeboxNote? note;
}

class SafeboxFolderPage {
  const SafeboxFolderPage({
    required this.folder,
    required this.breadcrumbs,
    required this.folders,
    required this.files,
    required this.nextCursor,
  });

  factory SafeboxFolderPage.fromJson(Map<String, dynamic> j) => SafeboxFolderPage(
        folder: SafeboxFolder.fromJson(_map(j['folder'])),
        breadcrumbs: _list(j['breadcrumbs']).map(SafeboxFolder.fromJson).toList(),
        folders: _list(j['folders']).map(SafeboxFolder.fromJson).toList(),
        files: _list(j['files']).map(SafeboxFile.fromJson).toList(),
        nextCursor: _intOrNull(j['nextCursor']),
      );

  final SafeboxFolder folder;
  final List<SafeboxFolder> breadcrumbs;
  final List<SafeboxFolder> folders;
  final List<SafeboxFile> files;
  final int? nextCursor;
}

/// Un album de l'accueil (`GET /api/safebox/albums/recent`) : son nombre de
/// fichiers et ses quatre couvertures, photos et vidéos d'abord.
class SafeboxRecentAlbum {
  const SafeboxRecentAlbum({required this.folder, required this.fileCount, required this.cover, this.lastAddedAt});

  factory SafeboxRecentAlbum.fromJson(Map<String, dynamic> j) => SafeboxRecentAlbum(
        folder: SafeboxFolder.fromJson(j),
        fileCount: _int(j['fileCount']),
        lastAddedAt: _date(j['lastAddedAt']),
        cover: _list(j['cover']).map(SafeboxFile.fromJson).toList(),
      );

  static List<SafeboxRecentAlbum> listFromJson(Map<String, dynamic> j) =>
      _list(j['albums']).map(SafeboxRecentAlbum.fromJson).toList();

  final SafeboxFolder folder;
  final int fileCount;
  final DateTime? lastAddedAt;
  final List<SafeboxFile> cover;
}

/// Adresse signée d'un bloc (ou de l'aperçu, `n == 0`).
class SafeboxSignedBlock {
  const SafeboxSignedBlock({required this.n, required this.size, required this.url});

  factory SafeboxSignedBlock.fromJson(Map<String, dynamic> j) =>
      SafeboxSignedBlock(n: _int(j['n']), size: _int(j['size']), url: '${j['url']}');

  final int n;
  final int size;
  final String url;
}

class SafeboxUploadTicket {
  const SafeboxUploadTicket({
    required this.fileId,
    required this.blockSize,
    required this.blockCount,
    required this.size,
    required this.blocks,
    required this.preview,
    required this.urlTtlSeconds,
  });

  factory SafeboxUploadTicket.fromJson(Map<String, dynamic> j) => SafeboxUploadTicket(
        fileId: _int(j['fileId']),
        blockSize: _int(j['blockSize']),
        blockCount: _int(j['blockCount']),
        size: _int(j['size']),
        blocks: _list(j['blocks']).map(SafeboxSignedBlock.fromJson).toList(),
        preview: j['preview'] is Map ? SafeboxSignedBlock.fromJson(_map(j['preview'])) : null,
        urlTtlSeconds: _int(j['urlTtlSeconds']),
      );

  final int fileId;
  final int blockSize;
  final int blockCount;
  final int size;
  final List<SafeboxSignedBlock> blocks;
  final SafeboxSignedBlock? preview;
  final int urlTtlSeconds;
}

class SafeboxUploadStatus {
  const SafeboxUploadStatus({
    required this.blockCount,
    required this.received,
    required this.missing,
    required this.previewMissing,
  });

  factory SafeboxUploadStatus.fromJson(Map<String, dynamic> j) => SafeboxUploadStatus(
        blockCount: _int(j['blockCount']),
        received: (j['received'] as List? ?? const []).map(_int).toList(),
        missing: (j['missing'] as List? ?? const []).map(_int).toList(),
        previewMissing: j['previewMissing'] == true,
      );

  final int blockCount;
  final List<int> received;
  final List<int> missing;
  final bool previewMissing;
}

class SafeboxDownloadPlan {
  const SafeboxDownloadPlan({
    required this.file,
    required this.key,
    required this.blockSize,
    required this.blockCount,
    required this.blocks,
  });

  factory SafeboxDownloadPlan.fromJson(Map<String, dynamic> j) => SafeboxDownloadPlan(
        file: SafeboxFile.fromJson(_map(j['file'])),
        key: base64Decode('${j['key']}'),
        blockSize: _int(j['blockSize']),
        blockCount: _int(j['blockCount']),
        blocks: _list(j['blocks']).map(SafeboxSignedBlock.fromJson).toList(),
      );

  final SafeboxFile file;
  final Uint8List key;
  final int blockSize;
  final int blockCount;
  final List<SafeboxSignedBlock> blocks;
}

class SafeboxTrash {
  const SafeboxTrash({required this.trashDays, required this.folders, required this.files});

  factory SafeboxTrash.fromJson(Map<String, dynamic> j) => SafeboxTrash(
        trashDays: _int(j['trashDays']),
        folders: _list(j['folders']).map(SafeboxFolder.fromJson).toList(),
        files: _list(j['files']).map(SafeboxFile.fromJson).toList(),
      );

  final int trashDays;
  final List<SafeboxFolder> folders;
  final List<SafeboxFile> files;

  bool get isEmpty => folders.isEmpty && files.isEmpty;
}

/// Partage créé (`POST /api/safebox/shares`).
/// Éléments d'un partage en lot au plus (serveur : SHARE_MAX_ITEMS).
const int kSafeboxShareMaxItems = 500;

/// Un partage, d'un fichier ou d'un lot (lot 9 : un album ou une sélection,
/// une seule carte).
enum SafeboxShareKind {
  file,
  batch;

  static SafeboxShareKind fromName(String? name) => name == 'batch' ? batch : file;
}

/// Nombre d'éléments par type d'un lot (« 35 photos, 6 vidéos, 1 document »),
/// dans l'ordre des types ; vide pour un fichier seul.
Map<SafeboxFamily, int> safeboxFamilyCounts(dynamic j) {
  if (j is! Map) return const {};
  return {
    for (final f in SafeboxFamily.values)
      if (_int(j[f.name]) > 0) f: _int(j[f.name]),
  };
}

/// Identifiant local d'un élément reçu par un partage : négatif, pour ne
/// jamais croiser celui d'un fichier de mon coffre dans les caches ; celui
/// d'un fichier seul (élément 0) reste celui de son partage.
int safeboxSharedLocalId(int shareId, int itemId) => itemId == 0 ? -shareId : -((1 << 40) + itemId);

/// Ce que rend la création d'un partage (`POST /api/safebox/shares`).
class SafeboxShareCreated {
  const SafeboxShareCreated({
    required this.shareId,
    required this.name,
    required this.mime,
    required this.family,
    required this.plainBytes,
    this.kind = SafeboxShareKind.file,
    this.count = 1,
    this.families = const {},
    this.meta,
    this.cover = const [],
  });

  factory SafeboxShareCreated.fromJson(Map<String, dynamic> j) => SafeboxShareCreated(
        shareId: _int(j['shareId']),
        name: '${j['name'] ?? ''}',
        mime: j['mime'] as String?,
        family: SafeboxFamily.fromName(j['family'] as String?),
        plainBytes: _int(j['plainBytes']),
        kind: SafeboxShareKind.fromName(j['kind'] as String?),
        count: j['count'] == null ? 1 : _int(j['count']),
        families: safeboxFamilyCounts(j['families']),
        meta: SafeboxMeta.fromJson(j['meta']),
        cover: [for (final v in (j['cover'] is List ? j['cover'] as List : const [])) _int(v)],
      );

  final int shareId;
  final SafeboxShareKind kind;

  /// Nom du fichier, ou titre du lot.
  final String name;
  final String? mime;

  /// Type du fichier ; pour un lot, le plus nombreux.
  final SafeboxFamily family;

  /// Taille en clair ; pour un lot, la somme.
  final int plainBytes;
  final int count;
  final Map<SafeboxFamily, int> families;
  final SafeboxMeta? meta;

  /// Mes fichiers des quatre premiers éléments : la mosaïque floue du message.
  final List<int> cover;
}

/// Qui a envoyé un partage.
class SafeboxShareSender {
  const SafeboxShareSender({required this.id, this.name, this.avatarUrl});

  static SafeboxShareSender? fromJson(dynamic j) {
    if (j is! Map) return null;
    return SafeboxShareSender(
      id: _int(j['id']),
      name: j['name'] is String && (j['name'] as String).isNotEmpty ? j['name'] as String : null,
      avatarUrl: j['avatarUrl'] as String?,
    );
  }

  final int id;
  final String? name;
  final String? avatarUrl;
}

/// Résumé du suivi, pour l'expéditeur : membres de la discussion (lui exclu),
/// ceux qui ont téléchargé, ceux qui ont gardé le contenu dans leur coffre.
class SafeboxShareTracking {
  const SafeboxShareTracking({required this.members, required this.downloaded, required this.saved});

  static SafeboxShareTracking? fromJson(dynamic j) {
    if (j is! Map) return null;
    return SafeboxShareTracking(
      members: _int(j['members']),
      downloaded: _int(j['downloaded']),
      saved: _int(j['saved']),
    );
  }

  final int members;
  final int downloaded;
  final int saved;

  /// Ceux qui l'ont reçu, d'une façon ou de l'autre.
  int get received => downloaded + saved;
  bool get receivedByAll => members > 0 && received >= members;
}

/// Un élément d'un partage, tel que l'écran ouvert depuis la carte l'affiche
/// (`GET /api/safebox/shares/:id/items`) ; l'élément 0 est le fichier d'un
/// partage simple.
class SafeboxShareItem {
  const SafeboxShareItem({
    required this.shareId,
    required this.id,
    required this.position,
    required this.name,
    required this.ext,
    required this.mime,
    required this.family,
    required this.plainBytes,
    required this.available,
    this.storedBytes,
    this.quality = SafeboxQuality.original,
    this.meta,
    this.lost = false,
    this.key,
    this.previewUrl,
    this.savedFileId,
  });

  factory SafeboxShareItem.fromJson(int shareId, Map<String, dynamic> j) => SafeboxShareItem(
        shareId: shareId,
        id: _int(j['id']),
        position: _int(j['position']),
        name: '${j['name'] ?? ''}',
        ext: '${j['ext'] ?? ''}',
        mime: j['mime'] as String?,
        family: SafeboxFamily.fromName(j['family'] as String?),
        plainBytes: _int(j['plainBytes']),
        available: j['available'] == true,
        storedBytes: _intOrNull(j['storedBytes']),
        quality: SafeboxQuality.fromName(j['quality'] as String?),
        meta: SafeboxMeta.fromJson(j['meta']),
        lost: j['lost'] == true,
        key: j['key'] is String ? base64Decode(j['key'] as String) : null,
        previewUrl: j['previewUrl'] as String?,
        savedFileId: _intOrNull(j['savedFileId']),
      );

  final int shareId;
  final int id;
  final int position;
  final String name;
  final String ext;
  final String? mime;
  final SafeboxFamily family;
  final int plainBytes;

  /// Faux quand l'expéditeur a supprimé ce fichier ou retiré le partage.
  final bool available;
  final int? storedBytes;
  final SafeboxQuality quality;
  final SafeboxMeta? meta;
  final bool lost;
  final Uint8List? key;
  final String? previewUrl;

  /// Le même contenu, déjà dans mon coffre.
  final int? savedFileId;

  int get localId => safeboxSharedLocalId(shareId, id);

  /// Vu comme un fichier, pour l'aperçu, la grille et le téléchargement.
  SafeboxFile asFile() => SafeboxFile(
        id: localId,
        folderId: 0,
        name: name,
        ext: ext.isNotEmpty ? ext : safeboxExtensionOf(name),
        mime: mime,
        family: family,
        plainBytes: plainBytes,
        storedBytes: storedBytes ?? 0,
        originalBytes: null,
        compressed: quality != SafeboxQuality.original,
        cipherFormat: '',
        key: key,
        previewUrl: previewUrl,
        meta: meta,
        lost: lost,
        quality: quality,
      );
}

/// Une page d'éléments d'un partage.
class SafeboxShareItemsPage {
  const SafeboxShareItemsPage({required this.items, this.nextCursor});

  factory SafeboxShareItemsPage.fromJson(int shareId, Map<String, dynamic> j) => SafeboxShareItemsPage(
        items: _list(j['items']).map((e) => SafeboxShareItem.fromJson(shareId, e)).toList(),
        nextCursor: _intOrNull(j['nextCursor']),
      );

  final List<SafeboxShareItem> items;
  final int? nextCursor;
}

/// Un membre dans le suivi de l'expéditeur.
enum SafeboxRecipientState {
  saved,
  downloaded,
  pending;

  static SafeboxRecipientState fromName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => pending);
}

class SafeboxShareMember {
  const SafeboxShareMember({required this.alanyaId, required this.state, this.name, this.avatarUrl, this.at});

  factory SafeboxShareMember.fromJson(Map<String, dynamic> j) => SafeboxShareMember(
        alanyaId: _int(j['alanyaID']),
        name: j['name'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        state: SafeboxRecipientState.fromName(j['state'] as String?),
        at: _date(j['at']),
      );

  final int alanyaId;
  final String? name;
  final String? avatarUrl;
  final SafeboxRecipientState state;

  /// Première réception (téléchargement ou « Garder »).
  final DateTime? at;
}

/// Le suivi chez l'expéditeur (`GET /api/safebox/shares/:id/recipients`).
class SafeboxShareRecipients {
  const SafeboxShareRecipients({required this.members, required this.tracking});

  factory SafeboxShareRecipients.fromJson(Map<String, dynamic> j) => SafeboxShareRecipients(
        members: _list(j['members']).map(SafeboxShareMember.fromJson).toList(),
        tracking: SafeboxShareTracking.fromJson(j['tracking']) ??
            const SafeboxShareTracking(members: 0, downloaded: 0, saved: 0),
      );

  final List<SafeboxShareMember> members;
  final SafeboxShareTracking tracking;
}

/// La carte d'un partage (`GET /api/safebox/shares/:id`), et une ligne de
/// l'onglet « Reçus » (`GET /api/safebox/shares/received`).
class SafeboxShareInfo {
  const SafeboxShareInfo({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.name,
    required this.mime,
    required this.family,
    required this.plainBytes,
    required this.available,
    required this.isSender,
    this.kind = SafeboxShareKind.file,
    this.count = 1,
    this.families = const {},
    this.storedBytes,
    this.quality = SafeboxQuality.original,
    this.key,
    this.previewUrl,
    this.downloadsLeft,
    this.savedFileId,
    this.meta,
    this.lost = false,
    this.removedByModeration = false,
    this.revokedBySender = false,
    this.sender,
    this.tracking,
    this.cover = const [],
    this.availableCount,
    this.savedCount,
    this.fileIds = const [],
    this.createdAt,
    this.receivedAt,
  });

  factory SafeboxShareInfo.fromJson(Map<String, dynamic> j) {
    final id = _int(j['id']);
    final couverture = j['cover'];
    return SafeboxShareInfo(
      id: id,
      conversationId: _int(j['conversationId']),
      senderId: _int(j['senderId']),
      name: '${j['name'] ?? ''}',
      mime: j['mime'] as String?,
      family: SafeboxFamily.fromName(j['family'] as String?),
      plainBytes: _int(j['plainBytes']),
      available: j['available'] == true,
      isSender: j['isSender'] == true,
      kind: SafeboxShareKind.fromName(j['kind'] as String?),
      count: j['count'] == null ? 1 : _int(j['count']),
      families: safeboxFamilyCounts(j['families']),
      storedBytes: _intOrNull(j['storedBytes']),
      quality: SafeboxQuality.fromName(j['quality'] as String?),
      key: j['key'] is String ? base64Decode(j['key'] as String) : null,
      previewUrl: j['previewUrl'] as String?,
      downloadsLeft: _intOrNull(j['downloadsLeft']),
      savedFileId: _intOrNull(j['savedFileId']),
      meta: SafeboxMeta.fromJson(j['meta']),
      lost: j['lost'] == true,
      removedByModeration: j['removedByModeration'] == true,
      revokedBySender: j['revokedBySender'] == true,
      sender: SafeboxShareSender.fromJson(j['sender']),
      tracking: SafeboxShareTracking.fromJson(j['tracking']),
      // Une liste pour la carte d'un lot, un seul élément pour une ligne de « Reçus ».
      cover: couverture is Map
          ? [SafeboxShareItem.fromJson(id, Map<String, dynamic>.from(couverture))]
          : _list(couverture).map((e) => SafeboxShareItem.fromJson(id, e)).toList(),
      availableCount: _intOrNull(j['availableCount']),
      savedCount: _intOrNull(j['savedCount']),
      fileIds: [for (final v in (j['fileIds'] is List ? j['fileIds'] as List : const [])) _int(v)],
      createdAt: _date(j['createdAt']),
      receivedAt: _date(j['receivedAt']),
    );
  }

  final int id;
  final int conversationId;
  final int senderId;
  final SafeboxShareKind kind;

  /// Nom du fichier, ou titre du lot.
  final String name;
  final String? mime;
  final SafeboxFamily family;
  final int plainBytes;
  final int count;
  final Map<SafeboxFamily, int> families;

  /// Faux quand l'expéditeur a retiré le fichier (ou tout le lot) de son
  /// coffre, ou le partage.
  final bool available;
  final bool isSender;
  final int? storedBytes;
  final SafeboxQuality quality;
  final Uint8List? key;
  final String? previewUrl;

  /// Téléchargements restants aujourd'hui ; nul pour l'expéditeur.
  final int? downloadsLeft;

  /// Le même fichier, déjà dans mon coffre.
  final int? savedFileId;

  final SafeboxMeta? meta;

  /// Contenu perdu chez l'hébergeur : la carte le dit, rien ne se télécharge.
  final bool lost;

  /// Retiré par la modération d'Alanya.
  final bool removedByModeration;

  /// Retiré par l'expéditeur (« Retirer le partage »).
  final bool revokedBySender;

  final SafeboxShareSender? sender;

  /// Pour l'expéditeur seul : « téléchargé par 2 sur 7 ».
  final SafeboxShareTracking? tracking;

  /// Lot : les quatre premiers éléments disponibles (la mosaïque) ; ligne de
  /// « Reçus » : le premier.
  final List<SafeboxShareItem> cover;

  /// Lot : éléments encore disponibles, et ceux déjà dans mon coffre.
  final int? availableCount;
  final int? savedCount;

  /// Pour l'expéditeur : ses fichiers encore disponibles (« Envoyer ailleurs »).
  final List<int> fileIds;
  final DateTime? createdAt;

  /// Ligne de « Reçus » : quand je l'ai téléchargé ou gardé la première fois.
  final DateTime? receivedAt;

  bool get isBatch => kind == SafeboxShareKind.batch;

  /// Identifiant local d'un fichier reçu : négatif, pour ne jamais croiser
  /// celui d'un fichier de mon coffre dans les caches.
  int get localId => -id;

  /// Un fichier seul vu comme son unique élément.
  SafeboxShareItem asItem() => SafeboxShareItem(
        shareId: id,
        id: 0,
        position: 0,
        name: name,
        ext: safeboxExtensionOf(name),
        mime: mime,
        family: family,
        plainBytes: plainBytes,
        available: available,
        storedBytes: storedBytes,
        quality: quality,
        meta: meta,
        lost: lost,
        key: key,
        previewUrl: previewUrl,
        savedFileId: savedFileId,
      );

  /// Vu comme un fichier, pour l'aperçu et le téléchargement.
  SafeboxFile asFile() => asItem().asFile();
}

/// Une page de l'onglet « Reçus ».
class SafeboxReceivedPage {
  const SafeboxReceivedPage({required this.shares, this.nextCursor});

  factory SafeboxReceivedPage.fromJson(Map<String, dynamic> j) => SafeboxReceivedPage(
        shares: _list(j['shares']).map(SafeboxShareInfo.fromJson).toList(),
        nextCursor: _intOrNull(j['nextCursor']),
      );

  final List<SafeboxShareInfo> shares;
  final int? nextCursor;
}
