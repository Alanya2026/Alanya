# Plan de correction : barre supérieure de la visionneuse sensible

## Constat

Dans [`visionneuse_document_sensible.dart`](../lib/screens/chats/visionneuse_document_sensible.dart), la
visionneuse utilise un fond noir et demande déjà `foregroundColor: AppColors.white`
(ligne 161). Cependant, le thème global défini dans
[`app_theme.dart`](../lib/core/theme/app_theme.dart) fournit une couleur
`colorScheme.onSurface` aux styles `AppBarTheme.titleTextStyle`, `iconTheme` et
`IconButtonTheme`. Ces styles peuvent prendre le dessus pour le titre, la flèche
de retour et l'icône de téléchargement, ce qui explique leur rendu gris sur
l'écran sensible.

## Objectif

Garantir que la flèche de retour, le titre du document et le bouton de
téléchargement de la visionneuse sensible soient blancs sur le fond noir, en
mode clair comme en mode sombre, sans modifier l'apparence des autres écrans.

## Tâches

### Phase 1 : correction locale

- [ ] Ajouter à l'`AppBar` de `VisionneuseDocumentSensible` un style local blanc
  explicite pour le titre et les icônes (retour et actions).
- [ ] Conserver le bouton de téléchargement blanc également pendant son état
  désactivé de sauvegarde, tandis que le spinner reste blanc.

### Phase 2 : régression

- [ ] Ajouter un test widget ciblé vérifiant le rendu/couleur du titre, du
  bouton retour et de l'action de téléchargement dans la visionneuse sensible.
- [ ] Vérifier que les AppBars ordinaires ne sont pas affectées.

## Vérification

- `flutter test test/document_sensible_test.dart`
- `flutter analyze`
- Vérification manuelle : ouvrir un document sensible et confirmer que les trois
  éléments restent blancs avant, pendant et après le téléchargement.

## Risques et décisions

| Risque | Impact | Mitigation |
|---|---|---|
| Le thème global écrase encore une couleur locale | Moyen | Définir explicitement `titleTextStyle`, `iconTheme` et le style de l'action dans la visionneuse |
| Le bouton devient gris pendant l'attente | Faible | Définir aussi la couleur d'état désactivé, sans supprimer le garde-fou `_enregistrement` |
| Régression visuelle d'autres écrans | Faible | Ne modifier que l'`AppBar` de la visionneuse sensible et exécuter les tests ciblés |

## Dépendances

Une seule surface applicative est concernée : la visionneuse sensible. Aucun
changement backend, API ou localisation n'est nécessaire.
