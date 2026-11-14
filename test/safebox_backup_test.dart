import 'dart:async';
import 'dart:io';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_backup_background.dart';

/// Lot 10 : la sauvegarde automatique, sans téléphone ni serveur.
void main() {
  late Directory dossier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dossier = await Directory.systemTemp.createTemp('coffre_sauvegarde');
  });
  tearDown(() => dossier.delete(recursive: true));

  Future<File> fichier(String nom, int taille, {int graine = 1}) async {
    final f = File('${dossier.path}/$nom');
    await f.writeAsBytes(Uint8List.fromList(List<int>.generate(taille, (i) => (i * graine) % 251)));
    return f;
  }

  group('réglages', () {
    test('par défaut : photos, vidéos, documents, Wi-Fi, charge ; aller-retour', () async {
      const d = SafeboxBackupSettings();
      expect(d.enabled, isFalse);
      expect(d.families, {SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.documents});
      expect(d.wifiOnly && d.chargingOnly, isTrue);
      expect(d.qualityOf(SafeboxFamily.documents), SafeboxQuality.original);
      final s = d.copyWith(
        enabled: true,
        galleryFolders: {'camera'},
        documentFolders: const [SafeboxDocumentFolder(uri: 'content://x', name: 'Docs')],
        since: DateTime.utc(2026, 10, 26),
        quality: {SafeboxFamily.videos: SafeboxQuality.hd, SafeboxFamily.documents: SafeboxQuality.compressed},
        wifiOnly: false,
      );
      await s.save();
      final relu = await SafeboxBackupSettings.load();
      expect(relu.enabled, isTrue);
      expect(relu.galleryFolders, {'camera'});
      expect(relu.documentFolders.single.name, 'Docs');
      expect(relu.since, DateTime.utc(2026, 10, 26));
      expect(relu.qualityOf(SafeboxFamily.videos), SafeboxQuality.hd);
      expect(relu.qualityOf(SafeboxFamily.documents), SafeboxQuality.original, reason: 'documents toujours tels quels');
      expect(relu.wifiOnly, isFalse);
      expect(relu.copyWith(clearSince: true).since, isNull);
      // 11/11/2026 : retirer du téléphone, décoché par défaut, 30 jours.
      expect([d.removeFromPhone, d.removeAfterDays], [false, 30]);
      await s.copyWith(removeFromPhone: true, removeAfterDays: 7).save();
      final retrait = await SafeboxBackupSettings.load();
      expect([retrait.removeFromPhone, retrait.removeAfterDays], [true, 7]);
    });
  });

  group('empreinte de l\'original', () {
    test('stable, et sensible au contenu, à la taille et à la fin du fichier', () async {
      final a = await fichier('a.jpg', 600 * 1024);
      final b = await fichier('b.jpg', 600 * 1024);
      final fpA = safeboxSourceFingerprintSync(a.path);
      expect(fpA, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(safeboxSourceFingerprintSync(b.path), fpA, reason: 'même contenu, même empreinte');
      // Un octet changé à la fin : une autre empreinte.
      final octets = await b.readAsBytes();
      octets[octets.length - 10] ^= 0xff;
      await b.writeAsBytes(octets);
      expect(safeboxSourceFingerprintSync(b.path), isNot(fpA));
      final petit = await fichier('p.pdf', 1000);
      expect(safeboxSourceFingerprintSync(petit.path), isNot(fpA));
      expect(await safeboxSourceFingerprint(a.path), fpA, reason: 'calculée hors du fil principal');
    });
  });

  group('estimations et formats', () {
    SafeboxDeviceItem photo(String k, int taille) => SafeboxDeviceItem(
          key: 'g:$k', name: '$k.jpg', family: SafeboxFamily.photos, size: taille, modified: DateTime(2026),
          width: 4000, height: 3000,
        );
    SafeboxDeviceItem video(String k, int taille, {double ms = 60000}) => SafeboxDeviceItem(
          key: 'g:$k', name: '$k.mp4', family: SafeboxFamily.videos, size: taille, modified: DateTime(2026),
          width: 1920, height: 1080, durationMs: ms,
        );

    test('nombre et poids par type et par format ; présélection Original si tout tient', () {
      final e = SafeboxBackupEstimate.of([photo('1', 5 << 20), photo('2', 5 << 20), video('3', 200 << 20)]);
      expect(e.countOf(SafeboxFamily.photos), 2);
      expect(e.bytesOf(SafeboxFamily.photos, SafeboxQuality.original), 10 << 20);
      expect(e.bytesOf(SafeboxFamily.videos, SafeboxQuality.hd), lessThan(200 << 20));
      expect(e.bytesOf(SafeboxFamily.photos, SafeboxQuality.compressed),
          lessThan(e.bytesOf(SafeboxFamily.photos, SafeboxQuality.hd)));
      final total = e.total((_) => SafeboxQuality.original);
      expect(safeboxBackupPreselect(e, total), SafeboxQuality.original);
      expect(safeboxBackupPreselect(e, total - 1), SafeboxQuality.hd);
    });

    test('une vidéo de plus de 1 Go en Original passe en HD', () {
      expect(safeboxBackupQualityFor(video('v', 2 << 30), SafeboxQuality.original, 1 << 30), SafeboxQuality.hd);
      expect(safeboxBackupQualityFor(video('v', 100 << 20), SafeboxQuality.original, 1 << 30), SafeboxQuality.original);
      expect(safeboxBackupQualityFor(photo('p', 2 << 30), SafeboxQuality.original, 1 << 30), SafeboxQuality.original);
    });

    test('dossiers cochés d\'office : appareil photo et WhatsApp', () {
      bool coche(String n) => SafeboxDeviceFolder(id: n, name: n, count: 1).checkedByDefault;
      expect(coche('Camera'), isTrue);
      expect(coche('WhatsApp Images'), isTrue);
      expect(coche('Screenshots'), isFalse);
      expect(coche('Download'), isFalse);
    });
  });

  group('le moteur', () {
    late _FauxTelephone tel;
    late _FauxServeur srv;
    late _Memoire store;
    late List<SafeboxBackupUpload> envoyes;
    int? libre;
    var enCharge = true;

    SafeboxBackupEngine moteur() => SafeboxBackupEngine(
          device: tel,
          api: srv,
          enqueue: (u) async {
            envoyes.add(u);
            return 'job${envoyes.length}';
          },
          freeSpace: () async => libre,
          maxFileBytes: () => 1 << 30,
          charging: () async => enCharge,
          store: store,
        );

    setUp(() {
      tel = _FauxTelephone();
      srv = _FauxServeur();
      store = _Memoire();
      envoyes = [];
      libre = 1 << 30;
      enCharge = true;
    });

    const reglages = SafeboxBackupSettings(
      enabled: true,
      families: {SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.documents},
      galleryFolders: {'camera'},
    );

    Future<SafeboxDeviceItem> ajouter(String id, String nom, SafeboxFamily f, int taille,
        {String dossierPhone = 'camera', int graine = 1, DateTime? modifie}) async {
      final file = await fichier(nom, taille, graine: graine);
      final it = SafeboxDeviceItem(
        key: 'g:$id', name: nom, family: f, size: -1, modified: modifie ?? DateTime(2026, 10, 1), folder: dossierPhone,
        width: 4000, height: 3000,
      );
      tel.ajouter(it, file, dossierPhone);
      return it;
    }

    test('déjà là, supprimé du coffre, ailleurs, neuf : seul le neuf part ; rien au passage suivant', () async {
      await ajouter('1', 'deja.jpg', SafeboxFamily.photos, 1000, graine: 1);
      await ajouter('2', 'supprimee.jpg', SafeboxFamily.photos, 1000, graine: 2);
      await ajouter('3', 'album.jpg', SafeboxFamily.photos, 1000, graine: 3);
      await ajouter('4', 'neuve.jpg', SafeboxFamily.photos, 1000, graine: 4);
      await ajouter('5', 'autre.jpg', SafeboxFamily.photos, 1000, dossierPhone: 'screenshots', graine: 5);
      Future<String> fp(String nom) => safeboxSourceFingerprint('${dossier.path}/$nom');
      srv.etats[await fp('deja.jpg')] = SafeboxBackupCheck.saved;
      srv.etats[await fp('supprimee.jpg')] = SafeboxBackupCheck.skip;
      srv.etats[await fp('album.jpg')] = SafeboxBackupCheck.elsewhere;

      final m = moteur();
      final r = await m.run(reglages);
      expect(r.seen, 4, reason: 'les captures d\'écran ne sont pas retenues');
      expect([r.alreadySaved, r.skipped, r.queued], [2, 1, 1]);
      expect(envoyes.single.item.name, 'neuve.jpg');
      expect(envoyes.single.quality, SafeboxQuality.original);
      expect(envoyes.single.fp, await fp('neuve.jpg'));
      expect(envoyes.single.item.size, 1000, reason: 'mesuré à l\'ouverture');
      expect(srv.liens, [true], reason: 'ajout sans copie à Photos demandé');
      final faits = await m.records();
      expect(faits['g:2']!.state, SafeboxBackupState.skip);
      expect(faits['g:4']!.state, SafeboxBackupState.queued);

      final r2 = await m.run(reglages);
      expect(r2.queued, 0);
      expect(srv.appels, 1, reason: 'le téléphone se souvient de ce qu\'il a vu');

      // L'envoi arrive : sauvegardé. Le fichier change sur le téléphone : revu.
      await m.markSaved('g:4');
      expect((await m.records())['g:4']!.state, SafeboxBackupState.saved);
      tel.toucher('g:4');
      await m.run(reglages);
      expect(srv.appels, 2);
    });

    test('compresser seulement pendant la charge ; espace plein', () async {
      await ajouter('1', 'v.mp4', SafeboxFamily.videos, 2000);
      final hd = reglages.copyWith(quality: {SafeboxFamily.videos: SafeboxQuality.hd});
      enCharge = false;
      final r = await moteur().run(hd);
      expect(r.waitingCharge, 1);
      expect(envoyes, isEmpty);
      expect(await moteur().records(), isEmpty, reason: 'repris au passage suivant');
      enCharge = true;
      expect((await moteur().run(hd)).queued, 1);

      await ajouter('2', 'grosse.jpg', SafeboxFamily.photos, 5000, graine: 9);
      libre = 100;
      final plein = await moteur().run(reglages);
      expect(plein.stop, SafeboxBackupStop.spaceFull);
      expect(envoyes, hasLength(1), reason: 'rien de plus');
    });

    test('place qui manque : les plus récents d\'abord, un fichier trop gros ne bloque pas les petits', () async {
      // Ajoutés dans le désordre, et dans deux dossiers du téléphone.
      await ajouter('1', 'ancienne.jpg', SafeboxFamily.photos, 1000, graine: 1, modifie: DateTime(2026, 10, 1));
      await ajouter('2', 'grosse-recente.jpg', SafeboxFamily.photos, 5000, graine: 2, modifie: DateTime(2026, 10, 9));
      await ajouter('3', 'moyenne.jpg', SafeboxFamily.photos, 1000,
          graine: 3, modifie: DateTime(2026, 10, 5), dossierPhone: 'whatsapp');
      final deuxDossiers = reglages.copyWith(galleryFolders: {'camera', 'whatsapp'});

      // De quoi loger une seule petite : la plus récente des deux.
      libre = 1500;
      final r = await moteur().run(deuxDossiers);
      expect(envoyes.map((u) => u.item.name), ['moyenne.jpg']);
      expect(r.noRoom, 2);
      expect(r.stop, SafeboxBackupStop.spaceFull);

      // De la place pour les deux petites, pas pour la grosse : les petites partent.
      envoyes.clear();
      await store.save({});
      libre = 2500;
      final r2 = await moteur().run(deuxDossiers);
      expect(envoyes.map((u) => u.item.name), ['moyenne.jpg', 'ancienne.jpg']);
      expect(r2.noRoom, 1);
      expect(r2.stop, SafeboxBackupStop.spaceFull, reason: 'la grosse ne tient toujours pas');

      // Tout tient : plus d'« espace plein ».
      envoyes.clear();
      await store.save({});
      libre = 1 << 20;
      final r3 = await moteur().run(deuxDossiers);
      expect(envoyes.map((u) => u.item.name), ['grosse-recente.jpg', 'moyenne.jpg', 'ancienne.jpg']);
      expect(r3.stop, SafeboxBackupStop.none);
    });

    test('désactivée, ou sans accès à la galerie : rien', () async {
      await ajouter('1', 'a.jpg', SafeboxFamily.photos, 10);
      expect((await moteur().run(reglages.copyWith(enabled: false))).stop, SafeboxBackupStop.disabled);
      tel.acces = SafeboxMediaAccess.denied;
      expect((await moteur().run(reglages)).stop, SafeboxBackupStop.noAccess);
      expect(envoyes, isEmpty);
    });

    test('« Libérer la mémoire » : seulement ce qui est dans le coffre en Original', () async {
      await ajouter('1', 'orig.jpg', SafeboxFamily.photos, 1000, graine: 1);
      await ajouter('2', 'hd.mp4', SafeboxFamily.videos, 1000, graine: 2);
      final m = moteur();
      await m.run(reglages.copyWith(quality: {SafeboxFamily.videos: SafeboxQuality.hd}));
      expect(await m.freeable(reglages), isEmpty, reason: 'pas encore arrivés');
      await m.markSaved('g:1');
      await m.markSaved('g:2');
      final liberables = await m.freeable(reglages);
      expect(liberables.map((i) => i.key), ['g:1']);
      expect(await m.free(liberables), {'g:1'});
    });

    // 11/11/2026 : un passage enregistrait sa copie de la liste par-dessus
    // les « arrivé » notés entre-temps (4 photos sur 5 restaient « en cours »).
    test('arrivés pendant le passage : tous notés dans le coffre, tous libérables', () async {
      for (var i = 0; i < 5; i += 1) {
        await ajouter('$i', 'p$i.jpg', SafeboxFamily.photos, 1000 + i, graine: i + 3, modifie: DateTime(2026, 11, 1, 10, i));
      }
      late SafeboxBackupEngine m;
      m = SafeboxBackupEngine(
        device: tel,
        api: srv,
        // Petite photo : l'envoi se termine avant la fin du lot.
        enqueue: (u) async {
          envoyes.add(u);
          unawaited(Future<void>.delayed(Duration.zero, () => m.markSaved(u.item.key)));
          return 'job${envoyes.length}';
        },
        freeSpace: () async => libre,
        maxFileBytes: () => 1 << 30,
        charging: () async => true,
        jobAlive: (_) async => false,
        store: store,
        batchSize: 2,
      );
      await m.run(reglages);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final faits = await m.records();
      expect(faits.values.map((r) => r.state).toSet(), {SafeboxBackupState.saved});
      expect(faits.length, 5);
      expect((await m.freeable(reglages)).length, 5);
      envoyes.clear();
      await m.run(reglages);
      expect(envoyes, isEmpty, reason: 'rien ne repart');
    });

    test('envoi perdu ou en échec : relancé, l\'ancien retiré, 3 essais au plus', () async {
      await ajouter('1', 'a.jpg', SafeboxFamily.photos, 1000);
      final vivants = <String>{};
      final retires = <String>[];
      SafeboxBackupEngine m2() => SafeboxBackupEngine(
            device: tel,
            api: srv,
            enqueue: (u) async {
              envoyes.add(u);
              final id = 'job${envoyes.length}';
              vivants.add(id);
              return id;
            },
            freeSpace: () async => libre,
            maxFileBytes: () => 1 << 30,
            charging: () async => true,
            jobAlive: (id) async => vivants.contains(id),
            discardJob: (id) async => retires.add(id),
            store: store,
          );
      await m2().run(reglages);
      expect(envoyes.length, 1);
      // Encore en route : rien ne repart.
      await m2().run(reglages);
      expect(envoyes.length, 1);
      // En échec : relancé, l'ancien envoi retiré.
      vivants.clear();
      await m2().run(reglages);
      expect(envoyes.length, 2);
      expect(retires, ['job1']);
      expect((await m2().pending(reglages)), isEmpty, reason: 'job2 en route');
      vivants.clear();
      await m2().run(reglages);
      expect(envoyes.length, 3);
      expect((await store.load())['g:1']!.attempts, 3);
      vivants.clear();
      await m2().run(reglages);
      expect(envoyes.length, 3, reason: 'trois essais : il attend qu\'il change');
      expect(await m2().pending(reglages), isEmpty);
      // Arrivé quand même (relancé à la main) : noté dans le coffre.
      await m2().markSaved('g:1');
      expect((await store.load())['g:1']!.state, SafeboxBackupState.saved);
    });

    // 11/11/2026 : la barre de l'accueil et de la notification.
    test('progression : sur tous les fichiers retenus, elle ne recule jamais', () async {
      await ajouter('1', 'deja.jpg', SafeboxFamily.photos, 1000, graine: 1);
      await ajouter('2', 'a.jpg', SafeboxFamily.photos, 1000, graine: 2);
      await ajouter('3', 'b.jpg', SafeboxFamily.photos, 1000, graine: 3);
      srv.etats[await safeboxSourceFingerprint('${dossier.path}/deja.jpg')] = SafeboxBackupCheck.saved;
      final m = moteur();
      expect(m.progress.value, isNull, reason: 'rien avant le premier passage');
      final vus = <SafeboxBackupProgress>[];
      m.progress.addListener(() => vus.add(m.progress.value!));
      await m.run(reglages);
      expect(vus.first.listing, isTrue, reason: 'd\'abord la recherche des fichiers');
      expect(vus.any((p) => p.analysing && p.toCheck == 3), isTrue);
      final fin = m.progress.value!;
      expect([fin.total, fin.done, fin.remaining], [3, 1, 2]);
      expect(fin.listing || fin.analysing, isFalse);
      expect(fin.complete, isFalse);
      final faits = [for (final p in vus.where((p) => !p.listing)) p.done];
      for (var i = 1; i < faits.length; i += 1) {
        expect(faits[i], greaterThanOrEqualTo(faits[i - 1]));
      }
      await m.markSaved('g:2');
      await m.markSaved('g:2');
      expect(m.progress.value!.done, 2, reason: 'compté une seule fois');
      await m.markSaved('g:3');
      expect(m.progress.value!.complete, isTrue);
      expect((await m.run(reglages.copyWith(enabled: false))).stop, SafeboxBackupStop.disabled);
      expect(m.progress.value, isNull);
    });

    test('fichier illisible : hors du compte, la barre va au bout ; lisible, il revient', () async {
      await ajouter('1', 'a.jpg', SafeboxFamily.photos, 1000, graine: 1);
      await ajouter('2', 'cloud.jpg', SafeboxFamily.photos, 1000, graine: 2);
      tel.illisibles.add('g:2');
      final m = moteur();
      await m.run(reglages);
      expect([m.progress.value!.total, m.progress.value!.unreadable], [1, 1]);
      await m.markSaved('g:1');
      expect(m.progress.value!.complete, isTrue, reason: 'l\'illisible ne bloque plus la fin');
      // Au passage suivant, toujours illisible : la barre ne recule pas.
      await m.run(reglages);
      expect(m.progress.value!.complete, isTrue);
      tel.illisibles.clear();
      await m.run(reglages);
      expect([m.progress.value!.total, m.progress.value!.unreadable, m.progress.value!.remaining], [2, 0, 1]);
      expect(envoyes.map((u) => u.item.name), ['a.jpg', 'cloud.jpg']);
    });

    // 11/11/2026 : retirer du téléphone ce qui est sauvegardé.
    test('à retirer : en Original, plus vieux que le délai, et encore dans le coffre', () async {
      final maintenant = DateTime(2026, 11, 11);
      await ajouter('1', 'vieille.jpg', SafeboxFamily.photos, 1000, graine: 1, modifie: DateTime(2026, 9, 1));
      await ajouter('2', 'recente.jpg', SafeboxFamily.photos, 1000, graine: 2, modifie: DateTime(2026, 11, 9));
      await ajouter('3', 'hd.mp4', SafeboxFamily.videos, 1000, graine: 3, modifie: DateTime(2026, 9, 1));
      await ajouter('4', 'ancienne-appli.jpg', SafeboxFamily.photos, 1000, graine: 4, modifie: DateTime(2026, 9, 1));
      await ajouter('5', 'corbeille-coffre.jpg', SafeboxFamily.photos, 1000, graine: 5, modifie: DateTime(2026, 9, 1));
      Future<String> fp(String nom) => safeboxSourceFingerprint('${dossier.path}/$nom');
      // Déjà dans le coffre : le serveur dit en quelle qualité.
      for (final n in ['vieille.jpg', 'recente.jpg', 'corbeille-coffre.jpg']) {
        srv.etats[await fp(n)] = SafeboxBackupCheck.saved;
        srv.originaux[await fp(n)] = true;
      }
      srv.etats[await fp('hd.mp4')] = SafeboxBackupCheck.saved;
      srv.originaux[await fp('hd.mp4')] = false;
      srv.etats[await fp('ancienne-appli.jpg')] = SafeboxBackupCheck.saved; // qualité inconnue
      final m = moteur();
      await m.run(reglages);
      final faits = await m.records();
      expect(faits['g:1']!.quality, SafeboxQuality.original, reason: 'qualité dite par le serveur');
      expect(faits['g:3']!.quality, SafeboxQuality.hd);
      expect(faits['g:4']!.quality, isNull);

      final candidats = await m.freeable(reglages, olderThanDays: 30, now: maintenant);
      expect(candidats.map((i) => i.key), unorderedEquals(['g:1', 'g:4', 'g:5']),
          reason: 'la récente reste, la HD reste, l\'inconnue attend le serveur');
      expect(candidats.firstWhere((i) => i.key == 'g:1').size, 1000, reason: 'taille de la fiche');
      expect((await m.freeable(reglages, now: maintenant)).length, 4, reason: 'tout de suite : la récente aussi');

      // Juste avant : mise à la corbeille du coffre entre-temps, qualité toujours inconnue.
      srv.etats[await fp('corbeille-coffre.jpg')] = SafeboxBackupCheck.skip;
      expect((await m.confirmInVault(candidats)).map((i) => i.key), ['g:1']);
      expect(srv.liens.last, isFalse, reason: 'vérifier sans rien ajouter au coffre');
      expect((await m.records())['g:5']!.state, SafeboxBackupState.skip);
      // Le serveur apprend la qualité de l'inconnue : notée.
      srv.originaux[await fp('ancienne-appli.jpg')] = true;
      expect((await m.confirmInVault(candidats)).map((i) => i.key), unorderedEquals(['g:1', 'g:4']));
      expect((await m.records())['g:4']!.quality, SafeboxQuality.original);
      // Vers la corbeille du téléphone.
      expect(await m.free([candidats.first]), {'g:1'});
    });

    test('dossier de documents illisible : les photos partent quand même', () async {
      await ajouter('1', 'a.jpg', SafeboxFamily.photos, 1000);
      tel.erreurDocuments = MissingPluginException('tâche de fond');
      final r = await moteur().run(reglages.copyWith(
        documentFolders: const [SafeboxDocumentFolder(uri: 'content://x', name: 'Factures')],
      ));
      expect(r.queued, 1);
      expect(envoyes.single.item.name, 'a.jpg');
    });
  });

  group('l\'application et la tâche de fond n\'envoient jamais en même temps', () {
    test('présence fraîche, puis périmée, puis retirée', () async {
      expect(await SafeboxRunLock.held(SafeboxRunLock.app), isFalse);
      await SafeboxRunLock.beat(SafeboxRunLock.app);
      expect(await SafeboxRunLock.held(SafeboxRunLock.app), isTrue);
      expect(await SafeboxRunLock.held(SafeboxRunLock.app, now: DateTime.now().add(const Duration(minutes: 3))), isFalse);
      await SafeboxRunLock.release(SafeboxRunLock.app);
      expect(await SafeboxRunLock.held(SafeboxRunLock.app), isFalse);
      expect(await SafeboxRunLock.held(SafeboxRunLock.background), isFalse);
    });
  });
}

class _FauxTelephone implements SafeboxDeviceSource {
  SafeboxMediaAccess acces = SafeboxMediaAccess.full;
  final List<({SafeboxDeviceItem item, File file, String folder})> _elements = [];

  void ajouter(SafeboxDeviceItem it, File f, String folder) => _elements.add((item: it, file: f, folder: folder));

  /// Le fichier change sur le téléphone : nouvelle date.
  void toucher(String key) {
    final i = _elements.indexWhere((e) => e.item.key == key);
    final e = _elements[i];
    _elements[i] = (
      item: SafeboxDeviceItem(
        key: e.item.key, name: e.item.name, family: e.item.family, size: -1,
        modified: e.item.modified.add(const Duration(minutes: 1)), folder: e.item.folder,
      ),
      file: e.file,
      folder: e.folder,
    );
  }

  @override
  Future<SafeboxMediaAccess> access() async => acces;
  @override
  Future<SafeboxMediaAccess> requestAccess() async => acces;
  @override
  Future<List<SafeboxDeviceFolder>> galleryFolders() async => const [
        SafeboxDeviceFolder(id: 'camera', name: 'Camera', count: 4),
        SafeboxDeviceFolder(id: 'screenshots', name: 'Screenshots', count: 1),
      ];

  @override
  Future<List<SafeboxDeviceItem>> galleryItems({
    required Set<String> folderIds,
    required Set<SafeboxFamily> families,
    DateTime? since,
    bool withSizes = false,
  }) async =>
      [
        for (final e in _elements)
          if (folderIds.contains(e.folder) && families.contains(e.item.family))
            withSizes ? e.item.withSize(await e.file.length()) : e.item,
      ];

  @override
  Future<SafeboxDocumentFolder?> pickDocumentFolder() async => null;
  /// Le canal des documents absent (tâche de fond) ou un droit retiré.
  Object? erreurDocuments;

  @override
  Future<List<SafeboxDeviceItem>> documentItems(SafeboxDocumentFolder folder, {DateTime? since}) async {
    if (erreurDocuments != null) throw erreurDocuments!;
    return const [];
  }
  /// Illisibles (dans le cloud, supprimés entre-temps).
  final Set<String> illisibles = {};

  @override
  Future<File?> open(SafeboxDeviceItem item) async =>
      illisibles.contains(item.key) ? null : _elements.firstWhere((e) => e.item.key == item.key).file;
  @override
  Future<Set<String>> delete(List<SafeboxDeviceItem> items) async => {for (final i in items) i.key};

  @override
  Future<Set<String>> trashMedia(List<String> mediaIds) async => mediaIds.toSet();
  @override
  Future<({int free, int total})?> storage() async => (free: 1 << 30, total: 64 << 30);
}

class _FauxServeur implements SafeboxBackupApi {
  final Map<String, SafeboxBackupCheck> etats = {};

  /// Copie du coffre en Original ; absente : serveur d'avant le 11/11/2026.
  final Map<String, bool> originaux = {};
  final List<bool> liens = [];
  int appels = 0;

  @override
  Future<Map<String, SafeboxBackupStatus>> check(List<String> fps, {bool link = true}) async {
    appels += 1;
    liens.add(link);
    return {
      for (final fp in fps) fp: SafeboxBackupStatus(etats[fp] ?? SafeboxBackupCheck.unknown, original: originaux[fp]),
    };
  }

  @override
  Future<void> skip(List<String> fps) async {}
}

class _Memoire implements SafeboxBackupStore {
  Map<String, SafeboxBackupRecord> faits = {};
  @override
  Future<Map<String, SafeboxBackupRecord>> load() async => Map.of(faits);
  @override
  Future<void> save(Map<String, SafeboxBackupRecord> records) async => faits = Map.of(records);
}
