#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Produit les captures PNG des planches « Trajets de confiance » (étape 7).

Les planches sont au format Artifact (elles commencent à <title>, sans <!DOCTYPE>).
Pour les photographier, on les enveloppe à la volée dans un document complet, on
masque le chapô et le colophon, et on ne garde que la ou les sections utiles — c'est
ce que montrent les PNG déjà versionnés : une rangée d'appareils, pas la page entière.

Dépendances : google-chrome (headless) et Pillow.
Usage :  python3 _capture_trajets.py
"""

import os
import subprocess
import sys
import tempfile

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
CHROME = "/usr/bin/google-chrome"
# 1720 px : assez large pour que cinq appareils tiennent sur une seule rangée.
# \imageOuCadre n'impose que la largeur (\includegraphics[width=...]) — une figure
# plus haute que large déborderait la page A4. On vise un rapport d'au moins 1,3.
LARGEUR = 1720
HAUTEUR_MAX = 4200
MARGE = 18          # marge conservée autour du contenu, après rognage

# planche -> sections à photographier (1-indexé, dans l'ordre de la page)
CIBLES = [
    ("trajets-parcours.html",       [1, 2]),
    ("trajets-depart.html",         [1]),
    ("trajets-en-cours.html",       [1]),
    ("trajets-membre.html",         [1, 2]),
    ("trajets-alerte.html",         [2, 3]),
    ("trajets-fin-historique.html", [1]),
    ("trajets-erreurs-admin.html",  [1, 2]),
]


def surcharges(sections):
    """CSS de capture : on force le thème clair et on isole les sections voulues."""
    gardees = ", ".join(f'.wrap > section:nth-of-type({n})' for n in sections)
    return f"""
    html, body {{ margin: 0; padding: 0; background: #EEF0F7; }}
    .page {{ min-height: 0; padding: {MARGE}px; }}
    .wrap {{ gap: 34px; max-width: none; }}
    .masthead, footer.colophon {{ display: none; }}
    .wrap > section {{ display: none; }}
    {gardees} {{ display: flex; }}
    .panel {{ border: none; padding: 0; background: transparent; }}
    .panel > header {{ display: none; }}
    /* Le rendu est figé : pas d'animation à photographier. */
    *, *::before, *::after {{ animation: none !important; transition: none !important; }}
    """


def enveloppe(source, sections):
    """Le fichier versionné reste intact : on n'enveloppe qu'une copie temporaire."""
    contenu = open(source, encoding="utf-8").read()
    tete, corps = contenu.split("</style>", 1)
    return (f'<!DOCTYPE html><html lang="fr" data-theme="light"><head>'
            f'<meta charset="utf-8">{tete}</style>'
            f'<style>{surcharges(sections)}</style></head>'
            f'<body>{corps}</body></html>')


def rogner(chemin):
    """Retire le fond uniforme autour du contenu, puis rend une marge régulière."""
    im = Image.open(chemin).convert("RGB")
    fond = im.getpixel((2, 2))
    masque = Image.new("RGB", im.size, fond)
    from PIL import ImageChops
    boite = ImageChops.difference(im, masque).getbbox()
    if not boite:
        return im.size
    g, h, d, b = boite
    g, h = max(0, g - MARGE), max(0, h - MARGE)
    d, b = min(im.width, d + MARGE), min(im.height, b + MARGE)
    im.crop((g, h, d, b)).save(chemin, optimize=True)
    return (d - g, b - h)


def capturer(nom, sections):
    source = os.path.join(ICI, nom)
    cible = os.path.join(ICI, nom.replace(".html", ".png"))

    with tempfile.TemporaryDirectory() as tmp:
        page = os.path.join(tmp, "page.html")
        with open(page, "w", encoding="utf-8") as f:
            f.write(enveloppe(source, sections))

        subprocess.run(
            [CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
             "--force-color-profile=srgb", "--default-background-color=EEF0F7",
             f"--window-size={LARGEUR},{HAUTEUR_MAX}",
             f"--screenshot={cible}", f"--user-data-dir={tmp}/profil",
             "--virtual-time-budget=2500", f"file://{page}"],
            check=True, capture_output=True, timeout=120,
        )

    return rogner(cible)


def main():
    print("Captures « Trajets de confiance » :")
    for nom, sections in CIBLES:
        try:
            l, h = capturer(nom, sections)
            png = nom.replace(".html", ".png")
            ko = os.path.getsize(os.path.join(ICI, png)) // 1024
            print(f"  {png:32s} {l}x{h}  ({ko} ko)  sections {sections}")
        except subprocess.CalledProcessError as e:
            print(f"  {nom}: ECHEC — {e.stderr.decode()[:300]}", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
