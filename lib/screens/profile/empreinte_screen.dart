import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/services/documents_sensibles/empreinte_saisie.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../talky_api_client.dart';

/// VÉRIFIER UNE EMPREINTE (reprise d'Alanya Work ; plan :
/// PLAN-DOCUMENTS-SENSIBLES.md).
///
/// On saisit ou colle l'empreinte numérique écrite sur une copie signée d'un
/// document sensible ; l'écran dit qui l'a fait sortir, quand, depuis quel
/// appareil, et qui avait envoyé le document. Le serveur ne répond qu'à qui
/// pouvait voir ce document : pour tout autre, l'empreinte est « inconnue ».
class EmpreinteScreen extends StatefulWidget {
  const EmpreinteScreen({super.key});

  @override
  State<EmpreinteScreen> createState() => _EmpreinteScreenState();
}

class _EmpreinteScreenState extends State<EmpreinteScreen> {
  final _champ = TextEditingController();
  bool _enCours = false;
  String? _erreur;
  Map<String, dynamic>? _resultat;

  static const _chasseFixe = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 0.5,
  );

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  Future<void> _coller() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text;
    if (t == null) return;
    _champ.value = FormateurEmpreinte().formatEditUpdate(
      _champ.value,
      TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      ),
    );
  }

  Future<void> _rechercher() async {
    final l10n = context.l10n;
    final code = Empreinte.pourServeur(_champ.text);
    if (code == null) {
      setState(() {
        _erreur = l10n.fingerprintInvalid;
        _resultat = null;
      });
      return;
    }
    final api = context.read<TalkyApiClient>();
    setState(() {
      _enCours = true;
      _erreur = null;
      _resultat = null;
    });
    try {
      final r = await api.verifierEmpreinte(code);
      if (mounted) setState(() => _resultat = r);
    } on TalkyException catch (e) {
      if (mounted) {
        setState(() => _erreur = e.statusCode == 404
            ? l10n.fingerprintUnknown
            : e.statusCode == 422
                ? l10n.fingerprintInvalid
                : l10n.fingerprintLookupFailed);
      }
    } catch (_) {
      if (mounted) setState(() => _erreur = l10n.fingerprintLookupFailed);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  String _personne(Object? p) {
    if (p is! Map) return context.l10n.fingerprintUnknownValue;
    final numero = AlanyaPhoneFormatter.formatDisplay('${p['alanyaId'] ?? ''}');
    final nom = (p['nom'] as String?)?.trim() ?? '';
    if (nom.isEmpty) return numero.isEmpty ? context.l10n.fingerprintUnknownValue : numero;
    return numero.isEmpty ? nom : '$nom · $numero';
  }

  String _geste(String? g) => switch (g) {
        'TELECHARGEMENT' => context.l10n.fingerprintActionDownload,
        'PARTAGE' => context.l10n.fingerprintActionShare,
        'TRANSFERT' => context.l10n.fingerprintActionForward,
        _ => g ?? context.l10n.fingerprintUnknownValue,
      };

  String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return context.l10n.fingerprintUnknownValue;
    String deux(int n) => n.toString().padLeft(2, '0');
    return '${deux(d.day)}/${deux(d.month)}/${d.year} ${deux(d.hour)}:${deux(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = _resultat;
    final discret = context.colors.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fingerprintCheckTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(l10n.fingerprintCheckIntro,
              style: context.text.bodyMedium?.copyWith(color: discret)),
          AppSpacing.vGapLg,
          TextField(
            controller: _champ,
            inputFormatters: [FormateurEmpreinte()],
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            style: _chasseFixe.copyWith(fontSize: 17),
            // Huit blocs de quatre, plus sept espaces.
            maxLines: 2,
            minLines: 1,
            onChanged: (_) {
              if (_erreur != null) setState(() => _erreur = null);
            },
            onSubmitted: (_) => _rechercher(),
            decoration: InputDecoration(
              labelText: l10n.fingerprintField,
              hintText: 'XXXX XXXX XXXX XXXX XXXX XXXX XXXX XXXX',
              hintStyle: _chasseFixe.copyWith(fontSize: 15, color: discret),
              errorText: _erreur,
              errorMaxLines: 3,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: l10n.fingerprintPaste,
                icon: const Icon(Icons.content_paste),
                onPressed: _coller,
              ),
            ),
          ),
          AppSpacing.vGapLg,
          FilledButton.icon(
            onPressed: _enCours ? null : _rechercher,
            icon: _enCours
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(l10n.fingerprintSearch),
          ),
          if (r != null) ...[
            AppSpacing.vGapXl,
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined,
                            color: context.colors.primary),
                        AppSpacing.hGapSm,
                        Expanded(
                          child: Text(l10n.fingerprintResult,
                              style: context.text.titleMedium),
                        ),
                      ],
                    ),
                    AppSpacing.vGapMd,
                    _ligne(l10n.fingerprintField,
                        Empreinte.enBlocs('${r['empreinte'] ?? ''}'),
                        chasseFixe: true),
                    _ligne(l10n.fingerprintBy, _personne(r['utilisateur'])),
                    _ligne(l10n.fingerprintAction, _geste(r['geste'] as String?)),
                    _ligne(l10n.fingerprintDate, _date(r['date'] as String?)),
                    _ligne(l10n.fingerprintDevice,
                        (r['appareil'] as String?) ?? l10n.fingerprintUnknownValue),
                    _ligne(l10n.fingerprintSender, _personne(r['expediteur'])),
                    if ((r['document'] as Map?)?['nom'] is String)
                      _ligne(l10n.fingerprintDocument,
                          (r['document'] as Map)['nom'] as String),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ligne(String titre, String valeur, {bool chasseFixe = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre,
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant)),
          const SizedBox(height: 2),
          SelectableText(
            valeur,
            style: chasseFixe
                ? _chasseFixe.copyWith(fontSize: 15)
                : context.text.bodyMedium,
          ),
        ],
      ),
    );
  }
}
