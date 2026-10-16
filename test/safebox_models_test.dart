import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';

/// Réponses telles que les rend le backend (src/services/safebox/service.js).
void main() {
  final limites = SafeboxLimits.fromJson({
    'maxFileBytes': 1073741824,
    'blockBytes': 8388608,
    'maxPreviewBytes': 262144,
    'maxDepth': 5,
    'maxFolders': 500,
    'folderNameMax': 80,
    'fileNameMax': 180,
    'extensions': {
      'albums': ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'gif'],
      'videos': ['mp4', 'mov', 'm4v', 'mkv', '3gp', 'webm', 'avi'],
      'audios': ['mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus', 'amr'],
      'documents': ['pdf', 'docx', 'tif', 'tiff'],
    },
  });

  test('GET /api/safebox', () {
    final v = SafeboxOverview.fromJson({
      'quota': {
        'quotaBytes': 10737418240,
        'usedBytes': 7945689498,
        'pendingBytes': 0,
        'trashBytes': 120000,
        'byRoot': {
          'albums': {'bytes': 5000, 'files': 3},
          'videos': {'bytes': 0, 'files': 0},
          'audios': {'bytes': 0, 'files': 0},
          'documents': {'bytes': 12, 'files': 1},
        },
      },
      'roots': [
        {'id': 11, 'root': 'albums'},
        {'id': 12, 'root': 'videos'},
        {'id': 13, 'root': 'audios'},
        {'id': 14, 'root': 'documents'},
      ],
      'limits': {'maxFileBytes': 1073741824, 'blockBytes': 8388608, 'extensions': {}},
    });
    expect(v.rootIds[SafeboxRoot.documents], 14);
    expect(v.quota.byRoot[SafeboxRoot.albums]!.files, 3);
    expect(v.quota.ratio, closeTo(0.74, 0.01));
    expect(v.quota.freeBytes, 10737418240 - 7945689498);
    expect(v.limits.blockBytes, 8388608);
  });

  test('fichier : clé en base64, dates, aperçu', () {
    final cle = List<int>.generate(32, (i) => i);
    final f = SafeboxFile.fromJson({
      'id': 5,
      'folderId': 11,
      'name': 'Cérémonie.mp4',
      'ext': 'mp4',
      'mime': 'video/mp4',
      'family': 'videos',
      'plainBytes': 1000,
      'storedBytes': 1016,
      'originalBytes': 5000,
      'compressed': true,
      'cipherFormat': 'SBX1',
      'createdAt': '2026-10-15T10:00:00.000Z',
      'updatedAt': '2026-10-15T10:00:00.000Z',
      'key': base64Encode(cle),
      'previewUrl': 'https://s4/apercu',
    });
    expect(f.key, cle);
    expect(f.family, SafeboxRoot.videos);
    expect(f.createdAt!.toUtc().hour, 10);
    expect(f.compressed, isTrue);
  });

  test('dossier racine : sans nom ni parent', () {
    final d = SafeboxFolder.fromJson({'id': 11, 'parentId': null, 'root': 'albums', 'name': null, 'depth': 0});
    expect(d.isRoot, isTrue);
    expect(d.name, isNull);
  });

  test('famille par extension : même règle que le serveur', () {
    expect(limites.familyOf('photo.JPG'), SafeboxRoot.albums);
    expect(limites.familyOf('scan.tiff'), SafeboxRoot.documents);
    expect(limites.familyOf('film.mov'), SafeboxRoot.videos);
    expect(limites.familyOf('LISEZMOI'), SafeboxRoot.documents);
    expect(limites.familyOf('.cache'), SafeboxRoot.documents);
    expect(safeboxExtensionOf('archive.tar.gz'), 'gz');
  });

  test('ticket d\'envoi et état de reprise', () {
    final t = SafeboxUploadTicket.fromJson({
      'fileId': 9,
      'blockSize': 8388608,
      'blockCount': 2,
      'size': 9000000,
      'blocks': [
        {'n': 1, 'size': 8388608, 'url': 'https://a'},
        {'n': 2, 'size': 611392, 'url': 'https://b'},
      ],
      'preview': {'size': 4016, 'url': 'https://p'},
      'urlTtlSeconds': 86400,
    });
    expect(t.blocks.map((b) => b.n), [1, 2]);
    expect(t.preview!.size, 4016);
    final s = SafeboxUploadStatus.fromJson({'blockCount': 2, 'received': [1], 'missing': [2], 'previewMissing': true});
    expect(s.missing, [2]);
    expect(s.previewMissing, isTrue);
  });
}
