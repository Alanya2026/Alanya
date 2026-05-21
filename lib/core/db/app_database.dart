import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────
//  Base SQLite locale (drift) — miroir offline-first des conversations
//  et messages. L'UI lit/écrit TOUJOURS ici ; le ChatRepository
//  synchronise avec le serveur en arrière-plan.
// ─────────────────────────────────────────────────────────────────────

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

  /// Participants sérialisés en JSON (alanyaID, nom, pseudo, avatar_url,
  /// is_online, last_seen). Évite une table relationnelle lourde.
  TextColumn get participantsJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {conversID};
}

/// Messages mis en cache localement.
///
/// `clientId` est généré côté client AVANT l'envoi : il permet de retrouver
/// la ligne optimiste quand le serveur renvoie le vrai `msgID`, et sert de
/// clé d'idempotence pour l'outbox.
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

@DriftDatabase(tables: [LocalConversations, LocalMessages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'talky_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
