// ── USER MODEL ───────────────────────────────────────────────────────

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
  final String createdAt;

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
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    alanyaID: json['alanyaID'],
    nom: json['nom'] ?? '',
    pseudo: json['pseudo'] ?? '',
    alanyaPhone: json['alanyaPhone'] ?? '',
    email: json['email'] ?? '',
    idPays: json['idPays'] ?? 1,
    avatarUrl: json['avatar_url'] ?? '',
    typeCompte: json['type_compte'] ?? 0,
    isOnline: json['is_online'] == 1 || json['is_online'] == true,
    lastSeen: json['last_seen'] ?? '',
    createdAt: json['created_at'] ?? '',
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
    'created_at': createdAt,
  };
}

// ── MESSAGE MODEL ────────────────────────────────────────────────────

class Message {
  final int idMessage;
  final int idConversation;
  final int idExpediteur;
  final String contenu;
  final String type;
  final String? mediaUrl;
  final int? dureeVocal;
  final String dateEnvoi;
  final String? dateModification;
  final String? dateSuppression;
  final bool aLire;

  Message({
    required this.idMessage,
    required this.idConversation,
    required this.idExpediteur,
    required this.contenu,
    required this.type,
    this.mediaUrl,
    this.dureeVocal,
    required this.dateEnvoi,
    this.dateModification,
    this.dateSuppression,
    required this.aLire,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    idMessage: json['idMessage'],
    idConversation: json['idConversation'],
    idExpediteur: json['idExpediteur'],
    contenu: json['contenu'] ?? '',
    type: json['type'] ?? 'text',
    mediaUrl: json['media_url'],
    dureeVocal: json['duree_vocal'],
    dateEnvoi: json['dateEnvoi'] ?? '',
    dateModification: json['dateModification'],
    dateSuppression: json['dateSuppression'],
    aLire: json['aLire'] == 1 || json['aLire'] == true,
  );

  Map<String, dynamic> toJson() => {
    'idMessage': idMessage,
    'idConversation': idConversation,
    'idExpediteur': idExpediteur,
    'contenu': contenu,
    'type': type,
    if (mediaUrl != null) 'media_url': mediaUrl,
    if (dureeVocal != null) 'duree_vocal': dureeVocal,
    'dateEnvoi': dateEnvoi,
    if (dateModification != null) 'dateModification': dateModification,
    if (dateSuppression != null) 'dateSuppression': dateSuppression,
    'aLire': aLire,
  };
}

// ── CONVERSATION MODEL ───────────────────────────────────────────────

class Conversation {
  final int idConversation;
  final String type;
  final String? nomGroupe;
  final String? description;
  final String? avatarUrl;
  final int idCreateur;
  final String dateCreation;
  final List<User> participants;
  final Message? lastMessage;

  Conversation({
    required this.idConversation,
    required this.type,
    this.nomGroupe,
    this.description,
    this.avatarUrl,
    required this.idCreateur,
    required this.dateCreation,
    required this.participants,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    idConversation: json['idConversation'],
    type: json['type'] ?? 'private',
    nomGroupe: json['nomGroupe'],
    description: json['description'],
    avatarUrl: json['avatar_url'],
    idCreateur: json['idCreateur'],
    dateCreation: json['dateCreation'] ?? '',
    participants:
        (json['participants'] as List?)
            ?.map((e) => User.fromJson(e))
            .toList() ??
        [],
    lastMessage: json['lastMessage'] != null
        ? Message.fromJson(json['lastMessage'])
        : null,
  );
}

// ── CALL MODEL ───────────────────────────────────────────────────────

class Call {
  final int idAppel;
  final int idAppelant;
  final int idReceptionniste;
  final String type;
  final String etat;
  final String dateDebut;
  final String? dateFin;
  final int? duree;
  final User? caller;
  final User? receiver;

  Call({
    required this.idAppel,
    required this.idAppelant,
    required this.idReceptionniste,
    required this.type,
    required this.etat,
    required this.dateDebut,
    this.dateFin,
    this.duree,
    this.caller,
    this.receiver,
  });

  factory Call.fromJson(Map<String, dynamic> json) => Call(
    idAppel: json['idAppel'],
    idAppelant: json['idAppelant'],
    idReceptionniste: json['idReceptionniste'],
    type: json['type'] ?? 'audio',
    etat: json['etat'] ?? 'initiated',
    dateDebut: json['dateDebut'] ?? '',
    dateFin: json['dateFin'],
    duree: json['duree'],
    caller: json['caller'] != null ? User.fromJson(json['caller']) : null,
    receiver: json['receiver'] != null ? User.fromJson(json['receiver']) : null,
  );
}

// ── MEETING MODEL ─────────────────────────────────────────────────────

class Meeting {
  final int idMeeting;
  final String titre;
  final String? description;
  final String dateDebut;
  final String dateFin;
  final String etat;
  final int idCreateur;
  final String dateCreation;
  final List<User> participants;
  final String? roomId;

  Meeting({
    required this.idMeeting,
    required this.titre,
    this.description,
    required this.dateDebut,
    required this.dateFin,
    required this.etat,
    required this.idCreateur,
    required this.dateCreation,
    required this.participants,
    this.roomId,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) => Meeting(
    idMeeting: json['idMeeting'],
    titre: json['titre'] ?? '',
    description: json['description'],
    dateDebut: json['dateDebut'] ?? '',
    dateFin: json['dateFin'] ?? '',
    etat: json['etat'] ?? 'planning',
    idCreateur: json['idCreateur'],
    dateCreation: json['dateCreation'] ?? '',
    participants:
        (json['participants'] as List?)
            ?.map((e) => User.fromJson(e))
            .toList() ??
        [],
    roomId: json['roomId'],
  );
}

// ── SOCKET EVENT CONSTANTS ───────────────────────────────────────────

class SocketEvents {
  // Auth
  static const auth = 'auth';
  static const authenticated = 'authenticated';
  static const authError = 'auth_error';

  // Presence
  static const userOnline = 'user_online';
  static const userOffline = 'user_offline';
  static const presenceOnline = 'presence:online';
  static const presenceOffline = 'presence:offline';

  // Chat
  static const joinConversation = 'join_conversation';
  static const leaveConversation = 'leave_conversation';
  static const messageSend = 'message:send';
  static const messageNew = 'message:new';
  static const messageUpdate = 'message:update';
  static const messageDelete = 'message:delete';
  static const typingStart = 'typing:start';
  static const typingStop = 'typing:stop';

  // Calls 1-1
  static const callUser = 'call:user';
  static const callIncoming = 'call:incoming';
  static const callAnswer = 'call:answer';
  static const callReject = 'call:reject';
  static const callEnd = 'call:end';
  static const iceCandidate = 'ice:candidate';
  static const offer = 'offer';
  static const answer = 'answer';

  // Group Calls
  static const groupCallCreate = 'group_call:create';
  static const groupCallJoin = 'group_call:join';
  static const groupCallLeave = 'group_call:leave';
  static const groupCallEnd = 'group_call:end';
  static const groupOffer = 'group:offer';
  static const groupAnswer = 'group:answer';
  static const groupIceCandidate = 'group:ice_candidate';

  // Meetings
  static const meetingCreate = 'meeting:create';
  static const meetingJoinRoom = 'meeting:join_room';
  static const meetingJoinRequest = 'meeting:join_request';
  static const meetingJoinAccept = 'meeting:join_accept';
  static const meetingJoinDecline = 'meeting:join_decline';
  static const meetingStart = 'meeting:start';
  static const meetingEnd = 'meeting:end';
  static const meetingChat = 'meeting:chat';
  static const meetingLeave = 'meeting:leave';
  static const meetingOffer = 'meeting:offer';
  static const meetingAnswer = 'meeting:answer';
  static const meetingIceCandidate = 'meeting:ice_candidate';

  // Notifications
  static const notification = 'notification';
}
