// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Alanya';

  @override
  String get navChats => 'Chats';

  @override
  String get navCalls => 'Appels';

  @override
  String get navStatuses => 'Statuts';

  @override
  String get navMeetings => 'Réunions';

  @override
  String get navProfile => 'Profil';

  @override
  String get offlineBanner =>
      'Pas de connexion — les messages seront envoyés à la reconnexion';

  @override
  String get loginWelcome => 'Bienvenue';

  @override
  String get loginSubtitle => 'Connectez-vous pour continuer vers Alanya';

  @override
  String get loginPasswordHint => 'Mot de passe';

  @override
  String get loginForgotPassword => 'Mot de passe oublié ?';

  @override
  String get loginSubmit => 'Se connecter';

  @override
  String get loginNoAccount => 'Pas encore de compte ?';

  @override
  String get loginSignUp => 'S\'inscrire';

  @override
  String get signupTitle => 'Créer un compte';

  @override
  String get signupSubtitle => 'Rejoignez la communauté Alanya';

  @override
  String get signupNameHint => 'Nom complet';

  @override
  String get signupPseudoHint => 'Pseudo';

  @override
  String get signupEmailHint => 'Adresse e-mail';

  @override
  String get signupPasswordHint => 'Mot de passe';

  @override
  String get signupSubmit => 'S\'inscrire';

  @override
  String get signupHasAccount => 'Déjà un compte ?';

  @override
  String get signupLogin => 'Se connecter';

  @override
  String get validatorRequired => 'Champ requis';

  @override
  String get validatorEmail => 'Email invalide';

  @override
  String validatorMinLength(int n) {
    return 'Au moins $n caractères';
  }

  @override
  String get validatorOtp6 => 'Code OTP à 6 chiffres';

  @override
  String get validatorPasswordMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get unknownSender => 'Inconnu';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusSent => 'Envoyé';

  @override
  String get statusDelivered => 'Livré';

  @override
  String get statusRead => 'Lu';

  @override
  String get statusFailedRetry => 'Échec — touchez pour réessayer';

  @override
  String get retry => 'Réessayer';

  @override
  String get forgotPasswordTitle => 'Récupération du mot de passe';

  @override
  String get forgotEmailTitle => 'Entrez votre email';

  @override
  String get forgotEmailSubtitle => 'Un code OTP sera envoyé à votre email';

  @override
  String get forgotEmailHint => 'E-mail';

  @override
  String get forgotOtpTitle => 'Vérification du code';

  @override
  String forgotOtpSubtitle(String email) {
    return 'Entrez le code 6 chiffres envoyé à $email';
  }

  @override
  String get forgotResendCode => 'Renvoyer le code';

  @override
  String get forgotNewPasswordTitle => 'Nouveau mot de passe';

  @override
  String get forgotNewPasswordSubtitle => 'Entrez votre nouveau mot de passe';

  @override
  String get forgotNewPasswordHint => 'Nouveau mot de passe';

  @override
  String get forgotConfirmPasswordHint => 'Confirmer le mot de passe';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLangSystem => 'Système';

  @override
  String get settingsSectionLanguages => 'Langues';

  @override
  String get settingsAppLanguage => 'Langue de l\'application';

  @override
  String get settingsMessageTranslation => 'Traduction des messages';

  @override
  String settingsLangSystemResolved(String language) {
    return 'Suit le téléphone — actuellement $language';
  }

  @override
  String get languageScreenHint =>
      'La langue de l\'application. Elle ne change pas la langue des messages que vous recevez.';

  @override
  String get languageSectionMessages => 'Messages';

  @override
  String get settingsMedia => 'Médias';

  @override
  String get settingsAutoDownload => 'Téléchargement automatique';

  @override
  String get settingsAutoDownloadSubtitle =>
      'Télécharge les médias reçus dans l’app';

  @override
  String get settingsMediaVisibility => 'Enregistrer dans la galerie';

  @override
  String get settingsMediaVisibilitySubtitle =>
      'Les photos et vidéos reçues apparaissent dans la galerie de l’appareil';

  @override
  String get mediaSaveToGallery => 'Enregistrer dans la galerie';

  @override
  String get mediaSaveToDownloads => 'Enregistrer dans Téléchargements';

  @override
  String get mediaSavedToGallery => 'Enregistré dans la galerie';

  @override
  String get mediaSavedToDownloads => 'Enregistré dans Téléchargements';

  @override
  String get mediaAlreadyInGallery => 'Déjà dans la galerie';

  @override
  String get mediaAlreadyInDownloads => 'Déjà dans Téléchargements';

  @override
  String get mediaSaveAgain => 'Enregistrer à nouveau';

  @override
  String get mediaSaveFailed => 'Impossible d’enregistrer ce média';

  @override
  String get mediaExpired => 'Média expiré';

  @override
  String mediaExpiredAskSender(String name) {
    return 'Demandez à $name de vous le renvoyer';
  }

  @override
  String get mediaExpiredResendYourself =>
      'Renvoyez-le depuis votre galerie si vous l\'avez encore';

  @override
  String get settingsRingtone => 'Sonnerie d\'appel';

  @override
  String get ringtoneScreenTitle => 'Sonnerie d\'appel';

  @override
  String get ringtoneSectionSystem => 'Sonnerie par défaut';

  @override
  String get ringtoneSectionApp => 'Sonneries préinstallées';

  @override
  String get ringtoneSectionCustom => 'Sonneries importées';

  @override
  String get ringtoneSystemDefaultLabel => 'Sonnerie par défaut de l\'appareil';

  @override
  String get ringtoneAddCustomAction => 'Ajouter une sonnerie';

  @override
  String get ringtoneAddCustomHint =>
      'Fichiers audio (MP3, WAV, M4A…), 5 Mo max';

  @override
  String get ringtoneLimitReached => 'Nombre maximal de sonneries atteint (10)';

  @override
  String get ringtoneCustomEmpty => 'Aucune sonnerie importée pour l\'instant';

  @override
  String get ringtoneDeleteConfirmTitle => 'Supprimer cette sonnerie ?';

  @override
  String get ringtoneDeleteConfirmMessage => 'Cette action est irréversible.';

  @override
  String get ringtoneImportSuccess => 'Sonnerie ajoutée et sélectionnée';

  @override
  String get ringtoneImportError => 'Impossible d\'importer ce fichier';

  @override
  String get ringtonePreviewError => 'Impossible de lire cette sonnerie';

  @override
  String get ringtoneSyncInfoTitle => 'Synchronisation entre appareils';

  @override
  String get ringtoneSyncInfoBody =>
      'Cette sonnerie est enregistrée sur cet appareil uniquement : le fichier audio n\'est jamais envoyé sur nos serveurs.\n\nPour l\'entendre aussi sur vos autres appareils, importez-y le même fichier audio. Alanya reconnaît un fichier à son contenu, pas à son nom : un fichier différent portant le même nom ne sera pas reconnu.\n\nEn attendant, vos autres appareils jouent leur son habituel — votre choix, lui, est conservé, et la sonnerie revient dès que le fichier y est importé.';

  @override
  String get ringtoneSyncInfoTooltip =>
      'Utiliser ce son sur mes autres appareils';

  @override
  String get listRingtoneSoundMissing => 'fichier absent sur cet appareil';

  @override
  String get listRingtoneSyncedNote =>
      'Ce choix suit votre compte : il s\'applique à tous vos appareils. Une sonnerie importée doit être présente sur un appareil pour y être jouée.';

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsPrivacySubtitle => 'Contacts bloqués';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonOk => 'OK';

  @override
  String get commonAccept => 'Accepter';

  @override
  String get commonDecline => 'Refuser';

  @override
  String get commonCallBack => 'Rappeler';

  @override
  String get callMissed => 'Appel manqué';

  @override
  String get callIncoming => 'APPEL ENTRANT';

  @override
  String membersCount(int count) {
    return 'Membres ($count)';
  }

  @override
  String groupMembersCount(int count) {
    return 'Groupe • $count membres';
  }

  @override
  String pinnedMessagesCount(int count) {
    return 'Messages épinglés ($count)';
  }

  @override
  String selectCount(int count) {
    return 'Sélectionner ($count)';
  }

  @override
  String forwardAlbumCount(int count) {
    return 'Transférer l\'album ($count)';
  }

  @override
  String downloadAlbumCount(int count) {
    return 'Télécharger l\'album ($count)';
  }

  @override
  String get downloadAlbumHint => 'Enregistrer tous les médias sur l\'appareil';

  @override
  String downloadAlbumProgress(int current, int total) {
    return '$current sur $total';
  }

  @override
  String get albumMediaAlreadyDownloaded =>
      'Tous les médias de l\'album sont déjà téléchargés';

  @override
  String maxMessages(int count) {
    return 'Maximum $count messages';
  }

  @override
  String maxVideos(int count) {
    return 'Maximum $count vidéos.';
  }

  @override
  String albumFirstOnly(int count) {
    return 'Seules les $count premières seront envoyées.';
  }

  @override
  String videoTooLarge(String mb, String limit) {
    return 'Vidéo ignorée ($mb Mo). Limite : $limit Mo.';
  }

  @override
  String fileTooLarge(String mb, String limit) {
    return 'Fichier trop volumineux ($mb Mo). Limite : $limit Mo.';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationLabel(String duration) {
    return 'Durée : $duration';
  }

  @override
  String todayAt(String time) {
    return 'Aujourd\'hui · $time';
  }

  @override
  String tomorrowAt(String time) {
    return 'Demain · $time';
  }

  @override
  String todayAtTime(String time) {
    return 'Aujourd\'hui à $time';
  }

  @override
  String seenAt(String time) {
    return 'Vu à $time';
  }

  @override
  String seenYesterdayAt(String time) {
    return 'Vu hier à $time';
  }

  @override
  String seenOnDate(int day, int month) {
    return 'Vu le $day/$month';
  }

  @override
  String seenAtLower(String time) {
    return 'vu à $time';
  }

  @override
  String seenYesterdayAtLower(String time) {
    return 'vu hier à $time';
  }

  @override
  String timeAgoDays(int count) {
    return 'il y a $count j';
  }

  @override
  String timeAgoHours(int count) {
    return 'il y a $count h';
  }

  @override
  String timeAgoMinutes(int count) {
    return 'il y a $count min';
  }

  @override
  String pageOf(int page, int total) {
    return 'Page $page / $total';
  }

  @override
  String usedByOwner(String owner) {
    return 'Utilisé · $owner';
  }

  @override
  String maxParticipants(int count) {
    return 'Maximum $count participants';
  }

  @override
  String selectUpToVideo(int count) {
    return 'Sélectionnez jusqu\'à $count membres pour l\'appel vidéo';
  }

  @override
  String selectUpToVoice(int count) {
    return 'Sélectionnez jusqu\'à $count membres pour l\'appel vocal';
  }

  @override
  String noResultsFor(String query) {
    return 'Aucun résultat pour \"$query\"';
  }

  @override
  String editedAt(String time) {
    return 'Modifié à $time';
  }

  @override
  String labelForwarded(String label) {
    return '$label transféré';
  }

  @override
  String labelForwardedTo(String label, int count) {
    return '$label transféré vers $count discussions';
  }

  @override
  String forwardedToRatio(int ok, int total) {
    return 'Transféré vers $ok/$total discussions';
  }

  @override
  String callFrom(String name) {
    return 'Appel de $name';
  }

  @override
  String organizedBy(String name) {
    return 'Organisé par $name';
  }

  @override
  String numberAssigned(String number) {
    return 'Numéro attribué : $number';
  }

  @override
  String userIdLabel(String id) {
    return 'User $id';
  }

  @override
  String canContactAgain(String name) {
    return '$name pourra de nouveau vous contacter.';
  }

  @override
  String removePreferredContact(String name) {
    return 'Retirer $name des contacts préférés';
  }

  @override
  String videoMaxSelectable(int count) {
    return 'Vidéo : $count max.';
  }

  @override
  String callBackName(String name) {
    return 'Rappeler $name';
  }

  @override
  String mediaTitleNamed(String name) {
    return '$name — Médias';
  }

  @override
  String photosCount(int count) {
    return '📷 $count photos';
  }

  @override
  String videosCount(int count) {
    return '🎥 $count vidéos';
  }

  @override
  String locationLabel(String label) {
    return '📍 $label';
  }

  @override
  String contactLabel(String label) {
    return '👤 $label';
  }

  @override
  String tapToOpenLabel(String label) {
    return '$label · appuyer pour ouvrir';
  }

  @override
  String get mediaAccessErrorMakeSureHttps =>
      'Erreur d\'accès aux médias. Vérifiez que HTTPS est activé ou que vous êtes sur localhost.';

  @override
  String get cannotAccessMicrophoneCameraCheckThat =>
      'Impossible d\'accéder au microphone/caméra. Vérifiez que l\'application a les permissions.';

  @override
  String get thisActionCannotBeUndoneThe =>
      'Cette action est irréversible. La réunion sera supprimée pour tous les participants.';

  @override
  String get ifYouReceivedAMeetingLink =>
      'Si vous avez reçu un lien de réunion, vous pouvez cliquer sur le lien à la place.';

  @override
  String get microphoneErrorPleaseCheckYourPermissions =>
      'Erreur microphone. Veuillez vérifier vos permissions et votre matériel audio.';

  @override
  String get permissionDeniedOpenSettingsOrPick =>
      'Permission refusée. Ouvrez les réglages ou choisissez un point sur la carte.';

  @override
  String get statusesFromContactsWhoFavoritedYou =>
      'Les statuts de vos contacts qui vous ont ajouté en favori s\'afficheront ici.';

  @override
  String get enableLocationToUseYourPosition =>
      'Activez la localisation pour utiliser votre position, ou déplacez la carte.';

  @override
  String get permissionDeniedYouCanStillPick =>
      'Permission refusée. Vous pouvez quand même choisir un point sur la carte.';

  @override
  String get addContactsToFindThemQuickly =>
      'Ajoutez des contacts pour les retrouver\nrapidement lors de vos réunions';

  @override
  String get editingIsOnlyPossibleWithin30 =>
      'La modification n\'est possible que dans les 30 minutes suivant l\'envoi';

  @override
  String get cameraErrorPleaseCheckYourPermissions =>
      'Erreur caméra. Veuillez vérifier vos permissions et votre caméra.';

  @override
  String get saveTheseDetailsYouWillNeed =>
      'Notez ces informations — elles vous serviront à vous connecter :';

  @override
  String get doYouWantToEndThe =>
      'Voulez-vous mettre fin à la réunion pour tous les participants ?';

  @override
  String get freeEntryReservedPatternsOrStandard =>
      'Saisie libre : patterns réservés ou numéros standard 8 chiffres';

  @override
  String get viewOnceMediaVisibleOnlyOnce =>
      'Média à vue unique — visible une seule fois par le destinataire';

  @override
  String get youWillNoLongerSeeThis =>
      'Vous ne verrez plus ce groupe dans votre liste de discussions.';

  @override
  String get cannotAccessDevicesCheckPermissions =>
      'Impossible d\'accéder aux appareils. Vérifiez les permissions.';

  @override
  String get permissionDeniedPleaseAllowMicrophoneCamera =>
      'Permission refusée. Veuillez autoriser le microphone/caméra.';

  @override
  String get theyWillNoLongerBeAble =>
      'Il ne pourra plus vous envoyer de messages ni vous appeler.';

  @override
  String get n8DigitsAutoGeneratedExcludingReserved =>
      '8 chiffres (génération automatique, hors numéros réservés)';

  @override
  String get noMicrophoneCameraDeviceFoundOn =>
      'Aucun appareil microphone/caméra trouvé sur votre système.';

  @override
  String get gpsUnavailableMoveTheMapTo =>
      'GPS indisponible. Déplacez la carte pour choisir un point.';

  @override
  String get localMessagesInThisChatWill =>
      'Les messages locaux de cette discussion seront supprimés.';

  @override
  String get oneOrMoreMessagesCannotBe =>
      'Un ou plusieurs messages ne peuvent pas être transférés';

  @override
  String get mediaAccessErrorCheckHttpsOr =>
      'Erreur d\'accès aux médias. Vérifiez HTTPS ou localhost.';

  @override
  String get noResultsEnterAFullPattern =>
      'Aucun résultat — saisissez un numéro pattern complet ';

  @override
  String get conversationDeletedLocallyServerUnreachable =>
      'Discussion supprimée localement (serveur injoignable)';

  @override
  String get thisMessageCannotBeForwardedRight =>
      'Ce message ne peut pas être transféré pour le moment';

  @override
  String get thisAlbumCannotBeForwardedRight =>
      'Cet album ne peut pas être transféré pour le moment';

  @override
  String get selectedChatsAreNotArchived =>
      'Les discussions sélectionnées ne sont pas archivées';

  @override
  String get enterTheMeetingCodeProvidedBy =>
      'Entrez le code de réunion fourni par l\'organisateur';

  @override
  String get startANewChatWithThe =>
      'Démarrez une nouvelle discussion avec le bouton +.';

  @override
  String get thisMediaCannotBeForwardedRight =>
      'Ce média ne peut pas être transféré pour le moment';

  @override
  String get reservationLimitedTo3Or4 =>
      'Réservation limitée aux numéros 3 ou 4 chiffres, ';

  @override
  String get selectedChatsAreAlreadyArchived =>
      'Les discussions sélectionnées sont déjà archivées';

  @override
  String get selectedChatsAreAlreadyPinned =>
      'Les discussions sélectionnées sont déjà épinglées';

  @override
  String get unableToAddParticipantsTryAgain =>
      'Impossible d\'ajouter les participants, réessayez';

  @override
  String get peopleYouBlockWillAppearHere =>
      'Les personnes que vous bloquez apparaîtront ici.';

  @override
  String get unableToInviteParticipantsTryAgain =>
      'Impossible d\'inviter les participants, réessayez';

  @override
  String pausedTapToReturn(String type) {
    return 'En pause · $type · Toucher pour revenir';
  }

  @override
  String get sayHelloToStartTheConversation =>
      'Dites bonjour pour démarrer la conversation !';

  @override
  String get noFreeNumberFoundInThe =>
      'Aucun numéro libre trouvé dans la liste admin';

  @override
  String get unableToDeleteTheMeetingTry =>
      'Impossible de supprimer la réunion, réessayez';

  @override
  String get yourPastAndReceivedCallsWill =>
      'Vos appels passés et reçus apparaîtront ici.';

  @override
  String get microphoneCameraPermissionDenied =>
      'Permission refusée pour le microphone/caméra';

  @override
  String get unableToRemoveThisContactTry =>
      'Impossible de retirer ce contact, réessayez';

  @override
  String get newChatUnavailableOffline =>
      'Nouvelle discussion indisponible hors ligne';

  @override
  String get messageNotFoundInThisConversation =>
      'Message introuvable dans cette conversation';

  @override
  String get numberMustContainOnlyDigits =>
      'Le numéro ne doit contenir que des chiffres';

  @override
  String get invalidNumber34Or8 =>
      'Numéro invalide : 3, 4 ou 8 chiffres requis';

  @override
  String get errorCreatingTheConversation =>
      'Erreur lors de la création de la discussion';

  @override
  String get unableToLeaveTheGroupTry =>
      'Impossible de quitter le groupe, réessayez';

  @override
  String get unableToPostTheStatusTry =>
      'Impossible de publier le statut, réessayez';

  @override
  String get unableToAddThisContactTry =>
      'Impossible d\'ajouter ce contact, réessayez';

  @override
  String get canBeOpenedOnlyOnceThen =>
      'Ouvrable une seule fois, puis inaccessible';

  @override
  String get unableToLoadBlockedContacts =>
      'Impossible de charger les contacts bloqués';

  @override
  String get enterANumberOrChooseA =>
      'Entrez un numéro ou choisissez un contact';

  @override
  String get unableToCreateTheMeetingTry =>
      'Impossible de créer la réunion, réessayez';

  @override
  String get unableToCreateTheGroupTry =>
      'Impossible de créer le groupe, réessayez';

  @override
  String get searchByNameUsernameOrPhone =>
      'Rechercher par nom, pseudo ou ID Alanya…';

  @override
  String get assignAReservedNumberOptional =>
      'Attribuer un numéro réservé (optionnel)';

  @override
  String get ajoutezDesContactsPourLesRetrouver =>
      'Ajoutez des contacts pour les retrouver';

  @override
  String get unableToStartTheCallTry =>
      'Impossible de lancer l\'appel, réessayez';

  @override
  String get cannotInviteABlockedContact =>
      'Impossible d\'inviter un contact bloqué';

  @override
  String get manageUsersAndMonitoring =>
      'Gérez les utilisateurs et surveillance';

  @override
  String get fromGalleryOrCamera => 'Depuis la galerie ou l\'appareil photo';

  @override
  String get passwordResetSuccessfully =>
      'Mot de passe réinitialisé avec succès';

  @override
  String get reservedPatternDirectAssignment =>
      'Pattern réservé (attribution directe)';

  @override
  String get unableToForwardTheMessages =>
      'Impossible de transférer les messages';

  @override
  String get longPressToExitSelection => 'Appui long pour quitter la sélection';

  @override
  String get unableToDownloadTheFile => 'Impossible de télécharger le fichier';

  @override
  String get yourProfilePhotoWillBeRemoved =>
      'Votre photo de profil sera retirée.';

  @override
  String get unableToForwardTheMessage => 'Impossible de transférer le message';

  @override
  String get thisNumberCannotBeAssigned =>
      'Ce numéro ne peut pas être attribué';

  @override
  String get unableToUpdateTheCountry => 'Impossible de mettre à jour le pays';

  @override
  String get errorStartingTheCall => 'Erreur lors du démarrage de l\'appel';

  @override
  String get unableToDownloadTheMedia => 'Impossible de télécharger le média';

  @override
  String get mediaNoLongerAvailable => 'Ce média n\'est plus disponible';

  @override
  String get unableToUnblockThisContact => 'Impossible de débloquer ce contact';

  @override
  String get unableToLoadNumbers => 'Impossible de charger les numéros';

  @override
  String get searchByNameUsernameOr => 'Rechercher par nom, pseudo ou ...';

  @override
  String get unableToCreateTheConversation =>
      'Impossible de créer la discussion';

  @override
  String get noAudioVideoDeviceFound => 'Aucun appareil audio/vidéo trouvé';

  @override
  String get unableToOpenTheConversation =>
      'Impossible d\'ouvrir la discussion';

  @override
  String get connectingTapToReturn => 'Connexion… · Toucher pour revenir';

  @override
  String get unableToVerifyTheContact => 'Impossible de vérifier le contact';

  @override
  String get meetingInvitationsAndReminders =>
      'Invitations et rappels de réunion';

  @override
  String get errorGroupIdNotFound => 'Erreur : ID du groupe introuvable';

  @override
  String get profileUnavailableTryAgain => 'Profil non disponible, réessayez';

  @override
  String get cannotCallThisContact => 'Appel impossible avec ce contact';

  @override
  String get unableToForwardTheAlbum => 'Impossible de transférer l\'album';

  @override
  String get thisGroupIsNoLongerAccessible =>
      'Ce groupe n\'est plus accessible.';

  @override
  String get youHaveBlockedThisUser => 'Vous avez bloqué cet utilisateur';

  @override
  String get unableToDisplayTheMessage => 'Impossible d\'afficher le message';

  @override
  String get meetingInLessThan10Minutes => 'Réunion dans moins de 10 minutes';

  @override
  String get addACaptionOptional => 'Ajouter une légende (optionnel)';

  @override
  String get rapidementLorsDeVosReunions => 'rapidement lors de vos réunions';

  @override
  String get alreadyInYourPreferredContacts =>
      'Déjà dans vos contacts préférés';

  @override
  String get dateMustBeInTheFuture => 'La date doit être dans le futur';

  @override
  String get longPressFailedTryAgain => 'Échec appui long pour réessayer';

  @override
  String get eG112233441234OrLabel => 'Ex. 11223344, 1234, ou libellé…';

  @override
  String get theOtherPartyIsBusy => 'Votre correspondant est occupé.';

  @override
  String get viewAndUnblockContacts => 'Voir et débloquer les contacts';

  @override
  String get thisActionCannotBeUndone => 'Cette action est irréversible.';

  @override
  String get mediaIsNotReadyYet => 'Le média n\'est pas encore prêt';

  @override
  String get thisMediaIsNoLongerAvailable => 'Ce média n\'est plus disponible';

  @override
  String get yourSignInCredentials => 'Vos identifiants de connexion';

  @override
  String get resetPassword => 'Réinitialiser le mot de passe';

  @override
  String get microphonePermissionDenied => 'Permission microphone refusée';

  @override
  String get noConversationToDelete => 'Aucune discussion à supprimer';

  @override
  String get phoneAlanyaPhone => 'ID Alanya';

  @override
  String get noOtherMembersToCall => 'Aucun autre membre à appeler';

  @override
  String get actionFailedPleaseTryAgain => 'Action impossible, réessayez';

  @override
  String get failedToAddParticipants => 'Ajout de participants échoué';

  @override
  String get noArchivedConversations => 'Aucune conversation archivée';

  @override
  String get noConnectionsRecorded => 'Aucune connexion enregistrée';

  @override
  String get countryListUnavailable => 'Liste des pays indisponible';

  @override
  String get profilePhotoUpdated => 'Photo de profil mise à jour';

  @override
  String get searchByNameUsername => 'Rechercher par nom, pseudo…';

  @override
  String get noConversationToClear => 'Aucune discussion à effacer';

  @override
  String get historyWillBeDeleted => 'L\'historique sera supprimé.';

  @override
  String get addAtLeastOneMember => 'Ajouter au moins un membre';

  @override
  String get searchChats => 'Rechercher une discussion…';

  @override
  String get thisMediaHasAlreadyBeenOpened => 'Ce média a déjà été ouvert';

  @override
  String get addAPreferredContact => 'Ajouter un contact préféré';

  @override
  String get enterANumberToAdd => 'Entrez un numéro à ajouter';

  @override
  String get noMeetingsToday => 'Aucune réunion aujourd\'hui';

  @override
  String get aCallIsAlreadyInProgress => 'Un appel est déjà en cours';

  @override
  String get failedToCreateGroup => 'Création du groupe échouée';

  @override
  String get turnOffSpeaker => 'Désactiver le haut-parleur';

  @override
  String get noParticipantsConnected => 'Aucun participant connecté';

  @override
  String get chooseFromGallery => 'Choisir depuis la galerie';

  @override
  String get deleteConversation => 'Supprimer la discussion ?';

  @override
  String get manualNumberEntry => 'Saisie manuelle du numéro';

  @override
  String get thisMessageWasDeleted => 'Ce message a été supprimé';

  @override
  String get deleteUser => 'Supprimer l\'utilisateur ?';

  @override
  String get mediaAccessError => 'Erreur d\'accès aux médias';

  @override
  String get addADescription => 'Ajouter une description…';

  @override
  String get microphonePermissionDenied2 => 'Permission micro refusée';

  @override
  String get failedToLeaveGroup => 'Quitter le groupe échoué';

  @override
  String get unableToOpenMaps => 'Impossible d\'ouvrir Maps';

  @override
  String get conversationNotFound => 'Conversation introuvable';

  @override
  String get addParticipants => 'Ajouter des participants';

  @override
  String get tapToDownload => 'Appuyer pour télécharger';

  @override
  String pdfPageCount(int count) {
    return '$count pages';
  }

  @override
  String get noUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get enterTheGroupName => 'Entrez le nom du groupe';

  @override
  String get requiredExceptTier3 => 'Obligatoire sauf tier 3';

  @override
  String get deleteConversation2 => 'Supprimer la discussion';

  @override
  String get userNotFound => 'Utilisateur introuvable';

  @override
  String get downloadFailed => 'Échec du téléchargement';

  @override
  String get invalidUploadResponse => 'Réponse upload invalide';

  @override
  String get enableLocation => 'Activer la localisation';

  @override
  String get noUpcomingMeetings => 'Aucune réunion à venir';

  @override
  String get exampleAbcDefgHij => 'Exemple : abc-defg-hij';

  @override
  String get unblockThisContact => 'Débloquer ce contact ?';

  @override
  String get clearMessages => 'Effacer les messages ?';

  @override
  String get sendThisLocation => 'Envoyer cette position';

  @override
  String get startVideoCall => 'Démarrer l\'appel vidéo';

  @override
  String get forwardUnavailable => 'Transfert indisponible';

  @override
  String get startVoiceCall => 'Démarrer l\'appel vocal';

  @override
  String get noPastMeetings => 'Aucune réunion passée';

  @override
  String get scheduleAMeeting => 'Planifier une réunion';

  @override
  String get n34DigitsOrXxyyzztt => '3 / 4 ch. ou XXYYZZTT';

  @override
  String get groupCallInProgress => 'Appel groupé en cours';

  @override
  String get deleteThisStatus => 'Supprimer ce statut ?';

  @override
  String get mediaLinksAndDocs => 'Médias, liens et docs';

  @override
  String get searchForACountry => 'Rechercher un pays...';

  @override
  String get voiceMessageEnded => 'Message vocal terminé';

  @override
  String get musicEnded => 'Musique terminée';

  @override
  String get noPreferredContacts => 'Aucun contact préféré';

  @override
  String get donTHaveAnAccount => 'Pas encore de compte?';

  @override
  String get joinAMeeting => 'Rejoindre une réunion';

  @override
  String get meetingDetails => 'Détail de la réunion';

  @override
  String get noBlockedContacts => 'Aucun contact bloqué';

  @override
  String get blockThisContact => 'Bloquer ce contact ?';

  @override
  String get sendALocation => 'Envoyer une position';

  @override
  String get createUser => 'Créer un utilisateur';

  @override
  String get addACaption => 'Ajouter une légende…';

  @override
  String get alanyaNumberRequired => 'ID Alanya requis';

  @override
  String get selectACountry => 'Sélectionnez un pays';

  @override
  String get noReservedNumbers => 'Aucun numéro réservé';

  @override
  String get clearMessages2 => 'Effacer les messages';

  @override
  String get removeFromContacts => 'Retirer des contacts';

  @override
  String get messageToForward => 'Message à transférer';

  @override
  String get deletePhoto => 'Supprimer la photo ?';

  @override
  String get unblockContact => 'Débloquer le contact';

  @override
  String get loadingCountries => 'Chargement des pays…';

  @override
  String get newChat => 'Nouvelle discussion';

  @override
  String get typeYourStatus => 'Tapez votre statut…';

  @override
  String get editMessage => 'Modifier le message';

  @override
  String get noRecentStatus => 'Aucun statut récent';

  @override
  String get closeSearch => 'Fermer la recherche';

  @override
  String get sendLocation => 'Envoyer la position';

  @override
  String get openSettings => 'Ouvrir les réglages';

  @override
  String get statusReply => 'Réponse à un statut';

  @override
  String get statusNoLongerAvailable => 'Ce statut n\'est plus disponible';

  @override
  String get socketNotConnected => 'Socket non connecté';

  @override
  String get deleteForEveryone => 'Supprimer pour tous';

  @override
  String get meetingTitle => 'Titre de la réunion';

  @override
  String get connecting => 'Connexion en cours…';

  @override
  String get callReconnecting => 'Reconnexion…';

  @override
  String get freeUnassigned => 'Libre · non assigné';

  @override
  String get numberUnavailable => 'Numéro indisponible';

  @override
  String get meetingNotFound => 'Réunion introuvable';

  @override
  String get recentConnections => 'Connexions récentes';

  @override
  String get replyToStatus => 'Répondre au statut…';

  @override
  String get noSharedMedia => 'Aucun média partagé';

  @override
  String get leaveGroup => 'Quitter le groupe ?';

  @override
  String get typing => 'en train d\'écrire…';

  @override
  String get cancelMeeting => 'Annuler la réunion';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get blockContact => 'Bloquer le contact';

  @override
  String get groupNotFound => 'Groupe introuvable';

  @override
  String get deleteForMe => 'Supprimer pour moi';

  @override
  String get groupVideoCall => 'Appel groupé vidéo';

  @override
  String get noRecentCalls => 'Aucun appel récent';

  @override
  String get audioUnavailable => 'Audio indisponible';

  @override
  String get typing2 => 'En train d\'écrire…';

  @override
  String get numberOrLabel => 'Numéro ou libellé…';

  @override
  String get albumToForward => 'Album à transférer';

  @override
  String get mediaUnavailable => 'Média indisponible';

  @override
  String get messageDetails => 'Détails du message';

  @override
  String get endForEveryone => 'Terminer pour tous';

  @override
  String get writeAMessage => 'Écrire un message…';

  @override
  String get changeNumber => 'Changer le numéro';

  @override
  String get countryUnavailable => 'Pays indisponible';

  @override
  String get numberAvailable => 'Numéro disponible';

  @override
  String get addAVideo => 'Ajouter une vidéo';

  @override
  String get noCountryFound => 'Aucun pays trouvé';

  @override
  String get addAPhoto => 'Ajouter une photo';

  @override
  String get cameraDisabled => 'Caméra désactivée';

  @override
  String get searchInConversationHint => 'Rechercher dans la discussion';

  @override
  String get searchNoResult => 'Aucun message trouvé';

  @override
  String searchResultCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String get searchPrevious => 'Résultat précédent';

  @override
  String get searchNext => 'Résultat suivant';

  @override
  String get searchExit => 'Fermer la recherche';

  @override
  String get takeAPhoto => 'Prendre une photo';

  @override
  String get enableCamera => 'Activer la caméra';

  @override
  String get switchCamera => 'Changer de caméra';

  @override
  String get noChats => 'Aucune discussion';

  @override
  String get callFailed => 'Échec de l\'appel.';

  @override
  String get retrySending => 'Réessayer l\'envoi';

  @override
  String get leaveGroup2 => 'Quitter le groupe';

  @override
  String get preferredContacts => 'Contacts préférés';

  @override
  String get turnOffCamera => 'Couper la caméra';

  @override
  String get messagesCleared => 'Messages effacés';

  @override
  String get reservedNumbers => 'Numéros réservés';

  @override
  String get meetingEnded => 'Réunion terminée';

  @override
  String get meetingBlockedByCall =>
      'Un appel est en cours : impossible de rejoindre la réunion.';

  @override
  String get meetingJoinExpired => 'Cette réunion est échue.';

  @override
  String get meetingJoinNotInvited => 'Réunion introuvable.';

  @override
  String get meetingParticipantJoined => 'A rejoint';

  @override
  String get meetingParticipantPending => 'En attente';

  @override
  String get meetingExpired => 'Échue';

  @override
  String get newMeeting => 'Nouvelle réunion';

  @override
  String get alanyaPhone => 'ID Alanya';

  @override
  String get deletedMessage => 'Message supprimé';

  @override
  String get verifyCode => 'Vérifier le code';

  @override
  String get notDeliveredYet => 'Pas encore livré';

  @override
  String get someoneIsTyping => 'Quelqu\'un écrit…';

  @override
  String nameIsTyping(String name) {
    return '$name écrit…';
  }

  @override
  String get lastWeek => 'Dernière semaine';

  @override
  String get otherResults => 'Autres résultats';

  @override
  String get changeMedia => 'Changer le média';

  @override
  String get contactUnblocked => 'Contact débloqué';

  @override
  String get downloading => 'Téléchargement…';

  @override
  String get minimizeCall => 'Réduire l\'appel';

  @override
  String get createAGroup => 'Créer un groupe';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get replySent => 'Réponse envoyée';

  @override
  String get sessionExpired => 'Session expirée';

  @override
  String get callInProgress => 'Appel en cours…';

  @override
  String get createGroup => 'Créer le groupe';

  @override
  String get newMessage => 'Nouveau message';

  @override
  String get groupInfo => 'Infos du groupe';

  @override
  String get placeACall => 'Lancer un appel';

  @override
  String get newContact => 'Nouveau contact';

  @override
  String get noAnswer => 'Pas de réponse.';

  @override
  String get backgroundColor => 'Couleur de fond';

  @override
  String get photoDeleted => 'Photo supprimée';

  @override
  String get serverError => 'Erreur serveur';

  @override
  String get noDocuments => 'Aucun document';

  @override
  String get reservedNumber => 'Numéro réservé';

  @override
  String get password => 'Mot de passe *';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get missedCalls => 'Appels manqués';

  @override
  String get newStatus => 'Nouveau statut';

  @override
  String get newGroup => 'Nouveau groupe';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get labelRequired => 'Libellé requis';

  @override
  String get unlike => 'Je n\'aime plus';

  @override
  String get messages7d => 'Messages (7j)';

  @override
  String get noContacts => 'Aucun contact';

  @override
  String get callEnded => 'Appel terminé';

  @override
  String get joinedOn => 'Inscrit(e) le';

  @override
  String get uploadFailed => 'Upload échoué';

  @override
  String get cameraOn => 'Caméra active';

  @override
  String get cameraOff => 'Caméra coupée';

  @override
  String get verifying => 'Vérification…';

  @override
  String get reRecord => 'Réenregistrer';

  @override
  String get videoComingSoon => 'Vidéo à venir';

  @override
  String get dateAndTime => 'Date et heure';

  @override
  String get noMessages => 'Aucun message';

  @override
  String get lastCall => 'Dernier appel';

  @override
  String get videoMeeting => 'Réunion vidéo';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get callComingSoon => 'Appel à venir';

  @override
  String get noAnswer2 => 'Sans réponse';

  @override
  String get organizer => 'Organisateur';

  @override
  String get noImages => 'Aucune image';

  @override
  String get emptyMessage => 'Message vide';

  @override
  String get rewind10S => 'Reculer 10 s';

  @override
  String get pdfDocument => 'Document PDF';

  @override
  String get speaker => 'Haut-parleur';

  @override
  String get audioOutputEarpiece => 'Écouteur';

  @override
  String get audioOutputWired => 'Casque filaire';

  @override
  String get audioOutputBluetooth => 'Bluetooth';

  @override
  String get changeAudioOutput => 'Changer la sortie audio';

  @override
  String get newCall => 'Nouvel appel';

  @override
  String get lastView => 'Dernière vue';

  @override
  String get receivedCalls => 'Appels reçus';

  @override
  String get participants => 'Participants';

  @override
  String get alreadyUsed => 'Déjà utilisé';

  @override
  String get select => 'Sélectionner';

  @override
  String get makeAdmin => 'Rendre admin';

  @override
  String get statuses7d => 'Statuts (7j)';

  @override
  String get forward10S => 'Avancer 10 s';

  @override
  String get openWith => 'Ouvrir avec…';

  @override
  String get groupCall => 'Appel groupé';

  @override
  String get noVideos => 'Aucune vidéo';

  @override
  String get chats => 'Discussions';

  @override
  String get creating => 'Création...';

  @override
  String get videoCall => 'Appel vidéo';

  @override
  String get unpin => 'Désépingler';

  @override
  String get micMuted => 'Micro coupé';

  @override
  String get outgoingCalls => 'Appels émis';

  @override
  String get micOn => 'Micro actif';

  @override
  String get demote => 'Rétrograder';

  @override
  String get audioCall => 'Appel audio';

  @override
  String get description => 'Description';

  @override
  String get unarchive => 'Désarchiver';

  @override
  String get voiceCall => 'Appel vocal';

  @override
  String get search => 'Rechercher…';

  @override
  String get signOut => 'Déconnexion';

  @override
  String get calls7d => 'Appels (7j)';

  @override
  String get justNow => 'à l\'instant';

  @override
  String get notSet => 'Non défini';

  @override
  String get myStatus => 'Mon statut';

  @override
  String get noViews => 'Aucune vue';

  @override
  String get connecting2 => 'Connexion…';

  @override
  String get forward => 'Transférer';

  @override
  String get noLinks => 'Aucun lien';

  @override
  String get emptyAlbum => 'Album vide';

  @override
  String get message => 'Message...';

  @override
  String get offline => 'Hors ligne';

  @override
  String get viewOnce => 'Vue unique';

  @override
  String get refresh => 'Actualiser';

  @override
  String get location => '📍 Position';

  @override
  String get later => 'Plus tard';

  @override
  String get warning => 'Attention';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get forwarded => 'Transféré';

  @override
  String get edited => '· modifié';

  @override
  String get unblock => 'Débloquer';

  @override
  String get file => '📎 Fichier';

  @override
  String get results => 'Résultats';

  @override
  String get join => 'Rejoindre';

  @override
  String get allow => 'Autoriser';

  @override
  String get recently => 'Récemment';

  @override
  String get documents => 'Documents';

  @override
  String get phone => 'Téléphone';

  @override
  String get scheduled => 'Planifiée';

  @override
  String get contact => '👤 Contact';

  @override
  String get gotIt => 'J\'ai noté';

  @override
  String get banReason => 'Motif ban';

  @override
  String get used => 'Utilisés';

  @override
  String get sentAt => 'Envoyé à';

  @override
  String get pin => 'Épingler';

  @override
  String get unpin2 => 'Détacher';

  @override
  String get username => 'Pseudo *';

  @override
  String get reply => 'Répondre';

  @override
  String get message2 => 'Message…';

  @override
  String get unban => 'Débannir';

  @override
  String get online => 'En ligne';

  @override
  String get edit => 'Modifier';

  @override
  String get inProgress => 'En cours';

  @override
  String get ended => 'Terminée';

  @override
  String get location2 => 'Position';

  @override
  String get alreadyViewed => 'Déjà vus';

  @override
  String get archived => 'Archivés';

  @override
  String get files => 'Fichiers';

  @override
  String get share => 'Partager';

  @override
  String get shareToConversation => 'Envoyer via Alanya';

  @override
  String get sharedContentSent => 'Contenu envoyé';

  @override
  String sharedContentSentTo(int count) {
    return 'Contenu envoyé vers $count discussions';
  }

  @override
  String get unableToShareTheContent => 'Impossible d\'envoyer le contenu';

  @override
  String get unableToShareTheMessage => 'Impossible de partager le message';

  @override
  String get thisMessageCannotBeSharedRight =>
      'Ce message ne peut pas être partagé pour le moment';

  @override
  String get document => 'Document';

  @override
  String get activity => 'Activité';

  @override
  String get album => '📷 Album';

  @override
  String get answered => 'Répondu';

  @override
  String get upcoming => 'À venir';

  @override
  String get generate => 'Générer';

  @override
  String get audio => '🎵 Audio';

  @override
  String get photo => '📷 Photo';

  @override
  String get reply2 => 'Réponse';

  @override
  String get deliveredAt => 'Livré à';

  @override
  String get gallery => 'Galerie';

  @override
  String get meeting => 'Réunion';

  @override
  String get next => 'Suivant';

  @override
  String get dismiss => 'Ignorer';

  @override
  String get file2 => 'Fichier';

  @override
  String get sensitiveDocument => 'Sensible';

  @override
  String get sensitiveDocumentBadge => 'Document sensible';

  @override
  String sensitiveViewedBy(String numero, String appareil, String date) {
    return 'Consulté par Alanya $numero · $appareil · $date';
  }

  @override
  String get sensitiveCannotPreview =>
      'Ce document ne s\'ouvre pas dans Alanya. Il reste protégé : seule une copie signée à votre nom peut en sortir.';

  @override
  String get sensitiveSaveSigned => 'Enregistrer une copie signée';

  @override
  String get sensitiveSavedSigned =>
      'Copie signée enregistrée : elle porte votre empreinte numérique.';

  @override
  String get sensitiveSavedUnsigned =>
      'Copie enregistrée, mais ce format ne peut pas être signé. L\'enregistrement a été noté.';

  @override
  String get sensitiveSaveFailed => 'Impossible d\'enregistrer la copie.';

  @override
  String get sensitiveAlreadySignedTitle => 'Copie déjà signée';

  @override
  String get sensitiveAlreadySignedBody =>
      'Ce fichier est la copie signée d\'un document sensible. Il ne peut pas repartir en sensible : il serait signé à nouveau et perdrait l\'empreinte de la personne qui l\'a fait sortir. Vous pouvez l\'envoyer en document ordinaire, qui la garde.';

  @override
  String get sensitiveSendAsOrdinary => 'Envoyer en ordinaire';

  @override
  String get fingerprintCheckTitle => 'Vérifier une empreinte';

  @override
  String get fingerprintCheckSubtitle =>
      'Qui a fait sortir une copie signée d\'un document sensible';

  @override
  String get fingerprintCheckIntro =>
      'Chaque copie d\'un document sensible enregistrée hors d\'Alanya porte une empreinte numérique : 32 caractères sur ses bords ou dans ses propriétés. Saisissez-la pour savoir qui l\'a fait sortir. Seules les personnes qui pouvaient voir le document obtiennent une réponse.';

  @override
  String get fingerprintField => 'Empreinte numérique';

  @override
  String get fingerprintPaste => 'Coller';

  @override
  String get fingerprintSearch => 'Rechercher';

  @override
  String get fingerprintInvalid =>
      'Il faut 32 caractères, chiffres de 0 à 9 et lettres de A à F.';

  @override
  String get fingerprintUnknown =>
      'Empreinte inconnue, ou copie d\'un document que vous ne pouviez pas voir.';

  @override
  String get fingerprintLookupFailed =>
      'La recherche n\'a pas abouti. Réessayez.';

  @override
  String get fingerprintResult => 'Copie identifiée';

  @override
  String get fingerprintBy => 'Sortie par';

  @override
  String get fingerprintAction => 'Geste';

  @override
  String get fingerprintDate => 'Date';

  @override
  String get fingerprintDevice => 'Appareil';

  @override
  String get fingerprintSender => 'Expéditeur du document';

  @override
  String get fingerprintDocument => 'Document';

  @override
  String get fingerprintUnknownValue => 'Inconnu';

  @override
  String get fingerprintActionDownload => 'Enregistrement';

  @override
  String get fingerprintActionShare => 'Partage';

  @override
  String get fingerprintActionForward => 'Transfert';

  @override
  String get pdfProtectionTitle => 'Protéger la copie du PDF';

  @override
  String get pdfProtectionIntro =>
      'Ces réglages s\'appliquent à la copie que le destinataire enregistrera hors d\'Alanya. Dans Alanya, le document reste lisible dans la visionneuse protégée.';

  @override
  String get pdfProtectionAllowPrint => 'Autoriser l\'impression';

  @override
  String get pdfProtectionPassword => 'Protéger par mot de passe';

  @override
  String get pdfProtectionPasswordHelp =>
      'La copie sera chiffrée ; il faudra le mot de passe d\'ouverture pour la lire.';

  @override
  String get pdfOpenPassword => 'Mot de passe d\'ouverture';

  @override
  String get pdfOpenPasswordHelp => 'Montré une seule fois au destinataire.';

  @override
  String get pdfOwnerPassword => 'Mot de passe propriétaire';

  @override
  String get pdfOwnerPasswordHelp =>
      'Lève les restrictions (l\'impression). Jamais montré au destinataire.';

  @override
  String pdfPasswordTooShort(int n) {
    return '$n caractères au moins.';
  }

  @override
  String get pdfProtectionSend => 'Envoyer';

  @override
  String get pdfPrintForbidden => 'Impression interdite';

  @override
  String get pdfPasswordShowOnce => 'Voir le mot de passe (une seule fois)';

  @override
  String get pdfPasswordAlreadySeen => 'Mot de passe déjà affiché';

  @override
  String get pdfPasswordOnceNotice =>
      'Notez-le : il ne sera plus affiché. Il ouvre la copie enregistrée de ce PDF.';

  @override
  String get pdfPasswordCopy => 'Copier';

  @override
  String get pdfPasswordDone => 'J\'ai noté';

  @override
  String get pdfProtectionFailed =>
      'La protection du PDF a échoué : aucune copie n\'est sortie.';

  @override
  String get comingSoon => 'Bientôt';

  @override
  String get recent => 'Récents';

  @override
  String get label => 'Libellé';

  @override
  String get invite => 'Inviter';

  @override
  String get ended2 => 'Terminé';

  @override
  String get video => '🎥 Vidéo';

  @override
  String get contact2 => 'Contact';

  @override
  String get leave => 'Quitter';

  @override
  String get favorites => 'Favoris';

  @override
  String get gotIt2 => 'Compris';

  @override
  String get edited2 => 'Modifié';

  @override
  String get inactive => 'Inactif';

  @override
  String get add => 'Ajouter';

  @override
  String get member => 'Membre';

  @override
  String get success => 'Succès';

  @override
  String get ban => 'Bannir';

  @override
  String get past => 'Passés';

  @override
  String get videos => 'Vidéos';

  @override
  String get copy => 'Copier';

  @override
  String get camera => 'Caméra';

  @override
  String get photos => 'Photos';

  @override
  String get sending => 'Envoi…';

  @override
  String get blocked => 'Bloqué';

  @override
  String get added => 'Ajouté';

  @override
  String get images => 'Images';

  @override
  String get number => 'Numéro';

  @override
  String get back => 'Retour';

  @override
  String get missed => 'Manqué';

  @override
  String voicemailPeerUnavailable(String name) {
    return '$name est indisponible';
  }

  @override
  String get voicemailLeaveMessage =>
      'Laissez un message vocal, il le recevra dans votre conversation.';

  @override
  String get voicemailRecord => 'Enregistrer';

  @override
  String get voicemailSend => 'Envoyer';

  @override
  String get voicemailDiscard => 'Annuler';

  @override
  String get voicemailNotNow => 'Pas maintenant';

  @override
  String get voicemailSent => 'Message envoyé';

  @override
  String get voicemailBannerActive => 'Répondeur actif';

  @override
  String voicemailBannerUntil(String time) {
    return 'Répondeur actif jusqu\'à $time';
  }

  @override
  String get voicemailBannerDisable => 'Désactiver';

  @override
  String get voicemailDisabled => 'Répondeur désactivé';

  @override
  String get voicemailScheduleTitle => 'Répondeur';

  @override
  String get voicemailEnabled => 'Répondeur planifié';

  @override
  String get voicemailEnabledSubtitle =>
      'Sur ces créneaux, votre téléphone ne sonne pas et l\'appelant peut laisser un message';

  @override
  String voicemailTimezoneHint(String timezone) {
    return 'Heures évaluées à $timezone';
  }

  @override
  String get voicemailBypassTitle => 'Peuvent me joindre quand même';

  @override
  String get voicemailBypassTile => 'Liste autorisée';

  @override
  String get voicemailBypassNobody => 'Personne';

  @override
  String get voicemailBypassHint =>
      'Les membres de cette liste feront sonner votre téléphone malgré le répondeur.';

  @override
  String voicemailPeerNoAnswer(String name) {
    return '$name n\'a pas répondu';
  }

  @override
  String get voicemailGreetingPause => 'Couper l\'annonce';

  @override
  String get voicemailGreetingReplay => 'Réécouter l\'annonce';

  @override
  String get voicemailGreetingSection => 'Mon annonce';

  @override
  String get voicemailGreetingTitle => 'Enregistrer votre annonce';

  @override
  String voicemailGreetingHint(int max) {
    return 'Elle sera jouée à ceux qui tombent sur votre répondeur. $max secondes au maximum.';
  }

  @override
  String get voicemailGreetingStop => 'Terminer';

  @override
  String get voicemailGreetingSaved => 'Annonce enregistrée';

  @override
  String get voicemailGreetingNone =>
      'Aucune annonce — un texte s\'affichera à la place';

  @override
  String voicemailGreetingSet(int seconds) {
    return '$seconds secondes enregistrées';
  }

  @override
  String get voicemailGreetingListen => 'Écouter l\'annonce';

  @override
  String get voicemailGreetingDelete => 'Supprimer l\'annonce';

  @override
  String get voicemailGreetingDeleted => 'Annonce supprimée';

  @override
  String get voicemailWhenNoAnswer => 'Quand je ne réponds pas';

  @override
  String get voicemailAfterDelay => 'Répondeur après 30 secondes';

  @override
  String get voicemailAfterDelaySubtitle =>
      'Le téléphone sonne. Si vous ne décrochez pas, si vous refusez l\'appel ou si votre ligne est occupée, l\'appelant peut laisser un message.';

  @override
  String get voicemailWhenUnavailable => 'Quand je suis indisponible';

  @override
  String get voicemailSlotsEnabled => 'Plages programmées';

  @override
  String get voicemailSlotsEnabledSubtitle =>
      'Sur ces périodes, votre téléphone ne sonne pas du tout';

  @override
  String get voicemailSlotNone => 'Aucune plage';

  @override
  String get voicemailSlotAllDay => 'Toute la journée';

  @override
  String voicemailSlotOvernight(String range) {
    return '$range (jusqu\'au lendemain)';
  }

  @override
  String voicemailSlotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plages programmées',
      one: '1 plage programmée',
    );
    return '$_temp0';
  }

  @override
  String get voicemailQuickHint =>
      'Choisissez jusqu\'à quand. Toutes les options ont une fin : un répondeur qu\'on oublie est pire que pas de répondeur.';

  @override
  String get voicemailQuickSchedule => 'Planifier des créneaux';

  @override
  String get voicemailForOneHour => 'Pendant 1 heure';

  @override
  String get voicemailForFourHours => 'Pendant 4 heures';

  @override
  String get voicemailUntilMorning => 'Jusqu\'à demain matin';

  @override
  String get voicemailUntilCustom => 'Jusqu\'à une date précise';

  @override
  String get voicemailDeadlinePast => 'Cette échéance est déjà passée';

  @override
  String get voicemailCallStatus => 'Répondeur';

  @override
  String get rejected => 'Rejeté';

  @override
  String get links => 'Liens';

  @override
  String get linkNoun => 'Lien';

  @override
  String get timeZoneLabel => 'Fuseau horaire';

  @override
  String get email => 'Email';

  @override
  String get create => 'Créer';

  @override
  String get name => 'Nom *';

  @override
  String get title => 'Titre';

  @override
  String get admin => 'Admin';

  @override
  String get audio2 => 'Audio';

  @override
  String get playbackSpeed => 'Vitesse de lecture';

  @override
  String get playbackSpeedVoiceLabel => 'Messages vocaux';

  @override
  String get playbackSpeedVideoLabel => 'Vidéos';

  @override
  String get playbackSpeedMusicLabel => 'Musique';

  @override
  String get music => 'Musique';

  @override
  String musicPreview(String name) {
    return '🎵 $name';
  }

  @override
  String get active => 'Actif';

  @override
  String get duration => 'Durée';

  @override
  String get failure => 'Échec';

  @override
  String get photo2 => 'Photo';

  @override
  String get copied => 'Copié';

  @override
  String get video2 => 'Vidéo';

  @override
  String get theme => 'Thème';

  @override
  String get all => 'Tout';

  @override
  String get role => 'Rôle';

  @override
  String get mute => 'Muet';

  @override
  String get readAt => 'Lu à';

  @override
  String get more => 'Plus';

  @override
  String get country => 'Pays';

  @override
  String get name2 => 'Nom';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get showLabel => 'Afficher';

  @override
  String get hideLabel => 'Masquer';

  @override
  String selectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String participantsAdded(int count) {
    return '$count participant(s) ajouté(s)';
  }

  @override
  String participantsInvited(int count) {
    return '$count participant(s) invité(s)';
  }

  @override
  String get accepted => 'Accepté';

  @override
  String get startAction => 'Démarrer';

  @override
  String get likeAction => 'J\'aime';

  @override
  String get incomingCallsChannel => 'Appels entrants';

  @override
  String get ongoingCallsChannel => 'Appels en cours';

  @override
  String get viewsTitle => 'Vues';

  @override
  String get keypadTitle => 'Clavier';

  @override
  String get clearAction => 'Effacer';

  @override
  String get scheduleAction => 'Planifier';

  @override
  String get archiveAction => 'Archiver';

  @override
  String get markAsRead => 'Marquer lu';

  @override
  String get infoAction => 'Infos';

  @override
  String get reportAction => 'Signaler';

  @override
  String get reportMessageTitle => 'Signaler ce message';

  @override
  String get reportUserTitle => 'Signaler ce compte';

  @override
  String get reportSubtitle =>
      'Votre signalement est transmis à l’équipe ALANYA. La personne concernée n’en est pas informée.';

  @override
  String get reportReasonHarassment => 'Harcèlement ou intimidation';

  @override
  String get reportReasonHate => 'Propos haineux';

  @override
  String get reportReasonViolence => 'Violence ou menaces';

  @override
  String get reportReasonSexual => 'Contenu sexuel';

  @override
  String get reportReasonScam => 'Arnaque ou fraude';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonImpersonation => 'Usurpation d’identité';

  @override
  String get reportReasonOther => 'Autre';

  @override
  String get reportNoteHint => 'Précision (facultatif)';

  @override
  String get reportSubmit => 'Envoyer le signalement';

  @override
  String get reportSent => 'Signalement transmis. Merci.';

  @override
  String get reportFailed => 'Envoi impossible. Réessayez.';

  @override
  String get cannotPlaceCallCheckInternet =>
      'Impossible de passer un appel, vérifiez votre connexion à internet et réessayez.';

  @override
  String get cannotPlaceCallServerFailed =>
      'Impossible de passer un appel, la connexion au serveur a échoué. Réessayez.';

  @override
  String get connectionRequired => 'Connexion requise';

  @override
  String get callImpossible => 'Appel impossible.';

  @override
  String get errorAcceptingCall => 'Erreur lors de l\'acceptation de l\'appel';

  @override
  String get userNotConnected => 'Utilisateur non connecté';

  @override
  String get mediaUnavailableForTransfer =>
      'Média indisponible pour le transfert';

  @override
  String get invalidPositionForTransfer =>
      'Position invalide pour le transfert';

  @override
  String get invalidContactForTransfer => 'Contact invalide pour le transfert';

  @override
  String get photoViewOnce => '📷 Photo · Vue unique';

  @override
  String get videoViewOnce => '🎥 Vidéo · Vue unique';

  @override
  String get videoCallPreview => '📹 Appel vidéo';

  @override
  String get voiceCallPreview => '📞 Appel vocal';

  @override
  String get deletePhotoAction => 'Supprimer la photo';

  @override
  String get unavailableOffline => 'Indisponible hors ligne';

  @override
  String get noParticipantsYet => 'Aucun participant pour le moment';

  @override
  String get noMessagesYet => 'Aucun message pour le moment';

  @override
  String get removeParticipantToAddAnother =>
      'Retirez un participant pour en ajouter un autre.';

  @override
  String get noContactsYet => 'Aucun contact pour le moment';

  @override
  String get voiceMessage => 'Message vocal';

  @override
  String get paused => 'En pause';

  @override
  String get recordOrImportAudio =>
      'Enregistrez un vocal ou importez un fichier audio';

  @override
  String get tapToAddYourStatus => 'Appuyer pour ajouter votre statut';

  @override
  String get shareAContact => 'Partager un contact';

  @override
  String get searchAContact => 'Rechercher un contact';

  @override
  String get unmuteMic => 'Activer le micro';

  @override
  String get muteMic => 'Couper le micro';

  @override
  String get turnOnSpeaker => 'Activer le haut-parleur';

  @override
  String get notAuthenticated => 'Non authentifié';

  @override
  String get networkTimeout => 'Timeout réseau';

  @override
  String get networkError =>
      'Connexion impossible. Vérifiez votre réseau et réessayez.';

  @override
  String get noRefreshToken => 'Pas de refresh token';

  @override
  String get refreshFailed => 'Refresh échoué';

  @override
  String addedToPreferredContacts(String name) {
    return '$name ajouté aux contacts préférés';
  }

  @override
  String get approximateGpsSlow => 'Position approximative (GPS lent).';

  @override
  String get notYetRead => 'Pas encore lu';

  @override
  String get sentOnTapSend => 'Appui sur envoyer';

  @override
  String maxPhotos(int count) {
    return 'Maximum $count photos.';
  }

  @override
  String maxFiles(int count) {
    return 'Maximum $count fichiers.';
  }

  @override
  String filesSkippedTooLarge(int count, String limit) {
    return '$count fichier(s) ignoré(s) : limite $limit Mo.';
  }

  @override
  String maxMedias(int count) {
    return 'Maximum $count médias.';
  }

  @override
  String get addMore => 'Ajouter';

  @override
  String get removeMedia => 'Retirer';

  @override
  String get voiceViewOnce => 'Vocal · vue unique';

  @override
  String get heCanContactYouAgain => 'Il pourra de nouveau vous contacter.';

  @override
  String unableToLoadNamed(String name) {
    return 'Impossible de charger $name';
  }

  @override
  String get contactNotFound => 'Contact introuvable';

  @override
  String get yesterday => 'Hier';

  @override
  String get today => 'Aujourd\'hui';

  @override
  String get tomorrow => 'Demain';

  @override
  String get nowLabel => 'Maintenant';

  @override
  String get positionUnavailable => 'Position indisponible';

  @override
  String get contactUnavailable => 'Contact indisponible';

  @override
  String tapToViewKind(String kind) {
    return '$kind · Appuyer pour voir';
  }

  @override
  String kindViewOnce(String kind) {
    return '$kind · Vue unique';
  }

  @override
  String get viewOnceOpened => 'Ouvert';

  @override
  String viewOnceDownloadKind(String kind) {
    return '$kind · Télécharger';
  }

  @override
  String get viewOnceDownloading => 'Téléchargement…';

  @override
  String get viewOnceRetry => 'Échec — Réessayer';

  @override
  String get recordingEllipsis => 'Enregistrement…';

  @override
  String get unread => 'Non lus';

  @override
  String get addAContact => 'Ajouter un contact';

  @override
  String meetingNamed(String when) {
    return 'Réunion $when';
  }

  @override
  String get dataUnavailable => 'données indisponibles';

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get unableToLoadCountryList =>
      'Impossible de charger la liste des pays';

  @override
  String maxAudioParticipantsHint(int count) {
    return 'Maximum $count participants (appel audio). ';
  }

  @override
  String membersOnlyCount(int count) {
    return '$count membres';
  }

  @override
  String sendWithCount(int count) {
    return 'Envoyer ($count)';
  }

  @override
  String messagesCountLabel(int count) {
    return '$count messages';
  }

  @override
  String messagesCountLabelOne(int count) {
    return '$count message';
  }

  @override
  String deliveredAtTime(String time) {
    return 'Livré à $time';
  }

  @override
  String readAtTime(String time) {
    return 'Lu à $time';
  }

  @override
  String durationTapToReturn(String duration) {
    return '$duration · Toucher pour revenir';
  }

  @override
  String sessionBannerTapToReturn(String duration, String type) {
    return '$duration · $type · Toucher pour revenir';
  }

  @override
  String get usedLabel => 'Utilisé';

  @override
  String limitReachedParticipants(int total, String media) {
    return 'Maximum $total participants en $media (vous inclus)';
  }

  @override
  String get mediaLabelVideo => 'vidéo';

  @override
  String get mediaLabelAudio => 'audio';

  @override
  String activeStatusesTapToView(int count) {
    return '$count statut(s) actif(s) — appuyer pour voir';
  }

  @override
  String viewsCountLabel(int count) {
    return '$count vue(s)';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date à $time';
  }

  @override
  String selectedFeminineCount(int count) {
    return '$count sélectionnée(s)';
  }

  @override
  String selectionRatio(int count, int max) {
    return '$count/$max sélectionné(s)';
  }

  @override
  String get groupFallback => 'Groupe';

  @override
  String get reservedPhoneSearchHelp =>
      'Recherchez dans la liste admin ou saisissez un pattern complet (3 ch., 4 ch., ou 8 ch. XXYYZZTT). Les patterns peuvent être attribués directement sans être ajoutés à la liste.';

  @override
  String get reservedPhoneOnlyHint =>
      'Uniquement 3 ou 4 chiffres, ou 8 chiffres XXYYZZTT (ex. 11 22 33 44). Ces formes sont exclus de l\'inscription automatique.';

  @override
  String messagesSummaryMulti(int totalMessages, int convCount) {
    return '$totalMessages messages · $convCount conversations';
  }

  @override
  String messagesSummaryOne(int count) {
    return '$count nouveau message';
  }

  @override
  String messagesSummaryMany(int count) {
    return '$count nouveaux messages';
  }

  @override
  String dateAtTimeFull(int day, int month, int year, String time) {
    return '$day/$month/$year à $time';
  }

  @override
  String todayTimeShort(String time) {
    return 'Aujourd\'hui $time';
  }

  @override
  String get albumCannotBeForwarded => 'Cet album ne peut pas être transféré';

  @override
  String userHashId(Object id) {
    return 'Utilisateur #$id';
  }

  @override
  String listWithCount(int count) {
    return 'Liste ($count)';
  }

  @override
  String get listLabel => 'Liste';

  @override
  String get filterLabel => 'Filtre';

  @override
  String get freePlural => 'Libres';

  @override
  String get assignAction => 'Attribuer';

  @override
  String get messagesChannelName => 'Messages';

  @override
  String get searchEllipsis => 'Rechercher...';

  @override
  String get callNoun => 'Appel';

  @override
  String get allFilter => 'Tous';

  @override
  String get audioViewOnce => '🎵 Audio · Vue unique';

  @override
  String get mediaFallback => 'Média';

  @override
  String fileWithName(String name) {
    return '📎 $name';
  }

  @override
  String get groupsFilter => 'Groupes';

  @override
  String participantsSelected(int count) {
    return '$count participant(s) sélectionné(s)';
  }

  @override
  String get waitingForParticipants => 'En attente des participants…';

  @override
  String participantsCount(int count) {
    return '$count participants';
  }

  @override
  String durationParticipants(String duration, int count) {
    return '$duration · $count participants';
  }

  @override
  String participantsRatio(int current, int max) {
    return 'Participants ($current/$max)';
  }

  @override
  String confirmWithParticipants(String label, int count) {
    return '$label · $count participant(s)';
  }

  @override
  String dotParticipantsCount(int count) {
    return '· $count participant(s)';
  }

  @override
  String get text2 => 'Texte';

  @override
  String get publishAction => 'Publier';

  @override
  String get importAction => 'Importer';

  @override
  String get finishAction => 'Terminer';

  @override
  String get recordAction => 'Enregistrer';

  @override
  String get meLabel => 'Moi';

  @override
  String selfChatTitle(String name) {
    return '$name (Moi)';
  }

  @override
  String get messageYourself => 'M\'envoyer un message';

  @override
  String get selfChatSubtitle => 'Notes, rappels, fichiers';

  @override
  String get selfChatDeleteWarning =>
      'Toutes vos notes seront définitivement supprimées. Cette action est irréversible.';

  @override
  String get cannotCallYourself => 'Vous ne pouvez pas vous appeler vous-même';

  @override
  String get statusNoun => 'Statut';

  @override
  String get youLabel => 'Vous';

  @override
  String get hostLabel => 'Hôte';

  @override
  String get guestLabel => 'Invité';

  @override
  String get chatLabel => 'Chat';

  @override
  String get summaryLabel => 'Résumé';

  @override
  String get typeLabel => 'Type';

  @override
  String get accountLabel => 'Compte';

  @override
  String get adminDashboard => 'Tableau de bord Admin';

  @override
  String get superAdmin => 'Super Admin';

  @override
  String inMinutes(int mins) {
    return 'Dans ${mins}min';
  }

  @override
  String get participantFallback => 'Participant';

  @override
  String get userFallback => 'Utilisateur';

  @override
  String nameYouParen(String name) {
    return '$name (vous)';
  }

  @override
  String get contactsLabel => 'Contacts';

  @override
  String get searchUserByNameOrUsername =>
      'Recherchez un utilisateur par nom ou pseudo';

  @override
  String get endMeetingAction => 'Terminer';

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String hoursAndMinutesShort(int hours, int minutes) {
    return '$hours h $minutes';
  }

  @override
  String get formatBold => 'Gras';

  @override
  String get formatItalic => 'Italique';

  @override
  String get formatUnderline => 'Souligné';

  @override
  String get formatStrikethrough => 'Barré';

  @override
  String get formatHandwriting => 'Manuscrit';

  @override
  String get genderMale => 'Homme';

  @override
  String get genderFemale => 'Femme';

  @override
  String get avatarLabel => 'Avatar';

  @override
  String get nameUsernamePasswordRequired =>
      'Nom, pseudo et mot de passe requis';

  @override
  String get usersLabel => 'Utilisateurs';

  @override
  String get bannedUsers => 'Bannis';

  @override
  String get bannedLabel => 'Banni';

  @override
  String get adminsLabel => 'Admins';

  @override
  String get actionsLabel => 'Actions';

  @override
  String get conversationsLabel => 'Conversations';

  @override
  String get totalLabel => 'Total';

  @override
  String get commonBlock => 'Bloquer';

  @override
  String get messageNoun => 'Message';

  @override
  String get albumNoun => 'Album';

  @override
  String get favoriteSingular => 'Favori';

  @override
  String get hangUp => 'Raccrocher';

  @override
  String get viewAction => 'Voir';

  @override
  String invitationFrom(String name) {
    return 'Invitation de $name';
  }

  @override
  String get fileArchive => 'Archive';

  @override
  String get reservationLimitedTo3Or4OrXxyyzztt =>
      'Réservation limitée aux numéros 3 ou 4 chiffres, ou 8 chiffres au format XXYYZZTT (ex. 11 22 33 44)';

  @override
  String get discussionFallback => 'Discussion';

  @override
  String get overviewSection => 'Vue d\'ensemble';

  @override
  String rangeOfTotal(int from, int to, int total) {
    return '$from–$to sur $total';
  }

  @override
  String get tryAnotherName => 'Essayez un autre nom.';

  @override
  String get tryAnotherSearchTerm => 'Essayez un autre terme de recherche.';

  @override
  String andNOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '… et $count autres',
      one: '… et 1 autre',
    );
    return '$_temp0';
  }

  @override
  String get voiceCallOutgoing => 'Appel vocal sortant';

  @override
  String get voiceCallIncoming => 'Appel vocal entrant';

  @override
  String get videoCallOutgoing => 'Appel vidéo sortant';

  @override
  String get videoCallIncoming => 'Appel vidéo entrant';

  @override
  String reactionChipLabel(String emoji, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réactions',
      one: '1 réaction',
    );
    return '$emoji, $_temp0';
  }

  @override
  String get reactToMessage => 'Réagir';

  @override
  String get moreReactions => 'Plus de réactions';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSubtitle =>
      'Messages, appels, confidentialité';

  @override
  String get notifPrefsSectionAlerts => 'Alertes';

  @override
  String get notifPrefsSectionBehavior => 'Comportement';

  @override
  String get notifPrefMessages => 'Messages privés';

  @override
  String get notifPrefGroupMessages => 'Messages de groupe';

  @override
  String get notifPrefCalls => 'Appels';

  @override
  String get notifPrefMeetings => 'Réunions';

  @override
  String get notifPrefStatusView => 'Vues de statut';

  @override
  String get notifPrefBroadcasts => 'Annonces Alanya';

  @override
  String get notifPrefSound => 'Son';

  @override
  String get notifPrefVibration => 'Vibration';

  @override
  String get notifPrefPreviewTitle => 'Aperçu sur l\'écran verrouillé';

  @override
  String get notifPrefPreviewFull => 'Nom + contenu';

  @override
  String get notifPrefPreviewNameOnly => 'Nom seulement';

  @override
  String get notifPrefPreviewGeneric => 'Générique';

  @override
  String get notifPrefsSaveFailed =>
      'Impossible d\'enregistrer les préférences';

  @override
  String get convMuteAction => 'Notifications';

  @override
  String get convMuteSubtitle => 'Couper les alertes pour cette conversation';

  @override
  String convMuteTitle(String name) {
    return 'Notifications — $name';
  }

  @override
  String get convMute8h => 'Couper 8 heures';

  @override
  String get convMute1w => 'Couper 1 semaine';

  @override
  String get convMuteForever => 'Toujours couper';

  @override
  String get convUnmute => 'Réactiver les notifications';

  @override
  String convMuteDone(String name) {
    return 'Notifications coupées pour $name';
  }

  @override
  String convUnmuteDone(String name) {
    return 'Notifications réactivées pour $name';
  }

  @override
  String get convMuteFailed => 'Impossible de modifier le mute';

  @override
  String sysGroupCreated(String actor, String value) {
    return '$actor a créé le groupe « $value »';
  }

  @override
  String sysGroupCreatedByMe(String value) {
    return 'Vous avez créé le groupe « $value »';
  }

  @override
  String sysMemberAdded(String actor, String targets) {
    return '$actor a ajouté $targets';
  }

  @override
  String sysMemberAddedByMe(String targets) {
    return 'Vous avez ajouté $targets';
  }

  @override
  String sysMemberRemoved(String actor, String targets) {
    return '$actor a retiré $targets';
  }

  @override
  String sysMemberRemovedByMe(String targets) {
    return 'Vous avez retiré $targets';
  }

  @override
  String sysMemberLeft(String actor) {
    return '$actor a quitté le groupe';
  }

  @override
  String get sysMemberLeftByMe => 'Vous avez quitté le groupe';

  @override
  String sysGroupRenamed(String actor, String value) {
    return '$actor a renommé le groupe en « $value »';
  }

  @override
  String sysGroupRenamedByMe(String value) {
    return 'Vous avez renommé le groupe en « $value »';
  }

  @override
  String sysGroupPhotoChanged(String actor) {
    return '$actor a changé la photo du groupe';
  }

  @override
  String get sysGroupPhotoChangedByMe => 'Vous avez changé la photo du groupe';

  @override
  String sysGroupDescriptionChanged(String actor) {
    return '$actor a modifié la description';
  }

  @override
  String get sysGroupDescriptionChangedByMe =>
      'Vous avez modifié la description';

  @override
  String sysRolePromoted(String actor, String targets) {
    return '$actor a nommé $targets administrateur';
  }

  @override
  String sysRolePromotedByMe(String targets) {
    return 'Vous avez nommé $targets administrateur';
  }

  @override
  String sysRoleDemoted(String actor, String targets) {
    return '$actor a retiré les droits d\'administrateur à $targets';
  }

  @override
  String sysRoleDemotedByMe(String targets) {
    return 'Vous avez retiré les droits d\'administrateur à $targets';
  }

  @override
  String sysOnlyAdminsSendOn(String actor) {
    return '$actor a réservé l\'envoi aux administrateurs';
  }

  @override
  String get sysOnlyAdminsSendOnByMe =>
      'Vous avez réservé l\'envoi aux administrateurs';

  @override
  String sysOnlyAdminsSendOff(String actor) {
    return '$actor a autorisé tout le monde à écrire';
  }

  @override
  String get sysOnlyAdminsSendOffByMe =>
      'Vous avez autorisé tout le monde à écrire';

  @override
  String sysOnlyAdminsEditOn(String actor) {
    return '$actor a réservé la modification des infos aux administrateurs';
  }

  @override
  String get sysOnlyAdminsEditOnByMe =>
      'Vous avez réservé la modification des infos aux administrateurs';

  @override
  String sysOnlyAdminsEditOff(String actor) {
    return '$actor a autorisé tout le monde à modifier les infos';
  }

  @override
  String get sysOnlyAdminsEditOffByMe =>
      'Vous avez autorisé tout le monde à modifier les infos';

  @override
  String get sysGroupEventFallback => 'Le groupe a été mis à jour';

  @override
  String sysPreviewGroupCreated(String actor, String value) {
    return '$actor a créé « $value »';
  }

  @override
  String sysPreviewGroupCreatedShort(String actor) {
    return '$actor a créé le groupe';
  }

  @override
  String sysPreviewMemberAdded(String actor) {
    return '$actor a ajouté des membres';
  }

  @override
  String sysPreviewMemberRemoved(String actor) {
    return '$actor a retiré un membre';
  }

  @override
  String sysPreviewMemberLeft(String actor) {
    return '$actor a quitté le groupe';
  }

  @override
  String sysPreviewGroupRenamed(String actor) {
    return '$actor a renommé le groupe';
  }

  @override
  String sysPreviewGroupPhotoChanged(String actor) {
    return '$actor a changé la photo du groupe';
  }

  @override
  String sysPreviewGroupDescriptionChanged(String actor) {
    return '$actor a modifié la description';
  }

  @override
  String sysPreviewRolePromoted(String actor) {
    return '$actor a nommé un administrateur';
  }

  @override
  String sysPreviewRoleDemoted(String actor) {
    return '$actor a retiré des droits d\'administrateur';
  }

  @override
  String sysPreviewSettingsChanged(String actor) {
    return '$actor a modifié les réglages du groupe';
  }

  @override
  String get groupOwner => 'Propriétaire';

  @override
  String get groupAdmin => 'Admin';

  @override
  String get removeFromGroup => 'Retirer du groupe';

  @override
  String removeMemberConfirm(String name) {
    return 'Retirer $name du groupe ?';
  }

  @override
  String removeMemberDone(String name) {
    return '$name a été retiré du groupe';
  }

  @override
  String get dismissAdmin => 'Retirer les droits d\'administrateur';

  @override
  String get viewProfile => 'Voir le profil';

  @override
  String get groupDescription => 'Description';

  @override
  String get groupDescriptionHint => 'Ajouter une description…';

  @override
  String get noGroupDescription => 'Aucune description';

  @override
  String get renameGroup => 'Renommer le groupe';

  @override
  String get changeGroupPhoto => 'Changer la photo';

  @override
  String get groupSettings => 'Réglages du groupe';

  @override
  String get onlyAdminsCanSendLabel => 'Seuls les admins peuvent écrire';

  @override
  String get onlyAdminsCanSendSubtitle =>
      'Le groupe devient un canal d\'annonces';

  @override
  String get onlyAdminsCanEditInfoLabel =>
      'Seuls les admins modifient les infos';

  @override
  String get onlyAdminsCanEditInfoSubtitle => 'Nom, photo et description';

  @override
  String get hideHistoryForNewMembersLabel =>
      'Masquer l\'historique pour les nouveaux';

  @override
  String get hideHistoryForNewMembersSubtitle =>
      'Les membres ajoutés ne verront pas les messages antérieurs';

  @override
  String get onlyAdminsCanAddMembersLabel =>
      'Seuls les admins peuvent ajouter des membres';

  @override
  String get onlyAdminsCanAddMembersSubtitle =>
      'Inviter de nouveaux participants au groupe';

  @override
  String groupJoinBannerBody(String actor, String group) {
    return '$actor vous a ajouté au groupe « $group »';
  }

  @override
  String get stay => 'Rester';

  @override
  String sysHideHistoryOn(String actor) {
    return '$actor a masqué l\'historique pour les nouveaux membres';
  }

  @override
  String get sysHideHistoryOnByMe =>
      'Vous avez masqué l\'historique pour les nouveaux membres';

  @override
  String sysHideHistoryOff(String actor) {
    return '$actor a rendu l\'historique visible pour les nouveaux membres';
  }

  @override
  String get sysHideHistoryOffByMe =>
      'Vous avez rendu l\'historique visible pour les nouveaux membres';

  @override
  String sysOnlyAdminsAddOn(String actor) {
    return '$actor a réservé l\'ajout de membres aux administrateurs';
  }

  @override
  String get sysOnlyAdminsAddOnByMe =>
      'Vous avez réservé l\'ajout de membres aux administrateurs';

  @override
  String sysOnlyAdminsAddOff(String actor) {
    return '$actor a autorisé tout le monde à ajouter des membres';
  }

  @override
  String get sysOnlyAdminsAddOffByMe =>
      'Vous avez autorisé tout le monde à ajouter des membres';

  @override
  String get mentionsOnlyLabel => 'Uniquement les mentions';

  @override
  String get mentionsOnlySubtitle =>
      'N\'être alerté que si l\'on vous mentionne';

  @override
  String get youWereRemovedFromGroup =>
      'Vous ne faites plus partie de ce groupe';

  @override
  String get notAllowedGroupAction => 'Action non autorisée';

  @override
  String get ownerMustTransferOnLeave =>
      'Vous êtes propriétaire : le groupe sera confié au membre le plus ancien.';

  @override
  String get groupInfoUpdated => 'Infos du groupe mises à jour';

  @override
  String get groupUpdateFailed => 'Impossible de modifier le groupe';

  @override
  String get announcementOnlyAdmins =>
      'Seuls les administrateurs peuvent envoyer des messages';

  @override
  String get officialAccountReadonlyBanner =>
      'Ce compte diffuse des annonces. Vous ne pouvez pas y répondre.';

  @override
  String get accountBadgeVerified => 'Abonné Alanya Plus';

  @override
  String get accountBadgeBusinessDeclared => 'Commerce déclaré';

  @override
  String get accountBadgeBusinessVerified => 'Commerce vérifié';

  @override
  String get accountBadgeOfficial => 'Compte officiel Alanya';

  @override
  String get mentionAll => '@Tous';

  @override
  String mentionAllSubtitle(int count) {
    return 'Alerte les $count membres';
  }

  @override
  String get mentionYou => 'Vous';

  @override
  String get jumpToMention => 'Aller à la mention suivante';

  @override
  String get unreadMessagesSeparator => 'Messages non lus';

  @override
  String get signupEmailOptionalHint => 'Adresse e-mail (optionnel)';

  @override
  String get signupEmailOptionalSubtitle =>
      'Uniquement pour récupérer votre mot de passe';

  @override
  String get signupNoEmailWarningTitle => 'Sans adresse e-mail';

  @override
  String get signupNoEmailWarningBody =>
      'Sans e-mail, vous ne pourrez pas récupérer votre compte si vous oubliez votre ID Alanya ou votre mot de passe.';

  @override
  String get signupAddEmail => 'Ajouter un e-mail';

  @override
  String get signupContinueWithoutEmail => 'Continuer';

  @override
  String get signupCredentialsNoEmailReminder =>
      'Sans e-mail, la récupération de compte est impossible. Vous pourrez en ajouter un à tout moment dans Profil → Compte → Modifier le profil (vérification par code OTP).';

  @override
  String get signupCredentialsEmailOk =>
      'Votre e-mail pourra servir à récupérer votre mot de passe en cas d\'oubli.';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get emailNotSet => 'Non renseigné';

  @override
  String get emailNeededForRecovery =>
      'Nécessaire pour récupérer votre mot de passe';

  @override
  String get emailMissingRecoveryBanner =>
      'Aucune adresse e-mail : vous ne pourrez pas récupérer votre compte en cas d\'oubli d\'identifiants.';

  @override
  String get accountSecurityTitle => 'Compte et sécurité';

  @override
  String get accountSecuritySubtitle => 'E-mail et mot de passe';

  @override
  String get changeEmailTitle => 'Adresse e-mail';

  @override
  String get changeEmailSubtitleAdd =>
      'Ajoutez une adresse pour pouvoir récupérer votre mot de passe.';

  @override
  String get changeEmailSubtitleReplace =>
      'Un code de vérification sera envoyé à la nouvelle adresse.';

  @override
  String get changeEmailCurrentLabel => 'Adresse actuelle';

  @override
  String get changeEmailNewLabel => 'Nouvelle adresse e-mail';

  @override
  String get changeEmailAddLabel => 'Votre adresse e-mail';

  @override
  String get changeEmailStep1 => '1. Adresse';

  @override
  String get changeEmailStep2 => '2. Vérification';

  @override
  String get changeEmailWhyOtp =>
      'Pour confirmer que vous avez accès à cette adresse, un code à 6 chiffres vous sera envoyé par e-mail.';

  @override
  String get changeEmailCheckInbox =>
      'Ouvrez votre boîte mail et saisissez le code reçu. Vérifiez aussi les spams.';

  @override
  String get changeEmailEditAddress => 'Modifier l\'adresse';

  @override
  String get changeEmailSendCode => 'Envoyer le code';

  @override
  String get changeEmailOtpTitle => 'Code de vérification';

  @override
  String changeEmailOtpSubtitle(String email) {
    return 'Saisissez le code envoyé à $email';
  }

  @override
  String get changeEmailResendCode => 'Renvoyer le code';

  @override
  String get changeEmailConfirm => 'Valider et enregistrer';

  @override
  String get changeEmailSuccess => 'Adresse e-mail mise à jour';

  @override
  String get changePasswordTitle => 'Changer le mot de passe';

  @override
  String get changePasswordSubtitle => 'Le mot de passe actuel est requis';

  @override
  String get changePasswordCurrent => 'Mot de passe actuel';

  @override
  String get changePasswordNew => 'Nouveau mot de passe';

  @override
  String get changePasswordConfirm => 'Confirmer le nouveau mot de passe';

  @override
  String get changePasswordSubmit => 'Enregistrer';

  @override
  String get changePasswordSuccess => 'Mot de passe modifié';

  @override
  String get changePasswordSameAsCurrent =>
      'Le nouveau mot de passe doit être différent de l\'actuel';

  @override
  String get profileNoEmailChip =>
      'Ajoutez un e-mail pour sécuriser votre compte';

  @override
  String get addToCall => 'Ajouter à l\'appel';

  @override
  String get transferCall => 'Transférer l\'appel';

  @override
  String get transferCallSheetTitle => 'Transférer l\'appel';

  @override
  String get transferCallConfirmationTitle => 'Transférer l\'appel ?';

  @override
  String get transferCallConfirmationBody =>
      'Le contact rejoindra d\'abord l\'appel. Vous quitterez automatiquement environ 10 secondes après que sa connexion sera établie.';

  @override
  String get addToCallConfirmBody =>
      'Inviter ce contact à rejoindre l\'appel en cours ?';

  @override
  String get transferWaitingForParticipant => 'En attente de réponse…';

  @override
  String get transferWaitingForConnection => 'Connexion en cours…';

  @override
  String get transferCountdown =>
      'Transfert en cours… Vous quitterez bientôt l\'appel.';

  @override
  String transferCountdownSeconds(int seconds) {
    return 'Transfert · ${seconds}s';
  }

  @override
  String get transferCompleted => 'Appel transféré';

  @override
  String get mediaConnectionFailed =>
      'La connexion média n\'a pas pu être établie';

  @override
  String get conferenceTransferInviteBody =>
      'souhaite vous transférer cet appel';

  @override
  String get confCallOfThree => 'Appel à 3';

  @override
  String get confRinging => 'Sonnerie…';

  @override
  String confAddingInvitee(String name) {
    return '$name est en train d\'être ajouté';
  }

  @override
  String confSomeoneAdds(String who, String name) {
    return '$who ajoute $name';
  }

  @override
  String confJoinedCall(String name) {
    return '$name a rejoint l\'appel';
  }

  @override
  String confLeftCall(String name) {
    return '$name a quitté l\'appel';
  }

  @override
  String confDeclined(String name) {
    return '$name a refusé de rejoindre';
  }

  @override
  String confBusy(String name) {
    return '$name est déjà en appel';
  }

  @override
  String confNoAnswer(String name) {
    return '$name n\'a pas répondu';
  }

  @override
  String confNotJoined(String name) {
    return '$name n\'a pas rejoint l\'appel';
  }

  @override
  String get confAddAlreadyUsed =>
      'Un participant a déjà été ajouté à cet appel';

  @override
  String confCannotAdd(String name) {
    return '$name ne peut pas être ajoutée';
  }

  @override
  String get confAddFailed => 'L\'ajout n\'a pas pu aboutir';

  @override
  String confInviteSubtitle(String name) {
    return 'vous ajoute à un appel avec $name';
  }

  @override
  String get confAddSheetTitle => 'Ajouter à l\'appel';

  @override
  String get noContactsToAdd => 'Aucun contact à ajouter';

  @override
  String get confAlreadyInCall => 'déjà là';

  @override
  String get confContactBusy => 'en appel';

  @override
  String get confCancelInvite => 'Annuler';

  @override
  String get qrMyCodeTitle => 'Mon code QR';

  @override
  String get qrMyCodeTabCode => 'Mon code';

  @override
  String get qrMyCodeTabScan => 'Scanner';

  @override
  String get qrMyCodeSubtitle =>
      'Faites scanner ce code pour être ajouté en contact préféré.';

  @override
  String get qrMyCodeShare => 'Partager';

  @override
  String qrMyCodeExpiresIn(String time) {
    return 'Expire dans $time';
  }

  @override
  String get qrMyCodeValidityNote =>
      'Valable 10 minutes et pour une seule personne. Un nouveau code est généré automatiquement.';

  @override
  String get qrMyCodeNewCode => 'Nouveau code';

  @override
  String get qrMyCodeShareValidity =>
      'Ce code est valable 10 minutes et pour une seule personne.';

  @override
  String get qrScanReturnTitle => 'Nouveau contact';

  @override
  String qrScanReturnBody(String name) {
    return '$name vous a ajouté à ses contacts préférés avec votre code QR. L\'ajouter en retour ?';
  }

  @override
  String get qrScanReturnAccept => 'Ajouter';

  @override
  String get qrScanReturnDecline => 'Non merci';

  @override
  String get qrScanReturnFailed => 'Impossible d\'ajouter ce contact';

  @override
  String qrScannedMutualInfo(String name) {
    return '$name vous a ajouté avec votre code QR';
  }

  @override
  String get qrNoteFieldHint => 'Ajouter une note (lieu, contexte…)';

  @override
  String get qrNoteSaved => 'Note enregistrée';

  @override
  String get qrNoteFailed => 'Impossible d\'enregistrer la note';

  @override
  String get qrContactsFilterAll => 'Tous';

  @override
  String get qrContactsFilterQr => 'Par QR';

  @override
  String get qrContactAddedViaQr => 'Ajouté par QR code';

  @override
  String qrContactAddedViaQrOn(String date) {
    return 'Ajouté par QR code · $date';
  }

  @override
  String get qrMyCodeShareSheetTitle => 'Partager mon code';

  @override
  String get qrMyCodeShareLink => 'Partager le lien';

  @override
  String get qrMyCodeShareLinkHint => 'Lien cliquable et Alanya ID';

  @override
  String get qrMyCodeShareImage => 'Partager l\'image';

  @override
  String get qrMyCodeShareImageHint => 'La carte à scanner';

  @override
  String qrMyCodeShareId(String id) {
    return 'Mon Alanya ID : $id';
  }

  @override
  String get qrMyCodeRegenerate => 'Régénérer';

  @override
  String get qrMyCodeRegenerateConfirmTitle => 'Régénérer votre code ?';

  @override
  String get qrMyCodeRegenerateConfirmBody =>
      'L\'ancien code cessera immédiatement de fonctionner. Les personnes qui l\'ont enregistré ne pourront plus vous ajouter avec.';

  @override
  String get qrMyCodeRegenerateDone => 'Nouveau code généré';

  @override
  String qrMyCodeShareText(String name) {
    return 'Ajoutez-moi sur Alanya : je suis $name.';
  }

  @override
  String get qrScanTitle => 'Scanner un code';

  @override
  String get qrScanEntryButton => 'Scanner un code';

  @override
  String get qrScanInstruction => 'Cadrez le code QR d\'un contact';

  @override
  String get qrScanErrorUnreadable =>
      'Code illisible. Rapprochez-vous et réessayez.';

  @override
  String get qrScanErrorUnknown => 'Ce code est expiré ou inconnu.';

  @override
  String get qrScanOwnCode => 'C\'est votre propre code.';

  @override
  String qrScanAddSuccess(String name) {
    return '$name a été ajouté à vos contacts préférés';
  }

  @override
  String qrScanAlreadyContact(String name) {
    return '$name est déjà dans vos contacts préférés';
  }

  @override
  String get qrScanResultAdded => 'Ajouté à vos contacts';

  @override
  String get qrScanResultAlready => 'Déjà dans vos contacts';

  @override
  String get qrScanActionMessage => 'Message';

  @override
  String get qrScanActionDetails => 'Voir détails';

  @override
  String get qrScanUndo => 'Annuler';

  @override
  String qrScanUndone(String name) {
    return '$name a été retiré de vos contacts préférés';
  }

  @override
  String get qrScanUndoFailed => 'Impossible d\'annuler l\'ajout';

  @override
  String get qrScanCameraDenied =>
      'Alanya a besoin d\'accéder à la caméra pour scanner un code.';

  @override
  String get qrScanOpenSettings => 'Ouvrir les réglages';

  @override
  String get qrScanTorchOn => 'Lampe allumée';

  @override
  String get qrScanTorchOff => 'Lampe éteinte';

  @override
  String get qrScanImportImage => 'Importer une image';

  @override
  String get qrScanImportNoCode => 'Aucun code QR dans cette image.';

  @override
  String get qrScanImportNotAlanya => 'Ce code QR n\'est pas un code Alanya.';

  @override
  String get qrScanImportFailed => 'Impossible de lire cette image.';

  @override
  String get qrLoginTitle => 'Connexion par QR code';

  @override
  String get qrLoginEntryButton => 'Se connecter avec un code QR';

  @override
  String get qrLoginUsePassword => 'Se connecter avec mon mot de passe';

  @override
  String get qrLoginExplanation =>
      'Ouvrez Alanya sur votre téléphone déjà connecté, allez dans Compte et sécurité, puis scannez ce code.';

  @override
  String get qrLoginDeviceNotTrustedNotice =>
      'Ce téléphone n\'est pas encore reconnu pour ce compte. Faites scanner ce code depuis un appareil déjà connecté. Si vous n\'y avez plus accès, réinitialisez votre mot de passe depuis l\'écran de connexion.';

  @override
  String qrLoginExpiresIn(String time) {
    return 'Expire dans $time';
  }

  @override
  String get qrLoginStatusWaiting => 'En attente de scan…';

  @override
  String get qrLoginStatusScanned =>
      'Code scanné. Confirmez sur votre autre appareil.';

  @override
  String get qrLoginStatusRejected =>
      'Connexion refusée depuis votre autre appareil.';

  @override
  String get qrLoginStatusExpired => 'Ce code a expiré.';

  @override
  String get qrLoginRegenerate => 'Générer un nouveau code';

  @override
  String get qrLoginNetworkError =>
      'Connexion impossible. Vérifiez votre réseau et réessayez.';

  @override
  String get qrApproveTitle => 'Nouvelle connexion';

  @override
  String get qrApproveIntro =>
      'Ce code vient d\'être scanné depuis cet appareil :';

  @override
  String get qrApproveDeviceLabel => 'Appareil (nom déclaré)';

  @override
  String get qrApprovePlatformLabel => 'Plateforme';

  @override
  String get qrApproveRequestedLabel => 'Demandé';

  @override
  String get qrApproveIpLabel => 'Adresse IP';

  @override
  String get qrApproveLocationLabel => 'Lieu approximatif';

  @override
  String get qrApproveDeclaredNotice =>
      'Le nom et la plateforme sont annoncés par l\'appareil qui demande la connexion : ils peuvent être falsifiés. Seule l\'adresse IP est constatée par Alanya.';

  @override
  String get qrApproveSecurityWarning =>
      'Si vous n\'êtes pas à l\'origine de cette demande, refusez-la et changez votre mot de passe.';

  @override
  String get qrApproveReject => 'Refuser';

  @override
  String get qrApproveConfirm => 'Confirmer';

  @override
  String get qrApproveDone => 'Appareil connecté';

  @override
  String get qrApproveRejectDone => 'Connexion refusée';

  @override
  String get qrApproveSessionExpired =>
      'Cette demande a expiré. Faites afficher un nouveau code sur l\'autre appareil.';

  @override
  String get qrDevicesTitle => 'Appareils connectés';

  @override
  String get qrDevicesEntryTitle => 'Appareils connectés';

  @override
  String get qrDevicesEntrySubtitle => 'Voir où votre compte est ouvert';

  @override
  String get qrLinkDeviceTitle => 'Lier un nouvel appareil';

  @override
  String get qrLinkDeviceSubtitle =>
      'Scanner le code affiché sur l\'autre appareil';

  @override
  String get qrDevicesThisDevice => 'Cet appareil';

  @override
  String get qrDevicesUnknownDevice => 'Appareil inconnu';

  @override
  String get qrDevicesMethodPassword => 'Connexion par mot de passe';

  @override
  String get qrDevicesMethodSignup => 'Appareil d\'inscription';

  @override
  String get qrDevicesMethodQr => 'Connexion par code QR';

  @override
  String qrDevicesLastActive(String date) {
    return 'Actif $date';
  }

  @override
  String get qrDevicesRevoke => 'Déconnecter';

  @override
  String get qrDevicesRevokeConfirmTitle => 'Déconnecter cet appareil ?';

  @override
  String qrDevicesRevokeConfirmBody(String name) {
    return '$name sera déconnecté immédiatement. Il faudra saisir votre mot de passe pour s\'y reconnecter.';
  }

  @override
  String get qrDevicesRevokeDone => 'Appareil déconnecté';

  @override
  String get qrDevicesEmpty => 'Aucun autre appareil connecté';

  @override
  String get qrDevicesLoadError => 'Impossible de charger vos appareils';

  @override
  String get qrDevicesIosNote =>
      'Sur iPhone, un appareil peut réapparaître comme un nouvel appareil dans cette liste après une réinstallation d\'Alanya.';

  @override
  String qrBannerNewDevice(String name) {
    return 'Nouvel appareil connecté : $name';
  }

  @override
  String get qrBannerSignedOutRemotely =>
      'Cet appareil a été déconnecté depuis un autre appareil.';

  @override
  String get myAccountLabel => 'Mon compte';

  @override
  String get accountHubTitle => 'Mon compte';

  @override
  String get accountHubSecurityScore => 'Score de sécurité';

  @override
  String accountHubSecurityScoreValue(int score, int max) {
    return '$score / $max';
  }

  @override
  String get securityScoreAddEmail =>
      'Ajoutez un e-mail pour améliorer votre score.';

  @override
  String get securityScoreAddBiometric =>
      'Activez la biométrie pour améliorer votre score.';

  @override
  String get accountHubSectionIdentity => 'Identité';

  @override
  String get accountHubSectionProtection => 'Protection';

  @override
  String get accountHubSectionData => 'Données';

  @override
  String get accountHubEditProfile => 'Modifier le profil';

  @override
  String get accountHubEditProfileSubtitle => 'Nom, pseudo, bio, photo';

  @override
  String get accountHubMyMedia => 'Mes médias';

  @override
  String get accountHubPrivacy => 'Confidentialité';

  @override
  String get accountHubPrivacySubtitle => 'Visibilité, blocage, lectures';

  @override
  String get accountHubSecurity => 'Sécurité du compte';

  @override
  String get accountHubSecuritySubtitle => 'Mot de passe, appareils, biométrie';

  @override
  String get accountHubDataAccount => 'Données et compte';

  @override
  String get accountHubDataAccountSubtitle => 'Export RGPD, suppression';

  @override
  String get accountHubProfilePreview => 'Aperçu profil';

  @override
  String get accountHubProfilePreviewSubtitle => 'Voir comme vos contacts';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileBioHint =>
      'Parlez de vous en quelques mots (500 caractères max)';

  @override
  String get profilePreviewLink => 'Aperçu du profil';

  @override
  String get myMediaTitle => 'Mes médias';

  @override
  String get myMediaPlaceholder =>
      'Vos photos et vidéos partagées apparaîtront ici.';

  @override
  String get storageTitle => 'Stockage et cache';

  @override
  String get storageUsed => 'Espace utilisé';

  @override
  String get storageBreakdownTitle => 'Répartition';

  @override
  String get storageMediaCache => 'Cache médias';

  @override
  String get storageDatabase => 'Base de données';

  @override
  String get storageTempFiles => 'Fichiers temporaires';

  @override
  String get storageOther => 'Autres données';

  @override
  String get storageClearMediaCache => 'Vider le cache médias';

  @override
  String get storageClearTemp => 'Vider les fichiers temporaires';

  @override
  String get storageClearCacheConfirm =>
      'Les fichiers en cache seront supprimés. Les médias encore présents sur le serveur pourront être retéléchargés ; les plus anciens seront définitivement perdus.';

  @override
  String get storageClearCacheDone => 'Cache médias vidé';

  @override
  String get storageClearTempDone => 'Fichiers temporaires supprimés';

  @override
  String get networkDataTitle => 'Réseau et données';

  @override
  String get networkDataSectionNetwork => 'Réseau';

  @override
  String get networkWifiOnly => 'Wi-Fi uniquement';

  @override
  String get networkWifiOnlySubtitle =>
      'Ne télécharge les médias que sur Wi-Fi';

  @override
  String get networkDataSaver => 'Économiseur de données';

  @override
  String get networkDataSaverSubtitle =>
      'Réduit la qualité et les téléchargements automatiques';

  @override
  String get settingsSectionCommunication => 'Communication';

  @override
  String get settingsSectionApplication => 'Application';

  @override
  String get settingsSectionInformation => 'Informations';

  @override
  String get settingsStorage => 'Stockage et cache';

  @override
  String get settingsStorageSubtitle => 'Espace utilisé et nettoyage';

  @override
  String get settingsNetwork => 'Réseau et données';

  @override
  String get settingsNetworkSubtitle => 'Wi-Fi et économiseur de données';

  @override
  String get settingsAccessibility => 'Accessibilité';

  @override
  String get settingsAccessibilitySubtitle => 'Texte et animations';

  @override
  String get settingsAbout => 'À propos et mentions légales';

  @override
  String get settingsMutedConversations => 'Conversations silencieuses';

  @override
  String get accessibilityTitle => 'Accessibilité';

  @override
  String get accessibilitySectionDisplay => 'Affichage';

  @override
  String get accessibilityFontScale => 'Taille du texte';

  @override
  String get accessibilityFontScaleSmall => 'Petit';

  @override
  String get accessibilityFontScaleDefault => 'Normal';

  @override
  String get accessibilityFontScaleMedium => 'Grand';

  @override
  String get accessibilityFontScaleLarge => 'Très grand';

  @override
  String get accessibilityReduceMotion => 'Réduire les animations';

  @override
  String get accessibilityReduceMotionSubtitle =>
      'Limite les transitions et effets visuels';

  @override
  String get accessibilitySaveFailed =>
      'Impossible d\'enregistrer les préférences';

  @override
  String get mutedConversationsTitle => 'Conversations silencieuses';

  @override
  String get mutedConversationsEmpty => 'Aucune conversation silencieuse';

  @override
  String mutedConversationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversations',
      one: '1 conversation',
    );
    return '$_temp0';
  }

  @override
  String get mutedForeverLabel => 'Silencieux indéfiniment';

  @override
  String mutedUntilLabel(String date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get dndScheduleTitle => 'Ne pas déranger';

  @override
  String get dndEnabled => 'Planifier';

  @override
  String get dndEnabledSubtitle =>
      'Couper les notifications sur un créneau horaire';

  @override
  String get dndScheduleHours => 'Horaires';

  @override
  String get dndStartTime => 'Début';

  @override
  String get dndEndTime => 'Fin';

  @override
  String get dndDays => 'Jours actifs';

  @override
  String get dndDayMon => 'Lun';

  @override
  String get dndDayTue => 'Mar';

  @override
  String get dndDayWed => 'Mer';

  @override
  String get dndDayThu => 'Jeu';

  @override
  String get dndDayFri => 'Ven';

  @override
  String get dndDaySat => 'Sam';

  @override
  String get dndDaySun => 'Dim';

  @override
  String get dndSaveFailed => 'Impossible d\'enregistrer le planning';

  @override
  String get aboutTitle => 'À propos';

  @override
  String get aboutSectionLegal => 'Mentions légales';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutTerms => 'Conditions d\'utilisation';

  @override
  String get aboutPrivacy => 'Politique de confidentialité';

  @override
  String get aboutLicenses => 'Licences open source';

  @override
  String get aboutSupport => 'Contacter le support';

  @override
  String get aboutCopyright => '© 2026 Alanya · Fait avec soin à Yaoundé';

  @override
  String get exportDataTitle => 'Données et compte';

  @override
  String get exportSectionYourData => 'Vos données';

  @override
  String get exportSectionDanger => 'Zone sensible';

  @override
  String get exportPhase1Title => 'Export rapide (RGPD)';

  @override
  String get exportPhase1Subtitle =>
      'Profil, contacts, métadonnées — disponible immédiatement';

  @override
  String get exportPhase2Title => 'Export complet';

  @override
  String get exportPhase2Subtitle =>
      'Inclut messages et médias — prêt sous ~24 h';

  @override
  String get exportRequestPhase1 => 'Exporter maintenant';

  @override
  String get exportRequestPhase2 => 'Demander l\'export complet';

  @override
  String get exportPhase1ReadyTitle => 'Export prêt';

  @override
  String get exportPhase2Started =>
      'Export complet demandé — vous serez notifié';

  @override
  String get exportInProgress => 'Export en cours';

  @override
  String get exportInProgressHint =>
      'Prêt dans ~24 h · notification à l\'achèvement';

  @override
  String get exportReady => 'Votre export est prêt';

  @override
  String get exportDownload => 'Télécharger';

  @override
  String get deleteAccountTitle => 'Supprimer le compte';

  @override
  String get deleteAccountEntrySubtitle => 'Action irréversible';

  @override
  String get deleteAccountStep1Title => 'Action irréversible';

  @override
  String get deleteAccountStep1Bullet1 => 'Suppression des messages et médias';

  @override
  String get deleteAccountStep1Bullet2 => 'Retrait de tous les groupes';

  @override
  String get deleteAccountStep1Bullet3 =>
      'Numéro libéré après la période de grâce';

  @override
  String get deleteAccountContinue => 'Continuer';

  @override
  String get deleteAccountPassword => 'Mot de passe';

  @override
  String get deleteAccountConfirmLabel => 'Taper SUPPRIMER';

  @override
  String get deleteAccountConfirmWord => 'SUPPRIMER';

  @override
  String get deleteAccountConfirmMismatch => 'Tapez SUPPRIMER pour confirmer';

  @override
  String get deleteAccountSubmit => 'Supprimer mon compte';

  @override
  String get deleteAccountGraceTitle => 'Suppression planifiée';

  @override
  String deleteAccountGraceBody(String date) {
    return 'Votre compte sera définitivement supprimé le $date. Vous pouvez annuler d\'ici là.';
  }

  @override
  String get biometricLock => 'Verrouillage biométrique';

  @override
  String get biometricLockTitle => 'Alanya est verrouillé';

  @override
  String get biometricLockUnlock => 'Déverrouiller';

  @override
  String get biometricLockSubtitle =>
      'Empreinte ou reconnaissance faciale à l\'ouverture';

  @override
  String get biometricLockEnableConfirm =>
      'Confirmez votre empreinte pour activer le verrou';

  @override
  String get biometricLockUnavailable =>
      'Biométrie indisponible sur cet appareil';

  @override
  String get accountSecuritySectionProtection => 'Protection';

  @override
  String get logoutAllDevices => 'Déconnecter tous les appareils';

  @override
  String get logoutAllDevicesSubtitle =>
      'Ferme toutes les sessions sauf celle-ci';

  @override
  String get logoutAllDevicesConfirm =>
      'Tous les autres appareils seront déconnectés immédiatement.';

  @override
  String get logoutAllDevicesAction => 'Déconnecter';

  @override
  String get logoutAllDevicesDone => 'Autres appareils déconnectés';

  @override
  String get logoutAllDevicesFailed =>
      'Impossible de déconnecter tous les appareils';

  @override
  String get privacySectionWhoCanSee => 'Qui peut me voir';

  @override
  String get privacySectionMessages => 'Messages';

  @override
  String get privacySectionLists => 'Listes et groupes';

  @override
  String get privacyLastSeen => 'Dernière connexion';

  @override
  String get privacyOnlineStatus => 'Statut en ligne';

  @override
  String get privacyProfilePhoto => 'Photo de profil';

  @override
  String get privacyReadReceipts => 'Accusés de lecture';

  @override
  String get privacyReadReceiptsSubtitle =>
      'Envoyer et recevoir les confirmations de lecture';

  @override
  String get privacyNotificationPreview => 'Aperçu des notifications';

  @override
  String get privacyBlockedContacts => 'Contacts bloqués';

  @override
  String get privacyBlockedContactsEmpty => 'Aucun contact bloqué';

  @override
  String privacyBlockedContactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '1 contact',
    );
    return '$_temp0';
  }

  @override
  String get privacyAddToGroups => 'Ajout aux groupes';

  @override
  String get privacyVisibilityEveryone => 'Tout le monde';

  @override
  String get privacyVisibilityContacts => 'Mes contacts';

  @override
  String get privacyVisibilityNobody => 'Personne';

  @override
  String get privacySaveFailed => 'Impossible d\'enregistrer les préglages';

  @override
  String get onboardingCredentialsTitle => 'Vos identifiants';

  @override
  String get onboardingCredentialsSubtitle =>
      'Conservez ces informations en lieu sûr.';

  @override
  String get onboardingCredentialsBanner =>
      'Notez votre numéro Alanya et votre mot de passe — ils ne seront plus affichés.';

  @override
  String get onboardingProfileTitle => 'Votre profil';

  @override
  String get onboardingProfileSubtitle =>
      'Photo, genre, âge, pays, bio : complétez maintenant ou plus tard dans Mon compte.';

  @override
  String get profileBioDefault => 'Salut, je suis sur Alanya';

  @override
  String get onboardingPersonalizeTitle => 'Personnaliser Alanya';

  @override
  String get onboardingPersonalizeSubtitle =>
      'Thème, langue et verrouillage. Modifiable à tout moment dans Paramètres.';

  @override
  String onboardingStepOf(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get onboardingCountryTitle => 'Votre pays';

  @override
  String get onboardingCountrySubtitle =>
      'Aide vos contacts à vous identifier.';

  @override
  String get onboardingPhotoTitle => 'Photo de profil';

  @override
  String get onboardingPhotoSubtitle =>
      'Ajoutez une photo ou passez cette étape.';

  @override
  String get onboardingPhotoChooseGallery => 'Choisir dans la galerie';

  @override
  String get onboardingPhotoCamera => 'Prendre une photo';

  @override
  String get onboardingPhotoFailed => 'Impossible d\'ajouter la photo';

  @override
  String get onboardingBioTitle => 'Quelques mots sur vous';

  @override
  String get onboardingBioSubtitle =>
      'Présentez-vous en une phrase (optionnel).';

  @override
  String get onboardingBioHint => 'Salut, je suis sur Alanya';

  @override
  String get onboardingPreferencesTitle => 'Préférences';

  @override
  String get onboardingPreferencesSubtitle =>
      'Thème et langue de l\'application.';

  @override
  String get onboardingThemeLabel => 'Thème';

  @override
  String get onboardingLanguageLabel => 'Langue';

  @override
  String get onboardingBiometricTitle => 'Protéger l\'accès';

  @override
  String get onboardingBiometricSubtitle =>
      'Un geste rapide à chaque retour dans l\'app.';

  @override
  String get onboardingBiometricFriendlyTitle =>
      'Empreinte ou reconnaissance faciale';

  @override
  String get onboardingBiometricFriendlyBody =>
      'Activez le déverrouillage rapide. Vous pourrez le modifier dans Paramètres.';

  @override
  String get onboardingBiometricUnavailable =>
      'Biométrie indisponible — vous pourrez l\'activer plus tard dans les paramètres.';

  @override
  String get onboardingCompleteTitle => 'C\'est parti !';

  @override
  String get onboardingCompleteSubtitle => 'Votre compte est prêt.';

  @override
  String get onboardingCompleteMessage =>
      'Explorez Alanya et restez connecté avec vos proches.';

  @override
  String get onboardingCompleteCta => 'Découvrir Alanya';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingSkipAll => 'Configurer plus tard';

  @override
  String get onboardingSkipAllTitle => 'Passer la configuration ?';

  @override
  String get onboardingSkipAllBody =>
      'Vous pourrez compléter votre profil à tout moment dans Mon compte.';

  @override
  String get onboardingSkipAllCredentialsBody =>
      'Vous ne reverrez plus votre mot de passe ici. Complétez votre profil quand vous voulez dans Mon compte.';

  @override
  String get onboardingSkipAllRecoveryBody =>
      'Vous ne reverrez plus votre mot de passe ici, et votre code de récupération ne réapparaîtra que dans Mon compte → Sécurité. Notez-les avant de continuer.';

  @override
  String get onboardingSaveFailed =>
      'Enregistrement impossible — réessayez ou passez cette étape.';

  @override
  String get onboardingCredentialsBannerNoEmail =>
      'Notez votre numéro Alanya, votre mot de passe et votre code de récupération — ils ne seront plus affichés ici.';

  @override
  String get onboardingPhotoAdd => 'Appuyez pour ajouter une photo';

  @override
  String get onboardingIdentityTitle => 'À propos de vous';

  @override
  String get onboardingIdentitySubtitle =>
      'Genre et âge ne seront plus modifiables une fois enregistrés.';

  @override
  String get profileGenderLabel => 'Genre';

  @override
  String get profileIdentitySection => 'Identité';

  @override
  String get profileGenderSegmentPreferNotSay => 'Ne pas dire';

  @override
  String get profileGenderMale => 'Homme';

  @override
  String get profileGenderFemale => 'Femme';

  @override
  String get profileGenderOther => 'Autre';

  @override
  String get profileGenderUnspecified => 'Je préfère ne pas dire';

  @override
  String get profileAgeLabel => 'Âge';

  @override
  String get profileAgeSuffix => 'ans';

  @override
  String profileAgeBirthYear(int year) {
    return 'Année de naissance ≈ $year';
  }

  @override
  String profileAgeInvalid(int min, int max) {
    return 'Âge invalide (entre $min et $max ans)';
  }

  @override
  String get recoveryCodeTitle => 'Code de récupération';

  @override
  String get recoveryCodeKeepSafe => 'À conserver';

  @override
  String get recoveryCodeOnboardingHint =>
      'Sans adresse e-mail, ce code est votre seule façon de reprendre la main sur votre compte. Notez-le ailleurs que sur ce téléphone.';

  @override
  String get recoveryCodeCopied => 'Code de récupération copié';

  @override
  String get recoveryCodeEntrySubtitle =>
      'Réinitialiser votre mot de passe sans e-mail';

  @override
  String get recoveryCodeIntro =>
      'Ce code réinitialise votre mot de passe sans passer par un e-mail. Il ne change jamais, même après un changement de mot de passe.';

  @override
  String get recoveryCodeSecurityWarning =>
      'Toute personne connaissant ce code et votre ID Alanya peut changer votre mot de passe. Ne le partagez avec personne.';

  @override
  String get recoveryCodeReveal => 'Afficher le code';

  @override
  String get recoveryCodeHide => 'Masquer';

  @override
  String get recoveryCodePasswordPrompt =>
      'Saisissez votre mot de passe pour afficher le code.';

  @override
  String get recoveryCodeRevealFailed => 'Impossible d\'afficher le code';

  @override
  String get forgotMethodTitle => 'Récupérer votre compte';

  @override
  String get forgotMethodSubtitle => 'Comment souhaitez-vous procéder ?';

  @override
  String get forgotMethodEmail => 'J\'ai une adresse e-mail';

  @override
  String get forgotMethodEmailSubtitle =>
      'Recevez un code à 6 chiffres par e-mail.';

  @override
  String get forgotMethodCode => 'J\'ai un code de récupération';

  @override
  String get forgotMethodCodeSubtitle =>
      'Le code affiché à la création de votre compte.';

  @override
  String get forgotCodeTitle => 'Votre code de récupération';

  @override
  String get forgotCodeSubtitle =>
      'Saisissez votre ID Alanya et le code noté à l\'inscription.';

  @override
  String get forgotCodeHint => 'XXXX-XXXX-XXXX';

  @override
  String get forgotCodeSubmit => 'Valider le code';

  @override
  String get validatorRecoveryCode => 'Code de récupération à 12 caractères';

  @override
  String deleteAccountGraceDays(int days) {
    return 'Délai de grâce · $days jours';
  }

  @override
  String get deleteAccountCancelDeletion => 'Annuler la suppression';

  @override
  String get deleteAccountCancelSuccess => 'Suppression annulée';

  @override
  String get deleteAccountCancelFailed =>
      'Impossible d\'annuler la suppression';

  @override
  String get deleteAccountLogoutNow => 'Se déconnecter';

  @override
  String get myMediaEmpty => 'Aucun média partagé pour le moment';

  @override
  String get myMediaLoadFailed => 'Impossible de charger vos médias';

  @override
  String get bytesUnitB => 'o';

  @override
  String get bytesUnitKB => 'Ko';

  @override
  String get bytesUnitMB => 'Mo';

  @override
  String get bytesUnitGB => 'Go';

  @override
  String get myMediaSortRecent => 'Récents';

  @override
  String get myMediaSortLargest => 'Plus lourds';

  @override
  String myMediaOnThisDevice(String size) {
    return '$size sur cet appareil';
  }

  @override
  String get myMediaFreeSpace => 'Libérer de l\'espace';

  @override
  String get myMediaFreeSpaceConfirm =>
      'La copie locale des médias sélectionnés sera supprimée. Ils restent dans vos conversations et se retéléchargeront à l\'ouverture.';

  @override
  String get myMediaFreeSpaceConfirmMaybeGone =>
      'La copie locale des médias sélectionnés sera supprimée. Ils restent dans vos conversations, mais certains sont anciens : s\'ils ne sont plus disponibles sur le serveur, ils resteront introuvables.';

  @override
  String myMediaFreedSpace(String size) {
    return '$size libérés sur cet appareil';
  }

  @override
  String get myMediaNothingCached =>
      'Aucun de ces médias n\'occupe d\'espace sur cet appareil';

  @override
  String get myMediaForwardUnavailable =>
      'Ces médias ne sont plus dans vos conversations sur cet appareil';

  @override
  String get myMediaSelectAll => 'Tout sélectionner';

  @override
  String get myMediaFilterReceived => 'Reçus';

  @override
  String get myMediaFilterSent => 'Envoyés';

  @override
  String get myMediaFilterAll => 'Tous';

  @override
  String myMediaFrom(String name) {
    return 'De $name';
  }

  @override
  String get settingsBackup => 'Sauvegarde';

  @override
  String get settingsBackupSubtitle => 'Vos messages et réglages, chiffrés';

  @override
  String get backupTitle => 'Sauvegarde';

  @override
  String get backupSubtitle => 'Vos messages et réglages, chiffrés';

  @override
  String get backupFrequencyLabel => 'Fréquence';

  @override
  String get backupFrequencyDaily => 'Quotidienne';

  @override
  String get backupFrequencyWeekly => 'Hebdomadaire';

  @override
  String get backupFrequencyMonthly => 'Mensuelle';

  @override
  String get backupFrequencyNever => 'Jamais';

  @override
  String get backupLastNever => 'Aucune sauvegarde pour l\'instant';

  @override
  String backupLastAt(String when, String size) {
    return 'Dernière sauvegarde : $when · $size';
  }

  @override
  String backupCounts(int messages, int conversations) {
    return '$messages messages · $conversations discussions';
  }

  @override
  String get backupRunNow => 'Sauvegarder maintenant';

  @override
  String get backupRunning => 'Sauvegarde en cours…';

  @override
  String get backupSucceeded => 'Sauvegarde terminée';

  @override
  String get backupAlreadyRunning => 'Une sauvegarde est déjà en cours.';

  @override
  String get backupFailed => 'La sauvegarde a échoué';

  @override
  String get backupStaleWarning =>
      'Aucune sauvegarde n\'a abouti depuis plusieurs jours. Vérifiez votre connexion et l\'espace disponible.';

  @override
  String get backupDestinationLabel => 'Destination';

  @override
  String backupDestinationDrive(String account) {
    return 'Google Drive $account';
  }

  @override
  String get backupDestinationDriveUnlinked =>
      'Google Drive — aucun compte connecté sur cet appareil';

  @override
  String get backupDestinationDevice => 'Sur cet appareil';

  @override
  String get backupChangeAccount => 'Changer de compte Google';

  @override
  String get backupConnectDrive => 'Connecter Google Drive';

  @override
  String get backupUseDevice => 'Sauvegarder sur cet appareil';

  @override
  String get backupDriveConnected =>
      'Google Drive connecté. Vos prochaines sauvegardes y seront déposées.';

  @override
  String get backupDriveRefused =>
      'Connexion à Google annulée. Rien n\'a changé.';

  @override
  String get backupFellBack =>
      'Drive était injoignable : la sauvegarde a été faite sur cet appareil.';

  @override
  String backupFellBackAt(String when) {
    return 'Drive était injoignable. Une sauvegarde a été faite sur cet appareil le $when.';
  }

  @override
  String get backupLocalRisksTitle => 'Sauvegarde sur cet appareil';

  @override
  String get backupLocalRisksBody =>
      'Votre sauvegarde est sur ce téléphone, dans Téléchargements › Alanya › Sauvegardes.\n\n✓ Elle survit à une réinstallation d\'Alanya.\n✗ Elle ne survit pas à la perte, au vol ou à la casse du téléphone.\n✗ Elle ne survit pas à un effacement complet de l\'appareil.\n\nPour mettre vos données à l\'abri hors du téléphone, connectez Google Drive.';

  @override
  String get backupWhatIsSaved =>
      'Sont sauvegardés : messages, discussions, contacts et réglages. Les photos, vidéos et fichiers ne le sont pas — utilisez « Exporter cette période » depuis Mes médias pour les conserver.';

  @override
  String get backupNotEndToEnd =>
      'La sauvegarde est chiffrée. Alanya peut techniquement la déchiffrer pour vous la restaurer ; personne d\'autre ne le peut.';

  @override
  String get backupRestoreEntry => 'Restaurer une sauvegarde';

  @override
  String get backupRestoreEntryHint =>
      'Depuis Google Drive ou un fichier de votre téléphone';

  @override
  String get restoreTitle => 'Restaurer vos données';

  @override
  String restoreFound(String when, String size) {
    return 'Une sauvegarde du $when a été trouvée ($size).';
  }

  @override
  String get restoreExplain =>
      'Vos messages et réglages seront remis en place. Les photos et vidéos de plus de 30 jours ne reviendront pas : elles ne sont pas dans la sauvegarde.';

  @override
  String get restoreAction => 'Restaurer';

  @override
  String get restoreConnectGoogle => 'Se connecter à Google Drive';

  @override
  String get restoreGoogleRefused => 'Connexion à Google annulée';

  @override
  String get restoreGoogleEmpty => 'Aucune sauvegarde dans ce compte Google';

  @override
  String get restorePickFile => 'Choisir un fichier de sauvegarde';

  @override
  String get restorePickHint =>
      'Si votre sauvegarde ne s\'affiche pas — après une réinstallation, par exemple — désignez le fichier .enc dans Téléchargements › Alanya › Sauvegardes.';

  @override
  String get restorePickCancelled => 'Aucun fichier choisi';

  @override
  String get restorePickWrongFile =>
      'Ce fichier n\'est pas une sauvegarde Alanya';

  @override
  String get restoreSkip => 'Ignorer et continuer';

  @override
  String get restoreRunning => 'Restauration en cours…';

  @override
  String get restoreCloseApp => 'Fermer Alanya';

  @override
  String get restoreDoneRestart =>
      'Restauration prête. Fermez Alanya, puis rouvrez-la : vos données seront en place au démarrage.';

  @override
  String get restoreFailedMessage =>
      'La restauration a échoué. Vous pouvez réessayer depuis les réglages.';

  @override
  String get restoreKeyUnknown =>
      'Cette sauvegarde a été chiffrée avec une clé que nous ne reconnaissons plus.';

  @override
  String get restoreTooRecent =>
      'Cette sauvegarde vient d\'une version plus récente d\'Alanya. Mettez l\'application à jour.';

  @override
  String get restoreInterrupted =>
      'Une restauration précédente a été interrompue. Elle va être reprise depuis le début.';

  @override
  String get exportPeriodAction => 'Exporter cette période';

  @override
  String get exportSheetTitle => 'Exporter cette période';

  @override
  String exportSheetSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments · $size',
      one: '1 élément · $size',
      zero: 'Aucun élément',
    );
    return '$_temp0';
  }

  @override
  String get exportSheetNothing => 'Aucun média à exporter pour ces filtres';

  @override
  String exportMissingRecoverable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments manquants peuvent être récupérés ($size)',
      one: '1 élément manquant peut être récupéré ($size)',
    );
    return '$_temp0';
  }

  @override
  String exportMissingRecoverableEstimate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jusqu\'à $count éléments manquants peuvent être récupérés',
      one: 'Jusqu\'à 1 élément manquant peut être récupéré',
    );
    return '$_temp0';
  }

  @override
  String get exportMissingEstimateHint =>
      'Le serveur n\'a pas pu être consulté : certains de ces éléments n\'y sont peut-être plus.';

  @override
  String exportDoneWithMissing(String size, int missing) {
    return 'Archive prête : $size · $missing élément(s) indisponible(s)';
  }

  @override
  String get exportMissingRecoverableHint =>
      'Coché, ces éléments seront téléchargés avant l\'assemblage. Décoché, aucune donnée mobile n\'est consommée.';

  @override
  String exportMissingLost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ne sont plus disponibles sur les serveurs',
      one: '1 élément n\'est plus disponible sur les serveurs',
    );
    return '$_temp0';
  }

  @override
  String get exportMissingLostHint =>
      'Ils sont signalés dans l\'archive, mais leur contenu est définitivement perdu.';

  @override
  String get exportDestinationShare => 'Partager';

  @override
  String get exportDestinationDownloads => 'Enregistrer dans Téléchargements';

  @override
  String get exportPhaseScanning => 'Inventaire…';

  @override
  String exportPhaseRecovering(int done, int total) {
    return 'Récupération $done / $total';
  }

  @override
  String exportPhaseAssembling(int done, int total) {
    return 'Assemblage $done / $total';
  }

  @override
  String exportDone(String size) {
    return 'Archive prête : $size';
  }

  @override
  String get exportFailedGeneric => 'L\'exportation a échoué';

  @override
  String get exportNoSpace =>
      'Espace insuffisant sur l\'appareil pour cette archive';

  @override
  String get exportSaveUnsupported =>
      'Cette destination n\'est pas disponible sur cet appareil';

  @override
  String get exportSavedToDownloads =>
      'Archive enregistrée dans Téléchargements/Alanya';

  @override
  String get exportCancelled => 'Exportation annulée';

  @override
  String get myMediaFilters => 'Filtres';

  @override
  String get myMediaFilterDiscussion => 'Discussion';

  @override
  String get myMediaAllDiscussions => 'Toutes les discussions';

  @override
  String get myMediaSearchDiscussion => 'Rechercher une discussion';

  @override
  String get myMediaFilterOrigin => 'Origine';

  @override
  String get myMediaFilterPeriod => 'Période';

  @override
  String get myMediaPeriodAny => 'Toute la période';

  @override
  String get myMediaPeriodStart => 'Début';

  @override
  String get myMediaPeriodEnd => 'Fin';

  @override
  String get myMediaPeriodLast7 => '7 jours';

  @override
  String get myMediaPeriodLast30 => '30 jours';

  @override
  String get myMediaPeriodThisYear => 'Cette année';

  @override
  String get myMediaPeriodClear => 'Effacer la période';

  @override
  String get myMediaKindAll => 'Tout';

  @override
  String get myMediaKindPhotos => 'Photos';

  @override
  String get myMediaKindVideos => 'Vidéos';

  @override
  String get myMediaKindAudio => 'Vocaux';

  @override
  String get myMediaKindFiles => 'Fichiers';

  @override
  String myMediaSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments · $size',
      one: '1 élément · $size',
      zero: 'Aucun élément',
    );
    return '$_temp0';
  }

  @override
  String get myMediaEmptyFiltered => 'Aucun média ne correspond à ces filtres';

  @override
  String get myMediaResetFilters => 'Réinitialiser les filtres';

  @override
  String dndSummaryActive(String start, String end, String days) {
    return '$start – $end · $days';
  }

  @override
  String get dndSummaryInactive => 'Désactivé';

  @override
  String get exportPhase1ShareSubject =>
      'Export Alanya (profil et métadonnées)';

  @override
  String get officialContactSupport => 'Contacter le support';

  @override
  String get officialComingSoon => 'Bientôt disponible';

  @override
  String get officialHelpAndFaq => 'Aide et questions fréquentes';

  @override
  String get officialHelpUnavailable => 'Impossible d\'ouvrir la page d\'aide';

  @override
  String get listKindFamily => 'Famille';

  @override
  String get listKindFriends => 'Amis';

  @override
  String get listKindWork => 'Bureau';

  @override
  String get listKindTrust => 'Confiance';

  @override
  String get contactLists => 'Listes de contacts';

  @override
  String get contactListsManage => 'Gérer';

  @override
  String get createList => 'Créer une liste';

  @override
  String get listName => 'Nom de la liste';

  @override
  String get listNameHint => 'Famille, Amis, Bureau…';

  @override
  String get renameList => 'Renommer la liste';

  @override
  String get deleteList => 'Supprimer la liste';

  @override
  String deleteListConfirm(String name) {
    return 'Supprimer « $name » ? Vos contacts restent dans vos favoris.';
  }

  @override
  String get listColor => 'Couleur de la puce';

  @override
  String get listNameAlreadyExists => 'Une liste porte déjà ce nom';

  @override
  String get listSaveFailed => 'Impossible d\'enregistrer la liste. Réessayez.';

  @override
  String get listMembersUpdateFailed =>
      'Impossible de modifier les membres. Réessayez.';

  @override
  String listMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
      zero: 'Aucun membre',
    );
    return '$_temp0';
  }

  @override
  String listMembersCountLimited(int current, int limit) {
    return '$current/$limit membres';
  }

  @override
  String listMemberLimitReached(int limit) {
    return 'Cette liste est limitée à $limit membres';
  }

  @override
  String get addToList => 'Ajouter des membres';

  @override
  String get removeFromList => 'Retirer de la liste';

  @override
  String get createGroupFromList => 'Créer un groupe';

  @override
  String get noLists => 'Aucune liste de contacts';

  @override
  String get noListsHint =>
      'Rangez vos contacts préférés par Famille, Amis, Bureau…';

  @override
  String get noListMembers => 'Aucun membre dans cette liste';

  @override
  String get noContactToAddToList =>
      'Tous vos contacts préférés sont déjà dans cette liste';

  @override
  String addMembersSelected(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get newList => 'Nouvelle liste';

  @override
  String get contactListsHint =>
      'Une liste ne peut contenir que des contacts déjà en favoris. Un même contact peut appartenir à plusieurs listes.';

  @override
  String get notInThisList => 'Favori — pas dans cette liste';

  @override
  String createGroupNamed(String name) {
    return 'Créer un groupe « $name »';
  }

  @override
  String get manageLists => 'Gérer les listes';

  @override
  String get contactListsSheetSubtitle =>
      'Ouvrir une liste, ou en faire un groupe.';

  @override
  String get markAllAsRead => 'Tout marquer comme lu';

  @override
  String markAllAsReadDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count discussions marquées comme lues',
      one: '1 discussion marquée comme lue',
      zero: 'Aucune discussion non lue',
    );
    return '$_temp0';
  }

  @override
  String get optionsAction => 'Options';

  @override
  String get trips => 'Trajets de confiance';

  @override
  String get tripsCircleEmptyTitle => 'Votre cercle de confiance est vide';

  @override
  String get tripsCircleEmptyBody =>
      'Choisissez jusqu\'à cinq proches. Eux seuls verront vos trajets, et seulement ceux que vous partagez.';

  @override
  String get tripsComposeCircle => 'Composer mon cercle';

  @override
  String get tripsMyCircle => 'Mon cercle de confiance';

  @override
  String get tripsNone => 'Aucun trajet en cours.';

  @override
  String get tripsNew => 'Nouveau trajet';

  @override
  String get tripsKindTaxi => 'Taxi';

  @override
  String get tripsKindTaxiHint => 'Un déplacement, une arrivée attendue';

  @override
  String get tripsKindWalk => 'À pied';

  @override
  String get tripsKindWalkHint => 'Un trajet à pied, une arrivée attendue';

  @override
  String get tripsKindMeeting => 'À pied';

  @override
  String get tripsKindMeetingHint => 'Un trajet à pied, une arrivée attendue';

  @override
  String get tripsArrivalIn => 'Arrivée dans';

  @override
  String tripsMinutes(int count) {
    return '$count min';
  }

  @override
  String get tripsNoteLabel => 'Note pour le cercle';

  @override
  String get tripsNoteHint => 'Taxi jaune, plaque LT 4471';

  @override
  String get tripsStart => 'Démarrer le partage';

  @override
  String tripsContract(int count, String eta, String alert) {
    return 'Vos $count proches verront votre position en direct jusqu\'à $eta. Si vous n\'avez pas confirmé à $alert, ils seront prévenus avec votre dernière position.';
  }

  @override
  String get tripsCircleFrozen =>
      'Le cercle se modifie dans Profil › Listes de contacts, jamais au départ d\'un trajet. Personne n\'apprend qu\'il y entre ou en sort.';

  @override
  String get tripsInProgress => 'Trajet en cours';

  @override
  String get tripsLive => 'En direct';

  @override
  String get tripsStale => 'Position indisponible';

  @override
  String get tripsAwaitingConfirm => 'Arrivée à confirmer';

  @override
  String get tripsAlerted => 'Alerte envoyée';

  @override
  String tripsWatcherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes suivent',
      one: '1 personne suit',
    );
    return '$_temp0';
  }

  @override
  String tripsWatcherFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes ont suivi',
      one: '1 personne a suivi',
      zero: 'Personne n\'a suivi',
    );
    return '$_temp0';
  }

  @override
  String tripsEtaAt(String time) {
    return 'Arrivée prévue $time';
  }

  @override
  String get tripsAlreadyActive => 'Un trajet est déjà en cours.';

  @override
  String get tripsStartFailed => 'Impossible de démarrer le trajet.';

  @override
  String get tripsSosUnavailable => 'Le SOS n\'est pas encore disponible.';

  @override
  String get tripsStop => 'Arrêter le partage';

  @override
  String get tripsForegroundOnly =>
      'Le partage s\'interrompt si vous quittez Alanya. Vos proches seront prévenus à l\'heure prévue dans tous les cas.';

  @override
  String tripsCardStarted(String name) {
    return '$name a démarré un trajet';
  }

  @override
  String get tripsCardStartedByMe => 'Vous avez démarré un trajet';

  @override
  String tripsCardAwaiting(String name) {
    return '$name devrait être arrivé·e';
  }

  @override
  String get tripsCardAwaitingByMe => 'Vous devriez être arrivé·e';

  @override
  String tripsCardAlert(String name) {
    return '$name n\'a pas confirmé son arrivée';
  }

  @override
  String get tripsCardAlertByMe => 'Vous n\'avez pas confirmé votre arrivée';

  @override
  String tripsCardSos(String name) {
    return '$name a déclenché un SOS';
  }

  @override
  String get tripsCardSosByMe => 'Vous avez déclenché un SOS';

  @override
  String tripsCardArrived(String name) {
    return '$name est bien arrivé·e';
  }

  @override
  String get tripsCardArrivedByMe => 'Vous êtes bien arrivé·e';

  @override
  String tripsCardStopped(String name) {
    return '$name a arrêté le partage';
  }

  @override
  String get tripsCardStoppedByMe => 'Vous avez arrêté le partage';

  @override
  String get tripsCardFollow => 'Suivre en direct';

  @override
  String get tripsCardView => 'Voir';

  @override
  String get tripsCardSeePosition => 'Voir la position';

  @override
  String get tripsCardSeeLast => 'Voir la dernière position';

  @override
  String get tripsCardFallback =>
      'Trajet de confiance — mettez à jour l\'application';

  @override
  String get tripsConfirmArrival => 'Je suis bien arrivé·e';

  @override
  String tripsExtendBy(int count) {
    return '+$count min';
  }

  @override
  String tripsExtended(int count) {
    return 'Prolongé de $count minutes. Votre cercle a été informé.';
  }

  @override
  String get tripsAlreadyClosed => 'Ce trajet est déjà clos.';

  @override
  String get tripsActionFailed => 'Action impossible pour le moment.';

  @override
  String get tripsHistory => 'Historique';

  @override
  String get tripsHistoryEmpty => 'Aucun trajet pour l\'instant';

  @override
  String get tripsHistoryEmptyBody =>
      'Quand vous partagerez un trajet, il apparaîtra ici — et seulement ici.';

  @override
  String get tripsHistoryUnavailable => 'Historique indisponible';

  @override
  String get tripsHistoryOnline =>
      'Vos trajets passés se consultent en ligne : ils ne sont pas conservés sur cet appareil.';

  @override
  String get tripsRetentionNote =>
      'Vos trajets sont conservés douze mois. Les traces détaillées, vingt-quatre heures — trente jours après une alerte.';

  @override
  String get tripsOutcomeConfirmed => 'Arrivée confirmée';

  @override
  String get tripsOutcomeStopped => 'Trajet arrêté';

  @override
  String get tripsOutcomeAlert => 'Alerte déclenchée';

  @override
  String get tripsDeleteLocked =>
      'Ce trajet est conservé trente jours après une alerte. Cette règle protège la personne concernée.';

  @override
  String get loadMore => 'Charger plus';

  @override
  String get tripsFgsTitle => 'Trajet de confiance en cours';

  @override
  String get tripsFgsBodyPlain =>
      'Votre position est partagée avec votre cercle';

  @override
  String tripsFgsBody(String names) {
    return 'Partagé avec $names';
  }

  @override
  String get tripsSosTitle => 'SOS';

  @override
  String get tripsSosHold => 'Appuyez pour lancer le SOS';

  @override
  String get tripsSosHoldBody =>
      'Le compte à rebours commence immédiatement et vous pouvez annuler avant l\'envoi.';

  @override
  String get tripsSosNotEmergency =>
      'Le SOS ne prévient pas les secours. Il prévient votre cercle de confiance.';

  @override
  String tripsSosSending(int count) {
    return 'Envoi dans $count secondes';
  }

  @override
  String get tripsSosSendingNow => 'Envoi en cours…';

  @override
  String get tripsSosSendingNowBody =>
      'Vos proches seront prévenus dans un instant.';

  @override
  String get tripsSosSent => 'Vos proches ont été prévenus';

  @override
  String get tripsSosDiscreet =>
      'Aucun son, aucune vibration. Votre position continue d\'être partagée.';

  @override
  String get tripsSosActive => 'Partage actif';

  @override
  String get tripsSosActiveBody =>
      'Votre position est partagée. Aucun son, aucune vibration.';

  @override
  String get tripsSosTooMany => 'Trop de SOS sur les dernières 24 heures.';

  @override
  String get tripsSosFalseAlarm => 'Fausse alerte, je vais bien';

  @override
  String get tripsSosButton => 'Lancer un SOS';

  @override
  String get tripsKeepsRunning =>
      'Le partage continue même écran verrouillé. Une notification vous le rappelle et permet de l\'arrêter.';

  @override
  String get tripsDestination => 'Destination';

  @override
  String get tripsDestinationOptional => 'Choisir une destination (facultatif)';

  @override
  String get tripsDestinationRadius =>
      'L\'arrivée sera détectée dans un rayon de 100 m';

  @override
  String get tripsShort => 'Confiance';

  @override
  String get tripsRailStart => 'Partir';

  @override
  String get tripsRailFollow => 'Suivre';

  @override
  String get tripsRailConfirm => 'Confirmer';

  @override
  String get tripsRailClose => 'Clore';

  @override
  String get tripsConfirmed => 'Arrivée confirmée. Votre cercle est prévenu.';

  @override
  String get tripsDeleteTitle => 'Supprimer ce trajet ?';

  @override
  String get tripsDeleteBody =>
      'Le trajet et sa trace seront effacés. Cette action est définitive.';

  @override
  String get tripsRecenter => 'Recentrer sur la position';

  @override
  String get tripsMapExpand => 'Plein écran';

  @override
  String get tripsMapReduce => 'Réduire';

  @override
  String get tripsMapFitBounds => 'Voir position et destination';

  @override
  String get tripsDestinationSafetyNet =>
      'Avec une destination, on vous demandera de confirmer dès l\'arrivée — pas seulement à l\'heure.';

  @override
  String tripsDistanceM(int meters) {
    return '~$meters m';
  }

  @override
  String tripsDistanceKm(double km) {
    final intl.NumberFormat kmNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String kmString = kmNumberFormat.format(km);

    return '~$kmString km';
  }

  @override
  String tripsUpdatedAgo(String age) {
    return 'maj il y a $age';
  }

  @override
  String get tripsPositionFrozen => 'Position figée';

  @override
  String get tripsDeleteLockedHint => 'Conservé 30 jours après une alerte';

  @override
  String tripsEventWatcherSeenGroup(int count) {
    return '$count proches ont vu';
  }

  @override
  String get tripsArrivalReachedTitle => 'Vous êtes arrivé·e ?';

  @override
  String get tripsArrivalReachedBody =>
      'Vous êtes à votre destination depuis une minute.';

  @override
  String get tripsArrivalDueTitle => 'Confirmez votre arrivée';

  @override
  String tripsArrivalDueBody(String time) {
    return 'Sans réponse, vos proches seront prévenus à $time avec votre dernière position.';
  }

  @override
  String get tripsArrivalDueBodyPlain =>
      'Sans réponse, vos proches seront prévenus avec votre dernière position.';

  @override
  String get tripsArrivalLater => 'Pas encore — l\'échéance continue de courir';

  @override
  String get tripsDegradedPermission => 'Localisation désactivée';

  @override
  String get tripsDegradedPermissionBody =>
      'Vos proches ne voient plus votre position. L\'heure d\'arrivée reste surveillée : ils seront prévenus si vous ne confirmez pas.';

  @override
  String get tripsDegradedStale => 'Position indisponible';

  @override
  String get tripsDegradedStaleBody =>
      'Tunnel, parking ou signal faible. Ce n\'est pas une alerte — l\'échéance continue de courir.';

  @override
  String get tripsDegradedBattery => 'Batterie faible';

  @override
  String get tripsDegradedBatteryBody =>
      'Le suivi est ralenti. Si le téléphone s\'éteint, votre dernière position sera envoyée.';

  @override
  String get tripsDegradedFix => 'Réparer';

  @override
  String get locationSearchHint => 'Rechercher un lieu, une adresse…';

  @override
  String get locationSearchEmpty =>
      'Aucun résultat. Vous pouvez toujours choisir sur la carte.';

  @override
  String get locationSearchUnavailable =>
      'La recherche est indisponible. Vérifiez votre connexion et réessayez.';

  @override
  String get locationPickerChooseDestination => 'Choisir une destination';

  @override
  String get locationPickerUseDestination => 'Choisir cette destination';

  @override
  String get locationUseMyPosition => 'Utiliser ma position';

  @override
  String get locationPickerInstruction =>
      'Recherchez, déplacez la carte ou utilisez votre position';

  @override
  String get mapCompassNorth => 'Remettre le nord en haut';

  @override
  String tripsCardFalseAlarm(String name) {
    return '$name a signalé une fausse alerte';
  }

  @override
  String get tripsCardFalseAlarmByMe => 'Vous avez signalé une fausse alerte';

  @override
  String get tripsSosFalseAlarmSent =>
      'Votre cercle a été prévenu que tout va bien.';

  @override
  String get tripsCall => 'Appeler';

  @override
  String get tripsPermissionTitle => 'Autoriser la localisation';

  @override
  String get tripsPermissionBody =>
      'Sans cette autorisation, vos proches ne verront pas où vous êtes. L\'heure d\'arrivée reste surveillée dans tous les cas.';

  @override
  String get tripsPermissionNever =>
      'Alanya n\'utilise votre position que pendant un trajet que vous avez démarré. Jamais avant, jamais après.';

  @override
  String get tripsPermissionAllow => 'Autoriser';

  @override
  String get tripsPermissionLater => 'Plus tard';

  @override
  String sysTripAlert(String actor) {
    return '$actor n\'a pas confirmé son arrivée — le cercle a été prévenu';
  }

  @override
  String get sysTripAlertByMe =>
      'Vous n\'avez pas confirmé votre arrivée — votre cercle a été prévenu';

  @override
  String sysTripSos(String actor) {
    return '$actor a déclenché un SOS';
  }

  @override
  String get sysTripSosByMe => 'Vous avez déclenché un SOS';

  @override
  String get tripsPreviewActive => '🧭 Trajet en cours';

  @override
  String get tripsPreviewAwaiting => '🧭 Arrivée à confirmer';

  @override
  String get tripsPreviewAlert => '🆘 Alerte trajet';

  @override
  String get tripsPreviewSos => '🆘 SOS';

  @override
  String get tripsPreviewConfirmed => '✅ Bien arrivé·e';

  @override
  String get tripsPreviewStopped => '🧭 Trajet arrêté';

  @override
  String get tripsPreviewFalseAlarm => '✅ Fausse alerte';

  @override
  String get tripsAlertChannelName => 'Alertes de trajet';

  @override
  String get tripsAlertChannelBody =>
      'Un proche n\'a pas confirmé son arrivée, ou a déclenché un SOS. Ces alertes traversent le mode silencieux.';

  @override
  String get tripsChannelName => 'Trajets de confiance';

  @override
  String get tripsChannelBody =>
      'Rappels de confirmation d\'arrivée, pour vos propres trajets.';

  @override
  String tripsRevokeTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get tripsRevokeBody =>
      'Cette personne cessera de voir votre position et l\'état de ce trajet. Elle n\'en sera pas informée.';

  @override
  String get tripsRevokeAction => 'Retirer';

  @override
  String get tripsWatchersNoneSeen => 'Personne n\'a encore ouvert';

  @override
  String tripsWatchersSeenCount(int seen, int total) {
    return '$seen sur $total ont vu';
  }

  @override
  String get tripsWatcherSeen => 'a vu';

  @override
  String get tripsOtherDeviceTitle =>
      'Trajet en cours sur votre autre appareil';

  @override
  String get tripsOtherDeviceBody =>
      'Un seul appareil envoie la position, sinon la trace sauterait d\'un endroit à l\'autre.';

  @override
  String get tripsOtherDeviceTake => 'Suivre depuis cet appareil';

  @override
  String get tripsOtherDeviceKeep => 'Rester en lecture seule';

  @override
  String get tripsNoLongerShared => 'Ce trajet n\'est plus partagé avec vous';

  @override
  String get tripsNoLongerSharedBody =>
      'Il a pu être clos, ou vous en avez été retiré. Aucune autre information n\'est donnée.';

  @override
  String get tripsLiveEndedArrived => 'Arrivée confirmée';

  @override
  String get tripsLiveEndedStopped => 'Le partage est terminé';

  @override
  String get tripsLiveEndedBody => 'Le partage de position est terminé.';

  @override
  String get tripsDetailTitle => 'Détail du trajet';

  @override
  String get tripsDetailTimeline => 'Frise';

  @override
  String get tripsDetailNoEvents => 'Aucun événement enregistré.';

  @override
  String get tripsTraceExpired => 'Trace expirée';

  @override
  String get tripsTraceExpiredBody =>
      'Les positions de ce trajet ont été purgées. Le résumé et la frise restent disponibles.';

  @override
  String get tripsTraceUnavailable => 'Trace indisponible';

  @override
  String get tripsTraceUnavailableBody =>
      'Impossible de charger les positions de ce trajet. Elles n\'ont pas été effacées — réessayez.';

  @override
  String get tripsTraceEmpty => 'Aucune position';

  @override
  String get tripsTraceEmptyBody =>
      'Aucune position n\'a été enregistrée pendant ce trajet. Le résumé et la frise restent disponibles.';

  @override
  String get tripsEventStarted => 'Départ';

  @override
  String get tripsEventExtended => 'Prolongation';

  @override
  String get tripsEventArrivalDetected => 'Arrivée détectée';

  @override
  String get tripsEventEtaDue => 'Échéance atteinte';

  @override
  String get tripsEventAlerted => 'Alerte envoyée';

  @override
  String get tripsEventClosed => 'Clôture';

  @override
  String get tripsEventSignalBack => 'Signal rétabli';

  @override
  String get tripsEventLowBattery => 'Batterie faible';

  @override
  String get tripsEventWatcherSeen => 'Vu par un proche';

  @override
  String get tripsEventWatcherRevoked => 'Destinataire retiré';

  @override
  String get tripsEventDeviceTakeover => 'Reprise sur un autre appareil';

  @override
  String get tripsUnreachable => 'Trajet indisponible';

  @override
  String get tripsUnreachableBody =>
      'Impossible de joindre le serveur. Votre connexion est peut-être coupée.';

  @override
  String get tripsLeave => 'Quitter le suivi';

  @override
  String get tripsLeaveTitle => 'Quitter ce trajet ?';

  @override
  String get tripsLeaveBody =>
      'Vous ne verrez plus sa position et ne serez pas alerté s\'il ne confirme pas son arrivée.';

  @override
  String get translationSection => 'Traduction';

  @override
  String get autoTranslate => 'Traduction automatique';

  @override
  String get autoTranslateDescription =>
      'Traduire les messages reçus qui ne sont pas dans votre langue de lecture.';

  @override
  String get onDeviceTranslationNotice =>
      'La traduction s\'effectue sur votre appareil. Aucun message n\'est envoyé à un service tiers, et elle fonctionne hors ligne.';

  @override
  String get translateTo => 'Traduire vers';

  @override
  String translatedFrom(String language) {
    return 'Traduit du $language';
  }

  @override
  String get showOriginal => 'voir l\'original';

  @override
  String get showTranslation => 'voir la traduction';

  @override
  String get translate => 'Traduire';

  @override
  String get translating => 'Traduction…';

  @override
  String get translationFailed => 'Traduction impossible';

  @override
  String get translationUnavailable =>
      'Aucune traduction disponible pour ce message.';

  @override
  String get languageModels => 'Modèles de langue';

  @override
  String languageModelsDescription(int size) {
    return 'Chaque langue occupe environ $size Mo sur votre appareil.';
  }

  @override
  String downloadLanguageModel(String language, int size) {
    return 'Télécharger $language ($size Mo) pour traduire';
  }

  @override
  String get downloadModel => 'Télécharger';

  @override
  String get deleteModel => 'Supprimer';

  @override
  String get modelBundled => 'Inclus dans l’application';

  @override
  String downloadingModel(String language) {
    return 'Téléchargement de $language…';
  }

  @override
  String get modelDownloadFailed =>
      'Téléchargement impossible. Vérifiez votre connexion Wi-Fi.';

  @override
  String get modelDownloadWifiNotice =>
      'Le téléchargement se fait en Wi-Fi pour préserver vos données mobiles.';

  @override
  String get translateThisConversation => 'Traduire cette conversation';

  @override
  String get translateModeAuto => 'Automatique';

  @override
  String get translateModeAlways => 'Toujours';

  @override
  String get translateModeNever => 'Jamais';

  @override
  String get translateModeAutoSubtitle => 'Suit le réglage général';

  @override
  String get errDelaiDepasse =>
      'Le serveur met trop de temps à répondre. Réessayez.';

  @override
  String get errReseauSuspect =>
      'Connexion sécurisée impossible. Vérifiez votre réseau.';

  @override
  String get errSessionExpiree => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get errIntrouvable =>
      'Introuvable. Ce contenu a peut-être été supprimé.';

  @override
  String get errConflit => 'Action impossible dans l\'état actuel.';

  @override
  String get errTropDeRequetes => 'Trop de tentatives. Patientez un instant.';

  @override
  String get errServeur =>
      'Le service est momentanément indisponible. Réessayez.';

  @override
  String get errPermission =>
      'Autorisation refusée. Vérifiez les réglages de votre appareil.';

  @override
  String get errPeripherique =>
      'Périphérique indisponible ou déjà utilisé par une autre application.';

  @override
  String get errStockage =>
      'Accès au fichier impossible. Vérifiez l\'espace disponible.';

  @override
  String get errGenerique => 'Une erreur est survenue. Réessayez.';

  @override
  String get errDomaineAuth => 'Connexion impossible. Réessayez.';

  @override
  String get errDomaineChat => 'Message non envoyé. Réessayez.';

  @override
  String get errDomaineAppel => 'L\'appel n\'a pas pu aboutir. Réessayez.';

  @override
  String get errDomaineReunion =>
      'La réunion n\'a pas pu s\'ouvrir. Réessayez.';

  @override
  String get errDomaineQr => 'Ce code n\'a pas pu être utilisé. Réessayez.';

  @override
  String get errDomaineMedia =>
      'Le fichier n\'a pas pu être traité. Réessayez.';

  @override
  String get errDomaineTrajet =>
      'Le trajet n\'a pas pu être mis à jour. Réessayez.';

  @override
  String get errDomaineStatut =>
      'Le statut n\'a pas pu être publié. Réessayez.';

  @override
  String get errDomaineProfil => 'Modification impossible. Réessayez.';

  @override
  String get errDomaineAdmin => 'Opération impossible. Réessayez.';

  @override
  String get errAppelHorsLigne => 'Appel impossible sans connexion.';

  @override
  String get errChatHorsLigne =>
      'Message en attente : il partira au retour du réseau.';

  @override
  String get errMediaStockage =>
      'Enregistrement impossible. Vérifiez l\'espace disponible sur l\'appareil.';

  @override
  String get errCodeRefreshExpired =>
      'Votre session a expiré. Reconnectez-vous.';

  @override
  String get errCodeDeviceRevoked =>
      'Cet appareil a été déconnecté. Reconnectez-vous.';

  @override
  String get errCodeAccountDeletionPending =>
      'Ce compte est en cours de suppression.';

  @override
  String get errCodeRegisterRateLimited =>
      'Trop de créations de compte. Réessayez plus tard.';

  @override
  String get errCodeInvalidCredentials =>
      'Identifiant ou mot de passe incorrect.';

  @override
  String get errCodePasswordIncorrect => 'Mot de passe incorrect.';

  @override
  String get errCodeQrSessionExpired =>
      'Ce code QR a expiré. Affichez-en un nouveau.';

  @override
  String get errCodeDeviceNotOwner =>
      'Cet appareil n\'est pas autorisé pour cette action.';

  @override
  String get errCodeDeviceNotTrusted =>
      'Ce téléphone n\'est pas encore reconnu pour ce compte. Connectez-vous avec un code QR depuis un appareil déjà connecté.';

  @override
  String get errCodeAddAlreadyUsed => 'Ce code a déjà été utilisé.';

  @override
  String get errCodeAddMePolicyDenied =>
      'Cette personne n\'accepte pas les ajouts par code.';

  @override
  String get errCodeMeetingExpired => 'Cette réunion a expiré.';

  @override
  String get errCodeMeetingEnded => 'Cette réunion est terminée.';

  @override
  String get errCodeMeetingOrganiserRequired =>
      'Seul l\'organisateur peut faire cela.';

  @override
  String get errCodeAccountAlreadyInMeeting =>
      'Ce compte participe déjà à la réunion sur un autre appareil.';

  @override
  String get errCodeSessionBusy =>
      'Un appel est en cours. Terminez-le d\'abord.';

  @override
  String get errCodeMaxDurationReached => 'La durée maximale est atteinte.';

  @override
  String get errCodeBlockedBySender =>
      'Vous ne pouvez pas contacter cette personne.';

  @override
  String get errCodeNotAMember => 'Vous ne faites plus partie de ce groupe.';

  @override
  String get errCodeGroupAdminsOnly => 'Réservé aux administrateurs du groupe.';

  @override
  String get errCodeGroupOwnerRequired =>
      'Seul le propriétaire du groupe peut faire cela.';

  @override
  String get errCodeConversationNotFound =>
      'Cette conversation n\'existe plus.';

  @override
  String get errCodeOfficialReadonly =>
      'Ce compte officiel n\'accepte pas de réponse.';

  @override
  String get errCodeListMemberLimit =>
      'Cette liste a atteint son nombre maximal de membres.';

  @override
  String get errCodeSystemListReadonly =>
      'Cette liste système ne peut pas être modifiée.';

  @override
  String get errCodeInviteBlocked => 'Cette personne ne peut pas être invitée.';

  @override
  String get errCodeBusinessOnly => 'Réservé aux comptes professionnels.';

  @override
  String get errCodeTrustListEmpty =>
      'Votre cercle de confiance est vide. Ajoutez-y quelqu\'un d\'abord.';

  @override
  String get errCodeTripAlreadyActive => 'Un trajet est déjà en cours.';

  @override
  String get errCodeTripTerminal => 'Ce trajet est déjà terminé.';

  @override
  String get errCodeTripStillOpen => 'Terminez d\'abord le trajet en cours.';

  @override
  String get errCodeSosRateLimited =>
      'Alerte déjà envoyée. Patientez avant d\'en envoyer une autre.';

  @override
  String get errCodeInvalidEta =>
      'L\'heure d\'arrivée indiquée n\'est pas valide.';

  @override
  String get errCodeInvalidDestination =>
      'La destination indiquée n\'est pas valide.';

  @override
  String get errCodeMediaExpired =>
      'Ce média a expiré et n\'est plus disponible.';

  @override
  String get errCodeInvalidExtension =>
      'Ce type de fichier n\'est pas accepté.';

  @override
  String get errCodeInsufficientRole =>
      'Vos droits ne permettent pas cette action.';

  @override
  String get errCodeFieldImmutable => 'Ce champ ne peut plus être modifié.';

  @override
  String get errAucuneAppPourFichier =>
      'Aucune application ne peut ouvrir ce fichier.';

  @override
  String get plusBrand => 'Alanya Plus';

  @override
  String get plusFeatureTranslation => 'Traduction';

  @override
  String get plusFeatureBackup => 'Sauvegarde';

  @override
  String get plusFeatureTrips => 'Trajets';

  @override
  String get plusFeatureRingtones => 'Sonneries';

  @override
  String get plusFeatureStyle => 'Style';

  @override
  String get plusFeatureBadge => 'Coche';

  @override
  String plusAmount(String amount) {
    return '$amount F';
  }

  @override
  String get plusPerMonth => '/ mois';

  @override
  String get plusPerYear => '/ an';

  @override
  String plusPerNMonths(int count) {
    return '/ $count mois';
  }

  @override
  String get plusPlanMonthly => 'Mensuel';

  @override
  String get plusPlanYearly => 'Annuel';

  @override
  String get plusRenew => 'Renouveler';

  @override
  String get plusResubscribe => 'Me réabonner';

  @override
  String get paywallFromLabel => 'À partir de';

  @override
  String get paywallSeeOffer => 'Voir l\'offre';

  @override
  String get paywallTranslationTitle => 'Traduire vos messages';

  @override
  String get paywallTranslationBody =>
      'La traduction fait partie d\'Alanya Plus. Elle fonctionne sur votre téléphone, même sans connexion, et vos messages ne quittent jamais l\'appareil.';

  @override
  String get paywallBackupTitle => 'Sauvegarder vos discussions';

  @override
  String get paywallBackupBody =>
      'La sauvegarde fait partie d\'Alanya Plus : chiffrée, sur votre téléphone ou votre Drive. Vos sauvegardes existantes restent toujours restaurables.';

  @override
  String get paywallTripsTitle => 'Partir en trajet de confiance';

  @override
  String get paywallTripsBody =>
      'Les trajets de confiance et le SOS font partie d\'Alanya Plus : vos proches suivent votre trajet et sont prévenus si vous n\'arrivez pas. Un trajet déjà commencé garde son SOS jusqu\'à la fin.';

  @override
  String get paywallRingtonesTitle => 'Une sonnerie par liste';

  @override
  String get paywallRingtonesBody =>
      'Les sonneries par liste font partie d\'Alanya Plus : reconnaissez la famille, le bureau ou les amis avant même de regarder l\'écran.';

  @override
  String get paywallGenericTitle => 'Fonctionnalité Alanya Plus';

  @override
  String get paywallGenericBody =>
      'Cette fonctionnalité fait partie d\'Alanya Plus.';

  @override
  String get errCodeSubscriptionRequired =>
      'Cette fonctionnalité fait partie d\'Alanya Plus.';

  @override
  String get errCodeBillingNotActive =>
      'Alanya Plus est gratuit pour le moment : rien à payer.';

  @override
  String get errCodePaymentPending =>
      'Un paiement attend déjà votre confirmation.';

  @override
  String get errCodeInvalidMsisdn =>
      'Ce numéro mobile money n\'est pas valide.';

  @override
  String get errCodeInvalidChannel =>
      'Ce moyen de paiement n\'est pas proposé.';

  @override
  String get errCodePlanNotFound =>
      'Cette formule n\'est plus proposée. Rechargez l\'offre.';

  @override
  String get errCodePaymentProviderError =>
      'Le service de paiement ne répond pas. Réessayez dans un instant.';

  @override
  String get errDomaineAbonnement =>
      'L\'opération sur votre abonnement n\'a pas abouti.';

  @override
  String plusCardGraceTitle(String date) {
    return 'Payant à partir du $date';
  }

  @override
  String plusCardGraceBody(String date) {
    return 'Traduction, sauvegarde, trajets et sonneries par liste restent gratuits jusque-là. Abonnez-vous maintenant : votre première période commencera le $date.';
  }

  @override
  String plusCardGraceDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'encore $count jours gratuits',
      one: 'encore 1 jour gratuit',
      zero: 'dernier jour gratuit',
    );
    return '$_temp0';
  }

  @override
  String get plusCardUpgradeTitle => 'Passez à Alanya Plus';

  @override
  String get plusCardDiscover => 'Découvrir l\'offre';

  @override
  String plusCardActiveUntil(String date) {
    return 'Actif jusqu\'au $date';
  }

  @override
  String plusCardEndsOn(String date) {
    return 'Prend fin le $date';
  }

  @override
  String plusCardEndsSoonBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count jours. Renouvelez pour garder vos fonctionnalités.',
      one: 'Encore 1 jour. Renouvelez pour garder vos fonctionnalités.',
      zero: 'Dernier jour. Renouvelez pour garder vos fonctionnalités.',
    );
    return '$_temp0';
  }

  @override
  String get plusCardAutoRenewOn => 'Renouvellement automatique activé.';

  @override
  String get plusCardAutoRenewOff => 'Pensez à renouveler avant l\'échéance.';

  @override
  String get plusCardBadgeActive => 'Abonné Alanya Plus';

  @override
  String plusCardStartsOn(String date) {
    return 'Votre abonnement commence le $date';
  }

  @override
  String get plusCardScheduledBody =>
      'D\'ici là, tout reste gratuit pour vous.';

  @override
  String plusCardLapsedKicker(String date) {
    return 'Terminé le $date';
  }

  @override
  String get plusCardLapsedTitle => 'Vos fonctionnalités Plus sont en pause';

  @override
  String get plusCardLapsedBody =>
      'Vos réglages sont conservés. Réabonnez-vous pour tout retrouver, coche comprise.';

  @override
  String get plusOfferUnlocks => 'Ce que Plus débloque';

  @override
  String get plusOfferUnavailable =>
      'Le paiement n\'est pas disponible pour le moment. Réessayez plus tard.';

  @override
  String get plusOfferDuration => 'Durée';

  @override
  String plusOfferContinue(String amount) {
    return 'Continuer — $amount';
  }

  @override
  String get plusOfferNoCommitment => 'sans engagement';

  @override
  String plusOfferEquivalent(String amount) {
    return 'soit $amount par mois';
  }

  @override
  String plusOfferMonthsFree(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mois offerts',
      one: '1 mois offert',
    );
    return '$_temp0';
  }

  @override
  String plusOfferFirstPeriod(String start, String end) {
    return 'Première période : du $start au $end.';
  }

  @override
  String plusOfferNextPeriod(String start, String end) {
    return 'Nouvelle période : du $start au $end, à la suite de l\'actuelle.';
  }

  @override
  String get plusOfferNoRefund =>
      'Chaque période se paie d\'avance et n\'est pas remboursable.';

  @override
  String get checkoutTitle => 'Paiement';

  @override
  String get checkoutPayWith => 'Payer avec';

  @override
  String get checkoutNumber => 'Numéro à débiter';

  @override
  String get checkoutNumberHint => '6XX XX XX XX';

  @override
  String get checkoutNumberInvalid =>
      'Entrez un numéro mobile camerounais : 9 chiffres commençant par 6.';

  @override
  String get checkoutAutoRenew => 'Renouvellement automatique';

  @override
  String checkoutAutoRenewHint(String operator) {
    return '$operator vous demandera de confirmer la veille de l\'échéance.';
  }

  @override
  String get checkoutSimulated =>
      'Paiement simulé : aucun argent n\'est débité. Numéro finissant par 01 : solde insuffisant · 02 : refus · 03 : sans réponse.';

  @override
  String checkoutPay(String amount) {
    return 'Payer $amount';
  }

  @override
  String get checkoutWaitingTitle => 'Confirmez sur votre téléphone';

  @override
  String checkoutWaitingBody(String operator, String amount) {
    return 'Composez votre code $operator pour valider $amount. Cet écran se met à jour tout seul.';
  }

  @override
  String checkoutExpiresIn(String time) {
    return 'la demande expire dans $time';
  }

  @override
  String get checkoutStepSent => 'Demande envoyée';

  @override
  String checkoutStepSentTo(String number) {
    return 'à $number';
  }

  @override
  String get checkoutStepConfirm => 'Confirmation par votre code';

  @override
  String get checkoutStepPending => 'en attente';

  @override
  String get checkoutStepActivated => 'Abonnement activé';

  @override
  String checkoutStepActivatedHint(String operator) {
    return 'dès la réponse de $operator';
  }

  @override
  String get checkoutLeave => 'Quitter cet écran';

  @override
  String get checkoutLeaveHint =>
      'L\'abonnement s\'activera dès la confirmation, même si vous quittez cet écran.';

  @override
  String get checkoutSuccessTitle => 'Alanya Plus est actif';

  @override
  String checkoutSuccessBody(String plan, String start, String end) {
    return '$plan, du $start au $end.';
  }

  @override
  String get checkoutSuccessScheduled =>
      'D\'ici là, tout reste gratuit pour vous.';

  @override
  String get checkoutSuccessFeatures =>
      'Traduction, sauvegarde, trajets et sonneries par liste sont actifs.';

  @override
  String get checkoutSuccessFeaturesScheduled =>
      'Traduction, sauvegarde, trajets et sonneries par liste restent actifs sans interruption.';

  @override
  String get checkoutDone => 'Terminé';

  @override
  String get checkoutFailedTitle => 'Le paiement n\'a pas abouti';

  @override
  String get checkoutFailedInsufficient =>
      'Solde insuffisant sur ce compte mobile money.';

  @override
  String get checkoutFailedDeclined =>
      'Le paiement a été refusé sur le téléphone.';

  @override
  String get checkoutFailedTimeout =>
      'Aucune confirmation n\'est arrivée à temps. Vous pouvez réessayer.';

  @override
  String get checkoutFailedGeneric =>
      'Le paiement a échoué. Vous pouvez réessayer.';

  @override
  String get subscriptionTitle => 'Mon abonnement';

  @override
  String get subscriptionAutoRenew => 'Renouvellement automatique';

  @override
  String get subscriptionAutoRenewHint =>
      'La veille de l\'échéance, votre opérateur vous demandera de confirmer le paiement.';

  @override
  String get subscriptionNextDuration => 'Durée au prochain renouvellement';

  @override
  String get subscriptionPayments => 'Paiements';

  @override
  String get subscriptionPeriods => 'Périodes';

  @override
  String subscriptionRenewAmount(String amount) {
    return 'Renouveler — $amount';
  }

  @override
  String get subscriptionNoPayments => 'Aucun paiement pour l\'instant.';

  @override
  String get subscriptionSourcePaid => 'Payé';

  @override
  String get subscriptionSourceTrial => 'Essai';

  @override
  String get subscriptionSourceGift => 'Offert';

  @override
  String get subscriptionSourceCompensation => 'Compensation';

  @override
  String subscriptionEndsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count jours',
      one: 'dans 1 jour',
      zero: 'aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionNoneTitle => 'Aucun abonnement en cours';

  @override
  String get subscriptionNoneBody =>
      'Alanya Plus débloque la traduction, la sauvegarde, les trajets de confiance et les sonneries par liste.';

  @override
  String get subscriptionExemptTitle =>
      'Alanya Plus est inclus avec votre compte';

  @override
  String get paymentStatusSucceeded => 'Réussi';

  @override
  String get paymentStatusFailed => 'Échoué';

  @override
  String get paymentStatusExpired => 'Expiré';

  @override
  String get paymentStatusRefunded => 'Remboursé';

  @override
  String get paymentStatusPending => 'En attente';

  @override
  String get plusLockedTranslation =>
      'Sans abonnement, la traduction ne s\'applique qu\'à vos conversations avec un contact Alanya Plus.';

  @override
  String get plusLockedBackup =>
      'Les nouvelles sauvegardes sont réservées à Alanya Plus. Vos sauvegardes existantes restent restaurables.';

  @override
  String get plusLockedRingtones =>
      'Les sonneries par liste sont réservées à Alanya Plus. Vos réglages sont conservés et reprendront dès l\'abonnement.';

  @override
  String get plusLockedTrips =>
      'Les nouveaux trajets et le SOS hors trajet sont réservés à Alanya Plus. Un trajet déjà commencé garde son SOS jusqu\'à la fin.';

  @override
  String plusCardLapsedBodyUntil(String date) {
    return 'Vos réglages et votre historique sont conservés jusqu\'au $date. Réabonnez-vous d\'ici là pour tout retrouver, coche comprise.';
  }

  @override
  String get plusCardPurgedBody =>
      'Vos réglages et votre historique Plus ont été effacés. Réabonnez-vous pour retrouver vos fonctionnalités.';

  @override
  String get plusCardTrialKicker => 'Essai gratuit';

  @override
  String plusCardTrialTitle(String date) {
    return 'Gratuit jusqu\'au $date';
  }

  @override
  String get plusCardTrialBody =>
      'Tout est ouvert. Ensuite, vous recevrez toujours vos messages et vos appels, mais il faudra un abonnement pour envoyer et appeler.';

  @override
  String plusCardTrialDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'encore $count jours d\'essai',
      one: 'encore 1 jour d\'essai',
      zero: 'dernier jour d\'essai',
    );
    return '$_temp0';
  }

  @override
  String get plusCardSubscribe => 'S\'abonner';

  @override
  String get plusCardRestrictedKicker => 'Essai terminé';

  @override
  String get plusCardRestrictedTitle =>
      'Vous ne pouvez plus envoyer ni appeler';

  @override
  String get plusCardRestrictedBody =>
      'Vous recevez toujours vos messages et vos appels. Abonnez-vous pour envoyer des messages et appeler de nouveau.';

  @override
  String get plusCardLapsedTrialBody =>
      'Vous recevez toujours vos messages et vos appels. Entrez un nouveau code pour reprendre.';

  @override
  String get plusCardRenewByCode =>
      'Pour renouveler, il vous faudra un nouveau code.';

  @override
  String get plusCardScheduledTrialBody =>
      'Votre essai gratuit continue jusque-là, puis l\'abonnement prend le relais.';

  @override
  String get subscriptionSourceCode => 'Code d\'activation';

  @override
  String get redeemTitle => 'J\'ai un code';

  @override
  String get redeemIntro =>
      'Après votre paiement sur le site, vous avez reçu un code. Entrez-le ici : il débloque tout pendant un an.';

  @override
  String get redeemFieldLabel => 'Code d\'activation';

  @override
  String get redeemFieldHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get redeemSubmit => 'Activer';

  @override
  String get redeemChecksumError =>
      'Ce code ne semble pas correct. Vérifiez chaque caractère.';

  @override
  String get redeemSuccessTitle => 'Abonnement activé';

  @override
  String redeemSuccessActive(String date) {
    return 'Votre abonnement est actif jusqu\'au $date.';
  }

  @override
  String redeemSuccessScheduled(String start, String end) {
    return 'Votre essai gratuit continue. L\'abonnement commencera le $start et durera jusqu\'au $end.';
  }

  @override
  String get redeemDone => 'Terminé';

  @override
  String get redeemPaste => 'Coller le code';

  @override
  String get composerSubscriptionRequired =>
      'Votre essai est terminé : vous recevez vos messages, mais il faut un abonnement pour en envoyer.';

  @override
  String redeemLocked(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Trop d\'essais. Réessayez dans $_temp0.';
  }

  @override
  String get paywallOutgoingTitle => 'Abonnez-vous pour continuer';

  @override
  String get paywallOutgoingBody =>
      'Votre essai gratuit est terminé. Vous recevez toujours vos messages et vos appels, mais il faut un abonnement pour envoyer des messages et appeler.';

  @override
  String get paywallTrialTitle => 'Abonnez-vous à Alanya';

  @override
  String get paywallTrialBody =>
      'Un abonnement d\'un an débloque tout : envoyer des messages, appeler, traduire, sauvegarder et vos trajets de confiance. Pendant l\'essai gratuit, vous pouvez le prendre dès maintenant : il commencera à la fin de l\'essai.';

  @override
  String get paywallPayOnline => 'Payer en ligne';

  @override
  String get paywallHaveCode => 'J\'ai un code';

  @override
  String get paywallPayHint =>
      'Vous paierez sur notre site, puis vous recevrez un code à entrer ici.';

  @override
  String get paywallPayUnavailable =>
      'Le paiement en ligne n\'est pas encore disponible. Si vous avez un code, entrez-le.';

  @override
  String get paywallPayOpenFailed =>
      'Impossible d\'ouvrir le site de paiement.';

  @override
  String get errCodeInvalidCode => 'Ce code n\'existe pas. Vérifiez-le.';

  @override
  String get errCodeInvalidCodeFormat =>
      'Ce code est mal saisi. Il comporte 15 caractères.';

  @override
  String get errCodeCodeAlreadyUsed => 'Ce code a déjà été utilisé.';

  @override
  String get errCodeCodeExpired => 'Ce code a expiré.';

  @override
  String get errCodeCodeRevoked => 'Ce code a été annulé.';

  @override
  String get errCodeCodeLocked =>
      'Trop d\'essais. Réessayez dans quelques minutes.';

  @override
  String get verificationTitle => 'Obtenir la coche';

  @override
  String get verificationStatusTitle => 'Ma vérification';

  @override
  String get verificationIntro =>
      'La coche dit à vos contacts que vous êtes bien la personne dont ce compte porte le nom.';

  @override
  String get verificationNameLabel => 'Nom à vérifier';

  @override
  String get verificationNameHint =>
      'C\'est le nom de votre profil. Il doit correspondre à votre pièce.';

  @override
  String get verificationToProvide => 'À fournir';

  @override
  String get verificationIdFront => 'Pièce d\'identité — recto';

  @override
  String get verificationIdFrontHint => 'CNI, passeport ou permis de conduire';

  @override
  String get verificationIdBack => 'Pièce d\'identité — verso';

  @override
  String get verificationIdBackHint => 'si votre pièce en a un';

  @override
  String get verificationSelfie => 'Selfie avec la pièce';

  @override
  String get verificationSelfieHint => 'visage et pièce lisibles';

  @override
  String get verificationTakePhoto => 'Prendre une photo';

  @override
  String get verificationChooseGallery => 'Choisir dans la galerie';

  @override
  String get verificationRemove => 'Retirer';

  @override
  String get verificationPrivacy =>
      'Vos pièces sont chiffrées, vues seulement par l\'administration, et supprimées 90 jours après la décision. Chaque consultation est journalisée.';

  @override
  String get verificationSubmit => 'Envoyer ma demande';

  @override
  String get verificationSendPieces => 'Envoyer les pièces';

  @override
  String get verificationPendingTitle => 'Vérification en cours';

  @override
  String verificationPendingBody(String date) {
    return 'Déposée le $date · réponse sous 5 jours ouvrés';
  }

  @override
  String get verificationStepSent => 'Demande envoyée';

  @override
  String get verificationStepPieces => 'Pièces reçues';

  @override
  String verificationPiecesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces',
      one: '1 pièce',
    );
    return '$_temp0';
  }

  @override
  String get verificationStepReview => 'Examen par Alanya';

  @override
  String get verificationStepInProgress => 'en cours';

  @override
  String get verificationStepDecision => 'Décision';

  @override
  String get verificationStepDecisionHint => 'une notification vous préviendra';

  @override
  String get verificationPlusNotWaiting =>
      'Votre abonnement est actif : vos fonctionnalités Plus n\'attendent pas la décision.';

  @override
  String get verificationCancel => 'Annuler ma demande';

  @override
  String get verificationCancelConfirm =>
      'Annuler la demande ? Vos pièces seront supprimées.';

  @override
  String get verificationDocRequestedTitle =>
      'Une pièce manque à votre dossier';

  @override
  String get verificationRefusedTitle => 'Demande refusée';

  @override
  String get verificationRevokedTitle => 'Coche retirée';

  @override
  String verificationReason(String reason) {
    return 'Motif : $reason';
  }

  @override
  String get verificationResubmitHint =>
      'Vous pouvez déposer une nouvelle demande.';

  @override
  String get verificationRenamedTitle => 'Votre nom a changé';

  @override
  String get verificationRenamedBody =>
      'La coche attend un nouvel examen : déposez des pièces au nom affiché, ou reprenez le nom vérifié.';

  @override
  String get verificationApprovedTitle => 'Identité vérifiée, coche active';

  @override
  String verificationApprovedUntil(String date) {
    return 'Elle suit votre abonnement : jusqu\'au $date.';
  }

  @override
  String get verificationApprovedFree =>
      'La coche s\'affiche à côté de votre nom.';

  @override
  String get verificationPausedTitle => 'Identité vérifiée, coche en pause';

  @override
  String get verificationPausedBody =>
      'Elle revient dès que votre abonnement reprend.';

  @override
  String get verificationUnavailableBody =>
      'La vérification d\'identité ouvre bientôt. Revenez dans quelques jours.';

  @override
  String get plusCardBadgeMissing =>
      'La coche s\'affiche avec un abonnement actif.';

  @override
  String get errCodeVerificationUnavailable =>
      'La vérification d\'identité n\'est pas encore ouverte.';

  @override
  String get errCodeDocumentsRequired =>
      'Ajoutez votre pièce d\'identité et un selfie avec la pièce.';

  @override
  String get errCodeNameRequired =>
      'Renseignez votre nom dans votre profil avant de le faire vérifier.';

  @override
  String get errCodeVerificationAlreadyOpen =>
      'Une demande est déjà en cours d\'examen.';

  @override
  String get errCodeVerificationAlreadyApproved =>
      'Votre identité est déjà vérifiée sous ce nom.';

  @override
  String get errCodeRequestNotPending =>
      'Ce dossier a changé entre-temps. Rechargez l\'écran.';

  @override
  String get phoneChangeTitle => 'Choisir mon numéro';

  @override
  String get phoneChangeProduct => 'Numéro Alanya';

  @override
  String get phoneChangeCurrent => 'Votre numéro actuel';

  @override
  String phoneChangeIntro(String amount) {
    return 'Choisissez un numéro à 8 chiffres plus facile à retenir, pour $amount. Il remplace l\'actuel, y compris pour vous connecter.';
  }

  @override
  String get phoneChangeFieldLabel => 'Numéro souhaité';

  @override
  String get phoneChangeCheck => 'Vérifier';

  @override
  String get phoneChangeMustBe8 => 'Entrez un numéro à 8 chiffres.';

  @override
  String get phoneChangeAvailable => 'Disponible';

  @override
  String get phoneChangeReasonSame => 'C\'est déjà votre numéro.';

  @override
  String get phoneChangeReasonTaken =>
      'Ce numéro est déjà utilisé. Essayez-en un autre.';

  @override
  String get phoneChangeReasonSetAside =>
      'Ce numéro est réservé par Alanya. Essayez-en un autre.';

  @override
  String get phoneChangeReasonHeld =>
      'Quelqu\'un est en train de prendre ce numéro. Réessayez dans quelques minutes, ou choisissez-en un autre.';

  @override
  String get phoneChangeReasonQuarantine =>
      'Ce numéro vient d\'être libéré par son titulaire et n\'est pas encore disponible. Essayez-en un autre.';

  @override
  String phoneChangeReserveAndPay(String amount) {
    return 'Réserver et payer $amount';
  }

  @override
  String get phoneChangeUseCredit => 'Valider ce numéro';

  @override
  String get phoneChangeCreditBanner =>
      'Votre changement est déjà payé, mais le numéro choisi a été pris entre-temps. Choisissez-en un autre : rien ne vous sera redemandé.';

  @override
  String phoneChangeHeldUntil(String phone, String time) {
    return '$phone est réservé pour vous jusqu\'à $time.';
  }

  @override
  String get phoneChangeReleaseHold => 'Libérer ce numéro';

  @override
  String phoneChangePending(String phone) {
    return 'Paiement en cours pour le $phone.';
  }

  @override
  String get phoneChangeSeeWaiting => 'Suivre le paiement';

  @override
  String get phoneChangeLoginNote =>
      'Après le changement, connectez-vous avec le nouveau numéro. Vos conversations, contacts et groupes vous suivent. Votre ancien numéro ne sera pas redonné tout de suite à quelqu\'un d\'autre.';

  @override
  String get phoneChangeUnavailable =>
      'Le choix du numéro n\'est pas disponible pour le moment.';

  @override
  String phoneChangeSummaryHeld(String time) {
    return 'Réservé pour vous jusqu\'à $time';
  }

  @override
  String get phoneChangeStepApplied => 'Numéro changé';

  @override
  String get phoneChangeLeaveHint =>
      'Votre numéro changera dès la confirmation, même si vous quittez cet écran.';

  @override
  String get phoneChangeSuccessTitle => 'Voici votre nouveau numéro';

  @override
  String get phoneChangeSuccessBody =>
      'C\'est lui qui sert désormais à vous connecter. Vos conversations, contacts et groupes vous suivent.';

  @override
  String get phoneChangeCreditTitle => 'Paiement confirmé';

  @override
  String get phoneChangeCreditBody =>
      'Le numéro choisi a été pris entre-temps. Choisissez-en un autre : rien ne vous sera redemandé.';

  @override
  String get phoneChangeChooseAnother => 'Choisir un numéro';

  @override
  String get errCodePhonePurchaseUnavailable =>
      'Le choix du numéro n\'est pas encore proposé.';

  @override
  String get errCodeOfficialPhoneFixed =>
      'Le numéro de ce compte ne peut pas changer.';

  @override
  String get errCodePhoneNotPurchasable =>
      'Seuls les numéros à 8 chiffres peuvent être choisis.';

  @override
  String get errCodePhoneUnavailable =>
      'Ce numéro n\'est plus disponible. Essayez-en un autre.';

  @override
  String get errCodePhoneHoldExpired =>
      'La réservation de ce numéro a expiré. Vérifiez-le à nouveau.';

  @override
  String get errCodePhoneOrderNotFound =>
      'Cette réservation n\'existe plus. Recommencez.';

  @override
  String get errCodePhoneOrderPending =>
      'Un paiement de numéro attend déjà votre confirmation.';

  @override
  String accountSecurityPhoneSubtitle(String amount) {
    return 'Changer pour un numéro plus facile à retenir · $amount';
  }

  @override
  String accountSecurityPhonePending(String phone) {
    return 'Changement en cours vers le $phone';
  }

  @override
  String get accountSecurityPhoneCredit =>
      'Changement payé : choisissez votre numéro';

  @override
  String get receiptsTitle => 'Infos du message';

  @override
  String receiptsReadBy(int count) {
    return 'Lu par $count';
  }

  @override
  String receiptsOutOf(int total) {
    return 'sur $total';
  }

  @override
  String receiptsDeliveredBy(int count) {
    return 'Reçu par $count';
  }

  @override
  String receiptsPendingCount(int count) {
    return 'En attente $count';
  }

  @override
  String get receiptsReadSection => 'Lu';

  @override
  String receiptsShowAllReaders(int count) {
    return 'Voir les $count lecteurs';
  }

  @override
  String get receiptsDeliveredNotRead => 'Reçu, pas encore lu';

  @override
  String get receiptsNotDelivered => 'Pas encore reçu';

  @override
  String receiptsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get receiptsNoReaders => 'Personne ne l\'a encore lu';

  @override
  String get receiptsLoadError =>
      'Impossible d\'afficher les accusés de lecture.';

  @override
  String receiptsBarLabel(int read, int delivered, int pending) {
    return '$read lu, $delivered reçu sans être lu, $pending en attente';
  }

  @override
  String get stickerWord => 'Sticker';

  @override
  String stickerPreview(String emoji) {
    return '$emoji Sticker';
  }

  @override
  String get stickerRemoved => 'Sticker retiré';

  @override
  String get stickerUnsupported =>
      'Sticker non pris en charge — mettez à jour l\'application';

  @override
  String get stickerTabEmojis => 'Émojis';

  @override
  String get stickerTabStickers => 'Stickers';

  @override
  String get stickerRecents => 'Récents';

  @override
  String get stickerFavorites => 'Favoris';

  @override
  String get stickerEmptyRecents => 'Vos stickers récents apparaîtront ici.';

  @override
  String get stickerEmptyFavorites =>
      'Touchez ★ dans la fiche d\'un sticker pour l\'ajouter à vos favoris.';

  @override
  String get stickerLoadError => 'Impossible de charger les stickers.';

  @override
  String get stickerRetry => 'Réessayer';

  @override
  String get stickerLockedBanner => 'Ce pack est réservé à Alanya Plus.';

  @override
  String get stickerUnlockCta => 'Découvrir Alanya Plus';

  @override
  String stickerLockedLabel(String name) {
    return 'Pack $name, verrouillé';
  }

  @override
  String get stickerBadgeOfficial => 'Officiel';

  @override
  String get stickerBadgePlus => 'Plus';

  @override
  String get stickerFavoriteAdd => 'Ajouter aux favoris';

  @override
  String get stickerFavoriteRemove => 'Retirer des favoris';

  @override
  String get stickerViewPack => 'Voir le pack';

  @override
  String get stickerForward => 'Transférer';

  @override
  String stickerSheetPack(String name) {
    return 'Pack : $name';
  }

  @override
  String stickerSheetSender(String name) {
    return 'Envoyé par $name';
  }

  @override
  String stickerSheetSize(int w, int h) {
    return '$w × $h px';
  }

  @override
  String stickerSheetWeight(String size) {
    return 'Poids : $size';
  }

  @override
  String get stickerAddPack => 'Ajouter';

  @override
  String get stickerRemovePack => 'Retirer';

  @override
  String get stickerAdded => 'Pack ajouté.';

  @override
  String get stickerPackRemoved => 'Pack retiré.';

  @override
  String get stickerMyPacks => 'Mes packs';

  @override
  String get stickerCatalog => 'Catalogue';

  @override
  String get stickerManage => 'Gérer les stickers';

  @override
  String stickerPackCount(int count) {
    return '$count stickers';
  }

  @override
  String get stickerPackInstalled => 'Installé';

  @override
  String get stickerSendLockedPlus => 'Ce sticker nécessite Alanya Plus.';

  @override
  String get stickerDomainError =>
      'Les stickers ne sont pas disponibles pour le moment.';

  @override
  String get errCodeStickerNotFound => 'Ce sticker n\'existe plus.';

  @override
  String get errCodeStickerPackUnavailable => 'Ce pack n\'est plus disponible.';

  @override
  String get errCodeStickerInvalidPayload =>
      'Ce sticker n\'a pas pu être envoyé.';

  @override
  String get errCodeStickerAssetInvalid =>
      'Cette image ne peut pas devenir un sticker.';

  @override
  String get errCodeStickerAssetBlocked =>
      'Cette image est bloquée et ne peut pas être utilisée.';

  @override
  String get errCodeStickerQuotaExceeded =>
      'Vous avez atteint votre limite de 200 stickers.';

  @override
  String get errCodeStickerPackLimit =>
      'Vous avez atteint la limite de packs ou de stickers par pack.';

  @override
  String get plusFeatureStickers => 'Stickers Royal';

  @override
  String get paywallStickersTitle => 'Les stickers Royal';

  @override
  String get paywallStickersBody =>
      'Le pack Royal fait partie d\'Alanya Plus : couronnes, trophées et paillettes pour vos conversations.';

  @override
  String get stickerTrayLabel => 'Stickers';

  @override
  String get stickerNoPacks =>
      'Aucun pack installé. Ouvrez le catalogue pour en ajouter.';

  @override
  String get stickerPreviewTitle => 'Aperçu du sticker';

  @override
  String get stickerReplyQuote => 'Sticker';

  @override
  String stickerSemantics(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get stickerPackLockedSemantics => 'Verrouillé, Alanya Plus requis';

  @override
  String get stickerSendFailed => 'Le sticker n\'a pas pu être envoyé.';

  @override
  String get stickerPackReorderHint => 'Maintenez et glissez pour réordonner';

  @override
  String get stickerPackActions => 'Actions du pack';

  @override
  String get stickerMoveUp => 'Monter';

  @override
  String get stickerMoveDown => 'Descendre';

  @override
  String get stickerNoFavorites => 'Aucun favori';

  @override
  String get stickerOfficialPackName => 'Pack officiel';

  @override
  String get stickerTabInstalled => 'Installés';

  @override
  String get stickerMyCreations => 'Mes créations';

  @override
  String get stickerCreatedEmpty =>
      'Vous n\'avez encore créé aucun pack. Touchez ＋ pour commencer.';

  @override
  String get stickerNewPack => 'Nouveau pack';

  @override
  String get stickerPackNameLabel => 'Nom du pack';

  @override
  String get stickerDefaultPackName => 'Mes stickers';

  @override
  String get stickerPrivacyTitle => 'Avant de créer';

  @override
  String get stickerPrivacyBody =>
      'Un sticker envoyé peut être vu par ses destinataires.';

  @override
  String get stickerPrivacyDetail =>
      'Votre pack reste privé, mais chaque image est accessible à toute personne qui la reçoit dans une conversation.';

  @override
  String get stickerPrivacyConfirm => 'J\'ai compris';

  @override
  String get stickerRename => 'Renommer';

  @override
  String get stickerDeletePack => 'Supprimer le pack';

  @override
  String get stickerDeletePackBody =>
      'Le pack sera supprimé et son lien de partage révoqué. Les stickers déjà envoyés peuvent s\'afficher « Sticker retiré ».';

  @override
  String get stickerPackDeleted => 'Pack supprimé.';

  @override
  String get stickerAddFromGallery => 'Ajouter depuis la galerie';

  @override
  String get stickerAddedSticker => 'Sticker ajouté au pack.';

  @override
  String get stickerAlreadyOwned => 'Cette image est déjà dans vos stickers.';

  @override
  String get stickerRemoveFromPack => 'Retirer du pack';

  @override
  String get stickerPackEmpty =>
      'Ce pack est vide. Ajoutez une image depuis la galerie.';

  @override
  String get stickerImageFormat =>
      'Image illisible. Choisissez une photo JPEG, PNG ou WebP.';

  @override
  String get stickerImageTooBig => 'L\'image dépasse 1 Mo.';

  @override
  String get stickerImageSize =>
      'L\'image doit mesurer exactement 512 × 512 px.';

  @override
  String get stickerImageNoAlpha =>
      'L\'image doit avoir un fond transparent (PNG ou WebP avec transparence).';

  @override
  String get stickerImageAnimated =>
      'Les images animées (GIF, WebP animé) ne sont pas encore prises en charge.';

  @override
  String get stickerImageInputTooBig =>
      'Cette image est trop grande (20 Mo ou 50 mégapixels au plus).';

  @override
  String get stickerPreviewHint =>
      'L\'image est ajustée dans un carré de 512 × 512 px. Le damier montre les zones transparentes.';

  @override
  String get stickerPreviewAdd => 'Ajouter';

  @override
  String get stickerAddToPack => 'Ajouter à un pack';

  @override
  String get stickerChoosePack => 'Choisir un pack';

  @override
  String get stickerCopiedToPack => 'Sticker ajouté à votre pack.';

  @override
  String get stickerReport => 'Signaler';

  @override
  String get stickerReportTitle => 'Pourquoi signaler ce sticker ?';

  @override
  String get stickerReportInappropriate => 'Contenu inapproprié';

  @override
  String get stickerReportSpam => 'Spam';

  @override
  String get stickerReportRights => 'Atteinte à des droits';

  @override
  String get stickerReportOther => 'Autre';

  @override
  String get stickerReported => 'Merci, votre signalement a été envoyé.';

  @override
  String get stickerReportedAlready => 'Vous avez déjà signalé ce sticker.';

  @override
  String get stickerShareByLink => 'Partager par lien';

  @override
  String get stickerShareRevoke => 'Révoquer le lien';

  @override
  String get stickerShareRevoked => 'Lien révoqué.';

  @override
  String get stickerShareRevokeBody =>
      'Le lien ne fonctionnera plus. Les personnes qui ont déjà ajouté le pack en gardent leur copie.';

  @override
  String get stickerShareEmpty =>
      'Ajoutez au moins un sticker avant de partager.';

  @override
  String get stickerShared => 'Partagé';

  @override
  String stickerShareMessage(String name, String link, String code) {
    return 'Mon pack de stickers « $name » sur Alanya : $link\nCode : $code';
  }

  @override
  String get stickerOpenLink => 'Ouvrir un lien de pack';

  @override
  String get stickerOpenLinkHint => 'Collez un lien ou un code';

  @override
  String get stickerOpenLinkInvalid =>
      'Ce lien ou ce code n\'est pas celui d\'un pack de stickers.';

  @override
  String get stickerSharedPackTitle => 'Pack partagé';

  @override
  String get stickerShareInstall => 'Ajouter à mes packs';

  @override
  String get stickerShareCopyInfo =>
      'Vous recevez votre propre copie : elle reste à vous même si le lien est révoqué.';

  @override
  String get stickerShareAlreadyAdded => 'Déjà ajouté';

  @override
  String get stickerShareMine => 'C\'est votre propre pack.';

  @override
  String get stickerShareDone => 'Pack ajouté à vos créations.';

  @override
  String stickerShareIgnored(int count) {
    return '$count image(s) ignorée(s) (bloquées ou retirées).';
  }

  @override
  String stickerCreatedCount(int count, int max) {
    return '$count/$max';
  }

  @override
  String get errCodeRateLimited =>
      'Trop de demandes. Réessayez dans une minute.';

  @override
  String get stickerSetCover => 'Définir comme couverture';

  @override
  String get stickerPaste => 'Coller';

  @override
  String get stickerPreviewEdit => 'Modifier';

  @override
  String get mediaEditorTitleSticker => 'Modifier le sticker';

  @override
  String get mediaEditorTitlePhoto => 'Retoucher l\'image';

  @override
  String get mediaEditorDone => 'Terminer';

  @override
  String get mediaEditorUndo => 'Annuler';

  @override
  String get mediaEditorRedo => 'Rétablir';

  @override
  String get mediaEditorTools => 'Outils de retouche';

  @override
  String get mediaEditorToolCrop => 'Rogner';

  @override
  String get mediaEditorToolDraw => 'Crayon';

  @override
  String get mediaEditorToolText => 'Texte';

  @override
  String get mediaEditorToolEmoji => 'Emoji';

  @override
  String get mediaEditorPen => 'Crayon';

  @override
  String get mediaEditorEraser => 'Gomme';

  @override
  String get mediaEditorColor => 'Couleur';

  @override
  String get mediaEditorColorBlack => 'Noir';

  @override
  String get mediaEditorColorWhite => 'Blanc';

  @override
  String get mediaEditorColorRed => 'Rouge';

  @override
  String get mediaEditorColorOrange => 'Orange';

  @override
  String get mediaEditorColorGreen => 'Vert';

  @override
  String get mediaEditorColorBlue => 'Bleu';

  @override
  String get mediaEditorColorIndigo => 'Indigo';

  @override
  String get mediaEditorThickness => 'Épaisseur du trait';

  @override
  String get mediaEditorCropHintSticker =>
      'Pincez pour zoomer, glissez pour déplacer l\'image dans le carré.';

  @override
  String get mediaEditorCropHintPhoto =>
      'Pincez pour zoomer, glissez pour déplacer l\'image dans le cadre.';

  @override
  String get mediaEditorFitContain => 'Ajuster';

  @override
  String get mediaEditorFitCover => 'Remplir';

  @override
  String get mediaEditorAspectOriginal => 'Original';

  @override
  String get mediaEditorAddText => 'Ajouter un texte';

  @override
  String get mediaEditorEditText => 'Modifier le texte';

  @override
  String get mediaEditorTextHint => 'Votre texte';

  @override
  String get mediaEditorFontStandard => 'Standard';

  @override
  String get mediaEditorFontBold => 'Gras';

  @override
  String get mediaEditorFontHandwriting => 'Manuscrite';

  @override
  String get mediaEditorAddEmoji => 'Ajouter un emoji';

  @override
  String get mediaEditorSize => 'Taille';

  @override
  String get mediaEditorRotation => 'Rotation';

  @override
  String get mediaEditorDeleteItem => 'Supprimer l\'élément';

  @override
  String get mediaEditorCanvas => 'Zone de retouche de l\'image';

  @override
  String get mediaEditorDiscardTitle => 'Abandonner les modifications ?';

  @override
  String get mediaEditorDiscardBody => 'Vos retouches seront perdues.';

  @override
  String get mediaEditorKeepEditing => 'Continuer';

  @override
  String get mediaEditorDiscard => 'Abandonner';

  @override
  String get mediaEditorExporting => 'Préparation de l\'image…';

  @override
  String get mediaEditorToolCutout => 'Détourer';

  @override
  String get mediaEditorCutoutHint =>
      'Détourage automatique : personnes. Pour le reste, utilisez le pinceau.';

  @override
  String get mediaEditorCutoutAuto => 'Détourer les personnes';

  @override
  String get mediaEditorCutoutBusy => 'Détourage en cours…';

  @override
  String get mediaEditorCutoutKeep => 'Garder';

  @override
  String get mediaEditorCutoutErase => 'Effacer';

  @override
  String get mediaEditorCutoutSize => 'Taille du pinceau';

  @override
  String get mediaEditorCutoutSoft => 'Bords doux';

  @override
  String get mediaEditorCutoutReset => 'Réinitialiser le masque';

  @override
  String get mediaEditorCutoutNoPerson =>
      'Aucune personne détectée sur cette image. Utilisez le pinceau pour détourer.';

  @override
  String get mediaEditorCutoutFailed =>
      'Le détourage automatique a échoué. Utilisez le pinceau pour détourer.';

  @override
  String stickerAnimatedSemantics(String emoji) {
    return 'Sticker animé $emoji';
  }

  @override
  String get stickerReplay => 'Rejouer l\'animation';

  @override
  String get stickerOpenDetails => 'Voir la fiche du sticker';

  @override
  String get stickerBadgeAnimated => 'Animé';

  @override
  String get stickerAddAnimated => 'Ajouter un sticker animé';

  @override
  String get stickerAnimatedTitle => 'Sticker animé';

  @override
  String get stickerAnimatedShape => 'Forme';

  @override
  String get stickerShapeCircle => 'Cercle';

  @override
  String get stickerShapeRounded => 'Carré arrondi';

  @override
  String get stickerShapeSquare => 'Carré';

  @override
  String get stickerAnimatedHint =>
      'Votre image sera recadrée en carré et limitée à 3 secondes environ. Dans la conversation, l\'animation se joue une fois ; touchez le sticker pour la rejouer.';

  @override
  String get stickerAnimatedPreviewLabel => 'Aperçu animé du sticker';

  @override
  String get stickerAnimatedConverting => 'Conversion en cours…';

  @override
  String get stickerAnimatedConvertingHint =>
      'Cela peut prendre une quinzaine de secondes.';

  @override
  String get stickerAnimatedAdded => 'Sticker animé ajouté.';

  @override
  String get stickerAnimatedNotAnimated =>
      'Ce fichier n\'est pas animé. Choisissez un GIF ou un WebP animé.';

  @override
  String get stickerAnimatedFormat =>
      'Seuls les GIF et les WebP animés sont acceptés.';

  @override
  String get stickerAnimatedTooBig => 'Ce fichier dépasse 3 Mo.';

  @override
  String get stickerAnimatedInvalid =>
      'Ce fichier est trop lourd ou n\'est pas pris en charge. Essayez un GIF plus court ou plus petit.';

  @override
  String get stickerAnimatedRateLimited =>
      'Vous avez créé beaucoup de stickers animés. Réessayez plus tard (10 par heure au plus).';

  @override
  String get stickerAnimatedBusy =>
      'Le service est occupé. Réessayez dans un instant.';

  @override
  String get stickerAnimatedClosed =>
      'Les stickers animés ne sont pas disponibles pour le moment.';

  @override
  String get mediaEditorCropHintRound =>
      'Glissez et pincez pour cadrer la photo : elle s\'affichera dans un cercle.';

  @override
  String get mediaEditorEditFailed =>
      'Impossible de préparer la photo modifiée. Réessayez.';

  @override
  String get stickerCreateTile => 'Créer';

  @override
  String get stickerCreateHint =>
      'Créez un sticker à partir d\'une photo de votre galerie.';

  @override
  String stickerCreatedInMyStickers(String name) {
    return 'Ajouté à $name';
  }

  @override
  String get stickerView => 'Voir';

  @override
  String get chatPanelExpand => 'Agrandir le panneau';

  @override
  String get chatPanelCollapse => 'Réduire le panneau';

  @override
  String get stickerVideoTitle => 'Sticker depuis une vidéo';

  @override
  String get stickerVideoPreviewLabel => 'Aperçu de la vidéo découpée';

  @override
  String get stickerVideoStart => 'Début';

  @override
  String get stickerVideoDuration => 'Durée';

  @override
  String stickerVideoStartValue(String time) {
    return 'Début : $time';
  }

  @override
  String stickerVideoDurationValue(String seconds) {
    return 'Durée : $seconds s';
  }

  @override
  String get stickerVideoPlay => 'Lecture';

  @override
  String get stickerVideoPause => 'Pause';

  @override
  String get stickerVideoHint =>
      'Choisissez les 3 secondes à garder (500 ms au minimum). La vidéo est découpée sur nos serveurs, sans le son.';

  @override
  String get stickerVideoTooBig =>
      'Cette vidéo dépasse 20 Mo. Choisissez-en une plus courte.';

  @override
  String get stickerVideoFormat =>
      'Format non pris en charge. Choisissez une vidéo MP4, MOV ou WebM.';

  @override
  String get stickerVideoUnsupported =>
      'Les vidéos ne sont pas encore prises en charge.';

  @override
  String get stickerVideoTooShort =>
      'Cette vidéo est trop courte (500 ms au minimum).';

  @override
  String get stickerVideoLoadFailed => 'Impossible de lire cette vidéo.';

  @override
  String get stickerVideoConverting => 'Envoi et conversion de la vidéo…';

  @override
  String get stickerVideoConvertingHint =>
      'En données mobiles, cela peut prendre jusqu\'à une minute.';

  @override
  String get stickerVideoInvalid =>
      'Cette vidéo n\'est pas prise en charge ou est trop détaillée. Essayez une vidéo plus courte ou plus simple.';

  @override
  String get mediaEditorToolFilters => 'Filtres';

  @override
  String get mediaEditorBrushPen => 'Stylo';

  @override
  String get mediaEditorBrushHighlighter => 'Surligneur';

  @override
  String get mediaEditorBrushNeon => 'Néon';

  @override
  String get mediaEditorBrushBlur => 'Flou';

  @override
  String get mediaEditorBlurHint =>
      'Passez le doigt sur un visage ou une plaque pour le flouter.';

  @override
  String get mediaEditorColorYellow => 'Jaune';

  @override
  String get mediaEditorColorPink => 'Rose';

  @override
  String get mediaEditorRotate90 => 'Pivoter';

  @override
  String get mediaEditorFlip => 'Miroir';

  @override
  String get mediaEditorReset => 'Réinitialiser';

  @override
  String get mediaEditorStraighten => 'Redresser';

  @override
  String get mediaEditorTabFilters => 'Filtres';

  @override
  String get mediaEditorTabAdjust => 'Réglages';

  @override
  String get mediaEditorIntensity => 'Intensité';

  @override
  String get mediaEditorBrightness => 'Luminosité';

  @override
  String get mediaEditorContrast => 'Contraste';

  @override
  String get mediaEditorSaturation => 'Saturation';

  @override
  String get mediaEditorWarmth => 'Chaleur';

  @override
  String get mediaEditorFilterNone => 'Original';

  @override
  String get mediaEditorFilterVivid => 'Vif';

  @override
  String get mediaEditorFilterWarm => 'Chaud';

  @override
  String get mediaEditorFilterSoft => 'Doux';

  @override
  String get mediaEditorFilterMono => 'N&B';

  @override
  String get mediaEditorFilterNight => 'Nuit';

  @override
  String get mediaEditorCompare => 'Maintenir pour voir l\'original';

  @override
  String get mediaEditorAlign => 'Alignement du texte';

  @override
  String get mediaEditorTextBackground => 'Fond du texte';

  @override
  String get mediaEditorItemHint =>
      'Glissez pour déplacer, pincez pour agrandir ou tourner.';

  @override
  String get mediaSendRemoveItem => 'Retirer de l\'envoi';

  @override
  String get mediaSendAddMore => 'Ajouter des médias';

  @override
  String get mediaSendUndoEdit => 'Annuler la dernière retouche';

  @override
  String get mediaSendViewOnceOn => 'Vue unique activée';

  @override
  String get mediaSendViewOnceOff => 'Vue unique désactivée';

  @override
  String get mediaSendMute => 'Couper le son';

  @override
  String get mediaSendUnmute => 'Remettre le son';

  @override
  String mediaSendEdits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count retouches',
      one: '1 retouche',
    );
    return '$_temp0';
  }

  @override
  String mediaSendItemLabel(String kind, int index, int total) {
    return '$kind $index sur $total';
  }

  @override
  String get cameraShutterHint =>
      'Appuyer pour une photo, maintenir pour filmer';

  @override
  String get cameraTakePhoto => 'Prendre une photo';

  @override
  String get cameraStartRecording => 'Filmer';

  @override
  String get cameraStopRecording => 'Arrêter l\'enregistrement';

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraOpenGallery => 'Ouvrir la galerie';

  @override
  String get videoTrimStart => 'Début de la vidéo';

  @override
  String get videoTrimEnd => 'Fin de la vidéo';

  @override
  String get videoRendering => 'Préparation de la vidéo…';

  @override
  String get videoRenderFailed => 'Impossible de préparer la vidéo. Réessayez.';

  @override
  String get videoFrameFailed =>
      'Impossible de lire cette vidéo pour la retoucher.';

  @override
  String videoTrimSummary(String range, String length, String total) {
    return '$range · $length sur $total';
  }

  @override
  String get errCodeDeleteWindowExpired =>
      'La suppression pour tous n\'est possible que dans les 72 heures suivant l\'envoi.';

  @override
  String get clearChatTitle => 'Effacer la discussion';

  @override
  String get clearChatAllMessages => 'Tous les messages';

  @override
  String get clearChatMediaOnly => 'Fichiers médias uniquement';

  @override
  String get clearChatAllHint =>
      'La discussion reste dans votre liste. Les autres participants ne voient aucun changement.';

  @override
  String get clearChatMediaHint =>
      'Les messages restent, sans les fichiers téléchargés sur cet appareil.';

  @override
  String clearChatButton(String size) {
    return 'Effacer la discussion ($size)';
  }

  @override
  String get clearChatButtonNoSize => 'Effacer la discussion';

  @override
  String get clearChatDone => 'Discussion effacée';

  @override
  String get clearChatMediaDone => 'Fichiers médias supprimés';

  @override
  String sysScreenshot(String actor) {
    return '$actor a fait une capture d\'écran de cette discussion';
  }

  @override
  String get sysScreenshotByMe =>
      'Vous avez fait une capture d\'écran de cette discussion';

  @override
  String sysScreenRecording(String actor) {
    return '$actor a enregistré l\'écran de cette discussion';
  }

  @override
  String get sysScreenRecordingByMe =>
      'Vous avez enregistré l\'écran de cette discussion';

  @override
  String get renameContactTitle => 'Nom du contact';

  @override
  String get renameContactHelper =>
      'Visible par vous seul. Laissez vide pour revenir au nom du profil.';

  @override
  String get contactProfileSection => 'Profil';

  @override
  String get contactProfileName => 'Nom';

  @override
  String get contactProfilePseudo => 'Pseudo';

  @override
  String get contactProfileNumber => 'Numéro Alanya';

  @override
  String get contactYourNameSection => 'Votre nom pour ce contact';

  @override
  String get contactYourNameNone => 'Aucun';

  @override
  String get contactYourNameAdd => 'Ajouter un nom';

  @override
  String get contactYourNameEdit => 'Modifier';

  @override
  String get contactYourNameClear => 'Effacer le nom';

  @override
  String get contactYourNameHelpSet =>
      'Visible par vous seul. Il remplace le nom du profil dans vos discussions, appels et notifications.';

  @override
  String get contactYourNameHelpEmpty =>
      'Enregistrez ce contact sous le nom de votre choix. Lui ne le verra jamais.';
}
