import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/list_ringtone_preferences.dart';
import '../../core/services/ringtone_preferences.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_list_display.dart';
import '../../widgets/common/ringtone_sync_info.dart';

/// Préfixe des entrées « son personnalisé choisi ailleurs, absent ici ».
/// Elles ne sont pas sélectionnables : elles disent seulement ce que la liste
/// attend, pour que l'utilisateur ne croie pas son réglage perdu.
const String _kMissingPrefix = 'missing:';

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
    // Son personnalisé attendu mais absent de cet appareil : rien à écouter.
    if (option.type == RingtoneSourceType.custom && option.filePath == null) {
      return;
    }

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

  /// Ajoute en tête l'entrée décrivant un son personnalisé attendu par la
  /// liste mais absent de cet appareil. La préférence n'est pas perdue : elle
  /// reprendra dès que le fichier sera importé ici (reconnaissance par le
  /// contenu du fichier, pas par son nom).
  List<RingtoneOption> _withMissing(
    List<RingtoneOption> catalogue,
    ListSoundChoice? sound,
    String? localId,
  ) {
    if (sound?.type != ListSoundType.custom) return catalogue;
    if (localId != null && localId.isNotEmpty) return catalogue;
    final name = sound!.name?.trim();
    return [
      RingtoneOption(
        id: '$_kMissingPrefix${sound.id}',
        label: '${name == null || name.isEmpty ? 'Sonnerie importée' : name} '
            '— ${context.l10n.listRingtoneSoundMissing}',
        type: RingtoneSourceType.custom,
      ),
      ...catalogue,
    ];
  }

  String _valueFor(String? localId, ListSoundChoice? sound) {
    if (localId != null && localId.isNotEmpty) return localId;
    if (sound?.type == ListSoundType.custom) {
      return '$_kMissingPrefix${sound!.id}';
    }
    return RingtoneOption.systemId;
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
    final messageOptions = _withMissing(
      _withLegacy(
        ringtonePrefs.notificationOptions,
        setting.messageRingtoneId,
        note: '(sonnerie d’appel)',
      ),
      setting.messageSound,
      setting.messageRingtoneId,
    );
    final callOptions = _withMissing(
      _withLegacy(ringtonePrefs.allOptions, setting.callRingtoneId),
      setting.callSound,
      setting.callRingtoneId,
    );
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
            value: _valueFor(setting.messageRingtoneId, setting.messageSound),
            options: messageOptions,
            optionLabel: label,
            previewingId: _previewingId,
            onPreview: _togglePreview,
            onChanged: (id) {
              // Ré-appuyer sur l'entrée « fichier absent » ne doit rien
              // enregistrer : ce n'est pas un son sélectionnable.
              if (id.startsWith(_kMissingPrefix)) return;
              listPrefs.setRingtone(list.idList, messageRingtoneId: id);
            },
          ),
          AppSpacing.vGapMd,
          _RingtoneDropdown(
            title: 'Appels entrants',
            icon: Icons.phone_in_talk_outlined,
            value: _valueFor(setting.callRingtoneId, setting.callSound),
            options: callOptions,
            optionLabel: label,
            previewingId: _previewingId,
            onPreview: _togglePreview,
            onChanged: (id) {
              if (id.startsWith(_kMissingPrefix)) return;
              listPrefs.setRingtone(list.idList, callRingtoneId: id);
            },
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.l10n.listRingtoneSyncedNote,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              const RingtoneSyncInfoButton(),
            ],
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
    final canPreview = current.type == RingtoneSourceType.bundled ||
        (current.type == RingtoneSourceType.custom && current.filePath != null);
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
