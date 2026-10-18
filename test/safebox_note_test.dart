import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/errors/app_error.dart';
import 'package:talky_flutter/core/errors/error_presenter.dart';
import 'package:talky_flutter/core/services/safebox/safebox_cipher.dart';
import 'package:talky_flutter/core/services/safebox/safebox_models.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';

void main() {
  group('commentaire d\'une photo', () {
    test('texte et audio lus depuis le serveur', () {
      final f = SafeboxFile.fromJson({
        'id': 4, 'family': 'albums', 'name': 'Plage.jpg',
        'note': {
          'text': 'Mariage de Paul',
          'audio': {'durationMs': 83000, 'plainBytes': 1000, 'storedBytes': 1016, 'url': 'https://u', 'key': base64Encode(List<int>.filled(32, 2))},
        },
      });
      expect(f.note!.text, 'Mariage de Paul');
      expect(f.note!.audio!.durationLabel, '1:23');
      expect(f.note!.audio!.key, List<int>.filled(32, 2));
    });

    test('rien d\'utile : pas de commentaire', () {
      for (final j in [null, 'x', <String, dynamic>{}, {'text': '   '}, {'text': null, 'audio': {'url': 'u'}}]) {
        expect(SafeboxNote.fromJson(j), isNull, reason: '$j');
      }
      expect(SafeboxFile.fromJson({'id': 1}).note, isNull, reason: 'serveur sans la migration 107');
      expect(SafeboxNote.fromJson({'text': 'seul'})!.audio, isNull);
    });

    test('l\'audio (5 minutes au plus) tient en un bloc et se relit', () {
      final cle = Uint8List.fromList(List<int>.generate(32, (i) => i));
      // 5 minutes à 32 kbit/s ≈ 1,2 Mo : deux morceaux de 1 Mio dans un bloc de 8 Mio.
      final clair = Uint8List.fromList(List<int>.generate(1200000, (i) => (i * 13) & 0xff));
      final plan = safeboxPlanBlock(1, plainSize: clair.length, blockSize: 8 << 20);
      expect(plan.plainLength, clair.length);
      final chiffre = safeboxEncryptBlockSync(cle, clair, plan);
      expect(chiffre.length, safeboxEncryptedLength(clair.length));
      expect(safeboxDecryptBlockSync(cle, chiffre, plan), clair);
    });

    test('les refus du serveur se lisent en clair', () {
      final fr = lookupAppLocalizations(const Locale('fr'));
      String texte(String code) => presenterErreur(fr, TalkyException('x', 400, code: code),
          domaine: ErrorDomain.generique, journaliser: false, avecDiagnostic: false);
      expect(texte('SAFEBOX_NOTE_TOO_LONG'), fr.safeboxNoteTooLong);
      expect(texte('SAFEBOX_NOTE_UNAVAILABLE'), fr.safeboxNoteUnavailable);
    });
  });
}
