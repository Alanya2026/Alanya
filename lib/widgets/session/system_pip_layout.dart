import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/services/call/session_video_renderers.dart';

/// Ce que l'application affiche quand elle est réduite en vignette système.
///
/// Le Picture-in-Picture d'Android ne réduit pas une vue : il réduit
/// **l'activité entière**. Sans disposition dédiée, la vignette montrerait
/// l'écran courant en miniature — barres, boutons et listes compris —, illisible
/// dans un rectangle de quelques centimètres. Elle ne porte donc que l'image,
/// et rien d'autre : aucun contrôle n'y serait cliquable de toute façon, les
/// gestes appartenant au système.
///
/// Le fond est noir et non thématisé : c'est la couleur des bandes d'une vidéo
/// qui ne remplit pas son cadre, et la vignette n'appartient plus à
/// l'application mais à l'écran d'accueil.
class SystemPipLayout extends StatefulWidget {
  const SystemPipLayout({super.key});

  @override
  State<SystemPipLayout> createState() => _SystemPipLayoutState();
}

class _SystemPipLayoutState extends State<SystemPipLayout> {
  SessionVideoRenderers get _renderers => SessionVideoRenderers.instance;

  @override
  void initState() {
    super.initState();
    _renderers.addListener(_onRenderersChanged);
  }

  @override
  void dispose() {
    _renderers.removeListener(_onRenderersChanged);
    super.dispose();
  }

  void _onRenderersChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final remote = _renderers.remote;
    final local = _renderers.local;

    // Le correspondant d'abord : c'est lui qu'on veut garder à l'œil. Sa
    // caméra coupée, sa propre image vaut mieux qu'un carré noir, qui se lit
    // comme une panne.
    final RTCVideoRenderer? renderer;
    final bool mirror;
    if (remote != null && remote.srcObject != null && remote.videoWidth > 0) {
      renderer = remote;
      mirror = false;
    } else if (local != null && local.srcObject != null && local.videoWidth > 0) {
      renderer = local;
      mirror = _renderers.mirrorLocal;
    } else {
      renderer = null;
      mirror = false;
    }

    return ColoredBox(
      color: Colors.black,
      child: renderer == null
          ? const SizedBox.expand()
          : RTCVideoView(
              renderer,
              mirror: mirror,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
    );
  }
}
