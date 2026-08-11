#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génère les sept planches de maquettes du volet « Trajets de confiance » (étape 7).

Même principe que _generate_profil_maquettes.py : un CSS partagé en constante, une
fonction par planche. Deux différences volontaires :

  * les fichiers produits sont au **format Artifact** (ils commencent à <title> et
    n'ont ni <!DOCTYPE>, ni <html>, ni <head>, ni <body>), comme listes-contacts.html
    et qr-identite.html — et contrairement aux planches profil/onboarding, qui sont
    des documents HTML complets ;
  * les jetons de couleur reprennent lib/core/theme/app_colors.dart sans en inventer
    aucun : les quatre jetons de trajet sont success / warning / error et la couleur
    de la liste Confiance (defaultContactLists.js).

Usage :  python3 _generate_trajets_maquettes.py
"""

import os

SORTIE = os.path.dirname(os.path.abspath(__file__))

# =====================================================================
#  CSS partagé
# =====================================================================
# Le bloc :root et les composants d'écran sont repris tels quels de
# listes-contacts.html — les planches d'un même dossier forment une série.
# Tout ce qui suit « Trajets » est propre à ce volet.

CSS = """
  :root {
    --brand:            #3F51B5;
    --brand-dark:       #1A237E;
    --brand-strong:     #303F9F;
    --brand-container:  #E8EAF6;
    --online:           #1FA363;

    --bg:               #F6F7FB;
    --surface:          #FFFFFF;
    --surface-muted:    #F4F5F8;
    --outline:          #E2E5EC;
    --outline-strong:   #CBD0E0;

    --ink:              #1A1D23;
    --ink-2:            #5B6273;
    --ink-3:            #9AA0AE;

    --page-bg:          #EEF0F7;
    --page-panel:       #FFFFFF;
    --page-line:        #DDE1EC;
    --page-ink:         #23283A;
    --page-ink-2:       #626A82;

    /* Jetons de trajet — aucune couleur nouvelle.
       success / warning / error de app_colors.dart, plus la teinte de la liste
       Confiance stockée en base dans contact_list.color (#B7791F). */
    --t-actif:      #1FA363;
    --t-actif-bg:   #E4F5EC;
    --t-attente:    #F59E0B;
    --t-attente-bg: #FDF0D9;
    --t-alerte:     #EF4444;
    --t-alerte-bg:  #FDE7E7;
    --t-confiance:  #B7791F;

    --r-sm: 12px; --r-md: 16px; --r-lg: 20px; --r-pill: 28px;
    --s-xs: 4px; --s-sm: 8px; --s-md: 12px; --s-lg: 16px; --s-xl: 20px; --s-xxl: 24px;

    --sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
    --mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
  }

  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) {
      --bg: #0F1115; --surface: #181B21; --surface-muted: #1F232B;
      --outline: #3A404C; --outline-strong: #3A404C;
      --ink: #F2F4F8; --ink-2: #AAB1C0; --ink-3: #6F7787;
      --brand-container: #283593;
      --page-bg: #0A0C11; --page-panel: #14171E; --page-line: #262C38;
      --page-ink: #E8EBF2; --page-ink-2: #939BAF;
      --t-actif-bg: #10301F; --t-attente-bg: #33260B; --t-alerte-bg: #3A1717;
    }
  }
  :root[data-theme="dark"] {
    --bg: #0F1115; --surface: #181B21; --surface-muted: #1F232B;
    --outline: #3A404C; --outline-strong: #3A404C;
    --ink: #F2F4F8; --ink-2: #AAB1C0; --ink-3: #6F7787;
    --brand-container: #283593;
    --page-bg: #0A0C11; --page-panel: #14171E; --page-line: #262C38;
    --page-ink: #E8EBF2; --page-ink-2: #939BAF;
    --t-actif-bg: #10301F; --t-attente-bg: #33260B; --t-alerte-bg: #3A1717;
  }
  :root[data-theme="light"] {
    --bg: #F6F7FB; --surface: #FFFFFF; --surface-muted: #F4F5F8;
    --outline: #E2E5EC; --outline-strong: #CBD0E0;
    --ink: #1A1D23; --ink-2: #5B6273; --ink-3: #9AA0AE;
    --brand-container: #E8EAF6;
    --page-bg: #EEF0F7; --page-panel: #FFFFFF; --page-line: #DDE1EC;
    --page-ink: #23283A; --page-ink-2: #626A82;
    --t-actif-bg: #E4F5EC; --t-attente-bg: #FDF0D9; --t-alerte-bg: #FDE7E7;
  }

  * { box-sizing: border-box; }

  .page {
    background: var(--page-bg); color: var(--page-ink);
    font-family: var(--sans); font-size: 15px; line-height: 1.55;
    min-height: 100vh; padding: clamp(20px, 5vw, 56px) clamp(16px, 4vw, 40px) 72px;
    -webkit-font-smoothing: antialiased;
  }
  .wrap { max-width: 1180px; margin: 0 auto; display: flex; flex-direction: column; gap: 40px; }

  .masthead { display: flex; flex-direction: column; gap: var(--s-md); max-width: 64ch; }
  .eyebrow {
    font-family: var(--mono); font-size: 11px; letter-spacing: 0.14em;
    text-transform: uppercase; color: var(--brand); margin: 0;
  }
  .masthead h1 {
    font-size: clamp(26px, 3.6vw, 38px); line-height: 1.12; letter-spacing: -0.02em;
    font-weight: 700; margin: 0; text-wrap: balance;
  }
  .masthead p { margin: 0; color: var(--page-ink-2); }

  .panel {
    background: var(--page-panel); border: 1px solid var(--page-line);
    border-radius: var(--r-lg); padding: clamp(18px, 3vw, 30px);
    display: flex; flex-direction: column; gap: var(--s-xl);
  }
  .panel > header { display: flex; flex-direction: column; gap: 6px; }
  .panel h2 { font-size: 19px; font-weight: 650; margin: 0; letter-spacing: -0.01em; }
  .panel header p { margin: 0; color: var(--page-ink-2); font-size: 14px; max-width: 70ch; }

  /* ---------- Scène ---------- */
  .stage {
    display: grid; grid-template-columns: repeat(auto-fit, minmax(290px, 1fr));
    gap: clamp(18px, 2.6vw, 32px); align-items: start;
  }
  .stage.serre { grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); }
  .device-block { display: flex; flex-direction: column; gap: var(--s-md); align-items: center; }
  .device-caption {
    font-family: var(--mono); font-size: 10.5px; letter-spacing: 0.08em;
    text-transform: uppercase; color: var(--page-ink-2); text-align: center; max-width: 32ch;
  }
  .device-caption b { display: block; color: var(--page-ink); font-weight: 600; letter-spacing: 0.06em; }
  .device {
    width: 100%; max-width: 330px; background: var(--bg);
    border: 1px solid var(--outline); border-radius: 30px; padding: 8px;
    box-shadow: 0 18px 44px rgba(26, 35, 126, 0.13), 0 2px 6px rgba(0,0,0,0.05);
  }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) .device { box-shadow: 0 18px 44px rgba(0,0,0,0.5); }
  }
  :root[data-theme="dark"] .device { box-shadow: 0 18px 44px rgba(0,0,0,0.5); }

  .screen {
    background: var(--bg); border-radius: 23px; overflow: hidden;
    display: flex; flex-direction: column; min-height: 560px; color: var(--ink);
    position: relative;
  }
  .screen.court { min-height: 420px; }

  .appbar {
    background: var(--surface); border-bottom: 1px solid var(--outline);
    padding: 14px var(--s-lg) var(--s-md);
    display: flex; align-items: center; gap: var(--s-md);
  }
  .appbar .back { width: 22px; height: 22px; color: var(--ink-2); flex: none; }
  .appbar h3 { margin: 0; font-size: 18px; font-weight: 650; letter-spacing: -0.01em; }
  .appbar .spacer { flex: 1; }
  .appbar .compte { font-size: 12px; color: var(--ink-3); font-variant-numeric: tabular-nums; }

  .rows { background: var(--surface); display: flex; flex-direction: column; }
  .rows.grandit { flex: 1; }
  .row {
    display: flex; align-items: center; gap: var(--s-md);
    padding: 11px var(--s-lg); border-bottom: 1px solid var(--outline);
  }
  .row:last-child { border-bottom: none; }
  .row-body { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
  .row-nom {
    font-size: 15px; font-weight: 600; color: var(--ink);
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  .row-sous { font-size: 12.5px; color: var(--ink-2); }
  .row-sous.mono { font-family: var(--mono); font-variant-numeric: tabular-nums; }

  .avatar {
    width: 40px; height: 40px; border-radius: 50%; display: grid; place-items: center;
    flex: none; position: relative; font-size: 13px; font-weight: 650; color: #fff;
    background: var(--brand-strong);
  }
  .avatar.sm { width: 28px; height: 28px; font-size: 11px; }
  .avatar.xs { width: 22px; height: 22px; font-size: 9.5px; border: 2px solid var(--surface); }

  .chevron { width: 18px; height: 18px; color: var(--ink-3); flex: none; }
  .check {
    width: 22px; height: 22px; border-radius: 50%; flex: none;
    border: 1.8px solid var(--outline-strong); display: grid; place-items: center;
  }
  .check[data-on="1"] { background: var(--brand); border-color: var(--brand); }
  .check svg { width: 13px; height: 13px; color: #fff; }

  .bas {
    padding: var(--s-md) var(--s-lg) var(--s-lg);
    background: var(--surface); border-top: 1px solid var(--outline);
    display: flex; flex-direction: column; gap: var(--s-sm);
  }
  .cta {
    width: 100%; min-height: 48px; border-radius: var(--r-sm); border: none;
    background: var(--brand); color: #fff; font-size: 15px; font-weight: 650;
    font-family: inherit; display: inline-flex; align-items: center;
    justify-content: center; gap: var(--s-sm); padding: 0 var(--s-md);
  }
  .cta svg { width: 19px; height: 19px; }
  .cta.fantome { background: transparent; color: var(--ink-2); border: 1px solid var(--outline-strong); }
  .cta.vert { background: var(--t-actif); }
  .cta.rouge { background: var(--t-alerte); }
  .cta.mini { min-height: 40px; font-size: 14px; }

  .hint {
    margin: 0; padding: var(--s-lg);
    font-size: 12.5px; line-height: 1.5; color: var(--ink-3);
    background: var(--surface);
  }
  .hint.grandit { flex: 1; }

  /* =================================================================
     Trajets — composants propres au volet 7
     ================================================================= */

  /* Bandeau d'état en tête d'écran. La couleur EST l'information :
     on doit pouvoir lire l'état sans lire le texte. */
  .etat {
    display: flex; align-items: center; gap: var(--s-sm);
    padding: 9px var(--s-lg); font-size: 12.5px; font-weight: 600;
    background: var(--t-actif-bg); color: var(--t-actif);
  }
  .etat.attente { background: var(--t-attente-bg); color: #9A6100; }
  .etat.alerte  { background: var(--t-alerte-bg);  color: #B32020; }
  .etat.neutre  { background: var(--surface-muted); color: var(--ink-2); }
  :root[data-theme="dark"] .etat.attente { color: #F3C05A; }
  :root[data-theme="dark"] .etat.alerte  { color: #FF8D8D; }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) .etat.attente { color: #F3C05A; }
    :root:not([data-theme="light"]) .etat.alerte  { color: #FF8D8D; }
  }
  .etat .spacer { flex: 1; }
  .etat .chrono { font-family: var(--mono); font-variant-numeric: tabular-nums; }

  /* Pastille « en direct ». L'anneau ne clignote pas : il respire.
     Un clignotement rapide sur un écran de sûreté fatigue. */
  .pouls { width: 8px; height: 8px; border-radius: 50%; background: currentColor; flex: none;
           position: relative; }
  .pouls::after {
    content: ""; position: absolute; inset: -4px; border-radius: 50%;
    border: 1.5px solid currentColor; opacity: 0.45;
    animation: respire 2.4s ease-in-out infinite;
  }
  @keyframes respire {
    0%, 100% { transform: scale(0.75); opacity: 0.5; }
    50%      { transform: scale(1.15); opacity: 0.1; }
  }

  /* Carte. Un fond quadrillé discret plus une polyligne : assez pour lire
     « on suit un déplacement », sans faire semblant d'être une vraie carte. */
  .carte-geo { position: relative; background: var(--surface-muted); flex: 1; min-height: 190px; }
  .carte-geo svg { position: absolute; inset: 0; width: 100%; height: 100%; }
  .carte-geo .rue { stroke: var(--outline); stroke-width: 1; }
  .carte-geo .bloc { fill: var(--surface); }
  .carte-geo .route { stroke: var(--brand); stroke-width: 3; fill: none; stroke-linecap: round; }
  .carte-geo .route.pale { stroke: var(--outline-strong); stroke-dasharray: 5 5; }
  .carte-geo .route.alerte { stroke: var(--t-alerte); }
  .carte-geo .halo { fill: var(--brand); opacity: 0.14; }
  .carte-geo .halo.alerte { fill: var(--t-alerte); opacity: 0.16; }

  .pin {
    position: absolute; width: 15px; height: 15px; border-radius: 50%;
    background: var(--brand); border: 2.5px solid var(--surface);
    box-shadow: 0 2px 6px rgba(0,0,0,0.28); transform: translate(-50%, -50%);
  }
  .pin.but { background: var(--t-actif); }
  .pin.sos { background: var(--t-alerte); width: 17px; height: 17px; }
  .pin.perdu { background: var(--ink-3); }

  .drapeau {
    position: absolute; transform: translate(-50%, -50%);
    display: flex; align-items: center; gap: 5px;
    background: var(--surface); border: 1px solid var(--outline);
    border-radius: var(--r-pill); padding: 3px 9px 3px 5px;
    font-size: 10.5px; font-weight: 600; color: var(--ink-2); white-space: nowrap;
    box-shadow: 0 2px 8px rgba(0,0,0,0.12);
  }
  .drapeau i { width: 7px; height: 7px; border-radius: 50%; background: var(--t-actif); }

  /* La « rampe » : les quatre temps du trajet, toujours dans le même ordre.
     C'est la seule chose qui reste identique d'un écran à l'autre. */
  .rampe { display: flex; gap: 0; padding: var(--s-md) var(--s-lg); background: var(--surface);
           border-bottom: 1px solid var(--outline); }
  .rampe .pas { flex: 1; display: flex; flex-direction: column; gap: 5px; }
  .rampe .barre { height: 3px; border-radius: 2px; background: var(--outline); }
  .rampe .pas[data-on="1"] .barre { background: var(--t-actif); }
  .rampe .pas[data-on="now"] .barre { background: var(--brand); }
  .rampe .pas[data-on="alerte"] .barre { background: var(--t-alerte); }
  .rampe .lib { font-size: 9.5px; letter-spacing: 0.05em; text-transform: uppercase;
                color: var(--ink-3); font-family: var(--mono); }
  .rampe .pas[data-on="now"] .lib { color: var(--brand); }
  .rampe .pas[data-on="alerte"] .lib { color: var(--t-alerte); }

  /* Le contrat, en toutes lettres. C'est le seul élément qui garantit que
     l'utilisateur a compris ce qu'il déclenche. */
  .contrat {
    margin: var(--s-md) var(--s-lg); padding: var(--s-md);
    border-radius: var(--r-sm); background: var(--brand-container);
    color: var(--brand-dark); font-size: 13px; line-height: 1.5;
  }
  :root[data-theme="dark"] .contrat { color: #DDE1FF; }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) .contrat { color: #DDE1FF; }
  }
  .contrat b { font-weight: 700; }

  /* Carte de trajet dans une conversation — le message de type 9. */
  .fil { flex: 1; background: var(--bg); padding: var(--s-md) var(--s-lg);
         display: flex; flex-direction: column; gap: var(--s-sm); }
  .bulle {
    max-width: 78%; padding: 8px 12px; border-radius: var(--r-md);
    font-size: 13.5px; background: var(--surface); border: 1px solid var(--outline);
    align-self: flex-start;
  }
  .bulle.moi { align-self: flex-end; background: var(--brand-container); border-color: transparent;
               color: var(--brand-dark); }
  :root[data-theme="dark"] .bulle.moi { color: #DDE1FF; }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) .bulle.moi { color: #DDE1FF; }
  }
  .bulle .h { font-size: 10px; color: var(--ink-3); font-family: var(--mono);
              display: block; margin-top: 3px; }

  .tcard {
    align-self: flex-start; width: 88%; background: var(--surface);
    border: 1px solid var(--outline); border-radius: var(--r-md); overflow: hidden;
    display: flex; flex-direction: column;
  }
  .tcard.systeme { align-self: center; width: 100%; background: transparent; border: none;
                   text-align: center; }
  .tcard .liseré { height: 3px; background: var(--t-actif); }
  .tcard .liseré.attente { background: var(--t-attente); }
  .tcard .liseré.alerte  { background: var(--t-alerte); }
  .tcard .liseré.gris    { background: var(--outline-strong); }
  .tcard .corps { padding: 10px var(--s-md); display: flex; flex-direction: column; gap: 7px; }
  .tcard .tete { display: flex; align-items: center; gap: var(--s-sm); }
  .tcard .titre { font-size: 13.5px; font-weight: 650; color: var(--ink); line-height: 1.3; }
  .tcard .meta { font-size: 11.5px; color: var(--ink-2); font-family: var(--mono);
                 font-variant-numeric: tabular-nums; }
  .tcard .apercu { height: 62px; background: var(--surface-muted); border-radius: var(--r-sm);
                   position: relative; overflow: hidden; }
  .tcard .apercu svg { position: absolute; inset: 0; width: 100%; height: 100%; }
  .tcard .suivre {
    border-top: 1px solid var(--outline); padding: 9px; text-align: center;
    font-size: 13px; font-weight: 650; color: var(--brand);
  }
  .tcard .suivre.rouge { color: var(--t-alerte); }
  .tcard .suivre.gris  { color: var(--ink-3); font-weight: 550; }
  .sysline {
    align-self: center; font-size: 11.5px; color: var(--ink-2); text-align: center;
    background: var(--surface-muted); border-radius: var(--r-pill); padding: 4px 12px;
  }
  .sysline.alerte { background: var(--t-alerte-bg); color: #B32020; font-weight: 600; }
  :root[data-theme="dark"] .sysline.alerte { color: #FF8D8D; }
  @media (prefers-color-scheme: dark) {
    :root:not([data-theme="light"]) .sysline.alerte { color: #FF8D8D; }
  }

  /* Bandeau persistant, posé au-dessus de la barre de navigation.
     Il occupe l'espace déjà réservé par kGlassNavBarSpace. */
  .bandeau {
    margin: 0 var(--s-md) var(--s-sm); border-radius: var(--r-sm);
    background: var(--t-actif); color: #fff; padding: 9px var(--s-md);
    display: flex; align-items: center; gap: var(--s-sm); font-size: 12.5px; font-weight: 600;
  }
  .bandeau.attente { background: var(--t-attente); color: #3A2A00; }
  .bandeau.alerte  { background: var(--t-alerte); }
  .bandeau .spacer { flex: 1; }
  .bandeau .chrono { font-family: var(--mono); font-variant-numeric: tabular-nums;
                     font-weight: 600; opacity: 0.92; }

  .nav {
    background: var(--surface); border-top: 1px solid var(--outline);
    display: flex; padding: var(--s-sm) 0 var(--s-md);
  }
  .nav span {
    flex: 1; text-align: center; font-size: 9.5px; color: var(--ink-3);
    display: flex; flex-direction: column; align-items: center; gap: 3px;
  }
  .nav span i { width: 20px; height: 20px; border-radius: 6px; background: var(--outline);
                display: block; }
  .nav span[data-on="1"] { color: var(--brand); }
  .nav span[data-on="1"] i { background: var(--brand); }

  /* Feuille modale : arrivée, prolongation, consentement. */
  .voile { position: absolute; inset: 0; background: rgba(10, 12, 17, 0.45); }
  .feuille {
    position: absolute; left: 0; right: 0; bottom: 0;
    background: var(--surface); border-radius: var(--r-lg) var(--r-lg) 0 0;
    padding: var(--s-lg); display: flex; flex-direction: column; gap: var(--s-md);
  }
  .feuille .poignee { width: 36px; height: 4px; border-radius: 2px; background: var(--outline-strong);
                      align-self: center; }
  .feuille h4 { margin: 0; font-size: 17px; font-weight: 700; letter-spacing: -0.01em;
                text-wrap: balance; }
  .feuille p { margin: 0; font-size: 13.5px; color: var(--ink-2); }
  .duo { display: flex; gap: var(--s-sm); width: 100%; }
  .duo .cta { flex: 1; }

  /* SOS : maintien puis décompte. Deux gestes, pas un. */
  .sos-zone { flex: 1; display: flex; flex-direction: column; align-items: center;
              justify-content: center; gap: var(--s-lg); padding: var(--s-xl);
              background: var(--surface); text-align: center; }
  .sos-bouton {
    width: 148px; height: 148px; border-radius: 50%; display: grid; place-items: center;
    background: var(--t-alerte); color: #fff; font-size: 27px; font-weight: 800;
    letter-spacing: 0.06em; position: relative;
  }
  .sos-bouton::before {
    content: ""; position: absolute; inset: -11px; border-radius: 50%;
    border: 3px solid var(--t-alerte); opacity: 0.28;
  }
  .sos-bouton::after {
    content: ""; position: absolute; inset: -11px; border-radius: 50%;
    border: 3px solid var(--t-alerte); border-right-color: transparent;
    border-bottom-color: transparent; transform: rotate(-30deg);
  }
  .sos-bouton.discret { background: var(--surface-muted); color: var(--ink-3);
                        font-size: 15px; font-weight: 650; letter-spacing: 0; }
  .sos-bouton.discret::before, .sos-bouton.discret::after { display: none; }
  .decompte { font-size: 52px; font-weight: 800; color: var(--t-alerte);
              font-variant-numeric: tabular-nums; line-height: 1; }
  .sos-zone h4 { margin: 0; font-size: 18px; font-weight: 700; text-wrap: balance; }
  .sos-zone p { margin: 0; font-size: 13.5px; color: var(--ink-2); max-width: 30ch; }

  /* Écran d'alerte reçue — plein écran, une seule décision visible. */
  .alerte-plein {
    flex: 1; background: var(--t-alerte); color: #fff; padding: var(--s-xl);
    display: flex; flex-direction: column; gap: var(--s-md); justify-content: center;
    text-align: center; align-items: center;
  }
  .alerte-plein .quoi { font-size: 12px; font-family: var(--mono); letter-spacing: 0.16em;
                        text-transform: uppercase; opacity: 0.85; }
  .alerte-plein h4 { margin: 0; font-size: 23px; font-weight: 800; line-height: 1.2;
                     text-wrap: balance; }
  .alerte-plein .ou { font-size: 13px; opacity: 0.92; font-variant-numeric: tabular-nums; }
  .alerte-plein .encart {
    background: rgba(255,255,255,0.16); border-radius: var(--r-sm); padding: var(--s-md);
    font-size: 12.5px; width: 100%; text-align: left; line-height: 1.5;
  }

  /* Notification système et écran verrouillé. */
  .verrou { flex: 1; background: linear-gradient(160deg, #1A237E, #0D123E); color: #fff;
            padding: var(--s-xl) var(--s-lg); display: flex; flex-direction: column; gap: var(--s-md); }
  .verrou .heure { font-size: 46px; font-weight: 300; letter-spacing: -0.02em; line-height: 1;
                   font-variant-numeric: tabular-nums; }
  .verrou .date { font-size: 13px; opacity: 0.72; margin-bottom: var(--s-sm); }
  .notif {
    background: rgba(255,255,255,0.94); color: var(--ink); border-radius: var(--r-md);
    padding: 10px var(--s-md); display: flex; flex-direction: column; gap: 4px;
  }
  .notif .app { font-size: 10.5px; font-family: var(--mono); color: var(--ink-3);
                letter-spacing: 0.06em; text-transform: uppercase; }
  .notif .t { font-size: 13.5px; font-weight: 650; }
  .notif .c { font-size: 12.5px; color: var(--ink-2); line-height: 1.45; }
  .notif .actions { display: flex; gap: var(--s-lg); margin-top: 3px;
                    font-size: 12.5px; font-weight: 650; color: var(--brand); }
  .notif.urgent { border-left: 4px solid var(--t-alerte); }
  .notif.urgent .t { color: #B32020; }

  /* Historique. */
  .histo-row { display: flex; align-items: center; gap: var(--s-md);
               padding: 12px var(--s-lg); border-bottom: 1px solid var(--outline); }
  .jalon { width: 30px; height: 30px; border-radius: 50%; flex: none; display: grid;
           place-items: center; background: var(--t-actif-bg); color: var(--t-actif); }
  .jalon.alerte { background: var(--t-alerte-bg); color: var(--t-alerte); }
  .jalon.gris { background: var(--surface-muted); color: var(--ink-3); }
  .jalon svg { width: 15px; height: 15px; }

  .frise { padding: var(--s-lg); background: var(--surface); display: flex;
           flex-direction: column; gap: 0; }
  .frise .ev { display: grid; grid-template-columns: 54px 13px 1fr; gap: var(--s-sm);
               align-items: start; }
  .frise .h { font-family: var(--mono); font-size: 11px; color: var(--ink-3);
              font-variant-numeric: tabular-nums; padding-top: 1px; }
  .frise .axe { display: flex; flex-direction: column; align-items: center; height: 100%; }
  .frise .axe i { width: 9px; height: 9px; border-radius: 50%; background: var(--outline-strong);
                  flex: none; margin-top: 4px; }
  .frise .axe u { flex: 1; width: 1.5px; background: var(--outline); min-height: 16px; }
  .frise .ev:last-child .axe u { display: none; }
  .frise .ev[data-k="ok"] .axe i { background: var(--t-actif); }
  .frise .ev[data-k="alerte"] .axe i { background: var(--t-alerte); }
  .frise .txt { font-size: 12.5px; color: var(--ink-2); padding-bottom: var(--s-md); }
  .frise .txt b { color: var(--ink); font-weight: 600; }

  .vide { flex: 1; display: flex; flex-direction: column; align-items: center;
          justify-content: center; gap: var(--s-md); padding: var(--s-xl); text-align: center;
          background: var(--surface); }
  .vide .rond { width: 68px; height: 68px; border-radius: 50%; background: var(--surface-muted);
                display: grid; place-items: center; color: var(--ink-3); }
  .vide .rond svg { width: 30px; height: 30px; }
  .vide h4 { margin: 0; font-size: 17px; font-weight: 650; text-wrap: balance; }
  .vide p { margin: 0; font-size: 13.5px; color: var(--ink-2); max-width: 30ch; }

  /* Administration : des compteurs, et rien d'autre. */
  .kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
          gap: var(--s-md); }
  .kpi { border: 1px solid var(--page-line); border-radius: var(--r-md); padding: var(--s-md);
         display: flex; flex-direction: column; gap: 3px; }
  .kpi .lib { font-family: var(--mono); font-size: 10.5px; letter-spacing: 0.08em;
              text-transform: uppercase; color: var(--page-ink-2); }
  .kpi .val { font-size: 27px; font-weight: 700; letter-spacing: -0.02em;
              font-variant-numeric: tabular-nums; color: var(--page-ink); }
  .kpi .var { font-size: 12px; color: var(--page-ink-2); font-variant-numeric: tabular-nums; }
  .kpi .val.vert { color: var(--t-actif); }
  .kpi .val.rouge { color: var(--t-alerte); }
  .spark { height: 34px; margin-top: 3px; }
  .spark path.aire { fill: var(--brand); opacity: 0.12; }
  .spark path.trait { fill: none; stroke: var(--brand); stroke-width: 1.6; }
  .spark circle { fill: var(--brand); }

  .interdit {
    border: 1px dashed var(--page-line); border-radius: var(--r-md); padding: var(--s-lg);
    display: flex; flex-direction: column; gap: var(--s-sm); background: var(--page-panel);
  }
  .interdit h3 { margin: 0; font-size: 14px; font-weight: 650; color: var(--page-ink); }
  .interdit ul { margin: 0; padding-left: 1.1em; font-size: 13.5px; color: var(--page-ink-2);
                 display: flex; flex-direction: column; gap: 4px; }

  /* ---------- Blocs de page ---------- */
  .modele { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: var(--s-lg); }
  .fiche {
    border: 1px solid var(--page-line); border-radius: var(--r-md);
    padding: var(--s-lg); display: flex; flex-direction: column; gap: var(--s-sm);
  }
  .fiche h3 {
    margin: 0; font-family: var(--mono); font-size: 12.5px; color: var(--brand);
    letter-spacing: 0.02em; font-weight: 600;
  }
  .fiche p { margin: 0; font-size: 13.5px; color: var(--page-ink-2); }
  .fiche dl {
    margin: 0; display: grid; grid-template-columns: auto 1fr; gap: 3px var(--s-md);
    font-family: var(--mono); font-size: 12px; font-variant-numeric: tabular-nums;
  }
  .fiche dt { color: var(--page-ink); }
  .fiche dd { margin: 0; color: var(--page-ink-2); }

  .notes { display: flex; flex-direction: column; gap: var(--s-md); }
  .note {
    border-left: 3px solid var(--brand); padding-left: var(--s-md);
    font-size: 14px; color: var(--page-ink-2); max-width: 78ch;
  }
  .note.attention { border-left-color: var(--t-alerte); }
  .note.bien { border-left-color: var(--t-actif); }
  .note b { color: var(--page-ink); font-weight: 650; }

  .tableau { width: 100%; overflow-x: auto; }
  .tableau table { border-collapse: collapse; width: 100%; min-width: 520px; font-size: 13.5px; }
  .tableau th, .tableau td { text-align: left; padding: 8px 10px;
                             border-bottom: 1px solid var(--page-line); vertical-align: top; }
  .tableau th { font-family: var(--mono); font-size: 11px; letter-spacing: 0.06em;
                text-transform: uppercase; color: var(--page-ink-2); font-weight: 600; }
  .tableau td code { font-family: var(--mono); font-size: 12px; color: var(--brand); }

  footer.colophon {
    display: flex; flex-wrap: wrap; gap: var(--s-sm) var(--s-xl);
    padding-top: var(--s-lg); border-top: 1px solid var(--page-line);
    font-family: var(--mono); font-size: 11.5px; color: var(--page-ink-2);
  }

  :focus-visible { outline: 2px solid var(--brand); outline-offset: 3px; border-radius: 4px; }
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: 0.001ms !important; animation-iteration-count: 1 !important;
      transition-duration: 0.001ms !important;
    }
  }
"""

# =====================================================================
#  Fragments réutilisés
# =====================================================================

ICONES = {
    "back": '<path d="M15 18l-6-6 6-6"/>',
    "chevron": '<path d="M9 18l6-6-6-6"/>',
    "check": '<path d="M20 6L9 17l-5-5"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "shield": '<path d="M12 3l7 3v6c0 4.4-3 8-7 9-4-1-7-4.6-7-9V6z"/>',
    "pin": '<path d="M12 21s7-5.7 7-11a7 7 0 10-14 0c0 5.3 7 11 7 11z"/><circle cx="12" cy="10" r="2.6"/>',
    "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.2 2"/>',
    "car": '<path d="M4 15h16M6 15V9.5L7.6 6h8.8L18 9.5V15M6.5 18.5v-2M17.5 18.5v-2"/>',
    "users": '<circle cx="9" cy="8" r="3.2"/><path d="M3.5 19a5.5 5.5 0 0111 0"/>'
             '<path d="M16 5.4a3.2 3.2 0 010 5.2M17.5 19a5.5 5.5 0 00-2-4.2"/>',
    "alert": '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.2v.2"/>',
    "off": '<path d="M3 3l18 18"/><path d="M12 21s7-5.7 7-11a6.9 6.9 0 00-1.3-4"/>'
           '<path d="M7.4 5.6A7 7 0 005 10c0 5.3 7 11 7 11"/>',
    "wifi": '<path d="M3 3l18 18"/><path d="M5 12.5a11 11 0 013.5-2.3M15 10.3a11 11 0 013.9 2.2"/>'
            '<path d="M8.5 15.7a6.5 6.5 0 013-1.2M12 19.5v.2"/>',
    "battery": '<rect x="2" y="8" width="16" height="9" rx="2"/><path d="M21 11.5v2"/>'
               '<path d="M5 11v3"/>',
    "phone": '<path d="M6 3.5h3l1.6 4-2 1.4a12 12 0 006.5 6.5l1.4-2 4 1.6v3a2 2 0 01-2.2 2A17 17 0 014 5.7 2 2 0 016 3.5z"/>',
    "stop": '<rect x="6" y="6" width="12" height="12" rx="2.5"/>',
    "eye": '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/>'
           '<circle cx="12" cy="12" r="3"/>',
    "trash": '<path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13"/>',
    "lock": '<rect x="4.5" y="10.5" width="15" height="10" rx="2.5"/>'
            '<path d="M8 10.5V7.5a4 4 0 018 0v3"/>',
}


def svg(nom, cls="", taille=None):
    """Icône linéaire, même facture que les planches existantes."""
    attrs = f' class="{cls}"' if cls else ""
    if taille:
        attrs += f' width="{taille}" height="{taille}"'
    return (f'<svg{attrs} viewBox="0 0 24 24" fill="none" stroke="currentColor" '
            f'stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">'
            f'{ICONES[nom]}</svg>')


def appbar(titre, compte="", retour=True):
    dos = svg("back", "back") if retour else ""
    fin = f'<span class="spacer"></span><span class="compte">{compte}</span>' if compte else ""
    return f'<div class="appbar">{dos}<h3>{titre}</h3>{fin}</div>'


def device(contenu, legende, sous, court=False):
    cl = "screen court" if court else "screen"
    return (f'<div class="device-block">'
            f'<div class="device"><div class="{cl}">{contenu}</div></div>'
            f'<p class="device-caption"><b>{legende}</b>{sous}</p></div>')


def carte_geo(route="M18 150 C 60 120, 78 78, 130 62 S 214 40, 250 26",
              pins=(), classe="", halo=None, pale=False):
    """Fond de carte schématique. Les blocs sont fixes : c'est un décor, pas une carte."""
    blocs = ""
    for x in (10, 96, 182, 250):
        for y in (14, 78, 142):
            blocs += f'<rect class="bloc" x="{x}" y="{y}" width="62" height="46" rx="3"/>'
    rues = ('<path class="rue" d="M0 70h290M0 134h290M88 0v200M174 0v200"/>')
    h = ""
    if halo:
        h = f'<circle class="halo{" alerte" if "alerte" in classe else ""}" ' \
            f'cx="{halo[0]}" cy="{halo[1]}" r="{halo[2]}"/>'
    rcl = "route pale" if pale else f"route {classe}".strip()
    corps = (f'<svg viewBox="0 0 290 200" preserveAspectRatio="xMidYMid slice" aria-hidden="true">'
             f'<rect width="290" height="200" fill="none"/>{blocs}{rues}{h}'
             f'<path class="{rcl}" d="{route}"/></svg>')
    for p in pins:
        corps += p
    return f'<div class="carte-geo">{corps}</div>'


def pin(x, y, cls=""):
    return f'<div class="pin {cls}" style="left:{x}%;top:{y}%"></div>'


def drapeau(x, y, texte, point=True):
    i = '<i></i>' if point else ""
    return f'<div class="drapeau" style="left:{x}%;top:{y}%">{i}{texte}</div>'


def rampe(actif):
    """Les quatre temps : Partir, Suivre, Confirmer, Clore. actif ∈ 0..3, ou 'alerte'."""
    libs = ["Partir", "Suivre", "Confirmer", "Clore"]
    out = ""
    for i, lib in enumerate(libs):
        if actif == "alerte":
            etat = "1" if i < 2 else ("alerte" if i == 2 else "0")
        else:
            etat = "1" if i < actif else ("now" if i == actif else "0")
        out += f'<div class="pas" data-on="{etat}"><div class="barre"></div>' \
               f'<span class="lib">{lib}</span></div>'
    return f'<div class="rampe">{out}</div>'


def apercu_mini(alerte=False):
    """Vignette de carte dans la carte de trajet : basse, sans interaction."""
    coul = "var(--t-alerte)" if alerte else "var(--brand)"
    return ('<div class="apercu"><svg viewBox="0 0 260 62" preserveAspectRatio="none" '
            'aria-hidden="true">'
            '<path d="M0 22h260M0 44h260M70 0v62M156 0v62" stroke="var(--outline)" '
            'stroke-width="1" fill="none"/>'
            f'<path d="M12 50 C 60 44, 84 26, 130 22 S 210 14, 248 8" stroke="{coul}" '
            'stroke-width="2.6" fill="none" stroke-linecap="round"/>'
            f'<circle cx="248" cy="8" r="5" fill="{coul}"/>'
            '<circle cx="248" cy="8" r="9" fill="none" stroke="' + coul + '" '
            'stroke-width="1.4" opacity="0.4"/>'
            '</svg></div>')


def page(titre, eyebrow, h1, chapo, corps, colophon):
    """Format Artifact : on démarre à <title>, sans <!DOCTYPE> ni <body>."""
    return f"""<title>{titre}</title>

<style>{CSS}</style>

<div class="page">
<div class="wrap">

  <header class="masthead">
    <p class="eyebrow">{eyebrow}</p>
    <h1>{h1}</h1>
    <p>{chapo}</p>
  </header>

{corps}

  <footer class="colophon">{colophon}</footer>

</div>
</div>
"""


COLOPHON = ('<span>Alanya · Trajets de confiance · Étape 7</span>'
            '<span>Jetons : lib/core/theme/app_colors.dart</span>'
            '<span>Document de travail</span>')


# =====================================================================
#  Planche 1 — Le parcours
# =====================================================================

def planche_parcours():
    # Chemin nominal : cinq temps, de la feuille de départ à la clôture.
    nominal = ""
    nominal += device(
        rampe(0) +
        '<div class="contrat">Si vous n\'avez pas confirmé à <b>21:45</b>,'
        ' vos cinq proches seront prévenus.</div>' +
        '<div class="rows grandit">'
        '<div class="row">' + svg("car", "chevron") +
        '<div class="row-body"><span class="row-nom">Taxi</span>'
        '<span class="row-sous">Retour du bureau</span></div>'
        '<span class="check" data-on="1">' + svg("check") + '</span></div>'
        '<div class="row">' + svg("pin", "chevron") +
        '<div class="row-body"><span class="row-nom">Domicile</span>'
        '<span class="row-sous mono">rayon 150 m</span></div></div>'
        '<div class="row">' + svg("clock", "chevron") +
        '<div class="row-body"><span class="row-nom">21:45</span>'
        '<span class="row-sous">dans 32 minutes</span></div></div>'
        '<div class="row">' + svg("users", "chevron") +
        '<div class="row-body"><span class="row-nom">Mon cercle de confiance</span>'
        '<span class="row-sous">Maman · Karim · Sofia · Awa · Yann</span></div></div>'
        '</div>'
        '<div class="bas"><button class="cta">' + svg("shield") + ' Démarrer le partage</button></div>',
        "1 · Partir", "Le contrat est écrit en toutes lettres avant le premier appui.",
        court=True)

    nominal += device(
        '<div class="etat"><span class="pouls"></span>En direct'
        '<span class="spacer"></span><span class="chrono">21:13</span></div>' +
        carte_geo(pins=(pin(44, 55), drapeau(44, 42, "Vous"), pin(84, 20, "but"))) +
        '<div class="rows"><div class="row">'
        '<div class="row-body"><span class="row-nom">Arrivée prévue 21:45</span>'
        '<span class="row-sous mono">5 personnes suivent · maj il y a 8 s</span></div></div></div>'
        '<div class="bas"><button class="cta fantome mini">' + svg("stop") + ' Arrêter</button></div>',
        "2 · Suivre", "La position bouge, l'état ne change pas.", court=True)

    nominal += device(
        '<div class="etat attente">' + svg("clock", "", 15) + ' À confirmer'
        '<span class="spacer"></span><span class="chrono">+02:10</span></div>' +
        carte_geo(pins=(pin(82, 24), drapeau(82, 12, "Vous"), pin(84, 20, "but")),
                  halo=(240, 46, 34)) +
        '<div class="voile"></div>'
        '<div class="feuille"><span class="poignee"></span>'
        '<h4>Vous êtes arrivée ?</h4>'
        '<p>Vous êtes à votre destination depuis une minute.</p>'
        '<button class="cta vert">' + svg("check") + ' Oui, je suis bien arrivée</button>'
        '<div class="duo"><button class="cta fantome mini">+15 min</button>'
        '<button class="cta fantome mini">Pas encore</button></div></div>',
        "3 · Confirmer", "Le GPS propose. Il ne clôt jamais tout seul.", court=True)

    nominal += device(
        '<div class="etat">' + svg("check", "", 15) + ' Trajet confirmé'
        '<span class="spacer"></span><span class="chrono">21:38</span></div>' +
        '<div class="frise">'
        '<div class="ev" data-k="ok"><span class="h">21:12</span>'
        '<span class="axe"><i></i><u></u></span>'
        '<span class="txt"><b>Trajet démarré</b><br>Partagé avec le cercle · 5 personnes</span></div>'
        '<div class="ev"><span class="h">21:19</span><span class="axe"><i></i><u></u></span>'
        '<span class="txt">Maman a vu</span></div>'
        '<div class="ev"><span class="h">21:36</span><span class="axe"><i></i><u></u></span>'
        '<span class="txt">Destination atteinte</span></div>'
        '<div class="ev" data-k="ok"><span class="h">21:38</span><span class="axe"><i></i></span>'
        '<span class="txt"><b>Arrivée confirmée</b><br>26 minutes · 4,1 km</span></div>'
        '</div>'
        '<div class="hint grandit">La trace détaillée sera effacée dans 24 heures.'
        ' Le trajet reste dans votre historique.</div>'
        '<div class="bas"><button class="cta fantome mini">' + svg("trash") +
        ' Supprimer ce trajet</button></div>',
        "4 · Clore", "Ce qui reste : le fait, pas le tracé.", court=True)

    # Chemin d'alerte : même départ, silence, puis escalade.
    alerte = ""
    alerte += device(
        '<div class="etat attente">' + svg("clock", "", 15) + ' À confirmer'
        '<span class="spacer"></span><span class="chrono">+07:00</span></div>' +
        '<div class="sos-zone">'
        '<div class="decompte">3:00</div>'
        '<h4>Confirmez votre arrivée</h4>'
        '<p>Sans réponse, vos cinq proches seront prévenus avec votre dernière position.</p>'
        '<button class="cta vert">Je suis bien arrivée</button>'
        '<button class="cta fantome mini">Prolonger de 15 minutes</button>'
        '</div>',
        "A · Trois relances", "Le propriétaire seul est sollicité. Le cercle ne sait rien.",
        court=True)

    alerte += device(
        '<div class="etat alerte">' + svg("alert", "", 15) + ' Alerte envoyée'
        '<span class="spacer"></span><span class="chrono">21:55</span></div>' +
        carte_geo(route="M18 150 C 60 120, 78 78, 130 62", classe="alerte",
                  pins=(pin(45, 31, "sos"), drapeau(45, 19, "Dernier point"), pin(84, 20, "but")),
                  halo=(130, 62, 30)) +
        '<div class="rows"><div class="row">'
        '<div class="row-body"><span class="row-nom">Vos cinq proches ont été prévenus</span>'
        '<span class="row-sous mono">dernière position à 21:44 · à 60 m près</span>'
        '</div></div></div>'
        '<div class="bas"><button class="cta vert">Je vais bien, lever l\'alerte</button></div>',
        "B · Alerter", "Dix minutes après l'échéance, avec la dernière position connue.",
        court=True)

    alerte += device(
        '<div class="alerte-plein">'
        '<span class="quoi">Alerte trajet</span>'
        '<h4>Awa n\'a pas confirmé son arrivée</h4>'
        '<span class="ou">Dernière position à 21:44 · avenue Kennedy</span>'
        '<div class="encart">Elle devait arriver à 21:45. Son téléphone émettait encore'
        ' il y a 11 minutes.</div>'
        '</div>'
        '<div class="bas"><button class="cta rouge">' + svg("phone") + ' Appeler Awa</button>'
        '<button class="cta fantome mini">Voir la dernière position</button>'
        '<button class="cta fantome mini">Je m\'en occupe</button></div>',
        "C · Côté membre", "Une seule décision visible : joindre la personne.", court=True)

    alerte += device(
        '<div class="etat">' + svg("check", "", 15) + ' Alerte levée'
        '<span class="spacer"></span><span class="chrono">22:02</span></div>' +
        '<div class="frise">'
        '<div class="ev" data-k="ok"><span class="h">21:12</span>'
        '<span class="axe"><i></i><u></u></span><span class="txt"><b>Trajet démarré</b></span></div>'
        '<div class="ev"><span class="h">21:45</span><span class="axe"><i></i><u></u></span>'
        '<span class="txt">Échéance atteinte · 3 relances</span></div>'
        '<div class="ev" data-k="alerte"><span class="h">21:55</span>'
        '<span class="axe"><i></i><u></u></span>'
        '<span class="txt"><b>Alerte envoyée</b><br>5 destinataires</span></div>'
        '<div class="ev"><span class="h">21:58</span><span class="axe"><i></i><u></u></span>'
        '<span class="txt">Karim s\'en occupe</span></div>'
        '<div class="ev" data-k="ok"><span class="h">22:02</span><span class="axe"><i></i></span>'
        '<span class="txt"><b>Alerte levée par Awa</b></span></div></div>'
        '<div class="hint grandit">Une alerte émise ne se retire pas. Elle se résout — et'
        ' le journal la garde.</div>',
        "D · Résoudre", "Ce qui est parti reste parti. On le clôt, on ne l'efface pas.",
        court=True)

    corps = f"""  <section class="panel">
    <header>
      <h2>Le chemin nominal</h2>
      <p>Quatre temps, dans cet ordre, toujours. C'est la rampe qu'on retrouve en haut de
         chaque écran du propriétaire&nbsp;: partir, suivre, confirmer, clore.</p>
    </header>
    <div class="stage serre">{nominal}</div>
  </section>

  <section class="panel">
    <header>
      <h2>Le chemin d'alerte</h2>
      <p>Le départ est identique. Ce qui change, c'est le silence — et l'escalade tient le
         cercle à l'écart aussi longtemps que possible.</p>
    </header>
    <div class="stage serre">{alerte}</div>
  </section>

  <section class="panel">
    <header>
      <h2>Ce que garantit chaque état</h2>
      <p>La garantie de sûreté est l'échéance, pas la trace. Perdre la position est une
         information&nbsp;; ne pas confirmer est un incident.</p>
    </header>
    <div class="tableau"><table>
      <thead><tr><th>État</th><th>Le cercle voit</th><th>Ce qui le fait changer</th></tr></thead>
      <tbody>
        <tr><td><code>active</code></td><td>La position, en direct</td>
            <td>ETA atteinte, ou destination tenue 60&nbsp;s</td></tr>
        <tr><td><code>awaiting_confirm</code></td><td>Rien de plus — le cercle n'est pas
            sollicité</td><td>Confirmation, prolongation, ou 10&nbsp;min de grâce</td></tr>
        <tr><td><code>alert</code></td><td>L'alerte et la dernière position connue</td>
            <td>Confirmation tardive, ou plafond dur</td></tr>
        <tr><td><code>sos</code></td><td>L'alerte, immédiatement, sans échéance</td>
            <td>Le propriétaire, et lui seul</td></tr>
        <tr><td><code>closed_confirmed</code></td><td>«&nbsp;Awa est bien arrivée à
            21:38&nbsp;»</td><td>—&nbsp;terminal</td></tr>
      </tbody>
    </table></div>
    <div class="notes">
      <p class="note"><b>Une arrivée détectée ne clôt rien.</b> Elle pose la question. Le coût
         d'un faux positif devient une question à balayer, jamais un filet rompu.</p>
      <p class="note attention"><b>Perdre le signal n'exempte pas de confirmer.</b> Un tunnel,
         un GPS coupé, une application tuée&nbsp;: le cercle lit «&nbsp;position
         indisponible&nbsp;» et la chaîne d'échéance continue de tourner côté serveur.</p>
    </div>
  </section>"""

    return page("Alanya — Trajets de confiance · Le parcours",
                "Alanya · Trajets de confiance · Étape 7",
                "Partir, suivre, confirmer — ou alerter",
                "Deux chemins partent de la même feuille&nbsp;: celui où l'on confirme, et "
                "celui où le silence déclenche l'alerte. Entre les deux, dix minutes de grâce "
                "et trois relances qui ne dérangent que la personne concernée.",
                corps, COLOPHON)


# =====================================================================
#  Planche 2 — Partir
# =====================================================================

def planche_depart():
    ecrans = ""

    ecrans += device(
        appbar("Trajets de confiance") +
        '<div class="vide">'
        '<span class="rond">' + svg("users") + '</span>'
        '<h4>Votre cercle de confiance est vide</h4>'
        '<p>Choisissez jusqu\'à cinq proches. Eux seuls verront vos trajets, et seulement '
        'ceux que vous partagez.</p>'
        '<button class="cta">' + svg("plus") + ' Composer mon cercle</button>'
        '</div>'
        '<div class="hint">Le cercle est votre liste <b>Confiance</b>. Vous la retrouvez '
        'dans Profil › Listes de contacts.</div>',
        "Cercle vide",
        "État bloquant, mais utile : il renvoie là où l'on remplit la liste Confiance.")

    ecrans += device(
        appbar("Trajets de confiance") +
        '<div class="rows">'
        '<div class="row"><span class="avatar" style="background:var(--t-confiance)">C</span>'
        '<div class="row-body"><span class="row-nom">Mon cercle</span>'
        '<span class="row-sous">Maman · Karim · Sofia · Awa · Yann</span></div>'
        + svg("chevron", "chevron") + '</div></div>'
        '<div class="hint">Aucun trajet en cours.</div>'
        '<div class="rows">'
        '<div class="row">' + svg("car", "chevron") +
        '<div class="row-body"><span class="row-nom">Taxi</span>'
        '<span class="row-sous">Un déplacement, une arrivée attendue</span></div>'
        + svg("chevron", "chevron") + '</div>'
        '<div class="row">' + svg("pin", "chevron") +
        '<div class="row-body"><span class="row-nom">Rendez-vous</span>'
        '<span class="row-sous">Un lieu, une heure de retour</span></div>'
        + svg("chevron", "chevron") + '</div></div>'
        '<div class="hint grandit">Vos trajets passés restent visibles ici. '
        'Personne d\'autre n\'y a accès.</div>'
        '<div class="bas"><button class="cta">' + svg("shield") + ' Nouveau trajet</button>'
        '<button class="cta fantome mini">' + svg("alert") + ' Lancer un SOS</button></div>',
        "Cercle prêt",
        "Le SOS est atteignable sans démarrer de trajet — il en crée un.")

    ecrans += device(
        appbar("Localisation") +
        '<div class="sos-zone">'
        '<span class="rond" style="width:76px;height:76px;border-radius:50%;'
        'background:var(--brand-container);display:grid;place-items:center;color:var(--brand)">'
        + svg("pin", "", 34) + '</span>'
        '<h4>Autoriser «&nbsp;Toujours&nbsp;»</h4>'
        '<p>Sans cette autorisation, le partage s\'arrête dès que vous quittez '
        'l\'application — au moment précis où il sert.</p>'
        '</div>'
        '<div class="contrat">Alanya n\'utilise votre position que pendant un trajet '
        'que <b>vous</b> avez démarré. Jamais avant, jamais après.</div>'
        '<div class="bas"><button class="cta">Autoriser</button>'
        '<button class="cta fantome mini">Plus tard</button></div>',
        "Avant la demande système",
        "On explique avant que l'OS ne demande : c'est le seul moyen d'obtenir « Toujours ».")

    ecrans += device(
        appbar("Nouveau trajet") +
        rampe(0) +
        '<div class="rows">'
        '<div class="row">' + svg("car", "chevron") +
        '<div class="row-body"><span class="row-nom">Taxi</span></div>'
        '<span class="check" data-on="1">' + svg("check") + '</span></div>'
        '<div class="row">' + svg("pin", "chevron") +
        '<div class="row-body"><span class="row-nom">Domicile</span>'
        '<span class="row-sous mono">3.8480, 11.5021 · rayon 150 m</span></div>'
        + svg("chevron", "chevron") + '</div>'
        '<div class="row">' + svg("clock", "chevron") +
        '<div class="row-body"><span class="row-nom">Arrivée vers 21:45</span>'
        '<span class="row-sous">dans 32 minutes</span></div>'
        + svg("chevron", "chevron") + '</div>'
        '</div>'
        '<div class="hint">Une destination, une heure, ou les deux. Avec les deux, '
        'la première atteinte pose la question.</div>'
        '<div class="rows grandit"><div class="row">'
        '<div class="row-body"><span class="row-nom">Note pour le cercle</span>'
        '<span class="row-sous">Taxi jaune, plaque LT 4471</span></div></div></div>'
        '<div class="bas"><button class="cta">Continuer</button></div>',
        "Type, lieu, heure",
        "Trois lignes. On doit pouvoir partir en moins de vingt secondes.")

    ecrans += device(
        appbar("Confirmer le départ") +
        rampe(0) +
        '<div class="rows">'
        '<div class="row"><span class="avatar" style="background:var(--t-confiance)">C</span>'
        '<div class="row-body"><span class="row-nom">Votre cercle de confiance</span>'
        '<span class="row-sous">Maman · Karim · Sofia · Awa · Yann</span></div>'
        '<span class="compte">5</span></div>'
        '<div class="row">' + svg("car", "chevron") +
        '<div class="row-body"><span class="row-nom">Taxi vers Domicile</span>'
        '<span class="row-sous mono">arrivée 21:45 · rayon 150 m</span></div></div>'
        '</div>'
        '<div class="contrat">Vos <b>cinq proches</b> verront votre position en direct '
        'jusqu\'à <b>21:45</b>. Si vous n\'avez pas confirmé à <b>21:55</b>, ils seront '
        'prévenus avec votre dernière position.</div>'
        '<div class="hint grandit">Le cercle se modifie dans Profil › Listes de contacts, '
        'jamais au départ d\'un trajet. Personne n\'apprend qu\'il y entre ou en sort.</div>'
        '<div class="bas"><button class="cta">' + svg("shield") + ' Démarrer le partage</button>'
        '</div>',
        "Le contrat, puis le départ",
        "Aucune case à cocher : le cercle est l'audience, en entier.")

    corps = f"""  <section class="panel">
    <header>
      <h2>De la liste vide au départ</h2>
      <p>Cinq écrans, dont deux qu'on ne voit qu'une fois&nbsp;: la composition du cercle et
         l'explication de la permission.</p>
    </header>
    <div class="stage">{ecrans}</div>
  </section>

  <section class="panel">
    <header>
      <h2>Ce que le composeur impose</h2>
      <p>Trois règles qui ne sont pas négociables côté serveur, et qui doivent donc être
         lisibles côté écran.</p>
    </header>
    <div class="modele">
      <div class="fiche">
        <h3>Le cercle entier, toujours</h3>
        <p>Aucune case à cocher, aucune sous-sélection. Le cercle de confiance <em>est</em>
           l'audience du trajet&nbsp;: c'est ce qui permet de partir en un appui, et ce qui
           rend la promesse lisible.</p>
        <dl><dt>Source</dt><dd>contact_list kind = trust</dd></dl>
      </div>
      <div class="fiche">
        <h3>Cinq au maximum, au moins un</h3>
        <p>Le plafond de cinq est déjà appliqué en base. Un cercle vide bloque le
           départ&nbsp;: un trajet sans destinataire n'est pas de la sécurité, c'est un
           traceur.</p>
        <dl><dt>Plafond</dt><dd>contact_list.member_limit</dd>
            <dt>Refus</dt><dd>409 TRUST_LIST_EMPTY</dd></dl>
      </div>
      <div class="fiche">
        <h3>Un seul trajet ouvert</h3>
        <p>Si un trajet tourne déjà, l'écran d'accueil le montre au lieu de proposer d'en
           démarrer un second.</p>
        <dl><dt>Refus</dt><dd>409 TRIP_ALREADY_ACTIVE</dd></dl>
      </div>
    </div>
    <div class="notes">
      <p class="note"><b>Le contrat en toutes lettres.</b> «&nbsp;Si vous n'avez pas confirmé
         à 21:55, ils seront prévenus&nbsp;» est le seul élément de l'écran qui garantit que
         la personne a compris ce qu'elle déclenche. Les deux heures — échéance et grâce —
         sont écrites, pas déduites.</p>
      <p class="note bien"><b>Choisir l'audience se fait hors trajet.</b> On modifie son
         cercle dans Profil › Listes de contacts, à froid, et cette modification ne notifie
         personne — ni celui qui entre, ni celui qui sort. Au moment de partir, il n'y a plus
         rien à décider.</p>
      <p class="note attention"><b>Le cercle est figé au départ.</b> Retirer quelqu'un de sa
         liste Confiance pendant un trajet ne le retire pas du trajet en cours. Un geste
         explicite existe pour cela&nbsp;: révoquer un destinataire.</p>
    </div>
  </section>"""

    return page("Alanya — Trajets de confiance · Partir",
                "Alanya · Trajets de confiance · Étape 7",
                "Composer un trajet en moins de vingt secondes",
                "Le type, le lieu, l'heure, les destinataires — puis une phrase qui dit "
                "exactement ce qui se passera en cas de silence. C'est cette phrase, et non "
                "la carte, qui fait la promesse.",
                corps, COLOPHON)


# =====================================================================
#  Planche 3 — En cours (propriétaire)
# =====================================================================

def planche_en_cours():
    ecrans = ""

    ecrans += device(
        '<div class="etat"><span class="pouls"></span>En direct'
        '<span class="spacer"></span><span class="chrono">21:13</span></div>' +
        rampe(1) +
        carte_geo(pins=(pin(44, 55), drapeau(44, 42, "Vous"), pin(84, 20, "but"),
                        drapeau(84, 8, "Domicile", point=False))) +
        '<div class="rows">'
        '<div class="row"><div class="row-body">'
        '<span class="row-nom">Arrivée prévue 21:45</span>'
        '<span class="row-sous mono">4,1 km · maj il y a 8 s · à 22 m près</span></div>'
        '<span class="avatar xs" style="background:var(--brand)">M</span>'
        '<span class="avatar xs" style="background:var(--t-confiance);margin-left:-8px">K</span>'
        '<span class="avatar xs" style="background:#00796B;margin-left:-8px">S</span>'
        '<span class="avatar xs" style="background:#C2185B;margin-left:-8px">A</span>'
        '<span class="avatar xs" style="background:#455A64;margin-left:-8px">Y</span>'
        '</div></div>'
        '<div class="bas">'
        '<button class="cta vert">' + svg("check") + ' Je suis arrivée</button>'
        '<button class="cta fantome mini">' + svg("stop") + ' Arrêter le partage</button>'
        '</div>',
        "Trajet actif",
        "Deux destinataires, nommés. « Arrêter » est toujours à un appui.")

    ecrans += device(
        '<div class="etat attente">' + svg("clock", "", 15) + ' À confirmer'
        '<span class="spacer"></span><span class="chrono">+03:12</span></div>' +
        rampe(2) +
        carte_geo(pins=(pin(82, 24), drapeau(82, 12, "Vous"), pin(84, 20, "but")),
                  halo=(240, 46, 32)) +
        '<div class="voile"></div>'
        '<div class="feuille"><span class="poignee"></span>'
        '<h4>Tout va bien ?</h4>'
        '<p>Votre arrivée était prévue à 21:45. Sans réponse, vos cinq proches seront '
        'prévenus à 21:55.</p>'
        '<button class="cta vert">' + svg("check") + ' Je suis bien arrivée</button>'
        '<div class="duo">'
        '<button class="cta fantome mini">+15 min</button>'
        '<button class="cta fantome mini">+30 min</button></div>'
        '</div>',
        "Échéance atteinte",
        "Le cercle n'est pas encore sollicité. Prolonger tient en deux appuis.")

    ecrans += device(
        '<div class="etat neutre">' + svg("off", "", 15) + ' Position indisponible'
        '<span class="spacer"></span><span class="chrono">21:31</span></div>' +
        rampe(1) +
        carte_geo(route="M18 150 C 60 120, 78 78, 118 66", pale=True,
                  pins=(pin(41, 33, "perdu"), drapeau(41, 21, "Il y a 6 min", point=False),
                        pin(84, 20, "but"))) +
        '<div class="rows"><div class="row">' + svg("wifi", "chevron") +
        '<div class="row-body"><span class="row-nom">Le GPS ne répond plus</span>'
        '<span class="row-sous">Tunnel, parking, ou signal faible</span></div></div>'
        '<div class="row"><div class="row-body">'
        '<span class="row-nom">Votre cercle voit la même chose</span>'
        '<span class="row-sous mono">dernier point 21:25 · à 60 m près</span></div></div></div>'
        '<div class="contrat"><b>Ce n\'est pas une alerte.</b> Votre arrivée reste attendue '
        'à 21:45 — il faudra confirmer, même sans position.</div>'
        '<div class="bas"><button class="cta fantome mini">' + svg("stop") +
        ' Arrêter le partage</button></div>',
        "Signal perdu",
        "Le seul écran où la couleur doit rester neutre : gris, pas rouge.")

    ecrans += device(
        appbar("Discussions", "3", retour=False) +
        '<div class="rows grandit">'
        '<div class="row"><span class="avatar">K</span>'
        '<div class="row-body"><span class="row-nom">Karim</span>'
        '<span class="row-sous">Tu es partie ?</span></div>'
        '<span class="row-sous mono">21:14</span></div>'
        '<div class="row"><span class="avatar" style="background:var(--t-confiance)">M</span>'
        '<div class="row-body"><span class="row-nom">Maman</span>'
        '<span class="row-sous">Je te suis, fais attention</span></div>'
        '<span class="row-sous mono">21:13</span></div>'
        '<div class="row"><span class="avatar" style="background:#00796B">S</span>'
        '<div class="row-body"><span class="row-nom">Sofia</span>'
        '<span class="row-sous">Photo</span></div>'
        '<span class="row-sous mono">19:02</span></div>'
        '</div>'
        '<div class="bandeau"><span class="pouls"></span>Trajet en cours'
        '<span class="spacer"></span><span class="chrono">21:45</span>'
        + svg("chevron", "", 15) + '</div>'
        '<div class="nav">'
        '<span data-on="1"><i></i>Discussions</span><span><i></i>Appels</span>'
        '<span><i></i>Statuts</span><span><i></i>Réunions</span><span><i></i>Profil</span>'
        '</div>',
        "Bandeau persistant",
        "Visible sur les cinq onglets. Le sixième onglet sans en être un.")

    ecrans += device(
        appbar("Trajets de confiance") +
        '<div class="rows">'
        '<div class="row">' + svg("phone", "chevron") +
        '<div class="row-body"><span class="row-nom">Trajet en cours sur votre autre '
        'appareil</span><span class="row-sous">Pixel 7 · dernière position il y a 11 s</span>'
        '</div></div></div>' +
        carte_geo(pins=(pin(44, 55), pin(84, 20, "but")), pale=True) +
        '<div class="contrat">Un seul appareil émet la position. Sinon la trace passerait '
        'son temps à sauter d\'un endroit à l\'autre.</div>'
        '<div class="bas">'
        '<button class="cta">Suivre depuis cet appareil</button>'
        '<button class="cta fantome mini">Rester en lecture seule</button></div>',
        "Deuxième appareil",
        "Reprise explicite : l'ancien porteur est prévenu et arrête son service.")

    corps = f"""  <section class="panel">
    <header>
      <h2>L'écran du propriétaire, dans ses cinq états</h2>
      <p>La rampe en tête ne bouge jamais de place&nbsp;; c'est la couleur du bandeau qui
         porte l'état. On doit pouvoir lire la situation sans lire le texte.</p>
    </header>
    <div class="stage">{ecrans}</div>
  </section>

  <section class="panel">
    <header>
      <h2>Ce que la notification persistante doit dire</h2>
      <p>Android impose une notification tant que le service de localisation tourne. Son
         contenu n'est pas un détail d'implémentation.</p>
    </header>
    <div class="stage">
      <div class="device-block">
        <div class="device"><div class="screen court">
          <div class="verrou">
            <div class="heure">21:31</div>
            <div class="date">Jeudi 14 août</div>
            <div class="notif">
              <span class="app">Alanya · Trajet en cours</span>
              <span class="t">Partagé avec Maman, Karim, Sofia, Awa et Yann</span>
              <span class="c">Arrivée prévue 21:45 · position envoyée toutes les
                 50&nbsp;m</span>
              <span class="actions"><span>Arrêter</span><span>Ouvrir</span></span>
            </div>
          </div>
        </div></div>
        <p class="device-caption"><b>Écran verrouillé</b>Elle nomme les destinataires et
           offre « Arrêter » en un appui.</p>
      </div>
      <div class="interdit">
        <h3>Pourquoi c'est une contrainte de conception, pas de la décoration</h3>
        <ul>
          <li>Une notification de suivi qui ne dit pas <b>à qui</b> elle envoie la position
              se comporte comme un logiciel espion.</li>
          <li>Elle ne peut pas être masquée&nbsp;: c'est un service en avant-plan Android,
              et la pastille bleue sur iOS.</li>
          <li>«&nbsp;Arrêter&nbsp;» y figure toujours. Si arrêter demandait d'ouvrir
              l'application et de naviguer, arrêter deviendrait coûteux — donc
              punissable par quelqu'un qui regarde par-dessus l'épaule.</li>
          <li>Elle rappelle l'échéance&nbsp;: c'est le rappel le plus utile, et le seul
              qu'on est sûr de voir.</li>
        </ul>
      </div>
    </div>
    <div class="notes">
      <p class="note"><b>Trois régimes de position, pas une cadence fixe.</b> En régime
         nominal, une position tous les 50&nbsp;m avec un battement de 60&nbsp;s. À
         l'approche, 25&nbsp;m et 20&nbsp;s. En alerte, en continu. Le battement forcé sert
         à distinguer <em>immobile</em> de <em>traceur mort</em> — c'est exactement ce qu'un
         proche a besoin de savoir.</p>
      <p class="note attention"><b>Sous 15&nbsp;% de batterie</b>, le suivi ralentit et le
         cercle en est informé. Sous 5&nbsp;%, la dernière position est poussée avant
         extinction&nbsp;: un téléphone qui meurt est un signal, pas une disparition.</p>
    </div>
  </section>"""

    return page("Alanya — Trajets de confiance · En cours",
                "Alanya · Trajets de confiance · Étape 7",
                "Suivre, sans jamais confondre silence et danger",
                "Le trajet actif occupe cinq états côté propriétaire. Un seul est rouge — et "
                "ce n'est pas celui où le GPS a lâché.",
                corps, COLOPHON)


# =====================================================================
#  Planche 4 — Côté membre (la carte de type 9)
# =====================================================================

def tcard(liseré, titre, meta, action, apercu=True, alerte=False, action_cls=""):
    ap = apercu_mini(alerte) if apercu else ""
    act = f'<div class="suivre {action_cls}">{action}</div>' if action else ""
    mt = f'<span class="meta">{meta}</span>' if meta else ""
    return (f'<div class="tcard"><div class="liseré {liseré}"></div>'
            f'<div class="corps">'
            f'<div class="tete"><span class="avatar sm">A</span>'
            f'<span class="titre">{titre}</span></div>'
            f'{ap}{mt}</div>{act}</div>')


def vitrine(carte, legende, sous):
    """Une carte de type 9 seule, sur le fond d'une conversation."""
    return (f'<div class="device-block">'
            f'<div class="device" style="max-width:300px">'
            f'<div class="screen" style="min-height:0;padding:14px 12px;background:var(--bg)">'
            f'{carte}</div></div>'
            f'<p class="device-caption"><b>{legende}</b>{sous}</p></div>')


def planche_membre():
    fil_actif = (
        appbar("Awa", retour=True) +
        '<div class="fil">'
        '<div class="bulle">Je rentre, je te partage le trajet<span class="h">21:11</span></div>'
        + tcard("", "Awa a démarré un trajet",
                "Arrivée prévue 21:45 · maj il y a 8 s", "Suivre en direct")
        + '<div class="bulle moi">Reçu, je regarde<span class="h">21:14 · Vu</span></div>'
        '</div>'
        '<div class="bas"><button class="cta fantome mini">Message…</button></div>')

    fil_alerte = (
        appbar("Awa", retour=True) +
        '<div class="fil">'
        + tcard("alerte", "Awa n\'a pas confirmé son arrivée",
                "Dernière position 21:44 · avenue Kennedy",
                "Voir la dernière position", alerte=True, action_cls="rouge")
        + '<div class="sysline alerte">Alerte envoyée à 5 personnes · 21:55</div>'
        '<div class="bulle moi">J\'appelle<span class="h">21:56</span></div>'
        '<div class="sysline">Karim s\'en occupe · 21:58</div>'
        '</div>'
        '<div class="bas"><button class="cta rouge">' + svg("phone") + ' Appeler Awa</button>'
        '</div>')

    fils = (device(fil_actif, "La carte dans la conversation",
                   "Le message vit là où le membre passe déjà.") +
            device(fil_alerte, "La même carte, en alerte",
                   "L'incident écrit en plus une ligne système : elle, on ne l'efface pas."))

    etats = ""
    etats += vitrine(tcard("", "Awa a démarré un trajet",
                           "Arrivée prévue 21:45 · maj il y a 8 s", "Suivre en direct"),
                     "active", "Le seul état où la carte s'anime.")
    etats += vitrine(tcard("attente", "Awa devrait être arrivée",
                           "Échéance 21:45 · en attente de confirmation",
                           "Voir la position"),
                     "awaiting_confirm", "Le cercle voit, mais n'est pas sollicité.")
    etats += vitrine(tcard("alerte", "Awa n'a pas confirmé son arrivée",
                           "Dernière position 21:44 · à 60 m près",
                           "Voir la dernière position", alerte=True, action_cls="rouge"),
                     "alert", "Le titre dit le fait, pas une supposition.")
    etats += vitrine(tcard("alerte", "Awa a déclenché un SOS",
                           "21:29 · avenue Kennedy",
                           "Voir la dernière position", alerte=True, action_cls="rouge"),
                     "sos", "Plus fort qu'une alerte : ni échéance, ni grâce.")
    etats += vitrine(tcard("", "Awa est bien arrivée",
                           "21:38 · 26 minutes · 4,1 km", "Voir le récapitulatif",
                           apercu=False),
                     "closed_confirmed", "La carte se replie : plus de carte, plus de flux.")
    etats += vitrine(tcard("gris", "Awa a arrêté le partage",
                           "21:22 · avant l'échéance", "", apercu=False),
                     "closed_cancelled", "Ton neutre, délibérément. Arrêter n'est pas suspect.")
    etats += vitrine(tcard("gris", "Position indisponible",
                           "Dernier point il y a 6 min · arrivée prévue 21:45",
                           "Voir la dernière position", apercu=False),
                     "stale", "Gris, jamais rouge. Le silence n'est pas un incident.")
    etats += vitrine(tcard("gris", "Ce trajet n'est plus partagé avec vous",
                           "", "", apercu=False),
                     "revoked", "Pierre tombale. Aucune raison n'est donnée.")

    suivi = ""
    suivi += device(
        '<div class="etat"><span class="pouls"></span>Awa · en direct'
        '<span class="spacer"></span><span class="chrono">21:13</span></div>' +
        carte_geo(pins=(pin(44, 55), drapeau(44, 42, "Awa"), pin(84, 20, "but"),
                        drapeau(84, 8, "Domicile", point=False))) +
        '<div class="rows">'
        '<div class="row"><div class="row-body">'
        '<span class="row-nom">Arrivée prévue 21:45</span>'
        '<span class="row-sous mono">maj il y a 8 s · à 22 m près</span></div></div>'
        '<div class="row"><div class="row-body">'
        '<span class="row-nom">Vous et 4 autres personnes suivez</span>'
        '<span class="row-sous">Taxi jaune, plaque LT 4471</span></div></div></div>'
        '<div class="bas">'
        '<button class="cta fantome mini">' + svg("check") + ' J\'ai vu</button>'
        '<button class="cta fantome mini">' + svg("phone") + ' Appeler Awa</button></div>',
        "Suivre un trajet",
        "Aucun bouton ne clôt le trajet. Ce n'est pas au membre d'en décider.")

    suivi += device(
        appbar("Awa", retour=True) +
        '<div class="fil">'
        + tcard("", "Awa est bien arrivée", "21:38 · 26 minutes", "", apercu=False)
        + '<div class="sysline">Trajet clos · 21:38</div>'
        '<div class="bulle">Bien rentrée, merci d\'avoir suivi<span class="h">21:39</span>'
        '</div></div>'
        '<div class="hint">La trace détaillée n\'est plus consultable. Vous n\'avez pas '
        'accès aux trajets passés d\'Awa.</div>'
        '<div class="bas"><button class="cta fantome mini">Message…</button></div>',
        "Après la clôture",
        "Le membre n'a pas d'historique. C'est volontaire.")

    corps = f"""  <section class="panel">
    <header>
      <h2>La carte de trajet, dans la conversation</h2>
      <p>C'est la seule surface qu'un membre du cercle verra à coup sûr&nbsp;: elle reçoit
         déjà la notification, elle survit au redémarrage, elle reste dans l'archive. Un
         écran dédié seul serait invisible pour qui ignore l'existence de la
         fonctionnalité.</p>
    </header>
    <div class="stage">{fils}</div>
  </section>

  <section class="panel">
    <header>
      <h2>Les huit états de la carte</h2>
      <p>Un seul message par trajet, réécrit sur place à chaque transition — cinq à six fois
         au maximum. Les positions, elles, ne touchent jamais la conversation.</p>
    </header>
    <div class="stage">{etats}</div>
    <div class="notes">
      <p class="note"><b>La carte porte l'état, le socket porte le mouvement.</b> Réécrire le
         message à chaque position remonterait la conversation en tête de liste, rallumerait
         le compteur de non-lus et déclencherait une notification — toutes les huit secondes.
         Entre deux transitions, la vignette s'anime à partir du flux temps réel, sans
         écriture.</p>
      <p class="note bien"><b>La carte reste compacte.</b> Pas de vraie carte dans une bulle&nbsp;:
         conflit de défilement, tuiles chargées à l'infini dans l'historique, batterie
         gaspillée. La carte plein écran est à un appui.</p>
      <p class="note attention"><b>Un incident écrit une seconde ligne.</b> Une alerte ou un
         SOS ajoute un message système, en plus de la carte&nbsp;: si la carte est refermée
         ou la trace purgée, l'incident reste dans l'archive. Deux lignes au maximum par
         trajet.</p>
    </div>
  </section>

  <section class="panel">
    <header>
      <h2>Suivre, puis ne plus rien voir</h2>
      <p>Le membre a exactement deux gestes&nbsp;: dire qu'il a vu, et appeler. Il ne peut
         ni clore, ni consulter l'historique.</p>
    </header>
    <div class="stage">{suivi}</div>
    <div class="modele">
      <div class="fiche">
        <h3>Ce que le membre peut faire</h3>
        <p>Suivre en direct pendant le trajet · accuser réception («&nbsp;J'ai vu&nbsp;»,
           remonté au propriétaire) · appeler · quitter le suivi.</p>
      </div>
      <div class="fiche">
        <h3>Ce qu'il ne peut pas faire</h3>
        <p>Clore le trajet · demander une position · consulter les trajets passés ·
           savoir qui d'autre suit, au-delà du nombre.</p>
      </div>
      <div class="fiche">
        <h3>Pourquoi pas d'historique côté membre</h3>
        <p>Parce que «&nbsp;montre-moi où tu étais mardi&nbsp;» ne doit pas être une
           fonctionnalité. Le trajet se regarde pendant qu'il a lieu, et disparaît ensuite.</p>
      </div>
    </div>
  </section>"""

    return page("Alanya — Trajets de confiance · Côté membre",
                "Alanya · Trajets de confiance · Étape 7",
                "Un message qui change d'état, pas un flux de messages",
                "Le trajet arrive chez le proche là où il parle déjà avec la personne&nbsp;: "
                "dans la conversation. Un seul message, réécrit cinq fois au plus, et une "
                "carte plein écran à un appui.",
                corps, COLOPHON)


# =====================================================================
#  Planche 5 — Décider et alerter
# =====================================================================

def planche_alerte():
    decider = ""

    decider += device(
        '<div class="etat attente">' + svg("pin", "", 15) + ' Destination atteinte'
        '<span class="spacer"></span><span class="chrono">21:36</span></div>' +
        carte_geo(pins=(pin(82, 24), pin(84, 20, "but")), halo=(240, 46, 34)) +
        '<div class="voile"></div>'
        '<div class="feuille"><span class="poignee"></span>'
        '<h4>Vous êtes arrivée&nbsp;?</h4>'
        '<p>Vous êtes à votre destination depuis une minute.</p>'
        '<button class="cta vert">' + svg("check") + ' Oui, tout va bien</button>'
        '<button class="cta fantome mini">Pas encore, je continue</button></div>',
        "Arrivée détectée",
        "Ton doux : le GPS a une hypothèse, il ne l'impose pas.")

    decider += device(
        '<div class="etat attente">' + svg("clock", "", 15) + ' Échéance atteinte'
        '<span class="spacer"></span><span class="chrono">+07:00</span></div>' +
        '<div class="sos-zone">'
        '<div class="decompte">3:00</div>'
        '<h4>Confirmez votre arrivée</h4>'
        '<p>Sans réponse, vos cinq proches seront prévenus avec votre dernière position.</p>'
        '<button class="cta vert">Je suis bien arrivée</button>'
        '<div class="duo"><button class="cta fantome mini">+15 min</button>'
        '<button class="cta fantome mini">+30 min</button></div>'
        '</div>',
        "Troisième relance",
        "Ton insistant, décompte visible. Le cercle ne sait toujours rien.")

    decider += device(
        '<div class="etat"><span class="pouls"></span>Prolongé de 15 minutes'
        '<span class="spacer"></span><span class="chrono">22:00</span></div>' +
        rampe(1) +
        carte_geo(pins=(pin(70, 34), drapeau(70, 22, "Vous"), pin(84, 20, "but"))) +
        '<div class="rows"><div class="row"><div class="row-body">'
        '<span class="row-nom">Nouvelle arrivée prévue 22:00</span>'
        '<span class="row-sous mono">prolongé 1 fois · alerte à 22:10</span></div></div></div>'
        '<div class="contrat">Votre cercle a été informé&nbsp;: <b>«&nbsp;Awa a prolongé '
        'de 15 minutes&nbsp;»</b>. Cela rassure sans alerter.</div>'
        '<div class="bas"><button class="cta vert">' + svg("check") +
        ' Je suis arrivée</button></div>',
        "Prolongation",
        "Illimitée, deux appuis, et visible du cercle.")

    sos = ""
    sos += device(
        appbar("SOS") +
        '<div class="sos-zone">'
        '<div class="sos-bouton">SOS</div>'
        '<h4>Maintenez trois secondes</h4>'
        '<p>Vos cinq proches recevront une alerte avec votre position, immédiatement.</p>'
        '</div>'
        '<div class="hint">Le SOS ne prévient pas les secours. Il prévient votre cercle.</div>',
        "Armement",
        "Maintien long : une poche ne déclenche pas un SOS.")

    sos += device(
        appbar("SOS") +
        '<div class="sos-zone">'
        '<div class="decompte">5</div>'
        '<h4>Envoi dans 5 secondes</h4>'
        '<p>Maman, Karim, Sofia, Awa et Yann vont être prévenus.</p>'
        '<button class="cta fantome" style="min-height:56px;font-size:17px">Annuler</button>'
        '</div>',
        "Décompte annulable",
        "« Annuler » est le plus gros bouton de l'écran.")

    sos += device(
        '<div class="etat alerte">' + svg("alert", "", 15) + ' SOS envoyé'
        '<span class="spacer"></span><span class="chrono">21:29</span></div>' +
        '<div class="sos-zone">'
        '<div class="sos-bouton discret">Envoyé</div>'
        '<h4>Vos proches ont été prévenus</h4>'
        '<p>Aucun son, aucune vibration. Votre position continue d\'être partagée.</p>'
        '</div>'
        '<div class="contrat"><b>Mode discret.</b> L\'écran reste neutre&nbsp;: quelqu\'un '
        'qui le regarde par-dessus votre épaule ne voit rien d\'anormal.</div>'
        '<div class="bas"><button class="cta fantome mini">Fausse alerte, je vais bien'
        '</button></div>',
        "SOS envoyé",
        "Discrétion après l'envoi : c'est le moment le plus dangereux.")

    reception = ""
    reception += device(
        '<div class="alerte-plein">'
        '<span class="quoi">SOS</span>'
        '<h4>Awa a déclenché un SOS</h4>'
        '<span class="ou">21:29 · avenue Kennedy, Yaoundé</span>'
        '<div class="encart">Sa position continue d\'être partagée. Elle était en trajet '
        'depuis 17 minutes.</div>'
        '</div>'
        '<div class="bas">'
        '<button class="cta rouge">' + svg("phone") + ' Appeler Awa</button>'
        '<button class="cta fantome mini">Voir la position en direct</button>'
        '<button class="cta fantome mini">Je m\'en occupe</button></div>',
        "SOS reçu",
        "Plein écran, une décision dominante : joindre la personne.")

    reception += device(
        '<div class="verrou">'
        '<div class="heure">21:55</div>'
        '<div class="date">Jeudi 14 août</div>'
        '<div class="notif urgent">'
        '<span class="app">Alanya · Alerte trajet</span>'
        '<span class="t">Awa n\'a pas confirmé son arrivée</span>'
        '<span class="c">Elle devait arriver à 21:45. Dernière position à 21:44, '
        'avenue Kennedy.</span>'
        '<span class="actions"><span>Appeler</span><span>Voir</span></span>'
        '</div>'
        '<div class="notif">'
        '<span class="app">Alanya · Karim</span>'
        '<span class="t">Karim</span>'
        '<span class="c">Je l\'appelle</span>'
        '</div>'
        '</div>',
        "Sur écran verrouillé",
        "Les alertes passent outre le mode silencieux. Elles seules.")

    reception += device(
        '<div class="etat">' + svg("check", "", 15) + ' Alerte levée'
        '<span class="spacer"></span><span class="chrono">22:02</span></div>' +
        '<div class="fil">'
        + tcard("gris", "Awa a levé l'alerte", "22:02 · « Je vais bien »", "", apercu=False)
        + '<div class="sysline alerte">Alerte envoyée à 5 personnes · 21:55</div>'
        '<div class="sysline">Karim s\'en occupe · 21:58</div>'
        '<div class="bulle">Désolée, batterie morte dans le taxi'
        '<span class="h">22:03</span></div>'
        '</div>'
        '<div class="hint">La ligne d\'alerte reste. Une alerte se résout, elle ne '
        's\'efface pas.</div>',
        "Après la résolution",
        "Le journal garde la trace de ce qui est parti.")

    corps = f"""  <section class="panel">
    <header>
      <h2>Décider — l'arrivée, la relance, la prolongation</h2>
      <p>Trois écrans qui ne s'adressent qu'au propriétaire. Le cercle n'apprend rien tant
         que la grâce n'est pas écoulée.</p>
    </header>
    <div class="stage">{decider}</div>
    <div class="tableau"><table>
      <thead><tr><th>Moment</th><th>Qui est sollicité</th><th>Ton</th></tr></thead>
      <tbody>
        <tr><td>ETA moins 5 min</td><td>Le propriétaire, en silence</td>
            <td>«&nbsp;Vous arrivez bientôt&nbsp;?&nbsp;»</td></tr>
        <tr><td>ETA</td><td>Le propriétaire, notification prioritaire</td>
            <td>«&nbsp;Confirmez votre arrivée&nbsp;»</td></tr>
        <tr><td>ETA plus 3 et plus 7 min</td><td>Le propriétaire, relances</td>
            <td>Décompte visible</td></tr>
        <tr><td>ETA plus 10 min</td><td><b>Le cercle</b></td>
            <td>Alerte, avec la dernière position</td></tr>
      </tbody>
    </table></div>
    <div class="notes">
      <p class="note"><b>Dix minutes, et non cinq.</b> En deçà, chaque embouteillage devient
         une alerte — et le cercle apprend à ne plus les ouvrir. C'est le vrai mode de
         défaillance de ce genre de produit&nbsp;: pas l'alerte manquée, l'alerte qu'on
         ignore.</p>
    </div>
  </section>

  <section class="panel">
    <header>
      <h2>Le SOS — deux gestes, puis le silence</h2>
      <p>Accessible sans trajet en cours&nbsp;: dans ce cas il en crée un, sans destination
         ni heure, immédiatement en alerte.</p>
    </header>
    <div class="stage">{sos}</div>
    <div class="modele">
      <div class="fiche">
        <h3>Contre le déclenchement accidentel</h3>
        <p>Maintien de trois secondes, puis décompte annulable de cinq. Le SOS ne figure que
           sur l'écran de trajet et le bandeau&nbsp;: pas de widget d'accueil.</p>
      </div>
      <div class="fiche">
        <h3>Le mode discret</h3>
        <p>Après l'envoi&nbsp;: aucun son, aucune vibration, écran neutre. Quelqu'un qui
           regarde l'écran ne doit pas voir qu'une alerte est partie.</p>
      </div>
      <div class="fiche">
        <h3>Une fausse alerte se corrige</h3>
        <p>Elle ne s'efface pas. Une correction part au cercle en moins d'une minute, et
           l'alerte initiale reste au journal.</p>
      </div>
    </div>
  </section>

  <section class="panel">
    <header>
      <h2>Recevoir l'alerte</h2>
      <p>C'est le moment pour lequel toute la fonctionnalité existe. Une seule information
         dominante, une seule action évidente.</p>
    </header>
    <div class="stage">{reception}</div>
    <div class="notes">
      <p class="note attention"><b>Les alertes passent outre «&nbsp;Ne pas déranger&nbsp;».</b>
         Une alerte de sûreté qu'un réglage de silence peut étouffer n'est pas une alerte de
         sûreté. Le contournement s'arrête là&nbsp;: le démarrage d'un trajet est une
         notification ordinaire, sa clôture est silencieuse.</p>
      <p class="note"><b>Durée de vie courte&nbsp;: deux minutes.</b> Une alerte affichée
         trois heures après coup est du bruit, et elle décrédibilise les suivantes.</p>
    </div>
  </section>"""

    return page("Alanya — Trajets de confiance · Alerter",
                "Alanya · Trajets de confiance · Étape 7",
                "Confirmer, prolonger — ou déclencher",
                "Trois relances au propriétaire avant que le cercle n'entende quoi que ce "
                "soit. Et un SOS qui demande deux gestes pour partir, puis se tait.",
                corps, COLOPHON)


# =====================================================================
#  Planche 6 — Après le trajet
# =====================================================================

def planche_fin():
    ecrans = ""

    ecrans += device(
        '<div class="etat">' + svg("check", "", 15) + ' Trajet confirmé'
        '<span class="spacer"></span><span class="chrono">21:38</span></div>' +
        '<div class="frise">'
        '<div class="ev" data-k="ok"><span class="h">21:12</span>'
        '<span class="axe"><i></i><u></u></span>'
        '<span class="txt"><b>Trajet démarré</b><br>Taxi · partagé avec le cercle · 5 personnes</span>'
        '</div>'
        '<div class="ev"><span class="h">21:19</span><span class="axe"><i></i><u></u></span>'
        '<span class="txt">Maman a vu</span></div>'
        '<div class="ev"><span class="h">21:25</span><span class="axe"><i></i><u></u></span>'
        '<span class="txt">Position indisponible 4 min</span></div>'
        '<div class="ev"><span class="h">21:36</span><span class="axe"><i></i><u></u></span>'
        '<span class="txt">Destination atteinte</span></div>'
        '<div class="ev" data-k="ok"><span class="h">21:38</span><span class="axe"><i></i></span>'
        '<span class="txt"><b>Arrivée confirmée</b></span></div></div>'
        '<div class="rows"><div class="row"><div class="row-body">'
        '<span class="row-nom">26 minutes · 4,1 km</span>'
        '<span class="row-sous mono">trace conservée jusqu\'au 15/08 21:38</span>'
        '</div></div></div>'
        '<div class="bas"><button class="cta fantome mini">' + svg("trash") +
        ' Supprimer ce trajet</button></div>',
        "Récapitulatif",
        "La frise vient de trip_event. Elle dit aussi ce qui a raté.")

    ecrans += device(
        appbar("Historique", "18") +
        '<div class="rows grandit">'
        '<div class="histo-row"><span class="jalon">' + svg("check") + '</span>'
        '<div class="row-body"><span class="row-nom">Domicile</span>'
        '<span class="row-sous mono">14 août · 21:12 → 21:38 · 26 min</span></div>'
        + svg("chevron", "chevron") + '</div>'
        '<div class="histo-row"><span class="jalon alerte">' + svg("alert") + '</span>'
        '<div class="row-body"><span class="row-nom">Clinique Bastos</span>'
        '<span class="row-sous mono">9 août · alerte levée à 19:04</span></div>'
        + svg("chevron", "chevron") + '</div>'
        '<div class="histo-row"><span class="jalon">' + svg("check") + '</span>'
        '<div class="row-body"><span class="row-nom">Aéroport</span>'
        '<span class="row-sous mono">2 août · 05:40 → 06:22 · 42 min</span></div>'
        + svg("chevron", "chevron") + '</div>'
        '<div class="histo-row"><span class="jalon gris">' + svg("stop") + '</span>'
        '<div class="row-body"><span class="row-nom">Trajet arrêté</span>'
        '<span class="row-sous mono">28 juillet · 18:02 · avant l\'échéance</span></div>'
        + svg("chevron", "chevron") + '</div>'
        '</div>'
        '<div class="hint">Vos trajets sont conservés douze mois. Les traces détaillées, '
        'vingt-quatre heures.</div>',
        "Historique",
        "L'état se lit à la pastille avant de lire la ligne.")

    ecrans += device(
        appbar("Historique") +
        '<div class="vide">'
        '<span class="rond">' + svg("shield") + '</span>'
        '<h4>Aucun trajet pour l\'instant</h4>'
        '<p>Quand vous partagerez un trajet, il apparaîtra ici — et seulement ici.</p>'
        '<button class="cta">' + svg("shield") + ' Démarrer un trajet</button>'
        '</div>',
        "Historique vide",
        "L'état vide explique la fonctionnalité plutôt que de constater le vide.")

    ecrans += device(
        appbar("Confidentialité des trajets") +
        '<div class="rows">'
        '<div class="row">' + svg("eye", "chevron") +
        '<div class="row-body"><span class="row-nom">Qui voit vos trajets</span>'
        '<span class="row-sous">Uniquement les personnes cochées, pendant le trajet</span>'
        '</div></div>'
        '<div class="row">' + svg("clock", "chevron") +
        '<div class="row-body"><span class="row-nom">Trace détaillée</span>'
        '<span class="row-sous mono">effacée 24 h après la clôture</span></div></div>'
        '<div class="row">' + svg("shield", "chevron") +
        '<div class="row-body"><span class="row-nom">Historique</span>'
        '<span class="row-sous mono">12 mois, ou jusqu\'à suppression</span></div></div>'
        '<div class="row">' + svg("lock", "chevron") +
        '<div class="row-body"><span class="row-nom">Alanya</span>'
        '<span class="row-sous">N\'accède à aucune de vos positions</span></div></div>'
        '</div>'
        '<div class="contrat">Un trajet clos par une <b>alerte</b> est conservé 30 jours '
        'avant de pouvoir être supprimé.</div>'
        '<div class="hint grandit">Cette règle protège la personne, pas le service&nbsp;: '
        'elle empêche qu\'on contraigne quelqu\'un à effacer la trace d\'un incident.</div>'
        '<div class="bas"><button class="cta fantome mini">' + svg("trash") +
        ' Supprimer tout mon historique</button></div>',
        "Confidentialité",
        "La règle la plus contre-intuitive du volet, expliquée là où elle se subit.")

    corps = f"""  <section class="panel">
    <header>
      <h2>Ce qui reste après le trajet</h2>
      <p>Deux étages de conservation&nbsp;: la trace disparaît vite, le fait reste. C'est ce
         qui permet d'avoir un historique utile sans constituer un registre de déplacements.</p>
    </header>
    <div class="stage">{ecrans}</div>
  </section>

  <section class="panel">
    <header>
      <h2>Le tableau de rétention, tel qu'il est écrit dans l'application</h2>
      <p>Ces trois lignes sont les mêmes que celles du dossier technique&nbsp;: l'écran ne
         dit rien de plus, ni de moins, que ce que fait la purge nocturne.</p>
    </header>
    <div class="tableau"><table>
      <thead><tr><th>Donnée</th><th>Trajet normal</th><th>Trajet clos par une alerte</th>
                 <th>Pourquoi</th></tr></thead>
      <tbody>
        <tr><td><code>trip_point</code><br>la trace</td><td>24 h après clôture</td>
            <td>30 jours</td>
            <td>Un registre permanent des déplacements de tous les utilisateurs n'est
                justifié par aucun besoin. En cas d'incident, la trace peut servir de
                preuve.</td></tr>
        <tr><td><code>trip</code><br>le fait</td><td>12 mois</td><td>12 mois</td>
            <td>L'historique se contente du départ, de l'arrivée, de la durée et de
                l'issue.</td></tr>
        <tr><td><code>trip_event</code><br>le journal</td><td>12 mois</td><td>12 mois</td>
            <td>C'est la source de la frise, et la seule mémoire de ce qui a été notifié à
                qui.</td></tr>
      </tbody>
    </table></div>
    <div class="notes">
      <p class="note attention"><b>Le verrou de 30 jours n'est pas une contrainte
         technique.</b> C'est une mesure anti-coercition&nbsp;: quelqu'un ne doit pas pouvoir
         contraindre un proche à effacer la trace d'un incident dans la minute. On l'explique
         dans l'écran plutôt que de la faire découvrir par un refus.</p>
      <p class="note bien"><b>Le membre n'a pas d'historique</b>, et cet écran le dit
         explicitement — c'est ce qui empêche la fonctionnalité de devenir un outil de
         contrôle a posteriori.</p>
    </div>
  </section>"""

    return page("Alanya — Trajets de confiance · Après",
                "Alanya · Trajets de confiance · Étape 7",
                "Garder le fait, oublier le tracé",
                "L'historique doit être utile sans devenir un registre de déplacements. "
                "Deux étages de conservation, et une exception assumée pour les incidents.",
                corps, COLOPHON)


# =====================================================================
#  Planche 7 — États dégradés et administration
# =====================================================================

def planche_erreurs():
    ecrans = ""

    ecrans += device(
        appbar("Nouveau trajet") +
        '<div class="vide">'
        '<span class="rond" style="color:var(--t-attente)">' + svg("off") + '</span>'
        '<h4>La localisation est refusée</h4>'
        '<p>Sans position, vous pouvez quand même annoncer une heure d\'arrivée&nbsp;: vos '
        'proches seront prévenus si vous ne confirmez pas.</p>'
        '<button class="cta">Ouvrir les réglages</button>'
        '<button class="cta fantome mini">Partir sans position</button>'
        '</div>'
        '<div class="hint">Le filet de sécurité ne dépend pas du GPS. Il dépend de '
        'l\'échéance.</div>',
        "Permission refusée",
        "Dégradation, pas panne : l'échéance seule suffit à protéger.")

    ecrans += device(
        appbar("Trajet en cours") +
        '<div class="etat attente">' + svg("battery", "", 15) + ' Batterie faible'
        '<span class="spacer"></span><span class="chrono">11 %</span></div>' +
        carte_geo(pins=(pin(58, 44), drapeau(58, 32, "Vous"), pin(84, 20, "but")), pale=True) +
        '<div class="rows"><div class="row"><div class="row-body">'
        '<span class="row-nom">Suivi ralenti</span>'
        '<span class="row-sous">Une position toutes les 2 minutes au lieu de 50 mètres</span>'
        '</div></div>'
        '<div class="row"><div class="row-body">'
        '<span class="row-nom">Votre cercle a été informé</span>'
        '<span class="row-sous mono">« batterie faible — suivi ralenti »</span>'
        '</div></div></div>'
        '<div class="contrat">Si votre téléphone s\'éteint, votre <b>dernière position</b> '
        'sera envoyée avant extinction.</div>',
        "Batterie faible",
        "Un téléphone qui meurt est un signal, pas une disparition.")

    ecrans += device(
        appbar("Trajet en cours") +
        '<div class="etat neutre">' + svg("wifi", "", 15) + ' Hors ligne'
        '<span class="spacer"></span><span class="chrono">4 min</span></div>' +
        carte_geo(route="M18 150 C 60 120, 78 78, 118 66", pale=True,
                  pins=(pin(41, 33, "perdu"), pin(84, 20, "but"))) +
        '<div class="rows"><div class="row"><div class="row-body">'
        '<span class="row-nom">37 positions en attente d\'envoi</span>'
        '<span class="row-sous mono">elles partiront avec leur heure réelle</span>'
        '</div></div>'
        '<div class="row"><div class="row-body">'
        '<span class="row-nom">Votre cercle voit « position indisponible »</span>'
        '<span class="row-sous">Dernier point reçu à 21:25</span></div></div></div>'
        '<div class="contrat">L\'échéance de <b>21:45</b> tient quand même&nbsp;: elle est '
        'gardée par le serveur, pas par votre téléphone.</div>',
        "Hors ligne",
        "Le tampon local repart avec les horodatages réels, sans doublon.")

    ecrans += device(
        '<div class="etat attente">' + svg("users", "", 15) + ' Plus aucun destinataire'
        '<span class="spacer"></span><span class="chrono">4:38</span></div>' +
        '<div class="sos-zone">'
        '<span class="rond" style="width:70px;height:70px;border-radius:50%;'
        'background:var(--t-attente-bg);display:grid;place-items:center;color:var(--t-attente)">'
        + svg("users", "", 32) + '</span>'
        '<h4>Personne ne suit votre trajet</h4>'
        '<p>Choisissez quelqu\'un d\'autre, ou arrêtez le partage. Sans réponse, le trajet '
        's\'arrêtera tout seul dans 5 minutes.</p>'
        '<button class="cta">Choisir un autre proche</button>'
        '<button class="cta fantome mini">Arrêter le partage</button>'
        '</div>',
        "Cercle vidé en cours de route",
        "Un trajet sans destinataire n'est plus de la sécurité : c'est un traceur.")

    admin = """  <section class="panel">
    <header>
      <h2>Administration — des compteurs, et rien d'autre</h2>
      <p>Aucune coordonnée, aucun identifiant de compte, aucune destination, aucune identité
         de destinataire. La seule page d'administration du volet.</p>
    </header>
    <div class="kpis">
      <div class="kpi"><span class="lib">Trajets démarrés</span><span class="val">1 284</span>
        <span class="var">7 jours · +12 %</span>
        <svg class="spark" viewBox="0 0 120 34" aria-hidden="true">
          <path class="aire" d="M0 28 L18 24 L36 26 L54 17 L72 19 L90 11 L108 9 L120 6
                                L120 34 L0 34 Z"/>
          <path class="trait" d="M0 28 L18 24 L36 26 L54 17 L72 19 L90 11 L108 9 L120 6"/>
          <circle cx="120" cy="6" r="2.6"/>
        </svg>
      </div>
      <div class="kpi"><span class="lib">Confirmés</span>
        <span class="val vert">96,4 %</span><span class="var">1 238 sur 1 284</span></div>
      <div class="kpi"><span class="lib">Clos par une alerte</span>
        <span class="val rouge">31</span><span class="var">2,4 % · dont 4 SOS</span></div>
      <div class="kpi"><span class="lib">Durée médiane</span>
        <span class="val">23 min</span><span class="var">p90 · 51 min</span></div>
      <div class="kpi"><span class="lib">Prolongations</span>
        <span class="val">0,7</span><span class="var">par trajet</span></div>
      <div class="kpi"><span class="lib">Alertes levées</span>
        <span class="val">27 sur 31</span><span class="var">délai médian 6 min</span></div>
    </div>
    <div class="modele">
      <div class="interdit">
        <h3>Ce que cette page ne montrera jamais</h3>
        <ul>
          <li>Aucune coordonnée, aucune trace, aucune destination.</li>
          <li>Aucun nom, aucun identifiant de compte, aucun cercle.</li>
          <li>Aucun trajet individuel — même clos par une alerte.</li>
          <li>Aucune carte. Le composant existe déjà dans l'administration&nbsp;; il n'est
              pas branché ici.</li>
        </ul>
      </div>
      <div class="interdit">
        <h3>Deux options examinées, puis écartées</h3>
        <ul>
          <li>Un <b>registre d'incidents pseudonymisé</b> aiderait le support à vérifier que
              la chaîne d'escalade fonctionne.</li>
          <li>Un <b>bris de glace</b> à quatre yeux, avec justification, expiration et
              notification à la personne, aiderait en cas d'incident réel.</li>
          <li>Les deux sont écartés pour cette étape&nbsp;: la posture la plus défendable est
              celle où la donnée n'est pas accessible. Et la rétention l'emporte de toute
              façon — à 24&nbsp;h de conservation, il n'y a presque rien à consulter.</li>
        </ul>
      </div>
    </div>
  </section>"""

    corps = f"""  <section class="panel">
    <header>
      <h2>Quand ça se dégrade</h2>
      <p>Quatre situations qui arrivent tous les jours. Aucune n'est rouge&nbsp;: le rouge
         est réservé à l'alerte et au SOS, sans quoi il ne veut plus rien dire.</p>
    </header>
    <div class="stage">{ecrans}</div>
    <div class="notes">
      <p class="note"><b>Une couleur, une signification.</b> Vert&nbsp;: tout va bien.
         Ambre&nbsp;: quelque chose demande votre attention. Gris&nbsp;: on ne sait pas.
         Rouge&nbsp;: le cercle a été prévenu. Un GPS perdu est gris, pas rouge — c'est la
         règle la plus importante de la palette du volet.</p>
      <p class="note bien"><b>Chaque écran dégradé rappelle que l'échéance tient.</b> C'est
         ce qui distingue une dégradation d'une panne, et c'est la seule chose que
         l'utilisateur a besoin de savoir à ce moment-là.</p>
    </div>
  </section>

{admin}"""

    return page("Alanya — Trajets de confiance · États et administration",
                "Alanya · Trajets de confiance · Étape 7",
                "Ce qui se dégrade, et ce que personne ne voit",
                "Le GPS lâche, la batterie tombe, le réseau saute&nbsp;: rien de tout cela "
                "n'est un incident. Et du côté de l'administration, il n'y a que des "
                "compteurs.",
                corps, COLOPHON)


# =====================================================================
#  Sortie
# =====================================================================

PLANCHES = [
    ("trajets-parcours.html",       planche_parcours),
    ("trajets-depart.html",         planche_depart),
    ("trajets-en-cours.html",       planche_en_cours),
    ("trajets-membre.html",         planche_membre),
    ("trajets-alerte.html",         planche_alerte),
    ("trajets-fin-historique.html", planche_fin),
    ("trajets-erreurs-admin.html",  planche_erreurs),
]


def main():
    for nom, fn in PLANCHES:
        chemin = os.path.join(SORTIE, nom)
        with open(chemin, "w", encoding="utf-8") as f:
            f.write(fn())
        print(f"  {nom}  ({os.path.getsize(chemin) // 1024} ko)")


if __name__ == "__main__":
    print("Planches « Trajets de confiance » :")
    main()
