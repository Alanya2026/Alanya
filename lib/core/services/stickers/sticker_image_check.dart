import 'dart:typed_data';

/// Raison pour laquelle une image ne peut pas devenir un sticker en l'état.
enum StickerImageIssue {
  /// Ni PNG ni WebP (ou fichier illisible).
  format,

  /// Plus d'1 Mo.
  tooBig,

  /// Pas exactement 512×512.
  size,

  /// Aucun canal alpha (fond opaque).
  noAlpha,

  /// Image animée (GIF, WebP animé) : V1c.
  animated,

  /// Image choisie trop lourde ou trop grande pour être adaptée (plus de
  /// 20 Mo ou de 50 mégapixels) : voir `StickerImageAdapter`.
  inputTooBig,
}

/// Résultat de [StickerImageCheck.inspect].
class StickerImageInfo {
  const StickerImageInfo({
    required this.mime,
    required this.width,
    required this.height,
    required this.hasAlpha,
    required this.animated,
    required this.bytes,
  });

  final String mime;
  final int width;
  final int height;
  final bool hasAlpha;
  final bool animated;
  final int bytes;
}

/// Refus d'une image avant tout envoi : l'interface le dit en clair (fr/en/zh)
/// plutôt que d'attendre un `STICKER_ASSET_INVALID` du serveur.
class StickerImageRejected implements Exception {
  const StickerImageRejected(this.issue);
  final StickerImageIssue issue;

  @override
  String toString() => 'StickerImageRejected(${issue.name})';
}

/// Contrôle **sur les octets** (en-têtes PNG / WebP), sans décoder ni dépendre
/// du paquet `image` : le serveur reste la frontière (il ré-encode et rejette
/// ce qui ne va pas), ce contrôle ne sert qu'à dire pourquoi, tout de suite.
///
/// Contrat §8 : PNG ou WebP ≤ 1 Mo, **exactement 512×512**, alpha obligatoire.
/// Les photos de la galerie passent d'abord par `StickerImageAdapter`
/// (contain 512×512 + PNG) ; l'éditeur T4b viendra ensuite.
abstract final class StickerImageCheck {
  static const int maxBytes = 1024 * 1024;
  static const int side = 512;

  /// Lit l'en-tête de [data] ; `null` si ce n'est ni un PNG ni un WebP lisible.
  static StickerImageInfo? inspect(Uint8List data) => _png(data) ?? _webp(data);

  /// Lève [StickerImageRejected] à la première règle violée.
  static StickerImageInfo validate(Uint8List data) {
    if (data.length > maxBytes) {
      throw const StickerImageRejected(StickerImageIssue.tooBig);
    }
    final info = inspect(data);
    if (info == null) {
      throw const StickerImageRejected(StickerImageIssue.format);
    }
    if (info.animated) {
      throw const StickerImageRejected(StickerImageIssue.animated);
    }
    if (info.width != side || info.height != side) {
      throw const StickerImageRejected(StickerImageIssue.size);
    }
    if (!info.hasAlpha) {
      throw const StickerImageRejected(StickerImageIssue.noAlpha);
    }
    return info;
  }

  static int _u32be(Uint8List d, int o) =>
      (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3];

  static int _u32le(Uint8List d, int o) =>
      d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | (d[o + 3] << 24);

  static bool _tag(Uint8List d, int o, String tag) {
    if (o + tag.length > d.length) return false;
    for (var i = 0; i < tag.length; i++) {
      if (d[o + i] != tag.codeUnitAt(i)) return false;
    }
    return true;
  }

  static StickerImageInfo? _png(Uint8List d) {
    const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (d.length < 33) return null;
    for (var i = 0; i < sig.length; i++) {
      if (d[i] != sig[i]) return null;
    }
    if (!_tag(d, 12, 'IHDR')) return null;
    final w = _u32be(d, 16);
    final h = _u32be(d, 20);
    final colorType = d[25];
    var alpha = colorType == 4 || colorType == 6;
    if (!alpha && colorType == 3) {
      // Palette : la transparence tient dans un bloc `tRNS` avant les données.
      var o = 8;
      while (o + 8 <= d.length) {
        final len = _u32be(d, o);
        if (_tag(d, o + 4, 'tRNS')) {
          alpha = true;
          break;
        }
        if (_tag(d, o + 4, 'IDAT') || _tag(d, o + 4, 'IEND')) break;
        o += 12 + len;
      }
    }
    return StickerImageInfo(
      mime: 'image/png',
      width: w,
      height: h,
      hasAlpha: alpha,
      animated: false,
      bytes: d.length,
    );
  }

  static StickerImageInfo? _webp(Uint8List d) {
    if (d.length < 30 || !_tag(d, 0, 'RIFF') || !_tag(d, 8, 'WEBP')) {
      return null;
    }
    int w;
    int h;
    var alpha = false;
    var animated = false;
    if (_tag(d, 12, 'VP8X')) {
      final flags = d[20];
      animated = (flags & 0x02) != 0;
      alpha = (flags & 0x10) != 0;
      w = 1 + (d[24] | (d[25] << 8) | (d[26] << 16));
      h = 1 + (d[27] | (d[28] << 8) | (d[29] << 16));
    } else if (_tag(d, 12, 'VP8L')) {
      if (d[20] != 0x2F) return null;
      final bits = _u32le(d, 21);
      w = 1 + (bits & 0x3FFF);
      h = 1 + ((bits >> 14) & 0x3FFF);
      alpha = ((bits >> 28) & 1) == 1;
    } else if (_tag(d, 12, 'VP8 ')) {
      // Avec perte, sans alpha : en-tête de trame après le code de départ.
      if (d.length < 30 || d[23] != 0x9D || d[24] != 0x01 || d[25] != 0x2A) {
        return null;
      }
      w = (d[26] | (d[27] << 8)) & 0x3FFF;
      h = (d[28] | (d[29] << 8)) & 0x3FFF;
    } else {
      return null;
    }
    return StickerImageInfo(
      mime: 'image/webp',
      width: w,
      height: h,
      hasAlpha: alpha,
      animated: animated,
      bytes: d.length,
    );
  }
}
