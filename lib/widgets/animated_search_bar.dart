import 'package:flutter/material.dart';

import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';

/// Barre de recherche pliable affichée sous l'AppBar.
/// L'écran parent garde la source de vérité (`open`, contrôleur) et bascule
/// l'état via un IconButton(search) dans son AppBar. Quand `open` passe à true,
/// la barre s'anime en hauteur et le focus va automatiquement dans le champ.
class AnimatedSearchBar extends StatefulWidget {
  final bool open;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback onClose;
  final String hintText;
  final Duration duration;

  const AnimatedSearchBar({
    super.key,
    required this.open,
    required this.controller,
    required this.onClose,
    this.onChanged,
    this.hintText = '', // filled by l10n in build if empty — see below
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant AnimatedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      // Demande le focus une fois la barre dépliée pour ouvrir le clavier.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    } else if (!widget.open && oldWidget.open) {
      _focus.unfocus();
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: widget.open
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                onChanged: widget.onChanged,
                textInputAction: TextInputAction.search,
                style: context.text.bodyLarge,
                decoration: InputDecoration(
                  hintText: widget.hintText.isEmpty ? context.l10n.searchEllipsis : widget.hintText,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: context.colors.onSurfaceVariant),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: context.colors.onSurfaceVariant),
                    onPressed: widget.onClose,
                    tooltip: context.l10n.commonClose,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.brPill,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.brPill,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brPill,
                    borderSide: BorderSide(color: context.colors.primary, width: 1.5),
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}
