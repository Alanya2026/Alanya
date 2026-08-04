import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/avatar_utils.dart';
import '../../core/utils/backend_url.dart';
import '../qr_pin.dart';

/// Forme de l'avatar.
enum AppAvatarShape { circle, squircle }

/// Avatar réutilisable et unifié de Talky.
///
/// Centralise la logique image (réseau via [CachedNetworkImage], locale via
/// [Image.file]) **et** le fallback initiales / icône de groupe, jusqu'ici
/// dupliquée dans `profile_avatar.dart`, `status_ring_avatar.dart`,
/// `add_contact_sheet.dart` et plusieurs écrans.
///
/// Purement présentationnel : passez [onTap] pour le rendre cliquable
/// (ex. ouverture d'un modal de profil par l'appelant).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.localPath,
    required this.name,
    this.size = AppSizes.avatarMd,
    this.shape = AppAvatarShape.circle,
    this.isGroup = false,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
    this.showShadow = false,
    this.cornerRadius,
    this.qrBadge = false,
  });

  final String? imageUrl;
  final String? localPath;
  final String name;
  final double size;
  final AppAvatarShape shape;
  final bool isGroup;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showShadow;

  /// Override explicite du rayon (sinon dérivé de [shape] et [size]).
  final double? cornerRadius;

  /// Pastille « contact ajouté par QR » en coin bas-gauche (le bas-droit reste
  /// au point de présence). Rendue ICI et non par chaque liste : toutes les
  /// surfaces qui montrent ce contact doivent porter la même marque, au même
  /// endroit.
  final bool qrBadge;

  double get _radius {
    if (cornerRadius != null) return cornerRadius!;
    return shape == AppAvatarShape.circle
        ? size / 2
        : AppRadius.md * (size / 56).clamp(0.5, 1.4);
  }

  BorderRadius get _borderRadius => BorderRadius.circular(_radius);

  bool get _hasLocal => localPath != null && localPath!.isNotEmpty;
  bool get _hasNetwork => hasValidAvatarUrl(imageUrl);

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: _borderRadius,
        boxShadow: showShadow ? AppShadows.subtle : null,
      ),
      child: ClipRRect(
        borderRadius: _borderRadius,
        child: _buildContent(context),
      ),
    );

    if (qrBadge) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            left: -2,
            bottom: -2,
            child: QrPin(size: (size * 0.42).clamp(15.0, 20.0)),
          ),
        ],
      );
    }

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  Widget _buildContent(BuildContext context) {
    if (_hasLocal) {
      return Image.file(
        File(localPath!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(context),
      );
    }
    if (_hasNetwork) {
      final resolved = normalizeBackendUrl(imageUrl!.trim())!;
      return CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(color: context.colors.surfaceContainerHighest),
        errorWidget: (_, __, ___) => _buildFallback(context),
      );
    }
    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    final bg = backgroundColor ?? context.colors.primaryContainer;
    final fg = foregroundColor ?? context.colors.onPrimaryContainer;
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      color: bg,
      alignment: Alignment.center,
      child: isGroup
          ? Icon(Icons.group_rounded, size: size * 0.5, color: fg)
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
    );
  }
}
