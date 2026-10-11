// talky_api_client.dart — aligné avec le backend Alanya
// Routes, champs et socket events corrects
//
// Ce fichier ne contient que le cœur du client (état + plomberie HTTP/refresh +
// helpers privés). Les endpoints sont répartis par domaine dans des extensions
// `part of` sous lib/api/ (auth, users, chat, calls, meetings, media, socket,
// status, admin, misc). Tout partage la même librairie : les extensions ont
// accès aux membres privés et aux imports déclarés ici.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'talky_models.dart';
import 'models/qr_models.dart';
import 'core/theme/locale_controller.dart';
import 'core/services/call/call_history_rules.dart';
import 'core/services/storage_service.dart';
import 'core/utils/app_log.dart';
import 'api/socket_auth_recovery.dart';

part 'api/auth_api.dart';
part 'api/users_api.dart';
part 'api/contact_lists_api.dart';
part 'api/trips_api.dart';
part 'api/chat_api.dart';
part 'api/calls_api.dart';
part 'api/meetings_api.dart';
part 'api/media_api.dart';
part 'api/socket_api.dart';
part 'api/status_api.dart';
part 'api/admin_api.dart';
part 'api/misc_api.dart';
part 'api/qr_api.dart';
part 'api/qr_auth_api.dart';
part 'api/welcome_api.dart';
part 'api/reports_api.dart';
part 'api/stickers_api.dart';
part 'api/backup_api.dart';
part 'api/billing_api.dart';
part 'api/alanya_phone_api.dart';

class TalkyApiClient {
  // ** Remplace par ton IP/domaine de production
  static const String baseUrl   = 'https://www.alanya237.com/api';
  static const String socketUrl = 'https://www.alanya237.com/';

  String? _accessToken;
  String? _refreshToken;
  io.Socket? _socket;
  final http.Client _client;

  // Callbacks Socket globaux (pour CallService, MeetingService)
  final Map<String, List<void Function(dynamic)>> _socketListeners = {};

  /// Tentatives de ré-authentification consécutives du socket, remises à zéro
  /// dès qu'une authentification aboutit. Déclarées ici et non dans l'extension
  /// `SocketApi` : une extension Dart ne peut pas porter de champ.
  int _authRetryCount = 0;
  Timer? _authRetryTimer;

  /// Vrai uniquement après que le serveur a confirmé `auth:verified`. Le simple
  /// `_socket.connected` ne suffit pas : émettre avant l'auth fait silencieusement
  /// jeter les events côté serveur.
  bool _isSocketAuthVerified = false;

  /// Garde anti-réentrance : refresh JWT en cours suite à un `auth:error`
  /// TOKEN_EXPIRED (évite d'empiler plusieurs refresh sur des events répétés).
  bool _socketReauthInFlight = false;

  /// Un seul refresh HTTP à la fois — le backend rotate le refresh token et
  /// révoque l'ancien ; des appels concurrents provoquaient des 401 en cascade.
  Future<void>? _refreshInFlight;

  /// Reconnect forcé en cours (outbox stale / resume pending).
  Future<bool>? _forceReconnectInFlight;

  /// Reconnect manuel après `onDisconnect` si l'auto-reconnect Socket.IO est épuisé.
  Timer? _socketReconnectWatchdog;

  /// Health check périodique tant qu'il reste des messages en outbox.
  DateTime? _lastEventReceivedAt;
  Timer? _healthCheckTimer;
  Future<bool> Function()? _pendingMessagesCallback;

  /// Présence à déclarer au serveur juste après `auth:verified`.
  /// Renseigné par [PresenceService] ; null ⇒ on suppose « en ligne ».
  bool Function()? _presenceOnlineCallback;

  /// Enveloppes pour [onSocketEvent] afin de [removeSocketListener] avec la bonne ref.
  final Map<void Function(dynamic), void Function(dynamic)> _socketCallbackWrappers = {};

  Future<String>? _stableDeviceIdFuture;

  // Cache TURN/ICE (voir fetchIceServers dans misc_api.dart)
  List<Map<String, dynamic>>? _cachedIceServers;
  DateTime? _iceServersExpiresAt;

  String? get accessToken        => _accessToken;
  String? get currentRefreshToken => _refreshToken;
  bool   get isSocketConnected   => _socket?.connected ?? false;
  bool   get isSocketReady       => isSocketConnected && _isSocketAuthVerified;

  TalkyApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// ID d'installation stable (FCM multi-appareil + auth socket).
  Future<String> ensureStableDeviceId() {
    final memo = _stableDeviceIdFuture;
    if (memo != null) return memo;
    final f = StorageService().getOrCreateDeviceId();
    _stableDeviceIdFuture = f;
    // Un ÉCHEC ne doit pas rester en cache pour la vie du processus.
    //
    // `??=` ne teste que la nullité de la référence : un Future rejeté restait
    // mémorisé, et chaque appel suivant renvoyait la même erreur. Comme
    // `_emitSocketAuthLogin` l'attend avant d'émettre `auth:login`, et qu'il est
    // lancé en `unawaited` depuis `onConnect`, la panne était totale et
    // silencieuse : socket connecté, aucun indicateur hors-ligne, et plus aucun
    // appel entrant routé — y compris après un redémarrage de l'application.
    unawaited(f.then((_) {}, onError: (_) {
      if (identical(_stableDeviceIdFuture, f)) _stableDeviceIdFuture = null;
    }));
    return f;
  }

  /// Identifiant matériel du téléphone (`device_ID`) à envoyer au
  /// login/register — voir [_currentHardwareId] pour le détail par
  /// plateforme et la distinction avec [ensureStableDeviceId].
  static Future<String> currentHardwareId() => _currentHardwareId();

  void setToken(String token) => _accessToken = token;
  void setRefreshToken(String token) => _refreshToken = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // ── HTTP HELPER ───────────────────────────────────────────────────

  Future<dynamic> _handleRequest(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await request().timeout(timeout);

      if (response.statusCode == 401) {
        if (_refreshToken != null) {
          try {
            await _refreshAccessToken();
            final retried = await request().timeout(timeout);
            return _parseResponse(retried);
          } on TalkyException catch (e) {
            if (e.statusCode == 401 || e.statusCode == 403) {
              throw TalkyException(resolveL10n().sessionExpired, 401);
            }
            rethrow;
          }
        }
        throw TalkyException(resolveL10n().notAuthenticated, 401);
      }
      return _parseResponse(response);
    } on TalkyException {
      rethrow;
    } on TimeoutException catch (e) {
      throw TalkyException(resolveL10n().networkTimeout, 0, cause: e);
    } catch (e) {
      // La cause voyage désormais telle quelle plutôt que d'être aplatie dans
      // le texte. `networkErrorWithDetails('$e')` produisait un message *déjà
      // formaté pour l'écran* contenant le `toString()` de l'exception, qui
      // ressortait tel quel dans une SnackBar à l'autre bout de l'application.
      throw TalkyException(resolveL10n().networkError, 0, cause: e);
    }
  }

  dynamic _parseResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode >= 400) {
        final msg = body is Map
            ? (body['error'] ?? resolveL10n().serverError)
            : resolveL10n().serverError;
        // Le `code` était jeté ici, et c'est la cause de tout le reste : privée
        // du code machine, l'application ne pouvait plus distinguer les cas
        // qu'en lisant la prose du serveur — d'où les `message.contains(...)`
        // semés dans les écrans, et l'affichage de cette prose faute de mieux.
        throw TalkyException(
          msg.toString(),
          response.statusCode,
          code: body is Map ? body['code']?.toString() : null,
          details: body is Map ? Map<String, dynamic>.from(body) : null,
        );
      }
      return body;
    } catch (e) {
      if (e is TalkyException) rethrow;
      throw TalkyException(
        resolveL10n().serverError,
        response.statusCode,
        cause: e,
      );
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null) {
      throw TalkyException(resolveL10n().noRefreshToken, 401);
    }
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    _refreshInFlight = _performRefreshAccessToken();
    try {
      await _refreshInFlight;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _performRefreshAccessToken() async {
    var refreshTokenUsed = _refreshToken;
    if (refreshTokenUsed == null) {
      final stored = await StorageService().getRefreshToken();
      if (stored == null) {
        throw TalkyException(resolveL10n().noRefreshToken, 401);
      }
      _refreshToken = stored;
      refreshTokenUsed = stored;
    }
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshTokenUsed}),
        )
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw TalkyException(
        resolveL10n().refreshFailed,
        response.statusCode,
      );
    }
    if (response.statusCode == 200) {
      _accessToken = data['accessToken'] as String?;
      _refreshToken = data['refreshToken'] as String?;
      if (_accessToken == null || _refreshToken == null) {
        throw TalkyException(resolveL10n().refreshFailed, 500);
      }
      await _persistTokensAfterRefresh();
      reauthSocketIfConnected();
      return;
    }
    // Token en mémoire périmé (rotation concurrente) → relire le stockage une fois.
    if (response.statusCode == 401) {
      final stored = await StorageService().getRefreshToken();
      if (stored != null && stored != refreshTokenUsed) {
        _refreshToken = stored;
        return _performRefreshAccessTokenRetry(stored);
      }
    }
    throw TalkyException(
      data['error']?.toString() ?? resolveL10n().refreshFailed,
      response.statusCode,
    );
  }

  Future<void> _performRefreshAccessTokenRetry(String refreshTokenUsed) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshTokenUsed}),
        )
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw TalkyException(
        resolveL10n().refreshFailed,
        response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      throw TalkyException(
        data['error']?.toString() ?? resolveL10n().refreshFailed,
        response.statusCode,
      );
    }
    _accessToken = data['accessToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    if (_accessToken == null || _refreshToken == null) {
      throw TalkyException(resolveL10n().refreshFailed, 500);
    }
    await _persistTokensAfterRefresh();
    reauthSocketIfConnected();
  }

  Future<void> _persistTokensAfterRefresh() async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await StorageService().saveTokens(
          accessToken: _accessToken!,
          refreshToken: _refreshToken!,
        );
        return;
      } catch (e, st) {
        lastError = e;
        lastStack = st;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
        }
      }
    }
    AppLog.e(
      'TalkyApiClient',
      'Persistance tokens après refresh échouée (3 tentatives)',
      lastError,
      lastStack,
    );
  }

  /// Recharge access/refresh depuis le stockage puis renouvelle la session HTTP.
  Future<bool> refreshSessionFromStorage() async {
    final access = await StorageService().getAccessToken();
    final refresh = await StorageService().getRefreshToken();
    if (access == null && refresh == null) return false;
    if (access != null) _accessToken = access;
    if (refresh != null) _refreshToken = refresh;
    if (_refreshToken == null) return _accessToken != null;
    try {
      await _refreshAccessToken();
      return _accessToken != null;
    } on TalkyException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) return false;
      rethrow;
    }
  }

  // ── HELPERS APPAREIL (auth) ───────────────────────────────────────

  /// OS courant à envoyer dans `os_system` pour la table userAccess.
  /// Capitalise pour cohérence avec le parser server-side (Android / iOS / …).
  static String _currentOs() {
    if (kIsWeb) return 'Web';
    switch (Platform.operatingSystem) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'macos':
        return 'macOS';
      case 'windows':
        return 'Windows';
      case 'linux':
        return 'Linux';
      default:
        return Platform.operatingSystem;
    }
  }

  /// Libellé lisible du téléphone (marque + modèle) à envoyer dans
  /// `device_model` lors de login/register, stocké dans userAccess.device.
  /// Best-effort : retourne 'INDEFINI' si l'info n'est pas disponible.
  static Future<String> _currentDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final b = await info.webBrowserInfo;
        return b.browserName.name;
      }
      switch (Platform.operatingSystem) {
        case 'android':
          final a = await info.androidInfo;
          final brand = (a.manufacturer.isNotEmpty ? a.manufacturer : a.brand).trim();
          final model = a.model.trim();
          final label = (brand.isEmpty ? model : '$brand $model').trim();
          return label.isEmpty ? 'INDEFINI' : label;
        case 'ios':
          final i = await info.iosInfo;
          final machine = i.utsname.machine.trim();
          final model = i.model.trim();
          return machine.isNotEmpty ? 'Apple $machine' : (model.isEmpty ? 'INDEFINI' : 'Apple $model');
        case 'macos':
          final m = await info.macOsInfo;
          return m.model.isNotEmpty ? m.model : 'macOS';
        case 'windows':
          final w = await info.windowsInfo;
          return w.computerName.isNotEmpty ? w.computerName : 'Windows';
        case 'linux':
          final l = await info.linuxInfo;
          return l.prettyName.isNotEmpty ? l.prettyName : 'Linux';
        default:
          return 'INDEFINI';
      }
    } catch (_) {
      return 'INDEFINI';
    }
  }

  static const _deviceIdentityChannel = MethodChannel('com.alanya/device_identity');

  /// Identifiant matériel du téléphone, clé de la table `appareils` et donc de
  /// toute la révocation de session. Distinct de [ensureStableDeviceId] (UUID
  /// applicatif du push/socket, régénéré à la réinstallation).
  ///
  /// Android : `Settings.Secure.ANDROID_ID` via canal natif — unique par
  /// (appareil, signature d'app, utilisateur) et survivant à la réinstallation.
  /// Surtout PAS `AndroidDeviceInfo.id`, qui est `Build.ID` : l'empreinte du
  /// firmware, identique sur tous les téléphones d'un même modèle et modifiée à
  /// chaque mise à jour système. device_info_plus n'expose plus ANDROID_ID
  /// depuis sa v9, d'où le canal natif.
  ///
  /// iOS : `identifierForVendor` recopié dans le Keychain (voir
  /// [_iosHardwareId]), parce que l'IDFV seul ne survit pas à la
  /// désinstallation de la dernière app du vendeur.
  ///
  /// Ailleurs (desktop, web) : repli sur l'UUID applicatif, pour que la
  /// connexion par QR reste possible plutôt que de rejeter la session.
  static Future<String> _currentHardwareId() async {
    try {
      // `Platform.operatingSystem` lève sur le web : garde avant tout accès.
      if (kIsWeb) return StorageService().getOrCreateDeviceId();
      switch (Platform.operatingSystem) {
        case 'android':
          final id = (await _deviceIdentityChannel.invokeMethod<String>('getAndroidId'))?.trim();
          if (id != null && id.isNotEmpty) return id;
          return StorageService().getOrCreateDeviceId();
        case 'ios':
          return _iosHardwareId();
        default:
          return StorageService().getOrCreateDeviceId();
      }
    } catch (_) {
      // Dernier recours : mieux vaut un identifiant par installation qu'aucun,
      // sinon la session devient invisible dans « Appareils connectés ».
      try {
        return await StorageService().getOrCreateDeviceId();
      } catch (_) {
        return 'INDEFINI';
      }
    }
  }

  /// IDFV mémorisé dans le Keychain, qui lui survit à la désinstallation.
  ///
  /// L'IDFV change dès que la dernière app du vendeur est retirée : sans cette
  /// copie, une réinstallation ferait réapparaître le téléphone comme un
  /// appareil inconnu, et l'utilisateur devrait repasser par le QR pour se
  /// reconnecter sur un appareil qu'il n'a jamais quitté.
  ///
  /// La valeur mémorisée prime toujours : c'est elle que la table `appareils`
  /// connaît, y compris après une réinstallation qui a changé l'IDFV.
  static Future<String> _iosHardwareId() async {
    final storage = StorageService();
    final memorise = (await storage.getHardwareId())?.trim();
    if (memorise != null && memorise.isNotEmpty) return memorise;

    final idfv = (await DeviceInfoPlugin().iosInfo).identifierForVendor?.trim();
    final id = (idfv != null && idfv.isNotEmpty)
        ? idfv
        : await storage.getOrCreateDeviceId();
    try {
      await storage.saveHardwareId(id);
    } catch (e) {
      // Même arbitrage que `getOrCreateDeviceId` : un identifiant non persisté
      // reste exact pour cette session — il vaut mieux se connecter avec un
      // identifiant dégradé que d'échouer sur une écriture Keychain.
      debugPrint(
        '[TalkyApiClient] identifiant matériel iOS non mémorisé ($e) — '
        'conservé pour cette session',
      );
    }
    return id;
  }

  // ── UPLOAD HELPER ─────────────────────────────────────────────────

  /// MIME pour upload multipart — fallback par extension si lookup échoue.
  MediaType mimeTypeForPath(String path) {
    final mimeStr = lookupMimeType(path) ?? _mimeFallbackFromExtension(path);
    final slash = mimeStr.indexOf('/');
    if (slash > 0) {
      return MediaType(mimeStr.substring(0, slash), mimeStr.substring(slash + 1));
    }
    return MediaType('application', 'octet-stream');
  }

  String _mimeFallbackFromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case '3gp':
        return 'video/3gpp';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'm4a':
      case 'm4b':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      // Extensions que le package `mime` ne connaît pas : sans ces entrées
      // elles retombent sur application/octet-stream et le serveur rejette.
      case 'opus':
        return 'audio/opus';
      case 'wav':
        return 'audio/wav';
      case 'flac':
        return 'audio/flac';
      case 'ogg':
      case 'oga':
        return 'audio/ogg';
      case 'aac':
        return 'audio/aac';
      case 'amr':
        return 'audio/amr';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'odt':
        return 'application/vnd.oasis.opendocument.text';
      case 'ods':
        return 'application/vnd.oasis.opendocument.spreadsheet';
      case 'odp':
        return 'application/vnd.oasis.opendocument.presentation';
      case 'rtf':
        return 'application/rtf';
      case 'zip':
        return 'application/zip';
      case '7z':
        return 'application/x-7z-compressed';
      case 'rar':
        return 'application/vnd.rar';
      case 'apk':
        return 'application/vnd.android.package-archive';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Duration uploadTimeoutForFileSize(int bytes) {
    final mb = bytes / (1024 * 1024);
    final seconds = (30 + mb * 2).ceil();
    return Duration(seconds: seconds.clamp(30, 600));
  }

  TalkyException uploadHttpException(http.Response response) {
    final code = response.statusCode;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        // Le code et le corps suivent, comme pour `_parseResponse` : sans eux,
        // un refus d'envoi (pièce trop lourde, dossier déjà ouvert) retombait
        // sur le repli du statut HTTP au lieu de sa phrase.
        return TalkyException(
          body['error'].toString(),
          code,
          code: body['code']?.toString(),
          details: Map<String, dynamic>.from(body),
        );
      }
    } catch (_) {
      // body non JSON (ex. page nginx HTML)
    }
    final snippet = response.body.length > 120
        ? '${response.body.substring(0, 120)}…'
        : response.body;
    return TalkyException(
      snippet.isEmpty ? resolveL10n().uploadFailed : snippet,
      code,
    );
  }

  // http.MultipartFile.fromPath n'infère PAS le type MIME (octet-stream par
  // défaut), que le filtre multer du backend rejette. On le détecte ici.
  Future<http.MultipartFile> _multipartFile(
    String field,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final mediaType = mimeTypeForPath(file.path);
    final length = await file.length();
    if (onProgress == null) {
      return http.MultipartFile.fromPath(
        field,
        file.path,
        contentType: mediaType,
      );
    }
    var sent = 0;
    final stream = file.openRead().map((chunk) {
      sent += chunk.length;
      if (length > 0) onProgress(sent / length);
      return chunk;
    });
    final name = file.path.split('/').last;
    return http.MultipartFile(
      field,
      stream,
      length,
      filename: name,
      contentType: mediaType,
    );
  }

  void dispose() {
    logout();
    _client.close();
  }
}

class TalkyException implements Exception {
  /// Texte renvoyé par le serveur, ou message de repli.
  ///
  /// **Ne pas afficher.** C'est de la prose libre, écrite en français côté
  /// backend et jamais traduite — un utilisateur en chinois y lirait du
  /// français, et parfois un identifiant de table. Passer par
  /// `presenterErreur` (lib/core/errors/error_presenter.dart), qui choisit un
  /// texte à partir de [code]. Ce champ reste pour les journaux.
  final String message;

  final int statusCode;

  /// Code machine stable du backend (`TRUST_LIST_EMPTY`, `SESSION_BUSY`…).
  ///
  /// Nul tant que la route n'a pas été migrée côté serveur : la présentation
  /// retombe alors sur le statut HTTP. C'est ce qui permet de livrer l'app sans
  /// attendre le backend.
  final String? code;

  /// Exception d'origine, quand la requête n'a jamais abouti.
  ///
  /// Sans elle, `statusCode == 0` confond une coupure réseau, un délai dépassé
  /// et un refus TLS — trois pannes dont on ne dit pas la même chose à
  /// l'utilisateur.
  final Object? cause;

  /// Corps JSON de la réponse d'erreur, quand il y en a un.
  ///
  /// Porte les précisions qui accompagnent certains codes : la fonctionnalité
  /// d'un `SUBSCRIPTION_REQUIRED`, le paiement d'un `PAYMENT_PENDING`. Jamais
  /// affiché tel quel, pour la même raison que [message].
  final Map<String, dynamic>? details;

  TalkyException(
    this.message,
    this.statusCode, {
    this.code,
    this.cause,
    this.details,
  });

  @override
  String toString() => 'TalkyException: $message (Status: $statusCode'
      '${code != null ? ', Code: $code' : ''})';
}
