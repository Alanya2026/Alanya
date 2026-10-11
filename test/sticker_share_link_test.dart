// Lien de partage d'un pack (V1b) : fabrication `https://www.alanya237.com/s/…`
// et lecture stricte (https + hôte de LegalUrls, ou alanya://sticker/…).
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/config/legal_urls.dart';
import 'package:talky_flutter/core/services/qr_deep_link_service.dart';
import 'package:talky_flutter/core/services/stickers/sticker_share_link.dart';

const kToken = 'AbCdEfGh_-0123456789xYzQ'; // 24 caractères du jeton

void main() {
  test('le jeton d\'essai a bien 24 caractères', () {
    expect(kToken.length, 24);
    expect(StickerShareLink.isToken(kToken), isTrue);
  });

  group('fabrication', () {
    test('build : https://www.alanya237.com/s/<jeton> (hôte de LegalUrls)', () {
      expect(StickerShareLink.build(kToken), 'https://www.alanya237.com/s/$kToken');
      expect(StickerShareLink.build(kToken), startsWith('${LegalUrls.baseHost}/s/'));
    });

    test('buildApp : alanya://sticker/<jeton>', () {
      expect(StickerShareLink.buildApp(kToken), 'alanya://sticker/$kToken');
    });

    test('aller-retour : ce qu\'on fabrique se relit', () {
      expect(StickerShareLink.parse(StickerShareLink.build(kToken)), kToken);
      expect(StickerShareLink.parse(StickerShareLink.buildApp(kToken)), kToken);
    });
  });

  group('lecture : formes valides', () {
    test('jeton nu, avec espaces et retours', () {
      expect(StickerShareLink.parse(kToken), kToken);
      expect(StickerShareLink.parse('  $kToken\n'), kToken);
    });

    test('lien https www.alanya237.com/s/<jeton>', () {
      expect(StickerShareLink.parse('https://www.alanya237.com/s/$kToken'), kToken);
      expect(StickerShareLink.fromUri(Uri.parse('https://www.alanya237.com/s/$kToken')), kToken);
      // Hôte et schéma sont insensibles à la casse ; requête et ancre ignorées.
      expect(StickerShareLink.parse('HTTPS://WWW.ALANYA237.COM/s/$kToken?utm=x#a'), kToken);
      expect(StickerShareLink.parse('https://www.alanya237.com/s/$kToken/'), kToken);
      expect(StickerShareLink.parse('https://www.alanya237.com:443/s/$kToken'), kToken);
    });

    test('lien alanya://sticker/<jeton>', () {
      expect(StickerShareLink.fromUri(Uri.parse('alanya://sticker/$kToken')), kToken);
    });

    test('texte collé contenant le lien (ponctuation autour)', () {
      expect(
        StickerShareLink.parse('Mon pack : https://www.alanya237.com/s/$kToken\nCode : $kToken'),
        kToken,
      );
      expect(StickerShareLink.parse('Voir (https://www.alanya237.com/s/$kToken).'), kToken);
      expect(StickerShareLink.parse('Voir https://www.alanya237.com/s/$kToken !'), kToken);
      expect(StickerShareLink.parse('Mon pack : alanya://sticker/$kToken'), kToken);
    });

    test('le message partagé (lien + code) se relit', () {
      final texte = 'Mon pack de stickers « Fête » sur Alanya : '
          '${StickerShareLink.build(kToken)}\nCode : $kToken';
      expect(StickerShareLink.parse(texte), kToken);
    });
  });

  group('lecture : refus', () {
    String? p(String s) => StickerShareLink.fromUri(Uri.parse(s));

    test('jeton mal formé : trop court, trop long, caractère interdit', () {
      expect(p('https://www.alanya237.com/s/abc'), isNull);
      expect(p('https://www.alanya237.com/s/${kToken}x'), isNull);
      expect(p('https://www.alanya237.com/s/${kToken.substring(1)}!'), isNull);
      expect(p('alanya://sticker/abc'), isNull);
      expect(p('alanya://sticker/${kToken}x'), isNull);
      expect(StickerShareLink.parse('abc'), isNull);
      expect(StickerShareLink.parse('${kToken}x'), isNull);
    });

    test('autre hôte', () {
      expect(p('https://example.com/s/$kToken'), isNull);
      expect(p('https://alanya237.com/s/$kToken'), isNull);
      expect(p('https://www.alanya237.com.evil.example/s/$kToken'), isNull);
      expect(p('https://evil-www.alanya237.com/s/$kToken'), isNull);
      expect(StickerShareLink.parse('https://example.com/s/$kToken'), isNull);
    });

    test('http (non chiffré) refusé', () {
      expect(p('http://www.alanya237.com/s/$kToken'), isNull);
      expect(StickerShareLink.parse('http://www.alanya237.com/s/$kToken'), isNull);
    });

    test('userinfo et port refusés', () {
      expect(p('https://user@www.alanya237.com/s/$kToken'), isNull);
      expect(p('https://user:pw@www.alanya237.com/s/$kToken'), isNull);
      expect(p('https://www.alanya237.com@evil.example/s/$kToken'), isNull);
      expect(p('https://evil.example@www.alanya237.com/s/$kToken'), isNull);
      expect(p('https://www.alanya237.com:8443/s/$kToken'), isNull);
      expect(p('alanya://user@sticker/$kToken'), isNull);
    });

    test('mauvais chemin', () {
      expect(p('https://www.alanya237.com/$kToken'), isNull);
      expect(p('https://www.alanya237.com/stickers/$kToken'), isNull);
      expect(p('https://www.alanya237.com/x/s/$kToken'), isNull);
      expect(p('https://www.alanya237.com/s/'), isNull);
      expect(p('https://www.alanya237.com/q/c/$kToken'), isNull);
      expect(p('alanya://other/$kToken'), isNull);
      expect(p('alanya://sticker/x/$kToken'), isNull);
    });

    test('autres schémas, vide, null', () {
      expect(p('ftp://www.alanya237.com/s/$kToken'), isNull);
      expect(p('javascript:alert(1)'), isNull);
      expect(StickerShareLink.parse(''), isNull);
      expect(StickerShareLink.parse('   '), isNull);
      expect(StickerShareLink.parse(null), isNull);
      expect(StickerShareLink.fromUri(null), isNull);
    });

    test('un lien d\'identité QR n\'est pas un lien de pack', () {
      expect(p('alanya://q/u/$kToken'), isNull);
      expect(p('https://www.alanya237.com/q/c/$kToken'), isNull);
      expect(StickerShareLink.parse('alanya://q/c/$kToken'), isNull);
    });
  });

  group('QrDeepLinkService : /s/ n\'est pas pris pour une identité', () {
    test('le lien de pack n\'est pas un jeton d\'identité', () {
      expect(
        QrDeepLinkService.extractIdentityToken(
          Uri.parse('https://www.alanya237.com/s/$kToken'),
        ),
        isNull,
      );
    });

    test('les liens /q/ restent des identités, pas des packs', () {
      final uri = Uri.parse('https://www.alanya237.com/q/c/$kToken');
      expect(QrDeepLinkService.extractIdentityToken(uri)?.kind, 'c');
      expect(StickerShareLink.fromUri(uri), isNull);
    });
  });
}
