import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/documents_sensibles/descripteur_sensible.dart';
import '../../core/theme/app_theme.dart';

/// Ce qu'on a déjà montré d'un mot de passe en VUE UNIQUE, par message.
///
/// ⚠️ LOCAL À L'APPAREIL : le serveur ne lit pas le descripteur, il ne peut
/// donc pas compter les vues (et le jour où le descripteur sera chiffré, il ne
/// saura même plus qu'il existe).
class VuesMotDePassePdf {
  VuesMotDePassePdf._();

  static String _cle(String id) => 'pdf_mdp_vu.$id';

  static Future<bool> dejaVu(String id) async =>
      (await SharedPreferences.getInstance()).getBool(_cle(id)) ?? false;

  static Future<void> marquerVu(String id) async =>
      (await SharedPreferences.getInstance()).setBool(_cle(id), true);
}

/// SOUS LE PDF SENSIBLE PROTÉGÉ (reprise d'Alanya Work) :
///
/// * chez l'EXPÉDITEUR, les mots de passe EN CLAIR — il les a choisis, il doit
///   pouvoir les retrouver ;
/// * chez le DESTINATAIRE, le mot de passe d'ouverture en VUE UNIQUE. Le
///   propriétaire ne lui est jamais montré : c'est lui qui lève l'interdiction
///   d'imprimer.
///
/// Et, des deux côtés, si l'impression est interdite, on le dit.
class InfosProtectionPdf extends StatefulWidget {
  const InfosProtectionPdf({
    super.key,
    required this.protection,
    required this.idMessage,
    required this.isMe,
    required this.couleurDiscrete,
  });

  final ProtectionPdf protection;

  /// Ce qui identifie le message sur cet appareil, pour la vue unique.
  final String idMessage;
  final bool isMe;
  final Color couleurDiscrete;

  @override
  State<InfosProtectionPdf> createState() => _InfosProtectionPdfState();
}

class _InfosProtectionPdfState extends State<InfosProtectionPdf> {
  /// `null` tant qu'on ne sait pas encore (lecture des préférences).
  bool? _vu;

  ProtectionPdf get p => widget.protection;

  @override
  void initState() {
    super.initState();
    if (!widget.isMe && p.avecMotDePasse) {
      VuesMotDePassePdf.dejaVu(widget.idMessage).then((v) {
        if (mounted) setState(() => _vu = v);
      });
    }
  }

  Future<void> _voir() async {
    // Marqué AVANT d'être montré : fermer l'application pendant l'affichage
    // ne doit pas offrir une seconde vue.
    await VuesMotDePassePdf.marquerVu(widget.idMessage);
    if (!mounted) return;
    setState(() => _vu = true);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.pdfOpenPassword),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              p.ouverture!,
              key: const Key('pdfp_mdp_revele'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ctx.l10n.pdfPasswordOnceNotice,
              style: ctx.text.bodySmall
                  ?.copyWith(color: ctx.colors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: p.ouverture!)),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(ctx.l10n.pdfPasswordCopy),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.pdfPasswordDone),
          ),
        ],
      ),
    );
  }

  Widget _ligne(IconData icone, Widget texte) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(icone, size: 15, color: widget.couleurDiscrete),
            const SizedBox(width: 6),
            Flexible(child: texte),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final discret = TextStyle(fontSize: 12, color: widget.couleurDiscrete);
    final fort = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      fontFamily: 'monospace',
      color: widget.couleurDiscrete,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!p.imprimer)
          _ligne(Icons.print_disabled_outlined,
              Text(l10n.pdfPrintForbidden, style: discret)),
        if (p.avecMotDePasse && widget.isMe) ...[
          _ligne(
            Icons.lock_open_outlined,
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l10n.pdfOpenPassword} : ', style: discret),
                TextSpan(text: p.ouverture, style: fort),
              ]),
              key: const Key('pdfp_mdp_expediteur'),
            ),
          ),
          _ligne(
            Icons.admin_panel_settings_outlined,
            Text.rich(TextSpan(children: [
              TextSpan(text: '${l10n.pdfOwnerPassword} : ', style: discret),
              TextSpan(text: p.proprietaire, style: fort),
            ])),
          ),
        ],
        if (p.avecMotDePasse && !widget.isMe)
          if (_vu == false)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                key: const Key('pdfp_voir'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _voir,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(l10n.pdfPasswordShowOnce),
              ),
            )
          else if (_vu == true)
            _ligne(Icons.visibility_off_outlined,
                Text(l10n.pdfPasswordAlreadySeen, style: discret)),
      ],
    );
  }
}
