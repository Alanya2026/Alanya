// L'aperçu d'une photo du PC : 480 px sur le petit côté, en JPEG, comme le
// téléphone (kSafeboxPreviewSide, qualité 70). Décodé par Flutter, encodé en
// JPEG dans un isolat.

import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'importer.dart';

const int kPreviewSide = 480;

Future<PhotoPreview> makePhotoPreview(String path) async {
  final octets = await File(path).readAsBytes();
  final tampon = await ui.ImmutableBuffer.fromUint8List(octets);
  final desc = await ui.ImageDescriptor.encoded(tampon);
  try {
    final w = desc.width;
    final h = desc.height;
    final court = w < h ? w : h;
    // Un seul côté imposé : le décodeur garde les proportions, même quand
    // l'orientation EXIF tourne l'image.
    final codec = court <= kPreviewSide
        ? await desc.instantiateCodec()
        : w <= h
            ? await desc.instantiateCodec(targetWidth: kPreviewSide)
            : await desc.instantiateCodec(targetHeight: kPreviewSide);
    final image = (await codec.getNextFrame()).image;
    try {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return (jpeg: null, width: w, height: h);
      final iw = image.width;
      final ih = image.height;
      final pixels = rgba.buffer.asUint8List();
      final jpeg = await Isolate.run(() {
        final im = img.Image.fromBytes(width: iw, height: ih, bytes: pixels.buffer, numChannels: 4);
        return Uint8List.fromList(img.encodeJpg(im, quality: 70));
      });
      // Dimensions telles qu'on voit la photo (après l'orientation EXIF).
      final tourne = (iw > ih) != (w > h) && iw != ih;
      return (jpeg: jpeg, width: tourne ? h : w, height: tourne ? w : h);
    } finally {
      image.dispose();
      codec.dispose();
    }
  } finally {
    desc.dispose();
    tampon.dispose();
  }
}
