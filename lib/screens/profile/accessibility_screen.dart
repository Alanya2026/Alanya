import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/app_settings_sync_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../widgets/profile/settings_group.dart';

/// Taille du texte et réduction des animations.
class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _reduceMotion = false;
  double _fontScale = 1.0;

  static const _fontScaleSteps = [0.85, 1.0, 1.15, 1.3];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await context.read<TalkyApiClient>().getAppSettings();
      if (!mounted) return;
      setState(() {
        _reduceMotion = settings.reduceMotion;
        _fontScale = settings.fontScale;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final sync = context.read<AppSettingsSyncService>();
      final next = await sync.patchAndSync(patch);
      if (!mounted) return;
      setState(() {
        _reduceMotion = next.reduceMotion;
        _fontScale = next.fontScale;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accessibilitySaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fontScaleLabel(double scale) {
    final l10n = context.l10n;
    if (scale <= 0.9) return l10n.accessibilityFontScaleSmall;
    if (scale >= 1.25) return l10n.accessibilityFontScaleLarge;
    if (scale >= 1.1) return l10n.accessibilityFontScaleMedium;
    return l10n.accessibilityFontScaleDefault;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.accessibilityTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                AppSpacing.vGapLg,
                SettingsGroup(
                  title: l10n.accessibilitySectionDisplay,
                  child: Column(
                    children: [
                      Padding(
                        padding: AppSpacing.card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.accessibilityFontScale,
                              style: context.text.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            AppSpacing.vGapSm,
                            SegmentedButton<double>(
                              showSelectedIcon: false,
                              segments: _fontScaleSteps
                                  .map(
                                    (s) => ButtonSegment(
                                      value: s,
                                      label: Text(_fontScaleLabel(s)),
                                    ),
                                  )
                                  .toList(),
                              selected: {_fontScale},
                              onSelectionChanged: (sel) {
                                final v = sel.first;
                                setState(() => _fontScale = v);
                                _patch({'fontScale': v});
                              },
                            ),
                          ],
                        ),
                      ),
                      SettingsBoolTile(
                        icon: Icons.motion_photos_off_outlined,
                        title: l10n.accessibilityReduceMotion,
                        subtitle: l10n.accessibilityReduceMotionSubtitle,
                        value: _reduceMotion,
                        onChanged: (v) {
                          setState(() => _reduceMotion = v);
                          _patch({'reduceMotion': v});
                        },
                      ),
                    ],
                  ),
                ),
                AppSpacing.vGapXxl,
              ],
            ),
    );
  }
}
