// Retouche vidéo : faut-il réencoder, fin effective, calques et filtre.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/features/media_editor/model/editor_document.dart';
import 'package:talky_flutter/features/media_editor/model/editor_geometry.dart';
import 'package:talky_flutter/features/media_editor/video/video_retouch.dart';

EditorDoc _doc({EditorLook look = EditorLook.neutral, bool item = false}) =>
    EditorDoc(
      canvas: const Size(10, 10),
      imageWidth: 10,
      imageHeight: 10,
      imageTransform: const EditorImageTransform(
        center: Offset(5, 5),
        scale: 1,
      ),
      look: look,
      items: item
          ? const [
              EditorEmojiItem(
                id: 1,
                placement: EditorPlacement(center: Offset(5, 5)),
                emoji: 'A',
              ),
            ]
          : const [],
    );

void main() {
  const total = Duration(seconds: 20);

  test('neutre : pas de rendu', () {
    expect(const VideoRetouch().needsRender(total), isFalse);
    // Fin au-delà de la durée : rien de découpé.
    expect(
      const VideoRetouch(end: Duration(seconds: 30)).needsRender(total),
      isFalse,
    );
    expect(VideoRetouch(doc: _doc()).needsRender(total), isFalse);
  });

  test('découpe, son coupé, calque, filtre : rendu', () {
    expect(
      const VideoRetouch(start: Duration(seconds: 2)).needsRender(total),
      isTrue,
    );
    expect(
      const VideoRetouch(end: Duration(seconds: 15)).needsRender(total),
      isTrue,
    );
    expect(const VideoRetouch(muted: true).needsRender(total), isTrue);
    expect(VideoRetouch(doc: _doc(item: true)).needsRender(total), isTrue);
    final warm = VideoRetouch(
      doc: _doc(look: const EditorLook(filter: EditorFilter.warm)),
    );
    expect(warm.needsRender(total), isTrue);
    expect(warm.colorMatrix, hasLength(20));
  });

  test('fin effective bornée à la durée', () {
    expect(const VideoRetouch().endFor(total), total);
    expect(
      const VideoRetouch(end: Duration(seconds: 5)).endFor(total),
      const Duration(seconds: 5),
    );
  });
}
