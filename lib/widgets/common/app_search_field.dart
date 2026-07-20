import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Champ de recherche unifié (décoration cohérente partout).
///
/// Factorise les décorations recopiées dans `animated_search_bar.dart`,
/// `country_picker_sheet.dart`, `add_contact_sheet.dart`, etc.
class AppSearchField extends StatelessWidget {
  AppSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
    this.fillColor,
    this.borderColor,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Couleur de remplissage (sinon celle du thème). Utile pour détacher le
  /// champ d'un fond `surfaceMuted` identique à la valeur par défaut.
  final Color? fillColor;

  /// Bordure au repos (sinon aucune, comme dans le thème). Le focus garde la
  /// bordure primaire du thème.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText ?? context.l10n.commonSearch,
        prefixIcon: Icon(Icons.search_rounded,
            color: colors.onSurfaceVariant, size: AppIconSize.md),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded,
                    color: colors.onSurfaceVariant, size: AppIconSize.sm),
                onPressed: onClear,
                tooltip: context.l10n.clearAction,
              ),
        filled: fillColor != null ? true : null,
        fillColor: fillColor,
        enabledBorder: borderColor == null
            ? null
            : OutlineInputBorder(
                borderRadius: AppRadius.brSm,
                borderSide: BorderSide(color: borderColor!),
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
    );
  }
}
