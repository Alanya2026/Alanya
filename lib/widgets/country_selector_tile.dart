import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/country_flag.dart';
import '../talky_models.dart';
import 'country_picker_sheet.dart';

enum CountrySelectorStyle { formField, settingsRow }

/// Sélecteur de pays réutilisable (inscription, compte).
class CountrySelectorTile extends StatefulWidget {
  CountrySelectorTile({
    super.key,
    required this.countries,
    required this.onChanged,
    this.selected,
    this.label,
    this.required = false,
    this.style = CountrySelectorStyle.formField,
    this.enabled = true,
    this.decoration,
  });

  final List<Pays> countries;
  final Pays? selected;
  final ValueChanged<Pays> onChanged;
  final String? label;
  final bool required;
  final CountrySelectorStyle style;
  final bool enabled;
  final InputDecoration? decoration;

  @override
  State<CountrySelectorTile> createState() => _CountrySelectorTileState();
}

class _CountrySelectorTileState extends State<CountrySelectorTile> {
  late final TextEditingController _displayController;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(text: _labelFor(widget.selected));
  }

  @override
  void didUpdateWidget(CountrySelectorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?.idPays != widget.selected?.idPays) {
      _displayController.text = _labelFor(widget.selected);
    }
  }

  @override
  void dispose() {
    _displayController.dispose();
    super.dispose();
  }

  String _labelFor(Pays? pays) {
    if (pays == null) return '';
    final flag = CountryFlags.flagFor(pays);
    return flag.isNotEmpty ? '$flag ${pays.libelle}' : pays.libelle;
  }

  Future<void> _openPicker() async {
    if (!widget.enabled || widget.countries.isEmpty) return;
    final picked = await CountryPickerSheet.show(
      context,
      countries: widget.countries,
      selectedId: widget.selected?.idPays,
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == CountrySelectorStyle.settingsRow) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? _openPicker : null,
          borderRadius: AppRadius.brSm,
          child: Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: context.semantic.surfaceMuted,
              borderRadius: AppRadius.brSm,
            ),
            child: Row(
              children: [
                Icon(Icons.public,
                    color: context.colors.primary, size: AppIconSize.sm),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (widget.label ?? context.l10n.country),
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        widget.selected == null
                            ? context.l10n.notSet
                            : _labelFor(widget.selected),
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: widget.selected == null
                              ? context.colors.onSurfaceVariant
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.enabled)
                  Icon(Icons.chevron_right,
                      color: context.colors.outlineVariant),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: widget.enabled ? _openPicker : null,
      child: IgnorePointer(
        child: TextField(
          readOnly: true,
          controller: _displayController,
          style: context.text.bodyLarge,
          decoration: widget.decoration ??
              InputDecoration(
                hintText: context.l10n.country,
                prefixIcon: const Icon(Icons.public_outlined),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
        ),
      ),
    );
  }
}
