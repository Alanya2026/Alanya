import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/services/call/call_conf_routing.dart';
import '../../core/services/call/session_video_renderers.dart';
import '../../core/services/call_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/call_ui_theme.dart';
import '../common/app_avatar.dart';
import 'dashed_border.dart';
import 'speaking_indicator_border.dart';

/// Tuile participant pour les appels de groupe / conf.
class CallParticipantTile extends StatefulWidget {
  const CallParticipantTile({
    super.key,
    required this.userId,
    required this.name,
    required this.isSpeaking,
    this.stream,
    this.photoUrl,
    this.isMuted = false,
    this.isVideoOn = true,
    this.mirror = false,
    this.onTap,
  });

  final String userId;
  final MediaStream? stream;
  final String name;
  final String? photoUrl;
  final bool isSpeaking;
  final bool isMuted;
  final bool isVideoOn;
  final bool mirror;
  final VoidCallback? onTap;

  @override
  State<CallParticipantTile> createState() => _CallParticipantTileState();
}

class _CallParticipantTileState extends State<CallParticipantTile> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // `initialize()` échoue — plateforme saturée, texture indisponible — et sans
    // garde l'exception part dans un `initState` où personne ne l'attrape :
    // la tuile reste vide à vie, sans un mot. `SessionVideoRenderers` protège
    // déjà le même appel ; ici un participant disparaissait de la mosaïque.
    try {
      await _renderer.initialize();
    } catch (e) {
      debugPrint('[CallParticipantTile] ** initialisation du rendu: $e');
      return;
    }
    if (!mounted) return;
    _renderer.srcObject = widget.stream;
    setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(covariant CallParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.stream != widget.stream) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.srcObject = null;
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final initial = widget.name.isNotEmpty
        ? widget.name.substring(0, 1).toUpperCase()
        : '?';
    final url = widget.photoUrl;
    final hasPhoto = url != null &&
        url.isNotEmpty &&
        url.toUpperCase() != 'NON DEFINI' &&
        (url.startsWith('http://') || url.startsWith('https://'));
    final showAvatar = !widget.isVideoOn ||
        widget.stream == null ||
        (_ready && _renderer.videoWidth == 0);

    final tile = SpeakingIndicatorBorder(
      isSpeaking: widget.isSpeaking && !widget.isMuted,
      borderRadius: AppRadius.brMd,
      speakingColor: callUi.speakingRing,
      child: Container(
        decoration: BoxDecoration(
          color: callUi.groupTileBackground,
          borderRadius: AppRadius.brMd,
          boxShadow: [
            BoxShadow(
              color: callUi.groupTileShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_ready && widget.isVideoOn && widget.stream != null)
              RTCVideoView(
                _renderer,
                mirror: widget.mirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            if (showAvatar)
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.brandPrimary,
                  backgroundImage: hasPhoto ? NetworkImage(url) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          initial,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: callUi.videoChromeSurface.withValues(alpha: 0.85),
                  borderRadius: AppRadius.brPill,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: callUi.onVideoChrome,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.isMuted)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          CupertinoIcons.mic_off,
                          color: callUi.actionReject,
                          size: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return tile;
    return Semantics(
      button: true,
      label: widget.name,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: tile,
      ),
    );
  }
}

/// Grille de participants pour appel groupé / conf (inclut la tuile locale).
class CallGroupGrid extends StatelessWidget {
  const CallGroupGrid({
    super.key,
    required this.streams,
    required this.roster,
    required this.activeSpeakers,
    this.pendingInvitee,
    this.onCancelPending,
    this.localUserId,
    this.localStream,
    this.localName,
    this.localPhoto,
    this.localMuted = false,
    this.localVideoOn = true,
    this.localSpeaking = false,
    this.onParticipantTap,
  });

  final Map<String, MediaStream> streams;
  final Map<String, GroupParticipantInfo> roster;
  final Set<String> activeSpeakers;

  /// Invité dont la tuile existe avant qu'il ait répondu.
  final GroupParticipantInfo? pendingInvitee;

  /// Annulation de l'invitation — fournie au seul auteur de celle-ci.
  final VoidCallback? onCancelPending;

  final String? localUserId;
  final MediaStream? localStream;
  final String? localName;
  final String? localPhoto;
  final bool localMuted;
  final bool localVideoOn;
  final bool localSpeaking;

  /// Tap sur une tuile active (pas pending) → focus modal.
  final ValueChanged<String>? onParticipantTap;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    // La grille itérait sur les flux : un participant entré dont la
    // PeerConnection n'a pas encore reçu de piste n'avait aucune tuile, alors
    // que le roster le connaît. Pendant toute la négociation, il était donc
    // invisible — et le compte affiché était faux d'autant.
    final remoteIds = conferenceTileIds(
      rosterIds: roster.keys,
      streamIds: streams.keys,
      myRosterId: localUserId,
    );
    final hasLocal = localUserId != null && localUserId!.isNotEmpty;
    final itemCount = remoteIds.length +
        (hasLocal ? 1 : 0) +
        (pendingInvitee != null ? 1 : 0);

    if (itemCount == 0) {
      return Container(
        color: callUi.groupBackground,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colors.primary,
              ),
            ),
            AppSpacing.vGapLg,
            Text(
              context.l10n.waitingForParticipants,
              style: TextStyle(
                color: callUi.onBackgroundMuted,
                fontSize: 14,
              ),
            ),
            AppSpacing.vGapXl,
            _SkeletonTiles(callUi: callUi),
          ],
        ),
      );
    }

    return Container(
      color: callUi.groupBackground,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        88,
        AppSpacing.sm,
        168,
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.75,
        ),
        itemCount: itemCount,
        itemBuilder: (context, i) {
          var index = i;

          if (hasLocal) {
            if (index == 0) {
              final id = localUserId!;
              final name = localName?.isNotEmpty == true
                  ? localName!
                  : context.l10n.meLabel;
              return CallParticipantTile(
                key: ValueKey('local_$id'),
                userId: id,
                stream: localStream,
                name: name,
                photoUrl: localPhoto,
                isSpeaking: localSpeaking,
                isMuted: localMuted,
                isVideoOn: localVideoOn,
                mirror: SessionVideoRenderers.instance.mirrorLocal,
                onTap: onParticipantTap == null
                    ? null
                    : () => onParticipantTap!(id),
              );
            }
            index -= 1;
          }

          if (index < remoteIds.length) {
            final id = remoteIds[index];
            final info = roster[id];
            // `stream` peut être nul : la tuile affiche alors l'avatar, ce
            // qu'elle sait déjà faire pour une caméra coupée.
            return CallParticipantTile(
              key: ValueKey('remote_$id'),
              userId: id,
              stream: streams[id],
              name: info?.name ?? context.l10n.participantFallback,
              photoUrl: info?.photo,
              isSpeaking: activeSpeakers.contains(id),
              isMuted: info?.isMuted ?? false,
              isVideoOn: info?.isVideoOn ?? true,
              onTap: onParticipantTap == null
                  ? null
                  : () => onParticipantTap!(id),
            );
          }

          return _PendingParticipantTile(
            key: ValueKey('pending_${pendingInvitee!.id}'),
            invitee: pendingInvitee!,
            onCancel: onCancelPending,
          );
        },
      ),
    );
  }
}

/// Tuile d'un invité qui sonne encore : avatar désaturé, cadre pointillé.
class _PendingParticipantTile extends StatelessWidget {
  const _PendingParticipantTile({super.key, required this.invitee, this.onCancel});

  final GroupParticipantInfo invitee;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final callUi = context.callUi;
    final l10n = context.l10n;

    return DashedBorder(
      color: AppColors.warning.withValues(alpha: 0.75),
      borderRadius: AppRadius.brMd,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: callUi.groupTileBackground,
          borderRadius: AppRadius.brMd,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0, 0, 0, 0.55, 0,
                  ]),
                  child: AppAvatar(
                    imageUrl: invitee.photo,
                    name: invitee.name,
                    size: 56,
                  ),
                ),
                AppSpacing.vGapSm,
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text(
                    invitee.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: callUi.onBackground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  l10n.confRinging,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            if (onCancel != null)
              Positioned(
                top: 4,
                right: 4,
                child: Semantics(
                  button: true,
                  label: l10n.confCancelInvite,
                  child: IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    color: callUi.onBackgroundMuted,
                    onPressed: onCancel,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTiles extends StatelessWidget {
  const _SkeletonTiles({required this.callUi});

  final CallUiColors callUi;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          width: 72,
          height: 96,
          margin: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.sm),
          decoration: BoxDecoration(
            color: callUi.groupTileBackground,
            borderRadius: AppRadius.brMd,
            boxShadow: [
              BoxShadow(
                color: callUi.groupTileShadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      }),
    );
  }
}
