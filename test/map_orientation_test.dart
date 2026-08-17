import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:talky_flutter/core/utils/map_tiles.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/widgets/maps/map_compass.dart';

void main() {
  test('les cartes manipulables autorisent la rotation', () {
    expect(InteractiveFlag.hasRotate(MapTiles.interactive.flags), isTrue);
    expect(InteractiveFlag.hasRotate(MapTiles.inert.flags), isFalse);
  });

  testWidgets('la boussole remet le nord en haut', (tester) async {
    final carte = MapController();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('fr'),
      home: SizedBox(
        width: 400,
        height: 400,
        child: FlutterMap(
          mapController: carte,
          options: const MapOptions(
            initialCenter: LatLng(0, 0),
            initialZoom: 3,
            interactionOptions: MapTiles.interactive,
          ),
          children: const [MapCompass()],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    carte.rotate(45);
    await tester.pump();
    expect(carte.camera.rotation, closeTo(45, 0.01));

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(carte.camera.rotation, closeTo(0, 0.01));
  });
}
