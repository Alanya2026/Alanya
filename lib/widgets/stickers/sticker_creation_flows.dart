import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/db/app_database.dart';
import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/stickers/sticker_creation_repository.dart';
import '../../core/services/stickers/sticker_image_check.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_bottom_sheet.dart';
import 'sticker_image.dart';

/// Parcours communs de la création de stickers (V1b) : confidentialité, nom
/// d'un pack, choix d'un pack, signalement. Utilisés par « Mes créations » et
/// par la fiche d'un sticker reçu.

/// Clé SharedPreferences : l'écran de confidentialité a été lu une fois.
const String kStickerPrivacyAckKey = 'stickers_privacy_ack';

/// Valeur renvoyée par [pickStickerPack] pour « Nouveau pack ».
const int kPickNewStickerPack = -1;

/// Présente une erreur de création : un refus d'image local (format, taille,
/// transparence) en clair ; tout le reste passe par `afficherErreur`
/// (`STICKER_QUOTA_EXCEEDED`, `STICKER_PACK_LIMIT`, `RATE_LIMITED`…).
void showStickerCreationError(BuildContext context, Object error) {
  if (!context.mounted) return;
  if (error is StickerImageRejected) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(stickerImageIssueText(context.l10n, error.issue))),
    );
    return;
  }
  afficherErreur(context, error, domaine: ErrorDomain.stickers);
}

String stickerImageIssueText(AppLocalizations l10n, StickerImageIssue issue) {
  switch (issue) {
    case StickerImageIssue.format:
      return l10n.stickerImageFormat;
    case StickerImageIssue.tooBig:
      return l10n.stickerImageTooBig;
    case StickerImageIssue.size:
      return l10n.stickerImageSize;
    case StickerImageIssue.noAlpha:
      return l10n.stickerImageNoAlpha;
    case StickerImageIssue.animated:
      return l10n.stickerImageAnimated;
    case StickerImageIssue.inputTooBig:
      return l10n.stickerImageInputTooBig;
  }
}

/// Choix de l'utilisateur devant l'aperçu d'un sticker.
enum StickerPreviewChoice { cancel, edit, add }

/// Confirmation avant l'envoi : aperçu de l'image **adaptée** (PNG 512×512)
/// sur un damier qui rend la transparence visible. « Ajouter » envoie
/// l'image telle quelle (le chemin « sans modifier ») ; « Modifier » ouvre
/// l'éditeur (si [canEdit]).
Future<StickerPreviewChoice> confirmStickerPreview(
  BuildContext context,
  Uint8List png, {
  bool canEdit = true,
}) async {
  final choice = await showDialog<StickerPreviewChoice>(
    context: context,
    builder: (ctx) {
      final l10n = ctx.l10n;
      return AlertDialog(
        title: Text(l10n.stickerPreviewTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 220,
                height: 220,
                child: CustomPaint(
                  key: const ValueKey('sticker-checkerboard'),
                  painter: _CheckerPainter(
                    ctx.colors.surfaceContainerHighest,
                    ctx.colors.surface,
                  ),
                  child: Image.memory(
                    png,
                    key: const ValueKey('sticker-preview-image'),
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      color: ctx.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              l10n.stickerPreviewHint,
              textAlign: TextAlign.center,
              style: ctx.text.bodySmall?.copyWith(
                color: ctx.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, StickerPreviewChoice.cancel),
            child: Text(l10n.commonCancel),
          ),
          if (canEdit)
            OutlinedButton(
              key: const ValueKey('sticker-preview-edit'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(AppSizes.minTapTarget, AppSizes.buttonHeight),
              ),
              onPressed: () => Navigator.pop(ctx, StickerPreviewChoice.edit),
              child: Text(l10n.stickerPreviewEdit),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(AppSizes.minTapTarget, AppSizes.buttonHeight),
            ),
            onPressed: () => Navigator.pop(ctx, StickerPreviewChoice.add),
            child: Text(l10n.stickerPreviewAdd),
          ),
        ],
      );
    },
  );
  return choice ?? StickerPreviewChoice.cancel;
}

/// Damier à deux teintes (pas de couleur en dur : elles viennent du thème).
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter(this.a, this.b);
  final Color a;
  final Color b;

  static const double _cell = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var y = 0; y * _cell < size.height; y++) {
      for (var x = 0; x * _cell < size.width; x++) {
        paint.color = (x + y).isEven ? a : b;
        canvas.drawRect(
          Rect.fromLTWH(x * _cell, y * _cell, _cell, _cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter old) => old.a != a || old.b != b;
}

/// Écran de confidentialité : « Un sticker envoyé peut être vu par ses
/// destinataires. » Montré avant la première création, puis mémorisé.
/// `false` si l'utilisateur renonce.
Future<bool> ensureStickerPrivacyAck(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(kStickerPrivacyAckKey) == true) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final l10n = ctx.l10n;
      return AlertDialog(
        icon: Icon(Icons.visibility_outlined, color: ctx.colors.primary),
        title: Text(l10n.stickerPrivacyTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.stickerPrivacyBody, style: ctx.text.titleSmall),
            AppSpacing.vGapSm,
            Text(
              l10n.stickerPrivacyDetail,
              style: ctx.text.bodyMedium?.copyWith(
                color: ctx.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.stickerPrivacyConfirm),
          ),
        ],
      );
    },
  );
  if (ok != true) return false;
  await prefs.setBool(kStickerPrivacyAckKey, true);
  return true;
}

/// Demande le nom d'un pack (60 caractères au plus, comme le serveur).
/// [forCreation] rappelle la confidentialité sous le champ.
Future<String?> promptStickerPackName(
  BuildContext context, {
  String? initial,
  bool forCreation = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _NameDialog(initial: initial, forCreation: forCreation),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.initial, required this.forCreation});
  final String? initial;
  final bool forCreation;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial ?? '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(
        widget.forCreation ? l10n.stickerNewPack : l10n.stickerRename,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _c,
            autofocus: true,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.stickerPackNameLabel,
              hintText: l10n.stickerDefaultPackName,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.forCreation)
            Text(
              l10n.stickerPrivacyBody,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.forCreation ? l10n.create : l10n.commonSave),
        ),
      ],
    );
  }
}

/// Création d'un pack : confidentialité (première fois), nom, création côté
/// serveur. Renvoie l'identifiant du pack, ou `null` (renoncement ou refus,
/// déjà présenté à l'utilisateur).
Future<int?> createStickerPackFlow(
  BuildContext context,
  StickerCreationRepository repo,
) async {
  if (!await ensureStickerPrivacyAck(context)) return null;
  if (!context.mounted) return null;
  final name = await promptStickerPackName(context, forCreation: true);
  if (name == null || !context.mounted) return null;
  try {
    return await repo.createPack(name);
  } catch (e) {
    if (context.mounted) showStickerCreationError(context, e);
    return null;
  }
}

/// Choix du pack de destination d'un sticker : un de mes packs (hors pleins),
/// ou [kPickNewStickerPack]. `null` si l'utilisateur ferme la feuille.
Future<int?> pickStickerPack(
  BuildContext context,
  StickerCreationRepository repo,
) {
  return showAppBottomSheet<int>(
    context: context,
    builder: (ctx) => AppBottomSheet(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: _PackPicker(repo: repo),
    ),
  );
}

class _PackPicker extends StatelessWidget {
  const _PackPicker({required this.repo});
  final StickerCreationRepository repo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return StreamBuilder<List<LocalStickerPack>>(
      stream: repo.watchCreated(),
      builder: (context, snap) {
        final packs = snap.data ?? const <LocalStickerPack>[];
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  l10n.stickerChoosePack,
                  style: context.text.titleMedium,
                ),
              ),
              for (final p in packs)
                ListTile(
                  enabled: p.stickerCount < kMaxStickersPerPack,
                  leading: SizedBox(
                    width: 40,
                    height: 40,
                    child: p.coverUrl == null
                        ? const Icon(Icons.emoji_emotions_outlined)
                        : StickerImage(
                            url: p.coverUrl!,
                            emoji: '',
                            size: 40,
                            showRemovedLabel: false,
                            semanticLabel: p.name,
                          ),
                  ),
                  title: Text(p.name),
                  trailing: Text(
                    l10n.stickerCreatedCount(
                      p.stickerCount,
                      kMaxStickersPerPack,
                    ),
                    style: context.text.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, p.packId),
                ),
              ListTile(
                leading: Icon(Icons.add_circle_outline, color: colors.primary),
                title: Text(l10n.stickerNewPack),
                onTap: () => Navigator.pop(context, kPickNewStickerPack),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Feuille de signalement : choisit un motif. `null` si fermée.
Future<StickerReportReason?> pickStickerReportReason(BuildContext context) {
  return showAppBottomSheet<StickerReportReason>(
    context: context,
    builder: (ctx) {
      final l10n = ctx.l10n;
      final labels = {
        StickerReportReason.inapproprie: l10n.stickerReportInappropriate,
        StickerReportReason.spam: l10n.stickerReportSpam,
        StickerReportReason.droits: l10n.stickerReportRights,
        StickerReportReason.autre: l10n.stickerReportOther,
      };
      return AppBottomSheet(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.stickerReportTitle,
                  style: ctx.text.titleMedium,
                ),
              ),
            ),
            for (final e in labels.entries)
              ListTile(
                leading: Icon(Icons.flag_outlined, color: ctx.colors.primary),
                title: Text(e.value),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      );
    },
  );
}
