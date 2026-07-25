import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/playback_speed_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlaybackSpeedPreferences.resetForTesting();
  });

  group('valeur par défaut', () {
    test('1× tant que rien n’est mémorisé', () async {
      await PlaybackSpeedPreferences.preload();
      for (final kind in PlaybackSpeedKind.values) {
        expect(PlaybackSpeedPreferences.speedOf(kind), 1.0, reason: '$kind');
      }
    });
  });

  group('persistance', () {
    test('aller-retour d’écriture', () async {
      await PlaybackSpeedPreferences.preload();
      await PlaybackSpeedPreferences.setSpeed(PlaybackSpeedKind.voice, 1.5);
      expect(PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.voice), 1.5);

      // Relecture depuis le disque, comme au redémarrage de l'app.
      PlaybackSpeedPreferences.resetForTesting();
      await PlaybackSpeedPreferences.preload();
      expect(PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.voice), 1.5);
    });

    test('les types sont indépendants', () async {
      await PlaybackSpeedPreferences.preload();
      await PlaybackSpeedPreferences.setSpeed(PlaybackSpeedKind.voice, 2.0);
      await PlaybackSpeedPreferences.setSpeed(PlaybackSpeedKind.video, 0.75);

      expect(PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.voice), 2.0);
      expect(PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.video), 0.75);
      expect(PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.music), 1.0);
    });

    test('une valeur hors paliers ne bloque pas la lecture', () async {
      // 0,75× est un palier vidéo, pas un palier audio.
      SharedPreferences.setMockInitialValues({'playback_speed_voice': 0.75});
      PlaybackSpeedPreferences.resetForTesting();
      await PlaybackSpeedPreferences.preload();
      expect(PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.voice), 1.0);
    });

    test('une valeur aberrante retombe sur 1×', () async {
      SharedPreferences.setMockInitialValues({'playback_speed_video': 12.0});
      PlaybackSpeedPreferences.resetForTesting();
      await PlaybackSpeedPreferences.preload();
      expect(PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.video), 1.0);
    });
  });

  group('nextSpeed', () {
    test('boucle audio 1 → 1,5 → 2 → 1', () {
      double s = 1.0;
      s = PlaybackSpeedPreferences.nextSpeed(PlaybackSpeedKind.voice, s);
      expect(s, 1.5);
      s = PlaybackSpeedPreferences.nextSpeed(PlaybackSpeedKind.voice, s);
      expect(s, 2.0);
      s = PlaybackSpeedPreferences.nextSpeed(PlaybackSpeedKind.voice, s);
      expect(s, 1.0);
    });

    test('une vitesse inconnue repart du premier palier', () {
      expect(
        PlaybackSpeedPreferences.nextSpeed(PlaybackSpeedKind.voice, 1.75),
        1.0,
      );
    });

    test('la vidéo a ses propres paliers', () {
      expect(
        PlaybackSpeedPreferences.nextSpeed(PlaybackSpeedKind.video, 1.0),
        1.25,
      );
    });
  });

  group('formatPlaybackSpeed', () {
    test('virgule décimale française, pas de zéro superflu', () {
      expect(formatPlaybackSpeed(1.0), '1×');
      expect(formatPlaybackSpeed(2.0), '2×');
      expect(formatPlaybackSpeed(1.5), '1,5×');
      expect(formatPlaybackSpeed(0.75), '0,75×');
    });
  });
}
