import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/video_thumbnail_service.dart';
import 'package:talky_flutter/widgets/video_message_preview.dart';

void main() {
  group('VideoThumbnailService', () {
    test('hasLocalSource returns false when no file exists', () {
      expect(
        VideoThumbnailService.hasLocalSource(
          pendingPath: '/tmp/nonexistent_pending.mp4',
          localPath: '/tmp/nonexistent_local.mp4',
        ),
        isFalse,
      );
    });

    test('resolveLocalPath returns null when paths are missing', () {
      expect(
        VideoThumbnailService.resolveLocalPath(
          pendingPath: null,
          localPath: null,
        ),
        isNull,
      );
    });
  });

  group('VideoMessagePreview.formatDuration', () {
    test('formats seconds under one hour', () {
      expect(VideoMessagePreview.formatDuration(65), '01:05');
    });

    test('formats seconds over one hour', () {
      expect(VideoMessagePreview.formatDuration(3661), '1:01:01');
    });
  });
}
