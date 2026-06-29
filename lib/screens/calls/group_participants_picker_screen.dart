import 'package:flutter/material.dart';

import '../../core/call_limits.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';

/// Sélecteur de participants pour un appel de groupe dont le nombre de membres
/// dépasse la limite autorisée. Retourne la `List<User>` choisie via `Navigator.pop`.
class GroupParticipantsPickerScreen extends StatefulWidget {
  final List<User> members;
  final int maxSelection;
  final bool isVideo;

  GroupParticipantsPickerScreen({
    super.key,
    required this.members,
    required this.isVideo,
    int? maxSelection,
  }) : maxSelection =
            maxSelection ?? CallLimits.maxSelectable(isVideo: isVideo);

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
              content: Text('Maximum ${widget.maxSelection} participants'),
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${_selected.length} / ${widget.maxSelection}'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              widget.isVideo
                  ? 'Sélectionnez jusqu\'à ${widget.maxSelection} membres pour l\'appel vidéo'
                  : 'Sélectionnez jusqu\'à ${widget.maxSelection} membres pour l\'appel vocal',
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: widget.members.length,
        itemBuilder: (context, index) {
          final user = widget.members[index];
          final isSelected = _selected.contains(user.alanyaID);
          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) => _toggle(user),
            controlAffinity: ListTileControlAffinity.trailing,
            activeColor: context.colors.primary,
            secondary: Stack(
              children: [
                AppAvatar(
                  imageUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
                  name: user.nom.isNotEmpty ? user.nom : user.pseudo,
                  size: AppSizes.avatarSm,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.colors.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              user.nom.isNotEmpty ? user.nom : user.pseudo,
              style: context.text.titleSmall,
            ),
            subtitle: user.alanyaPhone.isNotEmpty
                ? Text(
                    AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone),
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  )
                : null,
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: ElevatedButton.icon(
            onPressed: canConfirm ? _confirm : null,
            icon: Icon(widget.isVideo ? Icons.videocam : Icons.call),
            label: Text(
              widget.isVideo
                  ? 'Démarrer l\'appel vidéo'
                  : 'Démarrer l\'appel vocal',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              shape:
                  const RoundedRectangleBorder(borderRadius: AppRadius.brSm),
            ),
          ),
        ),
      ),
    );
  }
}
