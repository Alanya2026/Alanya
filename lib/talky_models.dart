// talky_models.dart — aligné avec la DB Alanya réelle
// Champs mappés exactement sur les colonnes MySQL

import 'core/utils/backend_url.dart';
import 'core/utils/contact_payload.dart';
import 'core/utils/location_payload.dart';
import 'core/theme/locale_controller.dart';
import 'core/utils/self_chat.dart';

// ── USER ─────────────────────────────────────────────────────────────

class User {
  final int alanyaID;
  final String nom;
  final String pseudo;
  final String alanyaPhone;
  final String email;
  final int idPays;
  final String avatarUrl;
  final int typeCompte;
  final bool isOnline;
  final String lastSeen;
  // Champs admin (optionnels — peuplés uniquement par les endpoints admin)
  final bool exclus;
  final String? excludeAt;
  final String? excludeReason;
  final String? createdAt;
  final String? paysLibelle;

  User({
    required this.alanyaID,
    required this.nom,
    required this.pseudo,
    required this.alanyaPhone,
    required this.email,
    required this.idPays,
    required this.avatarUrl,
    required this.typeCompte,
    required this.isOnline,
    required this.lastSeen,
    this.exclus = false,
    this.excludeAt,
    this.excludeReason,
    this.createdAt,
    this.paysLibelle,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        alanyaID: json['alanyaID'] ?? 0,
        nom: json['nom'] ?? '',
        pseudo: json['pseudo'] ?? '',
        alanyaPhone: json['alanyaPhone'] ?? '',
        email: json['email'] ?? '',
        idPays: json['idPays'] ?? 10,
        avatarUrl: normalizeBackendUrl(json['avatar_url']?.toString()) ?? '',
        typeCompte: json['type_compte'] ?? 0,
        isOnline: json['is_online'] == 1 || json['is_online'] == true,
        lastSeen: json['last_seen'] ?? '',
        exclus: json['exclus'] == 1 || json['exclus'] == true,
        excludeAt: json['exclude_at'],
        excludeReason: json['exclude_reason'],
        createdAt: json['created_at'],
        paysLibelle: json['pays_libelle'],
      );

  Map<String, dynamic> toJson() => {
        'alanyaID': alanyaID,
        'nom': nom,
        'pseudo': pseudo,
        'alanyaPhone': alanyaPhone,
        'email': email,
        'idPays': idPays,
        'avatar_url': avatarUrl,
        'type_compte': typeCompte,
        'is_online': isOnline,
        'last_seen': lastSeen,
        'pays_libelle': paysLibelle,
        'exclus': exclus,
        'exclude_at': excludeAt,
        'exclude_reason': excludeReason,
        'created_at': createdAt,
      };
}

// ── PAYS ─────────────────────────────────────────────────────────────
// Table: pays
// PK: idPays | libelle | prefix

class Pays {
  final int idPays;
  final String libelle;
  final String prefix;

  const Pays({
    required this.idPays,
    required this.libelle,
    required this.prefix,
  });

  factory Pays.fromJson(Map<String, dynamic> json) => Pays(
        idPays: json['idPays'] ?? 0,
        libelle: json['libelle'] ?? '',
        prefix: json['prefix'] ?? '',
      );
}

// ── MESSAGE ──────────────────────────────────────────────────────────
// Table: message
// PK: msgID | senderID | conversationID | content | type | status
// status: 1=envoyé, 2=livré, 3=lu

class Message {
  final int msgID;
  final int senderID;
  final int conversationID;
  final String? content;
  final int type; // 0=texte,1=image,2=vidéo,3=audio,4=fichier,5=localisation
  final int status; // 0=sending,1=sent,2=delivered,3=read
  final String sendAt;
  final String? deliveredAt;
  final String? readAt;
  /// Instant (horloge de l'expéditeur) où il a appuyé sur LocaleController.instance.l10n.commonSend.
  final String? clickSentAt;
  /// Fuseau horaire de l'expéditeur (pays enregistré), renvoyé par le
  /// serveur — dérivé via jointure, jamais capturé ni stocké par message.
  final String? messageTz;
  /// Décalage horaire (heures) du pays de l'expéditeur, pour un affichage
  /// direct type "UTC+1" sans interpréter [messageTz].
  final int? messageTzOffset;
  final String? mediaUrl;
  final String? mediaName;
  final int? mediaDuration;
  final int? mediaSize;
  final int? mediaPageCount;
  final int? replyToID;
  final String? replyToContent;
  final bool isEdited;
  final String? editedAt;
  final bool isDeleted;
  final int? deletedForID;
  final int isStatusReply;
  final bool isForwarded;
  final bool isPinned;
  final bool isViewOnce;
  // Jointure users
  final String? senderNom;
  final String? senderPseudo;
  final String? senderAvatar;

  Message({
    required this.msgID,
    required this.senderID,
    required this.conversationID,
    this.content,
    required this.type,
    required this.status,
    required this.sendAt,
    this.deliveredAt,
    this.readAt,
    this.clickSentAt,
    this.messageTz,
    this.messageTzOffset,
    this.mediaUrl,
    this.mediaName,
    this.mediaDuration,
    this.mediaSize,
    this.mediaPageCount,
    this.replyToID,
    this.replyToContent,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    this.deletedForID,
    required this.isStatusReply,
    this.isForwarded = false,
    this.isPinned = false,
    this.isViewOnce = false,
    this.senderNom,
    this.senderPseudo,
    this.senderAvatar,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        msgID: json['msgID'] ?? 0,
        senderID: json['senderID'] ?? 0,
        conversationID: json['conversationID'] ?? 0,
        content: json['content'],
        type: json['type'] ?? 0,
        status: json['status'] ?? 1,
        sendAt: json['sendAt'] ?? '',
        deliveredAt: json['deliveredAt'],
        readAt: json['readAt'],
        clickSentAt: json['clickSentAt'],
        messageTz: json['messageTz'],
        messageTzOffset: json['messageTzOffset'] is int
            ? json['messageTzOffset'] as int
            : int.tryParse(json['messageTzOffset']?.toString() ?? ''),
        mediaUrl: normalizeBackendUrl(json['mediaUrl']?.toString()),
        mediaName: json['mediaName'],
        mediaDuration: json['mediaDuration'],
        mediaSize: json['mediaSize'] is int
            ? json['mediaSize'] as int
            : int.tryParse(json['mediaSize']?.toString() ?? ''),
        mediaPageCount: json['mediaPageCount'] is int
            ? json['mediaPageCount'] as int
            : int.tryParse(json['mediaPageCount']?.toString() ?? ''),
        replyToID: json['replyToID'],
        replyToContent: json['replyToContent'],
        isEdited: json['isEdited'] == 1 || json['isEdited'] == true,
        editedAt: json['editedAt'],
        isDeleted: json['isDeleted'] == 1 || json['isDeleted'] == true,
        deletedForID: json['deletedForID'] is int
            ? json['deletedForID'] as int
            : (json['deletedForID'] == null
                ? null
                : int.tryParse(json['deletedForID'].toString())),
        isStatusReply: json['isStatusReply'] ?? 0,
        isForwarded: json['isForwarded'] == 1 || json['isForwarded'] == true,
        isPinned: json['isPinned'] == 1 || json['isPinned'] == true,
        isViewOnce: json['isViewOnce'] == 1 || json['isViewOnce'] == true,
        senderNom: json['sender_nom'],
        senderPseudo: json['sender_pseudo'],
        senderAvatar: normalizeBackendUrl(json['sender_avatar']?.toString()),
      );

  // Texte affiché dans le résumé de conversation
  String get displayContent {
    if (type == 5) {
      final loc = LocationPayload.tryParse(content);
      return loc?.previewLabel ?? LocaleController.instance.l10n.location;
    }
    if (type == 7) {
      final contact = ContactPayload.tryParse(content);
      return contact?.previewLabel ?? LocaleController.instance.l10n.contact;
    }
    if (content != null && content!.isNotEmpty) return content!;
    if (mediaName != null) return mediaName!;
    switch (type) {
      case 1: return LocaleController.instance.l10n.photo;
      case 2: return LocaleController.instance.l10n.video;
      case 3: return LocaleController.instance.l10n.audio;
      case 4: return LocaleController.instance.l10n.file;
      default: return '';
    }
  }
}

// ── RÉACTION ──────────────────────────────────────────────────────────
// Table: message_reaction
// PK: (msgID, userID) — une seule réaction par utilisateur et par message.

class MessageReaction {
  final int msgID;
  final int userID;
  final String emoji;
  final String? reactedAt;
  // Jointure users (utile pour un futur détail « qui a réagi »)
  final String? userNom;
  final String? userPseudo;

  const MessageReaction({
    required this.msgID,
    required this.userID,
    required this.emoji,
    this.reactedAt,
    this.userNom,
    this.userPseudo,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        msgID: json['msgID'] is int
            ? json['msgID'] as int
            : int.tryParse(json['msgID']?.toString() ?? '') ?? 0,
        userID: json['userID'] is int
            ? json['userID'] as int
            : int.tryParse(json['userID']?.toString() ?? '') ?? 0,
        emoji: json['emoji']?.toString() ?? '',
        reactedAt: json['reactedAt']?.toString(),
        userNom: json['user_nom'],
        userPseudo: json['user_pseudo'],
      );
}

// ── CONVERSATION ─────────────────────────────────────────────────────
// Table: conversation
// PK: conversID | isGroup | GroupName | groupPhoto | lastMessage | lastMessageAt

/// Rôles dans un groupe — miroir de `conv_participants.role`.
///
/// Volontairement des constantes sur un `int` plutôt qu'une enum : la valeur
/// voyage telle quelle en JSON et en base, et le gating s'écrit `role >= admin`
/// (même style que `AdminProvider.isAdmin`, qui compare `typeCompte >= 1`).
abstract final class GroupRole {
  static const int member = 0;
  static const int admin = 1;
  static const int owner = 2;
}

/// Un membre d'une conversation, avec ses métadonnées de liaison.
///
/// Le rôle ne peut pas vivre sur [User] : cette classe est partagée par les
/// contacts, l'administration, les appels et les réunions, où un rôle de groupe
/// vaudrait 0 partout et se confondrait avec `typeCompte`.
class Participant {
  final User user;
  final int role;
  final String? joinedAt;

  const Participant({
    required this.user,
    this.role = GroupRole.member,
    this.joinedAt,
  });

  bool get isAdmin => role >= GroupRole.admin;
  bool get isOwner => role == GroupRole.owner;

  int get alanyaID => user.alanyaID;
  String get nom => user.nom;

  /// Le serveur aplatit le rôle dans l'objet utilisateur (`attachParticipants`),
  /// il n'y a donc pas d'objet imbriqué à déballer.
  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        user: User.fromJson(json),
        role: (json['role'] as num?)?.toInt() ?? GroupRole.member,
        joinedAt: json['joinedAt']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        ...user.toJson(),
        'role': role,
        if (joinedAt != null) 'joinedAt': joinedAt,
      };
}

class Conversation {
  final int conversID;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final String? description;
  final int? createdBy;
  final String? lastMessage;
  final String? lastMessageAt;
  final int? lastMessageSenderID;
  final int? lastMessageType;
  final int? lastMessageStatus;
  final String? updatedAt;
  // Réglages de groupe
  final bool onlyAdminsCanSend;
  final bool onlyAdminsCanEditInfo;
  // conv_participants
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final int myRole;
  final String? mutedUntil;
  final bool muteForever;
  final bool mentionsOnly;
  // Jointure participants
  final List<Participant> participants;

  Conversation({
    required this.conversID,
    required this.isGroup,
    this.groupName,
    this.groupPhoto,
    this.description,
    this.createdBy,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderID,
    this.lastMessageType,
    this.lastMessageStatus,
    this.updatedAt,
    this.onlyAdminsCanSend = false,
    this.onlyAdminsCanEditInfo = false,
    required this.unreadCount,
    required this.isPinned,
    required this.isArchived,
    this.myRole = GroupRole.member,
    this.mutedUntil,
    this.muteForever = false,
    this.mentionsOnly = false,
    required this.participants,
  });

  static bool _flag(dynamic v) => v == 1 || v == true || v == '1';

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        conversID: json['conversID'] ?? 0,
        isGroup: _flag(json['isGroup']),
        groupName: json['GroupName'],
        groupPhoto: normalizeBackendUrl(json['groupPhoto']?.toString()),
        description: json['description'],
        createdBy: (json['createdBy'] as num?)?.toInt(),
        lastMessage: json['lastMessage'],
        lastMessageAt: json['lastMessageAt'],
        lastMessageSenderID: json['lastMessageSenderID'],
        lastMessageType: json['lastMessageType'],
        lastMessageStatus: json['lastMessageStatus'],
        updatedAt: json['updatedAt']?.toString(),
        onlyAdminsCanSend: _flag(json['onlyAdminsCanSend']),
        onlyAdminsCanEditInfo: _flag(json['onlyAdminsCanEditInfo']),
        unreadCount: json['unreadCount'] ?? 0,
        isPinned: _flag(json['isPinned']),
        isArchived: _flag(json['isArchived']),
        myRole: (json['myRole'] as num?)?.toInt() ?? GroupRole.member,
        mutedUntil: json['mutedUntil']?.toString(),
        muteForever: _flag(json['muteForever']),
        mentionsOnly: _flag(json['mentionsOnly']),
        participants: (json['participants'] as List?)
                ?.map((e) => Participant.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  bool get iAmAdmin => myRole >= GroupRole.admin;
  bool get iAmOwner => myRole == GroupRole.owner;

  /// Conversation « avec soi-même » (marqueur serveur porté par `GroupName`).
  bool isSelfChat(int myId) {
    if (isGroup || myId == 0) return false;
    if (groupName != kSelfChatMarker) return false;
    if (participants.isEmpty) return true; // payload serveur tronqué
    return participants.any((u) => u.alanyaID == myId);
  }

  // Nom à afficher (groupe, « Moi », ou nom de l'autre participant)
  String displayName(int myId) {
    final l10n = resolveL10n();
    if (isGroup) return groupName ?? l10n.groupFallback;
    if (isSelfChat(myId)) {
      final me = participants.where((u) => u.alanyaID == myId).firstOrNull;
      final name = me?.nom.trim();
      return l10n.selfChatTitle(
        name != null && name.isNotEmpty ? name : l10n.meLabel,
      );
    }
    final other = participants.where((u) => u.alanyaID != myId).firstOrNull;
    return other?.nom ?? l10n.unknownSender;
  }

  // Avatar à afficher
  String? displayAvatar(int myId) {
    if (isGroup) return groupPhoto;
    final source = isSelfChat(myId)
        ? participants.where((u) => u.alanyaID == myId).firstOrNull
        : participants.where((u) => u.alanyaID != myId).firstOrNull;
    return source?.user.avatarUrl;
  }

  /// Mon rôle dans ce groupe, en repli sur la liste des participants quand
  /// `myRole` n'est pas dans le payload (trame socket `conversation:updated`,
  /// qui omet volontairement les champs par-utilisateur).
  int roleOf(int userId) =>
      participants.where((p) => p.alanyaID == userId).firstOrNull?.role ??
      GroupRole.member;
}

// ── CALL ─────────────────────────────────────────────────────────────
// Table: callHistory
// PK: IDcall | idCaller | idReceiver | type | status | created_at | start_time | duree
// status: 0=en cours, 1=terminé, 2=rejeté, 3=manqué
// type: 0=audio, 1=vidéo

class Call {
  final int idCall;        // IDcall en DB
  final int idCaller;
  final int idReceiver;
  final int type;          // 0=audio, 1=vidéo
  final int status;        // 0=en cours,1=terminé,2=rejeté,3=manqué
  final String createdAt;
  final String? startTime;
  final int? duree;        // en secondes
  // Jointure users
  final User? caller;
  final User? receiver;

  Call({
    required this.idCall,
    required this.idCaller,
    required this.idReceiver,
    required this.type,
    required this.status,
    required this.createdAt,
    this.startTime,
    this.duree,
    this.caller,
    this.receiver,
  });

  factory Call.fromJson(Map<String, dynamic> json) => Call(
        idCall: json['IDcall'] ?? json['idCall'] ?? 0,
        idCaller: json['idCaller'] ?? 0,
        idReceiver: json['idReceiver'] ?? 0,
        type: json['type'] ?? 0,
        status: json['status'] ?? 0,
        createdAt: json['created_at'] ?? '',
        startTime: json['start_time'],
        duree: json['duree'],
        caller: json['caller_nom'] != null
            ? User.fromJson({
                'alanyaID': json['idCaller'],
                'nom': json['caller_nom'],
                'pseudo': json['caller_pseudo'] ?? '',
                'avatar_url': json['caller_avatar'] ?? '',
                'alanyaPhone': '',
                'email': '',
              })
            : null,
        receiver: json['receiver_nom'] != null
            ? User.fromJson({
                'alanyaID': json['idReceiver'],
                'nom': json['receiver_nom'],
                'pseudo': json['receiver_pseudo'] ?? '',
                'avatar_url': json['receiver_avatar'] ?? '',
                'alanyaPhone': '',
                'email': '',
              })
            : null,
      );

  bool get isVideo => type == 1;
  bool get isMissed => status == 3 || status == 2;
  bool get isOngoing => status == 0;

  String get statusLabel {
    switch (status) {
      case 0: return LocaleController.instance.l10n.inProgress;
      case 1: return LocaleController.instance.l10n.ended2;
      case 2: return LocaleController.instance.l10n.rejected;
      case 3: return LocaleController.instance.l10n.missed;
      default: return '';
    }
  }

  String get formattedDuration {
    if (duree == null) return '';
    final m = duree! ~/ 60;
    final s = duree! % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── MEETING ───────────────────────────────────────────────────────────
// Table: meeting
// PK: idMeeting | idOrganiser | start_time | duree | objet | room | isEnd | type_media
// Table: participant — idMeeting | IDparticipant | status | connecte | duree

class Meeting {
  final int idMeeting;
  final int idOrganiser;
  final String startTime;  // start_time en DB
  final int duree;         // en minutes
  final String objet;      // titre de la réunion
  final String room;       // code de la room
  final bool isEnd;
  final int typeMedia;     // 0=audio+vidéo, 1=audio only
  final bool reminderSent;
  // Jointure
  final String? organiserNom;
  final String? organiserPseudo;
  final String? organiserAvatar;
  final List<MeetingParticipant> participants;

  Meeting({
    required this.idMeeting,
    required this.idOrganiser,
    required this.startTime,
    required this.duree,
    required this.objet,
    required this.room,
    required this.isEnd,
    required this.typeMedia,
    required this.reminderSent,
    this.organiserNom,
    this.organiserPseudo,
    this.organiserAvatar,
    required this.participants,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
        idMeeting: json['idMeeting'] ?? 0,
        idOrganiser: json['idOrganiser'] ?? 0,
        startTime: json['start_time'] ?? '',
        duree: json['duree'] ?? 60,
        objet: json['objet'] ?? LocaleController.instance.l10n.meeting,
        room: json['room'] ?? '',
        isEnd: json['isEnd'] == 1 || json['isEnd'] == true,
        typeMedia: json['type_media'] ?? 0,
        reminderSent: json['reminder_sent'] == 1 || json['reminder_sent'] == true,
        organiserNom: json['organiser_nom'],
        organiserPseudo: json['organiser_pseudo'],
        organiserAvatar: normalizeBackendUrl(json['organiser_avatar']?.toString()),
        participants: (json['participants'] as List?)
                ?.map((e) => MeetingParticipant.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  DateTime get startDateTime {
    final dt = DateTime.tryParse(startTime) ?? DateTime.now();
    return dt.isUtc ? dt.toLocal() : dt;
  }
  DateTime get endDateTime => startDateTime.add(Duration(minutes: duree));
  bool get isToday {
    final now = DateTime.now();
    final d = startDateTime;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class MeetingParticipant {
  final int idMeeting;
  final int participantID; // IDparticipant en DB
  final int status;        // 0=pending,1=accepté,2=refusé
  final bool connecte;
  final int duree;
  // Jointure users
  final String? nom;
  final String? pseudo;
  final String? avatarUrl;
  final bool? isOnline;

  MeetingParticipant({
    required this.idMeeting,
    required this.participantID,
    required this.status,
    required this.connecte,
    required this.duree,
    this.nom,
    this.pseudo,
    this.avatarUrl,
    this.isOnline,
  });

  factory MeetingParticipant.fromJson(Map<String, dynamic> json) =>
      MeetingParticipant(
        idMeeting: json['idMeeting'] ?? 0,
        participantID: json['IDparticipant'] ?? 0,
        status: json['status'] ?? 0,
        connecte: json['connecte'] == 1 || json['connecte'] == true,
        duree: json['duree'] ?? 0,
        nom: json['nom'],
        pseudo: json['pseudo'],
        avatarUrl: normalizeBackendUrl(json['avatar_url']?.toString()),
        isOnline: json['is_online'] == 1 || json['is_online'] == true,
      );
}

// ── STATUT (stories) ─────────────────────────────────────────────────

class Statut {
  final int id;
  final int alanyaID;
  final int type; // 0=texte, 1=image, 2=vidéo, 3=audio
  final String? text;
  final String? mediaUrl;
  final int? mediaDurationMs;
  final String? backgroundColor;
  final String createdAt;
  final String expiredAt;
  final int viewedBy;
  final int likedBy;
  final bool likedByMe;
  final bool seenByMe;
  // Jointure users
  final String? nom;
  final String? pseudo;
  final String? avatarUrl;
  final bool? isOnline;

  Statut({
    required this.id,
    required this.alanyaID,
    required this.type,
    this.text,
    this.mediaUrl,
    this.mediaDurationMs,
    this.backgroundColor,
    required this.createdAt,
    required this.expiredAt,
    required this.viewedBy,
    this.likedBy = 0,
    this.likedByMe = false,
    this.seenByMe = false,
    this.nom,
    this.pseudo,
    this.avatarUrl,
    this.isOnline,
  });

  factory Statut.fromJson(Map<String, dynamic> json) => Statut(
        id: json['ID'] ?? 0,
        alanyaID: json['alanyaID'] ?? 0,
        type: json['type'] ?? 0,
        text: json['text'],
        mediaUrl: normalizeBackendUrl(json['mediaUrl']?.toString()),
        mediaDurationMs: json['mediaDurationMs'],
        backgroundColor: json['backgroundColor'],
        createdAt: json['createdAt'] ?? '',
        expiredAt: json['expiredAt'] ?? '',
        viewedBy: json['viewedBy'] ?? 0,
        likedBy: json['likedBy'] ?? 0,
        likedByMe: json['likedByMe'] == 1 || json['likedByMe'] == true,
        seenByMe: json['seenByMe'] == 1 || json['seenByMe'] == true,
        nom: json['nom'],
        pseudo: json['pseudo'],
        avatarUrl: normalizeBackendUrl(json['avatar_url']?.toString()),
        isOnline: json['is_online'] == 1 || json['is_online'] == true,
      );

  bool get isExpired =>
      DateTime.now().isAfter(DateTime.tryParse(expiredAt) ?? DateTime.now());

  Statut copyWith({
    int? viewedBy,
    int? likedBy,
    bool? likedByMe,
    bool? seenByMe,
  }) =>
      Statut(
        id: id,
        alanyaID: alanyaID,
        type: type,
        text: text,
        mediaUrl: mediaUrl,
        mediaDurationMs: mediaDurationMs,
        backgroundColor: backgroundColor,
        createdAt: createdAt,
        expiredAt: expiredAt,
        viewedBy: viewedBy ?? this.viewedBy,
        likedBy: likedBy ?? this.likedBy,
        likedByMe: likedByMe ?? this.likedByMe,
        seenByMe: seenByMe ?? this.seenByMe,
        nom: nom,
        pseudo: pseudo,
        avatarUrl: avatarUrl,
        isOnline: isOnline,
      );
}

// ── STATUT_VIEW (qui a vu/liké un statut) ─────────────────────────

class StatutView {
  final int statutID;
  final int alanyaID;
  final String nom;
  final String pseudo;
  final String? avatarUrl;
  final String seenAt;
  final bool liked;
  final String? likedAt;

  StatutView({
    required this.statutID,
    required this.alanyaID,
    required this.nom,
    required this.pseudo,
    this.avatarUrl,
    required this.seenAt,
    required this.liked,
    this.likedAt,
  });

  factory StatutView.fromJson(Map<String, dynamic> json) => StatutView(
        statutID: json['statutID'] ?? 0,
        alanyaID: json['alanyaID'] ?? 0,
        nom: json['nom'] ?? '',
        pseudo: json['pseudo'] ?? '',
        avatarUrl: normalizeBackendUrl(json['avatar_url']?.toString()),
        seenAt: json['seenAt'] ?? '',
        liked: json['liked'] == 1 || json['liked'] == true,
        likedAt: json['likedAt'],
      );

  StatutView copyWith({bool? liked, String? likedAt}) => StatutView(
        statutID: statutID,
        alanyaID: alanyaID,
        nom: nom,
        pseudo: pseudo,
        avatarUrl: avatarUrl,
        seenAt: seenAt,
        liked: liked ?? this.liked,
        likedAt: likedAt ?? this.likedAt,
      );
}

// ── PREFERRED CONTACT ────────────────────────────────────────────────

class PreferredContact {
  final int idPrefContact;
  final String addedAt;
  final int alanyaID;
  final String nom;
  final String pseudo;
  final String alanyaPhone;
  final String? avatarUrl;
  final bool isOnline;
  final String? lastSeen;

  PreferredContact({
    required this.idPrefContact,
    required this.addedAt,
    required this.alanyaID,
    required this.nom,
    required this.pseudo,
    required this.alanyaPhone,
    this.avatarUrl,
    required this.isOnline,
    this.lastSeen,
  });

  factory PreferredContact.fromJson(Map<String, dynamic> json) =>
      PreferredContact(
        idPrefContact: json['idPrefContact'] ?? 0,
        addedAt: json['addedAt'] ?? '',
        alanyaID: json['alanyaID'] ?? 0,
        nom: json['nom'] ?? '',
        pseudo: json['pseudo'] ?? '',
        alanyaPhone: json['alanyaPhone'] ?? '',
        avatarUrl: normalizeBackendUrl(json['avatar_url']?.toString()),
        isOnline: json['is_online'] == 1 || json['is_online'] == true,
        lastSeen: json['last_seen'],
      );
}

// ── SOCKET EVENTS ────────────────────────────────────────────────────
// Noms exacts utilisés par le backend Node.js

class SocketEvents {
  // Auth socket
  static const authLogin    = 'auth:login';
  static const authVerified = 'auth:verified';
  static const authError    = 'auth:error';
  static const authConflict = 'auth:conflict';

  // Présence
  static const presenceOnline   = 'presence:online';
  static const presenceOffline  = 'presence:offline';
  static const presenceUpdated  = 'presence:updated';

  // Chat
  static const joinConversation  = 'join_conversation';
  static const joinedConversation = 'joined_conversation';
  static const messageSend       = 'message:send';
  static const messageReceived   = 'message:received';
  static const messageSent       = 'message:sent';
  /// Échec d'envoi métier / validation (payload: clientId, code, message).
  static const messageSendFailed = 'message:send_failed';
  static const messageUpdated    = 'message:updated';
  static const messageDeleted    = 'message:deleted';
  static const messagesDeleted   = 'messages:deleted';
  static const messagePinned     = 'message:pinned';
  static const messageViewed     = 'message:viewed';
  /// Réaction posée/retirée sur un message. Payload : { msgID, conversationID,
  /// userID, emoji }. `emoji` absent/vide = réaction retirée.
  static const messageReaction   = 'message:reaction';
  static const messageDelivered  = 'message:delivered';
  static const messageRead       = 'message:read';
  static const messageStatus     = 'message:status';
  /// Sync badge non-lus entre appareils du même compte (local uniquement).
  static const inboxSync         = 'inbox:sync';
  /// Réservé au cas « je n'avais pas cette conversation » : 1-1, création de
  /// groupe, membre ajouté. N'est plus un upsert générique.
  static const conversationCreated = 'conversation:created';

  /// Métadonnées de conversation modifiées (nom, photo, description, rôles,
  /// réglages). La charge omet volontairement les champs par-utilisateur
  /// (`unreadCount`, `isPinned`, `isArchived`, `lastMessage*`) : les écraser
  /// avec une trame tardive ferait réapparaître un badge fantôme.
  static const conversationUpdated = 'conversation:updated';

  /// Un membre a quitté ou a été retiré. Indispensable en plus de
  /// `conversation:updated` : l'exclu n'est plus dans la liste de diffusion de
  /// ce dernier et n'apprendrait jamais son exclusion.
  static const groupParticipantRemoved = 'group:participant:removed';

  static const typingStart       = 'typing:start';
  static const typingStop        = 'typing:stop';
  static const typingStarted     = 'typing:started';
  static const typingStopped     = 'typing:stopped';

  // Appels 1-1 (Flutter → Backend)
  static const callUser    = 'call_user';
  static const answerCall  = 'answer_call';
  static const rejectCall  = 'reject_call';
  static const iceCandidate = 'ice_candidate';
  static const endCall     = 'end_call';
  static const callRejoin  = 'call_rejoin';
  static const callRejoinAnswer = 'call_rejoin_answer';

  // Appels 1-1 (Backend → Flutter)
  static const incomingCall  = 'incoming_call';
  static const callAnswered  = 'call_answered';
  static const callRejected  = 'call_rejected';
  static const callEnded     = 'call_ended';
  static const callFailed    = 'call_failed';
  static const callBusy      = 'call_busy';       // cible occupée (ringing/in_call)
  static const callNoAnswer  = 'call_no_answer';  // timeout serveur sans réponse
  static const callResume    = 'call_resume';
  static const callRejoinOffer = 'call_rejoin_offer';
  static const callLogUpdated = 'call_log_updated';

  // Appels groupe (Flutter → Backend)
  static const createGroupCall    = 'create_group_call';
  static const joinGroupCall      = 'join_group_call';
  static const leaveGroupCall     = 'leave_group_call';
  static const endGroupCall       = 'end_group_call';
  static const groupOffer         = 'group_offer';
  static const groupAnswer        = 'group_answer';
  static const groupIceCandidate  = 'group_ice_candidate';

  // Appels groupe (Backend → Flutter)
  static const groupCallInvite    = 'group_call_invite';
  static const groupUserJoined    = 'group_user_joined';
  static const groupParticipants  = 'group_participants';
  static const groupCallEnded     = 'group_call_ended';
  static const groupUserLeft      = 'group_user_left';

  // Mute state (Flutter ↔ Backend ↔ Flutter)
  static const callMuteState      = 'call:mute_state';
  static const groupMuteState     = 'group:mute_state';
  static const callVideoState     = 'call:video_state';
  static const groupVideoState    = 'group:video_state';
  static const meetingMuteState   = 'meeting:mute_state';
  static const meetingVideoState  = 'meeting:video_state';

  // Meetings (Flutter → Backend)
  static const meetingCreate      = 'meeting:create';
  static const meetingJoinRoom    = 'meeting:join_room';
  static const meetingJoinRequest   = 'meeting:join_request';
  static const meetingJoinRequested = 'meeting:join_requested';
  static const meetingJoinAccept    = 'meeting:join_accept';
  static const meetingJoinDecline = 'meeting:join_decline';
  static const meetingStart       = 'meeting:start';
  static const meetingEnd         = 'meeting:end';
  static const meetingLeave       = 'meeting:leave';
  static const meetingChat        = 'meeting:chat';
  static const meetingOffer       = 'meeting:offer';
  static const meetingAnswer      = 'meeting:answer';
  static const meetingIceCandidate = 'meeting:ice_candidate';

  // Meetings (Backend → Flutter)
  static const meetingCreated     = 'meeting:created';
  static const meetingRoomJoined  = 'meeting:room_joined';
  static const meetingUserJoined  = 'meeting:user_joined';
  static const meetingUserLeft    = 'meeting:user_left';
  static const meetingAccepted    = 'meeting:accepted';
  static const meetingDeclined    = 'meeting:declined';
  static const meetingStarted     = 'meeting:started';
  static const meetingEnded       = 'meeting:ended';
  static const meetingMessage     = 'meeting:message';

  // Statuts (Backend → Flutter)
  static const statusCreated  = 'status:created';
  static const statusViewed   = 'status:viewed';
  static const statusLiked    = 'status:liked';
  static const statusUnliked  = 'status:unliked';
  static const statusDeleted  = 'status:deleted';
}