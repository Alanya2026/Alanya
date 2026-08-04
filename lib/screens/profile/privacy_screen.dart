import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/privacy_prefs_service.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/profile/settings_group.dart';
import 'blocked_contacts_screen.dart';

/// Réglages de confidentialité complets.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _loadingBlocked = true;
  bool _saving = false;
  int _blockedCount = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final privacy = context.read<PrivacyPrefsService>();
    if (!privacy.isLoaded) {
      try {
        await privacy.syncFromServer();
      } catch (_) {}
    }
    await _loadBlockedCount();
  }

  Future<void> _loadBlockedCount() async {
    try {
      final blocked = await context.read<TalkyApiClient>().getBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blockedCount = blocked.length;
        _loadingBlocked = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingBlocked = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<PrivacyPrefsService>().patchField(
            patch.keys.first,
            patch.values.first,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.privacySaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _visibilityLabel(String value) {
    final l10n = context.l10n;
    return switch (value) {
      PrivacyVisibility.contacts => l10n.privacyVisibilityContacts,
      PrivacyVisibility.nobody => l10n.privacyVisibilityNobody,
      _ => l10n.privacyVisibilityEveryone,
    };
  }

  String _previewLabel(String value) {
    final l10n = context.l10n;
    return switch (value) {
      NotificationPreviewMode.nameOnly => l10n.notifPrefPreviewNameOnly,
      NotificationPreviewMode.generic => l10n.notifPrefPreviewGeneric,
      _ => l10n.notifPrefPreviewFull,
    };
  }

  Future<void> _pickVisibility({
    required String title,
    required String current,
    required void Function(String) onSelected,
  }) async {
    final values = [
      PrivacyVisibility.everyone,
      PrivacyVisibility.contacts,
      PrivacyVisibility.nobody,
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: AppSpacing.card,
              child: Text(title, style: context.text.titleMedium),
            ),
            ...values.map(
              (v) => ListTile(
                title: Text(_visibilityLabel(v)),
                trailing: v == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, v),
              ),
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    onSelected(picked);
  }

  Future<void> _pickPreviewMode(PrivacyPrefs prefs) async {
    final values = [
      NotificationPreviewMode.full,
      NotificationPreviewMode.nameOnly,
      NotificationPreviewMode.generic,
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: values
              .map(
                (v) => ListTile(
                  title: Text(_previewLabel(v)),
                  trailing:
                      v == prefs.previewMode ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, v),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked == null || picked == prefs.previewMode) return;
    _patch({'previewMode': picked});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<PrivacyPrefsService>(
      builder: (context, privacyService, _) {
        final prefs = privacyService.prefs;
        final loading = _loadingBlocked && !privacyService.isLoaded;

        return Scaffold(
          backgroundColor: context.semantic.surfaceMuted,
          appBar: AppBar(title: Text(l10n.settingsPrivacy)),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    AppSpacing.vGapLg,
                    SettingsGroup(
                      title: l10n.privacySectionWhoCanSee,
                      child: Column(
                        children: [
                          SettingsNavTile(
                            title: l10n.privacyLastSeen,
                            subtitle: _visibilityLabel(prefs.lastSeenVisibility),
                            onTap: () => _pickVisibility(
                              title: l10n.privacyLastSeen,
                              current: prefs.lastSeenVisibility,
                              onSelected: (v) =>
                                  _patch({'lastSeenVisibility': v}),
                            ),
                          ),
                          SettingsNavTile(
                            title: l10n.privacyOnlineStatus,
                            subtitle: _visibilityLabel(prefs.onlineVisibility),
                            onTap: () => _pickVisibility(
                              title: l10n.privacyOnlineStatus,
                              current: prefs.onlineVisibility,
                              onSelected: (v) =>
                                  _patch({'onlineVisibility': v}),
                            ),
                          ),
                          SettingsNavTile(
                            title: l10n.privacyProfilePhoto,
                            subtitle:
                                _visibilityLabel(prefs.profilePhotoVisibility),
                            onTap: () => _pickVisibility(
                              title: l10n.privacyProfilePhoto,
                              current: prefs.profilePhotoVisibility,
                              onSelected: (v) =>
                                  _patch({'profilePhotoVisibility': v}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vGapXxl,
                    SettingsGroup(
                      title: l10n.privacySectionMessages,
                      child: Column(
                        children: [
                          SettingsBoolTile(
                            title: l10n.privacyReadReceipts,
                            subtitle: l10n.privacyReadReceiptsSubtitle,
                            value: prefs.readReceiptsEnabled,
                            onChanged: (v) => _patch({'readReceiptsEnabled': v}),
                          ),
                          SettingsNavTile(
                            title: l10n.privacyNotificationPreview,
                            subtitle: _previewLabel(prefs.previewMode),
                            onTap: () => _pickPreviewMode(prefs),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vGapXxl,
                    SettingsGroup(
                      title: l10n.privacySectionLists,
                      child: Column(
                        children: [
                          SettingsNavTile(
                            icon: Icons.block,
                            title: l10n.privacyBlockedContacts,
                            subtitle: _blockedCount == 0
                                ? l10n.privacyBlockedContactsEmpty
                                : l10n.privacyBlockedContactsCount(_blockedCount),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const BlockedContactsScreen(),
                                ),
                              );
                              if (mounted) _loadBlockedCount();
                            },
                          ),
                          SettingsNavTile(
                            title: l10n.privacyAddToGroups,
                            subtitle: _visibilityLabel(prefs.addMePolicy),
                            onTap: () => _pickVisibility(
                              title: l10n.privacyAddToGroups,
                              current: prefs.addMePolicy,
                              onSelected: (v) => _patch({'addMePolicy': v}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.vGapXxl,
                  ],
                ),
        );
      },
    );
  }
}
