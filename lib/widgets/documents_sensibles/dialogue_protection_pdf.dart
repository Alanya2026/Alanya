import 'package:flutter/material.dart';

import '../../core/services/documents_sensibles/descripteur_sensible.dart';
import '../../core/theme/app_theme.dart';

/// Ce qu'a choisi l'expéditeur : [protection] nulle = aucune (impression
/// permise, pas de mot de passe — la copie sort simplement signée).
typedef ChoixProtectionPdf = ({ProtectionPdf? protection});

/// LES PERMISSIONS D'UN PDF SENSIBLE, réglées UNE FOIS à l'envoi (reprise
/// d'Alanya Work) : autoriser l'impression ou non, mettre un mot de passe ou
/// non — et alors en saisir deux, ouverture et propriétaire.
///
/// Rend `null` si l'expéditeur renonce : l'envoi n'a pas lieu.
///
/// Elles valent pour les [nombre] PDF sensibles de l'envoi, et s'appliquent
/// à la copie qui SORT d'Alanya (enregistrement) ; dans l'application, le
/// document reste lisible dans la visionneuse protégée.
Future<ChoixProtectionPdf?> demanderProtectionPdf(
  BuildContext context, {
  int nombre = 1,
}) {
  return showDialog<ChoixProtectionPdf>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DialogueProtectionPdf(nombre: nombre),
  );
}

/// Les mots de passe trop courts ne protègent rien : quatre caractères au
/// moins, comme un code.
const longueurMinMotDePassePdf = 4;

class DialogueProtectionPdf extends StatefulWidget {
  const DialogueProtectionPdf({super.key, this.nombre = 1});

  /// Le nombre de PDF sensibles concernés.
  final int nombre;

  @override
  State<DialogueProtectionPdf> createState() => _DialogueProtectionPdfState();
}

class _DialogueProtectionPdfState extends State<DialogueProtectionPdf> {
  final _ouverture = TextEditingController();
  final _proprietaire = TextEditingController();
  bool _imprimer = true;
  bool _motDePasse = false;
  bool _cacheOuverture = true;
  bool _cacheProprietaire = true;
  bool _erreurOuverture = false;
  bool _erreurProprietaire = false;

  @override
  void dispose() {
    _ouverture.dispose();
    _proprietaire.dispose();
    super.dispose();
  }

  void _valider() {
    if (!_motDePasse) {
      Navigator.of(context).pop<ChoixProtectionPdf>((
        protection: _imprimer
            ? null
            // Une restriction de PDF n'existe qu'avec un mot de passe
            // propriétaire : tiré au hasard, personne ne le voit.
            : ProtectionPdf(
                imprimer: false,
                proprietaire: ProtectionPdf.proprietaireAuHasard(),
              ),
      ));
      return;
    }
    // Sans trim : un espace fait partie du mot de passe. Seule règle : la
    // longueur. Les deux PEUVENT être identiques — le lecteur PDF donne alors
    // les droits du propriétaire, impression comprise, à qui ouvre avec lui.
    final o = _ouverture.text;
    final p = _proprietaire.text;
    final eo = o.length < longueurMinMotDePassePdf;
    final ep = p.length < longueurMinMotDePassePdf;
    if (eo || ep) {
      setState(() {
        _erreurOuverture = eo;
        _erreurProprietaire = ep;
      });
      return;
    }
    Navigator.of(context).pop<ChoixProtectionPdf>((
      protection: ProtectionPdf(imprimer: _imprimer, ouverture: o, proprietaire: p),
    ));
  }

  Widget _champ({
    required Key cle,
    required TextEditingController ctrl,
    required String libelle,
    required String aide,
    required bool erreur,
    required bool cache,
    required VoidCallback basculer,
    TextInputAction action = TextInputAction.next,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          key: cle,
          controller: ctrl,
          obscureText: cache,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: action,
          onSubmitted: action == TextInputAction.done ? (_) => _valider() : null,
          decoration: InputDecoration(
            labelText: libelle,
            helperText: aide,
            helperMaxLines: 3,
            errorText: erreur
                ? context.l10n.pdfPasswordTooShort(longueurMinMotDePassePdf)
                : null,
            errorMaxLines: 3,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(cache ? Icons.visibility : Icons.visibility_off),
              onPressed: basculer,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.pdfProtectionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nombre > 1
                  ? l10n.pdfProtectionIntroMany(widget.nombre)
                  : l10n.pdfProtectionIntro,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('pdfp_imprimer'),
              contentPadding: EdgeInsets.zero,
              value: _imprimer,
              onChanged: (v) => setState(() => _imprimer = v),
              title: Text(l10n.pdfProtectionAllowPrint),
              secondary: const Icon(Icons.print_outlined),
            ),
            SwitchListTile(
              key: const Key('pdfp_mot_de_passe'),
              contentPadding: EdgeInsets.zero,
              value: _motDePasse,
              onChanged: (v) => setState(() => _motDePasse = v),
              title: Text(l10n.pdfProtectionPassword),
              subtitle: Text(l10n.pdfProtectionPasswordHelp),
              secondary: const Icon(Icons.password),
            ),
            if (_motDePasse) ...[
              _champ(
                cle: const Key('pdfp_ouverture'),
                ctrl: _ouverture,
                libelle: l10n.pdfOpenPassword,
                aide: l10n.pdfOpenPasswordHelp,
                erreur: _erreurOuverture,
                cache: _cacheOuverture,
                basculer: () => setState(() => _cacheOuverture = !_cacheOuverture),
              ),
              _champ(
                cle: const Key('pdfp_proprietaire'),
                ctrl: _proprietaire,
                libelle: l10n.pdfOwnerPassword,
                aide: l10n.pdfOwnerPasswordHelp,
                erreur: _erreurProprietaire,
                cache: _cacheProprietaire,
                basculer: () =>
                    setState(() => _cacheProprietaire = !_cacheProprietaire),
                action: TextInputAction.done,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('pdfp_valider'),
          onPressed: _valider,
          child: Text(l10n.pdfProtectionSend),
        ),
      ],
    );
  }
}
