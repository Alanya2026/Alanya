// Codes d'erreur stickers : chacun a un texte propre dans les trois langues,
// aligné sur erreurs.json du contrat.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/errors/afficher_erreur.dart';
import 'package:talky_flutter/core/errors/app_error.dart';
import 'package:talky_flutter/core/errors/error_presenter.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';

void main() {
  final contrat = jsonDecode(
          File('test/fixtures/stickers/erreurs.json').readAsStringSync())
      as Map<String, dynamic>;

  test('kStickerErrorCodes = les codes STICKER_* du contrat', () {
    final attendus =
        contrat.keys.where((k) => k.startsWith('STICKER_')).toSet();
    expect(kStickerErrorCodes.toSet(), attendus);
  });

  for (final lang in ['fr', 'en', 'zh']) {
    test('chaque code a son texte ($lang), distinct du repli', () {
      final l = lookupAppLocalizations(Locale(lang));
      final repli = presenterErreur(l, TalkyException('x', 400),
          domaine: ErrorDomain.stickers,
          journaliser: false,
          avecDiagnostic: false);
      final vus = <String>{};
      for (final code in kStickerErrorCodes) {
        final statut = (contrat[code] as Map)['status'] as int;
        final t = presenterErreur(l, TalkyException('prose', statut, code: code),
            domaine: ErrorDomain.stickers,
            journaliser: false,
            avecDiagnostic: false);
        expect(t, isNotEmpty);
        expect(t, isNot(repli), reason: code);
        expect(t, isNot(contains('prose')));
        vus.add(t);
      }
      expect(vus, hasLength(kStickerErrorCodes.length));
    });
  }

  test('SUBSCRIPTION_REQUIRED stickers_premium est un refus Plus', () {
    final e = TalkyException('x', 403,
        code: 'SUBSCRIPTION_REQUIRED',
        details: {'feature': 'stickers_premium'});
    final refus = refusAlanyaPlus(e);
    expect(refus, isNotNull);
    expect(refus!.feature?.code, 'stickers_premium');
    expect(refus.outgoing, isFalse);
  });
}
