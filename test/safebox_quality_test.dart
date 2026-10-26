import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/safebox/safebox_quality.dart';

/// Les trois formats du coffre (décision du 24/10/2026, conception section 05).
void main() {
  const mo = 1000 * 1000;

  group('profils', () {
    test('vidéo : 720p ou 480p, H.265 quand permis, H.264 plus lourd en repli', () {
      final hd = safeboxVideoProfile(SafeboxQuality.hd, hevc: true)!;
      expect((hd.shortSide, hd.longSide, hd.videoBitrate, hd.mime), (720, 1280, 1300000, 'video/hevc'));
      final c = safeboxVideoProfile(SafeboxQuality.compressed, hevc: false)!;
      expect((c.shortSide, c.videoBitrate, c.mime), (480, 1000000, 'video/avc'));
      expect(safeboxVideoProfile(SafeboxQuality.original, hevc: true), isNull);
    });

    test('photo et musique', () {
      expect(safeboxPhotoProfile(SafeboxQuality.hd)!.longSide, 2560);
      expect(safeboxPhotoProfile(SafeboxQuality.compressed)!.longSide, 1600);
      expect(safeboxAudioBitrate(SafeboxQuality.hd), 128000);
      expect(safeboxAudioBitrate(SafeboxQuality.compressed), 64000);
    });
  });

  group('vidéo', () {
    const film = SafeboxMediaFacts(sizeBytes: 1300 * mo, width: 1920, height: 1080, durationMs: 600000, frameRate: 30);

    test('1080p : convertie en HD comme en Compressé', () {
      for (final q in [SafeboxQuality.hd, SafeboxQuality.compressed]) {
        expect(safeboxShouldTranscodeVideo(film, safeboxVideoProfile(q, hevc: true)!), isTrue);
      }
    });

    test('10 minutes de 1080p : ≈ 102 Mo en HD H.265, ≈ 50 Mo en Compressé, ≈ 155 Mo en HD H.264', () {
      expect(safeboxEstimateVideoBytes(film, SafeboxQuality.hd, hevc: true), 102300000);
      expect(safeboxEstimateVideoBytes(film, SafeboxQuality.compressed, hevc: true), 49800000);
      expect(safeboxEstimateVideoBytes(film, SafeboxQuality.hd, hevc: false), 154800000);
      expect(safeboxEstimateVideoBytes(film, SafeboxQuality.original, hevc: true), 1300 * mo);
    });

    test('déjà légère (720p à 1 Mbit/s) : telle quelle en HD, convertie en Compressé', () {
      const whatsapp = SafeboxMediaFacts(sizeBytes: 7500000, width: 1280, height: 720, durationMs: 60000);
      expect(safeboxEstimateVideoBytes(whatsapp, SafeboxQuality.hd, hevc: true), 7500000);
      expect(safeboxShouldTranscodeVideo(whatsapp, safeboxVideoProfile(SafeboxQuality.compressed, hevc: true)!), isTrue);
    });

    test('portrait, 60 images/s, petit fichier, métadonnées absentes', () {
      final hd = safeboxVideoProfile(SafeboxQuality.hd, hevc: true)!;
      expect(safeboxShouldTranscodeVideo(const SafeboxMediaFacts(sizeBytes: 50 * mo, width: 720, height: 1280, durationMs: 400000), hd),
          isFalse, reason: '720p en portrait, débit sous la cible');
      expect(safeboxShouldTranscodeVideo(const SafeboxMediaFacts(sizeBytes: 50 * mo, width: 1280, height: 720, durationMs: 400000, frameRate: 60), hd),
          isTrue);
      expect(safeboxShouldTranscodeVideo(const SafeboxMediaFacts(sizeBytes: 900000), hd), isFalse);
      expect(safeboxShouldTranscodeVideo(const SafeboxMediaFacts(sizeBytes: 10 * mo), hd), isTrue);
      expect(safeboxShouldTranscodeVideo(const SafeboxMediaFacts(sizeBytes: 5 * mo), hd), isFalse);
    });

    test('source en H.265 vers des destinataires qui ne le lisent pas : conversion obligée', () {
      const petite = SafeboxMediaFacts(sizeBytes: 500000, width: 640, height: 360, durationMs: 10000, hevcSource: true);
      expect(safeboxShouldTranscodeVideo(petite, safeboxVideoProfile(SafeboxQuality.hd, hevc: false)!), isTrue);
      expect(safeboxShouldTranscodeVideo(petite, safeboxVideoProfile(SafeboxQuality.hd, hevc: true)!), isFalse);
    });
  });

  group('photo', () {
    test('4 000 × 3 000 : ≈ 1,2 Mo en HD, ≈ 0,3 Mo en Compressé', () {
      const f = SafeboxMediaFacts(sizeBytes: 5 * mo, width: 4000, height: 3000);
      expect(safeboxEstimatePhotoBytes(f, SafeboxQuality.hd), 1179648);
      expect(safeboxEstimatePhotoBytes(f, SafeboxQuality.compressed), 307200);
    });

    test('jamais plus lourde que l\'original', () {
      const petite = SafeboxMediaFacts(sizeBytes: 200000, width: 1200, height: 900);
      expect(safeboxEstimatePhotoBytes(petite, SafeboxQuality.hd), 200000);
    });
  });

  group('musique', () {
    test('MP3 à 320 kbit/s : réduit ; MP3 à 128 kbit/s : tel quel en HD', () {
      const fort = SafeboxMediaFacts(sizeBytes: 9600000, durationMs: 240000);
      expect(safeboxEstimateAudioBytes(fort, SafeboxQuality.hd), 3840000);
      expect(safeboxEstimateAudioBytes(fort, SafeboxQuality.compressed), 1920000);
      const moyen = SafeboxMediaFacts(sizeBytes: 3840000, durationMs: 240000);
      expect(safeboxEstimateAudioBytes(moyen, SafeboxQuality.hd), 3840000);
      expect(safeboxEstimateAudioBytes(moyen, SafeboxQuality.compressed), 1920000);
    });
  });

  test('format retenu : le suivant plus léger si celui demandé dépasse la limite', () {
    bool sauf(SafeboxQuality q, Set<SafeboxQuality> trop) => !trop.contains(q);
    expect(safeboxFittingQuality(SafeboxQuality.original, (q) => sauf(q, {SafeboxQuality.original})), SafeboxQuality.hd);
    expect(safeboxFittingQuality(SafeboxQuality.hd, (q) => true), SafeboxQuality.hd);
    expect(safeboxFittingQuality(SafeboxQuality.compressed, (q) => sauf(q, {SafeboxQuality.compressed})), isNull);
    expect(safeboxFittingQuality(SafeboxQuality.original, (q) => false), isNull);
    expect(SafeboxQuality.fromName('hd'), SafeboxQuality.hd);
    expect(SafeboxQuality.fromName('inconnu'), SafeboxQuality.original);
  });
}
