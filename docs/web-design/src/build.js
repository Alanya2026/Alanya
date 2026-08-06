#!/usr/bin/env node
/**
 * Assemble chaque fragment de src/screens/ en une page HTML autonome dans dist/.
 * Le CSS et le sprite d'icônes sont inlinés : aucun chemin relatif à résoudre,
 * donc aucun risque de rendu cassé dans le volet Claude Design.
 *
 * Fragment attendu :
 *   <!--@ {"title":"...","group":"...","w":1280,"h":840,"theme":"light"} -->
 *   <markup…>
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'src');
const OUT = path.join(ROOT, 'dist');

const css = fs.readFileSync(path.join(SRC, 'styles.css'), 'utf8');
const sprite = fs.readFileSync(path.join(SRC, 'icons.svg'), 'utf8').trim();

const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function walk(dir, base = '') {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const rel = path.join(base, e.name);
    const abs = path.join(dir, e.name);
    if (e.isDirectory()) return walk(abs, rel);
    return e.name.endsWith('.html') ? [{ abs, rel }] : [];
  });
}

const files = walk(path.join(SRC, 'screens'));
if (!files.length) {
  console.error('Aucun fragment trouvé dans src/screens/');
  process.exit(1);
}

const cards = [];

for (const { abs, rel } of files) {
  const raw = fs.readFileSync(abs, 'utf8');
  const m = raw.match(/^<!--@\s*([\s\S]*?)\s*-->/);
  if (!m) {
    console.error(`✗ ${rel} — en-tête <!--@ {...} --> manquant`);
    process.exit(1);
  }

  let meta;
  try {
    meta = JSON.parse(m[1]);
  } catch (err) {
    console.error(`✗ ${rel} — méta JSON invalide : ${err.message}`);
    process.exit(1);
  }

  for (const key of ['title', 'group']) {
    if (!meta[key]) {
      console.error(`✗ ${rel} — champ méta « ${key} » manquant`);
      process.exit(1);
    }
  }

  const body = raw.slice(m[0].length).trim();
  const theme = meta.theme === 'dark' ? 'dark' : 'light';
  const width = meta.w || 1280;
  const height = meta.h || 860;

  const html = `<!-- @dsCard group="${esc(meta.group)}" -->
<!doctype html>
<html lang="fr" data-theme="${theme}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(meta.title)} — Alanya Web</title>
<style>
${css}
</style>
</head>
<body>
${sprite}
${body}
</body>
</html>
`;

  const dest = path.join(OUT, rel);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, html);

  cards.push({
    name: meta.title,
    path: rel.split(path.sep).join('/'),
    group: meta.group,
    subtitle: meta.subtitle || '',
    viewport: { width, height },
  });
  console.log(`✓ ${rel}  (${meta.group})`);
}

fs.writeFileSync(path.join(OUT, '_cards.json'), JSON.stringify(cards, null, 2));
console.log(`\n${cards.length} maquette(s) → dist/`);
