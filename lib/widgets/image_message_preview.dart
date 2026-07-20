import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/services/video_thumbnail_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';

/// Aperçu image dans les bulles / grilles.
///
/// Priorité :
///  1. fichier local → net ;
///  2. [useBlurredThumb] (reçu non téléchargé) → `mediaThumb` basse qualité + blur,
///     **sans** fetch de [networkUrl], taille = même ratio que l'image dans
///     [maxWidth]×[maxHeight] ;
///  3. [networkUrl] → cache UI (messages miens / cas edge) ;
///  4. fond uni.
class ImageMessagePreview extends StatelessWidget {
  const ImageMessagePreview({
    super.key,
    this.localPath,
    this.networkUrl,
    this.thumbBase64,
    this.useBlurredThumb = false,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.expandToFill = false,
    this.maxWidth = 240,
    this.maxHeight = 220,
    this.width,
    this.height,
    this.blurSigma = 3,
    this.fallbackColor,
  });

  final String? localPath;
  final String? networkUrl;
  final String? thumbBase64;

  /// True quand le média reçu n'est pas encore dans [localMediaPath] :
  /// on n'affiche que la vignette floutée (pas de téléchargement réseau UI).
  final bool useBlurredThumb;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool expandToFill;
  final double maxWidth;
  final double maxHeight;
  final double? width;
  final double? height;
  final double blurSigma;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadius.brSm;
    final fallback = fallbackColor ?? AppColors.immersiveBackground;
    final onVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final local = localPath;
    final hasLocal = local != null && File(local).existsSync();

    late final Widget child;
    if (hasLocal) {
      child = Image.file(
        File(local),
        fit: fit,
        width: expandToFill ? double.infinity : null,
        height: expandToFill ? double.infinity : null,
        errorBuilder: (_, __, ___) => _fallbackBox(fallback, onVariant),
      );
    } else if (useBlurredThumb) {
      child = _BlurredMediaThumb(
        bytes: VideoThumbnailService.decodeBase64(thumbBase64),
        fit: fit,
        blurSigma: blurSigma,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        expandToFill: expandToFill,
        fallback: fallback,
        iconColor: onVariant,
      );
    } else if (networkUrl != null && networkUrl!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: networkUrl!,
        fit: fit,
        width: expandToFill ? double.infinity : null,
        height: expandToFill ? double.infinity : null,
        placeholder: (_, __) => ColoredBox(color: fallback),
        errorWidget: (_, __, ___) => _fallbackBox(fallback, onVariant),
      );
    } else {
      child = _fallbackBox(fallback, onVariant);
    }

    Widget framed = child;
    if (expandToFill) {
      framed = SizedBox.expand(child: framed);
    } else if (width != null || height != null) {
      framed = SizedBox(width: width, height: height, child: framed);
    } else if (!useBlurredThumb || hasLocal) {
      // Le thumb flou calcule déjà sa taille (ratio image) ; local / réseau
      // respectent les max via ConstrainedBox comme avant.
      framed = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: framed,
      );
    }

    return ClipRRect(borderRadius: radius, child: framed);
  }

  Widget _fallbackBox(Color fallback, Color iconColor) {
    return ColoredBox(
      color: fallback,
      child: SizedBox(
        width: expandToFill ? double.infinity : 200,
        height: expandToFill ? double.infinity : 160,
        child: Icon(Icons.image_outlined, size: 48, color: iconColor),
      ),
    );
  }
}

/// Affiche [bytes] floutés, agrandis pour tenir dans [maxWidth]×[maxHeight]
/// **en conservant le ratio** (même empreinte que l'image locale contrainte).
class _BlurredMediaThumb extends StatefulWidget {
  const _BlurredMediaThumb({
    required this.bytes,
    required this.fit,
    required this.blurSigma,
    required this.maxWidth,
    required this.maxHeight,
    required this.expandToFill,
    required this.fallback,
    required this.iconColor,
  });

  final Uint8List? bytes;
  final BoxFit fit;
  final double blurSigma;
  final double maxWidth;
  final double maxHeight;
  final bool expandToFill;
  final Color fallback;
  final Color iconColor;

  @override
  State<_BlurredMediaThumb> createState() => _BlurredMediaThumbState();
}

class _BlurredMediaThumbState extends State<_BlurredMediaThumb> {
  double? _aspect; // width / height

  @override
  void initState() {
    super.initState();
    _aspect = _aspectOf(widget.bytes);
    if (_aspect == null) _resolveAspect(widget.bytes);
  }

  @override
  void didUpdateWidget(covariant _BlurredMediaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _aspect = _aspectOf(widget.bytes);
      if (_aspect == null) _resolveAspect(widget.bytes);
    }
  }

  /// PNG (format de nos thumbs) : largeur/hauteur dans l'IHDR, synchrone.
  static double? _aspectOf(Uint8List? bytes) {
    if (bytes == null || bytes.length < 24) return null;
    if (bytes[0] != 0x89 || bytes[1] != 0x50) return null; // PNG
    final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    if (w <= 0 || h <= 0) return null;
    return w / h;
  }

  Future<void> _resolveAspect(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final aspect = image.width / image.height;
      image.dispose();
      if (!mounted) return;
      setState(() => _aspect = aspect);
    } catch (_) {}
  }

  Size _fittedSize(double aspect) {
    final maxW = widget.maxWidth;
    final maxH = widget.maxHeight;
    if (maxW / aspect <= maxH) {
      return Size(maxW, maxW / aspect);
    }
    return Size(maxH * aspect, maxH);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.bytes;
    if (bytes == null || bytes.isEmpty) {
      return ColoredBox(
        color: widget.fallback,
        child: SizedBox(
          width: widget.expandToFill ? double.infinity : 200,
          height: widget.expandToFill ? double.infinity : 160,
          child: Icon(Icons.image_outlined, size: 48, color: widget.iconColor),
        ),
      );
    }

    final image = Image.memory(
      bytes,
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
    );

    final blurred = ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: widget.blurSigma,
        sigmaY: widget.blurSigma,
        tileMode: TileMode.clamp,
      ),
      child: Transform.scale(
        scale: 1.08,
        child: image,
      ),
    );

    if (widget.expandToFill) {
      return blurred;
    }

    final aspect = _aspect;
    if (aspect == null || aspect <= 0) {
      return SizedBox(
        width: widget.maxWidth,
        height: widget.maxHeight,
        child: ColoredBox(color: widget.fallback),
      );
    }

    final size = _fittedSize(aspect);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: blurred,
    );
  }
}
