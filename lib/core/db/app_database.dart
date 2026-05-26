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
  DateTimeColumn get readAt => dateTime().nullable()();

  TextColumn get mediaUrl => text().nullable()();
  TextColumn get mediaName => text().nullable()();
  IntColumn get mediaDuration => integer().nullable()();

  /// Chemin du média téléchargé/mis en cache localement (consultable offline).
  TextColumn get localMediaPath => text().nullable()();

  /// Chemin du fichier local à uploader (envoi offline d'un média).
  TextColumn get pendingUploadPath => text().nullable()();

  IntColumn get replyToID => integer().nullable()();
  TextColumn get replyToContent => text().nullable()();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get isStatusReply => integer().withDefault(const Constant(0))();

  TextColumn get senderNom => text().nullable()();
  TextColumn get senderPseudo => text().nullable()();
  TextColumn get senderAvatar => text().nullable()();

  /// true tant que le message n'a pas été remis au serveur (outbox).
  BoolColumn get syncPending => boolean().withDefault(const Constant(false))();

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

@DriftDatabase(
  tables: [
    LocalConversations,
    LocalMessages,
    LocalUsers,
    LocalCalls,
    LocalMeetings,
    LocalStatuses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

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
