import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/upload_errors.dart';
import 'package:talky_flutter/talky_api_client.dart';

void main() {
  group('isTransientUploadError', () {
    test('429 est retentable', () {
      expect(
        isTransientUploadError(TalkyException('Limite', 429)),
        isTrue,
      );
    });

    test('413 n’est pas retentable', () {
      expect(
        isTransientUploadError(TalkyException('Trop gros', 413)),
        isFalse,
      );
    });

    test('timeout réseau (0) est retentable', () {
      expect(
        isTransientUploadError(TalkyException('Timeout', 0)),
        isTrue,
      );
    });

    test('5xx est retentable', () {
      expect(
        isTransientUploadError(TalkyException('Erreur serveur', 503)),
        isTrue,
      );
    });
  });
}
