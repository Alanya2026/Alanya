import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';

/// Explication de la synchronisation d'une sonnerie **importée** entre les
/// appareils d'un même compte.
///
/// Le choix de sonnerie d'une liste suit le compte ; le fichier audio, lui,
/// reste sur l'appareil. Il faut donc l'importer sur chaque appareil — et c'est
/// son CONTENU qui l'identifie, pas son nom : deux fichiers homonymes de
/// contenu différent ne sont pas le même son. C'est exactement ce que ce
/// message doit faire comprendre, sans parler de « hash » à l'utilisateur.
Future<void> showRingtoneSyncInfo(BuildContext context) {
  final l10n = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.devices_rounded),
      title: Text(l10n.ringtoneSyncInfoTitle),
      content: SingleChildScrollView(
        child: Text(
          l10n.ringtoneSyncInfoBody,
          style: ctx.text.bodyMedium?.copyWith(
            color: ctx.colors.onSurfaceVariant,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.commonOk),
        ),
      ],
    ),
  );
}

/// Petit ⓘ posé à côté d'un son importé, qui ouvre [showRingtoneSyncInfo].
class RingtoneSyncInfoButton extends StatelessWidget {
  const RingtoneSyncInfoButton({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.info_outline_rounded,
        color: context.colors.onSurfaceVariant,
        size: size ?? AppIconSize.md,
      ),
      tooltip: context.l10n.ringtoneSyncInfoTooltip,
      onPressed: () => showRingtoneSyncInfo(context),
    );
  }
}
