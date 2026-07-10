import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../utils/media_album.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'media_cache_service.dart';

/// Cache lecture-seule pour les modules secondaires (contacts préférés,
/// historique d'appels, meetings, statuses). Patron commun :
/// - `watchXxx()` expose un stream Drift réactif (UI s'hydrate offline)
/// - `syncXxx()` fetch l'API et upsert (à appeler en background)
///
/// Aucune écriture utilisateur n'est différée ici (les mutations comme
/// addContact/createMeeting restent online via TalkyApiClient).
class LocalCacheRepository {
  final AppDatabase _db;
  final TalkyApiClient _api;
  final MediaCacheService _media;

  LocalCacheRepository({
    required AppDatabase db,
    required TalkyApiClient api,
    MediaCacheService? media,
  })  : _db = db,
        _api = api,
        _media = media ?? MediaCacheService();

  // ── CONTACTS PRÉFÉRÉS ───────────────────────────────────────────────

  Stream<List<LocalUser>> watchPreferredContacts() {
    return (_db.select(_db.localUsers)
          ..where((u) => u.isPreferredContact.equals(true))
          ..orderBy([(u) => OrderingTerm(expression: u.nom)]))
        .watch();
  }

  Future<List<LocalUser>> getPreferredContactsOnce() {
    return (_db.select(_db.localUsers)
          ..where((u) => u.isPreferredContact.equals(true))
          ..orderBy([(u) => OrderingTerm(expression: u.nom)]))
        .get();
  }

  /// Retourne le cache immédiatement. Si [syncInBackground] est vrai,
  /// lance [syncPreferredContacts] sans bloquer l'appelant.
  Future<List<LocalUser>> loadPreferredContacts({
    bool syncInBackground = true,
  }) async {
    final local = await getPreferredContactsOnce();
    if (syncInBackground) {
      unawaited(syncPreferredContacts());
    }
    return local;
  }

  /// Synchronise depuis l'API puis retourne la liste à jour.
  Future<List<LocalUser>> syncAndGetPreferredContacts() async {
    await syncPreferredContacts();
    return getPreferredContactsOnce();
  }

  /// Rafraîchit la liste des contacts préférés depuis l'API et met à jour
  /// le cache local. Best-effort : en cas d'erreur réseau, retourne sans
  /// rien casser (le cache reste utilisable).
  Future<void> syncPreferredContacts() async {
    try {
      final raw = await _api.getContacts();
      final now = DateTime.now();
      // Step 1: récupérer la liste actuelle pour détecter les retraits.
      final previousIds =
          (await getPreferredContactsOnce()).map((u) => u.alanyaID).toSet();
      final newIds = <int>{};
      await _db.batch((b) {
        for (final r in raw.whereType<Map<String, dynamic>>()) {
          final u = User.fromJson(r);
          if (u.alanyaID == 0) continue;
          newIds.add(u.alanyaID);
          b.insert(
            _db.localUsers,
            _userToCompanion(u, preferred: true, cachedAt: now),
            onConflict: DoUpdate((_) => _userToCompanion(u, preferred: true, cachedAt: now)),
          );
        }
      });
      // Step 2 : démarquer ceux qui ne sont plus dans la liste préférée
      // (sans les supprimer — ils peuvent rester en cache comme "auteur connu").
      final removed = previousIds.difference(newIds);
      if (removed.isNotEmpty) {
        await (_db.update(_db.localUsers)
              ..where((u) => u.alanyaID.isIn(removed)))
            .write(const LocalUsersCompanion(isPreferredContact: Value(false)));
      }
    } catch (e) {
      debugPrint('[LocalCacheRepo] syncPreferredContacts échouée: $e');
    }
  }

  /// Stocke un user vu de passage (résolu via getUserById) — utile pour
  /// peupler le roster d'appel groupe ou l'affichage de messages.
  Future<void> upsertKnownUser(User u, {bool preferred = false}) async {
    await _db.into(_db.localUsers).insertOnConflictUpdate(
          _userToCompanion(u, preferred: preferred, cachedAt: DateTime.now()),
        );
  }

  /// Récupère un user du cache local (null si jamais vu).
  Future<LocalUser?> getKnownUser(int alanyaID) {
    return (_db.select(_db.localUsers)..where((u) => u.alanyaID.equals(alanyaID)))
        .getSingleOrNull();
  }

  // ── HISTORIQUE D'APPELS ─────────────────────────────────────────────

  Stream<List<LocalCall>> watchCalls() {
    return (_db.select(_db.localCalls)
          ..orderBy([(c) => OrderingTerm(expression: c.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Écrit immédiatement un appel finalisé reçu via socket `call_log_updated`.
  Future<void> upsertCallFromPayload(
    dynamic data, {
    required int myId,
    Future<void> Function()? onMissingConversation,
  }) async {
    try {
      if (data is! Map) return;
      final callRaw = data['call'];
      if (callRaw is! Map) return;

      final call = Call.fromJson(Map<String, dynamic>.from(callRaw));
      if (call.idCall == 0) return;

      await _upsertCall(call, myId: myId);

      final conversID = _toInt(data['conversationID']);
      if (conversID == 0) return;

      final exists = await (_db.select(_db.localConversations)
            ..where((c) => c.conversID.equals(conversID)))
          .getSingleOrNull();
      if (exists != null) {
        await _bumpConversationForCall(conversID: conversID, call: call);
      } else if (onMissingConversation != null) {
        await onMissingConversation();
      }
    } catch (e) {
      debugPrint('[LocalCacheRepo] upsertCallFromPayload échouée: $e');
    }
  }

  Future<void> syncCalls({required int myId}) async {
    try {
      final raw = await _api.getCallHistory();
      final now = DateTime.now();
      await _db.batch((b) {
        for (final r in raw.whereType<Map<String, dynamic>>()) {
          final c = Call.fromJson(r);
          _insertCallIntoBatch(b, c, myId: myId, now: now);
        }
      });
    } catch (e) {
      debugPrint('[LocalCacheRepo] syncCalls échouée: $e');
    }
  }

  // ── MEETINGS ────────────────────────────────────────────────────────

  Stream<List<LocalMeeting>> watchMeetings() {
    return (_db.select(_db.localMeetings)
          ..orderBy([(m) => OrderingTerm(expression: m.startTime, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> syncMeetings() async {
    try {
      final raw = await _api.getMeetings();
      await _db.batch((b) {
        for (final r in raw.whereType<Map<String, dynamic>>()) {
          final m = Meeting.fromJson(r);
          if (m.idMeeting == 0) continue;
          b.insert(
            _db.localMeetings,
            _meetingToCompanion(m, r),
            onConflict: DoUpdate((_) => _meetingToCompanion(m, r)),
          );
        }
      });
    } catch (e) {
      debugPrint('[LocalCacheRepo] syncMeetings échouée: $e');
    }
  }

  // ── STATUSES ────────────────────────────────────────────────────────

  Stream<List<LocalStatuse>> watchStatuses() {
    final now = DateTime.now();
    return (_db.select(_db.localStatuses)
          ..where((s) => s.expiresAt.isBiggerThanValue(now))
          ..orderBy([(s) => OrderingTerm(expression: s.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<void> upsertStatus(Statut s, {required bool isMine}) async {
    final companion = LocalStatusesCompanion(
      idStatut: Value(s.id),
      authorID: Value(s.alanyaID),
      authorNom: Value(s.nom),
      authorAvatar: Value(s.avatarUrl),
      type: Value(s.type),
      textContent: Value(s.text),
      mediaUrl: Value(s.mediaUrl),
      backgroundColor: Value(s.backgroundColor),
      mediaDurationMs: Value(s.mediaDurationMs),
      createdAt: Value(_parseDate(s.createdAt) ?? DateTime.now()),
      expiresAt: Value(_parseDate(s.expiredAt) ?? DateTime.now().add(const Duration(hours: 24))),
      isMine: Value(isMine),
    );
    await _db.into(_db.localStatuses).insertOnConflictUpdate(companion);
    // Pré-cache image / audio des statuts (vidéos restent on-demand).
    if (s.mediaUrl != null && (s.type == 1 || s.type == 3)) {
      _media.ensureCached(s.mediaUrl!).then((path) {
        if (path == null) return;
        (_db.update(_db.localStatuses)..where((x) => x.idStatut.equals(s.id)))
            .write(LocalStatusesCompanion(localMediaPath: Value(path)));
      });
    }
  }

  Future<void> purgeExpiredStatuses() async {
    await (_db.delete(_db.localStatuses)
          ..where((s) => s.expiresAt.isSmallerThanValue(DateTime.now())))
        .go();
  }

  Future<void> deleteStatusById(int id) async {
    await (_db.delete(_db.localStatuses)
          ..where((s) => s.idStatut.equals(id)))
        .go();
  }

  /// Vide les caches secondaires (contacts, appels, meetings, statuts).
  Future<void> clearSession() async {
    await _db.delete(_db.localStatuses).go();
    await _db.delete(_db.localMeetings).go();
    await _db.delete(_db.localCalls).go();
    await _db.delete(_db.localUsers).go();
  }

  // ── Helpers de conversion ───────────────────────────────────────────

  LocalUsersCompanion _userToCompanion(
    User u, {
    bool? preferred,
    required DateTime cachedAt,
  }) {
    return LocalUsersCompanion(
      alanyaID: Value(u.alanyaID),
      nom: Value(u.nom),
      pseudo: Value(u.pseudo),
      alanyaPhone: Value(u.alanyaPhone),
      email: Value(u.email),
      avatarUrl: Value(u.avatarUrl),
      idPays: Value(u.idPays),
      paysLibelle: Value(u.paysLibelle),
      isOnline: Value(u.isOnline),
      lastSeen: Value(DateTime.tryParse(u.lastSeen)),
      typeCompte: Value(u.typeCompte),
      isPreferredContact:
          preferred != null ? Value(preferred) : const Value.absent(),
      cachedAt: Value(cachedAt),
    );
  }

  Future<void> _upsertCall(Call c, {required int myId}) async {
    if (c.idCall == 0) return;
    final now = DateTime.now();
    await _db.batch((b) {
      _insertCallIntoBatch(b, c, myId: myId, now: now);
    });
  }

  void _insertCallIntoBatch(
    Batch b,
    Call c, {
    required int myId,
    required DateTime now,
  }) {
    if (c.idCall == 0) return;
    // Snapshot du correspondant : on doit prendre celui qui n'est PAS
    // l'utilisateur courant — sinon les appels sortants stockent mon
    // propre nom/avatar et l'UI offline les affiche à la place du contact.
    final other = (c.idCaller == myId) ? c.receiver : c.caller;
    b.insert(
      _db.localCalls,
      _callToCompanion(c, other),
      onConflict: DoUpdate((_) => _callToCompanion(c, other)),
    );
    if (other != null) {
      b.insert(
        _db.localUsers,
        _userToCompanion(other, cachedAt: now),
        onConflict: DoUpdate((_) => _userToCompanion(other, cachedAt: now)),
      );
    }
  }

  Future<void> _bumpConversationForCall({
    required int conversID,
    required Call call,
  }) async {
    final preview = call.isVideo ? '📹 Appel vidéo' : '📞 Appel vocal';
    final type = call.isVideo ? 6 : 5;
    final at = _parseDate(call.createdAt) ?? DateTime.now();
    final normalized = normalizeConversationPreview(preview);
    final companion = LocalConversationsCompanion(
      conversID: Value(conversID),
      lastMessage: Value(
        normalized.length > 200 ? normalized.substring(0, 200) : normalized,
      ),
      lastMessageAt: Value(at),
      lastMessageType: Value(type),
      lastMessageSenderID: Value(call.idCaller),
    );
    await _db.into(_db.localConversations).insertOnConflictUpdate(companion);
  }

  LocalCallsCompanion _callToCompanion(Call c, User? other) {
    return LocalCallsCompanion(
      idCall: Value(c.idCall),
      idCaller: Value(c.idCaller),
      idReceiver: Value(c.idReceiver),
      type: Value(c.type),
      status: Value(c.status),
      duration: Value(c.duree),
      createdAt: Value(_parseDate(c.createdAt) ?? DateTime.now()),
      otherNom: Value(other?.nom),
      otherAvatar: Value(other?.avatarUrl),
    );
  }

  LocalMeetingsCompanion _meetingToCompanion(Meeting m, Map<String, dynamic> raw) {
    int statut = 0;
    if (m.isEnd) {
      statut = 2;
    } else if (DateTime.now().isAfter(m.endDateTime)) {
      statut = 2;
    } else if (DateTime.now().isAfter(m.startDateTime)) {
      statut = 1;
    }
    return LocalMeetingsCompanion(
      idMeeting: Value(m.idMeeting),
      objet: Value(m.objet),
      room: Value(m.room),
      startTime: Value(m.startDateTime),
      duree: Value(m.duree),
      typeMedia: Value(m.typeMedia),
      organiserID: Value(m.idOrganiser),
      organiserNom: Value(m.organiserNom),
      participantsJson: Value(jsonEncode(raw['participants'] ?? [])),
      statut: Value(statut),
      cachedAt: Value(DateTime.now()),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
