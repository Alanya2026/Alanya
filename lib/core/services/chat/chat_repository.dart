import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import '../../utils/forward_message.dart';
import '../../utils/conversation_display.dart';
import '../../utils/backend_url.dart';
import '../../utils/media_upload_limits.dart';
import '../../utils/contact_payload.dart';
import '../../utils/location_payload.dart';
import '../../utils/media_album.dart';
import '../../utils/trip_payload.dart';
import '../alanya_media_export_service.dart';
import '../local_notification_helper.dart';
import '../notifications/badge_sync_service.dart';
import '../notifications/pending_notification_action_store.dart';
import '../translation/message_translation_service.dart';
import '../media_cache_service.dart';
import '../media_download_preferences.dart';
import '../voice_asset_resolver.dart';
import '../../../talky_api_client.dart' hide ChatHttpApi;
import '../../../talky_models.dart';
import '../billing/entitlement_service.dart';
import 'chat_api.dart';
import 'conversation_clear_service.dart';
import 'conversation_summary_reducer.dart';
import 'conversation_sync.dart';
import 'debounced_recompute.dart';
import 'receipt_service.dart';
import 'message_ack_watchdog.dart';
import 'message_outbox.dart';
import 'message_sender.dart';
import 'socket_message_handlers.dart';
import 'talky_chat_api.dart';
import '../../theme/locale_controller.dart';
import '../image_upload_compressor.dart';
import '../video_codec_policy.dart';
import '../video_upload_compressor.dart';

/// Facade messaging : sync, envoi, outbox, accusés, handlers socket.
class ChatRepository {
  final AppDatabase _db;
  final ChatDao _dao;
  final ChatApi _api;
  final MediaCacheService _mediaCache = MediaCacheService();
  final VideoUploadCompressor? _videoCompressor;
  final ImageUploadCompressor? _imageCompressor;
  late final ConversationSummaryReducer _reducer;
  late final ConversationClearService _clearer;
  late final DebouncedRecompute _debouncedRecompute;
  late final MessageAckWatchdog _ackWatchdog;
  late final ConversationSync _sync;
  late final ReceiptService _receipts;
  late final MessageSender _sender;
  late final MessageOutbox _outbox;
  late final SocketMessageHandlers _handlers;

  /// Progression d'upload éphémère par [clientId] (0.0–1.0).
  final ValueNotifier<Map<String, double>> uploadProgress =
      ValueNotifier<Map<String, double>>({});

  /// Progression de la compression d'une vidéo par [clientId] (0.0–1.0),
  /// avant son upload.
  final ValueNotifier<Map<String, double>> compressionProgress =
      ValueNotifier<Map<String, double>>({});

  /// La discussion lit-elle le HEVC ? (voir `VideoCodecPolicy`)
  final Future<bool> Function(int conversationID) _hevcAllowed;

  /// Ce fichier vidéo est-il en HEVC ?
  final Future<bool> Function(String path) _isHevc;

  /// Uploads en cours par [clientId] — évite les uploads parallèles du même message.
  final Set<String> _inFlightUploads = {};

  int _myId = 0;
  bool _listenersBound = false;

  /// Rattrapage coalescé de la liste des conversations après un événement
  /// socket entrant. Filet de sécurité : garantit que la liste reflète la
  /// réalité même si `recompute` n'a pas pu agir (conversation encore absente
  /// en local, `conversation:created` perdu, event dédupliqué, etc.).
  /// Débouncé pour coalescer les rafales (une seule sync par fenêtre courte).
  Timer? _listCatchUpTimer;

  /// Sync liste en cours : les appelants concurrents attendent le même Future.
  Future<void>? _syncInFlight;

  /// Fin du dernier `syncConversations` réussi (pour cooldown / timer).
  DateTime? _lastSyncCompletedAt;

  /// Fenêtre pendant laquelle un 2e sync non forcé est ignoré.
  static const Duration syncCooldown = Duration(seconds: 8);

  /// Au-delà de cet âge, le timer périodique peut relancer un sync liste.
  static const Duration fullListSyncInterval = Duration(minutes: 5);

  DateTime? get lastSyncCompletedAt => _lastSyncCompletedAt;

  bool get isSocketReady => _api.isSocketReady;

  /// Conversation actuellement ouverte à l'écran (0 = aucune). Un message reçu
  /// pour cette conversation est marqué lu immédiatement et n'incrémente pas
  /// l'unread (l'utilisateur le voit en direct) — **uniquement si l'app est
  /// au premier plan** (sinon écran encore sur la pile mais téléphone verrouillé).
  int _activeConversationID = 0;

  int get activeConversationId => _activeConversationID;

  /// False dès que l'app passe en arrière-plan / inactive.
  bool _appInForeground = true;

  bool get appInForeground => _appInForeground;

  /// True seulement si le chat est ouvert ET visible (pas en veille).
  bool get _isChatVisiblyActive =>
      _activeConversationID != 0 && _appInForeground;

  /// Lectures à confirmer au serveur dès la reconnexion (lecture hors-ligne).
  final Set<int> _pendingReads = {};
  /// Retry tracker pour les lectures hors-ligne (conversationID -> retryCount)
  final Map<int, int> _pendingReadsRetry = {};

  void setActiveConversation(int conversationID) {
    _activeConversationID = conversationID;
    if (_appInForeground) {
      LocalNotificationHelper.setActiveConversationId(conversationID);
    }
  }

  void clearActiveConversation(int conversationID) {
    if (_activeConversationID == conversationID) {
      _activeConversationID = 0;
      LocalNotificationHelper.setActiveConversationId(null);
    }
  }

  /// Synchronise la suppression push + le traitement « chat actif » avec le
  /// cycle de vie. En arrière-plan : on reçoit les notifs et on compte les
  /// non-lus (même si le ChatDetail est encore sur la pile).
  void syncPushSuppressionForLifecycle(bool appInForeground) {
    _appInForeground = appInForeground;
    if (!appInForeground || _activeConversationID == 0) {
      LocalNotificationHelper.setActiveConversationId(null);
    } else {
      LocalNotificationHelper.setActiveConversationId(_activeConversationID);
    }
  }

  ChatRepository._(
    this._api,
    this._db, {
    AppRoots? appRoots,
    VideoUploadCompressor? videoCompressor,
    ImageUploadCompressor? imageCompressor,
    Future<bool> Function(int conversationID)? hevcAllowed,
    Future<bool> Function(String path)? isHevc,
  })  : _dao = ChatDao(_db),
        _videoCompressor = videoCompressor,
        _imageCompressor = imageCompressor,
        _hevcAllowed = hevcAllowed ?? hevcAllowedFor,
        _isHevc = isHevc ??
            (videoCompressor ?? VideoUploadCompressor.instance).isHevc {
    _reducer = ConversationSummaryReducer(_db, _dao);
    _clearer = ConversationClearService(_db, appRoots: appRoots);
    _debouncedRecompute = DebouncedRecompute(
      (convId) async {
        await _reducer.recompute(convId, _myId);
        if (_myId != 0) {
          await BadgeSyncService.syncFromDao(_dao);
        }
      },
    );
    Future<void> scheduleRecompute(int convId) =>
        _debouncedRecompute.schedule(convId);

    _ackWatchdog = MessageAckWatchdog(
      api: _api,
      dao: _dao,
      recompute: scheduleRecompute,
    );

    _sync = ConversationSync(
      api: _api,
      dao: _dao,
      myId: () => _myId,
      upsertServerMsg: _upsertServerMsg,
      upsertIncomingBatch: _upsertIncomingServerMessagesBatch,
      convToCompanion: _convToCompanion,
      parseDate: _parseDate,
      purgeBeforeCutoff: (convId, cutoff) async {
        if (await _clearer.purgeIfStale(convId, cutoff) > 0) {
          await _reducer.recompute(convId, _myId);
        }
      },
      recompute: (convId) => _reducer.recompute(convId, _myId),
      recomputeMany: (ids) => _reducer.recomputeMany(ids, _myId),
    );
    _receipts = ReceiptService(
      api: _api,
      dao: _dao,
      myId: () => _myId,
      activeConversationID: () =>
          _isChatVisiblyActive ? _activeConversationID : 0,
      pendingReadsRetry: _pendingReadsRetry,
      recompute: scheduleRecompute,
    );

    _sender = MessageSender(
      api: _api,
      dao: _dao,
      db: _db,
      myId: () => _myId,
      recompute: scheduleRecompute,
      uploadProgress: uploadProgress,
      compressionProgress: compressionProgress,
      hevcAllowed: _hevcAllowed,
      inFlightUploads: _inFlightUploads,
      ackWatchdog: _ackWatchdog,
      videoCompressor: _videoCompressor,
      imageCompressor: _imageCompressor,
    );
    _outbox = MessageOutbox(
      api: _api,
      dao: _dao,
      db: _db,
      sender: _sender,
      pendingReads: _pendingReads,
      recompute: scheduleRecompute,
    );
    _handlers = SocketMessageHandlers(
      api: _api,
      dao: _dao,
      db: _db,
      myId: () => _myId,
      activeConversationID: () => _activeConversationID,
      appInForeground: () => _appInForeground,
      recompute: scheduleRecompute,
      upsertServerMsg: _upsertServerMsg,
      receipts: _receipts,
      mediaCache: _mediaCache,
      scheduleListCatchUp: scheduleListCatchUp,
      ackWatchdog: _ackWatchdog,
    );
  }

  /// Planifie un rattrapage coalescé de la liste des conversations (débouncé).
  /// Sûr côté récepteur : `ConversationSync` protège les aperçus optimistes
  /// (via `hasLocalPendingNewer`) et redérive tout depuis les messages locaux.
  void scheduleListCatchUp() {
    _listCatchUpTimer?.cancel();
    _listCatchUpTimer = Timer(const Duration(milliseconds: 600), () {
      if (_myId == 0) return;
      unawaited(syncConversations());
    });
  }

  MediaCacheService get mediaCache => _mediaCache;

  factory ChatRepository({required TalkyApiClient api, AppDatabase? database}) {
    return ChatRepository._(TalkyChatApi(api), database ?? AppDatabase());
  }

  /// Constructeur de test : injecte un [ChatApi] (ex. FakeChatApi) + Drift mémoire.
  factory ChatRepository.forTesting({
    required ChatApi api,
    required AppDatabase database,
    AppRoots? appRoots,
    VideoUploadCompressor? videoCompressor,
    ImageUploadCompressor? imageCompressor,
    Future<bool> Function(int conversationID)? hevcAllowed,
    Future<bool> Function(String path)? isHevc,
  }) {
    return ChatRepository._(
      api,
      database,
      appRoots: appRoots,
      videoCompressor: videoCompressor,
      imageCompressor: imageCompressor,
      hevcAllowed: hevcAllowed,
      isHevc: isHevc,
    );
  }

  AppDatabase get db => _db;
  ChatDao get dao => _dao;
  int get myId => _myId;
  Stream<List<LocalConversation>> watchConversations() => _dao.watchConversations();
  Stream<LocalConversation?> watchConversation(int conversationID) =>
      _dao.watchConversation(conversationID);
  Stream<List<LocalMessage>> watchMessages(int conversationID) =>
      _dao.watchMessages(conversationID, _myId);

  /// Flux des messages épinglés d'une conversation (pour la bannière).
  Stream<List<LocalMessage>> watchPinnedMessages(int conversationID) =>
      _dao.watchPinnedMessages(conversationID, _myId);
 
  /// Handler `auth:verified`. Méthode (et non lambda stockée) pour garder
  /// une référence stable utilisable par `removeSocketListener` au logout.
  Future<void> _onAuthVerified(dynamic _) async {
    try {
      rejoinActiveRoom();
      // En premier : une réponse rapide en attente est l'écriture la plus
      // visible pour l'utilisateur, et le marquage lu doit précéder le
      // catch-up des accusés pour ne pas être recalculé par-dessus.
      await flushPendingNotificationActions();
      // Avant le catch-up socket : ces accusés viennent de messages reçus par
      // push alors que l'app était fermée, ils sont les plus en retard.
      await _receipts.flushNativeDeliveryAcks();
      await flushReceiptsCatchUp();
      await resyncActiveConversation();
      await _receipts.flushPendingReads();
    } catch (e) {
      debugPrint('[ChatRepo] authVerified handler failed: $e');
    }
  }

  Future<void> bind(int myId) async {
    if (myId == 0) return;
    _myId = myId;

    // Listeners AVANT toute I/O : sinon `message:received` / `auth:verified`
    // tombés pendant les purges sont perdus (pas de buffer socket.io).
    if (!_listenersBound) {
      _listenersBound = true;

      _api.onSocketEvent(SocketEvents.messageReceived, _handlers.onMessageReceived);
      _api.onSocketEvent(SocketEvents.messageSent, _handlers.onMessageSent);
      _api.onSocketEvent(SocketEvents.messageSendFailed, _handlers.onMessageSendFailed);
      _api.onSocketEvent(SocketEvents.messageUpdated, _handlers.onMessageUpdated);
      _api.onSocketEvent(SocketEvents.messageDeleted, _handlers.onMessageDeleted);
      _api.onSocketEvent(SocketEvents.messagesDeleted, _handlers.onMessagesDeleted);
      _api.onSocketEvent(SocketEvents.messagePinned, _handlers.onMessagePinned);
      _api.onSocketEvent(SocketEvents.messageViewed, _handlers.onMessageViewed);
      _api.onSocketEvent(SocketEvents.messageReaction, _handlers.onMessageReaction);
      _api.onSocketEvent(SocketEvents.messageStatus, _handlers.onMessageStatus);
      _api.onSocketEvent(SocketEvents.inboxSync, _handlers.onInboxSync);
      _api.onSocketEvent(SocketEvents.conversationCreated, _onConversationCreated);
      _api.onSocketEvent(SocketEvents.conversationUpdated, _onConversationUpdated);
      _api.onSocketEvent(SocketEvents.conversationCleared, _onConversationCleared);
      _api.onSocketEvent(
          SocketEvents.groupParticipantRemoved, _onGroupParticipantRemoved);
      _api.onSocketEvent(SocketEvents.authVerified, _onAuthVerified);
    }

    // Purges / éviction en arrière-plan : ne doivent pas retarder l'écoute.
    unawaited(_runStartupPurges());
  }

  Future<void> _runStartupPurges() async {
    try {
      await _dao.purgeGhostMessages();
      await _dao.purgeDuplicateOptimistics();
      await _dao.purgeDuplicateByMsgId();
      // Plus d'éviction du cache média ici : un média téléchargé reste jusqu'à
      // la désinstallation ou un changement de compte. Voir MediaCacheService.
    } catch (e) {
      debugPrint('[ChatRepo] startup purges échouées: $e');
    }
  }

  /// Détache les listeners socket et autorise un futur `bind` (cas logout/login
  /// dans la même session d'app). `disconnectSocket` aurait déjà vidé le
  /// registre côté API client, mais on remet le drapeau à zéro pour que la
  /// prochaine connexion repasse par l'enregistrement complet.
  void unbind() {
    _listCatchUpTimer?.cancel();
    _listCatchUpTimer = null;
    _syncInFlight = null;
    _lastSyncCompletedAt = null;
    _debouncedRecompute.dispose();
    _ackWatchdog.dispose();
    if (!_listenersBound) return;
    _listenersBound = false;
    _api.removeSocketListener(SocketEvents.messageReceived, _handlers.onMessageReceived);
    _api.removeSocketListener(SocketEvents.messageSent, _handlers.onMessageSent);
    _api.removeSocketListener(SocketEvents.messageSendFailed, _handlers.onMessageSendFailed);
    _api.removeSocketListener(SocketEvents.messageUpdated, _handlers.onMessageUpdated);
    _api.removeSocketListener(SocketEvents.messageDeleted, _handlers.onMessageDeleted);
    _api.removeSocketListener(SocketEvents.messagesDeleted, _handlers.onMessagesDeleted);
    _api.removeSocketListener(SocketEvents.messagePinned, _handlers.onMessagePinned);
    _api.removeSocketListener(SocketEvents.messageViewed, _handlers.onMessageViewed);
    _api.removeSocketListener(SocketEvents.messageReaction, _handlers.onMessageReaction);
    _api.removeSocketListener(SocketEvents.messageStatus, _handlers.onMessageStatus);
    _api.removeSocketListener(SocketEvents.inboxSync, _handlers.onInboxSync);
    _api.removeSocketListener(SocketEvents.conversationCreated, _onConversationCreated);
    _api.removeSocketListener(
        SocketEvents.conversationUpdated, _onConversationUpdated);
    _api.removeSocketListener(
        SocketEvents.conversationCleared, _onConversationCleared);
    _api.removeSocketListener(
        SocketEvents.groupParticipantRemoved, _onGroupParticipantRemoved);
    _api.removeSocketListener(SocketEvents.authVerified, _onAuthVerified);
    _activeConversationID = 0;
    LocalNotificationHelper.setActiveConversationId(null);
    _pendingReads.clear();
    _pendingReadsRetry.clear();
    _myId = 0;
  }

  /// Efface conversations, messages et cache média (logout / changement de compte).
  Future<void> clearLocalSession() async {
    _listCatchUpTimer?.cancel();
    _listCatchUpTimer = null;
    _syncInFlight = null;
    _lastSyncCompletedAt = null;
    _debouncedRecompute.dispose();
    _ackWatchdog.dispose();
    _activeConversationID = 0;
    LocalNotificationHelper.setActiveConversationId(null);
    _pendingReads.clear();
    _pendingReadsRetry.clear();
    await _dao.clearAll();
    await _mediaCache.clearAll();
    await BadgeSyncService.clear();
  }

  void _onConversationCreated(dynamic data) {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    _dao.upsertConversation(_convToCompanion(Conversation.fromJson(json), json));
  }

  /// Métadonnées de groupe modifiées (nom, photo, description, rôles, verrous).
  ///
  /// Écrit un companion PARTIEL : la trame n'a pas les champs par-utilisateur,
  /// et les écraser ferait réapparaître un badge fantôme.
  ///
  /// Garde anti-réordonnancement : Socket.IO ne garantit pas l'ordre entre deux
  /// émissions issues de requêtes HTTP concurrentes. Sans elle, un renommage
  /// suivi d'un changement de photo pourrait s'appliquer à l'envers et
  /// ressusciter l'ancien nom.
  Future<void> _onConversationUpdated(dynamic data) async {
    if (data is! Map) return;
    final json = Map<String, dynamic>.from(data);
    final conv = Conversation.fromJson(json);
    if (conv.conversID <= 0) return;

    final incoming = _parseDate(conv.updatedAt);
    if (incoming != null) {
      final local = await _dao.watchConversation(conv.conversID).first;
      final known = local?.metaUpdatedAt;
      // `isBefore` et non `!isAfter` : le rôle de cette garde est de rejeter
      // les trames STRICTEMENT plus anciennes. À horodatage égal la trame
      // porte les mêmes données, l'appliquer est un no-op inoffensif — alors
      // que la rejeter perdait la seconde de deux actions d'administration
      // rapprochées, et laissait un membre retiré affiché jusqu'au prochain
      // sync HTTP.
      if (known != null && incoming.isBefore(known)) return;
    }

    await _dao.upsertConversation(_convToPartialCompanion(conv, json));

    // Ré-ajout avec historique masqué : purger le cache local antérieur au
    // cutoff, sinon d'anciens messages d'un membership précédent ressurgissent.
    final cutoff = _parseDate(conv.myHistoryCutoffAt);
    if (cutoff != null) {
      final removed = await _dao.deleteMessagesBefore(conv.conversID, cutoff);
      if (removed > 0) {
        unawaited(syncMessages(conv.conversID));
      }
    }
  }

  /// Un membre a quitté ou a été retiré.
  ///
  /// Si c'est MOI, la conversation disparaît du cache : `watchConversation`
  /// émet alors `null`, ce que la fiche groupe et l'écran de discussion
  /// interprètent comme « sors d'ici ». C'est le seul chemin qui prévient
  /// l'exclu — il n'est plus destinataire de `conversation:updated`.
  ///
  /// Sinon rien à faire : le `conversation:updated` qui accompagne l'événement
  /// porte déjà la liste des participants à jour.
  Future<void> _onGroupParticipantRemoved(dynamic data) async {
    if (data is! Map) return;
    final conversID = _toInt(data['conversID']);
    final removedId = _toInt(data['alanyaID']);
    if (conversID <= 0 || removedId <= 0) return;
    if (removedId != _myId) return;

    await _dao.deleteConversation(conversID);
  }
 
  /// Sync liste HTTP + delta messages.
  ///
  /// [force] ignore le cooldown (pull-to-refresh, nouvelle conversation…).
  /// Les appels concurrents partagent le même Future (pas de double pipeline).
  Future<void> syncConversations({bool force = false}) async {
    if (_myId == 0) return;
    final inFlight = _syncInFlight;
    if (inFlight != null) return inFlight;

    if (!force &&
        _lastSyncCompletedAt != null &&
        DateTime.now().difference(_lastSyncCompletedAt!) < syncCooldown) {
      return;
    }

    final future = _runSyncConversations();
    _syncInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_syncInFlight, future)) {
        _syncInFlight = null;
      }
    }
  }

  Future<void> _runSyncConversations() async {
    await _sync.syncConversations();
    await catchUpDeletions();
    _lastSyncCompletedAt = DateTime.now();
  }

  // ── Suppressions pour tous manquées hors ligne ──────────────────────

  static String _deletionsCursorKey(int myId) => 'deletions_cursor_$myId';

  /// Rejoue les suppressions « pour tous » survenues pendant que cet appareil
  /// était éteint ou hors ligne : `POST /messages/sync` ne renvoie jamais un
  /// message supprimé, donc sans cela il resterait affiché pour toujours.
  ///
  /// Le curseur est mémorisé par compte. Au premier appel (aucun curseur) le
  /// serveur ne rejoue rien et donne seulement sa position : on ne remonte pas
  /// l'histoire d'avant la fonctionnalité. Best-effort : une erreur réseau se
  /// rattrape à la synchronisation suivante.
  Future<void> catchUpDeletions() async {
    final me = _myId;
    if (me == 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _deletionsCursorKey(me);
      var after = prefs.getInt(key);
      for (var page = 0; page < 20; page++) {
        final res = await _api.getDeletionsSince(after: after);
        final deletions = res['deletions'];
        final ids = <int>[
          if (deletions is List)
            for (final d in deletions)
              if (d is Map && _toInt(d['msgID']) > 0) _toInt(d['msgID']),
        ];
        if (ids.isNotEmpty) {
          await _handlers.onMessagesDeleted({'msgIDs': ids, 'all': true});
        }
        final cursor = _toInt(res['cursor']);
        if (after == null || cursor > after) {
          after = cursor;
          await prefs.setInt(key, cursor);
        }
        if (res['hasMore'] != true) break;
      }
    } catch (e) {
      debugPrint('[ChatRepo] catchUpDeletions: $e');
    }
  }

  // ── Capture d'écran ─────────────────────────────────────────────────

  /// Dit au serveur que j'ai fait une capture d'écran de cette discussion à deux
  /// (il écrit la ligne système que les deux participants voient). Best-effort :
  /// hors ligne ou refus, rien à afficher — l'utilisateur n'a rien demandé.
  Future<void> signalScreenshot(int conversID) async {
    if (conversID <= 0) return;
    try {
      await _api.signalScreenshot(conversID);
    } catch (e) {
      debugPrint('[ChatRepo] signalScreenshot: $e');
    }
  }

  // ── Effacer la discussion ───────────────────────────────────────────

  /// Poids de ce qu'« Effacer la discussion » libérerait sur cet appareil.
  Future<ClearEstimate> estimateClear(int conversID) =>
      _clearer.estimate(conversID);

  /// « Effacer la discussion » : la discussion reste dans la liste et ne quitte
  /// rien — c'est ce qui la distingue de [deleteConversations]. Les autres
  /// participants ne voient aucun changement.
  ///
  /// [ClearMode.all] passe d'abord par le serveur (curseur d'historique propre à
  /// moi, valable sur tous mes appareils et après réinstallation) : sans
  /// réseau, l'erreur remonte et RIEN n'est effacé — vider seulement la copie
  /// locale ferait croire à un effacement que le serveur ne connaît pas.
  /// [ClearMode.mediaOnly] est purement local : les messages restent.
  Future<void> clearConversation(
    int conversID, {
    required ClearMode mode,
  }) async {
    if (conversID <= 0) return;
    if (mode == ClearMode.mediaOnly) {
      await _clearer.clearMediaOnly(conversID);
      return;
    }
    final res = await _api.clearConversation(conversID);
    final cutoff =
        _parseDate(res['historyCutoffAt']) ?? DateTime.now().toUtc();
    await _applyClear(conversID, cutoff);
  }

  Future<void> _applyClear(int conversID, DateTime cutoff) async {
    await _clearer.clearBefore(conversID, cutoff);
    // Sans message restant, `recompute` ne touche à rien (l'aperçu vient d'être
    // vidé) ; s'il en reste (reçus après le curseur), il redérive aperçu et non-lus.
    await _recomputeSummary(conversID);
    unawaited(BadgeSyncService.syncFromDao(_dao));
  }

  /// `conversation:cleared` : j'ai effacé la discussion depuis un autre appareil.
  Future<void> _onConversationCleared(dynamic data) async {
    if (data is! Map) return;
    final conversID = _toInt(data['conversationID']);
    final cutoff = _parseDate(data['historyCutoffAt']);
    if (conversID <= 0 || cutoff == null) return;
    await _applyClear(conversID, cutoff);
  }

  /// True si le dernier sync liste est plus vieux que [fullListSyncInterval]
  /// (ou jamais fait).
  bool get needsPeriodicListSync {
    final last = _lastSyncCompletedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) >= fullListSyncInterval;
  }

  /// Sync delta globale des messages (curseur par conversation). Rattrapage
  /// garanti et sans trou des messages manqués par le WebSocket.
  Future<void> syncGlobalDelta() => _sync.syncGlobalDelta();

  /// Précharge les messages des conversations sans historique local.
  Future<void> bootstrapEmptyConversationMessages() =>
      _sync.bootstrapEmptyConversationMessages();

  /// Charge l'historique d'une conversation.
  /// Si `delta == true`, ne récupère que les messages plus récents que le
  /// dernier confirmé en local (curseur `after` côté API).
  Future<void> syncMessages(int conversationID, {bool delta = false}) =>
      _sync.syncMessages(conversationID, delta: delta);

  /// Charge une page d'anciens messages
  Future<int> loadOlderMessages(int conversationID, {int limit = 30}) =>
      _sync.loadOlderMessages(conversationID, limit: limit);

  /// Doublons 1-1 legacy : l'aperçu peut être sur une conv vide (ex. après un
  /// appel) alors que l'historique texte est sur une autre. Tente chaque conv
  /// locale avec le même interlocuteur et retourne celle qui a des messages.
  Future<int?> resolveDirectConversationWithHistory({
    required int myId,
    required int peerUserId,
    required int currentConvId,
  }) async {
    if (myId == 0 || peerUserId == 0) return null;
    final convs = await _dao.getAllConversations();
    final candidateIds = findAllDirectConversationIds(convs, myId, peerUserId);
    if (candidateIds.isEmpty) return null;

    // Conv courante d'abord, puis les autres (doublons).
    candidateIds.sort((a, b) {
      if (a == currentConvId) return -1;
      if (b == currentConvId) return 1;
      return b.compareTo(a);
    });

    for (final id in candidateIds) {
      await syncMessages(id);
      if (await _dao.maxServerMsgId(id) > 0) {
        if (id != currentConvId) {
          debugPrint(
            '[ChatRepo] conv 1-1 doublon: historique sur conv=$id '
            '(ouverte conv=$currentConvId)',
          );
        }
        return id;
      }
    }
    return null;
  }


  /// Nombre maximal de médias d'un album pour CE compte : annoncé par le
  /// serveur avec ses droits (30, ou 100 pour un abonné).
  static int get maxAlbumItems => MediaUploadLimits.maxAlbumItems;

  /// Le compte peut-il émettre ? Sinon le panneau de l'abonnement s'ouvre.
  /// Voir `MessageSender._outgoingAllowed` : sans droits connus, tout passe.
  bool _outgoingAllowed() {
    if (EntitlementService.allowsOutgoing) return true;
    EntitlementService.maybeInstance?.reportOutgoingBlocked();
    return false;
  }

  Future<void> sendText({
    required int conversationID,
    required String content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
    List<int>? mentions,
    bool mentionsAll = false,
  }) =>
      _sender.sendText(
        conversationID: conversationID,
        content: content,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isStatusReply: isStatusReply,
        isForwarded: isForwarded,
        mentions: mentions,
        mentionsAll: mentionsAll,
      );

  Future<void> sendLocation({
    required int conversationID,
    required LocationPayload location,
    int? replyToID,
    String? replyToContent,
    bool isForwarded = false,
  }) =>
      _sender.sendLocation(
        conversationID: conversationID,
        location: location,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isForwarded: isForwarded,
      );

  Future<void> sendContact({
    required int conversationID,
    required ContactPayload contact,
    int? replyToID,
    String? replyToContent,
    bool isForwarded = false,
  }) =>
      _sender.sendContact(
        conversationID: conversationID,
        contact: contact,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isForwarded: isForwarded,
      );

  Future<void> sendMedia({
    required int conversationID,
    required int type,
    required String mediaUrl,
    String? mediaName,
    int? mediaDuration,
    int? mediaSize,
    int? mediaPageCount,
    String? mediaThumb,
    String? localMediaPath,
    String? content,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) =>
      _sender.sendMedia(
        conversationID: conversationID,
        type: type,
        mediaUrl: mediaUrl,
        mediaName: mediaName,
        mediaDuration: mediaDuration,
        mediaSize: mediaSize,
        mediaPageCount: mediaPageCount,
        mediaThumb: mediaThumb,
        localMediaPath: localMediaPath,
        content: content,
        isForwarded: isForwarded,
        isViewOnce: isViewOnce,
      );

  Future<void> sendMediaFile({
    required int conversationID,
    required int type,
    required File file,
    String? mediaName,
    int? mediaDuration,
    String? content,
    int? replyToID,
    String? replyToContent,
    int isStatusReply = 0,
    bool isForwarded = false,
    bool isViewOnce = false,
  }) =>
      _sender.sendMediaFile(
        conversationID: conversationID,
        type: type,
        file: file,
        mediaName: mediaName,
        mediaDuration: mediaDuration,
        content: content,
        replyToID: replyToID,
        replyToContent: replyToContent,
        isStatusReply: isStatusReply,
        isForwarded: isForwarded,
        isViewOnce: isViewOnce,
      );

  /// Un message par fichier — documents et morceaux, sans regroupement album.
  Future<void> sendMediaFiles({
    required int conversationID,
    required List<AlbumSendItem> items,
  }) =>
      _sender.sendMediaFiles(
        conversationID: conversationID,
        items: items,
      );

  Future<void> sendMediaAlbum({
    required int conversationID,
    required List<AlbumSendItem> items,
    String? content,
    bool isForwarded = false,
  }) =>
      _sender.sendMediaAlbum(
        conversationID: conversationID,
        items: items,
        content: content,
        isForwarded: isForwarded,
      );

  /// Transfère un album complet vers une ou plusieurs conversations.
  Future<ForwardResult> forwardAlbum({
    required List<LocalMessage> sourceItems,
    required List<int> targetConversationIDs,
  }) async {
    if (_myId == 0) {
      return ForwardResult(
        succeeded: 0,
        failed: 0,
      );
    }
    if (!_outgoingAllowed()) {
      return const ForwardResult(succeeded: 0, failed: 1);
    }
    if (!canForwardAlbum(sourceItems)) {
      return ForwardResult(
        succeeded: 0,
        failed: 1,
      );
    }
    if (targetConversationIDs.isEmpty) {
      return const ForwardResult(succeeded: 0, failed: 0);
    }

    final hevc = await _hevcVideoClientIds(sourceItems);
    final split = await _splitForHevc(targetConversationIDs, hevc);
    var direct = split.direct;
    var succeeded = 0;
    var failed = 0;

    if (direct.isNotEmpty && canBatchForwardOnServer(sourceItems)) {
      try {
        final sorted = _sortAlbumItems(sourceItems);
        final sourceMsgIDs = sorted.map((m) => m.msgID).toList();
        await _api.batchForward(
          sourceMsgIDs: sourceMsgIDs,
          targetConversationIDs: direct,
        );
        succeeded += direct.length;
        direct = const [];
      } catch (e) {
        debugPrint('[ChatRepo] batch forward album échoué, fallback client: $e');
      }
    }

    for (final convId in [...direct, ...split.reencode]) {
      try {
        await _forwardAlbumToConversation(
          sourceItems: sourceItems,
          conversationID: convId,
          reencodeClientIds:
              split.reencode.contains(convId) ? hevc : const <String>{},
        );
        succeeded++;
      } catch (e) {
        failed++;
        debugPrint('[ChatRepo] forward album vers $convId échoué: $e');
      }
    }

    return ForwardResult(succeeded: succeeded, failed: failed);
  }

  /// Vidéos HEVC parmi [sources] dont le fichier est sur ce téléphone, par
  /// `clientId`. Elles seules peuvent être reconverties en H.264 pour une
  /// discussion qui ne lit pas le HEVC ; sans fichier local, le transfert
  /// habituel s'applique.
  Future<Set<String>> _hevcVideoClientIds(List<LocalMessage> sources) async {
    final ids = <String>{};
    for (final m in sources) {
      if (m.type != 2) continue;
      final file = localMediaFileForForward(m);
      if (file == null || !file.existsSync()) continue;
      if (await _isHevc(file.path)) ids.add(m.clientId);
    }
    return ids;
  }

  /// Sépare les destinations d'un transfert qui contient du HEVC : celles qui
  /// le lisent reçoivent le transfert habituel (copie côté serveur), les
  /// autres une copie reconvertie en H.264, envoyée depuis ce téléphone.
  Future<({List<int> direct, List<int> reencode})> _splitForHevc(
    List<int> targets,
    Set<String> hevcClientIds,
  ) async {
    if (hevcClientIds.isEmpty) {
      return (direct: targets, reencode: const <int>[]);
    }
    final direct = <int>[];
    final reencode = <int>[];
    for (final id in targets) {
      (await _hevcAllowed(id) ? direct : reencode).add(id);
    }
    return (direct: direct, reencode: reencode);
  }

  List<LocalMessage> _sortAlbumItems(List<LocalMessage> sourceItems) {
    final sorted = List<LocalMessage>.from(sourceItems)
      ..sort((a, b) {
        final ma = parseAlbumMarker(a.content);
        final mb = parseAlbumMarker(b.content);
        return (ma?.index ?? 0).compareTo(mb?.index ?? 0);
      });
    return sorted;
  }

  Future<void> _forwardAlbumToConversation({
    required List<LocalMessage> sourceItems,
    required int conversationID,
    Set<String> reencodeClientIds = const {},
  }) async {
    final sorted = _sortAlbumItems(sourceItems);

    if (sorted.length == 1) {
      await _forwardToConversation(
        source: sorted.first,
        conversationID: conversationID,
        reencodeClientIds: reencodeClientIds,
      );
      return;
    }

    final freshAlbumId = newAlbumId();
    final total = sorted.length;
    final albumCaption = albumCaptionFromMessages(sorted);
    final counts = countAlbumMediaTypes(sorted);

    for (var i = 0; i < sorted.length; i++) {
      final source = sorted[i];
      final marker = reencodeAlbumMarkerForForward(
        newAlbumId: freshAlbumId,
        index: i,
        total: total,
        photoCount: counts.photos,
        videoCount: counts.videos,
        caption: albumCaption,
      );

      final url = source.mediaUrl;
      if (url != null &&
          url.isNotEmpty &&
          !reencodeClientIds.contains(source.clientId)) {
        await sendMedia(
          conversationID: conversationID,
          type: source.type,
          mediaUrl: url,
          mediaName: source.mediaName,
          mediaDuration: source.mediaDuration,
          mediaSize: source.mediaSize,
          mediaPageCount: source.mediaPageCount,
          mediaThumb: source.mediaThumb,
          localMediaPath: source.localMediaPath,
          content: marker,
          isForwarded: true,
        );
        continue;
      }

      // Vidéo HEVC vers une discussion qui ne le lit pas : renvoyée depuis le
      // fichier local, l'envoi la convertit en H.264.
      final file = localMediaFileForForward(source);
      if (file == null) {
        throw StateError(LocaleController.instance.l10n.mediaUnavailableForTransfer);
      }

      await sendMediaFile(
        conversationID: conversationID,
        type: source.type,
        file: file,
        mediaName: source.mediaName,
        mediaDuration: source.mediaDuration,
        content: marker,
        isForwarded: true,
      );
    }
  }

  /// Transfère un message vers une ou plusieurs conversations.
  Future<ForwardResult> forwardMessage({
    required LocalMessage source,
    required List<int> targetConversationIDs,
    String? caption,
  }) async {
    return forwardMessages(
      sources: [source],
      targetConversationIDs: targetConversationIDs,
      caption: caption,
    );
  }

  /// Transfère plusieurs messages vers une ou plusieurs conversations.
  Future<ForwardResult> forwardMessages({
    required List<LocalMessage> sources,
    required List<int> targetConversationIDs,
    String? caption,
  }) async {
    if (_myId == 0) {
      return ForwardResult(
        succeeded: 0,
        failed: 0,
      );
    }
    if (!_outgoingAllowed()) {
      return const ForwardResult(succeeded: 0, failed: 1);
    }
    if (sources.isEmpty || targetConversationIDs.isEmpty) {
      return const ForwardResult(succeeded: 0, failed: 0);
    }
    if (!sources.every(canForwardMessage)) {
      return ForwardResult(
        succeeded: 0,
        failed: 1,
      );
    }

    if (sources.length >= 2 && isCompleteAlbumSelection(sources)) {
      return forwardAlbum(
        sourceItems: sources,
        targetConversationIDs: targetConversationIDs,
      );
    }

    final hevc = await _hevcVideoClientIds(sources);
    final split = await _splitForHevc(targetConversationIDs, hevc);
    var direct = split.direct;
    var succeeded = 0;
    var failed = 0;

    if (direct.isNotEmpty && canBatchForwardOnServer(sources)) {
      try {
        final sourceMsgIDs = _sortForwardSources(sources).map((m) => m.msgID).toList();
        await _api.batchForward(
          sourceMsgIDs: sourceMsgIDs,
          targetConversationIDs: direct,
          caption: caption,
        );
        succeeded += direct.length;
        direct = const [];
      } catch (e) {
        debugPrint('[ChatRepo] batch forward échoué, fallback client: $e');
      }
    }

    for (final convId in [...direct, ...split.reencode]) {
      final reencode =
          split.reencode.contains(convId) ? hevc : const <String>{};
      try {
        for (var i = 0; i < sources.length; i++) {
          final source = sources[i];
          await _forwardToConversation(
            source: source,
            conversationID: convId,
            caption: i == 0 ? caption : null,
            reencodeClientIds: reencode,
          );
        }
        succeeded++;
      } catch (e) {
        failed++;
        debugPrint('[ChatRepo] forward vers $convId échoué: $e');
      }
    }

    return ForwardResult(succeeded: succeeded, failed: failed);
  }

  List<LocalMessage> _sortForwardSources(List<LocalMessage> sources) {
    final sorted = List<LocalMessage>.from(sources)
      ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
    return sorted;
  }

  Future<void> _forwardToConversation({
    required LocalMessage source,
    required int conversationID,
    String? caption,
    Set<String> reencodeClientIds = const {},
  }) async {
    final effectiveCaption = resolveForwardCaption(source, caption);

    if (source.type == 0) {
      await sendText(
        conversationID: conversationID,
        content: source.content!.trim(),
        isForwarded: true,
      );
      return;
    }

    if (source.type == 5) {
      final loc = LocationPayload.tryParse(source.content);
      if (loc == null) {
        throw StateError(LocaleController.instance.l10n.invalidPositionForTransfer);
      }
      await sendLocation(
        conversationID: conversationID,
        location: loc,
        isForwarded: true,
      );
      return;
    }

    if (source.type == 7) {
      final contact = ContactPayload.tryParse(source.content);
      if (contact == null) {
        throw StateError(LocaleController.instance.l10n.invalidContactForTransfer);
      }
      await sendContact(
        conversationID: conversationID,
        contact: contact,
        isForwarded: true,
      );
      return;
    }

    final url = source.mediaUrl;
    if (url != null &&
        url.isNotEmpty &&
        !reencodeClientIds.contains(source.clientId)) {
      await sendMedia(
        conversationID: conversationID,
        type: source.type,
        mediaUrl: url,
        mediaName: source.mediaName,
        mediaDuration: source.mediaDuration,
        mediaSize: source.mediaSize,
        mediaPageCount: source.mediaPageCount,
        mediaThumb: source.mediaThumb,
        localMediaPath: source.localMediaPath,
        content: effectiveCaption,
        isForwarded: true,
      );
      return;
    }

    // Vidéo HEVC vers une discussion qui ne le lit pas : renvoyée depuis le
    // fichier local, l'envoi la convertit en H.264.
    final file = localMediaFileForForward(source);
    if (file == null) {
      throw StateError(LocaleController.instance.l10n.mediaUnavailableForTransfer);
    }

    await sendMediaFile(
      conversationID: conversationID,
      type: source.type,
      file: file,
      mediaName: source.mediaName,
      mediaDuration: source.mediaDuration,
      content: effectiveCaption,
      isForwarded: true,
    );
  }

  /// Renvoie tous les messages en attente (appelé à la reconnexion socket).
  /// Gère AUSSI les uploads de fichier qui n'ont pas pu aboutir : si un
  /// message porte `pendingUploadPath` sans `mediaUrl`, on relance l'upload
  /// avant l'émission du message:send.
  Future<void> flushOutbox() => _outbox.flushOutbox();

  /// True s'il reste des messages en outbox (horloge).
  Future<bool> hasSyncPending() => _dao.hasSyncPending();

  Future<void> editMessage(int msgID, String content) async {
    // Modifier un message est émettre : refusé sans abonnement, AVANT la mise à
    // jour locale — sinon l'écran montrerait un texte que le serveur a refusé.
    if (!_outgoingAllowed()) return;
    await _dao.updateContentByServerId(msgID, content);
    // Aperçu à jour si c'était le dernier message.
    final convID = await _conversationIdForMsg(msgID);
    if (convID != null) await _recomputeSummary(convID);
    try {
      await _api.editMessage(msgID, content);
    } catch (e) {
      debugPrint('[ChatRepo] editMessage échouée: $e');
    }
  }

  Future<int?> _conversationIdForMsg(int msgID) async {
    if (msgID == 0) return null;
    final row = await (_db.select(_db.localMessages)
          ..where((m) => m.msgID.equals(msgID))
          ..limit(1))
        .getSingleOrNull();
    return row?.conversationID;
  }

  /// Supprime un ou plusieurs messages (délègue au batch si nécessaire).
  /// [conversationID] sert à rafraîchir l'aperçu.
  /// Pour les optimistes (msgID=0), passer [clientIds] — jamais « tous les pending ».
  Future<void> deleteMessage(
    int msgID, {
    bool forAll = false,
    int? conversationID,
    String? clientId,
  }) async {
    await deleteMessages(
      msgID > 0 ? [msgID] : const [],
      forAll: forAll,
      conversationID: conversationID,
      clientIds: clientId != null && clientId.isNotEmpty ? [clientId] : null,
    );
  }

  Future<void> deleteMessages(
    List<int> msgIDs, {
    bool forAll = false,
    int? conversationID,
    List<String>? clientIds,
  }) async {
    // Collecte les conversationID affectées pour rafraîchir les aperçus.
    final affectedConvIDs = <int>{};
    if (conversationID != null) affectedConvIDs.add(conversationID);

    // 1. Messages confirmés (msgID > 0)
    final serverIds = msgIDs.where((id) => id > 0).toSet().toList();
    if (serverIds.isNotEmpty) {
      // Récupère les conversationID avant suppression, et ce qui n'était pas
      // déjà supprimé (c'est ce que l'on rendrait si le serveur refusait).
      final wasVisible = <int>[];
      for (final id in serverIds) {
        final msg = await (_db.select(_db.localMessages)
              ..where((m) => m.msgID.equals(id))
              ..limit(1))
            .getSingleOrNull();
        if (msg != null) {
          affectedConvIDs.add(msg.conversationID);
          if (!msg.isDeleted) wasVisible.add(id);
        }
      }
      if (forAll) {
        await _dao.softDeleteManyByServerId(serverIds);
      } else {
        await _dao.softDeleteManyForUser(serverIds, _myId);
      }
      try {
        await _api.deleteMessages(serverIds, forAll: forAll);
      } catch (e) {
        debugPrint('[ChatRepo] deleteMessages échouée: $e');
        // « Pour tous » : le serveur décide (72 h, droits). S'il refuse, le message
        // reste visible chez tous les autres : on le rend aussi ici, au lieu de
        // laisser l'expéditeur croire qu'il a disparu pour tout le monde, et on
        // remonte l'erreur pour que l'écran la dise. « Pour moi » ne change pas :
        // c'est une préférence locale, sans conséquence pour les autres.
        if (forAll && _isDeletionRefusal(e)) {
          await _dao.restoreManyByServerId(wasVisible);
          for (final convId in affectedConvIDs) {
            await _recomputeSummary(convId);
          }
          rethrow;
        }
      }
    }

    // 2. Messages en attente (msgID = 0) — ciblés par clientId uniquement.
    final pendingIds = (clientIds ?? const <String>[])
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    if (pendingIds.isNotEmpty) {
      for (final cid in pendingIds) {
        final row = await (_db.select(_db.localMessages)
              ..where((m) => m.clientId.equals(cid))
              ..limit(1))
            .getSingleOrNull();
        if (row != null) affectedConvIDs.add(row.conversationID);
      }
      await _dao.softDeletePendingByClientIds(
        pendingIds,
        _myId,
        forAll: forAll,
      );
    }

    // 3. Réaligner l'aperçu de chaque conversation sur son dernier message réel
    //    (et non forcer « supprimé » : si le message effacé n'était pas le
    //    dernier, l'aperçu doit rester le vrai dernier message).
    for (final convId in affectedConvIDs) {
      await _recomputeSummary(convId);
    }
  }

  /// Un refus DÉFINITIF du serveur (72 h dépassées, droits, message inconnu) : on
  /// annule la suppression locale. Une panne réseau ou un 5xx n'en est pas un —
  /// la suppression locale reste et sera visible à la prochaine synchronisation.
  bool _isDeletionRefusal(Object e) {
    if (e is! TalkyException) return false;
    final s = e.statusCode;
    return s >= 400 && s < 500 && s != 408 && s != 429;
  }

  Future<void> retryMessage(String clientId) => _outbox.retryMessage(clientId);

  Future<void> setConversationPinned(int conversID, bool pinned) async {
    await _dao.setPinned(conversID, pinned);
    try {
      await _api.updateConversation(conversID, isPinned: pinned);
    } catch (e) {
      await _dao.setPinned(conversID, !pinned);
      rethrow;
    }
  }

  Future<void> setConversationsPinned(List<int> conversIDs, bool pinned) async {
    final ids = conversIDs.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    await _dao.setPinnedMany(ids, pinned);
    try {
      await _api.updateConversationsBatch(ids, isPinned: pinned);
    } catch (e) {
      debugPrint('[ChatRepo] setConversationsPinned échouée: $e');
      await syncConversations(force: true);
      rethrow;
    }
  }

  Future<void> setConversationArchived(int conversID, bool archived) async {
    await _dao.setArchived(conversID, archived);
    try {
      await _api.updateConversation(conversID, isArchived: archived);
    } catch (e) {
      await _dao.setArchived(conversID, !archived);
      rethrow;
    }
  }

  Future<void> setConversationsArchived(List<int> conversIDs, bool archived) async {
    final ids = conversIDs.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    await _dao.setArchivedMany(ids, archived);
    try {
      await _api.updateConversationsBatch(ids, isArchived: archived);
    } catch (e) {
      debugPrint('[ChatRepo] setConversationsArchived échouée: $e');
      await syncConversations(force: true);
      rethrow;
    }
  }

  Future<void> deleteConversations(List<int> conversIDs) async {
    final ids = conversIDs.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    await _dao.deleteConversations(ids);
    try {
      await _api.deleteConversations(ids);
    } catch (e) {
      debugPrint('[ChatRepo] deleteConversations échouée: $e');
      await syncConversations(force: true);
      rethrow;
    }
  }

  // ── GROUPES ─────────────────────────────────────────────────────────
  //
  // Ces opérations passaient auparavant en direct des écrans vers
  // TalkyApiClient. Elles remontent ici pour trois raisons :
  //
  // 1. chaque mutation renvoie la conversation enrichie, qui doit atterrir en
  //    Drift — seule source lue par la liste, la fiche groupe et le verrou du
  //    composeur ;
  // 2. les handlers socket vivent déjà dans ce fichier : deux chemins d'écriture
  //    concurrents sur la même ligne seraient une course garantie ;
  // 3. c'est la seule façon de les tester avec ChatTestHarness.
  //
  // TOUTES sont online-only et SANS écriture optimiste. Un retrait appliqué
  // localement puis refusé par le serveur (j'ai perdu mon rôle entre-temps)
  // est pire qu'un délai : l'utilisateur croirait l'action faite. Les LECTURES,
  // elles, restent offline-first depuis Drift, rôles compris.

  /// Ids des messages non lus qui me mentionnent, du plus ancien au plus
  /// récent. Dérivé du cache local : aucune requête réseau.
  Future<List<int>> unreadMentionMsgIds(int conversID, int myId) =>
      _dao.unreadMentionMsgIds(conversID, myId);

  /// Rafraîchit une conversation depuis le serveur et l'écrit en cache.
  Future<void> refreshConversation(int conversID) async {
    if (conversID <= 0) return;
    final raw = await _api.getConversation(conversID);
    await _upsertGroupResponse(raw);
  }

  Future<void> updateGroupInfo(
    int conversID, {
    String? groupName,
    String? groupPhoto,
    String? description,
  }) async {
    final raw = await _api.updateGroupInfo(
      conversID,
      groupName: groupName,
      groupPhoto: groupPhoto,
      description: description,
    );
    await _upsertGroupResponse(raw);
  }

  Future<void> updateGroupSettings(
    int conversID, {
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
    bool? hideHistoryForNewMembers,
    bool? onlyAdminsCanAddMembers,
  }) async {
    final raw = await _api.updateGroupSettings(
      conversID,
      onlyAdminsCanSend: onlyAdminsCanSend,
      onlyAdminsCanEditInfo: onlyAdminsCanEditInfo,
      hideHistoryForNewMembers: hideHistoryForNewMembers,
      onlyAdminsCanAddMembers: onlyAdminsCanAddMembers,
    );
    await _upsertGroupResponse(raw);
  }

  /// Nouvel ajouté : « Rester » — clear pendingJoinMsgID côté serveur.
  Future<void> ackGroupJoin(int conversID, {int? msgID}) async {
    final raw = await _api.ackGroupJoin(conversID, msgID: msgID);
    await _upsertGroupResponse(raw);
  }

  Future<void> addParticipants(int conversID, List<int> participantIDs) async {
    final ids = participantIDs.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    final raw = await _api.addParticipants(conversID, ids);
    await _upsertGroupResponse(raw);
  }

  Future<void> removeParticipant(int conversID, int userId) async {
    final raw = await _api.removeParticipant(conversID, userId);
    // Le serveur renvoie `{ alreadyGone: true }` sans conversation quand le
    // membre était déjà parti : rien à écrire, l'état voulu est déjà atteint.
    if (raw['conversID'] != null && raw['participants'] != null) {
      await _upsertGroupResponse(raw);
    } else {
      await refreshConversation(conversID);
    }
  }

  Future<void> setParticipantRole(int conversID, int userId, int role) async {
    final raw = await _api.setParticipantRole(conversID, userId, role);
    await _upsertGroupResponse(raw);
  }

  /// Quitte le groupe et le retire du cache.
  ///
  /// La suppression locale est faite APRÈS l'aller-retour réussi : si le
  /// serveur refuse, la conversation doit rester visible plutôt que de
  /// disparaître d'un écran auquel l'utilisateur appartient toujours.
  Future<void> leaveGroup(int conversID) async {
    await _api.leaveGroup(conversID);
    await _dao.deleteConversation(conversID);
  }

  /// Bascule « uniquement les mentions » sur un groupe.
  ///
  /// C'est ce qui rend enfin effectif le paramètre `mentionsOnly` de l'API,
  /// qu'aucun appelant ne passait jusqu'ici — et donc la colonne serveur
  /// correspondante, qui se comportait comme une sourdine totale.
  Future<void> setMentionsOnly(int conversID, bool value) async {
    final raw = await _api.updateConversationMute(
      conversID,
      mentionsOnly: value,
    );
    // La réponse de /mute ne porte que l'état de sourdine, pas la conversation
    // entière : on écrit ces seules colonnes plutôt que de passer par le
    // companion complet, qui viderait tout le reste.
    await _dao.upsertConversation(
      LocalConversationsCompanion(
        conversID: Value(conversID),
        mutedUntil: Value(_parseDate(raw['mutedUntil']?.toString())),
        muteForever: Value(raw['muteForever'] == 1 || raw['muteForever'] == true),
        mentionsOnly:
            Value(raw['mentionsOnly'] == 1 || raw['mentionsOnly'] == true),
      ),
    );
  }

  /// Écrit la conversation enrichie renvoyée par une mutation de groupe.
  Future<void> _upsertGroupResponse(Map<String, dynamic> raw) async {
    if (raw.isEmpty) return;
    final conv = Conversation.fromJson(raw);
    if (conv.conversID <= 0) return;
    await _dao.upsertConversation(_convToCompanion(conv, raw));
    final cutoff = _parseDate(conv.myHistoryCutoffAt);
    if (cutoff != null) {
      await _dao.deleteMessagesBefore(conv.conversID, cutoff);
    }
    await _recomputeSummary(conv.conversID);
  }

  Future<void> markAsRead(int conversationID) =>
      _receipts.markAsRead(conversationID);

  /// Re-sync de la conversation actuellement à l'écran après reconnexion.
  /// Évite à l'utilisateur de quitter/rouvrir la conv pour voir les messages
  /// reçus pendant la coupure. Ne marque lu que si l'app est au premier plan.
  Future<void> resyncActiveConversation() async {
    if (_activeConversationID == 0) return;
    if (_myId == 0) return;
    final convID = _activeConversationID;
    await syncMessages(convID, delta: true);
    if (!_appInForeground) return;
    await _dao.markConversationRead(convID, _myId);
    await _recomputeSummary(convID);
    try {
      _api.sendSocketEvent(SocketEvents.messageRead, {'conversationID': convID});
    } catch (_) {
      _pendingReadsRetry[convID] = (_pendingReadsRetry[convID] ?? 0);
    }
  }

  /// Ré-émet `joinConversation` pour la conv active après reconnexion (les
  /// rooms socket.io sont volatiles, le serveur ne les restaure pas).
  void rejoinActiveRoom() {
    if (_activeConversationID == 0) return;
    if (!_api.isSocketReady) return;
    _api.sendSocketEvent(
      SocketEvents.joinConversation,
      {'conversationID': _activeConversationID},
    );
  }

  Future<void> flushReceiptsCatchUp() => _receipts.flushReceiptsCatchUp();

  /// Rejeu des accusés de remise déposés par la couche push native.
  Future<void> flushNativeDeliveryAcks() => _receipts.flushNativeDeliveryAcks();

  /// Rejoue les actions de notification (réponse rapide, marquer lu) que la
  /// couche native n'a pas réussi à poster — réseau coupé, refresh token mort,
  /// process tué en plein POST.
  ///
  /// Pour un `reply`, `GET /messages/status?clientId=` d'abord : si le POST
  /// natif avait en réalité abouti (réponse HTTP perdue, watchdog), on ne
  /// renvoie RIEN — deuxième ceinture anti-doublon, indépendante de
  /// l'idempotence serveur. Sinon `sendText` avec LE MÊME clientId : la ligne
  /// locale et la ligne serveur se réconcilient par l'ack `message:sent`, et
  /// l'outbox porte la livraison si le socket n'est pas encore prêt.
  Future<void> flushPendingNotificationActions() async {
    if (_myId == 0) return;
    final pending = await PendingNotificationActionStore.takeAll();
    if (pending.isEmpty) return;
    debugPrint(
        '[ChatRepo] 🔁 flushPendingNotificationActions count=${pending.length}');
    for (final action in pending) {
      try {
        if (action.kind == PendingNotificationActionStore.kindReply) {
          final st = await _api.getMessageStatusByClientId(action.clientId!);
          if (st['found'] == true) {
            await PendingNotificationActionStore.remove(action);
            unawaited(syncMessages(action.conversationId, delta: true));
            continue;
          }
          await _sender.sendText(
            conversationID: action.conversationId,
            content: action.text ?? '',
            clientId: action.clientId,
          );
          await PendingNotificationActionStore.remove(action);
        } else {
          // Le POST est l'action en attente ; le marquage local est best-effort
          // (le serveur fait foi, le prochain refresh ramènerait unread=0).
          await _api.markConversationAsRead(action.conversationId);
          await PendingNotificationActionStore.remove(action);
          try {
            await _receipts.markAsReadLocal(action.conversationId);
          } catch (e) {
            debugPrint('[ChatRepo] markAsReadLocal après rejeu: $e');
          }
        }
      } catch (e) {
        debugPrint(
            '[ChatRepo] rejeu ${action.kind} conv=${action.conversationId}: $e');
        await PendingNotificationActionStore.bumpAttempts(action);
      }
    }
  }


  /// Batch upsert pour messages **entrants** (pas de matching optimiste).
  /// Une seule transaction Drift + prefetch média hors transaction.
  Future<Set<int>> _upsertIncomingServerMessagesBatch(
    List<Map<String, dynamic>> jsons, {
    bool prefetchMedia = false,
  }) async {
    if (jsons.isEmpty) return {};

    final companions = <LocalMessagesCompanion>[];
    final toPrefetch = <Map<String, dynamic>>[];
    final affected = <int>{};
    final existingKeys = <String>{};

    // Précharge les clés déjà présentes pour savoir quoi prefetch.
    final msgIds = <int>[];
    for (final j in jsons) {
      final msgID = _toInt(j['msgID']);
      if (msgID > 0) msgIds.add(msgID);
    }
    if (msgIds.isNotEmpty) {
      final existing = await (_db.select(_db.localMessages)
            ..where((m) => m.msgID.isIn(msgIds)))
          .get();
      for (final m in existing) {
        if (m.msgID > 0) existingKeys.add('srv_${m.msgID}');
      }
    }

    for (final json in jsons) {
      final msgID = _toInt(json['msgID']);
      final convID = _toInt(json['conversationID']);
      if (convID != 0) affected.add(convID);

      if (msgID == 0) {
        companions.add(_msgJsonToCompanion(json));
        continue;
      }

      final srvKey = 'srv_$msgID';
      companions.add(
        _msgJsonToCompanion(json).copyWith(clientId: Value(srvKey)),
      );

      if (prefetchMedia && !existingKeys.contains(srvKey)) {
        toPrefetch.add(json);
      }
    }

    if (companions.isNotEmpty) {
      await _dao.upsertMessages(companions);
      // Traduction sur l'appareil : le service relit lui-même ce qui reste à
      // traiter. Appelé après l'upsert, jamais avant, et sans `await` — rien
      // dans la synchronisation ne doit attendre une traduction.
      final translation = MessageTranslationService.maybeInstance;
      if (translation != null) {
        for (final convID in affected) {
          translation.scheduleScan(convID);
        }
      }
    }

    if (prefetchMedia && toPrefetch.isNotEmpty) {
      for (final json in toPrefetch) {
        _maybePrefetchIncomingMedia(json);
      }
    }

    return affected;
  }

  void _maybePrefetchIncomingMedia(Map<String, dynamic> json) {
    if (!MediaDownloadPreferences.isAutoDownloadEnabled) return;
    final isViewOnce = json['isViewOnce'] == 1 || json['isViewOnce'] == true;
    if (isViewOnce) return;
    final senderID = _toInt(json['senderID']);
    if (senderID != 0 && senderID == _myId) return;

    final msgID = _toInt(json['msgID']);
    final mtype = _toInt(json['type']);
    final mediaUrl = json['mediaUrl']?.toString();
    if (mediaUrl == null || mediaUrl.isEmpty) return;
    final mediaName = json['mediaName']?.toString();
    if (mtype == 1 || mtype == 2) {
      _cacheMedia(
        msgID,
        mediaUrl,
        type: mtype,
        isMine: false,
        isViewOnce: false,
        mediaName: mediaName,
      );
    } else if (mtype == 4) {
      _cacheMedia(
        msgID,
        mediaUrl,
        maxBytes: 5 * 1024 * 1024,
        type: 4,
        isMine: false,
        isViewOnce: false,
        mediaName: mediaName,
      );
    }
  }

  /// Upsert un message serveur et renvoie `true` s'il était nouveau en local.
  Future<bool> _upsertServerMsg(
    Map<String, dynamic> json, {
    bool prefetchMedia = false,
  }) async {
    final msgID = _toInt(json['msgID']);
    final convID = _toInt(json['conversationID']);
    if (msgID == 0) {
      await _dao.upsertMessage(_msgJsonToCompanion(json));
      return true;
    }

    final srvKey = 'srv_$msgID';
    final clientId = _clientIdFromJson(json);
    final content = json['content']?.toString();
    final mediaName = json['mediaName']?.toString();
    final serverAt = _parseDate(json['sendAt']);
    bool wasNew = false;
    await _db.transaction(() async {
      String? carriedLocalPath;
      DateTime? carriedClickSentAt;

      // Création d'un prédicat optimiste plus strict pour éviter d'associer
      // par erreur un message d'un autre utilisateur ayant le même contenu.
      var candidates = await (_db.select(_db.localMessages)
            ..where((m) {
              // Ligne déjà confirmée avec le même msgID mais clé différente
              final sameOtherKey =
                  m.msgID.equals(msgID) & m.clientId.equals(srvKey).not();

              // Base optimiste : même conversation et msgID==0
              final optimisticBase =
                  m.conversationID.equals(convID) & m.msgID.equals(0);

              // Match prioritaire par clientId si fourni par le serveur
              Expression<bool> optimistic = const Constant(false);
              if (clientId != null && clientId.isNotEmpty) {
                optimistic = optimisticBase & m.clientId.equals(clientId);
              } else if (content != null && content.isNotEmpty) {
                // Pour matcher sur le contenu, restreindre au messages dont
                // l'émetteur local est bien l'utilisateur courant (évite collisions)
                optimistic = optimisticBase &
                    m.content.equals(content) &
                    m.senderID.equals(_myId);
              } else if (mediaName != null && mediaName.isNotEmpty) {
                optimistic = optimisticBase &
                    m.mediaName.equals(mediaName) &
                    m.senderID.equals(_myId);
              }

              return sameOtherKey | optimistic;
            }))
          .get();

      // Fallback contenu/mediaName : ne garder qu'1 candidat récent (±5 s),
      // jamais supprimer plusieurs optimistes pour un seul ack serveur.
      if ((clientId == null || clientId.isEmpty) && candidates.isNotEmpty) {
        final confirmed = candidates.where((m) => m.msgID == msgID).toList();
        final optimistics = candidates.where((m) => m.msgID == 0).toList();
        if (optimistics.length > 1) {
          optimistics.sort((a, b) => b.sendAt.compareTo(a.sendAt));
          LocalMessage? best;
          if (serverAt != null) {
            for (final o in optimistics) {
              final delta = o.sendAt.difference(serverAt).abs();
              if (delta <= const Duration(seconds: 5)) {
                best = o;
                break;
              }
            }
          }
          best ??= optimistics.first;
          candidates = [...confirmed, best];
        }
      }

      // Nouveau message local si aucun candidat avec ce msgID confirmé
      wasNew = candidates.every((m) => m.msgID != msgID);

      String? carriedMediaThumb;
      int? carriedMediaSize;
      int? carriedMediaPageCount;
      String? carriedMentions;
      for (final m in candidates) {
        carriedLocalPath ??= m.localMediaPath;
        carriedClickSentAt ??= m.clickSentAt;
        carriedMediaThumb ??= m.mediaThumb;
        carriedMediaSize ??= m.mediaSize;
        carriedMediaPageCount ??= m.mediaPageCount;
        carriedMentions ??= m.mentionsJson;
        await (_db.delete(_db.localMessages)
              ..where((x) => x.clientId.equals(m.clientId)))
            .go();
      }

      // Insère une seule ligne normalisée `srv_<msgID>` (clé primaire stable).
      var companion =
          _msgJsonToCompanion(json).copyWith(clientId: Value(srvKey));
      if (carriedLocalPath != null) {
        companion = companion.copyWith(localMediaPath: Value(carriedLocalPath));
      }
      if (carriedClickSentAt != null) {
        companion = companion.copyWith(clickSentAt: Value(carriedClickSentAt));
      }
      // Préserve la vignette locale si le serveur (non migré) ne l'a pas renvoyée.
      if (carriedMediaThumb != null && !companion.mediaThumb.present) {
        companion = companion.copyWith(mediaThumb: Value(carriedMediaThumb));
      }
      if (carriedMediaSize != null && !companion.mediaSize.present) {
        companion = companion.copyWith(mediaSize: Value(carriedMediaSize));
      }
      if (carriedMediaPageCount != null && !companion.mediaPageCount.present) {
        companion = companion.copyWith(mediaPageCount: Value(carriedMediaPageCount));
      }
      // Filet pour un serveur qui n'aurait pas encore la colonne : sans lui, les
      // mentions écrites à l'envoi étaient perdues dès l'ack, la ligne
      // optimiste étant supprimée puis réinsérée depuis le seul JSON serveur.
      if (carriedMentions != null && companion.mentionsJson.value == null) {
        companion = companion.copyWith(mentionsJson: Value(carriedMentions));
      }

      debugPrint(
          '[ChatRepo] _upsertServerMsg msgID=$msgID conv=$convID candidates=${candidates.length} wasNew=$wasNew');
      await _dao.upsertMessage(companion);
    });

    // Traduction sur l'appareil, hors transaction et sans attente : la bulle
    // s'affiche d'abord en version originale, la traduction la remplace quand
    // elle arrive via le stream `watchMessages`.
    if (convID != 0) {
      MessageTranslationService.maybeInstance?.scheduleScan(convID);
    }

    // Préfetch médias reçus si auto-download activé (images, vidéos, fichiers < 5 Mo).
    // Les vues uniques ne sont jamais mises en cache. Les vocaux restent manuels.
    if (prefetchMedia && wasNew) {
      _maybePrefetchIncomingMedia(json);
    }
    return wasNew;
  }

  /// Télécharge un média reçu vers le cache app, met à jour [localMediaPath],
  /// puis exporte vers le stockage interne si la visibilité est activée.
  Future<String?> ensureReceivedMediaLocal({
    required int msgID,
    required String mediaUrl,
    required int type,
    required bool isMine,
    required bool isViewOnce,
    String? mediaName,
    String? existingLocalPath,
    int? maxBytes,
    void Function(double? progress)? onProgress,
  }) async {
    if (isViewOnce) return null;

    String? path = (existingLocalPath != null &&
            File(existingLocalPath).existsSync())
        ? existingLocalPath
        : null;

    if (path == null) {
      if (mediaUrl.isEmpty) return null;
      if (onProgress != null) {
        path = await _mediaCache.downloadWithProgress(
          mediaUrl,
          onProgress: onProgress,
          maxBytes: maxBytes,
        );
      } else {
        path = await _mediaCache.ensureCached(mediaUrl, maxBytes: maxBytes);
      }
      if (path == null) return null;
      if (msgID != 0) {
        await _dao.setLocalMediaPath(msgID, path);
      }
    }

    await AlanyaMediaExportService.instance.exportIfNeeded(
      msgID: msgID,
      type: type,
      localPath: path,
      isViewOnce: isViewOnce,
      isMine: isMine,
      mediaName: mediaName,
    );
    return path;
  }

  Future<void> _cacheMedia(
    int msgID,
    String url, {
    int? maxBytes,
    required int type,
    required bool isMine,
    required bool isViewOnce,
    String? mediaName,
  }) async {
    // Consulte la préférence ET le réseau : l'auto-téléchargement est actif par
    // défaut, mais restreint au Wi-Fi pour ne pas consommer le forfait de
    // l'utilisateur sans qu'il l'ait demandé.
    if (!await MediaDownloadPreferences.shouldAutoDownloadNow()) return;
    await ensureReceivedMediaLocal(
      msgID: msgID,
      mediaUrl: url,
      type: type,
      isMine: isMine,
      isViewOnce: isViewOnce,
      mediaName: mediaName,
      maxBytes: maxBytes,
    );
  }

  /// Lie un fichier déjà présent dans le cache disque au message (legacy auto-cache).
  Future<String?> adoptCachedVoicePath({
    required int msgID,
    required String mediaUrl,
  }) async {
    final resolved = await VoiceAssetResolver(
      mediaCache: _mediaCache,
      dao: _dao,
    ).resolve(
      serverMsgId: msgID,
      isMe: false,
      mediaUrl: mediaUrl,
    );
    return resolved?.path;
  }

  /// Réconcilie les chemins locaux des messages vocaux d'une conversation.
  Future<void> reconcileVoiceLocalPaths(int conversationId) async {
    final messages = await _dao.getVoiceMessages(conversationId);
    final resolver = VoiceAssetResolver(mediaCache: _mediaCache, dao: _dao);
    for (final m in messages) {
      if (m.msgID == 0) continue;
      final isMe = m.senderID == _myId;
      await resolver.resolve(
        serverMsgId: m.msgID,
        isMe: isMe,
        dbPath: m.localMediaPath,
        pendingPath: isMe ? m.pendingUploadPath : null,
        mediaUrl: m.mediaUrl,
      );
    }
  }

  /// Téléchargement manuel d'un audio reçu (vocal ou musique), avec
  /// progression. Le plafond par défaut est celui des vocaux ; l'appelant le
  /// relève pour un morceau.
  Future<String?> downloadVoiceMessage({
    required int msgID,
    required String mediaUrl,
    void Function(double? progress)? onProgress,
    int maxBytes = 15 * 1024 * 1024,
  }) async {
    if (msgID == 0) return null;
    final path = await _mediaCache.downloadWithProgress(
      mediaUrl,
      onProgress: onProgress,
      maxBytes: maxBytes,
    );
    if (path != null) await _dao.setLocalMediaPath(msgID, path);
    return path;
  }


  /// (Dés)épingle un message. Optimistic : on écrit localement d'abord pour un
  /// retour instantané, puis on confirme côté serveur (rollback en cas d'échec).
  Future<void> setMessagePinned(int msgID, bool pinned) async {
    if (msgID == 0) return;
    await _dao.setMessagePinnedByServerId(msgID, pinned);
    try {
      await _api.pinMessage(msgID, pinned);
    } catch (e) {
      await _dao.setMessagePinnedByServerId(msgID, !pinned);
      rethrow;
    }
  }


  /// Signale au serveur qu'un média à vue unique a été consulté, puis marque
  /// le message consommé localement (efface toute trace ré-ouvrable).
  Future<void> markViewed(int msgID) async {
    if (msgID == 0) return;
    await _dao.markViewedByServerId(msgID);
    try {
      await _api.markViewed(msgID);
    } catch (e) {
      debugPrint('[ChatRepo] markViewed échouée: $e');
    }
  }


  /// Toutes les réactions d'une conversation, regroupées côté écran par
  /// `msgID` (voir [ReactionsByMessage] côté UI).
  Stream<List<LocalMessageReaction>> watchReactions(int conversationID) =>
      _dao.watchReactions(conversationID);

  /// Pose/remplace ma réaction sur [msgID]. Optimistic avec rollback — logique
  /// portée par [SocketMessageHandlers] pour rester la source unique de vérité
  /// partagée avec l'événement socket entrant.
  Future<void> setReaction(
    int msgID,
    String emoji, {
    int? conversationID,
  }) =>
      _handlers.setReaction(msgID, emoji, conversationID: conversationID);

  /// Retire ma réaction sur [msgID].
  Future<void> removeReaction(int msgID, {int? conversationID}) =>
      _handlers.removeReaction(msgID, conversationID: conversationID);

  /// Hydratation initiale des réactions d'une conversation à l'ouverture du
  /// chat (les mises à jour suivantes arrivent en direct par socket).
  Future<void> syncReactions(int conversationID) async {
    try {
      final raw = await _api.getReactions(conversationID);
      final companions = raw
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .map((json) {
        final msgID = _toInt(json['msgID']);
        final userID = _toInt(json['userID']);
        final emoji = json['emoji']?.toString() ?? '';
        return LocalMessageReactionsCompanion.insert(
          msgID: msgID,
          userID: userID,
          conversationID: conversationID,
          emoji: emoji,
          reactedAt: Value(_parseDate(json['reactedAt']) ?? DateTime.now()),
        );
      })
          .where((c) =>
              c.msgID.value != 0 && c.userID.value != 0 && c.emoji.value.isNotEmpty)
          .toList();
      await _dao.mergeReactionsFromServer(
        conversationID,
        companions,
        preserveKeys: _handlers.pendingReactionKeys,
      );
    } catch (e) {
      debugPrint('[ChatRepo] syncReactions échouée: $e');
    }
  }


  Future<void> _recomputeSummary(int conversID) {
    return _reducer.recompute(conversID, _myId);
  }

  /// Réécrit le contenu d'une carte de trajet (type 9) déjà en cache.
  ///
  /// Appelé sur `trip:card_update`, quand le serveur a fait passer un trajet
  /// d'un état à un autre. Sans cette écriture, la bulle et l'aperçu de la
  /// conversation restaient sur l'ancien état jusqu'au prochain sync HTTP :
  /// « bien arrivée » continuait de s'afficher « trajet en cours ».
  ///
  /// Volontairement, on ne touche ni à `sendAt` ni au compteur de non-lus — une
  /// transition d'état n'est pas un nouveau message.
  Future<void> updateTripCard(int tripId, String content) async {
    final lignes = await (_db.select(_db.localMessages)
          ..where((m) => m.type.equals(kTripMessageType)))
        .get();

    final concernees = lignes.where((m) {
      final p = TripCardPayload.tryParse(m.content);
      return p != null && p.tripId == tripId;
    }).toList();
    if (concernees.isEmpty) return;

    final convs = <int>{};
    for (final m in concernees) {
      await (_db.update(_db.localMessages)..where((r) => r.msgID.equals(m.msgID)))
          .write(LocalMessagesCompanion(content: Value(content)));
      convs.add(m.conversationID);
    }
    for (final c in convs) {
      await _recomputeSummary(c);
    }
  }

  LocalConversationsCompanion _convToCompanion(Conversation c, Map<String, dynamic> raw) {
    return LocalConversationsCompanion(
      conversID: Value(c.conversID),
      isGroup: Value(c.isGroup),
      groupName: Value(c.groupName),
      groupPhoto: Value(c.groupPhoto),
      lastMessage: Value(
        c.lastMessage == null
            ? null
            : normalizeConversationPreview(c.lastMessage),
      ),
      lastMessageAt: Value(_parseDate(c.lastMessageAt)),
      lastMessageSenderID: Value(c.lastMessageSenderID),
      lastMessageType: Value(c.lastMessageType),
      lastMessageStatus: c.lastMessageStatus != null
          ? Value(c.lastMessageStatus)
          : const Value.absent(),
      unreadCount: Value(c.unreadCount),
      isPinned: Value(c.isPinned),
      isArchived: Value(c.isArchived),
      participantsJson: Value(encodeParticipants(raw['participants'] as List? ?? [])),
      description: Value(c.description),
      createdBy: Value(c.createdBy),
      metaUpdatedAt: Value(_parseDate(c.updatedAt)),
      onlyAdminsCanSend: Value(c.onlyAdminsCanSend),
      onlyAdminsCanEditInfo: Value(c.onlyAdminsCanEditInfo),
      hideHistoryForNewMembers: Value(c.hideHistoryForNewMembers),
      onlyAdminsCanAddMembers: Value(c.onlyAdminsCanAddMembers),
      myRole: Value(c.myRole),
      mutedUntil: Value(_parseDate(c.mutedUntil)),
      muteForever: Value(c.muteForever),
      mentionsOnly: Value(c.mentionsOnly),
      myPendingJoinMsgID: Value(c.myPendingJoinMsgID),
      myHistoryCutoffAt: Value(_parseDate(c.myHistoryCutoffAt)),
    );
  }

  /// Variante PARTIELLE, pour la trame socket `conversation:updated`.
  ///
  /// Cette trame ne porte que les métadonnées de groupe : elle omet
  /// délibérément `unreadCount`, `isPinned`, `isArchived` et `lastMessage*`,
  /// qui diffèrent d'un membre à l'autre. On écrit donc `Value.absent()` pour
  /// eux — les recopier depuis un payload qui ne les contient pas remettrait
  /// tout à zéro et ferait disparaître un badge légitime.
  ///
  /// `myRole` et l'état de sourdine sont eux aussi absents de la trame (ce sont
  /// des champs par-utilisateur) : ils restent tels quels en local et seront
  /// rafraîchis au prochain sync HTTP. Le rôle de CHAQUE participant, lui,
  /// voyage bien dans `participants[]` — c'est ce qui permet à la fiche groupe
  /// de se mettre à jour en direct après une promotion.
  LocalConversationsCompanion _convToPartialCompanion(
    Conversation c,
    Map<String, dynamic> raw,
  ) {
    return LocalConversationsCompanion(
      conversID: Value(c.conversID),
      isGroup: Value(c.isGroup),
      groupName: Value(c.groupName),
      groupPhoto: Value(c.groupPhoto),
      description: Value(c.description),
      createdBy: Value(c.createdBy),
      metaUpdatedAt: Value(_parseDate(c.updatedAt)),
      onlyAdminsCanSend: Value(c.onlyAdminsCanSend),
      onlyAdminsCanEditInfo: Value(c.onlyAdminsCanEditInfo),
      hideHistoryForNewMembers: Value(c.hideHistoryForNewMembers),
      onlyAdminsCanAddMembers: Value(c.onlyAdminsCanAddMembers),
      // Champs par-utilisateur portés par les trames personnalisées
      // (ack-join, nouvel ajouté après member_added).
      myPendingJoinMsgID: Value(c.myPendingJoinMsgID),
      myHistoryCutoffAt: Value(_parseDate(c.myHistoryCutoffAt)),
      participantsJson:
          Value(encodeParticipants(raw['participants'] as List? ?? [])),
    );
  }

  /// Normalise le champ `mentions` du serveur vers la colonne locale.
  ///
  /// Trois formes possibles à l'arrivée : une `List` d'ids (cas courant), la
  /// chaîne `"all"` (marqueur @Tous d'un grand groupe), ou une chaîne JSON si
  /// un intermédiaire a sérialisé la colonne.
  static String? _mentionsFromJson(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      // Déjà du JSON (`"all"`, `[45,46]`) : on le garde tel quel, decodeMentions
      // sait le relire.
      return trimmed;
    }
    if (raw is List) {
      return encodeMentions(
        raw
            .map((e) => (e is num) ? e.toInt() : int.tryParse('$e'))
            .whereType<int>()
            .toList(),
      );
    }
    return null;
  }

  LocalMessagesCompanion _msgJsonToCompanion(Map<String, dynamic> j) {
    final rawClient = _clientIdFromJson(j);
    final clientId = (rawClient != null && rawClient.isNotEmpty)
        ? rawClient
        : 'srv_${_toInt(j['msgID'])}';
    return LocalMessagesCompanion(
      clientId: Value(clientId),
      msgID: Value(_toInt(j['msgID'])),
      conversationID: Value(_toInt(j['conversationID'])),
      senderID: Value(_toInt(j['senderID'])),
      content: Value(j['content']?.toString()),
      type: Value(_toInt(j['type'])),
      status: Value(_toInt(j['status'], fallback: 1)),
      sendAt: Value(_parseDate(j['sendAt']) ?? DateTime.now()),
      // clickSentAt est désormais synchronisé avec le serveur (persisté à
      // l'envoi) : on l'hydrate depuis le JSON pour que le destinataire le
      // voie aussi. `_upsertServerMsg` conserve en priorité la valeur locale
      // déjà connue le cas échéant (même valeur, capturée avant l'aller-retour).
      clickSentAt: Value(_parseDate(j['clickSentAt'])),
      messageTz: Value(j['messageTz']?.toString()),
      messageTzOffset: Value(j['messageTzOffset'] == null ? null : _toInt(j['messageTzOffset'])),
      deliveredAt: Value(_parseDate(j['deliveredAt'])),
      readAt: Value(_parseDate(j['readAt'])),
      mediaUrl: Value(normalizeBackendUrl(j['mediaUrl']?.toString())),
      mediaName: Value(j['mediaName']?.toString()),
      mediaDuration: Value(j['mediaDuration'] == null ? null : _toInt(j['mediaDuration'])),
      mediaSize: j['mediaSize'] == null
          ? const Value.absent()
          : Value(_toInt(j['mediaSize'])),
      mediaPageCount: j['mediaPageCount'] == null
          ? const Value.absent()
          : Value(_toInt(j['mediaPageCount'])),
      // Vignette base64 : on ne l'écrase que si le serveur en fournit une
      // (backend non migré ⇒ champ absent ⇒ on préserve la valeur locale).
      mediaThumb: j['mediaThumb'] == null
          ? const Value.absent()
          : Value(j['mediaThumb'].toString()),
      replyToID: j['replyToID'] == null
          ? const Value.absent()
          : Value(_toInt(j['replyToID'])),
      // Préserve la citation locale si le serveur renvoie null (ID non résolu).
      replyToContent: (j['replyToContent'] == null ||
              j['replyToContent'].toString().trim().isEmpty)
          ? const Value.absent()
          : Value(j['replyToContent'].toString()),
      isEdited: Value(j['isEdited'] == 1 || j['isEdited'] == true),
      editedAt: Value(_parseDate(j['editedAt'])),
      // Ces champs ne doivent JAMAIS être écrasés par le sync serveur.
      // isDeleted est set par softDeleteMany* (action locale) ou via socket.
      // deletedForID est purement local (suppression « pour moi »).
      isDeleted: const Value.absent(),
      deletedForID: const Value.absent(),
      isStatusReply: Value(_toInt(j['isStatusReply'])),
      isForwarded: Value(j['isForwarded'] == 1 || j['isForwarded'] == true),
      isPinned: Value(j['isPinned'] == 1 || j['isPinned'] == true),
      isViewOnce: Value(j['isViewOnce'] == 1 || j['isViewOnce'] == true),
      // On ne pose viewedAt QUE si le serveur confirme la vue. Sinon on laisse
      // la colonne intacte (Value.absent) : un média déjà ouvert localement le
      // reste, même si une resync arrive avant que le serveur ait persisté /view.
      viewedAt: (j['isViewOnce'] == 1 || j['isViewOnce'] == true) && _toInt(j['viewedByMe']) > 0
          ? Value(DateTime.now())
          : const Value.absent(),
      // Le serveur renvoie la colonne `mentions` (MSG_SELECT fait SELECT m.*).
      // Sans ce mapping, elle était écrite NULL à CHAQUE ingestion serveur —
      // socket, getMessages et /messages/sync passant tous par ici — donc le
      // compteur du bouton « @ », le saut, la bulle teintée et le surlignage
      // étaient morts.
      //
      // Une colonne JSON MySQL arrive DÉJÀ PARSÉE côté Dart (List, ou la
      // chaîne « all » du marqueur @Tous), pas comme une chaîne JSON : on
      // repasse par l'encodage local, qui normalise aussi null et [] en null
      // pour préserver le filtre `IS NOT NULL` du DAO.
      mentionsJson: Value(_mentionsFromJson(j['mentions'])),
      senderNom: Value(j['sender_nom']?.toString()),
      senderPseudo: Value(j['sender_pseudo']?.toString()),
      senderAvatar: Value(normalizeBackendUrl(j['sender_avatar']?.toString())),
      syncPending: const Value(false),
      lastEmittedAt: const Value(null),
    );
  }


  static String? _clientIdFromJson(Map<String, dynamic> j) {
    final v = j['clientId'] ?? j['clientID'];
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static int _toInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}

