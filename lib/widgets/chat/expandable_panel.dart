import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/theme/app_theme.dart';

/// Niveau d'ouverture du panneau : hauteur d'origine, ou grand (~90 % de la
/// place disponible). « Fermé » n'est pas un niveau : le panneau demande alors
/// sa propre disparition (`onClose`).
enum PanelLevel { normal, large }

/// Hauteur de la poignée, cible tactile comprise (≥ 48 dp).
const double kPanelHandleHeight = 48;

/// Vitesse (dp/s) au-delà de laquelle un geste est un « jeté » : il change de
/// niveau quelle que soit la position où il se termine.
const double kPanelFlingVelocity = 700;

/// Pilote d'un [ExpandablePanel] depuis l'extérieur : l'écran qui l'héberge
/// lit le niveau (masquer le champ de saisie, bouton Retour) sans connaître
/// l'animation.
class ExpandablePanelController extends ChangeNotifier {
  PanelLevel _level = PanelLevel.normal;
  bool _covering = false;
  double? _height;
  final _HeightTicker _heightTicker = _HeightTicker();
  _ExpandablePanelState? _state;

  /// Niveau visé (il change dès le début d'une animation).
  PanelLevel get level => _level;
  bool get isLarge => _level == PanelLevel.large;

  /// Le panneau est grand **et posé** : il recouvre le champ de saisie, qu'on
  /// peut alors masquer sans que la liste de messages saute pendant le geste.
  bool get covering => _covering;

  /// Prévient à chaque image de l'animation de hauteur (haute fréquence).
  Listenable get heightChanges => _heightTicker;

  /// Hauteur à réserver dans la mise en page sous la liste de messages : celle
  /// du panneau, **plafonnée à sa hauteur normale** (le niveau grand recouvre
  /// la liste au lieu de la repousser).
  double reserve(double normalHeight) {
    final h = _height;
    if (h == null) return normalHeight;
    return math.min(h, normalHeight);
  }

  /// Réduit un panneau grand (Retour du système). `false` s'il ne l'était pas.
  bool collapse() {
    final s = _state;
    if (s == null || !isLarge) return false;
    s._goTo(PanelLevel.normal);
    return true;
  }

  /// Agrandit le panneau.
  void expand() => _state?._goTo(PanelLevel.large);

  void _setLevel(PanelLevel level, {required bool covering}) {
    if (_level == level && _covering == covering) return;
    _level = level;
    _covering = covering;
    notifyListeners();
  }

  void _setHeight(double h) {
    _height = h;
    _heightTicker.fire();
  }

  /// Oublie l'état du panneau démonté, sans rien notifier (peut être appelé
  /// pendant le démontage de l'arbre).
  void _forget() {
    _level = PanelLevel.normal;
    _covering = false;
    _height = null;
  }
}

class _HeightTicker extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Réserve, sous le contenu principal, la place du panneau **normal** : le
/// panneau lui-même flotte au-dessus (cf. [ExpandablePanel]) pour pouvoir
/// grandir sans refaire la mise en page de tout l'écran.
class ExpandablePanelReserve extends StatelessWidget {
  const ExpandablePanelReserve({
    super.key,
    required this.controller,
    required this.active,
    required this.normalHeight,
    required this.child,
  });

  final ExpandablePanelController controller;

  /// Le panneau est affiché.
  final bool active;
  final double normalHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.heightChanges,
      child: child,
      builder: (context, child) => Padding(
        padding: EdgeInsets.only(
          bottom: active ? controller.reserve(normalHeight) : 0,
        ),
        child: child,
      ),
    );
  }
}

/// Panneau du bas (émojis · stickers) extensible par sa poignée.
///
/// - Deux niveaux : normal ([normalHeight]) et grand ([largeHeight]).
/// - Glisser la poignée vers le haut agrandit ; vers le bas : grand → normal,
///   puis normal → fermé (`onClose`). Un geste parti du niveau grand ne ferme
///   jamais d'un seul trait.
/// - Au relâchement, le panneau s'accroche au niveau le plus proche, ou au
///   suivant si le geste est un « jeté » ([kPanelFlingVelocity]).
/// - Une grille en haut de sa course qu'on tire vers le bas réduit le panneau
///   au lieu de défiler.
/// - `MediaQuery.disableAnimations` : changement de niveau sans animation.
///
/// À poser dans un `Stack`, ancré en bas (`Positioned`) : la poignée reste
/// sensible sur toute sa hauteur, même quand le panneau recouvre le reste.
class ExpandablePanel extends StatefulWidget {
  const ExpandablePanel({
    super.key,
    required this.controller,
    required this.normalHeight,
    required this.largeHeight,
    required this.onClose,
    required this.expandLabel,
    required this.collapseLabel,
    required this.child,
    this.bottomInset = 0,
  });

  final ExpandablePanelController controller;
  final double normalHeight;
  final double largeHeight;

  /// Le panneau a fini de se fermer (glissé vers le bas).
  final VoidCallback onClose;

  /// Libellés d'accessibilité de la poignée.
  final String expandLabel;
  final String collapseLabel;

  /// Contenu : remplit la hauteur que le panneau lui donne.
  final Widget child;

  /// Zone sûre du bas, ajoutée sous le contenu.
  final double bottomInset;

  /// Hauteurs d'un panneau dont le contenu normal mesure [contentHeight], dans
  /// [available] dp de haut : le normal ne dépasse jamais 60 % de la place (petits
  /// écrans, paysage), le grand en prend ~90 %.
  static ({double normal, double large}) heightsFor({
    required double available,
    required double bottomInset,
    double contentHeight = 280,
  }) {
    final avail = math.max(0.0, available);
    final wanted = kPanelHandleHeight + contentHeight + bottomInset;
    final normal = math.min(wanted, avail * 0.6);
    final large = math.max(normal, avail * 0.9);
    return (normal: normal, large: large);
  }

  @override
  State<ExpandablePanel> createState() => _ExpandablePanelState();
}

class _ExpandablePanelState extends State<ExpandablePanel>
    with SingleTickerProviderStateMixin {
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
    ratio: 1,
  );

  // La valeur du contrôleur d'animation EST la hauteur du panneau, en dp.
  late final AnimationController _anim = AnimationController.unbounded(
    vsync: this,
    value: widget.normalHeight,
  );

  PanelLevel _level = PanelLevel.normal;
  bool _dragging = false;
  bool _viaScroll = false;
  double _dragMin = 0;
  int _gen = 0;

  double get _normal => widget.normalHeight;
  double get _large => math.max(widget.normalHeight, widget.largeHeight);

  @override
  void initState() {
    super.initState();
    widget.controller._forget();
    widget.controller._state = this;
    widget.controller._height = _anim.value;
    _anim.addListener(_onTick);
  }

  @override
  void didUpdateWidget(ExpandablePanel old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._forget();
      widget.controller._state = this;
    }
    final sizeChanged =
        old.normalHeight != widget.normalHeight ||
        old.largeHeight != widget.largeHeight;
    if (sizeChanged && !_dragging) {
      // Rotation, clavier, zones sûres : le niveau reste, la hauteur suit.
      _gen++;
      _anim.stop();
      _anim.value = _level == PanelLevel.large ? _large : _normal;
    }
  }

  @override
  void dispose() {
    _gen++;
    _anim.removeListener(_onTick);
    if (widget.controller._state == this) {
      widget.controller._state = null;
      widget.controller._forget();
    }
    _anim.dispose();
    super.dispose();
  }

  void _onTick() => widget.controller._setHeight(_anim.value);

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  // ── Geste ─────────────────────────────────────────────────────────

  void _beginDrag() {
    _gen++;
    _anim.stop();
    _dragging = true;
    // Parti du niveau grand : on ne descend pas plus bas que le normal.
    _dragMin = _level == PanelLevel.large ? _normal : 0;
    // Le champ de saisie réapparaît sous le panneau qui se retire.
    widget.controller._setLevel(_level, covering: false);
  }

  void _dragBy(double up) {
    _anim.value = (_anim.value + up).clamp(_dragMin, _large).toDouble();
  }

  void _endDrag(double velocityUp) {
    if (!_dragging) return;
    _dragging = false;
    _release(velocityUp);
  }

  /// Choisit le niveau d'accrochage selon la position et la vitesse.
  void _release(double velocityUp) {
    final h = _anim.value;
    final stops = <double>[
      if (_dragMin < _normal) 0.0,
      _normal,
      if (_large > _normal) _large,
    ];
    double target;
    if (velocityUp.abs() > kPanelFlingVelocity) {
      target = velocityUp > 0
          ? stops.firstWhere((s) => s > h + 1, orElse: () => stops.last)
          : stops.lastWhere((s) => s < h - 1, orElse: () => stops.first);
    } else {
      final projected = h + velocityUp * 0.1;
      target = stops.reduce(
        (a, b) => (a - projected).abs() <= (b - projected).abs() ? a : b,
      );
    }
    _settle(target, velocityUp);
  }

  void _goTo(PanelLevel level) {
    _gen++;
    _anim.stop();
    _dragging = false;
    _viaScroll = false;
    _settle(level == PanelLevel.large ? _large : _normal, 0);
  }

  void _toggle() =>
      _goTo(_level == PanelLevel.large ? PanelLevel.normal : PanelLevel.large);

  /// Anime jusqu'à [target] (0 = fermé), puis fixe le niveau.
  void _settle(double target, double velocityUp) {
    final closing = target <= 0;
    final next = closing
        ? _level
        : (target >= _large && _large > _normal
              ? PanelLevel.large
              : PanelLevel.normal);
    _level = next;
    widget.controller._setLevel(next, covering: false);
    if (mounted) setState(() {});
    if (_reduceMotion || (_anim.value - target).abs() < 0.5) {
      _anim.value = target;
      _arrived(target);
      return;
    }
    final gen = ++_gen;
    _anim
        .animateWith(SpringSimulation(_spring, _anim.value, target, velocityUp))
        .then<void>((_) {
          if (mounted && gen == _gen) {
            _anim.value = target;
            _arrived(target);
          }
        });
  }

  void _arrived(double target) {
    if (target <= 0) {
      widget.onClose();
      return;
    }
    widget.controller._setLevel(
      _level,
      covering: _level == PanelLevel.large,
    );
  }

  // ── Défilement : une grille en haut qu'on tire vers le bas ────────────

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification) {
      if (n.dragDetails != null && n.overscroll < 0) {
        if (!_dragging) {
          _beginDrag();
          _viaScroll = true;
        }
        if (_viaScroll) _dragBy(n.overscroll);
      }
    } else if (n is ScrollEndNotification && _viaScroll) {
      _viaScroll = false;
      _endDrag(-(n.dragDetails?.primaryVelocity ?? 0));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final large = _level == PanelLevel.large;
    final handle = Semantics(
      container: true,
      button: true,
      label: large ? widget.collapseLabel : widget.expandLabel,
      onTap: _toggle,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('panel-handle'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        onVerticalDragStart: (_) => _beginDrag(),
        onVerticalDragUpdate: (d) => _dragBy(-(d.primaryDelta ?? d.delta.dy)),
        onVerticalDragEnd: (d) => _endDrag(-(d.primaryVelocity ?? 0)),
        onVerticalDragCancel: () => _endDrag(0),
        child: SizedBox(
          height: kPanelHandleHeight,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          handle,
          Expanded(
            // Défilement « tiré vers le bas » : voir `_onScroll`. Butée franche
            // (pas de rebond) pour que le tirage atteigne le panneau.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(overscroll: false, physics: const ClampingScrollPhysics()),
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: widget.child,
              ),
            ),
          ),
          SizedBox(height: widget.bottomInset),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _anim,
      child: content,
      builder: (context, child) {
        final h = _anim.value.clamp(0.0, _large).toDouble();
        // Sous la hauteur normale, le contenu garde la sienne et se laisse
        // rogner par le bas : il glisse hors de vue avec la poignée.
        final contentHeight = math.max(h, _normal);
        return SizedBox(
          height: h,
          width: double.infinity,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: contentHeight,
              maxHeight: contentHeight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
