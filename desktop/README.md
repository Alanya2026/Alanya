# Alanya Coffre-fort (bureau)

Le coffre-fort Alanya sur Windows et Linux. Conception :
`Alanya-backend/docs/conception/coffre-bureau.html`.

Le code du coffre (chiffrement, API, envois, téléchargements) vient du paquet
commun `../packages/alanya_safebox`, partagé avec l'application mobile.

## Linux

Une fois sur le poste :

    sudo apt install pkg-config clang cmake ninja-build libgtk-3-dev libsecret-1-dev

Puis :

    flutter run -d linux
    flutter build linux --release   # build/linux/x64/release/bundle/alanya_coffre

Paquet .deb à partir de ce build (dans `dist/`) :

    linux/packaging/build_packages.sh 1.0.0

## Windows

Construit sur une machine Windows (Flutter ne construit pas pour Windows
depuis Linux) : `flutter build windows --release`, puis l'installateur
Inno Setup `windows/installer/alanya_coffre.iss`. En pratique, c'est GitHub
Actions qui le fait (ci-dessous).

## Publier une version

Les fichiers sont servis par le serveur, sur `alanya237.com/coffre`
(dépôt privé : pas de téléchargement public sur GitHub). Rien n'est payant ;
les minutes GitHub Actions sont gratuites dans la limite offerte au dépôt.

1. **Numéro de version** : le même à deux endroits, `version:` de
   `pubspec.yaml` (ex. `1.2.0+3`) et `kAppVersion` de
   `lib/core/app_version.dart` (ex. `'1.2.0'`). Un test le vérifie.
2. **Nouveautés** affichées sur la page : `release-notes.json` (fr, en).
3. **Commiter, pousser, puis poser l'étiquette** :

       git tag coffre-v1.2.0
       git push origin coffre-v1.2.0

   GitHub Actions (« Coffre de bureau », environ 15 minutes) construit
   l'installateur Windows, le .deb et l'AppImage, puis les **dépose sur le
   VPS** (`~/Alanya-backend/downloads/coffre`), `version.json` en dernier.
   La page affiche alors la nouvelle version, et les applications déjà
   installées l'annoncent (au démarrage, ou dans les 24 h). Pas de
   redémarrage du serveur.
4. **Vérifier** : https://www.alanya237.com/coffre affiche la version.

### Une fois : la clé de dépôt sur le VPS

Le dépôt automatique a besoin de quatre secrets dans le dépôt GitHub
Alanya (Settings › Secrets and variables › Actions › New repository
secret). Sans eux, la construction réussit quand même et l'avertit : les
fichiers se déposent alors à la main (ci-dessous).

Une clé SSH réservée à ce dépôt, créée sur un poste qui se connecte au VPS :

    ssh-keygen -t ed25519 -f ~/.ssh/alanya_coffre_depot -N "" -C "coffre bureau GitHub"
    ssh-copy-id -i ~/.ssh/alanya_coffre_depot.pub ubuntu@www.alanya237.com

| Secret | Valeur |
|---|---|
| `ALANYA_HOST` | `www.alanya237.com` |
| `ALANYA_USER` | `ubuntu` |
| `ALANYA_PORT` | `22` |
| `ALANYA_SSH_KEY` | tout le contenu de `~/.ssh/alanya_coffre_depot` (la clé privée, lignes BEGIN et END comprises) |

La clé privée ne va nulle part ailleurs ; pour la révoquer, retirer sa
ligne (« coffre bureau GitHub ») de `~/.ssh/authorized_keys` sur le VPS.

### Déposer à la main (sans les secrets)

Télécharger l'artefact `coffre-release` (GitHub › Actions › la
construction), le décompresser, puis :

    ssh ubuntu@www.alanya237.com 'mkdir -p ~/Alanya-backend/downloads/coffre'
    scp *.exe *.deb *.AppImage ubuntu@www.alanya237.com:~/Alanya-backend/downloads/coffre/
    scp version.json ubuntu@www.alanya237.com:~/Alanya-backend/downloads/coffre/

`version.json` en dernier. Les anciennes versions peuvent rester dans le
dossier : seuls les fichiers annoncés par `version.json` se téléchargent.
