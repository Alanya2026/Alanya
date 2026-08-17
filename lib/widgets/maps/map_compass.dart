import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Boussole posée **dans** les `children` d'une [FlutterMap].
///
/// Elle lit la caméra via [MapCamera.of] : elle tourne avec la carte, et un
/// appui ramène le nord en haut. À placer uniquement sur les cartes
/// manipulables — les vignettes du fil n'ont ni geste ni boussole.
class MapCompass extends StatelessWidget {
  const MapCompass({
    super.key,
    this.alignment = Alignment.topLeft,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.useSafeArea = false,
  });

  final Alignment alignment;
  final EdgeInsets padding;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final controller = MapController.of(context);
    final colors = context.colors;
    final l10n = context.l10n;

    final rose = SizedBox(
      width: AppSizes.minTapTarget,
      height: AppSizes.minTapTarget,
      child: Material(
        color: colors.surface.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: Tooltip(
          message: l10n.mapCompassNorth,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => controller.rotate(0),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Transform.rotate(
                angle: camera.rotationRad,
                child: const SizedBox.expand(
                  child: CustomPaint(painter: _CompassRosePainter()),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Widget child = Align(
      alignment: alignment,
      child: Padding(padding: padding, child: rose),
    );
    if (useSafeArea) child = SafeArea(child: child);
    return child;
  }
}

/// Rose des vents : le nord rouge pointe vers le nord géographique une fois
/// composée avec la rotation de la carte.
class _CompassRosePainter extends CustomPainter {
  const _CompassRosePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    final nord = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.28, c.dy)
      ..lineTo(c.dx, c.dy - r * 0.12)
      ..lineTo(c.dx - r * 0.28, c.dy)
      ..close();
    final sud = Path()
      ..moveTo(c.dx, c.dy + r)
      ..lineTo(c.dx + r * 0.28, c.dy)
      ..lineTo(c.dx, c.dy + r * 0.12)
      ..lineTo(c.dx - r * 0.28, c.dy)
      ..close();

    canvas.drawPath(sud, Paint()..color = const Color(0xFF9AA0A6));
    canvas.drawPath(nord, Paint()..color = const Color(0xFFE53935));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
