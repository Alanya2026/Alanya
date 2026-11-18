import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_presenter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_log.dart';
import '../../../models/group_invite_models.dart';
import '../../../talky_api_client.dart';
import '../../../widgets/alanya_qr_view.dart';
import '../../../widgets/common/common.dart';

/// Diamètre du médaillon qui déborde le haut de la carte — même valeur que
/// l'écran « Mon code QR », dont cette carte reprend le dessin.
const double _kMedallionSize = 88;

enum _ModePartage { lien, image }

/// Lien et QR code d'invitation d'un groupe.
///
/// La carte est celle de « Mon code QR » (`QrCodeScreen`) : médaillon qui
/// déborde, carte blanche même en sombre, [AlanyaQrView] au centre. Une seule
/// identité visuelle pour tous les QR d'Alanya.
class GroupInviteLinkScreen extends StatefulWidget {
  final int conversationId;
  final String groupName;
  final String? groupPhoto;
  final int memberCount;

  /// Administrateur : peut réinitialiser le lien.
  final bool isAdmin;

  const GroupInviteLinkScreen({
    super.key,
    required this.conversationId,
    required this.groupName,
    this.groupPhoto,
    required this.memberCount,
    required this.isAdmin,
  });

  @override
  State<GroupInviteLinkScreen> createState() => _GroupInviteLinkScreenState();
}

class _GroupInviteLinkScreenState extends State<GroupInviteLinkScreen> {
  final GlobalKey _carteKey = GlobalKey();

  GroupInviteLinkInfo? _lien;
  String? _erreur;
  bool _chargement = true;
  bool _reinitialisation = false;

  TalkyApiClient get _api => Provider.of<TalkyApiClient>(context, listen: false);

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger() async {
    try {
      final lien = await _api.getGroupInviteLink(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _lien = lien;
        _erreur = null;
        _chargement = false;
      });
    } catch (e, st) {
      AppLog.e('GroupInvite', 'Lecture du lien échouée', e, st);
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = (e is TalkyException && e.code == 'GROUP_INVITE_LINK_ADMIN_ONLY')
            ? context.l10n.groupInviteAdminOnly
            : presenterErreur(context.l10n, e, domaine: ErrorDomain.chat);
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────

  String _texteDePartage(GroupInviteLinkInfo lien) =>
      '${context.l10n.groupInviteShareText(widget.groupName)}\n${lien.url}';

  Future<void> _copier() async {
    final lien = _lien;
    if (lien == null) return;
    await Clipboard.setData(ClipboardData(text: lien.url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.groupInviteCopied)));
  }

  /// Deux partages distincts, pour la même raison que « Mon code QR » : la
  /// plupart des messageries ignorent le texte dès qu'il y a une image.
  Future<void> _partager() async {
    if (_lien == null) return;
    final l10n = context.l10n;
    final choix = await showModalBottomSheet<_ModePartage>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
              child: Text(l10n.groupInviteShareSheetTitle,
                  style: ctx.text.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.groupInviteShareLink),
              subtitle: Text(l10n.groupInviteShareLinkHint),
              onTap: () => Navigator.pop(ctx, _ModePartage.lien),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.groupInviteShareImage),
              subtitle: Text(l10n.groupInviteShareImageHint),
              onTap: () => Navigator.pop(ctx, _ModePartage.image),
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
    if (!mounted || choix == null) return;
    await (choix == _ModePartage.lien ? _partagerLien() : _partagerImage());
  }

  Future<void> _partagerLien() async {
    final lien = _lien;
    if (lien == null) return;
    try {
      await SharePlus.instance.share(ShareParams(
        text: _texteDePartage(lien),
        sharePositionOrigin: _shareOrigin(),
      ));
    } catch (e, st) {
      AppLog.e('GroupInvite', 'Partage du lien échoué', e, st);
    }
  }

  Future<void> _partagerImage() async {
    final lien = _lien;
    if (lien == null) return;
    final texte = _texteDePartage(lien);
    final origine = _shareOrigin();
    final bytes = await _capturerCarte();
    final fichier = bytes == null ? null : await _ecrireFichier(bytes);
    if (!mounted) return;
    // Capture ratée : le lien suffit pour rejoindre.
    if (fichier == null) return _partagerLien();
    try {
      await SharePlus.instance.share(ShareParams(
        text: texte,
        files: [XFile(fichier.path)],
        sharePositionOrigin: origine,
      ));
    } catch (e, st) {
      AppLog.e('GroupInvite', 'Partage de l\'image échoué', e, st);
    }
  }

  /// `pixelRatio` 3 : l'image doit rester scannable une fois agrandie.
  Future<Uint8List?> _capturerCarte() async {
    try {
      final boundary = _carteKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e, st) {
      AppLog.e('GroupInvite', 'Capture de la carte échouée', e, st);
      return null;
    }
  }

  Future<File?> _ecrireFichier(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/alanya-invitation-groupe.png');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e, st) {
      AppLog.e('GroupInvite', 'Écriture du fichier temporaire échouée', e, st);
      return null;
    }
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Contrairement au code contact (10 minutes), le lien de groupe est
  /// permanent et peut être imprimé : la réinitialisation se confirme.
  Future<void> _reinitialiser() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.restart_alt, color: ctx.colors.error),
        title: Text(l10n.groupInviteResetTitle),
        content: Text(l10n.groupInviteResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.colors.error,
              foregroundColor: ctx.colors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.groupInviteReset),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _reinitialisation = true);
    try {
      final lien = await _api.resetGroupInviteLink(widget.conversationId);
      if (!mounted) return;
      setState(() => _lien = lien);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.groupInviteResetDone),
        action: SnackBarAction(label: l10n.groupInviteCopy, onPressed: _copier),
      ));
    } catch (e, st) {
      AppLog.e('GroupInvite', 'Réinitialisation échouée', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(presenterErreur(l10n, e, domaine: ErrorDomain.chat)),
      ));
    } finally {
      if (mounted) setState(() => _reinitialisation = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.groupInviteLinkTitle),
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (_chargement) return const LoadingState();
    final erreur = _erreur;
    if (erreur != null) {
      return Padding(
        padding: AppSpacing.screenH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link_off,
                size: AppIconSize.xl, color: context.colors.onSurfaceVariant),
            AppSpacing.vGapLg,
            Text(erreur,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
            AppSpacing.vGapXl,
            OutlinedButton(
              onPressed: () {
                setState(() => _chargement = true);
                unawaited(_charger());
              },
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    final l10n = context.l10n;
    final lien = _lien!;
    final cote = math.min(260.0, MediaQuery.sizeOf(context).width - 96);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.xxxl, AppSpacing.lg, AppSpacing.xxl),
      children: [
        RepaintBoundary(
          key: _carteKey,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: _kMedallionSize / 2),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                    _kMedallionSize / 2 + AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
                decoration: BoxDecoration(
                  // Blanche même en sombre : un QR sur fond foncé se scanne mal.
                  color: AppColors.white,
                  borderRadius: AppRadius.brMd,
                  boxShadow: AppShadows.subtle,
                ),
                child: Column(
                  children: [
                    Text(
                      widget.groupName,
                      textAlign: TextAlign.center,
                      style: context.text.titleLarge
                          ?.copyWith(color: AppColors.textPrimary),
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      l10n.groupMembersCount(widget.memberCount),
                      style: context.text.bodyMedium?.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    AppSpacing.vGapXl,
                    AlanyaQrView(payload: lien.url, size: cote),
                    AppSpacing.vGapMd,
                    if (lien.approveNewMembers) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.brandContainer,
                          borderRadius: AppRadius.brPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.how_to_reg_outlined,
                                size: 16, color: AppColors.brandPrimaryDark),
                            AppSpacing.hGapXs,
                            Flexible(
                              child: Text(
                                l10n.approveNewMembersLabel,
                                style: context.text.labelMedium?.copyWith(
                                    color: AppColors.brandPrimaryDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.vGapMd,
                    ],
                    Text(
                      l10n.groupInviteScanHint,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: AppAvatar(
                  imageUrl: (widget.groupPhoto ?? '').isNotEmpty
                      ? widget.groupPhoto
                      : null,
                  name: widget.groupName,
                  isGroup: true,
                  size: _kMedallionSize - AppSpacing.sm,
                  backgroundColor: AppColors.brandContainer,
                  foregroundColor: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vGapLg,
        // Le lien en clair, copiable d'un geste.
        Material(
          color: context.colors.surface,
          borderRadius: AppRadius.brMd,
          child: InkWell(
            borderRadius: AppRadius.brMd,
            onTap: _copier,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lien.url.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.groupInviteCopy,
                    icon: Icon(Icons.copy_rounded, color: context.colors.primary),
                    onPressed: _copier,
                  ),
                ],
              ),
            ),
          ),
        ),
        AppSpacing.vGapXl,
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _partager,
                icon: const Icon(Icons.ios_share, size: AppIconSize.sm),
                label: Text(l10n.qrMyCodeShare),
              ),
            ),
            if (widget.isAdmin) ...[
              AppSpacing.hGapMd,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reinitialisation ? null : _reinitialiser,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.error),
                  icon: _reinitialisation
                      ? SizedBox(
                          width: AppIconSize.sm,
                          height: AppIconSize.sm,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.colors.error),
                        )
                      : const Icon(Icons.restart_alt, size: AppIconSize.sm),
                  label: Text(l10n.groupInviteReset),
                ),
              ),
            ],
          ],
        ),
        AppSpacing.vGapLg,
        Text(
          l10n.groupInviteTrustNote,
          textAlign: TextAlign.center,
          style: context.text.bodySmall
              ?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
