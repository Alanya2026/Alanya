import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_presenter.dart';
import '../../../core/services/notification_navigation.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_log.dart';
import '../../../models/group_invite_models.dart';
import '../../../talky_api_client.dart';
import '../../../widgets/common/common.dart';

/// Point d'entrée unique d'un lien d'invitation de groupe : lien système, lien
/// touché dans un message, carte d'invitation, QR scanné. Tous mènent ici.
///
/// Rien n'entre dans un groupe sans un appui sur « Rejoindre » (ou « Demander
/// à rejoindre ») : l'aperçu ne modifie rien côté serveur.
abstract final class GroupInviteFlow {
  /// Ouvre l'aperçu par-dessus l'écran courant. Renvoie le résultat de
  /// l'adhésion (null si la feuille est fermée sans rejoindre).
  ///
  /// [openChat] : ouvrir la discussion une fois membre. L'appelant qui doit
  /// d'abord se retirer (le scanner, dont la caméra tournerait sous la
  /// discussion) passe `false` et appelle [openConversation] lui-même.
  static Future<GroupJoinResult?> open(BuildContext context, String token,
      {GroupInvitePreview? preview, bool openChat = true}) {
    return openWith(Navigator.of(context, rootNavigator: true), token,
        preview: preview, openChat: openChat);
  }

  /// Variante sans `BuildContext` d'écran : liens reçus par le système.
  static Future<GroupJoinResult?> openWith(NavigatorState nav, String token,
      {GroupInvitePreview? preview, bool openChat = true}) async {
    final resultat = await nav.push<GroupJoinResult>(ModalBottomSheetRoute(
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => GroupInvitePreviewSheet(token: token, initial: preview),
    ));
    if (openChat && resultat != null) await openConversation(nav, resultat);
    return resultat;
  }

  /// Ouvre la discussion du groupe que l'on vient de rejoindre.
  static Future<void> openConversation(
      NavigatorState nav, GroupJoinResult resultat) async {
    final id = resultat.conversationId;
    if (!resultat.isMember || id == null || !nav.mounted) return;
    await NotificationNavigation.openConversation(nav.context, {
      'conversationId': '$id',
      'isGroup': '1',
    });
  }
}

class GroupInvitePreviewSheet extends StatefulWidget {
  final String token;
  final GroupInvitePreview? initial;

  const GroupInvitePreviewSheet({super.key, required this.token, this.initial});

  @override
  State<GroupInvitePreviewSheet> createState() => _GroupInvitePreviewSheetState();
}

class _GroupInvitePreviewSheetState extends State<GroupInvitePreviewSheet> {
  GroupInvitePreview? _apercu;
  String? _erreur;
  bool _occupe = false;

  TalkyApiClient get _api => Provider.of<TalkyApiClient>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _apercu = widget.initial;
    if (_apercu == null) unawaited(_charger());
  }

  Future<void> _charger() async {
    try {
      final apercu = await _api.previewGroupInvite(widget.token);
      if (!mounted) return;
      setState(() {
        _apercu = apercu;
        _erreur = null;
      });
    } catch (e, st) {
      AppLog.w('GroupInvite', 'Aperçu du lien échoué', e, st);
      if (!mounted) return;
      setState(() => _erreur = _message(e));
    }
  }

  String _message(Object e) {
    final l10n = context.l10n;
    if (e is TalkyException) {
      switch (e.code) {
        case 'INVITE_LINK_INVALID':
          return l10n.groupInviteInvalid;
        case 'GROUP_REMOVED':
          return l10n.groupInviteRemoved;
        case 'GROUP_FULL':
          return l10n.groupInviteFull;
      }
      if (e.statusCode == 404) return l10n.groupInviteInvalid;
    }
    return presenterErreur(l10n, e, domaine: ErrorDomain.chat);
  }

  Future<void> _rejoindre() async {
    final apercu = _apercu;
    if (apercu == null || _occupe) return;
    setState(() => _occupe = true);
    try {
      final r = await _api.joinGroupByInvite(widget.token);
      if (!mounted) return;
      if (r.isMember) {
        if (r.state == 'joined') {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
              content: Text(context.l10n.groupInviteJoined(apercu.name))));
        }
        Navigator.of(context).pop(r);
        return;
      }
      setState(() => _apercu = apercu.copyWith(state: GroupInviteState.pending));
    } catch (e, st) {
      AppLog.w('GroupInvite', 'Adhésion échouée', e, st);
      if (!mounted) return;
      final code = e is TalkyException ? e.code : null;
      setState(() {
        if (code == 'GROUP_REMOVED') {
          _apercu = apercu.copyWith(state: GroupInviteState.removed);
        } else if (code == 'GROUP_FULL') {
          _apercu = apercu.copyWith(state: GroupInviteState.full);
        } else if (code == 'INVITE_LINK_INVALID') {
          _erreur = _message(e);
        }
      });
      if (code == null) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(_message(e))));
      }
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _annulerDemande() async {
    final apercu = _apercu;
    if (apercu == null || _occupe) return;
    setState(() => _occupe = true);
    try {
      await _api.cancelGroupJoinRequest(widget.token);
      if (!mounted) return;
      setState(() => _apercu = apercu.copyWith(state: GroupInviteState.canJoin));
    } catch (e, st) {
      AppLog.w('GroupInvite', 'Annulation échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(_message(e))));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _contenu(),
      ),
    );
  }

  Widget _contenu() {
    final l10n = context.l10n;
    final erreur = _erreur;
    if (erreur != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off,
              size: AppIconSize.xl, color: context.colors.onSurfaceVariant),
          AppSpacing.vGapLg,
          Text(erreur,
              textAlign: TextAlign.center, style: context.text.bodyLarge),
          AppSpacing.vGapXl,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonClose),
            ),
          ),
        ],
      );
    }

    final a = _apercu;
    if (a == null) {
      return const SizedBox(height: 240, child: LoadingState());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(imageUrl: a.photo, name: a.name, isGroup: true, size: 96),
        AppSpacing.vGapMd,
        Text(a.name,
            textAlign: TextAlign.center, style: context.text.headlineSmall),
        AppSpacing.vGapXs,
        Text(l10n.groupMembersCount(a.memberCount),
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant)),
        if ((a.description ?? '').isNotEmpty) ...[
          AppSpacing.vGapMd,
          Text(a.description!,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium),
        ],
        AppSpacing.vGapLg,
        ..._selonEtat(a),
      ],
    );
  }

  Widget _encart(List<(IconData, String)> lignes, {Color? fond, Color? encre}) {
    final c = encre ?? context.colors.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fond ?? context.colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        children: [
          for (var i = 0; i < lignes.length; i++) ...[
            if (i > 0) AppSpacing.vGapSm,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(lignes[i].$1,
                    size: 18, color: encre ?? context.colors.primary),
                AppSpacing.hGapSm,
                Expanded(
                  child: Text(lignes[i].$2,
                      style: context.text.bodySmall?.copyWith(color: c)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _boutonPrincipal(String texte, VoidCallback? onPressed) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _occupe ? null : onPressed,
          child: _occupe
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(texte),
        ),
      );

  List<Widget> _selonEtat(GroupInvitePreview a) {
    final l10n = context.l10n;
    final fermer = SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.commonClose),
      ),
    );

    switch (a.state) {
      case GroupInviteState.alreadyMember:
        return [
          _encart([(Icons.check_circle_outline, l10n.groupInviteAlreadyMember)]),
          AppSpacing.vGapLg,
          _boutonPrincipal(
            l10n.groupInviteOpenChat,
            () => Navigator.of(context).pop(GroupJoinResult(
                state: 'already_member', conversationId: a.conversationId)),
          ),
          fermer,
        ];
      case GroupInviteState.pending:
        return [
          _encart([(Icons.check, l10n.groupInviteRequestSent)],
              fond: context.semantic.successContainer,
              encre: context.semantic.success),
          AppSpacing.vGapLg,
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.error),
              onPressed: _occupe ? null : _annulerDemande,
              child: Text(l10n.groupInviteCancelRequest),
            ),
          ),
          fermer,
        ];
      case GroupInviteState.removed:
        return [
          _encart([(Icons.block, l10n.groupInviteRemoved)],
              fond: context.colors.errorContainer,
              encre: context.colors.onErrorContainer),
          AppSpacing.vGapLg,
          fermer,
        ];
      case GroupInviteState.full:
        return [
          _encart([(Icons.groups_outlined, l10n.groupInviteFull)]),
          AppSpacing.vGapLg,
          fermer,
        ];
      case GroupInviteState.canJoin:
      case GroupInviteState.unknown:
        return [
          if (a.approval)
            _encart([(Icons.verified_user_outlined, l10n.groupInviteApprovalInfo)])
          else
            _encart([
              if (a.hideHistory) (Icons.schedule, l10n.groupInviteHistoryNote),
              (Icons.person_outline, l10n.groupInviteProfileNote),
            ]),
          AppSpacing.vGapLg,
          _boutonPrincipal(
            a.approval ? l10n.groupInviteAskToJoin : l10n.groupInviteJoin,
            _rejoindre,
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
          ),
        ];
    }
  }
}
