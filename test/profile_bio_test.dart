import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/profile_bio.dart';

void main() {
  group('ProfileBio', () {
    const defaultBio = 'Salut, je suis sur Alanya';

    test('display returns default when bio is empty', () {
      expect(ProfileBio.display('', defaultBio), defaultBio);
      expect(ProfileBio.display('   ', defaultBio), defaultBio);
    });

    test('display returns custom bio when set', () {
      expect(ProfileBio.display('Designer à Douala', defaultBio),
          'Designer à Douala');
    });

    test('valueToSave uses default when input empty', () {
      expect(ProfileBio.valueToSave('', defaultBio), defaultBio);
      expect(ProfileBio.valueToSave('Ma bio', defaultBio), 'Ma bio');
    });
  });
}
