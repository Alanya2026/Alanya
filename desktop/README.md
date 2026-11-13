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
   `pubspec.yaml` (ex. `1.1.0+2`) et `kAppVersion` de
   `lib/core/app_version.dart` (ex. `'1.1.0'`). Un test le vérifie.
2. **Construire** : commiter, pousser, puis poser l'étiquette :

       git tag coffre-v1.1.0
       git push origin coffre-v1.1.0

   GitHub Actions (« Coffre de bureau ») construit l'installateur Windows,
   le .deb et l'AppImage, et prépare `version.json`. Environ 15 minutes.
3. **Récupérer** : GitHub › Actions › la construction › artefact
   `coffre-release` (un zip). Le décompresser. Dans `version.json`, écrire
   au besoin les nouveautés (`notes.fr`, `notes.en`), affichées sur la page.
4. **Essayer** l'installateur sur un PC Windows et le .deb sur une Ubuntu :
   connexion QR, parcours, ajout, téléchargement.
5. **Déposer sur le serveur** (depuis le dossier décompressé) :

       ssh ubuntu@www.alanya237.com 'mkdir -p ~/Alanya-backend/downloads/coffre'
       scp *.exe *.deb *.AppImage ubuntu@www.alanya237.com:~/Alanya-backend/downloads/coffre/
       scp version.json ubuntu@www.alanya237.com:~/Alanya-backend/downloads/coffre/

   `version.json` en dernier : la page et l'avis « nouvelle version » ne
   changent qu'à ce moment, quand les fichiers sont déjà là. Pas de
   redémarrage du serveur.
6. **Vérifier** : https://www.alanya237.com/coffre affiche la nouvelle
   version et ses trois boutons. Les applications déjà installées affichent
   « Nouvelle version disponible » au prochain démarrage (ou dans les 24 h).

Les anciennes versions peuvent rester dans le dossier : seuls les fichiers
annoncés par `version.json` se téléchargent.
