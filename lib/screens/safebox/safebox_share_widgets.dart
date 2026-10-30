//  Petits éléments communs aux partages du coffre (lot 9, maquettes « Envoi
//  dans les discussions » du 24/10/2026) : la pastille « Coffre-fort », la
//  mosaïque d'un lot, le détail « 35 photos, 6 vidéos, 1 document », le nom
//  d'une discussion, et la carte d'un envoi en cours dans la discussion.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/services/safebox/safebox_upload_manager.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import 'safebox_widgets.dart';

/// « 35 photos, 6 vidéos, 1 document », dans l'ordre des types.
String safeboxFamiliesLabel(AppLocalizations l10n, Map<SafeboxFamily, int> families) => [
      for (final e in families.entries)
        switch (e.key) {
          SafeboxFamily.photos => l10n.safeboxShareFamilyPhotos(e.value),
          SafeboxFamily.videos => l10n.safeboxShareFamilyVideos(e.value),
          SafeboxFamily.audios => l10n.safeboxShareFamilyAudios(e.value),
          SafeboxFamily.documents => l10n.safeboxShareFamilyDocuments(e.value),
        },
    ].join(', ');

/// « 920 Mo · HD » : la taille et le format, s'il n'est pas l'original.
String safeboxSizeAndQuality(AppLocalizations l10n, String size, SafeboxQuality q) => [
      size,
      if (q == SafeboxQuality.hd) l10n.safeboxQualityHd,
      if (q == SafeboxQuality.compressed) l10n.safeboxQualityCompressed,
    ].join(' · ');

/// Mini-images du message décodées une fois.
final Map<String, Uint8List?> _flous = {};
Uint8List? safeboxDecodeBlur(String? b64) {
  if (b64 == null || b64.isEmpty) return null;
  return _flous.putIfAbsent(b64, () {
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  });
}

/// Une mini-image floue, agrandie et adoucie.
class SafeboxBlur extends StatelessWidget {
  const SafeboxBlur({super.key, required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      );
}

/// La pastille « Coffre-fort » posée sur l'image d'une carte.
class SafeboxVaultBadge extends StatelessWidget {
  const SafeboxVaultBadge({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: AppRadius.brPill),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xs + 2, 4, AppSpacing.sm, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(context.l10n.safeboxShareBadge,
                  style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
}

/// Petite étiquette sur une image : « 12:20 », « 1080p », « 4 pages ».
class SafeboxImageLabel extends StatelessWidget {
  const SafeboxImageLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: AppRadius.brSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2, vertical: 2),
          child: Text(text, style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
        ),
      );
}

/// La mosaïque d'un lot : quatre cases côte à côte, la mini-image floue du
/// message d'abord, puis l'aperçu net de l'élément ; « +38 » sur la dernière
/// quand le lot en a plus.
class SafeboxShareMosaic extends StatelessWidget {
  const SafeboxShareMosaic({
    super.key,
    required this.count,
    this.blurs = const [],
    this.items = const [],
    this.height = 112,
  });

  final int count;
  final List<String> blurs;
  final List<SafeboxShareItem> items;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cases = count.clamp(1, 4);
    final reste = count - cases;
    return ClipRRect(
      borderRadius: AppRadius.brMd,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              children: [
                for (var i = 0; i < cases; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(child: _case(context, i, plus: i == cases - 1 && reste > 0 ? reste : 0)),
                ],
              ],
            ),
            const Positioned(left: AppSpacing.sm, top: AppSpacing.sm, child: SafeboxVaultBadge()),
          ],
        ),
      ),
    );
  }

  Widget _case(BuildContext context, int i, {required int plus}) {
    final flou = safeboxDecodeBlur(i < blurs.length ? blurs[i] : null);
    final element = i < items.length ? items[i] : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (flou != null) SafeboxBlur(bytes: flou) else ColoredBox(color: context.semantic.brandContainer),
        if (element != null && element.available && (element.previewUrl != null || flou == null))
          SafeboxFileThumb(file: element.asFile(), fill: true),
        if (plus > 0)
          ColoredBox(
            color: const Color(0xFF0D123E).withValues(alpha: 0.45),
            child: Center(
              child: Text('+$plus',
                  style: context.text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

/// Le nom d'une discussion tel que la liste des discussions l'affiche
/// (« Famille Ngono », ou le contact) ; [fallback] sans la discussion (plus
/// membre, ou hors de l'écran des discussions, dans un test).
class SafeboxConversationName extends StatelessWidget {
  const SafeboxConversationName({
    super.key,
    required this.conversationId,
    required this.builder,
  });

  final int? conversationId;

  /// [isGroup] : null tant que la discussion n'est pas connue.
  final Widget Function(BuildContext context, String? name, bool? isGroup) builder;

  @override
  Widget build(BuildContext context) {
    final id = conversationId;
    ChatProvider? chat;
    try {
      chat = context.read<ChatProvider>();
    } on ProviderNotFoundException {
      chat = null;
    }
    if (id == null || chat == null) return builder(context, null, null);
    int moi;
    try {
      moi = context.read<AuthProvider>().currentUser?.alanyaID ?? 0;
    } on ProviderNotFoundException {
      moi = 0;
    }
    return StreamBuilder<LocalConversation?>(
      stream: chat.repository.watchConversation(id),
      builder: (context, snap) => switch (snap.data) {
        final conv? => builder(context, conversationDisplayName(conv, moi), conv.isGroup),
        null => builder(context, null, null),
      },
    );
  }
}

/// Dans une discussion, chez l'expéditeur : les fichiers du téléphone en
/// route vers le coffre pour cette discussion (maquette « ChatEnvoye »). Les
/// membres ne voient rien avant la fin de l'envoi ; « Annuler » arrête tout.
/// Plusieurs fichiers envoyés ensemble font une seule carte, comme leur
/// futur message.
class SafeboxPendingShares extends StatelessWidget {
  const SafeboxPendingShares({super.key, required this.conversationId});
  final int conversationId;

  @override
  Widget build(BuildContext context) {
    final SafeboxController c;
    try {
      c = context.watch<SafeboxController>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final groupes = <String, List<SafeboxUploadJob>>{};
    for (final j in c.uploads.jobs) {
      if (j.shareConversationId != conversationId || !safeboxShareJobPending(j)) continue;
      groupes.putIfAbsent(j.shareGroup ?? j.id, () => []).add(j);
    }
    if (groupes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [for (final g in groupes.values) _CarteEnvoi(jobs: g)],
    );
  }
}

/// Un envoi vers le coffre pas encore arrivé (ni terminé, ni abandonné).
bool safeboxShareJobPending(SafeboxUploadJob j) =>
    j.state != SafeboxUploadState.completed && j.state != SafeboxUploadState.failed;

class _CarteEnvoi extends StatelessWidget {
  const _CarteEnvoi({required this.jobs});
  final List<SafeboxUploadJob> jobs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.read<SafeboxController>();
    final total = jobs.fold<int>(0, (s, j) => s + j.storedSize);
    final envoye = jobs.fold<int>(0, (s, j) => s + j.sentBytes);
    final progres = total <= 0 ? 0.0 : (envoye / total).clamp(0.0, 1.0);
    final qualite = SafeboxQuality.fromName(jobs.first.quality);
    final titre = jobs.length == 1 ? jobs.first.name : l10n.safeboxShareBatchTitle(jobs.length);
    final etat = jobs.any((j) => j.state == SafeboxUploadState.waitingNetwork)
        ? l10n.safeboxUploadWaitingNetwork
        : safeboxSizeAndQuality(l10n, l10n.safeboxShareUploading((progres * 100).floor()), qualite);
    const blanc = Colors.white;
    final blancDoux = Colors.white.withValues(alpha: 0.85);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxxl, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 284),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(color: blanc, fontWeight: FontWeight.w500)),
                AppSpacing.vGapXs,
                Text(etat, style: context.text.bodySmall?.copyWith(color: blancDoux)),
                AppSpacing.vGapXs,
                ClipRRect(
                  borderRadius: AppRadius.brPill,
                  child: LinearProgressIndicator(
                    value: progres,
                    minHeight: 4,
                    color: blanc,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                AppSpacing.vGapXs,
                Text(l10n.safeboxShareUploadingHint, style: context.text.bodySmall?.copyWith(color: blancDoux)),
                AppSpacing.vGapSm,
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: blanc,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  onPressed: () {
                    for (final j in jobs) {
                      c.uploads.cancel(j.id).ignore();
                    }
                  },
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
