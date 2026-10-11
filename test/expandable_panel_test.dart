// Panneau du bas extensible (émojis · stickers) : niveaux normal / grand /
// fermé par geste simulé et par tap sur la poignée, accrochage selon la
// vitesse, grille tirée vers le bas, Retour du système, réduction des
// animations, hauteur bornée, clair / sombre × fr / en / zh.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/theme/app_theme.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/widgets/chat/expandable_panel.dart';

const double _normal = 300;
const double _large = 540;

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    required this.controller,
    this.scroll,
    this.closed,
  });
  final ExpandablePanelController controller;
  final ScrollController? scroll;
  final ValueNotifier<int>? closed;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool open = true;

  void close() => setState(() => open = false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        ExpandablePanelReserve(
          controller: widget.controller,
          active: open,
          normalHeight: _normal,
          child: const SizedBox.expand(key: ValueKey('main')),
        ),
        if (open)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ExpandablePanel(
              controller: widget.controller,
              normalHeight: _normal,
              largeHeight: _large,
              expandLabel: l10n.chatPanelExpand,
              collapseLabel: l10n.chatPanelCollapse,
              onClose: () {
                widget.closed?.value++;
                setState(() => open = false);
              },
              child: ListView.builder(
                controller: widget.scroll,
                itemCount: 80,
                itemBuilder: (_, i) => SizedBox(height: 48, child: Text('ligne $i')),
              ),
            ),
          ),
      ],
    );
  }
}

Widget _app(
  Widget body, {
  Brightness b = Brightness.light,
  String lang = 'fr',
  bool reduce = false,
}) => MaterialApp(
  theme: b == Brightness.light ? AppTheme.light : AppTheme.dark,
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: c!,
  ),
  home: Scaffold(body: body),
);

void main() {
  final handle = find.byKey(const ValueKey('panel-handle'));
  final panel = find.byType(ExpandablePanel);

  late ExpandablePanelController ctl;
  late ValueNotifier<int> closed;

  setUp(() {
    ctl = ExpandablePanelController();
    closed = ValueNotifier<int>(0);
  });
  tearDown(() {
    ctl.dispose();
    closed.dispose();
  });

  Future<void> pumpPanel(
    WidgetTester t, {
    bool reduce = false,
    Brightness b = Brightness.light,
    String lang = 'fr',
    ScrollController? scroll,
  }) async {
    await t.pumpWidget(
      _app(
        _Harness(controller: ctl, closed: closed, scroll: scroll),
        reduce: reduce,
        b: b,
        lang: lang,
      ),
    );
  }

  double h(WidgetTester t) => t.getSize(panel).height;

  group('hauteurs', () {
    test('normal 280 + poignée + zone sûre ; grand ~90 % ; jamais hors limites', () {
      final r = ExpandablePanel.heightsFor(available: 700, bottomInset: 20);
      expect(r.normal, 280 + kPanelHandleHeight + 20);
      expect(r.large, closeTo(630, 0.001));
    });

    test('petit écran / paysage : le normal est borné à 60 %, le grand ≥ normal', () {
      final r = ExpandablePanel.heightsFor(available: 300, bottomInset: 0);
      expect(r.normal, closeTo(180, 0.001));
      expect(r.large, closeTo(270, 0.001));
      expect(r.large, greaterThanOrEqualTo(r.normal));
      expect(r.large, lessThanOrEqualTo(300));
    });

    test('place nulle ou négative : aucune hauteur négative', () {
      final r = ExpandablePanel.heightsFor(available: -5, bottomInset: 10);
      expect(r.normal, 0);
      expect(r.large, 0);
    });
  });

  group('niveaux par geste', () {
    testWidgets('ouvre à la hauteur normale, poignée visible', (t) async {
      await pumpPanel(t);
      expect(h(t), _normal);
      expect(handle, findsOneWidget);
      expect(t.getSize(handle).height, greaterThanOrEqualTo(48));
      expect(ctl.level, PanelLevel.normal);
      expect(ctl.covering, isFalse);
    });

    testWidgets('glisser la poignée vers le haut : grand', (t) async {
      await pumpPanel(t);
      await t.drag(handle, const Offset(0, -260));
      await t.pumpAndSettle();
      expect(h(t), _large);
      expect(ctl.level, PanelLevel.large);
      expect(ctl.covering, isTrue, reason: 'le champ de saisie se masque');
    });

    testWidgets('petit glissé vers le haut, lent : retombe au normal', (t) async {
      await pumpPanel(t);
      await t.drag(handle, const Offset(0, -90));
      await t.pumpAndSettle();
      expect(h(t), _normal);
      expect(ctl.level, PanelLevel.normal);
    });

    testWidgets('jeté rapide vers le haut, même court : grand (accrochage à la vitesse)', (t) async {
      await pumpPanel(t);
      await t.fling(handle, const Offset(0, -60), 2500);
      await t.pumpAndSettle();
      expect(h(t), _large);
    });

    testWidgets('grand → normal par glissé vers le bas, sans fermer', (t) async {
      await pumpPanel(t);
      ctl.expand();
      await t.pumpAndSettle();
      expect(h(t), _large);
      await t.drag(handle, const Offset(0, 500));
      await t.pumpAndSettle();
      expect(h(t), _normal, reason: 'borné au niveau normal, jamais fermé d\'un trait');
      expect(closed.value, 0);
      expect(ctl.level, PanelLevel.normal);
      expect(ctl.covering, isFalse);
    });

    testWidgets('grand → jeté vers le bas : normal, pas fermé', (t) async {
      await pumpPanel(t);
      ctl.expand();
      await t.pumpAndSettle();
      await t.fling(handle, const Offset(0, 120), 3000);
      await t.pumpAndSettle();
      expect(h(t), _normal);
      expect(closed.value, 0);
    });

    testWidgets('normal → fermé par glissé vers le bas', (t) async {
      await pumpPanel(t);
      await t.drag(handle, const Offset(0, 260));
      await t.pumpAndSettle();
      expect(closed.value, 1);
      expect(panel, findsNothing);
    });

    testWidgets('normal → fermé par jeté vers le bas, même court', (t) async {
      await pumpPanel(t);
      await t.fling(handle, const Offset(0, 50), 2500);
      await t.pumpAndSettle();
      expect(closed.value, 1);
    });

    testWidgets('petit glissé vers le bas, lent : reste normal', (t) async {
      await pumpPanel(t);
      await t.drag(handle, const Offset(0, 60));
      await t.pumpAndSettle();
      expect(h(t), _normal);
      expect(closed.value, 0);
    });

    testWidgets('séquence complète : normal → grand → normal → fermé', (t) async {
      await pumpPanel(t);
      await t.drag(handle, const Offset(0, -260));
      await t.pumpAndSettle();
      expect(h(t), _large);
      await t.drag(handle, const Offset(0, 500));
      await t.pumpAndSettle();
      expect(h(t), _normal);
      await t.drag(handle, const Offset(0, 260));
      await t.pumpAndSettle();
      expect(closed.value, 1);
    });

    testWidgets('pendant le glissé, la hauteur suit le doigt', (t) async {
      await pumpPanel(t);
      final g = await t.startGesture(t.getCenter(handle));
      await g.moveBy(const Offset(0, -40));
      await t.pump();
      await g.moveBy(const Offset(0, -60));
      await t.pump();
      expect(h(t), greaterThan(_normal + 40));
      expect(h(t), lessThan(_large));
      await g.up();
      await t.pumpAndSettle();
    });
  });

  group('poignée au tap et accessibilité', () {
    testWidgets('tap : normal → grand → normal', (t) async {
      await pumpPanel(t);
      await t.tap(handle);
      await t.pumpAndSettle();
      expect(h(t), _large);
      expect(ctl.isLarge, isTrue);
      await t.tap(handle);
      await t.pumpAndSettle();
      expect(h(t), _normal);
      expect(ctl.isLarge, isFalse);
      expect(closed.value, 0);
    });

    testWidgets('animation fluide : image intermédiaire entre les deux niveaux', (t) async {
      await pumpPanel(t);
      await t.tap(handle);
      await t.pump();
      await t.pump(const Duration(milliseconds: 60));
      expect(h(t), greaterThan(_normal));
      expect(h(t), lessThan(_large));
      await t.pumpAndSettle();
      expect(h(t), _large);
    });

    testWidgets('Semantics « Agrandir / Réduire le panneau », activable', (t) async {
      final s = t.ensureSemantics();
      await pumpPanel(t);
      expect(find.bySemanticsLabel('Agrandir le panneau'), findsOneWidget);
      final node = t.getSemantics(find.bySemanticsLabel('Agrandir le panneau'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await t.pumpAndSettle();
      expect(h(t), _large);
      expect(find.bySemanticsLabel('Réduire le panneau'), findsOneWidget);
      expect(find.bySemanticsLabel('Agrandir le panneau'), findsNothing);
      s.dispose();
    });
  });

  group('Retour du système', () {
    testWidgets('réduit d\'abord le panneau grand, puis laisse l\'écran fermer', (t) async {
      await pumpPanel(t);
      // Normal : rien à réduire, l'écran ferme le panneau lui-même.
      expect(ctl.collapse(), isFalse);
      ctl.expand();
      await t.pumpAndSettle();
      expect(h(t), _large);
      expect(ctl.collapse(), isTrue);
      await t.pumpAndSettle();
      expect(h(t), _normal);
      expect(ctl.collapse(), isFalse);
      expect(closed.value, 0);
    });

    testWidgets('PopScope : Retour → grand→normal ; Retour → fermé', (t) async {
      final key = GlobalKey<_HarnessState>();
      await t.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => PopScope(
              canPop: !(key.currentState?.open ?? true),
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (!ctl.collapse()) {
                  key.currentState!.close();
                  setState(() {});
                }
              },
              child: _Harness(key: key, controller: ctl, closed: closed),
            ),
          ),
        ),
      );
      ctl.expand();
      await t.pumpAndSettle();
      expect(h(t), _large);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(h(t), _normal);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(panel, findsNothing);
    });
  });

  group('défilement de la grille', () {
    testWidgets('grille en haut tirée vers le bas : le panneau se réduit au lieu de défiler', (t) async {
      final sc = ScrollController();
      addTearDown(sc.dispose);
      await pumpPanel(t, scroll: sc);
      ctl.expand();
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, 320));
      await t.pumpAndSettle();
      expect(sc.offset, 0);
      expect(h(t), _normal);
      expect(closed.value, 0);
    });

    testWidgets('normal, grille en haut tirée loin vers le bas : fermeture', (t) async {
      final sc = ScrollController();
      addTearDown(sc.dispose);
      await pumpPanel(t, scroll: sc);
      await t.drag(find.byType(ListView), const Offset(0, 300));
      await t.pumpAndSettle();
      expect(closed.value, 1);
      expect(panel, findsNothing);
    });

    testWidgets('grille défilée : tirer vers le bas fait remonter la grille, pas le panneau', (t) async {
      final sc = ScrollController();
      addTearDown(sc.dispose);
      await pumpPanel(t, scroll: sc);
      ctl.expand();
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, -300));
      await t.pumpAndSettle();
      expect(sc.offset, greaterThan(100));
      await t.drag(find.byType(ListView), const Offset(0, 100));
      await t.pumpAndSettle();
      expect(h(t), _large);
      expect(ctl.level, PanelLevel.large);
    });

    testWidgets('tirer la grille vers le haut ne change pas le niveau', (t) async {
      final sc = ScrollController();
      addTearDown(sc.dispose);
      await pumpPanel(t, scroll: sc);
      await t.drag(find.byType(ListView), const Offset(0, -200));
      await t.pumpAndSettle();
      expect(sc.offset, greaterThan(0));
      expect(h(t), _normal);
    });
  });

  group('place réservée à la liste de messages', () {
    testWidgets('niveau grand : la liste garde la place du normal (le panneau la recouvre)', (t) async {
      const key = ValueKey('main');
      await pumpPanel(t);
      final main = find.byKey(key);
      expect(t.getSize(main).height, 600 - _normal);
      ctl.expand();
      await t.pumpAndSettle();
      expect(t.getSize(main).height, 600 - _normal);
    });

    testWidgets('fermé : toute la place revient à la liste', (t) async {
      await pumpPanel(t);
      await t.drag(handle, const Offset(0, 260));
      await t.pumpAndSettle();
      expect(t.getSize(find.byKey(const ValueKey('main'))).height, 600);
    });

    testWidgets('en cours de fermeture, la réserve suit le panneau', (t) async {
      await pumpPanel(t);
      final g = await t.startGesture(t.getCenter(handle));
      await g.moveBy(const Offset(0, 60));
      await t.pump();
      await g.moveBy(const Offset(0, 100));
      await t.pump();
      final reserved = 600 - t.getSize(find.byKey(const ValueKey('main'))).height;
      expect(reserved, closeTo(h(t), 0.5));
      expect(reserved, lessThan(_normal));
      await g.up();
      await t.pumpAndSettle();
    });
  });

  group('réduction des animations', () {
    testWidgets('disableAnimations : changement de niveau immédiat, sans image intermédiaire', (t) async {
      await pumpPanel(t, reduce: true);
      await t.tap(handle);
      await t.pump();
      expect(h(t), _large, reason: 'aucune animation');
      expect(ctl.covering, isTrue);
      await t.tap(handle);
      await t.pump();
      expect(h(t), _normal);
      await t.drag(handle, const Offset(0, 260));
      await t.pump();
      expect(closed.value, 1);
    });
  });

  group('tailles et zones sûres', () {
    testWidgets('changement de hauteur disponible (rotation, clavier) : le niveau reste, la hauteur suit', (t) async {
      final heights = ValueNotifier<({double n, double l})>((n: 300, l: 540));
      addTearDown(heights.dispose);
      await t.pumpWidget(
        _app(
          ValueListenableBuilder(
            valueListenable: heights,
            builder: (context, v, _) => Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ExpandablePanel(
                    controller: ctl,
                    normalHeight: v.n,
                    largeHeight: v.l,
                    expandLabel: 'a',
                    collapseLabel: 'b',
                    onClose: () {},
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      ctl.expand();
      await t.pumpAndSettle();
      expect(h(t), 540);
      heights.value = (n: 150, l: 220);
      await t.pump();
      expect(h(t), 220);
      expect(ctl.isLarge, isTrue);
      heights.value = (n: 300, l: 540);
      await t.pump();
      expect(h(t), 540);
    });

    testWidgets('très petit écran : aucun débordement ni exception', (t) async {
      t.view.physicalSize = const Size(400, 220);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final r = ExpandablePanel.heightsFor(available: 220, bottomInset: 0);
      await t.pumpWidget(
        _app(
          Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExpandablePanel(
                  controller: ctl,
                  normalHeight: r.normal,
                  largeHeight: r.large,
                  expandLabel: 'a',
                  collapseLabel: 'b',
                  onClose: () {},
                  child: ListView(children: const [Text('x')]),
                ),
              ),
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
      ctl.expand();
      await t.pumpAndSettle();
      expect(h(t), lessThanOrEqualTo(220));
      expect(t.takeException(), isNull);
    });
  });

  group('clair / sombre × fr / en / zh', () {
    const expand = {'fr': 'Agrandir le panneau', 'en': 'Expand panel', 'zh': '展开面板'};
    const collapse = {'fr': 'Réduire le panneau', 'en': 'Collapse panel', 'zh': '收起面板'};
    for (final b in Brightness.values) {
      for (final lang in expand.keys) {
        testWidgets('poignée — ${b.name} — $lang', (t) async {
          final s = t.ensureSemantics();
          await pumpPanel(t, b: b, lang: lang);
          expect(find.bySemanticsLabel(expand[lang]!), findsOneWidget);
          // Couleurs du thème, jamais en dur.
          final theme = b == Brightness.light ? AppTheme.light : AppTheme.dark;
          final deco = t.widgetList<DecoratedBox>(
            find.descendant(of: panel, matching: find.byType(DecoratedBox)),
          ).map((d) => d.decoration).whereType<BoxDecoration>();
          expect(
            deco.any((d) => d.color == theme.colorScheme.surface),
            isTrue,
          );
          await t.tap(handle);
          await t.pumpAndSettle();
          expect(find.bySemanticsLabel(collapse[lang]!), findsOneWidget);
          expect(t.takeException(), isNull);
          s.dispose();
        });
      }
    }
  });
}
