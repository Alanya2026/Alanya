import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/call/video_capture_profile.dart';

void main() {
  group('contraintes de capture', () {
    test('des entiers, que flutter_webrtc lit sur Android et iOS', () {
      expect(videoCaptureConstraints(quality: CallVideoQuality.standard), {
        'width': 848,
        'height': 480,
        'frameRate': 30,
      });
      expect(videoCaptureConstraints(quality: CallVideoQuality.low), {
        'width': 640,
        'height': 360,
        'frameRate': 30,
      });
      expect(videoCaptureConstraints(quality: CallVideoQuality.hd), {
        'width': 1280,
        'height': 720,
        'frameRate': 30,
      });
      expect(videoCaptureConstraints(quality: CallVideoQuality.fullHd), {
        'width': 1920,
        'height': 1080,
        'frameRate': 30,
      });
    });

    // Demander 20 i/s à la caméra d'un Xiaomi lui faisait choisir la plage fixe
    // [10:10]. La cadence d'un niveau se règle à l'encodeur.
    test('le 360p filme à 30 i/s et l\'encodeur plafonne à 20', () {
      expect(videoCaptureConstraints(quality: CallVideoQuality.low)['frameRate'],
          kCallCaptureFps);
      expect(CallVideoQuality.low.frameRate, 20);
    });

    test('en conférence, le Standard garde sa taille mais pas ses 30 i/s', () {
      expect(
        videoCaptureConstraints(
          quality: CallVideoQuality.standard,
          frameRate: kConferenceCaptureFps,
        ),
        {'width': 848, 'height': 480, 'frameRate': 24},
      );
    });

    test('plafonds de débit des captures du client', () {
      expect(CallVideoQuality.low.maxBitrate, 600000);
      expect(CallVideoQuality.standard.maxBitrate, 1200000);
      expect(CallVideoQuality.hd.maxBitrate, 2500000);
      expect(CallVideoQuality.fullHd.maxBitrate, 5000000);
    });

    test('les contraintes retournées sont indépendantes', () {
      final first = videoCaptureConstraints(quality: CallVideoQuality.low);
      first['width'] = 1;
      expect(
        videoCaptureConstraints(quality: CallVideoQuality.low)['width'],
        640,
      );
    });
  });

  group('niveau appliqué', () {
    test('un code inconnu ou absent retombe sur le standard', () {
      expect(CallVideoQuality.fromCode(null), CallVideoQuality.standard);
      expect(CallVideoQuality.fromCode('4k'), CallVideoQuality.standard);
      expect(CallVideoQuality.fromCode('hd'), CallVideoQuality.hd);
      expect(CallVideoQuality.fromCode('fullhd'), CallVideoQuality.fullHd);
    });

    test('sans Alanya Plus, le Full HD part en standard', () {
      expect(
        CallVideoQualityPreferences.effectiveFor(
          CallVideoQuality.fullHd,
          hdAllowed: false,
        ),
        CallVideoQuality.standard,
      );
      expect(
        CallVideoQualityPreferences.effectiveFor(
          CallVideoQuality.fullHd,
          hdAllowed: true,
        ),
        CallVideoQuality.fullHd,
      );
    });

    test('sans Alanya Plus, la HD part en standard', () {
      expect(
        CallVideoQualityPreferences.effectiveFor(
          CallVideoQuality.hd,
          hdAllowed: false,
        ),
        CallVideoQuality.standard,
      );
      expect(
        CallVideoQualityPreferences.effectiveFor(
          CallVideoQuality.hd,
          hdAllowed: true,
        ),
        CallVideoQuality.hd,
      );
      expect(
        CallVideoQualityPreferences.effectiveFor(
          CallVideoQuality.low,
          hdAllowed: false,
        ),
        CallVideoQuality.low,
      );
    });

    test('le choix est mémorisé et relu', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = CallVideoQualityPreferences();
      await prefs.load();
      expect(prefs.quality, CallVideoQuality.standard);
      await prefs.setQuality(CallVideoQuality.low);
      expect(CallVideoQualityPreferences.chosen, CallVideoQuality.low);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getString('call_video_quality'), 'low');
    });
  });
}
