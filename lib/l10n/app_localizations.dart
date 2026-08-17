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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  /// **'Alanya'**
  String get appTitle;

  /// No description provided for @navChats.
  ///
  /// In fr, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get navCalls;

  /// No description provided for @navStatuses.
  ///
  /// In fr, this message translates to:
  /// **'Statuts'**
  String get navStatuses;

  /// No description provided for @navMeetings.
  ///
  /// In fr, this message translates to:
  /// **'Réunions'**
  String get navMeetings;

  /// No description provided for @navProfile.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// No description provided for @offlineBanner.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion — les messages seront envoyés à la reconnexion'**
  String get offlineBanner;

  /// No description provided for @loginWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous pour continuer vers Alanya'**
  String get loginSubtitle;

  /// No description provided for @loginPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get loginPasswordHint;

  /// No description provided for @loginForgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get loginForgotPassword;

  /// No description provided for @loginSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get loginSubmit;

  /// No description provided for @loginNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get loginNoAccount;

  /// No description provided for @loginSignUp.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get loginSignUp;

  /// No description provided for @signupTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Rejoignez la communauté Alanya'**
  String get signupSubtitle;

  /// No description provided for @signupNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Nom complet'**
  String get signupNameHint;

  /// No description provided for @signupPseudoHint.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo'**
  String get signupPseudoHint;

  /// No description provided for @signupEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get signupEmailHint;

  /// No description provided for @signupPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get signupPasswordHint;

  /// No description provided for @signupSubmit.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get signupSubmit;

  /// No description provided for @signupHasAccount.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ?'**
  String get signupHasAccount;

  /// No description provided for @signupLogin.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signupLogin;

  /// No description provided for @validatorRequired.
  ///
  /// In fr, this message translates to:
  /// **'Champ requis'**
  String get validatorRequired;

  /// No description provided for @validatorEmail.
  ///
  /// In fr, this message translates to:
  /// **'Email invalide'**
  String get validatorEmail;

  /// No description provided for @validatorMinLength.
  ///
  /// In fr, this message translates to:
  /// **'Au moins {n} caractères'**
  String validatorMinLength(int n);

  /// No description provided for @validatorOtp6.
  ///
  /// In fr, this message translates to:
  /// **'Code OTP à 6 chiffres'**
  String get validatorOtp6;

  /// No description provided for @validatorPasswordMatch.
  ///
  /// In fr, this message translates to:
  /// **'Les mots de passe ne correspondent pas'**
  String get validatorPasswordMatch;

  /// No description provided for @unknownSender.
  ///
  /// In fr, this message translates to:
  /// **'Inconnu'**
  String get unknownSender;

  /// No description provided for @statusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get statusPending;

  /// No description provided for @statusSent.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé'**
  String get statusSent;

  /// No description provided for @statusDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Livré'**
  String get statusDelivered;

  /// No description provided for @statusRead.
  ///
  /// In fr, this message translates to:
  /// **'Lu'**
  String get statusRead;

  /// No description provided for @statusFailedRetry.
  ///
  /// In fr, this message translates to:
  /// **'Échec — touchez pour réessayer'**
  String get statusFailedRetry;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Récupération du mot de passe'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre email'**
  String get forgotEmailTitle;

  /// No description provided for @forgotEmailSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un code OTP sera envoyé à votre email'**
  String get forgotEmailSubtitle;

  /// No description provided for @forgotEmailHint.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get forgotEmailHint;

  /// No description provided for @forgotOtpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vérification du code'**
  String get forgotOtpTitle;

  /// No description provided for @forgotOtpSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code 6 chiffres envoyé à {email}'**
  String forgotOtpSubtitle(String email);

  /// No description provided for @forgotResendCode.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get forgotResendCode;

  /// No description provided for @forgotNewPasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get forgotNewPasswordTitle;

  /// No description provided for @forgotNewPasswordSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Entrez votre nouveau mot de passe'**
  String get forgotNewPasswordSubtitle;

  /// No description provided for @forgotNewPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get forgotNewPasswordHint;

  /// No description provided for @forgotConfirmPasswordHint.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le mot de passe'**
  String get forgotConfirmPasswordHint;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get settingsThemeSystem;

  /// No description provided for @settingsLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get settingsLanguage;

  /// No description provided for @settingsLangFr.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get settingsLangFr;

  /// No description provided for @settingsLangEn.
  ///
  /// In fr, this message translates to:
  /// **'Anglais'**
  String get settingsLangEn;

  /// No description provided for @settingsLangSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get settingsLangSystem;

  /// No description provided for @settingsMedia.
  ///
  /// In fr, this message translates to:
  /// **'Médias'**
  String get settingsMedia;

  /// No description provided for @settingsAutoDownload.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement automatique'**
  String get settingsAutoDownload;

  /// No description provided for @settingsAutoDownloadSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Télécharge les médias reçus dans l’app'**
  String get settingsAutoDownloadSubtitle;

  /// No description provided for @settingsMediaVisibility.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans la galerie'**
  String get settingsMediaVisibility;

  /// No description provided for @settingsMediaVisibilitySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les photos et vidéos reçues apparaissent dans la galerie de l’appareil'**
  String get settingsMediaVisibilitySubtitle;

  /// No description provided for @mediaSaveToGallery.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans la galerie'**
  String get mediaSaveToGallery;

  /// No description provided for @mediaSaveToDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer dans Téléchargements'**
  String get mediaSaveToDownloads;

  /// No description provided for @mediaSavedToGallery.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré dans la galerie'**
  String get mediaSavedToGallery;

  /// No description provided for @mediaSavedToDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Enregistré dans Téléchargements'**
  String get mediaSavedToDownloads;

  /// No description provided for @mediaAlreadyInGallery.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans la galerie'**
  String get mediaAlreadyInGallery;

  /// No description provided for @mediaAlreadyInDownloads.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans Téléchargements'**
  String get mediaAlreadyInDownloads;

  /// No description provided for @mediaSaveAgain.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer à nouveau'**
  String get mediaSaveAgain;

  /// No description provided for @mediaSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d’enregistrer ce média'**
  String get mediaSaveFailed;

  /// No description provided for @settingsCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get settingsCalls;

  /// No description provided for @settingsRingtone.
  ///
  /// In fr, this message translates to:
  /// **'Sonnerie d\'appel'**
  String get settingsRingtone;

  /// No description provided for @ringtoneScreenTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sonnerie d\'appel'**
  String get ringtoneScreenTitle;

  /// No description provided for @ringtoneSectionSystem.
  ///
  /// In fr, this message translates to:
  /// **'Sonnerie par défaut'**
  String get ringtoneSectionSystem;

  /// No description provided for @ringtoneSectionApp.
  ///
  /// In fr, this message translates to:
  /// **'Sonneries préinstallées'**
  String get ringtoneSectionApp;

  /// No description provided for @ringtoneSectionCustom.
  ///
  /// In fr, this message translates to:
  /// **'Sonneries importées'**
  String get ringtoneSectionCustom;

  /// No description provided for @ringtoneSystemDefaultLabel.
  ///
  /// In fr, this message translates to:
  /// **'Sonnerie par défaut de l\'appareil'**
  String get ringtoneSystemDefaultLabel;

  /// No description provided for @ringtoneAddCustomAction.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une sonnerie'**
  String get ringtoneAddCustomAction;

  /// No description provided for @ringtoneAddCustomHint.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers audio (MP3, WAV, M4A…), 5 Mo max'**
  String get ringtoneAddCustomHint;

  /// No description provided for @ringtoneLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Nombre maximal de sonneries atteint (10)'**
  String get ringtoneLimitReached;

  /// No description provided for @ringtoneCustomEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune sonnerie importée pour l\'instant'**
  String get ringtoneCustomEmpty;

  /// No description provided for @ringtoneDeleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette sonnerie ?'**
  String get ringtoneDeleteConfirmTitle;

  /// No description provided for @ringtoneDeleteConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get ringtoneDeleteConfirmMessage;

  /// No description provided for @ringtoneImportSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Sonnerie ajoutée et sélectionnée'**
  String get ringtoneImportSuccess;

  /// No description provided for @ringtoneImportError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'importer ce fichier'**
  String get ringtoneImportError;

  /// No description provided for @ringtonePreviewError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire cette sonnerie'**
  String get ringtonePreviewError;

  /// No description provided for @settingsPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Contacts bloqués'**
  String get settingsPrivacySubtitle;

  /// No description provided for @commonCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get commonSave;

  /// No description provided for @commonSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get commonSend;

  /// No description provided for @commonClose.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement…'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur'**
  String get commonError;

  /// No description provided for @commonYes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get commonNo;

  /// No description provided for @commonOk.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonAccept.
  ///
  /// In fr, this message translates to:
  /// **'Accepter'**
  String get commonAccept;

  /// No description provided for @commonDecline.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get commonDecline;

  /// No description provided for @commonCallBack.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler'**
  String get commonCallBack;

  /// No description provided for @callMissed.
  ///
  /// In fr, this message translates to:
  /// **'Appel manqué'**
  String get callMissed;

  /// No description provided for @callIncoming.
  ///
  /// In fr, this message translates to:
  /// **'APPEL ENTRANT'**
  String get callIncoming;

  /// No description provided for @errorWithDetails.
  ///
  /// In fr, this message translates to:
  /// **'Échec : {error}'**
  String errorWithDetails(String error);

  /// No description provided for @actionFailedWithError.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible : {error}'**
  String actionFailedWithError(String error);

  /// No description provided for @cannotUnblockWithError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de débloquer : {error}'**
  String cannotUnblockWithError(String error);

  /// No description provided for @loadErrorWithDetails.
  ///
  /// In fr, this message translates to:
  /// **'Erreur chargement : {error}'**
  String loadErrorWithDetails(String error);

  /// No description provided for @cannotOpenFileApp.
  ///
  /// In fr, this message translates to:
  /// **'Aucune app pour ouvrir ce fichier ({message})'**
  String cannotOpenFileApp(String message);

  /// No description provided for @cannotOpenFileAppAlt.
  ///
  /// In fr, this message translates to:
  /// **'Aucune application pour ouvrir ce fichier ({message})'**
  String cannotOpenFileAppAlt(String message);

  /// No description provided for @membersCount.
  ///
  /// In fr, this message translates to:
  /// **'Membres ({count})'**
  String membersCount(int count);

  /// No description provided for @groupMembersCount.
  ///
  /// In fr, this message translates to:
  /// **'Groupe • {count} membres'**
  String groupMembersCount(int count);

  /// No description provided for @pinnedMessagesCount.
  ///
  /// In fr, this message translates to:
  /// **'Messages épinglés ({count})'**
  String pinnedMessagesCount(int count);

  /// No description provided for @selectCount.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner ({count})'**
  String selectCount(int count);

  /// No description provided for @forwardAlbumCount.
  ///
  /// In fr, this message translates to:
  /// **'Transférer l\'album ({count})'**
  String forwardAlbumCount(int count);

  /// No description provided for @downloadAlbumCount.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger l\'album ({count})'**
  String downloadAlbumCount(int count);

  /// No description provided for @downloadAlbumHint.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer tous les médias sur l\'appareil'**
  String get downloadAlbumHint;

  /// No description provided for @downloadAlbumProgress.
  ///
  /// In fr, this message translates to:
  /// **'{current} sur {total}'**
  String downloadAlbumProgress(int current, int total);

  /// No description provided for @albumMediaAlreadyDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'Tous les médias de l\'album sont déjà téléchargés'**
  String get albumMediaAlreadyDownloaded;

  /// No description provided for @maxMessages.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} messages'**
  String maxMessages(int count);

  /// No description provided for @maxVideos.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} vidéos.'**
  String maxVideos(int count);

  /// No description provided for @albumFirstOnly.
  ///
  /// In fr, this message translates to:
  /// **'Seules les {count} premières seront envoyées.'**
  String albumFirstOnly(int count);

  /// No description provided for @videoTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo ignorée ({mb} Mo). Limite : 50 Mo.'**
  String videoTooLarge(String mb);

  /// No description provided for @fileTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Fichier trop volumineux ({mb} Mo). Limite : 50 Mo.'**
  String fileTooLarge(String mb);

  /// No description provided for @minutesShort.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @durationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Durée : {duration}'**
  String durationLabel(String duration);

  /// No description provided for @todayAt.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui · {time}'**
  String todayAt(String time);

  /// No description provided for @tomorrowAt.
  ///
  /// In fr, this message translates to:
  /// **'Demain · {time}'**
  String tomorrowAt(String time);

  /// No description provided for @todayAtTime.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui à {time}'**
  String todayAtTime(String time);

  /// No description provided for @seenAt.
  ///
  /// In fr, this message translates to:
  /// **'Vu à {time}'**
  String seenAt(String time);

  /// No description provided for @seenYesterdayAt.
  ///
  /// In fr, this message translates to:
  /// **'Vu hier à {time}'**
  String seenYesterdayAt(String time);

  /// No description provided for @seenOnDate.
  ///
  /// In fr, this message translates to:
  /// **'Vu le {day}/{month}'**
  String seenOnDate(int day, int month);

  /// No description provided for @seenAtLower.
  ///
  /// In fr, this message translates to:
  /// **'vu à {time}'**
  String seenAtLower(String time);

  /// No description provided for @seenYesterdayAtLower.
  ///
  /// In fr, this message translates to:
  /// **'vu hier à {time}'**
  String seenYesterdayAtLower(String time);

  /// No description provided for @timeAgoDays.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} j'**
  String timeAgoDays(int count);

  /// No description provided for @timeAgoHours.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} h'**
  String timeAgoHours(int count);

  /// No description provided for @timeAgoMinutes.
  ///
  /// In fr, this message translates to:
  /// **'il y a {count} min'**
  String timeAgoMinutes(int count);

  /// No description provided for @pageOf.
  ///
  /// In fr, this message translates to:
  /// **'Page {page} / {total}'**
  String pageOf(int page, int total);

  /// No description provided for @usedByOwner.
  ///
  /// In fr, this message translates to:
  /// **'Utilisé · {owner}'**
  String usedByOwner(String owner);

  /// No description provided for @maxParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} participants'**
  String maxParticipants(int count);

  /// No description provided for @selectUpToVideo.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez jusqu\'à {count} membres pour l\'appel vidéo'**
  String selectUpToVideo(int count);

  /// No description provided for @selectUpToVoice.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez jusqu\'à {count} membres pour l\'appel vocal'**
  String selectUpToVoice(int count);

  /// No description provided for @cannotLoadMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la réunion : {error}'**
  String cannotLoadMeeting(String error);

  /// No description provided for @cannotJoinMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de rejoindre : {error}'**
  String cannotJoinMeeting(String error);

  /// No description provided for @cannotCreateMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer la réunion : {error}'**
  String cannotCreateMeeting(String error);

  /// No description provided for @meetingConnectFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de la connexion à la réunion : {error}'**
  String meetingConnectFailed(String error);

  /// No description provided for @uploadFailedWithError.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'upload : {error}'**
  String uploadFailedWithError(String error);

  /// No description provided for @sendFailedWithError.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'envoi : {error}'**
  String sendFailedWithError(String error);

  /// No description provided for @recordFailedWithError.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'enregistrement : {error}'**
  String recordFailedWithError(String error);

  /// No description provided for @roleChangeError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur changement de rôle: {error}'**
  String roleChangeError(String error);

  /// No description provided for @noResultsFor.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @editedAt.
  ///
  /// In fr, this message translates to:
  /// **'Modifié à {time}'**
  String editedAt(String time);

  /// No description provided for @labelForwarded.
  ///
  /// In fr, this message translates to:
  /// **'{label} transféré'**
  String labelForwarded(String label);

  /// No description provided for @labelForwardedTo.
  ///
  /// In fr, this message translates to:
  /// **'{label} transféré vers {count} discussions'**
  String labelForwardedTo(String label, int count);

  /// No description provided for @forwardedToRatio.
  ///
  /// In fr, this message translates to:
  /// **'Transféré vers {ok}/{total} discussions'**
  String forwardedToRatio(int ok, int total);

  /// No description provided for @callFrom.
  ///
  /// In fr, this message translates to:
  /// **'Appel de {name}'**
  String callFrom(String name);

  /// No description provided for @organizedBy.
  ///
  /// In fr, this message translates to:
  /// **'Organisé par {name}'**
  String organizedBy(String name);

  /// No description provided for @numberAssigned.
  ///
  /// In fr, this message translates to:
  /// **'Numéro attribué : {number}'**
  String numberAssigned(String number);

  /// No description provided for @userIdLabel.
  ///
  /// In fr, this message translates to:
  /// **'User {id}'**
  String userIdLabel(String id);

  /// No description provided for @canContactAgain.
  ///
  /// In fr, this message translates to:
  /// **'{name} pourra de nouveau vous contacter.'**
  String canContactAgain(String name);

  /// No description provided for @removePreferredContact.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} des contacts préférés'**
  String removePreferredContact(String name);

  /// No description provided for @videoMaxSelectable.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo : {count} max.'**
  String videoMaxSelectable(int count);

  /// No description provided for @callBackName.
  ///
  /// In fr, this message translates to:
  /// **'Rappeler {name}'**
  String callBackName(String name);

  /// No description provided for @mediaTitleNamed.
  ///
  /// In fr, this message translates to:
  /// **'{name} — Médias'**
  String mediaTitleNamed(String name);

  /// No description provided for @photosCount.
  ///
  /// In fr, this message translates to:
  /// **'📷 {count} photos'**
  String photosCount(int count);

  /// No description provided for @videosCount.
  ///
  /// In fr, this message translates to:
  /// **'🎥 {count} vidéos'**
  String videosCount(int count);

  /// No description provided for @locationLabel.
  ///
  /// In fr, this message translates to:
  /// **'📍 {label}'**
  String locationLabel(String label);

  /// No description provided for @contactLabel.
  ///
  /// In fr, this message translates to:
  /// **'👤 {label}'**
  String contactLabel(String label);

  /// No description provided for @tapToOpenLabel.
  ///
  /// In fr, this message translates to:
  /// **'{label} · appuyer pour ouvrir'**
  String tapToOpenLabel(String label);

  /// No description provided for @mediaAccessErrorMakeSureHttps.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'accès aux médias. Vérifiez que HTTPS est activé ou que vous êtes sur localhost.'**
  String get mediaAccessErrorMakeSureHttps;

  /// No description provided for @cannotAccessMicrophoneCameraCheckThat.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'accéder au microphone/caméra. Vérifiez que l\'application a les permissions.'**
  String get cannotAccessMicrophoneCameraCheckThat;

  /// No description provided for @thisActionCannotBeUndoneThe.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible. La réunion sera supprimée pour tous les participants.'**
  String get thisActionCannotBeUndoneThe;

  /// No description provided for @ifYouReceivedAMeetingLink.
  ///
  /// In fr, this message translates to:
  /// **'Si vous avez reçu un lien de réunion, vous pouvez cliquer sur le lien à la place.'**
  String get ifYouReceivedAMeetingLink;

  /// No description provided for @microphoneErrorPleaseCheckYourPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Erreur microphone. Veuillez vérifier vos permissions et votre matériel audio.'**
  String get microphoneErrorPleaseCheckYourPermissions;

  /// No description provided for @permissionDeniedOpenSettingsOrPick.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée. Ouvrez les réglages ou choisissez un point sur la carte.'**
  String get permissionDeniedOpenSettingsOrPick;

  /// No description provided for @statusesFromContactsWhoFavoritedYou.
  ///
  /// In fr, this message translates to:
  /// **'Les statuts de vos contacts qui vous ont ajouté en favori s\'afficheront ici.'**
  String get statusesFromContactsWhoFavoritedYou;

  /// No description provided for @enableLocationToUseYourPosition.
  ///
  /// In fr, this message translates to:
  /// **'Activez la localisation pour utiliser votre position, ou déplacez la carte.'**
  String get enableLocationToUseYourPosition;

  /// No description provided for @permissionDeniedYouCanStillPick.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée. Vous pouvez quand même choisir un point sur la carte.'**
  String get permissionDeniedYouCanStillPick;

  /// No description provided for @addContactsToFindThemQuickly.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des contacts pour les retrouver\nrapidement lors de vos réunions'**
  String get addContactsToFindThemQuickly;

  /// No description provided for @editingIsOnlyPossibleWithin30.
  ///
  /// In fr, this message translates to:
  /// **'La modification n\'est possible que dans les 30 minutes suivant l\'envoi'**
  String get editingIsOnlyPossibleWithin30;

  /// No description provided for @cameraErrorPleaseCheckYourPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Erreur caméra. Veuillez vérifier vos permissions et votre caméra.'**
  String get cameraErrorPleaseCheckYourPermissions;

  /// No description provided for @saveTheseDetailsYouWillNeed.
  ///
  /// In fr, this message translates to:
  /// **'Notez ces informations — elles vous serviront à vous connecter :'**
  String get saveTheseDetailsYouWillNeed;

  /// No description provided for @doYouWantToEndThe.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous mettre fin à la réunion pour tous les participants ?'**
  String get doYouWantToEndThe;

  /// No description provided for @freeEntryReservedPatternsOrStandard.
  ///
  /// In fr, this message translates to:
  /// **'Saisie libre : patterns réservés ou numéros standard 8 chiffres'**
  String get freeEntryReservedPatternsOrStandard;

  /// No description provided for @viewOnceMediaVisibleOnlyOnce.
  ///
  /// In fr, this message translates to:
  /// **'Média à vue unique — visible une seule fois par le destinataire'**
  String get viewOnceMediaVisibleOnlyOnce;

  /// No description provided for @youWillNoLongerSeeThis.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne verrez plus ce groupe dans votre liste de discussions.'**
  String get youWillNoLongerSeeThis;

  /// No description provided for @cannotAccessDevicesCheckPermissions.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'accéder aux appareils. Vérifiez les permissions.'**
  String get cannotAccessDevicesCheckPermissions;

  /// No description provided for @permissionDeniedPleaseAllowMicrophoneCamera.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée. Veuillez autoriser le microphone/caméra.'**
  String get permissionDeniedPleaseAllowMicrophoneCamera;

  /// No description provided for @theyWillNoLongerBeAble.
  ///
  /// In fr, this message translates to:
  /// **'Il ne pourra plus vous envoyer de messages ni vous appeler.'**
  String get theyWillNoLongerBeAble;

  /// No description provided for @n8DigitsAutoGeneratedExcludingReserved.
  ///
  /// In fr, this message translates to:
  /// **'8 chiffres (génération automatique, hors numéros réservés)'**
  String get n8DigitsAutoGeneratedExcludingReserved;

  /// No description provided for @noMicrophoneCameraDeviceFoundOn.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil microphone/caméra trouvé sur votre système.'**
  String get noMicrophoneCameraDeviceFoundOn;

  /// No description provided for @gpsUnavailableMoveTheMapTo.
  ///
  /// In fr, this message translates to:
  /// **'GPS indisponible. Déplacez la carte pour choisir un point.'**
  String get gpsUnavailableMoveTheMapTo;

  /// No description provided for @localMessagesInThisChatWill.
  ///
  /// In fr, this message translates to:
  /// **'Les messages locaux de cette discussion seront supprimés.'**
  String get localMessagesInThisChatWill;

  /// No description provided for @oneOrMoreMessagesCannotBe.
  ///
  /// In fr, this message translates to:
  /// **'Un ou plusieurs messages ne peuvent pas être transférés'**
  String get oneOrMoreMessagesCannotBe;

  /// No description provided for @mediaAccessErrorCheckHttpsOr.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'accès aux médias. Vérifiez HTTPS ou localhost.'**
  String get mediaAccessErrorCheckHttpsOr;

  /// No description provided for @noResultsEnterAFullPattern.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat — saisissez un numéro pattern complet '**
  String get noResultsEnterAFullPattern;

  /// No description provided for @conversationDeletedLocallyServerUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Discussion supprimée localement (serveur injoignable)'**
  String get conversationDeletedLocallyServerUnreachable;

  /// No description provided for @thisMessageCannotBeForwardedRight.
  ///
  /// In fr, this message translates to:
  /// **'Ce message ne peut pas être transféré pour le moment'**
  String get thisMessageCannotBeForwardedRight;

  /// No description provided for @thisAlbumCannotBeForwardedRight.
  ///
  /// In fr, this message translates to:
  /// **'Cet album ne peut pas être transféré pour le moment'**
  String get thisAlbumCannotBeForwardedRight;

  /// No description provided for @selectedChatsAreNotArchived.
  ///
  /// In fr, this message translates to:
  /// **'Les discussions sélectionnées ne sont pas archivées'**
  String get selectedChatsAreNotArchived;

  /// No description provided for @enterTheMeetingCodeProvidedBy.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le code de réunion fourni par l\'organisateur'**
  String get enterTheMeetingCodeProvidedBy;

  /// No description provided for @startANewChatWithThe.
  ///
  /// In fr, this message translates to:
  /// **'Démarrez une nouvelle discussion avec le bouton +.'**
  String get startANewChatWithThe;

  /// No description provided for @thisMediaCannotBeForwardedRight.
  ///
  /// In fr, this message translates to:
  /// **'Ce média ne peut pas être transféré pour le moment'**
  String get thisMediaCannotBeForwardedRight;

  /// No description provided for @reservationLimitedTo3Or4.
  ///
  /// In fr, this message translates to:
  /// **'Réservation limitée aux numéros 3 ou 4 chiffres, '**
  String get reservationLimitedTo3Or4;

  /// No description provided for @selectedChatsAreAlreadyArchived.
  ///
  /// In fr, this message translates to:
  /// **'Les discussions sélectionnées sont déjà archivées'**
  String get selectedChatsAreAlreadyArchived;

  /// No description provided for @selectedChatsAreAlreadyPinned.
  ///
  /// In fr, this message translates to:
  /// **'Les discussions sélectionnées sont déjà épinglées'**
  String get selectedChatsAreAlreadyPinned;

  /// No description provided for @unableToAddParticipantsTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter les participants, réessayez'**
  String get unableToAddParticipantsTryAgain;

  /// No description provided for @peopleYouBlockWillAppearHere.
  ///
  /// In fr, this message translates to:
  /// **'Les personnes que vous bloquez apparaîtront ici.'**
  String get peopleYouBlockWillAppearHere;

  /// No description provided for @unableToInviteParticipantsTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'inviter les participants, réessayez'**
  String get unableToInviteParticipantsTryAgain;

  /// No description provided for @pausedTapToReturn.
  ///
  /// In fr, this message translates to:
  /// **'En pause · {type} · Toucher pour revenir'**
  String pausedTapToReturn(String type);

  /// No description provided for @sayHelloToStartTheConversation.
  ///
  /// In fr, this message translates to:
  /// **'Dites bonjour pour démarrer la conversation !'**
  String get sayHelloToStartTheConversation;

  /// No description provided for @noFreeNumberFoundInThe.
  ///
  /// In fr, this message translates to:
  /// **'Aucun numéro libre trouvé dans la liste admin'**
  String get noFreeNumberFoundInThe;

  /// No description provided for @unableToDeleteTheMeetingTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer la réunion, réessayez'**
  String get unableToDeleteTheMeetingTry;

  /// No description provided for @yourPastAndReceivedCallsWill.
  ///
  /// In fr, this message translates to:
  /// **'Vos appels passés et reçus apparaîtront ici.'**
  String get yourPastAndReceivedCallsWill;

  /// No description provided for @microphoneCameraPermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission refusée pour le microphone/caméra'**
  String get microphoneCameraPermissionDenied;

  /// No description provided for @unableToRemoveThisContactTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de retirer ce contact, réessayez'**
  String get unableToRemoveThisContactTry;

  /// No description provided for @newChatUnavailableOffline.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle discussion indisponible hors ligne'**
  String get newChatUnavailableOffline;

  /// No description provided for @messageNotFoundInThisConversation.
  ///
  /// In fr, this message translates to:
  /// **'Message introuvable dans cette conversation'**
  String get messageNotFoundInThisConversation;

  /// No description provided for @numberMustContainOnlyDigits.
  ///
  /// In fr, this message translates to:
  /// **'Le numéro ne doit contenir que des chiffres'**
  String get numberMustContainOnlyDigits;

  /// No description provided for @invalidNumber34Or8.
  ///
  /// In fr, this message translates to:
  /// **'Numéro invalide : 3, 4 ou 8 chiffres requis'**
  String get invalidNumber34Or8;

  /// No description provided for @errorCreatingTheConversation.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la création de la discussion'**
  String get errorCreatingTheConversation;

  /// No description provided for @unableToLeaveTheGroupTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de quitter le groupe, réessayez'**
  String get unableToLeaveTheGroupTry;

  /// No description provided for @unableToPostTheStatusTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de publier le statut, réessayez'**
  String get unableToPostTheStatusTry;

  /// No description provided for @unableToAddThisContactTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter ce contact, réessayez'**
  String get unableToAddThisContactTry;

  /// No description provided for @canBeOpenedOnlyOnceThen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrable une seule fois, puis inaccessible'**
  String get canBeOpenedOnlyOnceThen;

  /// No description provided for @unableToLoadBlockedContacts.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les contacts bloqués'**
  String get unableToLoadBlockedContacts;

  /// No description provided for @enterANumberOrChooseA.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un numéro ou choisissez un contact'**
  String get enterANumberOrChooseA;

  /// No description provided for @unableToCreateTheMeetingTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer la réunion, réessayez'**
  String get unableToCreateTheMeetingTry;

  /// No description provided for @unableToCreateTheGroupTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer le groupe, réessayez'**
  String get unableToCreateTheGroupTry;

  /// No description provided for @searchByNameUsernameOrPhone.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, pseudo ou ID Alanya…'**
  String get searchByNameUsernameOrPhone;

  /// No description provided for @assignAReservedNumberOptional.
  ///
  /// In fr, this message translates to:
  /// **'Attribuer un numéro réservé (optionnel)'**
  String get assignAReservedNumberOptional;

  /// No description provided for @ajoutezDesContactsPourLesRetrouver.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez des contacts pour les retrouver'**
  String get ajoutezDesContactsPourLesRetrouver;

  /// No description provided for @unableToStartTheCallTry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lancer l\'appel, réessayez'**
  String get unableToStartTheCallTry;

  /// No description provided for @cannotInviteABlockedContact.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'inviter un contact bloqué'**
  String get cannotInviteABlockedContact;

  /// No description provided for @manageUsersAndMonitoring.
  ///
  /// In fr, this message translates to:
  /// **'Gérez les utilisateurs et surveillance'**
  String get manageUsersAndMonitoring;

  /// No description provided for @fromGalleryOrCamera.
  ///
  /// In fr, this message translates to:
  /// **'Depuis la galerie ou l\'appareil photo'**
  String get fromGalleryOrCamera;

  /// No description provided for @passwordResetSuccessfully.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe réinitialisé avec succès'**
  String get passwordResetSuccessfully;

  /// No description provided for @reservedPatternDirectAssignment.
  ///
  /// In fr, this message translates to:
  /// **'Pattern réservé (attribution directe)'**
  String get reservedPatternDirectAssignment;

  /// No description provided for @unableToForwardTheMessages.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de transférer les messages'**
  String get unableToForwardTheMessages;

  /// No description provided for @longPressToExitSelection.
  ///
  /// In fr, this message translates to:
  /// **'Appui long pour quitter la sélection'**
  String get longPressToExitSelection;

  /// No description provided for @unableToDownloadTheFile.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de télécharger le fichier'**
  String get unableToDownloadTheFile;

  /// No description provided for @yourProfilePhotoWillBeRemoved.
  ///
  /// In fr, this message translates to:
  /// **'Votre photo de profil sera retirée.'**
  String get yourProfilePhotoWillBeRemoved;

  /// No description provided for @unableToForwardTheMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de transférer le message'**
  String get unableToForwardTheMessage;

  /// No description provided for @thisNumberCannotBeAssigned.
  ///
  /// In fr, this message translates to:
  /// **'Ce numéro ne peut pas être attribué'**
  String get thisNumberCannotBeAssigned;

  /// No description provided for @unableToUpdateTheCountry.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de mettre à jour le pays'**
  String get unableToUpdateTheCountry;

  /// No description provided for @errorStartingTheCall.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors du démarrage de l\'appel'**
  String get errorStartingTheCall;

  /// No description provided for @unableToDownloadTheMedia.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de télécharger le média'**
  String get unableToDownloadTheMedia;

  /// No description provided for @unableToUnblockThisContact.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de débloquer ce contact'**
  String get unableToUnblockThisContact;

  /// No description provided for @unableToLoadNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les numéros'**
  String get unableToLoadNumbers;

  /// No description provided for @searchByNameUsernameOr.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, pseudo ou ...'**
  String get searchByNameUsernameOr;

  /// No description provided for @unableToCreateTheConversation.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de créer la discussion'**
  String get unableToCreateTheConversation;

  /// No description provided for @noAudioVideoDeviceFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appareil audio/vidéo trouvé'**
  String get noAudioVideoDeviceFound;

  /// No description provided for @unableToOpenTheConversation.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir la discussion'**
  String get unableToOpenTheConversation;

  /// No description provided for @connectingTapToReturn.
  ///
  /// In fr, this message translates to:
  /// **'Connexion… · Toucher pour revenir'**
  String get connectingTapToReturn;

  /// No description provided for @unableToVerifyTheContact.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de vérifier le contact'**
  String get unableToVerifyTheContact;

  /// No description provided for @meetingInvitationsAndReminders.
  ///
  /// In fr, this message translates to:
  /// **'Invitations et rappels de réunion'**
  String get meetingInvitationsAndReminders;

  /// No description provided for @errorGroupIdNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : ID du groupe introuvable'**
  String get errorGroupIdNotFound;

  /// No description provided for @profileUnavailableTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Profil non disponible, réessayez'**
  String get profileUnavailableTryAgain;

  /// No description provided for @cannotCallThisContact.
  ///
  /// In fr, this message translates to:
  /// **'Appel impossible avec ce contact'**
  String get cannotCallThisContact;

  /// No description provided for @unableToForwardTheAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de transférer l\'album'**
  String get unableToForwardTheAlbum;

  /// No description provided for @thisGroupIsNoLongerAccessible.
  ///
  /// In fr, this message translates to:
  /// **'Ce groupe n\'est plus accessible.'**
  String get thisGroupIsNoLongerAccessible;

  /// No description provided for @youHaveBlockedThisUser.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez bloqué cet utilisateur'**
  String get youHaveBlockedThisUser;

  /// No description provided for @unableToDisplayTheMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'afficher le message'**
  String get unableToDisplayTheMessage;

  /// No description provided for @meetingInLessThan10Minutes.
  ///
  /// In fr, this message translates to:
  /// **'Réunion dans moins de 10 minutes'**
  String get meetingInLessThan10Minutes;

  /// No description provided for @addACaptionOptional.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une légende (optionnel)'**
  String get addACaptionOptional;

  /// No description provided for @rapidementLorsDeVosReunions.
  ///
  /// In fr, this message translates to:
  /// **'rapidement lors de vos réunions'**
  String get rapidementLorsDeVosReunions;

  /// No description provided for @alreadyInYourPreferredContacts.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans vos contacts préférés'**
  String get alreadyInYourPreferredContacts;

  /// No description provided for @dateMustBeInTheFuture.
  ///
  /// In fr, this message translates to:
  /// **'La date doit être dans le futur'**
  String get dateMustBeInTheFuture;

  /// No description provided for @longPressFailedTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Échec appui long pour réessayer'**
  String get longPressFailedTryAgain;

  /// No description provided for @eG112233441234OrLabel.
  ///
  /// In fr, this message translates to:
  /// **'Ex. 11223344, 1234, ou libellé…'**
  String get eG112233441234OrLabel;

  /// No description provided for @theOtherPartyIsBusy.
  ///
  /// In fr, this message translates to:
  /// **'Votre correspondant est occupé.'**
  String get theOtherPartyIsBusy;

  /// No description provided for @viewAndUnblockContacts.
  ///
  /// In fr, this message translates to:
  /// **'Voir et débloquer les contacts'**
  String get viewAndUnblockContacts;

  /// No description provided for @thisActionCannotBeUndone.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irréversible.'**
  String get thisActionCannotBeUndone;

  /// No description provided for @mediaIsNotReadyYet.
  ///
  /// In fr, this message translates to:
  /// **'Le média n\'est pas encore prêt'**
  String get mediaIsNotReadyYet;

  /// No description provided for @thisMediaIsNoLongerAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Ce média n\'est plus disponible'**
  String get thisMediaIsNoLongerAvailable;

  /// No description provided for @yourSignInCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Vos identifiants de connexion'**
  String get yourSignInCredentials;

  /// No description provided for @resetPassword.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser le mot de passe'**
  String get resetPassword;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In fr, this message translates to:
  /// **'Permission microphone refusée'**
  String get microphonePermissionDenied;

  /// No description provided for @noConversationToDelete.
  ///
  /// In fr, this message translates to:
  /// **'Aucune discussion à supprimer'**
  String get noConversationToDelete;

  /// No description provided for @phoneAlanyaPhone.
  ///
  /// In fr, this message translates to:
  /// **'ID Alanya'**
  String get phoneAlanyaPhone;

  /// No description provided for @noOtherMembersToCall.
  ///
  /// In fr, this message translates to:
  /// **'Aucun autre membre à appeler'**
  String get noOtherMembersToCall;

  /// No description provided for @actionFailedPleaseTryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible, réessayez'**
  String get actionFailedPleaseTryAgain;

  /// No description provided for @failedToAddParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Ajout de participants échoué'**
  String get failedToAddParticipants;

  /// No description provided for @noArchivedConversations.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation archivée'**
  String get noArchivedConversations;

  /// No description provided for @noConnectionsRecorded.
  ///
  /// In fr, this message translates to:
  /// **'Aucune connexion enregistrée'**
  String get noConnectionsRecorded;

  /// No description provided for @countryListUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Liste des pays indisponible'**
  String get countryListUnavailable;

  /// No description provided for @profilePhotoUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil mise à jour'**
  String get profilePhotoUpdated;

  /// No description provided for @searchByNameUsername.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher par nom, pseudo…'**
  String get searchByNameUsername;

  /// No description provided for @noConversationToClear.
  ///
  /// In fr, this message translates to:
  /// **'Aucune discussion à effacer'**
  String get noConversationToClear;

  /// No description provided for @historyWillBeDeleted.
  ///
  /// In fr, this message translates to:
  /// **'L\'historique sera supprimé.'**
  String get historyWillBeDeleted;

  /// No description provided for @addAtLeastOneMember.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au moins un membre'**
  String get addAtLeastOneMember;

  /// No description provided for @searchChats.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une discussion…'**
  String get searchChats;

  /// No description provided for @thisMediaHasAlreadyBeenOpened.
  ///
  /// In fr, this message translates to:
  /// **'Ce média a déjà été ouvert'**
  String get thisMediaHasAlreadyBeenOpened;

  /// No description provided for @addAPreferredContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact préféré'**
  String get addAPreferredContact;

  /// No description provided for @enterANumberToAdd.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un numéro à ajouter'**
  String get enterANumberToAdd;

  /// No description provided for @noMeetingsToday.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réunion aujourd\'hui'**
  String get noMeetingsToday;

  /// No description provided for @aCallIsAlreadyInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Un appel est déjà en cours'**
  String get aCallIsAlreadyInProgress;

  /// No description provided for @failedToCreateGroup.
  ///
  /// In fr, this message translates to:
  /// **'Création du groupe échouée'**
  String get failedToCreateGroup;

  /// No description provided for @turnOffSpeaker.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver le haut-parleur'**
  String get turnOffSpeaker;

  /// No description provided for @noParticipantsConnected.
  ///
  /// In fr, this message translates to:
  /// **'Aucun participant connecté'**
  String get noParticipantsConnected;

  /// No description provided for @chooseFromGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir depuis la galerie'**
  String get chooseFromGallery;

  /// No description provided for @deleteConversation.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la discussion ?'**
  String get deleteConversation;

  /// No description provided for @manualNumberEntry.
  ///
  /// In fr, this message translates to:
  /// **'Saisie manuelle du numéro'**
  String get manualNumberEntry;

  /// No description provided for @thisMessageWasDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Ce message a été supprimé'**
  String get thisMessageWasDeleted;

  /// No description provided for @deleteUser.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'utilisateur ?'**
  String get deleteUser;

  /// No description provided for @mediaAccessError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur d\'accès aux médias'**
  String get mediaAccessError;

  /// No description provided for @addADescription.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une description…'**
  String get addADescription;

  /// No description provided for @microphonePermissionDenied2.
  ///
  /// In fr, this message translates to:
  /// **'Permission micro refusée'**
  String get microphonePermissionDenied2;

  /// No description provided for @failedToLeaveGroup.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe échoué'**
  String get failedToLeaveGroup;

  /// No description provided for @unableToOpenMaps.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir Maps'**
  String get unableToOpenMaps;

  /// No description provided for @conversationNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Conversation introuvable'**
  String get conversationNotFound;

  /// No description provided for @addParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des participants'**
  String get addParticipants;

  /// No description provided for @tapToDownload.
  ///
  /// In fr, this message translates to:
  /// **'Appuyer pour télécharger'**
  String get tapToDownload;

  /// No description provided for @pdfPageCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} pages'**
  String pdfPageCount(int count);

  /// No description provided for @noUsersFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun utilisateur trouvé'**
  String get noUsersFound;

  /// No description provided for @enterTheGroupName.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le nom du groupe'**
  String get enterTheGroupName;

  /// No description provided for @requiredExceptTier3.
  ///
  /// In fr, this message translates to:
  /// **'Obligatoire sauf tier 3'**
  String get requiredExceptTier3;

  /// No description provided for @deleteConversation2.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la discussion'**
  String get deleteConversation2;

  /// No description provided for @userNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur introuvable'**
  String get userNotFound;

  /// No description provided for @downloadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec du téléchargement'**
  String get downloadFailed;

  /// No description provided for @invalidUploadResponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse upload invalide'**
  String get invalidUploadResponse;

  /// No description provided for @enableLocation.
  ///
  /// In fr, this message translates to:
  /// **'Activer la localisation'**
  String get enableLocation;

  /// No description provided for @noUpcomingMeetings.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réunion à venir'**
  String get noUpcomingMeetings;

  /// No description provided for @exampleAbcDefgHij.
  ///
  /// In fr, this message translates to:
  /// **'Exemple : abc-defg-hij'**
  String get exampleAbcDefgHij;

  /// No description provided for @unblockThisContact.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer ce contact ?'**
  String get unblockThisContact;

  /// No description provided for @clearMessages.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les messages ?'**
  String get clearMessages;

  /// No description provided for @sendThisLocation.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer cette position'**
  String get sendThisLocation;

  /// No description provided for @startVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer l\'appel vidéo'**
  String get startVideoCall;

  /// No description provided for @forwardUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Transfert indisponible'**
  String get forwardUnavailable;

  /// No description provided for @startVoiceCall.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer l\'appel vocal'**
  String get startVoiceCall;

  /// No description provided for @noPastMeetings.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réunion passée'**
  String get noPastMeetings;

  /// No description provided for @scheduleAMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Planifier une réunion'**
  String get scheduleAMeeting;

  /// No description provided for @n34DigitsOrXxyyzztt.
  ///
  /// In fr, this message translates to:
  /// **'3 / 4 ch. ou XXYYZZTT'**
  String get n34DigitsOrXxyyzztt;

  /// No description provided for @groupCallInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Appel groupé en cours'**
  String get groupCallInProgress;

  /// No description provided for @deleteThisStatus.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce statut ?'**
  String get deleteThisStatus;

  /// No description provided for @mediaLinksAndDocs.
  ///
  /// In fr, this message translates to:
  /// **'Médias, liens et docs'**
  String get mediaLinksAndDocs;

  /// No description provided for @searchForACountry.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un pays...'**
  String get searchForACountry;

  /// No description provided for @voiceMessageEnded.
  ///
  /// In fr, this message translates to:
  /// **'Message vocal terminé'**
  String get voiceMessageEnded;

  /// No description provided for @musicEnded.
  ///
  /// In fr, this message translates to:
  /// **'Musique terminée'**
  String get musicEnded;

  /// No description provided for @noPreferredContacts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact préféré'**
  String get noPreferredContacts;

  /// No description provided for @donTHaveAnAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte?'**
  String get donTHaveAnAccount;

  /// No description provided for @joinAMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre une réunion'**
  String get joinAMeeting;

  /// No description provided for @meetingDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détail de la réunion'**
  String get meetingDetails;

  /// No description provided for @noBlockedContacts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact bloqué'**
  String get noBlockedContacts;

  /// No description provided for @blockThisContact.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer ce contact ?'**
  String get blockThisContact;

  /// No description provided for @sendALocation.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer une position'**
  String get sendALocation;

  /// No description provided for @createUser.
  ///
  /// In fr, this message translates to:
  /// **'Créer un utilisateur'**
  String get createUser;

  /// No description provided for @addACaption.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une légende…'**
  String get addACaption;

  /// No description provided for @alanyaNumberRequired.
  ///
  /// In fr, this message translates to:
  /// **'ID Alanya requis'**
  String get alanyaNumberRequired;

  /// No description provided for @selectACountry.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez un pays'**
  String get selectACountry;

  /// No description provided for @noReservedNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun numéro réservé'**
  String get noReservedNumbers;

  /// No description provided for @clearMessages2.
  ///
  /// In fr, this message translates to:
  /// **'Effacer les messages'**
  String get clearMessages2;

  /// No description provided for @removeFromContacts.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des contacts'**
  String get removeFromContacts;

  /// No description provided for @messageToForward.
  ///
  /// In fr, this message translates to:
  /// **'Message à transférer'**
  String get messageToForward;

  /// No description provided for @deletePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo ?'**
  String get deletePhoto;

  /// No description provided for @unblockContact.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer le contact'**
  String get unblockContact;

  /// No description provided for @loadingCountries.
  ///
  /// In fr, this message translates to:
  /// **'Chargement des pays…'**
  String get loadingCountries;

  /// No description provided for @newChat.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle discussion'**
  String get newChat;

  /// No description provided for @typeYourStatus.
  ///
  /// In fr, this message translates to:
  /// **'Tapez votre statut…'**
  String get typeYourStatus;

  /// No description provided for @editMessage.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le message'**
  String get editMessage;

  /// No description provided for @noRecentStatus.
  ///
  /// In fr, this message translates to:
  /// **'Aucun statut récent'**
  String get noRecentStatus;

  /// No description provided for @closeSearch.
  ///
  /// In fr, this message translates to:
  /// **'Fermer la recherche'**
  String get closeSearch;

  /// No description provided for @sendLocation.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer la position'**
  String get sendLocation;

  /// No description provided for @openSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get openSettings;

  /// No description provided for @statusReply.
  ///
  /// In fr, this message translates to:
  /// **'Réponse à un statut'**
  String get statusReply;

  /// No description provided for @statusNoLongerAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Ce statut n\'est plus disponible'**
  String get statusNoLongerAvailable;

  /// No description provided for @socketNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Socket non connecté'**
  String get socketNotConnected;

  /// No description provided for @deleteForEveryone.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer pour tous'**
  String get deleteForEveryone;

  /// No description provided for @meetingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre de la réunion'**
  String get meetingTitle;

  /// No description provided for @connecting.
  ///
  /// In fr, this message translates to:
  /// **'Connexion en cours…'**
  String get connecting;

  /// No description provided for @callReconnecting.
  ///
  /// In fr, this message translates to:
  /// **'Reconnexion…'**
  String get callReconnecting;

  /// No description provided for @freeUnassigned.
  ///
  /// In fr, this message translates to:
  /// **'Libre · non assigné'**
  String get freeUnassigned;

  /// No description provided for @numberUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Numéro indisponible'**
  String get numberUnavailable;

  /// No description provided for @meetingNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Réunion introuvable'**
  String get meetingNotFound;

  /// No description provided for @recentConnections.
  ///
  /// In fr, this message translates to:
  /// **'Connexions récentes'**
  String get recentConnections;

  /// No description provided for @replyToStatus.
  ///
  /// In fr, this message translates to:
  /// **'Répondre au statut…'**
  String get replyToStatus;

  /// No description provided for @noSharedMedia.
  ///
  /// In fr, this message translates to:
  /// **'Aucun média partagé'**
  String get noSharedMedia;

  /// No description provided for @leaveGroup.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe ?'**
  String get leaveGroup;

  /// No description provided for @typing.
  ///
  /// In fr, this message translates to:
  /// **'en train d\'écrire…'**
  String get typing;

  /// No description provided for @cancelMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la réunion'**
  String get cancelMeeting;

  /// No description provided for @editProfile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get editProfile;

  /// No description provided for @blockContact.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer le contact'**
  String get blockContact;

  /// No description provided for @groupNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Groupe introuvable'**
  String get groupNotFound;

  /// No description provided for @deleteForMe.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer pour moi'**
  String get deleteForMe;

  /// No description provided for @groupVideoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel groupé vidéo'**
  String get groupVideoCall;

  /// No description provided for @noRecentCalls.
  ///
  /// In fr, this message translates to:
  /// **'Aucun appel récent'**
  String get noRecentCalls;

  /// No description provided for @audioUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Audio indisponible'**
  String get audioUnavailable;

  /// No description provided for @typing2.
  ///
  /// In fr, this message translates to:
  /// **'En train d\'écrire…'**
  String get typing2;

  /// No description provided for @numberOrLabel.
  ///
  /// In fr, this message translates to:
  /// **'Numéro ou libellé…'**
  String get numberOrLabel;

  /// No description provided for @albumToForward.
  ///
  /// In fr, this message translates to:
  /// **'Album à transférer'**
  String get albumToForward;

  /// No description provided for @mediaUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Média indisponible'**
  String get mediaUnavailable;

  /// No description provided for @messageDetails.
  ///
  /// In fr, this message translates to:
  /// **'Détails du message'**
  String get messageDetails;

  /// No description provided for @endForEveryone.
  ///
  /// In fr, this message translates to:
  /// **'Terminer pour tous'**
  String get endForEveryone;

  /// No description provided for @writeAMessage.
  ///
  /// In fr, this message translates to:
  /// **'Écrire un message…'**
  String get writeAMessage;

  /// No description provided for @changeNumber.
  ///
  /// In fr, this message translates to:
  /// **'Changer le numéro'**
  String get changeNumber;

  /// No description provided for @countryUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Pays indisponible'**
  String get countryUnavailable;

  /// No description provided for @numberAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Numéro disponible'**
  String get numberAvailable;

  /// No description provided for @addAVideo.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une vidéo'**
  String get addAVideo;

  /// No description provided for @noCountryFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun pays trouvé'**
  String get noCountryFound;

  /// No description provided for @addAPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une photo'**
  String get addAPhoto;

  /// No description provided for @cameraDisabled.
  ///
  /// In fr, this message translates to:
  /// **'Caméra désactivée'**
  String get cameraDisabled;

  /// No description provided for @searchComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Recherche à venir'**
  String get searchComingSoon;

  /// No description provided for @takeAPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get takeAPhoto;

  /// No description provided for @enableCamera.
  ///
  /// In fr, this message translates to:
  /// **'Activer la caméra'**
  String get enableCamera;

  /// No description provided for @switchCamera.
  ///
  /// In fr, this message translates to:
  /// **'Changer de caméra'**
  String get switchCamera;

  /// No description provided for @noChats.
  ///
  /// In fr, this message translates to:
  /// **'Aucune discussion'**
  String get noChats;

  /// No description provided for @callFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec de l\'appel.'**
  String get callFailed;

  /// No description provided for @retrySending.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer l\'envoi'**
  String get retrySending;

  /// No description provided for @leaveGroup2.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe'**
  String get leaveGroup2;

  /// No description provided for @preferredContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts préférés'**
  String get preferredContacts;

  /// No description provided for @turnOffCamera.
  ///
  /// In fr, this message translates to:
  /// **'Couper la caméra'**
  String get turnOffCamera;

  /// No description provided for @messagesCleared.
  ///
  /// In fr, this message translates to:
  /// **'Messages effacés'**
  String get messagesCleared;

  /// No description provided for @reservedNumbers.
  ///
  /// In fr, this message translates to:
  /// **'Numéros réservés'**
  String get reservedNumbers;

  /// No description provided for @meetingEnded.
  ///
  /// In fr, this message translates to:
  /// **'Réunion terminée'**
  String get meetingEnded;

  /// No description provided for @newMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle réunion'**
  String get newMeeting;

  /// No description provided for @alanyaPhone.
  ///
  /// In fr, this message translates to:
  /// **'ID Alanya'**
  String get alanyaPhone;

  /// No description provided for @deletedMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message supprimé'**
  String get deletedMessage;

  /// No description provided for @verifyCode.
  ///
  /// In fr, this message translates to:
  /// **'Vérifier le code'**
  String get verifyCode;

  /// No description provided for @notDeliveredYet.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore livré'**
  String get notDeliveredYet;

  /// No description provided for @someoneIsTyping.
  ///
  /// In fr, this message translates to:
  /// **'Quelqu\'un écrit…'**
  String get someoneIsTyping;

  /// No description provided for @lastWeek.
  ///
  /// In fr, this message translates to:
  /// **'Dernière semaine'**
  String get lastWeek;

  /// No description provided for @otherResults.
  ///
  /// In fr, this message translates to:
  /// **'Autres résultats'**
  String get otherResults;

  /// No description provided for @changeMedia.
  ///
  /// In fr, this message translates to:
  /// **'Changer le média'**
  String get changeMedia;

  /// No description provided for @contactUnblocked.
  ///
  /// In fr, this message translates to:
  /// **'Contact débloqué'**
  String get contactUnblocked;

  /// No description provided for @downloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement…'**
  String get downloading;

  /// No description provided for @minimizeCall.
  ///
  /// In fr, this message translates to:
  /// **'Réduire l\'appel'**
  String get minimizeCall;

  /// No description provided for @createAGroup.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get createAGroup;

  /// No description provided for @dashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord'**
  String get dashboard;

  /// No description provided for @replySent.
  ///
  /// In fr, this message translates to:
  /// **'Réponse envoyée'**
  String get replySent;

  /// No description provided for @sessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée'**
  String get sessionExpired;

  /// No description provided for @callInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Appel en cours…'**
  String get callInProgress;

  /// No description provided for @createGroup.
  ///
  /// In fr, this message translates to:
  /// **'Créer le groupe'**
  String get createGroup;

  /// No description provided for @newMessage.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau message'**
  String get newMessage;

  /// No description provided for @groupInfo.
  ///
  /// In fr, this message translates to:
  /// **'Infos du groupe'**
  String get groupInfo;

  /// No description provided for @placeACall.
  ///
  /// In fr, this message translates to:
  /// **'Lancer un appel'**
  String get placeACall;

  /// No description provided for @newContact.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get newContact;

  /// No description provided for @noAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réponse.'**
  String get noAnswer;

  /// No description provided for @backgroundColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur de fond'**
  String get backgroundColor;

  /// No description provided for @photoDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Photo supprimée'**
  String get photoDeleted;

  /// No description provided for @serverError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur'**
  String get serverError;

  /// No description provided for @noDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document'**
  String get noDocuments;

  /// No description provided for @reservedNumber.
  ///
  /// In fr, this message translates to:
  /// **'Numéro réservé'**
  String get reservedNumber;

  /// No description provided for @password.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe *'**
  String get password;

  /// No description provided for @notNow.
  ///
  /// In fr, this message translates to:
  /// **'Pas maintenant'**
  String get notNow;

  /// No description provided for @missedCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels manqués'**
  String get missedCalls;

  /// No description provided for @newStatus.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau statut'**
  String get newStatus;

  /// No description provided for @newGroup.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get newGroup;

  /// No description provided for @noResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat'**
  String get noResults;

  /// No description provided for @labelRequired.
  ///
  /// In fr, this message translates to:
  /// **'Libellé requis'**
  String get labelRequired;

  /// No description provided for @unlike.
  ///
  /// In fr, this message translates to:
  /// **'Je n\'aime plus'**
  String get unlike;

  /// No description provided for @messages7d.
  ///
  /// In fr, this message translates to:
  /// **'Messages (7j)'**
  String get messages7d;

  /// No description provided for @noContacts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact'**
  String get noContacts;

  /// No description provided for @callEnded.
  ///
  /// In fr, this message translates to:
  /// **'Appel terminé'**
  String get callEnded;

  /// No description provided for @joinedOn.
  ///
  /// In fr, this message translates to:
  /// **'Inscrit(e) le'**
  String get joinedOn;

  /// No description provided for @uploadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Upload échoué'**
  String get uploadFailed;

  /// No description provided for @cameraOn.
  ///
  /// In fr, this message translates to:
  /// **'Caméra active'**
  String get cameraOn;

  /// No description provided for @cameraOff.
  ///
  /// In fr, this message translates to:
  /// **'Caméra coupée'**
  String get cameraOff;

  /// No description provided for @verifying.
  ///
  /// In fr, this message translates to:
  /// **'Vérification…'**
  String get verifying;

  /// No description provided for @reRecord.
  ///
  /// In fr, this message translates to:
  /// **'Réenregistrer'**
  String get reRecord;

  /// No description provided for @videoComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo à venir'**
  String get videoComingSoon;

  /// No description provided for @dateAndTime.
  ///
  /// In fr, this message translates to:
  /// **'Date et heure'**
  String get dateAndTime;

  /// No description provided for @noMessages.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message'**
  String get noMessages;

  /// No description provided for @lastCall.
  ///
  /// In fr, this message translates to:
  /// **'Dernier appel'**
  String get lastCall;

  /// No description provided for @videoMeeting.
  ///
  /// In fr, this message translates to:
  /// **'Réunion vidéo'**
  String get videoMeeting;

  /// No description provided for @groupName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get groupName;

  /// No description provided for @callComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Appel à venir'**
  String get callComingSoon;

  /// No description provided for @noAnswer2.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse'**
  String get noAnswer2;

  /// No description provided for @organizer.
  ///
  /// In fr, this message translates to:
  /// **'Organisateur'**
  String get organizer;

  /// No description provided for @noImages.
  ///
  /// In fr, this message translates to:
  /// **'Aucune image'**
  String get noImages;

  /// No description provided for @emptyMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message vide'**
  String get emptyMessage;

  /// No description provided for @rewind10S.
  ///
  /// In fr, this message translates to:
  /// **'Reculer 10 s'**
  String get rewind10S;

  /// No description provided for @pdfDocument.
  ///
  /// In fr, this message translates to:
  /// **'Document PDF'**
  String get pdfDocument;

  /// No description provided for @speaker.
  ///
  /// In fr, this message translates to:
  /// **'Haut-parleur'**
  String get speaker;

  /// No description provided for @newCall.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel appel'**
  String get newCall;

  /// No description provided for @lastView.
  ///
  /// In fr, this message translates to:
  /// **'Dernière vue'**
  String get lastView;

  /// No description provided for @receivedCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels reçus'**
  String get receivedCalls;

  /// No description provided for @participants.
  ///
  /// In fr, this message translates to:
  /// **'Participants'**
  String get participants;

  /// No description provided for @alreadyUsed.
  ///
  /// In fr, this message translates to:
  /// **'Déjà utilisé'**
  String get alreadyUsed;

  /// No description provided for @select.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner'**
  String get select;

  /// No description provided for @makeAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Rendre admin'**
  String get makeAdmin;

  /// No description provided for @statuses7d.
  ///
  /// In fr, this message translates to:
  /// **'Statuts (7j)'**
  String get statuses7d;

  /// No description provided for @forward10S.
  ///
  /// In fr, this message translates to:
  /// **'Avancer 10 s'**
  String get forward10S;

  /// No description provided for @openWith.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir avec…'**
  String get openWith;

  /// No description provided for @groupCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel groupé'**
  String get groupCall;

  /// No description provided for @noVideos.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vidéo'**
  String get noVideos;

  /// No description provided for @chats.
  ///
  /// In fr, this message translates to:
  /// **'Discussions'**
  String get chats;

  /// No description provided for @creating.
  ///
  /// In fr, this message translates to:
  /// **'Création...'**
  String get creating;

  /// No description provided for @videoCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo'**
  String get videoCall;

  /// No description provided for @unpin.
  ///
  /// In fr, this message translates to:
  /// **'Désépingler'**
  String get unpin;

  /// No description provided for @micMuted.
  ///
  /// In fr, this message translates to:
  /// **'Micro coupé'**
  String get micMuted;

  /// No description provided for @outgoingCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels émis'**
  String get outgoingCalls;

  /// No description provided for @micOn.
  ///
  /// In fr, this message translates to:
  /// **'Micro actif'**
  String get micOn;

  /// No description provided for @demote.
  ///
  /// In fr, this message translates to:
  /// **'Rétrograder'**
  String get demote;

  /// No description provided for @audioCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel audio'**
  String get audioCall;

  /// No description provided for @description.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @unarchive.
  ///
  /// In fr, this message translates to:
  /// **'Désarchiver'**
  String get unarchive;

  /// No description provided for @voiceCall.
  ///
  /// In fr, this message translates to:
  /// **'Appel vocal'**
  String get voiceCall;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher…'**
  String get search;

  /// No description provided for @signOut.
  ///
  /// In fr, this message translates to:
  /// **'Déconnexion'**
  String get signOut;

  /// No description provided for @calls7d.
  ///
  /// In fr, this message translates to:
  /// **'Appels (7j)'**
  String get calls7d;

  /// No description provided for @justNow.
  ///
  /// In fr, this message translates to:
  /// **'à l\'instant'**
  String get justNow;

  /// No description provided for @notSet.
  ///
  /// In fr, this message translates to:
  /// **'Non défini'**
  String get notSet;

  /// No description provided for @myStatus.
  ///
  /// In fr, this message translates to:
  /// **'Mon statut'**
  String get myStatus;

  /// No description provided for @noViews.
  ///
  /// In fr, this message translates to:
  /// **'Aucune vue'**
  String get noViews;

  /// No description provided for @connecting2.
  ///
  /// In fr, this message translates to:
  /// **'Connexion…'**
  String get connecting2;

  /// No description provided for @forward.
  ///
  /// In fr, this message translates to:
  /// **'Transférer'**
  String get forward;

  /// No description provided for @noLinks.
  ///
  /// In fr, this message translates to:
  /// **'Aucun lien'**
  String get noLinks;

  /// No description provided for @emptyAlbum.
  ///
  /// In fr, this message translates to:
  /// **'Album vide'**
  String get emptyAlbum;

  /// No description provided for @message.
  ///
  /// In fr, this message translates to:
  /// **'Message...'**
  String get message;

  /// No description provided for @offline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get offline;

  /// No description provided for @viewOnce.
  ///
  /// In fr, this message translates to:
  /// **'Vue unique'**
  String get viewOnce;

  /// No description provided for @refresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get refresh;

  /// No description provided for @location.
  ///
  /// In fr, this message translates to:
  /// **'📍 Position'**
  String get location;

  /// No description provided for @later.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get later;

  /// No description provided for @warning.
  ///
  /// In fr, this message translates to:
  /// **'Attention'**
  String get warning;

  /// No description provided for @seeAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get seeAll;

  /// No description provided for @forwarded.
  ///
  /// In fr, this message translates to:
  /// **'Transféré'**
  String get forwarded;

  /// No description provided for @edited.
  ///
  /// In fr, this message translates to:
  /// **'· modifié'**
  String get edited;

  /// No description provided for @unblock.
  ///
  /// In fr, this message translates to:
  /// **'Débloquer'**
  String get unblock;

  /// No description provided for @file.
  ///
  /// In fr, this message translates to:
  /// **'📎 Fichier'**
  String get file;

  /// No description provided for @results.
  ///
  /// In fr, this message translates to:
  /// **'Résultats'**
  String get results;

  /// No description provided for @join.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get join;

  /// No description provided for @allow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get allow;

  /// No description provided for @recently.
  ///
  /// In fr, this message translates to:
  /// **'Récemment'**
  String get recently;

  /// No description provided for @documents.
  ///
  /// In fr, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone'**
  String get phone;

  /// No description provided for @scheduled.
  ///
  /// In fr, this message translates to:
  /// **'Planifiée'**
  String get scheduled;

  /// No description provided for @contact.
  ///
  /// In fr, this message translates to:
  /// **'👤 Contact'**
  String get contact;

  /// No description provided for @gotIt.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai noté'**
  String get gotIt;

  /// No description provided for @banReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif ban'**
  String get banReason;

  /// No description provided for @used.
  ///
  /// In fr, this message translates to:
  /// **'Utilisés'**
  String get used;

  /// No description provided for @sentAt.
  ///
  /// In fr, this message translates to:
  /// **'Envoyé à'**
  String get sentAt;

  /// No description provided for @pin.
  ///
  /// In fr, this message translates to:
  /// **'Épingler'**
  String get pin;

  /// No description provided for @unpin2.
  ///
  /// In fr, this message translates to:
  /// **'Détacher'**
  String get unpin2;

  /// No description provided for @username.
  ///
  /// In fr, this message translates to:
  /// **'Pseudo *'**
  String get username;

  /// No description provided for @reply.
  ///
  /// In fr, this message translates to:
  /// **'Répondre'**
  String get reply;

  /// No description provided for @message2.
  ///
  /// In fr, this message translates to:
  /// **'Message…'**
  String get message2;

  /// No description provided for @unban.
  ///
  /// In fr, this message translates to:
  /// **'Débannir'**
  String get unban;

  /// No description provided for @online.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get online;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @inProgress.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get inProgress;

  /// No description provided for @ended.
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get ended;

  /// No description provided for @location2.
  ///
  /// In fr, this message translates to:
  /// **'Position'**
  String get location2;

  /// No description provided for @alreadyViewed.
  ///
  /// In fr, this message translates to:
  /// **'Déjà vus'**
  String get alreadyViewed;

  /// No description provided for @archived.
  ///
  /// In fr, this message translates to:
  /// **'Archivés'**
  String get archived;

  /// No description provided for @files.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers'**
  String get files;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @shareToConversation.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer via Alanya'**
  String get shareToConversation;

  /// No description provided for @sharedContentSent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu envoyé'**
  String get sharedContentSent;

  /// No description provided for @sharedContentSentTo.
  ///
  /// In fr, this message translates to:
  /// **'Contenu envoyé vers {count} discussions'**
  String sharedContentSentTo(int count);

  /// No description provided for @unableToShareTheContent.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'envoyer le contenu'**
  String get unableToShareTheContent;

  /// No description provided for @unableToShareTheMessage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de partager le message'**
  String get unableToShareTheMessage;

  /// No description provided for @thisMessageCannotBeSharedRight.
  ///
  /// In fr, this message translates to:
  /// **'Ce message ne peut pas être partagé pour le moment'**
  String get thisMessageCannotBeSharedRight;

  /// No description provided for @document.
  ///
  /// In fr, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @activity.
  ///
  /// In fr, this message translates to:
  /// **'Activité'**
  String get activity;

  /// No description provided for @album.
  ///
  /// In fr, this message translates to:
  /// **'📷 Album'**
  String get album;

  /// No description provided for @answered.
  ///
  /// In fr, this message translates to:
  /// **'Répondu'**
  String get answered;

  /// No description provided for @upcoming.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get upcoming;

  /// No description provided for @generate.
  ///
  /// In fr, this message translates to:
  /// **'Générer'**
  String get generate;

  /// No description provided for @audio.
  ///
  /// In fr, this message translates to:
  /// **'🎵 Audio'**
  String get audio;

  /// No description provided for @photo.
  ///
  /// In fr, this message translates to:
  /// **'📷 Photo'**
  String get photo;

  /// No description provided for @reply2.
  ///
  /// In fr, this message translates to:
  /// **'Réponse'**
  String get reply2;

  /// No description provided for @deliveredAt.
  ///
  /// In fr, this message translates to:
  /// **'Livré à'**
  String get deliveredAt;

  /// No description provided for @gallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get gallery;

  /// No description provided for @meeting.
  ///
  /// In fr, this message translates to:
  /// **'Réunion'**
  String get meeting;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Suivant'**
  String get next;

  /// No description provided for @dismiss.
  ///
  /// In fr, this message translates to:
  /// **'Ignorer'**
  String get dismiss;

  /// No description provided for @file2.
  ///
  /// In fr, this message translates to:
  /// **'Fichier'**
  String get file2;

  /// No description provided for @comingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt'**
  String get comingSoon;

  /// No description provided for @recent.
  ///
  /// In fr, this message translates to:
  /// **'Récents'**
  String get recent;

  /// No description provided for @label.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get label;

  /// No description provided for @invite.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get invite;

  /// No description provided for @ended2.
  ///
  /// In fr, this message translates to:
  /// **'Terminé'**
  String get ended2;

  /// No description provided for @video.
  ///
  /// In fr, this message translates to:
  /// **'🎥 Vidéo'**
  String get video;

  /// No description provided for @contact2.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get contact2;

  /// No description provided for @leave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get leave;

  /// No description provided for @favorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get favorites;

  /// No description provided for @gotIt2.
  ///
  /// In fr, this message translates to:
  /// **'Compris'**
  String get gotIt2;

  /// No description provided for @edited2.
  ///
  /// In fr, this message translates to:
  /// **'Modifié'**
  String get edited2;

  /// No description provided for @inactive.
  ///
  /// In fr, this message translates to:
  /// **'Inactif'**
  String get inactive;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @member.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get member;

  /// No description provided for @success.
  ///
  /// In fr, this message translates to:
  /// **'Succès'**
  String get success;

  /// No description provided for @ban.
  ///
  /// In fr, this message translates to:
  /// **'Bannir'**
  String get ban;

  /// No description provided for @past.
  ///
  /// In fr, this message translates to:
  /// **'Passés'**
  String get past;

  /// No description provided for @videos.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get videos;

  /// No description provided for @copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copy;

  /// No description provided for @camera.
  ///
  /// In fr, this message translates to:
  /// **'Caméra'**
  String get camera;

  /// No description provided for @photos.
  ///
  /// In fr, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @sending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get sending;

  /// No description provided for @blocked.
  ///
  /// In fr, this message translates to:
  /// **'Bloqué'**
  String get blocked;

  /// No description provided for @added.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté'**
  String get added;

  /// No description provided for @images.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @number.
  ///
  /// In fr, this message translates to:
  /// **'Numéro'**
  String get number;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @missed.
  ///
  /// In fr, this message translates to:
  /// **'Manqué'**
  String get missed;

  /// No description provided for @rejected.
  ///
  /// In fr, this message translates to:
  /// **'Rejeté'**
  String get rejected;

  /// No description provided for @links.
  ///
  /// In fr, this message translates to:
  /// **'Liens'**
  String get links;

  /// No description provided for @linkNoun.
  ///
  /// In fr, this message translates to:
  /// **'Lien'**
  String get linkNoun;

  /// No description provided for @timeZoneLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fuseau horaire'**
  String get timeZoneLabel;

  /// No description provided for @email.
  ///
  /// In fr, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get create;

  /// No description provided for @name.
  ///
  /// In fr, this message translates to:
  /// **'Nom *'**
  String get name;

  /// No description provided for @title.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get title;

  /// No description provided for @admin.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @audio2.
  ///
  /// In fr, this message translates to:
  /// **'Audio'**
  String get audio2;

  /// No description provided for @playbackSpeed.
  ///
  /// In fr, this message translates to:
  /// **'Vitesse de lecture'**
  String get playbackSpeed;

  /// No description provided for @playbackSpeedVoiceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Messages vocaux'**
  String get playbackSpeedVoiceLabel;

  /// No description provided for @playbackSpeedVideoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vidéos'**
  String get playbackSpeedVideoLabel;

  /// No description provided for @playbackSpeedMusicLabel.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get playbackSpeedMusicLabel;

  /// No description provided for @music.
  ///
  /// In fr, this message translates to:
  /// **'Musique'**
  String get music;

  /// No description provided for @musicPreview.
  ///
  /// In fr, this message translates to:
  /// **'🎵 {name}'**
  String musicPreview(String name);

  /// No description provided for @active.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get active;

  /// No description provided for @duration.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get duration;

  /// No description provided for @failure.
  ///
  /// In fr, this message translates to:
  /// **'Échec'**
  String get failure;

  /// No description provided for @photo2.
  ///
  /// In fr, this message translates to:
  /// **'Photo'**
  String get photo2;

  /// No description provided for @copied.
  ///
  /// In fr, this message translates to:
  /// **'Copié'**
  String get copied;

  /// No description provided for @video2.
  ///
  /// In fr, this message translates to:
  /// **'Vidéo'**
  String get video2;

  /// No description provided for @theme.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get theme;

  /// No description provided for @all.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get all;

  /// No description provided for @role.
  ///
  /// In fr, this message translates to:
  /// **'Rôle'**
  String get role;

  /// No description provided for @mute.
  ///
  /// In fr, this message translates to:
  /// **'Muet'**
  String get mute;

  /// No description provided for @readAt.
  ///
  /// In fr, this message translates to:
  /// **'Lu à'**
  String get readAt;

  /// No description provided for @more.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get more;

  /// No description provided for @country.
  ///
  /// In fr, this message translates to:
  /// **'Pays'**
  String get country;

  /// No description provided for @name2.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get name2;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @showLabel.
  ///
  /// In fr, this message translates to:
  /// **'Afficher'**
  String get showLabel;

  /// No description provided for @hideLabel.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get hideLabel;

  /// No description provided for @selectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} sélectionné(s)'**
  String selectedCount(int count);

  /// No description provided for @participantsAdded.
  ///
  /// In fr, this message translates to:
  /// **'{count} participant(s) ajouté(s)'**
  String participantsAdded(int count);

  /// No description provided for @participantsInvited.
  ///
  /// In fr, this message translates to:
  /// **'{count} participant(s) invité(s)'**
  String participantsInvited(int count);

  /// No description provided for @accepted.
  ///
  /// In fr, this message translates to:
  /// **'Accepté'**
  String get accepted;

  /// No description provided for @startAction.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer'**
  String get startAction;

  /// No description provided for @likeAction.
  ///
  /// In fr, this message translates to:
  /// **'J\'aime'**
  String get likeAction;

  /// No description provided for @incomingCallsChannel.
  ///
  /// In fr, this message translates to:
  /// **'Appels entrants'**
  String get incomingCallsChannel;

  /// No description provided for @ongoingCallsChannel.
  ///
  /// In fr, this message translates to:
  /// **'Appels en cours'**
  String get ongoingCallsChannel;

  /// No description provided for @viewsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vues'**
  String get viewsTitle;

  /// No description provided for @keypadTitle.
  ///
  /// In fr, this message translates to:
  /// **'Clavier'**
  String get keypadTitle;

  /// No description provided for @clearAction.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get clearAction;

  /// No description provided for @scheduleAction.
  ///
  /// In fr, this message translates to:
  /// **'Planifier'**
  String get scheduleAction;

  /// No description provided for @archiveAction.
  ///
  /// In fr, this message translates to:
  /// **'Archiver'**
  String get archiveAction;

  /// No description provided for @markAsRead.
  ///
  /// In fr, this message translates to:
  /// **'Marquer lu'**
  String get markAsRead;

  /// No description provided for @infoAction.
  ///
  /// In fr, this message translates to:
  /// **'Infos'**
  String get infoAction;

  /// No description provided for @cannotPlaceCallCheckInternet.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de passer un appel, vérifiez votre connexion à internet et réessayez.'**
  String get cannotPlaceCallCheckInternet;

  /// No description provided for @cannotPlaceCallServerFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de passer un appel, la connexion au serveur a échoué. Réessayez.'**
  String get cannotPlaceCallServerFailed;

  /// No description provided for @connectionRequired.
  ///
  /// In fr, this message translates to:
  /// **'Connexion requise'**
  String get connectionRequired;

  /// No description provided for @callImpossible.
  ///
  /// In fr, this message translates to:
  /// **'Appel impossible.'**
  String get callImpossible;

  /// No description provided for @errorAcceptingCall.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'acceptation de l\'appel'**
  String get errorAcceptingCall;

  /// No description provided for @userNotConnected.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur non connecté'**
  String get userNotConnected;

  /// No description provided for @mediaUnavailableForTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Média indisponible pour le transfert'**
  String get mediaUnavailableForTransfer;

  /// No description provided for @invalidPositionForTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Position invalide pour le transfert'**
  String get invalidPositionForTransfer;

  /// No description provided for @invalidContactForTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Contact invalide pour le transfert'**
  String get invalidContactForTransfer;

  /// No description provided for @photoViewOnce.
  ///
  /// In fr, this message translates to:
  /// **'📷 Photo · Vue unique'**
  String get photoViewOnce;

  /// No description provided for @videoViewOnce.
  ///
  /// In fr, this message translates to:
  /// **'🎥 Vidéo · Vue unique'**
  String get videoViewOnce;

  /// No description provided for @videoCallPreview.
  ///
  /// In fr, this message translates to:
  /// **'📹 Appel vidéo'**
  String get videoCallPreview;

  /// No description provided for @voiceCallPreview.
  ///
  /// In fr, this message translates to:
  /// **'📞 Appel vocal'**
  String get voiceCallPreview;

  /// No description provided for @anErrorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue: {error}'**
  String anErrorOccurred(String error);

  /// No description provided for @errorColon.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String errorColon(String error);

  /// No description provided for @deletePhotoAction.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la photo'**
  String get deletePhotoAction;

  /// No description provided for @unavailableOffline.
  ///
  /// In fr, this message translates to:
  /// **'Indisponible hors ligne'**
  String get unavailableOffline;

  /// No description provided for @noParticipantsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun participant pour le moment'**
  String get noParticipantsYet;

  /// No description provided for @noMessagesYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun message pour le moment'**
  String get noMessagesYet;

  /// No description provided for @removeParticipantToAddAnother.
  ///
  /// In fr, this message translates to:
  /// **'Retirez un participant pour en ajouter un autre.'**
  String get removeParticipantToAddAnother;

  /// No description provided for @noContactsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact pour le moment'**
  String get noContactsYet;

  /// No description provided for @voiceMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message vocal'**
  String get voiceMessage;

  /// No description provided for @paused.
  ///
  /// In fr, this message translates to:
  /// **'En pause'**
  String get paused;

  /// No description provided for @recordOrImportAudio.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrez un vocal ou importez un fichier audio'**
  String get recordOrImportAudio;

  /// No description provided for @unableToPostStatusWithError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de publier le statut : {error}'**
  String unableToPostStatusWithError(String error);

  /// No description provided for @tapToAddYourStatus.
  ///
  /// In fr, this message translates to:
  /// **'Appuyer pour ajouter votre statut'**
  String get tapToAddYourStatus;

  /// No description provided for @shareAContact.
  ///
  /// In fr, this message translates to:
  /// **'Partager un contact'**
  String get shareAContact;

  /// No description provided for @searchAContact.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un contact'**
  String get searchAContact;

  /// No description provided for @unmuteMic.
  ///
  /// In fr, this message translates to:
  /// **'Activer le micro'**
  String get unmuteMic;

  /// No description provided for @muteMic.
  ///
  /// In fr, this message translates to:
  /// **'Couper le micro'**
  String get muteMic;

  /// No description provided for @turnOnSpeaker.
  ///
  /// In fr, this message translates to:
  /// **'Activer le haut-parleur'**
  String get turnOnSpeaker;

  /// No description provided for @notAuthenticated.
  ///
  /// In fr, this message translates to:
  /// **'Non authentifié'**
  String get notAuthenticated;

  /// No description provided for @networkTimeout.
  ///
  /// In fr, this message translates to:
  /// **'Timeout réseau'**
  String get networkTimeout;

  /// No description provided for @networkErrorWithDetails.
  ///
  /// In fr, this message translates to:
  /// **'Erreur réseau: {error}'**
  String networkErrorWithDetails(String error);

  /// No description provided for @invalidResponseWithCode.
  ///
  /// In fr, this message translates to:
  /// **'Réponse invalide ({code})'**
  String invalidResponseWithCode(Object code);

  /// No description provided for @noRefreshToken.
  ///
  /// In fr, this message translates to:
  /// **'Pas de refresh token'**
  String get noRefreshToken;

  /// No description provided for @refreshFailed.
  ///
  /// In fr, this message translates to:
  /// **'Refresh échoué'**
  String get refreshFailed;

  /// No description provided for @addedToPreferredContacts.
  ///
  /// In fr, this message translates to:
  /// **'{name} ajouté aux contacts préférés'**
  String addedToPreferredContacts(String name);

  /// No description provided for @approximateGpsSlow.
  ///
  /// In fr, this message translates to:
  /// **'Position approximative (GPS lent).'**
  String get approximateGpsSlow;

  /// No description provided for @notYetRead.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore lu'**
  String get notYetRead;

  /// No description provided for @sentOnTapSend.
  ///
  /// In fr, this message translates to:
  /// **'Appui sur envoyer'**
  String get sentOnTapSend;

  /// No description provided for @maxPhotos.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} photos.'**
  String maxPhotos(int count);

  /// No description provided for @maxFiles.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} fichiers.'**
  String maxFiles(int count);

  /// No description provided for @filesSkippedTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'{count} fichier(s) ignoré(s) : limite 50 Mo.'**
  String filesSkippedTooLarge(int count);

  /// No description provided for @maxMedias.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} médias.'**
  String maxMedias(int count);

  /// No description provided for @addMore.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get addMore;

  /// No description provided for @removeMedia.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get removeMedia;

  /// No description provided for @voiceViewOnce.
  ///
  /// In fr, this message translates to:
  /// **'Vocal · vue unique'**
  String get voiceViewOnce;

  /// No description provided for @heCanContactYouAgain.
  ///
  /// In fr, this message translates to:
  /// **'Il pourra de nouveau vous contacter.'**
  String get heCanContactYouAgain;

  /// No description provided for @unableToLoadNamed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger {name}'**
  String unableToLoadNamed(String name);

  /// No description provided for @contactNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Contact introuvable'**
  String get contactNotFound;

  /// No description provided for @yesterday.
  ///
  /// In fr, this message translates to:
  /// **'Hier'**
  String get yesterday;

  /// No description provided for @today.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In fr, this message translates to:
  /// **'Demain'**
  String get tomorrow;

  /// No description provided for @nowLabel.
  ///
  /// In fr, this message translates to:
  /// **'Maintenant'**
  String get nowLabel;

  /// No description provided for @positionUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Position indisponible'**
  String get positionUnavailable;

  /// No description provided for @contactUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Contact indisponible'**
  String get contactUnavailable;

  /// No description provided for @tapToViewKind.
  ///
  /// In fr, this message translates to:
  /// **'{kind} · Appuyer pour voir'**
  String tapToViewKind(String kind);

  /// No description provided for @kindViewOnce.
  ///
  /// In fr, this message translates to:
  /// **'{kind} · Vue unique'**
  String kindViewOnce(String kind);

  /// No description provided for @viewOnceOpened.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get viewOnceOpened;

  /// No description provided for @viewOnceDownloadKind.
  ///
  /// In fr, this message translates to:
  /// **'{kind} · Télécharger'**
  String viewOnceDownloadKind(String kind);

  /// No description provided for @viewOnceDownloading.
  ///
  /// In fr, this message translates to:
  /// **'Téléchargement…'**
  String get viewOnceDownloading;

  /// No description provided for @viewOnceRetry.
  ///
  /// In fr, this message translates to:
  /// **'Échec — Réessayer'**
  String get viewOnceRetry;

  /// No description provided for @recordingEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement…'**
  String get recordingEllipsis;

  /// No description provided for @unread.
  ///
  /// In fr, this message translates to:
  /// **'Non lus'**
  String get unread;

  /// No description provided for @addAContact.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un contact'**
  String get addAContact;

  /// No description provided for @meetingNamed.
  ///
  /// In fr, this message translates to:
  /// **'Réunion {when}'**
  String meetingNamed(String when);

  /// No description provided for @dataUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'données indisponibles'**
  String get dataUnavailable;

  /// No description provided for @sendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get sendCode;

  /// No description provided for @unableToLoadCountryList.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger la liste des pays'**
  String get unableToLoadCountryList;

  /// No description provided for @maxAudioParticipantsHint.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {count} participants (appel audio). '**
  String maxAudioParticipantsHint(int count);

  /// No description provided for @membersOnlyCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} membres'**
  String membersOnlyCount(int count);

  /// No description provided for @sendWithCount.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer ({count})'**
  String sendWithCount(int count);

  /// No description provided for @messagesCountLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} messages'**
  String messagesCountLabel(int count);

  /// No description provided for @messagesCountLabelOne.
  ///
  /// In fr, this message translates to:
  /// **'{count} message'**
  String messagesCountLabelOne(int count);

  /// No description provided for @deliveredAtTime.
  ///
  /// In fr, this message translates to:
  /// **'Livré à {time}'**
  String deliveredAtTime(String time);

  /// No description provided for @readAtTime.
  ///
  /// In fr, this message translates to:
  /// **'Lu à {time}'**
  String readAtTime(String time);

  /// No description provided for @durationTapToReturn.
  ///
  /// In fr, this message translates to:
  /// **'{duration} · Toucher pour revenir'**
  String durationTapToReturn(String duration);

  /// No description provided for @sessionBannerTapToReturn.
  ///
  /// In fr, this message translates to:
  /// **'{duration} · {type} · Toucher pour revenir'**
  String sessionBannerTapToReturn(String duration, String type);

  /// No description provided for @usedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Utilisé'**
  String get usedLabel;

  /// No description provided for @banUnbanError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur ban/unban: {error}'**
  String banUnbanError(String error);

  /// No description provided for @deleteErrorWithDetails.
  ///
  /// In fr, this message translates to:
  /// **'Erreur suppression: {error}'**
  String deleteErrorWithDetails(String error);

  /// No description provided for @loadUsersError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur chargement utilisateurs: {error}'**
  String loadUsersError(String error);

  /// No description provided for @limitReachedParticipants.
  ///
  /// In fr, this message translates to:
  /// **'Maximum {total} participants en {media} (vous inclus)'**
  String limitReachedParticipants(int total, String media);

  /// No description provided for @mediaLabelVideo.
  ///
  /// In fr, this message translates to:
  /// **'vidéo'**
  String get mediaLabelVideo;

  /// No description provided for @mediaLabelAudio.
  ///
  /// In fr, this message translates to:
  /// **'audio'**
  String get mediaLabelAudio;

  /// No description provided for @activeStatusesTapToView.
  ///
  /// In fr, this message translates to:
  /// **'{count} statut(s) actif(s) — appuyer pour voir'**
  String activeStatusesTapToView(int count);

  /// No description provided for @viewsCountLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} vue(s)'**
  String viewsCountLabel(int count);

  /// No description provided for @dateAtTime.
  ///
  /// In fr, this message translates to:
  /// **'{date} à {time}'**
  String dateAtTime(String date, String time);

  /// No description provided for @selectedFeminineCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} sélectionnée(s)'**
  String selectedFeminineCount(int count);

  /// No description provided for @selectionRatio.
  ///
  /// In fr, this message translates to:
  /// **'{count}/{max} sélectionné(s)'**
  String selectionRatio(int count, int max);

  /// No description provided for @groupFallback.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get groupFallback;

  /// No description provided for @reservedPhoneSearchHelp.
  ///
  /// In fr, this message translates to:
  /// **'Recherchez dans la liste admin ou saisissez un pattern complet (3 ch., 4 ch., ou 8 ch. XXYYZZTT). Les patterns peuvent être attribués directement sans être ajoutés à la liste.'**
  String get reservedPhoneSearchHelp;

  /// No description provided for @reservedPhoneOnlyHint.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement 3 ou 4 chiffres, ou 8 chiffres XXYYZZTT (ex. 11 22 33 44). Ces formes sont exclus de l\'inscription automatique.'**
  String get reservedPhoneOnlyHint;

  /// No description provided for @messagesSummaryMulti.
  ///
  /// In fr, this message translates to:
  /// **'{totalMessages} messages · {convCount} conversations'**
  String messagesSummaryMulti(int totalMessages, int convCount);

  /// No description provided for @messagesSummaryOne.
  ///
  /// In fr, this message translates to:
  /// **'{count} nouveau message'**
  String messagesSummaryOne(int count);

  /// No description provided for @messagesSummaryMany.
  ///
  /// In fr, this message translates to:
  /// **'{count} nouveaux messages'**
  String messagesSummaryMany(int count);

  /// No description provided for @dateAtTimeFull.
  ///
  /// In fr, this message translates to:
  /// **'{day}/{month}/{year} à {time}'**
  String dateAtTimeFull(int day, int month, int year, String time);

  /// No description provided for @todayTimeShort.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui {time}'**
  String todayTimeShort(String time);

  /// No description provided for @sourceFileNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Fichier source introuvable : {path}'**
  String sourceFileNotFound(String path);

  /// No description provided for @copyImpossible.
  ///
  /// In fr, this message translates to:
  /// **'Copie impossible : {error}'**
  String copyImpossible(String error);

  /// No description provided for @copyFailedPath.
  ///
  /// In fr, this message translates to:
  /// **'Copie échouée : {path}'**
  String copyFailedPath(String path);

  /// No description provided for @albumCannotBeForwarded.
  ///
  /// In fr, this message translates to:
  /// **'Cet album ne peut pas être transféré'**
  String get albumCannotBeForwarded;

  /// No description provided for @userHashId.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur #{id}'**
  String userHashId(Object id);

  /// No description provided for @listWithCount.
  ///
  /// In fr, this message translates to:
  /// **'Liste ({count})'**
  String listWithCount(int count);

  /// No description provided for @listLabel.
  ///
  /// In fr, this message translates to:
  /// **'Liste'**
  String get listLabel;

  /// No description provided for @filterLabel.
  ///
  /// In fr, this message translates to:
  /// **'Filtre'**
  String get filterLabel;

  /// No description provided for @freePlural.
  ///
  /// In fr, this message translates to:
  /// **'Libres'**
  String get freePlural;

  /// No description provided for @assignAction.
  ///
  /// In fr, this message translates to:
  /// **'Attribuer'**
  String get assignAction;

  /// No description provided for @messagesChannelName.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get messagesChannelName;

  /// No description provided for @searchEllipsis.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get searchEllipsis;

  /// No description provided for @callNoun.
  ///
  /// In fr, this message translates to:
  /// **'Appel'**
  String get callNoun;

  /// No description provided for @allFilter.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get allFilter;

  /// No description provided for @audioViewOnce.
  ///
  /// In fr, this message translates to:
  /// **'🎵 Audio · Vue unique'**
  String get audioViewOnce;

  /// No description provided for @mediaFallback.
  ///
  /// In fr, this message translates to:
  /// **'Média'**
  String get mediaFallback;

  /// No description provided for @fileWithName.
  ///
  /// In fr, this message translates to:
  /// **'📎 {name}'**
  String fileWithName(String name);

  /// No description provided for @groupsFilter.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groupsFilter;

  /// No description provided for @participantsSelected.
  ///
  /// In fr, this message translates to:
  /// **'{count} participant(s) sélectionné(s)'**
  String participantsSelected(int count);

  /// No description provided for @waitingForParticipants.
  ///
  /// In fr, this message translates to:
  /// **'En attente des participants…'**
  String get waitingForParticipants;

  /// No description provided for @participantsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count} participants'**
  String participantsCount(int count);

  /// No description provided for @durationParticipants.
  ///
  /// In fr, this message translates to:
  /// **'{duration} · {count} participants'**
  String durationParticipants(String duration, int count);

  /// No description provided for @participantsRatio.
  ///
  /// In fr, this message translates to:
  /// **'Participants ({current}/{max})'**
  String participantsRatio(int current, int max);

  /// No description provided for @confirmWithParticipants.
  ///
  /// In fr, this message translates to:
  /// **'{label} · {count} participant(s)'**
  String confirmWithParticipants(String label, int count);

  /// No description provided for @dotParticipantsCount.
  ///
  /// In fr, this message translates to:
  /// **'· {count} participant(s)'**
  String dotParticipantsCount(int count);

  /// No description provided for @text2.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get text2;

  /// No description provided for @publishAction.
  ///
  /// In fr, this message translates to:
  /// **'Publier'**
  String get publishAction;

  /// No description provided for @importAction.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get importAction;

  /// No description provided for @finishAction.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get finishAction;

  /// No description provided for @recordAction.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get recordAction;

  /// No description provided for @meLabel.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get meLabel;

  /// Titre d'une conversation avec soi-même
  ///
  /// In fr, this message translates to:
  /// **'{name} (Moi)'**
  String selfChatTitle(String name);

  /// No description provided for @messageYourself.
  ///
  /// In fr, this message translates to:
  /// **'M\'envoyer un message'**
  String get messageYourself;

  /// No description provided for @selfChatSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Notes, rappels, fichiers'**
  String get selfChatSubtitle;

  /// No description provided for @selfChatDeleteWarning.
  ///
  /// In fr, this message translates to:
  /// **'Toutes vos notes seront définitivement supprimées. Cette action est irréversible.'**
  String get selfChatDeleteWarning;

  /// No description provided for @cannotCallYourself.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne pouvez pas vous appeler vous-même'**
  String get cannotCallYourself;

  /// No description provided for @statusNoun.
  ///
  /// In fr, this message translates to:
  /// **'Statut'**
  String get statusNoun;

  /// No description provided for @youLabel.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get youLabel;

  /// No description provided for @hostLabel.
  ///
  /// In fr, this message translates to:
  /// **'Hôte'**
  String get hostLabel;

  /// No description provided for @guestLabel.
  ///
  /// In fr, this message translates to:
  /// **'Invité'**
  String get guestLabel;

  /// No description provided for @chatLabel.
  ///
  /// In fr, this message translates to:
  /// **'Chat'**
  String get chatLabel;

  /// No description provided for @summaryLabel.
  ///
  /// In fr, this message translates to:
  /// **'Résumé'**
  String get summaryLabel;

  /// No description provided for @typeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @accountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get accountLabel;

  /// No description provided for @adminDashboard.
  ///
  /// In fr, this message translates to:
  /// **'Tableau de bord Admin'**
  String get adminDashboard;

  /// No description provided for @superAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Super Admin'**
  String get superAdmin;

  /// No description provided for @inMinutes.
  ///
  /// In fr, this message translates to:
  /// **'Dans {mins}min'**
  String inMinutes(int mins);

  /// No description provided for @participantFallback.
  ///
  /// In fr, this message translates to:
  /// **'Participant'**
  String get participantFallback;

  /// No description provided for @userFallback.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur'**
  String get userFallback;

  /// No description provided for @nameYouParen.
  ///
  /// In fr, this message translates to:
  /// **'{name} (vous)'**
  String nameYouParen(String name);

  /// No description provided for @contactsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Contacts'**
  String get contactsLabel;

  /// No description provided for @searchUserByNameOrUsername.
  ///
  /// In fr, this message translates to:
  /// **'Recherchez un utilisateur par nom ou pseudo'**
  String get searchUserByNameOrUsername;

  /// No description provided for @endMeetingAction.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get endMeetingAction;

  /// No description provided for @hoursShort.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h'**
  String hoursShort(int hours);

  /// No description provided for @hoursAndMinutesShort.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes}'**
  String hoursAndMinutesShort(int hours, int minutes);

  /// No description provided for @formatBold.
  ///
  /// In fr, this message translates to:
  /// **'Gras'**
  String get formatBold;

  /// No description provided for @formatItalic.
  ///
  /// In fr, this message translates to:
  /// **'Italique'**
  String get formatItalic;

  /// No description provided for @formatUnderline.
  ///
  /// In fr, this message translates to:
  /// **'Souligné'**
  String get formatUnderline;

  /// No description provided for @formatStrikethrough.
  ///
  /// In fr, this message translates to:
  /// **'Barré'**
  String get formatStrikethrough;

  /// No description provided for @formatHandwriting.
  ///
  /// In fr, this message translates to:
  /// **'Manuscrit'**
  String get formatHandwriting;

  /// No description provided for @genderMale.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get genderFemale;

  /// No description provided for @avatarLabel.
  ///
  /// In fr, this message translates to:
  /// **'Avatar'**
  String get avatarLabel;

  /// No description provided for @nameUsernamePasswordRequired.
  ///
  /// In fr, this message translates to:
  /// **'Nom, pseudo et mot de passe requis'**
  String get nameUsernamePasswordRequired;

  /// No description provided for @usersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateurs'**
  String get usersLabel;

  /// No description provided for @bannedUsers.
  ///
  /// In fr, this message translates to:
  /// **'Bannis'**
  String get bannedUsers;

  /// No description provided for @bannedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Banni'**
  String get bannedLabel;

  /// No description provided for @adminsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Admins'**
  String get adminsLabel;

  /// No description provided for @actionsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Actions'**
  String get actionsLabel;

  /// No description provided for @conversationsLabel.
  ///
  /// In fr, this message translates to:
  /// **'Conversations'**
  String get conversationsLabel;

  /// No description provided for @totalLabel.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @commonBlock.
  ///
  /// In fr, this message translates to:
  /// **'Bloquer'**
  String get commonBlock;

  /// No description provided for @messageNoun.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get messageNoun;

  /// No description provided for @albumNoun.
  ///
  /// In fr, this message translates to:
  /// **'Album'**
  String get albumNoun;

  /// No description provided for @favoriteSingular.
  ///
  /// In fr, this message translates to:
  /// **'Favori'**
  String get favoriteSingular;

  /// No description provided for @hangUp.
  ///
  /// In fr, this message translates to:
  /// **'Raccrocher'**
  String get hangUp;

  /// No description provided for @viewAction.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get viewAction;

  /// No description provided for @invitationFrom.
  ///
  /// In fr, this message translates to:
  /// **'Invitation de {name}'**
  String invitationFrom(String name);

  /// No description provided for @fileArchive.
  ///
  /// In fr, this message translates to:
  /// **'Archive'**
  String get fileArchive;

  /// No description provided for @reservationLimitedTo3Or4OrXxyyzztt.
  ///
  /// In fr, this message translates to:
  /// **'Réservation limitée aux numéros 3 ou 4 chiffres, ou 8 chiffres au format XXYYZZTT (ex. 11 22 33 44)'**
  String get reservationLimitedTo3Or4OrXxyyzztt;

  /// No description provided for @discussionFallback.
  ///
  /// In fr, this message translates to:
  /// **'Discussion'**
  String get discussionFallback;

  /// No description provided for @overviewSection.
  ///
  /// In fr, this message translates to:
  /// **'Vue d\'ensemble'**
  String get overviewSection;

  /// No description provided for @rangeOfTotal.
  ///
  /// In fr, this message translates to:
  /// **'{from}–{to} sur {total}'**
  String rangeOfTotal(int from, int to, int total);

  /// No description provided for @tryAnotherName.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre nom.'**
  String get tryAnotherName;

  /// No description provided for @tryAnotherSearchTerm.
  ///
  /// In fr, this message translates to:
  /// **'Essayez un autre terme de recherche.'**
  String get tryAnotherSearchTerm;

  /// No description provided for @andNOthers.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{… et 1 autre} other{… et {count} autres}}'**
  String andNOthers(int count);

  /// No description provided for @voiceCallOutgoing.
  ///
  /// In fr, this message translates to:
  /// **'Appel vocal sortant'**
  String get voiceCallOutgoing;

  /// No description provided for @voiceCallIncoming.
  ///
  /// In fr, this message translates to:
  /// **'Appel vocal entrant'**
  String get voiceCallIncoming;

  /// No description provided for @videoCallOutgoing.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo sortant'**
  String get videoCallOutgoing;

  /// No description provided for @videoCallIncoming.
  ///
  /// In fr, this message translates to:
  /// **'Appel vidéo entrant'**
  String get videoCallIncoming;

  /// No description provided for @reactionChipLabel.
  ///
  /// In fr, this message translates to:
  /// **'{emoji}, {count, plural, =1{1 réaction} other{{count} réactions}}'**
  String reactionChipLabel(String emoji, int count);

  /// No description provided for @reactToMessage.
  ///
  /// In fr, this message translates to:
  /// **'Réagir'**
  String get reactToMessage;

  /// No description provided for @moreReactions.
  ///
  /// In fr, this message translates to:
  /// **'Plus de réactions'**
  String get moreReactions;

  /// No description provided for @settingsNotifications.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Messages, appels, confidentialité'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @notifPrefsSectionAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get notifPrefsSectionAlerts;

  /// No description provided for @notifPrefsSectionBehavior.
  ///
  /// In fr, this message translates to:
  /// **'Comportement'**
  String get notifPrefsSectionBehavior;

  /// No description provided for @notifPrefMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages privés'**
  String get notifPrefMessages;

  /// No description provided for @notifPrefGroupMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages de groupe'**
  String get notifPrefGroupMessages;

  /// No description provided for @notifPrefCalls.
  ///
  /// In fr, this message translates to:
  /// **'Appels'**
  String get notifPrefCalls;

  /// No description provided for @notifPrefMeetings.
  ///
  /// In fr, this message translates to:
  /// **'Réunions'**
  String get notifPrefMeetings;

  /// No description provided for @notifPrefStatusView.
  ///
  /// In fr, this message translates to:
  /// **'Vues de statut'**
  String get notifPrefStatusView;

  /// No description provided for @notifPrefBroadcasts.
  ///
  /// In fr, this message translates to:
  /// **'Annonces Alanya'**
  String get notifPrefBroadcasts;

  /// No description provided for @notifPrefSound.
  ///
  /// In fr, this message translates to:
  /// **'Son'**
  String get notifPrefSound;

  /// No description provided for @notifPrefVibration.
  ///
  /// In fr, this message translates to:
  /// **'Vibration'**
  String get notifPrefVibration;

  /// No description provided for @notifPrefPreviewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu sur l\'écran verrouillé'**
  String get notifPrefPreviewTitle;

  /// No description provided for @notifPrefPreviewFull.
  ///
  /// In fr, this message translates to:
  /// **'Nom + contenu'**
  String get notifPrefPreviewFull;

  /// No description provided for @notifPrefPreviewNameOnly.
  ///
  /// In fr, this message translates to:
  /// **'Nom seulement'**
  String get notifPrefPreviewNameOnly;

  /// No description provided for @notifPrefPreviewGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Générique'**
  String get notifPrefPreviewGeneric;

  /// No description provided for @notifPrefsSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer les préférences'**
  String get notifPrefsSaveFailed;

  /// No description provided for @convMuteAction.
  ///
  /// In fr, this message translates to:
  /// **'Notifications'**
  String get convMuteAction;

  /// No description provided for @convMuteSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Couper les alertes pour cette conversation'**
  String get convMuteSubtitle;

  /// No description provided for @convMuteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Notifications — {name}'**
  String convMuteTitle(String name);

  /// No description provided for @convMute8h.
  ///
  /// In fr, this message translates to:
  /// **'Couper 8 heures'**
  String get convMute8h;

  /// No description provided for @convMute1w.
  ///
  /// In fr, this message translates to:
  /// **'Couper 1 semaine'**
  String get convMute1w;

  /// No description provided for @convMuteForever.
  ///
  /// In fr, this message translates to:
  /// **'Toujours couper'**
  String get convMuteForever;

  /// No description provided for @convUnmute.
  ///
  /// In fr, this message translates to:
  /// **'Réactiver les notifications'**
  String get convUnmute;

  /// No description provided for @convMuteDone.
  ///
  /// In fr, this message translates to:
  /// **'Notifications coupées pour {name}'**
  String convMuteDone(String name);

  /// No description provided for @convUnmuteDone.
  ///
  /// In fr, this message translates to:
  /// **'Notifications réactivées pour {name}'**
  String convUnmuteDone(String name);

  /// No description provided for @convMuteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier le mute'**
  String get convMuteFailed;

  /// No description provided for @sysGroupCreated.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a créé le groupe « {value} »'**
  String sysGroupCreated(String actor, String value);

  /// No description provided for @sysGroupCreatedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez créé le groupe « {value} »'**
  String sysGroupCreatedByMe(String value);

  /// No description provided for @sysMemberAdded.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a ajouté {targets}'**
  String sysMemberAdded(String actor, String targets);

  /// No description provided for @sysMemberAddedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez ajouté {targets}'**
  String sysMemberAddedByMe(String targets);

  /// No description provided for @sysMemberRemoved.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a retiré {targets}'**
  String sysMemberRemoved(String actor, String targets);

  /// No description provided for @sysMemberRemovedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez retiré {targets}'**
  String sysMemberRemovedByMe(String targets);

  /// No description provided for @sysMemberLeft.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a quitté le groupe'**
  String sysMemberLeft(String actor);

  /// No description provided for @sysMemberLeftByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le groupe'**
  String get sysMemberLeftByMe;

  /// No description provided for @sysGroupRenamed.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a renommé le groupe en « {value} »'**
  String sysGroupRenamed(String actor, String value);

  /// No description provided for @sysGroupRenamedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez renommé le groupe en « {value} »'**
  String sysGroupRenamedByMe(String value);

  /// No description provided for @sysGroupPhotoChanged.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a changé la photo du groupe'**
  String sysGroupPhotoChanged(String actor);

  /// No description provided for @sysGroupPhotoChangedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez changé la photo du groupe'**
  String get sysGroupPhotoChangedByMe;

  /// No description provided for @sysGroupDescriptionChanged.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a modifié la description'**
  String sysGroupDescriptionChanged(String actor);

  /// No description provided for @sysGroupDescriptionChangedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez modifié la description'**
  String get sysGroupDescriptionChangedByMe;

  /// No description provided for @sysRolePromoted.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a nommé {targets} administrateur'**
  String sysRolePromoted(String actor, String targets);

  /// No description provided for @sysRolePromotedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez nommé {targets} administrateur'**
  String sysRolePromotedByMe(String targets);

  /// No description provided for @sysRoleDemoted.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a retiré les droits d\'administrateur à {targets}'**
  String sysRoleDemoted(String actor, String targets);

  /// No description provided for @sysRoleDemotedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez retiré les droits d\'administrateur à {targets}'**
  String sysRoleDemotedByMe(String targets);

  /// No description provided for @sysOnlyAdminsSendOn.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a réservé l\'envoi aux administrateurs'**
  String sysOnlyAdminsSendOn(String actor);

  /// No description provided for @sysOnlyAdminsSendOnByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez réservé l\'envoi aux administrateurs'**
  String get sysOnlyAdminsSendOnByMe;

  /// No description provided for @sysOnlyAdminsSendOff.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a autorisé tout le monde à écrire'**
  String sysOnlyAdminsSendOff(String actor);

  /// No description provided for @sysOnlyAdminsSendOffByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez autorisé tout le monde à écrire'**
  String get sysOnlyAdminsSendOffByMe;

  /// No description provided for @sysOnlyAdminsEditOn.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a réservé la modification des infos aux administrateurs'**
  String sysOnlyAdminsEditOn(String actor);

  /// No description provided for @sysOnlyAdminsEditOnByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez réservé la modification des infos aux administrateurs'**
  String get sysOnlyAdminsEditOnByMe;

  /// No description provided for @sysOnlyAdminsEditOff.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a autorisé tout le monde à modifier les infos'**
  String sysOnlyAdminsEditOff(String actor);

  /// No description provided for @sysOnlyAdminsEditOffByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez autorisé tout le monde à modifier les infos'**
  String get sysOnlyAdminsEditOffByMe;

  /// No description provided for @sysGroupEventFallback.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe a été mis à jour'**
  String get sysGroupEventFallback;

  /// No description provided for @sysPreviewGroupCreated.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a créé « {value} »'**
  String sysPreviewGroupCreated(String actor, String value);

  /// No description provided for @sysPreviewGroupCreatedShort.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a créé le groupe'**
  String sysPreviewGroupCreatedShort(String actor);

  /// No description provided for @sysPreviewMemberAdded.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a ajouté des membres'**
  String sysPreviewMemberAdded(String actor);

  /// No description provided for @sysPreviewMemberRemoved.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a retiré un membre'**
  String sysPreviewMemberRemoved(String actor);

  /// No description provided for @sysPreviewMemberLeft.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a quitté le groupe'**
  String sysPreviewMemberLeft(String actor);

  /// No description provided for @sysPreviewGroupRenamed.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a renommé le groupe'**
  String sysPreviewGroupRenamed(String actor);

  /// No description provided for @sysPreviewGroupPhotoChanged.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a changé la photo du groupe'**
  String sysPreviewGroupPhotoChanged(String actor);

  /// No description provided for @sysPreviewGroupDescriptionChanged.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a modifié la description'**
  String sysPreviewGroupDescriptionChanged(String actor);

  /// No description provided for @sysPreviewRolePromoted.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a nommé un administrateur'**
  String sysPreviewRolePromoted(String actor);

  /// No description provided for @sysPreviewRoleDemoted.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a retiré des droits d\'administrateur'**
  String sysPreviewRoleDemoted(String actor);

  /// No description provided for @sysPreviewSettingsChanged.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a modifié les réglages du groupe'**
  String sysPreviewSettingsChanged(String actor);

  /// No description provided for @groupOwner.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaire'**
  String get groupOwner;

  /// No description provided for @groupAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get groupAdmin;

  /// No description provided for @removeFromGroup.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du groupe'**
  String get removeFromGroup;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} du groupe ?'**
  String removeMemberConfirm(String name);

  /// No description provided for @removeMemberDone.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été retiré du groupe'**
  String removeMemberDone(String name);

  /// No description provided for @dismissAdmin.
  ///
  /// In fr, this message translates to:
  /// **'Retirer les droits d\'administrateur'**
  String get dismissAdmin;

  /// No description provided for @viewProfile.
  ///
  /// In fr, this message translates to:
  /// **'Voir le profil'**
  String get viewProfile;

  /// No description provided for @groupDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get groupDescription;

  /// No description provided for @groupDescriptionHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une description…'**
  String get groupDescriptionHint;

  /// No description provided for @noGroupDescription.
  ///
  /// In fr, this message translates to:
  /// **'Aucune description'**
  String get noGroupDescription;

  /// No description provided for @renameGroup.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le groupe'**
  String get renameGroup;

  /// No description provided for @changeGroupPhoto.
  ///
  /// In fr, this message translates to:
  /// **'Changer la photo'**
  String get changeGroupPhoto;

  /// No description provided for @groupSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages du groupe'**
  String get groupSettings;

  /// No description provided for @onlyAdminsCanSendLabel.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les admins peuvent écrire'**
  String get onlyAdminsCanSendLabel;

  /// No description provided for @onlyAdminsCanSendSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe devient un canal d\'annonces'**
  String get onlyAdminsCanSendSubtitle;

  /// No description provided for @onlyAdminsCanEditInfoLabel.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les admins modifient les infos'**
  String get onlyAdminsCanEditInfoLabel;

  /// No description provided for @onlyAdminsCanEditInfoSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nom, photo et description'**
  String get onlyAdminsCanEditInfoSubtitle;

  /// No description provided for @hideHistoryForNewMembersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Masquer l\'historique pour les nouveaux'**
  String get hideHistoryForNewMembersLabel;

  /// No description provided for @hideHistoryForNewMembersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Les membres ajoutés ne verront pas les messages antérieurs'**
  String get hideHistoryForNewMembersSubtitle;

  /// No description provided for @onlyAdminsCanAddMembersLabel.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les admins peuvent ajouter des membres'**
  String get onlyAdminsCanAddMembersLabel;

  /// No description provided for @onlyAdminsCanAddMembersSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Inviter de nouveaux participants au groupe'**
  String get onlyAdminsCanAddMembersSubtitle;

  /// No description provided for @groupJoinBannerBody.
  ///
  /// In fr, this message translates to:
  /// **'{actor} vous a ajouté au groupe « {group} »'**
  String groupJoinBannerBody(String actor, String group);

  /// No description provided for @stay.
  ///
  /// In fr, this message translates to:
  /// **'Rester'**
  String get stay;

  /// No description provided for @sysHideHistoryOn.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a masqué l\'historique pour les nouveaux membres'**
  String sysHideHistoryOn(String actor);

  /// No description provided for @sysHideHistoryOnByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez masqué l\'historique pour les nouveaux membres'**
  String get sysHideHistoryOnByMe;

  /// No description provided for @sysHideHistoryOff.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a rendu l\'historique visible pour les nouveaux membres'**
  String sysHideHistoryOff(String actor);

  /// No description provided for @sysHideHistoryOffByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez rendu l\'historique visible pour les nouveaux membres'**
  String get sysHideHistoryOffByMe;

  /// No description provided for @sysOnlyAdminsAddOn.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a réservé l\'ajout de membres aux administrateurs'**
  String sysOnlyAdminsAddOn(String actor);

  /// No description provided for @sysOnlyAdminsAddOnByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez réservé l\'ajout de membres aux administrateurs'**
  String get sysOnlyAdminsAddOnByMe;

  /// No description provided for @sysOnlyAdminsAddOff.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a autorisé tout le monde à ajouter des membres'**
  String sysOnlyAdminsAddOff(String actor);

  /// No description provided for @sysOnlyAdminsAddOffByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez autorisé tout le monde à ajouter des membres'**
  String get sysOnlyAdminsAddOffByMe;

  /// No description provided for @mentionsOnlyLabel.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement les mentions'**
  String get mentionsOnlyLabel;

  /// No description provided for @mentionsOnlySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'N\'être alerté que si l\'on vous mentionne'**
  String get mentionsOnlySubtitle;

  /// No description provided for @youWereRemovedFromGroup.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne faites plus partie de ce groupe'**
  String get youWereRemovedFromGroup;

  /// No description provided for @notAllowedGroupAction.
  ///
  /// In fr, this message translates to:
  /// **'Action non autorisée'**
  String get notAllowedGroupAction;

  /// No description provided for @ownerMustTransferOnLeave.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes propriétaire : le groupe sera confié au membre le plus ancien.'**
  String get ownerMustTransferOnLeave;

  /// No description provided for @groupInfoUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Infos du groupe mises à jour'**
  String get groupInfoUpdated;

  /// No description provided for @groupUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier le groupe'**
  String get groupUpdateFailed;

  /// No description provided for @announcementOnlyAdmins.
  ///
  /// In fr, this message translates to:
  /// **'Seuls les administrateurs peuvent envoyer des messages'**
  String get announcementOnlyAdmins;

  /// No description provided for @officialAccountReadonlyBanner.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte diffuse des annonces. Vous ne pouvez pas y répondre.'**
  String get officialAccountReadonlyBanner;

  /// No description provided for @accountBadgeVerified.
  ///
  /// In fr, this message translates to:
  /// **'Compte vérifié'**
  String get accountBadgeVerified;

  /// No description provided for @accountBadgeBusinessDeclared.
  ///
  /// In fr, this message translates to:
  /// **'Commerce déclaré'**
  String get accountBadgeBusinessDeclared;

  /// No description provided for @accountBadgeBusinessVerified.
  ///
  /// In fr, this message translates to:
  /// **'Commerce vérifié'**
  String get accountBadgeBusinessVerified;

  /// No description provided for @accountBadgeOfficial.
  ///
  /// In fr, this message translates to:
  /// **'Compte officiel Alanya'**
  String get accountBadgeOfficial;

  /// No description provided for @mentionAll.
  ///
  /// In fr, this message translates to:
  /// **'@Tous'**
  String get mentionAll;

  /// No description provided for @mentionAllSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Alerte les {count} membres'**
  String mentionAllSubtitle(int count);

  /// No description provided for @mentionYou.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get mentionYou;

  /// No description provided for @jumpToMention.
  ///
  /// In fr, this message translates to:
  /// **'Aller à la mention suivante'**
  String get jumpToMention;

  /// No description provided for @unreadMessagesSeparator.
  ///
  /// In fr, this message translates to:
  /// **'Messages non lus'**
  String get unreadMessagesSeparator;

  /// No description provided for @signupEmailOptionalHint.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail (optionnel)'**
  String get signupEmailOptionalHint;

  /// No description provided for @signupEmailOptionalSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Uniquement pour récupérer votre mot de passe'**
  String get signupEmailOptionalSubtitle;

  /// No description provided for @signupNoEmailWarningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Sans adresse e-mail'**
  String get signupNoEmailWarningTitle;

  /// No description provided for @signupNoEmailWarningBody.
  ///
  /// In fr, this message translates to:
  /// **'Sans e-mail, vous ne pourrez pas récupérer votre compte si vous oubliez votre ID Alanya ou votre mot de passe.'**
  String get signupNoEmailWarningBody;

  /// No description provided for @signupAddEmail.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un e-mail'**
  String get signupAddEmail;

  /// No description provided for @signupContinueWithoutEmail.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get signupContinueWithoutEmail;

  /// No description provided for @signupCredentialsNoEmailReminder.
  ///
  /// In fr, this message translates to:
  /// **'Sans e-mail, la récupération de compte est impossible. Vous pourrez en ajouter un à tout moment dans Profil → Compte → Modifier le profil (vérification par code OTP).'**
  String get signupCredentialsNoEmailReminder;

  /// No description provided for @signupCredentialsEmailOk.
  ///
  /// In fr, this message translates to:
  /// **'Votre e-mail pourra servir à récupérer votre mot de passe en cas d\'oubli.'**
  String get signupCredentialsEmailOk;

  /// No description provided for @emailLabel.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get emailLabel;

  /// No description provided for @emailNotSet.
  ///
  /// In fr, this message translates to:
  /// **'Non renseigné'**
  String get emailNotSet;

  /// No description provided for @emailNeededForRecovery.
  ///
  /// In fr, this message translates to:
  /// **'Nécessaire pour récupérer votre mot de passe'**
  String get emailNeededForRecovery;

  /// No description provided for @emailMissingRecoveryBanner.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse e-mail : vous ne pourrez pas récupérer votre compte en cas d\'oubli d\'identifiants.'**
  String get emailMissingRecoveryBanner;

  /// No description provided for @accountSecurityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Compte et sécurité'**
  String get accountSecurityTitle;

  /// No description provided for @accountSecuritySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'E-mail et mot de passe'**
  String get accountSecuritySubtitle;

  /// No description provided for @changeEmailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get changeEmailTitle;

  /// No description provided for @changeEmailSubtitleAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez une adresse pour pouvoir récupérer votre mot de passe.'**
  String get changeEmailSubtitleAdd;

  /// No description provided for @changeEmailSubtitleReplace.
  ///
  /// In fr, this message translates to:
  /// **'Un code de vérification sera envoyé à la nouvelle adresse.'**
  String get changeEmailSubtitleReplace;

  /// No description provided for @changeEmailCurrentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse actuelle'**
  String get changeEmailCurrentLabel;

  /// No description provided for @changeEmailNewLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle adresse e-mail'**
  String get changeEmailNewLabel;

  /// No description provided for @changeEmailAddLabel.
  ///
  /// In fr, this message translates to:
  /// **'Votre adresse e-mail'**
  String get changeEmailAddLabel;

  /// No description provided for @changeEmailStep1.
  ///
  /// In fr, this message translates to:
  /// **'1. Adresse'**
  String get changeEmailStep1;

  /// No description provided for @changeEmailStep2.
  ///
  /// In fr, this message translates to:
  /// **'2. Vérification'**
  String get changeEmailStep2;

  /// No description provided for @changeEmailWhyOtp.
  ///
  /// In fr, this message translates to:
  /// **'Pour confirmer que vous avez accès à cette adresse, un code à 6 chiffres vous sera envoyé par e-mail.'**
  String get changeEmailWhyOtp;

  /// No description provided for @changeEmailCheckInbox.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez votre boîte mail et saisissez le code reçu. Vérifiez aussi les spams.'**
  String get changeEmailCheckInbox;

  /// No description provided for @changeEmailEditAddress.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'adresse'**
  String get changeEmailEditAddress;

  /// No description provided for @changeEmailSendCode.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le code'**
  String get changeEmailSendCode;

  /// No description provided for @changeEmailOtpTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code de vérification'**
  String get changeEmailOtpTitle;

  /// No description provided for @changeEmailOtpSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez le code envoyé à {email}'**
  String changeEmailOtpSubtitle(String email);

  /// No description provided for @changeEmailResendCode.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get changeEmailResendCode;

  /// No description provided for @changeEmailConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Valider et enregistrer'**
  String get changeEmailConfirm;

  /// No description provided for @changeEmailSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail mise à jour'**
  String get changeEmailSuccess;

  /// No description provided for @changePasswordTitle.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le mot de passe actuel est requis'**
  String get changePasswordSubtitle;

  /// No description provided for @changePasswordCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe actuel'**
  String get changePasswordCurrent;

  /// No description provided for @changePasswordNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get changePasswordNew;

  /// No description provided for @changePasswordConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer le nouveau mot de passe'**
  String get changePasswordConfirm;

  /// No description provided for @changePasswordSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get changePasswordSubmit;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe modifié'**
  String get changePasswordSuccess;

  /// No description provided for @changePasswordSameAsCurrent.
  ///
  /// In fr, this message translates to:
  /// **'Le nouveau mot de passe doit être différent de l\'actuel'**
  String get changePasswordSameAsCurrent;

  /// No description provided for @profileNoEmailChip.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un e-mail pour sécuriser votre compte'**
  String get profileNoEmailChip;

  /// No description provided for @addToCall.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à l\'appel'**
  String get addToCall;

  /// No description provided for @transferCall.
  ///
  /// In fr, this message translates to:
  /// **'Transférer l\'appel'**
  String get transferCall;

  /// No description provided for @transferCallSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transférer l\'appel'**
  String get transferCallSheetTitle;

  /// No description provided for @transferCallConfirmationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transférer l\'appel ?'**
  String get transferCallConfirmationTitle;

  /// No description provided for @transferCallConfirmationBody.
  ///
  /// In fr, this message translates to:
  /// **'Le contact rejoindra d\'abord l\'appel. Vous quitterez automatiquement environ 10 secondes après que sa connexion sera établie.'**
  String get transferCallConfirmationBody;

  /// No description provided for @addToCallConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'Inviter ce contact à rejoindre l\'appel en cours ?'**
  String get addToCallConfirmBody;

  /// No description provided for @transferWaitingForParticipant.
  ///
  /// In fr, this message translates to:
  /// **'En attente de réponse…'**
  String get transferWaitingForParticipant;

  /// No description provided for @transferWaitingForConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion en cours…'**
  String get transferWaitingForConnection;

  /// No description provided for @transferCountdown.
  ///
  /// In fr, this message translates to:
  /// **'Transfert en cours… Vous quitterez bientôt l\'appel.'**
  String get transferCountdown;

  /// No description provided for @transferCountdownSeconds.
  ///
  /// In fr, this message translates to:
  /// **'Transfert · {seconds}s'**
  String transferCountdownSeconds(int seconds);

  /// No description provided for @transferCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Appel transféré'**
  String get transferCompleted;

  /// No description provided for @mediaConnectionFailed.
  ///
  /// In fr, this message translates to:
  /// **'La connexion média n\'a pas pu être établie'**
  String get mediaConnectionFailed;

  /// No description provided for @conferenceTransferInviteBody.
  ///
  /// In fr, this message translates to:
  /// **'souhaite vous transférer cet appel'**
  String get conferenceTransferInviteBody;

  /// No description provided for @confCallOfThree.
  ///
  /// In fr, this message translates to:
  /// **'Appel à 3'**
  String get confCallOfThree;

  /// No description provided for @confRinging.
  ///
  /// In fr, this message translates to:
  /// **'Sonnerie…'**
  String get confRinging;

  /// No description provided for @confAddingInvitee.
  ///
  /// In fr, this message translates to:
  /// **'{name} est en train d\'être ajouté'**
  String confAddingInvitee(String name);

  /// No description provided for @confSomeoneAdds.
  ///
  /// In fr, this message translates to:
  /// **'{who} ajoute {name}'**
  String confSomeoneAdds(String who, String name);

  /// No description provided for @confJoinedCall.
  ///
  /// In fr, this message translates to:
  /// **'{name} a rejoint l\'appel'**
  String confJoinedCall(String name);

  /// No description provided for @confLeftCall.
  ///
  /// In fr, this message translates to:
  /// **'{name} a quitté l\'appel'**
  String confLeftCall(String name);

  /// No description provided for @confDeclined.
  ///
  /// In fr, this message translates to:
  /// **'{name} a refusé de rejoindre'**
  String confDeclined(String name);

  /// No description provided for @confBusy.
  ///
  /// In fr, this message translates to:
  /// **'{name} est déjà en appel'**
  String confBusy(String name);

  /// No description provided for @confNoAnswer.
  ///
  /// In fr, this message translates to:
  /// **'{name} n\'a pas répondu'**
  String confNoAnswer(String name);

  /// No description provided for @confNotJoined.
  ///
  /// In fr, this message translates to:
  /// **'{name} n\'a pas rejoint l\'appel'**
  String confNotJoined(String name);

  /// No description provided for @confAddAlreadyUsed.
  ///
  /// In fr, this message translates to:
  /// **'Un participant a déjà été ajouté à cet appel'**
  String get confAddAlreadyUsed;

  /// No description provided for @confCannotAdd.
  ///
  /// In fr, this message translates to:
  /// **'{name} ne peut pas être ajoutée'**
  String confCannotAdd(String name);

  /// No description provided for @confAddFailed.
  ///
  /// In fr, this message translates to:
  /// **'L\'ajout n\'a pas pu aboutir'**
  String get confAddFailed;

  /// No description provided for @confInviteSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'vous ajoute à un appel avec {name}'**
  String confInviteSubtitle(String name);

  /// No description provided for @confAddSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à l\'appel'**
  String get confAddSheetTitle;

  /// No description provided for @noContactsToAdd.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact à ajouter'**
  String get noContactsToAdd;

  /// No description provided for @confAlreadyInCall.
  ///
  /// In fr, this message translates to:
  /// **'déjà là'**
  String get confAlreadyInCall;

  /// No description provided for @confContactBusy.
  ///
  /// In fr, this message translates to:
  /// **'en appel'**
  String get confContactBusy;

  /// No description provided for @confCancelInvite.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get confCancelInvite;

  /// No description provided for @qrMyCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon code QR'**
  String get qrMyCodeTitle;

  /// No description provided for @qrMyCodeTabCode.
  ///
  /// In fr, this message translates to:
  /// **'Mon code'**
  String get qrMyCodeTabCode;

  /// No description provided for @qrMyCodeTabScan.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get qrMyCodeTabScan;

  /// No description provided for @qrMyCodeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Faites scanner ce code pour être ajouté en contact préféré.'**
  String get qrMyCodeSubtitle;

  /// No description provided for @qrMyCodeShare.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get qrMyCodeShare;

  /// No description provided for @qrMyCodeExpiresIn.
  ///
  /// In fr, this message translates to:
  /// **'Expire dans {time}'**
  String qrMyCodeExpiresIn(String time);

  /// No description provided for @qrMyCodeValidityNote.
  ///
  /// In fr, this message translates to:
  /// **'Valable 10 minutes et pour une seule personne. Un nouveau code est généré automatiquement.'**
  String get qrMyCodeValidityNote;

  /// No description provided for @qrMyCodeNewCode.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code'**
  String get qrMyCodeNewCode;

  /// No description provided for @qrMyCodeShareValidity.
  ///
  /// In fr, this message translates to:
  /// **'Ce code est valable 10 minutes et pour une seule personne.'**
  String get qrMyCodeShareValidity;

  /// No description provided for @qrScanReturnTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau contact'**
  String get qrScanReturnTitle;

  /// No description provided for @qrScanReturnBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous a ajouté à ses contacts préférés avec votre code QR. L\'ajouter en retour ?'**
  String qrScanReturnBody(String name);

  /// No description provided for @qrScanReturnAccept.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get qrScanReturnAccept;

  /// No description provided for @qrScanReturnDecline.
  ///
  /// In fr, this message translates to:
  /// **'Non merci'**
  String get qrScanReturnDecline;

  /// No description provided for @qrScanReturnFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter ce contact'**
  String get qrScanReturnFailed;

  /// No description provided for @qrScannedMutualInfo.
  ///
  /// In fr, this message translates to:
  /// **'{name} vous a ajouté avec votre code QR'**
  String qrScannedMutualInfo(String name);

  /// No description provided for @qrNoteFieldHint.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une note (lieu, contexte…)'**
  String get qrNoteFieldHint;

  /// No description provided for @qrNoteSaved.
  ///
  /// In fr, this message translates to:
  /// **'Note enregistrée'**
  String get qrNoteSaved;

  /// No description provided for @qrNoteFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la note'**
  String get qrNoteFailed;

  /// No description provided for @qrContactsFilterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get qrContactsFilterAll;

  /// No description provided for @qrContactsFilterQr.
  ///
  /// In fr, this message translates to:
  /// **'Par QR'**
  String get qrContactsFilterQr;

  /// No description provided for @qrContactAddedViaQr.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté par QR code'**
  String get qrContactAddedViaQr;

  /// No description provided for @qrContactAddedViaQrOn.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté par QR code · {date}'**
  String qrContactAddedViaQrOn(String date);

  /// No description provided for @qrMyCodeShareSheetTitle.
  ///
  /// In fr, this message translates to:
  /// **'Partager mon code'**
  String get qrMyCodeShareSheetTitle;

  /// No description provided for @qrMyCodeShareLink.
  ///
  /// In fr, this message translates to:
  /// **'Partager le lien'**
  String get qrMyCodeShareLink;

  /// No description provided for @qrMyCodeShareLinkHint.
  ///
  /// In fr, this message translates to:
  /// **'Lien cliquable et Alanya ID'**
  String get qrMyCodeShareLinkHint;

  /// No description provided for @qrMyCodeShareImage.
  ///
  /// In fr, this message translates to:
  /// **'Partager l\'image'**
  String get qrMyCodeShareImage;

  /// No description provided for @qrMyCodeShareImageHint.
  ///
  /// In fr, this message translates to:
  /// **'La carte à scanner'**
  String get qrMyCodeShareImageHint;

  /// No description provided for @qrMyCodeShareId.
  ///
  /// In fr, this message translates to:
  /// **'Mon Alanya ID : {id}'**
  String qrMyCodeShareId(String id);

  /// No description provided for @qrMyCodeRegenerate.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer'**
  String get qrMyCodeRegenerate;

  /// No description provided for @qrMyCodeRegenerateConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Régénérer votre code ?'**
  String get qrMyCodeRegenerateConfirmTitle;

  /// No description provided for @qrMyCodeRegenerateConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'L\'ancien code cessera immédiatement de fonctionner. Les personnes qui l\'ont enregistré ne pourront plus vous ajouter avec.'**
  String get qrMyCodeRegenerateConfirmBody;

  /// No description provided for @qrMyCodeRegenerateDone.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code généré'**
  String get qrMyCodeRegenerateDone;

  /// No description provided for @qrMyCodeShareText.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez-moi sur Alanya : je suis {name}.'**
  String qrMyCodeShareText(String name);

  /// No description provided for @qrScanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un code'**
  String get qrScanTitle;

  /// No description provided for @qrScanEntryButton.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un code'**
  String get qrScanEntryButton;

  /// No description provided for @qrScanInstruction.
  ///
  /// In fr, this message translates to:
  /// **'Cadrez le code QR d\'un contact'**
  String get qrScanInstruction;

  /// No description provided for @qrScanErrorUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Code illisible. Rapprochez-vous et réessayez.'**
  String get qrScanErrorUnreadable;

  /// No description provided for @qrScanErrorUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Ce code est expiré ou inconnu.'**
  String get qrScanErrorUnknown;

  /// No description provided for @qrScanOwnCode.
  ///
  /// In fr, this message translates to:
  /// **'C\'est votre propre code.'**
  String get qrScanOwnCode;

  /// No description provided for @qrScanAddSuccess.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été ajouté à vos contacts préférés'**
  String qrScanAddSuccess(String name);

  /// No description provided for @qrScanAlreadyContact.
  ///
  /// In fr, this message translates to:
  /// **'{name} est déjà dans vos contacts préférés'**
  String qrScanAlreadyContact(String name);

  /// No description provided for @qrScanResultAdded.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté à vos contacts'**
  String get qrScanResultAdded;

  /// No description provided for @qrScanResultAlready.
  ///
  /// In fr, this message translates to:
  /// **'Déjà dans vos contacts'**
  String get qrScanResultAlready;

  /// No description provided for @qrScanActionMessage.
  ///
  /// In fr, this message translates to:
  /// **'Message'**
  String get qrScanActionMessage;

  /// No description provided for @qrScanActionDetails.
  ///
  /// In fr, this message translates to:
  /// **'Voir détails'**
  String get qrScanActionDetails;

  /// No description provided for @qrScanUndo.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get qrScanUndo;

  /// No description provided for @qrScanUndone.
  ///
  /// In fr, this message translates to:
  /// **'{name} a été retiré de vos contacts préférés'**
  String qrScanUndone(String name);

  /// No description provided for @qrScanUndoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'annuler l\'ajout'**
  String get qrScanUndoFailed;

  /// No description provided for @qrScanCameraDenied.
  ///
  /// In fr, this message translates to:
  /// **'Alanya a besoin d\'accéder à la caméra pour scanner un code.'**
  String get qrScanCameraDenied;

  /// No description provided for @qrScanOpenSettings.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir les réglages'**
  String get qrScanOpenSettings;

  /// No description provided for @qrScanTorchOn.
  ///
  /// In fr, this message translates to:
  /// **'Lampe allumée'**
  String get qrScanTorchOn;

  /// No description provided for @qrScanTorchOff.
  ///
  /// In fr, this message translates to:
  /// **'Lampe éteinte'**
  String get qrScanTorchOff;

  /// No description provided for @qrScanImportImage.
  ///
  /// In fr, this message translates to:
  /// **'Importer une image'**
  String get qrScanImportImage;

  /// No description provided for @qrScanImportNoCode.
  ///
  /// In fr, this message translates to:
  /// **'Aucun code QR dans cette image.'**
  String get qrScanImportNoCode;

  /// No description provided for @qrScanImportNotAlanya.
  ///
  /// In fr, this message translates to:
  /// **'Ce code QR n\'est pas un code Alanya.'**
  String get qrScanImportNotAlanya;

  /// No description provided for @qrScanImportFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de lire cette image.'**
  String get qrScanImportFailed;

  /// No description provided for @qrLoginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par QR code'**
  String get qrLoginTitle;

  /// No description provided for @qrLoginEntryButton.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec un code QR'**
  String get qrLoginEntryButton;

  /// No description provided for @qrLoginUsePassword.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter avec mon mot de passe'**
  String get qrLoginUsePassword;

  /// No description provided for @qrLoginExplanation.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez Alanya sur votre téléphone déjà connecté, allez dans Compte et sécurité, puis scannez ce code.'**
  String get qrLoginExplanation;

  /// No description provided for @qrLoginExpiresIn.
  ///
  /// In fr, this message translates to:
  /// **'Expire dans {time}'**
  String qrLoginExpiresIn(String time);

  /// No description provided for @qrLoginStatusWaiting.
  ///
  /// In fr, this message translates to:
  /// **'En attente de scan…'**
  String get qrLoginStatusWaiting;

  /// No description provided for @qrLoginStatusScanned.
  ///
  /// In fr, this message translates to:
  /// **'Code scanné. Confirmez sur votre autre appareil.'**
  String get qrLoginStatusScanned;

  /// No description provided for @qrLoginStatusRejected.
  ///
  /// In fr, this message translates to:
  /// **'Connexion refusée depuis votre autre appareil.'**
  String get qrLoginStatusRejected;

  /// No description provided for @qrLoginStatusExpired.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré.'**
  String get qrLoginStatusExpired;

  /// No description provided for @qrLoginRegenerate.
  ///
  /// In fr, this message translates to:
  /// **'Générer un nouveau code'**
  String get qrLoginRegenerate;

  /// No description provided for @qrLoginNetworkError.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Vérifiez votre réseau et réessayez.'**
  String get qrLoginNetworkError;

  /// No description provided for @qrApproveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle connexion'**
  String get qrApproveTitle;

  /// No description provided for @qrApproveIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ce code vient d\'être scanné depuis cet appareil :'**
  String get qrApproveIntro;

  /// No description provided for @qrApproveDeviceLabel.
  ///
  /// In fr, this message translates to:
  /// **'Appareil (nom déclaré)'**
  String get qrApproveDeviceLabel;

  /// No description provided for @qrApprovePlatformLabel.
  ///
  /// In fr, this message translates to:
  /// **'Plateforme'**
  String get qrApprovePlatformLabel;

  /// No description provided for @qrApproveRequestedLabel.
  ///
  /// In fr, this message translates to:
  /// **'Demandé'**
  String get qrApproveRequestedLabel;

  /// No description provided for @qrApproveIpLabel.
  ///
  /// In fr, this message translates to:
  /// **'Adresse IP'**
  String get qrApproveIpLabel;

  /// No description provided for @qrApproveLocationLabel.
  ///
  /// In fr, this message translates to:
  /// **'Lieu approximatif'**
  String get qrApproveLocationLabel;

  /// No description provided for @qrApproveDeclaredNotice.
  ///
  /// In fr, this message translates to:
  /// **'Le nom et la plateforme sont annoncés par l\'appareil qui demande la connexion : ils peuvent être falsifiés. Seule l\'adresse IP est constatée par Alanya.'**
  String get qrApproveDeclaredNotice;

  /// No description provided for @qrApproveSecurityWarning.
  ///
  /// In fr, this message translates to:
  /// **'Si vous n\'êtes pas à l\'origine de cette demande, refusez-la et changez votre mot de passe.'**
  String get qrApproveSecurityWarning;

  /// No description provided for @qrApproveReject.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get qrApproveReject;

  /// No description provided for @qrApproveConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get qrApproveConfirm;

  /// No description provided for @qrApproveDone.
  ///
  /// In fr, this message translates to:
  /// **'Appareil connecté'**
  String get qrApproveDone;

  /// No description provided for @qrApproveRejectDone.
  ///
  /// In fr, this message translates to:
  /// **'Connexion refusée'**
  String get qrApproveRejectDone;

  /// No description provided for @qrApproveSessionExpired.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande a expiré. Faites afficher un nouveau code sur l\'autre appareil.'**
  String get qrApproveSessionExpired;

  /// No description provided for @qrDevicesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get qrDevicesTitle;

  /// No description provided for @qrDevicesEntryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Appareils connectés'**
  String get qrDevicesEntryTitle;

  /// No description provided for @qrDevicesEntrySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voir où votre compte est ouvert'**
  String get qrDevicesEntrySubtitle;

  /// No description provided for @qrLinkDeviceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lier un nouvel appareil'**
  String get qrLinkDeviceTitle;

  /// No description provided for @qrLinkDeviceSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner le code affiché sur l\'autre appareil'**
  String get qrLinkDeviceSubtitle;

  /// No description provided for @qrDevicesThisDevice.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil'**
  String get qrDevicesThisDevice;

  /// No description provided for @qrDevicesUnknownDevice.
  ///
  /// In fr, this message translates to:
  /// **'Appareil inconnu'**
  String get qrDevicesUnknownDevice;

  /// No description provided for @qrDevicesMethodPassword.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par mot de passe'**
  String get qrDevicesMethodPassword;

  /// No description provided for @qrDevicesMethodSignup.
  ///
  /// In fr, this message translates to:
  /// **'Appareil d\'inscription'**
  String get qrDevicesMethodSignup;

  /// No description provided for @qrDevicesMethodQr.
  ///
  /// In fr, this message translates to:
  /// **'Connexion par code QR'**
  String get qrDevicesMethodQr;

  /// No description provided for @qrDevicesLastActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif {date}'**
  String qrDevicesLastActive(String date);

  /// No description provided for @qrDevicesRevoke.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get qrDevicesRevoke;

  /// No description provided for @qrDevicesRevokeConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter cet appareil ?'**
  String get qrDevicesRevokeConfirmTitle;

  /// No description provided for @qrDevicesRevokeConfirmBody.
  ///
  /// In fr, this message translates to:
  /// **'{name} sera déconnecté immédiatement. Il faudra saisir votre mot de passe pour s\'y reconnecter.'**
  String qrDevicesRevokeConfirmBody(String name);

  /// No description provided for @qrDevicesRevokeDone.
  ///
  /// In fr, this message translates to:
  /// **'Appareil déconnecté'**
  String get qrDevicesRevokeDone;

  /// No description provided for @qrDevicesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun autre appareil connecté'**
  String get qrDevicesEmpty;

  /// No description provided for @qrDevicesLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos appareils'**
  String get qrDevicesLoadError;

  /// No description provided for @qrDevicesIosNote.
  ///
  /// In fr, this message translates to:
  /// **'Sur iPhone, un appareil peut réapparaître comme un nouvel appareil dans cette liste après une réinstallation d\'Alanya.'**
  String get qrDevicesIosNote;

  /// No description provided for @qrBannerNewDevice.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel appareil connecté : {name}'**
  String qrBannerNewDevice(String name);

  /// No description provided for @qrBannerSignedOutRemotely.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil a été déconnecté depuis un autre appareil.'**
  String get qrBannerSignedOutRemotely;

  /// No description provided for @myAccountLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get myAccountLabel;

  /// No description provided for @accountHubTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get accountHubTitle;

  /// No description provided for @accountHubSecurityScore.
  ///
  /// In fr, this message translates to:
  /// **'Score de sécurité'**
  String get accountHubSecurityScore;

  /// No description provided for @accountHubSecurityScoreValue.
  ///
  /// In fr, this message translates to:
  /// **'{score} / {max}'**
  String accountHubSecurityScoreValue(int score, int max);

  /// No description provided for @securityScoreAddEmail.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un e-mail pour améliorer votre score.'**
  String get securityScoreAddEmail;

  /// No description provided for @securityScoreAddBiometric.
  ///
  /// In fr, this message translates to:
  /// **'Activez la biométrie pour améliorer votre score.'**
  String get securityScoreAddBiometric;

  /// No description provided for @accountHubSectionIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get accountHubSectionIdentity;

  /// No description provided for @accountHubSectionProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get accountHubSectionProtection;

  /// No description provided for @accountHubSectionData.
  ///
  /// In fr, this message translates to:
  /// **'Données'**
  String get accountHubSectionData;

  /// No description provided for @accountHubEditProfile.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le profil'**
  String get accountHubEditProfile;

  /// No description provided for @accountHubEditProfileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Nom, pseudo, bio, photo'**
  String get accountHubEditProfileSubtitle;

  /// No description provided for @accountHubMyMedia.
  ///
  /// In fr, this message translates to:
  /// **'Mes médias'**
  String get accountHubMyMedia;

  /// No description provided for @accountHubPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Confidentialité'**
  String get accountHubPrivacy;

  /// No description provided for @accountHubPrivacySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Visibilité, blocage, lectures'**
  String get accountHubPrivacySubtitle;

  /// No description provided for @accountHubSecurity.
  ///
  /// In fr, this message translates to:
  /// **'Sécurité du compte'**
  String get accountHubSecurity;

  /// No description provided for @accountHubSecuritySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe, appareils, biométrie'**
  String get accountHubSecuritySubtitle;

  /// No description provided for @accountHubDataAccount.
  ///
  /// In fr, this message translates to:
  /// **'Données et compte'**
  String get accountHubDataAccount;

  /// No description provided for @accountHubDataAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Export RGPD, suppression'**
  String get accountHubDataAccountSubtitle;

  /// No description provided for @accountHubProfilePreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu profil'**
  String get accountHubProfilePreview;

  /// No description provided for @accountHubProfilePreviewSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voir comme vos contacts'**
  String get accountHubProfilePreviewSubtitle;

  /// No description provided for @profileBioLabel.
  ///
  /// In fr, this message translates to:
  /// **'Bio'**
  String get profileBioLabel;

  /// No description provided for @profileBioHint.
  ///
  /// In fr, this message translates to:
  /// **'Parlez de vous en quelques mots (500 caractères max)'**
  String get profileBioHint;

  /// No description provided for @profilePreviewLink.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu du profil'**
  String get profilePreviewLink;

  /// No description provided for @myMediaTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes médias'**
  String get myMediaTitle;

  /// No description provided for @myMediaPlaceholder.
  ///
  /// In fr, this message translates to:
  /// **'Vos photos et vidéos partagées apparaîtront ici.'**
  String get myMediaPlaceholder;

  /// No description provided for @storageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Stockage et cache'**
  String get storageTitle;

  /// No description provided for @storageUsed.
  ///
  /// In fr, this message translates to:
  /// **'Espace utilisé'**
  String get storageUsed;

  /// No description provided for @storageBreakdownTitle.
  ///
  /// In fr, this message translates to:
  /// **'Répartition'**
  String get storageBreakdownTitle;

  /// No description provided for @storageMediaCache.
  ///
  /// In fr, this message translates to:
  /// **'Cache médias'**
  String get storageMediaCache;

  /// No description provided for @storageDatabase.
  ///
  /// In fr, this message translates to:
  /// **'Base de données'**
  String get storageDatabase;

  /// No description provided for @storageTempFiles.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers temporaires'**
  String get storageTempFiles;

  /// No description provided for @storageOther.
  ///
  /// In fr, this message translates to:
  /// **'Autres données'**
  String get storageOther;

  /// No description provided for @storageClearMediaCache.
  ///
  /// In fr, this message translates to:
  /// **'Vider le cache médias'**
  String get storageClearMediaCache;

  /// No description provided for @storageClearTemp.
  ///
  /// In fr, this message translates to:
  /// **'Vider les fichiers temporaires'**
  String get storageClearTemp;

  /// No description provided for @storageClearCacheConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Les fichiers en cache seront supprimés. Les médias pourront être retéléchargés.'**
  String get storageClearCacheConfirm;

  /// No description provided for @storageClearCacheDone.
  ///
  /// In fr, this message translates to:
  /// **'Cache médias vidé'**
  String get storageClearCacheDone;

  /// No description provided for @storageClearTempDone.
  ///
  /// In fr, this message translates to:
  /// **'Fichiers temporaires supprimés'**
  String get storageClearTempDone;

  /// No description provided for @networkDataTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réseau et données'**
  String get networkDataTitle;

  /// No description provided for @networkDataSectionNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Réseau'**
  String get networkDataSectionNetwork;

  /// No description provided for @networkWifiOnly.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi uniquement'**
  String get networkWifiOnly;

  /// No description provided for @networkWifiOnlySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ne télécharge les médias que sur Wi-Fi'**
  String get networkWifiOnlySubtitle;

  /// No description provided for @networkDataSaver.
  ///
  /// In fr, this message translates to:
  /// **'Économiseur de données'**
  String get networkDataSaver;

  /// No description provided for @networkDataSaverSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Réduit la qualité et les téléchargements automatiques'**
  String get networkDataSaverSubtitle;

  /// No description provided for @settingsSectionCommunication.
  ///
  /// In fr, this message translates to:
  /// **'Communication'**
  String get settingsSectionCommunication;

  /// No description provided for @settingsSectionApplication.
  ///
  /// In fr, this message translates to:
  /// **'Application'**
  String get settingsSectionApplication;

  /// No description provided for @settingsSectionInformation.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get settingsSectionInformation;

  /// No description provided for @settingsStorage.
  ///
  /// In fr, this message translates to:
  /// **'Stockage et cache'**
  String get settingsStorage;

  /// No description provided for @settingsStorageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Espace utilisé et nettoyage'**
  String get settingsStorageSubtitle;

  /// No description provided for @settingsNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Réseau et données'**
  String get settingsNetwork;

  /// No description provided for @settingsNetworkSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Wi-Fi et économiseur de données'**
  String get settingsNetworkSubtitle;

  /// No description provided for @settingsAccessibility.
  ///
  /// In fr, this message translates to:
  /// **'Accessibilité'**
  String get settingsAccessibility;

  /// No description provided for @settingsAccessibilitySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Texte et animations'**
  String get settingsAccessibilitySubtitle;

  /// No description provided for @settingsAbout.
  ///
  /// In fr, this message translates to:
  /// **'À propos et mentions légales'**
  String get settingsAbout;

  /// No description provided for @settingsMutedConversations.
  ///
  /// In fr, this message translates to:
  /// **'Conversations silencieuses'**
  String get settingsMutedConversations;

  /// No description provided for @accessibilityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accessibilité'**
  String get accessibilityTitle;

  /// No description provided for @accessibilitySectionDisplay.
  ///
  /// In fr, this message translates to:
  /// **'Affichage'**
  String get accessibilitySectionDisplay;

  /// No description provided for @accessibilityFontScale.
  ///
  /// In fr, this message translates to:
  /// **'Taille du texte'**
  String get accessibilityFontScale;

  /// No description provided for @accessibilityFontScaleSmall.
  ///
  /// In fr, this message translates to:
  /// **'Petit'**
  String get accessibilityFontScaleSmall;

  /// No description provided for @accessibilityFontScaleDefault.
  ///
  /// In fr, this message translates to:
  /// **'Normal'**
  String get accessibilityFontScaleDefault;

  /// No description provided for @accessibilityFontScaleMedium.
  ///
  /// In fr, this message translates to:
  /// **'Grand'**
  String get accessibilityFontScaleMedium;

  /// No description provided for @accessibilityFontScaleLarge.
  ///
  /// In fr, this message translates to:
  /// **'Très grand'**
  String get accessibilityFontScaleLarge;

  /// No description provided for @accessibilityReduceMotion.
  ///
  /// In fr, this message translates to:
  /// **'Réduire les animations'**
  String get accessibilityReduceMotion;

  /// No description provided for @accessibilityReduceMotionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Limite les transitions et effets visuels'**
  String get accessibilityReduceMotionSubtitle;

  /// No description provided for @accessibilitySaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer les préférences'**
  String get accessibilitySaveFailed;

  /// No description provided for @mutedConversationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conversations silencieuses'**
  String get mutedConversationsTitle;

  /// No description provided for @mutedConversationsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune conversation silencieuse'**
  String get mutedConversationsEmpty;

  /// No description provided for @mutedConversationsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 conversation} other{{count} conversations}}'**
  String mutedConversationsCount(int count);

  /// No description provided for @mutedForeverLabel.
  ///
  /// In fr, this message translates to:
  /// **'Silencieux indéfiniment'**
  String get mutedForeverLabel;

  /// No description provided for @mutedUntilLabel.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au {date}'**
  String mutedUntilLabel(String date);

  /// No description provided for @dndScheduleTitle.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas déranger'**
  String get dndScheduleTitle;

  /// No description provided for @dndEnabled.
  ///
  /// In fr, this message translates to:
  /// **'Planifier'**
  String get dndEnabled;

  /// No description provided for @dndEnabledSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Couper les notifications sur un créneau horaire'**
  String get dndEnabledSubtitle;

  /// No description provided for @dndScheduleHours.
  ///
  /// In fr, this message translates to:
  /// **'Horaires'**
  String get dndScheduleHours;

  /// No description provided for @dndStartTime.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get dndStartTime;

  /// No description provided for @dndEndTime.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get dndEndTime;

  /// No description provided for @dndDays.
  ///
  /// In fr, this message translates to:
  /// **'Jours actifs'**
  String get dndDays;

  /// No description provided for @dndDayMon.
  ///
  /// In fr, this message translates to:
  /// **'Lun'**
  String get dndDayMon;

  /// No description provided for @dndDayTue.
  ///
  /// In fr, this message translates to:
  /// **'Mar'**
  String get dndDayTue;

  /// No description provided for @dndDayWed.
  ///
  /// In fr, this message translates to:
  /// **'Mer'**
  String get dndDayWed;

  /// No description provided for @dndDayThu.
  ///
  /// In fr, this message translates to:
  /// **'Jeu'**
  String get dndDayThu;

  /// No description provided for @dndDayFri.
  ///
  /// In fr, this message translates to:
  /// **'Ven'**
  String get dndDayFri;

  /// No description provided for @dndDaySat.
  ///
  /// In fr, this message translates to:
  /// **'Sam'**
  String get dndDaySat;

  /// No description provided for @dndDaySun.
  ///
  /// In fr, this message translates to:
  /// **'Dim'**
  String get dndDaySun;

  /// No description provided for @dndSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer le planning'**
  String get dndSaveFailed;

  /// No description provided for @aboutTitle.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get aboutTitle;

  /// No description provided for @aboutSectionLegal.
  ///
  /// In fr, this message translates to:
  /// **'Mentions légales'**
  String get aboutSectionLegal;

  /// No description provided for @aboutVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version {version} (build {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutTerms.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get aboutTerms;

  /// No description provided for @aboutPrivacy.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get aboutPrivacy;

  /// No description provided for @aboutLicenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences open source'**
  String get aboutLicenses;

  /// No description provided for @aboutSupport.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le support'**
  String get aboutSupport;

  /// No description provided for @aboutCopyright.
  ///
  /// In fr, this message translates to:
  /// **'© 2026 Alanya · Fait avec soin à Yaoundé'**
  String get aboutCopyright;

  /// No description provided for @exportDataTitle.
  ///
  /// In fr, this message translates to:
  /// **'Données et compte'**
  String get exportDataTitle;

  /// No description provided for @exportSectionYourData.
  ///
  /// In fr, this message translates to:
  /// **'Vos données'**
  String get exportSectionYourData;

  /// No description provided for @exportSectionDanger.
  ///
  /// In fr, this message translates to:
  /// **'Zone sensible'**
  String get exportSectionDanger;

  /// No description provided for @exportPhase1Title.
  ///
  /// In fr, this message translates to:
  /// **'Export rapide (RGPD)'**
  String get exportPhase1Title;

  /// No description provided for @exportPhase1Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Profil, contacts, métadonnées — disponible immédiatement'**
  String get exportPhase1Subtitle;

  /// No description provided for @exportPhase2Title.
  ///
  /// In fr, this message translates to:
  /// **'Export complet'**
  String get exportPhase2Title;

  /// No description provided for @exportPhase2Subtitle.
  ///
  /// In fr, this message translates to:
  /// **'Inclut messages et médias — prêt sous ~24 h'**
  String get exportPhase2Subtitle;

  /// No description provided for @exportRequestPhase1.
  ///
  /// In fr, this message translates to:
  /// **'Exporter maintenant'**
  String get exportRequestPhase1;

  /// No description provided for @exportRequestPhase2.
  ///
  /// In fr, this message translates to:
  /// **'Demander l\'export complet'**
  String get exportRequestPhase2;

  /// No description provided for @exportPhase1ReadyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Export prêt'**
  String get exportPhase1ReadyTitle;

  /// No description provided for @exportPhase2Started.
  ///
  /// In fr, this message translates to:
  /// **'Export complet demandé — vous serez notifié'**
  String get exportPhase2Started;

  /// No description provided for @exportInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Export en cours'**
  String get exportInProgress;

  /// No description provided for @exportInProgressHint.
  ///
  /// In fr, this message translates to:
  /// **'Prêt dans ~24 h · notification à l\'achèvement'**
  String get exportInProgressHint;

  /// No description provided for @exportReady.
  ///
  /// In fr, this message translates to:
  /// **'Votre export est prêt'**
  String get exportReady;

  /// No description provided for @exportDownload.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger'**
  String get exportDownload;

  /// No description provided for @exportFailed.
  ///
  /// In fr, this message translates to:
  /// **'Export impossible : {error}'**
  String exportFailed(String error);

  /// No description provided for @deleteAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountEntrySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Action irréversible'**
  String get deleteAccountEntrySubtitle;

  /// No description provided for @deleteAccountStep1Title.
  ///
  /// In fr, this message translates to:
  /// **'Action irréversible'**
  String get deleteAccountStep1Title;

  /// No description provided for @deleteAccountStep1Bullet1.
  ///
  /// In fr, this message translates to:
  /// **'Suppression des messages et médias'**
  String get deleteAccountStep1Bullet1;

  /// No description provided for @deleteAccountStep1Bullet2.
  ///
  /// In fr, this message translates to:
  /// **'Retrait de tous les groupes'**
  String get deleteAccountStep1Bullet2;

  /// No description provided for @deleteAccountStep1Bullet3.
  ///
  /// In fr, this message translates to:
  /// **'Numéro libéré après la période de grâce'**
  String get deleteAccountStep1Bullet3;

  /// No description provided for @deleteAccountContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get deleteAccountContinue;

  /// No description provided for @deleteAccountPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get deleteAccountPassword;

  /// No description provided for @deleteAccountConfirmLabel.
  ///
  /// In fr, this message translates to:
  /// **'Taper SUPPRIMER'**
  String get deleteAccountConfirmLabel;

  /// No description provided for @deleteAccountConfirmWord.
  ///
  /// In fr, this message translates to:
  /// **'SUPPRIMER'**
  String get deleteAccountConfirmWord;

  /// No description provided for @deleteAccountConfirmMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Tapez SUPPRIMER pour confirmer'**
  String get deleteAccountConfirmMismatch;

  /// No description provided for @deleteAccountSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccountSubmit;

  /// No description provided for @deleteAccountGraceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suppression planifiée'**
  String get deleteAccountGraceTitle;

  /// No description provided for @deleteAccountGraceBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte sera définitivement supprimé le {date}. Vous pouvez annuler d\'ici là.'**
  String deleteAccountGraceBody(String date);

  /// No description provided for @deleteAccountFailed.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible : {error}'**
  String deleteAccountFailed(String error);

  /// No description provided for @biometricLock.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage biométrique'**
  String get biometricLock;

  /// No description provided for @biometricLockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alanya est verrouillé'**
  String get biometricLockTitle;

  /// No description provided for @biometricLockUnlock.
  ///
  /// In fr, this message translates to:
  /// **'Déverrouiller'**
  String get biometricLockUnlock;

  /// No description provided for @biometricLockSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte ou reconnaissance faciale à l\'ouverture'**
  String get biometricLockSubtitle;

  /// No description provided for @biometricLockEnableConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre empreinte pour activer le verrou'**
  String get biometricLockEnableConfirm;

  /// No description provided for @biometricLockUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Biométrie indisponible sur cet appareil'**
  String get biometricLockUnavailable;

  /// No description provided for @biometricLockFailed.
  ///
  /// In fr, this message translates to:
  /// **'Biométrie : {error}'**
  String biometricLockFailed(String error);

  /// No description provided for @accountSecuritySectionProtection.
  ///
  /// In fr, this message translates to:
  /// **'Protection'**
  String get accountSecuritySectionProtection;

  /// No description provided for @logoutAllDevices.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter tous les appareils'**
  String get logoutAllDevices;

  /// No description provided for @logoutAllDevicesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ferme toutes les sessions sauf celle-ci'**
  String get logoutAllDevicesSubtitle;

  /// No description provided for @logoutAllDevicesConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Tous les autres appareils seront déconnectés immédiatement.'**
  String get logoutAllDevicesConfirm;

  /// No description provided for @logoutAllDevicesAction.
  ///
  /// In fr, this message translates to:
  /// **'Déconnecter'**
  String get logoutAllDevicesAction;

  /// No description provided for @logoutAllDevicesDone.
  ///
  /// In fr, this message translates to:
  /// **'Autres appareils déconnectés'**
  String get logoutAllDevicesDone;

  /// No description provided for @logoutAllDevicesFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de déconnecter tous les appareils'**
  String get logoutAllDevicesFailed;

  /// No description provided for @privacySectionWhoCanSee.
  ///
  /// In fr, this message translates to:
  /// **'Qui peut me voir'**
  String get privacySectionWhoCanSee;

  /// No description provided for @privacySectionMessages.
  ///
  /// In fr, this message translates to:
  /// **'Messages'**
  String get privacySectionMessages;

  /// No description provided for @privacySectionLists.
  ///
  /// In fr, this message translates to:
  /// **'Listes et groupes'**
  String get privacySectionLists;

  /// No description provided for @privacyLastSeen.
  ///
  /// In fr, this message translates to:
  /// **'Dernière connexion'**
  String get privacyLastSeen;

  /// No description provided for @privacyOnlineStatus.
  ///
  /// In fr, this message translates to:
  /// **'Statut en ligne'**
  String get privacyOnlineStatus;

  /// No description provided for @privacyProfilePhoto.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get privacyProfilePhoto;

  /// No description provided for @privacyReadReceipts.
  ///
  /// In fr, this message translates to:
  /// **'Accusés de lecture'**
  String get privacyReadReceipts;

  /// No description provided for @privacyReadReceiptsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer et recevoir les confirmations de lecture'**
  String get privacyReadReceiptsSubtitle;

  /// No description provided for @privacyNotificationPreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu des notifications'**
  String get privacyNotificationPreview;

  /// No description provided for @privacyBlockedContacts.
  ///
  /// In fr, this message translates to:
  /// **'Contacts bloqués'**
  String get privacyBlockedContacts;

  /// No description provided for @privacyBlockedContactsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun contact bloqué'**
  String get privacyBlockedContactsEmpty;

  /// No description provided for @privacyBlockedContactsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 contact} other{{count} contacts}}'**
  String privacyBlockedContactsCount(int count);

  /// No description provided for @privacyAddToGroups.
  ///
  /// In fr, this message translates to:
  /// **'Ajout aux groupes'**
  String get privacyAddToGroups;

  /// No description provided for @privacyVisibilityEveryone.
  ///
  /// In fr, this message translates to:
  /// **'Tout le monde'**
  String get privacyVisibilityEveryone;

  /// No description provided for @privacyVisibilityContacts.
  ///
  /// In fr, this message translates to:
  /// **'Mes contacts'**
  String get privacyVisibilityContacts;

  /// No description provided for @privacyVisibilityNobody.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get privacyVisibilityNobody;

  /// No description provided for @privacySaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer les préglages'**
  String get privacySaveFailed;

  /// No description provided for @onboardingCredentialsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vos identifiants'**
  String get onboardingCredentialsTitle;

  /// No description provided for @onboardingCredentialsSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Conservez ces informations en lieu sûr.'**
  String get onboardingCredentialsSubtitle;

  /// No description provided for @onboardingCredentialsBanner.
  ///
  /// In fr, this message translates to:
  /// **'Notez votre numéro Alanya et votre mot de passe — ils ne seront plus affichés.'**
  String get onboardingCredentialsBanner;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre profil'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Photo, genre, âge, pays, bio : complétez maintenant ou plus tard dans Mon compte.'**
  String get onboardingProfileSubtitle;

  /// No description provided for @profileBioDefault.
  ///
  /// In fr, this message translates to:
  /// **'Salut, je suis sur Alanya'**
  String get profileBioDefault;

  /// No description provided for @onboardingPersonalizeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Personnaliser Alanya'**
  String get onboardingPersonalizeTitle;

  /// No description provided for @onboardingPersonalizeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Thème, langue et verrouillage. Modifiable à tout moment dans Paramètres.'**
  String get onboardingPersonalizeSubtitle;

  /// No description provided for @onboardingStepOf.
  ///
  /// In fr, this message translates to:
  /// **'Étape {current} sur {total}'**
  String onboardingStepOf(int current, int total);

  /// No description provided for @onboardingCountryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre pays'**
  String get onboardingCountryTitle;

  /// No description provided for @onboardingCountrySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Aide vos contacts à vous identifier.'**
  String get onboardingCountrySubtitle;

  /// No description provided for @onboardingPhotoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Photo de profil'**
  String get onboardingPhotoTitle;

  /// No description provided for @onboardingPhotoSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez une photo ou passez cette étape.'**
  String get onboardingPhotoSubtitle;

  /// No description provided for @onboardingPhotoChooseGallery.
  ///
  /// In fr, this message translates to:
  /// **'Choisir dans la galerie'**
  String get onboardingPhotoChooseGallery;

  /// No description provided for @onboardingPhotoCamera.
  ///
  /// In fr, this message translates to:
  /// **'Prendre une photo'**
  String get onboardingPhotoCamera;

  /// No description provided for @onboardingPhotoFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter la photo'**
  String get onboardingPhotoFailed;

  /// No description provided for @onboardingBioTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quelques mots sur vous'**
  String get onboardingBioTitle;

  /// No description provided for @onboardingBioSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Présentez-vous en une phrase (optionnel).'**
  String get onboardingBioSubtitle;

  /// No description provided for @onboardingBioHint.
  ///
  /// In fr, this message translates to:
  /// **'Salut, je suis sur Alanya'**
  String get onboardingBioHint;

  /// No description provided for @onboardingPreferencesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Préférences'**
  String get onboardingPreferencesTitle;

  /// No description provided for @onboardingPreferencesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Thème et langue de l\'application.'**
  String get onboardingPreferencesSubtitle;

  /// No description provided for @onboardingThemeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get onboardingThemeLabel;

  /// No description provided for @onboardingLanguageLabel.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get onboardingLanguageLabel;

  /// No description provided for @onboardingBiometricTitle.
  ///
  /// In fr, this message translates to:
  /// **'Protéger l\'accès'**
  String get onboardingBiometricTitle;

  /// No description provided for @onboardingBiometricSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Un geste rapide à chaque retour dans l\'app.'**
  String get onboardingBiometricSubtitle;

  /// No description provided for @onboardingBiometricFriendlyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte ou reconnaissance faciale'**
  String get onboardingBiometricFriendlyTitle;

  /// No description provided for @onboardingBiometricFriendlyBody.
  ///
  /// In fr, this message translates to:
  /// **'Activez le déverrouillage rapide. Vous pourrez le modifier dans Paramètres.'**
  String get onboardingBiometricFriendlyBody;

  /// No description provided for @onboardingBiometricUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Biométrie indisponible — vous pourrez l\'activer plus tard dans les paramètres.'**
  String get onboardingBiometricUnavailable;

  /// No description provided for @onboardingCompleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'C\'est parti !'**
  String get onboardingCompleteTitle;

  /// No description provided for @onboardingCompleteSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre compte est prêt.'**
  String get onboardingCompleteSubtitle;

  /// No description provided for @onboardingCompleteMessage.
  ///
  /// In fr, this message translates to:
  /// **'Explorez Alanya et restez connecté avec vos proches.'**
  String get onboardingCompleteMessage;

  /// No description provided for @onboardingCompleteCta.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir Alanya'**
  String get onboardingCompleteCta;

  /// No description provided for @onboardingContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get onboardingContinue;

  /// No description provided for @onboardingSkip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get onboardingSkip;

  /// No description provided for @onboardingSkipAll.
  ///
  /// In fr, this message translates to:
  /// **'Configurer plus tard'**
  String get onboardingSkipAll;

  /// No description provided for @onboardingSkipAllTitle.
  ///
  /// In fr, this message translates to:
  /// **'Passer la configuration ?'**
  String get onboardingSkipAllTitle;

  /// No description provided for @onboardingSkipAllBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez compléter votre profil à tout moment dans Mon compte.'**
  String get onboardingSkipAllBody;

  /// No description provided for @onboardingSkipAllCredentialsBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne reverrez plus votre mot de passe ici. Complétez votre profil quand vous voulez dans Mon compte.'**
  String get onboardingSkipAllCredentialsBody;

  /// No description provided for @onboardingSkipAllRecoveryBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne reverrez plus votre mot de passe ici, et votre code de récupération ne réapparaîtra que dans Mon compte → Sécurité. Notez-les avant de continuer.'**
  String get onboardingSkipAllRecoveryBody;

  /// No description provided for @onboardingSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement impossible — réessayez ou passez cette étape.'**
  String get onboardingSaveFailed;

  /// No description provided for @onboardingCredentialsBannerNoEmail.
  ///
  /// In fr, this message translates to:
  /// **'Notez votre numéro Alanya, votre mot de passe et votre code de récupération — ils ne seront plus affichés ici.'**
  String get onboardingCredentialsBannerNoEmail;

  /// No description provided for @onboardingPhotoAdd.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez pour ajouter une photo'**
  String get onboardingPhotoAdd;

  /// No description provided for @onboardingIdentityTitle.
  ///
  /// In fr, this message translates to:
  /// **'À propos de vous'**
  String get onboardingIdentityTitle;

  /// No description provided for @onboardingIdentitySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Genre et âge ne seront plus modifiables une fois enregistrés.'**
  String get onboardingIdentitySubtitle;

  /// No description provided for @profileGenderLabel.
  ///
  /// In fr, this message translates to:
  /// **'Genre'**
  String get profileGenderLabel;

  /// No description provided for @profileIdentitySection.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get profileIdentitySection;

  /// No description provided for @profileGenderSegmentPreferNotSay.
  ///
  /// In fr, this message translates to:
  /// **'Ne pas dire'**
  String get profileGenderSegmentPreferNotSay;

  /// No description provided for @profileGenderMale.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get profileGenderMale;

  /// No description provided for @profileGenderFemale.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get profileGenderFemale;

  /// No description provided for @profileGenderOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get profileGenderOther;

  /// No description provided for @profileGenderUnspecified.
  ///
  /// In fr, this message translates to:
  /// **'Je préfère ne pas dire'**
  String get profileGenderUnspecified;

  /// No description provided for @profileAgeLabel.
  ///
  /// In fr, this message translates to:
  /// **'Âge'**
  String get profileAgeLabel;

  /// No description provided for @profileAgeSuffix.
  ///
  /// In fr, this message translates to:
  /// **'ans'**
  String get profileAgeSuffix;

  /// No description provided for @profileAgeBirthYear.
  ///
  /// In fr, this message translates to:
  /// **'Année de naissance ≈ {year}'**
  String profileAgeBirthYear(int year);

  /// No description provided for @profileAgeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Âge invalide (entre {min} et {max} ans)'**
  String profileAgeInvalid(int min, int max);

  /// No description provided for @recoveryCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération'**
  String get recoveryCodeTitle;

  /// No description provided for @recoveryCodeKeepSafe.
  ///
  /// In fr, this message translates to:
  /// **'À conserver'**
  String get recoveryCodeKeepSafe;

  /// No description provided for @recoveryCodeOnboardingHint.
  ///
  /// In fr, this message translates to:
  /// **'Sans adresse e-mail, ce code est votre seule façon de reprendre la main sur votre compte. Notez-le ailleurs que sur ce téléphone.'**
  String get recoveryCodeOnboardingHint;

  /// No description provided for @recoveryCodeCopied.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération copié'**
  String get recoveryCodeCopied;

  /// No description provided for @recoveryCodeEntrySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser votre mot de passe sans e-mail'**
  String get recoveryCodeEntrySubtitle;

  /// No description provided for @recoveryCodeIntro.
  ///
  /// In fr, this message translates to:
  /// **'Ce code réinitialise votre mot de passe sans passer par un e-mail. Il ne change jamais, même après un changement de mot de passe.'**
  String get recoveryCodeIntro;

  /// No description provided for @recoveryCodeSecurityWarning.
  ///
  /// In fr, this message translates to:
  /// **'Toute personne connaissant ce code et votre ID Alanya peut changer votre mot de passe. Ne le partagez avec personne.'**
  String get recoveryCodeSecurityWarning;

  /// No description provided for @recoveryCodeReveal.
  ///
  /// In fr, this message translates to:
  /// **'Afficher le code'**
  String get recoveryCodeReveal;

  /// No description provided for @recoveryCodeHide.
  ///
  /// In fr, this message translates to:
  /// **'Masquer'**
  String get recoveryCodeHide;

  /// No description provided for @recoveryCodePasswordPrompt.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre mot de passe pour afficher le code.'**
  String get recoveryCodePasswordPrompt;

  /// No description provided for @recoveryCodeRevealFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'afficher le code'**
  String get recoveryCodeRevealFailed;

  /// No description provided for @forgotMethodTitle.
  ///
  /// In fr, this message translates to:
  /// **'Récupérer votre compte'**
  String get forgotMethodTitle;

  /// No description provided for @forgotMethodSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Comment souhaitez-vous procéder ?'**
  String get forgotMethodSubtitle;

  /// No description provided for @forgotMethodEmail.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai une adresse e-mail'**
  String get forgotMethodEmail;

  /// No description provided for @forgotMethodEmailSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Recevez un code à 6 chiffres par e-mail.'**
  String get forgotMethodEmailSubtitle;

  /// No description provided for @forgotMethodCode.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai un code de récupération'**
  String get forgotMethodCode;

  /// No description provided for @forgotMethodCodeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le code affiché à la création de votre compte.'**
  String get forgotMethodCodeSubtitle;

  /// No description provided for @forgotCodeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre code de récupération'**
  String get forgotCodeTitle;

  /// No description provided for @forgotCodeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez votre ID Alanya et le code noté à l\'inscription.'**
  String get forgotCodeSubtitle;

  /// No description provided for @forgotCodeHint.
  ///
  /// In fr, this message translates to:
  /// **'XXXX-XXXX-XXXX'**
  String get forgotCodeHint;

  /// No description provided for @forgotCodeSubmit.
  ///
  /// In fr, this message translates to:
  /// **'Valider le code'**
  String get forgotCodeSubmit;

  /// No description provided for @validatorRecoveryCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de récupération à 12 caractères'**
  String get validatorRecoveryCode;

  /// No description provided for @deleteAccountGraceDays.
  ///
  /// In fr, this message translates to:
  /// **'Délai de grâce · {days} jours'**
  String deleteAccountGraceDays(int days);

  /// No description provided for @deleteAccountCancelDeletion.
  ///
  /// In fr, this message translates to:
  /// **'Annuler la suppression'**
  String get deleteAccountCancelDeletion;

  /// No description provided for @deleteAccountCancelSuccess.
  ///
  /// In fr, this message translates to:
  /// **'Suppression annulée'**
  String get deleteAccountCancelSuccess;

  /// No description provided for @deleteAccountCancelFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'annuler la suppression'**
  String get deleteAccountCancelFailed;

  /// No description provided for @deleteAccountLogoutNow.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get deleteAccountLogoutNow;

  /// No description provided for @myMediaEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun média partagé pour le moment'**
  String get myMediaEmpty;

  /// No description provided for @myMediaLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger vos médias'**
  String get myMediaLoadFailed;

  /// No description provided for @dndSummaryActive.
  ///
  /// In fr, this message translates to:
  /// **'{start} – {end} · {days}'**
  String dndSummaryActive(String start, String end, String days);

  /// No description provided for @dndSummaryInactive.
  ///
  /// In fr, this message translates to:
  /// **'Désactivé'**
  String get dndSummaryInactive;

  /// No description provided for @exportPhase1ShareSubject.
  ///
  /// In fr, this message translates to:
  /// **'Export Alanya (profil et métadonnées)'**
  String get exportPhase1ShareSubject;

  /// No description provided for @officialContactSupport.
  ///
  /// In fr, this message translates to:
  /// **'Contacter le support'**
  String get officialContactSupport;

  /// No description provided for @officialComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get officialComingSoon;

  /// No description provided for @officialHelpAndFaq.
  ///
  /// In fr, this message translates to:
  /// **'Aide et questions fréquentes'**
  String get officialHelpAndFaq;

  /// No description provided for @officialHelpUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir la page d\'aide'**
  String get officialHelpUnavailable;

  /// No description provided for @listKindFamily.
  ///
  /// In fr, this message translates to:
  /// **'Famille'**
  String get listKindFamily;

  /// No description provided for @listKindFriends.
  ///
  /// In fr, this message translates to:
  /// **'Amis'**
  String get listKindFriends;

  /// No description provided for @listKindWork.
  ///
  /// In fr, this message translates to:
  /// **'Bureau'**
  String get listKindWork;

  /// No description provided for @listKindTrust.
  ///
  /// In fr, this message translates to:
  /// **'Confiance'**
  String get listKindTrust;

  /// No description provided for @contactLists.
  ///
  /// In fr, this message translates to:
  /// **'Listes de contacts'**
  String get contactLists;

  /// No description provided for @contactListsManage.
  ///
  /// In fr, this message translates to:
  /// **'Gérer'**
  String get contactListsManage;

  /// No description provided for @createList.
  ///
  /// In fr, this message translates to:
  /// **'Créer une liste'**
  String get createList;

  /// No description provided for @listName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la liste'**
  String get listName;

  /// No description provided for @listNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Famille, Amis, Bureau…'**
  String get listNameHint;

  /// No description provided for @renameList.
  ///
  /// In fr, this message translates to:
  /// **'Renommer la liste'**
  String get renameList;

  /// No description provided for @deleteList.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la liste'**
  String get deleteList;

  /// No description provided for @deleteListConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ? Vos contacts restent dans vos favoris.'**
  String deleteListConfirm(String name);

  /// No description provided for @listColor.
  ///
  /// In fr, this message translates to:
  /// **'Couleur de la puce'**
  String get listColor;

  /// No description provided for @listNameAlreadyExists.
  ///
  /// In fr, this message translates to:
  /// **'Une liste porte déjà ce nom'**
  String get listNameAlreadyExists;

  /// No description provided for @listSaveFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'enregistrer la liste. Réessayez.'**
  String get listSaveFailed;

  /// No description provided for @listMembersUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier les membres. Réessayez.'**
  String get listMembersUpdateFailed;

  /// No description provided for @listMembersCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun membre} =1{1 membre} other{{count} membres}}'**
  String listMembersCount(int count);

  /// No description provided for @listMembersCountLimited.
  ///
  /// In fr, this message translates to:
  /// **'{current}/{limit} membres'**
  String listMembersCountLimited(int current, int limit);

  /// No description provided for @listMemberLimitReached.
  ///
  /// In fr, this message translates to:
  /// **'Cette liste est limitée à {limit} membres'**
  String listMemberLimitReached(int limit);

  /// No description provided for @addToList.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des membres'**
  String get addToList;

  /// No description provided for @removeFromList.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la liste'**
  String get removeFromList;

  /// No description provided for @createGroupFromList.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe'**
  String get createGroupFromList;

  /// No description provided for @noLists.
  ///
  /// In fr, this message translates to:
  /// **'Aucune liste de contacts'**
  String get noLists;

  /// No description provided for @noListsHint.
  ///
  /// In fr, this message translates to:
  /// **'Rangez vos contacts préférés par Famille, Amis, Bureau…'**
  String get noListsHint;

  /// No description provided for @noListMembers.
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre dans cette liste'**
  String get noListMembers;

  /// No description provided for @noContactToAddToList.
  ///
  /// In fr, this message translates to:
  /// **'Tous vos contacts préférés sont déjà dans cette liste'**
  String get noContactToAddToList;

  /// No description provided for @addMembersSelected.
  ///
  /// In fr, this message translates to:
  /// **'{count} sélectionné(s)'**
  String addMembersSelected(int count);

  /// No description provided for @newList.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle liste'**
  String get newList;

  /// No description provided for @contactListsHint.
  ///
  /// In fr, this message translates to:
  /// **'Une liste ne peut contenir que des contacts déjà en favoris. Un même contact peut appartenir à plusieurs listes.'**
  String get contactListsHint;

  /// No description provided for @notInThisList.
  ///
  /// In fr, this message translates to:
  /// **'Favori — pas dans cette liste'**
  String get notInThisList;

  /// No description provided for @createGroupNamed.
  ///
  /// In fr, this message translates to:
  /// **'Créer un groupe « {name} »'**
  String createGroupNamed(String name);

  /// No description provided for @manageLists.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les listes'**
  String get manageLists;

  /// No description provided for @contactListsSheetSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir une liste, ou en faire un groupe.'**
  String get contactListsSheetSubtitle;

  /// No description provided for @markAllAsRead.
  ///
  /// In fr, this message translates to:
  /// **'Tout marquer comme lu'**
  String get markAllAsRead;

  /// No description provided for @markAllAsReadDone.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune discussion non lue} =1{1 discussion marquée comme lue} other{{count} discussions marquées comme lues}}'**
  String markAllAsReadDone(int count);

  /// No description provided for @optionsAction.
  ///
  /// In fr, this message translates to:
  /// **'Options'**
  String get optionsAction;

  /// No description provided for @trips.
  ///
  /// In fr, this message translates to:
  /// **'Trajets de confiance'**
  String get trips;

  /// No description provided for @tripsCircleEmptyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre cercle de confiance est vide'**
  String get tripsCircleEmptyTitle;

  /// No description provided for @tripsCircleEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez jusqu\'à cinq proches. Eux seuls verront vos trajets, et seulement ceux que vous partagez.'**
  String get tripsCircleEmptyBody;

  /// No description provided for @tripsComposeCircle.
  ///
  /// In fr, this message translates to:
  /// **'Composer mon cercle'**
  String get tripsComposeCircle;

  /// No description provided for @tripsMyCircle.
  ///
  /// In fr, this message translates to:
  /// **'Mon cercle de confiance'**
  String get tripsMyCircle;

  /// No description provided for @tripsNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet en cours.'**
  String get tripsNone;

  /// No description provided for @tripsNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau trajet'**
  String get tripsNew;

  /// No description provided for @tripsKindTaxi.
  ///
  /// In fr, this message translates to:
  /// **'Taxi'**
  String get tripsKindTaxi;

  /// No description provided for @tripsKindTaxiHint.
  ///
  /// In fr, this message translates to:
  /// **'Un déplacement, une arrivée attendue'**
  String get tripsKindTaxiHint;

  /// No description provided for @tripsKindWalk.
  ///
  /// In fr, this message translates to:
  /// **'À pied'**
  String get tripsKindWalk;

  /// No description provided for @tripsKindWalkHint.
  ///
  /// In fr, this message translates to:
  /// **'Un trajet à pied, une arrivée attendue'**
  String get tripsKindWalkHint;

  /// No description provided for @tripsKindMeeting.
  ///
  /// In fr, this message translates to:
  /// **'À pied'**
  String get tripsKindMeeting;

  /// No description provided for @tripsKindMeetingHint.
  ///
  /// In fr, this message translates to:
  /// **'Un trajet à pied, une arrivée attendue'**
  String get tripsKindMeetingHint;

  /// No description provided for @tripsArrivalIn.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée dans'**
  String get tripsArrivalIn;

  /// No description provided for @tripsMinutes.
  ///
  /// In fr, this message translates to:
  /// **'{count} min'**
  String tripsMinutes(int count);

  /// No description provided for @tripsNoteLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note pour le cercle'**
  String get tripsNoteLabel;

  /// No description provided for @tripsNoteHint.
  ///
  /// In fr, this message translates to:
  /// **'Taxi jaune, plaque LT 4471'**
  String get tripsNoteHint;

  /// No description provided for @tripsStart.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer le partage'**
  String get tripsStart;

  /// No description provided for @tripsContract.
  ///
  /// In fr, this message translates to:
  /// **'Vos {count} proches verront votre position en direct jusqu\'à {eta}. Si vous n\'avez pas confirmé à {alert}, ils seront prévenus avec votre dernière position.'**
  String tripsContract(int count, String eta, String alert);

  /// No description provided for @tripsCircleFrozen.
  ///
  /// In fr, this message translates to:
  /// **'Le cercle se modifie dans Profil › Listes de contacts, jamais au départ d\'un trajet. Personne n\'apprend qu\'il y entre ou en sort.'**
  String get tripsCircleFrozen;

  /// No description provided for @tripsInProgress.
  ///
  /// In fr, this message translates to:
  /// **'Trajet en cours'**
  String get tripsInProgress;

  /// No description provided for @tripsLive.
  ///
  /// In fr, this message translates to:
  /// **'En direct'**
  String get tripsLive;

  /// No description provided for @tripsStale.
  ///
  /// In fr, this message translates to:
  /// **'Position indisponible'**
  String get tripsStale;

  /// No description provided for @tripsAwaitingConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée à confirmer'**
  String get tripsAwaitingConfirm;

  /// No description provided for @tripsAlerted.
  ///
  /// In fr, this message translates to:
  /// **'Alerte envoyée'**
  String get tripsAlerted;

  /// No description provided for @tripsWatcherCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 personne suit} other{{count} personnes suivent}}'**
  String tripsWatcherCount(int count);

  /// No description provided for @tripsWatcherFollowedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Personne n\'a suivi} =1{1 personne a suivi} other{{count} personnes ont suivi}}'**
  String tripsWatcherFollowedCount(int count);

  /// No description provided for @tripsEtaAt.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée prévue {time}'**
  String tripsEtaAt(String time);

  /// No description provided for @tripsAlreadyActive.
  ///
  /// In fr, this message translates to:
  /// **'Un trajet est déjà en cours.'**
  String get tripsAlreadyActive;

  /// No description provided for @tripsStartFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de démarrer le trajet.'**
  String get tripsStartFailed;

  /// No description provided for @tripsSosUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Le SOS n\'est pas encore disponible.'**
  String get tripsSosUnavailable;

  /// No description provided for @tripsStop.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter le partage'**
  String get tripsStop;

  /// No description provided for @tripsForegroundOnly.
  ///
  /// In fr, this message translates to:
  /// **'Le partage s\'interrompt si vous quittez Alanya. Vos proches seront prévenus à l\'heure prévue dans tous les cas.'**
  String get tripsForegroundOnly;

  /// No description provided for @tripsCardStarted.
  ///
  /// In fr, this message translates to:
  /// **'{name} a démarré un trajet'**
  String tripsCardStarted(String name);

  /// No description provided for @tripsCardStartedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez démarré un trajet'**
  String get tripsCardStartedByMe;

  /// No description provided for @tripsCardAwaiting.
  ///
  /// In fr, this message translates to:
  /// **'{name} devrait être arrivé·e'**
  String tripsCardAwaiting(String name);

  /// No description provided for @tripsCardAwaitingByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous devriez être arrivé·e'**
  String get tripsCardAwaitingByMe;

  /// No description provided for @tripsCardAlert.
  ///
  /// In fr, this message translates to:
  /// **'{name} n\'a pas confirmé son arrivée'**
  String tripsCardAlert(String name);

  /// No description provided for @tripsCardAlertByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas confirmé votre arrivée'**
  String get tripsCardAlertByMe;

  /// No description provided for @tripsCardSos.
  ///
  /// In fr, this message translates to:
  /// **'{name} a déclenché un SOS'**
  String tripsCardSos(String name);

  /// No description provided for @tripsCardSosByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déclenché un SOS'**
  String get tripsCardSosByMe;

  /// No description provided for @tripsCardArrived.
  ///
  /// In fr, this message translates to:
  /// **'{name} est bien arrivé·e'**
  String tripsCardArrived(String name);

  /// No description provided for @tripsCardArrivedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes bien arrivé·e'**
  String get tripsCardArrivedByMe;

  /// No description provided for @tripsCardStopped.
  ///
  /// In fr, this message translates to:
  /// **'{name} a arrêté le partage'**
  String tripsCardStopped(String name);

  /// No description provided for @tripsCardStoppedByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez arrêté le partage'**
  String get tripsCardStoppedByMe;

  /// No description provided for @tripsCardFollow.
  ///
  /// In fr, this message translates to:
  /// **'Suivre en direct'**
  String get tripsCardFollow;

  /// No description provided for @tripsCardView.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get tripsCardView;

  /// No description provided for @tripsCardSeePosition.
  ///
  /// In fr, this message translates to:
  /// **'Voir la position'**
  String get tripsCardSeePosition;

  /// No description provided for @tripsCardSeeLast.
  ///
  /// In fr, this message translates to:
  /// **'Voir la dernière position'**
  String get tripsCardSeeLast;

  /// No description provided for @tripsCardFallback.
  ///
  /// In fr, this message translates to:
  /// **'Trajet de confiance — mettez à jour l\'application'**
  String get tripsCardFallback;

  /// No description provided for @tripsConfirmArrival.
  ///
  /// In fr, this message translates to:
  /// **'Je suis bien arrivé·e'**
  String get tripsConfirmArrival;

  /// No description provided for @tripsExtendBy.
  ///
  /// In fr, this message translates to:
  /// **'+{count} min'**
  String tripsExtendBy(int count);

  /// No description provided for @tripsExtended.
  ///
  /// In fr, this message translates to:
  /// **'Prolongé de {count} minutes. Votre cercle a été informé.'**
  String tripsExtended(int count);

  /// No description provided for @tripsAlreadyClosed.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet est déjà clos.'**
  String get tripsAlreadyClosed;

  /// No description provided for @tripsActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Action impossible pour le moment.'**
  String get tripsActionFailed;

  /// No description provided for @tripsHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get tripsHistory;

  /// No description provided for @tripsHistoryEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun trajet pour l\'instant'**
  String get tripsHistoryEmpty;

  /// No description provided for @tripsHistoryEmptyBody.
  ///
  /// In fr, this message translates to:
  /// **'Quand vous partagerez un trajet, il apparaîtra ici — et seulement ici.'**
  String get tripsHistoryEmptyBody;

  /// No description provided for @tripsHistoryUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Historique indisponible'**
  String get tripsHistoryUnavailable;

  /// No description provided for @tripsHistoryOnline.
  ///
  /// In fr, this message translates to:
  /// **'Vos trajets passés se consultent en ligne : ils ne sont pas conservés sur cet appareil.'**
  String get tripsHistoryOnline;

  /// No description provided for @tripsRetentionNote.
  ///
  /// In fr, this message translates to:
  /// **'Vos trajets sont conservés douze mois. Les traces détaillées, vingt-quatre heures — trente jours après une alerte.'**
  String get tripsRetentionNote;

  /// No description provided for @tripsOutcomeConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée confirmée'**
  String get tripsOutcomeConfirmed;

  /// No description provided for @tripsOutcomeStopped.
  ///
  /// In fr, this message translates to:
  /// **'Trajet arrêté'**
  String get tripsOutcomeStopped;

  /// No description provided for @tripsOutcomeAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte déclenchée'**
  String get tripsOutcomeAlert;

  /// No description provided for @tripsDeleteLocked.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet est conservé trente jours après une alerte. Cette règle protège la personne concernée.'**
  String get tripsDeleteLocked;

  /// No description provided for @loadMore.
  ///
  /// In fr, this message translates to:
  /// **'Charger plus'**
  String get loadMore;

  /// No description provided for @tripsFgsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trajet de confiance en cours'**
  String get tripsFgsTitle;

  /// No description provided for @tripsFgsBodyPlain.
  ///
  /// In fr, this message translates to:
  /// **'Votre position est partagée avec votre cercle'**
  String get tripsFgsBodyPlain;

  /// No description provided for @tripsFgsBody.
  ///
  /// In fr, this message translates to:
  /// **'Partagé avec {names}'**
  String tripsFgsBody(String names);

  /// No description provided for @tripsSosTitle.
  ///
  /// In fr, this message translates to:
  /// **'SOS'**
  String get tripsSosTitle;

  /// No description provided for @tripsSosHold.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez pour lancer le SOS'**
  String get tripsSosHold;

  /// No description provided for @tripsSosHoldBody.
  ///
  /// In fr, this message translates to:
  /// **'Le compte à rebours commence immédiatement et vous pouvez annuler avant l\'envoi.'**
  String get tripsSosHoldBody;

  /// No description provided for @tripsSosNotEmergency.
  ///
  /// In fr, this message translates to:
  /// **'Le SOS ne prévient pas les secours. Il prévient votre cercle de confiance.'**
  String get tripsSosNotEmergency;

  /// No description provided for @tripsSosSending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi dans {count} secondes'**
  String tripsSosSending(int count);

  /// No description provided for @tripsSosSendingNow.
  ///
  /// In fr, this message translates to:
  /// **'Envoi en cours…'**
  String get tripsSosSendingNow;

  /// No description provided for @tripsSosSendingNowBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos proches seront prévenus dans un instant.'**
  String get tripsSosSendingNowBody;

  /// No description provided for @tripsSosSent.
  ///
  /// In fr, this message translates to:
  /// **'Vos proches ont été prévenus'**
  String get tripsSosSent;

  /// No description provided for @tripsSosDiscreet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun son, aucune vibration. Votre position continue d\'être partagée.'**
  String get tripsSosDiscreet;

  /// No description provided for @tripsSosActive.
  ///
  /// In fr, this message translates to:
  /// **'Partage actif'**
  String get tripsSosActive;

  /// No description provided for @tripsSosActiveBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre position est partagée. Aucun son, aucune vibration.'**
  String get tripsSosActiveBody;

  /// No description provided for @tripsSosTooMany.
  ///
  /// In fr, this message translates to:
  /// **'Trop de SOS sur les dernières 24 heures.'**
  String get tripsSosTooMany;

  /// No description provided for @tripsSosFalseAlarm.
  ///
  /// In fr, this message translates to:
  /// **'Fausse alerte, je vais bien'**
  String get tripsSosFalseAlarm;

  /// No description provided for @tripsSosButton.
  ///
  /// In fr, this message translates to:
  /// **'Lancer un SOS'**
  String get tripsSosButton;

  /// No description provided for @tripsKeepsRunning.
  ///
  /// In fr, this message translates to:
  /// **'Le partage continue même écran verrouillé. Une notification vous le rappelle et permet de l\'arrêter.'**
  String get tripsKeepsRunning;

  /// No description provided for @tripsDestination.
  ///
  /// In fr, this message translates to:
  /// **'Destination'**
  String get tripsDestination;

  /// No description provided for @tripsDestinationOptional.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une destination (facultatif)'**
  String get tripsDestinationOptional;

  /// No description provided for @tripsDestinationRadius.
  ///
  /// In fr, this message translates to:
  /// **'L\'arrivée sera détectée dans un rayon de 100 m'**
  String get tripsDestinationRadius;

  /// No description provided for @tripsShort.
  ///
  /// In fr, this message translates to:
  /// **'Confiance'**
  String get tripsShort;

  /// No description provided for @tripsRailStart.
  ///
  /// In fr, this message translates to:
  /// **'Partir'**
  String get tripsRailStart;

  /// No description provided for @tripsRailFollow.
  ///
  /// In fr, this message translates to:
  /// **'Suivre'**
  String get tripsRailFollow;

  /// No description provided for @tripsRailConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get tripsRailConfirm;

  /// No description provided for @tripsRailClose.
  ///
  /// In fr, this message translates to:
  /// **'Clore'**
  String get tripsRailClose;

  /// No description provided for @tripsConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée confirmée. Votre cercle est prévenu.'**
  String get tripsConfirmed;

  /// No description provided for @tripsDeleteTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce trajet ?'**
  String get tripsDeleteTitle;

  /// No description provided for @tripsDeleteBody.
  ///
  /// In fr, this message translates to:
  /// **'Le trajet et sa trace seront effacés. Cette action est définitive.'**
  String get tripsDeleteBody;

  /// No description provided for @tripsRecenter.
  ///
  /// In fr, this message translates to:
  /// **'Recentrer sur la position'**
  String get tripsRecenter;

  /// No description provided for @tripsMapExpand.
  ///
  /// In fr, this message translates to:
  /// **'Plein écran'**
  String get tripsMapExpand;

  /// No description provided for @tripsMapReduce.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get tripsMapReduce;

  /// No description provided for @tripsMapFitBounds.
  ///
  /// In fr, this message translates to:
  /// **'Voir position et destination'**
  String get tripsMapFitBounds;

  /// No description provided for @tripsDestinationSafetyNet.
  ///
  /// In fr, this message translates to:
  /// **'Avec une destination, on vous demandera de confirmer dès l\'arrivée — pas seulement à l\'heure.'**
  String get tripsDestinationSafetyNet;

  /// No description provided for @tripsDistanceM.
  ///
  /// In fr, this message translates to:
  /// **'~{meters} m'**
  String tripsDistanceM(int meters);

  /// No description provided for @tripsDistanceKm.
  ///
  /// In fr, this message translates to:
  /// **'~{km} km'**
  String tripsDistanceKm(double km);

  /// No description provided for @tripsUpdatedAgo.
  ///
  /// In fr, this message translates to:
  /// **'maj il y a {age}'**
  String tripsUpdatedAgo(String age);

  /// No description provided for @tripsPositionFrozen.
  ///
  /// In fr, this message translates to:
  /// **'Position figée'**
  String get tripsPositionFrozen;

  /// No description provided for @tripsDeleteLockedHint.
  ///
  /// In fr, this message translates to:
  /// **'Conservé 30 jours après une alerte'**
  String get tripsDeleteLockedHint;

  /// No description provided for @tripsEventWatcherSeenGroup.
  ///
  /// In fr, this message translates to:
  /// **'{count} proches ont vu'**
  String tripsEventWatcherSeenGroup(int count);

  /// No description provided for @tripsArrivalReachedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes arrivé·e ?'**
  String get tripsArrivalReachedTitle;

  /// No description provided for @tripsArrivalReachedBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous êtes à votre destination depuis une minute.'**
  String get tripsArrivalReachedBody;

  /// No description provided for @tripsArrivalDueTitle.
  ///
  /// In fr, this message translates to:
  /// **'Confirmez votre arrivée'**
  String get tripsArrivalDueTitle;

  /// No description provided for @tripsArrivalDueBody.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse, vos proches seront prévenus à {time} avec votre dernière position.'**
  String tripsArrivalDueBody(String time);

  /// No description provided for @tripsArrivalDueBodyPlain.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse, vos proches seront prévenus avec votre dernière position.'**
  String get tripsArrivalDueBodyPlain;

  /// No description provided for @tripsArrivalLater.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore — l\'échéance continue de courir'**
  String get tripsArrivalLater;

  /// No description provided for @tripsDegradedPermission.
  ///
  /// In fr, this message translates to:
  /// **'Localisation désactivée'**
  String get tripsDegradedPermission;

  /// No description provided for @tripsDegradedPermissionBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos proches ne voient plus votre position. L\'heure d\'arrivée reste surveillée : ils seront prévenus si vous ne confirmez pas.'**
  String get tripsDegradedPermissionBody;

  /// No description provided for @tripsDegradedStale.
  ///
  /// In fr, this message translates to:
  /// **'Position indisponible'**
  String get tripsDegradedStale;

  /// No description provided for @tripsDegradedStaleBody.
  ///
  /// In fr, this message translates to:
  /// **'Tunnel, parking ou signal faible. Ce n\'est pas une alerte — l\'échéance continue de courir.'**
  String get tripsDegradedStaleBody;

  /// No description provided for @tripsDegradedBattery.
  ///
  /// In fr, this message translates to:
  /// **'Batterie faible'**
  String get tripsDegradedBattery;

  /// No description provided for @tripsDegradedBatteryBody.
  ///
  /// In fr, this message translates to:
  /// **'Le suivi est ralenti. Si le téléphone s\'éteint, votre dernière position sera envoyée.'**
  String get tripsDegradedBatteryBody;

  /// No description provided for @tripsDegradedFix.
  ///
  /// In fr, this message translates to:
  /// **'Réparer'**
  String get tripsDegradedFix;

  /// No description provided for @locationSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un lieu, une adresse…'**
  String get locationSearchHint;

  /// No description provided for @locationSearchEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat. Vous pouvez toujours choisir sur la carte.'**
  String get locationSearchEmpty;

  /// No description provided for @locationSearchUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'La recherche est indisponible. Vérifiez votre connexion et réessayez.'**
  String get locationSearchUnavailable;

  /// No description provided for @locationPickerChooseDestination.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une destination'**
  String get locationPickerChooseDestination;

  /// No description provided for @locationPickerUseDestination.
  ///
  /// In fr, this message translates to:
  /// **'Choisir cette destination'**
  String get locationPickerUseDestination;

  /// No description provided for @locationUseMyPosition.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser ma position'**
  String get locationUseMyPosition;

  /// No description provided for @locationPickerInstruction.
  ///
  /// In fr, this message translates to:
  /// **'Recherchez, déplacez la carte ou utilisez votre position'**
  String get locationPickerInstruction;

  /// No description provided for @tripsCardFalseAlarm.
  ///
  /// In fr, this message translates to:
  /// **'{name} a signalé une fausse alerte'**
  String tripsCardFalseAlarm(String name);

  /// No description provided for @tripsCardFalseAlarmByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez signalé une fausse alerte'**
  String get tripsCardFalseAlarmByMe;

  /// No description provided for @tripsSosFalseAlarmSent.
  ///
  /// In fr, this message translates to:
  /// **'Votre cercle a été prévenu que tout va bien.'**
  String get tripsSosFalseAlarmSent;

  /// No description provided for @tripsCall.
  ///
  /// In fr, this message translates to:
  /// **'Appeler'**
  String get tripsCall;

  /// No description provided for @tripsPermissionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser la localisation'**
  String get tripsPermissionTitle;

  /// No description provided for @tripsPermissionBody.
  ///
  /// In fr, this message translates to:
  /// **'Sans cette autorisation, vos proches ne verront pas où vous êtes. L\'heure d\'arrivée reste surveillée dans tous les cas.'**
  String get tripsPermissionBody;

  /// No description provided for @tripsPermissionNever.
  ///
  /// In fr, this message translates to:
  /// **'Alanya n\'utilise votre position que pendant un trajet que vous avez démarré. Jamais avant, jamais après.'**
  String get tripsPermissionNever;

  /// No description provided for @tripsPermissionAllow.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get tripsPermissionAllow;

  /// No description provided for @tripsPermissionLater.
  ///
  /// In fr, this message translates to:
  /// **'Plus tard'**
  String get tripsPermissionLater;

  /// No description provided for @sysTripAlert.
  ///
  /// In fr, this message translates to:
  /// **'{actor} n\'a pas confirmé son arrivée — le cercle a été prévenu'**
  String sysTripAlert(String actor);

  /// No description provided for @sysTripAlertByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas confirmé votre arrivée — votre cercle a été prévenu'**
  String get sysTripAlertByMe;

  /// No description provided for @sysTripSos.
  ///
  /// In fr, this message translates to:
  /// **'{actor} a déclenché un SOS'**
  String sysTripSos(String actor);

  /// No description provided for @sysTripSosByMe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déclenché un SOS'**
  String get sysTripSosByMe;

  /// No description provided for @tripsPreviewActive.
  ///
  /// In fr, this message translates to:
  /// **'🧭 Trajet en cours'**
  String get tripsPreviewActive;

  /// No description provided for @tripsPreviewAwaiting.
  ///
  /// In fr, this message translates to:
  /// **'🧭 Arrivée à confirmer'**
  String get tripsPreviewAwaiting;

  /// No description provided for @tripsPreviewAlert.
  ///
  /// In fr, this message translates to:
  /// **'🆘 Alerte trajet'**
  String get tripsPreviewAlert;

  /// No description provided for @tripsPreviewSos.
  ///
  /// In fr, this message translates to:
  /// **'🆘 SOS'**
  String get tripsPreviewSos;

  /// No description provided for @tripsPreviewConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'✅ Bien arrivé·e'**
  String get tripsPreviewConfirmed;

  /// No description provided for @tripsPreviewStopped.
  ///
  /// In fr, this message translates to:
  /// **'🧭 Trajet arrêté'**
  String get tripsPreviewStopped;

  /// No description provided for @tripsPreviewFalseAlarm.
  ///
  /// In fr, this message translates to:
  /// **'✅ Fausse alerte'**
  String get tripsPreviewFalseAlarm;

  /// No description provided for @tripsAlertChannelName.
  ///
  /// In fr, this message translates to:
  /// **'Alertes de trajet'**
  String get tripsAlertChannelName;

  /// No description provided for @tripsAlertChannelBody.
  ///
  /// In fr, this message translates to:
  /// **'Un proche n\'a pas confirmé son arrivée, ou a déclenché un SOS. Ces alertes traversent le mode silencieux.'**
  String get tripsAlertChannelBody;

  /// No description provided for @tripsChannelName.
  ///
  /// In fr, this message translates to:
  /// **'Trajets de confiance'**
  String get tripsChannelName;

  /// No description provided for @tripsChannelBody.
  ///
  /// In fr, this message translates to:
  /// **'Rappels de confirmation d\'arrivée, pour vos propres trajets.'**
  String get tripsChannelBody;

  /// No description provided for @tripsRevokeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer {name} ?'**
  String tripsRevokeTitle(String name);

  /// No description provided for @tripsRevokeBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne cessera de voir votre position et l\'état de ce trajet. Elle n\'en sera pas informée.'**
  String get tripsRevokeBody;

  /// No description provided for @tripsRevokeAction.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get tripsRevokeAction;

  /// No description provided for @tripsWatchersNoneSeen.
  ///
  /// In fr, this message translates to:
  /// **'Personne n\'a encore ouvert'**
  String get tripsWatchersNoneSeen;

  /// No description provided for @tripsWatchersSeenCount.
  ///
  /// In fr, this message translates to:
  /// **'{seen} sur {total} ont vu'**
  String tripsWatchersSeenCount(int seen, int total);

  /// No description provided for @tripsWatcherSeen.
  ///
  /// In fr, this message translates to:
  /// **'a vu'**
  String get tripsWatcherSeen;

  /// No description provided for @tripsOtherDeviceTitle.
  ///
  /// In fr, this message translates to:
  /// **'Trajet en cours sur votre autre appareil'**
  String get tripsOtherDeviceTitle;

  /// No description provided for @tripsOtherDeviceBody.
  ///
  /// In fr, this message translates to:
  /// **'Un seul appareil envoie la position, sinon la trace sauterait d\'un endroit à l\'autre.'**
  String get tripsOtherDeviceBody;

  /// No description provided for @tripsOtherDeviceTake.
  ///
  /// In fr, this message translates to:
  /// **'Suivre depuis cet appareil'**
  String get tripsOtherDeviceTake;

  /// No description provided for @tripsOtherDeviceKeep.
  ///
  /// In fr, this message translates to:
  /// **'Rester en lecture seule'**
  String get tripsOtherDeviceKeep;

  /// No description provided for @tripsNoLongerShared.
  ///
  /// In fr, this message translates to:
  /// **'Ce trajet n\'est plus partagé avec vous'**
  String get tripsNoLongerShared;

  /// No description provided for @tripsNoLongerSharedBody.
  ///
  /// In fr, this message translates to:
  /// **'Il a pu être clos, ou vous en avez été retiré. Aucune autre information n\'est donnée.'**
  String get tripsNoLongerSharedBody;

  /// No description provided for @tripsLiveEndedArrived.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée confirmée'**
  String get tripsLiveEndedArrived;

  /// No description provided for @tripsLiveEndedStopped.
  ///
  /// In fr, this message translates to:
  /// **'Le partage est terminé'**
  String get tripsLiveEndedStopped;

  /// No description provided for @tripsLiveEndedBody.
  ///
  /// In fr, this message translates to:
  /// **'Le partage de position est terminé.'**
  String get tripsLiveEndedBody;

  /// No description provided for @tripsDetailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détail du trajet'**
  String get tripsDetailTitle;

  /// No description provided for @tripsDetailTimeline.
  ///
  /// In fr, this message translates to:
  /// **'Frise'**
  String get tripsDetailTimeline;

  /// No description provided for @tripsDetailNoEvents.
  ///
  /// In fr, this message translates to:
  /// **'Aucun événement enregistré.'**
  String get tripsDetailNoEvents;

  /// No description provided for @tripsTraceExpired.
  ///
  /// In fr, this message translates to:
  /// **'Trace expirée'**
  String get tripsTraceExpired;

  /// No description provided for @tripsTraceExpiredBody.
  ///
  /// In fr, this message translates to:
  /// **'Les positions de ce trajet ont été purgées. Le résumé et la frise restent disponibles.'**
  String get tripsTraceExpiredBody;

  /// No description provided for @tripsEventStarted.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get tripsEventStarted;

  /// No description provided for @tripsEventExtended.
  ///
  /// In fr, this message translates to:
  /// **'Prolongation'**
  String get tripsEventExtended;

  /// No description provided for @tripsEventArrivalDetected.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée détectée'**
  String get tripsEventArrivalDetected;

  /// No description provided for @tripsEventEtaDue.
  ///
  /// In fr, this message translates to:
  /// **'Échéance atteinte'**
  String get tripsEventEtaDue;

  /// No description provided for @tripsEventAlerted.
  ///
  /// In fr, this message translates to:
  /// **'Alerte envoyée'**
  String get tripsEventAlerted;

  /// No description provided for @tripsEventClosed.
  ///
  /// In fr, this message translates to:
  /// **'Clôture'**
  String get tripsEventClosed;

  /// No description provided for @tripsEventSignalBack.
  ///
  /// In fr, this message translates to:
  /// **'Signal rétabli'**
  String get tripsEventSignalBack;

  /// No description provided for @tripsEventLowBattery.
  ///
  /// In fr, this message translates to:
  /// **'Batterie faible'**
  String get tripsEventLowBattery;

  /// No description provided for @tripsEventWatcherSeen.
  ///
  /// In fr, this message translates to:
  /// **'Vu par un proche'**
  String get tripsEventWatcherSeen;

  /// No description provided for @tripsEventWatcherRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Destinataire retiré'**
  String get tripsEventWatcherRevoked;

  /// No description provided for @tripsEventDeviceTakeover.
  ///
  /// In fr, this message translates to:
  /// **'Reprise sur un autre appareil'**
  String get tripsEventDeviceTakeover;

  /// No description provided for @tripsUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Trajet indisponible'**
  String get tripsUnreachable;

  /// No description provided for @tripsUnreachableBody.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Votre connexion est peut-être coupée.'**
  String get tripsUnreachableBody;

  /// No description provided for @tripsLeave.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le suivi'**
  String get tripsLeave;

  /// No description provided for @tripsLeaveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quitter ce trajet ?'**
  String get tripsLeaveTitle;

  /// No description provided for @tripsLeaveBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne verrez plus sa position et ne serez pas alerté s\'il ne confirme pas son arrivée.'**
  String get tripsLeaveBody;
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
