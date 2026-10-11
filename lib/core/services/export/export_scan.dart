import 'dart:io';

import 'package:path/path.dart' as p;

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../utils/audio_message_kind.dart';
import '../../utils/sticker_payload.dart';
import '../media_expiry_policy.dart';
import 'export_manifest.dart';

/// Résout le fichier local d'un **sticker**, ou `null` s'il n'est pas là.
///
/// Un sticker ne renseigne pas `localMediaPath` : son fichier vit dans le cache
/// dédié (`StickerCache`), indexé par URL. Le scan ne peut donc pas le lire
/// comme un média ordinaire, et il ne doit surtout pas le télécharger — d'où
/// cette injection : la couche export ne connaît ni le cache ni le réseau, et
/// reste testable sans l'un ni l'autre. Un résolveur absent (appels historiques,
/// tests) déclare le sticker manquant plutôt que de l'omettre en silence.
typedef StickerFileResolver = Future<File?> Function(LocalMessage msg);

/// Un média retenu pour l'archive, avec son fichier et sa place dedans.
class ScannedMedia {
  final LocalMessage message;
  final String? senderName;
  final File file;

  /// Poids mesuré sur le disque. Jamais lu depuis `mediaSize` : la colonne est
  /// nulle pour tout média antérieur à la collecte des tailles, et la sommer
  /// ferait annoncer un poids sous-évalué.
  final int bytes;

  /// Chemin dans l'archive, dossier compris.
  final String archivePath;

  const ScannedMedia({
    required this.message,
    required this.senderName,
    required this.file,
    required this.bytes,
    required this.archivePath,
  });
}

/// Résultat d'un scan : ce qui partira dans l'archive, et ce qui manque.
class ExportScanResult {
  final List<ScannedMedia> present;
  final List<ExportMissing> missing;

  /// Poids total réel de ce qui entrera dans l'archive.
  final int bytes;

  /// Tailles rattrapées en base pendant le scan — utile aux tests et aux
  /// journaux, l'écriture ayant déjà eu lieu.
  final int backfilled;

  /// Poids réel des manquants récupérables, quand le serveur l'a annoncé.
  ///
  /// `null` = le serveur n'a pas répondu. L'écran doit alors parler
  /// d'estimation, pas de promesse.
  final int? recoverableBytes;

  /// Le tri entre récupérable et perdu vient-il du serveur ?
  ///
  /// Quand il vient du client seul, il repose sur une durée de rétention
  /// **déduite** — et, tant qu'elle n'a jamais été apprise, le client croit
  /// tout récupérable. Le savoir change ce que l'écran a le droit de promettre.
  final bool verifiedByServer;

  const ExportScanResult({
    required this.present,
    required this.missing,
    required this.bytes,
    required this.backfilled,
    this.recoverableBytes,
    this.verifiedByServer = false,
  });

  /// Rejoue le tri à partir de la réponse du serveur.
  ///
  /// Ce que le serveur ne liste pas comme disponible est perdu, quelle que soit
  /// ce que le client croyait. C'est le seul verdict qui ne se trompe pas :
  /// il regarde le fichier, pas une date.
  ExportScanResult withServerVerdict({
    required Set<int> available,
    required Map<int, int> sizes,
  }) {
    final rescored = missing
        .map((m) => (available.contains(m.msgID) || m.isSticker)
            ? m
            : ExportMissing(
                msgID: m.msgID,
                clientId: m.clientId,
                sentAt: m.sentAt,
                reason: MissingReason.expired,
                type: m.type,
              ))
        .toList();

    var total = 0;
    for (final id in available) {
      total += sizes[id] ?? 0;
    }

    return ExportScanResult(
      present: present,
      missing: rescored,
      bytes: bytes,
      backfilled: backfilled,
      recoverableBytes: total,
      verifiedByServer: true,
    );
  }

  /// Manquants que le serveur peut encore rendre, si l'inscrit accepte la
  /// dépense réseau.
  List<ExportMissing> get recoverable =>
      missing.where((m) => m.recoverable).toList();

  /// Manquants définitivement perdus : purgés du serveur, absents d'ici.
  List<ExportMissing> get lost =>
      missing.where((m) => !m.recoverable).toList();
}

/// Inventaire d'une période avant assemblage.
///
/// Le scan répond à la seule question que la feuille d'export doit poser avant
/// que l'inscrit ne s'engage : **qu'est-ce que je tiens réellement, et
/// combien ça pèse ?**
///
/// Il visite le disque, ce qui a trois effets d'un seul passage :
///
/// 1. Il mesure — la base ne sait pas répondre pour les médias anciens.
/// 2. Il **rattrape** les tailles manquantes en base, si bien que la grille
///    « Mes médias », son total et son tri par poids se corrigent aussi.
/// 3. Il classe les absents, en distinguant ce qui est récupérable de ce qui
///    est perdu — sans quoi l'écran promettrait un téléchargement voué au
///    `410`.
class ExportScanner {
  final ChatDao dao;

  /// Résout le fichier d'un sticker (cache dédié). `null` = pas de résolveur :
  /// un sticker sera déclaré manquant, jamais omis en silence.
  final StickerFileResolver? stickerFile;

  const ExportScanner(this.dao, {this.stickerFile});

  /// Dossier d'archive par famille de média. Reprend la nomenclature que
  /// `AlanyaMediaExportService` pose déjà dans `Download/Alanya/` : un inscrit
  /// qui a exporté des médias un par un retrouve la même organisation dans le
  /// zip. Seul `Alanya Audio` est nouveau.
  static String folderForType(int type, {String? mediaName}) {
    switch (type) {
      case 1:
        return 'Alanya Images';
      case 2:
        return 'Alanya Videos';
      case 3:
        // Un vocal enregistré et un morceau importé sont tous deux des
        // messages de type 3 ; les mélanger dans un même dossier rendrait la
        // musique introuvable au milieu des mémos.
        return audioKindFromName(mediaName) == AudioMessageKind.music
            ? 'Alanya Musique'
            : 'Alanya Vocaux';
      case kStickerMessageType:
        // Les stickers ont leur propre dossier : ils ne sont pas des photos,
        // et les noyer dans « Alanya Images » les rendrait introuvables.
        return 'Alanya Stickers';
      default:
        return 'Alanya Documents';
    }
  }

  Future<ExportScanResult> scan(
    int myId, {
    bool? mineOnly,
    int? conversationID,
    DateTime? from,
    DateTime? until,
    List<int> types = kExportMediaTypes,
    DateTime? now,
  }) async {
    final rows = await dao.mediaForExport(
      myId,
      mineOnly: mineOnly,
      conversationID: conversationID,
      from: from,
      until: until,
      types: types,
    );

    final present = <ScannedMedia>[];
    final missing = <ExportMissing>[];
    var total = 0;
    var backfilled = 0;
    // Compteur par dossier : deux photos du même jour, du même expéditeur,
    // porteraient sinon le même nom et la seconde écraserait la première.
    final counters = <String, int>{};

    for (final row in rows) {
      final msg = row.message;
      final isSticker = msg.type == kStickerMessageType;

      // Un sticker n'a pas de `localMediaPath` : son fichier vit dans le cache
      // dédié, résolu par injection. On ne le télécharge jamais ici — un export
      // qui ferait du réseau sans que l'inscrit l'ait accepté serait une faute.
      final File? file;
      if (isSticker) {
        file = stickerFile == null ? null : await stickerFile!(msg);
      } else {
        final path = msg.localMediaPath;
        file = path == null ? null : File(path);
      }

      if (file == null) {
        missing.add(_missing(msg, MissingReason.neverDownloaded, now));
        continue;
      }

      final stat = FileStat.statSync(file.path);
      if (stat.type == FileSystemEntityType.notFound) {
        // La base annonçait un fichier que le disque n'a plus : effacé hors
        // de l'app. On la désynchronise, sinon la grille continuerait
        // d'afficher un média qui n'existe pas. Un sticker n'a pas de
        // `localMediaPath` à effacer — et son `msgID` peut valoir 0.
        if (!isSticker) await dao.clearLocalMediaPath(msg.msgID);
        missing.add(_missing(msg, MissingReason.fileGone, now));
        continue;
      }

      if (msg.mediaSize == null || msg.mediaSize! <= 0) {
        await dao.setMediaSize(msg.clientId, stat.size);
        backfilled++;
      }

      final folder = folderForType(msg.type, mediaName: msg.mediaName);
      final index = (counters[folder] ?? 0) + 1;
      counters[folder] = index;

      present.add(ScannedMedia(
        message: msg,
        senderName: row.senderName,
        file: file,
        bytes: stat.size,
        archivePath: p.join(
          folder,
          _archiveFileName(msg, row.senderName, index, file.path),
        ),
      ));
      total += stat.size;
    }

    return ExportScanResult(
      present: present,
      missing: missing,
      bytes: total,
      backfilled: backfilled,
    );
  }

  /// Un manquant est récupérable tant que sa partition serveur n'a pas été
  /// purgée. La question se tranche **sans requête** : l'URL porte le jour de
  /// dépôt, et [MediaExpiryPolicy] connaît la rétention annoncée par le
  /// serveur.
  ExportMissing _missing(LocalMessage msg, MissingReason reason, DateTime? now) {
    final expired = MediaExpiryPolicy.isExpired(msg.mediaUrl, now: now);
    return ExportMissing(
      msgID: msg.msgID,
      clientId: msg.clientId,
      sentAt: msg.sendAt,
      reason: expired ? MissingReason.expired : reason,
      type: msg.type,
    );
  }

  /// `2026-03-14_ama-nguema_0001.jpg` — daté, attribué, numéroté.
  ///
  /// Un nom d'origine seul (`IMG_2231.jpg`) ne dit rien un an plus tard, et
  /// deux appareils produisent régulièrement le même. Le nom d'origine n'est
  /// pas perdu pour autant : il voyage dans le manifeste.
  static String _archiveFileName(
    LocalMessage msg,
    String? senderName,
    int index,
    String localPath,
  ) {
    final date = msg.sendAt;
    final day = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final who = _slug(senderName ?? 'alanya');
    final n = index.toString().padLeft(4, '0');
    // Le nom d'origine puis le chemin local ; à défaut l'URL serveur — un
    // sticker n'a ni l'un ni l'autre de nommé, mais son URL se termine par
    // `.webp`, ce qui vaut mieux que le `bin` générique.
    final ext = _extensionOf(msg.mediaName) ??
        _extensionOf(localPath) ??
        _extensionOf(msg.mediaUrl) ??
        'bin';
    return '${day}_${who}_$n.$ext';
  }

  /// Réduit un pseudo à ce qui traverse sans dommage un système de fichiers,
  /// une clé USB et un ordinateur d'une autre langue.
  static String _slug(String value) {
    const accents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyy';
    final buffer = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      final at = accents.indexOf(c);
      final normalized = at >= 0 ? plain[at] : c;
      if (RegExp(r'[a-z0-9]').hasMatch(normalized)) {
        buffer.write(normalized);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith('-')) {
        buffer.write('-');
      }
    }
    final slug = buffer.toString().replaceAll(RegExp(r'-+$'), '');
    if (slug.isEmpty) return 'alanya';
    return slug.length > 24 ? slug.substring(0, 24) : slug;
  }

  static String? _extensionOf(String? name) {
    if (name == null || name.isEmpty) return null;
    final base = name.split('/').last.split('?').first;
    final dot = base.lastIndexOf('.');
    if (dot < 0 || dot >= base.length - 1) return null;
    final ext = base.substring(dot + 1).toLowerCase().trim();
    return RegExp(r'^[a-z0-9]{1,6}$').hasMatch(ext) ? ext : null;
  }
}
