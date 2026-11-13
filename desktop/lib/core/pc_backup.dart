// Sauvegarder des dossiers du PC dans le coffre (lot D6).
//
// Conception : coffre-bureau.html, section 06. Le moteur est celui du
// téléphone (SafeboxBackupEngine, paquet commun) : ce qui est déjà dans le
// coffre ne repart pas, ce que l'inscrit a supprimé du coffre ne revient pas
// (« ne plus sauvegarder »), les plus récents d'abord, les plus anciens
// attendent quand la place manque, un envoi perdu repart. Ici, la source
// lit les dossiers choisis sur le PC.
//
//  - Un seul sens : un fichier supprimé du PC reste dans le coffre.
//  - Chaque fichier va dans la racine de son type, avec le nom du dossier du
//    PC comme dossier d'origine.
//  - En Original : l'ordinateur ne compresse pas. Une vidéo plus lourde que
//    la limite d'un fichier attend (le moteur la voudrait en HD).
//  - Tourne quand l'application est ouverte : un passage au démarrage, à
//    chaque changement vu dans les dossiers (un peu après), et toutes les
//    15 minutes (sous Linux, la surveillance des sous-dossiers n'est pas
//    fiable).
//
// ATTENTION : le moteur supprime, après lecture, les « copies temporaires »
// des documents du téléphone (clé `d:`), et jamais les fichiers de la
// galerie (clé `g:`). Ici, `open` rend le VRAI fichier du PC : toutes les
// clés commencent donc par `g:` (kPcKeyPrefix). Le test
// pc_backup_test.dart vérifie qu'un passage ne supprime rien sur le PC.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préfixe des clés des fichiers du PC : `g:` pour que le moteur ne les
/// supprime jamais (voir l'avertissement en tête du fichier).
const String kPcKeyPrefix = 'g:pc:';

/// Un dossier du PC sauvegardé, et ce qui en part.
class PcBackupFolder {
  const PcBackupFolder({required this.path, required this.name, required this.families});

  factory PcBackupFolder.fromJson(Map<String, dynamic> j) => PcBackupFolder(
        path: '${j['path']}',
        name: '${j['name']}',
        families: {
          for (final f in (j['families'] as List? ?? const [])) SafeboxFamily.fromName('$f'),
        },
      );

  final String path;
  final String name;
  final Set<SafeboxFamily> families;

  PcBackupFolder withFamilies(Set<SafeboxFamily> f) => PcBackupFolder(path: path, name: name, families: f);

  Map<String, dynamic> toJson() => {'path': path, 'name': name, 'families': [for (final f in families) f.name]};
}

class PcBackupSettings {
  const PcBackupSettings({this.enabled = false, this.folders = const []});

  static const _cle = 'coffre_pc_backup_v1';

  final bool enabled;
  final List<PcBackupFolder> folders;

  static Future<PcBackupSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut == null) return const PcBackupSettings();
      final j = jsonDecode(brut) as Map<String, dynamic>;
      return PcBackupSettings(
        enabled: j['enabled'] == true,
        folders: [
          for (final f in (j['folders'] as List? ?? const []))
            if (f is Map) PcBackupFolder.fromJson(Map<String, dynamic>.from(f)),
        ],
      );
    } catch (_) {
      return const PcBackupSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode({'enabled': enabled, 'folders': [for (final f in folders) f.toJson()]}));
  }

  PcBackupSettings copyWith({bool? enabled, List<PcBackupFolder>? folders}) =>
      PcBackupSettings(enabled: enabled ?? this.enabled, folders: folders ?? this.folders);

  /// Les réglages du moteur : chaque dossier du PC passe par les deux
  /// entrées du moteur (« galerie » pour photos, vidéos, audios ;
  /// « documents » pour les documents), la source filtre par dossier.
  SafeboxBackupSettings toEngine() {
    final familles = {for (final f in folders) ...f.families};
    return SafeboxBackupSettings(
      enabled: enabled && folders.isNotEmpty && familles.isNotEmpty,
      families: familles,
      galleryFolders: {
        for (final f in folders)
          if (f.families.any((x) => x != SafeboxFamily.documents)) f.path,
      },
      documentFolders: [
        for (final f in folders)
          if (f.families.contains(SafeboxFamily.documents)) SafeboxDocumentFolder(uri: f.path, name: f.name),
      ],
      wifiOnly: false,
      chargingOnly: false,
    );
  }
}

/// Les dossiers du PC vus comme la « galerie » et les « dossiers de
/// documents » du moteur. Ne supprime jamais rien.
class PcFolderSource implements SafeboxDeviceSource {
  PcFolderSource({required this.folders, required this.limits});

  /// Les dossiers choisis (réglages en cours).
  final List<PcBackupFolder> Function() folders;

  /// Pour le type d'un fichier (mêmes extensions que le serveur).
  final SafeboxLimits? Function() limits;

  /// Un même dossier lu une fois par passage (galerie puis documents).
  final Map<String, ({DateTime quand, List<SafeboxDeviceItem> items})> _lus = {};

  PcBackupFolder? _dossier(String path) => folders().where((f) => f.path == path).firstOrNull;

  /// Tous les fichiers d'un dossier du PC, sous-dossiers compris ; cachés,
  /// vides et liens laissés de côté.
  Future<List<SafeboxDeviceItem>> scan(PcBackupFolder dossier) async {
    final deja = _lus[dossier.path];
    if (deja != null && DateTime.now().difference(deja.quand) < const Duration(seconds: 30)) return deja.items;
    final l = limits();
    if (l == null) throw StateError('réglages du coffre inconnus');
    final out = <SafeboxDeviceItem>[];
    final racine = Directory(dossier.path);
    if (!await racine.exists()) throw FileSystemException('dossier absent', dossier.path);
    Future<void> parcourir(Directory d) async {
      final entrees = <FileSystemEntity>[];
      try {
        await for (final e in d.list(followLinks: false)) {
          entrees.add(e);
        }
      } catch (_) {
        return; // sous-dossier illisible : le reste continue
      }
      for (final e in entrees) {
        final nom = e.uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? '';
        if (nom.startsWith('.') || _ignores.contains(nom.toLowerCase())) continue;
        if (e is Directory) {
          await parcourir(e);
        } else if (e is File) {
          try {
            final st = await e.stat();
            if (st.size <= 0) continue;
            out.add(SafeboxDeviceItem(
              key: '$kPcKeyPrefix${e.path}',
              name: nom,
              family: l.familyOf(nom),
              size: st.size,
              modified: st.modified,
              folder: dossier.name,
            ));
          } catch (_) {
            // illisible : revu au prochain passage
          }
        }
      }
    }

    await parcourir(racine);
    _lus[dossier.path] = (quand: DateTime.now(), items: out);
    return out;
  }

  /// Les fichiers de système que personne ne veut dans son coffre.
  static const _ignores = {'desktop.ini', 'thumbs.db', 'ehthumbs.db'};

  /// Oublie les lectures gardées (début d'un passage).
  void forget() => _lus.clear();

  @override
  Future<SafeboxMediaAccess> access() async => SafeboxMediaAccess.full;

  @override
  Future<SafeboxMediaAccess> requestAccess() async => SafeboxMediaAccess.full;

  @override
  Future<List<SafeboxDeviceFolder>> galleryFolders() async => const [];

  @override
  Future<List<SafeboxDeviceItem>> galleryItems({
    required Set<String> folderIds,
    required Set<SafeboxFamily> families,
    DateTime? since,
    bool withSizes = false,
  }) async {
    final out = <SafeboxDeviceItem>[];
    for (final id in folderIds) {
      final d = _dossier(id);
      if (d == null) continue;
      try {
        for (final it in await scan(d)) {
          if (it.family != SafeboxFamily.documents && families.contains(it.family) && d.families.contains(it.family)) {
            out.add(it);
          }
        }
      } catch (e) {
        debugPrint('[Sauvegarde PC] ${d.path} illisible : $e');
      }
    }
    return out;
  }

  @override
  Future<SafeboxDocumentFolder?> pickDocumentFolder() async => null;

  @override
  Future<List<SafeboxDeviceItem>> documentItems(SafeboxDocumentFolder folder, {DateTime? since}) async {
    final d = _dossier(folder.uri);
    if (d == null || !d.families.contains(SafeboxFamily.documents)) return const [];
    return [for (final it in await scan(d)) if (it.family == SafeboxFamily.documents) it];
  }

  @override
  Future<File?> open(SafeboxDeviceItem item) async {
    if (!item.key.startsWith(kPcKeyPrefix)) return null;
    final f = File(item.key.substring(kPcKeyPrefix.length));
    return await f.exists() ? f : null;
  }

  // Le PC n'efface jamais rien : la sauvegarde va dans un seul sens.
  @override
  Future<Set<String>> delete(List<SafeboxDeviceItem> items) async => const {};

  @override
  Future<Set<String>> trashMedia(List<String> mediaIds) async => const {};

  @override
  Future<({int free, int total})?> storage() async => null;
}

/// Ce qu'un dossier enverrait : nombre et poids, par type retenu.
class PcBackupEstimate {
  const PcBackupEstimate({required this.counts, required this.bytes});
  final Map<SafeboxFamily, int> counts;
  final Map<SafeboxFamily, int> bytes;

  int get count => counts.values.fold(0, (s, n) => s + n);
  int get totalBytes => bytes.values.fold(0, (s, n) => s + n);
}

/// La sauvegarde du PC : réglages, passages, surveillance des dossiers.
class PcBackup extends ChangeNotifier {
  PcBackup({
    required SafeboxBackupApi api,
    required Future<String?> Function(SafeboxBackupUpload upload) enqueue,
    required Future<int?> Function() freeSpace,
    required SafeboxLimits? Function() limits,
    required Future<bool> Function(String jobId) jobAlive,
    required Future<void> Function(String jobId) discardJob,
    required Future<void> Function() refreshOverview,
    SafeboxBackupStore? store,
    Future<PcBackupSettings> Function()? loadSettings,
    Future<void> Function(PcBackupSettings s)? saveSettings,
    this.period = const Duration(minutes: 15),
    this.settle = const Duration(seconds: 20),
  })  : _store = _MagasinFerme(store ?? PrefsSafeboxBackupStore()),
        _charger = loadSettings ?? PcBackupSettings.load,
        _enregistrer = saveSettings ?? ((s) => s.save()),
        _rafraichir = refreshOverview {
    source = PcFolderSource(folders: () => _reglages.folders, limits: limits);
    engine = SafeboxBackupEngine(
      device: source,
      api: api,
      enqueue: enqueue,
      freeSpace: freeSpace,
      maxFileBytes: () => limits()?.maxFileBytes ?? (1 << 30),
      charging: () async => true,
      jobAlive: jobAlive,
      discardJob: discardJob,
      store: _store,
    );
  }

  final _MagasinFerme _store;
  final Future<PcBackupSettings> Function() _charger;
  final Future<void> Function(PcBackupSettings) _enregistrer;
  final Future<void> Function() _rafraichir;

  /// Entre deux passages complets.
  final Duration period;

  /// Attente après un changement vu dans un dossier (une copie de 300
  /// photos ne lance qu'un passage).
  final Duration settle;

  late final PcFolderSource source;
  late final SafeboxBackupEngine engine;

  PcBackupSettings _reglages = const PcBackupSettings();
  PcBackupSettings get settings => _reglages;

  SafeboxBackupReport? _rapport;
  SafeboxBackupReport? get lastReport => _rapport;
  DateTime? _quand;
  DateTime? get lastRunAt => _quand;
  Object? _erreur;
  Object? get lastError => _erreur;

  bool get running => _boucle != null;
  bool _ferme = false;
  Timer? _minuteur;
  Timer? _bientot;
  final List<StreamSubscription<FileSystemEvent>> _veilles = [];
  bool _encore = false;

  /// Lit les réglages et démarre si la sauvegarde est activée.
  Future<void> start() async {
    _reglages = await _charger();
    notifyListeners();
    _armer();
  }

  /// Nouveaux réglages : enregistrés, puis la sauvegarde repart.
  Future<void> update(PcBackupSettings s) async {
    _reglages = s;
    await _enregistrer(s);
    notifyListeners();
    _armer();
  }

  void _armer() {
    _desarmer();
    if (_ferme || !_reglages.toEngine().enabled) return;
    _minuteur = Timer.periodic(period, (_) => unawaited(runNow()));
    for (final d in _reglages.folders) {
      try {
        // Windows suit les sous-dossiers ; Linux seulement le dossier
        // lui-même (le passage régulier complète).
        _veilles.add(Directory(d.path).watch(recursive: true).listen((_) => _changement(), onError: (_) {}));
      } catch (_) {
        try {
          _veilles.add(Directory(d.path).watch().listen((_) => _changement(), onError: (_) {}));
        } catch (_) {}
      }
    }
    unawaited(runNow());
  }

  void _desarmer() {
    _minuteur?.cancel();
    _minuteur = null;
    _bientot?.cancel();
    _bientot = null;
    for (final v in _veilles) {
      unawaited(v.cancel());
    }
    _veilles.clear();
  }

  void _changement() {
    _bientot?.cancel();
    _bientot = Timer(settle, () => unawaited(runNow()));
  }

  Future<void>? _boucle;

  /// La fin des passages en cours, sans en lancer un autre.
  Future<void> get idle => _boucle ?? Future<void>.value();

  /// Un passage maintenant ; pendant un passage, un autre le suivra. Rend la
  /// fin des passages.
  Future<void> runNow() {
    if (_ferme) return Future<void>.value();
    if (_boucle != null) {
      _encore = true;
      return _boucle!;
    }
    return _boucle = _passages().whenComplete(() => _boucle = null);
  }

  Future<void> _passages() async {
    do {
      _encore = false;
      await _passage();
    } while (_encore && !_ferme);
  }

  Future<void> _passage() async {
    final s = _reglages.toEngine();
    if (!s.enabled) return;
    try {
      await _rafraichir();
      if (_ferme) return;
      source.forget();
      _rapport = await engine.run(s);
      _quand = DateTime.now();
      _erreur = null;
    } catch (e) {
      debugPrint('[Sauvegarde PC] passage impossible : $e');
      _erreur = e;
    } finally {
      if (!_ferme) notifyListeners();
    }
  }

  /// Ce qu'enverrait [dossier] : tous ses fichiers des types retenus, avant
  /// de savoir ce que le coffre a déjà (montré avant de commencer).
  Future<PcBackupEstimate> estimate(PcBackupFolder dossier) async {
    final counts = <SafeboxFamily, int>{};
    final bytes = <SafeboxFamily, int>{};
    for (final it in await source.scan(dossier)) {
      if (!dossier.families.contains(it.family)) continue;
      counts[it.family] = (counts[it.family] ?? 0) + 1;
      bytes[it.family] = (bytes[it.family] ?? 0) + it.size;
    }
    return PcBackupEstimate(counts: counts, bytes: bytes);
  }

  /// Un envoi de la sauvegarde est arrivé dans le coffre.
  Future<void> markSaved(String key) => engine.markSaved(key);

  /// Déconnexion : plus de passage, plus d'écriture (tout va être effacé).
  void close() {
    _ferme = true;
    _store.closed = true;
    _desarmer();
  }

  @override
  void dispose() {
    close();
    engine.progress.dispose();
    super.dispose();
  }
}

/// Le magasin des fiches de sauvegarde, muet une fois le coffre fermé.
class _MagasinFerme implements SafeboxBackupStore {
  _MagasinFerme(this._s);
  final SafeboxBackupStore _s;
  bool closed = false;

  @override
  Future<Map<String, SafeboxBackupRecord>> load() async => closed ? {} : _s.load();

  @override
  Future<void> save(Map<String, SafeboxBackupRecord> records) async {
    if (!closed) await _s.save(records);
  }
}
