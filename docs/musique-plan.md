# Envoi de musiques avec lecteur dédié

## Problème

L'app ne savait pas envoyer de musique. Un MP3 ne pouvait passer que par « Fichier » : il partait en `type = 4` et s'affichait comme une ligne de document grise, ouvrable seulement dans une app externe.

Le partage OS mappait bien `audio/*` vers `type = 3`, mais le morceau prenait alors l'apparence d'un message vocal — icône micro, waveform, et `0:00` tant que la lecture n'avait pas démarré, faute de `mediaDuration`.

Plusieurs formats étaient par ailleurs rejetés par le serveur, dont `.wav` : le package `mime` renvoie `audio/x-wav` alors que la whitelist n'acceptait que `audio/wav`.

## Décisions

| Sujet | Décision |
|---|---|
| Discriminant | La musique **reste `type = 3`**. Un helper tranche vocal vs musique sur l'extension de `mediaName`. Aucun nouveau type, aucune migration, aucune rupture avec les clients existants. |
| Métadonnées | Pochette seule, en base64 dans la colonne `mediaThumb` existante. Pas d'artiste : aucune colonne ne peut le transporter. |
| Moteur | `VoicePlaybackService` inchangé et partagé — un morceau coupe un vocal en cours, et le mini-lecteur du bandeau fonctionne sans modification. |
| Bulle vocale | Inchangée visuellement. |

Le discriminant tient parce qu'un vocal enregistré porte toujours `mediaName = l10n.voiceMessage` — une chaîne localisée sans extension. Effet de bord voulu : les MP3 déjà reçus via le partage OS basculent rétroactivement sur la nouvelle UI.

**Piège** : ne jamais appliquer le helper à un *chemin de fichier*. Un vocal est stagé en `voice_<timestamp>.m4a` et son extension le ferait passer pour de la musique. Toujours l'appliquer à `mediaName`.

## Correctifs inclus — le spinner à la première lecture

Deux causes distinctes produisaient le même symptôme, il a fallu traiter les deux.

### 1. La waveform bloquait la mise à disposition du fichier

`VoiceMessageCoordinator._ensureReady` n'atteignait `ready` qu'après l'extraction de la waveform, alors que `_toggle` refuse de jouer hors phase `ready`. Fichier déjà sur le disque, immédiatement jouable, mais bouton bloqué en spinner le temps de calculer un décor — extraction sérialisée, timeout 15 s. Les fois suivantes la waveform était en cache, d'où un défaut visible uniquement à la première lecture.

Jouabilité et waveform sont désormais découplées : `ready` est émis dès la résolution du chemin local, l'extraction tourne en tâche de fond (`_scheduleWaveform`) et pousse un second snapshot. Un garde vérifie que le snapshot courant porte toujours le même fichier avant d'écrire, pour ne pas écraser un `invalidate()` concurrent. `VoiceUiPhase.extracting` a disparu.

### 2. `AudioPlayer.play()` était attendu, donc l'état « chargement » ne retombait jamais

C'est la cause principale, et elle est documentée dans just_audio :

> The Future returned by this method completes when the playback completes **or is paused or stopped**.

`await _player.play()` ne rend donc la main qu'à la **fin** du morceau. Comme `_loadingMessageId` n'était remis à `null` que dans le `finally` de `play()`, il restait armé pendant toute la lecture. Trois conséquences se cumulaient dans la bulle : rendu d'un spinner, `onPressed` à `null`, et `toggle()` qui avalait le tap (`if (_loadingMessageId == messageId) return`). D'où un spinner permanent dès le premier démarrage, sans aucun moyen d'arrêter.

Les quatre sites qui démarraient la lecture passent désormais par `_startPlayback()`, qui lance `play()` sans l'attendre. `_playing` est posé avant, et le `playerStateStream` reste la source de vérité ensuite.

Une fois cela corrigé, la fenêtre « chargement » se réduit au seul `setFilePath`. Elle est traitée en **démarrage optimiste et annulable** : la bulle affiche l'icône pause dès le tap plutôt qu'un spinner, le bouton reste actif, et un tap pendant cette fenêtre appelle `cancelPendingStart`, qui pose un drapeau relu par `play()` juste avant le démarrage — sans aucun `await` entre le test et le démarrage, pour ne pas rouvrir la course. Le player n'est pas touché pendant le chargement : un `stop()` concurrent au `setFilePath` lèverait une exception qui remonterait à l'UI en « audio indisponible ». La source finit de se charger et reste prête, simplement à l'arrêt.

Les barres de scrub restent actives pendant le décodage : `seekToRatioForMessage` ignore déjà un seek en cours de chargement, et les garder actives évite un clignotement du curseur.

## Implémentation

### Nouveaux fichiers

| Fichier | Rôle |
|---|---|
| `lib/core/utils/audio_message_kind.dart` | `AudioMessageKind`, `audioKindFromName`, `musicExtensionOf`, `musicTitleFromName` |
| `lib/core/services/music_metadata_service.dart` | Pochette base64 et durée d'un fichier musical |
| `lib/screens/chats/music_message_bubble.dart` | La carte de lecture |
| `test/audio_message_kind_test.dart` | Couverture du helper |

`lib/widgets/voice_seek_bar.dart` → `lib/widgets/audio_seek_bar.dart` : la classe était du code mort, jamais instanciée, et faisait déjà exactement la barre de scrub voulue. Renommage, pas de réécriture.

### Bulle

Carte : pochette 56×56 (rayon `AppRadius.brSm`, note de musique en repli), titre `bodyMedium` w600 sur deux lignes max, sous-titre `EXT · taille`, puis ligne de transport — bouton 34 px, `AudioSeekBar`, temps en chiffres tabulaires. Largeur minimale 260.

Le temps reprend la bascule de la bulle vocale : durée seule au repos, `position / durée` dès que la lecture a démarré.

L'aiguillage est dans `chat_bubbles.dart`, `case 3` de `_buildMedia`.

### Envoi

`_pickMusic` dans `chat_actions.dart` : `FilePicker(type: FileType.audio)`, envoi en `type = 3` avec le nom de fichier réel et la durée lue avant l'envoi — sans quoi la bulle afficherait `0:00`.

`MusicMetadataService.durationSeconds` lit d'abord les tags (gratuit, le fichier est déjà parsé pour la pochette) puis retombe sur just_audio.

Dans `message_sender.dart` : `_mediaThumbFor` prend `mediaName` et produit la pochette pour un audio musical ; la garde `mediaSize` couvre désormais la musique en plus des documents.

Entrée « Musique » en 2ᵉ ligne du menu pièce jointe, icône `music_note`, couleur `tertiary`.

### Formats débloqués

Whitelist serveur élargie aux variantes `x-` que le package `mime` produit et que le serveur refusait : `audio/x-wav`, `audio/x-flac`, `audio/opus`, `audio/x-ms-wma`, `audio/x-aiff`, `audio/midi`, `audio/x-caf`, `audio/amr`, plus `audio/mp3` et `audio/wave`.

Côté client, `_mimeFallbackFromExtension` couvre les extensions que `mime` ignore — `opus` en tête, qui retombait sur `application/octet-stream`.

### Aperçus

`conversation_merge.previewForMedia` et `forward_message.mediaLabelForType` distinguent les deux, tout comme `messagePreview.js` côté serveur : `🎵 Titre` pour un morceau, `🎤 Message vocal` pour un vocal. Icônes d'aperçu correspondantes dans l'écran de transfert et l'écran de partage.

La liste d'extensions est dupliquée entre Dart et Node, inévitable sans code partagé entre les deux dépôts. Un commentaire croisé la signale des deux côtés.

Corrigé au passage : `_mediaLabel` renvoyait une chaîne vide pour un type inconnu, ce qui produisait une bulle littéralement vide chez un client plus ancien. Il renvoie maintenant `mediaFallback`.

## Hors périmètre

- Onglet Audio dans la galerie de médias de conversation.
- Section médias de `group_detail_screen` / `contact_detail_screen` — le `_MediaCard` y est dupliqué, à factoriser d'abord.
- Export vers le dossier Musique de l'appareil.
- Auto-téléchargement des musiques entrantes : délibérément laissé manuel, comme les vocaux. Le plafond de téléchargement passe de 15 à 50 Mo pour la musique, aligné sur la limite d'envoi.
- Lecteur plein écran, envoi de plusieurs morceaux d'un coup, écran de légende avant envoi.

## Vérification

`flutter analyze lib/ test/` : zéro erreur, zéro warning introduit.

`test/audio_message_kind_test.dart` et `test/voice_message_pipeline_test.dart` : 18 tests au vert. Le second verrouille le correctif — `ensureReady` atteint `ready` **avant** que la waveform soit disponible, et la waveform arrive après coup sans quitter la phase `ready`.

Le reste de la suite est inchangé : 16 échecs préexistants (`LocaleController not ready`, plugins absents en environnement de test, smoke test), identiques avec et sans ces modifications — vérifié par comparaison `git stash` sur le sous-ensemble concerné.

Restent à valider sur appareil : l'affichage de la pochette de bout en bout, la lecture et le scrub, l'exclusion mutuelle avec un vocal, et l'envoi d'un `.wav` et d'un `.flac`.
