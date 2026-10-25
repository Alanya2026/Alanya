// Erreurs V1b (contrat §4b, fixture erreurs-v1b.json) : quotas, limite de
// débit et « fonctionnalité fermée », traduits en fr, en et zh.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/errors/app_error.dart';
import 'package:talky_flutter/core/errors/error_presenter.dart';
import 'package:talky_flutter/core/services/stickers/sticker_repository.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_api_client.dart';

void main() {
  final contrat =
      jsonDecode(
            File('test/fixtures/stickers/erreurs-v1b.json').readAsStringSync(),
          )
          as Map<String, dynamic>;

  String texte(String lang, String code) {
    final l = lookupAppLocalizations(Locale(lang));
    final statut = (contrat[code] as Map)['status'] as int;
    return presenterErreur(
      l,
      TalkyException('prose du serveur', statut, code: code),
      domaine: ErrorDomain.stickers,
      journaliser: false,
      avecDiagnostic: false,
    );
  }

  for (final lang in ['fr', 'en', 'zh']) {
    test(
      'quotas et débit : un texte propre par code ($lang), jamais la prose',
      () {
        final codes = [
          'STICKER_QUOTA_EXCEEDED',
          'STICKER_PACK_LIMIT',
          'RATE_LIMITED',
        ];
        final vus = <String>{};
        for (final c in codes) {
          final t = texte(lang, c);
          expect(t, isNotEmpty);
          expect(t, isNot(contains('prose')));
          vus.add(t);
        }
        expect(vus, hasLength(codes.length));
      },
    );
  }

  test(
    'RATE_LIMITED : phrase dédiée, distincte du repli « trop de tentatives »',
    () {
      final l = lookupAppLocalizations(const Locale('fr'));
      final generique = presenterErreur(
        l,
        TalkyException('x', 429),
        domaine: ErrorDomain.stickers,
        journaliser: false,
        avecDiagnostic: false,
      );
      expect(texte('fr', 'RATE_LIMITED'), isNot(generique));
      expect(texte('fr', 'RATE_LIMITED'), contains('minute'));
    },
  );

  test(
    'les limites chiffrées figurent dans les messages (200 stickers, packs)',
    () {
      expect(texte('fr', 'STICKER_QUOTA_EXCEEDED'), contains('200'));
      expect(texte('en', 'STICKER_QUOTA_EXCEEDED'), contains('200'));
      expect(texte('zh', 'STICKER_QUOTA_EXCEEDED'), contains('200'));
    },
  );

  test('statuts de la fixture alignés sur le contrat §4b', () {
    int s(String c) => (contrat[c] as Map)['status'] as int;
    expect(s('STICKER_PACK_LIMIT'), 409);
    expect(s('STICKER_QUOTA_EXCEEDED'), 429);
    expect(s('RATE_LIMITED'), 429);
    expect(s('STICKER_PACK_UNAVAILABLE'), 404);
    expect(s('NOT_FOUND'), 404);
  });

  group('« fermé » ≠ « introuvable »', () {
    test('404 sans code ou NOT_FOUND générique : module fermé', () {
      expect(
        StickerRepository.isModuleClosed(TalkyException('x', 404)),
        isTrue,
      );
      expect(
        StickerRepository.isModuleClosed(
          TalkyException('x', 404, code: 'NOT_FOUND'),
        ),
        isTrue,
      );
    });
    test('404 porteur d\'un code de sticker : réponse normale', () {
      for (final c in ['STICKER_PACK_UNAVAILABLE', 'STICKER_NOT_FOUND']) {
        expect(
          StickerRepository.isModuleClosed(TalkyException('x', 404, code: c)),
          isFalse,
        );
      }
    });
    test('autres statuts : jamais fermé', () {
      expect(
        StickerRepository.isModuleClosed(TalkyException('x', 500)),
        isFalse,
      );
      expect(StickerRepository.isModuleClosed(TalkyException('x', 0)), isFalse);
      expect(
        StickerRepository.isModuleClosed(
          TalkyException('x', 403, code: 'NOT_FOUND'),
        ),
        isFalse,
      );
    });
  });
}
