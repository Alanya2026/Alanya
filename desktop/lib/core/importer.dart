// Ajouter des fichiers et des dossiers du PC au coffre (lot D4).
//
// Conception : coffre-bureau.html, section 04.
//  - En Original seulement : un fichier part tel quel.
//  - Un dossier déposé dans Albums ou Partager y est recréé avec ses
//    sous-dossiers. Déposé dans Photos, Vidéos, Audios ou Documents, ses
//    fichiers partent chacun dans la racine de son type, et le nom du dossier
//    devient leur dossier d'origine (filtre de Photos et Vidéos).
//  - Pas de doublon : l'empreinte de l'original (SBF1) est la même que sur le
//    téléphone. Ce qui est déjà dans le coffre ne repart pas ; dans un album,
//    il y est ajouté sans copie.

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';

/// Un fichier du PC retenu pour le coffre.
class ImportCandidate {
  ImportCandidate({
    required this.path,
    required this.name,
    required this.size,
    required this.family,
    this.folderId,
    this.folderPath = const [],
    this.source,
  });

  final String path;
  final String name;
  final int size;
  final SafeboxFamily family;

  /// Dossier d'arrivée déjà connu (racines d'un type).
  final int? folderId;

  /// Sinon : sous-dossiers à recréer sous la cible (Albums, Partager), du
  /// plus haut au plus bas ; vide = la cible elle-même.
  final List<String> folderPath;

  /// Le dossier du PC d'où il vient (filtre « dossier d'origine »).
  final String? source;

  /// Empreinte de l'original ; null si le fichier n'a pas pu être lu.
  String? fp;

  /// Déjà dans le coffre : le fichier à ajouter sans copie à l'album.
  int? existingFileId;
}

/// Ce que l'ajout va faire, montré avant de commencer.
class ImportPlan {
  ImportPlan({required this.target, required this.freeBytes});

  final SafeboxFolder target;

  /// Place libre dans le coffre au moment de l'analyse.
  final int freeBytes;

  /// À envoyer.
  final List<ImportCandidate> send = [];

  /// Déjà dans le coffre, ajoutés sans copie à l'album.
  final List<ImportCandidate> link = [];

  /// Déjà dans le coffre : rien à faire.
  int already = 0;

  /// Plus lourds que la limite d'un fichier.
  final List<ImportCandidate> tooLarge = [];

  /// Fichiers cachés, vides ou liens, laissés de côté.
  int ignored = 0;

  /// Fichiers partis dans la racine de leur type plutôt que dans la cible.
  final Map<SafeboxRoot, int> diverted = {};

  int get sendBytes => send.fold(0, (s, c) => s + safeboxEncryptedLength(c.size));
  bool get fits => sendBytes <= freeBytes;
  bool get isEmpty => send.isEmpty && link.isEmpty;
}

/// Ce que fait l'importeur en ce moment (barre en bas de la fenêtre).
enum ImportStep { scanning, checking, preparing }

class ImportProgress {
  ImportProgress(this.step, {this.done = 0, this.total = 0});
  final ImportStep step;
  int done;
  int total;
}

/// L'aperçu d'une photo et ses dimensions.
typedef PhotoPreview = ({Uint8List? jpeg, int? width, int? height});

class Importer extends ChangeNotifier {
  Importer({
    required this.api,
    required this.enqueue,
    required this.workDir,
    required this.photoPreview,
    Future<List<String?>> Function(List<String> paths)? fingerprints,
  }) : _empreintes = fingerprints ?? _empreintesIsolat;

  final SafeboxCalls api;

  /// Confie un envoi au gestionnaire (SafeboxUploadManager.enqueue).
  final Future<void> Function(SafeboxUploadJob job, Uint8List key) enqueue;

  /// Où écrire les aperçus chiffrés en attendant leur envoi.
  final Future<Directory> Function() workDir;
  final Future<PhotoPreview> Function(String path) photoPreview;
  final Future<List<String?>> Function(List<String> paths) _empreintes;

  ImportProgress? _progres;
  ImportProgress? get progress => _progres;
  bool get busy => _progres != null;

  void _etape(ImportProgress? p) {
    _progres = p;
    notifyListeners();
  }

  void _avance(int done) {
    _progres?.done = done;
    notifyListeners();
  }

  // ── 1. Analyse ──────────────────────────────────────────────────────────

  /// Parcourt ce que l'inscrit a choisi ou déposé, calcule les empreintes et
  /// demande au coffre ce qu'il a déjà. Rien n'est envoyé.
  Future<ImportPlan> plan(List<String> paths, SafeboxFolder target, SafeboxOverview overview) async {
    try {
      _etape(ImportProgress(ImportStep.scanning));
      final limits = overview.limits;
      final plan = ImportPlan(
        target: target,
        freeBytes: (overview.quota.quotaBytes - overview.quota.usedBytes).clamp(0, 1 << 62),
      );
      final retenus = <ImportCandidate>[];
      final ouvert = target.root.family == null;

      void ajouter(File f, String nom, int taille, List<String> chemin) {
        final famille = limits.familyOf(nom);
        final ImportCandidate c;
        if (ouvert) {
          c = ImportCandidate(path: f.path, name: nom, size: taille, family: famille, folderPath: chemin);
        } else {
          final ici = target.root.accepts(famille);
          final racine = famille.root;
          final dossier = ici ? target.id : overview.rootIds[racine];
          if (dossier == null) {
            plan.ignored += 1;
            return;
          }
          if (!ici) plan.diverted[racine] = (plan.diverted[racine] ?? 0) + 1;
          c = ImportCandidate(
            path: f.path,
            name: nom,
            size: taille,
            family: famille,
            folderId: dossier,
            source: chemin.isEmpty ? null : chemin.first,
          );
        }
        if (limits.maxFileBytes > 0 && taille > limits.maxFileBytes) {
          plan.tooLarge.add(c);
        } else {
          retenus.add(c);
        }
        _avance(retenus.length + plan.tooLarge.length);
      }

      Future<void> parcourir(Directory d, List<String> chemin) async {
        final entrees = <FileSystemEntity>[];
        try {
          await for (final e in d.list(followLinks: false)) {
            entrees.add(e);
          }
        } catch (_) {
          plan.ignored += 1; // dossier illisible
          return;
        }
        // Les fichiers d'abord, puis les sous-dossiers, par nom sans casse.
        entrees.sort((a, b) {
          final da = a is Directory ? 1 : 0;
          final db = b is Directory ? 1 : 0;
          return da != db ? da - db : a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
        for (final e in entrees) {
          final nom = _nom(e.path);
          if (nom.startsWith('.')) {
            plan.ignored += 1;
            continue;
          }
          if (e is Directory) {
            await parcourir(e, [...chemin, nom]);
          } else if (e is File) {
            final taille = await _taille(e);
            if (taille <= 0) {
              plan.ignored += 1;
            } else {
              ajouter(e, nom, taille, chemin);
            }
          } else {
            plan.ignored += 1; // lien
          }
        }
      }

      for (final p in paths) {
        final type = await FileSystemEntity.type(p, followLinks: false);
        final nom = _nom(p);
        if (type == FileSystemEntityType.directory) {
          await parcourir(Directory(p), [nom]);
        } else if (type == FileSystemEntityType.file && !nom.startsWith('.')) {
          final taille = await _taille(File(p));
          if (taille <= 0) {
            plan.ignored += 1;
          } else {
            ajouter(File(p), nom, taille, const []);
          }
        } else {
          plan.ignored += 1;
        }
      }

      // Empreintes, par paquets pour montrer l'avancement.
      _etape(ImportProgress(ImportStep.checking, total: retenus.length));
      const paquet = 50;
      for (var i = 0; i < retenus.length; i += paquet) {
        final morceau = retenus.sublist(i, (i + paquet).clamp(0, retenus.length));
        final fps = await _empreintes([for (final c in morceau) c.path]);
        for (var j = 0; j < morceau.length; j += 1) {
          morceau[j].fp = fps[j];
        }
        _avance(i + morceau.length);
      }

      await _trier(plan, retenus);
      return plan;
    } finally {
      _etape(null);
    }
  }

  /// Répartit entre « à envoyer », « ajouté sans copie » et « déjà là ».
  Future<void> _trier(ImportPlan plan, List<ImportCandidate> retenus) async {
    final racine = plan.target.root;
    // Deux fois le même contenu dans un même dossier d'arrivée : une seule fois.
    final vus = <String>{};
    final uniques = <ImportCandidate>[];
    for (final c in retenus) {
      final cle = '${c.fp ?? c.path}|${c.folderId}|${c.folderPath.join('/')}';
      if (vus.add(cle)) {
        uniques.add(c);
      } else {
        plan.already += 1;
      }
    }
    // Partager reçoit ce qu'on y dépose, déjà dans le coffre ou non.
    final aVerifier = racine == SafeboxRoot.partager ? const <ImportCandidate>[] : uniques.where((c) => c.fp != null).toList();
    final etats = <String, ({String state, int? fileId})>{};
    final fps = aVerifier.map((c) => c.fp!).toSet().toList();
    for (var i = 0; i < fps.length; i += 500) {
      try {
        // Racine d'un type : ce qui n'est que dans un album y est ajouté sans
        // copie par le serveur (link), et compte comme déjà là.
        etats.addAll(await api.checkSafeboxSources(fps.sublist(i, (i + 500).clamp(0, fps.length)),
            link: racine != SafeboxRoot.albums));
      } catch (e) {
        debugPrint('[Coffre] vérification des empreintes impossible : $e');
      }
    }
    for (final c in uniques) {
      final etat = c.fp == null || racine == SafeboxRoot.partager ? null : etats[c.fp];
      switch (etat?.state) {
        case 'saved' || 'elsewhere' when racine == SafeboxRoot.albums && etat?.fileId != null:
          c.existingFileId = etat!.fileId;
          plan.link.add(c);
        case 'saved' || 'uploading':
          plan.already += 1;
        default:
          plan.send.add(c);
      }
    }
  }

  // ── 2. Envoi ────────────────────────────────────────────────────────────

  /// Crée les dossiers, ajoute sans copie ce qui est déjà dans le coffre et
  /// confie le reste au gestionnaire d'envois. Rend le nombre de fichiers
  /// confiés ou ajoutés.
  Future<int> run(ImportPlan plan, SafeboxLimits limits) async {
    final tous = [...plan.link, ...plan.send];
    _etape(ImportProgress(ImportStep.preparing, total: tous.length));
    var faits = 0;
    try {
      final dossiers = _Dossiers(api, plan.target.id, limits.folderNameMax);

      // Ajouts sans copie, par dossier d'arrivée.
      final parDossier = <int, List<int>>{};
      for (final c in plan.link) {
        final id = await dossiers.resolve(c.folderPath);
        parDossier.putIfAbsent(id, () => []).add(c.existingFileId!);
      }
      for (final MapEntry(key: dossier, value: ids) in parDossier.entries) {
        for (var i = 0; i < ids.length; i += 50) {
          final morceau = ids.sublist(i, (i + 50).clamp(0, ids.length));
          try {
            await api.addSafeboxFilesToFolder(dossier, morceau);
            faits += morceau.length;
          } catch (e) {
            debugPrint('[Coffre] ajout sans copie impossible : $e');
          }
          _avance(faits);
        }
      }

      final travail = await workDir();
      await travail.create(recursive: true);
      final maxApercu = limits.maxPreviewBytes - kSafeboxTagBytes;
      for (var i = 0; i < plan.send.length; i += 1) {
        final c = plan.send[i];
        try {
          final dossier = c.folderId ?? await dossiers.resolve(c.folderPath);
          await _confier(c, dossier, travail, maxApercu, limits.fileNameMax);
          faits += 1;
        } catch (e) {
          debugPrint('[Coffre] préparation de ${c.name} impossible : $e');
        }
        _avance(plan.link.length + i + 1);
      }
      return faits;
    } finally {
      _etape(null);
    }
  }

  Future<void> _confier(ImportCandidate c, int dossier, Directory travail, int maxApercu, int nomMax) async {
    final st = await File(c.path).stat();
    final cle = safeboxNewFileKey();
    String? cheminApercu;
    var tailleApercu = 0;
    int? largeur;
    int? hauteur;
    if (c.family == SafeboxFamily.photos) {
      try {
        final a = await photoPreview(c.path);
        largeur = a.width;
        hauteur = a.height;
        final jpeg = a.jpeg;
        if (jpeg != null && jpeg.isNotEmpty && jpeg.length <= maxApercu) {
          final chiffre = safeboxEncryptPreviewSync(cle, jpeg);
          cheminApercu = '${travail.path}${Platform.pathSeparator}apercu_${DateTime.now().microsecondsSinceEpoch}.sbx';
          await File(cheminApercu).writeAsBytes(chiffre, flush: true);
          tailleApercu = chiffre.length;
        }
      } catch (e) {
        // Format que l'ordinateur ne lit pas (HEIC sous Linux…) : sans aperçu.
        debugPrint('[Coffre] aperçu de ${c.name} impossible : $e');
      }
    }
    await enqueue(
      SafeboxUploadJob(
        id: '${DateTime.now().microsecondsSinceEpoch}_${c.path.hashCode}',
        folderId: dossier,
        name: shortenFileName(c.name, nomMax),
        mime: null,
        sourcePath: c.path,
        sourceSize: st.size,
        sourceModifiedMs: st.modified.millisecondsSinceEpoch,
        // Jamais le fichier de l'inscrit : il reste sur son PC.
        ownsSource: false,
        plainSize: st.size,
        originalSize: null,
        compressed: false,
        quality: SafeboxQuality.original.name,
        previewPath: cheminApercu,
        previewSize: tailleApercu,
        meta: {
          if (largeur != null && hauteur != null) ...{'width': largeur, 'height': hauteur},
          'source': ?c.source,
        },
        sourceFp: c.fp,
      ),
      cle,
    );
  }

  static Future<List<String?>> _empreintesIsolat(List<String> chemins) => Isolate.run(() => [
        for (final p in chemins)
          () {
            try {
              return safeboxSourceFingerprintSync(p);
            } catch (_) {
              return null;
            }
          }(),
      ]);

  /// Taille d'un fichier ; 0 s'il ne se lit pas (droits) : il est laissé de côté.
  static Future<int> _taille(File f) async {
    try {
      return await f.length();
    } catch (_) {
      return 0;
    }
  }

  static String _nom(String chemin) {
    final s = chemin.endsWith(Platform.pathSeparator) ? chemin.substring(0, chemin.length - 1) : chemin;
    final i = s.lastIndexOf(Platform.pathSeparator);
    return i < 0 ? s : s.substring(i + 1);
  }
}

/// Un nom trop long, raccourci en gardant l'extension.
String shortenFileName(String name, int max) {
  if (max <= 0 || name.length <= max) return name;
  final point = name.lastIndexOf('.');
  final ext = point > 0 && name.length - point <= 11 ? name.substring(point) : '';
  return '${name.substring(0, max - ext.length).trimRight()}$ext';
}

/// Les sous-dossiers recréés sous la cible : un dossier du même nom est
/// réutilisé ; trop profond, le fichier reste dans le dernier dossier créé.
class _Dossiers {
  _Dossiers(this.api, this.racine, this.nomMax);

  final SafeboxCalls api;
  final int racine;
  final int nomMax;
  final Map<String, int> _connus = {};
  final Map<int, Map<String, int>> _enfants = {};

  Future<int> resolve(List<String> chemin) async {
    var ici = racine;
    for (var i = 0; i < chemin.length; i += 1) {
      final cle = chemin.sublist(0, i + 1).join('\u0000');
      final connu = _connus[cle];
      if (connu != null) {
        ici = connu;
        continue;
      }
      final suivant = await _enfant(ici, chemin[i]);
      if (suivant == null) return ici;
      _connus[cle] = suivant;
      ici = suivant;
    }
    return ici;
  }

  Future<Map<String, int>> _lire(int parent) async {
    final p = await api.fetchSafeboxFolder(parent);
    return _enfants[parent] = {for (final f in p.folders) (f.name ?? '').toLowerCase(): f.id};
  }

  Future<int?> _enfant(int parent, String nomBrut) async {
    final nom = nomBrut.length > nomMax && nomMax > 0 ? nomBrut.substring(0, nomMax).trimRight() : nomBrut;
    final enfants = _enfants[parent] ?? await _lire(parent);
    final existant = enfants[nom.toLowerCase()];
    if (existant != null) return existant;
    try {
      final f = await api.createSafeboxFolder(parentId: parent, name: nom);
      enfants[nom.toLowerCase()] = f.id;
      return f.id;
    } on SafeboxHttpException catch (e) {
      // Créé entre-temps (autre appareil) : on le relit.
      if (e.code == 'SAFEBOX_NAME_TAKEN') return (await _lire(parent))[nom.toLowerCase()];
      // Trop profond, trop de dossiers : les fichiers restent au-dessus.
      debugPrint('[Coffre] dossier « $nom » non créé : $e');
      return null;
    }
  }
}
