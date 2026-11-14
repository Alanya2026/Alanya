import 'dart:io';

import 'package:alanya_coffre/core/pc_backup.dart';
import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';

final _limites = SafeboxLimits.fromJson({
  'maxFileBytes': 1 << 30,
  'blockBytes': 8 << 20,
  'maxPreviewBytes': 256 * 1024,
  'maxDepth': 8,
  'maxFolders': 1000,
  'folderNameMax': 80,
  'fileNameMax': 120,
  'extensions': {
    'photos': ['jpg'],
    'videos': ['mp4'],
    'audios': ['mp3'],
  },
});

/// Le serveur : empreinte → état ; tout le reste est neuf.
class _Api implements SafeboxBackupApi {
  final etats = <String, SafeboxBackupCheck>{};

  /// Empreintes gardées en Original dans le coffre (les autres : en HD).
  final originaux = <String>{};
  @override
  Future<Map<String, SafeboxBackupStatus>> check(List<String> fps, {bool link = true}) async => {
        for (final fp in fps)
          fp: SafeboxBackupStatus(etats[fp] ?? SafeboxBackupCheck.unknown, original: originaux.contains(fp)),
      };
  @override
  Future<void> skip(List<String> fps) async {}
}

/// Le coffre côté dossiers : Albums = 5 ; un fichier par empreinte.
class _Coffre with SafeboxCalls {
  final fichiers = <String, int>{};
  final crees = <(int parent, String nom, int id)>[];
  final ajouts = <int, List<int>>{};
  final renommes = <(int, String)>[];
  var _prochain = 100;

  @override
  SafeboxHttp get safeboxHttp => throw UnimplementedError();

  @override
  Future<Map<String, ({String state, int? fileId})>> checkSafeboxSources(List<String> fps, {bool link = false}) async => {
        for (final fp in fps) fp: fichiers[fp] == null ? (state: 'new', fileId: null) : (state: 'saved', fileId: fichiers[fp]),
      };

  @override
  Future<SafeboxFolderPage> fetchSafeboxFolder(int folderId, {int? cursor}) async => SafeboxFolderPage(
        folder: SafeboxFolder(id: folderId, parentId: null, root: SafeboxRoot.albums, name: null, depth: 0),
        breadcrumbs: const [],
        folders: [
          for (final c in crees.where((c) => c.$1 == folderId))
            SafeboxFolder(id: c.$3, parentId: folderId, root: SafeboxRoot.albums, name: c.$2, depth: 1),
        ],
        files: const [],
        nextCursor: null,
      );

  @override
  Future<SafeboxFolder> createSafeboxFolder({required int parentId, required String name}) async {
    final id = _prochain++;
    crees.add((parentId, name, id));
    return SafeboxFolder(id: id, parentId: parentId, root: SafeboxRoot.albums, name: name, depth: 1);
  }

  @override
  Future<List<SafeboxFile>> addSafeboxFilesToFolder(int folderId, List<int> fileIds) async {
    ajouts.putIfAbsent(folderId, () => []).addAll(fileIds);
    return const [];
  }

  @override
  Future<SafeboxFolder> updateSafeboxFolder(int folderId, {String? name, int? parentId}) async {
    renommes.add((folderId, name!));
    return SafeboxFolder(id: folderId, parentId: 5, root: SafeboxRoot.albums, name: name, depth: 1);
  }
}

class _Fiches implements SafeboxBackupStore {
  Map<String, SafeboxBackupRecord> fiches = {};
  @override
  Future<Map<String, SafeboxBackupRecord>> load() async => Map.of(fiches);
  @override
  Future<void> save(Map<String, SafeboxBackupRecord> records) async => fiches = Map.of(records);
}

void main() {
  late Directory tmp;
  late _Api api;
  late List<SafeboxBackupUpload> confies;
  late PcBackup sauvegarde;
  late PcBackupSettings reglages;
  late List<String> corbeille;
  late _Coffre coffre;

  File ecrire(String chemin, String contenu) => File('${tmp.path}/$chemin')
    ..createSync(recursive: true)
    ..writeAsStringSync(contenu);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('coffre_sauvegarde');
    api = _Api();
    confies = [];
    reglages = const PcBackupSettings();
    corbeille = [];
    coffre = _Coffre();
    var ranges = <String, String>{};
    sauvegarde = PcBackup(
      api: api,
      enqueue: (u) async {
        confies.add(u);
        return 'job${confies.length}';
      },
      freeSpace: () async => 1 << 30,
      limits: () => _limites,
      jobAlive: (_) async => true,
      discardJob: (_) async {},
      refreshOverview: () async {},
      store: _Fiches(),
      loadSettings: () async => reglages,
      saveSettings: (s) async => reglages = s,
      // La corbeille de l'ordinateur, simulée : le fichier quitte sa place.
      computerTrash: (chemins) async {
        corbeille.addAll(chemins);
        for (final c in chemins) {
          File(c).deleteSync();
        }
        return chemins.toSet();
      },
      calls: coffre,
      albumsRoot: () => 5,
      loadPlaced: () async => Map.of(ranges),
      savePlaced: (r) async => ranges = Map.of(r),
      // Pas de passage automatique pendant les tests.
      period: const Duration(days: 1),
      settle: const Duration(days: 1),
    );
  });

  tearDown(() {
    sauvegarde.dispose();
    tmp.deleteSync(recursive: true);
  });

  PcBackupFolder dossier(String nom, Set<SafeboxFamily> types) =>
      PcBackupFolder(path: '${tmp.path}/$nom', name: nom, families: types);

  test('un passage ne supprime AUCUN fichier du PC, quel que soit l’état dans le coffre', () async {
    final fichiers = [
      ecrire('Images/neuve.jpg', 'neuve'),
      ecrire('Images/deja.jpg', 'deja'),
      ecrire('Images/supprimee.jpg', 'supprimee'),
      ecrire('Images/en-cours.jpg', 'en-cours'),
      ecrire('Documents/facture.pdf', 'facture'),
      ecrire('Documents/contrat.pdf', 'contrat'),
    ];
    final fp = {for (final f in fichiers) f.path.split('/').last: safeboxSourceFingerprintSync(f.path)};
    api.etats[fp['deja.jpg']!] = SafeboxBackupCheck.saved;
    api.etats[fp['supprimee.jpg']!] = SafeboxBackupCheck.skip;
    api.etats[fp['en-cours.jpg']!] = SafeboxBackupCheck.uploading;
    api.etats[fp['contrat.pdf']!] = SafeboxBackupCheck.elsewhere;

    await sauvegarde.update(PcBackupSettings(enabled: true, folders: [
      dossier('Images', {SafeboxFamily.photos}),
      dossier('Documents', {SafeboxFamily.documents}),
    ]));
    // Activer lance le premier passage.
    await sauvegarde.idle;

    for (final f in fichiers) {
      expect(f.existsSync(), isTrue, reason: '${f.path} a disparu');
    }
    expect(confies.map((u) => u.item.name).toSet(), {'neuve.jpg', 'facture.pdf'});
    for (final u in confies) {
      expect(u.item.key, startsWith(kPcKeyPrefix));
      expect(u.quality, SafeboxQuality.original);
      expect(u.file.path, u.item.key.substring(kPcKeyPrefix.length)); // le vrai fichier, pas une copie
    }
    expect(confies.firstWhere((u) => u.item.name == 'neuve.jpg').item.folder, 'Images');
    final r = sauvegarde.lastReport!;
    expect((r.queued, r.alreadySaved, r.skipped), (2, 2, 1));
  });

  test('chaque dossier n’envoie que ses types ; cachés et vides laissés de côté', () async {
    ecrire('Mix/photo.jpg', 'p');
    ecrire('Mix/film.mp4', 'f');
    ecrire('Mix/sous/note.pdf', 'n');
    ecrire('Mix/.cache/x.jpg', 'x');
    ecrire('Mix/.cachee.jpg', 'c');
    ecrire('Mix/vide.jpg', '');
    ecrire('Mix/desktop.ini', 'w');

    await sauvegarde.update(PcBackupSettings(enabled: true, folders: [
      dossier('Mix', {SafeboxFamily.photos, SafeboxFamily.documents}),
    ]));
    await sauvegarde.runNow();

    expect(confies.map((u) => u.item.name).toSet(), {'photo.jpg', 'note.pdf'});
  });

  test('un fichier inchangé ne repart pas ; modifié, il repart', () async {
    final f = ecrire('Images/a.jpg', 'version 1');
    await sauvegarde.update(PcBackupSettings(enabled: true, folders: [dossier('Images', {SafeboxFamily.photos})]));
    await sauvegarde.runNow();
    await sauvegarde.markSaved('$kPcKeyPrefix${f.path}');
    await sauvegarde.runNow();
    expect(confies, hasLength(1));

    f.writeAsStringSync('version 2, plus longue');
    await sauvegarde.runNow();
    expect(confies, hasLength(2));
  });

  /// Sauvegarde [fichiers] puis les marque arrivés ; le serveur les dit
  /// dans le coffre, en Original sauf [enHd].
  Future<void> sauvegarder(List<File> fichiers, {Set<File> enHd = const {}}) async {
    await sauvegarde.idle;
    for (final f in fichiers) {
      final fp = safeboxSourceFingerprintSync(f.path);
      api.etats[fp] = SafeboxBackupCheck.saved;
      if (!enHd.contains(f)) api.originaux.add(fp);
      await sauvegarde.markSaved('$kPcKeyPrefix${f.path}');
    }
  }

  test('retirer de l’ordinateur : seulement photos et vidéos confirmées en Original', () async {
    final photo = ecrire('Images/photo.jpg', 'photo');
    final film = ecrire('Images/film.mp4', 'film');
    final hd = ecrire('Images/hd.jpg', 'hd');
    final doc = ecrire('Images/facture.pdf', 'facture');
    final supprimee = ecrire('Images/supprimee.jpg', 'supprimee');
    await sauvegarde.update(PcBackupSettings(
      enabled: true,
      removeFromPc: true,
      removeAfterDays: 0,
      folders: [dossier('Images', {SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.documents})],
    ));
    await sauvegarder([photo, film, hd, doc, supprimee], enHd: {hd});
    // Supprimée du coffre entre-temps : elle reste sur l'ordinateur.
    api.etats[safeboxSourceFingerprintSync(supprimee.path)] = SafeboxBackupCheck.skip;

    await sauvegarde.removeSaved();

    expect(corbeille.toSet(), {photo.path, film.path});
    expect([hd, doc, supprimee].every((f) => f.existsSync()), isTrue);
    expect(sauvegarde.lastRemoval!.count, 2);
  });

  test('option décochée, ou fichiers trop récents : rien ne quitte l’ordinateur', () async {
    final photo = ecrire('Images/photo.jpg', 'photo');
    await sauvegarde.update(PcBackupSettings(enabled: true, folders: [dossier('Images', {SafeboxFamily.photos})]));
    await sauvegarder([photo]);
    await sauvegarde.removeSaved();
    expect(corbeille, isEmpty);

    // « Après 30 jours » : une photo modifiée aujourd'hui reste.
    await sauvegarde.update(reglages.copyWith(removeFromPc: true, removeAfterDays: 30));
    await sauvegarde.idle;
    await sauvegarde.removeSaved();
    expect(corbeille, isEmpty);

    // Vieille de 40 jours : au passage suivant, le serveur la confirme dans
    // le coffre en Original, et elle part.
    photo.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 40)));
    await sauvegarde.runNow();
    expect(corbeille, [photo.path]);
  });

  test('le dossier du PC est recréé dans Albums, sous-dossiers compris, sans copie', () async {
    final a = ecrire('Images/a.jpg', 'a');
    final b = ecrire('Images/Vacances/b.jpg', 'b');
    final c = ecrire('Images/Vacances/c.pdf', 'c');
    // Venue du téléphone : déjà dans le coffre, elle ne repart pas mais
    // rejoint l'album.
    final tel = ecrire('Images/Vacances/telephone.jpg', 'tel');
    final fpTel = safeboxSourceFingerprintSync(tel.path);
    api.etats[fpTel] = SafeboxBackupCheck.saved;
    coffre.fichiers[fpTel] = 40;

    await sauvegarde.update(PcBackupSettings(
      enabled: true,
      folders: [dossier('Images', {SafeboxFamily.photos, SafeboxFamily.documents})],
    ));
    await sauvegarde.idle;
    expect(confies.map((u) => u.item.name).toSet(), {'a.jpg', 'b.jpg', 'c.pdf'});
    // Les envois arrivent : chacun a son fichier dans le coffre.
    for (final (f, id) in [(a, 41), (b, 42), (c, 43)]) {
      coffre.fichiers[safeboxSourceFingerprintSync(f.path)] = id;
    }
    await sauvegarder([a, b, c]);
    await sauvegarde.placeInAlbums();

    expect([for (final x in coffre.crees) (x.$1, x.$2)], [(5, 'Images'), (100, 'Vacances')]);
    expect(coffre.ajouts[100], [41]);
    expect(coffre.ajouts[101]!.toSet(), {40, 42, 43});
    expect(confies.where((u) => u.item.name == 'telephone.jpg'), isEmpty);

    // Déjà rangés : rien de plus (un fichier retiré de l'album n'y revient pas).
    coffre.ajouts.clear();
    await sauvegarde.placeInAlbums();
    expect(coffre.ajouts, isEmpty);
  });

  test('renommer un dossier sauvegardé renomme son album ; le chemin ne change pas', () async {
    final a = ecrire('Images/a.jpg', 'a');
    await sauvegarde.update(PcBackupSettings(enabled: true, folders: [dossier('Images', {SafeboxFamily.photos})]));
    await sauvegarde.idle;
    coffre.fichiers[safeboxSourceFingerprintSync(a.path)] = 41;
    await sauvegarder([a]);
    await sauvegarde.placeInAlbums();

    await sauvegarde.renameFolder(reglages.folders.single, 'PC du bureau');
    expect(coffre.renommes, [(100, 'PC du bureau')]);
    expect(reglages.folders.single.name, 'PC du bureau');
    expect(reglages.folders.single.path, '${tmp.path}/Images');
    await sauvegarde.idle;
  });

  test('désactivée : aucun passage', () async {
    ecrire('Images/a.jpg', 'a');
    await sauvegarde.update(PcBackupSettings(enabled: false, folders: [dossier('Images', {SafeboxFamily.photos})]));
    await sauvegarde.runNow();
    expect(confies, isEmpty);
  });

  test('l’estimation compte les fichiers des types retenus', () async {
    ecrire('Images/a.jpg', '12345');
    ecrire('Images/b.mp4', '1234567890');
    ecrire('Images/c.pdf', '1');
    final e = await sauvegarde.estimate(dossier('Images', {SafeboxFamily.photos, SafeboxFamily.videos}));
    expect((e.count, e.totalBytes), (2, 15));
  });
}
