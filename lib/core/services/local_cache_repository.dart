import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../theme/contact_list_colors.dart';
import '../utils/media_album.dart';
import '../utils/user_search.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'media_cache_service.dart';
import '../theme/locale_controller.dart';

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
          // `GET /contacts` ne porte ni email ni pays : écriture partielle
          // pour ne pas effacer une fiche déjà complète.
          final companion = _partialUserToCompanion(
            u,
            preferred: true,
            cachedAt: now,
            presenceKnown: true,
          );
          b.insert(
            _db.localUsers,
            companion,
            onConflict: DoUpdate((_) => companion),
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

  /// Retire un contact des favoris côté serveur **et** partout dans le cache.
  ///
  /// Point d'entrée unique pour tous les écrans : être un contact préféré est
  /// le prérequis pour appartenir à une liste, donc un retrait des favoris doit
  /// aussi sortir le contact de toutes les listes (le serveur fait la même
  /// chose de son côté). Passer par `_api.removeContact` seul laisserait des
  /// membres fantômes dans les listes en cache.
  Future<void> removePreferredContact(int alanyaID, {User? user}) async {
    await _api.removeContact(alanyaID);
    await forgetPreferredContact(alanyaID, user: user);
  }

  /// Volet local de [removePreferredContact] — sans appel réseau.
  Future<void> forgetPreferredContact(int alanyaID, {User? user}) async {
    if (user != null) {
      await upsertKnownUser(user, preferred: false, partial: true);
    } else {
      await (_db.update(_db.localUsers)
            ..where((u) => u.alanyaID.equals(alanyaID)))
          .write(const LocalUsersCompanion(isPreferredContact: Value(false)));
    }
    await (_db.delete(_db.localContactListMembers)
          ..where((m) => m.idFriend.equals(alanyaID)))
        .go();
    // Les `memberCount` des listes touchées viennent du serveur.
    await syncContactLists();
  }

  /// Stocke un user vu de passage (résolu via getUserById) — utile pour
  /// peupler le roster d'appel groupe ou l'affichage de messages.
  ///
  /// [partial] pour les sources qui ne portent pas tout l'utilisateur
  /// (résultat de recherche, carte de visite) : les colonnes absentes sont
  /// alors laissées telles quelles au lieu d'être vidées.
  Future<void> upsertKnownUser(
    User u, {
    bool preferred = false,
    bool partial = false,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.localUsers).insertOnConflictUpdate(
          partial
              ? _partialUserToCompanion(u, preferred: preferred, cachedAt: now)
              : _userToCompanion(u, preferred: preferred, cachedAt: now),
        );
  }

  /// Récupère un user du cache local (null si jamais vu).
  Future<LocalUser?> getKnownUser(int alanyaID) {
    return (_db.select(_db.localUsers)..where((u) => u.alanyaID.equals(alanyaID)))
        .getSingleOrNull();
  }

  /// Socle compte + statut préféré depuis le cache (Drift schema ≥ 20).
  Future<({
    bool isPreferredContact,
    int typeCompte,
    int accountType,
    int verificationStatus,
  })?> getKnownUserSocle(int alanyaID) async {
    final local = await getKnownUser(alanyaID);
    if (local == null) return null;
    return (
      isPreferredContact: local.isPreferredContact,
      typeCompte: local.typeCompte,
      accountType: local.accountType,
      verificationStatus: local.verificationStatus,
    );
  }

  /// Profil contact depuis le cache local (null si jamais vu).
  Future<User?> getKnownUserProfile(int alanyaID) async {
    final u = await getKnownUser(alanyaID);
    if (u == null) return null;
    return User(
      alanyaID: u.alanyaID,
      nom: u.nom,
      pseudo: u.pseudo,
      alanyaPhone: u.alanyaPhone,
      email: u.email,
      idPays: u.idPays,
      avatarUrl: u.avatarUrl,
      typeCompte: u.typeCompte,
      accountType: u.accountType,
      verificationStatus: u.verificationStatus,
      verifiedUntil: u.verifiedUntil?.toIso8601String(),
      isOnline: u.isOnline,
      lastSeen: u.lastSeen?.toIso8601String() ?? '',
      paysLibelle: u.paysLibelle,
      addedViaQr: u.addedViaQr,
      preferredAddedAt: u.preferredAddedAt,
      preferredNote: u.preferredNote,
    );
  }

  /// Champs relation contact préféré depuis le cache.
  Future<({
    bool isPreferredContact,
    bool addedViaQr,
    DateTime? preferredAddedAt,
    String? preferredNote,
  })?> getKnownUserRelation(int alanyaID) async {
    final u = await getKnownUser(alanyaID);
    if (u == null) return null;
    return (
      isPreferredContact: u.isPreferredContact,
      addedViaQr: u.addedViaQr,
      preferredAddedAt: u.preferredAddedAt,
      preferredNote: u.preferredNote,
    );
  }

  // ── LISTES DE CONTACTS ──────────────────────────────────────────────

  /// Listes de contacts en cache (offline-first, comme les contacts préférés).
  Stream<List<LocalContactList>> watchContactLists() {
    return (_db.select(_db.localContactLists)
          ..orderBy([(l) => OrderingTerm(expression: l.name)]))
        .watch();
  }

  Future<List<LocalContactList>> getContactListsOnce() {
    return (_db.select(_db.localContactLists)
          ..orderBy([(l) => OrderingTerm(expression: l.name)]))
        .get();
  }

  /// Rafraîchit les listes depuis l'API. Best-effort : en cas d'erreur réseau,
  /// le cache reste utilisable.
  Future<void> syncContactLists() async {
    try {
      final raw = await _api.getContactLists();
      final now = DateTime.now();
      final previousIds =
          (await getContactListsOnce()).map((l) => l.idList).toSet();
      final newIds = <int>{};
      await _db.batch((b) {
        for (final r in raw.whereType<Map<String, dynamic>>()) {
          final l = ContactList.fromJson(r);
          if (l.idList == 0) continue;
          newIds.add(l.idList);
          final companion = LocalContactListsCompanion(
            idList: Value(l.idList),
            name: Value(l.name),
            color: Value(l.color),
            memberCount: Value(l.memberCount),
            cachedAt: Value(now),
          );
          b.insert(
            _db.localContactLists,
            companion,
            onConflict: DoUpdate((_) => companion),
          );
        }
      });
      // Listes supprimées ailleurs : on les retire vraiment (contrairement aux
      // contacts préférés, une liste orpheline n'a aucune utilité en cache).
      final removed = previousIds.difference(newIds);
      if (removed.isNotEmpty) {
        await _forgetLists(removed);
      }
      await _backfillListColors();
    } catch (e) {
      debugPrint('[LocalCacheRepo] syncContactLists échouée: $e');
    }
  }

  /// Écrit en base la couleur des listes qui n'en ont pas.
  ///
  /// Depuis que la couleur est attribuée d'office à la création, seules les
  /// listes créées **avant** peuvent être sans teinte. L'UI en affiche déjà une
  /// (via `resolveListColors`) ; ce rattrapage persiste exactement la même,
  /// pour que tous les appareils du compte s'accordent. Idempotent : au tour
  /// suivant il n'y a plus rien à faire.
  Future<void> _backfillListColors() async {
    final lists = await getContactListsOnce();
    final aRepeindre =
        lists.where((l) => parseListColor(l.color) == null).toList();
    if (aRepeindre.isEmpty) return;

    final resolved = resolveListColors(lists);
    for (final list in aRepeindre) {
      final hex = resolved[list.idList];
      if (hex == null) continue;
      try {
        await _api.updateContactList(list.idList, color: hex);
        await (_db.update(_db.localContactLists)
              ..where((l) => l.idList.equals(list.idList)))
            .write(LocalContactListsCompanion(color: Value(hex)));
      } catch (e) {
        // Best-effort : sans réseau la liste garde sa couleur d'affichage,
        // le rattrapage se refera à la prochaine synchro.
        debugPrint('[LocalCacheRepo] couleur de liste non persistée: $e');
      }
    }
  }

  /// Membres d'une liste, hydratés depuis [LocalUsers] — l'appartenance ne
  /// duplique aucun profil.
  Stream<List<User>> watchListMembers(int idList) {
    final query = _db.select(_db.localContactListMembers).join([
      innerJoin(
        _db.localUsers,
        _db.localUsers.alanyaID.equalsExp(_db.localContactListMembers.idFriend),
      ),
    ])
      ..where(_db.localContactListMembers.idList.equals(idList))
      ..orderBy([OrderingTerm(expression: _db.localUsers.nom)]);
    return query.watch().map(
          (rows) => rows
              .map((r) => localUserToUser(r.readTable(_db.localUsers)))
              .toList(),
        );
  }

  /// Ids des membres d'une liste — assez pour filtrer une liste déjà streamée
  /// sans re-jointure sur les profils.
  Stream<Set<int>> watchListMemberIds(int idList) {
    return (_db.select(_db.localContactListMembers)
          ..where((m) => m.idList.equals(idList)))
        .watch()
        .map((rows) => rows.map((m) => m.idFriend).toSet());
  }

  /// Appartenances vues depuis le contact : `alanyaID → listes`.
  ///
  /// L'écran des contacts préférés affiche sous chaque contact les puces de
  /// ses listes ; un stream par contact serait une requête par ligne de liste.
  /// Une seule jointure suffit, l'index se fait en mémoire.
  Stream<Map<int, List<LocalContactList>>> watchListsByMember() {
    final query = _db.select(_db.localContactListMembers).join([
      innerJoin(
        _db.localContactLists,
        _db.localContactLists.idList
            .equalsExp(_db.localContactListMembers.idList),
      ),
    ])
      ..orderBy([OrderingTerm(expression: _db.localContactLists.name)]);
    return query.watch().map((rows) {
      final byMember = <int, List<LocalContactList>>{};
      for (final row in rows) {
        final member = row.readTable(_db.localContactListMembers);
        byMember
            .putIfAbsent(member.idFriend, () => [])
            .add(row.readTable(_db.localContactLists));
      }
      return byMember;
    });
  }

  Future<void> syncListMembers(int idList) async {
    try {
      final raw = await _api.getListMembers(idList);
      final now = DateTime.now();
      final ids = <int>{};
      await _db.batch((b) {
        for (final r in raw.whereType<Map<String, dynamic>>()) {
          final u = User.fromJson(r);
          if (u.alanyaID == 0) continue;
          ids.add(u.alanyaID);
          // Même projection partielle que les contacts préférés : ne pas
          // écraser une fiche déjà complète avec un profil tronqué.
          final companion = _partialUserToCompanion(
            u,
            cachedAt: now,
            presenceKnown: true,
          );
          b.insert(
            _db.localUsers,
            companion,
            onConflict: DoUpdate((_) => companion),
          );
          b.insert(
            _db.localContactListMembers,
            LocalContactListMembersCompanion(
              idList: Value(idList),
              idFriend: Value(u.alanyaID),
            ),
            onConflict: DoNothing(),
          );
        }
      });
      // Retraits faits ailleurs.
      await (_db.delete(_db.localContactListMembers)
            ..where((m) =>
                m.idList.equals(idList) &
                (ids.isEmpty ? const Constant(true) : m.idFriend.isNotIn(ids))))
          .go();
    } catch (e) {
      debugPrint('[LocalCacheRepo] syncListMembers($idList) échouée: $e');
    }
  }

  /// Crée une liste côté serveur puis resynchronise le cache. Comme
  /// `addContact`, la mutation reste online : pas d'outbox pour les listes.
  ///
  /// [memberIds] permet de peupler la liste dans la foulée : une liste vide
  /// n'a aucun intérêt, on ne force donc pas un second aller-retour par l'UI.
  Future<ContactList> createContactList(
    String name, {
    String? color,
    Iterable<int> memberIds = const [],
  }) async {
    // Une liste naît toujours colorée : si l'appelant n'impose rien, elle prend
    // la première teinte libre de la palette.
    final teinte = parseListColor(color) != null
        ? color
        : nextFreeContactListColor({
            for (final l in await getContactListsOnce())
              if (parseListColor(l.color) != null) l.color!.toUpperCase(),
          });
    final raw = await _api.createContactList(name, color: teinte);
    final created = ContactList.fromJson(raw);
    if (created.idList != 0 && memberIds.isNotEmpty) {
      for (final id in memberIds) {
        await _api.addListMember(created.idList, id);
      }
      await syncListMembers(created.idList);
    }
    await syncContactLists();
    return created;
  }

  Future<void> updateContactList(int idList,
      {String? name, String? color}) async {
    await _api.updateContactList(idList, name: name, color: color);
    await syncContactLists();
  }

  Future<void> deleteContactList(int idList) async {
    await _api.deleteContactList(idList);
    await _forgetLists({idList});
  }

  Future<void> addListMember(int idList, int friendID) =>
      addListMembers(idList, [friendID]);

  /// Ajout groupé : une seule resynchro pour toute la sélection (la feuille
  /// d'ajout en envoie souvent plusieurs d'un coup).
  Future<void> addListMembers(int idList, Iterable<int> friendIDs) async {
    if (friendIDs.isEmpty) return;
    for (final id in friendIDs) {
      await _api.addListMember(idList, id);
    }
    await syncListMembers(idList);
    await syncContactLists();
  }

  Future<void> removeListMember(int idList, int friendID) async {
    await _api.removeListMember(idList, friendID);
    await syncListMembers(idList);
    await syncContactLists();
  }

  /// Oublie localement des listes (et leurs appartenances) — les profils des
  /// membres restent en cache, ils sont partagés avec le reste de l'app.
  Future<void> _forgetLists(Set<int> idLists) async {
    if (idLists.isEmpty) return;
    await (_db.delete(_db.localContactListMembers)
          ..where((m) => m.idList.isIn(idLists)))
        .go();
    await (_db.delete(_db.localContactLists)
          ..where((l) => l.idList.isIn(idLists)))
        .go();
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

  /// Écrit en cache une réponse GET /calls déjà téléchargée — permet à un
  /// écran qui vient de faire l'appel réseau d'alimenter le cache sans le
  /// refaire (syncCalls refaisait un GET identique juste derrière).
  Future<void> ingestCallsRaw(List<dynamic> raw, {required int myId}) async {
    try {
      final now = DateTime.now();
      await _db.batch((b) {
        for (final r in raw.whereType<Map<String, dynamic>>()) {
          final c = Call.fromJson(r);
          _insertCallIntoBatch(b, c, myId: myId, now: now);
        }
      });
    } catch (e) {
      debugPrint('[LocalCacheRepo] ingestCallsRaw échouée: $e');
    }
  }

  Future<void> syncCalls({required int myId}) async {
    try {
      final raw = await _api.getCallHistory();
      await ingestCallsRaw(raw, myId: myId);
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

  /// Écrit en cache une réponse GET /meetings déjà téléchargée (même logique
  /// que [ingestCallsRaw]).
  Future<void> ingestMeetingsRaw(List<dynamic> raw) async {
    try {
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
      debugPrint('[LocalCacheRepo] ingestMeetingsRaw échouée: $e');
    }
  }

  Future<void> syncMeetings() async {
    try {
      final raw = await _api.getMeetings();
      await ingestMeetingsRaw(raw);
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

  /// Vide les caches secondaires (contacts, listes, appels, meetings, statuts).
  Future<void> clearSession() async {
    await _db.delete(_db.localStatuses).go();
    await _db.delete(_db.localMeetings).go();
    await _db.delete(_db.localCalls).go();
    await _db.delete(_db.localContactListMembers).go();
    await _db.delete(_db.localContactLists).go();
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
      accountType: Value(u.accountType),
      verificationStatus: Value(u.verificationStatus),
      verifiedUntil: u.verifiedUntil != null
          ? Value(DateTime.tryParse(u.verifiedUntil!))
          : const Value.absent(),
      isPreferredContact:
          preferred != null ? Value(preferred) : const Value.absent(),
      // Relation « ajouté par QR » : null = la source ne portait pas
      // l'information, on n'écrase pas ce que le cache sait déjà.
      addedViaQr: u.addedViaQr != null
          ? Value(u.addedViaQr!)
          : const Value.absent(),
      preferredAddedAt: u.preferredAddedAt != null
          ? Value(u.preferredAddedAt)
          : const Value.absent(),
      // Chaîne vide = « pas de note », connue — on efface. Null = source
      // muette, on ne touche pas.
      preferredNote: u.preferredNote != null
          ? Value(u.preferredNote!.isEmpty ? null : u.preferredNote)
          : const Value.absent(),
      cachedAt: Value(cachedAt),
    );
  }

  /// Companion « partiel » : n'écrit que les colonnes réellement portées par
  /// la source.
  ///
  /// L'historique d'appels, la liste des contacts préférés ou une carte de
  /// visite ne transportent pas tout un utilisateur (pas de pays, parfois
  /// pas de téléphone). Les écrire via [_userToCompanion] remplaçait la
  /// ligne entière et effaçait ce qu'un `GET /users/:id` avait déjà appris —
  /// la fiche contact repartait alors sur un aller-retour réseau pour
  /// réafficher le numéro et le pays.
  ///
  /// [presenceKnown] distingue les sources qui portent `is_online` /
  /// `last_seen` (contacts préférés) de celles qui les inventent à faux
  /// (snapshots d'appel, cartes de visite).
  LocalUsersCompanion _partialUserToCompanion(
    User u, {
    bool? preferred,
    required DateTime cachedAt,
    bool presenceKnown = false,
  }) {
    // Le pays n'est jamais partiel : `idPays` seul vaut 10 par défaut dans
    // User.fromJson, donc on ne l'écrit qu'accompagné de son libellé.
    final hasCountry = (u.paysLibelle ?? '').isNotEmpty;
    return LocalUsersCompanion(
      alanyaID: Value(u.alanyaID),
      nom: u.nom.isNotEmpty ? Value(u.nom) : const Value.absent(),
      pseudo: u.pseudo.isNotEmpty ? Value(u.pseudo) : const Value.absent(),
      alanyaPhone: u.alanyaPhone.isNotEmpty
          ? Value(u.alanyaPhone)
          : const Value.absent(),
      email: u.email.isNotEmpty ? Value(u.email) : const Value.absent(),
      avatarUrl:
          u.avatarUrl.isNotEmpty ? Value(u.avatarUrl) : const Value.absent(),
      idPays: hasCountry ? Value(u.idPays) : const Value.absent(),
      paysLibelle: hasCountry ? Value(u.paysLibelle) : const Value.absent(),
      isOnline: presenceKnown ? Value(u.isOnline) : const Value.absent(),
      lastSeen: presenceKnown
          ? Value(DateTime.tryParse(u.lastSeen))
          : const Value.absent(),
      typeCompte:
          u.typeCompte > 0 ? Value(u.typeCompte) : const Value.absent(),
      accountType:
          u.accountType != 0 ? Value(u.accountType) : const Value.absent(),
      verificationStatus: u.verificationStatus != 0
          ? Value(u.verificationStatus)
          : const Value.absent(),
      verifiedUntil: u.verifiedUntil != null
          ? Value(DateTime.tryParse(u.verifiedUntil!))
          : const Value.absent(),
      isPreferredContact:
          preferred != null ? Value(preferred) : const Value.absent(),
      addedViaQr: u.addedViaQr != null
          ? Value(u.addedViaQr!)
          : const Value.absent(),
      preferredAddedAt: u.preferredAddedAt != null
          ? Value(u.preferredAddedAt)
          : const Value.absent(),
      // Chaîne vide = « pas de note », connue — on efface. Null = source
      // muette, on ne touche pas.
      preferredNote: u.preferredNote != null
          ? Value(u.preferredNote!.isEmpty ? null : u.preferredNote)
          : const Value.absent(),
      cachedAt: Value(cachedAt),
    );
  }

  /// Pose (ou efface, si vide) la note contextuelle d'un contact — miroir
  /// local de PUT /contacts/:id/note.
  Future<void> setPreferredNote(int alanyaID, String? note) async {
    final clean = (note ?? '').trim();
    await (_db.update(_db.localUsers)
          ..where((u) => u.alanyaID.equals(alanyaID)))
        .write(LocalUsersCompanion(
      preferredNote: Value(clean.isEmpty ? null : clean),
    ));
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
      // L'historique d'appels ne renvoie que nom / pseudo / avatar : sans
      // écriture partielle, chaque synchro d'appels effaçait le numéro et le
      // pays du contact (et le marquait hors ligne à tort).
      final companion = _partialUserToCompanion(other, cachedAt: now);
      b.insert(
        _db.localUsers,
        companion,
        onConflict: DoUpdate((_) => companion),
      );
    }
  }

  Future<void> _bumpConversationForCall({
    required int conversID,
    required Call call,
  }) async {
    final preview = call.isVideo ? LocaleController.instance.l10n.videoCallPreview : LocaleController.instance.l10n.voiceCallPreview;
    // 10/11 : aperçus d'appel locaux (évite collision avec message.type 5=location).
    final type = call.isVideo ? 11 : 10;
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
