import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

import 'backend_url.dart';

bool hasValidAvatarUrl(String? url) {
  if (url == null) return false;
  final u = normalizeBackendUrl(url.trim()) ?? '';
  if (u.isEmpty) return false;
  if (u.toUpperCase() == 'NON DEFINI') return false;
  return u.startsWith('http://') || u.startsWith('https://');
}

ImageProvider? avatarImage(String? url) {
  final resolved = normalizeBackendUrl(url?.trim());
  return hasValidAvatarUrl(resolved)
      ? CachedNetworkImageProvider(resolved!)
      : null;
}
