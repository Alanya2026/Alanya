import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/stickers/sticker_trust.dart';

/// Garde « l'appareil ne télécharge un sticker que chez Alanya ».
void main() {
  group('isTrustedStickerUrl', () {
    // Les formes légitimes telles que le serveur les génère (stickerAsset.js) :
    // bucket public (key officielle ou perso) et repli `/uploads/<clé>`.
    test('URLs Alanya acceptées', () {
      const bonnes = [
        'https://www.alanya237.com/uploads/official/stickers/mboa/4812_ab12cd34.webp',
        'https://www.alanya237.com/official/stickers/mboa/4812_ab12cd34.webp',
        'https://profilemedia.s3.us-west-004.backblazeb2.com/official/stickers/mboa/4812_ab12cd34.webp',
        'https://profilemedia.s3.us-west-004.backblazeb2.com/stickers/u/42/sel16_sha256.webp',
        'https://pub-6f2a31d45e01d9a0.r2.dev/official/stickers/mboa/4812_ab12cd34.webp',
        'https://www.alanya237.com/uploads/official/stickers/mboa/4812_ab12cd34_t.webp',
      ];
      for (final u in bonnes) {
        expect(StickerTrust.isTrustedStickerUrl(u), isTrue, reason: u);
      }
    });

    test('hôte non Alanya refusé, même avec un chemin de sticker', () {
      const mauvaises = [
        // SSRF : jamais les métadonnées cloud.
        'http://169.254.169.254/latest/meta-data/',
        'https://169.254.169.254/official/stickers/x.webp',
        'http://evil.example/official/stickers/1_ab.webp',
        'https://evil.example/stickers/u/1/x.webp',
        'https://www.google.com/stickers/u/1/x.webp',
        // Nom d'hôte voisin, pas le bon.
        'https://www.alanya237.com.evil.example/official/stickers/x.webp',
        'https://evilwww.alanya237.com/official/stickers/x.webp',
        // Hôte littéral, pas un sous-domaine de bucket.
        'https://backblazeb2.com/stickers/u/1/x.webp',
        'https://r2.dev/official/stickers/x.webp',
      ];
      for (final u in mauvaises) {
        expect(StickerTrust.isTrustedStickerUrl(u), isFalse, reason: u);
      }
    });

    test('fausses formes : userinfo, mauvais schéma, mauvais chemin', () {
      const invalides = [
        // `user:pass@` même devant un hôte de confiance.
        'https://evil.example@www.alanya237.com/official/stickers/x.webp',
        'https://user:pass@profilemedia.s3.us-west-004.backblazeb2.com/official/stickers/x.webp',
        // Pas de sticker.
        'https://www.alanya237.com/uploads/media/2026/10/11/a.webp',
        'https://www.alanya237.com/uploads/avatars/x.webp',
        // Schéma hors http/https.
        'file:///etc/passwd',
        'ftp://www.alanya237.com/official/stickers/x.webp',
        // Fragment ou query ne suffisent pas : il faut le chemin.
        'https://www.alanya237.com/?official/stickers/x.webp',
        // Relatif / invalide / vide.
        '/uploads/official/stickers/x.webp',
        'not a url',
      ];
      for (final u in invalides) {
        expect(StickerTrust.isTrustedStickerUrl(u), isFalse, reason: u);
      }
    });

    test('null, chaîne vide ou blancs : refus', () {
      expect(StickerTrust.isTrustedStickerUrl(null), isFalse);
      expect(StickerTrust.isTrustedStickerUrl(''), isFalse);
      expect(StickerTrust.isTrustedStickerUrl('   '), isFalse);
    });
  });
}