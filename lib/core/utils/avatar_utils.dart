import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

bool hasValidAvatarUrl(String? url) {
  if (url == null) return false;
  final u = url.trim();
  if (u.isEmpty) return false;
  if (u.toUpperCase() == 'NON DEFINI') return false;
  return u.startsWith('http://') || u.startsWith('https://');
}

ImageProvider? avatarImage(String? url) =>
    hasValidAvatarUrl(url) ? CachedNetworkImageProvider(url!.trim()) : null;
