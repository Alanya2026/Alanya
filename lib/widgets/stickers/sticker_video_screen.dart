import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/services/stickers/sticker_repository.dart';
import '../../core/services/stickers/sticker_video_check.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../talky_api_client.dart' show TalkyException;
import 'sticker_animated_screen.dart' show StickerConvertingOverlay;
import 'sticker_creation_flows.dart';
import 'video_window_player.dart';

/// Écran « Sticker depuis une vidéo » (V1c, contrat §4d) : on choisit la
/// fenêtre à garder (début, durée de 500 ms à 3 s), la forme, puis « Ajouter ».
///
/// L'aperçu joue **en boucle la seule fenêtre choisie**, découpée dans la forme
/// (simple aperçu : le serveur découpe avec ffmpeg, recadre en 512×512 et pose le
/// vrai masque). La vidéo part **entière** (≤ 20 Mo) avec `start` / `duration`.
///
/// Ferme avec le [StickerAnimatedResult] en cas de succès, `null` sinon.
class StickerVideoScreen extends StatefulWidget {
  const StickerVideoScreen({
    super.key,
    required this.packId,
    required this.bytes,
    required this.filename,
    this.playerFactory = createVideoWindowPlayer,
  });

  /// `null` : pack perso par défaut côté serveur (bouton « Créer » du plateau).
  final int? packId;
  final Uint8List bytes;
  final String filename;

  /// Injectable : les tests n'ont pas de moteur vidéo.
  final VideoWindowPlayerFactory playerFactory;

  @override
  State<StickerVideoScreen> createState() => _StickerVideoScreenState();
}

const double _kPreviewSide = 240;
const double _kRoundedRatio = 0.22;

class _StickerVideoScreenState extends State<StickerVideoScreen>
    with WidgetsBindingObserver {
  late final StickerCreationRepository _repo = context
      .read<StickerCreationRepository>();

  VideoWindowPlayer? _player;
  StickerVideoWindow? _window;
  StickerAnimatedShape _shape = StickerAnimatedShape.carreArrondi;
  Object? _loadError;
  bool _loading = true;
  bool _sending = false;
  bool _cancelled = false;
  bool _resumeOnForeground = false;
  Completer<void>? _cancel;
  bool _started = false;

  int get _videoMs => _player?.durationMs ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    VideoWindowPlayer? player;
    try {
      final kind = StickerVideoCheck.validate(widget.bytes);
      player = await widget.playerFactory(widget.bytes, kind);
      await player.initialize();
      if (!mounted) {
        await player.dispose();
        return;
      }
      final window = StickerVideoWindow.initial(player.durationMs);
      if (window == null) {
        await player.dispose();
        setState(() {
          _loading = false;
          _loadError = const StickerVideoRejected(StickerVideoIssue.tooShort);
        });
        return;
      }
      player.addListener(_onTick);
      setState(() {
        _player = player;
        _window = window;
        _loading = false;
      });
      await player.seekTo(window.startMs);
    } catch (e) {
      await player?.dispose();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  /// Lecture en boucle de la seule fenêtre : à la fin, retour au début.
  void _onTick() {
    final p = _player;
    final w = _window;
    if (p == null || w == null || _sending) return;
    if (p.isPlaying && p.positionMs >= w.endMs - 30) {
      unawaited(p.seekTo(w.startMs));
    }
  }

  /// Lance la lecture une fois que l'écran est visible, sauf si l'utilisateur a
  /// demandé de réduire les animations (la vidéo reste alors à l'arrêt).
  void _autoStartOnce(BuildContext context) {
    if (_started || _player == null) return;
    _started = true;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) return;
    // Après le premier affichage : jamais d'effet de bord dans `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_player?.play());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final p = _player;
    if (p == null) return;
    if (state != AppLifecycleState.resumed) {
      // Arrière-plan : on coupe la lecture (batterie), on la reprend au retour.
      _resumeOnForeground = p.isPlaying;
      unawaited(p.pause());
    } else if (_resumeOnForeground) {
      _resumeOnForeground = false;
      unawaited(p.play());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _cancel;
    if (c != null && !c.isCompleted) c.complete();
    final p = _player;
    if (p != null) {
      p.removeListener(_onTick);
      unawaited(p.dispose());
    }
    super.dispose();
  }

  /// Un geste sur un curseur : la fenêtre suit tout de suite ; la lecture saute
  /// au nouveau début quand on lâche (un saut à chaque pixel saccaderait).
  void _setWindow(StickerVideoWindow w) => setState(() => _window = w);

  Future<void> _restart() async {
    final p = _player;
    final w = _window;
    if (p == null || w == null) return;
    await p.seekTo(w.startMs);
  }

  Future<void> _togglePlay() async {
    final p = _player;
    if (p == null) return;
    if (p.isPlaying) {
      await p.pause();
    } else {
      await _restartIfOutside();
      await p.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _restartIfOutside() async {
    final p = _player;
    final w = _window;
    if (p == null || w == null) return;
    if (p.positionMs < w.startMs || p.positionMs >= w.endMs) {
      await p.seekTo(w.startMs);
    }
  }

  Future<void> _send() async {
    final w = _window;
    if (_sending || w == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    final l10n = context.l10n;
    final cancel = Completer<void>();
    unawaited(_player?.pause());
    setState(() {
      _sending = true;
      _cancelled = false;
      _cancel = cancel;
    });
    try {
      final r = await _repo.addVideoSticker(
        widget.packId,
        widget.bytes,
        filename: widget.filename,
        shape: _shape,
        window: w,
        cancel: cancel.future,
      );
      if (!mounted) return;
      nav.pop(r);
    } catch (e) {
      if (!mounted) return;
      if (_cancelled) {
        // Le serveur a peut-être fini avant l'annulation : on relit mes packs.
        unawaited(_repo.syncCreated());
        return;
      }
      if (e is TalkyException && StickerRepository.isModuleClosed(e)) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.stickerAnimatedClosed)),
        );
        nav.pop();
        return;
      }
      showAnimatedCreationError(context, e, video: true);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _cancel = null;
        });
      }
    }
  }

  void _cancelSend() {
    final c = _cancel;
    if (!_sending || c == null || c.isCompleted) return;
    _cancelled = true;
    c.complete();
  }

  String _clock(int ms) {
    final total = ms / 1000;
    final m = total ~/ 60;
    final s = (total - m * 60).toStringAsFixed(1).padLeft(4, '0');
    return '${m.toString().padLeft(2, '0')}:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return PopScope(
      canPop: !_sending,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sending) _cancelSend();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.stickerVideoTitle)),
        // « Ajouter » reste visible quel que soit l'écran : on ne le cherche pas
        // en bas d'une liste qu'il faut faire défiler.
        bottomNavigationBar: _player != null && _window != null && _loadError == null
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md,
                  ),
                  child: FilledButton(
                    key: const ValueKey('sticker-video-add'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                    ),
                    onPressed: _sending ? null : _send,
                    child: Text(l10n.stickerPreviewAdd),
                  ),
                ),
              )
            : null,
        body: Stack(
          children: [
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                  key: ValueKey('sticker-video-loading'),
                ),
              )
            else if (_loadError != null)
              _LoadError(error: _loadError!)
            else
              _body(context, l10n, colors),
            if (_sending)
              Positioned.fill(
                child: StickerConvertingOverlay(
                  onCancel: _cancelSend,
                  title: l10n.stickerVideoConverting,
                  hint: l10n.stickerVideoConvertingHint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, ColorScheme colors) {
    _autoStartOnce(context);
    final player = _player!;
    final w = _window!;
    final video = _videoMs;
    final maxStart = (video - w.durationMs).clamp(0, video);
    final maxDuration = video < StickerVideoWindow.maxDurationMs
        ? video
        : StickerVideoWindow.maxDurationMs;
    final radius = switch (_shape) {
      StickerAnimatedShape.cercle => _kPreviewSide / 2,
      StickerAnimatedShape.carreArrondi => _kPreviewSide * _kRoundedRatio,
      StickerAnimatedShape.carre => 0.0,
    };
    final size = player.videoSize;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: Semantics(
            label: l10n.stickerVideoPreviewLabel,
            image: true,
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.semantic.surfaceMuted,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: ClipRRect(
                key: const ValueKey('sticker-video-clip'),
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  width: _kPreviewSide,
                  height: _kPreviewSide,
                  // `cover` : la vidéo remplit le carré, comme le recadrage du serveur.
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: size.width <= 0 ? _kPreviewSide : size.width,
                      height: size.height <= 0 ? _kPreviewSide : size.height,
                      child: player.buildView(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AppSpacing.vGapSm,
        Center(
          child: IconButton.filledTonal(
            key: const ValueKey('sticker-video-play'),
            iconSize: 28,
            constraints: const BoxConstraints(
              minWidth: AppSizes.minTapTarget,
              minHeight: AppSizes.minTapTarget,
            ),
            tooltip: (player.isPlaying
                ? l10n.stickerVideoPause
                : l10n.stickerVideoPlay),
            onPressed: _sending ? null : _togglePlay,
            icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
        ),
        AppSpacing.vGapMd,
        _SliderRow(
          label: l10n.stickerVideoStart,
          value: _clock(w.startMs),
          semanticValue: (l10n.stickerVideoStartValue(_clock(w.startMs))),
          sliderKey: const ValueKey('sticker-video-start'),
          slider: Slider(
            min: 0,
            max: maxStart <= 0 ? 1 : maxStart.toDouble(),
            divisions: maxStart ~/ StickerVideoWindow.stepMs > 0
                ? maxStart ~/ StickerVideoWindow.stepMs
                : null,
            value: w.startMs.clamp(0, maxStart <= 0 ? 1 : maxStart).toDouble(),
            onChanged: _sending || maxStart <= 0
                ? null
                : (v) => _setWindow(_window!.withStart(v.round(), videoMs: video)),
            onChangeEnd: (_) => _restart(),
          ),
        ),
        _SliderRow(
          label: l10n.stickerVideoDuration,
          value: '${(w.durationMs / 1000).toStringAsFixed(1)} s',
          semanticValue: (l10n.stickerVideoDurationValue((w.durationMs / 1000).toStringAsFixed(1))),
          sliderKey: const ValueKey('sticker-video-duration'),
          slider: Slider(
            min: StickerVideoWindow.minDurationMs.toDouble(),
            max: maxDuration <= StickerVideoWindow.minDurationMs
                ? StickerVideoWindow.minDurationMs + 1.0
                : maxDuration.toDouble(),
            divisions: (maxDuration - StickerVideoWindow.minDurationMs) ~/
                        StickerVideoWindow.stepMs >
                    0
                ? (maxDuration - StickerVideoWindow.minDurationMs) ~/
                    StickerVideoWindow.stepMs
                : null,
            value: w.durationMs
                .clamp(
                  StickerVideoWindow.minDurationMs,
                  maxDuration < StickerVideoWindow.minDurationMs
                      ? StickerVideoWindow.minDurationMs
                      : maxDuration,
                )
                .toDouble(),
            onChanged: _sending ||
                    maxDuration <= StickerVideoWindow.minDurationMs
                ? null
                : (v) => _setWindow(_window!.withDuration(v.round(), videoMs: video)),
            onChangeEnd: (_) => _restart(),
          ),
        ),
        AppSpacing.vGapMd,
        Text(l10n.stickerAnimatedShape, style: context.text.titleSmall),
        AppSpacing.vGapSm,
        SegmentedButton<StickerAnimatedShape>(
          key: const ValueKey('sticker-video-shapes'),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(AppSizes.minTapTarget, AppSizes.buttonHeight),
          ),
          segments: [
            ButtonSegment(
              value: StickerAnimatedShape.cercle,
              icon: const Icon(Icons.circle_outlined),
              label: Text(l10n.stickerShapeCircle),
            ),
            ButtonSegment(
              value: StickerAnimatedShape.carreArrondi,
              icon: const Icon(Icons.rounded_corner),
              label: Text(l10n.stickerShapeRounded),
            ),
            ButtonSegment(
              value: StickerAnimatedShape.carre,
              icon: const Icon(Icons.crop_square),
              label: Text(l10n.stickerShapeSquare),
            ),
          ],
          selected: {_shape},
          onSelectionChanged: _sending
              ? null
              : (s) => setState(() => _shape = s.first),
        ),
        AppSpacing.vGapMd,
        Text(
          l10n.stickerVideoHint,
          style: context.text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Un curseur étiqueté : nom, valeur lue à voix haute (« début 3 secondes »),
/// cible tactile d'au moins 48 dp.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.semanticValue,
    required this.slider,
    required this.sliderKey,
  });

  final String label;
  final String value;
  final String semanticValue;
  final Widget slider;
  final Key sliderKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: context.text.titleSmall),
            Text(
              value,
              style: context.text.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Semantics(
            key: sliderKey,
            container: true,
            label: label,
            value: semanticValue,
            child: slider,
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = error is StickerVideoRejected
        ? stickerAnimatedErrorText(l10n, error) ?? l10n.stickerVideoLoadFailed
        : l10n.stickerVideoLoadFailed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, size: 40, color: context.colors.onSurfaceVariant),
            AppSpacing.vGapMd,
            Text(
              text,
              key: const ValueKey('sticker-video-error'),
              textAlign: TextAlign.center,
              style: context.text.bodyMedium,
            ),
            AppSpacing.vGapLg,
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(AppSizes.minTapTarget, AppSizes.buttonHeight),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }
}
