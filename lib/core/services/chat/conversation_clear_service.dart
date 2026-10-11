import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../db/app_database.dart';

/// Ce que « Effacer la discussion » retire de CET appareil.
enum ClearMode {
  /// Messages ET fichiers : la discussion repart d'une page blanche.
  all,

  /// Fichiers téléchargés seulement : les messages restent, sans leur fichier.
  mediaOnly,
}

/// Poids de ce qu'un effacement libérerait, pour la feuille de confirmation.
class ClearEstimate {
  const ClearEstimate({
    this.mediaFiles = 0,
    this.mediaBytes = 0,
    this.textBytes = 0,
  });

  final int mediaFiles;
  final int mediaBytes;
  final int textBytes;

  int bytesFor(ClearMode mode) =>
      mode == ClearMode.all ? mediaBytes + textBytes : mediaBytes;
}

/// Racines où l'app possède ses fichiers (documents et cache).
typedef AppRoots = Future<List<String>> Function();

Future<List<String>> _productionRoots() async => [
      (await getApplicationDocumentsDirectory()).path,
      (await getTemporaryDirectory()).path,
    ];

/// Effacement LOCAL d'une discussion : lignes `messages`, réactions, fichiers
/// téléchargés, aperçu de la liste.
///
/// Le serveur, lui, ne perd rien : « Effacer la discussion » pose un curseur
/// d'historique propre à l'utilisateur (`historyCutoffAt`) et c'est ce curseur
/// que ce service applique à la copie locale — pour l'appareil qui a effacé,
/// pour ses autres appareils (`conversation:cleared`) et pour un appareil resté
/// hors ligne (à la synchronisation de la liste).
///
/// Deux garde-fous sur les FICHIERS, parce qu'un effacement ne doit jamais
/// toucher à ce qui n'est pas à lui :
///  - seuls les fichiers situés dans les dossiers de l'app sont supprimés. Un
///    `localMediaPath` peut pointer ailleurs (photo prise dans la galerie) : ce
///    fichier-là est à l'utilisateur, on oublie la référence mais on le laisse ;
///  - un fichier encore référencé par un message d'une AUTRE discussion (un
///    transfert réutilise le même téléchargement) reste en place.
class ConversationClearService {
  ConversationClearService(this._db, {AppRoots? appRoots})
      : _roots = appRoots ?? _productionRoots;

  final AppDatabase _db;
  final AppRoots _roots;

  /// Messages qui partiraient (hors envois en attente), pour l'estimation.
  Future<List<LocalMessage>> _clearable(int conversID, {DateTime? before}) {
    final q = _db.select(_db.localMessages)
      ..where((m) {
        var cond =
            m.conversationID.equals(conversID) & m.syncPending.equals(false);
        if (before != null) cond = cond & m.sendAt.isSmallerThanValue(before);
        return cond;
      });
    return q.get();
  }

  Future<ClearEstimate> estimate(int conversID) async {
    final rows = await _clearable(conversID);
    final roots = await _roots();
    final seen = <String>{};
    var files = 0;
    var mediaBytes = 0;
    var textBytes = 0;
    for (final m in rows) {
      textBytes += (m.content ?? '').length;
      final path = m.localMediaPath;
      if (path == null || path.isEmpty || !seen.add(path)) continue;
      if (!_isInside(path, roots)) continue;
      try {
        final f = File(path);
        if (f.existsSync()) {
          mediaBytes += f.lengthSync();
          files++;
        }
      } catch (e) {
        debugPrint('[ClearService] taille $path: $e');
      }
    }
    return ClearEstimate(
        mediaFiles: files, mediaBytes: mediaBytes, textBytes: textBytes);
  }

  /// Retire tout ce qui est antérieur à [cutoff] (`sendAt < cutoff`, comme le
  /// serveur : un message de la seconde même du curseur reste visible), mémorise
  /// le curseur et, s'il ne reste plus aucun message, vide l'aperçu de la liste.
  ///
  /// Les envois en attente (`syncPending`) restent : ils partiront après
  /// l'effacement et appartiennent à la page blanche. Retourne le nombre de
  /// messages retirés ; l'appelant recalcule l'aperçu quand il en reste.
  Future<int> clearBefore(int conversID, DateTime cutoff) async {
    final rows = await _clearable(conversID, before: cutoff);
    final paths = <String>{
      for (final m in rows)
        for (final path in [m.localMediaPath, m.pendingUploadPath])
          if (path != null && path.isNotEmpty) path,
    };

    await _db.transaction(() async {
      if (rows.isNotEmpty) {
        final ids = rows.map((m) => m.clientId).toList();
        for (var i = 0; i < ids.length; i += 500) {
          final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
          await (_db.delete(_db.localMessages)
                ..where((m) => m.clientId.isIn(chunk)))
              .go();
        }
        final serverIds = rows.map((m) => m.msgID).where((id) => id > 0).toList();
        for (var i = 0; i < serverIds.length; i += 500) {
          final chunk = serverIds.sublist(
              i, i + 500 > serverIds.length ? serverIds.length : i + 500);
          await (_db.delete(_db.localMessageReactions)
                ..where((r) => r.msgID.isIn(chunk)))
              .go();
        }
      }
      await (_db.update(_db.localConversations)
            ..where((c) => c.conversID.equals(conversID)))
          .write(LocalConversationsCompanion(myHistoryCutoffAt: Value(cutoff)));

      final restants = await (_db.selectOnly(_db.localMessages)
            ..addColumns([_db.localMessages.clientId])
            ..where(_db.localMessages.conversationID.equals(conversID))
            ..limit(1))
          .get();
      if (restants.isEmpty) {
        // `lastMessageAt` reste : il ordonne la liste, comme chez le serveur.
        await (_db.update(_db.localConversations)
              ..where((c) => c.conversID.equals(conversID)))
            .write(const LocalConversationsCompanion(
          lastMessage: Value(null),
          lastMessageSenderID: Value(null),
          lastMessageType: Value(null),
          lastMessageStatus: Value(null),
          unreadCount: Value(0),
        ));
      }
    });

    await _deleteFiles(paths);
    return rows.length;
  }

  /// Comme [clearBefore], mais ne fait rien (et n'écrit rien : pas de flux
  /// réveillé pour rien) tant qu'aucun message local ne précède [cutoff]. C'est
  /// l'appel de la synchronisation périodique de la liste.
  Future<int> purgeIfStale(int conversID, DateTime cutoff) async {
    final une = await (_db.selectOnly(_db.localMessages)
          ..addColumns([_db.localMessages.clientId])
          ..where(_db.localMessages.conversationID.equals(conversID) &
              _db.localMessages.syncPending.equals(false) &
              _db.localMessages.sendAt.isSmallerThanValue(cutoff))
          ..limit(1))
        .get();
    if (une.isEmpty) return 0;
    return clearBefore(conversID, cutoff);
  }

  /// « Fichiers médias uniquement » : supprime les fichiers téléchargés de la
  /// discussion et oublie leur chemin. Les messages restent (texte, vignette) ;
  /// un média encore disponible sur le serveur se retélécharge à l'ouverture.
  /// Retourne le nombre de fichiers supprimés.
  Future<int> clearMediaOnly(int conversID) async {
    final rows = await (_db.select(_db.localMessages)
          ..where((m) =>
              m.conversationID.equals(conversID) &
              m.syncPending.equals(false) &
              m.localMediaPath.isNotNull()))
        .get();
    if (rows.isEmpty) return 0;
    final paths = <String>{
      for (final m in rows)
        for (final path in [m.localMediaPath, m.pendingUploadPath])
          if (path != null && path.isNotEmpty) path,
    };
    await _db.transaction(() async {
      final ids = rows.map((m) => m.clientId).toList();
      for (var i = 0; i < ids.length; i += 500) {
        final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
        await (_db.update(_db.localMessages)
              ..where((m) => m.clientId.isIn(chunk)))
            .write(const LocalMessagesCompanion(
          localMediaPath: Value(null),
          pendingUploadPath: Value(null),
        ));
      }
    });
    return _deleteFiles(paths);
  }

  /// Supprime [paths] sous les garde-fous de la description de la classe.
  Future<int> _deleteFiles(Set<String> paths) async {
    if (paths.isEmpty) return 0;
    final roots = await _roots();
    final candidats = paths.where((path) => _isInside(path, roots)).toList();
    if (candidats.isEmpty) return 0;

    final encoreUtilises = <String>{};
    for (var i = 0; i < candidats.length; i += 500) {
      final chunk = candidats.sublist(
          i, i + 500 > candidats.length ? candidats.length : i + 500);
      final refs = await (_db.select(_db.localMessages)
            ..where((m) =>
                m.localMediaPath.isIn(chunk) | m.pendingUploadPath.isIn(chunk)))
          .get();
      for (final m in refs) {
        for (final path in [m.localMediaPath, m.pendingUploadPath]) {
          if (path != null) encoreUtilises.add(path);
        }
      }
    }

    var supprimes = 0;
    for (final path in candidats) {
      if (encoreUtilises.contains(path)) continue;
      try {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
          supprimes++;
        }
      } catch (e) {
        debugPrint('[ClearService] suppression $path: $e');
      }
    }
    return supprimes;
  }

  static bool _isInside(String path, List<String> roots) {
    final normalise = p.normalize(p.absolute(path));
    return roots.any((r) => p.isWithin(p.normalize(p.absolute(r)), normalise));
  }
}
