import 'export_manifest.dart';

/// Construit la planche-contact `index.html` de l'archive.
///
/// ── Contraintes que ce fichier doit respecter, et pourquoi ──
///
/// **Aucune ressource externe.** Ni police, ni feuille de style, ni script
/// distant. L'archive doit s'ouvrir dans dix ans, sur un ordinateur hors
/// ligne, et rester exactement ce qu'elle était. Une seule dépendance à un
/// serveur tiers, et la planche-contact se dégrade le jour où ce serveur
/// disparaît.
///
/// **Des chemins relatifs.** Les vignettes pointent vers les fichiers voisins
/// dans l'archive, telle qu'elle est décompressée. Rien n'est copié ni
/// dupliqué.
///
/// **Les manquants sont écrits noir sur blanc.** Une archive incomplète qui le
/// dit vaut infiniment mieux qu'une archive incomplète qui se tait.
String buildExportIndexHtml(ExportManifest manifest) {
  final byDay = <String, List<ExportItem>>{};
  for (final item in manifest.items) {
    byDay.putIfAbsent(_dayKey(item.sentAt), () => []).add(item);
  }
  final days = byDay.keys.toList()..sort();

  final buffer = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="fr"><head><meta charset="utf-8">')
    ..writeln('<meta name="viewport" content="width=device-width,'
        'initial-scale=1">')
    ..writeln('<title>${_esc(_title(manifest))}</title>')
    ..writeln('<style>${_css()}</style>')
    ..writeln('</head><body>')
    ..writeln('<header><h1>${_esc(_title(manifest))}</h1>')
    ..writeln('<p class="sub">${_esc(_subtitle(manifest))}</p></header>');

  for (final day in days) {
    final items = byDay[day]!;
    buffer
      ..writeln('<h2>${_esc(_dayLabel(day))}</h2>')
      ..writeln('<div class="grid">');
    for (final item in items) {
      buffer.writeln(_cell(item));
    }
    buffer.writeln('</div>');
  }

  if (manifest.items.isEmpty) {
    buffer.writeln('<p class="empty">Aucun média dans cette période.</p>');
  }

  buffer.write(_missingSection(manifest));
  buffer.writeln('<footer>Archive Alanya · '
      '${_esc(_stamp(manifest.generatedAt))}</footer>');
  buffer.writeln('</body></html>');
  return buffer.toString();
}

String _cell(ExportItem item) {
  final href = _href(item.path);
  final caption = [
    if (item.senderName != null && item.senderName!.isNotEmpty)
      item.senderName!
    else if (item.isMine)
      'Moi',
    _time(item.sentAt),
    _bytes(item.bytes),
  ].where((s) => s.isNotEmpty).join(' · ');

  // Les images et les stickers ont un aperçu : le fichier est dans l'archive,
  // il s'affiche directement. Une vidéo demanderait de décoder une vignette
  // qu'on n'a pas ici, et un document n'en a pas.
  final preview = (item.type == 1 || item.isSticker)
      ? '<img loading="lazy" src="$href" alt="">'
      : '<span class="icon">${_icon(item.type)}</span>';

  return '<figure><a href="$href">$preview</a>'
      '<figcaption>${_esc(caption)}</figcaption></figure>';
}

String _missingSection(ExportManifest manifest) {
  if (manifest.missing.isEmpty) return '';
  final lost =
      manifest.missing.where((m) => m.reason == MissingReason.expired).length;
  final other = manifest.missing.length - lost;

  final buffer = StringBuffer()
    ..writeln('<section class="missing">')
    ..writeln('<h2>Éléments absents de cette archive</h2><ul>');
  if (lost > 0) {
    buffer.writeln('<li><strong>$lost</strong> ne sont plus disponibles : '
        'ils ont dépassé la durée de conservation sur les serveurs'
        '${manifest.retentionDaysKnown != null ? ' '
            '(${manifest.retentionDaysKnown} jours)' : ''}.</li>');
  }
  if (other > 0) {
    buffer.writeln('<li><strong>$other</strong> n\'avaient pas été '
        'téléchargés sur l\'appareil au moment de l\'export.</li>');
  }
  buffer.writeln('</ul><p class="hint">Le détail figure dans '
      '<code>manifest.json</code>.</p></section>');
  return buffer.toString();
}

// ── Rendu ─────────────────────────────────────────────────────────────

String _title(ExportManifest m) {
  final name = m.conversationName;
  return name != null && name.isNotEmpty
      ? 'Mes médias — $name'
      : 'Mes médias';
}

String _subtitle(ExportManifest m) {
  final parts = <String>[];
  if (m.periodFrom != null && m.periodTo != null) {
    parts.add('${_dayLabel(_dayKey(m.periodFrom))} '
        '→ ${_dayLabel(_dayKey(m.periodTo))}');
  }
  parts.add('${m.items.length} élément${m.items.length > 1 ? 's' : ''}');
  parts.add(_bytes(m.totalBytes));
  return parts.join(' · ');
}

String _icon(int type) => switch (type) {
      2 => 'Vidéo',
      3 => 'Audio',
      10 => 'Sticker',
      _ => 'Fichier',
    };

String _dayKey(DateTime? at) {
  if (at == null) return '0000-00-00';
  final d = at.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String _dayLabel(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return key;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _time(DateTime? at) {
  if (at == null) return '';
  final d = at.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

String _stamp(DateTime at) {
  final d = at.toLocal();
  return '${_dayLabel(_dayKey(d))} ${_time(d)}';
}

String _bytes(int b) {
  if (b <= 0) return '';
  const units = ['o', 'Ko', 'Mo', 'Go'];
  var value = b.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final rounded = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}

/// Échappe le texte inséré dans le document.
///
/// **Ce n'est pas une précaution de principe.** Les pseudos viennent d'autres
/// inscrits, donc de l'extérieur. Un nom contenant `<script>` s'exécuterait à
/// l'ouverture de la planche-contact, dans le navigateur de la personne qui
/// consulte son archive — et cette page-là a la particularité d'être ouverte
/// longtemps après, hors de toute protection de l'application.
String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// Encode le chemin pour une URL relative, en gardant les séparateurs.
///
/// Les dossiers de l'archive contiennent des espaces (« Alanya Images ») :
/// sans encodage, le lien casse dans la plupart des navigateurs.
String _href(String archivePath) =>
    archivePath.split('/').map(Uri.encodeComponent).join('/');

String _css() => '''
:root{color-scheme:light dark;--bg:#f6f7fb;--fg:#1a1d23;--muted:#5b6273;
--card:#fff;--line:#e2e5ec;--accent:#3f51b5}
@media(prefers-color-scheme:dark){:root{--bg:#0f1115;--fg:#f2f4f8;
--muted:#aab1c0;--card:#181b21;--line:#3a404c;--accent:#7986cb}}
*{box-sizing:border-box}
body{margin:0;padding:24px;background:var(--bg);color:var(--fg);
font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
header{margin-bottom:24px}
h1{margin:0;font-size:22px}
.sub{margin:4px 0 0;color:var(--muted);font-size:13px}
h2{font-size:13px;text-transform:uppercase;letter-spacing:.05em;
color:var(--muted);margin:28px 0 10px}
.grid{display:grid;gap:10px;
grid-template-columns:repeat(auto-fill,minmax(150px,1fr))}
figure{margin:0;background:var(--card);border:1px solid var(--line);
border-radius:10px;overflow:hidden}
figure a{display:block;aspect-ratio:1;background:var(--bg)}
img{width:100%;height:100%;object-fit:cover;display:block}
.icon{display:grid;place-items:center;height:100%;color:var(--accent);
font-size:13px;font-weight:600}
figcaption{padding:6px 8px;font-size:11px;color:var(--muted);
white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.missing{margin-top:32px;padding:14px 16px;background:var(--card);
border:1px solid var(--line);border-radius:10px}
.missing h2{margin-top:0}
.missing ul{margin:0;padding-left:18px}
.hint{color:var(--muted);font-size:12px;margin-bottom:0}
.empty{color:var(--muted)}
footer{margin-top:32px;color:var(--muted);font-size:12px}
''';
