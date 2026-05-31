import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../meetings/participant_picker_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _selectedDuration = 60;
  int _typeMedia = 0;
  bool _isLoading = false;
  List<User> _selectedParticipants = [];

  static const _durations = [30, 60, 90, 120, 180];
  static const _durationLabels = ['30 min', '1 h', '1 h 30', '2 h', '3 h'];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: context.colors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: context.colors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _openParticipantPicker() async {
    final result = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantPickerScreen(
          initialSelected: _selectedParticipants,
          confirmLabel: 'Confirmer',
        ),
      ),
    );
    if (result != null) setState(() => _selectedParticipants = result);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez saisir un titre pour la réunion')),
      );
      return;
    }

    final startDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (startDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La date doit être dans le futur')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final roomCode = 'mtg-${DateTime.now().millisecondsSinceEpoch}';

      final data = await apiClient.createMeeting(
        objet: title,
        startTime: startDateTime.toUtc().toIso8601String(),
        room: roomCode,
        duree: _selectedDuration,
        typeMedia: _typeMedia,
      );

      if (_selectedParticipants.isNotEmpty) {
        final meetingId =
            data['idMeeting'] as int? ?? data['id'] as int?;
        if (meetingId != null) {
          final ids = _selectedParticipants.map((u) => u.alanyaID).toList();
          await apiClient.inviteParticipants(meetingId, ids);
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la création : $e')),
        );
      }
    }
  }

  String _formatDate() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      return "Aujourd'hui";
    }
    if (_selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day) {
      return 'Demain';
    }
    const months = [
      '',
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Jun',
      'Jul',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    return '${_selectedDate.day} ${months[_selectedDate.month]} ${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Planifier une réunion'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: Text(
                    'Créer',
                    style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
          AppSpacing.hGapSm,
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: context.text.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Titre de la réunion',
                hintStyle: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: context.colors.onSurfaceVariant,
                ),
                border: InputBorder.none,
              ),
            ),
            const Divider(height: 32),

            // Type de réunion
            _SectionLabel(label: 'Type'),
            AppSpacing.vGapSm,
            Row(
              children: [
                _TypeChip(
                  label: 'Vidéo',
                  icon: CupertinoIcons.videocam_fill,
                  selected: _typeMedia == 0,
                  onTap: () => setState(() => _typeMedia = 0),
                ),
                AppSpacing.hGapMd,
                _TypeChip(
                  label: 'Audio',
                  icon: CupertinoIcons.phone_fill,
                  selected: _typeMedia == 1,
                  onTap: () => setState(() => _typeMedia = 1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl + 4),

            // Date et heure
            _SectionLabel(label: 'Date et heure'),
            AppSpacing.vGapSm,
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(),
                    onTap: _selectDate,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time,
                    label: _selectedTime.format(context),
                    onTap: _selectTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl + 4),

            // Durée
            _SectionLabel(label: 'Durée'),
            AppSpacing.vGapSm,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: List.generate(_durations.length, (i) {
                final selected = _selectedDuration == _durations[i];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedDuration = _durations[i]),
                  child: AnimatedContainer(
                    duration: AppDurations.fast,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg + 2, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: selected
                          ? context.colors.primary
                          : context.semantic.surfaceMuted,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      _durationLabels[i],
                      style: TextStyle(
                        color: selected
                            ? context.colors.onPrimary
                            : context.colors.onSurface,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xxl + 4),

            // Participants
            _SectionLabel(label: 'Participants'),
            AppSpacing.vGapSm,
            GestureDetector(
              onTap: _openParticipantPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.semantic.surfaceMuted,
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined,
                        color: context.colors.primary,
                        size: AppIconSize.sm),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        _selectedParticipants.isEmpty
                            ? 'Ajouter des participants'
                            : '${_selectedParticipants.length} participant${_selectedParticipants.length > 1 ? 's' : ''} sélectionné${_selectedParticipants.length > 1 ? 's' : ''}',
                        style: context.text.bodyMedium?.copyWith(
                          color: _selectedParticipants.isEmpty
                              ? context.colors.onSurfaceVariant
                              : context.colors.onSurface,
                          fontWeight: _selectedParticipants.isEmpty
                              ? FontWeight.normal
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: context.colors.outlineVariant),
                  ],
                ),
              ),
            ),
            if (_selectedParticipants.isNotEmpty) ...[
              AppSpacing.vGapSm,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm - 2,
                children: _selectedParticipants.map((user) {
                  final initial =
                      user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: context.colors.primary,
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                    ),
                    label: Text(
                      user.nom.isNotEmpty ? user.nom : user.pseudo,
                      style: context.text.labelMedium,
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() =>
                        _selectedParticipants.removeWhere(
                            (u) => u.alanyaID == user.alanyaID)),
                    backgroundColor: context.colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.brPill,
                      side:
                          BorderSide(color: context.colors.primaryContainer),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl + 4),

            // Résumé
            _SummaryCard(
              date: _formatDate(),
              time: _selectedTime.format(context),
              duration:
                  _durationLabels[_durations.indexOf(_selectedDuration)],
              typeMedia: _typeMedia,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.text.labelMedium?.copyWith(
        color: context.colors.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primary
              : context.semantic.surfaceMuted,
          borderRadius: AppRadius.brSm,
          border: selected
              ? null
              : Border.all(color: context.colors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: AppIconSize.sm,
                color: selected
                    ? context.colors.onPrimary
                    : context.colors.onSurfaceVariant),
            AppSpacing.hGapSm,
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? context.colors.onPrimary
                    : context.colors.onSurface,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.semantic.surfaceMuted,
          borderRadius: AppRadius.brSm,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: AppIconSize.sm, color: context.colors.primary),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                label,
                style: context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.date,
    required this.time,
    required this.duration,
    required this.typeMedia,
  });

  final String date;
  final String time;
  final String duration;
  final int typeMedia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: context.colors.primaryContainer,
        borderRadius: AppRadius.brMd,
        border: Border.all(
            color: context.colors.primaryContainer.withAlpha(180)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.vGapSm,
          _SummaryRow(icon: Icons.calendar_today_outlined, text: '$date à $time'),
          AppSpacing.vGapXs,
          _SummaryRow(icon: Icons.timelapse, text: 'Durée : $duration'),
          AppSpacing.vGapXs,
          _SummaryRow(
            icon: typeMedia == 0
                ? Icons.videocam_outlined
                : Icons.phone_outlined,
            text: typeMedia == 0 ? 'Réunion vidéo' : 'Appel audio',
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.sm - 4, color: context.colors.primary),
        AppSpacing.hGapSm,
        Text(
          text,
          style: context.text.bodySmall
              ?.copyWith(color: context.colors.primary),
        ),
      ],
    );
  }
}
