import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Poignée de glissement standard des bottom sheets (barre arrondie en haut).
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Conteneur de contenu de bottom sheet : poignée + padding cohérents.
///
/// Remplace les conteneurs « poignée 36×4 + coins arrondis » recopiés dans
/// `country_picker_sheet.dart`, `add_contact_sheet.dart`, etc.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      0,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    this.showHandle = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) const SheetDragHandle(),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Helper pour présenter un bottom sheet stylé de façon homogène.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useRoot = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRoot,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: builder,
  );
}
