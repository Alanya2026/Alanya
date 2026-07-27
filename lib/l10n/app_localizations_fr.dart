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
  String get settingsLangFr => 'Français';

  @override
  String get settingsLangEn => 'Anglais';

  @override
  String get settingsLangSystem => 'Système';

  @override
  String get settingsMedia => 'Médias';

  @override
  String get settingsAutoDownload => 'Téléchargement automatique';

  @override
  String get settingsAutoDownloadSubtitle =>
      'Télécharge automatiquement les photos, vidéos et fichiers reçus dans l’app';

  @override
  String get settingsMediaVisibility => 'Visibilité des médias';

  @override
  String get settingsMediaVisibilitySubtitle =>
      'Enregistre les médias reçus dans le stockage interne (Galerie et Téléchargements)';

  @override
  String get settingsCalls => 'Appels';

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
  String errorWithDetails(String error) {
    return 'Échec : $error';
  }

  @override
  String actionFailedWithError(String error) {
    return 'Action impossible : $error';
  }

  @override
  String cannotUnblockWithError(String error) {
    return 'Impossible de débloquer : $error';
  }

  @override
  String loadErrorWithDetails(String error) {
    return 'Erreur chargement : $error';
  }

  @override
  String cannotOpenFileApp(String message) {
    return 'Aucune app pour ouvrir ce fichier ($message)';
  }

  @override
  String cannotOpenFileAppAlt(String message) {
    return 'Aucune application pour ouvrir ce fichier ($message)';
  }

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
  String videoTooLarge(String mb) {
    return 'Vidéo ignorée ($mb Mo). Limite : 50 Mo.';
  }

  @override
  String fileTooLarge(String mb) {
    return 'Fichier trop volumineux ($mb Mo). Limite : 50 Mo.';
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
  String cannotLoadMeeting(String error) {
    return 'Impossible de charger la réunion : $error';
  }

  @override
  String cannotJoinMeeting(String error) {
    return 'Impossible de rejoindre : $error';
  }

  @override
  String cannotCreateMeeting(String error) {
    return 'Impossible de créer la réunion : $error';
  }

  @override
  String meetingConnectFailed(String error) {
    return 'Échec de la connexion à la réunion : $error';
  }

  @override
  String uploadFailedWithError(String error) {
    return 'Échec de l\'upload : $error';
  }

  @override
  String sendFailedWithError(String error) {
    return 'Échec de l\'envoi : $error';
  }

  @override
  String recordFailedWithError(String error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String roleChangeError(String error) {
    return 'Erreur changement de rôle: $error';
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
      'Rechercher par nom, pseudo ou téléphone…';

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
  String get phoneAlanyaPhone => 'Téléphone (Téléphone Alanya)';

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
  String get alanyaNumberRequired => 'Numéro Alanya requis';

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
  String get searchComingSoon => 'Recherche à venir';

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
  String get newMeeting => 'Nouvelle réunion';

  @override
  String get alanyaPhone => 'Téléphone Alanya';

  @override
  String get deletedMessage => 'Message supprimé';

  @override
  String get verifyCode => 'Vérifier le code';

  @override
  String get notDeliveredYet => 'Pas encore livré';

  @override
  String get someoneIsTyping => 'Quelqu\'un écrit…';

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
  String anErrorOccurred(String error) {
    return 'Une erreur est survenue: $error';
  }

  @override
  String errorColon(String error) {
    return 'Erreur: $error';
  }

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
  String unableToPostStatusWithError(String error) {
    return 'Impossible de publier le statut : $error';
  }

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
  String networkErrorWithDetails(String error) {
    return 'Erreur réseau: $error';
  }

  @override
  String invalidResponseWithCode(Object code) {
    return 'Réponse invalide ($code)';
  }

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
  String filesSkippedTooLarge(int count) {
    return '$count fichier(s) ignoré(s) : limite 50 Mo.';
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
  String banUnbanError(String error) {
    return 'Erreur ban/unban: $error';
  }

  @override
  String deleteErrorWithDetails(String error) {
    return 'Erreur suppression: $error';
  }

  @override
  String loadUsersError(String error) {
    return 'Erreur chargement utilisateurs: $error';
  }

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
  String sourceFileNotFound(String path) {
    return 'Fichier source introuvable : $path';
  }

  @override
  String copyImpossible(String error) {
    return 'Copie impossible : $error';
  }

  @override
  String copyFailedPath(String path) {
    return 'Copie échouée : $path';
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
  String get onlyAdminsCanEditInfoSubtitle =>
      'Nom, photo, description et ajout de membres';

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
      'Sans e-mail, vous ne pourrez pas récupérer votre compte si vous oubliez votre numéro Alanya ou votre mot de passe.';

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
  String get changeEmailConfirm => 'Confirmer';

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
}
