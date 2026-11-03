import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/call/video_capture_profile.dart';

void main() {
  test('le profil standard conserve les contraintes existantes', () {
    expect(videoCaptureConstraints(profile: 'standard'), {
      'width': {'ideal': 1280},
      'height': {'ideal': 720},
      'frameRate': {'ideal': 30},
    });
  });

  test('le profil réduit vise 640x480 à 24 images par seconde', () {
    expect(videoCaptureConstraints(profile: 'low'), {
      'width': {'ideal': 640},
      'height': {'ideal': 480},
      'frameRate': {'ideal': 24},
    });
  });

  test('une valeur inconnue conserve le profil standard', () {
    expect(videoCaptureConstraints(profile: 'inconnu'),
        videoCaptureConstraints(profile: 'standard'));
  });

  test('les contraintes retournées sont indépendantes', () {
    final first = videoCaptureConstraints(profile: 'low');
    (first['width'] as Map)['ideal'] = 1;
    expect(videoCaptureConstraints(profile: 'low')['width'], {'ideal': 640});
  });
}
