import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/media_staging.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stageMediaFile', () {
    test('copie le fichier et préserve l’extension', () async {
      final dir = await Directory.systemTemp.createTemp('talky_staging_test_');
      final source = File('${dir.path}/clip.mp4');
      await source.writeAsBytes([0, 1, 2, 3, 4]);

      final staged = await stageMediaFile(
        source,
        outboxDirectory: Directory('${dir.path}/talky_outbox'),
      );

      expect(staged.path, contains('talky_outbox'));
      expect(staged.path.endsWith('.mp4'), isTrue);
      expect(await staged.readAsBytes(), [0, 1, 2, 3, 4]);
      expect(staged.path, isNot(source.path));

      await staged.delete();
      await source.delete();
      await dir.delete(recursive: true);
    });

    test('lève une erreur si la source est absente', () async {
      final missing = File('/tmp/talky_staging_missing_${DateTime.now().microsecondsSinceEpoch}.mp4');
      expect(
        () => stageMediaFile(missing),
        throwsA(isA<MediaStagingException>()),
      );
    });
  });
}
