import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/utils/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_log.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<User> members;

  const CreateGroupScreen({super.key, required this.members});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  late List<User> _members;
  File? _photoFile;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.members);
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
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
        SnackBar(
            content: Text(context.l10n.addAtLeastOneMember)),
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

      await api.createGroup(
        groupName: _nameController.text,
        participantIDs: _members.map((m) => m.alanyaID).toList(),
        groupPhoto: photoUrl,
      );

      await chat.refreshConversations();
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
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
      appBar: AppBar(title: Text(context.l10n.createAGroup)),
      body: SingleChildScrollView(
        padding: AppSpacing.card,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(60),
                    image: _photoFile != null
                        ? DecorationImage(
                            image: FileImage(_photoFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _photoFile == null
                      ? Icon(
                          CupertinoIcons.camera,
                          color: context.colors.onSurfaceVariant,
                          size: 40,
                        )
                      : null,
                ),
              ),
            ),
            AppSpacing.vGapXxl,

            // Name field
            Text(context.l10n.groupName, style: context.text.titleSmall),
            AppSpacing.vGapSm,
            TextFormField(
              controller: _nameController,
              validator: Validators.required,
              decoration: InputDecoration(
                hintText: context.l10n.enterTheGroupName,
              ),
            ),
            AppSpacing.vGapXxl,

            // Members
            Text(context.l10n.membersCount(_members.length),
                style: context.text.titleSmall),
            AppSpacing.vGapSm,
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _members.length,
              separatorBuilder: (_, __) => AppSpacing.vGapSm,
              itemBuilder: (_, idx) {
                final member = _members[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
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
                            Text(member.nom,
                                style: context.text.titleSmall),
                            Text(
                                AlanyaPhoneFormatter.formatDisplay(
                                    member.alanyaPhone),
                                style: context.text.bodySmall?.copyWith(
                                    color:
                                        context.colors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark),
                        onPressed: () => _removeMember(member),
                      ),
                    ],
                  ),
                );
              },
            ),
            AppSpacing.vGapXxl,

            // Create button
            Consumer<ConnectivityProvider>(
              builder: (context, conn, _) {
                final online = conn.isOnline;
                final disabled = _creating || !online;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: disabled ? null : _create,
                    icon: _creating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.brMd),
                      elevation: 0,
                    ),
                  ),
                );
              },
            ),
          ],
          ),
        ),
      ),
    );
  }
}
