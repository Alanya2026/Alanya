import 'package:flutter/material.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/country_flag.dart';
import '../talky_models.dart' show Pays;
import 'common/common.dart';

/// Feuille modale de sélection de pays, avec recherche par nom ou préfixe.
/// Renvoie le [Pays] choisi via Navigator.pop.
class CountryPickerSheet extends StatefulWidget {
  const CountryPickerSheet(
      {super.key, required this.countries, this.selectedId});

  final List<Pays> countries;
  final int? selectedId;

  /// Ouvre la feuille et renvoie le pays sélectionné (ou null si annulé).
  static Future<Pays?> show(
    BuildContext context, {
    required List<Pays> countries,
    int? selectedId,
  }) {
    return showModalBottomSheet<Pays>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CountryPickerSheet(countries: countries, selectedId: selectedId),
    );
  }

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  String _query = '';

  List<Pays> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.countries;
    return widget.countries
        .where((p) =>
            p.libelle.toLowerCase().contains(q) ||
            p.prefix.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.sheetTop,
          ),
          child: Column(
            children: [
              AppSpacing.vGapSm,
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                    AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
                child: AppSearchField(
                  hintText: context.l10n.searchForACountry,
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.public_off,
                        title: context.l10n.noCountryFound,
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final p = _filtered[i];
                          final flag = CountryFlags.flagFor(p);
                          final selected = p.idPays == widget.selectedId;
                          return ListTile(
                            leading: Text(
                              flag.isNotEmpty ? flag : '🌍',
                              style: const TextStyle(fontSize: 26),
                            ),
                            title: Text(p.libelle),
                            subtitle: p.prefix.isNotEmpty
                                ? Text(_formatDialPrefix(p.prefix))
                                : null,
                            trailing: selected
                                ? Icon(Icons.check_circle,
                                    color: context.colors.primary)
                                : null,
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Affiche un seul `+` même si la base stocke déjà `+33`.
String _formatDialPrefix(String prefix) {
  final cleaned = prefix.trim().replaceFirst(RegExp(r'^\++'), '');
  if (cleaned.isEmpty) return '';
  return '+$cleaned';
}
