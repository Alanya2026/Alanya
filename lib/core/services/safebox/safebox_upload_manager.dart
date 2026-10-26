//  Envois vers le coffre-fort, avec reprise.
//
//  Conception : backend/docs/conception/coffre-fort.html, section 03. Un
//  fichier part en blocs indépendants de 8 Mio, un objet MEGA chacun : le lot 0
//  (15/10/2026) a montré que l'envoi en morceaux de S3 abandonne parfois TOUT
//  après une coupure, alors qu'un bloc coupé se renvoie simplement.
//
//  Chaque bloc est lu dans le fichier d'origine, chiffré dans un isolat, puis
//  envoyé : aucune copie chiffrée entière n'occupe le téléphone, et une
//  coupure ne coûte que le bloc en cours. Les envois sont gardés sur le
//  téléphone (préférences pour l'état, stockage sécurisé pour la clé) et
//  reprennent au redémarrage de l'application.
//
//  Un bloc rechiffré doit être identique au premier (même clé, même nonce) :
//  si le fichier d'origine a changé depuis le début de l'envoi, on s'arrête
//  plutôt que de chiffrer deux contenus différents sous le même nonce.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../talky_api_client.dart';
import '../connectivity_service.dart';
import '../secure_storage_guard.dart';
import 'safebox_cipher.dart';
import 'safebox_models.dart';

// ── Ce que le gestionnaire attend du réseau ────────────────────────────────

/// Les appels dont l'envoi a besoin. L'application passe [ApiSafeboxTransport] ;
/// les tests, un faux.
abstract class SafeboxTransport {
  Future<SafeboxUploadTicket> reserve({
    required int folderId,
    required String name,
    required String? mime,
    required int size,
    required int plainSize,
    required String cipherFormat,
    int? originalSize,
    bool compressed,
    String? quality,
    int previewSize,
    Map<String, dynamic>? meta,
    String? sourceFp,
  });

  Future<SafeboxUploadStatus> status(int fileId);

  Future<({List<SafeboxSignedBlock> blocks, SafeboxSignedBlock? preview})> urls(
    int fileId, {
    List<int> blocks,
    bool preview,
  });

  Future<SafeboxFile> complete(int fileId, Uint8List key);

  Future<void> cancel(int fileId);

  Future<void> putBlock(String url, Uint8List bytes, {void Function(int sent)? onProgress});
}

class ApiSafeboxTransport implements SafeboxTransport {
  ApiSafeboxTransport(this.api);

  final TalkyApiClient api;

  @override
  Future<SafeboxUploadTicket> reserve({
    required int folderId,
    required String name,
    required String? mime,
    required int size,
    required int plainSize,
    required String cipherFormat,
    int? originalSize,
    bool compressed = false,
    String? quality,
    int previewSize = 0,
    Map<String, dynamic>? meta,
    String? sourceFp,
  }) =>
      api.reserveSafeboxUpload(
        folderId: folderId,
        name: name,
        mime: mime,
        size: size,
        plainSize: plainSize,
        cipherFormat: cipherFormat,
        originalSize: originalSize,
        compressed: compressed,
        quality: quality,
        sourceFp: sourceFp,
        previewSize: previewSize,
        meta: meta,
      );

  @override
  Future<SafeboxUploadStatus> status(int fileId) => api.fetchSafeboxUploadStatus(fileId);

  @override
  Future<({List<SafeboxSignedBlock> blocks, SafeboxSignedBlock? preview})> urls(
    int fileId, {
    List<int> blocks = const [],
    bool preview = false,
  }) =>
      api.fetchSafeboxUploadUrls(fileId, blocks: blocks, preview: preview);

  @override
  Future<SafeboxFile> complete(int fileId, Uint8List key) => api.completeSafeboxUpload(fileId, key);

  @override
  Future<void> cancel(int fileId) => api.cancelSafeboxUpload(fileId);

  @override
  Future<void> putBlock(String url, Uint8List bytes, {void Function(int sent)? onProgress}) =>
      api.putSafeboxBlock(url, bytes, onProgress: onProgress);
}

// ── Un envoi ───────────────────────────────────────────────────────────────

/// `paused` : mis en pause par l'inscrit ; il le reste après un redémarrage,
/// jusqu'à ce qu'il le relance. `waitingWifi` : « Seulement en Wi-Fi » (lot
/// 10), sur des données mobiles ; repart au retour du Wi-Fi, ou quand
/// l'inscrit accepte les données mobiles.
enum SafeboxUploadState { queued, running, waitingNetwork, waitingWifi, paused, failed, completed }

class SafeboxUploadJob {
  SafeboxUploadJob({
    required this.id,
    required this.folderId,
    required this.name,
    required this.mime,
    required this.sourcePath,
    required this.sourceSize,
    required this.sourceModifiedMs,
    required this.ownsSource,
    required this.plainSize,
    required this.originalSize,
    required this.compressed,
    this.quality,
    this.previewPath,
    this.previewSize = 0,
    this.fileId,
    this.blockSize = 0,
    this.blockCount = 0,
    Set<int>? done,
    this.previewDone = false,
    this.state = SafeboxUploadState.queued,
    this.errorCode,
    this.shareConversationId,
    this.shareGroup,
    this.meta,
    this.sourceFp,
    this.wifiOnly = false,
    this.backupKey,
    DateTime? createdAt,
  })  : done = done ?? <int>{},
        createdAt = createdAt ?? DateTime.now();

  factory SafeboxUploadJob.fromJson(Map<String, dynamic> j) => SafeboxUploadJob(
        id: '${j['id']}',
        folderId: j['folderId'] as int,
        name: '${j['name']}',
        mime: j['mime'] as String?,
        sourcePath: '${j['sourcePath']}',
        sourceSize: j['sourceSize'] as int,
        sourceModifiedMs: j['sourceModifiedMs'] as int,
        ownsSource: j['ownsSource'] == true,
        plainSize: j['plainSize'] as int,
        originalSize: j['originalSize'] as int?,
        compressed: j['compressed'] == true,
        quality: j['quality'] as String?,
        previewPath: j['previewPath'] as String?,
        previewSize: (j['previewSize'] as int?) ?? 0,
        fileId: j['fileId'] as int?,
        blockSize: (j['blockSize'] as int?) ?? 0,
        blockCount: (j['blockCount'] as int?) ?? 0,
        done: ((j['done'] as List?) ?? const []).cast<int>().toSet(),
        previewDone: j['previewDone'] == true,
        state: SafeboxUploadState.values.firstWhere(
          (s) => s.name == j['state'],
          orElse: () => SafeboxUploadState.queued,
        ),
        errorCode: j['errorCode'] as String?,
        shareConversationId: j['shareConversationId'] as int?,
        shareGroup: j['shareGroup'] as String?,
        sourceFp: j['sourceFp'] as String?,
        wifiOnly: j['wifiOnly'] == true,
        backupKey: j['backupKey'] as String?,
        meta: j['meta'] is Map ? Map<String, dynamic>.from(j['meta'] as Map) : null,
        createdAt: DateTime.tryParse('${j['createdAt']}'),
      );

  final String id;
  final int folderId;
  final String name;
  final String? mime;

  /// Fichier lu bloc par bloc : l'original, ou la copie compressée.
  final String sourcePath;
  final int sourceSize;
  final int sourceModifiedMs;

  /// La source est une copie faite pour l'envoi (compression) : supprimée à la fin.
  final bool ownsSource;
  final int plainSize;
  final int? originalSize;
  final bool compressed;

  /// Format choisi (« original », « hd », « compressed ») ; null pour un
  /// envoi préparé avant le 24/10/2026.
  final String? quality;

  /// Aperçu déjà chiffré, prêt à partir.
  final String? previewPath;
  final int previewSize;

  int? fileId;
  int blockSize;
  int blockCount;
  final Set<int> done;
  bool previewDone;
  SafeboxUploadState state;
  String? errorCode;

  /// Discussion où partager le fichier dès qu'il est dans le coffre (envoi
  /// d'un gros fichier depuis une discussion), ou null.
  final int? shareConversationId;

  /// Plusieurs fichiers du téléphone envoyés ensemble dans une discussion :
  /// ils partent en un seul message (un lot) quand le dernier est dans le
  /// coffre (lot 9). Null pour un fichier seul.
  final String? shareGroup;

  /// Durée, définition, pages… relevés avant l'envoi ([SafeboxMeta.toJson]).
  final Map<String, dynamic>? meta;

  /// Empreinte de l'original (lot 10) : le coffre ne le reprendra pas deux fois.
  final String? sourceFp;

  /// « Seulement en Wi-Fi » ; levé quand l'inscrit accepte les données mobiles.
  bool wifiOnly;

  /// Le fichier du téléphone que la sauvegarde automatique envoie, ou null.
  final String? backupKey;
  final DateTime createdAt;

  /// Octets envoyés pendant le bloc en cours (non gardé).
  int inFlightBytes = 0;

  int get storedSize => safeboxEncryptedLength(plainSize);

  int get sentBytes {
    if (blockSize <= 0) return 0;
    var total = inFlightBytes;
    for (final n in done) {
      total += safeboxPlanBlock(n, plainSize: plainSize, blockSize: blockSize).cipherLength;
    }
    return total;
  }

  double get progress => storedSize <= 0 ? 0 : (sentBytes / storedSize).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'folderId': folderId,
        'name': name,
        'mime': mime,
        'sourcePath': sourcePath,
        'sourceSize': sourceSize,
        'sourceModifiedMs': sourceModifiedMs,
        'ownsSource': ownsSource,
        'plainSize': plainSize,
        'originalSize': originalSize,
        'compressed': compressed,
        if (quality != null) 'quality': quality,
        'previewPath': previewPath,
        'previewSize': previewSize,
        'fileId': fileId,
        'blockSize': blockSize,
        'blockCount': blockCount,
        'done': done.toList()..sort(),
        'previewDone': previewDone,
        'state': state.name,
        'errorCode': errorCode,
        'shareConversationId': shareConversationId,
        if (shareGroup != null) 'shareGroup': shareGroup,
        if (meta != null) 'meta': meta,
        if (sourceFp != null) 'sourceFp': sourceFp,
        if (wifiOnly) 'wifiOnly': true,
        if (backupKey != null) 'backupKey': backupKey,
        'createdAt': createdAt.toIso8601String(),
      };
}

// ── Où les envois sont gardés ──────────────────────────────────────────────

abstract class SafeboxJobStore {
  Future<List<SafeboxUploadJob>> loadJobs();
  Future<void> saveJobs(List<SafeboxUploadJob> jobs);
  Future<Uint8List?> loadKey(String jobId);
  Future<void> saveKey(String jobId, Uint8List key);
  Future<void> deleteKey(String jobId);
}

/// État dans les préférences, clé dans le stockage sécurisé : la clé d'un
/// fichier n'est jamais écrite en clair sur le téléphone.
class PrefsSafeboxJobStore implements SafeboxJobStore {
  static const _cle = 'safebox_upload_jobs_v1';
  static const _prefixeCle = 'safebox_upload_key_';
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: kSecureStorageAndroidOptions,
    iOptions: kSecureStorageIosOptions,
  );

  @override
  Future<List<SafeboxUploadJob>> loadJobs() async {
    final prefs = await SharedPreferences.getInstance();
    // La tâche de fond de la sauvegarde automatique a pu écrire (lot 10).
    await prefs.reload();
    final brut = prefs.getString(_cle);
    if (brut == null) return [];
    try {
      return (jsonDecode(brut) as List)
          .whereType<Map>()
          .map((e) => SafeboxUploadJob.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('[Coffre] envois illisibles, ignorés : $e');
      return [];
    }
  }

  @override
  Future<void> saveJobs(List<SafeboxUploadJob> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(jobs.map((j) => j.toJson()).toList()));
  }

  @override
  Future<Uint8List?> loadKey(String jobId) async {
    final v = await _secure.read(key: '$_prefixeCle$jobId');
    return v == null ? null : base64Decode(v);
  }

  @override
  Future<void> saveKey(String jobId, Uint8List key) =>
      _secure.write(key: '$_prefixeCle$jobId', value: base64Encode(key));

  @override
  Future<void> deleteKey(String jobId) => _secure.delete(key: '$_prefixeCle$jobId');
}

// ── Le gestionnaire ────────────────────────────────────────────────────────

/// Un envoi refusé pour de bon : on ne réessaie pas tout seul.
class SafeboxUploadFailure implements Exception {
  SafeboxUploadFailure(this.code);
  final String code;
  @override
  String toString() => 'SafeboxUploadFailure($code)';
}

class SafeboxUploadManager extends ChangeNotifier {
  SafeboxUploadManager({
    required SafeboxTransport transport,
    SafeboxJobStore? store,
    Future<void> Function(Duration)? sleep,
    Future<Uint8List> Function(List<int> key, Uint8List plain, SafeboxBlockPlan plan)? encrypt,
    Future<bool> Function()? unmetered,
    this.networkRetries = const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 30)],
  })  : _transport = transport,
        _store = store ?? PrefsSafeboxJobStore(),
        _sleep = sleep ?? Future<void>.delayed,
        _encrypt = encrypt ?? safeboxEncryptBlock,
        _surWifi = unmetered ?? (() => ConnectivityService().currentIsUnmetered);

  final SafeboxTransport _transport;
  final SafeboxJobStore _store;

  /// La connexion actuelle ne se paie pas au volume (Wi-Fi, Ethernet).
  final Future<bool> Function() _surWifi;
  final Future<void> Function(Duration) _sleep;
  final Future<Uint8List> Function(List<int>, Uint8List, SafeboxBlockPlan) _encrypt;

  /// Attentes entre deux essais après une erreur réseau. Au-delà, l'envoi
  /// attend le réseau ([SafeboxUploadState.waitingNetwork]) et reprendra au
  /// prochain [resumeAll].
  final List<Duration> networkRetries;

  final List<SafeboxUploadJob> _jobs = [];
  final StreamController<SafeboxFile> _termines = StreamController<SafeboxFile>.broadcast();
  final StreamController<({SafeboxUploadJob job, SafeboxFile file})> _terminesAvecEnvoi =
      StreamController<({SafeboxUploadJob job, SafeboxFile file})>.broadcast();
  bool _charge = false;
  bool _enCours = false;
  final Set<String> _annules = {};

  /// Envois en cours dont la pause est demandée : elle prend effet entre deux
  /// blocs, sans rien perdre de ce qui est déjà chez MEGA.
  final Set<String> _pauses = {};

  /// Les envois connus, du plus ancien au plus récent.
  List<SafeboxUploadJob> get jobs => List.unmodifiable(_jobs);

  /// Un fichier vient d'apparaître dans le coffre : l'écran du dossier se rafraîchit.
  Stream<SafeboxFile> get completed => _termines.stream;

  /// Même événement, avec l'envoi qui l'a produit (sa discussion de partage).
  Stream<({SafeboxUploadJob job, SafeboxFile file})> get completedJobs => _terminesAvecEnvoi.stream;

  bool get busy => _jobs.any((j) => j.state == SafeboxUploadState.running || j.state == SafeboxUploadState.queued);

  Future<void> _chargerUneFois() async {
    if (_charge) return;
    _charge = true;
    final gardes = await _store.loadJobs();
    for (final j in gardes) {
      if (j.state == SafeboxUploadState.running) j.state = SafeboxUploadState.queued;
      if (!_jobs.any((x) => x.id == j.id)) _jobs.add(j);
    }
  }

  Future<void> _sauver() => _store.saveJobs(_jobs.where((j) => j.state != SafeboxUploadState.completed).toList());

  /// Ajoute un envoi et le lance. [key] chiffre le fichier et son aperçu.
  Future<void> enqueue(SafeboxUploadJob job, Uint8List key) async {
    await _chargerUneFois();
    await _store.saveKey(job.id, key);
    _jobs.add(job);
    await _sauver();
    notifyListeners();
    unawaited(_pomper());
  }

  /// Relance ce qui attendait (démarrage de l'application, retour du réseau,
  /// ouverture du coffre).
  Future<void> resumeAll() async {
    await _chargerUneFois();
    for (final j in _jobs) {
      if (j.state == SafeboxUploadState.waitingNetwork) j.state = SafeboxUploadState.queued;
    }
    notifyListeners();
    await _pomper();
  }

  /// Met un envoi en pause. En cours, il s'arrête à la fin du bloc qui part ;
  /// en attente, tout de suite.
  Future<void> pause(String jobId) async {
    final j = _jobs.where((x) => x.id == jobId).firstOrNull;
    if (j == null) return;
    switch (j.state) {
      case SafeboxUploadState.running:
        _pauses.add(jobId);
      case SafeboxUploadState.queued || SafeboxUploadState.waitingNetwork:
        j.state = SafeboxUploadState.paused;
        await _sauver();
        notifyListeners();
      default:
        break;
    }
  }

  /// Relance un envoi mis en pause.
  Future<void> resume(String jobId) async {
    _pauses.remove(jobId);
    final j = _jobs.where((x) => x.id == jobId).firstOrNull;
    if (j == null || j.state != SafeboxUploadState.paused) return;
    j.state = SafeboxUploadState.queued;
    await _sauver();
    notifyListeners();
    unawaited(_pomper());
  }

  /// « Tout mettre en pause ».
  Future<void> pauseAll() async {
    for (final j in List.of(_jobs)) {
      await pause(j.id);
    }
  }

  /// « Tout reprendre » : les envois en pause repartent, dans l'ordre.
  Future<void> resumePaused() async {
    for (final j in _jobs.where((x) => x.state == SafeboxUploadState.paused).toList()) {
      await resume(j.id);
    }
  }

  /// Relit les envois gardés : ceux ajoutés par la tâche de fond de la
  /// sauvegarde automatique pendant que l'application était fermée.
  Future<void> reload() async {
    if (!_charge) return _chargerUneFois();
    final gardes = await _store.loadJobs();
    var nouveaux = false;
    for (final j in gardes) {
      if (_jobs.any((x) => x.id == j.id)) continue;
      if (j.state == SafeboxUploadState.running) j.state = SafeboxUploadState.queued;
      _jobs.add(j);
      nouveaux = true;
    }
    if (nouveaux) notifyListeners();
  }

  /// Le Wi-Fi est revenu : les envois qui l'attendaient repartent.
  Future<void> resumeWaitingWifi() async {
    await _chargerUneFois();
    var repris = false;
    for (final j in _jobs.where((x) => x.state == SafeboxUploadState.waitingWifi)) {
      j.state = SafeboxUploadState.queued;
      repris = true;
    }
    if (!repris) return;
    notifyListeners();
    await _pomper();
  }

  /// « Envoyer avec les données mobiles » : l'inscrit lève « Seulement en
  /// Wi-Fi » pour ce qui attend.
  Future<void> allowMobileData() async {
    await _chargerUneFois();
    for (final j in _jobs.where((x) => x.state == SafeboxUploadState.waitingWifi || (x.wifiOnly && x.state == SafeboxUploadState.queued))) {
      j
        ..wifiOnly = false
        ..state = SafeboxUploadState.queued;
    }
    await _sauver();
    notifyListeners();
    await _pomper();
  }

  /// Réessaie un envoi en échec.
  Future<void> retry(String jobId) async {
    final j = _jobs.where((x) => x.id == jobId).firstOrNull;
    if (j == null) return;
    j
      ..state = SafeboxUploadState.queued
      ..errorCode = null;
    await _sauver();
    notifyListeners();
    unawaited(_pomper());
  }

  /// Abandonne un envoi : l'espace réservé est libéré côté serveur.
  Future<void> cancel(String jobId) async {
    final j = _jobs.where((x) => x.id == jobId).firstOrNull;
    if (j == null) return;
    _annules.add(jobId);
    if (j.fileId != null) {
      try {
        await _transport.cancel(j.fileId!);
      } catch (e) {
        // Le serveur abandonnera de lui-même l'envoi après 48 h sans nouvelles.
        debugPrint('[Coffre] annulation non transmise : $e');
      }
    }
    await _nettoyer(j);
    _jobs.remove(j);
    await _sauver();
    notifyListeners();
  }

  /// Retire de la liste les envois terminés ou en échec.
  Future<void> clearFinished() async {
    final partants = _jobs.where((j) => j.state == SafeboxUploadState.failed).toList();
    for (final j in partants) {
      await _nettoyer(j);
    }
    _jobs.removeWhere((j) => j.state == SafeboxUploadState.completed || j.state == SafeboxUploadState.failed);
    await _sauver();
    notifyListeners();
  }

  Future<void> _pomper() async {
    if (_enCours) return;
    _enCours = true;
    try {
      for (;;) {
        final suivant = _jobs.where((j) => j.state == SafeboxUploadState.queued).firstOrNull;
        if (suivant == null) return;
        await _executer(suivant);
      }
    } finally {
      _enCours = false;
    }
  }

  Future<void> _executer(SafeboxUploadJob job) async {
    job
      ..state = SafeboxUploadState.running
      ..errorCode = null;
    notifyListeners();
    try {
      final cle = await _store.loadKey(job.id);
      if (cle == null) throw SafeboxUploadFailure('SAFEBOX_KEY_LOST');
      final fichier = await _envoyer(job, cle);
      if (_annules.contains(job.id)) return;
      job.state = SafeboxUploadState.completed;
      await _nettoyer(job);
      await _sauver();
      notifyListeners();
      _termines.add(fichier);
      _terminesAvecEnvoi.add((job: job, file: fichier));
    } on SafeboxUploadFailure catch (e) {
      if (_annules.contains(job.id)) return;
      job
        ..state = SafeboxUploadState.failed
        ..errorCode = e.code
        ..inFlightBytes = 0;
      await _sauver();
      notifyListeners();
    } on _AttendreReseau {
      job
        ..state = SafeboxUploadState.waitingNetwork
        ..errorCode = 'NETWORK'
        ..inFlightBytes = 0;
      await _sauver();
      notifyListeners();
    } on _AttendreWifi {
      job
        ..state = SafeboxUploadState.waitingWifi
        ..inFlightBytes = 0;
      await _sauver();
      notifyListeners();
    } on _Pause {
      _pauses.remove(job.id);
      job
        ..state = SafeboxUploadState.paused
        ..inFlightBytes = 0;
      await _sauver();
      notifyListeners();
    }
  }

  /// Réessaie [action] après une erreur réseau, selon [networkRetries].
  Future<T> _avecReprise<T>(Future<T> Function() action) async {
    for (var essai = 0;; essai += 1) {
      try {
        return await action();
      } on TalkyException catch (e) {
        if (e.statusCode != 0) rethrow;
        if (essai >= networkRetries.length) throw _AttendreReseau();
        await _sleep(networkRetries[essai]);
      }
    }
  }

  Future<void> _verifierSource(SafeboxUploadJob job) async {
    final f = File(job.sourcePath);
    if (!await f.exists()) throw SafeboxUploadFailure('SAFEBOX_SOURCE_MISSING');
    final st = await f.stat();
    if (st.size != job.sourceSize || st.modified.millisecondsSinceEpoch != job.sourceModifiedMs) {
      throw SafeboxUploadFailure('SAFEBOX_SOURCE_CHANGED');
    }
  }

  /// « Seulement en Wi-Fi » sur des données mobiles : l'envoi attend.
  Future<void> _verifierWifi(SafeboxUploadJob job) async {
    if (job.wifiOnly && !await _surWifi()) throw _AttendreWifi();
  }

  Future<SafeboxFile> _envoyer(SafeboxUploadJob job, Uint8List cle) async {
    await _verifierSource(job);
    await _verifierWifi(job);
    final adresses = <int, String>{};
    String? adresseApercu;

    Future<void> reserver() async {
      final ticket = await _avecReprise(() => _transport.reserve(
            folderId: job.folderId,
            name: job.name,
            mime: job.mime,
            size: job.storedSize,
            plainSize: job.plainSize,
            cipherFormat: kSafeboxCipherFormat,
            originalSize: job.originalSize,
            compressed: job.compressed,
            quality: job.quality,
            previewSize: job.previewSize,
            meta: job.meta,
            sourceFp: job.sourceFp,
          ));
      if (ticket.size != job.storedSize
          || ticket.blockCount != safeboxBlockCount(job.plainSize, ticket.blockSize)) {
        // Le serveur et l'application ne découpent pas de la même façon.
        throw SafeboxUploadFailure('SAFEBOX_BLOCK_MISMATCH');
      }
      job
        ..fileId = ticket.fileId
        ..blockSize = ticket.blockSize
        ..blockCount = ticket.blockCount
        ..done.clear()
        ..previewDone = false;
      for (final b in ticket.blocks) {
        adresses[b.n] = b.url;
      }
      adresseApercu = ticket.preview?.url;
      await _sauver();
    }

    try {
      if (job.fileId == null) {
        await reserver();
      } else {
        // Reprise : on demande à MEGA, par le serveur, ce qui est vraiment arrivé.
        try {
          final etat = await _avecReprise(() => _transport.status(job.fileId!));
          job.done
            ..clear()
            ..addAll(etat.received);
          job.previewDone = !etat.previewMissing;
        } on TalkyException catch (e) {
          // Envoi abandonné côté serveur (48 h sans nouvelles) : on repart.
          if (e.statusCode != 404) rethrow;
          job.fileId = null;
          await reserver();
        }
      }
      notifyListeners();

      for (var passage = 0; passage < 3; passage += 1) {
        await _envoyerBlocs(job, cle, adresses);
        if (job.previewSize > 0 && !job.previewDone) {
          adresseApercu = await _envoyerApercu(job, adresseApercu);
        }
        try {
          return await _avecReprise(() => _transport.complete(job.fileId!, cle));
        } on TalkyException catch (e) {
          if (e.code != 'SAFEBOX_UPLOAD_INCOMPLETE') rethrow;
          // MEGA n'a pas tout : on reprend la liste et on renvoie ce qui manque.
          final etat = await _avecReprise(() => _transport.status(job.fileId!));
          job.done
            ..clear()
            ..addAll(etat.received);
          job.previewDone = !etat.previewMissing;
          adresses.clear();
          adresseApercu = null;
        }
      }
      throw SafeboxUploadFailure('SAFEBOX_UPLOAD_INCOMPLETE');
    } on TalkyException catch (e) {
      throw SafeboxUploadFailure(e.code ?? 'HTTP_${e.statusCode}');
    }
  }

  Future<void> _envoyerBlocs(SafeboxUploadJob job, Uint8List cle, Map<int, String> adresses) async {
    final manquants = [
      for (var n = 1; n <= job.blockCount; n += 1)
        if (!job.done.contains(n)) n,
    ];
    if (manquants.isEmpty) return;
    final raf = await File(job.sourcePath).open();
    try {
      for (var i = 0; i < manquants.length; i += 1) {
        if (_annules.contains(job.id)) throw SafeboxUploadFailure('CANCELLED');
        if (_pauses.contains(job.id)) throw _Pause();
        await _verifierWifi(job);
        final n = manquants[i];
        if (!adresses.containsKey(n)) {
          final lot = manquants.skip(i).take(64).toList();
          final r = await _avecReprise(() => _transport.urls(job.fileId!, blocks: lot));
          for (final b in r.blocks) {
            adresses[b.n] = b.url;
          }
        }
        await _verifierSource(job);
        final plan = safeboxPlanBlock(n, plainSize: job.plainSize, blockSize: job.blockSize);
        await raf.setPosition(plan.plainStart);
        final clair = await raf.read(plan.plainLength);
        if (clair.length != plan.plainLength) throw SafeboxUploadFailure('SAFEBOX_SOURCE_CHANGED');
        final chiffre = await _encrypt(cle, clair, plan);
        await _envoyerUnBloc(job, n, chiffre, adresses);
        job
          ..done.add(n)
          ..inFlightBytes = 0;
        await _sauver();
        notifyListeners();
      }
    } finally {
      await raf.close();
    }
  }

  Future<void> _envoyerUnBloc(SafeboxUploadJob job, int n, Uint8List chiffre, Map<int, String> adresses) async {
    for (var essai = 0;; essai += 1) {
      try {
        await _avecReprise(() => _transport.putBlock(adresses[n]!, chiffre, onProgress: (sent) {
              job.inFlightBytes = sent;
              notifyListeners();
            }));
        return;
      } on TalkyException catch (e) {
        // 403 : adresse expirée (24 h). Une nouvelle, une fois.
        if (e.statusCode != 403 || essai > 0) rethrow;
        final r = await _avecReprise(() => _transport.urls(job.fileId!, blocks: [n]));
        adresses[n] = r.blocks.first.url;
      }
    }
  }

  Future<String?> _envoyerApercu(SafeboxUploadJob job, String? adresse) async {
    final chemin = job.previewPath;
    if (chemin == null || !await File(chemin).exists()) {
      // Aperçu perdu (cache vidé) : le fichier passe sans, le serveur l'attend
      // pourtant. On ne peut pas terminer sans lui.
      throw SafeboxUploadFailure('SAFEBOX_PREVIEW_MISSING');
    }
    final octets = await File(chemin).readAsBytes();
    var url = adresse;
    for (var essai = 0;; essai += 1) {
      url ??= (await _avecReprise(() => _transport.urls(job.fileId!, preview: true))).preview?.url;
      if (url == null) throw SafeboxUploadFailure('SAFEBOX_PREVIEW_MISSING');
      try {
        await _avecReprise(() => _transport.putBlock(url!, octets));
        job.previewDone = true;
        await _sauver();
        return url;
      } on TalkyException catch (e) {
        if (e.statusCode != 403 || essai > 0) rethrow;
        url = null;
      }
    }
  }

  Future<void> _nettoyer(SafeboxUploadJob job) async {
    await _store.deleteKey(job.id);
    for (final chemin in [job.previewPath, if (job.ownsSource) job.sourcePath]) {
      if (chemin == null) continue;
      try {
        await File(chemin).delete();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _termines.close();
    _terminesAvecEnvoi.close();
    super.dispose();
  }
}

class _AttendreReseau implements Exception {}

class _Pause implements Exception {}

/// « Seulement en Wi-Fi », sur des données mobiles.
class _AttendreWifi implements Exception {}
