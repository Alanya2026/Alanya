import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/app_log.dart';
import '../utils/backend_url.dart';
import 'media_expiry_policy.dart';

/// Nombre de nouvelles tentatives après un échec passager.
const kMediaDownloadRetries = 2;

/// Délai avant la tentative n° [tentative] (1, 2…) d'un téléchargement qui a
/// échoué, ou `null` s'il ne faut pas réessayer.
///
/// Le 9 octobre 2026, une panne de plusieurs heures du stockage a fait
/// échouer tous les téléchargements, et l'application traitait chaque échec
/// comme définitif : « Échec du téléchargement », sans nouvel essai (groupe
/// 3GI 2029, bug A3). On réessaie donc après une réponse passagère — 429 trop
/// de requêtes, 5xx — ou une erreur réseau ([status] `null`). Jamais après un
/// 4xx ordinaire : 403, 404 ou 410 ne changeront pas en attendant.
/// `Retry-After` (en secondes) est respecté, plafonné à 30 s.
Duration? delaiAvantNouvelEssai({
  required int tentative,
  required int? status,
  String? retryAfter,
}) {
  if (tentative > kMediaDownloadRetries) return null;
  final passager = status == null || status == 429 || status >= 500;
  if (!passager) return null;
  final demande = int.tryParse(retryAfter?.trim() ?? '');
  if (demande != null && demande >= 0) {
    return Duration(seconds: demande.clamp(0, 30));
  }
  return Duration(seconds: tentative == 1 ? 2 : 5);
}

//  Télécharge et conserve les médias reçus dans le dossier de l'app pour
//  une consultation hors-ligne.
//
//  ── Aucune éviction automatique ──
//
//  Un média téléchargé sur l'appareil reste accessible **jusqu'à la
//  désinstallation de l'application ou un changement de compte**. Rien d'autre
//  ne le supprime.
//
//  Une éviction LRU plafonnait auparavant ce dossier à 500 Mo : au-delà, les
//  fichiers les moins récemment consultés étaient effacés en silence, sans que
//  l'utilisateur en soit averti ni puisse s'y opposer. Ce plafond n'était une
//  contrainte ni d'Android ni d'iOS — une constante écrite à la main.
//
//  Elle est retirée parce que sa combinaison avec la rétention serveur était
//  destructrice : tant que le serveur conservait tout, un fichier évincé se
//  retéléchargeait et personne ne s'en apercevait. Depuis que le serveur
//  supprime au-delà de sa rétention, évincé côté appareil + tombé côté serveur
//  = **perdu définitivement**. Les deux mécanismes étaient anodins séparément
//  et destructeurs ensemble.
//
//  Le dossier grossit donc librement, et c'est l'utilisateur qui le gère :
//  [currentSizeBytes] alimente l'écran de stockage, [clearAll] le vide sur sa
//  demande explicite (`StorageInfoService.clearMediaCache`) comme au
//  changement de compte.
//
//  ⚠ Vider ce cache est devenu une suppression DÉFINITIVE pour tout média dont
//  la partition serveur est déjà tombée : il ne se retéléchargera pas. Le
//  libellé proposé à l'utilisateur doit le dire — « libérer de l'espace » n'est
//  plus anodin.
class MediaCacheService {

  Directory? _dir;

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'media_cache'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Chemin local si déjà en cache, sinon null (sans télécharger).
  Future<String?> cachedPathFor(String url) async {
    final resolved = _resolvedUrl(url);
    final dir = await _cacheDir();
    final file = File(p.join(dir.path, _fileName(resolved)));
    return file.existsSync() ? file.path : null;
  }

  /// Télécharge un média vers un fichier TEMPORAIRE (hors du cache persistant)
  /// et renvoie son chemin. Utilisé pour les médias à vue unique : on lit
  /// depuis ce fichier local (les lecteurs natifs vidéo/audio ignorent le
  /// cert pinning et échouent sur une URL réseau directe), puis l'appelant
  /// supprime le fichier immédiatement après visionnage.
  Future<String?> downloadToTemp(String url) async {
    final resolved = _resolvedUrl(url);
    try {
      final res = await http.get(Uri.parse(resolved)).timeout(const Duration(seconds: 30));
      // Un 410 signifie que le média a dépassé sa rétention côté serveur : le
      // corps porte la durée appliquée, qu'on mémorise pour pouvoir conclure
      // sans requête la prochaine fois.
      if (MediaExpiryPolicy.noteResponse(res.statusCode, body: res.body)) return null;
      if (res.statusCode != 200) return null;
      final tmp = await getTemporaryDirectory();
      final path = p.join(
        tmp.path,
        'vo_${DateTime.now().microsecondsSinceEpoch}_${_fileName(resolved)}',
      );
      final file = File(path);
      await file.writeAsBytes(res.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('[MediaCache] downloadToTemp échoué $resolved: $e');
      return null;
    }
  }

  /// Comme [downloadToTemp] (fichier TEMPORAIRE hors cache persistant, pour la
  /// vue unique) mais **en flux** avec progression (0.0–1.0, ou `null` si taille
  /// inconnue) et **annulation** via [isCancelled]. Renvoie le chemin du fichier
  /// temp, ou `null` en cas d'échec / d'annulation (le fichier partiel est alors
  /// supprimé). Aucune trace persistante : l'appelant supprime le temp après
  /// visionnage (ou en quittant, s'il n'a jamais été ouvert).
  Future<String?> downloadToTempWithProgress(
    String url, {
    void Function(double? progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final resolved = _resolvedUrl(url);
    final client = http.Client();
    File? part;
    try {
      final tmp = await getTemporaryDirectory();
      final path = p.join(
        tmp.path,
        'vo_${DateTime.now().microsecondsSinceEpoch}_${_fileName(resolved)}',
      );
      final file = File(path);
      part = File('$path.part');

      final request = http.Request('GET', Uri.parse(resolved));
      final streamed =
          await client.send(request).timeout(const Duration(seconds: 60));
      // En flux le corps n'est pas lu : le statut seul suffit à conclure que
      // le média est mort. La durée de rétention sera apprise d'une réponse
      // non streamée — elle n'est pas nécessaire pour abandonner ici.
      if (MediaExpiryPolicy.noteResponse(streamed.statusCode)) return null;
      if (streamed.statusCode != 200) return null;

      final int? total = streamed.contentLength;
      final hasKnownSize = total != null && total > 0;
      onProgress?.call(hasKnownSize ? 0.0 : null);

      final sink = part.openWrite();
      var received = 0;
      try {
        await for (final chunk in streamed.stream) {
          if (isCancelled?.call() ?? false) {
            await sink.close();
            await _deleteQuietly(part);
            return null;
          }
          sink.add(chunk);
          received += chunk.length;
          if (hasKnownSize) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.close();
      }

      if (hasKnownSize && received < total) {
        await _deleteQuietly(part);
        return null;
      }
      if (file.existsSync()) await file.delete();
      await part.rename(file.path);
      onProgress?.call(1.0);
      return file.path;
    } catch (e) {
      debugPrint('[MediaCache] downloadToTempWithProgress échoué $resolved: $e');
      if (part != null) await _deleteQuietly(part);
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } catch (_) {/* déjà supprimé — ignoré */}
  }

  /// Télécharge le média avec progression (0.0–1.0) ou `null` si taille inconnue.
  ///
  /// [knownSize] : voir [ensureCached].
  Future<String?> downloadWithProgress(
    String url, {
    void Function(double? progress)? onProgress,
    int? maxBytes,
    int? knownSize,
  }) async {
    final resolved = _resolvedUrl(url);
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, _fileName(resolved)));
      if (file.existsSync() && file.lengthSync() > 0) {
        onProgress?.call(1.0);
        try {
          file.setLastAccessedSync(DateTime.now());
        } catch (e, st) {
          AppLog.w('MediaCache', 'Touch LRU (setLastAccessed) échoué', e, st);
        }
        return file.path;
      }

      final uri = Uri.parse(resolved);
      final client = http.Client();
      try {
        if (maxBytes != null && knownSize != null && knownSize > 0) {
          if (knownSize > maxBytes) {
            debugPrint('[MediaCache] skip $resolved : taille $knownSize > $maxBytes');
            return null;
          }
        } else if (maxBytes != null) {
          try {
            final head =
                await client.head(uri).timeout(const Duration(seconds: 5));
            final len = int.tryParse(head.headers['content-length'] ?? '');
            if (len != null && len > maxBytes) {
              debugPrint('[MediaCache] skip $resolved : taille $len > $maxBytes');
              return null;
            }
          } catch (_) {}
        }

        late http.StreamedResponse streamed;
        for (var tentative = 1;; tentative++) {
          http.StreamedResponse? res;
          try {
            res = await client
                .send(http.Request('GET', uri))
                .timeout(const Duration(seconds: 60));
          } on TimeoutException {
            res = null;
          } on SocketException {
            res = null;
          } on http.ClientException {
            res = null;
          }
          if (res != null) {
            if (MediaExpiryPolicy.noteResponse(res.statusCode)) return null;
            if (res.statusCode == 200) {
              streamed = res;
              break;
            }
            // Corps d'une réponse d'erreur : à vider pour libérer la connexion.
            unawaited(res.stream.drain<void>().catchError((_) {}));
          }
          final delai = delaiAvantNouvelEssai(
            tentative: tentative,
            status: res?.statusCode,
            retryAfter: res?.headers['retry-after'],
          );
          if (delai == null) return null;
          debugPrint('[MediaCache] nouvel essai dans ${delai.inSeconds}s '
              '(${res?.statusCode ?? 'réseau'}) $resolved');
          await Future<void>.delayed(delai);
        }

        final int? total = streamed.contentLength;
        final hasKnownSize = total != null && total > 0;
        if (hasKnownSize) {
          onProgress?.call(0.0);
        } else {
          onProgress?.call(null);
        }

        final tmp = File('${file.path}.part');
        final sink = tmp.openWrite();
        var received = 0;
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (hasKnownSize) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        }
        await sink.close();

        if (hasKnownSize && received < total) return null;
        if (maxBytes != null && received > maxBytes) {
          await tmp.delete();
          return null;
        }

        if (file.existsSync()) await file.delete();
        await tmp.rename(file.path);
        onProgress?.call(1.0);
        return file.path;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[MediaCache] downloadWithProgress échoué $resolved: $e');
      return null;
    }
  }

  /// Télécharge le média s'il n'est pas déjà en cache et renvoie le chemin local.
  /// Si [maxBytes] est fourni, vérifie d'abord la taille via HEAD et abandonne
  /// si trop gros (utile pour ne pas auto-cacher des fichiers énormes).
  ///
  /// [knownSize] : taille déjà connue (`message.mediaSize`). Elle évite le HEAD,
  /// une requête de plus vers le serveur et le stockage pour chaque média reçu.
  Future<String?> ensureCached(String url, {int? maxBytes, int? knownSize}) async {
    final resolved = _resolvedUrl(url);
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, _fileName(resolved)));
      if (file.existsSync() && file.lengthSync() > 0) {
        // Touch pour LRU
        try {
          file.setLastAccessedSync(DateTime.now());
        } catch (e, st) {
          AppLog.w('MediaCache', 'Touch LRU (setLastAccessed) échoué', e, st);
        }
        return file.path;
      }

      // Média expiré côté serveur : inutile de partir. L'ORDRE compte — ce
      // test vient APRÈS la lecture du cache local, jamais avant : une copie
      // déjà téléchargée reste accessible indéfiniment, même quand le serveur
      // a supprimé l'original. C'est la règle produit : ce chantier borne
      // l'espace du serveur, jamais celui de l'utilisateur.
      if (MediaExpiryPolicy.isExpired(resolved)) return null;

      if (maxBytes != null && knownSize != null && knownSize > 0) {
        if (knownSize > maxBytes) {
          debugPrint('[MediaCache] skip $resolved : taille $knownSize > $maxBytes');
          return null;
        }
      } else if (maxBytes != null) {
        try {
          final head = await http.head(Uri.parse(resolved)).timeout(const Duration(seconds: 5));
          final len = int.tryParse(head.headers['content-length'] ?? '');
          if (len != null && len > maxBytes) {
            debugPrint('[MediaCache] skip $resolved : taille $len > $maxBytes');
            return null;
          }
        } catch (_) {
          // HEAD échoue → on tente quand même (mieux vaut un cache best-effort)
        }
      }

      for (var tentative = 1;; tentative++) {
        http.Response? res;
        try {
          res = await http.get(Uri.parse(resolved)).timeout(const Duration(seconds: 30));
        } on TimeoutException {
          res = null;
        } on SocketException {
          res = null;
        } on http.ClientException {
          res = null;
        }
        if (res != null) {
          if (MediaExpiryPolicy.noteResponse(res.statusCode, body: res.body)) return null;
          if (res.statusCode == 200) {
            await file.writeAsBytes(res.bodyBytes);
            return file.path;
          }
        }
        final delai = delaiAvantNouvelEssai(
          tentative: tentative,
          status: res?.statusCode,
          retryAfter: res?.headers['retry-after'],
        );
        if (delai == null) return null;
        debugPrint('[MediaCache] nouvel essai dans ${delai.inSeconds}s '
            '(${res?.statusCode ?? 'réseau'}) $resolved');
        await Future<void>.delayed(delai);
      }
    } catch (e) {
      debugPrint('[MediaCache] échec cache $resolved: $e');
      return null;
    }
  }

  /// Taille actuelle du cache (octets). Le scan s'exécute dans un isolate :
  /// `listSync` sur l'isolat UI gelait l'écran à l'entrée de « Mes médias »
  /// quand le dossier cache contenait des milliers de fichiers.
  Future<int> currentSizeBytes() async {
    try {
      final dir = await _cacheDir();
      return await compute(_scanDirSize, dir.path);
    } catch (e) {
      debugPrint('[MediaCache] currentSizeBytes échoué: $e');
      return 0;
    }
  }

  /// Supprime la copie en cache d'un seul média et renvoie les octets libérés
  /// (0 si rien n'était en cache). Sert à « libérer de l'espace » depuis
  /// l'écran Mes médias : le fichier reste sur le serveur et se retéléchargera
  /// à la prochaine consultation.
  Future<int> removeForUrl(String url) async {
    try {
      final path = await cachedPathFor(url);
      if (path == null) return 0;
      final file = File(path);
      final bytes = file.lengthSync();
      file.deleteSync();
      return bytes;
    } catch (e, st) {
      AppLog.w('MediaCache', 'Suppression ciblée du cache échouée', e, st);
      return 0;
    }
  }

  /// Vide entièrement le cache média (logout / changement de compte).
  Future<void> clearAll() async {
    try {
      final dir = await _cacheDir();
      if (!dir.existsSync()) return;
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        try {
          entity.deleteSync();
        } catch (e, st) {
          AppLog.w('MediaCache', 'Suppression fichier cache échouée', e, st);
        }
      }
      debugPrint('[MediaCache] cache vidé');
    } catch (e) {
      debugPrint('[MediaCache] clearAll échoué: $e');
    }
  }

  String _resolvedUrl(String url) => normalizeBackendUrl(url) ?? url;

  String _fileName(String url) {
    final uri = Uri.tryParse(url);
    final last = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    if (last != null && last.isNotEmpty) return last;
    return '${url.hashCode}.bin';
  }
}

/// Scan synchrone exécuté dans un isolate par [MediaCacheService.currentSizeBytes].
int _scanDirSize(String dirPath) {
  var total = 0;
  try {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      try {
        total += entity.lengthSync();
      } catch (_) {
        // Fichier supprimé entre-temps ou verrouillé — ignoré.
      }
    }
  } catch (_) {
    // Dossier illisible — on renvoie ce qu'on a pu mesurer.
  }
  return total;
}
