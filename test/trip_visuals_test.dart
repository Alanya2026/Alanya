import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/talky_models.dart';
import 'package:talky_flutter/widgets/trips/trip_visuals.dart';

/// Lisibilité des textes du volet, en clair **et** en sombre.
///
/// Ces tests verrouillent un défaut qui a atteint les écrans : la palette
/// sémantique de l'application est identique dans les deux thèmes — `success`
/// vaut `#1FA363`, `warning` `#F59E0B`, `error` `#EF4444` — et ce sont des
/// couleurs de *remplissage*. Employées en texte, l'ambre plafonne à 2:1 sur
/// blanc et le vert décroche sur fond sombre.
///
/// Pire, `colorScheme.outline` est un jeton de **bordure** (`#E2E5EC` en clair,
/// 1,26:1 sur blanc) et servait de couleur de texte dans tout le volet : les
/// écrans étaient illisibles dans les deux thèmes.
void main() {
  double luminance(Color c) {
    double canal(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * canal(c.r) + 0.7152 * canal(c.g) + 0.0722 * canal(c.b);
  }

  double contraste(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// Construit un contexte réel sous un thème donné : `TripVisual.encre` lit le
  /// `ColorScheme`, on ne peut pas l'éprouver hors arbre de widgets.
  Future<BuildContext> contexteSous(WidgetTester tester, Brightness b) async {
    late BuildContext capture;
    await tester.pumpWidget(MaterialApp(
      theme: b == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: Builder(builder: (c) {
        capture = c;
        return const SizedBox();
      }),
    ));
    return capture;
  }

  const etats = [
    TripState.active,
    TripState.awaitingConfirm,
    TripState.alert,
    TripState.sos,
    TripState.closedConfirmed,
    TripState.closedCancelled,
  ];

  for (final theme in Brightness.values) {
    final nom = theme == Brightness.light ? 'clair' : 'sombre';

    testWidgets('thème $nom : toute encre d\'état atteint 4.5:1', (t) async {
      final ctx = await contexteSous(t, theme);
      final fond = Theme.of(ctx).colorScheme.surface;

      for (final etat in etats) {
        final v = TripVisual.resolve(ctx, state: etat);
        expect(
          contraste(v.ink, fond),
          greaterThanOrEqualTo(4.5),
          reason: 'encre illisible pour « $etat » en thème $nom',
        );
      }
    });

    testWidgets('thème $nom : le signal perdu reste lisible', (t) async {
      // Le cas qui avait échappé : un état gris, dont l'encre passait
      // inchangée par la dérivation parce qu'elle n'est pas saturée.
      final ctx = await contexteSous(t, theme);
      final v = TripVisual.resolve(ctx, state: TripState.active, stale: true);
      expect(contraste(v.ink, Theme.of(ctx).colorScheme.surface),
          greaterThanOrEqualTo(4.5));
    });

    testWidgets('thème $nom : un jeton de bordure ne peut pas servir d\'encre',
        (t) async {
      // Le filet de `encre()` : passer `outline` doit rendre autre chose que
      // `outline`. C'est exactement l'erreur qui a rendu les écrans illisibles.
      final ctx = await contexteSous(t, theme);
      final schema = Theme.of(ctx).colorScheme;
      final rendu = TripVisual.encre(ctx, schema.outline);
      expect(contraste(rendu, schema.surface), greaterThanOrEqualTo(3.0));
    });
  }

  testWidgets('la règle de palette tient : un GPS perdu n\'est jamais rouge',
      (t) async {
    final ctx = await contexteSous(t, Brightness.light);
    final perdu = TripVisual.resolve(ctx, state: TripState.active, stale: true);
    final alerte = TripVisual.resolve(ctx, state: TripState.alert);

    expect(perdu.tone, TripTone.stale);
    expect(perdu.color, isNot(equals(alerte.color)),
        reason: 'le rouge signifie que le cercle a été prévenu, rien d\'autre');
  });

  testWidgets('une alerte reste rouge même sans position', (t) async {
    // `stale` ne doit pas adoucir une alerte : c'est justement le cas où
    // l'absence de position est le sujet.
    final ctx = await contexteSous(t, Brightness.light);
    final v = TripVisual.resolve(ctx, state: TripState.alert, stale: true);
    expect(v.tone, TripTone.alerted);
  });
}
