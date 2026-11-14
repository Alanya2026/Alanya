// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Alanya Coffre-fort';

  @override
  String get safeboxName => 'Coffre-fort';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSettings => 'Réglages';

  @override
  String get rootPhotos => 'Photos';

  @override
  String get rootVideos => 'Vidéos';

  @override
  String get rootAudios => 'Audio';

  @override
  String get rootDocuments => 'Documents';

  @override
  String get rootAlbums => 'Albums';

  @override
  String get rootShare => 'Partager';

  @override
  String get back => 'Retour';

  @override
  String get refresh => 'Actualiser';

  @override
  String get retry => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get errorNetwork =>
      'Pas de connexion au serveur. Vérifiez Internet, puis réessayez.';

  @override
  String get errorGeneric =>
      'Une erreur est survenue. Réessayez dans un instant.';

  @override
  String bytesB(int n) {
    return '$n o';
  }

  @override
  String bytesKB(String n) {
    return '$n Ko';
  }

  @override
  String bytesMB(String n) {
    return '$n Mo';
  }

  @override
  String bytesGB(String n) {
    return '$n Go';
  }

  @override
  String spaceUsedOf(String used, String total) {
    return '$used sur $total';
  }

  @override
  String spaceFree(String free) {
    return '$free libres';
  }

  @override
  String spaceTrash(String size) {
    return 'Corbeille · $size';
  }

  @override
  String fileCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers',
      one: '1 fichier',
      zero: 'Aucun fichier',
    );
    return '$_temp0';
  }

  @override
  String get homeFolders => 'Vos dossiers';

  @override
  String get homeRecentAlbums => 'Albums récents';

  @override
  String get folderEmpty => 'Vide';

  @override
  String get folderEmptyHint =>
      'Ajoutez des fichiers avec « Ajouter », ou déposez-les ici.';

  @override
  String get dateToday => 'Aujourd\'hui';

  @override
  String get dateYesterday => 'Hier';

  @override
  String get dateUnknown => 'Date inconnue';

  @override
  String get loginTitle => 'Connectez votre coffre-fort à cet ordinateur';

  @override
  String get loginStep1 => 'Ouvrez Alanya sur votre téléphone.';

  @override
  String get loginStep2 =>
      'Allez dans Compte et sécurité › Lier un nouvel appareil.';

  @override
  String get loginStep3 => 'Scannez ce code, puis confirmez sur le téléphone.';

  @override
  String get loginSharedComputer =>
      'Sur un ordinateur partagé, déconnectez-vous en partant (Réglages › Se déconnecter). Vous pouvez aussi retirer cet ordinateur à distance depuis « Appareils connectés » sur votre téléphone.';

  @override
  String get loginEndedRemotely =>
      'Cet ordinateur a été déconnecté. Scannez de nouveau le code pour l\'utiliser.';

  @override
  String get loginQrLabel => 'Code QR de connexion';

  @override
  String get loginQrHint => 'Le code change toutes les 90 secondes.';

  @override
  String get loginScannedTitle => 'Code scanné';

  @override
  String get loginScannedText => 'Confirmez la connexion sur votre téléphone.';

  @override
  String get loginDeniedTitle => 'Connexion refusée';

  @override
  String get loginDeniedText => 'La connexion a été refusée sur le téléphone.';

  @override
  String get loginExpiredTitle => 'Code expiré';

  @override
  String get loginExpiredText =>
      'Affichez un nouveau code pour vous connecter.';

  @override
  String get loginNewCode => 'Nouveau code';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsApp => 'Application';

  @override
  String get settingsComputerHint =>
      'Visible dans « Appareils connectés » sur votre téléphone';

  @override
  String settingsConnectedOn(String date) {
    return 'Connecté le $date · visible dans « Appareils connectés » sur votre téléphone';
  }

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Celle du système';

  @override
  String settingsVersion(String version) {
    return 'Alanya Coffre-fort $version';
  }

  @override
  String get logout => 'Se déconnecter';

  @override
  String get logoutTitle => 'Se déconnecter de cet ordinateur';

  @override
  String get logoutText =>
      'Efface tout ce que l\'application garde sur cet ordinateur. Vos fichiers restent dans le coffre.';

  @override
  String get logoutConfirmTitle => 'Se déconnecter ?';

  @override
  String get logoutConfirmText =>
      'L\'application efface ce qu\'elle garde sur cet ordinateur. Vos fichiers restent dans le coffre ; pour revenir, il faudra scanner de nouveau le code avec votre téléphone.';

  @override
  String get close => 'Fermer';

  @override
  String get save => 'Enregistrer';

  @override
  String get open => 'Ouvrir';

  @override
  String get empty => 'Vider';

  @override
  String get previous => 'Précédent';

  @override
  String get next => 'Suivant';

  @override
  String get download => 'Télécharger';

  @override
  String get downloadFolder => 'Télécharger le dossier';

  @override
  String downloadSaved(String path) {
    return 'Enregistré : $path';
  }

  @override
  String get downloadFailed => 'Le téléchargement n\'a pas abouti. Réessayez.';

  @override
  String get showInFolder => 'Afficher dans le dossier';

  @override
  String get openWith => 'Ouvrir avec…';

  @override
  String get openFailed =>
      'Aucun logiciel de l\'ordinateur ne sait ouvrir ce fichier.';

  @override
  String viewerPosition(int index, int total) {
    return '$index sur $total';
  }

  @override
  String get viewerKeys =>
      '← → pour passer d\'un fichier à l\'autre · molette pour zoomer · Échap pour fermer';

  @override
  String get viewerCannotShow =>
      'L\'ordinateur ne sait pas afficher cette photo ici.';

  @override
  String get viewerVideoHint =>
      'La vidéo s\'ouvre dans le lecteur de l\'ordinateur.';

  @override
  String get viewerAudioHint =>
      'L\'audio s\'ouvre dans le lecteur de l\'ordinateur.';

  @override
  String get viewerDocumentHint =>
      'Le document s\'ouvre avec le logiciel de l\'ordinateur.';

  @override
  String get viewerPlay => 'Lire';

  @override
  String get fileLost =>
      'Ce fichier est introuvable chez l\'hébergeur : il ne peut plus être ouvert.';

  @override
  String get noteNone => 'Pas de commentaire.';

  @override
  String get noteAdd => 'Ajouter un commentaire';

  @override
  String get noteEdit => 'Modifier le commentaire';

  @override
  String get noteEditTitle => 'Commentaire';

  @override
  String get noteHint =>
      'Quelques mots sur ce fichier (200 caractères au plus)';

  @override
  String get noteAudio => 'Commentaire audio';

  @override
  String get noteListen => 'Écouter le commentaire audio';

  @override
  String exportRunning(String name) {
    return 'Téléchargement de $name';
  }

  @override
  String exportRunningMany(String name, int done, int total) {
    return 'Téléchargement de $name : $done sur $total';
  }

  @override
  String exportDone(String name) {
    return '$name est sur l\'ordinateur';
  }

  @override
  String exportFailed(String name) {
    return '$name n\'a pas pu être téléchargé';
  }

  @override
  String exportCancelled(String name) {
    return 'Téléchargement de $name arrêté';
  }

  @override
  String get settingsFiles => 'Fichiers sur cet ordinateur';

  @override
  String get settingsDownloadFolder => 'Dossier des téléchargements';

  @override
  String get settingsKeptFiles => 'Fichiers gardés pour la visionneuse';

  @override
  String settingsKeptFilesSize(String size) {
    return '$size · 1 Go au plus, les plus anciens s\'effacent · se retéléchargent au besoin';
  }

  @override
  String get add => 'Ajouter';

  @override
  String get addFiles => 'Des fichiers…';

  @override
  String get addFolder => 'Un dossier…';

  @override
  String dropHere(String folder) {
    return 'Déposer ici pour ajouter à $folder';
  }

  @override
  String importScanning(int n) {
    return 'Analyse des fichiers… $n';
  }

  @override
  String importChecking(int done, int total) {
    return 'Comparaison avec le coffre… $done / $total';
  }

  @override
  String importPreparing(int done, int total) {
    return 'Préparation des envois… $done / $total';
  }

  @override
  String importTitle(String folder) {
    return 'Ajouter à $folder';
  }

  @override
  String importSend(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers à envoyer',
      one: '1 fichier à envoyer',
    );
    return '$_temp0 · $size';
  }

  @override
  String importLink(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n fichiers déjà dans le coffre, ajoutés à l\'album sans nouvel envoi',
      one: '1 fichier déjà dans le coffre, ajouté à l\'album sans nouvel envoi',
    );
    return '$_temp0';
  }

  @override
  String importAlready(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers déjà dans le coffre, pas renvoyés',
      one: '1 fichier déjà dans le coffre, pas renvoyé',
    );
    return '$_temp0';
  }

  @override
  String importDiverted(int n, String root) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers iront dans $root, le dossier de leur type',
      one: '1 fichier ira dans $root, le dossier de son type',
    );
    return '$_temp0';
  }

  @override
  String importTooLarge(int n, String max) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers dépassent $max et ne partiront pas',
      one: '1 fichier dépasse $max et ne partira pas',
    );
    return '$_temp0';
  }

  @override
  String importIgnored(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers cachés, vides ou raccourcis laissés de côté',
      one: '1 fichier caché, vide ou raccourci laissé de côté',
    );
    return '$_temp0';
  }

  @override
  String importFree(String size) {
    return 'Place libre dans le coffre : $size';
  }

  @override
  String importNoRoom(String size) {
    return 'Pas assez de place : il manque $size. Videz la corbeille ou ajoutez moins de fichiers.';
  }

  @override
  String get importOriginal =>
      'Les fichiers partent en Original, tels qu\'ils sont sur l\'ordinateur. Ils restent sur l\'ordinateur.';

  @override
  String get importNothing => 'Rien à envoyer : tout est déjà dans le coffre.';

  @override
  String get importStart => 'Envoyer';

  @override
  String get importFailed => 'Les fichiers n\'ont pas pu être lus.';

  @override
  String get importBusy => 'Un ajout est déjà en préparation.';

  @override
  String get uploadsTitle => 'Envois vers le coffre';

  @override
  String uploadsRunning(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Envoi de $n fichiers',
      one: 'Envoi d\'1 fichier',
    );
    return '$_temp0';
  }

  @override
  String uploadsDone(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers ajoutés au coffre',
      one: '1 fichier ajouté au coffre',
    );
    return '$_temp0';
  }

  @override
  String uploadsFailed(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n envois n\'ont pas abouti',
      one: '1 envoi n\'a pas abouti',
    );
    return '$_temp0';
  }

  @override
  String uploadsPaused(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n envois en pause',
      one: '1 envoi en pause',
    );
    return '$_temp0';
  }

  @override
  String get uploadsWaitingNetwork => 'En attente du réseau';

  @override
  String get pauseAll => 'Tout mettre en pause';

  @override
  String get resumeAll => 'Tout reprendre';

  @override
  String get details => 'Détails';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Reprendre';

  @override
  String get clearFinished => 'Effacer les terminés';

  @override
  String speed(String size) {
    return '$size/s';
  }

  @override
  String get uploadQueued => 'En attente';

  @override
  String get uploadPaused => 'En pause';

  @override
  String get uploadDone => 'Dans le coffre';

  @override
  String get uploadErrorQuota => 'Plus assez de place dans le coffre';

  @override
  String get uploadErrorChanged =>
      'Le fichier a changé sur l\'ordinateur pendant l\'envoi';

  @override
  String get uploadErrorMissing => 'Le fichier n\'est plus sur l\'ordinateur';

  @override
  String get uploadErrorGeneric => 'L\'envoi n\'a pas abouti';

  @override
  String get change => 'Changer';

  @override
  String get newFolder => 'Nouveau dossier';

  @override
  String get newAlbum => 'Nouvel album';

  @override
  String get folderNameLabel => 'Nom du dossier';

  @override
  String get albumNameLabel => 'Nom de l\'album';

  @override
  String get fileNameLabel => 'Nom du fichier';

  @override
  String get create => 'Créer';

  @override
  String get rename => 'Renommer';

  @override
  String get move => 'Déplacer…';

  @override
  String get moveTitle => 'Déplacer vers';

  @override
  String get moveHere => 'Déplacer ici';

  @override
  String get addToAlbum => 'Ajouter à un album…';

  @override
  String get addToAlbumTitle => 'Ajouter à un album';

  @override
  String get addHere => 'Ajouter ici';

  @override
  String addedToAlbum(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers ajoutés à l\'album, sans copie',
      one: '1 fichier ajouté à l\'album, sans copie',
    );
    return '$_temp0';
  }

  @override
  String moved(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n éléments déplacés',
      one: '1 élément déplacé',
    );
    return '$_temp0';
  }

  @override
  String get toTrash => 'Mettre à la corbeille';

  @override
  String movedToTrash(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n éléments mis à la corbeille',
      one: '1 élément mis à la corbeille',
    );
    return '$_temp0';
  }

  @override
  String deleteWhich(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Certains de ces fichiers sont aussi ailleurs dans le coffre',
      one: 'Ce fichier est aussi ailleurs dans le coffre',
    );
    return '$_temp0';
  }

  @override
  String deleteHereOnly(String place) {
    return 'Retirer de « $place » seulement';
  }

  @override
  String deleteHereOnlyHint(String other) {
    return 'Il reste dans « $other ». Aucun espace libéré.';
  }

  @override
  String get deleteEverywhere => 'Supprimer partout';

  @override
  String get deleteEverywhereHint =>
      'Il va à la corbeille ; l\'espace est libéré quand elle est vidée.';

  @override
  String selectedCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n éléments sélectionnés',
      one: '1 élément sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Tout sélectionner';

  @override
  String get clearSelection => 'Désélectionner';

  @override
  String get folderKeysHint =>
      'Double-clic pour ouvrir · Ctrl ou Maj + clic pour sélectionner · Suppr : corbeille · F2 : renommer · clic droit : menu';

  @override
  String get errorNameTaken => 'Ce nom est déjà pris dans ce dossier.';

  @override
  String get errorWrongFamily =>
      'Ce dossier n\'accepte pas ce type de fichier.';

  @override
  String get errorInvalidMove => 'Un dossier ne se range pas dans lui-même.';

  @override
  String get errorTooDeep => 'Trop de niveaux de dossiers.';

  @override
  String get errorFolderLimit => 'Trop de dossiers dans le coffre.';

  @override
  String get errorInvalidName => 'Ce nom n\'est pas valide.';

  @override
  String get errorRootLocked =>
      'Les dossiers principaux ne se renomment, ne se déplacent ni ne se suppriment.';

  @override
  String get errorNotFound => 'Cet élément n\'existe plus.';

  @override
  String get navTrash => 'Corbeille';

  @override
  String get trashEmptyState => 'La corbeille est vide';

  @override
  String trashHint(int days) {
    return 'Les éléments restent $days jours dans la corbeille, puis sont supprimés définitivement. Ils comptent dans votre espace jusque-là.';
  }

  @override
  String get emptyTrash => 'Vider la corbeille';

  @override
  String get emptyTrashConfirm =>
      'Tout le contenu de la corbeille sera supprimé définitivement. Impossible de revenir en arrière.';

  @override
  String get restore => 'Restaurer';

  @override
  String get restored => 'Restauré';

  @override
  String get deleteForever => 'Supprimer définitivement';

  @override
  String deleteForeverConfirm(String name) {
    return '« $name » sera supprimé définitivement.';
  }

  @override
  String trashPurgeIn(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Supprimé définitivement dans $n jours',
      one: 'Supprimé définitivement demain',
      zero: 'Supprimé définitivement aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String place) {
    return 'Depuis $place';
  }

  @override
  String get freeUp => 'Libérer de l\'espace';

  @override
  String get freeUpIntro =>
      'Les plus gros fichiers du coffre. Ceux que vous choisissez partent de partout, albums compris, pour que leur place soit vraiment libérée.';

  @override
  String get freeUpHint =>
      'Les fichiers mis à la corbeille comptent encore dans votre espace jusqu\'à ce que la corbeille soit vidée.';

  @override
  String freeUpSelected(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers',
      one: '1 fichier',
    );
    return '$_temp0 · $size';
  }

  @override
  String freeUpTrash(String size) {
    return 'La corbeille occupe $size';
  }

  @override
  String get freeUpNothing => 'Aucun fichier dans le coffre';

  @override
  String get navPcBackup => 'Sauvegarde du PC';

  @override
  String get pcBackupIntro =>
      'Chaque dossier choisi est recréé dans Albums avec ses sous-dossiers, et ses fichiers apparaissent aussi dans Photos, Vidéos, Audios ou Documents, sans place en plus. Un fichier supprimé du PC reste dans le coffre ; un fichier supprimé du coffre ne revient pas.';

  @override
  String get pcBackupSwitch => 'Sauvegarder ces dossiers automatiquement';

  @override
  String get pcBackupOpenOnly =>
      'Tant que l\'application tourne, fenêtre ouverte ou icône près de l\'horloge : un passage au démarrage, après chaque changement dans les dossiers, et toutes les 15 minutes. En Original.';

  @override
  String get pcBackupFolders => 'Dossiers sauvegardés';

  @override
  String get pcBackupAddFolder => 'Ajouter un dossier…';

  @override
  String get pcBackupNoFolder =>
      'Aucun dossier choisi. Ajoutez par exemple Images ou Documents.';

  @override
  String get pcBackupRemoveFolder => 'Ne plus sauvegarder ce dossier';

  @override
  String pcBackupRemoveConfirm(String name) {
    return '« $name » ne sera plus sauvegardé. Ce qui est déjà dans le coffre y reste.';
  }

  @override
  String get pcBackupFolderMissing => 'Dossier introuvable sur ce PC';

  @override
  String get pcBackupAlreadyAdded => 'Ce dossier est déjà sauvegardé.';

  @override
  String get pcBackupNoType => 'Choisissez au moins un type de fichier.';

  @override
  String get pcBackupRunNow => 'Sauvegarder maintenant';

  @override
  String get pcBackupListing => 'Lecture des dossiers…';

  @override
  String pcBackupChecking(int done, int total) {
    return 'Comparaison avec le coffre… $done / $total';
  }

  @override
  String pcBackupRemaining(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers à envoyer',
      one: '1 fichier à envoyer',
      zero: 'À jour',
    );
    return '$_temp0';
  }

  @override
  String pcBackupLast(String time) {
    return 'Dernier passage : $time';
  }

  @override
  String get pcBackupNever => 'Pas encore de passage';

  @override
  String get pcBackupOff => 'Sauvegarde arrêtée';

  @override
  String pcBackupQueued(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers envoyés',
      one: '1 fichier envoyé',
      zero: 'rien de nouveau',
    );
    return '$_temp0';
  }

  @override
  String pcBackupAlready(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n déjà dans le coffre',
      one: '1 déjà dans le coffre',
    );
    return '$_temp0';
  }

  @override
  String pcBackupSkipped(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n supprimés du coffre, pas renvoyés',
      one: '1 supprimé du coffre, pas renvoyé',
    );
    return '$_temp0';
  }

  @override
  String pcBackupNoRoom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers attendent de la place dans le coffre',
      one: '1 fichier attend de la place dans le coffre',
    );
    return '$_temp0';
  }

  @override
  String pcBackupUnreadable(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers illisibles',
      one: '1 fichier illisible',
    );
    return '$_temp0';
  }

  @override
  String pcBackupFailed(String reason) {
    return 'Le dernier passage n\'a pas abouti. $reason';
  }

  @override
  String pcBackupEstimateTitle(String name) {
    return 'Sauvegarder « $name »';
  }

  @override
  String get pcBackupTypes => 'Ce qui part :';

  @override
  String pcBackupEstimate(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fichiers · $size',
      one: '1 fichier · $size',
      zero: 'Aucun fichier de ces types pour l\'instant.',
    );
    return '$_temp0';
  }

  @override
  String get pcBackupEstimateHint =>
      'Ce qui est déjà dans le coffre (sauvegardé depuis le téléphone, par exemple) ne repartira pas : l\'envoi réel peut être plus léger. Les plus récents partent d\'abord ; si la place manque, les plus anciens attendent.';

  @override
  String get pcBackupStart => 'Sauvegarder';

  @override
  String get pcBackupHome => 'Sauvegarde du PC';

  @override
  String updateAvailable(String version) {
    return 'La version $version d\'Alanya Coffre-fort est disponible.';
  }

  @override
  String get updateDownload => 'Télécharger';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get filterWithNote => 'Avec commentaire';

  @override
  String get filterAll => 'Tout';

  @override
  String get folderCamera => 'Appareil photo';

  @override
  String get folderScreenshots => 'Captures d\'écran';

  @override
  String get folderDownloads => 'Images téléchargées';

  @override
  String get pcRemoveTitle => 'Retirer de l\'ordinateur après la sauvegarde';

  @override
  String get pcRemoveHint =>
      'Les photos et vidéos gardées en Original dans le coffre vont dans la corbeille de l\'ordinateur, d\'où vous pouvez les récupérer tant qu\'elle n\'est pas vidée. Les documents et les audios restent sur l\'ordinateur.';

  @override
  String get pcRemoveWhen => 'Quand les retirer';

  @override
  String pcRemoveAfter(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Après $n jours',
      one: 'Après 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get pcRemoveNow => 'Tout de suite';

  @override
  String get pcRemoveConfirmTitle => 'Retirer de l\'ordinateur ?';

  @override
  String get pcRemoveConfirm =>
      'Une fois arrivées dans le coffre en Original, et vérifiées auprès du serveur juste avant, les photos et vidéos des dossiers sauvegardés iront dans la corbeille de l\'ordinateur. Vous pourrez les récupérer depuis la corbeille tant que vous ne la videz pas, et toujours depuis le coffre.';

  @override
  String get pcRemoveConfirmAction => 'Activer';

  @override
  String pcRemoved(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos et vidéos mises à la corbeille de l\'ordinateur',
      one: '1 photo ou vidéo mise à la corbeille de l\'ordinateur',
    );
    return '$_temp0 · $size libérés';
  }

  @override
  String get pcBackupRename => 'Renommer';

  @override
  String get pcBackupNameLabel => 'Nom dans le coffre';

  @override
  String get pcBackupRenameHint =>
      'Le dossier garde ce nom dans le coffre (son album dans Albums, et le dossier d\'origine dans Photos et Vidéos). Le dossier de l\'ordinateur ne change pas, et la sauvegarde continue.';

  @override
  String pcBackupTooLarge(int n, String max) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n fichiers dépassent $max, la limite d\'un fichier du coffre : ils restent sur l\'ordinateur',
      one:
          '1 fichier dépasse $max, la limite d\'un fichier du coffre : il reste sur l\'ordinateur',
    );
    return '$_temp0';
  }

  @override
  String get trayOpen => 'Ouvrir Alanya Coffre-fort';

  @override
  String get trayBackupNow => 'Sauvegarder maintenant';

  @override
  String get trayQuit => 'Quitter';

  @override
  String get settingsKeepRunning =>
      'Continuer près de l\'horloge quand la fenêtre est fermée';

  @override
  String get settingsKeepRunningHint =>
      'La sauvegarde du PC et les envois continuent. Pour quitter vraiment : icône Alanya près de l\'horloge › Quitter.';

  @override
  String get settingsAutostart => 'Lancer au démarrage de l\'ordinateur';

  @override
  String get settingsAutostartHint =>
      'Alanya Coffre-fort s\'ouvre caché près de l\'horloge à l\'ouverture de votre session : la sauvegarde du PC tourne sans y penser.';

  @override
  String get settingsTrayUnavailable =>
      'L\'icône près de l\'horloge n\'est pas disponible sur ce système : fermer la fenêtre quitte l\'application.';
}
