# Alanya Coffre-fort (bureau)

Le coffre-fort Alanya sur Windows et Linux. Conception :
`Alanya-backend/docs/conception/coffre-bureau.html`.

Le code du coffre (chiffrement, API, envois, téléchargements) vient du paquet
commun `../packages/alanya_safebox`, partagé avec l'application mobile.

## Linux

Une fois sur le poste :

    sudo apt install pkg-config clang cmake ninja-build libgtk-3-dev libsecret-1-dev libmpv-dev

Puis :

    flutter run -d linux
    flutter build linux --release   # build/linux/x64/release/bundle/alanya_coffre

## Windows

Construit sur une machine Windows (Flutter ne construit pas pour Windows
depuis Linux) : `flutter build windows --release`.
