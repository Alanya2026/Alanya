#!/usr/bin/env python3
"""Generate profile/settings HTML mockups with shared design tokens."""

from pathlib import Path

OUT = Path(__file__).parent

SHARED_CSS = r"""
  :root {
    --brand: #3F51B5; --brand-dark: #1A237E; --brand-container: #E8EAF6;
    --error: #EF4444; --error-container: #FDECEC; --success: #1FA363;
    --success-container: #E2F6EC; --warning: #F59E0B; --warning-container: #FDF1DC;
    --bg: #F6F7FB; --surface: #FFFFFF; --surface-muted: #F4F5F8;
    --outline: #E2E5EC; --ink: #1A1D23; --ink-2: #5B6273; --ink-3: #9AA0AE;
    --page-bg: #EEF0F7; --page-panel: #FFFFFF; --page-line: #DDE1EC;
    --page-ink: #23283A; --page-ink-2: #626A82;
    --r-sm: 12px; --r-md: 16px; --r-lg: 20px;
    --s-xs: 4px; --s-sm: 8px; --s-md: 12px; --s-lg: 16px; --s-xl: 20px; --s-xxl: 24px;
    --sans: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    --mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --bg: #0F1115; --surface: #181B21; --surface-muted: #1F232B;
      --outline: #3A404C; --ink: #F2F4F8; --ink-2: #AAB1C0; --ink-3: #6F7787;
      --brand-container: #283593; --error-container: #3A1414;
      --success-container: #143726; --warning-container: #3A2C10;
      --page-bg: #0A0C11; --page-panel: #14171E; --page-line: #262C38;
      --page-ink: #E8EBF2; --page-ink-2: #939BAF;
    }
  }
  :root[data-theme="dark"] {
    --bg: #0F1115; --surface: #181B21; --surface-muted: #1F232B;
    --outline: #3A404C; --ink: #F2F4F8; --ink-2: #AAB1C0; --ink-3: #6F7787;
    --brand-container: #283593; --error-container: #3A1414;
    --success-container: #143726; --warning-container: #3A2C10;
    --page-bg: #0A0C11; --page-panel: #14171E; --page-line: #262C38;
    --page-ink: #E8EBF2; --page-ink-2: #939BAF;
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--page-bg); color: var(--page-ink); font-family: var(--sans); font-size: 15px; line-height: 1.55; }
  .page { max-width: 1180px; margin: 0 auto; padding: clamp(20px,5vw,56px) clamp(16px,4vw,40px) 72px; display: flex; flex-direction: column; gap: 40px; }
  .masthead { display: flex; flex-direction: column; gap: var(--s-md); max-width: 68ch; }
  .eyebrow { font-family: var(--mono); font-size: 11px; letter-spacing: .1em; text-transform: uppercase; color: var(--brand); font-weight: 600; }
  h1 { margin: 0; font-size: clamp(1.5rem,3vw,2rem); font-weight: 700; letter-spacing: -.02em; }
  .lead { margin: 0; color: var(--page-ink-2); max-width: 62ch; }
  .section h2 { margin: 0 0 var(--s-lg); font-size: 13px; font-family: var(--mono); letter-spacing: .08em; text-transform: uppercase; color: var(--page-ink-2); }
  .stage { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: clamp(20px,3vw,36px); align-items: start; }
  .device-block { display: flex; flex-direction: column; gap: var(--s-md); align-items: center; }
  .device-caption { font-family: var(--mono); font-size: 11px; letter-spacing: .08em; text-transform: uppercase; color: var(--page-ink-2); text-align: center; max-width: 32ch; }
  .device { width: 100%; max-width: 340px; background: var(--bg); border: 1px solid var(--outline); border-radius: 30px; padding: 8px; box-shadow: 0 18px 44px rgba(26,35,126,.13), 0 2px 6px rgba(0,0,0,.05); }
  .screen { background: var(--bg); border-radius: 23px; overflow: hidden; display: flex; flex-direction: column; min-height: 620px; color: var(--ink); }
  .appbar { background: var(--surface); padding: 14px var(--s-lg); display: flex; align-items: center; gap: var(--s-md); border-bottom: 1px solid var(--outline); }
  .appbar h3 { margin: 0; font-size: 20px; font-weight: 650; flex: 1; }
  .back { width: 20px; height: 20px; color: var(--brand); flex: none; }
  .body { flex: 1; overflow-y: auto; padding-bottom: var(--s-xxl); }
  .card { margin: var(--s-lg) var(--s-lg) 0; background: var(--surface); border-radius: var(--r-md); box-shadow: 0 1px 3px rgba(0,0,0,.04); overflow: hidden; }
  .profile-header { padding: var(--s-xxl) var(--s-lg); text-align: center; }
  .avatar-lg { width: 96px; height: 96px; border-radius: 50%; background: linear-gradient(135deg,#5C6BC0,#3949AB); color: #fff; font-size: 36px; font-weight: 650; display: grid; place-items: center; margin: 0 auto; position: relative; }
  .avatar-sm { width: 44px; height: 44px; border-radius: 50%; background: linear-gradient(135deg,#5C6BC0,#3949AB); color: #fff; font-size: 16px; font-weight: 650; display: grid; place-items: center; flex: none; }
  .cam-badge { position: absolute; bottom: 0; right: -4px; width: 28px; height: 28px; border-radius: 50%; background: var(--brand); color: #fff; font-size: 14px; display: grid; place-items: center; border: 2px solid var(--surface); }
  .pseudo { color: var(--ink-2); font-size: 15px; margin-top: 4px; }
  .phone-row { display: flex; align-items: center; justify-content: center; gap: 6px; margin-top: 8px; color: var(--brand); font-weight: 500; font-size: 14px; }
  .chip-warn { margin: var(--s-md) var(--s-lg) 0; padding: 10px var(--s-md); background: var(--error-container); border-radius: var(--r-sm); display: flex; align-items: center; gap: var(--s-sm); font-size: 13px; color: var(--error); }
  .chip-info { margin: var(--s-md) var(--s-lg) 0; padding: 10px var(--s-md); background: var(--warning-container); border-radius: var(--r-sm); font-size: 13px; color: var(--ink); }
  .chip-success { margin: var(--s-md) var(--s-lg) 0; padding: 12px var(--s-md); background: var(--success-container); border-radius: var(--r-sm); }
  .score-bar { height: 6px; background: var(--outline); border-radius: 999px; overflow: hidden; margin-top: 8px; }
  .score-fill { height: 100%; background: var(--success); border-radius: 999px; }
  .score-fill.warn { background: var(--warning); }
  .tile { display: flex; align-items: center; gap: var(--s-md); padding: 14px var(--s-lg); border-bottom: 1px solid var(--outline); }
  .tile:last-child { border-bottom: none; }
  .tile-icon { width: 36px; height: 36px; border-radius: 50%; background: var(--surface-muted); display: grid; place-items: center; font-size: 18px; flex: none; }
  .tile-icon.brand { background: var(--brand-container); color: var(--brand); }
  .tile-body { flex: 1; min-width: 0; }
  .tile-title { font-size: 15px; font-weight: 500; }
  .tile-sub { font-size: 12px; color: var(--ink-2); margin-top: 2px; }
  .chev { color: var(--ink-3); font-size: 18px; }
  .group-label { padding: var(--s-lg) var(--s-lg) var(--s-sm); font-size: 12px; font-weight: 600; color: var(--brand); text-transform: uppercase; letter-spacing: .04em; }
  .seg { display: flex; gap: 4px; padding: var(--s-md); background: var(--surface-muted); border-radius: var(--r-sm); margin: 0 var(--s-lg) var(--s-md); }
  .seg-btn { flex: 1; padding: 8px 4px; text-align: center; font-size: 11px; border-radius: 8px; color: var(--ink-2); }
  .seg-btn.on { background: var(--surface); color: var(--brand); font-weight: 600; box-shadow: 0 1px 2px rgba(0,0,0,.08); }
  .switch { width: 44px; height: 26px; border-radius: 999px; background: var(--brand); position: relative; flex: none; }
  .switch.off { background: var(--outline); }
  .switch::after { content: ''; position: absolute; right: 3px; top: 3px; width: 20px; height: 20px; border-radius: 50%; background: #fff; }
  .switch.off::after { right: auto; left: 3px; }
  .contacts-row { display: flex; justify-content: space-evenly; padding: var(--s-lg); }
  .contact-chip { text-align: center; width: 64px; }
  .contact-chip .av { width: 48px; height: 48px; border-radius: 50%; background: var(--brand-container); color: var(--brand); font-weight: 650; display: grid; place-items: center; margin: 0 auto 4px; font-size: 16px; }
  .contact-chip span { font-size: 11px; color: var(--ink-2); }
  .field { margin: var(--s-md) var(--s-lg); }
  .field label { display: block; font-size: 12px; color: var(--ink-2); margin-bottom: 6px; font-weight: 500; }
  .field input, .field textarea { width: 100%; padding: 12px; border: 1px solid var(--outline); border-radius: var(--r-sm); background: var(--surface); color: var(--ink); font-family: inherit; font-size: 15px; }
  .field textarea { min-height: 80px; resize: none; }
  .btn-primary { margin: var(--s-lg); padding: 14px; background: var(--brand); color: #fff; border: none; border-radius: var(--r-sm); font-weight: 600; font-size: 15px; width: calc(100% - 32px); }
  .btn-danger { background: var(--error); }
  .btn-outline { background: transparent; border: 1px solid var(--outline); color: var(--ink); }
  .media-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 2px; padding: var(--s-lg); }
  .media-cell { aspect-ratio: 1; background: var(--surface-muted); border-radius: 4px; }
  .media-cell:nth-child(1) { background: linear-gradient(135deg,#7986CB,#5C6BC0); }
  .media-cell:nth-child(2) { background: linear-gradient(135deg,#4DB6AC,#00897B); }
  .media-cell:nth-child(3) { background: linear-gradient(135deg,#FFB74D,#F57C00); }
  .storage-bar { height: 8px; background: var(--outline); border-radius: 999px; overflow: hidden; display: flex; margin: var(--s-md) 0; }
  .storage-seg { height: 100%; }
  .step-dots { display: flex; justify-content: center; gap: 8px; padding: var(--s-lg); }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--outline); }
  .dot.on { background: var(--brand); width: 24px; border-radius: 999px; }
  .theme-toggle { position: fixed; top: 16px; right: 16px; background: var(--page-panel); border: 1px solid var(--page-line); border-radius: var(--r-sm); padding: 6px 12px; font-size: 12px; font-family: var(--mono); cursor: pointer; color: var(--page-ink-2); z-index: 99; }
  .nav-glass { position: absolute; bottom: 12px; left: 12px; right: 12px; height: 56px; background: rgba(255,255,255,.85); border-radius: 28px; border: 1px solid var(--outline); display: flex; align-items: center; justify-content: space-around; font-size: 10px; color: var(--ink-3); }
  .nav-glass .on { color: var(--brand); font-weight: 600; }
  .screen-rel { position: relative; padding-bottom: 72px; }
"""

SCRIPT = r"""
  function toggleTheme() {
    const r = document.documentElement;
    const c = r.getAttribute('data-theme');
    if (c === 'dark') r.removeAttribute('data-theme');
    else if (c === 'light') r.setAttribute('data-theme', 'dark');
    else r.setAttribute('data-theme', window.matchMedia('(prefers-color-scheme: dark)').matches ? 'light' : 'dark');
  }
"""

def page(title, eyebrow, lead, sections_html):
    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Alanya — {title}</title>
<style>{SHARED_CSS}</style>
</head>
<body>
<button class="theme-toggle" type="button" onclick="toggleTheme()">Thème clair / sombre</button>
<div class="page">
<header class="masthead">
<span class="eyebrow">{eyebrow}</span>
<h1>{title}</h1>
<p class="lead">{lead}</p>
</header>
{sections_html}
<footer style="font-family:var(--mono);font-size:11px;color:var(--page-ink-2);padding-top:var(--s-xl);border-top:1px solid var(--page-line);">
Tokens : app_colors.dart · app_dimens.dart · Maquette Phase 0 — profils &amp; paramètres
</footer>
</div>
<script>{SCRIPT}</script>
</body>
</html>"""

def dual(light_html, dark_label="Mode sombre", light_label="Mode clair"):
    return f"""<section class="section"><h2>{light_label} · {dark_label}</h2><div class="stage">
<div class="device-block"><div class="device"><div class="screen">{light_html}</div></div><p class="device-caption">{light_label}</p></div>
<div class="device-block"><div class="device"><div class="screen" style="background:#0F1115;color:#F2F4F8;">{light_html.replace('var(--surface)', '#181B21').replace('var(--bg)', '#0F1115').replace('var(--surface-muted)', '#1F232B').replace('var(--outline)', '#3A404C').replace('var(--brand-container)', '#283593')}</div></div><p class="device-caption">{dark_label}</p></div>
</div></section>"""

def svg_back():
    return '<svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg>'



def ab(title, back=True):
    b = svg_back() if back else ""
    return f'<div class="appbar">{b}<h3>{title}</h3></div>'

def sw(on=True):
    return f'<div class="switch{"" if on else " off"}"></div>'

def tile(icon, title, sub=None, trail="chev", icls="tile-icon brand"):
    sub_h = f'<div class="tile-sub">{sub}</div>' if sub else ""
    if trail == "chev":
        tr = '<span class="chev">›</span>'
    elif trail == "on":
        tr = sw(True)
    elif trail == "off":
        tr = sw(False)
    else:
        tr = trail
    return (
        f'<div class="tile"><div class="{icls}">{icon}</div>'
        f'<div class="tile-body"><div class="tile-title">{title}</div>{sub_h}</div>{tr}</div>'
    )

def card(*rows):
    return f'<div class="card">{"".join(rows)}</div>'

def group_label(text):
    return f'<div class="group-label">{text}</div>'


MAQUETTES = {}

MAQUETTES['profil-hub.html'] = page(
    'Profil — hub restructuré',
    'Profil · Phase 0',
    'ProfileScreen : en-tête identité, bandeau e-mail, contacts préférés, entrées Mon compte, Paramètres, Mes médias, Déconnexion.',
    dual("""
<div class="appbar"><h3>Profil</h3></div>
<div class="body screen-rel">
<div class="card profile-header">
<div class="avatar-lg">M<div class="cam-badge">📷</div></div>
<div style="font-size:20px;font-weight:650;margin-top:12px;">Marie Kouassi</div>
<div class="pseudo">@marie_k</div>
<div class="phone-row">🪪 +237 6XX XXX XXX <span>QR</span></div>
<div style="font-size:13px;color:var(--ink-2);margin-top:4px;">🇨🇲 Cameroun</div>
</div>
<div class="chip-warn">⚠ Aucun e-mail — récupération impossible ›</div>
<div style="padding:var(--s-lg) var(--s-lg) var(--s-sm);display:flex;justify-content:space-between;align-items:center;">
<span style="font-weight:600;">Contacts préférés</span><span style="color:var(--brand);font-size:13px;">+2 ›</span></div>
<div class="card"><div class="contacts-row">
<div class="contact-chip"><div class="av">A</div><span>Alice</span></div>
<div class="contact-chip"><div class="av">B</div><span>Bob</span></div>
<div class="contact-chip"><div class="av">C</div><span>Claire</span></div>
<div class="contact-chip"><div class="av">D</div><span>David</span></div>
</div></div>
<div class="card" style="margin-top:var(--s-lg);">
<div class="tile"><div class="tile-icon brand">👤</div><div class="tile-body"><div class="tile-title">Mon compte</div><div class="tile-sub">Profil, sécurité, confidentialité, données</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon brand">⚙</div><div class="tile-body"><div class="tile-title">Paramètres</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon brand">🖼</div><div class="tile-body"><div class="tile-title">Mes médias</div><div class="tile-sub">Photos, vidéos, documents</div></div><span class="chev">›</span></div>
</div>
<div class="card" style="margin-top:var(--s-lg);"><div class="tile"><div class="tile-icon" style="background:var(--error-container);color:var(--error);">⎋</div><div class="tile-body"><div class="tile-title" style="color:var(--error);">Déconnexion</div></div><span class="chev">›</span></div></div>
<div class="nav-glass"><span>Chats</span><span>Appels</span><span>Statuts</span><span>Réunions</span><span class="on">Profil</span></div>
</div>
"""))

MAQUETTES['mon-compte-hub.html'] = page(
    'Mon compte — hub',
    'Compte · Phase 0',
    'AccountHubScreen : score de sécurité, raccourcis vers édition profil, confidentialité, sécurité du compte et données personnelles.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Mon compte</h3></div>
<div class="body">
<div class="card" style="margin-top:var(--s-lg);padding:var(--s-lg);">
<div style="display:flex;justify-content:space-between;align-items:center;">
<span style="font-weight:600;">Score de sécurité</span>
<span style="color:var(--warning);font-weight:700;">62 / 100</span>
</div>
<div class="score-bar"><div class="score-fill warn" style="width:62%;"></div></div>
<div style="font-size:12px;color:var(--ink-2);margin-top:8px;">Ajoutez un e-mail et activez la biométrie pour améliorer votre score.</div>
</div>
<div class="group-label">Identité</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">✏</div><div class="tile-body"><div class="tile-title">Modifier le profil</div><div class="tile-sub">Nom, pseudo, bio, photo</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon brand">🖼</div><div class="tile-body"><div class="tile-title">Mes médias</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Protection</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">🔒</div><div class="tile-body"><div class="tile-title">Confidentialité</div><div class="tile-sub">Visibilité, blocage, lectures</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon brand">🛡</div><div class="tile-body"><div class="tile-title">Sécurité du compte</div><div class="tile-sub">Mot de passe, appareils, biométrie</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Données</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">📦</div><div class="tile-body"><div class="tile-title">Données et compte</div><div class="tile-sub">Export RGPD, suppression</div></div><span class="chev">›</span></div>
</div>
</div>
"""))

MAQUETTES['edit-profil-apercu.html'] = page(
    'Modifier le profil — aperçu',
    'Compte · Phase 0',
    'EditProfileScreen : formulaire (nom, pseudo, bio, pays) avec carte d’aperçu « tel que les autres vous voient ».',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Modifier le profil</h3></div>
<div class="body">
<div class="group-label">Aperçu public</div>
<div class="card profile-header" style="padding:var(--s-lg);">
<div class="avatar-lg" style="width:72px;height:72px;font-size:28px;">M</div>
<div style="font-size:17px;font-weight:650;margin-top:8px;">Marie Kouassi</div>
<div class="pseudo">@marie_k</div>
<div style="font-size:13px;color:var(--ink-2);margin-top:8px;line-height:1.4;">Designer UX · Douala · Disponible en message</div>
</div>
<div class="group-label">Informations</div>
<div class="field"><label>Nom affiché</label><input type="text" value="Marie Kouassi"></div>
<div class="field"><label>Pseudo</label><input type="text" value="marie_k"></div>
<div class="field"><label>Bio</label><textarea>Designer UX · Douala · Disponible en message</textarea></div>
<div class="field"><label>Pays</label><input type="text" value="🇨🇲 Cameroun"></div>
<div class="chip-info">ℹ Le pseudo est visible par tous vos contacts.</div>
<button class="btn-primary" type="button">Enregistrer</button>
</div>
"""))

MAQUETTES['mes-medias-profil.html'] = page(
    'Mes médias',
    'Profil · Phase 0',
    'Grille des médias partagés dans les conversations (photos, vidéos, documents) avec filtres et espace utilisé.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Mes médias</h3></div>
<div class="body">
<div class="seg"><div class="seg-btn on">Tout</div><div class="seg-btn">Photos</div><div class="seg-btn">Vidéos</div><div class="seg-btn">Docs</div></div>
<div style="padding:0 var(--s-lg);font-size:12px;color:var(--ink-2);">248 éléments · 1,2 Go</div>
<div class="media-grid">
<div class="media-cell"></div><div class="media-cell"></div><div class="media-cell"></div>
<div class="media-cell"></div><div class="media-cell"></div><div class="media-cell"></div>
<div class="media-cell"></div><div class="media-cell"></div><div class="media-cell"></div>
<div class="media-cell"></div><div class="media-cell"></div><div class="media-cell"></div>
</div>
<div class="tile" style="margin:var(--s-lg);background:var(--surface);border-radius:var(--r-md);"><div class="tile-body"><div class="tile-title">Gérer le stockage</div><div class="tile-sub">Cache et téléchargements auto</div></div><span class="chev">›</span></div>
</div>
"""))

MAQUETTES['parametres-hub.html'] = page(
    'Paramètres — hub',
    'Paramètres · Phase 0',
    'SettingsScreen réorganisé : notifications, conversations silencieuses, stockage, préférences app, à propos — sans mélanger compte/sécurité.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Paramètres</h3></div>
<div class="body">
<div class="group-label">Communication</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">🔔</div><div class="tile-body"><div class="tile-title">Notifications</div><div class="tile-sub">Alertes, son, Ne pas déranger</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon brand">🔇</div><div class="tile-body"><div class="tile-title">Conversations silencieuses</div><div class="tile-sub">3 conversations</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Application</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">💾</div><div class="tile-body"><div class="tile-title">Stockage et cache</div><div class="tile-sub">1,8 Go utilisés</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon brand">⚡</div><div class="tile-body"><div class="tile-title">Préférences</div><div class="tile-sub">Réseau, lecture, accessibilité</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Apparence</div>
<div class="card" style="padding:var(--s-md);">
<div style="font-size:12px;color:var(--ink-2);margin-bottom:8px;padding:0 var(--s-sm);">Thème</div>
<div class="seg" style="margin:0;"><div class="seg-btn">Clair</div><div class="seg-btn on">Système</div><div class="seg-btn">Sombre</div></div>
</div>
<div class="group-label">Informations</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">ℹ</div><div class="tile-body"><div class="tile-title">À propos et mentions légales</div></div><span class="chev">›</span></div>
</div>
</div>
"""))

MAQUETTES['confidentialite.html'] = page(
    'Confidentialité',
    'Compte · Phase 0',
    'Écran confidentialité complet : dernière connexion, photo de profil, statuts, blocage, groupes, confirmation de lecture.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Confidentialité</h3></div>
<div class="body">
<div class="group-label">Qui peut me voir</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Dernière connexion</div><div class="tile-sub">Mes contacts</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Photo de profil</div><div class="tile-sub">Tout le monde</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Statuts</div><div class="tile-sub">Contacts sauf…</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Messages</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Accusés de lecture</div><div class="tile-sub">Envoyer et recevoir</div></div><div class="switch"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Aperçu des notifications</div><div class="tile-sub">Nom et contenu</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Listes et groupes</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">🚫</div><div class="tile-body"><div class="tile-title">Contacts bloqués</div><div class="tile-sub">2 contacts</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Ajout aux groupes</div><div class="tile-sub">Mes contacts</div></div><span class="chev">›</span></div>
</div>
</div>
"""))

MAQUETTES['compte-securite.html'] = page(
    'Sécurité du compte',
    'Compte · Phase 0',
    'Mot de passe, e-mail, biométrie, appareils connectés et déconnexion de tous les appareils.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Sécurité du compte</h3></div>
<div class="body">
<div class="chip-warn">⚠ Aucun e-mail enregistré — récupération impossible</div>
<div class="group-label">Identifiants</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">✉</div><div class="tile-body"><div class="tile-title">Adresse e-mail</div><div class="tile-sub">Non définie</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon brand">🔑</div><div class="tile-body"><div class="tile-title">Mot de passe</div><div class="tile-sub">Modifié il y a 3 mois</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Verrouillage</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">👆</div><div class="tile-body"><div class="tile-title">Déverrouillage biométrique</div><div class="tile-sub">Empreinte ou visage</div></div><div class="switch off"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Verrouiller après inactivité</div><div class="tile-sub">Immédiatement</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Appareils</div>
<div class="card">
<div class="tile"><div class="tile-icon brand">📱</div><div class="tile-body"><div class="tile-title">Appareils connectés</div><div class="tile-sub">2 appareils actifs</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-icon" style="background:var(--error-container);color:var(--error);">⎋</div><div class="tile-body"><div class="tile-title" style="color:var(--error);">Déconnecter tous les appareils</div></div><span class="chev">›</span></div>
</div>
</div>
"""))

MAQUETTES['notifications-dnd.html'] = page(
    'Notifications et Ne pas déranger',
    'Paramètres · Phase 0',
    'Préférences de notifications par type, aperçu, son/vibration et plage horaire Ne pas déranger.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Notifications</h3></div>
<div class="body">
<div class="group-label">Alertes</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Messages privés</div></div><div class="switch"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Messages de groupe</div></div><div class="switch"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Appels</div></div><div class="switch"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Réunions</div></div><div class="switch"></div></div>
</div>
<div class="group-label">Comportement</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Son</div></div><div class="switch"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Vibration</div></div><div class="switch"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Aperçu dans la notification</div><div class="tile-sub">Nom et message</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Ne pas déranger</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Activer le mode NPD</div></div><div class="switch"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Plage horaire</div><div class="tile-sub">22:00 – 07:00 · Lun–Ven</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Autoriser les appels favoris</div></div><div class="switch off"></div></div>
</div>
</div>
"""))

MAQUETTES['conversations-silencieuses.html'] = page(
    'Conversations silencieuses',
    'Paramètres · Phase 0',
    'Liste des chats en sourdine avec durée restante et action pour réactiver les notifications.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Conversations silencieuses</h3></div>
<div class="body">
<div class="chip-info">Les notifications sont coupées pour ces conversations. Les messages arrivent normalement.</div>
<div class="card" style="margin-top:var(--s-lg);">
<div class="tile"><div class="avatar-sm">É</div><div class="tile-body"><div class="tile-title">Équipe Projet</div><div class="tile-sub">Silencieux · 8 jours restants</div></div><span style="font-size:13px;color:var(--brand);">Réactiver</span></div>
<div class="tile"><div class="avatar-sm">P</div><div class="tile-body"><div class="tile-title">Paul N.</div><div class="tile-sub">Silencieux · Toujours</div></div><span style="font-size:13px;color:var(--brand);">Réactiver</span></div>
<div class="tile"><div class="avatar-sm">A</div><div class="tile-body"><div class="tile-title">Annonces Alanya</div><div class="tile-sub">Silencieux · 2 jours restants</div></div><span style="font-size:13px;color:var(--brand);">Réactiver</span></div>
</div>
</div>
"""))

MAQUETTES['stockage-cache.html'] = page(
    'Stockage et cache',
    'Paramètres · Phase 0',
    'Répartition de l’espace (messages, médias, cache), nettoyage sélectif et téléchargements automatiques.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Stockage et cache</h3></div>
<div class="body">
<div class="card" style="margin-top:var(--s-lg);padding:var(--s-lg);">
<div style="font-size:28px;font-weight:700;">1,8 Go</div>
<div style="font-size:12px;color:var(--ink-2);">sur 32 Go disponibles sur l'appareil</div>
<div class="storage-bar">
<div class="storage-seg" style="width:45%;background:var(--brand);"></div>
<div class="storage-seg" style="width:30%;background:#7986CB;"></div>
<div class="storage-seg" style="width:15%;background:var(--warning);"></div>
</div>
<div style="font-size:12px;color:var(--ink-2);">● Médias 820 Mo · ● Messages 540 Mo · ● Cache 270 Mo</div>
</div>
<div class="group-label">Nettoyage</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Vider le cache</div><div class="tile-sub">270 Mo</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Supprimer les médias téléchargés</div></div><span class="chev">›</span></div>
</div>
<div class="group-label">Téléchargements</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Photos</div><div class="tile-sub">Wi‑Fi uniquement</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Vidéos</div><div class="tile-sub">Jamais automatiquement</div></div><span class="chev">›</span></div>
</div>
</div>
"""))

MAQUETTES['preferences-app.html'] = page(
    "Préférences de l'application",
    'Paramètres · Phase 0',
    'Réseau (qualité appels, économie de données), vitesse de lecture des messages vocaux et options d’accessibilité.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Préférences</h3></div>
<div class="body">
<div class="group-label">Réseau</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Économie de données</div></div><div class="switch off"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Qualité des appels</div><div class="tile-sub">Automatique</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Envoyer en Wi‑Fi uniquement (fichiers lourds)</div></div><div class="switch"></div></div>
</div>
<div class="group-label">Lecture</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Messages vocaux</div><div class="tile-sub">Vitesse 1,25×</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Lecture automatique des vidéos</div></div><div class="switch off"></div></div>
</div>
<div class="group-label">Accessibilité</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Texte agrandi</div></div><div class="switch off"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Contraste renforcé</div></div><div class="switch off"></div></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Réduire les animations</div></div><div class="switch off"></div></div>
</div>
</div>
"""))

MAQUETTES["donnees-compte.html"] = page(
    "Données et compte",
    "Compte · Phase 0",
    "Export RGPD (demande + statut) et suppression de compte en trois étapes : avertissement, confirmation mot de passe, délai de grâce.",
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Données et compte</h3></div>
<div class="body">
<div class="group-label">Vos données</div>
<div class="card" style="padding:var(--s-lg);">
<div style="font-weight:600;">Exporter une copie (RGPD)</div>
<div style="font-size:13px;color:var(--ink-2);margin-top:8px;">Profil, messages, médias et métadonnées au format ZIP chiffré.</div>
<button class="btn-primary" type="button" style="margin:var(--s-md) 0 0;width:100%;">Demander l'export</button>
</div>
<div class="chip-success" style="margin-top:var(--s-lg);"><strong>Export en cours</strong><div style="font-size:12px;margin-top:4px;">Prêt dans ~24 h · notification à l'achèvement</div></div>
</div>
""", light_label="Export RGPD", dark_label="Export RGPD")
    + dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>Supprimer le compte</h3></div>
<div class="body">
<div class="step-dots"><div class="dot on"></div><div class="dot"></div><div class="dot"></div></div>
<div class="card" style="padding:var(--s-lg);margin-top:0;">
<div style="color:var(--error);font-weight:700;">Action irréversible</div>
<ul style="font-size:13px;color:var(--ink-2);padding-left:18px;margin:12px 0;">
<li>Suppression des messages et médias</li>
<li>Retrait de tous les groupes</li>
<li>Numéro libéré après 30 jours</li>
</ul>
<button class="btn-primary btn-danger" type="button">Continuer</button>
</div>
</div>
""", light_label="Suppression · étape 1", dark_label="Suppression · étape 1")
    + dual("""
<div class="appbar"><h3>Confirmer</h3></div>
<div class="body">
<div class="step-dots"><div class="dot"></div><div class="dot on"></div><div class="dot"></div></div>
<div class="field"><label>Mot de passe</label><input type="password" value="••••••••"></div>
<div class="field"><label>Taper SUPPRIMER</label><input type="text" placeholder="SUPPRIMER"></div>
<button class="btn-primary btn-danger" type="button">Supprimer mon compte</button>
</div>
""", light_label="Suppression · étape 2", dark_label="Suppression · étape 2")
    + dual("""
<div class="body" style="display:flex;flex-direction:column;align-items:center;justify-content:center;padding:var(--s-xxl);text-align:center;min-height:520px;">
<div style="font-size:48px;">⏳</div>
<div style="font-weight:700;margin-top:var(--s-lg);">Délai de grâce · 30 jours</div>
<div style="font-size:13px;color:var(--ink-2);margin-top:8px;">Reconnectez-vous avant le 1 sept. pour annuler la suppression.</div>
<button class="btn-primary btn-outline" type="button" style="margin-top:var(--s-xl);">Annuler la suppression</button>
</div>
""", light_label="Suppression · étape 3", dark_label="Suppression · étape 3")
)

def _onboarding_shell(title, step, total, body, skip=True):
    dots = ''.join(
        f'<div class="dot{" on" if i == step else ""}"></div>'
        for i in range(total)
    )
    skip_btn = (
        '<button class="btn-primary btn-outline" type="button" style="margin-top:0;">Passer</button>'
        if skip
        else ''
    )
    return f"""
<div class="appbar"><h3>{title}</h3></div>
<div class="body">
<div class="step-dots">{dots}</div>
{body}
<button class="btn-primary" type="button">Continuer</button>
{skip_btn}
</div>"""


MAQUETTES['onboarding-identifiants.html'] = page(
    'Onboarding — identifiants',
    'Onboarding · Phase 1',
    'Écran non skippable : numéro Alanya + rappel mot de passe après inscription minimale.',
    dual(_onboarding_shell(
        'Vos identifiants', 0, 8, """
<div class="chip-info">⚠ Notez ces informations — elles ne seront plus affichées.</div>
<div class="card profile-header" style="margin-top:var(--s-lg);">
<div style="font-size:12px;color:var(--ink-2);">Numéro Alanya</div>
<div style="font-size:32px;font-weight:700;letter-spacing:3px;color:var(--brand);margin-top:8px;">+237 6XX XXX XXX</div>
<div style="font-size:12px;color:var(--ink-2);margin-top:var(--s-xl);">Mot de passe</div>
<div style="font-size:18px;font-weight:600;margin-top:6px;">••••••••</div>
</div>
""", skip=False)))

MAQUETTES['onboarding-profil-pays.html'] = page(
    'Onboarding — pays',
    'Onboarding · Phase 1',
    'Étape optionnelle : sélection du pays avec Continuer / Passer.',
    dual(_onboarding_shell('Votre pays', 1, 8, """
<div style="padding:var(--s-lg);font-size:13px;color:var(--ink-2);text-align:center;">Aide vos contacts à vous identifier.</div>
<div class="field"><label>Pays</label><input type="text" value="🇨🇲 Cameroun"></div>
""")))

MAQUETTES['onboarding-profil-photo.html'] = page(
    'Onboarding — photo',
    'Onboarding · Phase 1',
    'Avatar camera/galerie, option Passer.',
    dual(_onboarding_shell('Photo de profil', 2, 8, """
<div class="profile-header">
<div class="avatar-lg">M<div class="cam-badge">📷</div></div>
<div style="font-size:13px;color:var(--ink-2);margin-top:var(--s-md);">Caméra ou galerie</div>
</div>
""")))

MAQUETTES['onboarding-profil-bio.html'] = page(
    'Onboarding — bio',
    'Onboarding · Phase 1',
    'Texte libre 500 caractères max, option Passer.',
    dual(_onboarding_shell('Quelques mots sur vous', 3, 8, """
<div class="field"><label>Bio</label><textarea placeholder="Designer UX · Douala…"></textarea></div>
<div style="padding:0 var(--s-lg);font-size:11px;color:var(--ink-3);text-align:right;">0 / 500</div>
""")))

MAQUETTES['onboarding-profil-email.html'] = page(
    'Onboarding — e-mail',
    'Onboarding · Phase 1',
    'E-mail optionnel avec bandeau d\'avertissement si vide.',
    dual(_onboarding_shell('Adresse e-mail', 4, 8, """
<div class="chip-warn">⚠ Sans e-mail, la récupération de compte est impossible.</div>
<div class="field"><label>E-mail (optionnel)</label><input type="email" placeholder="vous@exemple.com"></div>
""")))

MAQUETTES['onboarding-preferences-theme.html'] = page(
    'Onboarding — préférences',
    'Onboarding · Phase 1',
    'Thème clair / sombre / système et langue FR / EN / système.',
    dual(_onboarding_shell('Préférences', 5, 8, """
<div class="group-label">Apparence</div>
<div class="seg"><div class="seg-btn">Clair</div><div class="seg-btn">Sombre</div><div class="seg-btn on">Système</div></div>
<div class="group-label">Langue</div>
<div class="seg"><div class="seg-btn on">FR</div><div class="seg-btn">EN</div><div class="seg-btn">Système</div></div>
""")))

MAQUETTES['onboarding-securite-biometrie.html'] = page(
    'Onboarding — biométrie',
    'Onboarding · Phase 1',
    'Toggle biométrie si matériel disponible, option Passer.',
    dual(_onboarding_shell('Verrou biométrique', 6, 8, """
<div class="card" style="margin-top:var(--s-lg);">
<div class="tile"><div class="tile-icon brand">👆</div><div class="tile-body"><div class="tile-title">Déverrouillage biométrique</div><div class="tile-sub">Empreinte ou visage</div></div><div class="switch off"></div></div>
</div>
<div style="padding:var(--s-lg);font-size:13px;color:var(--ink-2);text-align:center;">Protège l'accès à l'app au retour.</div>
""")))

MAQUETTES['onboarding-termine.html'] = page(
    'Onboarding — terminé',
    'Onboarding · Phase 1',
    'Écran de fin avec CTA « Découvrir Alanya ».',
    dual("""
<div class="body" style="display:flex;flex-direction:column;align-items:center;justify-content:center;padding:var(--s-xxl);text-align:center;min-height:520px;">
<div style="font-size:56px;">🎉</div>
<div style="font-weight:700;font-size:22px;margin-top:var(--s-lg);">C'est parti !</div>
<div style="font-size:14px;color:var(--ink-2);margin-top:var(--s-sm);max-width:28ch;">Votre compte est prêt. Explorez Alanya.</div>
<button class="btn-primary" type="button" style="margin-top:var(--s-xxl);">Découvrir Alanya</button>
</div>
"""))

MAQUETTES['a-propos-legal.html'] = page(
    'À propos et mentions légales',
    'Paramètres · Phase 0',
    'Version de l’app, conditions d’utilisation, politique de confidentialité, licences open source et contact support.',
    dual("""
<div class="appbar"><svg class="back" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M15 18l-6-6 6-6"/></svg><h3>À propos</h3></div>
<div class="body">
<div class="profile-header" style="padding:var(--s-xxl) var(--s-lg);">
<div style="width:64px;height:64px;border-radius:16px;background:var(--brand);color:#fff;font-weight:800;font-size:28px;display:grid;place-items:center;margin:0 auto;">A</div>
<div style="font-size:18px;font-weight:700;margin-top:12px;">Alanya</div>
<div style="font-size:13px;color:var(--ink-2);">Version 2.4.0 (build 24018)</div>
</div>
<div class="card">
<div class="tile"><div class="tile-body"><div class="tile-title">Conditions d'utilisation</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Politique de confidentialité</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Licences open source</div></div><span class="chev">›</span></div>
<div class="tile"><div class="tile-body"><div class="tile-title">Contacter le support</div></div><span class="chev">›</span></div>
</div>
<div style="text-align:center;font-size:11px;color:var(--ink-3);padding:var(--s-xl);">© 2026 Alanya · Fait avec soin à Douala</div>
</div>
"""))


EXPECTED = [
    "onboarding-identifiants.html",
    "onboarding-profil-pays.html",
    "onboarding-profil-photo.html",
    "onboarding-profil-bio.html",
    "onboarding-profil-email.html",
    "onboarding-preferences-theme.html",
    "onboarding-securite-biometrie.html",
    "onboarding-termine.html",
    "profil-hub.html",
    "mon-compte-hub.html",
    "edit-profil-apercu.html",
    "mes-medias-profil.html",
    "parametres-hub.html",
    "confidentialite.html",
    "compte-securite.html",
    "notifications-dnd.html",
    "conversations-silencieuses.html",
    "stockage-cache.html",
    "preferences-app.html",
    "donnees-compte.html",
    "a-propos-legal.html",
]

if __name__ == "__main__":
    for name, content in MAQUETTES.items():
        (OUT / name).write_text(content, encoding="utf-8")
        print(f"Wrote {name}")
    missing = [n for n in EXPECTED if n not in MAQUETTES]
    extra = [n for n in MAQUETTES if n not in EXPECTED]
    if missing:
        print("MISSING:", missing)
    if extra:
        print("EXTRA:", extra)
    print(f"Done — {len(MAQUETTES)}/{len(EXPECTED)} maquettes")
