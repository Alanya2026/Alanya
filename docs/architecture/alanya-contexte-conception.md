# Alanya — contexte de conception

> Document de passation. Reprend l'intégralité d'une session de conception menée en amont
> du développement. À fournir comme contexte à Claude Code avant de travailler dans les repos.
>
> Statut : conception en cours, **aucune décision n'a encore été implémentée**.

---

## 1. Le projet

Alanya est une application de messagerie mobile. Trois codebases :

| Repo | Stack |
|---|---|
| Mobile | Flutter |
| Backend | Node.js + Express, MySQL |
| Admin | Next.js |

Deux dossiers contiennent déjà des travaux entamés qui doivent être relus avant toute
conception détaillée : le dossier `ideas` de la plateforme admin, et le dossier `docs` du mobile.

L'objectif de la session était de concevoir avant de développer : architecture, impact sur
l'existant, et design graphique des interfaces.

---

## 2. Les quatre fonctionnalités à concevoir

1. **Comptes business** avec métadonnées étendues : localisation, catégories, sites web,
   réseaux sociaux, vidéos et images de présentation, adresse physique, jours et heures de
   travail, catalogue de produits, moyens de paiement.
2. **Certification des comptes**, avec tout le mécanisme d'approbation et de paiement.
3. **Compte officiel** au nom de l'application, capable d'envoyer des messages et des statuts
   particuliers visibles par tous les utilisateurs ou par une partie d'entre eux.
   *Conception déjà entamée.*
4. **Listes de contacts préférés.** *Modélisation déjà entamée.*

> **Point resté en suspens.** L'énoncé initial de la fonctionnalité 1 se terminait sur
> « Ils pourront », phrase inachevée. Si l'intention était de permettre aux comptes business
> de **recevoir des paiements dans l'application**, ce n'est pas une métadonnée supplémentaire
> mais un sous-système entier (portefeuille, litiges, conformité) qui change le périmètre.
> À clarifier avant de figer le modèle.

---

## 3. Décision structurante : un modèle de compte unifié

Les fonctionnalités 1, 2 et 3 ne sont pas trois systèmes mais trois configurations du même
modèle. Les concevoir séparément produirait trois systèmes de badges, trois écrans de profil
et une logique d'affichage ingérable.

Deux axes **orthogonaux** portés par le socle `Account` :

- **Type de compte** — `PERSONNEL` / `BUSINESS` / `OFFICIEL`
- **État de vérification** — `AUCUN` / `EN_ATTENTE` / `VERIFIE` / `REJETE` / `REVOQUE` / `EXPIRE`

Ils sont indépendants : un business peut ne pas être vérifié, un compte personnel peut l'être
(personnalité publique). Le compte officiel Alanya est la combinaison `OFFICIEL` + vérifié
d'office + droits de diffusion.

Une troisième dimension, **les audiences**, se rattache aussi au socle et se réutilise
partout : segments pour les messages officiels, segments pour les statuts officiels, et listes
de contacts préférés. Une seule abstraction, trois usages — ne pas la dupliquer.

---

## 4. Décision structurante : découpler identité et argent

La certification ne doit **pas** être fusionnée avec l'abonnement payant.

- La **vérification** répond à « est-ce bien qui il prétend être ? ». Question d'identité,
  tranchée sur dossier.
- L'**abonnement** répond à « qu'est-ce qu'il a payé ? ». Question commerciale.

Les fusionner produit des états incohérents — un badge retiré pour défaut de paiement alors
que la personne est toujours la même. Fonctionnellement, l'application se met à vendre de la
confiance au lieu de la certifier.

Bénéfice immédiat : tant que les deux tables sont séparées, **le modèle économique n'a pas à
être décidé maintenant**. Badge gratuit sur dossier, paiement unique, ou inclus dans un plan
payant devient une règle de politique en configuration, pas une migration de schéma.

**Le modèle économique de la certification n'est à ce jour pas tranché.**

---

## 5. Modèle de données — noyau

```
ACCOUNTS ||--o| BUSINESS_PROFILES : etend
ACCOUNTS ||--o{ VERIFICATION_REQUESTS : soumet
VERIFICATION_REQUESTS ||--o{ VERIFICATION_DOCUMENTS : contient
ACCOUNTS ||--o{ SUBSCRIPTIONS : souscrit
SUBSCRIPTIONS ||--o{ PAYMENT_TRANSACTIONS : facture
```

| Table | Colonnes clés |
|---|---|
| `accounts` | `id` PK, `phone_e164`, `account_type` TINYINT, `verification_status` TINYINT, `verified_until` DATETIME |
| `business_profiles` | `id` PK, `account_id` FK, `legal_name`, `category_id` FK, `description` |
| `verification_requests` | `id` PK, `account_id` FK, `status` TINYINT, `reviewed_by` FK, `decided_at` |
| `verification_documents` | `id` PK, `request_id` FK, `doc_type` TINYINT, `storage_key`, `purge_after` DATETIME |
| `subscriptions` | `id` PK, `account_id` FK, `plan` TINYINT, `status` TINYINT, `current_period_end` DATETIME |
| `payment_transactions` | `id` PK, `subscription_id` FK, `provider_ref`, `idempotency_key` UNIQUE, `status` TINYINT |

Deux champs qui ont l'air anodins et ne le sont pas :

- **`purge_after`** sur les documents — une pièce d'identité ne doit pas être conservée
  indéfiniment après la décision. Porter l'échéance dans la ligne est plus simple qu'un script
  de rétention à part.
- **`idempotency_key`** en index unique — le fournisseur de paiement rejouera ses webhooks.
  Sans cette contrainte, double crédit garanti.

`subscriptions` est modélisée pour un **renouvellement manuel** avec relances, pas pour un
prélèvement automatique (voir §8).

Les tables du profil business étendu (lieux, horaires, liens, médias, catalogue, moyens de
paiement) n'ont pas encore été modélisées — c'est l'étape suivante.

---

## 6. Système de badges

Le badge est un **rendu dérivé**, pas une colonne. Aucune colonne `badge_type` : il se calcule
depuis `(account_type, verification_status)` au moment de l'affichage. Une valeur stockée
finira désynchronisée le jour où une certification expire ou est révoquée.

En contrepartie, les deux valeurs sources doivent être présentes dans la requête de liste de
conversations **sans jointure supplémentaire** — donc dénormalisées sur la ligne du compte.

### Le principe visuel

Un badge combinant panier et marque de certification devient illisible à 12 px dans une ligne
de conversation. Deux badges côte à côte mangent la largeur du nom, déjà tronqué sur petit
écran. La solution retenue sépare les deux informations sur deux canaux visuels :

- **Le glyphe dit *quoi*** — panier = commerce, coche = personne notable, marque = compte officiel
- **Le contenant dit *vérifié ou pas*** — glyphe nu = déclaré par le compte, glyphe dans une
  pastille pleine = vérifié par Alanya

| Type | État | Rendu |
|---|---|---|
| Personnel | non vérifié | aucun badge |
| Personnel | certifié | pastille + coche |
| Business | déclaré | panier nu |
| Business | certifié | pastille + panier |
| Officiel | réservé | pastille (couleur distincte) + marque |

### Pourquoi cette distinction est critique

Le type business est **déclaratif** — le compte s'auto-déclare commerce, personne ne l'a
vérifié. La certification est **attestée**. Si les deux badges ont le même poids visuel, un
arnaqueur crée un compte business en trente secondes et hérite d'une caution jamais accordée.
La pastille pleine doit rester le sceau d'Alanya, et rien d'autre ne doit pouvoir y ressembler.

### Règle de validation à implémenter dès maintenant

Filtrer les caractères Unicode de type coche, étoile et sceau dans les **noms d'affichage**, et
réserver les variantes du nom « Alanya ». Sinon quelqu'un s'appelle « Alanya ✓ » et le système
de badge est contourné sans avoir jamais été attaqué.

---

## 7. Spécificités MySQL à intégrer dès la modélisation

- **Fuir le type `ENUM`.** Chaque nouvelle valeur impose un `ALTER TABLE` sur une table qui
  deviendra grosse. Utiliser `TINYINT` avec l'énumération côté Node, ou une table de référence
  pour ce qui est éditable (catégories business, types de documents).
- **Recherche par proximité** — colonne `POINT SRID 4326` avec `SPATIAL INDEX` et
  `ST_Distance_Sphere()`. L'index spatial exige que la colonne soit `NOT NULL` : le prévoir tout
  de suite, l'ajouter après coup sur une table remplie est pénible.
- **Pas de `LISTEN/NOTIFY`** comme en PostgreSQL. Une file de jobs est nécessaire **dès la
  conception**, pas en rattrapage : BullMQ sur Redis. Elle servira au fan-out des diffusions, au
  transcodage des vidéos de présentation, aux relances d'abonnement et aux retries de webhooks.
  C'est une brique d'infrastructure à ajouter au périmètre.
- **`utf8mb4` partout**, y compris sur les noms et descriptions business — sinon le premier
  emoji dans un nom d'entreprise fait échouer l'insert.
- **Colonnes JSON** — acceptables pour des métadonnées affichées sans jamais être filtrées. Tout
  ce qui fait l'objet d'un `WHERE` doit être une vraie colonne.

---

## 8. Contraintes de plateforme et de paiement

- **App Store / Play Store.** Un badge de certification est un service numérique : les stores
  peuvent exiger un achat in-app avec leur commission de 30 %. C'est la raison pour laquelle
  Meta Verified coûte plus cher sur mobile que sur le web. À anticiper avant la soumission,
  pas pendant.
- **Prélèvement automatique fragile.** Sur mobile money, les autorisations expirent et les
  échecs sont silencieux. Une formule annuelle à **renouvellement manuel** avec relances est
  plus réaliste qu'un véritable auto-debit.

---

## 9. Diffusion du compte officiel

**Fan-out on read, pas on write.** Écrire une ligne de message par utilisateur tue la base dès
quelques dizaines de milliers de comptes. Retenir : un enregistrement de diffusion unique
+ un état de lecture par utilisateur, matérialisé à la demande.

Le ciblage réutilise l'abstraction d'audience du §3.

---

## 10. Impact sur l'existant

- **Annuaire et recherche business** par catégorie et proximité — index géospatial, et une
  taxonomie de catégories à figer tôt : elle est très difficile à changer une fois peuplée.
- **Confidentialité** — les valeurs par défaut ne sont pas les mêmes pour un compte business
  (profil public, pas de « vu à »).
- **Modération** — une arnaque commerciale n'est pas le même workflow qu'un signalement
  d'utilisateur.
- **Back-office** — validation des dossiers, gestion des paiements, déclenchement des
  diffusions. C'est une application complète qui ne figure pas encore dans le périmètre annoncé.
- **Migration** des comptes existants vers le nouveau modèle.

---

## 11. Côté Flutter

- **Le badge doit être un seul widget à variantes**, piloté par les deux axes, utilisé partout :
  liste de conversations, en-tête de chat, profil, résultats de recherche. Trois implémentations
  concurrentes divergeront en deux semaines.
- **Cache local** (Drift ou Isar) — un profil business avec catalogue et médias doit rester
  consultable hors ligne. Le réseau ne sera pas toujours stable.
- **L'éditeur d'horaires d'ouverture est l'écran le plus difficile de tout le lot.**
  Multi-créneaux par jour, copie d'un jour sur les autres, fermetures exceptionnelles, cas
  24h/24, le tout sur un écran de téléphone. À budgéter comme un écran à part entière, pas
  comme un champ de formulaire.

---

## 12. Pièges de modélisation identifiés

- **Pas une colonne par réseau social.** Une table `business_links (type, url, ordre)` permet
  d'ajouter TikTok demain sans migration.
- **Horaires** — fuseau horaire obligatoire, table d'exceptions (jours fériés, fermeture
  ponctuelle), et les cas « 24h/24 » et « fermé » gérés explicitement.
- **Prix du catalogue** — entier en unité mineure + code devise. Jamais un float.
- **Documents de certification** — données personnelles sensibles : chiffrement au repos, accès
  restreint et journalisé, suppression après décision.

---

## 13. Questions ouvertes à trancher

1. Modèle économique de la certification — gratuit sur dossier, paiement unique, ou abonnement ?
2. Un compte business est-il un nouveau compte ou l'upgrade d'un compte existant ? Réversible ?
   Que devient le catalogue si on repasse en personnel ?
3. Une entreprise peut-elle avoir plusieurs points de vente ? Si oui, adresse et horaires sont
   des relations 1:N, pas des champs plats sur le profil.
4. Les comptes business doivent-ils pouvoir **recevoir des paiements** dans l'application ?
   (cf. la phrase inachevée du §2)

---

## 14. Ordre de travail proposé

1. Modèle de domaine unifié (ERD complet, y compris le profil business étendu)
2. Machines à états : vérification, paiement, diffusion
3. Contrat d'API et événements
4. Inventaire des écrans et parcours
5. Design system : variantes de badges, composants business
6. Wireframes puis maquettes

---

## 15. Prochaine action — inventaire de l'existant

Rien de ce qui précède n'a été confronté au code réel. Avant de descendre dans les tables,
produire un inventaire de l'existant sur les trois repos.

```
Explore les trois codebases de ce workspace (mobile Flutter, backend Node/Express,
admin Next.js) et produis UN SEUL fichier markdown : docs/architecture/00-inventaire.md

N'écris pas de code. N'invente rien : si une info est absente, écris "absent".

1. BACKEND
   - ORM/query builder utilisé, emplacement des migrations
   - Schéma actuel des tables comptes/utilisateurs, contacts, messages, statuts :
     colonnes, types, index, clés étrangères (recopie le DDL réel)
   - Auth (jwt ? sessions ?), stockage des médias, file de jobs si elle existe
   - Conventions : nommage, structure des dossiers, format des réponses API,
     gestion des erreurs, validation

2. ADMIN NEXT.JS
   - Contenu intégral du dossier `ideas` (recopie-le, ne le résume pas)
   - Modèle de rôles et permissions existant
   - App router ou pages router, librairie UI, appels API vers le backend

3. MOBILE FLUTTER
   - Contenu intégral du dossier `docs` (recopie-le, ne le résume pas)
   - Gestion d'état, routing, structure des dossiers
   - Fichier de thème / design system : couleurs, typo, composants partagés
   - Tout code existant lié aux contacts favoris et au compte officiel

4. CHANTIERS EN COURS
   Liste ce qui est commencé mais incomplet, avec les chemins de fichiers.

Termine par une section "Contradictions et zones floues" : les endroits où les
trois repos divergent, ou où une intention documentée ne correspond pas au code.
```

Deux points dépendent directement du résultat de cet inventaire : la **taxonomie des catégories
business** et le **modèle de permissions du back-office**, qui doivent s'appuyer sur ce qui
existe déjà côté admin plutôt que d'être inventés à côté.
