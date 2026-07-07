import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/widgets/calls/draggable_video_pip.dart';

void main() {
  const screenSize = Size(400, 800);
  const safeArea = EdgeInsets.only(top: 44, bottom: 34);

  PipLayoutBounds normalBounds() => computePipBounds(
        screenSize: screenSize,
        safeArea: safeArea,
        controlsVisible: true,
      );

  PipLayoutBounds immersiveBounds() => computePipBounds(
        screenSize: screenSize,
        safeArea: safeArea,
        controlsVisible: false,
      );

  group('defaultPipOffset', () {
    test('places PiP in the top-right corner', () {
      final bounds = normalBounds();
      final offset = defaultPipOffset(bounds);

      expect(offset.dx, bounds.maxX);
      expect(offset.dy, bounds.minY);
    });
  });

  group('clampPipOffset', () {
    test('keeps position inside normal bounds', () {
      final bounds = normalBounds();
      final clamped = clampPipOffset(const Offset(200, 200), bounds);

      expect(clamped.dx, greaterThanOrEqualTo(bounds.minX));
      expect(clamped.dx, lessThanOrEqualTo(bounds.maxX));
      expect(clamped.dy, greaterThanOrEqualTo(bounds.minY));
      expect(clamped.dy, lessThanOrEqualTo(bounds.maxY));
    });

    test('clamps overflow on the left and top', () {
      final bounds = normalBounds();
      final clamped = clampPipOffset(const Offset(-50, -50), bounds);

      expect(clamped.dx, bounds.minX);
      expect(clamped.dy, bounds.minY);
    });

    test('clamps overflow on the right and bottom', () {
      final bounds = normalBounds();
      final clamped = clampPipOffset(const Offset(999, 999), bounds);

      expect(clamped.dx, bounds.maxX);
      expect(clamped.dy, bounds.maxY);
    });
  });

  group('computePipBounds', () {
    test('immersive mode allows lower PiP placement than normal mode', () {
      final normal = normalBounds();
      final immersive = immersiveBounds();

      expect(immersive.maxY, greaterThan(normal.maxY));
      expect(immersive.minY, lessThan(normal.minY));
    });
  });

  group('reclampPipOffset', () {
    test('returns null when position is null', () {
      expect(reclampPipOffset(null, normalBounds()), isNull);
    });

    test('returns same offset when already inside bounds', () {
      final bounds = normalBounds();
      const position = Offset(100, 150);

      expect(reclampPipOffset(position, bounds), position);
    });

    test('re-clamps when returning from immersive to normal mode', () {
      final immersive = immersiveBounds();
      final normal = normalBounds();
      final lowPosition = Offset(immersive.minX, immersive.maxY);

      final reclamped = reclampPipOffset(lowPosition, normal);

      expect(reclamped, isNotNull);
      expect(reclamped!.dy, normal.maxY);
      expect(reclamped.dy, lessThan(lowPosition.dy));
    });
  });
}
