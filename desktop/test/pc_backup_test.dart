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
  @override
  Future<Map<String, SafeboxBackupStatus>> check(List<String> fps, {bool link = true}) async => {
        for (final fp in fps) fp: SafeboxBackupStatus(etats[fp] ?? SafeboxBackupCheck.unknown),
      };
  @override
  Future<void> skip(List<String> fps) async {}
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

  File ecrire(String chemin, String contenu) => File('${tmp.path}/$chemin')
    ..createSync(recursive: true)
    ..writeAsStringSync(contenu);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('coffre_sauvegarde');
    api = _Api();
    confies = [];
    reglages = const PcBackupSettings();
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
