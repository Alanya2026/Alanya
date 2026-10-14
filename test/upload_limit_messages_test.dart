import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';

/// Les messages de refus disent le plafond DU COMPTE (100 ou 200 Mo), pas un
/// nombre écrit en dur : un abonné qui dépasse 200 Mo ne doit pas lire « limite : 100 ».
void main() {
  for (final entry in {
    'fr': (video: 'Limite : 200 Mo', file: 'Limite : 200 Mo', skipped: 'limite 200 Mo'),
    'en': (video: 'Limit: 200 MB', file: 'Limit: 200 MB', skipped: '200 MB limit'),
    'zh': (video: '上限：200 MB', file: '上限：200 MB', skipped: '200 MB 上限'),
  }.entries) {
    test('${entry.key} : le plafond annoncé est celui qu\'on passe', () {
      final l10n = lookupAppLocalizations(Locale(entry.key));
      expect(l10n.videoTooLarge('120.0', 200), contains(entry.value.video));
      expect(l10n.fileTooLarge('120.0', 200), contains(entry.value.file));
      expect(l10n.filesSkippedTooLarge(3, 200), contains(entry.value.skipped));
      expect(l10n.fileTooLarge('80.0', 100), isNot(contains('200')));
      expect(l10n.fileTooLarge('80.0', 100), contains('100'));
      expect(l10n.videoTooLarge('120.0', 200), contains('120.0'));
      expect(l10n.filesSkippedTooLarge(3, 200), contains('3'));
    });
  }
}
