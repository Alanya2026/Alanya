import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Champ de recherche unifié (décoration cohérente partout).
///
/// Factorise les décorations recopiées dans `animated_search_bar.dart`,
/// `country_picker_sheet.dart`, `add_contact_sheet.dart`, etc.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText = 'Rechercher',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;

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
        hintText: hintText,
        prefixIcon: Icon(Icons.search_rounded,
            color: colors.onSurfaceVariant, size: AppIconSize.md),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded,
                    color: colors.onSurfaceVariant, size: AppIconSize.sm),
                onPressed: onClear,
                tooltip: 'Effacer',
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
    );
  }
}
