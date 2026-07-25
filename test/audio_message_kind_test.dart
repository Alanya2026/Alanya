import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/audio_message_kind.dart';

void main() {
  group('audioKindFromName', () {
    test('nom de fichier musical → music', () {
      for (final name in [
        'Bohemian Rhapsody.mp3',
        'track.FLAC',
        'live.m4a',
        'podcast.opus',
        'sample.wav',
        'a.b.c.ogg',
      ]) {
        expect(audioKindFromName(name), AudioMessageKind.music, reason: name);
      }
    });

    test('libellé de vocal localisé → voiceNote', () {
      // C'est ce que _stopRecording pose dans mediaName.
      for (final name in ['Message vocal', 'Voice message', 'Sprachnachricht']) {
        expect(audioKindFromName(name), AudioMessageKind.voiceNote,
            reason: name);
      }
    });

    test('nom absent, vide ou sans extension connue → voiceNote', () {
      expect(audioKindFromName(null), AudioMessageKind.voiceNote);
      expect(audioKindFromName(''), AudioMessageKind.voiceNote);
      expect(audioKindFromName('sans_extension'), AudioMessageKind.voiceNote);
      expect(audioKindFromName('rapport.pdf'), AudioMessageKind.voiceNote);
      expect(audioKindFromName('finit.par.un.point.'),
          AudioMessageKind.voiceNote);
    });
  });

  group('musicTitleFromName', () {
    test('retire l’extension', () {
      expect(musicTitleFromName('Bohemian Rhapsody.mp3', fallback: 'Musique'),
          'Bohemian Rhapsody');
      expect(musicTitleFromName('a.b.c.ogg', fallback: 'Musique'), 'a.b.c');
    });

    test('laisse intact un nom sans extension musicale', () {
      expect(musicTitleFromName('Message vocal', fallback: 'Musique'),
          'Message vocal');
    });

    test('retombe sur le fallback si le nom est vide ou réduit à l’extension',
        () {
      expect(musicTitleFromName(null, fallback: 'Musique'), 'Musique');
      expect(musicTitleFromName('   ', fallback: 'Musique'), 'Musique');
      expect(musicTitleFromName('.mp3', fallback: 'Musique'), 'Musique');
    });
  });

  group('musicExtensionOf', () {
    test('normalise en minuscules', () {
      expect(musicExtensionOf('Track.FLAC'), 'flac');
      expect(musicExtensionOf('song.Mp3'), 'mp3');
    });

    test('null hors liste', () {
      expect(musicExtensionOf('doc.pdf'), isNull);
      expect(musicExtensionOf('Message vocal'), isNull);
    });
  });
}
