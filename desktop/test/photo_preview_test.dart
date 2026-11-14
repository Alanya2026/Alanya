import 'dart:io';

import 'package:alanya_coffre/core/photo_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  testWidgets('une photo de 2000 × 1000 donne un aperçu JPEG de 960 × 480', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('coffre_apercu');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final f = File('${tmp.path}/p.jpg')..writeAsBytesSync(img.encodeJpg(img.Image(width: 2000, height: 1000)));

    final a = (await tester.runAsync(() => makePhotoPreview(f.path)))!;

    expect((a.width, a.height), (2000, 1000));
    final apercu = img.decodeJpg(a.jpeg!)!;
    expect((apercu.width, apercu.height), (960, 480));
  });

  testWidgets('un fichier qui n’est pas une image échoue (l’envoi part sans aperçu)', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('coffre_apercu');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final f = File('${tmp.path}/p.heic')..writeAsStringSync('pas une image');
    final erreur = await tester.runAsync(() async {
      try {
        await makePhotoPreview(f.path);
        return null;
      } catch (e) {
        return e;
      }
    });
    expect(erreur, isNotNull);
  });
}
