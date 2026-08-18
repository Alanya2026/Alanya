// talky_models.dart — aligné avec la DB Alanya réelle
// Champs mappés exactement sur les colonnes MySQL

import 'core/utils/backend_url.dart';
import 'core/utils/contact_payload.dart';
import 'core/utils/location_payload.dart';
import 'core/theme/locale_controller.dart';
import 'core/utils/self_chat.dart';
import 'core/utils/welcome_cta_payload.dart';

// ── USER ─────────────────────────────────────────────────────────────

/// MySQL renvoie les entiers tantôt en `int`, tantôt en chaîne selon le driver
/// et le type de colonne (TINYINT/SMALLINT UNSIGNED notamment) ; le cache local
/// les relit ensuite depuis du JSON. Un seul point de conversion évite d'avoir
/// à s'en soucier partout.
int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class User {
  final int alanyaID;
  final String nom;
  final String pseudo;
  final String alanyaPhone;
  final String email;
  final int idPays;
  final String avatarUrl;
  final String bio;
  final int typeCompte;
  /// Genre de compte : 0 personnel, 1 business, 2 officiel (`users.account_type`).
  final int accountType;
  /// État de certification : 2 = vérifié (`users.verification_status`).
  final int verificationStatus;
  /// Fin de validité de la certification (`users.verified_until`).
  final String? verifiedUntil;
  final bool isOnline;
  final String lastSeen;
  /// Vrai si ce contact préféré a été ajouté par code QR (scan ou lien).
  /// Donnée de RELATION, pas d'identité — et nullable à dessein : null veut
  /// dire « la source ne portait pas cette information » (recherche,
  /// instantané d'appel), et le cache ne doit alors PAS écraser sa valeur.
  final bool? addedViaQr;

  /// Date d'ajout en contact préféré (`addedAt` du serveur). Même règle de
  /// nullité que [addedViaQr].
  final DateTime? preferredAddedAt;

  /// Note contextuelle de la relation (`addedNote` du serveur). Null = la
  /// source ne portait pas la relation ; chaîne vide = pas de note (connue).
  final String? preferredNote;

  /// Genre déclaré : `homme` | `femme` | `autre` | `non_precise`. Null = pas
  /// encore renseigné, ce qui est distinct de `non_precise` (« je préfère ne pas
  /// dire »), qui est une réponse. Non modifiable une fois posé.
  final String? genre;

  /// Âge déclaré à l'onboarding. Non modifiable une fois posé.
  final int? age;

  /// Année de naissance approximative, DÉDUITE de [age] par le serveur.
  final int? anneeNaissance;

  /// Ville déduite de l'adresse IP côté serveur — jamais saisie par
  /// l'utilisateur, et souvent null (IP privée, fournisseur indisponible).
  final String? ville;

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
    this.bio = '',
    required this.typeCompte,
    this.accountType = 0,
    this.verificationStatus = 0,
    this.verifiedUntil,
    required this.isOnline,
    required this.lastSeen,
    this.addedViaQr,
    this.preferredAddedAt,
    this.preferredNote,
    this.genre,
    this.age,
    this.anneeNaissance,
    this.ville,
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
        avatarUrl: normalizeAvatarUrl(json['avatar_url']?.toString()),
        bio: json['bio']?.toString() ?? '',
        typeCompte: json['type_compte'] ?? 0,
        accountType: _asInt(json['account_type']) ?? 0,
        verificationStatus: _asInt(json['verification_status']) ?? 0,
        verifiedUntil: json['verified_until']?.toString(),
        isOnline: json['is_online'] == 1 || json['is_online'] == true,
        lastSeen: json['last_seen'] ?? '',
        addedViaQr:
            json.containsKey('addedVia') ? json['addedVia'] == 'qr' : null,
        preferredAddedAt: json['addedAt'] != null
            ? DateTime.tryParse(json['addedAt'].toString())
            : null,
        preferredNote: json.containsKey('addedNote')
            ? (json['addedNote']?.toString() ?? '')
            : null,
        genre: json['genre']?.toString(),
        age: _asInt(json['age']),
        anneeNaissance: _asInt(json['annee_naissance']),
        ville: json['ville']?.toString(),
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
        'bio': bio,
        'type_compte': typeCompte,
        'account_type': accountType,
        'verification_status': verificationStatus,
        if (verifiedUntil != null) 'verified_until': verifiedUntil,
        'is_online': isOnline,
        'last_seen': lastSeen,
        'genre': genre,
        'age': age,
        'annee_naissance': anneeNaissance,
        'ville': ville,
        'pays_libelle': paysLibelle,
        'exclus': exclus,
        'exclude_at': excludeAt,
        'exclude_reason': excludeReason,
        'created_at': createdAt,
      };
}

// ── ACCOUNT LIFECYCLE ────────────────────────────────────────────────

class AccountDeletionSchedule {
  final DateTime scheduledAt;
  final int graceDays;

  const AccountDeletionSchedule({
    required this.scheduledAt,
    required this.graceDays,
  });

  factory AccountDeletionSchedule.fromJson(Map<String, dynamic> json) {
    final raw = json['scheduledAt']?.toString();
    return AccountDeletionSchedule(
      scheduledAt: raw != null
          ? (DateTime.tryParse(raw) ?? DateTime.now())
          : DateTime.now(),
      graceDays: json['graceDays'] is int
          ? json['graceDays'] as int
          : int.tryParse(json['graceDays']?.toString() ?? '') ?? 7,
    );
  }
}

class MyMediaItem {
  final int msgID;
  final int conversationID;
  final int type;
  final String mediaUrl;
  final String? mediaName;
  final DateTime? sendAt;

  const MyMediaItem({
    required this.msgID,
    required this.conversationID,
    required this.type,
    required this.mediaUrl,
    this.mediaName,
    this.sendAt,
  });

  factory MyMediaItem.fromJson(Map<String, dynamic> json) => MyMediaItem(
        msgID: json['msgID'] is int
            ? json['msgID'] as int
            : int.tryParse(json['msgID']?.toString() ?? '') ?? 0,
        conversationID: json['conversationID'] is int
            ? json['conversationID'] as int
            : int.tryParse(json['conversationID']?.toString() ?? '') ?? 0,
        type: json['type'] is int
            ? json['type'] as int
            : int.tryParse(json['type']?.toString() ?? '') ?? 0,
        mediaUrl: json['mediaUrl']?.toString() ?? '',
        mediaName: json['mediaName']?.toString(),
        sendAt: json['sendAt'] != null
            ? DateTime.tryParse(json['sendAt'].toString())
            : null,
      );

  bool get isVideo => type == 2;
}

class MyMediaPage {
  final List<MyMediaItem> items;
  final int? nextCursor;

  const MyMediaPage({required this.items, this.nextCursor});

  factory MyMediaPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => MyMediaItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MyMediaItem>[];
    final nc = json['nextCursor'];
    return MyMediaPage(
      items: list,
      nextCursor: nc == null
          ? null
          : (nc is int ? nc : int.tryParse(nc.toString())),
    );
  }
}

// ── PRIVACY PREFS ────────────────────────────────────────────────────
// Table: user_privacy_prefs (migration 031)

abstract final class PrivacyVisibility {
  static const everyone = 'everyone';
  static const contacts = 'contacts';
  static const nobody = 'nobody';
}

abstract final class NotificationPreviewMode {
  static const full = 'full';
  static const nameOnly = 'name_only';
  static const generic = 'generic';
}

class PrivacyPrefs {
  final String lastSeenVisibility;
  final String onlineVisibility;
  final bool readReceiptsEnabled;
  final String profilePhotoVisibility;
  final String addMePolicy;
  final String previewMode;

  const PrivacyPrefs({
    this.lastSeenVisibility = PrivacyVisibility.everyone,
    this.onlineVisibility = PrivacyVisibility.everyone,
    this.readReceiptsEnabled = true,
    this.profilePhotoVisibility = PrivacyVisibility.everyone,
    this.addMePolicy = PrivacyVisibility.everyone,
    this.previewMode = NotificationPreviewMode.full,
  });

  factory PrivacyPrefs.fromJson(Map<String, dynamic> json) => PrivacyPrefs(
        lastSeenVisibility:
            json['lastSeenVisibility']?.toString() ?? PrivacyVisibility.everyone,
        onlineVisibility:
            json['onlineVisibility']?.toString() ?? PrivacyVisibility.everyone,
        readReceiptsEnabled: json['readReceiptsEnabled'] == true ||
            json['readReceiptsEnabled'] == 1,
        profilePhotoVisibility: json['profilePhotoVisibility']?.toString() ??
            PrivacyVisibility.everyone,
        addMePolicy:
            json['addMePolicy']?.toString() ?? PrivacyVisibility.everyone,
        previewMode:
            json['previewMode']?.toString() ?? NotificationPreviewMode.full,
      );

  Map<String, dynamic> toJson() => {
        'lastSeenVisibility': lastSeenVisibility,
        'onlineVisibility': onlineVisibility,
        'readReceiptsEnabled': readReceiptsEnabled,
        'profilePhotoVisibility': profilePhotoVisibility,
        'addMePolicy': addMePolicy,
        'previewMode': previewMode,
      };

  PrivacyPrefs copyWith({
    String? lastSeenVisibility,
    String? onlineVisibility,
    bool? readReceiptsEnabled,
    String? profilePhotoVisibility,
    String? addMePolicy,
    String? previewMode,
  }) =>
      PrivacyPrefs(
        lastSeenVisibility: lastSeenVisibility ?? this.lastSeenVisibility,
        onlineVisibility: onlineVisibility ?? this.onlineVisibility,
        readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
        profilePhotoVisibility:
            profilePhotoVisibility ?? this.profilePhotoVisibility,
        addMePolicy: addMePolicy ?? this.addMePolicy,
        previewMode: previewMode ?? this.previewMode,
      );
}

// ── APP SETTINGS ─────────────────────────────────────────────────────
// Table: user_settings (migration 032)

abstract final class AppThemeMode {
  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';
}

class AppSettings {
  final String themeMode;
  final String locale;
  final double playbackSpeedVoice;
  final double playbackSpeedVideo;
  final double playbackSpeedMusic;
  final bool reduceMotion;
  final double fontScale;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.locale = 'fr',
    this.playbackSpeedVoice = 1.0,
    this.playbackSpeedVideo = 1.0,
    this.playbackSpeedMusic = 1.0,
    this.reduceMotion = false,
    this.fontScale = 1.0,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: json['themeMode']?.toString() ?? AppThemeMode.system,
        locale: json['locale']?.toString() ?? 'fr',
        playbackSpeedVoice:
            _toDouble(json['playbackSpeedVoice'], fallback: 1.0),
        playbackSpeedVideo:
            _toDouble(json['playbackSpeedVideo'], fallback: 1.0),
        playbackSpeedMusic:
            _toDouble(json['playbackSpeedMusic'], fallback: 1.0),
        reduceMotion: json['reduceMotion'] == true || json['reduceMotion'] == 1,
        fontScale: _toDouble(json['fontScale'], fallback: 1.0),
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'locale': locale,
        'playbackSpeedVoice': playbackSpeedVoice,
        'playbackSpeedVideo': playbackSpeedVideo,
        'playbackSpeedMusic': playbackSpeedMusic,
        'reduceMotion': reduceMotion,
        'fontScale': fontScale,
      };

  AppSettings copyWith({
    String? themeMode,
    String? locale,
    double? playbackSpeedVoice,
    double? playbackSpeedVideo,
    double? playbackSpeedMusic,
    bool? reduceMotion,
    double? fontScale,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
        playbackSpeedVoice: playbackSpeedVoice ?? this.playbackSpeedVoice,
        playbackSpeedVideo: playbackSpeedVideo ?? this.playbackSpeedVideo,
        playbackSpeedMusic: playbackSpeedMusic ?? this.playbackSpeedMusic,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        fontScale: fontScale ?? this.fontScale,
      );
}

double _toDouble(dynamic value, {required double fallback}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

// ── DND SCHEDULE ─────────────────────────────────────────────────────
// Table: user_dnd_schedule (migration 033) — bit0=lundi … bit6=dimanche

class DndSchedule {
  final bool enabled;
  final String startTime;
  final String endTime;
  final int daysBitmask;

  const DndSchedule({
    this.enabled = false,
    this.startTime = '22:00',
    this.endTime = '07:00',
    this.daysBitmask = 127,
  });

  factory DndSchedule.fromJson(Map<String, dynamic> json) => DndSchedule(
        enabled: json['enabled'] == true || json['enabled'] == 1,
        startTime: json['startTime']?.toString() ?? '22:00',
        endTime: json['endTime']?.toString() ?? '07:00',
        daysBitmask: json['daysBitmask'] is int
            ? json['daysBitmask'] as int
            : int.tryParse(json['daysBitmask']?.toString() ?? '') ?? 127,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startTime': startTime,
        'endTime': endTime,
        'daysBitmask': daysBitmask,
      };

  bool isDayEnabled(int mondayBasedIndex) {
    if (mondayBasedIndex < 0 || mondayBasedIndex > 6) return false;
    return (daysBitmask & (1 << mondayBasedIndex)) != 0;
  }

  DndSchedule copyWith({
    bool? enabled,
    String? startTime,
    String? endTime,
    int? daysBitmask,
  }) =>
      DndSchedule(
        enabled: enabled ?? this.enabled,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        daysBitmask: daysBitmask ?? this.daysBitmask,
      );
}

// ── EXPORT JOB ───────────────────────────────────────────────────────
// Table: user_export_jobs (migration 034)

abstract final class ExportJobStatus {
  static const pending = 'pending';
  static const processing = 'processing';
  static const ready = 'ready';
  static const failed = 'failed';
}

class ExportJob {
  final int jobId;
  final String status;
  final bool? includeMessages;
  final String? errorMessage;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? downloadUrl;

  const ExportJob({
    required this.jobId,
    required this.status,
    this.includeMessages,
    this.errorMessage,
    this.expiresAt,
    this.createdAt,
    this.completedAt,
    this.downloadUrl,
  });

  bool get isPending =>
      status == ExportJobStatus.pending || status == ExportJobStatus.processing;

  bool get isReady => status == ExportJobStatus.ready;

  bool get isFailed => status == ExportJobStatus.failed;

  factory ExportJob.fromJson(Map<String, dynamic> json) {
    final jobId = json['jobId'] is int
        ? json['jobId'] as int
        : int.tryParse(json['jobId']?.toString() ?? '') ??
            int.tryParse(json['id']?.toString() ?? '') ??
            0;
    final status = json['status']?.toString() ?? ExportJobStatus.pending;
    return ExportJob(
      jobId: jobId,
      status: status,
      includeMessages: json['includeMessages'] == true ||
          json['includeMessages'] == 1,
      errorMessage: json['errorMessage']?.toString() ?? json['error']?.toString(),
      expiresAt: _parseDateTime(json['expiresAt']),
      createdAt: _parseDateTime(json['createdAt']),
      completedAt: _parseDateTime(json['completedAt']),
      downloadUrl: json['downloadUrl']?.toString(),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
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
    if (type == kWelcomeCtaMessageType) {
      final cta = WelcomeCtaPayload.tryParse(content);
      if (cta != null && cta.buttons.isNotEmpty) {
        return cta.buttons.map((b) => b.label).join(' · ');
      }
      return LocaleController.instance.l10n.discussionFallback;
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
  int get accountType => user.accountType;
  int get verificationStatus => user.verificationStatus;
  String? get verifiedUntil => user.verifiedUntil;

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
  final bool hideHistoryForNewMembers;
  final bool onlyAdminsCanAddMembers;
  // conv_participants
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final int myRole;
  final String? mutedUntil;
  final bool muteForever;
  final bool mentionsOnly;
  /// msgID système en attente d'ack « Rester » (null = bannière absente).
  final int? myPendingJoinMsgID;
  /// Borne d'historique pour le viewer (ISO) — null = historique complet.
  final String? myHistoryCutoffAt;
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
    this.hideHistoryForNewMembers = false,
    this.onlyAdminsCanAddMembers = false,
    required this.unreadCount,
    required this.isPinned,
    required this.isArchived,
    this.myRole = GroupRole.member,
    this.mutedUntil,
    this.muteForever = false,
    this.mentionsOnly = false,
    this.myPendingJoinMsgID,
    this.myHistoryCutoffAt,
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
        hideHistoryForNewMembers: _flag(json['hideHistoryForNewMembers']),
        onlyAdminsCanAddMembers: _flag(json['onlyAdminsCanAddMembers']),
        unreadCount: json['unreadCount'] ?? 0,
        isPinned: _flag(json['isPinned']),
        isArchived: _flag(json['isArchived']),
        myRole: (json['myRole'] as num?)?.toInt() ?? GroupRole.member,
        mutedUntil: json['mutedUntil']?.toString(),
        muteForever: _flag(json['muteForever']),
        mentionsOnly: _flag(json['mentionsOnly']),
        myPendingJoinMsgID: (json['myPendingJoinMsgID'] as num?)?.toInt(),
        myHistoryCutoffAt: json['myHistoryCutoffAt']?.toString(),
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
  final String? textEn;
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
  final int? accountType;
  final int? verificationStatus;

  Statut({
    required this.id,
    required this.alanyaID,
    required this.type,
    this.text,
    this.textEn,
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
    this.accountType,
    this.verificationStatus,
  });

  factory Statut.fromJson(Map<String, dynamic> json) => Statut(
        id: json['ID'] ?? 0,
        alanyaID: json['alanyaID'] ?? 0,
        type: json['type'] ?? 0,
        text: json['text'],
        textEn: json['text_en'] ?? json['textEn'],
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
        accountType: _asInt(json['account_type']),
        verificationStatus: _asInt(json['verification_status']),
      );

  bool get isExpired =>
      DateTime.now().isAfter(DateTime.tryParse(expiredAt) ?? DateTime.now());

  /// Texte affiché selon la langue (EN si disponible, sinon FR).
  String? localizedText(String languageCode) {
    if (languageCode.startsWith('en') &&
        textEn != null &&
        textEn!.trim().isNotEmpty) {
      return textEn;
    }
    return text;
  }

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
        textEn: textEn,
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
        accountType: accountType,
        verificationStatus: verificationStatus,
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

// ── CONTACT LIST ─────────────────────────────────────────────────────

/// Liste nommée de contacts préférés (Famille, Amis, Bureau…).
///
/// Ne porte que l'entête : les membres se lisent séparément
/// (`GET /contact-lists/:id/members`) et sont hydratés en [User], comme les
/// contacts préférés.
class ContactList {
  final int idList;
  final String name;

  /// `family` | `friends` | `work` | `trust` pour les listes système.
  final String? kind;

  /// Teinte de la puce (`#RRGGBB`), null = teinte du thème.
  final String? color;
  final int? memberLimit;
  final int memberCount;

  /// Sonneries de la liste, **préférence du compte** partagée par tous les
  /// appareils (migration serveur 055). `builtin` = son fourni avec l'app,
  /// identifié par son id stable ; `custom` = son importé par l'utilisateur,
  /// identifié par le SHA-256 de son CONTENU — le fichier audio, lui, ne
  /// quitte jamais l'appareil. Null = liste jamais configurée, à distinguer de
  /// « sonnerie système », qui vaut builtin/`__system_default__`.
  ///
  /// Appliquées localement par `ListRingtonePreferences.applyFromServer`.
  final String? messageSoundType;
  final String? messageSoundId;

  /// Nom du fichier importé — **affichage uniquement**. Deux fichiers de même
  /// nom mais de contenu différent restent deux sons différents : seul
  /// [messageSoundId] (le hash) fait foi.
  final String? messageSoundName;

  final String? callSoundType;
  final String? callSoundId;
  final String? callSoundName;

  /// Rang de la liste quand un contact appartient à plusieurs listes : la
  /// première l'emporte. Null = jamais ordonnée (passe après les autres).
  final int? soundPriority;

  /// La réponse du serveur portait-elle les champs de son ?
  ///
  /// Sert à distinguer « le compte n'a aucune sonnerie pour cette liste » d'un
  /// **serveur pas encore à jour** (migration 055 non appliquée) : dans le
  /// second cas les champs sont simplement absents, et effacer les réglages
  /// locaux là-dessus reviendrait à perdre le choix de l'utilisateur.
  final bool soundSyncSupported;

  ContactList({
    required this.idList,
    required this.name,
    this.kind,
    this.color,
    this.memberLimit,
    this.memberCount = 0,
    this.messageSoundType,
    this.messageSoundId,
    this.messageSoundName,
    this.callSoundType,
    this.callSoundId,
    this.callSoundName,
    this.soundPriority,
    this.soundSyncSupported = false,
  });

  factory ContactList.fromJson(Map<String, dynamic> json) => ContactList(
        idList: (json['idList'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        kind: _nullableContactListKind(json['kind']),
        color: (json['color']?.toString().isEmpty ?? true)
            ? null
            : json['color'].toString(),
        memberLimit: (json['memberLimit'] as num?)?.toInt(),
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
        messageSoundType: _nonEmpty(json['messageSoundType']),
        messageSoundId: _nonEmpty(json['messageSoundId']),
        messageSoundName: _nonEmpty(json['messageSoundName']),
        callSoundType: _nonEmpty(json['callSoundType']),
        callSoundId: _nonEmpty(json['callSoundId']),
        callSoundName: _nonEmpty(json['callSoundName']),
        soundPriority: (json['soundPriority'] as num?)?.toInt(),
        soundSyncSupported: json.containsKey('messageSoundType') ||
            json.containsKey('callSoundType') ||
            json.containsKey('soundPriority'),
      );

  Map<String, dynamic> toJson() => {
        'idList': idList,
        'name': name,
        'kind': kind,
        'color': color,
        'memberLimit': memberLimit,
        'memberCount': memberCount,
        'messageSoundType': messageSoundType,
        'messageSoundId': messageSoundId,
        'messageSoundName': messageSoundName,
        'callSoundType': callSoundType,
        'callSoundId': callSoundId,
        'callSoundName': callSoundName,
        'soundPriority': soundPriority,
      };
}

String? _nonEmpty(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

String? _nullableContactListKind(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  return s.isEmpty ? null : s;
}

// ── TRAJETS DE CONFIANCE ─────────────────────────────────────────────

/// États d'un trajet, dans l'ordre du cycle de vie — mêmes libellés que
/// l'`ENUM` de `trip.state` (migration serveur 051).
abstract final class TripState {
  static const active = 'active';
  static const awaitingConfirm = 'awaiting_confirm';
  static const alert = 'alert';
  static const sos = 'sos';
  static const closedConfirmed = 'closed_confirmed';
  static const closedCancelled = 'closed_cancelled';
  static const closedExpired = 'closed_expired';
  static const closedUnwatched = 'closed_unwatched';

  static const open = {active, awaitingConfirm, alert, sos};

  /// Rouge à l'écran, et seuls états où le cercle a été prévenu.
  static const alerting = {alert, sos};

  static bool isOpen(String s) => open.contains(s);
  static bool isAlerting(String s) => alerting.contains(s);
}

/// Verdict de la dernière synchronisation d'un trajet.
///
/// Le serveur répond **404 indifférencié** à qui n'est plus destinataire, et
/// c'est délibéré : personne ne doit apprendre qu'un trajet existe encore, ni
/// pourquoi il n'y a plus accès. Le client ne peut donc pas distinguer
/// « révoqué » de « trajet inconnu ».
///
/// Il doit en revanche distinguer **« plus accessible »** de **« réseau
/// coupé »** : la première appelle une pierre tombale, la seconde un bouton
/// « Réessayer ». Confondre les deux produit un tourniquet sans fin, l'état le
/// plus désagréable de tous — on ne sait pas s'il faut attendre.
enum TripAccess {
  /// Aucune synchronisation n'a encore abouti ni échoué.
  inconnu,

  /// Le trajet est accessible.
  ok,

  /// 404 : révoqué, clos et purgé, ou jamais destinataire. Sans distinction.
  plusPartage,

  /// Réseau ou serveur indisponible. Réessayer a du sens.
  injoignable,
}

/// Clôture vue par un membre pendant qu'il suivait — conservée en mémoire
/// après [TripRepository.forget], pour l'écran de fin (pas d'historique).
class TripCloseInfo {
  const TripCloseInfo({required this.state, required this.ownerId});

  final String state;
  final int ownerId;

  bool get arrivedSafely => state == TripState.closedConfirmed;
}

abstract final class TripKind {
  static const taxi = 'taxi';
  static const walk = 'walk';

  /// Alias historique (« rendez-vous ») — normalisé en [walk].
  static const meeting = 'meeting';
  static const sos = 'sos';

  /// `taxi` reste taxi ; tout le reste (walk, meeting, sos, inconnu) → walk
  /// pour le filtre GPS. Le SOS bascule vite en régime alerte côté cadence.
  static String normalize(String? raw) {
    if (raw == taxi) return taxi;
    return walk;
  }
}

/// Une position d'un trajet.
///
/// [recordedAt] est l'heure de **capture**, pas de réception : c'est elle qu'on
/// affiche (« maj il y a 8 s »). Un point renvoyé par le battement porte un
/// horodatage ancien alors qu'il vient d'arriver — c'est précisément ce qui
/// distingue « immobile » de « traceur mort ».
class TripPoint {
  final double lat;
  final double lng;
  final int? accuracyM;
  final int? batteryPct;
  final DateTime recordedAt;

  const TripPoint({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.accuracyM,
    this.batteryPct,
  });

  /// Une position trop imprécise reste affichable — grisée, avec son cercle de
  /// précision — mais ne doit jamais servir à décider d'une arrivée.
  bool get isReliable => accuracyM == null || accuracyM! <= 100;

  static TripPoint? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    final at = DateTime.tryParse(raw['recordedAt']?.toString() ?? '');
    if (lat == null || lng == null || at == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return TripPoint(
      lat: lat,
      lng: lng,
      recordedAt: at.toLocal(),
      accuracyM: (raw['accuracyM'] as num?)?.toInt(),
      batteryPct: (raw['batteryPct'] as num?)?.toInt(),
    );
  }
}

/// Un trajet de confiance.
///
/// Le même objet sert des deux côtés : [isOwner] distingue « le trajet que je
/// partage » de « celui que je suis ». Côté membre, [watchers] est toujours
/// vide et seul [watcherCount] est renseigné — les identités des autres
/// destinataires ne sortent jamais du serveur.
class Trip {
  final int id;
  final int ownerId;
  final String kind;
  final String state;
  final DateTime? etaAt;
  final int graceMinutes;
  final int extensions;
  final String? note;
  final String? destLabel;

  /// Coordonnées de la destination et rayon d'arrivée, quand une destination a
  /// été déclarée. Le serveur les renvoie dans `destination` ; l'écran de suivi
  /// s'en sert pour dessiner le but et son cercle.
  final double? destLat;
  final double? destLng;
  final int? destRadiusM;

  final TripPoint? lastPoint;
  final bool stale;
  final DateTime startedAt;

  /// Horodatage de l'alerte, s'il y en a eu une. Non nul ⇒ le cercle a été
  /// prévenu, ce qui déclenche aussi le verrou de suppression de 30 jours.
  final DateTime? alertedAt;
  final DateTime? closedAt;
  final String? closeReason;
  final bool isOwner;
  final int watcherCount;

  /// Destinataires qui ont ouvert le suivi (`seen_at`). Null si non fourni
  /// (réponse ancienne / trajet live sans ce champ).
  final int? watchersSeenCount;
  final List<TripWatcher> watchers;

  const Trip({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.state,
    required this.startedAt,
    this.alertedAt,
    this.etaAt,
    this.graceMinutes = 10,
    this.extensions = 0,
    this.note,
    this.destLabel,
    this.destLat,
    this.destLng,
    this.destRadiusM,
    this.lastPoint,
    this.stale = false,
    this.closedAt,
    this.closeReason,
    this.isOwner = false,
    this.watcherCount = 0,
    this.watchersSeenCount,
    this.watchers = const [],
  });

  bool get isOpen => TripState.isOpen(state);
  bool get isAlerting => TripState.isAlerting(state);

  /// Heure à laquelle le cercle sera prévenu si rien n'est confirmé. C'est la
  /// phrase du contrat affichée au départ — jamais déduite, toujours calculée
  /// à partir des valeurs que le serveur a figées dans le trajet.
  DateTime? get alertAt =>
      etaAt?.add(Duration(minutes: graceMinutes));

  factory Trip.fromJson(Map<String, dynamic> json, {bool? isOwner}) {
    final dest = json['destination'];
    return Trip(
      id: (json['id'] as num?)?.toInt() ?? 0,
      ownerId: (json['ownerId'] as num?)?.toInt() ?? 0,
      kind: json['kind']?.toString() ?? TripKind.taxi,
      state: json['state']?.toString() ?? TripState.active,
      etaAt: DateTime.tryParse(json['etaAt']?.toString() ?? '')?.toLocal(),
      graceMinutes: (json['graceMinutes'] as num?)?.toInt() ?? 10,
      extensions: (json['extensions'] as num?)?.toInt() ?? 0,
      note: (json['note']?.toString().isEmpty ?? true)
          ? null
          : json['note'].toString(),
      destLabel: dest is Map ? dest['label']?.toString() : null,
      destLat: dest is Map ? (dest['lat'] as num?)?.toDouble() : null,
      destLng: dest is Map ? (dest['lng'] as num?)?.toDouble() : null,
      destRadiusM: dest is Map ? (dest['radiusM'] as num?)?.toInt() : null,
      lastPoint: TripPoint.tryParse(json['lastPoint']),
      stale: json['stale'] == true,
      startedAt:
          DateTime.tryParse(json['startedAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      alertedAt:
          DateTime.tryParse(json['alertedAt']?.toString() ?? '')?.toLocal(),
      closedAt: DateTime.tryParse(json['closedAt']?.toString() ?? '')?.toLocal(),
      closeReason: json['closeReason']?.toString(),
      isOwner: isOwner ?? false,
      watcherCount: (json['watcherCount'] as num?)?.toInt() ??
          (json['watchers'] is List ? (json['watchers'] as List).length : 0),
      watchersSeenCount: (json['watchersSeenCount'] as num?)?.toInt() ??
          (json['watchers'] is List
              ? (json['watchers'] as List)
                  .whereType<Map>()
                  .where((w) => w['seenAt'] != null)
                  .length
              : null),
      watchers: json['watchers'] is List
          ? (json['watchers'] as List)
              .whereType<Map>()
              .map((w) => TripWatcher.fromJson(w.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// Un destinataire d'un trajet. Visible du propriétaire seul.
class TripWatcher {
  final int alanyaID;
  final String nom;
  final String? avatarUrl;

  /// « Maman a vu » — le seul retour qu'un destinataire puisse donner.
  final DateTime? seenAt;

  const TripWatcher({
    required this.alanyaID,
    required this.nom,
    this.avatarUrl,
    this.seenAt,
  });

  factory TripWatcher.fromJson(Map<String, dynamic> json) => TripWatcher(
        alanyaID: (json['alanyaID'] as num?)?.toInt() ?? 0,
        nom: json['nom']?.toString() ?? '',
        avatarUrl: json['avatarUrl']?.toString(),
        seenAt: DateTime.tryParse(json['seenAt']?.toString() ?? '')?.toLocal(),
      );
}

/// Cadence GPS servie par le serveur.
///
/// ⚠ Ces valeurs ne doivent **jamais** être codées en dur : la cadence
/// s'exécute sur le téléphone, et la régler imposerait une publication de
/// l'application. [TripPolicy.fallback] n'existe que pour le cas où le serveur
/// ne renvoie pas le champ (version antérieure, réponse tronquée).
class TripPolicy {
  final Map<String, TripRegime> regimes;

  /// DistanceFilter du régime nominal selon le type (taxi / walk).
  /// Servi par le serveur ; défauts locaux si absent (serveur ancien).
  final Map<String, int> filterMByKind;
  final int staleFactor;
  final int staleMarginS;
  final int maxAccuracyM;
  final int lowBatteryPct;

  /// Délai de grâce après l'échéance, avant que le cercle ne soit prévenu.
  /// Servi en lecture pour que l'écran de composition puisse écrire l'heure
  /// d'alerte **exacte** avant même que le trajet n'existe. Le client ne
  /// l'envoie jamais : le serveur la fige à la création.
  final int graceMinutes;
  final int maxDurationH;

  const TripPolicy({
    required this.regimes,
    this.filterMByKind = const {TripKind.taxi: 450, TripKind.walk: 75},
    this.staleFactor = 3,
    this.staleMarginS = 30,
    this.maxAccuracyM = 100,
    this.lowBatteryPct = 15,
    this.graceMinutes = 10,
    this.maxDurationH = 12,
  });

  static const fallback = TripPolicy(regimes: {
    'nominal': TripRegime(
        accuracy: 'balanced', filterM: 75, floorS: 15, beatS: 90),
    'approach': TripRegime(
        accuracy: 'high', filterM: 30, floorS: 8, beatS: 30),
    'alert': TripRegime(accuracy: 'best', filterM: 15, floorS: 5, beatS: 15),
  });

  TripRegime regime(String name) => regimes[name] ?? regimes['nominal']!;

  /// Filtre mètres du régime **nominal** pour ce type de trajet.
  int filterMForKind(String kind) {
    final k = TripKind.normalize(kind);
    return filterMByKind[k] ?? (k == TripKind.taxi ? 450 : 75);
  }

  /// Régime à appliquer, avec le filtre nominal écrasé selon [kind].
  /// Approche / alerte : inchangés (plus serrés, indépendants du moyen).
  TripRegime regimeForKind(String name, String kind) {
    final r = regime(name);
    if (name != 'nominal') return r;
    return TripRegime(
      accuracy: r.accuracy,
      filterM: filterMForKind(kind),
      floorS: r.floorS,
      beatS: r.beatS,
    );
  }

  /// Délai de silence au-delà duquel on affiche « position indisponible ».
  /// Dérivé du battement : sans rythme attendu, aucun moyen de décider à quel
  /// moment un silence devient anormal.
  Duration staleAfter(String regimeName) =>
      Duration(seconds: regime(regimeName).beatS * staleFactor + staleMarginS);

  factory TripPolicy.fromJson(Map<String, dynamic>? json) {
    if (json == null) return fallback;
    final raw = json['regimes'];
    if (raw is! Map || raw.isEmpty) return fallback;
    final byKind = <String, int>{
      TripKind.taxi: 450,
      TripKind.walk: 75,
    };
    final rawKind = json['filterMByKind'];
    if (rawKind is Map) {
      final taxi = (rawKind['taxi'] as num?)?.toInt();
      final walk = (rawKind['walk'] as num?)?.toInt() ??
          (rawKind['meeting'] as num?)?.toInt();
      if (taxi != null) byKind[TripKind.taxi] = taxi;
      if (walk != null) byKind[TripKind.walk] = walk;
    }
    return TripPolicy(
      regimes: raw.map((k, v) => MapEntry(
            k.toString(),
            TripRegime.fromJson((v as Map).cast<String, dynamic>()),
          )),
      filterMByKind: byKind,
      staleFactor: (json['staleFactor'] as num?)?.toInt() ?? 3,
      staleMarginS: (json['staleMarginS'] as num?)?.toInt() ?? 30,
      maxAccuracyM: (json['maxAccuracyM'] as num?)?.toInt() ?? 100,
      lowBatteryPct: (json['lowBatteryPct'] as num?)?.toInt() ?? 15,
      graceMinutes:
          (json['contract']?['graceMinutes'] as num?)?.toInt() ?? 10,
      maxDurationH:
          (json['contract']?['maxDurationH'] as num?)?.toInt() ?? 12,
    );
  }
}

/// Un régime de cadence.
///
/// [filterM] déclenche à la **distance parcourue**, pas au temps : à l'arrêt,
/// le système n'émet rien. [floorS] borne le débit — sans lui, un taxi en ville
/// produirait une position toutes les six secondes. [beatS] force un envoi en
/// l'absence de mouvement, ce qui rend l'immobilité lisible.
class TripRegime {
  final String accuracy;
  final int filterM;
  final int floorS;
  final int beatS;

  const TripRegime({
    required this.accuracy,
    required this.filterM,
    required this.floorS,
    required this.beatS,
  });

  factory TripRegime.fromJson(Map<String, dynamic> json) => TripRegime(
        accuracy: json['accuracy']?.toString() ?? 'balanced',
        filterM: (json['filterM'] as num?)?.toInt() ?? 75,
        floorS: (json['floorS'] as num?)?.toInt() ?? 15,
        beatS: (json['beatS'] as num?)?.toInt() ?? 90,
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

  /// Un appareil du compte vient d'être déconnecté à distance. Payload :
  /// { appareilId, deviceId } où `deviceId` est l'identifiant MATÉRIEL, à
  /// comparer au sien : l'événement part à tout le compte, pas à une socket.
  static const authDeviceRevoked = 'auth:device_revoked';

  /// Votre code contact éphémère vient d'être scanné : { by, at }. L'écran
  /// « Mon code » régénère à la réception — le jeton est à usage unique.
  static const qrContactScanned = 'qr:contact_scanned';

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
  static const callResumeAck = 'call_resume_ack';
  static const callResumeReject = 'call_resume_reject';

  // Appels 1-1 (Backend → Flutter)
  static const incomingCall  = 'incoming_call';
  static const callAnswered  = 'call_answered';
  static const callRejected  = 'call_rejected';
  static const callEnded     = 'call_ended';
  static const callError     = 'call_error';
  static const callFailed    = 'call_failed';
  static const callBusy      = 'call_busy';       // cible occupée (ringing/in_call)
  static const callNoAnswer  = 'call_no_answer';  // timeout serveur sans réponse
  static const callResume    = 'call_resume';
  static const callRejoinOffer = 'call_rejoin_offer';
  static const callLogUpdated = 'call_log_updated';

  // « Ajouter à l'appel » — transfert assisté, 3 participants max (Flutter → Backend)
  static const callAddParticipant = 'call_add_participant';
  static const callAddCancel      = 'call_add_cancel';
  static const callConfJoin       = 'call_conf_join';
  static const callConfReject     = 'call_conf_reject';
  static const callConfReady      = 'call_conf_ready';

  // « Ajouter à l'appel » (Backend → Flutter)
  static const callAddPending     = 'call_add_pending';   // aux 2 présents : l'invité sonne
  static const callConfInvite     = 'call_conf_invite';   // à l'invité
  static const callConfJoined     = 'call_conf_joined';   // aux présents : offrir à l'arrivant
  static const callConfPeers      = 'call_conf_peers';    // à l'invité : qui va lui offrir
  static const callConfFailed     = 'call_conf_failed';   // invitation soldée
  static const callConfLeft       = 'call_conf_left';     // un participant s'est retiré
  static const callAddRejected    = 'call_add_rejected';  // demande d'ajout refusée
  static const callTransferArmed  = 'call_transfer_armed'; // countdown initiateur
  static const callTransferDone   = 'call_transfer_done';  // UI initiateur

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
  static const meetingJoinDenied  = 'meeting:join_denied';
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

  // ── Trajets de confiance ───────────────────────────────────────────
  // La room `trip_<id>` ne porte QUE le flux de positions. Tout ce qui doit
  // atteindre un destinataire — état, alerte, clôture — arrive par le compte
  // (`user_<id>`) et par la notification poussée, jamais par la seule room.

  /// Client → serveur. Rejoint le flux d'un trajet. Le serveur répond par
  /// [tripStateEvent], qui porte aussi la politique de cadence à appliquer.
  static const tripSubscribe   = 'trip:subscribe';
  static const tripUnsubscribe = 'trip:unsubscribe';

  /// Une position. Émise sans attendre d'accusé : si elle se perd, la suivante
  /// la remplace. Refusée si l'appareil n'est pas le porteur du trajet.
  static const tripPosition    = 'trip:position';

  /// Vidange du tampon hors ligne, 200 points au plus. Chaque point garde son
  /// horodatage de capture ; le serveur déduplique par `clientSeq`.
  static const tripPositionBatch = 'trip:position_batch';
  static const tripBatchAck      = 'trip:batch_ack';

  /// Reprend l'émission depuis cet appareil. L'ancien porteur reçoit
  /// [tripDeviceRevoked] et arrête son suivi — sans quoi la trace zigzaguerait.
  static const tripClaimDevice   = 'trip:claim_device';
  static const tripDeviceRevoked = 'trip:device_revoked';

  /// GPS coupé, permission retirée, économiseur de batterie. Information, pas
  /// alerte : l'échéance continue de courir côté serveur.
  static const tripSignal = 'trip:signal';

  /// « J'ai vu » — le seul retour qu'un destinataire puisse donner.
  static const tripSeen        = 'trip:seen';
  static const tripWatcherSeen = 'trip:watcher_seen';

  // Serveur → client
  static const tripStateEvent  = 'trip:state';
  static const tripStarted     = 'trip:started';
  static const tripCardUpdate  = 'trip:card_update';
  static const tripStale       = 'trip:stale';
  static const tripAlert       = 'trip:alert';
  static const tripClosed      = 'trip:closed';
  static const tripError       = 'trip:error';
}