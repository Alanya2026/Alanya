import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_presenter.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_log.dart';
import '../../../models/group_invite_models.dart';
import '../../../talky_api_client.dart';
import '../../../widgets/common/common.dart';

/// Demandes d'adhésion d'un groupe (administrateurs).
///
/// Tous les admins voient la même liste : l'événement `group:join_requests`
/// la rafraîchit dès qu'un autre admin répond ou qu'une demande arrive, et le
/// serveur fait gagner la première réponse (404 pour la suivante).
class GroupJoinRequestsScreen extends StatefulWidget {
  final int conversationId;
  final String groupName;

  const GroupJoinRequestsScreen({
    super.key,
    required this.conversationId,
    required this.groupName,
  });

  @override
  State<GroupJoinRequestsScreen> createState() => _GroupJoinRequestsScreenState();
}

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> {
  List<GroupJoinRequest> _demandes = const [];
  bool _chargement = true;
  String? _erreur;
  final Set<int> _enCours = {};
  bool _toutEnCours = false;

  late final TalkyApiClient _api = Provider.of<TalkyApiClient>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _api.onSocketEvent('group:join_requests', _onSocket);
    unawaited(_charger());
  }

  @override
  void dispose() {
    _api.removeSocketListener('group:join_requests', _onSocket);
    super.dispose();
  }

  void _onSocket(dynamic data) {
    if (data is! Map) return;
    final id = int.tryParse('${data['conversID']}') ?? 0;
    if (id == widget.conversationId && mounted) unawaited(_charger());
  }

  Future<void> _charger() async {
    try {
      final list = await _api.getGroupJoinRequests(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _demandes = list;
        _erreur = null;
        _chargement = false;
      });
    } catch (e, st) {
      AppLog.e('GroupJoinRequests', 'Lecture des demandes échouée', e, st);
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = presenterErreur(context.l10n, e, domaine: ErrorDomain.chat);
      });
    }
  }

  String _message(Object e) {
    final l10n = context.l10n;
    if (e is TalkyException) {
      if (e.code == 'JOIN_REQUEST_NOT_FOUND') return l10n.groupJoinAlreadyHandled;
      if (e.code == 'GROUP_FULL') return l10n.groupInviteFull;
    }
    return presenterErreur(l10n, e, domaine: ErrorDomain.chat);
  }

  Future<void> _decider(GroupJoinRequest d, {required bool approve}) async {
    if (_enCours.contains(d.alanyaID)) return;
    setState(() => _enCours.add(d.alanyaID));
    try {
      await _api.decideGroupJoinRequest(widget.conversationId, d.alanyaID,
          approve: approve);
      if (!mounted) return;
      setState(() => _demandes = _demandes.where((x) => x.alanyaID != d.alanyaID).toList());
    } catch (e, st) {
      AppLog.w('GroupJoinRequests', 'Décision échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
      unawaited(_charger());
    } finally {
      if (mounted) setState(() => _enCours.remove(d.alanyaID));
    }
  }

  Future<void> _toutApprouver() async {
    if (_toutEnCours) return;
    setState(() => _toutEnCours = true);
    try {
      final r = await _api.approveAllGroupJoinRequests(widget.conversationId);
      if (!mounted) return;
      if (r.full) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.groupInviteFull)));
      }
    } catch (e, st) {
      AppLog.w('GroupJoinRequests', 'Approbation en lot échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
    } finally {
      if (mounted) setState(() => _toutEnCours = false);
      unawaited(_charger());
    }
  }

  String _quand(DateTime? t) {
    if (t == null) return '';
    final loc = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final memeJour = t.year == now.year && t.month == now.month && t.day == now.day;
    return memeJour
        ? loc.formatTimeOfDay(TimeOfDay.fromDateTime(t))
        : loc.formatShortDate(t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.groupJoinRequestsTitle),
        actions: [
          if (_demandes.length > 1)
            TextButton(
              onPressed: _toutEnCours ? null : _toutApprouver,
              child: Text(l10n.groupJoinApproveAll),
            ),
        ],
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    final l10n = context.l10n;
    if (_chargement) return const LoadingState();
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenH,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erreur!, textAlign: TextAlign.center),
              AppSpacing.vGapLg,
              OutlinedButton(
                onPressed: () {
                  setState(() => _chargement = true);
                  unawaited(_charger());
                },
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_demandes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_reg_outlined,
                size: AppIconSize.xl, color: context.colors.onSurfaceVariant),
            AppSpacing.vGapLg,
            Text(l10n.groupJoinRequestsEmpty,
                style: context.text.bodyLarge
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          for (final d in _demandes) _ligne(d),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              l10n.groupJoinRequestsNote,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligne(GroupJoinRequest d) {
    final l10n = context.l10n;
    final occupe = _enCours.contains(d.alanyaID) || _toutEnCours;
    final sousTitre = [
      d.isContact ? l10n.groupJoinInContacts : l10n.groupJoinNotInContacts,
      _quand(d.requestedAt),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Material(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            AppAvatar(imageUrl: d.avatarUrl, name: d.displayName, size: 44),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall),
                  Text(sousTitre,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant)),
                ],
              ),
            ),
            if (occupe)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              IconButton.outlined(
                tooltip: l10n.groupJoinReject,
                icon: const Icon(Icons.close),
                onPressed: () => _decider(d, approve: false),
              ),
              AppSpacing.hGapXs,
              IconButton.filled(
                tooltip: l10n.groupJoinApprove,
                icon: const Icon(Icons.check),
                onPressed: () => _decider(d, approve: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
