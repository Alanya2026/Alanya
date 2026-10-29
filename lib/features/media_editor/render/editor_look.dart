import '../model/editor_document.dart';

/// Matrices de couleur (4×5, format de `ColorFilter.matrix` : décalages en
/// 0–255) des filtres et réglages de [EditorLook]. Calcul pur, sans moteur :
/// l'écran et l'export appliquent la même matrice à l'image de base.
abstract final class EditorLookMatrix {
  static const List<double> identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Matrice de [look] : le filtre (mêlé à l'identité selon son intensité),
  /// puis les réglages fins par-dessus. `null` si le rendu est neutre.
  static List<double>? of(EditorLook look) {
    if (look.isNeutral) return null;
    var m = identity;
    if (look.filter != EditorFilter.none && look.intensity > 0) {
      m = lerp(identity, preset(look.filter), look.intensity);
    }
    if (look.warmth != 0) m = multiply(warmthMatrix(look.warmth), m);
    if (look.saturation != 0) {
      m = multiply(saturationMatrix(1 + look.saturation), m);
    }
    if (look.contrast != 0) {
      m = multiply(contrastMatrix(1 + 0.5 * look.contrast), m);
    }
    if (look.brightness != 0) {
      m = multiply(brightnessMatrix(60 * look.brightness), m);
    }
    return m;
  }

  /// Matrice pleine (intensité 1) d'un filtre.
  static List<double> preset(EditorFilter f) => switch (f) {
    EditorFilter.none => identity,
    EditorFilter.vivid => multiply(
      contrastMatrix(1.1),
      saturationMatrix(1.55),
    ),
    EditorFilter.warm => multiply(
      warmthMatrix(0.7),
      saturationMatrix(1.15),
    ),
    EditorFilter.soft => multiply(
      brightnessMatrix(12),
      multiply(contrastMatrix(0.85), saturationMatrix(0.85)),
    ),
    EditorFilter.mono => multiply(contrastMatrix(1.1), saturationMatrix(0)),
    EditorFilter.night => multiply(
      brightnessMatrix(-15),
      multiply(
        const <double>[
          0.8, 0, 0, 0, 0, //
          0, 0.9, 0, 0, 0, //
          0, 0, 1.1, 0, 12, //
          0, 0, 0, 1, 0, //
        ],
        saturationMatrix(0.7),
      ),
    ),
  };

  /// Saturation : 0 = niveaux de gris (luminance Rec. 709), 1 = inchangé.
  static List<double> saturationMatrix(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final i = 1 - s;
    return <double>[
      lr * i + s, lg * i, lb * i, 0, 0, //
      lr * i, lg * i + s, lb * i, 0, 0, //
      lr * i, lg * i, lb * i + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Contraste autour du gris moyen (128) ; 1 = inchangé.
  static List<double> contrastMatrix(double c) {
    final o = 128 * (1 - c);
    return <double>[
      c, 0, 0, 0, o, //
      0, c, 0, 0, o, //
      0, 0, c, 0, o, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// Luminosité : décalage ajouté à chaque canal (0–255).
  static List<double> brightnessMatrix(double b) => <double>[
    1, 0, 0, 0, b, //
    0, 1, 0, 0, b, //
    0, 0, 1, 0, b, //
    0, 0, 0, 1, 0, //
  ];

  /// Chaleur : rouge renforcé et bleu atténué (négatif : l'inverse).
  static List<double> warmthMatrix(double t) => <double>[
    1 + 0.1 * t, 0, 0, 0, 20 * t, //
    0, 1, 0, 0, 0, //
    0, 0, 1 - 0.15 * t, 0, -20 * t, //
    0, 0, 0, 1, 0, //
  ];

  /// Composition : applique [b], puis [a].
  static List<double> multiply(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 5; c++) {
        var v = 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[r * 5 + k] * b[k * 5 + c];
        }
        if (c == 4) v += a[r * 5 + 4];
        out[r * 5 + c] = v;
      }
    }
    return out;
  }

  /// Mélange linéaire de deux matrices ([t] = 0 : [a], 1 : [b]).
  static List<double> lerp(List<double> a, List<double> b, double t) =>
      List<double>.generate(20, (i) => a[i] + (b[i] - a[i]) * t);
}
