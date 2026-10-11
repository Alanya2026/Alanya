import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'sticker_image.dart';

/// Ouvre la fiche d'un pack partagé par son [token] (lien reçu, code collé).
Future<void> openStickerShare(BuildContext context, String token) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StickerSharePreviewScreen(token: token),
    ),
  );
}

/// Saisie d'un lien ou d'un code de pack reçu hors de l'app (repli quand le
/// lien profond n'a pas ouvert l'app). Le texte collé peut contenir autre
/// chose que le lien : on y cherche le jeton.
Future<void> showOpenStickerLinkDialog(BuildContext context) async {
  final token = await showDialog<String>(
    context: context,
    builder: (_) => const _OpenLinkDialog(),
  );
  if (token != null && context.mounted) {
    await openStickerShare(context, token);
  }
}

class _OpenLinkDialog extends StatefulWidget {
  const _OpenLinkDialog();

  @override
  State<_OpenLinkDialog> createState() => _OpenLinkDialogState();
}

class _OpenLinkDialogState extends State<_OpenLinkDialog> {
  final TextEditingController _c = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t == null || !mounted) return;
    _c.text = t.trim();
    setState(() => _invalid = false);
  }

  void _submit() {
    final token = StickerShareLink.parse(_c.text);
    if (token == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.stickerOpenLink),
      content: TextField(
        controller: _c,
        autofocus: true,
        textInputAction: TextInputAction.go,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          hintText: l10n.stickerOpenLinkHint,
          errorText: _invalid ? l10n.stickerOpenLinkInvalid : null,
          errorMaxLines: 3,
          suffixIcon: IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: l10n.stickerPaste,
            onPressed: _paste,
          ),
        ),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.stickerOpenLink)),
      ],
    );
  }
}

/// Fiche d'un pack partagé : aperçu en lecture seule, puis « Ajouter à mes
/// packs ». Installer = **copier** : le destinataire reçoit un pack privé à
/// lui, qui survit à la révocation du lien.
class StickerSharePreviewScreen extends StatefulWidget {
  const StickerSharePreviewScreen({super.key, required this.token});
  final String token;

  @override
  State<StickerSharePreviewScreen> createState() =>
      _StickerSharePreviewScreenState();
}

class _StickerSharePreviewScreenState extends State<StickerSharePreviewScreen> {
  late final StickerCreationRepository _repo = context
      .read<StickerCreationRepository>();
  StickerSharePreview? _preview;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _addedNow = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _repo.resolveShare(widget.token);
      if (mounted) setState(() => _preview = p);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await _repo.addShared(widget.token);
      if (!mounted) return;
      final l10n = context.l10n;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (r.already) {
        // Déjà là (copie existante ou mon pack) : l'état de la fiche le dit.
        setState(() => _addedNow = true);
      } else {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              [
                l10n.stickerShareDone,
                if (r.ignored > 0) l10n.stickerShareIgnored(r.ignored),
              ].join(' '),
            ),
          ),
        );
        setState(() => _addedNow = true);
      }
    } catch (e) {
      // `STICKER_QUOTA_EXCEEDED`, `STICKER_PACK_LIMIT`, `RATE_LIMITED`,
      // `STICKER_PACK_UNAVAILABLE` : traduits par le présentateur d'erreurs.
      if (mounted) afficherErreur(context, e, domaine: ErrorDomain.stickers);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.stickerSharedPackTitle)),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final err = _error;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_off, size: 48, color: colors.onSurfaceVariant),
              AppSpacing.vGapMd,
              Text(
                presenterErreur(
                  l10n,
                  err,
                  domaine: ErrorDomain.stickers,
                  journaliser: false,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapLg,
              OutlinedButton(onPressed: _load, child: Text(l10n.stickerRetry)),
            ],
          ),
        ),
      );
    }
    final p = _preview!;
    final here = p.alreadyHere || _addedNow;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(p.name, style: context.text.titleLarge),
        AppSpacing.vGapXs,
        Text(
          l10n.stickerPackCount(p.count),
          style: context.text.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (p.description != null) ...[AppSpacing.vGapSm, Text(p.description!)],
        AppSpacing.vGapLg,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
          ),
          itemCount: p.stickers.length,
          itemBuilder: (_, i) {
            final s = p.stickers[i];
            return StickerImage(
              url: s.url,
              thumbUrl: s.thumb,
              emoji: s.emoji,
              size: 72,
              showRemovedLabel: false,
            );
          },
        ),
        AppSpacing.vGapXl,
        if (here)
          Center(
            child: Chip(
              avatar: Icon(
                Icons.check_circle_outline,
                size: 18,
                color: context.semantic.success,
              ),
              label: Text(
                p.mine ? l10n.stickerShareMine : l10n.stickerShareAlreadyAdded,
              ),
            ),
          )
        else ...[
          FilledButton.icon(
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(l10n.stickerShareInstall),
          ),
          AppSpacing.vGapSm,
          Text(
            l10n.stickerShareCopyInfo,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
