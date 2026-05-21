import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  int _typeMedia = 0; // 0 = vidéo+audio, 1 = audio seulement
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
          colorScheme: const ColorScheme.light(primary: Colors.indigo),
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
          colorScheme: const ColorScheme.light(primary: Colors.indigo),
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
        const SnackBar(content: Text('Veuillez saisir un titre pour la réunion')),
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
        // UTC explicite : évite tout décalage selon le fuseau serveur/client.
        startTime: startDateTime.toUtc().toIso8601String(),
        room: roomCode,
        duree: _selectedDuration,
        typeMedia: _typeMedia,
      );

      if (_selectedParticipants.isNotEmpty) {
        final meetingId = data['idMeeting'] as int? ?? data['id'] as int?;
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
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${_selectedDate.day} ${months[_selectedDate.month]} ${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Planifier une réunion',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.indigo),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Créer',
                    style: TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Titre de la réunion',
                hintStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
              ),
            ),
            const Divider(height: 32),

            // Type de réunion
            _SectionLabel(label: 'Type'),
            const SizedBox(height: 10),
            Row(
              children: [
                _TypeChip(
                  label: 'Vidéo',
                  icon: CupertinoIcons.videocam_fill,
                  selected: _typeMedia == 0,
                  onTap: () => setState(() => _typeMedia = 0),
                ),
                const SizedBox(width: 12),
                _TypeChip(
                  label: 'Audio',
                  icon: CupertinoIcons.phone_fill,
                  selected: _typeMedia == 1,
                  onTap: () => setState(() => _typeMedia = 1),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Date et heure
            _SectionLabel(label: 'Date et heure'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(),
                    onTap: _selectDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.access_time,
                    label: _selectedTime.format(context),
                    onTap: _selectTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Durée
            _SectionLabel(label: 'Durée'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(_durations.length, (i) {
                final selected = _selectedDuration == _durations[i];
                return GestureDetector(
                  onTap: () => setState(() => _selectedDuration = _durations[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? Colors.indigo : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _durationLabels[i],
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 28),

            // Participants
            _SectionLabel(label: 'Participants'),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _openParticipantPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined, color: Colors.indigo, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedParticipants.isEmpty
                            ? 'Ajouter des participants'
                            : '${_selectedParticipants.length} participant${_selectedParticipants.length > 1 ? 's' : ''} sélectionné${_selectedParticipants.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 15,
                          color: _selectedParticipants.isEmpty ? Colors.grey : Colors.black87,
                          fontWeight: _selectedParticipants.isEmpty ? FontWeight.normal : FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
            if (_selectedParticipants.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _selectedParticipants.map((user) {
                  final initial = user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.indigo.shade300,
                      child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    label: Text(
                      user.nom.isNotEmpty ? user.nom : user.pseudo,
                      style: const TextStyle(fontSize: 13),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(
                      () => _selectedParticipants.removeWhere((u) => u.alanyaID == user.alanyaID),
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.indigo.shade200),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 28),

            // Résumé
            _SummaryCard(
              date: _formatDate(),
              time: _selectedTime.format(context),
              duration: _durationLabels[_durations.indexOf(_selectedDuration)],
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
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.indigo,
        fontSize: 13,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: selected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.indigo),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Résumé',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            icon: Icons.calendar_today_outlined,
            text: '$date à $time',
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            icon: Icons.timelapse,
            text: 'Durée : $duration',
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            icon: typeMedia == 0 ? Icons.videocam_outlined : Icons.phone_outlined,
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
        Icon(icon, size: 15, color: Colors.indigo.shade400),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.indigo.shade700, fontSize: 13)),
      ],
    );
  }
}
