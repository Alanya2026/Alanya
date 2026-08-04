import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/notifications/notification_prefs_cache.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'dnd_schedule_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _loading = true;
  bool _saving = false;

  bool _messagesEnabled = true;
  bool _groupMessagesEnabled = true;
  bool _callsEnabled = true;
  bool _meetingsEnabled = true;
  bool _statusViewEnabled = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _previewMode = 'full';
  DndSchedule _dnd = const DndSchedule();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<TalkyApiClient>();
    try {
      final results = await Future.wait([
        api.getNotificationPrefs(),
        api.getDndSchedule(),
      ]);
      if (!mounted) return;
      setState(() {
        _applyPrefs(Map<String, dynamic>.from(results[0] as Map));
        _dnd = results[1] as DndSchedule;
        _loading = false;
      });
      await NotificationPrefsCache.applyFromServer(
        Map<String, dynamic>.from(results[0] as Map),
      );
    } catch (_) {
      await NotificationPrefsCache.load();
      if (!mounted) return;
      setState(() {
        _previewMode = NotificationPrefsCache.previewMode;
        _loading = false;
      });
    }
  }

  void _applyPrefs(Map<String, dynamic> prefs) {
    _messagesEnabled = prefs['messagesEnabled'] == true;
    _groupMessagesEnabled = prefs['groupMessagesEnabled'] == true;
    _callsEnabled = prefs['callsEnabled'] == true;
    _meetingsEnabled = prefs['meetingsEnabled'] == true;
    _statusViewEnabled = prefs['statusViewEnabled'] == true;
    _soundEnabled = prefs['soundEnabled'] == true;
    _vibrationEnabled = prefs['vibrationEnabled'] == true;
    _previewMode = prefs['previewMode']?.toString() ?? 'full';
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    final api = context.read<TalkyApiClient>();
    try {
      final prefs = await api.patchNotificationPrefs(patch);
      if (!mounted) return;
      setState(() => _applyPrefs(prefs));
      await NotificationPrefsCache.applyFromServer(prefs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.notifPrefsSaveFailed),
            backgroundColor: context.colors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dndSubtitle() {
    final l10n = context.l10n;
    if (!_dnd.enabled) return l10n.dndSummaryInactive;
    final dayLabels = <String>[];
    for (var i = 0; i < 7; i++) {
      if (_dnd.isDayEnabled(i)) {
        dayLabels.add(switch (i) {
          0 => l10n.dndDayMon,
          1 => l10n.dndDayTue,
          2 => l10n.dndDayWed,
          3 => l10n.dndDayThu,
          4 => l10n.dndDayFri,
          5 => l10n.dndDaySat,
          _ => l10n.dndDaySun,
        });
      }
    }
    final days = dayLabels.length == 7
        ? l10n.dndDayMon.substring(0, 1) == 'L'
            ? 'Lun–Dim'
            : 'Mon–Sun'
        : dayLabels.join(', ');
    return l10n.dndSummaryActive(_dnd.startTime, _dnd.endTime, days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.settingsNotifications),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                AppSpacing.vGapLg,
                _Group(
                  title: l10n.notifPrefsSectionAlerts,
                  child: Column(
                    children: [
                      _BoolTile(
                        title: l10n.notifPrefMessages,
                        value: _messagesEnabled,
                        onChanged: (v) {
                          setState(() => _messagesEnabled = v);
                          _patch({'messagesEnabled': v});
                        },
                      ),
                      _BoolTile(
                        title: l10n.notifPrefGroupMessages,
                        value: _groupMessagesEnabled,
                        onChanged: (v) {
                          setState(() => _groupMessagesEnabled = v);
                          _patch({'groupMessagesEnabled': v});
                        },
                      ),
                      _BoolTile(
                        title: l10n.notifPrefCalls,
                        value: _callsEnabled,
                        onChanged: (v) {
                          setState(() => _callsEnabled = v);
                          _patch({'callsEnabled': v});
                        },
                      ),
                      _BoolTile(
                        title: l10n.notifPrefMeetings,
                        value: _meetingsEnabled,
                        onChanged: (v) {
                          setState(() => _meetingsEnabled = v);
                          _patch({'meetingsEnabled': v});
                        },
                      ),
                      _BoolTile(
                        title: l10n.notifPrefStatusView,
                        value: _statusViewEnabled,
                        onChanged: (v) {
                          setState(() => _statusViewEnabled = v);
                          _patch({'statusViewEnabled': v});
                        },
                      ),
                    ],
                  ),
                ),
                AppSpacing.vGapXxl,
                _Group(
                  title: l10n.notifPrefsSectionBehavior,
                  child: Column(
                    children: [
                      _BoolTile(
                        title: l10n.notifPrefSound,
                        value: _soundEnabled,
                        onChanged: (v) {
                          setState(() => _soundEnabled = v);
                          _patch({'soundEnabled': v});
                        },
                      ),
                      _BoolTile(
                        title: l10n.notifPrefVibration,
                        value: _vibrationEnabled,
                        onChanged: (v) {
                          setState(() => _vibrationEnabled = v);
                          _patch({'vibrationEnabled': v});
                        },
                      ),
                    ],
                  ),
                ),
                AppSpacing.vGapXxl,
                _Group(
                  title: l10n.notifPrefPreviewTitle,
                  child: Padding(
                    padding: AppSpacing.card,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: 'full',
                          label: Text(l10n.notifPrefPreviewFull),
                        ),
                        ButtonSegment(
                          value: 'name_only',
                          label: Text(l10n.notifPrefPreviewNameOnly),
                        ),
                        ButtonSegment(
                          value: 'generic',
                          label: Text(l10n.notifPrefPreviewGeneric),
                        ),
                      ],
                      selected: {_previewMode},
                      onSelectionChanged: (s) {
                        final mode = s.first;
                        setState(() => _previewMode = mode);
                        _patch({'previewMode': mode});
                      },
                    ),
                  ),
                ),
                AppSpacing.vGapXxl,
                _Group(
                  title: l10n.dndScheduleTitle,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    leading: Icon(Icons.bedtime_outlined,
                        color: context.colors.onSurfaceVariant),
                    title: Text(
                      l10n.dndScheduleTitle,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _dndSubtitle(),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right,
                        color: context.colors.outlineVariant),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DndScheduleScreen(),
                        ),
                      );
                      if (mounted) {
                        try {
                          final schedule =
                              await context.read<TalkyApiClient>().getDndSchedule();
                          if (mounted) setState(() => _dnd = schedule);
                        } catch (_) {}
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(color: context.colors.surface, child: child),
      ],
    );
  }
}

class _BoolTile extends StatelessWidget {
  const _BoolTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      title: Text(
        title,
        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
