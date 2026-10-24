import 'dart:convert';

import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/errors/app_error.dart';
import 'package:talky_flutter/core/errors/error_presenter.dart';
import 'package:talky_flutter/core/services/chat/conversation_merge.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/core/services/safebox/safebox_received_files.dart';
import 'package:talky_flutter/core/services/safebox/safebox_upload_manager.dart';
import 'package:talky_flutter/core/theme/locale_controller.dart';
import 'package:talky_flutter/core/utils/safebox_share_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(LocaleController.new);

  group('message de type 11', () {
    test('aller-retour du contenu, tel que le réécrit le serveur', () {
      const p = SafeboxSharePayload(
        share: 7, name: 'Mariage.mp4', size: 880803840, mime: 'video/mp4',
        family: SafeboxFamily.videos, blur: 'AAAA',
      );
      final relu = SafeboxSharePayload.tryParse(p.encode())!;
      expect(relu.share, 7);
      expect(relu.name, 'Mariage.mp4');
      expect(relu.size, 880803840);
      expect(relu.family, SafeboxFamily.videos);
      expect(relu.blur, 'AAAA');
      expect(jsonDecode(p.encode())['v'], 1);
    });

    test('contenu illisible ou sans partage : rien', () {
      for (final c in [null, '', 'bonjour', '{"share":"7"}', '{"share":0}', '[1]']) {
        expect(SafeboxSharePayload.tryParse(c), isNull, reason: '$c');
      }
    });

    test('aperçu de la liste des discussions : le nom, jamais le JSON', () {
      final c = jsonEncode({'v': 1, 'share': 3, 'name': 'Acte.pdf', 'size': 10, 'family': 'documents'});
      expect(ConversationMerge.previewForMedia(kSafeboxShareMessageType, c, '📦 Acte.pdf · 1 Ko'), '📦 Acte.pdf');
      expect(ConversationMerge.previewForMedia(kSafeboxShareMessageType, 'abîmé', null), resolveL10n().safeboxShareFallback);
    });
  });

  test('un envoi garde sa discussion de partage d\'un redémarrage à l\'autre', () {
    final j = SafeboxUploadJob(
      id: 'j', folderId: 1, name: 'a.pdf', mime: null, sourcePath: '/x', sourceSize: 1,
      sourceModifiedMs: 0, ownsSource: false, plainSize: 1, originalSize: null, compressed: false,
      shareConversationId: 42,
    );
    expect(SafeboxUploadJob.fromJson(j.toJson()).shareConversationId, 42);
    final sans = SafeboxUploadJob.fromJson({...j.toJson(), 'shareConversationId': null});
    expect(sans.shareConversationId, isNull);
  });

  test('un fichier reçu se présente comme un fichier, avec un numéro local négatif', () {
    final info = SafeboxShareInfo.fromJson({
      'id': 12, 'conversationId': 5, 'senderId': 3, 'name': 'Contrat.pdf', 'mime': 'application/pdf',
      'family': 'documents', 'plainBytes': 20, 'available': true, 'isSender': false,
      'storedBytes': 36, 'key': base64Encode(List<int>.filled(32, 1)), 'previewUrl': 'https://p',
      'downloadsLeft': 2, 'savedFileId': null,
    });
    final f = info.asFile();
    expect(f.id, -12, reason: 'jamais le même numéro qu\'un fichier de mon coffre');
    expect(f.ext, 'pdf');
    expect(f.key, List<int>.filled(32, 1));
    expect(info.downloadsLeft, 2);
  });

  group('détails de la carte (durée, définition, pages)', () {
    test('libellés', () {
      final v = SafeboxMeta.fromJson({'durationMs': 767000, 'width': 1920, 'height': 1080})!;
      expect(v.durationLabel, '12:47');
      expect(v.definitionLabel, '1080p');
      expect(SafeboxMeta.fromJson({'durationMs': 3723000})!.durationLabel, '1:02:03');
      expect(SafeboxMeta.fromJson({'width': 1080, 'height': 1920})!.definitionLabel, '1080p', reason: 'vidéo verticale');
      expect(SafeboxMeta.fromJson({'width': 3840, 'height': 2160})!.definitionLabel, '4K');
      expect(SafeboxMeta.fromJson({'width': 1280, 'height': 718})!.definitionLabel, '720p');
      expect(SafeboxMeta.fromJson({'pages': 4})!.definitionLabel, isNull);
    });

    test('rien d\'utile : null', () {
      for (final j in [null, 'x', <String, dynamic>{}, {'width': 1920}, {'durationMs': 0, 'title': '  '}]) {
        expect(SafeboxMeta.fromJson(j), isNull, reason: '$j');
      }
    });

    test('voyagent dans le message, et dans un envoi qui reprend après redémarrage', () {
      const meta = SafeboxMeta(durationMs: 1000, title: 'Titre', artist: 'Artiste');
      const p = SafeboxSharePayload(share: 2, name: 'a.mp3', size: 9, family: SafeboxFamily.audios, meta: meta);
      final relu = SafeboxSharePayload.tryParse(p.encode())!;
      expect(relu.meta!.title, 'Titre');
      expect(relu.meta!.artist, 'Artiste');
      expect(relu.meta!.durationMs, 1000);
      final j = SafeboxUploadJob(
        id: 'j', folderId: 1, name: 'a.mp3', mime: null, sourcePath: '/x', sourceSize: 1,
        sourceModifiedMs: 0, ownsSource: false, plainSize: 1, originalSize: null, compressed: false,
        meta: meta.toJson(),
      );
      expect(SafeboxUploadJob.fromJson(j.toJson()).meta, {'durationMs': 1000, 'title': 'Titre', 'artist': 'Artiste'});
    });
  });

  group('badge de l\'expéditeur', () {
    test('lu depuis la liste du dossier', () {
      final f = SafeboxFile.fromJson({
        'id': 1, 'folderId': 2, 'name': 'v.mp4', 'family': 'videos', 'plainBytes': 5, 'storedBytes': 5,
        'meta': {'durationMs': 5000}, 'sent': {'shares': 2, 'recipients': 4, 'received': 3},
      });
      expect(f.meta!.durationLabel, '0:05');
      expect(f.sent!.shares, 2);
      expect(f.sent!.receivedByAll, isFalse);
      expect(SafeboxSent.fromJson({'shares': 1, 'recipients': 3, 'received': 3})!.receivedByAll, isTrue);
      expect(SafeboxSent.fromJson({'shares': 1, 'recipients': 3, 'received': null})!.receivedByAll, isFalse,
          reason: 'le serveur ne sait pas : on ne promet rien');
      expect(SafeboxSent.fromJson({'shares': 0, 'recipients': 0}), isNull);
      expect(SafeboxFile.fromJson({'id': 1, 'sent': null}).sent, isNull);
    });
  });

  group('fichiers reçus dans Téléchargements/Alanya', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('copie retenue, puis oubliée quand l\'inscrit la supprime', () async {
      final existants = <String>{};
      final copies = <String>[];
      final r = SafeboxReceivedFiles(
        publish: (path, name, mime, subdir) async {
          copies.add('$subdir/$name ($mime)');
          existants.add('content://dl/1');
          return 'content://dl/1';
        },
        exists: (loc) async => existants.contains(loc),
        open: (loc, mime) async => true,
      );
      expect(await r.location(5), isNull);
      final loc = await r.publish(File('/tmp/x'), shareId: 5, name: 'Mariage.mp4', family: SafeboxFamily.videos);
      expect(loc, 'content://dl/1');
      expect(copies, ['Alanya/Alanya Videos/Mariage.mp4 (video/mp4)']);
      expect(await r.location(5), 'content://dl/1');
      existants.clear();
      expect(await r.location(5), isNull);
      existants.add('content://dl/1');
      expect(await r.location(5), isNull, reason: 'oublié pour de bon');
    });

    test('copie impossible : rien de retenu', () async {
      final r = SafeboxReceivedFiles(
        publish: (path, name, mime, subdir) async => throw Exception('plein'),
        exists: (loc) async => true,
      );
      expect(await r.publish(File('/tmp/x'), shareId: 6, name: 'a.pdf', family: SafeboxFamily.documents), isNull);
      expect(await r.location(6), isNull);
    });

    test('rangement et type', () {
      expect(SafeboxReceivedFiles.subdirFor(SafeboxFamily.documents), 'Alanya/Alanya Documents');
      expect(SafeboxReceivedFiles.subdirFor(SafeboxFamily.audios), 'Alanya/Alanya Audio');
      expect(SafeboxReceivedFiles.mimeFor('acte.pdf', null), 'application/pdf');
      expect(SafeboxReceivedFiles.mimeFor('donnees.inconnu', null), 'application/octet-stream');
    });
  });

  group('fichier perdu chez l\'hébergeur, fichier retiré par la modération', () {
    test('lus depuis le serveur', () {
      expect(SafeboxFile.fromJson({'id': 1, 'lost': true}).lost, isTrue);
      expect(SafeboxFile.fromJson({'id': 1}).lost, isFalse, reason: 'serveur sans la migration 106');
      final carte = SafeboxShareInfo.fromJson({'id': 3, 'available': false, 'removedByModeration': true});
      expect(carte.removedByModeration, isTrue);
      expect(SafeboxShareInfo.fromJson({'id': 3, 'available': true, 'lost': true}).lost, isTrue);
    });

    test('le refus de téléchargement se lit en clair', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      final texte = presenterErreur(
        fr,
        TalkyException('Fichier endommagé', 410, code: 'SAFEBOX_FILE_LOST'),
        domaine: ErrorDomain.generique,
        journaliser: false,
        avecDiagnostic: false,
      );
      expect(texte, fr.safeboxFileLostBody);
    });
  });
}
