import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/profile/settings_group.dart';

/// Planification « Ne pas déranger » (horaires + jours).
class DndScheduleScreen extends StatefulWidget {
  const DndScheduleScreen({super.key});

  @override
  State<DndScheduleScreen> createState() => _DndScheduleScreenState();
}

class _DndScheduleScreenState extends State<DndScheduleScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _enabled = false;
  TimeOfDay _start = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 7, minute: 0);
  int _daysBitmask = 127;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final schedule = await context.read<TalkyApiClient>().getDndSchedule();
      if (!mounted) return;
      setState(() {
        _apply(schedule);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(DndSchedule schedule) {
    _enabled = schedule.enabled;
    _start = _parseTime(schedule.startTime, const TimeOfDay(hour: 22, minute: 0));
    _end = _parseTime(schedule.endTime, const TimeOfDay(hour: 7, minute: 0));
    _daysBitmask = schedule.daysBitmask;
  }

  TimeOfDay _parseTime(String raw, TimeOfDay fallback) {
    final parts = raw.split(':');
    if (parts.length < 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final next =
          await context.read<TalkyApiClient>().patchDndSchedule(patch);
      if (!mounted) return;
      setState(() => _apply(next));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dndSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
    await _patch({
      if (isStart) 'startTime': _formatTime(picked) else 'endTime': _formatTime(picked),
    });
  }

  bool _isDayActive(int bit) => (_daysBitmask & (1 << bit)) != 0;

  Future<void> _toggleDay(int bit) async {
    final next = _isDayActive(bit)
        ? _daysBitmask & ~(1 << bit)
        : _daysBitmask | (1 << bit);
    setState(() => _daysBitmask = next);
    await _patch({'daysBitmask': next});
  }

  String _dayLabel(int bit) {
    final l10n = context.l10n;
    return switch (bit) {
      0 => l10n.dndDayMon,
      1 => l10n.dndDayTue,
      2 => l10n.dndDayWed,
      3 => l10n.dndDayThu,
      4 => l10n.dndDayFri,
      5 => l10n.dndDaySat,
      _ => l10n.dndDaySun,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.dndScheduleTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                AppSpacing.vGapLg,
                SettingsGroup(
                  title: l10n.dndScheduleTitle,
                  child: SettingsBoolTile(
                    icon: Icons.bedtime_outlined,
                    title: l10n.dndEnabled,
                    subtitle: l10n.dndEnabledSubtitle,
                    value: _enabled,
                    onChanged: (v) {
                      setState(() => _enabled = v);
                      _patch({'enabled': v});
                    },
                  ),
                ),
                AppSpacing.vGapXxl,
                SettingsGroup(
                  title: l10n.dndScheduleHours,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.sm,
                        ),
                        title: Text(l10n.dndStartTime),
                        trailing: Text(
                          _formatTime(_start),
                          style: context.text.bodyLarge?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => _pickTime(isStart: true),
                      ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.sm,
                        ),
                        title: Text(l10n.dndEndTime),
                        trailing: Text(
                          _formatTime(_end),
                          style: context.text.bodyLarge?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vGapXxl,
                SettingsGroup(
                  title: l10n.dndDays,
                  child: Padding(
                    padding: AppSpacing.card,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: List.generate(7, (bit) {
                        final active = _isDayActive(bit);
                        return FilterChip(
                          label: Text(_dayLabel(bit)),
                          selected: active,
                          onSelected: (_) => _toggleDay(bit),
                        );
                      }),
                    ),
                  ),
                ),
                AppSpacing.vGapXxl,
              ],
            ),
    );
  }
}
