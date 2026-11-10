//  Les trois formats du coffre-fort : Original, HD, Compressé (décision du
//  24/10/2026, conception section 05). Règles pures, sans greffon : elles se
//  testent sans téléphone (test/safebox_quality_test.dart).
//
//  | Type    | Original | HD                          | Compressé                  |
//  |---------|----------|-----------------------------|----------------------------|
//  | Vidéo   | tel quel | 720p, H.265 1,3 Mbit/s      | 480p, H.265 0,6 Mbit/s     |
//  |         |          | (H.264 2 Mbit/s en repli)   | (H.264 1 Mbit/s en repli)  |
//  | Photo   | telle    | côté long 2 560 px, JPEG 85 | côté long 1 600 px, JPEG 75|
//  | Musique | telle    | AAC 128 kbit/s              | AAC 64 kbit/s              |
//
//  Jamais d'agrandissement : un fichier déjà plus léger que le format part
//  tel quel. Les documents ne sont jamais compressés.

import 'dart:math' as math;

enum SafeboxQuality {
  original,
  hd,
  compressed;

  /// Le format rendu par le serveur ; Original si inconnu.
  static SafeboxQuality fromName(String? name) =>
      values.firstWhere((q) => q.name == name, orElse: () => original);
}

const int kSafeboxVideoAudioBitrate = 64000;
const int kSafeboxVideoMaxFrameRate = 30;
const double kSafeboxVideoIFrameIntervalSeconds = 3;

/// En dessous de ce poids, une vidéo part telle quelle : le gain ne vaudrait
/// pas l'attente de la conversion.
const int kSafeboxVideoTranscodeAboveBytes = 1024 * 1024;

/// Sans dimensions ni durée lisibles, on ne convertit qu'au-delà de ce poids.
const int kSafeboxVideoWithoutFactsAboveBytes = 8 * 1024 * 1024;

/// Ce que vise un format pour une vidéo.
class SafeboxVideoProfile {
  const SafeboxVideoProfile({required this.shortSide, required this.videoBitrate, required this.hevc});

  /// Petit côté de l'image (720 ou 480) ; le grand côté suit en 16/9.
  final int shortSide;
  final int videoBitrate;

  /// H.265 quand ce téléphone l'encode et que les destinataires le lisent.
  final bool hevc;

  int get longSide => (shortSide * 16 / 9).round();
  int get totalBitrate => videoBitrate + kSafeboxVideoAudioBitrate;
  String get mime => hevc ? 'video/hevc' : 'video/avc';
}

/// Le profil vidéo d'un format ; null pour Original.
SafeboxVideoProfile? safeboxVideoProfile(SafeboxQuality q, {required bool hevc}) => switch (q) {
      SafeboxQuality.original => null,
      SafeboxQuality.hd => SafeboxVideoProfile(shortSide: 720, videoBitrate: hevc ? 1300000 : 2000000, hevc: hevc),
      SafeboxQuality.compressed => SafeboxVideoProfile(shortSide: 480, videoBitrate: hevc ? 600000 : 1000000, hevc: hevc),
    };

/// Le profil photo d'un format ; null pour Original. `bytesPerPixel` : poids
/// moyen d'un pixel d'une photo d'appareil à cette qualité JPEG.
({int longSide, int jpegQuality, double bytesPerPixel})? safeboxPhotoProfile(SafeboxQuality q) => switch (q) {
      SafeboxQuality.original => null,
      SafeboxQuality.hd => (longSide: 2560, jpegQuality: 85, bytesPerPixel: 0.24),
      SafeboxQuality.compressed => (longSide: 1600, jpegQuality: 75, bytesPerPixel: 0.16),
    };

/// Le débit AAC d'une musique dans ce format ; null pour Original.
int? safeboxAudioBitrate(SafeboxQuality q) => switch (q) {
      SafeboxQuality.original => null,
      SafeboxQuality.hd => 128000,
      SafeboxQuality.compressed => 64000,
    };

/// Ce qu'on sait d'une photo, d'une vidéo ou d'une musique avant de décider.
class SafeboxMediaFacts {
  const SafeboxMediaFacts({
    required this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.frameRate,
    this.hevcSource = false,
  });

  final int sizeBytes;
  final int? width;
  final int? height;
  final double? durationMs;
  final double? frameRate;

  /// La vidéo est déjà en H.265.
  final bool hevcSource;
}

/// Faut-il convertir cette vidéo pour ce profil ? Non quand elle est déjà
/// plus légère : elle part telle quelle.
bool safeboxShouldTranscodeVideo(SafeboxMediaFacts f, SafeboxVideoProfile p) {
  // Une source en H.265 qui doit partir en H.264 (des destinataires ne le
  // lisent pas) : conversion obligée.
  if (f.hevcSource && !p.hevc) return true;
  if (f.sizeBytes < kSafeboxVideoTranscodeAboveBytes) return false;
  final w = f.width, h = f.height, ms = f.durationMs;
  if (w == null || h == null || w <= 0 || h <= 0 || ms == null || ms <= 0) {
    return f.sizeBytes >= kSafeboxVideoWithoutFactsAboveBytes;
  }
  // Petit et grand côtés : une vidéo en portrait est rapportée dans un sens
  // ou dans l'autre selon la plateforme.
  if (math.min(w, h) > p.shortSide || math.max(w, h) > p.longSide) return true;
  final fps = f.frameRate;
  if (fps != null && fps > kSafeboxVideoMaxFrameRate + 0.5) return true;
  // Déjà à la bonne taille : seulement si le débit dépasse nettement la cible.
  return f.sizeBytes * 8 * 1000 / ms > p.totalBitrate * 1.2;
}

/// Poids probable d'une vidéo dans ce format.
int safeboxEstimateVideoBytes(SafeboxMediaFacts f, SafeboxQuality q, {required bool hevc}) {
  final p = safeboxVideoProfile(q, hevc: hevc);
  if (p == null || !safeboxShouldTranscodeVideo(f, p)) return f.sizeBytes;
  final ms = f.durationMs;
  // Sans durée, rien ne permet de calculer : une part du poids, à la louche.
  if (ms == null || ms <= 0) return (f.sizeBytes * (q == SafeboxQuality.hd ? 0.5 : 0.3)).round();
  return math.min(f.sizeBytes, (ms * p.totalBitrate / 8000).ceil());
}

/// Poids probable d'une photo dans ce format.
int safeboxEstimatePhotoBytes(SafeboxMediaFacts f, SafeboxQuality q) {
  final p = safeboxPhotoProfile(q);
  if (p == null) return f.sizeBytes;
  final w = f.width, h = f.height;
  if (w == null || h == null || w <= 0 || h <= 0) {
    return (f.sizeBytes * (q == SafeboxQuality.hd ? 0.5 : 0.3)).round();
  }
  final long = math.max(w, h);
  final echelle = long > p.longSide ? p.longSide / long : 1.0;
  return math.min(f.sizeBytes, (w * h * echelle * echelle * p.bytesPerPixel).round());
}

/// Poids probable d'une musique dans ce format : seulement si sa source est
/// nettement plus lourde que la cible (un MP3 à 128 kbit/s reste tel quel en HD).
int safeboxEstimateAudioBytes(SafeboxMediaFacts f, SafeboxQuality q) {
  final debit = safeboxAudioBitrate(q);
  final ms = f.durationMs;
  if (debit == null || ms == null || ms <= 0) return f.sizeBytes;
  if (f.sizeBytes * 8 * 1000 / ms <= debit * 1.2) return f.sizeBytes;
  return math.min(f.sizeBytes, (ms * debit / 8000).ceil());
}

/// Le format retenu : celui demandé s'il tient sous la limite d'un fichier,
/// sinon le suivant plus léger ; null si aucun ne tient.
SafeboxQuality? safeboxFittingQuality(SafeboxQuality preferred, bool Function(SafeboxQuality q) fits) {
  for (final q in SafeboxQuality.values.skip(preferred.index)) {
    if (fits(q)) return q;
  }
  return null;
}
