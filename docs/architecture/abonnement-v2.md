# Abonnement v2 — essai de trois mois, réception seule, code d'activation

Ce document dit ce que la v2 fait, comment l'allumer et la couper, et **ce que le site de
paiement devra respecter** pour se brancher après la publication de l'application, sans
nouvelle version de celle-ci.

Le plan d'origine est `~/.claude/plans/keen-skipping-adleman.md`. Code : dépôt backend
(`src/services/billing/`), admin (`app/(dashboard)/billing/`), app (`lib/core/services/billing/`,
`lib/screens/billing/`).

## Le principe

Deux régimes coexistent, choisis par le super-administrateur dans l'admin
(Abonnement → Régime). Le défaut est **Alanya Plus** : appliquer la migration 090 ne change rien
pour personne.

| | Régime 1 — Alanya Plus | Régime 2 — essai |
|---|---|---|
| Messages et appels | ouverts à tous | essai de 3 mois, puis **réception seule** sans abonnement |
| Fonctionnalités annexes (traduction, sauvegarde, trajets, sonneries) | payantes | ouvertes pendant l'essai, puis payantes |
| Paiement | mobile money dans l'application | sur le site, puis un **code** saisi dans l'application |
| Prix | `plan.price_amount` (admin) | le même, 1 000 FCFA par an |

En régime 2, sans abonnement et hors essai, le compte **reçoit** messages et appels, décroche,
refuse, raccroche, rejoint une réunion ou un appel de groupe sur invitation. Il ne peut ni
envoyer (message, transfert, réaction, modification, statut) ni lancer (appel, appel de groupe,
ajout à un appel, réunion, invitation à une réunion).

L'essai se **déduit**, il ne se stocke pas : fin d'essai = `users.created_at` + `billing_settings.trial_days`
(90), repoussée à la fin de la grâce pour les comptes déjà là le jour de l'activation (ils ont
trois mois à partir d'elle). Payer pendant l'essai est permis : l'année commence à sa fin.

## Le code

- 15 symboles de l'alphabet Crockford (ni I, L, O ni U) : 14 au hasard (70 bits) et un symbole de
  contrôle. Affiché `XXXXX-XXXXX-XXXXX`.
- **Jamais stocké en clair** : le serveur garde `HMAC-SHA256(code, ACTIVATION_CODE_SECRET)` et les
  quatre derniers symboles. Il n'est visible qu'une fois, à l'émission.
- Libre : n'importe quel compte peut l'activer, une seule fois. Il peut donc s'offrir.
- Valable un an à partir de l'émission si non utilisé. Le prix et la durée du plan sont recopiés sur
  le code : changer le plan plus tard ne touche aucun code déjà vendu.
- Cinq échecs en quinze minutes verrouillent le compte quinze minutes (`CODE_LOCKED`). Une faute de
  frappe (contrôle faux) ne compte pas comme un essai.
- Le rachat est une seule transaction : deux saisies simultanées du même code, un seul compte
  l'obtient. Rejouer son propre code rend le même succès sans seconde période.

## Limites selon l'abonnement

Le palier se décide sur une seule ligne de partage : **a payé** = phase payante ET (abonnement en
cours, payé, offert ou par code, OU compte exempté). En essai, en grâce ou payant éteint, tout le
monde est au palier standard.

| | Standard | A payé |
|---|---|---|
| Taille d'un fichier envoyé | 50 Mo | 200 Mo |
| Médias d'un album | 30 | 100 |
| Médias gardés sur le serveur | durée « standard » (page Purges) | durée « Alanya Plus » (page Purges) |

Le serveur envoie `limits: { maxUploadBytes, maxAlbumItems, tier }` avec les droits ; l'application
les lit (jamais de 50 ni de 30 codés en dur) et refuse tôt, en disant le bon plafond. Le serveur
applique la taille : le ticket d'envoi direct (`/upload/ticket`) et l'envoi par formulaire
(`/upload/media`, avant et après multer). Les plafonds sont des constantes
(`TIER_LIMITS`, `constants/billing.js`).

Le nombre de médias d'un album n'est contrôlé que par l'application : un album est une suite de
messages, le serveur ne connaît pas son total.

La **conservation sur le serveur** n'est pas une constante mais deux réglages de la page Purges
(« Rétention des médias — standard » et « — Alanya Plus »). Pour « 15 jours en essai, un an pour
qui a payé » : standard = 15, Alanya Plus = 365. Attention : la purge nocturne supprime alors,
définitivement, les médias de plus de 15 jours de tous les comptes hors abonnement — y compris
pendant la grâce, où personne n'est abonné. À régler le jour de l'activation, après l'avoir
annoncé aux utilisateurs ; la purge s'arrête d'elle-même si elle dépasse son seuil d'alerte.

## Ce que le site de paiement doit faire

Le site n'existe pas encore, et il n'y a pas encore de prestataire. Tout est prêt pour qu'il se
branche. Le parcours attendu :

1. **Le bouton « Payer en ligne » de l'application** ouvre `billing_settings.pay_url` dans le
   navigateur, avec `?lang=fr|en|zh`. **Aucune donnée personnelle** n'est dans l'adresse. Tant que
   `pay_url` est vide, le bouton est grisé (l'application n'a pas à être republiée pour que le site
   s'allume : il suffit de renseigner l'adresse dans l'admin).
2. **Le prix** se lit sans authentification : `GET /api/billing/public-offer` →
   `{ model, plan: { code, name, durationMonths, price, currency } }`. Le site n'a aucun prix à lui.
3. **Le paiement** se fait chez le prestataire choisi. Le module de paiement a déjà la forme d'un
   fournisseur (`src/services/payments/providers/index.js` : `initiate`, `parseWebhook`,
   `fetchStatus`) ; en ajouter un est un simple branchement.
4. **Une fois le paiement confirmé par le prestataire**, le backend appelle, **une seule fois**,
   `issueActivationCode({ amountPaid, currency, orderRef, buyerContact })`
   (`src/services/billing/activationCodes.js`) :
   - `orderRef` : la référence de la commande, **unique**. Un webhook rejoué n'émet jamais un
     second code : l'appel rend `{ created: false, code: null }`.
   - `amountPaid` : entier, en francs CFA (le XAF n'a pas de sous-unité).
   - `buyerContact` : e-mail ou téléphone laissé sur le site, pour renvoyer le code.
5. **Le code en clair est dans la réponse de la première émission seulement.** Le site doit le
   montrer sur la page de confirmation **et** l'envoyer au contact, dans la même opération : il ne
   pourra pas le redemander. Si la page est perdue, il n'y a que le courriel (ou une nouvelle
   génération par l'administration).

Ce qui reste à construire le jour du prestataire : une table de commandes (`web_order`), les routes
publiques du site (création de commande, retour de paiement), le webhook, la page et le courriel. Rien
de cela ne touche l'application.

### À trancher avant d'ouvrir le paiement externe

- **Règles des boutiques d'applications.** Apple interdit en général d'orienter l'utilisateur vers
  un paiement extérieur depuis l'application (guideline 3.1.1) ; Google Play l'encadre par région.
  L'iOS n'est pas publié. Par défaut, l'application montre « Payer en ligne » sur Android et, sur
  iOS, seulement « J'ai un code ». À valider avant toute publication sur l'App Store.

## Mettre en service

Ordre : migration 090 (à la main) → backend → admin → application.

1. Poser `ACTIVATION_CODE_SECRET` dans le `.env` **du serveur** (32 caractères au moins,
   `openssl rand -base64 48`). Le changer rend inconnus tous les codes déjà émis et non utilisés :
   à sauvegarder à part, comme `VAULT_KEY`.
2. Appliquer `migrations/090_abonnement_v2.sql`. Vérification en pied de fichier.
3. Admin → Abonnement, **payant éteint** : choisir le régime « Essai », régler l'essai
   (`trial_days`, 90), la grâce (90), et `pay_url` quand le site existe.
4. Générer quelques codes (onglet Codes) et les éprouver sur un compte testeur.
5. Activer le payant. La grâce commence : tous les comptes existants gardent tout trois mois.

Retour : désactiver le payant (tout redevient gratuit), puis rechoisir « Alanya Plus ». Le régime ne
se change **que payant éteint** — passer à l'essai payant allumé fermerait l'envoi, d'un coup, à tous
les comptes dont l'essai serait déjà écoulé.

Les comptes de `BILLING_TEST_USERS` voient le régime payant même payant éteint : en régime essai,
ils sont donc bloqués dès que leur essai est écoulé. C'est le moyen d'éprouver un code en production.

## Deux fermetures volontaires du régime 2

- `POST /billing/checkout` est refusé (`PLUS_CHECKOUT_DISABLED`) : avec le simulateur de paiement,
  il confirmerait un abonnement sans rien encaisser.
- Le renouvellement automatique est inerte : il passerait par le même simulateur.

L'achat du **numéro choisi** (1 000 F) est inchangé, toujours en mobile money simulé.

## Vérification

Backend : `npm run test:billing`, `test:erreurs`, `test:roles`, `test:calls`, `test:meetings`. Les
tests contre la base (`*.db.test.js`) ne tournent que sur une base **locale** (`DB_HOST=127.0.0.1`) :
le `.env` du dépôt pointe sur la production, et ils refusent de démarrer ailleurs.

Application : `flutter test test/activation_code_test.dart test/redeem_code_screen_test.dart
test/paywall_trial_test.dart test/outgoing_block_test.dart test/outgoing_call_block_test.dart`.
Le vecteur du code (`activation_code_test.dart`) a été calculé par le serveur : s'il échoue, le
téléphone et le serveur ne sont plus d'accord sur ce qu'est un code valide.
