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
  String get folderEmptyHint => 'Ajoutez des fichiers depuis votre téléphone.';

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
    return '$size · se retéléchargent au besoin';
  }
}
