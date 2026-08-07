import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_log.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/call_service.dart';
import '../../core/call_limits.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';
import '../../core/utils/group_permissions.dart';
import '../../core/utils/document_file_style.dart';
import '../../core/db/app_database.dart';
import '../../widgets/common/common.dart';
import '../../widgets/image_message_preview.dart';
import '../../widgets/video_message_preview.dart';
import '../calls/group_participants_picker_screen.dart';
import '../meetings/participant_picker_screen.dart';
import 'contact_detail_screen.dart';
import 'conversation_media_screen.dart';
import 'media_viewer_screen.dart';
import '../../widgets/conversation_mute_sheet.dart';

class GroupDetailScreen extends StatefulWidget {
  final int conversationId;
  final String groupName;
  final String? groupAvatar;

  const GroupDetailScreen({
    super.key,
    required this.conversationId,
    required this.groupName,
    this.groupAvatar,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  /// Dernier état connu, alimenté par le stream Drift. Conservé pour les
  /// callbacks (`_addParticipants`, `_leaveGroup`…) qui ne sont pas dans
  /// l'arbre du `StreamBuilder`.
  Conversation? _group;

  /// Vrai une fois qu'une exclusion a été détectée : empêche de rejouer le
  /// `pop` à chaque frame quand le stream continue d'émettre `null`.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // Le cache local peut être en retard (participants jamais synchronisés,
    // rôle absent d'une version antérieure) : on redemande au serveur sans
    // bloquer l'affichage, qui part de Drift.
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await context.read<ChatProvider>().repository
          .refreshConversation(widget.conversationId);
    } catch (e) {
      // Hors ligne : la fiche reste consultable depuis le cache.
      AppLog.w('GroupDetail', 'refreshConversation échouée: $e');
    }
  }

  /// Reconstruit le modèle depuis la ligne Drift.
  Conversation _fromLocal(LocalConversation c) => Conversation(
        conversID: c.conversID,
        isGroup: c.isGroup,
        groupName: c.groupName,
        groupPhoto: c.groupPhoto,
        description: c.description,
        createdBy: c.createdBy,
        lastMessage: c.lastMessage,
        lastMessageAt: c.lastMessageAt?.toIso8601String(),
        lastMessageSenderID: c.lastMessageSenderID,
        lastMessageType: c.lastMessageType,
        lastMessageStatus: c.lastMessageStatus,
        onlyAdminsCanSend: c.onlyAdminsCanSend,
        onlyAdminsCanEditInfo: c.onlyAdminsCanEditInfo,
        hideHistoryForNewMembers: c.hideHistoryForNewMembers,
        onlyAdminsCanAddMembers: c.onlyAdminsCanAddMembers,
        unreadCount: c.unreadCount,
        isPinned: c.isPinned,
        isArchived: c.isArchived,
        myRole: c.myRole,
        mentionsOnly: c.mentionsOnly,
        myPendingJoinMsgID: c.myPendingJoinMsgID,
        myHistoryCutoffAt: c.myHistoryCutoffAt?.toIso8601String(),
        participants: _parseParticipants(c.participantsJson),
      );

  List<Participant> _parseParticipants(String json) {
    try {
      final data =
          (jsonDecode(json) as List?)?.cast<Map<String, dynamic>>() ?? [];
      return data.map(Participant.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  // Conservé pour réactivation des appels de groupe.
  // ignore: unused_element
  Future<void> _startGroupCall(bool isVideo) async {
    if (_group == null) return;
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser;
    if (me == null) return;

    final members = _group!.participants;
    final others = members
        .where((p) => p.alanyaID != me.alanyaID)
        .map((p) => p.user)
        .toList();

    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.noOtherMembersToCall)),
      );
      return;
    }

    List<User> targets;
    final maxOthers = CallLimits.maxSelectable(isVideo: isVideo);
    if (others.length <= maxOthers) {
      targets = others;
    } else {
      final picked = await Navigator.push<List<User>>(
        context,
        MaterialPageRoute(
          builder: (_) => GroupParticipantsPickerScreen(
            members: others,
            isVideo: isVideo,
          ),
        ),
      );
      if (picked == null || picked.isEmpty || !mounted) return;
      targets = picked;
    }

    final cs = context.read<CallService>();
    if (cs.status != CallStatus.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.aCallIsAlreadyInProgress)),
      );
      return;
    }

    final roster = targets
        .map((u) => GroupParticipantInfo(
              id: u.alanyaID.toString(),
              name: u.nom.isNotEmpty ? u.nom : u.pseudo,
              photo: u.avatarUrl,
            ))
        .toList();

    final roomId =
        'group_${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}';

    await cs.createGroupCall(
      roomId: roomId,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
      targetUserIds: targets.map((u) => u.alanyaID).toList(),
      isVideo: isVideo,
      targets: roster,
    );

    if (!mounted) return;
    await cs.navigateToCallUi(context);
  }

  Future<void> _addParticipants() async {
    if (_group == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.colors.error;
    final chat = Provider.of<ChatProvider>(context, listen: false);

    final excludeIds =
        _group!.participants.map((p) => p.alanyaID).toSet();

    final picked = await Navigator.push<List<User>>(
      context,
      MaterialPageRoute(
        builder: (_) => ParticipantPickerScreen(
          confirmLabel: context.l10n.add,
          excludeIds: excludeIds,
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;

    try {
      // Via le repository : la conversation enrichie renvoyée atterrit en
      // Drift, et le StreamBuilder rafraîchit la liste tout seul.
      await chat.repository.addParticipants(
        widget.conversationId,
        picked.map((u) => u.alanyaID).toList(),
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(context.l10n.participantsAdded(picked.length)),
      ));
    } catch (e, st) {
      AppLog.e('GroupDetail', context.l10n.failedToAddParticipants, e, st);
      messenger.showSnackBar(SnackBar(
        content: Text(context.l10n.unableToAddParticipantsTryAgain),
        backgroundColor: errorColor,
      ));
    }
  }

  // ── Gestion des membres et des infos ────────────────────────────
  //
  // Chaque action passe par le repository et ne touche RIEN localement avant
  // la réponse du serveur : appliquer un retrait puis se le voir refuser (rôle
  // perdu entre-temps) ferait croire l'action faite. Le gating vient de
  // group_permissions.dart, mais c'est le serveur qui décide vraiment.

  ChatProvider get _chat => context.read<ChatProvider>();

  /// Exécute une mutation en affichant l'erreur serveur telle quelle.
  Future<void> _runGroupAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = context.colors.error;
    final echecLabel = context.l10n.groupUpdateFailed;
    try {
      await action();
      if (!mounted || successMessage == null) return;
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e, st) {
      AppLog.e('GroupDetail', 'action de groupe échouée', e, st);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(echecLabel),
        backgroundColor: errorColor,
      ));
    }
  }

  Future<void> _changeGroupPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;

    final api = Provider.of<TalkyApiClient>(context, listen: false);
    await _runGroupAction(
      () async {
        // Deux temps, comme à la création : l'upload rend une URL, que la
        // route de groupe enregistre. Le serveur ne reçoit jamais le binaire.
        final res = await api.uploadImage(File(x.path));
        final url = (res['url'] as String?)?.trim();
        if (url == null || url.isEmpty) {
          throw Exception('upload sans URL');
        }
        await _chat.repository
            .updateGroupInfo(widget.conversationId, groupPhoto: url);
      },
      successMessage: context.l10n.groupInfoUpdated,
    );
  }

  Future<void> _renameGroup() async {
    final controller = TextEditingController(text: _group?.groupName ?? '');
    final nom = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.renameGroup),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: ctx.l10n.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.l10n.commonSave),
          ),
        ],
      ),
    );
    if (nom == null || nom.isEmpty || nom == _group?.groupName) return;
    await _runGroupAction(
      () => _chat.repository
          .updateGroupInfo(widget.conversationId, groupName: nom),
      successMessage: context.l10n.groupInfoUpdated,
    );
  }

  Future<void> _editDescription() async {
    final controller = TextEditingController(text: _group?.description ?? '');
    final desc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.groupDescription),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 512,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration:
              InputDecoration(hintText: ctx.l10n.groupDescriptionHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.l10n.commonSave),
          ),
        ],
      ),
    );
    if (desc == null || desc == (_group?.description ?? '')) return;
    await _runGroupAction(
      () => _chat.repository
          .updateGroupInfo(widget.conversationId, description: desc),
      successMessage: context.l10n.groupInfoUpdated,
    );
  }

  Future<void> _removeMember(Participant membre) async {
    final nom = membre.nom.isNotEmpty ? membre.nom : membre.user.pseudo;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.removeFromGroup),
        content: Text(ctx.l10n.removeMemberConfirm(nom)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.removeMedia,
                style: TextStyle(color: ctx.colors.error)),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    await _runGroupAction(
      () => _chat.repository
          .removeParticipant(widget.conversationId, membre.alanyaID),
      successMessage: context.l10n.removeMemberDone(nom),
    );
  }

  Future<void> _setRole(Participant membre, int role) async {
    await _runGroupAction(
      () => _chat.repository
          .setParticipantRole(widget.conversationId, membre.alanyaID, role),
      successMessage: context.l10n.groupInfoUpdated,
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.leaveGroup),
        content: Text(
          // Le propriétaire n'est pas bloqué — il serait prisonnier de son
          // groupe — mais on lui dit ce qui va se passer : le serveur confie
          // la propriété au membre restant le plus ancien.
          (_group?.iAmOwner ?? false)
              ? '${context.l10n.youWillNoLongerSeeThis}\n\n'
                  '${context.l10n.ownerMustTransferOnLeave}'
              : context.l10n.youWillNoLongerSeeThis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.leave,
                style: TextStyle(color: context.colors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    try {
      final chat = Provider.of<ChatProvider>(context, listen: false);
      // Le repository ne supprime en local qu'après un aller-retour réussi :
      // si le serveur refuse, la conversation doit rester visible.
      _leaving = true;
      await chat.repository.leaveGroup(widget.conversationId);
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      _leaving = false;
      AppLog.e('GroupDetail', context.l10n.failedToLeaveGroup, e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.unableToLeaveTheGroupTry),
              backgroundColor: context.colors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ChatProvider>().repository;

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        centerTitle: true,
        title: Text(context.l10n.groupInfo),
        // Appels de groupe audio/vidéo — masqués temporairement, à remettre plus tard.
      ),
      // Le stream Drift est la source unique : il rafraîchit la fiche après
      // chaque mutation (réponse HTTP) ET après chaque trame
      // `conversation:updated` d'un autre appareil, sans rechargement manuel.
      body: StreamBuilder<LocalConversation?>(
        stream: repo.watchConversation(widget.conversationId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const LoadingState();
          }

          final local = snapshot.data;
          if (local == null) {
            // La ligne a disparu du cache : soit je viens d'être retiré
            // (`group:participant:removed` → deleteConversation), soit je viens
            // de partir. On sort de l'écran plutôt que d'afficher une fiche
            // fantôme. Le drapeau évite de rejouer le pop à chaque frame.
            if (!_leaving) {
              _leaving = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(context.l10n.youWereRemovedFromGroup),
                ));
                Navigator.of(context).pop();
              });
            }
            return const LoadingState();
          }

          final group = _fromLocal(local);
          _group = group;

          final myId = context.read<AuthProvider>().currentUser?.alanyaID ?? 0;
          final peutEditer =
              canEditInfo(group.myRole, group.onlyAdminsCanEditInfo);
          final peutAjouter =
              canAddParticipants(group.myRole, group.onlyAdminsCanAddMembers);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
            children: [
              _Header(
                // La conversation streamée fait foi : sans ça, le titre
                // resterait figé sur l'argument de navigation après un
                // renommage.
                groupName: group.groupName ?? widget.groupName,
                groupAvatar: widget.groupAvatar,
                groupPhoto: group.groupPhoto,
                memberCount: group.participants.length,
                canEdit: peutEditer,
                onRename: _renameGroup,
                onChangePhoto: _changeGroupPhoto,
              ),
              AppSpacing.vGapLg,
              _DescriptionCard(
                description: group.description,
                canEdit: peutEditer,
                onEdit: _editDescription,
              ),
              AppSpacing.vGapLg,
              _MediaCard(
                conversationId: widget.conversationId,
                conversationName: group.groupName ?? widget.groupName,
              ),
              AppSpacing.vGapLg,
              _MembersCard(
                participants: sortParticipantsForDisplay(group.participants),
                myId: myId,
                myRole: group.myRole,
                onAddParticipants: peutAjouter ? _addParticipants : null,
                onRemove: _removeMember,
                onSetRole: _setRole,
              ),
              if (canChangeSettings(group.myRole)) ...[
                AppSpacing.vGapLg,
                _SettingsCard(
                  onlyAdminsCanSend: group.onlyAdminsCanSend,
                  onlyAdminsCanEditInfo: group.onlyAdminsCanEditInfo,
                  hideHistoryForNewMembers: group.hideHistoryForNewMembers,
                  onlyAdminsCanAddMembers: group.onlyAdminsCanAddMembers,
                  onChanged: (send, edit, hideHistory, addMembers) =>
                      _runGroupAction(
                    () => _chat.repository.updateGroupSettings(
                      widget.conversationId,
                      onlyAdminsCanSend: send,
                      onlyAdminsCanEditInfo: edit,
                      hideHistoryForNewMembers: hideHistory,
                      onlyAdminsCanAddMembers: addMembers,
                    ),
                  ),
                ),
              ],
              AppSpacing.vGapLg,
              _Card(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ConversationMuteListTile(
                      conversationId: widget.conversationId,
                      conversationName: group.groupName ?? widget.groupName,
                    ),
                    // C'est ce qui rend enfin effectif le flag `mentionsOnly`,
                    // qu'aucun appelant ne passait : la colonne serveur se
                    // comportait jusqu'ici comme une sourdine totale.
                    SwitchListTile(
                      value: group.mentionsOnly,
                      onChanged: (v) => _runGroupAction(
                        () => _chat.repository
                            .setMentionsOnly(widget.conversationId, v),
                      ),
                      title: Text(context.l10n.mentionsOnlyLabel,
                          style: context.text.titleSmall),
                      subtitle: Text(context.l10n.mentionsOnlySubtitle,
                          style: context.text.bodySmall),
                    ),
                  ],
                ),
              ),
              AppSpacing.vGapLg,
              _DangerCard(onLeave: _leaveGroup),
            ],
          );
        },
      ),
    );
  }
}

// ── CARD CONTAINER ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card(
      {required this.child,
      this.padding = const EdgeInsets.all(AppSpacing.lg)});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        // En sombre, `surface` est plus foncé que `surfaceMuted` (fond page) :
        // on élève la carte pour garder le contraste carte / fond.
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

// ── HEADER ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String groupName;
  final String? groupAvatar;
  final String? groupPhoto;
  final int memberCount;
  final bool canEdit;
  final VoidCallback onRename;
  final VoidCallback onChangePhoto;

  const _Header({
    required this.groupName,
    this.groupAvatar,
    this.groupPhoto,
    required this.memberCount,
    required this.canEdit,
    required this.onRename,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    // La photo streamée d'abord : `groupAvatar` n'est que l'argument de
    // navigation, figé au moment de l'ouverture de l'écran.
    final avatarUrl = groupPhoto ?? groupAvatar;

    return _Card(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxxl, horizontal: AppSpacing.lg),
      child: Column(
        children: [
          // Avatar tappable quand j'ai le droit d'éditer. La pastille rend
          // l'affordance visible : sans elle, rien n'indique qu'on peut
          // toucher la photo.
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: canEdit ? onChangePhoto : null,
                child: AppAvatar(
                  imageUrl: avatarUrl?.isNotEmpty == true ? avatarUrl : null,
                  name: groupName,
                  isGroup: true,
                  size: 120,
                ),
              ),
              if (canEdit)
                GestureDetector(
                  onTap: onChangePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.colors.surface, width: 2),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  groupName,
                  style: context.text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              if (canEdit) ...[
                AppSpacing.hGapSm,
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: AppIconSize.sm,
                  visualDensity: VisualDensity.compact,
                  tooltip: context.l10n.renameGroup,
                  color: context.colors.primary,
                  onPressed: onRename,
                ),
              ],
            ],
          ),
          AppSpacing.vGapSm,
          Text(
            context.l10n.groupMembersCount(memberCount),
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── DESCRIPTION ───────────────────────────────────────────────────────

class _DescriptionCard extends StatelessWidget {
  final String? description;
  final bool canEdit;
  final VoidCallback onEdit;

  const _DescriptionCard({
    required this.description,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final texte = description?.trim() ?? '';
    // Rien à dire et rien à faire : on n'affiche pas une carte vide.
    if (texte.isEmpty && !canEdit) return const SizedBox.shrink();

    return _Card(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(context.l10n.groupDescription,
            style: context.text.titleSmall),
        subtitle: Text(
          texte.isEmpty ? context.l10n.noGroupDescription : texte,
          style: context.text.bodySmall?.copyWith(
            color: texte.isEmpty
                ? context.colors.onSurfaceVariant
                : context.colors.onSurface,
            fontStyle: texte.isEmpty ? FontStyle.italic : null,
          ),
        ),
        trailing: canEdit
            ? Icon(Icons.edit_outlined,
                size: AppIconSize.sm, color: context.colors.primary)
            : null,
        onTap: canEdit ? onEdit : null,
      ),
    );
  }
}

// ── RÉGLAGES DU GROUPE ────────────────────────────────────────────────

/// Les quatre verrous, visibles des seuls administrateurs.
///
/// Ce ne sont que des interrupteurs : le serveur (`groupSendPolicy`,
/// `requireGroupAdmin`, `onlyAdminsCanAddMembers`) fait foi.
class _SettingsCard extends StatelessWidget {
  final bool onlyAdminsCanSend;
  final bool onlyAdminsCanEditInfo;
  final bool hideHistoryForNewMembers;
  final bool onlyAdminsCanAddMembers;
  final void Function(
    bool? send,
    bool? edit,
    bool? hideHistory,
    bool? addMembers,
  ) onChanged;

  const _SettingsCard({
    required this.onlyAdminsCanSend,
    required this.onlyAdminsCanEditInfo,
    required this.hideHistoryForNewMembers,
    required this.onlyAdminsCanAddMembers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                AppSpacing.lg, AppSpacing.xs),
            child: Text(context.l10n.groupSettings,
                style: context.text.titleSmall),
          ),
          SwitchListTile(
            value: onlyAdminsCanSend,
            onChanged: (v) => onChanged(v, null, null, null),
            title: Text(context.l10n.onlyAdminsCanSendLabel,
                style: context.text.bodyMedium),
            subtitle: Text(context.l10n.onlyAdminsCanSendSubtitle,
                style: context.text.bodySmall),
          ),
          SwitchListTile(
            value: onlyAdminsCanEditInfo,
            onChanged: (v) => onChanged(null, v, null, null),
            title: Text(context.l10n.onlyAdminsCanEditInfoLabel,
                style: context.text.bodyMedium),
            subtitle: Text(context.l10n.onlyAdminsCanEditInfoSubtitle,
                style: context.text.bodySmall),
          ),
          SwitchListTile(
            value: hideHistoryForNewMembers,
            onChanged: (v) => onChanged(null, null, v, null),
            title: Text(context.l10n.hideHistoryForNewMembersLabel,
                style: context.text.bodyMedium),
            subtitle: Text(context.l10n.hideHistoryForNewMembersSubtitle,
                style: context.text.bodySmall),
          ),
          SwitchListTile(
            value: onlyAdminsCanAddMembers,
            onChanged: (v) => onChanged(null, null, null, v),
            title: Text(context.l10n.onlyAdminsCanAddMembersLabel,
                style: context.text.bodyMedium),
            subtitle: Text(context.l10n.onlyAdminsCanAddMembersSubtitle,
                style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }
}

// ── MEDIA CARD ────────────────────────────────────────────────────────

class _MediaCard extends StatefulWidget {
  final int conversationId;
  final String conversationName;

  const _MediaCard({
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  StreamSubscription<List<LocalMessage>>? _messagesSub;
  List<LocalMessage> _mediaMessages = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }

  void _init() {
    final chat = context.read<ChatProvider>();
    // Local-first : Drift immédiat, sync réseau en fond.
    _messagesSub =
        chat.watchMessages(widget.conversationId).listen(_onMessages);
    unawaited(chat.repository.syncMessages(widget.conversationId));
  }

  void _onMessages(List<LocalMessage> messages) {
    final media = <LocalMessage>[];
    for (final m in messages) {
      if ((m.type == 1 || m.type == 2 || m.type == 4) &&
          m.mediaUrl != null &&
          m.mediaUrl!.isNotEmpty) {
        media.add(m);
      }
    }
    if (!mounted) return;
    setState(() => _mediaMessages = media.reversed.take(4).toList());
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.mediaLinksAndDocs,
                  style: context.text.titleSmall,
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConversationMediaScreen(
                      conversationId: widget.conversationId,
                      conversationName: widget.conversationName,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.seeAll,
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: context.colors.primary, size: AppIconSize.sm),
                    ],
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vGapLg,
          _mediaMessages.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(
                      context.l10n.noSharedMedia,
                      style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant),
                    ),
                  ),
                )
              : SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaMessages.length,
                    separatorBuilder: (_, __) => AppSpacing.hGapSm,
                    itemBuilder: (context, index) {
                      final msg = _mediaMessages[index];
                      return GestureDetector(
                        onTap: msg.type == 4
                            ? () => _openDoc(msg)
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaViewerScreen(
                                    isVideo: msg.type == 2,
                                    localPath: msg.localMediaPath,
                                    networkUrl: msg.mediaUrl,
                                    title: msg.mediaName,
                                    msgID: msg.msgID,
                                  ),
                                ),
                              ),
                        child: ClipRRect(
                          borderRadius: AppRadius.brSm,
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildThumb(msg),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildThumb(LocalMessage msg) {
    final placeholder = context.colors.surfaceContainerHighest;
    if (msg.type == 4) {
      final style = DocumentFileStyle.fromMessage(
        mediaName: msg.mediaName,
        mediaUrl: msg.mediaUrl,
      );
      return Container(
        color: placeholder,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.color,
              borderRadius: AppRadius.brSm,
            ),
            child: Center(
              child: Text(
                style.extension,
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      );
    }
    if (msg.type == 2) {
      return VideoMessagePreview(
        pendingPath: msg.pendingUploadPath,
        localPath: msg.localMediaPath,
        thumbBase64: msg.mediaThumb,
        durationSeconds: msg.mediaDuration,
        borderRadius: BorderRadius.zero,
        expandToFill: true,
        playIconSize: 22,
        playPadding: 5,
        showDuration: false,
        fallbackColor: placeholder,
      );
    }

    final hasLocal = msg.localMediaPath != null &&
        File(msg.localMediaPath!).existsSync();
    final myId = context.read<ChatProvider>().repository.myId;
    final needsDl = !msg.isViewOnce &&
        msg.senderID != myId &&
        !hasLocal &&
        msg.mediaUrl != null &&
        msg.mediaUrl!.isNotEmpty;

    return ImageMessagePreview(
      localPath: msg.localMediaPath,
      networkUrl: msg.mediaUrl,
      thumbBase64: msg.mediaThumb,
      useBlurredThumb: needsDl,
      borderRadius: BorderRadius.zero,
      expandToFill: true,
      fallbackColor: placeholder,
    );
  }

  Future<void> _openDoc(LocalMessage msg) async {
    String? path = (msg.localMediaPath != null &&
            File(msg.localMediaPath!).existsSync())
        ? msg.localMediaPath
        : null;

    if (path == null) {
      if (msg.mediaUrl == null) return;
      _showLoading();
      final chat = context.read<ChatProvider>();
      final isMine = msg.senderID == chat.repository.myId;
      path = await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl!,
        type: msg.type,
        isMine: isMine,
        isViewOnce: msg.isViewOnce,
        mediaName: msg.mediaName,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } else if (!msg.isViewOnce && msg.msgID != 0) {
      final chat = context.read<ChatProvider>();
      final isMine = msg.senderID == chat.repository.myId;
      await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl ?? '',
        type: msg.type,
        isMine: isMine,
        isViewOnce: false,
        mediaName: msg.mediaName,
        existingLocalPath: path,
      );
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.unableToDownloadTheFile),
              backgroundColor: context.colors.error),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.l10n.cannotOpenFileApp(res.message)),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
          child: CircularProgressIndicator(color: context.colors.primary)),
    );
  }
}

// ── MEMBERS CARD ──────────────────────────────────────────────────────

class _MembersCard extends StatelessWidget {
  final List<Participant> participants;
  final int myId;
  final int myRole;
  final VoidCallback? onAddParticipants;
  final void Function(Participant) onRemove;
  final void Function(Participant, int) onSetRole;

  const _MembersCard({
    required this.participants,
    required this.myId,
    required this.myRole,
    required this.onRemove,
    required this.onSetRole,
    this.onAddParticipants,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg, AppSpacing.xs),
            child: Text(
              context.l10n.membersOnlyCount(participants.length),
              style: context.text.titleSmall,
            ),
          ),
          if (onAddParticipants != null)
            ListTile(
              leading: Container(
                width: AppSizes.avatarMd,
                height: AppSizes.avatarMd,
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_add_alt_1,
                    color: context.colors.primary),
              ),
              title: Text(
                context.l10n.addParticipants,
                style: context.text.titleSmall
                    ?.copyWith(color: context.colors.primary),
              ),
              onTap: onAddParticipants,
            ),
          ...participants.map((p) {
            final member = p.user;
            final isYou = member.alanyaID == myId;
            final nom = member.nom.isNotEmpty ? member.nom : member.pseudo;

            final peutRetirer = canRemove(myRole, p.role, isSelf: isYou);
            final peutChangerRole = canChangeRole(myRole, isSelf: isYou);
            final aDesActions = peutRetirer || peutChangerRole;

            return ListTile(
              leading: AppAvatar(
                imageUrl: hasValidAvatarUrl(member.avatarUrl)
                    ? member.avatarUrl
                    : null,
                name: nom,
                size: AppSizes.avatarMd,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      isYou ? context.l10n.youLabel : nom,
                      style: context.text.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (p.role >= GroupRole.admin) ...[
                    AppSpacing.hGapSm,
                    _RoleBadge(role: p.role),
                  ],
                ],
              ),
              subtitle: (!isYou && member.isOnline)
                  ? Text(
                      context.l10n.online,
                      style: context.text.bodySmall?.copyWith(
                          color: context.semantic.online),
                    )
                  : null,
              // Pas de menu quand il n'y a rien à y mettre : un menu réduit au
              // seul « voir le profil » ferait doublon avec le tap sur la ligne.
              trailing: aDesActions
                  ? PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: context.colors.onSurfaceVariant),
                      onSelected: (value) {
                        switch (value) {
                          case 'promote':
                            onSetRole(p, GroupRole.admin);
                          case 'demote':
                            onSetRole(p, GroupRole.member);
                          case 'remove':
                            onRemove(p);
                        }
                      },
                      itemBuilder: (context) => [
                        if (peutChangerRole && p.role < GroupRole.admin)
                          PopupMenuItem(
                            value: 'promote',
                            child: Text(context.l10n.makeAdmin),
                          ),
                        if (peutChangerRole && p.role == GroupRole.admin)
                          PopupMenuItem(
                            value: 'demote',
                            child: Text(context.l10n.dismissAdmin),
                          ),
                        if (peutRetirer)
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              context.l10n.removeFromGroup,
                              style: TextStyle(color: context.colors.error),
                            ),
                          ),
                      ],
                    )
                  : Icon(Icons.chevron_right,
                      color: context.colors.outlineVariant),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContactDetailScreen(
                    userId: member.alanyaID,
                    initialName: member.nom,
                    initialAvatar: member.avatarUrl,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Puce « Propriétaire » / « Admin » à côté du nom.
class _RoleBadge extends StatelessWidget {
  final int role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final estProprietaire = role == GroupRole.owner;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 1),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer,
        borderRadius: AppRadius.brSm,
      ),
      child: Text(
        estProprietaire ? context.l10n.groupOwner : context.l10n.groupAdmin,
        style: context.text.labelSmall
            ?.copyWith(color: context.colors.onPrimaryContainer),
      ),
    );
  }
}

// ── DANGER CARD ───────────────────────────────────────────────────────

class _DangerCard extends StatelessWidget {
  final VoidCallback onLeave;
  const _DangerCard({required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onLeave,
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.lg + 2),
          child: Row(
            children: [
              Icon(Icons.exit_to_app,
                  color: context.colors.error, size: AppIconSize.md),
              AppSpacing.hGapMd,
              Text(
                context.l10n.leaveGroup2,
                style: context.text.bodyLarge?.copyWith(
                  color: context.colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
