//  La sauvegarde automatique du coffre (lot 10, conception section 03,
//  décisions du 24/10/2026) : comme Google Photos, le coffre copie lui-même
//  les photos, vidéos, audios et documents du téléphone, une fois que
//  l'inscrit l'a autorisé. Dans un seul sens : rien n'est supprimé du
//  téléphone, et ce que l'inscrit supprime du coffre n'y revient pas.
//
//  Ce fichier ne touche ni au téléphone ni au réseau : il décide. La galerie
//  et les dossiers de documents passent par [SafeboxDeviceSource]
//  (safebox_device_media.dart), le serveur par [SafeboxBackupApi], l'envoi
//  par [SafeboxBackupEngine.enqueue] (le gestionnaire d'envois du coffre).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'safebox_models.dart';
import 'safebox_quality.dart';

// ── Réglages ─────────────────────────────────────────────────────────────────

/// Un dossier de documents choisi par l'inscrit dans le sélecteur d'Android
/// (choix « b » du 24/10/2026) : l'adresse `content://` de l'arborescence.
class SafeboxDocumentFolder {
  const SafeboxDocumentFolder({required this.uri, required this.name});

  static SafeboxDocumentFolder? fromJson(dynamic j) {
    if (j is! Map || j['uri'] is! String) return null;
    return SafeboxDocumentFolder(uri: j['uri'] as String, name: '${j['name'] ?? ''}');
  }

  final String uri;
  final String name;

  Map<String, dynamic> toJson() => {'uri': uri, 'name': name};

  @override
  bool operator ==(Object other) => other is SafeboxDocumentFolder && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

class SafeboxBackupSettings {
  const SafeboxBackupSettings({
    this.enabled = false,
    this.families = const {SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.documents},
    this.galleryFolders = const {},
    this.documentFolders = const [],
    this.since,
    this.quality = const {},
    this.wifiOnly = true,
    this.chargingOnly = true,
  });

  static const _cle = 'safebox_backup_settings_v1';

  /// Activée par l'inscrit (écrans d'activation).
  final bool enabled;

  /// Les types sauvegardés.
  final Set<SafeboxFamily> families;

  /// Les dossiers de la galerie (photos et vidéos) retenus, par identifiant.
  final Set<String> galleryFolders;

  /// Les dossiers de documents choisis.
  final List<SafeboxDocumentFolder> documentFolders;

  /// « À partir d'aujourd'hui » : les fichiers plus anciens restent sur le
  /// téléphone. Null : tout l'historique.
  final DateTime? since;

  /// Un format par type (les documents partent toujours tels quels). Absent :
  /// Original.
  final Map<SafeboxFamily, SafeboxQuality> quality;

  /// « Seulement en Wi-Fi » : cochée par défaut.
  final bool wifiOnly;

  /// « Compresser seulement pendant la charge » : cochée par défaut.
  final bool chargingOnly;

  SafeboxQuality qualityOf(SafeboxFamily f) =>
      f == SafeboxFamily.documents ? SafeboxQuality.original : quality[f] ?? SafeboxQuality.original;

  SafeboxBackupSettings copyWith({
    bool? enabled,
    Set<SafeboxFamily>? families,
    Set<String>? galleryFolders,
    List<SafeboxDocumentFolder>? documentFolders,
    DateTime? since,
    bool clearSince = false,
    Map<SafeboxFamily, SafeboxQuality>? quality,
    bool? wifiOnly,
    bool? chargingOnly,
  }) =>
      SafeboxBackupSettings(
        enabled: enabled ?? this.enabled,
        families: families ?? this.families,
        galleryFolders: galleryFolders ?? this.galleryFolders,
        documentFolders: documentFolders ?? this.documentFolders,
        since: clearSince ? null : since ?? this.since,
        quality: quality ?? this.quality,
        wifiOnly: wifiOnly ?? this.wifiOnly,
        chargingOnly: chargingOnly ?? this.chargingOnly,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'families': [for (final f in families) f.name],
        'galleryFolders': galleryFolders.toList(),
        'documentFolders': [for (final d in documentFolders) d.toJson()],
        if (since != null) 'since': since!.toUtc().toIso8601String(),
        'quality': {for (final e in quality.entries) e.key.name: e.value.name},
        'wifiOnly': wifiOnly,
        'chargingOnly': chargingOnly,
      };

  factory SafeboxBackupSettings.fromJson(Map<String, dynamic> j) {
    final q = j['quality'] is Map ? j['quality'] as Map : const {};
    return SafeboxBackupSettings(
      enabled: j['enabled'] == true,
      families: {
        for (final v in (j['families'] is List ? j['families'] as List : const []))
          if (v is String && SafeboxFamily.values.any((f) => f.name == v)) SafeboxFamily.fromName(v),
      },
      galleryFolders: {for (final v in (j['galleryFolders'] is List ? j['galleryFolders'] as List : const [])) '$v'},
      documentFolders: [
        for (final v in (j['documentFolders'] is List ? j['documentFolders'] as List : const []))
          ?SafeboxDocumentFolder.fromJson(v),
      ],
      since: j['since'] is String ? DateTime.tryParse(j['since'] as String) : null,
      quality: {
        for (final f in SafeboxFamily.values)
          if (q[f.name] is String) f: SafeboxQuality.fromName(q[f.name] as String),
      },
      wifiOnly: j['wifiOnly'] != false,
      chargingOnly: j['chargingOnly'] != false,
    );
  }

  static Future<SafeboxBackupSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut == null) return const SafeboxBackupSettings();
      return SafeboxBackupSettings.fromJson(Map<String, dynamic>.from(jsonDecode(brut) as Map));
    } catch (_) {
      return const SafeboxBackupSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(toJson()));
  }
}

// ── Le téléphone ─────────────────────────────────────────────────────────────

/// L'accès de l'application à la galerie.
enum SafeboxMediaAccess {
  /// Toute la galerie.
  full,

  /// Android 14 et plus : seulement les photos choisies par l'inscrit. Le
  /// coffre ne sauvegarde que celles-là et propose d'élargir l'accès.
  limited,
  denied,
}

/// Un dossier de la galerie (« Appareil photo », « WhatsApp Images »…).
class SafeboxDeviceFolder {
  const SafeboxDeviceFolder({required this.id, required this.name, required this.count});

  final String id;
  final String name;

  /// Photos et vidéos du dossier.
  final int count;

  /// Coché d'office à l'activation : l'appareil photo et WhatsApp. Les
  /// captures d'écran et les images téléchargées restent au choix.
  bool get checkedByDefault {
    final n = name.toLowerCase();
    return n == 'camera' || n.contains('dcim') || n.contains('appareil photo') || n.contains('whatsapp');
  }
}

/// Un fichier du téléphone que la sauvegarde peut prendre.
class SafeboxDeviceItem {
  const SafeboxDeviceItem({
    required this.key,
    required this.name,
    required this.family,
    required this.size,
    required this.modified,
    this.folder,
    this.width,
    this.height,
    this.durationMs,
  });

  /// Identifiant stable sur ce téléphone : `g:` suivi de l'identifiant de la
  /// galerie, `d:` suivi de l'adresse d'un document.
  final String key;
  final String name;
  final SafeboxFamily family;

  /// En octets ; -1 tant qu'il n'est pas mesuré (une photo de la galerie ne
  /// se mesure qu'en ouvrant son fichier : seulement pour les estimations).
  final int size;
  final DateTime modified;

  /// Son dossier d'origine (« Camera », « WhatsApp Images ») : il suit le
  /// fichier dans le coffre, pour filtrer Photos et Vidéos.
  final String? folder;
  final int? width;
  final int? height;
  final double? durationMs;

  bool get fromGallery => key.startsWith('g:');

  SafeboxDeviceItem withSize(int bytes) => SafeboxDeviceItem(
        key: key,
        name: name,
        family: family,
        size: bytes,
        modified: modified,
        folder: folder,
        width: width,
        height: height,
        durationMs: durationMs,
      );

  SafeboxMediaFacts get facts =>
      SafeboxMediaFacts(sizeBytes: size, width: width, height: height, durationMs: durationMs);
}

/// La galerie, les dossiers de documents et la mémoire du téléphone.
abstract class SafeboxDeviceSource {
  Future<SafeboxMediaAccess> access();
  Future<SafeboxMediaAccess> requestAccess();

  /// Les dossiers de photos et vidéos de la galerie.
  Future<List<SafeboxDeviceFolder>> galleryFolders();

  /// Photos, vidéos (dans [folderIds]) et audios (tous) du téléphone, modifiés
  /// depuis [since] ; mesurés seulement avec [withSizes] (plus lent).
  Future<List<SafeboxDeviceItem>> galleryItems({
    required Set<String> folderIds,
    required Set<SafeboxFamily> families,
    DateTime? since,
    bool withSizes = false,
  });

  /// Le sélecteur de dossiers d'Android ; null si l'inscrit renonce.
  Future<SafeboxDocumentFolder?> pickDocumentFolder();
  Future<List<SafeboxDeviceItem>> documentItems(SafeboxDocumentFolder folder, {DateTime? since});

  /// Le fichier, lisible : l'original de la galerie (localisation comprise),
  /// ou une copie temporaire d'un document (à supprimer après usage).
  Future<File?> open(SafeboxDeviceItem item);

  /// Retire ces fichiers du téléphone (Android demande lui-même la
  /// confirmation, une fois pour le lot). Rend les clés retirées.
  Future<Set<String>> delete(List<SafeboxDeviceItem> items);

  /// Mémoire du téléphone : libre et totale, en octets.
  Future<({int free, int total})?> storage();
}

// ── Empreinte de l'original ──────────────────────────────────────────────────

/// Morceaux lus au début et à la fin d'un fichier pour son empreinte.
const int kSafeboxFingerprintChunk = 256 * 1024;

/// Empreinte de l'original d'un fichier (64 caractères hexadécimaux) : sa
/// taille, ses 256 premiers Kio et ses 256 derniers, sous SHA-256. Assez pour
/// reconnaître un fichier sans lire une vidéo de 1 Go en entier. Le serveur la
/// lie au compte avant de la garder.
Future<String> safeboxSourceFingerprint(String path) => Isolate.run(() => safeboxSourceFingerprintSync(path));

String safeboxSourceFingerprintSync(String path) {
  final f = File(path).openSync();
  try {
    final taille = f.lengthSync();
    final entete = ByteData(12)
      ..setUint32(0, 0x53424631) // « SBF1 »
      ..setUint64(4, taille);
    final debut = f.readSync(kSafeboxFingerprintChunk);
    final morceaux = <List<int>>[entete.buffer.asUint8List(), debut];
    if (taille > kSafeboxFingerprintChunk) {
      final depart = taille - kSafeboxFingerprintChunk > kSafeboxFingerprintChunk ? taille - kSafeboxFingerprintChunk : kSafeboxFingerprintChunk;
      f.setPositionSync(depart);
      morceaux.add(f.readSync(kSafeboxFingerprintChunk));
    }
    return sha256.convert(morceaux.expand((m) => m).toList()).toString();
  } finally {
    f.closeSync();
  }
}

// ── Estimations (écran « Qualité » de l'activation) ──────────────────────────

/// Le nombre et le poids d'une sélection, par type et par format.
class SafeboxBackupEstimate {
  const SafeboxBackupEstimate({required this.counts, required this.bytes});

  final Map<SafeboxFamily, int> counts;

  /// Poids probable par type et par format (les documents : Original seul).
  final Map<SafeboxFamily, Map<SafeboxQuality, int>> bytes;

  int countOf(SafeboxFamily f) => counts[f] ?? 0;
  int bytesOf(SafeboxFamily f, SafeboxQuality q) => bytes[f]?[q] ?? 0;

  /// Le total avec un format par type.
  int total(SafeboxQuality Function(SafeboxFamily f) qualityOf) =>
      SafeboxFamily.values.fold(0, (s, f) => s + bytesOf(f, f == SafeboxFamily.documents ? SafeboxQuality.original : qualityOf(f)));

  static SafeboxBackupEstimate of(Iterable<SafeboxDeviceItem> items) {
    final counts = <SafeboxFamily, int>{};
    final bytes = <SafeboxFamily, Map<SafeboxQuality, int>>{};
    for (final it in items) {
      counts[it.family] = (counts[it.family] ?? 0) + 1;
      final parFormat = bytes.putIfAbsent(it.family, () => {});
      for (final q in SafeboxQuality.values) {
        final n = switch (it.family) {
          SafeboxFamily.photos => safeboxEstimatePhotoBytes(it.facts, q),
          SafeboxFamily.videos => safeboxEstimateVideoBytes(it.facts, q, hevc: true),
          SafeboxFamily.audios => safeboxEstimateAudioBytes(it.facts, q),
          SafeboxFamily.documents => it.size,
        };
        parFormat[q] = (parFormat[q] ?? 0) + n;
      }
    }
    return SafeboxBackupEstimate(counts: counts, bytes: bytes);
  }
}

/// Présélection du 24/10/2026 : Original si tout tient dans l'espace libre,
/// sinon HD.
SafeboxQuality safeboxBackupPreselect(SafeboxBackupEstimate e, int freeBytes) =>
    e.total((_) => SafeboxQuality.original) <= freeBytes ? SafeboxQuality.original : SafeboxQuality.hd;

/// Une vidéo de plus de 1 Go en Original passe en HD (limite d'un fichier).
SafeboxQuality safeboxBackupQualityFor(SafeboxDeviceItem item, SafeboxQuality wanted, int maxFileBytes) {
  if (wanted == SafeboxQuality.original && item.family == SafeboxFamily.videos && item.size > maxFileBytes) {
    return SafeboxQuality.hd;
  }
  return wanted;
}

// ── Ce que la sauvegarde a déjà fait ─────────────────────────────────────────

/// Ce que la sauvegarde sait d'un fichier du téléphone.
enum SafeboxBackupState {
  /// Dans le coffre.
  saved,

  /// Supprimé du coffre par l'inscrit : ne plus sauvegarder.
  skip,

  /// Confié au gestionnaire d'envois.
  queued,
}

class SafeboxBackupRecord {
  const SafeboxBackupRecord({
    required this.state,
    required this.size,
    required this.modifiedMs,
    this.fp,
    this.quality,
    this.jobId,
  });

  static SafeboxBackupRecord? fromJson(dynamic j) {
    if (j is! Map) return null;
    final etat = SafeboxBackupState.values.where((s) => s.name == j['s']).firstOrNull;
    if (etat == null) return null;
    return SafeboxBackupRecord(
      state: etat,
      size: (j['n'] as num?)?.toInt() ?? 0,
      modifiedMs: (j['m'] as num?)?.toInt() ?? 0,
      fp: j['fp'] as String?,
      quality: j['q'] is String ? SafeboxQuality.fromName(j['q'] as String) : null,
      jobId: j['j'] as String?,
    );
  }

  final SafeboxBackupState state;

  /// Taille et date du fichier quand il a été vu : changés, il est revu.
  final int size;
  final int modifiedMs;
  final String? fp;

  /// Le format dans lequel il est parti (« Libérer la mémoire du téléphone »
  /// ne propose que l'Original).
  final SafeboxQuality? quality;
  final String? jobId;

  /// Le même fichier qu'à son dernier passage : même date et, s'il est
  /// mesuré, même taille.
  bool matches(SafeboxDeviceItem it) =>
      (it.size < 0 || it.size == size) && it.modified.millisecondsSinceEpoch == modifiedMs;

  SafeboxBackupRecord copyWith({SafeboxBackupState? state, SafeboxQuality? quality}) => SafeboxBackupRecord(
        state: state ?? this.state,
        size: size,
        modifiedMs: modifiedMs,
        fp: fp,
        quality: quality ?? this.quality,
        jobId: jobId,
      );

  Map<String, dynamic> toJson() => {
        's': state.name,
        'n': size,
        'm': modifiedMs,
        'fp': ?fp,
        'q': ?quality?.name,
        'j': ?jobId,
      };
}

/// Où la sauvegarde garde ce qu'elle a fait (le téléphone le garde aussi
/// pour ne pas tout redemander au serveur à chaque passage).
abstract class SafeboxBackupStore {
  Future<Map<String, SafeboxBackupRecord>> load();
  Future<void> save(Map<String, SafeboxBackupRecord> records);
}

class PrefsSafeboxBackupStore implements SafeboxBackupStore {
  static const _cle = 'safebox_backup_records_v1';

  @override
  Future<Map<String, SafeboxBackupRecord>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Une autre partie de l'application (la tâche de fond) a pu écrire.
      await prefs.reload();
      final d = jsonDecode(prefs.getString(_cle) ?? '{}');
      if (d is! Map) return {};
      return {
        for (final e in d.entries)
          if (SafeboxBackupRecord.fromJson(e.value) case final r?) '${e.key}': r,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, SafeboxBackupRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode({for (final e in records.entries) e.key: e.value.toJson()}));
  }
}

// ── Le serveur ───────────────────────────────────────────────────────────────

/// Ce que le coffre a d'un original (`POST /api/safebox/backup/check`).
enum SafeboxBackupCheck { saved, elsewhere, uploading, skip, unknown }

abstract class SafeboxBackupApi {
  /// Empreintes → état ; `link` ajoute sans copie au dossier de son type ce
  /// qui n'est qu'ailleurs (un album).
  Future<Map<String, SafeboxBackupCheck>> check(List<String> fps, {bool link = true});
  Future<void> skip(List<String> fps);
}

// ── Le moteur ────────────────────────────────────────────────────────────────

/// Un fichier à envoyer, avec son format et son empreinte.
class SafeboxBackupUpload {
  const SafeboxBackupUpload({required this.item, required this.file, required this.quality, required this.fp});
  final SafeboxDeviceItem item;
  final File file;
  final SafeboxQuality quality;
  final String fp;
}

/// Pourquoi un passage s'est arrêté avant la fin.
enum SafeboxBackupStop { none, disabled, noAccess, spaceFull, busy }

/// Ce qu'a fait un passage.
class SafeboxBackupReport {
  const SafeboxBackupReport({
    this.seen = 0,
    this.alreadySaved = 0,
    this.skipped = 0,
    this.queued = 0,
    this.waitingCharge = 0,
    this.noRoom = 0,
    this.stop = SafeboxBackupStop.none,
  });

  /// Fichiers du téléphone retenus par les réglages.
  final int seen;

  /// Déjà dans le coffre (dont ceux ajoutés sans copie depuis un album).
  final int alreadySaved;
  final int skipped;
  final int queued;

  /// À compresser, en attente de la charge.
  final int waitingCharge;

  /// Trop gros pour la place qui restait : revus quand de la place se libère.
  final int noRoom;
  final SafeboxBackupStop stop;
}

/// Décide, à chaque passage, ce qui part : ce qui est neuf sur le téléphone,
/// ni déjà dans le coffre, ni supprimé du coffre par l'inscrit, tant que
/// l'espace le permet.
class SafeboxBackupEngine {
  SafeboxBackupEngine({
    required this.device,
    required this.api,
    required this.enqueue,
    required this.freeSpace,
    required this.maxFileBytes,
    required this.charging,
    SafeboxBackupStore? store,
    this.batchSize = 100,
  }) : _store = store ?? PrefsSafeboxBackupStore();

  final SafeboxDeviceSource device;
  final SafeboxBackupApi api;

  /// Confie un fichier au gestionnaire d'envois ; rend l'identifiant de
  /// l'envoi, ou null s'il n'a pas pu partir.
  final Future<String?> Function(SafeboxBackupUpload upload) enqueue;

  /// Espace libre du coffre, envois en cours déduits ; null s'il est inconnu.
  final Future<int?> Function() freeSpace;
  final int Function() maxFileBytes;

  /// Le téléphone est-il en charge ?
  final Future<bool> Function() charging;
  final SafeboxBackupStore _store;
  final int batchSize;

  bool _enCours = false;
  bool get running => _enCours;

  Future<Map<String, SafeboxBackupRecord>> records() => _store.load();

  /// Les fichiers du téléphone retenus par ces réglages ; mesurés avec
  /// [withSizes] (estimations, « Libérer la mémoire »).
  Future<List<SafeboxDeviceItem>> selection(SafeboxBackupSettings s, {bool withSizes = false}) async {
    final out = <SafeboxDeviceItem>[];
    final galerie = s.families.difference({SafeboxFamily.documents});
    if (galerie.isNotEmpty) {
      out.addAll(await device.galleryItems(
        folderIds: s.galleryFolders,
        families: galerie,
        since: s.since,
        withSizes: withSizes,
      ));
    }
    if (s.families.contains(SafeboxFamily.documents)) {
      for (final d in s.documentFolders) {
        out.addAll(await device.documentItems(d, since: s.since));
      }
    }
    return out;
  }

  /// Ce qui reste à sauvegarder, pour l'accueil : les fichiers retenus que la
  /// sauvegarde n'a pas encore vus partir.
  Future<List<SafeboxDeviceItem>> pending(SafeboxBackupSettings s) async {
    final faits = await _store.load();
    return [
      for (final it in await selection(s))
        if (!(faits[it.key]?.matches(it) ?? false)) it,
    ];
  }

  /// Un passage complet.
  Future<SafeboxBackupReport> run(SafeboxBackupSettings s) async {
    if (!s.enabled) return const SafeboxBackupReport(stop: SafeboxBackupStop.disabled);
    if (_enCours) return const SafeboxBackupReport(stop: SafeboxBackupStop.busy);
    _enCours = true;
    try {
      if (await device.access() == SafeboxMediaAccess.denied && s.documentFolders.isEmpty) {
        return const SafeboxBackupReport(stop: SafeboxBackupStop.noAccess);
      }
      final faits = await _store.load();
      final items = await selection(s);
      // Du plus récent au plus ancien, toutes sources confondues : quand la
      // place manque, ce sont les plus anciens qui attendent.
      final neufs = [for (final it in items) if (!(faits[it.key]?.matches(it) ?? false)) it]
        ..sort((a, b) => b.modified.compareTo(a.modified));
      var dejaLa = 0, sautes = 0, partis = 0, attenteCharge = 0, sansPlace = 0;
      var libre = await freeSpace();
      final enCharge = await charging();
      for (var i = 0; i < neufs.length; i += batchSize) {
        final lot = neufs.sublist(i, i + batchSize > neufs.length ? neufs.length : i + batchSize);
        // Les empreintes du lot, puis une seule question au serveur. La place
        // de chacun est retenue à l'ouverture et rendue s'il ne part pas.
        final ouverts = <({SafeboxDeviceItem item, File file, String fp, SafeboxQuality q, int poids})>[];
        for (final it in lot) {
          try {
            final f = await device.open(it);
            if (f == null) continue;
            final mesure = it.size >= 0 ? it : it.withSize(await f.length());
            final q = safeboxBackupQualityFor(mesure, s.qualityOf(mesure.family), maxFileBytes());
            final poids = switch (mesure.family) {
              SafeboxFamily.photos => safeboxEstimatePhotoBytes(mesure.facts, q),
              SafeboxFamily.videos => safeboxEstimateVideoBytes(mesure.facts, q, hevc: true),
              SafeboxFamily.audios => safeboxEstimateAudioBytes(mesure.facts, q),
              SafeboxFamily.documents => mesure.size,
            };
            // Trop gros pour la place qui reste : les suivants, plus petits,
            // peuvent encore tenir. Pas lu (pas d'empreinte) : il sera revu
            // quand de la place se libère.
            if (libre != null && poids > libre) {
              sansPlace += 1;
              _jeter(f, mesure);
              continue;
            }
            ouverts.add((item: mesure, file: f, fp: await safeboxSourceFingerprint(f.path), q: q, poids: poids));
            if (libre != null) libre -= poids;
          } catch (e) {
            debugPrint('[Sauvegarde] ${it.name} illisible : $e');
          }
        }
        if (ouverts.isEmpty) continue;
        final etats = await api.check([for (final o in ouverts) o.fp]);
        for (final o in ouverts) {
          final it = o.item;
          SafeboxBackupRecord note(SafeboxBackupState etat, {SafeboxQuality? q, String? job}) => SafeboxBackupRecord(
                state: etat,
                size: it.size,
                modifiedMs: it.modified.millisecondsSinceEpoch,
                fp: o.fp,
                quality: q,
                jobId: job,
              );
          var parti = false;
          switch (etats[o.fp] ?? SafeboxBackupCheck.unknown) {
            case SafeboxBackupCheck.saved || SafeboxBackupCheck.elsewhere:
              faits[it.key] = note(SafeboxBackupState.saved);
              dejaLa += 1;
              _jeter(o.file, it);
            case SafeboxBackupCheck.skip:
              faits[it.key] = note(SafeboxBackupState.skip);
              sautes += 1;
              _jeter(o.file, it);
            case SafeboxBackupCheck.uploading:
              // Un autre appareil l'envoie : revu au prochain passage.
              _jeter(o.file, it);
            case SafeboxBackupCheck.unknown:
              if (o.q != SafeboxQuality.original && s.chargingOnly && !enCharge) {
                attenteCharge += 1;
                _jeter(o.file, it);
                break;
              }
              final job = await enqueue(SafeboxBackupUpload(item: it, file: o.file, quality: o.q, fp: o.fp));
              if (job == null) break;
              faits[it.key] = note(SafeboxBackupState.queued, q: o.q, job: job);
              partis += 1;
              parti = true;
          }
          if (!parti && libre != null) libre += o.poids;
        }
        await _store.save(faits);
      }
      return SafeboxBackupReport(
        seen: items.length,
        alreadySaved: dejaLa,
        skipped: sautes,
        queued: partis,
        waitingCharge: attenteCharge,
        noRoom: sansPlace,
        // « Espace plein » seulement pour ce qui ne tient vraiment pas : tout
        // ce qui tenait est parti.
        stop: sansPlace > 0 ? SafeboxBackupStop.spaceFull : SafeboxBackupStop.none,
      );
    } finally {
      _enCours = false;
    }
  }

  /// Une copie temporaire d'un document n'est plus utile.
  void _jeter(File f, SafeboxDeviceItem it) {
    if (it.fromGallery) return;
    f.delete().ignore();
  }

  /// Un envoi de la sauvegarde est arrivé dans le coffre.
  Future<void> markSaved(String key) => _changer(key, SafeboxBackupState.saved);

  /// Un envoi a échoué ou a été annulé : le fichier sera repris au passage suivant.
  Future<void> forget(String key) async {
    final faits = await _store.load();
    if (faits.remove(key) != null) await _store.save(faits);
  }

  Future<void> _changer(String key, SafeboxBackupState etat) async {
    final faits = await _store.load();
    final r = faits[key];
    if (r == null) return;
    faits[key] = r.copyWith(state: etat);
    await _store.save(faits);
  }

  /// « Libérer la mémoire du téléphone » : les fichiers de la galerie déjà
  /// dans le coffre en Original (retirer un original gardé en HD ferait
  /// perdre la qualité d'origine).
  Future<List<SafeboxDeviceItem>> freeable(SafeboxBackupSettings s) async {
    final faits = await _store.load();
    bool enOriginal(SafeboxDeviceItem it) {
      final r = faits[it.key];
      return r != null &&
          r.state == SafeboxBackupState.saved &&
          r.matches(it) &&
          (r.quality ?? SafeboxQuality.original) == SafeboxQuality.original;
    }

    return [for (final it in await selection(s, withSizes: true)) if (it.fromGallery && enOriginal(it)) it];
  }

  /// Retire ces fichiers du téléphone ; ils restent dans le coffre.
  Future<Set<String>> free(List<SafeboxDeviceItem> items) => device.delete(items);
}
