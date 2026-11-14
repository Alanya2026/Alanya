// Lire une vidéo ou un audio du coffre sans l'avoir téléchargé en entier
// (14/11/2026).
//
// Un petit serveur HTTP, sur cet ordinateur seulement (127.0.0.1, adresse
// secrète tirée au hasard), sert le fichier EN CLAIR au lecteur (media_kit /
// mpv) au fil de ses demandes « octets de X à Y » : il ne télécharge et ne
// déchiffre que les blocs de 8 Mio concernés (chaque bloc SBX1 se déchiffre
// seul), en garde quelques-uns en mémoire et prépare le suivant. On peut
// avancer au milieu d'un film sans attendre le début. Rien n'est écrit en
// clair sur le disque.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/foundation.dart';

class VaultStreamServer {
  VaultStreamServer(this.api, {this.cachedBlocks = 4});

  final SafeboxCalls api;

  /// Blocs déchiffrés gardés en mémoire par fichier (8 Mio chacun).
  final int cachedBlocks;

  HttpServer? _serveur;
  Future<HttpServer>? _demarrage;
  final String _secret = _hasard();
  final Map<String, _Flux> _flux = {};

  static String _hasard() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// L'adresse à donner au lecteur pour [file] ; [release] quand il est fermé.
  Future<Uri> open(SafeboxFile file) async {
    final s = await (_demarrage ??= _demarrer());
    final jeton = _hasard();
    _flux[jeton] = _Flux(api, file, cachedBlocks);
    final nom = Uri.encodeComponent(file.name);
    return Uri.parse('http://127.0.0.1:${s.port}/$_secret/$jeton/$nom');
  }

  /// Le lecteur est fermé : ses blocs quittent la mémoire.
  void release(Uri url) {
    final segments = url.pathSegments;
    if (segments.length >= 2) _flux.remove(segments[1]);
  }

  Future<HttpServer> _demarrer() async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _serveur = s;
    s.listen((req) => unawaited(_repondre(req)));
    return s;
  }

  Future<void> _repondre(HttpRequest req) async {
    final res = req.response;
    try {
      final seg = req.uri.pathSegments;
      final flux = seg.length >= 2 && seg[0] == _secret ? _flux[seg[1]] : null;
      if (flux == null || (req.method != 'GET' && req.method != 'HEAD')) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      await flux.ready();
      final taille = flux.file.plainBytes;
      var debut = 0;
      var fin = taille - 1;
      final plage = req.headers.value(HttpHeaders.rangeHeader);
      final m = plage == null ? null : RegExp(r'bytes=(\d*)-(\d*)').firstMatch(plage);
      if (m != null) {
        if (m.group(1)!.isEmpty) {
          // « bytes=-N » : les N derniers octets.
          debut = max(0, taille - int.parse(m.group(2)!));
        } else {
          debut = int.parse(m.group(1)!);
          if (m.group(2)!.isNotEmpty) fin = min(int.parse(m.group(2)!), taille - 1);
        }
        if (debut >= taille || debut > fin) {
          res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$taille');
          await res.close();
          return;
        }
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $debut-$fin/$taille');
      }
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      res.contentLength = fin - debut + 1;
      if (req.method == 'HEAD') {
        await res.close();
        return;
      }
      var position = debut;
      while (position <= fin) {
        final n = flux.blocOf(position);
        final bloc = await flux.block(n);
        flux.prefetch(n + 1);
        final depart = position - flux.plainStartOf(n);
        final bout = min(bloc.length, depart + (fin - position + 1));
        res.add(Uint8List.sublistView(bloc, depart, bout));
        await res.flush();
        position += bout - depart;
      }
      await res.close();
    } catch (e) {
      // Le lecteur a fermé la connexion (il avance ailleurs), ou le réseau a
      // lâché : il redemandera.
      debugPrint('[Lecture] $e');
      try {
        await res.close();
      } catch (_) {}
    }
  }

  Future<void> close() async {
    _flux.clear();
    await _serveur?.close(force: true);
  }
}

/// Un fichier en lecture : son plan de téléchargement et quelques blocs.
class _Flux {
  _Flux(this.api, this.file, this.garde);

  final SafeboxCalls api;
  final SafeboxFile file;
  final int garde;
  SafeboxDownloadPlan? _plan;
  final Map<int, Future<Uint8List>> _blocs = {};

  int? _parBloc;

  Future<SafeboxDownloadPlan>? _planEnCours;

  Future<SafeboxDownloadPlan> _lePlan({bool neuf = false}) async {
    if (neuf || _plan == null) {
      final enCours = neuf ? null : _planEnCours;
      final f = enCours ?? (_planEnCours = api.fetchSafeboxDownload(file.id));
      try {
        _plan = await f;
      } finally {
        if (identical(_planEnCours, f)) _planEnCours = null;
      }
    }
    _parBloc = safeboxChunksPerBlock(_plan!.blockSize) * kSafeboxChunkPlainBytes;
    return _plan!;
  }

  /// Le plan est connu (taille réelle des blocs) avant de découper une plage.
  Future<void> ready() => _lePlan();

  /// Taille en clair d'un bloc (8 Mio moins les étiquettes) : connue après
  /// le premier plan ; avant, celle du format actuel.
  int get _taille => _parBloc ?? safeboxChunksPerBlock(8 << 20) * kSafeboxChunkPlainBytes;

  int blocOf(int position) => position ~/ _taille + 1;
  int plainStartOf(int n) => (n - 1) * _taille;

  void prefetch(int n) {
    final plan = _plan;
    if (plan != null && n <= plan.blockCount && !_blocs.containsKey(n)) unawaited(block(n).then((_) {}, onError: (_) {}));
  }

  Future<Uint8List> block(int n) {
    final deja = _blocs.remove(n);
    if (deja != null) {
      _blocs[n] = deja; // le plus récent en dernier
      return deja;
    }
    final f = _charger(n);
    _blocs[n] = f;
    while (_blocs.length > garde) {
      _blocs.remove(_blocs.keys.first);
    }
    // Un échec ne reste pas en mémoire : le lecteur redemandera.
    f.catchError((Object _) {
      if (identical(_blocs[n], f)) _blocs.remove(n);
      return Uint8List(0);
    });
    return f;
  }

  Future<Uint8List> _charger(int n) async {
    var plan = await _lePlan();
    final geo = safeboxPlanBlock(n, plainSize: file.plainBytes, blockSize: plan.blockSize);
    final recu = BytesBuilder(copy: false);
    var renouvele = false;
    var essais = 0;
    while (recu.length < geo.cipherLength) {
      final url = plan.blocks.firstWhere((b) => b.n == n).url;
      try {
        await api.getSafeboxBlock(url, from: recu.length, onBytes: recu.add);
      } on SafeboxHttpException catch (e) {
        // Adresses de 15 minutes : un film regardé longtemps les use.
        if (e.statusCode == 403 && !renouvele) {
          renouvele = true;
          plan = await _lePlan(neuf: true);
          continue;
        }
        if (e.statusCode != 0 || ++essais > 3) rethrow;
        await Future<void>.delayed(Duration(seconds: essais * 2));
      }
    }
    return safeboxDecryptBlock(plan.key, recu.takeBytes(), geo);
  }
}
