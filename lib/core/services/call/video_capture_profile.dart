import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../billing/entitlement_service.dart';
import '../billing/entitlements.dart';

/// Qualité de la vidéo ENVOYÉE pendant un appel individuel : taille et cadence
/// de capture de la caméra, plafonds de cadence et de débit de l'encodeur.
///
/// On fixe la capture au lieu de laisser le téléphone filmer en 720p et
/// WebRTC tout recompresser : une image trop grande, écrasée pour passer sur
/// un réseau faible, rend des mouvements saccadés. Sous ce plafond, WebRTC
/// continue de s'adapter seul à la connexion.
enum CallVideoQuality {
  low('low', 640, 360, 20, 600000),
  // 848 et non 854 : un multiple de 16, mieux géré par les encodeurs matériels.
  standard('standard', 848, 480, 30, 1200000),
  hd('hd', 1280, 720, 30, 2500000);

  const CallVideoQuality(
    this.code,
    this.width,
    this.height,
    this.frameRate,
    this.maxBitrate,
  );

  final String code;
  final int width;
  final int height;

  /// Images par seconde demandées à la caméra, et plafond de l'encodeur.
  final int frameRate;

  /// Plafond de l'encodeur, en bits/s.
  final int maxBitrate;

  static CallVideoQuality fromCode(String? code) {
    for (final q in values) {
      if (q.code == code) return q;
    }
    return standard;
  }
}

/// Cadence de capture des groupes et réunions. En maillage, la vidéo est
/// encodée une fois par participant et sans plafond d'encodeur : on n'y monte
/// pas à la cadence du niveau Standard.
const int kConferenceCaptureFps = 24;

/// Contraintes `getUserMedia` de la vidéo. [frameRate] remplace la cadence du
/// niveau (conférences).
///
/// Des entiers, pas des maps `{ideal, min, max}` : flutter_webrtc 0.14 ne lit
/// pas les maps sur Android (il retombe sur 1280 × 720 à 30 i/s) et n'y lit
/// `ideal` qu'en texte sur iOS. Le plugin choisit le format de caméra le plus
/// proche de ces valeurs.
Map<String, dynamic> videoCaptureConstraints({
  CallVideoQuality? quality,
  int? frameRate,
}) {
  final q = quality ?? CallVideoQualityPreferences.effective;
  return <String, dynamic>{
    'width': q.width,
    'height': q.height,
    'frameRate': frameRate ?? q.frameRate,
  };
}

/// Choix de qualité vidéo des appels, réglé dans Réseau et données.
///
/// La HD est réservée à Alanya Plus ([PlusFeature.videoHd]) : sans ce droit,
/// l'appel part en Standard, mais le choix enregistré est gardé et reprend
/// dès l'abonnement.
class CallVideoQualityPreferences extends ChangeNotifier {
  static const _kQualityKey = 'call_video_quality';

  static CallVideoQualityPreferences? _bound;
  static CallVideoQuality _cached = CallVideoQuality.standard;
  static bool _prefsLoaded = false;

  CallVideoQuality _quality = _cached;

  CallVideoQualityPreferences() {
    _bound = this;
  }

  /// Le niveau choisi, HD compris même si le droit manque.
  CallVideoQuality get quality => _quality;

  static CallVideoQuality get chosen => _bound?._quality ?? _cached;

  /// Le niveau appliqué à l'appel.
  static CallVideoQuality get effective => effectiveFor(
        chosen,
        hdAllowed: EntitlementService.allows(PlusFeature.videoHd),
      );

  static CallVideoQuality effectiveFor(
    CallVideoQuality chosen, {
    required bool hdAllowed,
  }) =>
      chosen == CallVideoQuality.hd && !hdAllowed
          ? CallVideoQuality.standard
          : chosen;

  static Future<void> preload() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cached = CallVideoQuality.fromCode(prefs.getString(_kQualityKey));
    _prefsLoaded = true;
  }

  Future<void> load() async {
    await preload();
    if (_quality == _cached) return;
    _quality = _cached;
    notifyListeners();
  }

  Future<void> setQuality(CallVideoQuality quality) async {
    if (_quality == quality) return;
    _quality = quality;
    _cached = quality;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQualityKey, quality.code);
  }
}
