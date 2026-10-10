// Un téléchargement de média qui échoue pour une raison passagère est retenté.
//
// Le 9 octobre 2026, une panne du stockage a fait échouer tous les
// téléchargements, chaque échec étant traité comme définitif (groupe 3GI 2029,
// bug A3).
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/media_cache_service.dart';

void main() {
  test('429, 5xx et erreur réseau : nouvel essai, délai croissant', () {
    for (final status in [429, 500, 502, 503, null]) {
      expect(delaiAvantNouvelEssai(tentative: 1, status: status),
          const Duration(seconds: 2),
          reason: '$status');
      expect(delaiAvantNouvelEssai(tentative: 2, status: status),
          const Duration(seconds: 5),
          reason: '$status');
    }
  });

  test('au-delà du nombre de tentatives : on abandonne', () {
    expect(
      delaiAvantNouvelEssai(
          tentative: kMediaDownloadRetries + 1, status: 503),
      isNull,
    );
  });

  test('4xx ordinaire (403, 404, 410) : jamais de nouvel essai', () {
    for (final status in [400, 403, 404, 410]) {
      expect(delaiAvantNouvelEssai(tentative: 1, status: status), isNull,
          reason: '$status');
    }
  });

  test('Retry-After respecté, plafonné à 30 s', () {
    expect(
      delaiAvantNouvelEssai(tentative: 1, status: 429, retryAfter: '7'),
      const Duration(seconds: 7),
    );
    expect(
      delaiAvantNouvelEssai(tentative: 1, status: 429, retryAfter: '600'),
      const Duration(seconds: 30),
    );
    expect(
      delaiAvantNouvelEssai(tentative: 1, status: 429, retryAfter: 'demain'),
      const Duration(seconds: 2),
    );
  });
}
