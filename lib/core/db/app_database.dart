import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

//  Base SQLite locale (drift) — miroir offline-first des conversations

/// Conversations mises en cache localement.
class LocalConversations extends Table {
  IntColumn get conversID => integer()();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  TextColumn get groupName => text().nullable()();
  TextColumn get groupPhoto => text().nullable()();
  TextColumn get lastMessage => text().nullable()();
  DateTimeColumn get lastMessageAt => dateTime().nullable()();
  IntColumn get lastMessageSenderID => integer().nullable()();
  IntColumn get lastMessageType => integer().nullable()();
  IntColumn get lastMessageStatus => integer().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get participantsJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {conversID};
}

/// Messages mis en cache localement
class LocalMessages extends Table {
  TextColumn get clientId => text()();

  /// `msgID` serveur — 0 tant que le message n'est pas confirmé.
  IntColumn get msgID => integer().withDefault(const Constant(0))();
  IntColumn get conversationID => integer()();
  IntColumn get senderID => integer()();
  TextColumn get content => text().nullable()();

  /// 0=texte 1=image 2=vidéo 3=audio 4=fichier 5=localisation
  IntColumn get type => integer().withDefault(const Constant(0))();

  /// 0=sending 1=sent 2=delivered 3=read 4=failed
  IntColumn get status => integer().withDefault(const Constant(0))();
  DateTimeColumn get sendAt => dateTime()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();

  TextColumn get mediaUrl => text().nullable()();
  TextColumn get mediaName => text().nullable()();
  IntColumn get mediaDuration => integer().nullable()();

  /// Taille du fichier en octets (documents / médias type fichier).
  IntColumn get mediaSize => integer().nullable()();

  /// Nombre de pages pour les PDF.
  IntColumn get mediaPageCount => integer().nullable()();

  /// Vignette vidéo (JPEG base64) transmise avec le message pour l'aperçu chez
  /// le destinataire, disponible immédiatement et hors ligne sans télécharger
  /// la vidéo complète.
  TextColumn get mediaThumb => text().nullable()();

  /// Chemin du média téléchargé/mis en cache localement (consultable offline).
  TextColumn get localMediaPath => text().nullable()();

  /// Chemin du fichier local à uploader (envoi offline d'un média).
  TextColumn get pendingUploadPath => text().nullable()();

  IntColumn get replyToID => integer().nullable()();
  TextColumn get replyToContent => text().nullable()();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  DateTimeColumn get editedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// alanyaID de l'utilisateur pour qui le message est masqué (suppression "pour moi").
  IntColumn get deletedForID => integer().nullable()();
  IntColumn get isStatusReply => integer().withDefault(const Constant(0))();
  BoolColumn get isForwarded => boolean().withDefault(const Constant(false))();

  /// Message épinglé dans la conversation (visible de tous les participants).
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// Média à vue unique (« view once »).
  BoolColumn get isViewOnce => boolean().withDefault(const Constant(false))();

  /// Instant où CE média vue unique a été consommé (ouvert par moi, ou signalé
  /// « vu » via socket). Non nul ⇒ le média n'est plus ré-ouvrable.
  DateTimeColumn get viewedAt => dateTime().nullable()();

  /// Heure locale à laquelle l'expéditeur a appuyé sur « envoyer » (heure du
  /// clic). Distincte de `sendAt`, qui devient l'horodatage serveur (départ
  /// effectif) une fois le message confirmé. Désormais synchronisée avec le
  /// serveur : visible aussi bien par l'expéditeur que par le destinataire.
  DateTimeColumn get clickSentAt => dateTime().nullable()();

  /// Cache local (dénormalisé, comme [senderNom]) du fuseau horaire de
  /// l'expéditeur, tel que renvoyé par le serveur. PAS de capture côté
  /// appareil ni de colonne dédiée en base : le serveur le dérive à la
  /// volée via une jointure `users` → `pays.timeZone` (le pays enregistré
  /// de l'expéditeur), donc rien n'est dupliqué par message côté backend.
  TextColumn get messageTz => text().nullable()();

  /// Décalage horaire (en heures) du pays de l'expéditeur, renvoyé par le
  /// serveur (`pays.decalageHoraire`) — permet un affichage direct type
  /// "UTC+1" sans avoir à interpréter [messageTz].
  IntColumn get messageTzOffset => integer().nullable()();

  TextColumn get senderNom => text().nullable()();
  TextColumn get senderPseudo => text().nullable()();
  TextColumn get senderAvatar => text().nullable()();

  /// true tant que le message n'a pas été remis au serveur (outbox).
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

  /// Dernier instant d'émission via le socket — sert au backoff de l'outbox.
  DateTimeColumn get lastEmittedAt => dateTime().nullable()();
  
  /// Nombre de tentatives de retry pour ce message (failed -> retry).
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {clientId};
}

/// Utilisateurs connus (contacts préférés + caches d'auteurs de messages).
class LocalUsers extends Table {
  IntColumn get alanyaID => integer()();
  TextColumn get nom => text().withDefault(const Constant(''))();
  TextColumn get pseudo => text().withDefault(const Constant(''))();
  TextColumn get alanyaPhone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  IntColumn get idPays => integer().withDefault(const Constant(0))();
  TextColumn get paysLibelle => text().nullable()();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  BoolColumn get isPreferredContact => boolean().withDefault(const Constant(false))();
  IntColumn get typeCompte => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {alanyaID};
}

/// Historique d'appels mis en cache localement.
class LocalCalls extends Table {
  IntColumn get idCall => integer()();
  IntColumn get idCaller => integer()();
  IntColumn get idReceiver => integer()();

  /// 0=audio, 1=vidéo
  IntColumn get type => integer().withDefault(const Constant(0))();

  /// 0=missed, 1=answered, 2=rejected, 3=outgoing answered…
  IntColumn get status => integer().withDefault(const Constant(0))();
  IntColumn get duration => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Snapshot dénormalisé pour affichage offline (avatar/nom du correspondant).
  TextColumn get otherNom => text().nullable()();
  TextColumn get otherAvatar => text().nullable()();

  @override
  Set<Column> get primaryKey => {idCall};
}

/// Réunions planifiées / passées mises en cache.
class LocalMeetings extends Table {
  IntColumn get idMeeting => integer()();
  TextColumn get objet => text().withDefault(const Constant(''))();
  TextColumn get room => text().withDefault(const Constant(''))();
  DateTimeColumn get startTime => dateTime()();
  IntColumn get duree => integer().withDefault(const Constant(60))();
  IntColumn get typeMedia => integer().withDefault(const Constant(0))();
  IntColumn get organiserID => integer().withDefault(const Constant(0))();
  TextColumn get organiserNom => text().nullable()();
  TextColumn get participantsJson => text().withDefault(const Constant('[]'))();

  /// 0=upcoming, 1=ongoing, 2=ended, 3=cancelled
  IntColumn get statut => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {idMeeting};
}

/// Statuts / stories mis en cache (TTL = expiresAt).
class LocalStatuses extends Table {
  IntColumn get idStatut => integer()();
  IntColumn get authorID => integer()();
  TextColumn get authorNom => text().nullable()();
  TextColumn get authorAvatar => text().nullable()();

  /// 0=texte, 1=image, 2=vidéo, 3=audio
  IntColumn get type => integer().withDefault(const Constant(0))();
  TextColumn get textContent => text().nullable()();
  TextColumn get mediaUrl => text().nullable()();
  TextColumn get localMediaPath => text().nullable()();
  TextColumn get backgroundColor => text().nullable()();
  IntColumn get mediaDurationMs => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  BoolColumn get isMine => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {idStatut};
}

/// Réactions emoji sur les messages — une seule réaction par utilisateur et
/// par message (comme WhatsApp/Telegram) : PK composite (msgID, userID), un
/// nouvel upsert avec un emoji différent remplace l'ancien.
class LocalMessageReactions extends Table {
  /// `msgID` serveur du message réagi (pas de réaction sur un message encore
  /// en attente d'envoi : msgID > 0 garanti côté DAO).
  IntColumn get msgID => integer()();

  /// alanyaID de l'auteur de la réaction.
  IntColumn get userID => integer()();

  /// Dénormalisé (comme `senderNom` sur [LocalMessages]) pour permettre une
  /// requête directe par conversation sans jointure.
  IntColumn get conversationID => integer()();

  /// Emoji unique (ex. "👍"). Jamais vide : une ligne sans réaction est
  /// supprimée plutôt que stockée avec un emoji vide.
  TextColumn get emoji => text()();

  DateTimeColumn get reactedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {msgID, userID};
}

@DriftDatabase(
  tables: [
    LocalConversations,
    LocalMessages,
    LocalUsers,
    LocalCalls,
    LocalMeetings,
    LocalStatuses,
    LocalMessageReactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 13;

  static const _legacyHttps = 'https://158.220.107.211';
  static const _httpHost = 'http://158.220.107.211';

  /// Nouveau domaine après migration serveur (Let's Encrypt HTTPS).
  static const _newHost = 'https://www.alanya237.com';

  Future<void> _migrateLegacyHttpsUrls(GeneratedDatabase db) async {
    Future<void> fixColumn(String table, String column) async {
      await db.customStatement(
        "UPDATE $table SET $column = REPLACE($column, '$_legacyHttps', '$_httpHost') "
        "WHERE $column LIKE '$_legacyHttps%'",
      );
    }

    await fixColumn('local_messages', 'media_url');
    await fixColumn('local_messages', 'sender_avatar');
    await fixColumn('local_conversations', 'group_photo');
    await fixColumn('local_users', 'avatar_url');
    await fixColumn('local_calls', 'other_avatar');
    await fixColumn('local_statuses', 'media_url');
    await fixColumn('local_statuses', 'author_avatar');
    await db.customStatement(
      "UPDATE local_conversations SET participants_json = REPLACE(participants_json, '$_legacyHttps', '$_httpHost') "
      "WHERE participants_json LIKE '%$_legacyHttps%'",
    );
    await db.customStatement(
      "UPDATE local_meetings SET participants_json = REPLACE(participants_json, '$_legacyHttps', '$_httpHost') "
      "WHERE participants_json LIKE '%$_legacyHttps%'",
    );
  }

  /// Réécrit toute URL de l'ancien hôte (`http`/`https://158.220.107.211`) vers
  /// le nouveau domaine, pour que les médias déjà en cache restent accessibles
  /// après la migration serveur vers www.alanya237.com.
  Future<void> _migrateToNewHost(GeneratedDatabase db) async {
    Future<void> fixColumn(String table, String column) async {
      for (final legacy in const [_legacyHttps, _httpHost]) {
        await db.customStatement(
          "UPDATE $table SET $column = REPLACE($column, '$legacy', '$_newHost') "
          "WHERE $column LIKE '$legacy%'",
        );
      }
    }

    await fixColumn('local_messages', 'media_url');
    await fixColumn('local_messages', 'sender_avatar');
    await fixColumn('local_conversations', 'group_photo');
    await fixColumn('local_users', 'avatar_url');
    await fixColumn('local_calls', 'other_avatar');
    await fixColumn('local_statuses', 'media_url');
    await fixColumn('local_statuses', 'author_avatar');
    for (final legacy in const [_legacyHttps, _httpHost]) {
      await db.customStatement(
        "UPDATE local_conversations SET participants_json = REPLACE(participants_json, '$legacy', '$_newHost') "
        "WHERE participants_json LIKE '%$legacy%'",
      );
      await db.customStatement(
        "UPDATE local_meetings SET participants_json = REPLACE(participants_json, '$legacy', '$_newHost') "
        "WHERE participants_json LIKE '%$legacy%'",
      );
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(localUsers);
            await m.createTable(localCalls);
            await m.createTable(localMeetings);
            await m.createTable(localStatuses);
          }
          if (from < 3) {
            await m.addColumn(localMessages, localMessages.deliveredAt);
            await m.addColumn(localMessages, localMessages.editedAt);
            await m.addColumn(localMessages, localMessages.deletedForID);
            await m.addColumn(localMessages, localMessages.lastEmittedAt);
          }
          if (from < 4) {
            await m.addColumn(localMessages, localMessages.retryCount);
          }
          if (from < 5) {
            await m.addColumn(localMessages, localMessages.isForwarded);
          }
          if (from < 6) {
            await m.addColumn(localMessages, localMessages.isPinned);
          }
          if (from < 7) {
            await m.addColumn(localMessages, localMessages.isViewOnce);
            await m.addColumn(localMessages, localMessages.viewedAt);
          }
          if (from < 8) {
            await m.addColumn(localMessages, localMessages.clickSentAt);
          }
          if (from < 9) {
            await _migrateLegacyHttpsUrls(m.database);
          }
          if (from < 10) {
            await m.addColumn(localMessages, localMessages.mediaThumb);
            await m.addColumn(localMessages, localMessages.messageTz);
            await m.addColumn(localMessages, localMessages.messageTzOffset);
          }
          if (from < 11) {
            await _migrateToNewHost(m.database);
          }
          if (from < 12) {
            await m.addColumn(localMessages, localMessages.mediaSize);
            await m.addColumn(localMessages, localMessages.mediaPageCount);
          }
          if (from < 13) {
            await m.createTable(localMessageReactions);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'talky_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
