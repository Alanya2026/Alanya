import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_cipher.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/core/services/safebox/safebox_upload_manager.dart';
import 'package:talky_flutter/talky_api_client.dart';

const _mio = 1 << 20;

/// Faux serveur : il tient la liste des blocs « reçus chez MEGA ».
class _FauxServeur implements SafeboxTransport {
  int prochainId = 100;
  int blockSize = _mio;
  final Map<int, ({int size, int plain, int preview})> envois = {};
  final Map<int, Set<int>> recus = {};
  final Set<int> apercus = {};
  final List<String> appels = [];

  /// Erreurs à lever, dans l'ordre, au prochain envoi de bloc.
  final List<TalkyException> erreursPut = [];
  TalkyException? erreurReserve;
  bool statusIntrouvable = false;
  int incompletUneFois = 0;
  bool annule = false;

  @override
  Future<SafeboxUploadTicket> reserve({
    required int folderId,
    required String name,
    required String? mime,
    required int size,
    required int plainSize,
    required String cipherFormat,
    int? originalSize,
    bool compressed = false,
    int previewSize = 0,
  }) async {
    appels.add('reserve');
    if (erreurReserve != null) throw erreurReserve!;
    final id = prochainId++;
    final n = safeboxBlockCount(plainSize, blockSize);
    envois[id] = (size: size, plain: plainSize, preview: previewSize);
    recus[id] = {};
    return SafeboxUploadTicket(
      fileId: id,
      blockSize: blockSize,
      blockCount: n,
      size: size,
      blocks: [for (var i = 1; i <= n; i += 1) SafeboxSignedBlock(n: i, size: 0, url: 'blk:$id:$i')],
      preview: previewSize > 0 ? SafeboxSignedBlock(n: 0, size: previewSize, url: 'apercu:$id') : null,
      urlTtlSeconds: 86400,
    );
  }

  @override
  Future<SafeboxUploadStatus> status(int fileId) async {
    appels.add('status');
    if (statusIntrouvable) throw TalkyException('introuvable', 404, code: 'SAFEBOX_NOT_FOUND');
    final e = envois[fileId]!;
    final n = safeboxBlockCount(e.plain, blockSize);
    final r = recus[fileId]!;
    return SafeboxUploadStatus(
      blockCount: n,
      received: r.toList()..sort(),
      missing: [for (var i = 1; i <= n; i += 1) if (!r.contains(i)) i],
      previewMissing: e.preview > 0 && !apercus.contains(fileId),
    );
  }

  @override
  Future<({List<SafeboxSignedBlock> blocks, SafeboxSignedBlock? preview})> urls(
    int fileId, {
    List<int> blocks = const [],
    bool preview = false,
  }) async {
    appels.add('urls');
    return (
      blocks: [for (final n in blocks) SafeboxSignedBlock(n: n, size: 0, url: 'blk:$fileId:$n')],
      preview: preview ? SafeboxSignedBlock(n: 0, size: 0, url: 'apercu:$fileId') : null,
    );
  }

  @override
  Future<void> putBlock(String url, Uint8List bytes, {void Function(int sent)? onProgress}) async {
    appels.add('put $url');
    if (erreursPut.isNotEmpty) throw erreursPut.removeAt(0);
    final parts = url.split(':');
    final id = int.parse(parts[1]);
    if (parts[0] == 'apercu') {
      expect(bytes.length, envois[id]!.preview);
      apercus.add(id);
      return;
    }
    final n = int.parse(parts[2]);
    final plan = safeboxPlanBlock(n, plainSize: envois[id]!.plain, blockSize: blockSize);
    expect(bytes.length, plan.cipherLength, reason: 'bloc $n de la mauvaise taille');
    onProgress?.call(bytes.length);
    recus[id]!.add(n);
  }

  @override
  Future<SafeboxFile> complete(int fileId, Uint8List key) async {
    appels.add('complete');
    if (incompletUneFois > 0) {
      incompletUneFois -= 1;
      recus[fileId]!.remove(2);
      throw TalkyException('incomplet', 409, code: 'SAFEBOX_UPLOAD_INCOMPLETE');
    }
    final e = envois[fileId]!;
    final n = safeboxBlockCount(e.plain, blockSize);
    expect(recus[fileId]!.length, n, reason: 'tous les blocs doivent être chez MEGA');
    if (e.preview > 0) expect(apercus, contains(fileId));
    return SafeboxFile(
      id: fileId, folderId: 1, name: 'f', ext: 'pdf', mime: null, family: SafeboxRoot.documents,
      plainBytes: e.plain, storedBytes: e.size, originalBytes: null, compressed: false,
      cipherFormat: kSafeboxCipherFormat, key: key, previewUrl: null,
    );
  }

  @override
  Future<void> cancel(int fileId) async {
    appels.add('cancel');
    annule = true;
  }
}

class _MemoireStore implements SafeboxJobStore {
  List<SafeboxUploadJob> gardes = [];
  final Map<String, Uint8List> cles = {};
  @override
  Future<List<SafeboxUploadJob>> loadJobs() async =>
      gardes.map((j) => SafeboxUploadJob.fromJson(j.toJson())).toList();
  @override
  Future<void> saveJobs(List<SafeboxUploadJob> jobs) async =>
      gardes = jobs.map((j) => SafeboxUploadJob.fromJson(j.toJson())).toList();
  @override
  Future<Uint8List?> loadKey(String jobId) async => cles[jobId];
  @override
  Future<void> saveKey(String jobId, Uint8List key) async => cles[jobId] = key;
  @override
  Future<void> deleteKey(String jobId) async => cles.remove(jobId);
}

final _reseau = TalkyException('réseau', 0);
final _cle = Uint8List.fromList(List<int>.generate(32, (i) => i));
Future<Uint8List> _fauxChiffrement(List<int> key, Uint8List plain, SafeboxBlockPlan plan) async =>
    Uint8List(plan.cipherLength);

void main() {
  late Directory dossier;
  late _FauxServeur serveur;
  late _MemoireStore store;
  final attentes = <Duration>[];

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('coffre_test');
    serveur = _FauxServeur();
    store = _MemoireStore();
    attentes.clear();
  });
  tearDown(() => dossier.delete(recursive: true));

  SafeboxUploadManager gestionnaire() => SafeboxUploadManager(
        transport: serveur,
        store: store,
        sleep: (d) async => attentes.add(d),
        encrypt: _fauxChiffrement,
      );

  /// 2,5 Mio : 3 blocs de 1 Mio chiffrés.
  Future<SafeboxUploadJob> travail({int taille = kSafeboxChunkPlainBytes * 2 + 1000, int apercu = 0, bool possede = false}) async {
    final f = File('${dossier.path}/source.bin');
    await f.writeAsBytes(Uint8List(taille));
    String? cheminApercu;
    if (apercu > 0) {
      cheminApercu = '${dossier.path}/apercu.bin';
      await File(cheminApercu).writeAsBytes(Uint8List(apercu));
    }
    final st = await f.stat();
    return SafeboxUploadJob(
      id: 'j1', folderId: 1, name: 'f.pdf', mime: 'application/pdf',
      sourcePath: f.path, sourceSize: st.size, sourceModifiedMs: st.modified.millisecondsSinceEpoch,
      ownsSource: possede, plainSize: taille, originalSize: null, compressed: false,
      previewPath: cheminApercu, previewSize: apercu,
    );
  }

  Future<SafeboxFile> attendreFin(SafeboxUploadManager m) => m.completed.first.timeout(const Duration(seconds: 10));

  Future<void> attendreEtat(SafeboxUploadManager m, SafeboxUploadState etat) async {
    for (var i = 0; i < 200; i += 1) {
      if (m.jobs.isNotEmpty && m.jobs.first.state == etat) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('état $etat jamais atteint (${m.jobs.map((j) => '${j.state} ${j.errorCode}')})');
  }

  test('envoi complet : réserve, 3 blocs, aperçu, fin ; la clé est oubliée', () async {
    final m = gestionnaire();
    final fin = attendreFin(m);
    await m.enqueue(await travail(apercu: 500, possede: true), _cle);
    final f = await fin;
    expect(f.id, 100);
    expect(serveur.recus[100], {1, 2, 3});
    expect(serveur.appels.where((a) => a.startsWith('put blk')).length, 3);
    expect(store.cles, isEmpty);
    expect(store.gardes, isEmpty);
    expect(File('${dossier.path}/source.bin').existsSync(), isFalse, reason: 'copie de compression supprimée');
    expect(m.jobs.single.progress, 1.0);
  });

  test('coupures passagères : réessayées, puis l\'envoi aboutit', () async {
    serveur.erreursPut.addAll([_reseau, _reseau]);
    final m = gestionnaire();
    final fin = attendreFin(m);
    await m.enqueue(await travail(), _cle);
    await fin;
    expect(attentes, const [Duration(seconds: 2), Duration(seconds: 5)]);
    expect(serveur.recus[100], {1, 2, 3});
  });

  test('réseau absent pour de bon : « attend le réseau », puis reprise au retour', () async {
    serveur.erreursPut.addAll([_reseau, _reseau, _reseau, _reseau, _reseau]);
    final m = gestionnaire();
    await m.enqueue(await travail(), _cle);
    await attendreEtat(m, SafeboxUploadState.waitingNetwork);
    expect(m.jobs.first.errorCode, 'NETWORK');
    final fin = attendreFin(m);
    await m.resumeAll();
    await fin;
    expect(serveur.appels.where((a) => a == 'status').length, 1, reason: 'la reprise demande ce qui est arrivé');
    expect(serveur.appels.where((a) => a == 'reserve').length, 1, reason: 'pas de nouvelle réservation');
  });

  test('redémarrage de l\'application : seuls les blocs absents repartent', () async {
    final job = await travail();
    // Simule un arrêt après le bloc 1 : l'état gardé sur le téléphone le dit.
    final ticket = await serveur.reserve(
      folderId: 1, name: 'f.pdf', mime: null, size: job.storedSize, plainSize: job.plainSize,
      cipherFormat: kSafeboxCipherFormat,
    );
    serveur.recus[ticket.fileId]!.add(1);
    job
      ..fileId = ticket.fileId
      ..blockSize = ticket.blockSize
      ..blockCount = ticket.blockCount
      ..done.add(1);
    store.gardes = [job];
    store.cles['j1'] = _cle;
    serveur.appels.clear();

    final m2 = gestionnaire();
    final fin = attendreFin(m2);
    await m2.resumeAll();
    await fin;
    expect(serveur.appels.where((a) => a.startsWith('put')).toList(), ['put blk:100:2', 'put blk:100:3']);
  });

  test('envoi abandonné côté serveur (404) : nouvelle réservation, tout repart', () async {
    final job = await travail();
    job
      ..fileId = 55
      ..blockSize = _mio
      ..blockCount = 3
      ..done.addAll([1, 2]);
    store.gardes = [job];
    store.cles['j1'] = _cle;
    serveur.statusIntrouvable = true;
    final m = gestionnaire();
    final fin = attendreFin(m);
    await m.resumeAll();
    final f = await fin;
    expect(f.id, 100);
    expect(serveur.recus[100], {1, 2, 3});
  });

  test('MEGA n\'a pas tout à la fin : le bloc manquant est renvoyé', () async {
    serveur.incompletUneFois = 1;
    final m = gestionnaire();
    final fin = attendreFin(m);
    await m.enqueue(await travail(), _cle);
    await fin;
    expect(serveur.appels.where((a) => a == 'put blk:100:2').length, 2);
  });

  test('adresse expirée (403) : une nouvelle, et le bloc passe', () async {
    serveur.erreursPut.add(TalkyException('expirée', 403, code: 'SAFEBOX_BLOCK_REJECTED'));
    final m = gestionnaire();
    final fin = attendreFin(m);
    await m.enqueue(await travail(), _cle);
    await fin;
    expect(serveur.appels, contains('urls'));
  });

  test('fichier d\'origine modifié pendant l\'envoi : arrêt, rien n\'est rechiffré', () async {
    final m = gestionnaire();
    final job = await travail();
    await File(job.sourcePath).writeAsBytes(Uint8List(job.plainSize + 1));
    await m.enqueue(job, _cle);
    await attendreEtat(m, SafeboxUploadState.failed);
    expect(m.jobs.first.errorCode, 'SAFEBOX_SOURCE_CHANGED');
    expect(serveur.appels, isEmpty);
  });

  test('espace plein : échec avec le code du serveur, pas de nouvel essai', () async {
    serveur.erreurReserve = TalkyException('plein', 409, code: 'SAFEBOX_QUOTA_EXCEEDED');
    final m = gestionnaire();
    await m.enqueue(await travail(), _cle);
    await attendreEtat(m, SafeboxUploadState.failed);
    expect(m.jobs.first.errorCode, 'SAFEBOX_QUOTA_EXCEEDED');
    expect(attentes, isEmpty);
  });

  test('annulation : le serveur libère l\'espace, la clé et la copie partent', () async {
    serveur.erreursPut.addAll(List.filled(5, _reseau));
    final m = gestionnaire();
    await m.enqueue(await travail(possede: true), _cle);
    await attendreEtat(m, SafeboxUploadState.waitingNetwork);
    await m.cancel('j1');
    expect(serveur.annule, isTrue);
    expect(store.cles, isEmpty);
    expect(m.jobs, isEmpty);
    expect(File('${dossier.path}/source.bin').existsSync(), isFalse);
  });
}
