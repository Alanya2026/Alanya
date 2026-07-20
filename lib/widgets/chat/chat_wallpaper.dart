import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Fond de discussion dense (style WhatsApp/Telegram).
///
/// Utilise des tuiles bitmap validées (motifs messagerie + tech + logo Alanya
/// en filigrane discret), répétées. Beaucoup plus fidèle aux maquettes qu'un
/// CustomPainter sparse.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  static const _lightAsset = 'assets/images/chat_wallpaper_light.jpg';
  static const _darkAsset = 'assets/images/chat_wallpaper_dark.jpg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted;

    // Opacité basse → motifs présents sans écraser les bulles ;
    // le logo (déjà désaturé dans l'asset) reste un filigrane.
    final opacity = isDark ? 0.32 : 0.42;
    // scale > 1 → tuile visuelle plus petite → plus de motifs à l'écran.
    const scale = 1.85;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: base,
          image: DecorationImage(
            image: AssetImage(isDark ? _darkAsset : _lightAsset),
            repeat: ImageRepeat.repeat,
            opacity: opacity,
            scale: scale,
            filterQuality: FilterQuality.medium,
            alignment: Alignment.topLeft,
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
