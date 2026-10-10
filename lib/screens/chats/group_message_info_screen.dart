import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/chat/conversation_merge.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../models/message_receipts.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/app_avatar.dart';

/// « Infos du message » d'un de MES messages de groupe : qui l'a lu, qui l'a
/// reçu sans le lire, qui ne l'a pas encore reçu (maquette « C · Barre et
/// relances » retenue le 10/10/2026).
///
/// Les doubles coches bleues restent allumées dès le premier lecteur ; c'est
/// ici que l'expéditeur voit le détail, membre par membre.
class GroupMessageInfoScreen extends StatefulWidget {
  const GroupMessageInfoScreen({
    super.key,
    required this.message,
    required this.conversationId,
  });

  final LocalMessage message;
  final int conversationId;

  @override
  State<GroupMessageInfoScreen> createState() => _GroupMessageInfoScreenState();
}

enum _Panneau { delivered, pending }

class _GroupMessageInfoScreenState extends State<GroupMessageInfoScreen> {
  static const _lecteursVisibles = 5;

  late final TalkyApiClient _api;
  MessageReceipts? _data;
  bool _loading = true;
  bool _error = false;
  bool _tousLesLecteurs = false;
  _Panneau? _ouvert = _Panneau.pending;
  Timer? _rafraichissement;

  @override
  void initState() {
    super.initState();
    _api = context.read<TalkyApiClient>();
    _api.onSocketEvent(SocketEvents.messageStatus, _onStatus);
    unawaited(_load());
  }

  @override
  void dispose() {
    _rafraichissement?.cancel();
    _api.removeSocketListener(SocketEvents.messageStatus, _onStatus);
    super.dispose();
  }

  /// Un membre vient de recevoir ou de lire : on relit, sans clignoter.
  void _onStatus(dynamic data) {
    if (data is! Map) return;
    final conv = int.tryParse('${data['conversationID']}') ?? 0;
    if (conv != widget.conversationId) return;
    _rafraichissement?.cancel();
    _rafraichissement = Timer(const Duration(milliseconds: 800), () {
      unawaited(_load(silencieux: true));
    });
  }

  Future<void> _load({bool silencieux = false}) async {
    if (!silencieux && mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final json = await _api.getMessageReceipts(widget.message.msgID);
      if (!mounted) return;
      setState(() {
        _data = MessageReceipts.fromJson(json);
        _loading = false;
        _error = false;
      });
    } catch (e) {
      debugPrint('[GroupMessageInfo] chargement: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Un rafraîchissement silencieux raté garde l'affichage précédent.
        _error = _data == null;
      });
    }
  }

  String _heure(DateTime? at) => at == null
      ? ''
      : formatReceiptTime(at, DateTime.now(), yesterday: context.l10n.yesterday);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.receiptsTitle)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildEntete(context),
            if (_loading && _data == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xxxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error)
              _buildErreur(context)
            else if (_data != null)
              _buildCartes(context, _data!),
          ],
        ),
      ),
    );
  }

  // ── En-tête : mon message, puis le résumé ──

  Widget _buildEntete(BuildContext context) {
    final colors = context.colors;
    final m = widget.message;
    final apercu = m.type == 0
        ? (m.content ?? '')
        : ConversationMerge.previewForMedia(m.type, m.content, m.mediaName,
            isViewOnce: m.isViewOnce);
    final envoye = m.sendAt.toLocal();
    final quand = _heure(envoye);
    final memeJour = DateUtils.isSameDay(envoye, DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 290),
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    apercu,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.onPrimary,
                      height: 1.4,
                    ),
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    memeJour ? '${context.l10n.today} $quand' : quand,
                    style: context.text.labelSmall?.copyWith(
                      color: colors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_data != null) ...[
            AppSpacing.vGapLg,
            _buildResume(context, _data!),
          ],
        ],
      ),
    );
  }

  Widget _buildResume(BuildContext context, MessageReceipts r) {
    final colors = context.colors;
    final lu = context.semantic.info;
    final recu = Color.lerp(colors.primary, colors.surface, 0.45)!;
    final piste = colors.outlineVariant;

    Color teinte(String kind) => switch (kind) {
          'read' => lu,
          'delivered' => recu,
          _ => piste,
        };

    final segments = receiptBarSegments(r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: context.l10n.receiptsReadBy(r.readCount)),
            const TextSpan(text: ' '),
            TextSpan(
              text: context.l10n.receiptsOutOf(r.total),
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: colors.onSurfaceVariant,
              ),
            ),
          ]),
          style: context.text.headlineSmall,
        ),
        AppSpacing.vGapMd,
        Semantics(
          label: context.l10n.receiptsBarLabel(
            r.readCount,
            r.deliveredCount - r.readCount,
            r.pendingCount,
          ),
          child: ExcludeSemantics(
            child: SizedBox(
              height: 10,
              child: segments.isEmpty
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: piste,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )
                  : Row(
                      children: [
                        for (var i = 0; i < segments.length; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Expanded(
                            flex: segments[i].flex,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: teinte(segments[i].kind),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
        AppSpacing.vGapMd,
        Wrap(
          spacing: AppSpacing.lg,
          children: [
            Text(context.l10n.receiptsDeliveredBy(r.deliveredCount),
                style: context.text.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
            Text(context.l10n.receiptsPendingCount(r.pendingCount),
                style: context.text.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  // ── Cartes : lecteurs, puis reçus et en attente, repliables ──

  Widget _buildCartes(BuildContext context, MessageReceipts r) {
    final lecteurs = _tousLesLecteurs
        ? r.read
        : r.read.take(_lecteursVisibles).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Carte(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 18, color: context.semantic.info),
                      AppSpacing.hGapSm,
                      Text(
                        context.l10n.receiptsReadSection,
                        style: context.text.labelLarge
                            ?.copyWith(color: context.colors.primary),
                      ),
                    ],
                  ),
                ),
                if (r.read.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
                    child: Text(
                      context.l10n.receiptsNoReaders,
                      style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant),
                    ),
                  )
                else
                  for (final m in lecteurs) _Ligne(membre: m, heure: _heure(m.at)),
                if (!_tousLesLecteurs && r.read.length > _lecteursVisibles)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: TextButton(
                        onPressed: () => setState(() => _tousLesLecteurs = true),
                        child: Text(context.l10n.receiptsShowAllReaders(r.readCount)),
                      ),
                    ),
                  ),
                AppSpacing.vGapXs,
              ],
            ),
          ),
          if (r.delivered.isNotEmpty) ...[
            AppSpacing.vGapMd,
            _CarteRepliable(
              titre: context.l10n.receiptsDeliveredNotRead,
              membres: r.delivered,
              ouverte: _ouvert == _Panneau.delivered,
              heure: _heure,
              onToggle: () => setState(() => _ouvert =
                  _ouvert == _Panneau.delivered ? null : _Panneau.delivered),
            ),
          ],
          if (r.pending.isNotEmpty) ...[
            AppSpacing.vGapMd,
            _CarteRepliable(
              titre: context.l10n.receiptsNotDelivered,
              membres: r.pending,
              ouverte: _ouvert == _Panneau.pending,
              heure: _heure,
              onToggle: () => setState(() => _ouvert =
                  _ouvert == _Panneau.pending ? null : _Panneau.pending),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErreur(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Text(
            context.l10n.receiptsLoadError,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.vGapMd,
          FilledButton.tonal(
            onPressed: _load,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.membre, required this.heure});

  final ReceiptMember membre;
  final String heure;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            AppAvatar(
              imageUrl: membre.avatar,
              name: membre.displayName,
              size: 34,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(
                membre.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge,
              ),
            ),
            if (heure.isNotEmpty)
              Text(
                heure,
                style: context.text.bodySmall
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

class _CarteRepliable extends StatelessWidget {
  const _CarteRepliable({
    required this.titre,
    required this.membres,
    required this.ouverte,
    required this.heure,
    required this.onToggle,
  });

  final String titre;
  final List<ReceiptMember> membres;
  final bool ouverte;
  final String Function(DateTime?) heure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pile = membres.take(3).toList();
    const taille = 30.0;
    const recouvrement = 8.0;

    return _Carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: ouverte,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 10),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: SizedBox(
                          width: taille + (pile.length - 1) * (taille - recouvrement),
                          height: taille,
                          child: Stack(
                            children: [
                              for (var i = 0; i < pile.length; i++)
                                Positioned(
                                  left: i * (taille - recouvrement),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colors.surface, width: 2),
                                    ),
                                    child: AppAvatar(
                                      imageUrl: pile[i].avatar,
                                      name: pile[i].displayName,
                                      size: taille - 4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titre,
                                style: context.text.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            Text(
                              context.l10n.receiptsMemberCount(membres.length),
                              style: context.text.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: ouverte ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: ouverte
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.outlineVariant)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Column(
                        children: [
                          for (final m in membres) _Ligne(membre: m, heure: heure(m.at)),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
