import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alanya Coffre-fort'**
  String get appTitle;

  /// No description provided for @safeboxName.
  ///
  /// In fr, this message translates to:
  /// **'Coffre-fort'**
  String get safeboxName;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get navSettings;

  /// No description provided for @rootPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get rootPhotos;

  /// No description provided for @rootVideos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get rootVideos;

  /// No description provided for @rootAudios.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get rootAudios;

  /// No description provided for @rootDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get rootDocuments;

  /// No description provided for @rootAlbums.
  ///
  /// In fr, this message translates to:
  /// **'Albums'**
  String get rootAlbums;

  /// No description provided for @rootShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get rootShare;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @refresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion au serveur. Vérifiez Internet, puis réessayez.'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessayez dans un instant.'**
  String get errorGeneric;

  /// No description provided for @bytesB.
  ///
  /// In fr, this message translates to:
  /// **'{n} o'**
  String bytesB(int n);

  /// No description provided for @bytesKB.
  ///
  /// In fr, this message translates to:
  /// **'{n} Ko'**
  String bytesKB(String n);

  /// No description provided for @bytesMB.
  ///
  /// In fr, this message translates to:
  /// **'{n} Mo'**
  String bytesMB(String n);

  /// No description provided for @bytesGB.
  ///
  /// In fr, this message translates to:
  /// **'{n} Go'**
  String bytesGB(String n);

  /// No description provided for @spaceUsedOf.
  ///
  /// In fr, this message translates to:
  /// **'{used} sur {total}'**
  String spaceUsedOf(String used, String total);

  /// No description provided for @spaceFree.
  ///
  /// In fr, this message translates to:
  /// **'{free} libres'**
  String spaceFree(String free);

  /// No description provided for @spaceTrash.
  ///
  /// In fr, this message translates to:
  /// **'Corbeille · {size}'**
  String spaceTrash(String size);

  /// No description provided for @fileCount.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Aucun fichier} =1{1 fichier} other{{n} fichiers}}'**
  String fileCount(int n);

  /// No description provided for @homeFolders.
  ///
  /// In fr, this message translates to:
  /// **'Vos dossiers'**
  String get homeFolders;

  /// No description provided for @homeRecentAlbums.
  ///
  /// In fr, this message translates to:
  /// **'Albums récents'**
  String get homeRecentAlbums;

  /// No description provided for @folderEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Vide'**
  String get folderEmpty;

  /// No description provided for @folderEmptyHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des fichiers avec « Ajouter », ou déposez-les ici.'**
  String get folderEmptyHint;

  /// No description provided for @dateToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get dateYesterday;

  /// No description provided for @dateUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Date inconnue'**
  String get dateUnknown;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez votre coffre-fort à cet ordinateur'**
  String get loginTitle;

  /// No description provided for @loginStep1.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez Alanya sur votre téléphone.'**
  String get loginStep1;

  /// No description provided for @loginStep2.
  ///
  /// In fr, this message translates to:
  /// **'Allez dans Compte et sécurité › Lier un nouvel appareil.'**
  String get loginStep2;

  /// No description provided for @loginStep3.
  ///
  /// In fr, this message translates to:
  /// **'Scannez ce code, puis confirmez sur le téléphone.'**
  String get loginStep3;

  /// No description provided for @loginSharedComputer.
  ///
  /// In fr, this message translates to:
  /// **'Sur un ordinateur partagé, déconnectez-vous en partant (Réglages › Se déconnecter). Vous pouvez aussi retirer cet ordinateur à distance depuis « Appareils connectés » sur votre téléphone.'**
  String get loginSharedComputer;

  /// No description provided for @loginEndedRemotely.
  ///
  /// In fr, this message translates to:
  /// **'Cet ordinateur a été déconnecté. Scannez de nouveau le code pour l\'utiliser.'**
  String get loginEndedRemotely;

  /// No description provided for @loginQrLabel.
  ///
  /// In fr, this message translates to:
  /// **'Code QR de connexion'**
  String get loginQrLabel;

  /// No description provided for @loginQrHint.
  ///
  /// In fr, this message translates to:
  /// **'Le code change toutes les 90 secondes.'**
  String get loginQrHint;

  /// No description provided for @loginScannedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code scanné'**
  String get loginScannedTitle;

  /// No description provided for @loginScannedText.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez la connexion sur votre téléphone.'**
  String get loginScannedText;

  /// No description provided for @loginDeniedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion refusée'**
  String get loginDeniedTitle;

  /// No description provided for @loginDeniedText.
  ///
  /// In fr, this message translates to:
  /// **'La connexion a été refusée sur le téléphone.'**
  String get loginDeniedText;

  /// No description provided for @loginExpiredTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code expiré'**
  String get loginExpiredTitle;

  /// No description provided for @loginExpiredText.
  ///
  /// In fr, this message translates to:
  /// **'Affichez un nouveau code pour vous connecter.'**
  String get loginExpiredText;

  /// No description provided for @loginNewCode.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code'**
  String get loginNewCode;

  /// No description provided for @settingsAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get settingsAccount;

  /// No description provided for @settingsApp.
  ///
  /// In fr, this message translates to:
  /// **'Application'**
  String get settingsApp;

  /// No description provided for @settingsComputerHint.
  ///
  /// In fr, this message translates to:
  /// **'Visible dans « Appareils connectés » sur votre téléphone'**
  String get settingsComputerHint;

  /// No description provided for @settingsConnectedOn.
  ///
  /// In fr, this message translates to:
  /// **'Connecté le {date} · visible dans « Appareils connectés » sur votre téléphone'**
  String settingsConnectedOn(String date);

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Celle du système'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsVersion.
  ///
  /// In fr, this message translates to:
  /// **'Alanya Coffre-fort {version}'**
  String settingsVersion(String version);

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter de cet ordinateur'**
  String get logoutTitle;

  /// No description provided for @logoutText.
  ///
  /// In fr, this message translates to:
  /// **'Efface tout ce que l\'application garde sur cet ordinateur. Vos fichiers restent dans le coffre.'**
  String get logoutText;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter ?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmText.
  ///
  /// In fr, this message translates to:
  /// **'L\'application efface ce qu\'elle garde sur cet ordinateur. Vos fichiers restent dans le coffre ; pour revenir, il faudra scanner de nouveau le code avec votre téléphone.'**
  String get logoutConfirmText;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @open.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir'**
  String get open;

  /// No description provided for @empty.
  ///
  /// In fr, this message translates to:
  /// **'Vider'**
  String get empty;

  /// No description provided for @previous.
  ///
  /// In fr, this message translates to:
  /// **'Précédent'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @download.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get download;

  /// No description provided for @downloadFolder.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger le dossier'**
  String get downloadFolder;

  /// No description provided for @downloadSaved.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré : {path}'**
  String downloadSaved(String path);

  /// No description provided for @downloadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le téléchargement n\'a pas abouti. Réessayez.'**
  String get downloadFailed;

  /// No description provided for @showInFolder.
  ///
  /// In fr, this message translates to:
  /// **'Afficher dans le dossier'**
  String get showInFolder;

  /// No description provided for @openWith.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir avec…'**
  String get openWith;

  /// No description provided for @openFailed.
  ///
  /// In fr, this message translates to:
  /// **'Aucun logiciel de l\'ordinateur ne sait ouvrir ce fichier.'**
  String get openFailed;

  /// No description provided for @viewerPosition.
  ///
  /// In fr, this message translates to:
  /// **'{index} sur {total}'**
  String viewerPosition(int index, int total);

  /// No description provided for @viewerKeys.
  ///
  /// In fr, this message translates to:
  /// **'← → pour passer d\'un fichier à l\'autre · molette pour zoomer · Échap pour fermer'**
  String get viewerKeys;

  /// No description provided for @viewerCannotShow.
  ///
  /// In fr, this message translates to:
  /// **'L\'ordinateur ne sait pas afficher cette photo ici.'**
  String get viewerCannotShow;

  /// No description provided for @viewerVideoHint.
  ///
  /// In fr, this message translates to:
  /// **'La vidéo s\'ouvre dans le lecteur de l\'ordinateur.'**
  String get viewerVideoHint;

  /// No description provided for @viewerAudioHint.
  ///
  /// In fr, this message translates to:
  /// **'L\'audio s\'ouvre dans le lecteur de l\'ordinateur.'**
  String get viewerAudioHint;

  /// No description provided for @viewerDocumentHint.
  ///
  /// In fr, this message translates to:
  /// **'Le document s\'ouvre avec le logiciel de l\'ordinateur.'**
  String get viewerDocumentHint;

  /// No description provided for @viewerPlay.
  ///
  /// In fr, this message translates to:
  /// **'Lire'**
  String get viewerPlay;

  /// No description provided for @fileLost.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier est introuvable chez l\'hébergeur : il ne peut plus être ouvert.'**
  String get fileLost;

  /// No description provided for @noteNone.
  ///
  /// In fr, this message translates to:
  /// **'Pas de commentaire.'**
  String get noteNone;

  /// No description provided for @noteAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un commentaire'**
  String get noteAdd;

  /// No description provided for @noteEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le commentaire'**
  String get noteEdit;

  /// No description provided for @noteEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire'**
  String get noteEditTitle;

  /// No description provided for @noteHint.
  ///
  /// In fr, this message translates to:
  /// **'Quelques mots sur ce fichier (200 caractères au plus)'**
  String get noteHint;

  /// No description provided for @noteAudio.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire audio'**
  String get noteAudio;

  /// No description provided for @noteListen.
  ///
  /// In fr, this message translates to:
  /// **'Écouter le commentaire audio'**
  String get noteListen;

  /// No description provided for @exportRunning.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement de {name}'**
  String exportRunning(String name);

  /// No description provided for @exportRunningMany.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement de {name} : {done} sur {total}'**
  String exportRunningMany(String name, int done, int total);

  /// No description provided for @exportDone.
  ///
  /// In fr, this message translates to:
  /// **'{name} est sur l\'ordinateur'**
  String exportDone(String name);

  /// No description provided for @exportFailed.
  ///
  /// In fr, this message translates to:
  /// **'{name} n\'a pas pu être téléchargé'**
  String exportFailed(String name);

  /// No description provided for @exportCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement de {name} arrêté'**
  String exportCancelled(String name);

  /// No description provided for @settingsFiles.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers sur cet ordinateur'**
  String get settingsFiles;

  /// No description provided for @settingsDownloadFolder.
  ///
  /// In fr, this message translates to:
  /// **'Dossier des téléchargements'**
  String get settingsDownloadFolder;

  /// No description provided for @settingsKeptFiles.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers gardés pour la visionneuse'**
  String get settingsKeptFiles;

  /// No description provided for @settingsKeptFilesSize.
  ///
  /// In fr, this message translates to:
  /// **'{size} · 1 Go au plus, les plus anciens s\'effacent · se retéléchargent au besoin'**
  String settingsKeptFilesSize(String size);

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @addFiles.
  ///
  /// In fr, this message translates to:
  /// **'Des fichiers…'**
  String get addFiles;

  /// No description provided for @addFolder.
  ///
  /// In fr, this message translates to:
  /// **'Un dossier…'**
  String get addFolder;

  /// No description provided for @dropHere.
  ///
  /// In fr, this message translates to:
  /// **'Déposer ici pour ajouter à {folder}'**
  String dropHere(String folder);

  /// No description provided for @importScanning.
  ///
  /// In fr, this message translates to:
  /// **'Analyse des fichiers… {n}'**
  String importScanning(int n);

  /// No description provided for @importChecking.
  ///
  /// In fr, this message translates to:
  /// **'Comparaison avec le coffre… {done} / {total}'**
  String importChecking(int done, int total);

  /// No description provided for @importPreparing.
  ///
  /// In fr, this message translates to:
  /// **'Préparation des envois… {done} / {total}'**
  String importPreparing(int done, int total);

  /// No description provided for @importTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à {folder}'**
  String importTitle(String folder);

  /// No description provided for @importSend.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier à envoyer} other{{n} fichiers à envoyer}} · {size}'**
  String importSend(int n, String size);

  /// No description provided for @importLink.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier déjà dans le coffre, ajouté à l\'album sans nouvel envoi} other{{n} fichiers déjà dans le coffre, ajoutés à l\'album sans nouvel envoi}}'**
  String importLink(int n);

  /// No description provided for @importAlready.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier déjà dans le coffre, pas renvoyé} other{{n} fichiers déjà dans le coffre, pas renvoyés}}'**
  String importAlready(int n);

  /// No description provided for @importDiverted.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier ira dans {root}, le dossier de son type} other{{n} fichiers iront dans {root}, le dossier de leur type}}'**
  String importDiverted(int n, String root);

  /// No description provided for @importTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier dépasse {max} et ne partira pas} other{{n} fichiers dépassent {max} et ne partiront pas}}'**
  String importTooLarge(int n, String max);

  /// No description provided for @importIgnored.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier caché, vide ou raccourci laissé de côté} other{{n} fichiers cachés, vides ou raccourcis laissés de côté}}'**
  String importIgnored(int n);

  /// No description provided for @importFree.
  ///
  /// In fr, this message translates to:
  /// **'Place libre dans le coffre : {size}'**
  String importFree(String size);

  /// No description provided for @importNoRoom.
  ///
  /// In fr, this message translates to:
  /// **'Pas assez de place : il manque {size}. Videz la corbeille ou ajoutez moins de fichiers.'**
  String importNoRoom(String size);

  /// No description provided for @importOriginal.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers partent en Original, tels qu\'ils sont sur l\'ordinateur. Ils restent sur l\'ordinateur.'**
  String get importOriginal;

  /// No description provided for @importNothing.
  ///
  /// In fr, this message translates to:
  /// **'Rien à envoyer : tout est déjà dans le coffre.'**
  String get importNothing;

  /// No description provided for @importStart.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get importStart;

  /// No description provided for @importFailed.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers n\'ont pas pu être lus.'**
  String get importFailed;

  /// No description provided for @importBusy.
  ///
  /// In fr, this message translates to:
  /// **'Un ajout est déjà en préparation.'**
  String get importBusy;

  /// No description provided for @uploadsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envois vers le coffre'**
  String get uploadsTitle;

  /// No description provided for @uploadsRunning.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{Envoi d\'1 fichier} other{Envoi de {n} fichiers}}'**
  String uploadsRunning(int n);

  /// No description provided for @uploadsDone.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier ajouté au coffre} other{{n} fichiers ajoutés au coffre}}'**
  String uploadsDone(int n);

  /// No description provided for @uploadsFailed.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 envoi n\'a pas abouti} other{{n} envois n\'ont pas abouti}}'**
  String uploadsFailed(int n);

  /// No description provided for @uploadsPaused.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 envoi en pause} other{{n} envois en pause}}'**
  String uploadsPaused(int n);

  /// No description provided for @uploadsWaitingNetwork.
  ///
  /// In fr, this message translates to:
  /// **'En attente du réseau'**
  String get uploadsWaitingNetwork;

  /// No description provided for @pauseAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout mettre en pause'**
  String get pauseAll;

  /// No description provided for @resumeAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout reprendre'**
  String get resumeAll;

  /// No description provided for @details.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get details;

  /// No description provided for @pause.
  ///
  /// In fr, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In fr, this message translates to:
  /// **'Reprendre'**
  String get resume;

  /// No description provided for @clearFinished.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les terminés'**
  String get clearFinished;

  /// No description provided for @speed.
  ///
  /// In fr, this message translates to:
  /// **'{size}/s'**
  String speed(String size);

  /// No description provided for @uploadQueued.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get uploadQueued;

  /// No description provided for @uploadPaused.
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get uploadPaused;

  /// No description provided for @uploadDone.
  ///
  /// In fr, this message translates to:
  /// **'Dans le coffre'**
  String get uploadDone;

  /// No description provided for @uploadErrorQuota.
  ///
  /// In fr, this message translates to:
  /// **'Plus assez de place dans le coffre'**
  String get uploadErrorQuota;

  /// No description provided for @uploadErrorChanged.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier a changé sur l\'ordinateur pendant l\'envoi'**
  String get uploadErrorChanged;

  /// No description provided for @uploadErrorMissing.
  ///
  /// In fr, this message translates to:
  /// **'Le fichier n\'est plus sur l\'ordinateur'**
  String get uploadErrorMissing;

  /// No description provided for @uploadErrorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'L\'envoi n\'a pas abouti'**
  String get uploadErrorGeneric;

  /// No description provided for @change.
  ///
  /// In fr, this message translates to:
  /// **'Changer'**
  String get change;

  /// No description provided for @newFolder.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau dossier'**
  String get newFolder;

  /// No description provided for @newAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel album'**
  String get newAlbum;

  /// No description provided for @folderNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du dossier'**
  String get folderNameLabel;

  /// No description provided for @albumNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom de l\'album'**
  String get albumNameLabel;

  /// No description provided for @fileNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom du fichier'**
  String get fileNameLabel;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get create;

  /// No description provided for @rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get rename;

  /// No description provided for @move.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer…'**
  String get move;

  /// No description provided for @moveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer vers'**
  String get moveTitle;

  /// No description provided for @moveHere.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer ici'**
  String get moveHere;

  /// No description provided for @addToAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à un album…'**
  String get addToAlbum;

  /// No description provided for @addToAlbumTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à un album'**
  String get addToAlbumTitle;

  /// No description provided for @addHere.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter ici'**
  String get addHere;

  /// No description provided for @addedToAlbum.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier ajouté à l\'album, sans copie} other{{n} fichiers ajoutés à l\'album, sans copie}}'**
  String addedToAlbum(int n);

  /// No description provided for @moved.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 élément déplacé} other{{n} éléments déplacés}}'**
  String moved(int n);

  /// No description provided for @toTrash.
  ///
  /// In fr, this message translates to:
  /// **'Mettre à la corbeille'**
  String get toTrash;

  /// No description provided for @movedToTrash.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 élément mis à la corbeille} other{{n} éléments mis à la corbeille}}'**
  String movedToTrash(int n);

  /// No description provided for @deleteWhich.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{Ce fichier est aussi ailleurs dans le coffre} other{Certains de ces fichiers sont aussi ailleurs dans le coffre}}'**
  String deleteWhich(int n);

  /// No description provided for @deleteHereOnly.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de « {place} » seulement'**
  String deleteHereOnly(String place);

  /// No description provided for @deleteHereOnlyHint.
  ///
  /// In fr, this message translates to:
  /// **'Il reste dans « {other} ». Aucun espace libéré.'**
  String deleteHereOnlyHint(String other);

  /// No description provided for @deleteEverywhere.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer partout'**
  String get deleteEverywhere;

  /// No description provided for @deleteEverywhereHint.
  ///
  /// In fr, this message translates to:
  /// **'Il va à la corbeille ; l\'espace est libéré quand elle est vidée.'**
  String get deleteEverywhereHint;

  /// No description provided for @selectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 élément sélectionné} other{{n} éléments sélectionnés}}'**
  String selectedCount(int n);

  /// No description provided for @selectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout sélectionner'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In fr, this message translates to:
  /// **'Désélectionner'**
  String get clearSelection;

  /// No description provided for @folderKeysHint.
  ///
  /// In fr, this message translates to:
  /// **'Double-clic pour ouvrir · Ctrl ou Maj + clic pour sélectionner · Suppr : corbeille · F2 : renommer · clic droit : menu'**
  String get folderKeysHint;

  /// No description provided for @errorNameTaken.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom est déjà pris dans ce dossier.'**
  String get errorNameTaken;

  /// No description provided for @errorWrongFamily.
  ///
  /// In fr, this message translates to:
  /// **'Ce dossier n\'accepte pas ce type de fichier.'**
  String get errorWrongFamily;

  /// No description provided for @errorInvalidMove.
  ///
  /// In fr, this message translates to:
  /// **'Un dossier ne se range pas dans lui-même.'**
  String get errorInvalidMove;

  /// No description provided for @errorTooDeep.
  ///
  /// In fr, this message translates to:
  /// **'Trop de niveaux de dossiers.'**
  String get errorTooDeep;

  /// No description provided for @errorFolderLimit.
  ///
  /// In fr, this message translates to:
  /// **'Trop de dossiers dans le coffre.'**
  String get errorFolderLimit;

  /// No description provided for @errorInvalidName.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom n\'est pas valide.'**
  String get errorInvalidName;

  /// No description provided for @errorRootLocked.
  ///
  /// In fr, this message translates to:
  /// **'Les dossiers principaux ne se renomment, ne se déplacent ni ne se suppriment.'**
  String get errorRootLocked;

  /// No description provided for @errorNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Cet élément n\'existe plus.'**
  String get errorNotFound;

  /// No description provided for @navTrash.
  ///
  /// In fr, this message translates to:
  /// **'Corbeille'**
  String get navTrash;

  /// No description provided for @trashEmptyState.
  ///
  /// In fr, this message translates to:
  /// **'La corbeille est vide'**
  String get trashEmptyState;

  /// No description provided for @trashHint.
  ///
  /// In fr, this message translates to:
  /// **'Les éléments restent {days} jours dans la corbeille, puis sont supprimés définitivement. Ils comptent dans votre espace jusque-là.'**
  String trashHint(int days);

  /// No description provided for @emptyTrash.
  ///
  /// In fr, this message translates to:
  /// **'Vider la corbeille'**
  String get emptyTrash;

  /// No description provided for @emptyTrashConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Tout le contenu de la corbeille sera supprimé définitivement. Impossible de revenir en arrière.'**
  String get emptyTrashConfirm;

  /// No description provided for @restore.
  ///
  /// In fr, this message translates to:
  /// **'Restaurer'**
  String get restore;

  /// No description provided for @restored.
  ///
  /// In fr, this message translates to:
  /// **'Restauré'**
  String get restored;

  /// No description provided for @deleteForever.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get deleteForever;

  /// No description provided for @deleteForeverConfirm.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » sera supprimé définitivement.'**
  String deleteForeverConfirm(String name);

  /// No description provided for @trashPurgeIn.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Supprimé définitivement aujourd\'hui} =1{Supprimé définitivement demain} other{Supprimé définitivement dans {n} jours}}'**
  String trashPurgeIn(int n);

  /// No description provided for @trashFrom.
  ///
  /// In fr, this message translates to:
  /// **'Depuis {place}'**
  String trashFrom(String place);

  /// No description provided for @freeUp.
  ///
  /// In fr, this message translates to:
  /// **'Libérer de l\'espace'**
  String get freeUp;

  /// No description provided for @freeUpIntro.
  ///
  /// In fr, this message translates to:
  /// **'Les plus gros fichiers du coffre. Ceux que vous choisissez partent de partout, albums compris, pour que leur place soit vraiment libérée.'**
  String get freeUpIntro;

  /// No description provided for @freeUpHint.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers mis à la corbeille comptent encore dans votre espace jusqu\'à ce que la corbeille soit vidée.'**
  String get freeUpHint;

  /// No description provided for @freeUpSelected.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier} other{{n} fichiers}} · {size}'**
  String freeUpSelected(int n, String size);

  /// No description provided for @freeUpTrash.
  ///
  /// In fr, this message translates to:
  /// **'La corbeille occupe {size}'**
  String freeUpTrash(String size);

  /// No description provided for @freeUpNothing.
  ///
  /// In fr, this message translates to:
  /// **'Aucun fichier dans le coffre'**
  String get freeUpNothing;

  /// No description provided for @navPcBackup.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde du PC'**
  String get navPcBackup;

  /// No description provided for @pcBackupIntro.
  ///
  /// In fr, this message translates to:
  /// **'Chaque dossier choisi est recréé dans Albums avec ses sous-dossiers, et ses fichiers apparaissent aussi dans Photos, Vidéos, Audios ou Documents, sans place en plus. Un fichier supprimé du PC reste dans le coffre ; un fichier supprimé du coffre ne revient pas.'**
  String get pcBackupIntro;

  /// No description provided for @pcBackupSwitch.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder ces dossiers automatiquement'**
  String get pcBackupSwitch;

  /// No description provided for @pcBackupOpenOnly.
  ///
  /// In fr, this message translates to:
  /// **'Tant que l\'application tourne, fenêtre ouverte ou icône près de l\'horloge : un passage au démarrage, après chaque changement dans les dossiers, et toutes les 15 minutes. En Original.'**
  String get pcBackupOpenOnly;

  /// No description provided for @pcBackupFolders.
  ///
  /// In fr, this message translates to:
  /// **'Dossiers sauvegardés'**
  String get pcBackupFolders;

  /// No description provided for @pcBackupAddFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un dossier…'**
  String get pcBackupAddFolder;

  /// No description provided for @pcBackupNoFolder.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dossier choisi. Ajoutez par exemple Images ou Documents.'**
  String get pcBackupNoFolder;

  /// No description provided for @pcBackupRemoveFolder.
  ///
  /// In fr, this message translates to:
  /// **'Ne plus sauvegarder ce dossier'**
  String get pcBackupRemoveFolder;

  /// No description provided for @pcBackupRemoveConfirm.
  ///
  /// In fr, this message translates to:
  /// **'« {name} » ne sera plus sauvegardé. Ce qui est déjà dans le coffre y reste.'**
  String pcBackupRemoveConfirm(String name);

  /// No description provided for @pcBackupFolderMissing.
  ///
  /// In fr, this message translates to:
  /// **'Dossier introuvable sur ce PC'**
  String get pcBackupFolderMissing;

  /// No description provided for @pcBackupAlreadyAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ce dossier est déjà sauvegardé.'**
  String get pcBackupAlreadyAdded;

  /// No description provided for @pcBackupNoType.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez au moins un type de fichier.'**
  String get pcBackupNoType;

  /// No description provided for @pcBackupRunNow.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder maintenant'**
  String get pcBackupRunNow;

  /// No description provided for @pcBackupListing.
  ///
  /// In fr, this message translates to:
  /// **'Lecture des dossiers…'**
  String get pcBackupListing;

  /// No description provided for @pcBackupChecking.
  ///
  /// In fr, this message translates to:
  /// **'Comparaison avec le coffre… {done} / {total}'**
  String pcBackupChecking(int done, int total);

  /// No description provided for @pcBackupRemaining.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{À jour} =1{1 fichier à envoyer} other{{n} fichiers à envoyer}}'**
  String pcBackupRemaining(int n);

  /// No description provided for @pcBackupLast.
  ///
  /// In fr, this message translates to:
  /// **'Dernier passage : {time}'**
  String pcBackupLast(String time);

  /// No description provided for @pcBackupNever.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de passage'**
  String get pcBackupNever;

  /// No description provided for @pcBackupOff.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde arrêtée'**
  String get pcBackupOff;

  /// No description provided for @pcBackupQueued.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{rien de nouveau} =1{1 fichier envoyé} other{{n} fichiers envoyés}}'**
  String pcBackupQueued(int n);

  /// No description provided for @pcBackupAlready.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 déjà dans le coffre} other{{n} déjà dans le coffre}}'**
  String pcBackupAlready(int n);

  /// No description provided for @pcBackupSkipped.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 supprimé du coffre, pas renvoyé} other{{n} supprimés du coffre, pas renvoyés}}'**
  String pcBackupSkipped(int n);

  /// No description provided for @pcBackupNoRoom.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier attend de la place dans le coffre} other{{n} fichiers attendent de la place dans le coffre}}'**
  String pcBackupNoRoom(int n);

  /// No description provided for @pcBackupUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier illisible} other{{n} fichiers illisibles}}'**
  String pcBackupUnreadable(int n);

  /// No description provided for @pcBackupFailed.
  ///
  /// In fr, this message translates to:
  /// **'Le dernier passage n\'a pas abouti. {reason}'**
  String pcBackupFailed(String reason);

  /// No description provided for @pcBackupEstimateTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder « {name} »'**
  String pcBackupEstimateTitle(String name);

  /// No description provided for @pcBackupTypes.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui part :'**
  String get pcBackupTypes;

  /// No description provided for @pcBackupEstimate.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Aucun fichier de ces types pour l\'instant.} =1{1 fichier · {size}} other{{n} fichiers · {size}}}'**
  String pcBackupEstimate(int n, String size);

  /// No description provided for @pcBackupEstimateHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce qui est déjà dans le coffre (sauvegardé depuis le téléphone, par exemple) ne repartira pas : l\'envoi réel peut être plus léger. Les plus récents partent d\'abord ; si la place manque, les plus anciens attendent.'**
  String get pcBackupEstimateHint;

  /// No description provided for @pcBackupStart.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder'**
  String get pcBackupStart;

  /// No description provided for @pcBackupHome.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarde du PC'**
  String get pcBackupHome;

  /// No description provided for @updateAvailable.
  ///
  /// In fr, this message translates to:
  /// **'La version {version} d\'Alanya Coffre-fort est disponible.'**
  String updateAvailable(String version);

  /// No description provided for @updateDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get updateDownload;

  /// No description provided for @updateLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get updateLater;

  /// No description provided for @filterWithNote.
  ///
  /// In fr, this message translates to:
  /// **'Avec commentaire'**
  String get filterWithNote;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get filterAll;

  /// No description provided for @folderCamera.
  ///
  /// In fr, this message translates to:
  /// **'Appareil photo'**
  String get folderCamera;

  /// No description provided for @folderScreenshots.
  ///
  /// In fr, this message translates to:
  /// **'Captures d\'écran'**
  String get folderScreenshots;

  /// No description provided for @folderDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Images téléchargées'**
  String get folderDownloads;

  /// No description provided for @pcRemoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de l\'ordinateur après la sauvegarde'**
  String get pcRemoveTitle;

  /// No description provided for @pcRemoveHint.
  ///
  /// In fr, this message translates to:
  /// **'Les photos et vidéos gardées en Original dans le coffre vont dans la corbeille de l\'ordinateur, d\'où vous pouvez les récupérer tant qu\'elle n\'est pas vidée. Les documents et les audios restent sur l\'ordinateur.'**
  String get pcRemoveHint;

  /// No description provided for @pcRemoveWhen.
  ///
  /// In fr, this message translates to:
  /// **'Quand les retirer'**
  String get pcRemoveWhen;

  /// No description provided for @pcRemoveAfter.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{Après 1 jour} other{Après {n} jours}}'**
  String pcRemoveAfter(int n);

  /// No description provided for @pcRemoveNow.
  ///
  /// In fr, this message translates to:
  /// **'Tout de suite'**
  String get pcRemoveNow;

  /// No description provided for @pcRemoveConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de l\'ordinateur ?'**
  String get pcRemoveConfirmTitle;

  /// No description provided for @pcRemoveConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Une fois arrivées dans le coffre en Original, et vérifiées auprès du serveur juste avant, les photos et vidéos des dossiers sauvegardés iront dans la corbeille de l\'ordinateur. Vous pourrez les récupérer depuis la corbeille tant que vous ne la videz pas, et toujours depuis le coffre.'**
  String get pcRemoveConfirm;

  /// No description provided for @pcRemoveConfirmAction.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get pcRemoveConfirmAction;

  /// No description provided for @pcRemoved.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 photo ou vidéo mise à la corbeille de l\'ordinateur} other{{n} photos et vidéos mises à la corbeille de l\'ordinateur}} · {size} libérés'**
  String pcRemoved(int n, String size);

  /// No description provided for @pcBackupRename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get pcBackupRename;

  /// No description provided for @pcBackupNameLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nom dans le coffre'**
  String get pcBackupNameLabel;

  /// No description provided for @pcBackupRenameHint.
  ///
  /// In fr, this message translates to:
  /// **'Le dossier garde ce nom dans le coffre (son album dans Albums, et le dossier d\'origine dans Photos et Vidéos). Le dossier de l\'ordinateur ne change pas, et la sauvegarde continue.'**
  String get pcBackupRenameHint;

  /// No description provided for @pcBackupTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =1{1 fichier dépasse {max}, la limite d\'un fichier du coffre : il reste sur l\'ordinateur} other{{n} fichiers dépassent {max}, la limite d\'un fichier du coffre : ils restent sur l\'ordinateur}}'**
  String pcBackupTooLarge(int n, String max);

  /// No description provided for @trayOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir Alanya Coffre-fort'**
  String get trayOpen;

  /// No description provided for @trayBackupNow.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder maintenant'**
  String get trayBackupNow;

  /// No description provided for @trayQuit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get trayQuit;

  /// No description provided for @settingsKeepRunning.
  ///
  /// In fr, this message translates to:
  /// **'Continuer près de l\'horloge quand la fenêtre est fermée'**
  String get settingsKeepRunning;

  /// No description provided for @settingsKeepRunningHint.
  ///
  /// In fr, this message translates to:
  /// **'La sauvegarde du PC et les envois continuent. Pour quitter vraiment : icône Alanya près de l\'horloge › Quitter.'**
  String get settingsKeepRunningHint;

  /// No description provided for @settingsAutostart.
  ///
  /// In fr, this message translates to:
  /// **'Lancer au démarrage de l\'ordinateur'**
  String get settingsAutostart;

  /// No description provided for @settingsAutostartHint.
  ///
  /// In fr, this message translates to:
  /// **'Alanya Coffre-fort s\'ouvre caché près de l\'horloge à l\'ouverture de votre session : la sauvegarde du PC tourne sans y penser.'**
  String get settingsAutostartHint;

  /// No description provided for @settingsTrayUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'L\'icône près de l\'horloge n\'est pas disponible sur ce système : fermer la fenêtre quitte l\'application.'**
  String get settingsTrayUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
