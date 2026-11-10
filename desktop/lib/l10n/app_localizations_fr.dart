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
}
