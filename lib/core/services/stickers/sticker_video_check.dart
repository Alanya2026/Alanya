import 'dart:typed_data';

/// Conteneur d'une vidéo acceptée en entrée de la création animée (§4d).
enum StickerVideoKind {
  /// MP4, MOV, 3GP (conteneur ISO BMFF).
  mp4('video/mp4', '.mp4'),

  /// WebM, Matroska.
  webm('video/webm', '.webm');

  const StickerVideoKind(this.mime, this.extension);
  final String mime;
  final String extension;
}

/// Pourquoi une vidéo ne peut pas partir vers `POST /assets/animated`.
enum StickerVideoIssue {
  /// Ni MP4/MOV ni WebM (ou image HEIC/AVIF au conteneur voisin).
  format,

  /// Plus de 20 Mo.
  tooBig,

  /// Le serveur ne sait pas (encore) convertir les vidéos.
  unsupported,

  /// Moins de 500 ms : rien à animer.
  tooShort,
}

/// Refus d'une vidéo avant tout envoi : dit en clair (fr/en/zh) plutôt
/// qu'après un aller-retour réseau. Le serveur reste la frontière.
class StickerVideoRejected implements Exception {
  const StickerVideoRejected(this.issue);
  final StickerVideoIssue issue;

  @override
  String toString() => 'StickerVideoRejected(${issue.name})';
}

/// Détection **sur les octets** (jamais l'extension ni le type déclaré) :
/// `ftyp` à l'offset 4 (MP4, MOV, 3GP) ou en-tête EBML `1A 45 DF A3` (WebM).
/// Les images HEIC / AVIF partagent le conteneur `ftyp` : leur marque les écarte.
abstract final class StickerVideoCheck {
  /// Contrat §4d : vidéo d'entrée ≤ 20 Mo.
  static const int maxBytes = 20 * 1024 * 1024;

  static const List<String> _imageBrands = [
    'avif', 'avis', 'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1',
    'msf1', 'miaf',
  ];

  /// `null` si [head] n'est pas une vidéo reconnaissable. 12 octets suffisent.
  static StickerVideoKind? kind(Uint8List head) {
    if (head.length < 12) return null;
    if (_ascii(head, 4, 'ftyp')) {
      final brand = String.fromCharCodes(head.sublist(8, 12)).toLowerCase();
      if (_imageBrands.contains(brand)) return null;
      return StickerVideoKind.mp4;
    }
    if (head[0] == 0x1a && head[1] == 0x45 && head[2] == 0xdf && head[3] == 0xa3) {
      return StickerVideoKind.webm;
    }
    return null;
  }

  /// Vrai pour une vidéo reconnue (sans contrôle de taille).
  static bool isVideo(Uint8List data) => kind(data) != null;

  /// Lève [StickerVideoRejected] à la première règle violée.
  static StickerVideoKind validate(Uint8List data) {
    if (data.length > maxBytes) {
      throw const StickerVideoRejected(StickerVideoIssue.tooBig);
    }
    final k = kind(data);
    if (k == null) throw const StickerVideoRejected(StickerVideoIssue.format);
    return k;
  }

  static bool _ascii(Uint8List d, int o, String tag) {
    if (o + tag.length > d.length) return false;
    for (var i = 0; i < tag.length; i++) {
      if (d[o + i] != tag.codeUnitAt(i)) return false;
    }
    return true;
  }
}

/// Fenêtre de découpe d'une vidéo : début et durée, en millisecondes
/// (contrat §4d : durée 500 ms à 3 s, début à partir de 0, jamais au-delà de
/// la fin). Logique **pure** : l'écran ne fait que l'afficher.
class StickerVideoWindow {
  const StickerVideoWindow({required this.startMs, required this.durationMs});

  static const int minDurationMs = 500;
  static const int maxDurationMs = 3000;

  /// Pas des curseurs.
  static const int stepMs = 100;

  final int startMs;
  final int durationMs;

  int get endMs => startMs + durationMs;

  /// Fenêtre par défaut : le début, 3 s ou toute la vidéo si elle est plus
  /// courte. `null` si la vidéo dure moins de [minDurationMs].
  static StickerVideoWindow? initial(int videoMs) {
    if (videoMs < minDurationMs) return null;
    final d = _snap(videoMs < maxDurationMs ? videoMs : maxDurationMs);
    return StickerVideoWindow(
      startMs: 0,
      durationMs: d < minDurationMs ? minDurationMs : d,
    );
  }

  /// Déplace le début : la fenêtre garde sa durée et reste dans la vidéo.
  StickerVideoWindow withStart(int ms, {required int videoMs}) {
    final maxStart = videoMs - durationMs;
    final s = _snap(ms.clamp(0, maxStart < 0 ? 0 : maxStart));
    return StickerVideoWindow(startMs: s, durationMs: durationMs);
  }

  /// Change la durée (500 ms à 3 s) ; elle ne dépasse jamais la fin de la
  /// vidéo (le début recule si besoin plutôt que de tronquer la durée).
  StickerVideoWindow withDuration(int ms, {required int videoMs}) {
    final cap = videoMs < maxDurationMs ? videoMs : maxDurationMs;
    var d = _snap(ms.clamp(minDurationMs, cap < minDurationMs ? minDurationMs : cap));
    if (d < minDurationMs) d = minDurationMs;
    var s = startMs;
    if (s + d > videoMs) s = videoMs - d;
    if (s < 0) s = 0;
    return StickerVideoWindow(startMs: s, durationMs: d);
  }

  /// Arrondi **vers le bas** au pas : un arrondi au plus proche pourrait faire
  /// dépasser la fin de la vidéo (250 ms → 300 ms).
  static int _snap(int ms) => (ms ~/ stepMs) * stepMs;

  @override
  bool operator ==(Object other) =>
      other is StickerVideoWindow &&
      other.startMs == startMs &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(startMs, durationMs);

  @override
  String toString() => 'StickerVideoWindow($startMs +$durationMs ms)';
}
