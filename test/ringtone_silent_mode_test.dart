// La sonnerie d'appel jouée par Flutter respecte le mode du téléphone.
//
// Elle sonnait et vibrait en silencieux (signalement du groupe 3GI 2029, bug A9).
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/ringtone_service.dart';

void main() {
  test('silencieux : ni son ni vibration', () {
    final r = sonnerieAutorisee(0);
    expect(r.son, isFalse);
    expect(r.vibration, isFalse);
  });

  test('vibreur : vibration seule', () {
    final r = sonnerieAutorisee(1);
    expect(r.son, isFalse);
    expect(r.vibration, isTrue);
  });

  test('normal ou inconnu (iOS, échec) : son et vibration', () {
    for (final mode in [2, null]) {
      final r = sonnerieAutorisee(mode);
      expect(r.son, isTrue, reason: '$mode');
      expect(r.vibration, isTrue, reason: '$mode');
    }
  });
}
