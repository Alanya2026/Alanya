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

  /// Participants sérialisés tels que renvoyés par le serveur. Le `role` de
  /// chacun voyage dedans : aucune colonne dédiée n'est nécessaire.
  TextColumn get participantsJson => text().withDefault(const Constant('[]'))();

  // ── Groupe (migration 024) ──────────────────────────────────────────
  TextColumn get description => text().nullable()();
  IntColumn get createdBy => integer().nullable()();

  /// `conversation.updatedAt` serveur. Garde anti-réordonnancement : une trame
  /// `conversation:updated` plus ancienne que ce qu'on a déjà est ignorée.
  DateTimeColumn get metaUpdatedAt => dateTime().nullable()();

  BoolColumn get onlyAdminsCanSend =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get onlyAdminsCanEditInfo =>
      boolean().withDefault(const Constant(false))();

  /// Masquer l'historique pour les membres ajoutés après activation (défaut OFF).
  BoolColumn get hideHistoryForNewMembers =>
      boolean().withDefault(const Constant(false))();

  /// Seuls les admins peuvent ajouter des membres (défaut OFF = tout le monde).
  BoolColumn get onlyAdminsCanAddMembers =>
      boolean().withDefault(const Constant(false))();

  /// Mon rôle : 0=membre, 1=admin, 2=propriétaire (voir `GroupRole`).
  IntColumn get myRole => integer().withDefault(const Constant(0))();

  // ── Sourdine (le client ne la stockait pas jusqu'ici) ───────────────
  DateTimeColumn get mutedUntil => dateTime().nullable()();
  BoolColumn get muteForever => boolean().withDefault(const Constant(false))();
  BoolColumn get mentionsOnly =>
      boolean().withDefault(const Constant(false))();

  /// msgID système `member_added` en attente d'ack « Rester » (null = ok).
  IntColumn get myPendingJoinMsgID => integer().nullable()();

  /// Borne d'historique pour MOI : null = tout visible ; sinon sendAt >= cutoff.
  DateTimeColumn get myHistoryCutoffAt => dateTime().nullable()();

  /// Au moins une mention non lue me ciblant.
  ///
  /// Dérivé par ConversationSummaryReducer à côté de `unreadCount`, et non
  /// calculé par tuile : la liste des discussions ne peut pas se permettre une
  /// requête par ligne à chaque frame.
  BoolColumn get hasUnreadMention =>
      boolean().withDefault(const Constant(false))();

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

  /// Code d'échec serveur quand l'envoi a été REFUSÉ définitivement
  /// (`GROUP_ADMINS_ONLY`, `NOT_A_MEMBER`, `BLOCKED_BY_SENDER`).
  ///
  /// Distingue « le réseau a lâché » — où réessayer a du sens — de « le
  /// serveur a dit non » — où le bouton « réessayer » échouerait
  /// indéfiniment et ferait tourner l'utilisateur en rond.
  TextColumn get failureCode => text().nullable()();

  /// Ids mentionnés, sérialisés (`[45,46]`), miroir de `message.mentions`.
  ///
  /// Persisté et pas seulement dérivé du texte : `flushOutbox` reconstruit
  /// l'émission depuis cette ligne, et une mention envoyée hors ligne perdrait
  /// sinon sa notification au rejeu.
  TextColumn get mentionsJson => text().nullable()();

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

  /// Origine du lien de contact préféré : vrai si ajouté par code QR (scan ou
  /// lien). Alimente la pastille des listes, le filtre « Par QR » et la
  /// mention datée de la fiche.
  BoolColumn get addedViaQr => boolean().withDefault(const Constant(false))();

  /// Date d'ajout en contact préféré (preferredContact.created_at côté
  /// serveur) — pour la mention « Ajouté par QR code le … » de la fiche.
  DateTimeColumn get preferredAddedAt => dateTime().nullable()();

  /// Note contextuelle saisie après un scan (« rencontré au salon de
  /// Douala ») — affichée sur la fiche du contact.
  TextColumn get preferredNote => text().nullable()();

  IntColumn get typeCompte => integer().withDefault(const Constant(0))();
  IntColumn get accountType => integer().withDefault(const Constant(0))();
  IntColumn get verificationStatus => integer().withDefault(const Constant(0))();
  DateTimeColumn get verifiedUntil => dateTime().nullable()();
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

/// Listes de contacts (Famille, Amis, Bureau…) — entêtes seules.
///
/// Miroir local de `contact_list` (migration serveur 038) : la liste reste
/// consultable hors ligne, comme les contacts préférés.
class LocalContactLists extends Table {
  IntColumn get idList => integer()();
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Identifiant stable des listes système (`family`, `friends`, …).
  /// Null pour une liste personnalisée — le libellé affiché est [name].
  TextColumn get kind => text().nullable()();

  /// Teinte de la puce (`#RRGGBB`), null = teinte du thème.
  TextColumn get color => text().nullable()();

  /// Plafond de membres (ex. Confiance = 5). Null = illimité.
  IntColumn get memberLimit => integer().nullable()();

  /// Compte renvoyé par le serveur — évite un COUNT par liste à l'affichage.
  IntColumn get memberCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {idList};
}

/// Appartenance liste ↔ contact, many-to-many : un contact peut être dans
/// plusieurs listes. PK composite comme [LocalMessageReactions] — la ligne ne
/// porte QUE le lien, le profil vit dans [LocalUsers].
class LocalContactListMembers extends Table {
  IntColumn get idList => integer()();
  IntColumn get idFriend => integer()();

  @override
  Set<Column> get primaryKey => {idList, idFriend};
}

/// Trajets de confiance — miroir local de `trip` (migration serveur 051).
///
/// Deux rôles dans la même table, distingués par [isOwner] : le trajet que
/// *je* partage, et ceux que je *suis* en tant que membre du cercle. Le second
/// cas n'est jamais un historique — un trajet suivi disparaît du cache dès
/// qu'il est clos (voir `TripRepository.pruneClosedWatched`). C'est ce qui
/// empêche « montre-moi où tu étais mardi » d'exister.
class LocalTrips extends Table {
  IntColumn get id => integer()();
  IntColumn get ownerId => integer()();

  /// `taxi` | `meeting` | `sos`.
  TextColumn get kind => text().withDefault(const Constant('meeting'))();

  /// `active` | `awaiting_confirm` | `alert` | `sos` | `closed_*`.
  TextColumn get state => text().withDefault(const Constant('active'))();

  DateTimeColumn get etaAt => dateTime().nullable()();
  IntColumn get graceMinutes => integer().withDefault(const Constant(10))();
  IntColumn get extensions => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  TextColumn get destLabel => text().nullable()();

  /// Destination déclarée au départ, avec son rayon d'arrivée.
  ///
  /// Mise en cache pour une seule raison : l'écran de suivi doit pouvoir
  /// dessiner le point d'arrivée et son cercle **avant** la première réponse du
  /// serveur, et continuer à les dessiner hors ligne. Sans ces colonnes, la
  /// carte n'affiche qu'un pin qui se déplace sans qu'on sache vers quoi.
  ///
  /// Le libellé, lui, est résolu une seule fois à la création : géocoder la
  /// trace enverrait tout le déplacement à un tiers.
  RealColumn get destLat => real().nullable()();
  RealColumn get destLng => real().nullable()();
  IntColumn get destRadiusM => integer().nullable()();

  /// Dernière position connue. `lastAt` est l'heure de **capture** : c'est elle
  /// qu'on affiche (« maj il y a 8 s »), pas l'heure de réception.
  RealColumn get lastLat => real().nullable()();
  RealColumn get lastLng => real().nullable()();
  IntColumn get lastAccuracyM => integer().nullable()();
  IntColumn get lastBattery => integer().nullable()();
  DateTimeColumn get lastAt => dateTime().nullable()();

  /// Plus de position reçue depuis le seuil de péremption. **Pas une alerte** :
  /// une information, affichée en gris.
  BoolColumn get stale => boolean().withDefault(const Constant(false))();

  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  TextColumn get closeReason => text().nullable()();

  BoolColumn get isOwner => boolean().withDefault(const Constant(false))();

  /// Nombre de destinataires. Côté membre, c'est tout ce qu'on connaît d'eux :
  /// le nombre rassure, les identités exposeraient le carnet d'adresses d'un
  /// autre.
  IntColumn get watcherCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Trace GPS, en **anneau borné**.
///
/// Deux usages dans la même table : tampon hors ligne côté propriétaire
/// (les points en attente d'envoi, [pending] à vrai), et cache de polyligne
/// côté membre. Le plafonnement se fait dans le DAO, pas dans le schéma.
///
/// [clientSeq] sert la déduplication : le serveur ignore un numéro déjà reçu,
/// ce qui rend la vidange du tampon rejouable sans risque de doublon.
class LocalTripPoints extends Table {
  IntColumn get tripId => integer()();
  IntColumn get clientSeq => integer()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get accuracyM => integer().nullable()();
  IntColumn get speedKmh => integer().nullable()();
  IntColumn get battery => integer().nullable()();

  /// Heure de capture réelle. Un point tamponné hors ligne repart avec **son**
  /// horodatage, jamais celui de l'envoi.
  DateTimeColumn get recordedAt => dateTime()();

  BoolColumn get pending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {tripId, clientSeq};
}

/// Frise d'événements d'un trajet — source du récapitulatif de fin.
class LocalTripEvents extends Table {
  IntColumn get tripId => integer()();
  IntColumn get seq => integer()();
  TextColumn get kind => text()();
  IntColumn get actorId => integer().nullable()();

  /// JSON brut renvoyé par le serveur, décodé à l'affichage seulement.
  TextColumn get meta => text().nullable()();
  DateTimeColumn get at => dateTime()();

  @override
  Set<Column> get primaryKey => {tripId, seq};
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
    LocalContactLists,
    LocalContactListMembers,
    LocalTrips,
    LocalTripPoints,
    LocalTripEvents,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 25;

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
        onCreate: (m) async {
          await m.createAll();
          await _createLocalMessagesIndexes(m.database);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(localUsers);
            await m.createTable(localCalls);
            await m.createTable(localMeetings);
            await m.createTable(localStatuses);
          }
          if (from < 3) {
            await _addColumnIfMissing(
                m, localMessages, localMessages.deliveredAt);
            await _addColumnIfMissing(m, localMessages, localMessages.editedAt);
            await _addColumnIfMissing(
                m, localMessages, localMessages.deletedForID);
            await _addColumnIfMissing(
                m, localMessages, localMessages.lastEmittedAt);
          }
          if (from < 4) {
            await _addColumnIfMissing(
                m, localMessages, localMessages.retryCount);
          }
          if (from < 5) {
            await _addColumnIfMissing(
                m, localMessages, localMessages.isForwarded);
          }
          if (from < 6) {
            await _addColumnIfMissing(m, localMessages, localMessages.isPinned);
          }
          if (from < 7) {
            await _addColumnIfMissing(
                m, localMessages, localMessages.isViewOnce);
            await _addColumnIfMissing(m, localMessages, localMessages.viewedAt);
          }
          if (from < 8) {
            await _addColumnIfMissing(
                m, localMessages, localMessages.clickSentAt);
          }
          if (from < 9) {
            await _migrateLegacyHttpsUrls(m.database);
          }
          if (from < 10) {
            await _addColumnIfMissing(
                m, localMessages, localMessages.mediaThumb);
            await _addColumnIfMissing(
                m, localMessages, localMessages.messageTz);
            await _addColumnIfMissing(
                m, localMessages, localMessages.messageTzOffset);
          }
          if (from < 11) {
            await _migrateToNewHost(m.database);
          }
          if (from < 12) {
            await _addColumnIfMissing(
                m, localMessages, localMessages.mediaSize);
            await _addColumnIfMissing(
                m, localMessages, localMessages.mediaPageCount);
          }
          if (from < 13) {
            await m.createTable(localMessageReactions);
          }
          if (from < 14) {
            await _createLocalMessagesIndexes(m.database);
          }
          if (from < 15) {
            // Groupes enrichis (migration serveur 024). Que des addColumn :
            // le cache existant n'est pas vidé.
            await _addColumnIfMissing(
                m, localConversations, localConversations.description);
            await _addColumnIfMissing(
                m, localConversations, localConversations.createdBy);
            await _addColumnIfMissing(
                m, localConversations, localConversations.metaUpdatedAt);
            await _addColumnIfMissing(
                m, localConversations, localConversations.onlyAdminsCanSend);
            await _addColumnIfMissing(
                m, localConversations, localConversations.onlyAdminsCanEditInfo);
            await _addColumnIfMissing(
                m, localConversations, localConversations.myRole);
            await _addColumnIfMissing(
                m, localConversations, localConversations.mutedUntil);
            await _addColumnIfMissing(
                m, localConversations, localConversations.muteForever);
            await _addColumnIfMissing(
                m, localConversations, localConversations.mentionsOnly);
            await _addColumnIfMissing(
                m, localConversations, localConversations.hasUnreadMention);
            await _addColumnIfMissing(
                m, localMessages, localMessages.mentionsJson);
            await _addColumnIfMissing(
                m, localMessages, localMessages.failureCode);
          }
          if (from < 16) {
            // Origine des contacts préférés (migration serveur 027). Que des
            // addColumn : le cache existant n'est pas vidé.
            await _addColumnIfMissing(m, localUsers, localUsers.addedViaQr);
            await _addColumnIfMissing(
                m, localUsers, localUsers.preferredAddedAt);
          }
          if (from < 17) {
            await _addColumnIfMissing(m, localUsers, localUsers.preferredNote);
          }
          if (from < 18) {
            // Historique masqué + ack « Rester » (migration serveur 028).
            await _addColumnIfMissing(
                m, localConversations, localConversations.hideHistoryForNewMembers);
            await _addColumnIfMissing(
                m, localConversations, localConversations.myPendingJoinMsgID);
            await _addColumnIfMissing(
                m, localConversations, localConversations.myHistoryCutoffAt);
          }
          if (from < 19) {
            await _addColumnIfMissing(
                m, localConversations, localConversations.onlyAdminsCanAddMembers);
          }
          if (from < 20) {
            await _addColumnIfMissing(m, localUsers, localUsers.accountType);
            await _addColumnIfMissing(
                m, localUsers, localUsers.verificationStatus);
            await _addColumnIfMissing(m, localUsers, localUsers.verifiedUntil);
          }
          if (from < 21) {
            // Listes de contacts (migration serveur 038). Deux créations de
            // tables : rien du cache existant n'est vidé.
            await m.createTable(localContactLists);
            await m.createTable(localContactListMembers);
            // Rattrapage installs v20 Alfred (tables ok, colonnes compte
            // officiel manquantes). Réellement no-op quand la v20 broadcast les
            // a déjà posées : `_addColumnIfMissing` teste avant d'ALTER, là où
            // `m.addColumn` échouait en « duplicate column name ».
            await _addColumnIfMissing(m, localUsers, localUsers.accountType);
            await _addColumnIfMissing(
                m, localUsers, localUsers.verificationStatus);
            await _addColumnIfMissing(m, localUsers, localUsers.verifiedUntil);
          }
          if (from < 22) {
            await _addColumnIfMissing(
                m, localContactLists, localContactLists.memberLimit);
          }
          if (from < 23) {
            await _addColumnIfMissing(
                m, localContactLists, localContactLists.kind);
          }
          if (from < 24) {
            // Trajets de confiance (migration serveur 051). Trois créations de
            // tables : rien du cache existant n'est vidé, et `local_messages`
            // ne change pas — le message de type 9 réutilise `content`.
            await m.createTable(localTrips);
            await m.createTable(localTripPoints);
            await m.createTable(localTripEvents);
          }
          if (from < 25) {
            // Coordonnées de destination : le serveur les renvoyait déjà, le
            // cache les jetait. Trois colonnes nullables, aucun trajet perdu.
            await _addColumnIfMissing(m, localTrips, localTrips.destLat);
            await _addColumnIfMissing(m, localTrips, localTrips.destLng);
            await _addColumnIfMissing(m, localTrips, localTrips.destRadiusM);
          }
        },
      );

  /// Ajoute [column] à [table] seulement si la colonne manque réellement.
  ///
  /// `Migrator.addColumn` émet un `ALTER TABLE … ADD COLUMN` nu, que SQLite
  /// refuse par « duplicate column name » quand la colonne est déjà là — il n'y
  /// a pas d'`IF NOT EXISTS` pour les colonnes. Or une base peut avoir reçu la
  /// colonne par un autre chemin que celui prévu par l'échelle des versions :
  /// deux branches ayant revendiqué le même numéro de schéma (cas des colonnes
  /// de compte officiel, posées en v20 *et* rejouées en v21), ou une migration
  /// interrompue après l'ALTER mais avant la mise à jour de `user_version`.
  ///
  /// L'échec est irrattrapable pour l'utilisateur : il survient dans
  /// `beforeOpen`, donc `ensureOpen()` rejette et **toute** requête sur le cache
  /// échoue — plus une seule conversation à l'écran. Et comme `user_version`
  /// n'est jamais incrémenté, la même migration replante à chaque lancement,
  /// jusqu'à l'effacement des données. Tester avant d'ALTER rend chaque barreau
  /// rejouable et répare au passage les bases déjà bloquées.
  static Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final rows = await m.database
        .customSelect('PRAGMA table_info(${_quote(table.aliasedName)})')
        .get();
    final exists = rows.any((row) => row.read<String>('name') == column.name);
    if (exists) return;
    await m.addColumn(table, column);
  }

  /// Littéral SQL entre guillemets simples, apostrophes doublées.
  static String _quote(String value) => "'${value.replaceAll("'", "''")}'";

  static Future<void> _createLocalMessagesIndexes(GeneratedDatabase db) async {
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_messages_conv_send '
      'ON local_messages (conversation_i_d, send_at)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_messages_msg_id '
      'ON local_messages (msg_i_d)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_messages_outbox '
      'ON local_messages (sync_pending, last_emitted_at, send_at)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_messages_conv_status_sender '
      'ON local_messages (conversation_i_d, status, sender_i_d)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'talky_chat.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
