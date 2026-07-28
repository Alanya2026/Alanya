// Modèles du volet QR : code d'identité, résolution d'un code scanné et
// session de connexion d'un nouvel appareil.
//
// Dart pur, sans dépendance à Flutter : le futur client web réutilisera ces
// modèles tels quels. Le parsing du payload reste l'affaire du serveur — ici on
// ne fait que transporter ce qu'il renvoie.

/// Code QR d'identité de l'utilisateur connecté (`GET /api/qr/me`).
class QrIdentity {
  final String qrPublicId;
  final String payload;

  const QrIdentity({
    required this.qrPublicId,
    required this.payload,
  });

  factory QrIdentity.fromJson(Map<String, dynamic> json) => QrIdentity(
        qrPublicId: json['qrPublicId']?.toString() ?? '',
        payload: json['payload']?.toString() ?? '',
      );
}

/// Session de connexion par QR, vue par l'appareil qui SCANNE le code :
/// de quoi décrire à l'utilisateur l'appareil qui demande à se connecter.
class QrLoginSessionInfo {
  final String sessionId;
  final String? deviceName;
  final String? platform;
  final String? ipAddress;

  /// Lieu approximatif déduit de l'adresse IP côté serveur (« Douala, Cameroun »).
  /// Null si la géolocalisation n'a pas abouti : l'écran retombe alors sur
  /// [ipAddress].
  final String? location;

  final DateTime? createdAt;
  final DateTime? expiresAt;

  const QrLoginSessionInfo({
    required this.sessionId,
    this.deviceName,
    this.platform,
    this.ipAddress,
    this.location,
    this.createdAt,
    this.expiresAt,
  });

  factory QrLoginSessionInfo.fromJson(Map<String, dynamic> json) =>
      QrLoginSessionInfo(
        sessionId: json['sessionId']?.toString() ?? '',
        deviceName: _optString(json['deviceName']),
        platform: _optString(json['platform']),
        ipAddress: _optString(json['ipAddress']),
        location: _optString(json['location']),
        createdAt: _optDate(json['createdAt']),
        expiresAt: _optDate(json['expiresAt']),
      );

  /// Vrai si la session a dépassé son TTL côté client (90 s serveur).
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Résultat de `POST /api/qr/resolve` : soit un contact, soit une demande de
/// connexion. Le champ [scanSecret] n'est jamais renvoyé par le serveur ; il est
/// rempli côté client depuis la chaîne scannée pour l'appel d'approbation.
class QrResolveResult {
  /// 'contact' | 'login'
  final String type;
  final bool isSelf;
  final bool added;
  final bool alreadyContact;
  final Map<String, dynamic>? contact;
  final QrLoginSessionInfo? session;
  final String? scanSecret;

  const QrResolveResult({
    required this.type,
    this.isSelf = false,
    this.added = false,
    this.alreadyContact = false,
    this.contact,
    this.session,
    this.scanSecret,
  });

  factory QrResolveResult.fromJson(
    Map<String, dynamic> json, {
    String? scanSecret,
  }) {
    final rawSession = json['session'];
    final rawContact = json['contact'];
    return QrResolveResult(
      type: json['type']?.toString() ?? '',
      isSelf: json['self'] == true,
      added: json['added'] == true,
      alreadyContact: json['alreadyContact'] == true,
      contact: rawContact is Map
          ? Map<String, dynamic>.from(rawContact)
          : null,
      session: rawSession is Map
          ? QrLoginSessionInfo.fromJson(Map<String, dynamic>.from(rawSession))
          : null,
      scanSecret: scanSecret,
    );
  }

  bool get isContact => type == 'contact';
  bool get isLogin => type == 'login';
}

/// Session créée par l'appareil qui AFFICHE le QR de connexion
/// (`POST /api/auth/qr-session`). [pollToken] ne doit jamais quitter cet
/// appareil : il donne accès aux tokens une fois la session approuvée.
class QrLoginCreated {
  final String sessionId;
  final String scanSecret;
  final String pollToken;
  final String payload;
  final DateTime? expiresAt;

  /// Durée de vie annoncée par le serveur. On décompte à partir de l'instant de
  /// réception plutôt que de comparer [expiresAt] à l'horloge locale : une
  /// horloge d'appareil décalée rendrait le code expiré dès son affichage.
  final Duration ttl;

  const QrLoginCreated({
    required this.sessionId,
    required this.scanSecret,
    required this.pollToken,
    required this.payload,
    this.expiresAt,
    this.ttl = const Duration(seconds: 90),
  });

  factory QrLoginCreated.fromJson(Map<String, dynamic> json) {
    final ttlMs = int.tryParse('${json['ttlMs']}');
    return QrLoginCreated(
      sessionId: json['sessionId']?.toString() ?? '',
      scanSecret: json['scanSecret']?.toString() ?? '',
      pollToken: json['pollToken']?.toString() ?? '',
      payload: json['payload']?.toString() ?? '',
      expiresAt: _optDate(json['expiresAt']),
      ttl: (ttlMs != null && ttlMs > 0)
          ? Duration(milliseconds: ttlMs)
          : const Duration(seconds: 90),
    );
  }
}

/// Réponse d'interrogation d'une session de connexion par QR.
/// Les tokens ne sont présents que sur le premier statut 'approved' :
/// la livraison est à usage unique côté serveur.
class QrLoginPollResult {
  /// 'pending' | 'scanned' | 'approved' | 'denied' | 'expired'
  final String status;
  final Map<String, dynamic>? user;
  final String? accessToken;
  final String? refreshToken;

  const QrLoginPollResult({
    required this.status,
    this.user,
    this.accessToken,
    this.refreshToken,
  });

  factory QrLoginPollResult.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return QrLoginPollResult(
      status: json['status']?.toString() ?? '',
      user: rawUser is Map ? Map<String, dynamic>.from(rawUser) : null,
      accessToken: _optString(json['accessToken']),
      refreshToken: _optString(json['refreshToken']),
    );
  }

  bool get isPending  => status == 'pending';
  bool get isScanned  => status == 'scanned';
  bool get isApproved => status == 'approved';
  bool get isDenied   => status == 'denied';

  /// Session disparue côté serveur (TTL dépassé, tokens déjà livrés, ou
  /// redémarrage : les sessions ne vivent qu'en mémoire). Le serveur la signale
  /// par un 200 et non par un 404, l'appelant doit donc la tester ici.
  bool get isExpired  => status == 'expired';

  /// Session approuvée ET tokens livrés : seul cas où l'on peut se connecter.
  bool get hasTokens =>
      accessToken != null && refreshToken != null;
}

// ── HELPERS DE PARSING ───────────────────────────────────────────────

/// Chaîne non vide, sinon null (le backend renvoie parfois '' pour « inconnu »).
String? _optString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// Date tolérante : ISO8601 ou timestamp epoch en millisecondes (les entrées de
/// qrLoginSessions portent des `Date.now()` bruts).
DateTime? _optDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed != null) return parsed;
  final millis = int.tryParse(text);
  return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
}
