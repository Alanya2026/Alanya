import 'dart:typed_data';

/// Format d'une image animée acceptée en entrée de la création animée (§4c).
enum StickerAnimatedKind { gif, webp }

/// Pourquoi un fichier ne peut pas partir vers `POST /assets/animated`.
enum StickerAnimatedIssue {
  /// Ni GIF ni WebP (ou fichier illisible).
  format,

  /// Plus de 3 Mo.
  tooBig,

  /// GIF ou WebP **fixe** : rien à animer.
  notAnimated,
}

/// Refus d'un fichier avant tout envoi : dit en clair (fr/en/zh) plutôt
/// qu'après un aller-retour réseau. Le serveur reste la frontière.
class StickerAnimatedRejected implements Exception {
  const StickerAnimatedRejected(this.issue);
  final StickerAnimatedIssue issue;

  @override
  String toString() => 'StickerAnimatedRejected(${issue.name})';
}

/// Résultat de [StickerAnimatedCheck.inspect].
class StickerAnimatedInfo {
  const StickerAnimatedInfo({
    required this.kind,
    required this.animated,
    required this.frames,
    required this.bytes,
  });

  final StickerAnimatedKind kind;

  /// Plus d'une image (GIF) ou chunk `ANIM` présent (WebP).
  final bool animated;

  /// Images comptées (informatif ; `0` si la lecture a été interrompue).
  final int frames;
  final int bytes;
}

/// Détection **sur les octets** (octets magiques), sans décoder ni dépendre du
/// paquet `image` : `GIF87a` / `GIF89a`, ou `RIFF…WEBP` avec un chunk `ANIM`.
///
/// Le fichier source part **tel quel** au serveur, qui recadre, applique la
/// forme et ré-encode ; ce contrôle sert seulement à répondre tout de suite
/// « ce n'est pas un GIF animé » ou « plus de 3 Mo ».
abstract final class StickerAnimatedCheck {
  /// Contrat §4c : GIF ou WebP animé d'entrée ≤ 3 Mo.
  static const int maxBytes = 3 * 1024 * 1024;

  /// Garde-fou de lecture : on ne parcourt jamais plus de blocs que cela.
  static const int _maxBlocks = 20000;

  /// `null` si [data] n'est ni un GIF ni un WebP reconnaissable.
  static StickerAnimatedInfo? inspect(Uint8List data) =>
      _gif(data) ?? _webp(data);

  /// Vrai pour un GIF ou un WebP **animé** (sans contrôle de taille).
  static bool isAnimated(Uint8List data) => inspect(data)?.animated ?? false;

  /// Lève [StickerAnimatedRejected] à la première règle violée.
  static StickerAnimatedInfo validate(Uint8List data) {
    if (data.length > maxBytes) {
      throw const StickerAnimatedRejected(StickerAnimatedIssue.tooBig);
    }
    final info = inspect(data);
    if (info == null) {
      throw const StickerAnimatedRejected(StickerAnimatedIssue.format);
    }
    if (!info.animated) {
      throw const StickerAnimatedRejected(StickerAnimatedIssue.notAnimated);
    }
    return info;
  }

  static bool _tag(Uint8List d, int o, String tag) {
    if (o < 0 || o + tag.length > d.length) return false;
    for (var i = 0; i < tag.length; i++) {
      if (d[o + i] != tag.codeUnitAt(i)) return false;
    }
    return true;
  }

  static int _u32le(Uint8List d, int o) =>
      d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | (d[o + 3] << 24);

  /// GIF : en-tête `GIF87a` / `GIF89a`, puis blocs jusqu'au terminateur. Les
  /// images (`0x2C`) sont comptées : une seule = GIF fixe.
  static StickerAnimatedInfo? _gif(Uint8List d) {
    if (d.length < 13 || !(_tag(d, 0, 'GIF87a') || _tag(d, 0, 'GIF89a'))) {
      return null;
    }
    var frames = 0;
    var o = 13;
    if ((d[10] & 0x80) != 0) o += 3 * (1 << ((d[10] & 0x07) + 1));
    var guard = 0;
    while (o < d.length && guard++ < _maxBlocks) {
      final b = d[o];
      if (b == 0x3B) break; // fin du fichier
      if (b == 0x21) {
        // Extension : étiquette, puis sous-blocs jusqu'à une longueur nulle.
        o = _skipSubBlocks(d, o + 2);
        if (o < 0) break;
        continue;
      }
      if (b == 0x2C) {
        frames++;
        if (frames >= 2) break; // assez pour conclure : animé
        if (o + 10 > d.length) break;
        final flags = d[o + 9];
        o += 10;
        if ((flags & 0x80) != 0) o += 3 * (1 << ((flags & 0x07) + 1));
        o = _skipSubBlocks(d, o + 1); // +1 : taille de code LZW minimale
        if (o < 0) break;
        continue;
      }
      break; // octet inattendu : fichier abîmé, on s'arrête là
    }
    return StickerAnimatedInfo(
      kind: StickerAnimatedKind.gif,
      animated: frames >= 2,
      frames: frames,
      bytes: d.length,
    );
  }

  /// Saute les sous-blocs à partir de [o] ; renvoie l'offset suivant, ou -1 si
  /// le fichier est tronqué.
  static int _skipSubBlocks(Uint8List d, int o) {
    var guard = 0;
    while (o < d.length && guard++ < _maxBlocks) {
      final n = d[o];
      if (n == 0) return o + 1;
      o += 1 + n;
    }
    return -1;
  }

  /// WebP : `RIFF` + taille + `WEBP`, puis chunks `[tag 4][taille LE 4][données
  /// (paires)]`. Animé si un chunk `ANIM` est présent.
  static StickerAnimatedInfo? _webp(Uint8List d) {
    if (d.length < 16 || !_tag(d, 0, 'RIFF') || !_tag(d, 8, 'WEBP')) {
      return null;
    }
    var animated = false;
    var frames = 0;
    var o = 12;
    var guard = 0;
    while (o + 8 <= d.length && guard++ < _maxBlocks) {
      final size = _u32le(d, o + 4);
      if (_tag(d, o, 'ANIM')) animated = true;
      if (_tag(d, o, 'ANMF')) frames++;
      if (size < 0) break;
      o += 8 + size + (size & 1);
    }
    return StickerAnimatedInfo(
      kind: StickerAnimatedKind.webp,
      animated: animated,
      frames: frames,
      bytes: d.length,
    );
  }
}
