# Prompts Claude Design — client web Alanya

Séquence de 8 prompts à envoyer **dans l'ordre**, dans une même conversation Claude Design.

Le prompt 0 est autonome : il installe le système (tokens, typographie, composants) et
c'est lui qui détermine la qualité de tout le reste — ne pas l'abréger. Les prompts 1 à 7
sont courts parce qu'ils s'appuient sur le système déjà en place.

Le détail complet des contraintes vit dans [BRIEF-CLAUDE-DESIGN.md](BRIEF-CLAUDE-DESIGN.md) ;
ces prompts en sont la version exécutable.

---

## Prompt 0 — Amorçage : le système

~~~text
Je construis le client web d'Alanya, un messager grand public francophone déjà en
production sur Android et iOS. Le web est un client compagnon : le téléphone reste
l'appareil principal, le navigateur sert à retrouver ses conversations au clavier sur
grand écran. Modèle mental : WhatsApp Web / Telegram Desktop.

Public : grand public francophone, Cameroun et diaspora. Interface entièrement en
français. C'est un outil qu'on laisse ouvert huit heures par jour — je veux de la
fiabilité et du calme, pas de l'effet. La densité d'information prime.

Commence par établir le design system. Ne produis aucun écran applicatif dans cette
étape.

## Tokens — à reprendre exactement

Ils viennent de l'app mobile existante (app_colors.dart). Tout écart rendrait le web et
le mobile visiblement différents.

Marque, indigo unifié :
  --brand #3F51B5 (boutons, accents, états actifs, bulles envoyées)
  --brand-strong #303F9F (hover/pressed) · --brand-dark #1A237E
  --brand-darker #0D123E (fond du rail de navigation)
  --brand-lift #7986CB (accent TEXTE en mode sombre uniquement)
  --brand-container #E8EAF6 · --brand-tint #F2F3FB

Sceau officiel, le seul accent chaud :
  --gold #C9A227

Neutres clair :
  --paper #F6F7FB · --surface #FFFFFF · --surface-muted #F4F5F8
  --surface-subtle #EDEFF4 · --line #E2E5EC · --line-strong #CBD0E0
Texte clair :
  --ink #1A1D23 · --ink-2 #5B6273 · --ink-3 #9AA0AE

Neutres sombre :
  --paper #0F1115 · --surface #181B21 · --surface-muted #1F232B
  --line #2C313B · --line-strong #3A404C
  --ink #F2F4F8 · --ink-2 #AAB1C0 · --ink-3 #6F7787

Sémantiques :
  --success #1FA363 (= indicateur « en ligne ») · --error #EF4444
  --warning #F59E0B · --info #2E90FA (= accusé de lecture, double coche lue)

Immersif, appels et réunions uniquement :
  --immersive-bg #0E1330 · --immersive-surface #1B2147

Règles d'usage strictes :
- L'or #C9A227 ne porte QUE l'autorité : badge vérifié, compte officiel, liseré de la
  conversation active, pastille du rail. Jamais une couleur d'action, il perdrait son sens.
- En mode sombre, l'indigo plein reste le fond des boutons (blanc sur #3F51B5 ≈ 5,9:1),
  mais le texte accentué et les liens passent à --brand-lift #7986CB, faute de contraste.
- Clair et sombre sont tous deux de premier rang. Rien n'est conçu pour un seul des deux.

## Direction artistique — « Encre »

La messagerie comme correspondance.

- Un serif éditorial, réservé aux rares moments de marque : écran de connexion, états
  vides, wordmark. JAMAIS dans une bulle de message ni dans la liste de conversations.
  Aucun messager ne fait de serif — c'est ce qui doit rendre Alanya reconnaissable.
- Un sans humaniste pour 95 % de l'interface. Il doit être excellent à 13–15 px et gérer
  correctement les accents français.
- Un mono pour ce qui est un identifiant et non une phrase : numéros Alanya, codes OTP,
  durées, horodatages. Chiffres de largeur fixe, pour que l'heure ne fasse pas vibrer la
  mise en page à chaque minute.

Trio suggéré, remplace-le si tu trouves mieux : Instrument Serif (display), Onest
(interface), DM Mono (identifiants). Évite Inter, Roboto, Space Grotesk.

Détails de signature à installer dès maintenant :
- Grain papier très léger sur le canvas de conversation (opacité ~0,03 clair / 0,05 sombre).
- Conversation active : liseré or de 3 px à gauche + fond légèrement teinté indigo.
- Bulle envoyée : indigo plein avec un liseré intérieur haut
  inset 0 1px 0 rgba(255,255,255,.14) — l'encre qui capte la lumière.
- Séparateurs de jour : filet réglé + petites capitales espacées.
- Réactions : pastille chevauchant le bord bas de la bulle.

À proscrire : dégradés violets sur blanc, ombres portées lourdes, coins ultra-arrondis
partout, icônes décoratives géantes, cartes imbriquées dans des cartes.

## Gabarit — adaptatif 2 ↔ 3 panneaux

  ≥ 1600 px    rail(68) | liste(300–372) | fil(1fr) | panneau détail(280–340)
  900–1600 px  rail(68) | liste(300–372) | fil(1fr)   → le détail devient un panneau glissant
  < 900 px     une seule colonne, le retour ramène à la liste (sert aussi de mobile web)

- Rail : fond --brand-darker, icônes seules, onglet actif marqué par un trait or à gauche.
  Entrées : Conversations, Appels, Statuts, Réunions ; puis Réglages et avatar en bas.
- Liste : recherche + filtres segmentés (Toutes / Non lues / Groupes).
- Fil : barre supérieure translucide (backdrop-filter), messages ancrés en bas,
  composeur fixe.

## Ce que je veux de cette première étape

Huit planches, chacune en clair ET en sombre :

1. Couleurs — nuanciers, usage de l'or, vérification des contrastes.
2. Typographie — échelle complète, rôle de chaque famille, pile de repli système.
3. Gabarit & mouvement — les 3 largeurs, espacement base 4, rayons, ombres, durées
   (120–320 ms), respect de prefers-reduced-motion.
4. Actions — boutons primaire / secondaire / fantôme / danger / or, boutons-icônes,
   contrôle segmenté, interrupteur. Avec états hover, pressed, focus, désactivé.
5. Saisie — champs, recherche, champ OTP 6 chiffres, composeur de message, états d'erreur.
6. Identité — avatars de 28 à 120 px avec 6 teintes déterministes, point de présence,
   pile d'avatars de groupe, badges (vérifié or, business, admin), pastille de non-lus.
7. Bulles de message — LA planche la plus importante. Toutes les variantes : texte,
   réponse citée, @mention, image, album 2/3/4+, vidéo, note vocale avec forme d'onde,
   fichier joint, localisation, view-once, message supprimé, événement système, les trois
   accusés (envoyé / distribué / lu), réactions, indicateur de saisie.
8. Retours — états vides, squelettes de chargement, toasts, boîtes de dialogue.

Barre de qualité : focus visible partout (anneau indigo 2 px, décalé de 2 px), usage
clavier lourd attendu. Densité avant décoration.
~~~

---

## Prompt 1 — Authentification

~~~text
Passe aux écrans, en réutilisant strictement le système établi. Trois écrans, clair et
sombre.

1. Connexion — attention, l'identifiant est le NUMÉRO ALANYA + mot de passe, pas
   l'e-mail. C'est inhabituel, l'écran doit le rendre évident (format +237 6 91 04 22 18,
   en mono). C'est le moment de marque : le serif éditorial a sa place ici.
2. Inscription — e-mail, mot de passe, nom, pseudo, sélection du pays.
3. Mot de passe oublié — 3 étapes enchaînées : demande par e-mail → saisie d'un code OTP
   à 6 chiffres → nouveau mot de passe. Montre les 3 états.

Inclus les états d'erreur réels : identifiants refusés, code OTP expiré, mot de passe
trop court.
~~~

---

## Prompt 2 — Le shell et le fil de discussion

~~~text
Le cœur du produit. Cinq écrans, clair et sombre.

1. Shell sans conversation sélectionnée — rail + liste remplie + zone vide au centre.
   L'état vide est éditorial (serif), pas une icône géante.
2. Fil 3 panneaux (≥1600 px) — conversation 1-1 avec le panneau contact ouvert à droite :
   avatar, nom + sceau vérifié, numéro Alanya en mono, actions d'appel, médias partagés en
   grille, documents, favoris, sourdine, bloquer, supprimer.
3. Fil 2 panneaux (900–1600 px) — le même, détail fermé.
4. Fil médias — un seul fil contenant image seule, album de 4+, vidéo, note vocale avec
   forme d'onde, document PDF, localisation.
5. Fil de groupe — noms d'auteurs colorés, @mentions surlignées, événements système
   (« Paul a rejoint le groupe »), badge de rôle admin.

Contenu : noms camerounais réalistes (Marie Ngo Bell, Paul Etoundi, Aïcha Bakari, Samuel
Mbarga, Léa Fotso), groupes « Famille Ngo Bell » et « Bureau — Projet Douala ». Des
phrases qu'on écrirait vraiment, jamais de lorem ipsum.

La liste de conversations doit montrer 8 à 10 entrées sans défilement — c'est le test de
densité du produit.
~~~

---

## Prompt 3 — Actions sur les conversations

~~~text
Cinq écrans, clair et sombre.

1. Nouvelle conversation — recherche d'un contact par nom ou par numéro Alanya.
2. Création de groupe — nom, photo, sélection multiple de membres avec jetons.
3. Composeur média — prévisualisation avant envoi, légende, plusieurs fichiers en file
   d'attente, possibilité d'en retirer un.
4. Visionneuse média plein écran — navigation entre médias, téléchargement, retour.
5. Recherche — deux variantes : globale avec résultats groupés par conversation, et
   dans la conversation avec navigation occurrence précédente / suivante et surlignage.

Pense navigateur, pas mobile étiré : glisser-déposer de fichiers, coller une image depuis
le presse-papier, menu contextuel au clic droit, raccourcis clavier visibles.
~~~

---

## Prompt 4 — Appels

~~~text
Quatre écrans. Les deux derniers utilisent la surface immersive (--immersive-bg #0E1330),
pas le fond clair habituel.

1. Journal d'appels — entrant / sortant / manqué, audio vs vidéo distingués, groupés par jour.
2. Clavier — composer un numéro Alanya, format +237 en mono.
3. Appel entrant — surface immersive, avatar avec anneau pulsé, accepter / refuser.
4. Appel en cours — deux variantes, audio et vidéo. Contrôles micro, caméra, haut-parleur,
   raccrocher. Indicateur du participant qui parle. Durée en mono.

Les appels sont en pair-à-pair : montre aussi l'état « connexion en cours » et l'état
« qualité réseau faible ».
~~~

---

## Prompt 5 — Statuts

~~~text
Trois écrans, clair et sombre.

1. Liste des statuts — anneaux vus (gris) / non vus (dégradé indigo→or), mes statuts en tête.
2. Visionneuse — plein écran, barres de progression segmentées en haut, réponse en bas,
   compteur de vues.
3. Création — deux modes : texte sur fond coloré, ou média avec légende.
~~~

---

## Prompt 6 — Réunions

~~~text
Trois écrans.

1. Liste des réunions — à venir / en cours / passées, avec organisateur et participants.
2. Salon d'attente — vérification caméra et micro avant de rejoindre, demande d'accès en
   attente de validation.
3. Réunion en cours — grille de participants en 2, 3 et 4+, chat latéral intégré,
   contrôles. Surface immersive.
~~~

---

## Prompt 7 — Profil et réglages

~~~text
Trois écrans, clair et sombre.

1. Mon profil — avatar modifiable, nom, pseudo, numéro Alanya (en mono, non modifiable),
   pays.
2. Réglages notifications — préférences par catégorie (messages, groupes, appels,
   réunions, vues de statut), son, vibration, et mode d'aperçu : complet / nom seul /
   générique.
3. Confidentialité — accusés de lecture, vu à, photo de profil, chacun en
   « Tout le monde / Mes contacts / Personne », plus la liste des contacts bloqués.

Ces trois écrans sont surtout des listes de réglages : c'est le test du rythme vertical
et de la hiérarchie typographique du système.
~~~

---

## Reprises utiles

À garder sous la main pour corriger sans tout relancer.

~~~text
Trop décoré. Enlève les ombres, resserre les espacements, et fais tenir 2 entrées de plus
dans la hauteur visible. Densité avant décoration.
~~~

~~~text
Le mode sombre est un simple inversement. Reprends-le avec les vrais tokens sombres
(--surface #181B21, --line #2C313B) et bascule le texte accentué sur --brand-lift #7986CB.
~~~

~~~text
L'or sert de couleur d'action ici, c'est contraire à la règle. Il ne porte que l'autorité :
badge vérifié, compte officiel, conversation active. Remets l'indigo sur les actions.
~~~

~~~text
Ça ressemble à une app mobile étirée. Ajoute ce qu'un navigateur permet : survol, clic
droit, raccourcis clavier, glisser-déposer, coller une image. Et sers-toi de la largeur.
~~~

---

## Hors périmètre — à rappeler s'il dérive

- Protection anti-capture d'écran : impossible dans un navigateur.
- Écran d'appel natif type CallKit.
- Réception depuis le menu de partage du système.
- Toute administration : elle vit dans une application Next.js séparée.
