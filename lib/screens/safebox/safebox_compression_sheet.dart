//  La question posée à chaque dépôt de photos ou de vidéos (conception,
//  section 04) : qualité d'origine, cochée par défaut, ou compressé. Les deux
//  tailles sont affichées avant de choisir.

import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../widgets/common/app_bottom_sheet.dart';

/// Rend `(compresser, retenir)`, ou null si l'inscrit renonce.
Future<({bool compress, bool remember})?> showSafeboxCompressionSheet(
  BuildContext context, {
  required int originalBytes,
  required int compressedBytes,
}) =>
    showAppBottomSheet<({bool compress, bool remember})>(
      context: context,
      builder: (_) => _FeuilleCompression(original: originalBytes, compresse: compressedBytes),
    );

class _FeuilleCompression extends StatefulWidget {
  const _FeuilleCompression({required this.original, required this.compresse});
  final int original;
  final int compresse;

  @override
  State<_FeuilleCompression> createState() => _FeuilleCompressionState();
}

class _FeuilleCompressionState extends State<_FeuilleCompression> {
  bool _compresser = false; // qualité d'origine par défaut (décision du 15/10/2026)
  bool _retenir = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gain = widget.original - widget.compresse;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.safeboxCompressTitle, style: context.text.titleMedium),
            AppSpacing.vGapMd,
            RadioGroup<bool>(
              groupValue: _compresser,
              onChanged: (v) => setState(() => _compresser = v ?? false),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: false,
                    title: Text(l10n.safeboxCompressOriginal(formatBytes(widget.original, l10n))),
                    subtitle: Text(l10n.safeboxCompressOriginalHint),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<bool>(
                    value: true,
                    title: Text(l10n.safeboxCompressReduced(formatBytes(widget.compresse, l10n))),
                    subtitle: Text(l10n.safeboxCompressReducedHint(formatBytes(gain > 0 ? gain : 0, l10n))),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            CheckboxListTile(
              value: _retenir,
              onChanged: (v) => setState(() => _retenir = v ?? false),
              title: Text(l10n.safeboxCompressRemember),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            AppSpacing.vGapSm,
            FilledButton(
              onPressed: () => Navigator.pop(context, (compress: _compresser, remember: _retenir)),
              child: Text(l10n.safeboxSend),
            ),
          ],
        ),
      ),
    );
  }
}
