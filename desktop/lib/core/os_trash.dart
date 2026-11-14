// La corbeille de l'ordinateur : « Retirer de l'ordinateur après la
// sauvegarde » y envoie les photos et vidéos, d'où l'inscrit peut les
// récupérer tant qu'il ne la vide pas. JAMAIS de suppression définitive :
// si la corbeille n'est pas utilisable, le fichier reste où il est.
//
//  - Linux : `gio trash` (GLib, présent avec GTK, dont l'application dépend).
//  - Windows : la Corbeille, par Microsoft.VisualBasic.FileIO depuis
//    PowerShell, une seule fois pour tout un lot.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Envoie ces fichiers à la corbeille de l'ordinateur ; rend ceux qui y sont
/// partis (ceux qui n'existent plus à leur place).
Future<Set<String>> moveToComputerTrash(List<String> paths) async {
  if (paths.isEmpty) return const {};
  try {
    if (Platform.isLinux) {
      for (var i = 0; i < paths.length; i += 50) {
        final lot = paths.sublist(i, i + 50 > paths.length ? paths.length : i + 50);
        final r = await Process.run('gio', ['trash', '--', ...lot]);
        if (r.exitCode != 0) debugPrint('[Corbeille] gio : ${r.stderr}');
      }
    } else if (Platform.isWindows) {
      final liste = File('${Directory.systemTemp.path}\\alanya_corbeille_${DateTime.now().microsecondsSinceEpoch}.txt');
      await liste.writeAsString(paths.join('\r\n'), encoding: utf8);
      final chemin = liste.path.replaceAll("'", "''");
      final script = "\$ErrorActionPreference='Continue'; "
          'Add-Type -AssemblyName Microsoft.VisualBasic; '
          "Get-Content -LiteralPath '$chemin' -Encoding UTF8 | ForEach-Object { "
          "try { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(\$_, 'OnlyErrorDialogs', 'SendToRecycleBin') } catch {} }";
      try {
        final r = await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);
        if (r.exitCode != 0) debugPrint('[Corbeille] PowerShell : ${r.stderr}');
      } finally {
        try {
          await liste.delete();
        } catch (_) {}
      }
    } else {
      return const {};
    }
  } catch (e) {
    debugPrint('[Corbeille] impossible : $e');
  }
  return {
    for (final p in paths)
      if (!await File(p).exists()) p,
  };
}
