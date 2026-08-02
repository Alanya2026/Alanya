import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/app_settings_sync_service.dart';
import '../../core/services/playback_speed_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/profile/settings_group.dart';

/// Vitesses de lecture globales (voix, vidéo, musique).
class PlaybackSpeedScreen extends StatefulWidget {
  const PlaybackSpeedScreen({super.key});

  @override
  State<PlaybackSpeedScreen> createState() => _PlaybackSpeedScreenState();
}

class _PlaybackSpeedScreenState extends State<PlaybackSpeedScreen> {
  late double _voice;
  late double _video;
  late double _music;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _voice = PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.voice);
    _video = PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.video);
    _music = PlaybackSpeedPreferences.speedOf(PlaybackSpeedKind.music);
  }

  Future<void> _set(PlaybackSpeedKind kind, double speed) async {
    await PlaybackSpeedPreferences.setSpeed(kind, speed);
    final field = switch (kind) {
      PlaybackSpeedKind.voice => 'playbackSpeedVoice',
      PlaybackSpeedKind.video => 'playbackSpeedVideo',
      PlaybackSpeedKind.music => 'playbackSpeedMusic',
    };
    try {
      await context.read<AppSettingsSyncService>().patchAndSync({field: speed});
    } catch (_) {}
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.playbackSpeed)),
      body: ListView(
        children: [
          AppSpacing.vGapLg,
          SettingsGroup(
            title: l10n.playbackSpeedVoiceLabel,
            child: _SpeedRow(
              speeds: PlaybackSpeedPreferences.speedsFor(PlaybackSpeedKind.voice),
              current: _voice,
              onSelected: (v) => _set(PlaybackSpeedKind.voice, v),
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.playbackSpeedVideoLabel,
            child: _SpeedRow(
              speeds: PlaybackSpeedPreferences.speedsFor(PlaybackSpeedKind.video),
              current: _video,
              onSelected: (v) => _set(PlaybackSpeedKind.video, v),
            ),
          ),
          AppSpacing.vGapXxl,
          SettingsGroup(
            title: l10n.playbackSpeedMusicLabel,
            child: _SpeedRow(
              speeds: PlaybackSpeedPreferences.speedsFor(PlaybackSpeedKind.music),
              current: _music,
              onSelected: (v) => _set(PlaybackSpeedKind.music, v),
            ),
          ),
          AppSpacing.vGapXxl,
        ],
      ),
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.speeds,
    required this.current,
    required this.onSelected,
  });

  final List<double> speeds;
  final double current;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.card,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: speeds.map((speed) {
          final selected = (current - speed).abs() < 0.01;
          return ChoiceChip(
            label: Text(formatPlaybackSpeed(speed)),
            selected: selected,
            onSelected: (_) => onSelected(speed),
          );
        }).toList(),
      ),
    );
  }
}
