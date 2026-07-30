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
    this.onNote,
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

  /// Enregistre la note contextuelle (« rencontré au salon de Douala »).
  /// Retourne vrai en cas de succès. Null — ou contact déjà présent — masque
  /// le champ : la note appartient au moment de l'ajout.
  final Future<bool> Function(String note)? onNote;

  /// Délai avant disparition automatique. `null` la désactive : présentée en
  /// feuille modale, la carte est le seul contenu à l'écran et s'évanouir
  /// toute seule sous les yeux de l'utilisateur passerait pour un bug.
  final Duration? duree;

  @override
  State<QrScanResultCard> createState() => _QrScanResultCardState();
}

class _QrScanResultCardState extends State<QrScanResultCard>
    with SingleTickerProviderStateMixin {
  Timer? _minuteur;

  final TextEditingController _noteCtrl = TextEditingController();
  bool _noteEnCours = false;
  bool _noteEnvoyee = false;

  /// Éclosion de l'étoile « contact préféré ». Une seule impulsion avec
  /// dépassement : répétée, elle deviendrait une alerte au lieu d'une
  /// confirmation.
  late final AnimationController _etoile = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    final duree = widget.duree;
    if (duree != null) {
      _minuteur = Timer(duree, () {
        if (mounted) widget.onDismissed();
      });
    }
    // Rien n'a été ajouté quand la personne était déjà un contact : animer
    // l'étoile féliciterait l'utilisateur pour un geste qui n'a pas eu lieu.
    if (widget.alreadyContact) {
      _etoile.value = 1;
    } else {
      _etoile.forward();
    }
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _noteCtrl.dispose();
    _etoile.dispose();
    super.dispose();
  }

  /// Écrire prend plus de six secondes : dès que l'utilisateur touche le
  /// champ, la carte cesse de s'effacer toute seule.
  void _gelerDisparition() {
    _minuteur?.cancel();
    _minuteur = null;
  }

  Future<void> _envoyerNote() async {
    final onNote = widget.onNote;
    final texte = _noteCtrl.text.trim();
    if (onNote == null || texte.isEmpty || _noteEnCours) return;
    _gelerDisparition();
    setState(() => _noteEnCours = true);
    final ok = await onNote(texte);
    if (!mounted) return;
    setState(() {
      _noteEnCours = false;
      _noteEnvoyee = ok;
    });
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
              _avatarEtoile(nom),
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
          if (!widget.alreadyContact && widget.onNote != null) ...[
            AppSpacing.vGapMd,
            if (_noteEnvoyee)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      size: AppIconSize.sm, color: AppColors.success),
                  AppSpacing.hGapXs,
                  Text(
                    l10n.qrNoteSaved,
                    style: context.text.bodySmall
                        ?.copyWith(color: AppColors.success),
                  ),
                ],
              )
            else
              TextField(
                controller: _noteCtrl,
                enabled: !_noteEnCours,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                onTap: _gelerDisparition,
                onChanged: (_) => _gelerDisparition(),
                onSubmitted: (_) => _envoyerNote(),
                style: context.text.bodyMedium,
                decoration: InputDecoration(
                  hintText: l10n.qrNoteFieldHint,
                  counterText: '',
                  isDense: true,
                  prefixIcon: const Icon(Icons.sticky_note_2_outlined,
                      size: AppIconSize.sm),
                  suffixIcon: _noteEnCours
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, size: AppIconSize.sm),
                          onPressed: _envoyerNote,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.brSm,
                    borderSide: BorderSide(color: context.colors.outline),
                  ),
                ),
              ),
          ],
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

  /// Avatar surmonté de l'étoile des contacts préférés. L'étoile dit « ajouté
  /// aux préférés » sans texte, et son éclosion apprend à l'utilisateur où vit
  /// ce statut — la même étoile que sur la fiche du contact.
  Widget _avatarEtoile(String nom) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AppAvatar(
            imageUrl:
                widget.user.avatarUrl.isNotEmpty ? widget.user.avatarUrl : null,
            name: nom,
            size: 44,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _etoile,
                curve: Curves.easeOutBack,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  // Le liseré reprend le fond de la carte : sans lui l'étoile
                  // se confond avec les avatars clairs.
                  color: context.colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  size: 14,
                  // Même étoile ambre que la fiche du contact : c'est ce
                  // rappel qui fait le lien entre les deux écrans.
                  color: context.semantic.warning,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
