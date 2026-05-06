# Sonneries d'appel

## Fichiers nécessaires

Ajoute un fichier MP3 pour la sonnerie d'appel entrant :

### `incoming_call.mp3` (obligatoire)
- **Chemin** : `assets/sounds/incoming_call.mp3`
- **Format** : MP3
- **Durée recommandée** : 3-5 secondes (sera en boucle)
- **Niveau sonore** : Médium à fort
- **Exemple** : Ringtone classique ou personnalisée

## Sources gratuites de sonneries

- [FreeSound](https://freesound.org/)
- [Zapsplat](https://www.zapsplat.com/music/category/sound-effects/)
- [Notification Sounds](https://notificationsounds.com/)

## Configuration

Les fichiers sont automatiquement inclus si le pubspec.yaml est configuré :

```yaml
flutter:
  assets:
    - assets/sounds/
```

## Utilisation

La sonnerie est jouée automatiquement quand :
- Un appel entrant est reçu
- Elle s'arrête quand l'appel est accepté ou rejeté
- Elle boucle jusqu'à action de l'utilisateur
