import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/services/call/session_video_renderers.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../calls/draggable_video_pip.dart';
import '../common/app_avatar.dart';

/// Fenêtre vidéo flottante d'une session minimisée.
///
/// Elle remplace le bandeau compact pour les sessions vidéo : celui-ci
/// n'affichait qu'un nom et une durée, ce qui revenait à couper l'image dès que
/// l'utilisateur quittait l'écran d'appel. Le bandeau reste pour l'audio et la
/// lecture vocale, qui n'ont rien à montrer.
///
/// Déplaçable, et ramenée à l'écran plein d'un tap. Le glissé et le seuil
/// anti-tap-parasite viennent de [DraggableVideoPiP], déjà éprouvé sur l'écran
/// d'appel — seules les bornes changent, la fenêtre n'ayant ici ni barre ni
/// contrôles à contourner.
class SessionVideoWindow extends StatefulWidget {
  const SessionVideoWindow({
    super.key,
    required this.onExpand,
    required this.onHangUp,
    required this.fallbackName,
    this.fallbackPhotoUrl,
    this.preferLocal = false,
  });

  /// Ramène l'écran plein.
  final VoidCallback onExpand;

  /// Quitte la session depuis la fenêtre. Sans ce bouton, minimiser un appel
  /// vidéo obligerait à rouvrir l'écran plein pour raccrocher — le bandeau,
  /// lui, l'a toujours proposé.
  final Future<void> Function() onHangUp;

  /// Affiché quand aucune image n'arrive : caméra distante coupée, ou flux pas
  /// encore négocié.
  final String fallbackName;
  final String? fallbackPhotoUrl;

  /// Montre sa propre caméra plutôt que celle du correspondant. Utile en
  /// réunion, où « le » flux distant n'existe pas.
  final bool preferLocal;

  @override
  State<SessionVideoWindow> createState() => _SessionVideoWindowState();
}

class _SessionVideoWindowState extends State<SessionVideoWindow> {
  Offset? _position;

  SessionVideoRenderers get _renderers => SessionVideoRenderers.instance;

  @override
  void initState() {
    super.initState();
    _renderers.addListener(_onRenderersChanged);
  }

  @override
  void dispose() {
    _renderers.removeListener(_onRenderersChanged);
    // Les rendus survivent à cette fenêtre : ils appartiennent à la session.
    super.dispose();
  }

  void _onRenderersChanged() {
    if (mounted) setState(() {});
  }

  /// Rendu à afficher, ou null si rien n'est montrable.
  ///
  /// `videoWidth > 0` est le seul témoin fiable qu'une image est arrivée : un
  /// rendu branché sur un flux dont la caméra est coupée reste noir, et un
  /// carré noir se lit comme une panne.
  RTCVideoRenderer? _visibleRenderer() {
    final candidates = widget.preferLocal
        ? [_renderers.local, _renderers.remote]
        : [_renderers.remote, _renderers.local];
    for (final renderer in candidates) {
      if (renderer == null) continue;
      if (renderer.srcObject == null) continue;
      if (renderer.videoWidth <= 0) continue;
      return renderer;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bounds = computeFloatingWindowBounds(
      screenSize: mq.size,
      safeArea: mq.padding,
    );

    final renderer = _visibleRenderer();
    final isLocal = renderer != null && identical(renderer, _renderers.local);

    return DraggableVideoPiP(
      bounds: bounds,
      position: _position,
      onPositionChanged: (offset) => setState(() => _position = offset),
      onTap: widget.onExpand,
      child: _WindowSurface(
        onHangUp: widget.onHangUp,
        child: renderer == null
            ? _WindowAvatar(
                name: widget.fallbackName,
                photoUrl: widget.fallbackPhotoUrl,
              )
            : RTCVideoView(
                renderer,
                mirror: isLocal && _renderers.mirrorLocal,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
      ),
    );
  }
}

class _WindowSurface extends StatelessWidget {
  const _WindowSurface({required this.child, required this.onHangUp});

  final Widget child;
  final Future<void> Function() onHangUp;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kFloatingWindowWidth,
      height: kFloatingWindowHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.colors.surfaceContainerHighest, child: child),
            Positioned(
              right: 4,
              bottom: 4,
              child: _HangUpButton(onPressed: onHangUp),
            ),
          ],
        ),
      ),
    );
  }
}

class _HangUpButton extends StatelessWidget {
  const _HangUpButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.hangUp,
      child: GestureDetector(
        // Le tap du bouton ne doit pas remonter à la fenêtre, qui ouvrirait
        // l'écran plein au lieu de raccrocher.
        behavior: HitTestBehavior.opaque,
        onTap: () => onPressed(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: context.colors.error,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.call_end_rounded,
            size: 16,
            color: context.colors.onError,
          ),
        ),
      ),
    );
  }
}

class _WindowAvatar extends StatelessWidget {
  const _WindowAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surfaceContainerHighest,
      alignment: Alignment.center,
      // AppAvatar et non ProfileAvatar : ce dernier ouvre le modal de profil au
      // clic, ce qui volerait le tap qui doit ramener l'écran d'appel.
      child: AppAvatar(
        imageUrl: photoUrl,
        name: name,
        size: AppSizes.avatarLg,
      ),
    );
  }
}