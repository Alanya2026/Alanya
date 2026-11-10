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
  /// **'Ajoutez des fichiers depuis votre téléphone.'**
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
