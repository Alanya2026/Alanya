import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/avatar_utils.dart';
import '../../talky_models.dart';

/// Sélecteur de participants pour un appel de groupe lancé depuis un groupe
/// > 10 membres. Retourne la `List<User>` choisie via `Navigator.pop`.
class GroupParticipantsPickerScreen extends StatefulWidget {
  final List<User> members;
  final int maxSelection;
  final bool isVideo;

  const GroupParticipantsPickerScreen({
    super.key,
    required this.members,
    this.maxSelection = 9,
    required this.isVideo,
  });

  @override
  State<GroupParticipantsPickerScreen> createState() =>
      _GroupParticipantsPickerScreenState();
}

class _GroupParticipantsPickerScreenState
    extends State<GroupParticipantsPickerScreen> {
  final Set<int> _selected = <int>{};

  void _toggle(User u) {
    setState(() {
      if (_selected.contains(u.alanyaID)) {
        _selected.remove(u.alanyaID);
      } else {
        if (_selected.length >= widget.maxSelection) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Maximum ${widget.maxSelection} participants',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _selected.add(u.alanyaID);
      }
    });
  }

  void _confirm() {
    final selectedUsers =
        widget.members.where((u) => _selected.contains(u.alanyaID)).toList();
    Navigator.pop(context, selectedUsers);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _selected.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_selected.length} / ${widget.maxSelection}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.isVideo
                  ? 'Sélectionnez jusqu\'à ${widget.maxSelection} membres pour l\'appel vidéo'
                  : 'Sélectionnez jusqu\'à ${widget.maxSelection} membres pour l\'appel vocal',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: widget.members.length,
        itemBuilder: (context, index) {
          final user = widget.members[index];
          final isSelected = _selected.contains(user.alanyaID);
          final hasPhoto = hasValidAvatarUrl(user.avatarUrl);
          final initial =
              user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?';
          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) => _toggle(user),
            controlAffinity: ListTileControlAffinity.trailing,
            activeColor: Colors.indigo,
            secondary: Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFCBD0E8),
                  backgroundImage:
                      hasPhoto ? CachedNetworkImageProvider(user.avatarUrl) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              user.nom.isNotEmpty ? user.nom : user.pseudo,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: user.alanyaPhone.isNotEmpty
                ? Text(
                    user.alanyaPhone,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  )
                : null,
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: ElevatedButton.icon(
            onPressed: canConfirm ? _confirm : null,
            icon: Icon(widget.isVideo ? Icons.videocam : Icons.call),
            label: Text(
              widget.isVideo ? 'Démarrer l\'appel vidéo' : 'Démarrer l\'appel vocal',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
