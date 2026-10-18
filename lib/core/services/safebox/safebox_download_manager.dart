//  Téléchargements du coffre-fort, avec reprise, et cache des aperçus.
//
//  Un fichier se lit bloc par bloc depuis MEGA (adresses signées, 15 minutes),
//  chaque bloc se déchiffre seul (format SBX1) et s'ajoute au fichier en
//  cours. Une coupure reprend au milieu du bloc (`Range`) ; un redémarrage de
//  l'application reprend au premier bloc absent du fichier en cours.

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../talky_api_client.dart';
import 'safebox_cipher.dart';
import 'safebox_models.dart';

abstract class SafeboxDownloadTransport {
  Future<SafeboxDownloadPlan> plan(int fileId);

  /// Plan d'un fichier reçu par partage (compte un téléchargement).
  Future<SafeboxDownloadPlan> sharePlan(int shareId);
  Future<void> getBlock(String url, {int from, required void Function(List<int> bytes) onBytes});
  Future<Uint8List> getPreview(String url);
}

class ApiSafeboxDownloadTransport implements SafeboxDownloadTransport {
  ApiSafeboxDownloadTransport(this.api);
  final TalkyApiClient api;

  @override
  Future<SafeboxDownloadPlan> plan(int fileId) => api.fetchSafeboxDownload(fileId);

  @override
  Future<SafeboxDownloadPlan> sharePlan(int shareId) => api.fetchSafeboxShareDownload(shareId);

  @override
  Future<void> getBlock(String url, {int from = 0, required void Function(List<int> bytes) onBytes}) =>
      api.getSafeboxBlock(url, from: from, onBytes: onBytes);

  @override
  Future<Uint8List> getPreview(String url) => api.getSafeboxPreview(url);
}

/// Dossier du coffre sur le téléphone (hors des sauvegardes de l'appareil).
Future<Directory> safeboxLocalDir() async {
  final base = await getApplicationSupportDirectory();
  return Directory('${base.path}/safebox');
}

/// Nom de fichier sûr pour le système de fichiers du téléphone.
String safeboxLocalName(String name) {
  final propre = name.replaceAll(RegExp(r'[/\\\u0000-\u001f]'), '_').trim();
  return propre.isEmpty || propre == '.' || propre == '..' ? 'fichier' : propre;
}

class SafeboxDownloadManager extends ChangeNotifier {
  SafeboxDownloadManager({
    required SafeboxDownloadTransport transport,
    Future<Directory> Function()? baseDir,
    Future<Uint8List> Function(List<int> key, Uint8List cipher, SafeboxBlockPlan plan)? decrypt,
    Future<void> Function(Duration)? sleep,
    this.networkRetries = const [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 30)],
  })  : _transport = transport,
        _baseDir = baseDir ?? safeboxLocalDir,
        _decrypt = decrypt ?? safeboxDecryptBlock,
        _sleep = sleep ?? Future<void>.delayed;

  final SafeboxDownloadTransport _transport;
  final Future<Directory> Function() _baseDir;
  final Future<Uint8List> Function(List<int>, Uint8List, SafeboxBlockPlan) _decrypt;
  final Future<void> Function(Duration) _sleep;
  final List<Duration> networkRetries;

  final Map<int, double> _progres = {};
  final Map<int, Future<File>> _enCours = {};

  /// Avancement d'un téléchargement en cours (0 à 1), ou null.
  double? progressOf(int fileId) => _progres[fileId];

  /// Un fichier de mon coffre sous `files/<id>/`, un fichier reçu sous
  /// `shares/<partage>/` (son identifiant local est négatif).
  Future<File> _cible(SafeboxFile file) async {
    final base = await _baseDir();
    final dossier = file.id < 0 ? 'shares/${-file.id}' : 'files/${file.id}';
    return File('${base.path}/$dossier/${safeboxLocalName(file.name)}');
  }

  /// Le fichier en clair s'il est déjà sur le téléphone.
  Future<File?> cached(SafeboxFile file) async {
    final f = await _cible(file);
    return await f.exists() && await f.length() == file.plainBytes ? f : null;
  }

  /// Le fichier en clair, téléchargé au besoin. Deux appels simultanés pour le
  /// même fichier partagent le même téléchargement.
  Future<File> fetch(SafeboxFile file) => _demarrer(file, () => _transport.plan(file.id));

  /// Un fichier reçu dans une discussion ([SafeboxShareInfo.asFile]).
  Future<File> fetchShare(SafeboxShareInfo share) =>
      _demarrer(share.asFile(), () => _transport.sharePlan(share.id));

  Future<File> _demarrer(SafeboxFile file, Future<SafeboxDownloadPlan> Function() planifier) {
    return _enCours.putIfAbsent(file.id, () async {
      try {
        return await _telecharger(file, planifier);
      } finally {
        _enCours.remove(file.id);
        _progres.remove(file.id);
        notifyListeners();
      }
    });
  }

  /// Supprime la copie en clair du téléphone (le fichier reste dans le coffre).
  Future<void> evict(int fileId) async {
    final base = await _baseDir();
    final d = Directory(fileId < 0 ? '${base.path}/shares/${-fileId}' : '${base.path}/files/$fileId');
    if (await d.exists()) await d.delete(recursive: true);
  }

  Future<T> _avecReprise<T>(Future<T> Function() action) async {
    for (var essai = 0;; essai += 1) {
      try {
        return await action();
      } on TalkyException catch (e) {
        if (e.statusCode != 0 || essai >= networkRetries.length) rethrow;
        await _sleep(networkRetries[essai]);
      }
    }
  }

  Future<File> _telecharger(SafeboxFile file, Future<SafeboxDownloadPlan> Function() planifier) async {
    final cible = await _cible(file);
    if (await cible.exists() && await cible.length() == file.plainBytes) return cible;
    await cible.parent.create(recursive: true);
    final partiel = File('${cible.path}.part');

    var plan = await _avecReprise(planifier);
    final parBloc = safeboxChunksPerBlock(plan.blockSize) * kSafeboxChunkPlainBytes;

    // Reprise : on garde les blocs entiers déjà déchiffrés.
    var deja = await partiel.exists() ? await partiel.length() : 0;
    final blocsFaits = deja ~/ parBloc;
    deja = blocsFaits * parBloc;
    final raf = await partiel.open(mode: deja > 0 ? FileMode.append : FileMode.write);
    try {
      await raf.truncate(deja);
      await raf.setPosition(deja);
      for (var n = blocsFaits + 1; n <= plan.blockCount; n += 1) {
        final geo = safeboxPlanBlock(n, plainSize: file.plainBytes, blockSize: plan.blockSize);
        final recu = BytesBuilder(copy: false);
        var adresseRenouvelee = false;
        while (recu.length < geo.cipherLength) {
          final url = plan.blocks.firstWhere((b) => b.n == n).url;
          try {
            await _avecReprise(() => _transport.getBlock(url, from: recu.length, onBytes: (b) {
                  recu.add(b);
                  _progres[file.id] = (geo.plainStart + recu.length * geo.plainLength / geo.cipherLength) / file.plainBytes;
                  notifyListeners();
                }));
          } on TalkyException catch (e) {
            // Adresses de 15 minutes : un gros fichier sur une ligne lente les use.
            if (e.statusCode != 403 || adresseRenouvelee) rethrow;
            adresseRenouvelee = true;
            plan = await _avecReprise(planifier);
          }
        }
        final chiffre = recu.takeBytes();
        if (chiffre.length != geo.cipherLength) {
          throw TalkyException('bloc $n de ${chiffre.length} octets', 0, code: 'SAFEBOX_BLOCK_SIZE');
        }
        await raf.writeFrom(await _decrypt(plan.key, chiffre, geo));
      }
    } finally {
      await raf.close();
    }
    if (await partiel.length() != file.plainBytes) {
      throw TalkyException('taille finale inattendue', 0, code: 'SAFEBOX_BLOCK_SIZE');
    }
    return partiel.rename(cible.path);
  }
}

/// Aperçus déchiffrés en mémoire (les 200 derniers), gardés CHIFFRÉS sur le
/// téléphone : rien du coffre n'y est écrit en clair sans que l'inscrit
/// l'ouvre.
class SafeboxPreviewCache {
  SafeboxPreviewCache({required SafeboxDownloadTransport transport, Future<Directory> Function()? baseDir})
      : _transport = transport,
        _baseDir = baseDir ?? safeboxLocalDir;

  final SafeboxDownloadTransport _transport;
  final Future<Directory> Function() _baseDir;
  final LinkedHashMap<int, Uint8List> _memoire = LinkedHashMap();
  final Map<int, Future<Uint8List?>> _enCours = {};
  static const _max = 200;

  Uint8List? peek(int fileId) => _memoire[fileId];

  Future<Uint8List?> load(SafeboxFile file) {
    final deja = _memoire[file.id];
    if (deja != null) return Future.value(deja);
    if (file.key == null) return Future.value(null);
    return _enCours.putIfAbsent(file.id, () async {
      try {
        final base = await _baseDir();
        final disque = File('${base.path}/previews/${file.id}.sbx');
        Uint8List chiffre;
        if (await disque.exists()) {
          chiffre = await disque.readAsBytes();
        } else {
          if (file.previewUrl == null) return null;
          chiffre = await _transport.getPreview(file.previewUrl!);
          await disque.parent.create(recursive: true);
          await disque.writeAsBytes(chiffre, flush: true);
        }
        final clair = safeboxDecryptPreviewSync(file.key!, chiffre);
        _memoire[file.id] = clair;
        while (_memoire.length > _max) {
          _memoire.remove(_memoire.keys.first);
        }
        return clair;
      } catch (e) {
        debugPrint('[Coffre] aperçu ${file.id} illisible : $e');
        return null;
      } finally {
        _enCours.remove(file.id);
      }
    });
  }
}
