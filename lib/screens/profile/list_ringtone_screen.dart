import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/list_ringtone_preferences.dart';
import '../../core/services/ringtone_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_list_display.dart';

class ListRingtoneScreen extends StatelessWidget {
  const ListRingtoneScreen({
    super.key,
    required this.list,
    required this.allLists,
  });

  final LocalContactList list;
  final List<LocalContactList> allLists;

  @override
  Widget build(BuildContext context) {
    final listPrefs = context.watch<ListRingtonePreferences>();
    final ringtonePrefs = context.watch<RingtonePreferences>();
    final setting = listPrefs.settingFor(list.idList);
    final options = ringtonePrefs.allOptions;
    final ordered = <LocalContactList>[
      for (final id in listPrefs.priority)
        ...allLists.where((item) => item.idList == id),
      ...allLists.where(
        (item) => !listPrefs.priority.contains(item.idList),
      ),
    ];

    String label(RingtoneOption option) {
      if (option.type == RingtoneSourceType.system) {
        return 'Sonnerie par défaut de l’appareil';
      }
      return option.label;
    }

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        title: Text('Sonneries — ${list.displayName(context.l10n)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Choisissez deux sons différents pour cette liste.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapLg,
          _RingtoneDropdown(
            title: 'Nouveaux messages',
            icon: Icons.message_outlined,
            value: setting.messageRingtoneId ?? RingtoneOption.systemId,
            options: options,
            optionLabel: label,
            onChanged: (id) => listPrefs.setRingtone(
              list.idList,
              messageRingtoneId: id,
            ),
          ),
          AppSpacing.vGapMd,
          _RingtoneDropdown(
            title: 'Appels entrants',
            icon: Icons.phone_in_talk_outlined,
            value: setting.callRingtoneId ?? RingtoneOption.systemId,
            options: options,
            optionLabel: label,
            onChanged: (id) => listPrefs.setRingtone(
              list.idList,
              callRingtoneId: id,
            ),
          ),
          AppSpacing.vGapXl,
          Text('Ordre de priorité', style: context.text.titleMedium),
          AppSpacing.vGapXs,
          Text(
            'Si un contact appartient à plusieurs listes, la première liste configurée ci-dessous gagne. Faites glisser pour réordonner.',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapMd,
          Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.brLg,
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ordered.length,
              onReorder: (oldIndex, newIndex) {
                final ids = ordered.map((item) => item.idList).toList();
                if (newIndex > oldIndex) newIndex--;
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                listPrefs.reorder(ids);
              },
              itemBuilder: (context, index) {
                final item = ordered[index];
                return ListTile(
                  key: ValueKey(item.idList),
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(item.displayName(context.l10n)),
                  trailing: const Icon(Icons.drag_handle),
                );
              },
            ),
          ),
          AppSpacing.vGapLg,
          Text(
            'Ce réglage est enregistré uniquement sur cet appareil. Les fichiers importés doivent rester présents sur le téléphone.',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingtoneDropdown extends StatelessWidget {
  const _RingtoneDropdown({
    required this.title,
    required this.icon,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final String value;
  final List<RingtoneOption> options;
  final String Function(RingtoneOption) optionLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final validValue = options.any((option) => option.id == value)
        ? value
        : RingtoneOption.systemId;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brLg,
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary),
          AppSpacing.hGapMd,
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: validValue,
              decoration: InputDecoration(
                labelText: title,
                border: InputBorder.none,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option.id,
                    child: Text(optionLabel(option)),
                  ),
              ],
              onChanged: (id) {
                if (id != null) onChanged(id);
              },
            ),
          ),
        ],
      ),
    );
  }
}
