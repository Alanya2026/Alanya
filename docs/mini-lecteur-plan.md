# Mini-lecteur audio, vitesse de lecture et navigation vidéo

## Problème

Quitter une conversation laissait l'audio jouer et affichait un bandeau en haut — mais inexploitable. Il montrait le **nom de la conversation** au lieu du titre du morceau, **aucune progression**, et seulement play/pause. Impossible de savoir où on en était.

Deux défauts réels trouvés au passage : le tap sur le bandeau **empilait une nouvelle instance** de l'écran de conversation, là où l'appel et la réunion se protègent avec `_isCallUiRouteOpen` ; et **rien ne mettait la lecture en pause à l'arrivée d'un appel**, donc musique et sonnerie se superposaient.

Design comparé et validé : https://claude.ai/code/artifact/29343ee0-4eb8-45cb-a220-6848f214e975

## Décisions

| Sujet | Décision |
|---|---|
| Forme | Bandeau **44 px enrichi**. Hauteur et structure inchangées, `_SessionTopBar` reste partagé par les trois états. |
| Progression | Barre fine **non interactive**, dessinée à l'intérieur des 44 px. |
| Vitesse audio | Pastille cyclique 1× → 1,5× → 2×, dans la bulle vocale et le bandeau. |
| Vitesse vidéo | Menu Chewie existant, paliers curés. |
| Persistance | Par type dans les SharedPreferences : vocal, musique, vidéo séparés. |
| Portée | Dans l'app uniquement. |

La barre de progression tient **à l'intérieur** des 44 px, en `Positioned` sur l'arête basse. C'est ce qui permet de ne pas toucher à `kActiveSessionTopBarHeight` ni au décalage injecté par `ActiveSessionChrome` à tous les écrans — le seul avantage de cette forme sur un bandeau dédié.

Elle est volontairement non interactive : 3 px n'atteignent pas la cible tactile, un scrub y serait imprécis. Le seek reste dans la bulle.

## Implémentation

### Nouveaux fichiers

| Fichier | Rôle |
|---|---|
| `lib/core/services/playback_speed_preferences.dart` | Vitesse mémorisée par type, paliers, formatage francophone |
| `lib/widgets/video/video_speed_memory.dart` | Applique et persiste la vitesse vidéo |
| `lib/widgets/video/double_tap_seek_overlay.dart` | Double tap ±10 s avec retour visuel |
| `test/playback_speed_preferences_test.dart` | 9 tests |

### Ce qui circule jusqu'au bandeau

`VoicePlaybackSource` gagne **`title`** et **`kind`**. C'est le point clé : le bandeau ne pouvait afficher que le nom de la conversation parce que rien d'autre ne lui parvenait. Les deux bulles connaissent déjà ces valeurs et les transmettent à `toggle` / `seekToRatioForMessage` — la carte musique passe son titre, la bulle vocale « Message vocal · *contact* ».

`kind` sert aussi à choisir la préférence de vitesse appliquée dans `_loadSource`, après `setFilePath`.

### Vitesse

`speed`, `setSpeed` et `cycleSpeed` sur le service. La pastille est identique dans les deux endroits, à la couleur près : blanc sur l'accent du bandeau, couleur de la bulle dans la conversation.

**La carte musique n'a pas de pastille**, seulement le bandeau — donc régler la vitesse d'un morceau sans quitter la conversation n'est pas possible. C'est une conséquence assumée du périmètre retenu, pas un oubli.

### Vidéo

Chewie 1.13.1 embarque déjà le menu de vitesse : `showOptions` et `allowPlaybackSpeedChanging` sont à `true` par défaut. Il n'y avait pas de menu à écrire — seulement à resserrer les paliers de huit à six, appliquer la vitesse mémorisée après `initialize()` et persister les changements. Chewie règle la vitesse directement sur le `VideoPlayerController` sans prévenir l'appelant, d'où l'observation du contrôleur plutôt que du menu.

`status_viewer_screen` est **exclu** des deux fonctionnalités : il construit son Chewie avec `showControls: false` et gère sa propre progression. Un viewer de stories qui défile seul n'a pas besoin de vitesse ni de seek.

### Double tap

Le geste est posé au-dessus du lecteur en `HitTestBehavior.translucent` et n'écoute que `onDoubleTapDown`, pour laisser passer le tap simple dont Chewie a besoin. Deux doubles taps rapprochés cumulent l'affichage (20 s), changer de côté repart de zéro, et la cible est bornée à la durée.

Pas de conflit avec le zoom : `InteractiveViewer` n'entoure que les images, jamais les vidéos.

### Correctifs

`_openVoiceChat` pose désormais un drapeau `isChatRouteOpen` sur le service avant le `push` et le lève dans un `finally`, sur le modèle de `call_ui.dart`.

La pause sur appel est câblée dans `main.dart`, où les deux providers sont créés : `VoicePlaybackService` est déclaré avant `CallService`, qui s'y abonne dans son `create`. Le test porte sur `status != idle && status != ended` et non sur `isCallActive`, **qui ignore le statut `incoming`** — sans quoi la sonnerie d'un appel entrant se serait superposée à la musique. Pas de reprise automatique en fin d'appel : une reprise surprise est plus gênante qu'un tap.

## Le défaut qui rendait le bandeau invisible

Le mini-lecteur ne s'était en réalité **jamais** affiché. `ChatDetailScreen.dispose()` appelait `context.read<VoicePlaybackService>()`, qui lève systématiquement sur Flutter 3.44 :

```dart
// framework.dart
void unmount() {          // StatefulElement, l. 6028
  super.unmount();        // Element.unmount vide _widget (l. 4863)
  state.dispose();        // ...puis seulement ici
}
```

Le contexte étant déjà vidé, la recherche de provider retourne `null`, Provider tente de lever une `ProviderNotFoundException` dont le message lit `context.widget.runtimeType`, et c'est ce `context.widget` qui explose. L'exception est avalée par le framework : rien ne plante visiblement, mais **tout ce qui suit dans le `dispose()` est sauté** — ici `leaveChat()`, donc `_backgroundPlayback` restait `false`.

La correction résout la référence dans `initState`, comme le fichier le faisait déjà pour `_chat` et `_apiClient`.

**Quatre autres écrans avaient le même défaut**, corrigés dans la foulée : `ongoing_meet_screen` (l'exception partait **avant** la libération des renderers WebRTC — fuite mémoire à chaque réunion quittée), `home_screen`, `incoming_call_screen`, et `ongoing_call_screen` dont le `try/catch` vide masquait le problème au prix d'un listener jamais retiré. Plus aucun `Provider.of` ni `context.read` ne subsiste dans un `dispose()` du projet.

## Trois défauts de comportement corrigés ensuite

**Le bandeau disparaissait en entrant dans une autre conversation.** `_attachToConversation` appelait `setChatContext` à chaque conversation ouverte, écrasant le contexte de celle qui joue — ce qui masquait le bandeau *et* aurait renvoyé au mauvais endroit. Le contexte vient désormais uniquement de la bulle, au moment de la lecture ; `setChatContext` a été supprimé. `enterChat` ne rend la main à la bulle que dans la conversation qui joue.

**400 à 600 ms avant l'apparition.** `dispose()` n'arrive qu'à la fin de la transition de sortie (≈300 ms), suivie de l'animation du bandeau (250 ms). `leaveChat()` part maintenant de `didPop()`, déclenché dès le pop, et reste dans `dispose()` en filet de sécurité.

**« Message vocal terminé » pour un morceau.** À l'affichage du message la source est déjà vidée par `_clearPlayback()` : le bandeau mémorise le type tant qu'il est visible, et la clé `musicEnded` donne « Musique terminée ».

**Le tap ramène jusqu'à la bulle.** `VoicePlaybackSource` porte le `serverMsgId` et `ChatDetailScreen` accepte un `focusMessageId`, qui réutilise `_scrollToReply` — le mécanisme déjà en place pour les réponses et les épinglés. Un vocal dont l'envoi n'est pas confirmé a un `serverMsgId` à `0` : le bandeau ouvre alors la conversation sans cibler la bulle, faute d'identifiant serveur.

## Vérification

`flutter analyze lib/ test/` : zéro erreur, zéro warning introduit.

`test/playback_speed_preferences_test.dart` : 9 tests au vert — défaut, aller-retour d'écriture, indépendance des types, rejet d'une valeur hors paliers, boucle de `nextSpeed`, formatage.

Suite complète inchangée : 16 échecs préexistants (`LocaleController not ready`, plugins absents en environnement de test, smoke test), identiques avec et sans ces modifications.

**Restent à valider sur appareil**, car ce sont des comportements de geste et de rendu :

1. Le bandeau affiche le titre du morceau, `1:42 / 5:55`, et la barre avance.
2. Taper le bandeau plusieurs fois de suite n'empile pas de doublon.
3. Une vitesse réglée sur un vocal tient sur le vocal suivant et après redémarrage.
4. Un appel entrant met la lecture en pause.
5. **Le tap simple atteint toujours les contrôles Chewie** malgré l'overlay de double tap — le point le plus incertain. Le tap simple est nécessairement retardé du délai de reconnaissance du double tap, le temps que l'arène de gestes tranche ; si le comportement gêne, le repli est le paramètre `customControls` de Chewie.
6. Le bandeau dans les deux thèmes, avec un titre long.
