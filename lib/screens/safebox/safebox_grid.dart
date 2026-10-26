//  La grille d'un dossier du coffre (lot 8) : photos et vidéos par jour,
//  albums de tous types (vignette, durée d'une vidéo, nom d'un document ou
//  d'une musique), sélection multiple.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import 'safebox_widgets.dart';

/// Les fichiers groupés par jour de dépôt, du plus récent au plus ancien, dans
/// l'ordre où ils arrivent (le serveur les rend du plus récent au plus ancien).
List<({DateTime day, List<SafeboxFile> files})> safeboxGroupByDay(List<SafeboxFile> files) {
  final groupes = <({DateTime day, List<SafeboxFile> files})>[];
  for (final f in files) {
    final d = (f.createdAt ?? DateTime(1970)).toLocal();
    final jour = DateTime(d.year, d.month, d.day);
    if (groupes.isEmpty || groupes.last.day != jour) {
      groupes.add((day: jour, files: <SafeboxFile>[]));
    }
    groupes.last.files.add(f);
  }
  return groupes;
}

/// « Aujourd'hui », « Hier », « 12 octobre », « 3 mars 2025 ».
String safeboxDayLabel(BuildContext context, DateTime day, {DateTime? now}) {
  final l10n = context.l10n;
  final n = now ?? DateTime.now();
  final aujourdhui = DateTime(n.year, n.month, n.day);
  if (day == aujourdhui) return l10n.safeboxToday;
  if (day == aujourdhui.subtract(const Duration(days: 1))) return l10n.safeboxYesterday;
  final locale = Localizations.localeOf(context).toString();
  return day.year == n.year ? DateFormat.MMMMd(locale).format(day) : DateFormat.yMMMMd(locale).format(day);
}

/// Une case de la grille.
class SafeboxGridTile extends StatelessWidget {
  const SafeboxGridTile({
    super.key,
    required this.file,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final SafeboxFile file;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final media = file.family == SafeboxFamily.photos || file.family == SafeboxFamily.videos;
    final duree = file.family == SafeboxFamily.videos ? file.meta?.durationLabel : null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeboxFileThumb(file: file, fill: true),
          // Document ou musique : son nom sous l'icône.
          if (!media)
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Text(
                file.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(color: context.colors.onSurface),
              ),
            ),
          if (duree != null)
            Positioned(
              left: 4,
              bottom: 4,
              child: _Pastille(child: Text(duree, style: const TextStyle(color: Colors.white, fontSize: 11))),
            ),
          if (file.note != null)
            const Positioned(
              right: 4,
              bottom: 4,
              child: _Pastille(round: true, child: Icon(Icons.mic, size: 12, color: Colors.white)),
            ),
          if (file.lost)
            Positioned(
              left: 4,
              top: 4,
              child: _Pastille(child: Icon(Icons.broken_image_outlined, size: 14, color: context.colors.errorContainer)),
            ),
          if (selecting)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? context.colors.primary : Colors.black26,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
          if (selected)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brSm,
                  border: Border.all(color: context.colors.primary, width: 3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.child, this.round = false});
  final Widget child;
  final bool round;

  @override
  Widget build(BuildContext context) => Container(
        padding: round ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: round ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: round ? null : AppRadius.brSm,
        ),
        child: child,
      );
}
