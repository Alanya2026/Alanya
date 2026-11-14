// Sauvegarder des dossiers du PC dans le coffre (lot D6).
//
// Conception : coffre-bureau.html, section 06. Le moteur est celui du
// téléphone (SafeboxBackupEngine, paquet commun) : ce qui est déjà dans le
// coffre ne repart pas, ce que l'inscrit a supprimé du coffre ne revient pas
// (« ne plus sauvegarder »), les plus récents d'abord, les plus anciens
// attendent quand la place manque, un envoi perdu repart. Ici, la source
// lit les dossiers choisis sur le PC.
//
//  - Un seul sens : un fichier supprimé du PC reste dans le coffre. Sur
//    option (« Retirer de l'ordinateur après la sauvegarde », décochée par
//    défaut), les photos et vidéos gardées en Original partent à la
//    corbeille de l'ordinateur, comme sur le téléphone (removeSaved).
//  - Le dossier du PC est recréé dans Albums, avec son arborescence
//    (Albums › Images › Vacances › plage.jpg, 14/11/2026) : rien ne se
//    disperse. Chaque fichier est aussi dans la racine de son type (Photos,
//    Documents…), sans place en plus : c'est le même contenu. Un fichier
//    déjà dans le coffre (venu du téléphone) n'est pas renvoyé mais rejoint
//    l'album. Ce que l'inscrit change ensuite dans l'album est respecté.
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

import 'importer.dart';
import 'os_trash.dart';

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
  const PcBackupSettings({
    this.enabled = false,
    this.folders = const [],
    this.removeFromPc = false,
    this.removeAfterDays = 30,
  });

  static const _cle = 'coffre_pc_backup_v1';

  final bool enabled;
  final List<PcBackupFolder> folders;

  /// « Retirer de l'ordinateur après la sauvegarde » (14/11/2026), comme
  /// sur le téléphone : décoché par défaut ; photos et vidéos gardées en
  /// Original dans le coffre seulement, vers la corbeille de l'ordinateur.
  final bool removeFromPc;

  /// Seulement celles plus vieilles que ce nombre de jours (30, 7) ; 0 : dès
  /// la sauvegarde.
  final int removeAfterDays;

  static Future<PcBackupSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cle);
      if (brut == null) return const PcBackupSettings();
      final j = jsonDecode(brut) as Map<String, dynamic>;
      return PcBackupSettings(
        enabled: j['enabled'] == true,
        removeFromPc: j['removeFromPc'] == true,
        removeAfterDays: j['removeAfterDays'] is int ? j['removeAfterDays'] as int : 30,
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
    await prefs.setString(
      _cle,
      jsonEncode({
        'enabled': enabled,
        'folders': [for (final f in folders) f.toJson()],
        'removeFromPc': removeFromPc,
        'removeAfterDays': removeAfterDays,
      }),
    );
  }

  PcBackupSettings copyWith({bool? enabled, List<PcBackupFolder>? folders, bool? removeFromPc, int? removeAfterDays}) =>
      PcBackupSettings(
        enabled: enabled ?? this.enabled,
        folders: folders ?? this.folders,
        removeFromPc: removeFromPc ?? this.removeFromPc,
        removeAfterDays: removeAfterDays ?? this.removeAfterDays,
      );

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
  PcFolderSource({required this.folders, required this.limits, this.stableAfter = const Duration(minutes: 2)});

  /// Un fichier modifié depuis moins longtemps est peut-être encore en cours
  /// de copie (une vidéo de 2 Go venue d'une clé USB) : il attend, sinon son
  /// envoi échouerait (« le fichier a changé ») et finirait abandonné.
  final Duration stableAfter;

  /// Le moment où le plus proche des fichiers écartés comme trop récents
  /// sera stable ; null s'il n'y en a pas (lu par [PcBackup] pour revenir).
  DateTime? nextStableAt;

  bool _stable(SafeboxDeviceItem it) {
    final pret = it.modified.add(stableAfter);
    if (!pret.isAfter(DateTime.now())) return true;
    if (nextStableAt == null || pret.isBefore(nextStableAt!)) nextStableAt = pret;
    return false;
  }

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
  void forget() {
    _lus.clear();
    nextStableAt = null;
  }

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
          if (it.family != SafeboxFamily.documents &&
              families.contains(it.family) &&
              d.families.contains(it.family) &&
              _stable(it)) {
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
    return [for (final it in await scan(d)) if (it.family == SafeboxFamily.documents && _stable(it)) it];
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
    Future<Set<String>> Function(List<String> paths)? computerTrash,
    SafeboxCalls? calls,
    int? Function()? albumsRoot,
    Future<Map<String, String>> Function()? loadPlaced,
    Future<void> Function(Map<String, String> placed)? savePlaced,
    Duration stableAfter = const Duration(minutes: 2),
    this.period = const Duration(minutes: 15),
    this.settle = const Duration(seconds: 20),
  })  : _store = _MagasinFerme(store ?? PrefsSafeboxBackupStore()),
        _charger = loadSettings ?? PcBackupSettings.load,
        _enregistrer = saveSettings ?? ((s) => s.save()),
        _rafraichir = refreshOverview,
        _corbeille = computerTrash ?? moveToComputerTrash,
        _api = calls,
        _albums = albumsRoot ?? (() => null),
        _chargerRanges = loadPlaced ?? _rangesPrefs,
        _enregistrerRanges = savePlaced ?? _enregistrerRangesPrefs {
    source = PcFolderSource(folders: () => _reglages.folders, limits: limits, stableAfter: stableAfter);
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
  final Future<Set<String>> Function(List<String>) _corbeille;

  /// Pour ranger dans Albums (null : pas de rangement, tests du moteur).
  final SafeboxCalls? _api;
  final int? Function() _albums;
  final Future<Map<String, String>> Function() _chargerRanges;
  final Future<void> Function(Map<String, String>) _enregistrerRanges;

  static const _cleRanges = 'coffre_pc_backup_placed_v1';

  /// Fichier du PC → empreinte déjà rangée dans l'album : un fichier retiré
  /// de l'album par l'inscrit n'y revient pas.
  static Future<Map<String, String>> _rangesPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cleRanges);
      return brut == null ? {} : Map<String, String>.from(jsonDecode(brut) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _enregistrerRangesPrefs(Map<String, String> r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleRanges, jsonEncode(r));
  }

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

  /// Le dernier retrait de l'ordinateur : nombre de fichiers et octets.
  ({int count, int bytes, DateTime at})? _retrait;
  ({int count, int bytes, DateTime at})? get lastRemoval => _retrait;
  Timer? _retraitBientot;
  Future<void>? _retraitEnCours;

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
      await placeInAlbums();
      await removeSaved();
      // Des fichiers encore en cours de copie ont été laissés : un passage
      // revient quand ils seront stables.
      final stable = source.nextStableAt;
      if (stable != null && !_ferme) {
        _bientot?.cancel();
        _bientot = Timer(stable.difference(DateTime.now()) + const Duration(seconds: 5), () => unawaited(runNow()));
      }
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

  /// Un envoi de la sauvegarde est arrivé dans le coffre. « Tout de suite » :
  /// le retrait suit peu après (une rafale d'envois, un seul retrait).
  Future<void> markSaved(String key) async {
    await engine.markSaved(key);
    if (_ferme) return;
    // Une rafale d'envois arrivés : un seul rangement (et un seul retrait
    // pour « Tout de suite »).
    _retraitBientot?.cancel();
    _retraitBientot = Timer(const Duration(seconds: 10), () async {
      await placeInAlbums();
      if (_reglages.removeFromPc && _reglages.removeAfterDays == 0) await removeSaved();
    });
  }

  Future<void>? _rangementEnCours;

  /// Range dans Albums › dossier › sous-dossiers les fichiers sauvegardés
  /// qui n'y sont pas encore, sans copie ; chacun est aussi lié à la racine
  /// de son type.
  Future<void> placeInAlbums() => _rangementEnCours ??= _ranger().whenComplete(() => _rangementEnCours = null);

  Future<void> _ranger() async {
    final api = _api;
    final albums = _albums();
    final r = _reglages;
    if (_ferme || api == null || albums == null || !r.toEngine().enabled) return;
    try {
      final fiches = await engine.records();
      final ranges = await _chargerRanges();
      final dossiers = [...r.folders]..sort((a, b) => b.path.length.compareTo(a.path.length));
      // Fichier → (empreinte, chemin dans l'album).
      final aRanger = <String, ({String fp, List<String> chemin})>{};
      for (final it in await engine.selection(r.toEngine())) {
        final f = fiches[it.key];
        final fp = f?.fp;
        if (f == null || fp == null || f.state != SafeboxBackupState.saved || !f.matches(it)) continue;
        if (ranges[it.key] == fp) continue;
        final chemin = it.key.substring(kPcKeyPrefix.length);
        final d = dossiers.where((x) => chemin.startsWith('${x.path}${Platform.pathSeparator}')).firstOrNull;
        if (d == null) continue;
        final morceaux = chemin.substring(d.path.length + 1).split(Platform.pathSeparator)..removeLast();
        aRanger[it.key] = (fp: fp, chemin: [d.name, ...morceaux.where((m) => m.isNotEmpty)]);
      }
      if (aRanger.isEmpty) return;
      // Le fichier du coffre de chaque empreinte, lié au passage à la racine
      // de son type s'il n'était que dans un album (link).
      final fps = {for (final v in aRanger.values) v.fp}.toList();
      final fichiers = <String, int>{};
      for (var i = 0; i < fps.length; i += 500) {
        final res = await api.checkSafeboxSources(fps.sublist(i, i + 500 > fps.length ? fps.length : i + 500), link: true);
        for (final e in res.entries) {
          if (e.value.fileId != null && (e.value.state == 'saved' || e.value.state == 'elsewhere')) fichiers[e.key] = e.value.fileId!;
        }
      }
      final resolveur = FolderResolver(api, albums, 80);
      final parDossier = <int, Map<String, int>>{};
      for (final e in aRanger.entries) {
        final id = fichiers[e.value.fp];
        if (id == null) continue;
        final dossier = await resolveur.resolve(e.value.chemin);
        parDossier.putIfAbsent(dossier, () => {})[e.key] = id;
      }
      for (final MapEntry(key: dossier, value: cles) in parDossier.entries) {
        final liste = cles.entries.toList();
        for (var i = 0; i < liste.length; i += 50) {
          final lot = liste.sublist(i, i + 50 > liste.length ? liste.length : i + 50);
          await api.addSafeboxFilesToFolder(dossier, [for (final x in lot) x.value]);
          for (final x in lot) {
            ranges[x.key] = aRanger[x.key]!.fp;
          }
          if (_ferme) return;
          await _enregistrerRanges(ranges);
        }
      }
    } catch (e) {
      debugPrint('[Sauvegarde PC] rangement dans Albums impossible : $e');
    }
  }

  /// Renomme un dossier sauvegardé : son album dans le coffre aussi (tous ses
  /// fichiers, anciens et nouveaux). Le chemin sur l'ordinateur ne change pas.
  Future<void> renameFolder(PcBackupFolder dossier, String nom) async {
    final api = _api;
    final albums = _albums();
    if (api != null && albums != null) {
      final id = await FolderResolver(api, albums, 80).find(dossier.name);
      if (id != null) await api.updateSafeboxFolder(id, name: nom);
    }
    await update(_reglages.copyWith(folders: [
      for (final f in _reglages.folders)
        f.path == dossier.path ? PcBackupFolder(path: f.path, name: nom, families: f.families) : f,
    ]));
  }

  /// « Retirer de l'ordinateur après la sauvegarde » : les photos et vidéos
  /// des dossiers sauvegardés, assez anciennes, que le serveur confirme à
  /// l'instant être dans le coffre en Original, partent à la corbeille de
  /// l'ordinateur. Rien d'autre : ni documents, ni audios, ni un fichier
  /// hors des dossiers choisis, ni une suppression définitive.
  Future<void> removeSaved() => _retraitEnCours ??= _retirer().whenComplete(() => _retraitEnCours = null);

  Future<void> _retirer() async {
    final r = _reglages;
    if (_ferme || !r.removeFromPc || !r.toEngine().enabled) return;
    try {
      final candidats = await engine.freeable(r.toEngine(), olderThanDays: r.removeAfterDays);
      if (candidats.isEmpty) return;
      final confirmes = await engine.confirmInVault(candidats);
      final racines = [for (final d in r.folders) d.path.endsWith(Platform.pathSeparator) ? d.path : '${d.path}${Platform.pathSeparator}'];
      final chemins = <String, int>{};
      for (final it in confirmes) {
        if (!it.key.startsWith(kPcKeyPrefix)) continue;
        if (it.family != SafeboxFamily.photos && it.family != SafeboxFamily.videos) continue;
        final chemin = it.key.substring(kPcKeyPrefix.length);
        // Garde-fou : jamais un fichier hors des dossiers sauvegardés.
        if (!racines.any(chemin.startsWith)) continue;
        chemins[chemin] = it.size;
      }
      if (chemins.isEmpty || _ferme) return;
      final partis = await _corbeille(chemins.keys.toList());
      if (partis.isEmpty) return;
      _retrait = (
        count: partis.length,
        bytes: partis.fold(0, (s, p) => s + (chemins[p] ?? 0)),
        at: DateTime.now(),
      );
      source.forget();
      if (!_ferme) notifyListeners();
    } catch (e) {
      debugPrint('[Sauvegarde PC] retrait impossible : $e');
    }
  }

  /// Déconnexion : plus de passage, plus d'écriture (tout va être effacé).
  void close() {
    _ferme = true;
    _retraitBientot?.cancel();
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
