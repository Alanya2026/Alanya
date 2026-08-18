import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/list_ringtone_preferences.dart';
import '../../core/services/ringtone_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_list_display.dart';

class ListRingtoneScreen extends StatefulWidget {
  const ListRingtoneScreen({
    super.key,
    required this.list,
    required this.allLists,
  });

  final LocalContactList list;
  final List<LocalContactList> allLists;

  @override
  State<ListRingtoneScreen> createState() => _ListRingtoneScreenState();
}

class _ListRingtoneScreenState extends State<ListRingtoneScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingId;

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  /// Aperçu du son actuellement choisi dans un des deux menus. Même
  /// comportement que l'écran des sonneries d'appel : un second appui coupe.
  Future<void> _togglePreview(RingtoneOption option) async {
    // La sonnerie système n'existe pas sous forme de fichier lisible par l'app.
    if (option.type == RingtoneSourceType.system) return;

    if (_previewingId == option.id) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _previewingId = null);
      return;
    }

    try {
      await _previewPlayer.stop();
      if (option.type == RingtoneSourceType.bundled) {
        await _previewPlayer.setAsset(option.assetPath!);
      } else {
        await _previewPlayer.setFilePath(option.filePath!);
      }
      setState(() => _previewingId = option.id);
      await _previewPlayer.play();
      _previewPlayer.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .then((_) {
        if (mounted && _previewingId == option.id) {
          setState(() => _previewingId = null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.ringtonePreviewError)),
      );
    }
  }

  /// Garantit qu'un choix déjà enregistré reste proposé même s'il ne fait plus
  /// partie du catalogue de l'événement — cas d'une liste configurée avant la
  /// séparation appels / notifications, dont le son de message est une
  /// sonnerie d'appel. On ne réécrit rien : l'ancien choix reste actif tant que
  /// l'utilisateur n'en sélectionne pas un autre.
  List<RingtoneOption> _withLegacy(
    List<RingtoneOption> catalogue,
    String? savedId, {
    String? note,
  }) {
    if (savedId == null || savedId.isEmpty) return catalogue;
    if (catalogue.any((option) => option.id == savedId)) return catalogue;
    final legacy = RingtonePreferences.optionById(savedId);
    if (legacy == null) return catalogue;
    return [
      RingtoneOption(
        // Identifiant inchangé : l'entrée reste celle déjà enregistrée.
        id: legacy.id,
        label: note == null ? legacy.label : '${legacy.label} $note',
        type: legacy.type,
        assetPath: legacy.assetPath,
        filePath: legacy.filePath,
        androidRawResource: legacy.androidRawResource,
        iosCafResource: legacy.iosCafResource,
      ),
      ...catalogue,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    final allLists = widget.allLists;
    final listPrefs = context.watch<ListRingtonePreferences>();
    final ringtonePrefs = context.watch<RingtonePreferences>();
    final setting = listPrefs.settingFor(list.idList);
    // Deux catalogues distincts : sons courts pour les messages, sonneries
    // pour les appels.
    final messageOptions = _withLegacy(
      ringtonePrefs.notificationOptions,
      setting.messageRingtoneId,
      note: '(sonnerie d’appel)',
    );
    final callOptions =
        _withLegacy(ringtonePrefs.allOptions, setting.callRingtoneId);
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
            'Choisissez deux sons différents pour cette liste : un son court '
            'pour les messages, une sonnerie pour les appels.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapLg,
          _RingtoneDropdown(
            title: 'Nouveaux messages',
            icon: Icons.message_outlined,
            value: setting.messageRingtoneId ?? RingtoneOption.systemId,
            options: messageOptions,
            optionLabel: label,
            previewingId: _previewingId,
            onPreview: _togglePreview,
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
            options: callOptions,
            optionLabel: label,
            previewingId: _previewingId,
            onPreview: _togglePreview,
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
    required this.previewingId,
    required this.onPreview,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final String value;
  final List<RingtoneOption> options;
  final String Function(RingtoneOption) optionLabel;
  final String? previewingId;
  final ValueChanged<RingtoneOption> onPreview;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final validValue = options.any((option) => option.id == value)
        ? value
        : RingtoneOption.systemId;
    final current = options.firstWhere(
      (option) => option.id == validValue,
      orElse: () => RingtoneOption.system,
    );
    final canPreview = current.type != RingtoneSourceType.system;
    final playing = previewingId == current.id;
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
          IconButton(
            icon: Icon(playing ? Icons.stop_circle_outlined : Icons.play_circle_outline),
            color: context.colors.primary,
            tooltip: playing ? 'Arrêter' : 'Écouter',
            onPressed: canPreview ? () => onPreview(current) : null,
          ),
        ],
      ),
    );
  }
}
