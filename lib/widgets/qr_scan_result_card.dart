import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../talky_models.dart';
import 'common/common.dart';

/// Carte de résultat affichée en bas du scanner après un ajout par code QR.
///
/// Elle remplace le bandeau système, qui n'accepte qu'une seule action : il
/// fallait choisir entre annuler et enchaîner. Ici les deux coexistent, et la
/// caméra reste vivante derrière — on peut ajouter plusieurs personnes à la
/// suite sans ressortir de l'écran.
///
/// Volontairement dépourvue de bouton d'appel : la carte apparaît d'elle-même
/// après un scan, y placer une action bruyante et irréversible à côté
/// d'« Annuler » invite à la faute de doigt. « Voir détails » y donne accès
/// sans ce risque.
class QrScanResultCard extends StatefulWidget {
  const QrScanResultCard({
    super.key,
    required this.user,
    required this.alreadyContact,
    required this.onMessage,
    required this.onDetails,
    required this.onUndo,
    required this.onDismissed,
    this.duree = const Duration(seconds: 6),
  });

  final User user;

  /// La personne était déjà un contact : rien n'a été écrit, donc rien à
  /// annuler — le bouton correspondant disparaît.
  final bool alreadyContact;

  final VoidCallback onMessage;
  final VoidCallback onDetails;
  final VoidCallback onUndo;

  /// Appelé à l'expiration ou à la fermeture manuelle, pour que le scanner
  /// retire la carte et réarme la détection.
  final VoidCallback onDismissed;

  final Duration duree;

  @override
  State<QrScanResultCard> createState() => _QrScanResultCardState();
}

class _QrScanResultCardState extends State<QrScanResultCard> {
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _minuteur = Timer(widget.duree, () {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  /// Toute action de l'utilisateur annule la disparition automatique : partir
  /// vers la conversation pendant que la carte s'efface derrière donnerait
  /// l'impression d'un geste raté.
  void _agir(VoidCallback action) {
    _minuteur?.cancel();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nom = widget.user.nom.trim().isNotEmpty
        ? widget.user.nom.trim()
        : widget.user.pseudo;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brLg,
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppAvatar(
                imageUrl: widget.user.avatarUrl.isNotEmpty
                    ? widget.user.avatarUrl
                    : null,
                name: nom,
                size: 44,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nom,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    Text(
                      widget.alreadyContact
                          ? l10n.qrScanResultAlready
                          : l10n.qrScanResultAdded,
                      style: context.text.bodySmall?.copyWith(
                        color: widget.alreadyContact
                            ? context.colors.onSurfaceVariant
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                iconSize: AppIconSize.sm,
                color: context.colors.onSurfaceVariant,
                onPressed: () => _agir(widget.onDismissed),
              ),
            ],
          ),
          AppSpacing.vGapMd,
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _agir(widget.onMessage),
                  icon: const Icon(Icons.chat_bubble_outline,
                      size: AppIconSize.sm),
                  label: Text(l10n.qrScanActionMessage),
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _agir(widget.onDetails),
                  icon: const Icon(Icons.person_outline, size: AppIconSize.sm),
                  label: Text(
                    l10n.qrScanActionDetails,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          if (!widget.alreadyContact) ...[
            AppSpacing.vGapXs,
            TextButton(
              onPressed: () => _agir(widget.onUndo),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.onSurfaceVariant,
              ),
              child: Text(l10n.qrScanUndo),
            ),
          ],
        ],
      ),
    );
  }
}
