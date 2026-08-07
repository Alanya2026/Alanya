import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/utils/app_log.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import 'chat_detail_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<User> members;

  /// Nom pré-rempli et éditable — utilisé quand le groupe naît d'une liste de
  /// contacts (« Famille » devient le nom proposé du groupe).
  final String? initialName;

  const CreateGroupScreen({
    super.key,
    required this.members,
    this.initialName,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late List<User> _members;
  File? _photoFile;
  bool _creating = false;
  bool _onlyAdminsCanSend = false;
  bool _onlyAdminsCanEditInfo = false;
  bool _hideHistoryForNewMembers = false;
  bool _onlyAdminsCanAddMembers = false;

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
    _nameController.text = widget.initialName ?? '';
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _photoFile = File(x.path));
  }

  void _removeMember(User u) {
    setState(() => _members.removeWhere((m) => m.alanyaID == u.alanyaID));
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addAtLeastOneMember)),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final api = Provider.of<TalkyApiClient>(context, listen: false);
      final chat = Provider.of<ChatProvider>(context, listen: false);

      String? photoUrl;
      if (_photoFile != null) {
        final res = await api.uploadImage(_photoFile!);
        photoUrl = (res['url'] as String?)?.trim();
      }

      final description = _descriptionController.text.trim();
      final cree = await api.createGroup(
        groupName: _nameController.text.trim(),
        participantIDs: _members.map((m) => m.alanyaID).toList(),
        groupPhoto: photoUrl,
        description: description.isEmpty ? null : description,
        onlyAdminsCanSend: _onlyAdminsCanSend,
        onlyAdminsCanEditInfo: _onlyAdminsCanEditInfo,
        hideHistoryForNewMembers: _hideHistoryForNewMembers,
        onlyAdminsCanAddMembers: _onlyAdminsCanAddMembers,
      );

      await chat.refreshConversations(force: true);
      if (!mounted) return;

      // La conversation créée était jetée, et l'écran renvoyait à la racine :
      // on venait de créer un groupe sans pouvoir y entrer. On l'ouvre, et le
      // message système « X a créé le groupe » en est déjà la première ligne.
      final convId = (cree['conversID'] as num?)?.toInt() ?? 0;
      if (convId <= 0) {
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }
      Navigator.popUntil(context, (route) => route.isFirst);
      unawaited(Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: _nameController.text.trim(),
            conversationId: convId,
            isGroup: true,
            avatarUrl: photoUrl,
          ),
        ),
      ));
    } catch (e, st) {
      AppLog.e('CreateGroup', context.l10n.failedToCreateGroup, e, st);
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.unableToCreateTheGroupTry)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        centerTitle: true,
        title: Text(context.l10n.createAGroup),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            _HeaderCard(
              photoFile: _photoFile,
              nameController: _nameController,
              onPickPhoto: _pickPhoto,
            ),
            AppSpacing.vGapLg,
            _DescriptionCard(controller: _descriptionController),
            AppSpacing.vGapLg,
            _MembersCard(
              members: _members,
              onRemove: _removeMember,
            ),
            AppSpacing.vGapLg,
            _GroupSettingsCard(
              onlyAdminsCanSend: _onlyAdminsCanSend,
              onlyAdminsCanEditInfo: _onlyAdminsCanEditInfo,
              hideHistoryForNewMembers: _hideHistoryForNewMembers,
              onlyAdminsCanAddMembers: _onlyAdminsCanAddMembers,
              onSendChanged: (v) => setState(() => _onlyAdminsCanSend = v),
              onEditChanged: (v) => setState(() => _onlyAdminsCanEditInfo = v),
              onHideHistoryChanged: (v) =>
                  setState(() => _hideHistoryForNewMembers = v),
              onAddMembersChanged: (v) =>
                  setState(() => _onlyAdminsCanAddMembers = v),
            ),
            AppSpacing.vGapXxl,
            Consumer<ConnectivityProvider>(
              builder: (context, conn, _) {
                final online = conn.isOnline;
                final disabled = _creating || !online;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: disabled ? null : _create,
                    icon: _creating
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.onPrimary,
                            ),
                          )
                        : Icon(online
                            ? CupertinoIcons.check_mark
                            : CupertinoIcons.wifi_slash),
                    label: Text(_creating
                        ? context.l10n.creating
                        : (online
                            ? context.l10n.createGroup
                            : context.l10n.unavailableOffline)),
                    style: ElevatedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.buttonHeight),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.brMd,
                      ),
                      elevation: 0,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── CARTE CONTENEUR ───────────────────────────────────────────────────

class _CreateGroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _CreateGroupCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? context.colors.surfaceContainerHigh
            : context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: isDark ? null : AppShadows.subtle,
        border: isDark
            ? Border.all(color: context.colors.outline.withValues(alpha: 0.55))
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ── EN-TÊTE (PHOTO + NOM) ─────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final File? photoFile;
  final TextEditingController nameController;
  final VoidCallback onPickPhoto;

  const _HeaderCard({
    required this.photoFile,
    required this.nameController,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return _CreateGroupCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.lg,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: onPickPhoto,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: context.colors.surfaceContainerHighest,
                  backgroundImage:
                      photoFile != null ? FileImage(photoFile!) : null,
                  child: photoFile == null
                      ? Icon(
                          CupertinoIcons.camera,
                          color: context.colors.onSurfaceVariant,
                          size: AppIconSize.lg,
                        )
                      : null,
                ),
              ),
              GestureDetector(
                onTap: onPickPhoto,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.surface,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: AppIconSize.sm,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vGapLg,
          TextFormField(
            controller: nameController,
            validator: Validators.required,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            style: context.text.headlineSmall,
            decoration: InputDecoration(
              hintText: context.l10n.enterTheGroupName,
              hintStyle: context.text.headlineSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ── DESCRIPTION ───────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  final TextEditingController controller;

  const _DescriptionCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return _CreateGroupCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.groupDescription, style: context.text.titleSmall),
          AppSpacing.vGapSm,
          TextFormField(
            controller: controller,
            maxLength: 512,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: context.text.bodyMedium,
            decoration: InputDecoration(
              hintText: context.l10n.groupDescriptionHint,
              hintStyle: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterStyle: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MEMBRES ───────────────────────────────────────────────────────────

class _MembersCard extends StatelessWidget {
  final List<User> members;
  final void Function(User) onRemove;

  const _MembersCard({
    required this.members,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _CreateGroupCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.membersCount(members.length),
            style: context.text.titleSmall,
          ),
          AppSpacing.vGapMd,
          ...members.map((member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.semantic.surfaceMuted,
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  children: [
                    AppAvatar(
                      name: member.nom,
                      imageUrl: member.avatarUrl.isNotEmpty
                          ? member.avatarUrl
                          : null,
                      size: AppSizes.avatarSm,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.nom, style: context.text.titleSmall),
                          Text(
                            AlanyaPhoneFormatter.formatDisplay(
                              member.alanyaPhone,
                            ),
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.xmark,
                        color: context.colors.onSurfaceVariant,
                        size: AppIconSize.sm,
                      ),
                      onPressed: () => onRemove(member),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── RÉGLAGES DU GROUPE ────────────────────────────────────────────────

class _GroupSettingsCard extends StatelessWidget {
  final bool onlyAdminsCanSend;
  final bool onlyAdminsCanEditInfo;
  final bool hideHistoryForNewMembers;
  final bool onlyAdminsCanAddMembers;
  final ValueChanged<bool> onSendChanged;
  final ValueChanged<bool> onEditChanged;
  final ValueChanged<bool> onHideHistoryChanged;
  final ValueChanged<bool> onAddMembersChanged;

  const _GroupSettingsCard({
    required this.onlyAdminsCanSend,
    required this.onlyAdminsCanEditInfo,
    required this.hideHistoryForNewMembers,
    required this.onlyAdminsCanAddMembers,
    required this.onSendChanged,
    required this.onEditChanged,
    required this.onHideHistoryChanged,
    required this.onAddMembersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _CreateGroupCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              context.l10n.groupSettings,
              style: context.text.titleSmall,
            ),
          ),
          SwitchListTile(
            value: onlyAdminsCanSend,
            onChanged: onSendChanged,
            title: Text(
              context.l10n.onlyAdminsCanSendLabel,
              style: context.text.bodyMedium,
            ),
            subtitle: Text(
              context.l10n.onlyAdminsCanSendSubtitle,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            value: onlyAdminsCanEditInfo,
            onChanged: onEditChanged,
            title: Text(
              context.l10n.onlyAdminsCanEditInfoLabel,
              style: context.text.bodyMedium,
            ),
            subtitle: Text(
              context.l10n.onlyAdminsCanEditInfoSubtitle,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            value: hideHistoryForNewMembers,
            onChanged: onHideHistoryChanged,
            title: Text(
              context.l10n.hideHistoryForNewMembersLabel,
              style: context.text.bodyMedium,
            ),
            subtitle: Text(
              context.l10n.hideHistoryForNewMembersSubtitle,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          SwitchListTile(
            value: onlyAdminsCanAddMembers,
            onChanged: onAddMembersChanged,
            title: Text(
              context.l10n.onlyAdminsCanAddMembersLabel,
              style: context.text.bodyMedium,
            ),
            subtitle: Text(
              context.l10n.onlyAdminsCanAddMembersSubtitle,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
