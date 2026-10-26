import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/safebox/safebox_cipher.dart';
import 'package:talky_flutter/core/services/safebox/safebox_controller.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/core/services/safebox/safebox_upload_manager.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/safebox_share_payload.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Lot 9 : un album ou une sélection en une seule carte, les éléments reçus,
/// le suivi, et plusieurs fichiers du téléphone partis en un seul message.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocaleController.new);

  group('message de type 11 : un lot', () {
    test('titre, nombre, types et mosaïque font l\'aller-retour', () {
      const p = SafeboxSharePayload(
        share: 9, name: 'Kribi 2026', size: 195035136, family: SafeboxFamily.photos,
        kind: SafeboxShareKind.batch, count: 42,
        families: {SafeboxFamily.photos: 35, SafeboxFamily.videos: 6, SafeboxFamily.documents: 1},
        mosaic: ['QUJD', '', 'REVG'],
      );
      final brut = jsonDecode(p.encode()) as Map;
      expect(brut['kind'], 'batch');
      expect(brut['families'], {'photos': 35, 'videos': 6, 'documents': 1});
      expect(brut['bs'], ['QUJD', '', 'REVG']);
      final relu = SafeboxSharePayload.tryParse(p.encode())!;
      expect(relu.isBatch, isTrue);
      expect(relu.count, 42);
      expect(relu.families.keys, [SafeboxFamily.photos, SafeboxFamily.videos, SafeboxFamily.documents]);
      expect(relu.mosaic, ['QUJD', '', 'REVG']);
    });

    test('un fichier seul reste lisible par les anciennes applications', () {
      const p = SafeboxSharePayload(share: 7, name: 'a.mp4', size: 1, family: SafeboxFamily.videos, mosaic: ['QUJD']);
      final brut = jsonDecode(p.encode()) as Map;
      expect(brut.containsKey('kind'), isFalse);
      expect(brut.containsKey('bs'), isFalse, reason: 'pas de mosaïque pour un fichier');
      final ancien = SafeboxSharePayload.tryParse('{"v":1,"share":3,"name":"x.pdf","size":2,"family":"documents"}')!;
      expect(ancien.isBatch, isFalse);
      expect(ancien.count, 1);
      expect(ancien.mosaic, isEmpty);
    });
  });

  group('modèles du lot 9', () {
    final cle = base64Encode(List<int>.filled(32, 7));

    test('la carte d\'un lot : mosaïque, expéditeur, suivi, fichiers de l\'expéditeur', () {
      final info = SafeboxShareInfo.fromJson({
        'id': 9, 'conversationId': 50, 'senderId': 3, 'kind': 'batch', 'name': 'Kribi 2026', 'family': 'photos',
        'plainBytes': 570, 'count': 4, 'families': {'photos': 2, 'videos': 1, 'documents': 1, 'pirate': 3},
        'available': true, 'isSender': true, 'availableCount': 3, 'savedCount': 1, 'revokedBySender': false,
        'sender': {'id': 3, 'name': 'Clarisse', 'avatarUrl': null},
        'tracking': {'members': 7, 'downloaded': 2, 'saved': 1},
        'fileIds': [11, 12, 13],
        'cover': [
          {'id': 101, 'position': 0, 'name': 'a.jpg', 'family': 'photos', 'plainBytes': 10, 'available': true, 'key': cle, 'previewUrl': 'https://p'},
          {'id': 102, 'position': 1, 'name': 'b.mp4', 'family': 'videos', 'plainBytes': 20, 'available': true, 'quality': 'hd'},
        ],
      });
      expect(info.isBatch, isTrue);
      expect(info.families, {SafeboxFamily.photos: 2, SafeboxFamily.videos: 1, SafeboxFamily.documents: 1});
      expect(info.sender!.name, 'Clarisse');
      expect(info.tracking!.received, 3);
      expect(info.tracking!.receivedByAll, isFalse);
      expect(info.fileIds, [11, 12, 13]);
      expect(info.cover.map((e) => e.name), ['a.jpg', 'b.mp4']);
      expect(info.cover.first.key, List<int>.filled(32, 7));
      expect(info.cover.last.quality, SafeboxQuality.hd);
    });

    test('numéros locaux : jamais ceux de mon coffre, ni d\'un autre partage', () {
      const element = SafeboxShareItem(
        shareId: 9, id: 101, position: 0, name: 'a.jpg', ext: 'jpg', mime: null,
        family: SafeboxFamily.photos, plainBytes: 1, available: true,
      );
      expect(element.localId, isNegative);
      expect(element.localId, isNot(-9));
      expect(element.localId, isNot(-101), reason: 'l\'élément 101 n\'est pas le partage 101');
      expect(element.asFile().id, element.localId);
      final seul = SafeboxShareInfo.fromJson({
        'id': 12, 'name': 'Contrat.pdf', 'family': 'documents', 'plainBytes': 20, 'available': true,
      });
      expect(seul.asItem().localId, -12, reason: 'un fichier seul garde le numéro de son partage');
      expect(seul.asItem().id, 0);
    });

    test('une ligne de « Reçus » : une seule vignette, ce que j\'en ai fait', () {
      final page = SafeboxReceivedPage.fromJson({
        'shares': [
          {
            'id': 5, 'kind': 'file', 'name': 'Plans.zip', 'family': 'documents', 'plainBytes': 3, 'available': true,
            'receivedAt': '2026-10-25T10:00:00Z', 'savedFileId': 77, 'quality': 'original',
            'cover': {'id': 0, 'position': 0, 'name': 'Plans.zip', 'family': 'documents', 'plainBytes': 3, 'available': true},
            'sender': {'id': 4, 'name': 'Paul'},
          },
        ],
        'nextCursor': 5,
      });
      expect(page.nextCursor, 5);
      final s = page.shares.single;
      expect(s.cover.single.localId, -5);
      expect(s.savedFileId, 77);
      expect(s.receivedAt, isNotNull);
    });

    test('le suivi, et la discussion du dernier partage d\'un fichier', () {
      final r = SafeboxShareRecipients.fromJson({
        'members': [
          {'alanyaID': 4, 'name': 'Lina', 'state': 'saved', 'at': '2026-10-26T09:25:00Z'},
          {'alanyaID': 5, 'name': 'Paul', 'state': 'downloaded'},
          {'alanyaID': 6, 'name': null, 'state': 'inconnu'},
        ],
        'tracking': {'members': 3, 'downloaded': 1, 'saved': 1},
      });
      expect(r.members.map((m) => m.state),
          [SafeboxRecipientState.saved, SafeboxRecipientState.downloaded, SafeboxRecipientState.pending]);
      expect(r.tracking.received, 2);
      expect(SafeboxSent.fromJson({'shares': 2, 'recipients': 3, 'received': 3, 'lastConversationId': 50})!.lastConversationId, 50);
      expect(SafeboxSent.fromJson({'shares': 1, 'recipients': 3})!.lastConversationId, isNull);
    });

    test('un envoi garde son groupe d\'un redémarrage à l\'autre', () {
      final j = SafeboxUploadJob(
        id: 'j', folderId: 1, name: 'a.pdf', mime: null, sourcePath: '/x', sourceSize: 1,
        sourceModifiedMs: 0, ownsSource: false, plainSize: 1, originalSize: null, compressed: false,
        shareConversationId: 42, shareGroup: 'g7',
      );
      expect(SafeboxUploadJob.fromJson(j.toJson()).shareGroup, 'g7');
      expect(SafeboxUploadJob.fromJson({...j.toJson()}..remove('shareGroup')).shareGroup, isNull);
    });
  });

  group('plusieurs fichiers du téléphone, un seul message', () {
    late Directory dossier;
    late List<Map<String, dynamic>> creations;
    late List<(int, SafeboxSharePayload)> messages;

    setUp(() async {
      dossier = await Directory.systemTemp.createTemp('coffre_lot9');
      creations = [];
      messages = [];
    });
    tearDown(() => dossier.delete(recursive: true));

    /// Faux serveur de l'API : il crée le partage demandé.
    http.Client api() => MockClient((req) async {
          if (req.method == 'POST' && req.url.path.endsWith('/safebox/shares')) {
            final corps = jsonDecode(req.body) as Map<String, dynamic>;
            creations.add(corps);
            final ids = (corps['fileIds'] as List?)?.cast<int>();
            final reponse = ids == null
                ? {'shareId': 30, 'kind': 'file', 'name': 'a.pdf', 'family': 'documents', 'plainBytes': 10, 'count': 1, 'cover': [corps['fileId']]}
                : {
                    'shareId': 31, 'kind': 'batch', 'name': corps['title'], 'family': 'documents', 'plainBytes': 20,
                    'count': ids.length, 'families': {'documents': ids.length}, 'cover': ids,
                  };
            return http.Response(jsonEncode(reponse), 201, headers: {'content-type': 'application/json; charset=utf-8'});
          }
          return http.Response('{"error":"absent","code":"NOT_FOUND"}', 404, headers: {'content-type': 'application/json'});
        });

    Future<SafeboxUploadJob> envoi(String id, {SafeboxUploadState etat = SafeboxUploadState.queued}) async {
      final f = File('${dossier.path}/$id.bin');
      await f.writeAsBytes(Uint8List(1000));
      final st = await f.stat();
      return SafeboxUploadJob(
        id: id, folderId: 16, name: '$id.pdf', mime: null, sourcePath: f.path, sourceSize: st.size,
        sourceModifiedMs: st.modified.millisecondsSinceEpoch, ownsSource: false, plainSize: 1000,
        originalSize: null, compressed: false, quality: 'original', state: etat,
        shareConversationId: 50, shareGroup: 'g1',
      );
    }

    Future<void> attendre(bool Function() condition, String quoi) async {
      for (var i = 0; i < 300; i += 1) {
        if (condition()) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('jamais : $quoi');
    }

    Future<(SafeboxController, _FauxTransport)> monter() async {
      // Le groupe tel que addFiles l'enregistre avant de préparer les fichiers.
      SharedPreferences.setMockInitialValues({
        'safebox_share_groups_v1': jsonEncode({'g1': {'conv': 50, 'title': '2 fichiers', 'files': []}}),
      });
      final transport = _FauxTransport();
      final c = SafeboxController(
        api: TalkyApiClient(client: api()),
        uploadManager: SafeboxUploadManager(
          transport: transport,
          store: _MemoireStore(),
          sleep: (_) async {},
          encrypt: (key, plain, plan) async => Uint8List(plan.cipherLength),
        ),
      );
      c.shareSender = (conv, payload) async => messages.add((conv, payload));
      addTearDown(c.dispose);
      return (c, transport);
    }

    test('le lot part quand le dernier envoi est arrivé, pas avant', () async {
      final (c, _) = await monter();
      final cle = Uint8List(32);
      await c.uploads.enqueue(await envoi('j1'), cle);
      await c.uploads.enqueue(await envoi('j2', etat: SafeboxUploadState.paused), cle);
      await attendre(() => c.uploads.jobs.first.state == SafeboxUploadState.completed, 'j1 arrivé');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(messages, isEmpty, reason: 'j2, en pause, retient le lot');

      await c.uploads.resume('j2');
      await attendre(() => messages.isNotEmpty, 'le message du lot');
      expect(creations, hasLength(1), reason: '$creations');
      expect(creations.single['fileIds'], [100, 101]);
      expect(creations.single['title'], '2 fichiers');
      final (conv, payload) = messages.single;
      expect(conv, 50);
      expect(payload.isBatch, isTrue);
      expect(payload.count, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('safebox_share_groups_v1')!), isEmpty, reason: 'le groupe est parti');
    });

    test('un envoi en échec ne retient pas les autres : le fichier arrivé part seul', () async {
      final (c, transport) = await monter();
      transport.refuser.add('j2.pdf');
      final cle = Uint8List(32);
      await c.uploads.enqueue(await envoi('j1'), cle);
      await c.uploads.enqueue(await envoi('j2'), cle);
      await attendre(() => messages.isNotEmpty, 'le message');
      expect(c.uploads.jobs.firstWhere((j) => j.id == 'j2').state, SafeboxUploadState.failed);
      expect(creations.single['fileId'], 100, reason: 'un seul fichier : un partage simple');
      expect(messages.single.$2.isBatch, isFalse);
    });
  });
}

/// Un faux transport qui reçoit tout, sauf les fichiers de [refuser].
class _FauxTransport implements SafeboxTransport {
  int prochainId = 100;
  final Set<String> refuser = {};
  final Map<int, int> tailles = {};

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
    String? quality,
    int previewSize = 0,
    Map<String, dynamic>? meta,
    String? sourceFp,
  }) async {
    if (refuser.contains(name)) throw TalkyException('refusé', 400, code: 'SAFEBOX_WRONG_FAMILY');
    final id = prochainId++;
    tailles[id] = plainSize;
    return SafeboxUploadTicket(
      fileId: id,
      blockSize: 1 << 20,
      blockCount: 1,
      size: size,
      blocks: [SafeboxSignedBlock(n: 1, size: 0, url: 'blk:$id:1')],
      preview: null,
      urlTtlSeconds: 86400,
    );
  }

  @override
  Future<SafeboxUploadStatus> status(int fileId) async =>
      const SafeboxUploadStatus(blockCount: 1, received: [], missing: [1], previewMissing: false);

  @override
  Future<({List<SafeboxSignedBlock> blocks, SafeboxSignedBlock? preview})> urls(
    int fileId, {
    List<int> blocks = const [],
    bool preview = false,
  }) async =>
      (blocks: [for (final n in blocks) SafeboxSignedBlock(n: n, size: 0, url: 'blk:$fileId:$n')], preview: null);

  @override
  Future<void> putBlock(String url, Uint8List bytes, {void Function(int sent)? onProgress}) async =>
      onProgress?.call(bytes.length);

  @override
  Future<SafeboxFile> complete(int fileId, Uint8List key) async => SafeboxFile(
        id: fileId, folderId: 16, name: 'f$fileId.pdf', ext: 'pdf', mime: null, family: SafeboxFamily.documents,
        plainBytes: tailles[fileId] ?? 0, storedBytes: 0, originalBytes: null, compressed: false,
        cipherFormat: kSafeboxCipherFormat, key: key, previewUrl: null,
      );

  @override
  Future<void> cancel(int fileId) async {}
}

class _MemoireStore implements SafeboxJobStore {
  List<SafeboxUploadJob> gardes = [];
  final Map<String, Uint8List> cles = {};
  @override
  Future<List<SafeboxUploadJob>> loadJobs() async => gardes;
  @override
  Future<void> saveJobs(List<SafeboxUploadJob> jobs) async => gardes = List.of(jobs);
  @override
  Future<Uint8List?> loadKey(String jobId) async => cles[jobId];
  @override
  Future<void> saveKey(String jobId, Uint8List key) async => cles[jobId] = key;
  @override
  Future<void> deleteKey(String jobId) async => cles.remove(jobId);
}
