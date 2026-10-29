import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../../utils/sticker_payload.dart';
import 'export_manifest.dart';
import 'export_scan.dart';

/// Avancement de l'assemblage, pour la notification de progression.
class ExportProgress {
  final int done;
  final int total;
  final int bytesWritten;

  const ExportProgress(this.done, this.total, this.bytesWritten);

  double get ratio => total == 0 ? 1 : done / total;
}

/// Assemble l'archive d'une période à partir des fichiers déjà sur l'appareil.
///
/// ── Pourquoi il ne compresse pas ──
///
/// Photos JPEG, vidéos MP4, vocaux M4A et PDF sont **déjà compressés**. Les
/// repasser dans l'algorithme *deflate* du zip coûte beaucoup de temps
/// processeur et de batterie pour un gain de taille voisin de zéro — parfois
/// négatif. Les médias sont donc écrits en mode **stocké**, et seuls le
/// manifeste et l'index HTML sont compressés. Le zip ne sert pas à réduire, il
/// sert à tenir ensemble.
///
/// ── Pourquoi il ne recopie rien ──
///
/// Les fichiers sont lus à leur emplacement d'origine et écrits au fil de
/// l'eau dans l'archive. Une mise en scène dans un dossier temporaire
/// doublerait l'espace disque nécessaire, ce qui, sur un téléphone qu'on
/// cherche précisément à soulager, serait une faute.
class ExportZipBuilder {
  /// Marge exigée au-dessus de la taille attendue : un disque rempli à ras
  /// bord par notre propre archive laisserait l'appareil dans un état pire que
  /// celui d'où l'on partait.
  static const int freeSpaceMarginBytes = 64 * 1024 * 1024;

  /// Écrit l'archive dans [destination] et retourne le manifeste effectivement
  /// produit — celui-ci peut différer du scan si un fichier a disparu entre le
  /// scan et l'assemblage.
  ///
  /// [onProgress] est appelé après chaque fichier ; [isCancelled] est consulté
  /// entre deux fichiers, jamais au milieu de l'un d'eux.
  Future<ExportManifest> build({
    required File destination,
    required ExportScanResult scan,
    required int alanyaID,
    DateTime? periodFrom,
    DateTime? periodTo,
    int? conversationID,
    String? conversationName,
    int? retentionDaysKnown,
    /// Espace libre sur le volume de destination, mesuré par l'appelant.
    /// `dart:io` n'expose pas `statfs` : la mesure est une affaire de
    /// plateforme, la décision est ici. Absent = contrôle non effectué.
    int? availableBytes,
    void Function(ExportProgress)? onProgress,
    bool Function()? isCancelled,
    String Function(ExportManifest)? indexHtmlBuilder,
  }) async {
    if (availableBytes != null &&
        availableBytes < scan.bytes + freeSpaceMarginBytes) {
      throw ExportInsufficientSpace(
        needed: scan.bytes + freeSpaceMarginBytes,
        available: availableBytes,
      );
    }
    await destination.parent.create(recursive: true);

    final encoder = ZipFileEncoder();
    encoder.create(destination.path);

    final items = <ExportItem>[];
    final missing = List<ExportMissing>.from(scan.missing);
    var written = 0;

    try {
      for (var i = 0; i < scan.present.length; i++) {
        if (isCancelled?.call() ?? false) {
          throw const ExportCancelled();
        }
        final media = scan.present[i];

        // Le fichier a pu disparaître entre le scan et ici. On le déclare
        // manquant plutôt que d'interrompre tout l'export pour un élément.
        if (!media.file.existsSync()) {
          missing.add(ExportMissing(
            msgID: media.message.msgID,
            clientId: media.message.clientId,
            sentAt: media.message.sendAt,
            reason: MissingReason.fileGone,
            type: media.message.type,
          ));
          continue;
        }

        final digest = await sha256.bind(media.file.openRead()).first;
        await _addStored(encoder, media.file, media.archivePath);

        // Un sticker ne porte pas de fichier nommé : l'archive emporte sa
        // **référence** (pack, identifiant, emoji) recalculée depuis le JSON du
        // message — jamais le JSON brut. Illisible, elle reste simplement
        // absente sans rendre l'entrée inexploitable.
        final StickerPayload? sticker =
            media.message.type == kStickerMessageType
                ? StickerPayload.tryParse(media.message.content)
                : null;

        items.add(ExportItem(
          msgID: media.message.msgID,
          clientId: media.message.clientId,
          conversationID: media.message.conversationID,
          senderID: media.message.senderID,
          senderName: media.senderName,
          isMine: media.message.senderID == alanyaID,
          type: media.message.type,
          stickerPack:
              (sticker?.pack.isNotEmpty ?? false) ? sticker!.pack : null,
          stickerSid: sticker?.sid,
          stickerEmoji:
              (sticker?.emoji.isNotEmpty ?? false) ? sticker!.emoji : null,
          sentAt: media.message.sendAt,
          path: media.archivePath,
          originalName: media.message.mediaName,
          bytes: media.bytes,
          sha256: digest.toString(),
          mediaUrl: media.message.mediaUrl ?? '',
        ));

        written += media.bytes;
        onProgress?.call(
          ExportProgress(i + 1, scan.present.length, written),
        );
      }

      final manifest = ExportManifest(
        alanyaID: alanyaID,
        generatedAt: DateTime.now().toUtc(),
        periodFrom: periodFrom,
        periodTo: periodTo,
        conversationID: conversationID,
        conversationName: conversationName,
        retentionDaysKnown: retentionDaysKnown,
        items: items,
        missing: missing,
      );

      // Le manifeste et l'index se compressent, eux : ce sont du texte, et le
      // gain y est réel.
      _addText(encoder, 'manifest.json', manifest.encode());
      if (indexHtmlBuilder != null) {
        _addText(encoder, 'index.html', indexHtmlBuilder(manifest));
      }

      await encoder.close();
      return manifest;
    } catch (_) {
      // Une archive à moitié écrite n'est bonne à rien et pèse le poids d'une
      // vraie : on la retire plutôt que de la laisser occuper la place qu'on
      // essayait justement de libérer.
      try {
        await encoder.close();
      } catch (_) {
        // L'encodeur est peut-être déjà fermé ou en erreur ; l'important est
        // que le fichier parte.
      }
      if (await destination.exists()) {
        await destination.delete();
      }
      rethrow;
    }
  }

  /// Ajoute un média **sans le compresser**.
  ///
  /// Attention au piège : `ZipFileEncoder.addFile(file, name, level)` ne
  /// permet pas d'obtenir le mode stocké. Son paramètre `level` ne règle que
  /// l'intensité de *deflate* — `level: 0` produit toujours une entrée
  /// deflate, simplement mal compressée. Le mode se décide sur
  /// `ArchiveFile.compression`, d'où cette construction à la main.
  ///
  /// Le contenu reste lu en flux (`ArchiveFile.stream`) : un fichier de
  /// plusieurs centaines de mégaoctets ne passe jamais par la mémoire.
  Future<void> _addStored(
    ZipFileEncoder encoder,
    File file,
    String archivePath,
  ) async {
    final stream = InputFileStream(file.path);
    try {
      final entry = ArchiveFile.stream(archivePath, stream)
        ..compression = CompressionType.none
        ..lastModTime =
            (await file.lastModified()).millisecondsSinceEpoch ~/ 1000
        ..mode = (await file.stat()).mode;
      encoder.addArchiveFile(entry);
    } finally {
      await stream.close();
    }
  }

  /// Manifeste et index : du texte, donc la compression par défaut du zip
  /// (deflate) est ici payante, contrairement aux médias.
  void _addText(ZipFileEncoder encoder, String name, String content) {
    encoder.addArchiveFile(ArchiveFile.bytes(name, utf8.encode(content)));
  }
}

/// L'inscrit a annulé l'assemblage.
class ExportCancelled implements Exception {
  const ExportCancelled();

  @override
  String toString() => 'ExportCancelled';
}

/// Pas assez de place pour écrire l'archive.
///
/// Levée **avant** d'écrire le premier octet : découvrir le manque à mi-course
/// laisserait une archive inutilisable occupant la place qu'on cherchait à
/// libérer.
class ExportInsufficientSpace implements Exception {
  final int needed;
  final int available;
  const ExportInsufficientSpace({
    required this.needed,
    required this.available,
  });

  @override
  String toString() =>
      'ExportInsufficientSpace(needed: $needed, available: $available)';
}
