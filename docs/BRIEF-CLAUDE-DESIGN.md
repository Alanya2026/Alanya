# Brief Claude Design — Client web Alanya


## 1. Le produit

Alanya est un **messager grand public** (concurrence WhatsApp / Telegram), déjà en
production sur Android et iOS. Je construis maintenant son **client web**, qui parle au
même backend.

C'est un **client compagnon** : l'utilisateur garde son téléphone comme appareil
principal et retrouve ses conversations dans un onglet de navigateur, au clavier, sur
grand écran. Modèle mental : WhatsApp Web / Telegram Desktop.

Public : grand public francophone, Cameroun et diaspora. Interface **en français**.
Beaucoup d'utilisateurs sont sur des connexions lentes et des écrans d'entrée de gamme.

Ce qui doit transparaître : **fiabilité et calme**. C'est un outil qu'on laisse ouvert
huit heures par jour. La densité d'information compte plus que l'effet.

---

## 2. Contraintes non négociables — tokens

Reprendre ces valeurs exactement. Elles existent déjà dans l'app mobile ; tout écart
rendrait le web et le mobile visiblement différents.

```css
/* Marque — indigo unifié */
--brand:            #3F51B5;   /* boutons, accents, états actifs, bulles envoyées */
--brand-strong:     #303F9F;   /* hover / pressed */
--brand-dark:       #1A237E;
--brand-darker:     #0D123E;   /* fond du rail de navigation */
--brand-lift:       #7986CB;   /* accent texte en mode sombre uniquement */
--brand-container:  #E8EAF6;   /* fonds teintés, sélection */
--brand-tint:       #F2F3FB;

/* Sceau officiel — le SEUL accent chaud */
--gold:             #C9A227;

/* Neutres — clair */
--paper: #F6F7FB;  --surface: #FFFFFF;  --surface-muted: #F4F5F8;
--surface-subtle: #EDEFF4;  --line: #E2E5EC;  --line-strong: #CBD0E0;

/* Texte — clair */
--ink: #1A1D23;  --ink-2: #5B6273;  --ink-3: #9AA0AE;

/* Sémantiques */
--success: #1FA363;  /* = indicateur « en ligne » */
--error:   #EF4444;
--warning: #F59E0B;
--info:    #2E90FA;  /* = accusé de lecture (double coche lue) */

/* Neutres — sombre */
--paper: #0F1115;  --surface: #181B21;  --surface-muted: #1F232B;
--line: #2C313B;  --line-strong: #3A404C;
--ink: #F2F4F8;  --ink-2: #AAB1C0;  --ink-3: #6F7787;

/* Immersif — appels et réunions uniquement */
--immersive-bg: #0E1330;  --immersive-surface: #1B2147;

/* Listes de contacts (fonctionnalité à venir) */
--famille: #C2185B;  --amis: #00796B;  --bureau: #3949AB;
```

**Règles d'usage strictes :**

- L'**or `#C9A227`** ne porte que l'**autorité** : badge vérifié, compte officiel, liseré
  de la conversation active, pastille du rail. **Jamais** une couleur d'action — il perdrait
  son sens.
- En **mode sombre**, l'indigo plein reste le fond des boutons (blanc sur `#3F51B5` ≈ 5,9:1),
  mais le **texte** accentué et les liens passent à `--brand-lift #7986CB`, faute de contraste.
- **Light et dark sont tous deux de premier rang.** Aucun écran ne doit être conçu pour un
  seul des deux.

---

## 3. Direction artistique

**Concept : « Encre » — la messagerie comme correspondance.**

- **Serif éditorial** réservé aux rares moments de marque : écran de connexion, états vides,
  wordmark. **Jamais** dans une bulle de message ni dans la liste de conversations.
  Aucun messager ne fait de serif : c'est ce qui rend Alanya reconnaissable.
- **Sans humaniste** pour 95 % de l'interface. Doit être excellent à 13–15 px, avec de vrais
  accents français.
- **Mono** pour ce qui est un identifiant et non une phrase : numéros Alanya, codes OTP,
  durées, horodatages (chiffres de largeur fixe — l'heure ne doit pas faire vibrer la mise
  en page à chaque minute).

Suggestion de trio, à remplacer si tu trouves mieux : **Instrument Serif** (display),
**Onest** (interface), **DM Mono** (identifiants). Éviter Inter, Roboto, Space Grotesk.

**Détails de signature à installer :**
- Grain papier très léger sur le canvas de conversation (opacité ≈ 0,03 en clair, 0,05 en sombre).
- Conversation active : liseré or de 3 px à gauche + fond légèrement teinté indigo.
- Bulle envoyée : indigo plein avec un liseré intérieur haut `inset 0 1px 0 rgba(255,255,255,.14)` —
  l'encre qui capte la lumière.
- Séparateurs de jour : filet réglé + petites capitales espacées.
- Réactions : pastille chevauchant le bord bas de la bulle.

**À proscrire :** dégradés violets sur blanc, ombres portées lourdes, coins ultra-arrondis
partout, icônes décoratives géantes, cartes dans des cartes dans des cartes.

---

## 4. Gabarit — adaptatif 2 ↔ 3 panneaux

```
≥ 1600 px   rail(68) | liste(300–372) | fil(1fr) | panneau détail(280–340)
900–1600    rail(68) | liste(300–372) | fil(1fr)        ← le détail devient un panneau glissant
< 900       une seule colonne, le retour ramène à la liste ← sert aussi de mobile web
```

- **Rail** : fond `--brand-darker`, icônes seules, onglet actif marqué par un trait or à gauche.
  Entrées : Conversations, Appels, Statuts, Réunions, puis Réglages et avatar en bas.
- **Liste** : barre de recherche + filtres segmentés (Toutes / Non lues / Groupes).
- **Fil** : barre supérieure translucide (`backdrop-filter`), zone de messages ancrée en bas,
  composeur fixe.
- La liste de messages doit être pensée **virtualisée** (des milliers d'entrées).

---

## 5. Inventaire des écrans

### Fondations (3)
1. **Couleurs** — nuanciers clair + sombre, usage de l'or, contrastes.
2. **Typographie** — échelle complète, rôles de chaque famille, repli système.
3. **Gabarit & mouvement** — grille des 3 largeurs, espacement base 4, rayons, ombres, durées.

### Composants (5)
4. **Actions** — boutons (primaire, secondaire, fantôme, danger, or), boutons-icônes, segmenté, interrupteur.
5. **Saisie** — champs, recherche, champ OTP, composeur de message, états d'erreur.
6. **Identité** — avatars (6 teintes déterministes, 28→120 px), point de présence, pile de groupe, badges (vérifié or, business, admin), pastille de non-lus.
7. **Bulles de message** — toutes les variantes : texte, réponse citée, mention, image, album 2/3/4+, vidéo, note vocale avec forme d'onde, fichier, localisation, view-once, message supprimé, événement système, accusés (envoyé / distribué / lu), réactions, indicateur de saisie.
8. **Retours** — états vides, squelettes de chargement, toasts, boîtes de dialogue.

### Authentification (3)
9. **Connexion** — identifiant = **numéro Alanya + mot de passe** (pas d'e-mail).
10. **Inscription** — e-mail, mot de passe, nom, pseudo, pays.
11. **Mot de passe oublié** — 3 étapes : demande → code OTP 6 chiffres → nouveau mot de passe.

### Conversations (9)
12. **Shell — aucune conversation sélectionnée** : état vide éditorial au centre.
13. **Fil — 3 panneaux** : conversation 1-1 avec panneau contact ouvert.
14. **Fil — 2 panneaux** : le même à largeur intermédiaire, détail fermé.
15. **Fil — médias** : image, album, vidéo, note vocale, document, localisation dans un même fil.
16. **Fil — groupe** : noms d'auteurs colorés, @mentions, événements système, badge de rôle admin.
17. **Nouvelle conversation** : recherche de contact par nom ou numéro Alanya.
18. **Création de groupe** : nom, photo, sélection multiple de membres.
19. **Composeur média** : prévisualisation avant envoi, légende, plusieurs fichiers en file.
20. **Visionneuse média** : plein écran, navigation, téléchargement.
21. **Recherche** : globale (résultats groupés par conversation) et dans la conversation (occurrence précédente / suivante, surlignage).

### Appels (4)
22. **Journal d'appels** — entrant / sortant / manqué, audio vs vidéo.
23. **Clavier** — composer un numéro Alanya.
24. **Appel entrant** — surface immersive, anneau pulsé, accepter / refuser.
25. **Appel en cours** — variante audio et variante vidéo, contrôles (micro, caméra, haut-parleur, raccrocher), indicateur de participant qui parle.

### Statuts (3)
26. **Liste des statuts** — anneaux vus / non vus, mes statuts.
27. **Visionneuse de statut** — barres de progression segmentées, réponse.
28. **Création de statut** — texte sur fond coloré, ou média avec légende.

### Réunions (3)
29. **Liste des réunions** — à venir / en cours / passées.
30. **Salon d'attente** — vérification caméra/micro avant de rejoindre, demande d'accès.
31. **Réunion en cours** — grille de participants (2, 3, 4+), chat latéral intégré.

### Profil & réglages (3)
32. **Mon profil** — avatar, nom, pseudo, numéro Alanya, pays.
33. **Réglages notifications** — préférences par catégorie, aperçu (complet / nom seul / générique).
34. **Confidentialité** — accusés de lecture, vu à, photo de profil (Tout le monde / Mes contacts / Personne), contacts bloqués.

---

## 6. Règles de contenu

- **Tout en français.** Pas de placeholder anglais.
- **Noms réalistes camerounais** : Marie Ngo Bell, Paul Etoundi, Aïcha Bakari, Samuel Mbarga,
  Léa Fotso. Groupes : « Famille Ngo Bell », « Bureau — Projet Douala ».
- **Numéros au format `+237 6 91 04 22 18`**, toujours en mono.
- Le **numéro Alanya est l'identifiant de connexion**, pas l'e-mail. C'est inhabituel :
  l'écran de connexion doit le rendre évident.
- **Badge vérifié** = sceau or, à côté du nom, dans la liste comme dans le fil.
- **Accusés** : une coche (envoyé), deux coches grises (distribué), deux coches bleues
  `#2E90FA` (lu).
- Contenus de messages **plausibles**, pas de lorem ipsum : des phrases qu'on écrirait vraiment.

---

## 7. Hors périmètre — ne pas maquetter

- Protection anti-capture d'écran (impossible dans un navigateur).
- Écran d'appel natif type CallKit.
- Réception depuis le menu de partage du système.
- Toute administration : elle vit dans une application Next.js séparée.

---

## 8. Barre de qualité

- **Densité avant décoration.** Une liste de conversations doit en montrer 8–10 sans défilement.
- **Chaque écran en clair ET en sombre.**
- **États réels** : vide, chargement, erreur, hors ligne, message non envoyé.
- **Focus visible partout** (anneau indigo 2 px, décalé de 2 px) — utilisation clavier lourde attendue.
- **Mouvement sobre** : 120–320 ms, une révélation échelonnée au chargement suffit ;
  respecter `prefers-reduced-motion`.
- Ne pas concevoir une app mobile étirée : hover, clic droit, raccourcis clavier,
  glisser-déposer de fichiers, coller une image depuis le presse-papier.
