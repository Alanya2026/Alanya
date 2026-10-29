import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/services/stickers/sticker_cache.dart';
import '../../core/services/stickers/sticker_trust.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'sticker_image.dart';

/// Lit les octets du fichier d'un sticker (cache disque dédié). Une réponse
/// 404/410 doit remonter telle quelle (`HttpExceptionWithStatus`) : c'est ce
/// qui distingue « Sticker retiré » d'une simple panne de réseau.
typedef StickerBytesLoader = Future<Uint8List> Function(String url);

Future<Uint8List> _loadFromCache(String url) async {
  final file = await StickerCache.instance.manager.getSingleFile(url);
  return file.readAsBytes();
}

/// État de session de la lecture des stickers animés : quelles bulles ont déjà
/// joué leur animation, et combien jouent **en même temps** (mémoire).
///
/// Un sticker animé joue **une seule fois** quand sa bulle devient visible pour
/// la première fois dans la session (V1c, plan §7.7) ; le tap la rejoue. Le
/// serveur écrit une boucle infinie dans le fichier : « une fois » est une
/// décision du client.
abstract final class StickerPlayback {
  /// Bulles animées qui jouent au même instant. Les autres attendent leur tour
  /// (une lecture dure au plus ~3 s) : chaque lecture tient une image 512×512
  /// décodée (~1 Mo) plus le décodeur, sur des téléphones d'entrée de gamme.
  static const int maxConcurrent = 3;

  /// Mémoire de bulles déjà jouées, bornée (la session d'un téléphone peut
  /// voir passer des milliers de messages).
  static const int maxRemembered = 2000;

  static final Set<String> _played = <String>{};
  static int _active = 0;
  static final Queue<Completer<bool>> _waiters = Queue<Completer<bool>>();

  /// Décodeurs ouverts en ce moment (contrôle de fuite par les tests).
  @visibleForTesting
  static int liveCodecs = 0;

  /// Lectures qui tiennent une place.
  @visibleForTesting
  static int get activeSlots => _active;

  /// Bulles en attente d'une place.
  @visibleForTesting
  static int get waitingSlots => _waiters.length;

  static bool hasPlayed(String key) => _played.contains(key);

  static void _markPlayed(String key) {
    if (_played.length >= maxRemembered) _played.clear();
    _played.add(key);
  }

  /// Oublie tout (tests ; compte suivant).
  @visibleForTesting
  static void reset() {
    _played.clear();
    _active = 0;
    liveCodecs = 0;
    _waiters.clear();
  }

  /// Attend une place. `false` : l'attente a été annulée, rien n'est tenu.
  static Future<bool> _acquire(Completer<bool> ticket) {
    if (_active < maxConcurrent) {
      _active++;
      ticket.complete(true);
    } else {
      _waiters.add(ticket);
    }
    return ticket.future;
  }

  static void _cancel(Completer<bool> ticket) {
    if (ticket.isCompleted) return;
    _waiters.remove(ticket);
    ticket.complete(false);
  }

  /// Rend une place : la première bulle en attente la reçoit.
  static void _release() {
    while (_waiters.isNotEmpty) {
      final next = _waiters.removeFirst();
      if (!next.isCompleted) {
        next.complete(true); // la place est transmise, `_active` ne bouge pas
        return;
      }
    }
    if (_active > 0) _active--;
  }
}

/// Sticker animé lu **une seule fois**, sans boucle.
///
/// `Image.network` / `CachedNetworkImage` bouclent un WebP animé sans fin : ici
/// le fichier est décodé à la main (`dart:ui` : `instantiateImageCodec`,
/// `FrameInfo.duration`, aucun paquet image) et chaque image est montrée
/// pendant sa durée ; la lecture **s'arrête sur la dernière image**.
///
/// * Lecture unique à l'arrivée : quand la bulle devient visible pour la
///   première fois dans la session (clé [playKey], cf. [StickerPlayback]).
/// * **Tap = rejouer** ; l'ouverture de la fiche passe par le petit bouton
///   « i » (cible de 48 dp) ou l'action d'accessibilité « Voir la fiche » —
///   l'appui long reste celui du menu du message, il n'est jamais capté ici.
/// * Image fixe (première image, sans décoder le reste) si
///   `MediaQuery.disableAnimations`, ou si [animate] est faux (fiches). Avec
///   « réduire les animations », le tap ouvre la fiche (rien à rejouer).
/// * Un seul décodeur par bulle, libéré dès la fin de la lecture ; au plus
///   [StickerPlayback.maxConcurrent] lectures simultanées.
/// * Décodage impossible : image fixe (vignette) ; « Sticker retiré »
///   seulement sur 404/410.
class NonLoopingAnimatedSticker extends StatefulWidget {
  const NonLoopingAnimatedSticker({
    super.key,
    required this.url,
    required this.emoji,
    this.thumbUrl,
    this.size = 150,
    this.playKey,
    this.animate = true,
    this.interactive = true,
    this.onOpenSheet,
    this.semanticLabel,
    this.showRemovedLabel = true,
    this.fit = BoxFit.contain,
    this.loadBytes,
  });

  final String url;
  final String emoji;

  /// Vignette 96×96 (première image) : affichée pendant le chargement et en
  /// repli. Sinon déduite de [url] (`…_t.webp`).
  final String? thumbUrl;
  final double size;

  /// Identité de la bulle pour « une seule fois dans la session » (le
  /// `clientId` du message). `null` : pas de lecture automatique, seulement au
  /// tap.
  final String? playKey;

  /// Faux : image fixe, ni lecture automatique ni rejeu (fiches).
  final bool animate;

  /// Faux : aucun geste (mode sélection de messages : le tap revient à la
  /// bulle).
  final bool interactive;

  /// Ouvre la fiche du sticker. Absent : pas de bouton « i ».
  final VoidCallback? onOpenSheet;
  final String? semanticLabel;
  final bool showRemovedLabel;

  /// Ajustement dans le carré (`cover` pour l'aperçu d'une création : le
  /// serveur recadre en carré).
  final BoxFit fit;

  /// Source des octets (tests, aperçu en mémoire). Absent : cache disque des
  /// stickers, et l'URL doit être de confiance (cf. [StickerTrust]).
  final StickerBytesLoader? loadBytes;

  @override
  State<NonLoopingAnimatedSticker> createState() =>
      NonLoopingAnimatedStickerState();
}

enum _Phase { loading, ready, removed, fallback }

class NonLoopingAnimatedStickerState extends State<NonLoopingAnimatedSticker> {
  _Phase _phase = _Phase.loading;
  ui.Image? _image;
  int _frame = -1;
  bool _playing = false;
  bool _reduce = false;
  bool _started = false;

  /// Invalide les lectures en cours (rejeu, changement d'URL, démontage).
  int _gen = 0;
  Completer<bool>? _ticket;

  ScrollPosition? _position;
  bool _awaitingVisible = false;
  bool _staticStarted = false;
  bool _checkQueued = false;

  /// Index de l'image montrée (`-1` : aucune), pour les tests.
  @visibleForTesting
  int get shownFrame => _frame;

  @visibleForTesting
  bool get isPlaying => _playing;

  @visibleForTesting
  bool get hasImage => _image != null;

  bool get _trusted =>
      widget.loadBytes != null || StickerTrust.isTrustedStickerUrl(widget.url);

  StickerBytesLoader get _load => widget.loadBytes ?? _loadFromCache;

  // ── Cycle de vie ────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _watchScroll();
    if (!_started) {
      _started = true;
      _begin();
    } else if (_awaitingVisible) {
      _queueVisibilityCheck();
    }
  }

  @override
  void didUpdateWidget(NonLoopingAnimatedSticker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _discardImage();
      _phase = _Phase.loading;
      _begin();
    } else if (oldWidget.animate != widget.animate) {
      _begin();
    }
  }

  @override
  void dispose() {
    _gen++; // toute lecture en cours s'arrête à son prochain point d'attente
    _stopWatchingScroll();
    final t = _ticket;
    if (t != null) StickerPlayback._cancel(t);
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  bool _current(int gen) => mounted && gen == _gen;

  // ── Choix du mode ───────────────────────────────────────────────────

  /// Image fixe d'abord ; la lecture automatique part dès que la bulle est
  /// visible, **une fois par session**.
  void _begin() {
    if (!_trusted) return;
    final key = widget.playKey;
    final auto = widget.animate &&
        !_reduce &&
        key != null &&
        !StickerPlayback.hasPlayed(key);
    _staticStarted = false;
    if (!auto) {
      _awaitingVisible = false;
      unawaited(_run(play: false));
      return;
    }
    // La vignette tient la place jusqu'à la première vérification (après le
    // premier rendu) : visible → on joue ; sinon image fixe en attendant.
    _awaitingVisible = true;
    _queueVisibilityCheck();
  }

  void _watchScroll() {
    final pos = Scrollable.maybeOf(context)?.position;
    if (identical(pos, _position)) return;
    _position?.removeListener(_onScroll);
    _position = pos;
    _position?.addListener(_onScroll);
  }

  void _stopWatchingScroll() {
    _position?.removeListener(_onScroll);
    _position = null;
  }

  void _onScroll() {
    if (_awaitingVisible) _queueVisibilityCheck();
  }

  void _queueVisibilityCheck() {
    if (_checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (!mounted || !_awaitingVisible) return;
      if (_visibleEnough()) {
        _awaitingVisible = false;
        unawaited(_run(play: true));
      } else if (!_staticStarted) {
        _staticStarted = true;
        unawaited(_run(play: false));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Au moins la moitié du sticker dans la zone visible, sur la route
  /// courante, sans `TickerMode` coupé (page cachée).
  bool _visibleEnough() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final rect = ro.localToGlobal(Offset.zero) & ro.size;
    if (rect.isEmpty) return false;
    final vp = Scrollable.maybeOf(context)?.context.findRenderObject();
    final Rect view = vp is RenderBox && vp.attached && vp.hasSize
        ? vp.localToGlobal(Offset.zero) & vp.size
        : Offset.zero & MediaQuery.sizeOf(context);
    final inter = rect.intersect(view);
    if (inter.width <= 0 || inter.height <= 0) return false;
    return inter.width * inter.height >= rect.width * rect.height * 0.5;
  }

  // ── Lecture ─────────────────────────────────────────────────────────

  /// Durée d'affichage d'une image : celle du fichier, avec la convention des
  /// navigateurs pour un délai nul ou absurdement court.
  static Duration _frameDelay(Duration d) =>
      d < const Duration(milliseconds: 20) ? const Duration(milliseconds: 100) : d;

  Future<ui.Codec> _instantiate(Uint8List bytes) async {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final target = (widget.size * dpr).round().clamp(32, 512);
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: target,
      allowUpscaling: false,
    );
    StickerPlayback.liveCodecs++;
    return codec;
  }

  void _setImage(ui.Image image, int index) {
    final old = _image;
    setState(() {
      _image = image;
      _frame = index;
      _phase = _Phase.ready;
    });
    // Libère l'ancienne image **après** le rendu qui n'en dépend plus.
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  void _discardImage() {
    final old = _image;
    _image = null;
    _frame = -1;
    _playing = false;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// Une lecture complète ([play]) ou la seule première image. Un seul décodeur
  /// à la fois par bulle ; il est libéré à la fin, quoi qu'il arrive.
  Future<void> _run({required bool play}) async {
    final gen = ++_gen;
    final prior = _ticket;
    if (prior != null) StickerPlayback._cancel(prior);
    _ticket = null;
    _playing = false;
    ui.Codec? codec;
    Completer<bool>? mine;
    var held = false;
    try {
      final bytes = await _load(widget.url);
      if (!_current(gen)) return;
      codec = await _instantiate(bytes);
      if (!_current(gen)) return;
      final count = codec.frameCount;
      if (!play || count < 2) {
        final f = await codec.getNextFrame();
        if (!_current(gen)) {
          f.image.dispose();
          return;
        }
        _setImage(f.image, 0);
        return;
      }

      // Place de lecture : au plus quelques bulles animées à la fois.
      final ticket = mine = Completer<bool>();
      _ticket = ticket;
      held = await StickerPlayback._acquire(ticket);
      if (!held || !_current(gen)) return;

      final key = widget.playKey;
      if (key != null) StickerPlayback._markPlayed(key);
      if (mounted) setState(() => _playing = true);
      for (var i = 0; i < count; i++) {
        final f = await codec.getNextFrame();
        if (!_current(gen)) {
          f.image.dispose();
          return;
        }
        _setImage(f.image, i);
        // Dernière image : la lecture s'arrête, l'image reste.
        if (i < count - 1) await Future<void>.delayed(_frameDelay(f.duration));
        if (!_current(gen)) return;
      }
    } catch (e) {
      if (!_current(gen)) return;
      // Un rejeu qui échoue ne retire pas une image déjà affichée.
      if (_image == null) {
        setState(() => _phase = isStickerGone(e) ? _Phase.removed : _Phase.fallback);
      }
    } finally {
      if (codec != null) {
        codec.dispose();
        StickerPlayback.liveCodecs--;
      }
      if (held) StickerPlayback._release();
      if (mine != null && identical(_ticket, mine)) _ticket = null;
      if (mounted && gen == _gen && _playing) setState(() => _playing = false);
    }
  }

  void _onTap() {
    if (!widget.animate || !widget.interactive) return;
    if (_reduce) {
      widget.onOpenSheet?.call();
      return;
    }
    if (_playing || !_trusted) return;
    _awaitingVisible = false;
    unawaited(_run(play: true));
  }

  // ── Rendu ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = widget.size;
    if (!_trusted) {
      // Hôte ou chemin hors Alanya : on ne télécharge rien (cf. StickerTrust).
      return StickerFallback(
        emoji: widget.emoji,
        size: size,
        showLabel: widget.showRemovedLabel,
      );
    }
    switch (_phase) {
      case _Phase.removed:
        return StickerFallback(
          emoji: widget.emoji,
          size: size,
          removed: true,
          showLabel: widget.showRemovedLabel,
        );
      case _Phase.fallback:
        // Décodage impossible : la vignette fixe, jamais une boucle.
        return StickerImage(
          url: widget.url,
          thumbUrl: widget.thumbUrl,
          emoji: widget.emoji,
          size: size,
          staticFrame: true,
          showRemovedLabel: widget.showRemovedLabel,
          semanticLabel: widget.semanticLabel,
        );
      case _Phase.loading:
      case _Phase.ready:
        break;
    }

    final image = _image;
    final Widget visual = image == null
        ? _placeholder()
        : CustomPaint(
            size: Size.square(size),
            painter: _FramePainter(image, _frame, widget.fit),
          );
    final canTap = widget.animate && widget.interactive;
    final showInfo = widget.interactive &&
        widget.onOpenSheet != null &&
        widget.animate &&
        !_reduce;

    Widget body = SizedBox(width: size, height: size, child: visual);
    if (showInfo) {
      body = SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(child: visual),
            // Cible de 48 dp ; le pictogramme, lui, reste discret. En haut : le
            // bas du sticker porte l'heure et les coches du message.
            PositionedDirectional(
              end: 0,
              top: 0,
              child: ExcludeSemantics(
                child: SizedBox(
                  width: AppSizes.minTapTarget,
                  height: AppSizes.minTapTarget,
                  child: InkResponse(
                    key: const ValueKey('sticker-open-sheet'),
                    onTap: widget.onOpenSheet,
                    radius: 24,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.semantic.surfaceMuted
                              .withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.info_outline,
                            size: 16,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final label = widget.semanticLabel ??
        l10n.stickerAnimatedSemantics(widget.emoji);
    Widget out = Semantics(
      label: label,
      image: true,
      button: canTap,
      enabled: widget.interactive,
      onTap: canTap ? _onTap : null,
      hint: canTap
          ? (_reduce ? l10n.stickerOpenDetails : l10n.stickerReplay)
          : null,
      customSemanticsActions: {
        if (widget.interactive && widget.onOpenSheet != null && !_reduce)
          CustomSemanticsAction(label: l10n.stickerOpenDetails):
              widget.onOpenSheet!,
      },
      excludeSemantics: true,
      child: body,
    );
    if (canTap) {
      out = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: out,
      );
    }
    return out;
  }

  Widget _placeholder() {
    final size = widget.size;
    final thumb = widget.thumbUrl ?? stickerThumbUrlOf(widget.url);
    if (thumb == null) {
      return Center(
        child: Text(widget.emoji, style: TextStyle(fontSize: size * 0.34)),
      );
    }
    return StickerImage(
      url: thumb,
      emoji: widget.emoji,
      size: size,
      showRemovedLabel: false,
      semanticLabel: widget.semanticLabel,
    );
  }
}

/// Peint une image décodée, ajustée « contain » dans le carré du sticker.
class _FramePainter extends CustomPainter {
  _FramePainter(this.image, this.frame, this.fit);
  final ui.Image image;
  final int frame;
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: fit,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      !identical(old.image, image) || old.frame != frame || old.fit != fit;
}
