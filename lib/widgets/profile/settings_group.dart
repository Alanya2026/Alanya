import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Groupe de réglages avec titre de section (pattern SettingsScreen).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.child});

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
        Container(
          width: double.infinity,
          color: context.colors.surface,
          child: child,
        ),
      ],
    );
  }
}

/// Tuile de navigation vers un sous-écran de réglages.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      leading: icon == null
          ? null
          : Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.semantic.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: context.colors.onSurfaceVariant,
                size: AppIconSize.md,
              ),
            ),
      title: Text(
        title,
        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
      trailing: trailing ??
          Icon(Icons.chevron_right, color: context.colors.outlineVariant),
      onTap: onTap,
    );
  }
}

/// Interrupteur dans un groupe de réglages.
class SettingsBoolTile extends StatelessWidget {
  const SettingsBoolTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      secondary: icon == null
          ? null
          : Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.semantic.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: context.colors.onSurfaceVariant,
                size: AppIconSize.md,
              ),
            ),
      title: Text(
        title,
        style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );
  }
}
