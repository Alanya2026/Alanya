// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Alanya';

  @override
  String get navChats => 'Chats';

  @override
  String get navCalls => 'Calls';

  @override
  String get navStatuses => 'Status';

  @override
  String get navMeetings => 'Meetings';

  @override
  String get navProfile => 'Profile';

  @override
  String get offlineBanner =>
      'No connection — messages will be sent when you\'re back online';

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginSubtitle => 'Sign in to continue to Alanya';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginNoAccount => 'Don\'t have an account?';

  @override
  String get loginSignUp => 'Sign up';

  @override
  String get signupTitle => 'Create an account';

  @override
  String get signupSubtitle => 'Join the Alanya community';

  @override
  String get signupNameHint => 'Full name';

  @override
  String get signupPseudoHint => 'Username';

  @override
  String get signupEmailHint => 'Email address';

  @override
  String get signupPasswordHint => 'Password';

  @override
  String get signupSubmit => 'Sign up';

  @override
  String get signupHasAccount => 'Already have an account?';

  @override
  String get signupLogin => 'Sign in';

  @override
  String get validatorRequired => 'Required field';

  @override
  String get validatorEmail => 'Invalid email';

  @override
  String validatorMinLength(int n) {
    return 'At least $n characters';
  }

  @override
  String get validatorOtp6 => '6-digit OTP code';

  @override
  String get validatorPasswordMatch => 'Passwords do not match';

  @override
  String get unknownSender => 'Unknown';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusSent => 'Sent';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusRead => 'Read';

  @override
  String get statusFailedRetry => 'Failed — tap to retry';

  @override
  String get retry => 'Retry';

  @override
  String get forgotPasswordTitle => 'Password recovery';

  @override
  String get forgotEmailTitle => 'Enter your email';

  @override
  String get forgotEmailSubtitle => 'An OTP code will be sent to your email';

  @override
  String get forgotEmailHint => 'Email';

  @override
  String get forgotOtpTitle => 'Code verification';

  @override
  String forgotOtpSubtitle(String email) {
    return 'Enter the 6-digit code sent to $email';
  }

  @override
  String get forgotResendCode => 'Resend code';

  @override
  String get forgotNewPasswordTitle => 'New password';

  @override
  String get forgotNewPasswordSubtitle => 'Enter your new password';

  @override
  String get forgotNewPasswordHint => 'New password';

  @override
  String get forgotConfirmPasswordHint => 'Confirm password';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLangSystem => 'System';

  @override
  String get settingsSectionLanguages => 'Languages';

  @override
  String get settingsAppLanguage => 'App language';

  @override
  String get settingsMessageTranslation => 'Message translation';

  @override
  String settingsLangSystemResolved(String language) {
    return 'Follows your phone — currently $language';
  }

  @override
  String get languageScreenHint =>
      'The language of the app. It does not change the language of the messages you receive.';

  @override
  String get languageSectionMessages => 'Messages';

  @override
  String get settingsMedia => 'Media';

  @override
  String get settingsAutoDownload => 'Automatic download';

  @override
  String get settingsAutoDownloadSubtitle =>
      'Download received media inside the app';

  @override
  String get settingsMediaVisibility => 'Save to gallery';

  @override
  String get settingsMediaVisibilitySubtitle =>
      'Received photos and videos show up in the device gallery';

  @override
  String get mediaSaveToGallery => 'Save to gallery';

  @override
  String get mediaSaveToDownloads => 'Save to Downloads';

  @override
  String get mediaSavedToGallery => 'Saved to gallery';

  @override
  String get mediaSavedToDownloads => 'Saved to Downloads';

  @override
  String get mediaAlreadyInGallery => 'Already in gallery';

  @override
  String get mediaAlreadyInDownloads => 'Already in Downloads';

  @override
  String get mediaSaveAgain => 'Save again';

  @override
  String get mediaSaveFailed => 'Could not save this media';

  @override
  String get mediaExpired => 'Media expired';

  @override
  String mediaExpiredAskSender(String name) {
    return 'Ask $name to send it again';
  }

  @override
  String get mediaExpiredResendYourself =>
      'Send it again from your gallery if you still have it';

  @override
  String get settingsRingtone => 'Call ringtone';

  @override
  String get ringtoneScreenTitle => 'Call ringtone';

  @override
  String get ringtoneSectionSystem => 'Default ringtone';

  @override
  String get ringtoneSectionApp => 'Preinstalled ringtones';

  @override
  String get ringtoneSectionCustom => 'Imported ringtones';

  @override
  String get ringtoneSystemDefaultLabel => 'Device default ringtone';

  @override
  String get ringtoneAddCustomAction => 'Add a ringtone';

  @override
  String get ringtoneAddCustomHint => 'Audio files (MP3, WAV, M4A…), 5 MB max';

  @override
  String get ringtoneLimitReached => 'Maximum number of ringtones reached (10)';

  @override
  String get ringtoneCustomEmpty => 'No imported ringtones yet';

  @override
  String get ringtoneDeleteConfirmTitle => 'Delete this ringtone?';

  @override
  String get ringtoneDeleteConfirmMessage => 'This action cannot be undone.';

  @override
  String get ringtoneImportSuccess => 'Ringtone added and selected';

  @override
  String get ringtoneImportError => 'Couldn\'t import this file';

  @override
  String get ringtonePreviewError => 'Couldn\'t play this ringtone';

  @override
  String get ringtoneSyncInfoTitle => 'Syncing across devices';

  @override
  String get ringtoneSyncInfoBody =>
      'This ringtone is stored on this device only: the audio file is never uploaded to our servers.\n\nTo hear it on your other devices, import the same audio file there too. Alanya recognises a file by its content, not by its name: a different file with the same name won\'t be recognised.\n\nIn the meantime your other devices play their usual sound — your choice is kept, and the ringtone comes back as soon as the file is imported there.';

  @override
  String get ringtoneSyncInfoTooltip => 'Use this sound on my other devices';

  @override
  String get listRingtoneSoundMissing => 'file missing on this device';

  @override
  String get listRingtoneSyncedNote =>
      'This choice follows your account and applies to all your devices. An imported ringtone must be present on a device to be played there.';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacySubtitle => 'Blocked contacts';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSend => 'Send';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonError => 'Error';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonOk => 'OK';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonDecline => 'Decline';

  @override
  String get commonCallBack => 'Call back';

  @override
  String get callMissed => 'Missed call';

  @override
  String get callIncoming => 'INCOMING CALL';

  @override
  String membersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String groupMembersCount(int count) {
    return 'Group • $count members';
  }

  @override
  String pinnedMessagesCount(int count) {
    return 'Pinned messages ($count)';
  }

  @override
  String selectCount(int count) {
    return 'Select ($count)';
  }

  @override
  String forwardAlbumCount(int count) {
    return 'Forward album ($count)';
  }

  @override
  String downloadAlbumCount(int count) {
    return 'Download album ($count)';
  }

  @override
  String get downloadAlbumHint => 'Save all media to your device';

  @override
  String downloadAlbumProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String get albumMediaAlreadyDownloaded =>
      'All album media are already downloaded';

  @override
  String maxMessages(int count) {
    return 'Maximum $count messages';
  }

  @override
  String maxVideos(int count) {
    return 'Maximum $count videos.';
  }

  @override
  String albumFirstOnly(int count) {
    return 'Only the first $count will be sent.';
  }

  @override
  String videoTooLarge(String mb) {
    return 'Video skipped ($mb MB). Limit: 50 MB.';
  }

  @override
  String fileTooLarge(String mb) {
    return 'File too large ($mb MB). Limit: 50 MB.';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String durationLabel(String duration) {
    return 'Duration: $duration';
  }

  @override
  String todayAt(String time) {
    return 'Today · $time';
  }

  @override
  String tomorrowAt(String time) {
    return 'Tomorrow · $time';
  }

  @override
  String todayAtTime(String time) {
    return 'Today at $time';
  }

  @override
  String seenAt(String time) {
    return 'Seen at $time';
  }

  @override
  String seenYesterdayAt(String time) {
    return 'Seen yesterday at $time';
  }

  @override
  String seenOnDate(int day, int month) {
    return 'Seen on $day/$month';
  }

  @override
  String seenAtLower(String time) {
    return 'seen at $time';
  }

  @override
  String seenYesterdayAtLower(String time) {
    return 'seen yesterday at $time';
  }

  @override
  String timeAgoDays(int count) {
    return '$count d ago';
  }

  @override
  String timeAgoHours(int count) {
    return '$count h ago';
  }

  @override
  String timeAgoMinutes(int count) {
    return '$count min ago';
  }

  @override
  String pageOf(int page, int total) {
    return 'Page $page / $total';
  }

  @override
  String usedByOwner(String owner) {
    return 'Used · $owner';
  }

  @override
  String maxParticipants(int count) {
    return 'Maximum $count participants';
  }

  @override
  String selectUpToVideo(int count) {
    return 'Select up to $count members for the video call';
  }

  @override
  String selectUpToVoice(int count) {
    return 'Select up to $count members for the voice call';
  }

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String editedAt(String time) {
    return 'Edited at $time';
  }

  @override
  String labelForwarded(String label) {
    return '$label forwarded';
  }

  @override
  String labelForwardedTo(String label, int count) {
    return '$label forwarded to $count chats';
  }

  @override
  String forwardedToRatio(int ok, int total) {
    return 'Forwarded to $ok/$total chats';
  }

  @override
  String callFrom(String name) {
    return 'Call from $name';
  }

  @override
  String organizedBy(String name) {
    return 'Organized by $name';
  }

  @override
  String numberAssigned(String number) {
    return 'Number assigned: $number';
  }

  @override
  String userIdLabel(String id) {
    return 'User $id';
  }

  @override
  String canContactAgain(String name) {
    return '$name will be able to contact you again.';
  }

  @override
  String removePreferredContact(String name) {
    return 'Remove $name from preferred contacts';
  }

  @override
  String videoMaxSelectable(int count) {
    return 'Video: $count max.';
  }

  @override
  String callBackName(String name) {
    return 'Call back $name';
  }

  @override
  String mediaTitleNamed(String name) {
    return '$name — Media';
  }

  @override
  String photosCount(int count) {
    return '📷 $count photos';
  }

  @override
  String videosCount(int count) {
    return '🎥 $count videos';
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
    return '$label · tap to open';
  }

  @override
  String get mediaAccessErrorMakeSureHttps =>
      'Media access error. Make sure HTTPS is enabled or you are on localhost.';

  @override
  String get cannotAccessMicrophoneCameraCheckThat =>
      'Cannot access microphone/camera. Check that the app has permissions.';

  @override
  String get thisActionCannotBeUndoneThe =>
      'This action cannot be undone. The meeting will be deleted for all participants.';

  @override
  String get ifYouReceivedAMeetingLink =>
      'If you received a meeting link, you can click the link instead.';

  @override
  String get microphoneErrorPleaseCheckYourPermissions =>
      'Microphone error. Please check your permissions and audio hardware.';

  @override
  String get permissionDeniedOpenSettingsOrPick =>
      'Permission denied. Open settings or pick a point on the map.';

  @override
  String get statusesFromContactsWhoFavoritedYou =>
      'Statuses from contacts who favorited you will appear here.';

  @override
  String get enableLocationToUseYourPosition =>
      'Enable location to use your position, or move the map.';

  @override
  String get permissionDeniedYouCanStillPick =>
      'Permission denied. You can still pick a point on the map.';

  @override
  String get addContactsToFindThemQuickly =>
      'Add contacts to find them quickly during meetings';

  @override
  String get editingIsOnlyPossibleWithin30 =>
      'Editing is only possible within 30 minutes of sending';

  @override
  String get cameraErrorPleaseCheckYourPermissions =>
      'Camera error. Please check your permissions and camera.';

  @override
  String get saveTheseDetailsYouWillNeed =>
      'Save these details — you will need them to sign in:';

  @override
  String get doYouWantToEndThe =>
      'Do you want to end the meeting for all participants?';

  @override
  String get freeEntryReservedPatternsOrStandard =>
      'Free entry: reserved patterns or standard 8-digit numbers';

  @override
  String get viewOnceMediaVisibleOnlyOnce =>
      'View-once media — visible only once to the recipient';

  @override
  String get youWillNoLongerSeeThis =>
      'You will no longer see this group in your chat list.';

  @override
  String get cannotAccessDevicesCheckPermissions =>
      'Cannot access devices. Check permissions.';

  @override
  String get permissionDeniedPleaseAllowMicrophoneCamera =>
      'Permission denied. Please allow microphone/camera.';

  @override
  String get theyWillNoLongerBeAble =>
      'They will no longer be able to message or call you.';

  @override
  String get n8DigitsAutoGeneratedExcludingReserved =>
      '8 digits (auto-generated, excluding reserved numbers)';

  @override
  String get noMicrophoneCameraDeviceFoundOn =>
      'No microphone/camera device found on your system.';

  @override
  String get gpsUnavailableMoveTheMapTo =>
      'GPS unavailable. Move the map to choose a point.';

  @override
  String get localMessagesInThisChatWill =>
      'Local messages in this chat will be deleted.';

  @override
  String get oneOrMoreMessagesCannotBe =>
      'One or more messages cannot be forwarded';

  @override
  String get mediaAccessErrorCheckHttpsOr =>
      'Media access error. Check HTTPS or localhost.';

  @override
  String get noResultsEnterAFullPattern =>
      'No results — enter a full pattern number ';

  @override
  String get conversationDeletedLocallyServerUnreachable =>
      'Conversation deleted locally (server unreachable)';

  @override
  String get thisMessageCannotBeForwardedRight =>
      'This message cannot be forwarded right now';

  @override
  String get thisAlbumCannotBeForwardedRight =>
      'This album cannot be forwarded right now';

  @override
  String get selectedChatsAreNotArchived => 'Selected chats are not archived';

  @override
  String get enterTheMeetingCodeProvidedBy =>
      'Enter the meeting code provided by the organizer';

  @override
  String get startANewChatWithThe => 'Start a new chat with the + button.';

  @override
  String get thisMediaCannotBeForwardedRight =>
      'This media cannot be forwarded right now';

  @override
  String get reservationLimitedTo3Or4 =>
      'Reservation limited to 3 or 4 digit numbers, ';

  @override
  String get selectedChatsAreAlreadyArchived =>
      'Selected chats are already archived';

  @override
  String get selectedChatsAreAlreadyPinned =>
      'Selected chats are already pinned';

  @override
  String get unableToAddParticipantsTryAgain =>
      'Unable to add participants, try again';

  @override
  String get peopleYouBlockWillAppearHere =>
      'People you block will appear here.';

  @override
  String get unableToInviteParticipantsTryAgain =>
      'Unable to invite participants, try again';

  @override
  String pausedTapToReturn(String type) {
    return 'Paused · $type · Tap to return';
  }

  @override
  String get sayHelloToStartTheConversation =>
      'Say hello to start the conversation!';

  @override
  String get noFreeNumberFoundInThe => 'No free number found in the admin list';

  @override
  String get unableToDeleteTheMeetingTry =>
      'Unable to delete the meeting, try again';

  @override
  String get yourPastAndReceivedCallsWill =>
      'Your past and received calls will appear here.';

  @override
  String get microphoneCameraPermissionDenied =>
      'Microphone/camera permission denied';

  @override
  String get unableToRemoveThisContactTry =>
      'Unable to remove this contact, try again';

  @override
  String get newChatUnavailableOffline => 'New chat unavailable offline';

  @override
  String get messageNotFoundInThisConversation =>
      'Message not found in this conversation';

  @override
  String get numberMustContainOnlyDigits => 'Number must contain only digits';

  @override
  String get invalidNumber34Or8 => 'Invalid number: 3, 4 or 8 digits required';

  @override
  String get errorCreatingTheConversation => 'Error creating the conversation';

  @override
  String get unableToLeaveTheGroupTry => 'Unable to leave the group, try again';

  @override
  String get unableToPostTheStatusTry => 'Unable to post the status, try again';

  @override
  String get unableToAddThisContactTry =>
      'Unable to add this contact, try again';

  @override
  String get canBeOpenedOnlyOnceThen =>
      'Can be opened only once, then inaccessible';

  @override
  String get unableToLoadBlockedContacts => 'Unable to load blocked contacts';

  @override
  String get enterANumberOrChooseA => 'Enter a number or choose a contact';

  @override
  String get unableToCreateTheMeetingTry =>
      'Unable to create the meeting, try again';

  @override
  String get unableToCreateTheGroupTry =>
      'Unable to create the group, try again';

  @override
  String get searchByNameUsernameOrPhone =>
      'Search by name, username or Alanya ID…';

  @override
  String get assignAReservedNumberOptional =>
      'Assign a reserved number (optional)';

  @override
  String get ajoutezDesContactsPourLesRetrouver => 'Add contacts to find them';

  @override
  String get unableToStartTheCallTry => 'Unable to start the call, try again';

  @override
  String get cannotInviteABlockedContact => 'Cannot invite a blocked contact';

  @override
  String get manageUsersAndMonitoring => 'Manage users and monitoring';

  @override
  String get fromGalleryOrCamera => 'From gallery or camera';

  @override
  String get passwordResetSuccessfully => 'Password reset successfully';

  @override
  String get reservedPatternDirectAssignment =>
      'Reserved pattern (direct assignment)';

  @override
  String get unableToForwardTheMessages => 'Unable to forward the messages';

  @override
  String get longPressToExitSelection => 'Long-press to exit selection';

  @override
  String get unableToDownloadTheFile => 'Unable to download the file';

  @override
  String get yourProfilePhotoWillBeRemoved =>
      'Your profile photo will be removed.';

  @override
  String get unableToForwardTheMessage => 'Unable to forward the message';

  @override
  String get thisNumberCannotBeAssigned => 'This number cannot be assigned';

  @override
  String get unableToUpdateTheCountry => 'Unable to update the country';

  @override
  String get errorStartingTheCall => 'Error starting the call';

  @override
  String get unableToDownloadTheMedia => 'Unable to download the media';

  @override
  String get mediaNoLongerAvailable => 'This media is no longer available';

  @override
  String get unableToUnblockThisContact => 'Unable to unblock this contact';

  @override
  String get unableToLoadNumbers => 'Unable to load numbers';

  @override
  String get searchByNameUsernameOr => 'Search by name, username or ...';

  @override
  String get unableToCreateTheConversation =>
      'Unable to create the conversation';

  @override
  String get noAudioVideoDeviceFound => 'No audio/video device found';

  @override
  String get unableToOpenTheConversation => 'Unable to open the conversation';

  @override
  String get connectingTapToReturn => 'Connecting… · Tap to return';

  @override
  String get unableToVerifyTheContact => 'Unable to verify the contact';

  @override
  String get meetingInvitationsAndReminders =>
      'Meeting invitations and reminders';

  @override
  String get errorGroupIdNotFound => 'Error: group ID not found';

  @override
  String get profileUnavailableTryAgain => 'Profile unavailable, try again';

  @override
  String get cannotCallThisContact => 'Cannot call this contact';

  @override
  String get unableToForwardTheAlbum => 'Unable to forward the album';

  @override
  String get thisGroupIsNoLongerAccessible =>
      'This group is no longer accessible.';

  @override
  String get youHaveBlockedThisUser => 'You have blocked this user';

  @override
  String get unableToDisplayTheMessage => 'Unable to display the message';

  @override
  String get meetingInLessThan10Minutes => 'Meeting in less than 10 minutes';

  @override
  String get addACaptionOptional => 'Add a caption (optional)';

  @override
  String get rapidementLorsDeVosReunions => 'quickly during your meetings';

  @override
  String get alreadyInYourPreferredContacts =>
      'Already in your preferred contacts';

  @override
  String get dateMustBeInTheFuture => 'Date must be in the future';

  @override
  String get longPressFailedTryAgain => 'Long-press failed, try again';

  @override
  String get eG112233441234OrLabel => 'E.g. 11223344, 1234, or label…';

  @override
  String get theOtherPartyIsBusy => 'The other party is busy.';

  @override
  String get viewAndUnblockContacts => 'View and unblock contacts';

  @override
  String get thisActionCannotBeUndone => 'This action cannot be undone.';

  @override
  String get mediaIsNotReadyYet => 'Media is not ready yet';

  @override
  String get thisMediaIsNoLongerAvailable =>
      'This media is no longer available';

  @override
  String get yourSignInCredentials => 'Your sign-in credentials';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get microphonePermissionDenied => 'Microphone permission denied';

  @override
  String get noConversationToDelete => 'No conversation to delete';

  @override
  String get phoneAlanyaPhone => 'Alanya ID';

  @override
  String get noOtherMembersToCall => 'No other members to call';

  @override
  String get actionFailedPleaseTryAgain => 'Action failed, please try again';

  @override
  String get failedToAddParticipants => 'Failed to add participants';

  @override
  String get noArchivedConversations => 'No archived conversations';

  @override
  String get noConnectionsRecorded => 'No connections recorded';

  @override
  String get countryListUnavailable => 'Country list unavailable';

  @override
  String get profilePhotoUpdated => 'Profile photo updated';

  @override
  String get searchByNameUsername => 'Search by name, username…';

  @override
  String get noConversationToClear => 'No conversation to clear';

  @override
  String get historyWillBeDeleted => 'History will be deleted.';

  @override
  String get addAtLeastOneMember => 'Add at least one member';

  @override
  String get searchChats => 'Search chats…';

  @override
  String get thisMediaHasAlreadyBeenOpened =>
      'This media has already been opened';

  @override
  String get addAPreferredContact => 'Add a preferred contact';

  @override
  String get enterANumberToAdd => 'Enter a number to add';

  @override
  String get noMeetingsToday => 'No meetings today';

  @override
  String get aCallIsAlreadyInProgress => 'A call is already in progress';

  @override
  String get failedToCreateGroup => 'Failed to create group';

  @override
  String get turnOffSpeaker => 'Turn off speaker';

  @override
  String get noParticipantsConnected => 'No participants connected';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get deleteConversation => 'Delete conversation?';

  @override
  String get manualNumberEntry => 'Manual number entry';

  @override
  String get thisMessageWasDeleted => 'This message was deleted';

  @override
  String get deleteUser => 'Delete user?';

  @override
  String get mediaAccessError => 'Media access error';

  @override
  String get addADescription => 'Add a description…';

  @override
  String get microphonePermissionDenied2 => 'Microphone permission denied';

  @override
  String get failedToLeaveGroup => 'Failed to leave group';

  @override
  String get unableToOpenMaps => 'Unable to open Maps';

  @override
  String get conversationNotFound => 'Conversation not found';

  @override
  String get addParticipants => 'Add participants';

  @override
  String get tapToDownload => 'Tap to download';

  @override
  String pdfPageCount(int count) {
    return '$count pages';
  }

  @override
  String get noUsersFound => 'No users found';

  @override
  String get enterTheGroupName => 'Enter the group name';

  @override
  String get requiredExceptTier3 => 'Required except tier 3';

  @override
  String get deleteConversation2 => 'Delete conversation';

  @override
  String get userNotFound => 'User not found';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get invalidUploadResponse => 'Invalid upload response';

  @override
  String get enableLocation => 'Enable location';

  @override
  String get noUpcomingMeetings => 'No upcoming meetings';

  @override
  String get exampleAbcDefgHij => 'Example: abc-defg-hij';

  @override
  String get unblockThisContact => 'Unblock this contact?';

  @override
  String get clearMessages => 'Clear messages?';

  @override
  String get sendThisLocation => 'Send this location';

  @override
  String get startVideoCall => 'Start video call';

  @override
  String get forwardUnavailable => 'Forward unavailable';

  @override
  String get startVoiceCall => 'Start voice call';

  @override
  String get noPastMeetings => 'No past meetings';

  @override
  String get scheduleAMeeting => 'Schedule a meeting';

  @override
  String get n34DigitsOrXxyyzztt => '3 / 4 digits or XXYYZZTT';

  @override
  String get groupCallInProgress => 'Group call in progress';

  @override
  String get deleteThisStatus => 'Delete this status?';

  @override
  String get mediaLinksAndDocs => 'Media, links and docs';

  @override
  String get searchForACountry => 'Search for a country...';

  @override
  String get voiceMessageEnded => 'Voice message ended';

  @override
  String get musicEnded => 'Music ended';

  @override
  String get noPreferredContacts => 'No preferred contacts';

  @override
  String get donTHaveAnAccount => 'Don\'t have an account?';

  @override
  String get joinAMeeting => 'Join a meeting';

  @override
  String get meetingDetails => 'Meeting details';

  @override
  String get noBlockedContacts => 'No blocked contacts';

  @override
  String get blockThisContact => 'Block this contact?';

  @override
  String get sendALocation => 'Send a location';

  @override
  String get createUser => 'Create user';

  @override
  String get addACaption => 'Add a caption…';

  @override
  String get alanyaNumberRequired => 'Alanya ID required';

  @override
  String get selectACountry => 'Select a country';

  @override
  String get noReservedNumbers => 'No reserved numbers';

  @override
  String get clearMessages2 => 'Clear messages';

  @override
  String get removeFromContacts => 'Remove from contacts';

  @override
  String get messageToForward => 'Message to forward';

  @override
  String get deletePhoto => 'Delete photo?';

  @override
  String get unblockContact => 'Unblock contact';

  @override
  String get loadingCountries => 'Loading countries…';

  @override
  String get newChat => 'New chat';

  @override
  String get typeYourStatus => 'Type your status…';

  @override
  String get editMessage => 'Edit message';

  @override
  String get noRecentStatus => 'No recent status';

  @override
  String get closeSearch => 'Close search';

  @override
  String get sendLocation => 'Send location';

  @override
  String get openSettings => 'Open settings';

  @override
  String get statusReply => 'Status reply';

  @override
  String get statusNoLongerAvailable => 'This status is no longer available';

  @override
  String get socketNotConnected => 'Socket not connected';

  @override
  String get deleteForEveryone => 'Delete for everyone';

  @override
  String get meetingTitle => 'Meeting title';

  @override
  String get connecting => 'Connecting…';

  @override
  String get callReconnecting => 'Reconnecting…';

  @override
  String get freeUnassigned => 'Free · unassigned';

  @override
  String get numberUnavailable => 'Number unavailable';

  @override
  String get meetingNotFound => 'Meeting not found';

  @override
  String get recentConnections => 'Recent connections';

  @override
  String get replyToStatus => 'Reply to status…';

  @override
  String get noSharedMedia => 'No shared media';

  @override
  String get leaveGroup => 'Leave group?';

  @override
  String get typing => 'typing…';

  @override
  String get cancelMeeting => 'Cancel meeting';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get blockContact => 'Block contact';

  @override
  String get groupNotFound => 'Group not found';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get groupVideoCall => 'Group video call';

  @override
  String get noRecentCalls => 'No recent calls';

  @override
  String get audioUnavailable => 'Audio unavailable';

  @override
  String get typing2 => 'Typing…';

  @override
  String get numberOrLabel => 'Number or label…';

  @override
  String get albumToForward => 'Album to forward';

  @override
  String get mediaUnavailable => 'Media unavailable';

  @override
  String get messageDetails => 'Message details';

  @override
  String get endForEveryone => 'End for everyone';

  @override
  String get writeAMessage => 'Write a message…';

  @override
  String get changeNumber => 'Change number';

  @override
  String get countryUnavailable => 'Country unavailable';

  @override
  String get numberAvailable => 'Number available';

  @override
  String get addAVideo => 'Add a video';

  @override
  String get noCountryFound => 'No country found';

  @override
  String get addAPhoto => 'Add a photo';

  @override
  String get cameraDisabled => 'Camera disabled';

  @override
  String get searchInConversationHint => 'Search this chat';

  @override
  String get searchNoResult => 'No messages found';

  @override
  String searchResultCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String get searchPrevious => 'Previous result';

  @override
  String get searchNext => 'Next result';

  @override
  String get searchExit => 'Close search';

  @override
  String get takeAPhoto => 'Take a photo';

  @override
  String get enableCamera => 'Enable camera';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get noChats => 'No chats';

  @override
  String get callFailed => 'Call failed.';

  @override
  String get retrySending => 'Retry sending';

  @override
  String get leaveGroup2 => 'Leave group';

  @override
  String get preferredContacts => 'Preferred contacts';

  @override
  String get turnOffCamera => 'Turn off camera';

  @override
  String get messagesCleared => 'Messages cleared';

  @override
  String get reservedNumbers => 'Reserved numbers';

  @override
  String get meetingEnded => 'Meeting ended';

  @override
  String get meetingBlockedByCall =>
      'A call is in progress: can\'t join the meeting.';

  @override
  String get meetingJoinExpired => 'This meeting has expired.';

  @override
  String get meetingJoinNotInvited => 'Meeting not found.';

  @override
  String get meetingParticipantJoined => 'Joined';

  @override
  String get meetingParticipantPending => 'Awaiting';

  @override
  String get meetingExpired => 'Expired';

  @override
  String get newMeeting => 'New meeting';

  @override
  String get alanyaPhone => 'Alanya ID';

  @override
  String get deletedMessage => 'Deleted message';

  @override
  String get verifyCode => 'Verify code';

  @override
  String get notDeliveredYet => 'Not delivered yet';

  @override
  String get someoneIsTyping => 'Someone is typing…';

  @override
  String nameIsTyping(String name) {
    return '$name is typing…';
  }

  @override
  String get lastWeek => 'Last week';

  @override
  String get otherResults => 'Other results';

  @override
  String get changeMedia => 'Change media';

  @override
  String get contactUnblocked => 'Contact unblocked';

  @override
  String get downloading => 'Downloading…';

  @override
  String get minimizeCall => 'Minimize call';

  @override
  String get createAGroup => 'Create a group';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get replySent => 'Reply sent';

  @override
  String get sessionExpired => 'Session expired';

  @override
  String get callInProgress => 'Call in progress…';

  @override
  String get createGroup => 'Create group';

  @override
  String get newMessage => 'New message';

  @override
  String get groupInfo => 'Group info';

  @override
  String get placeACall => 'Place a call';

  @override
  String get newContact => 'New contact';

  @override
  String get noAnswer => 'No answer.';

  @override
  String get backgroundColor => 'Background color';

  @override
  String get photoDeleted => 'Photo deleted';

  @override
  String get serverError => 'Server error';

  @override
  String get noDocuments => 'No documents';

  @override
  String get reservedNumber => 'Reserved number';

  @override
  String get password => 'Password *';

  @override
  String get notNow => 'Not now';

  @override
  String get missedCalls => 'Missed calls';

  @override
  String get newStatus => 'New status';

  @override
  String get newGroup => 'New group';

  @override
  String get noResults => 'No results';

  @override
  String get labelRequired => 'Label required';

  @override
  String get unlike => 'Unlike';

  @override
  String get messages7d => 'Messages (7d)';

  @override
  String get noContacts => 'No contacts';

  @override
  String get callEnded => 'Call ended';

  @override
  String get joinedOn => 'Joined on';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get cameraOn => 'Camera on';

  @override
  String get cameraOff => 'Camera off';

  @override
  String get verifying => 'Verifying…';

  @override
  String get reRecord => 'Re-record';

  @override
  String get videoComingSoon => 'Video coming soon';

  @override
  String get dateAndTime => 'Date and time';

  @override
  String get noMessages => 'No messages';

  @override
  String get lastCall => 'Last call';

  @override
  String get videoMeeting => 'Video meeting';

  @override
  String get groupName => 'Group name';

  @override
  String get callComingSoon => 'Call coming soon';

  @override
  String get noAnswer2 => 'No answer';

  @override
  String get organizer => 'Organizer';

  @override
  String get noImages => 'No images';

  @override
  String get emptyMessage => 'Empty message';

  @override
  String get rewind10S => 'Rewind 10 s';

  @override
  String get pdfDocument => 'PDF document';

  @override
  String get speaker => 'Speaker';

  @override
  String get audioOutputEarpiece => 'Earpiece';

  @override
  String get audioOutputWired => 'Wired headset';

  @override
  String get audioOutputBluetooth => 'Bluetooth';

  @override
  String get changeAudioOutput => 'Change audio output';

  @override
  String get newCall => 'New call';

  @override
  String get lastView => 'Last view';

  @override
  String get receivedCalls => 'Received calls';

  @override
  String get participants => 'Participants';

  @override
  String get alreadyUsed => 'Already used';

  @override
  String get select => 'Select';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get statuses7d => 'Statuses (7d)';

  @override
  String get forward10S => 'Forward 10 s';

  @override
  String get openWith => 'Open with…';

  @override
  String get groupCall => 'Group call';

  @override
  String get noVideos => 'No videos';

  @override
  String get chats => 'Chats';

  @override
  String get creating => 'Creating...';

  @override
  String get videoCall => 'Video call';

  @override
  String get unpin => 'Unpin';

  @override
  String get micMuted => 'Mic muted';

  @override
  String get outgoingCalls => 'Outgoing calls';

  @override
  String get micOn => 'Mic on';

  @override
  String get demote => 'Demote';

  @override
  String get audioCall => 'Audio call';

  @override
  String get description => 'Description';

  @override
  String get unarchive => 'Unarchive';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get search => 'Search…';

  @override
  String get signOut => 'Sign out';

  @override
  String get calls7d => 'Calls (7d)';

  @override
  String get justNow => 'just now';

  @override
  String get notSet => 'Not set';

  @override
  String get myStatus => 'My status';

  @override
  String get noViews => 'No views';

  @override
  String get connecting2 => 'Connecting…';

  @override
  String get forward => 'Forward';

  @override
  String get noLinks => 'No links';

  @override
  String get emptyAlbum => 'Empty album';

  @override
  String get message => 'Message...';

  @override
  String get offline => 'Offline';

  @override
  String get viewOnce => 'View once';

  @override
  String get refresh => 'Refresh';

  @override
  String get location => '📍 Location';

  @override
  String get later => 'Later';

  @override
  String get warning => 'Warning';

  @override
  String get seeAll => 'See all';

  @override
  String get forwarded => 'Forwarded';

  @override
  String get edited => '· edited';

  @override
  String get unblock => 'Unblock';

  @override
  String get file => '📎 File';

  @override
  String get results => 'Results';

  @override
  String get join => 'Join';

  @override
  String get allow => 'Allow';

  @override
  String get recently => 'Recently';

  @override
  String get documents => 'Documents';

  @override
  String get phone => 'Phone';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get contact => '👤 Contact';

  @override
  String get gotIt => 'Got it';

  @override
  String get banReason => 'Ban reason';

  @override
  String get used => 'Used';

  @override
  String get sentAt => 'Sent at';

  @override
  String get pin => 'Pin';

  @override
  String get unpin2 => 'Unpin';

  @override
  String get username => 'Username *';

  @override
  String get reply => 'Reply';

  @override
  String get message2 => 'Message…';

  @override
  String get unban => 'Unban';

  @override
  String get online => 'Online';

  @override
  String get edit => 'Edit';

  @override
  String get inProgress => 'In progress';

  @override
  String get ended => 'Ended';

  @override
  String get location2 => 'Location';

  @override
  String get alreadyViewed => 'Already viewed';

  @override
  String get archived => 'Archived';

  @override
  String get files => 'Files';

  @override
  String get share => 'Share';

  @override
  String get shareToConversation => 'Send via Alanya';

  @override
  String get sharedContentSent => 'Content sent';

  @override
  String sharedContentSentTo(int count) {
    return 'Content sent to $count chats';
  }

  @override
  String get unableToShareTheContent => 'Unable to send the content';

  @override
  String get unableToShareTheMessage => 'Unable to share the message';

  @override
  String get thisMessageCannotBeSharedRight =>
      'This message cannot be shared right now';

  @override
  String get document => 'Document';

  @override
  String get activity => 'Activity';

  @override
  String get album => '📷 Album';

  @override
  String get answered => 'Answered';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get generate => 'Generate';

  @override
  String get audio => '🎵 Audio';

  @override
  String get photo => '📷 Photo';

  @override
  String get reply2 => 'Reply';

  @override
  String get deliveredAt => 'Delivered at';

  @override
  String get gallery => 'Gallery';

  @override
  String get meeting => 'Meeting';

  @override
  String get next => 'Next';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get file2 => 'File';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get recent => 'Recent';

  @override
  String get label => 'Label';

  @override
  String get invite => 'Invite';

  @override
  String get ended2 => 'Ended';

  @override
  String get video => '🎥 Video';

  @override
  String get contact2 => 'Contact';

  @override
  String get leave => 'Leave';

  @override
  String get favorites => 'Favorites';

  @override
  String get gotIt2 => 'Got it';

  @override
  String get edited2 => 'Edited';

  @override
  String get inactive => 'Inactive';

  @override
  String get add => 'Add';

  @override
  String get member => 'Member';

  @override
  String get success => 'Success';

  @override
  String get ban => 'Ban';

  @override
  String get past => 'Past';

  @override
  String get videos => 'Videos';

  @override
  String get copy => 'Copy';

  @override
  String get camera => 'Camera';

  @override
  String get photos => 'Photos';

  @override
  String get sending => 'Sending…';

  @override
  String get blocked => 'Blocked';

  @override
  String get added => 'Added';

  @override
  String get images => 'Images';

  @override
  String get number => 'Number';

  @override
  String get back => 'Back';

  @override
  String get missed => 'Missed';

  @override
  String voicemailPeerUnavailable(String name) {
    return '$name is unavailable';
  }

  @override
  String get voicemailLeaveMessage =>
      'Leave a voice message — it will land in your conversation.';

  @override
  String get voicemailRecord => 'Record';

  @override
  String get voicemailSend => 'Send';

  @override
  String get voicemailDiscard => 'Discard';

  @override
  String get voicemailNotNow => 'Not now';

  @override
  String get voicemailSent => 'Message sent';

  @override
  String get voicemailBannerActive => 'Voicemail on';

  @override
  String voicemailBannerUntil(String time) {
    return 'Voicemail on until $time';
  }

  @override
  String get voicemailBannerDisable => 'Turn off';

  @override
  String get voicemailDisabled => 'Voicemail turned off';

  @override
  String get voicemailScheduleTitle => 'Voicemail';

  @override
  String get voicemailEnabled => 'Scheduled voicemail';

  @override
  String get voicemailEnabledSubtitle =>
      'During these hours your phone stays silent and callers can leave a message';

  @override
  String voicemailTimezoneHint(String timezone) {
    return 'Hours evaluated in $timezone';
  }

  @override
  String get voicemailBypassTitle => 'Can still reach me';

  @override
  String get voicemailBypassTile => 'Allowed list';

  @override
  String get voicemailBypassNobody => 'Nobody';

  @override
  String get voicemailBypassHint =>
      'Members of this list will ring your phone despite the voicemail.';

  @override
  String voicemailPeerNoAnswer(String name) {
    return '$name didn\'t answer';
  }

  @override
  String get voicemailGreetingPause => 'Stop the greeting';

  @override
  String get voicemailGreetingReplay => 'Play the greeting again';

  @override
  String get voicemailGreetingSection => 'My greeting';

  @override
  String get voicemailGreetingTitle => 'Record your greeting';

  @override
  String voicemailGreetingHint(int max) {
    return 'Callers who reach your voicemail will hear it. $max seconds maximum.';
  }

  @override
  String get voicemailGreetingStop => 'Finish';

  @override
  String get voicemailGreetingSaved => 'Greeting saved';

  @override
  String get voicemailGreetingNone =>
      'No greeting — a text will be shown instead';

  @override
  String voicemailGreetingSet(int seconds) {
    return '$seconds seconds recorded';
  }

  @override
  String get voicemailGreetingListen => 'Play the greeting';

  @override
  String get voicemailGreetingDelete => 'Delete greeting';

  @override
  String get voicemailGreetingDeleted => 'Greeting deleted';

  @override
  String get voicemailWhenNoAnswer => 'When I don\'t answer';

  @override
  String get voicemailAfterDelay => 'Voicemail after 30 seconds';

  @override
  String get voicemailAfterDelaySubtitle =>
      'Your phone rings. If you don\'t pick up, decline, or your line is busy, the caller can leave a message.';

  @override
  String get voicemailWhenUnavailable => 'When I\'m unavailable';

  @override
  String get voicemailSlotsEnabled => 'Scheduled periods';

  @override
  String get voicemailSlotsEnabledSubtitle =>
      'During these periods your phone doesn\'t ring at all';

  @override
  String get voicemailSlotNone => 'No period';

  @override
  String get voicemailSlotAllDay => 'All day';

  @override
  String voicemailSlotOvernight(String range) {
    return '$range (into the next day)';
  }

  @override
  String voicemailSlotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count scheduled periods',
      one: '1 scheduled period',
    );
    return '$_temp0';
  }

  @override
  String get voicemailQuickHint =>
      'Pick when it ends. Every option has an end — a voicemail you forget about is worse than none.';

  @override
  String get voicemailQuickSchedule => 'Schedule recurring hours';

  @override
  String get voicemailForOneHour => 'For 1 hour';

  @override
  String get voicemailForFourHours => 'For 4 hours';

  @override
  String get voicemailUntilMorning => 'Until tomorrow morning';

  @override
  String get voicemailUntilCustom => 'Until a specific date';

  @override
  String get voicemailDeadlinePast => 'That time has already passed';

  @override
  String get voicemailCallStatus => 'Voicemail';

  @override
  String get rejected => 'Rejected';

  @override
  String get links => 'Links';

  @override
  String get linkNoun => 'Link';

  @override
  String get timeZoneLabel => 'Time zone';

  @override
  String get email => 'Email';

  @override
  String get create => 'Create';

  @override
  String get name => 'Name *';

  @override
  String get title => 'Title';

  @override
  String get admin => 'Admin';

  @override
  String get audio2 => 'Audio';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get playbackSpeedVoiceLabel => 'Voice messages';

  @override
  String get playbackSpeedVideoLabel => 'Videos';

  @override
  String get playbackSpeedMusicLabel => 'Music';

  @override
  String get music => 'Music';

  @override
  String musicPreview(String name) {
    return '🎵 $name';
  }

  @override
  String get active => 'Active';

  @override
  String get duration => 'Duration';

  @override
  String get failure => 'Failure';

  @override
  String get photo2 => 'Photo';

  @override
  String get copied => 'Copied';

  @override
  String get video2 => 'Video';

  @override
  String get theme => 'Theme';

  @override
  String get all => 'All';

  @override
  String get role => 'Role';

  @override
  String get mute => 'Mute';

  @override
  String get readAt => 'Read at';

  @override
  String get more => 'More';

  @override
  String get country => 'Country';

  @override
  String get name2 => 'Name';

  @override
  String get continueLabel => 'Continue';

  @override
  String get showLabel => 'Show';

  @override
  String get hideLabel => 'Hide';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String participantsAdded(int count) {
    return '$count participant(s) added';
  }

  @override
  String participantsInvited(int count) {
    return '$count participant(s) invited';
  }

  @override
  String get accepted => 'Accepted';

  @override
  String get startAction => 'Start';

  @override
  String get likeAction => 'Like';

  @override
  String get incomingCallsChannel => 'Incoming calls';

  @override
  String get ongoingCallsChannel => 'Ongoing calls';

  @override
  String get viewsTitle => 'Views';

  @override
  String get keypadTitle => 'Keypad';

  @override
  String get clearAction => 'Clear';

  @override
  String get scheduleAction => 'Schedule';

  @override
  String get archiveAction => 'Archive';

  @override
  String get markAsRead => 'Mark as read';

  @override
  String get infoAction => 'Info';

  @override
  String get reportAction => 'Report';

  @override
  String get reportMessageTitle => 'Report this message';

  @override
  String get reportUserTitle => 'Report this account';

  @override
  String get reportSubtitle =>
      'Your report goes to the ALANYA team. The person concerned is not told.';

  @override
  String get reportReasonHarassment => 'Harassment or bullying';

  @override
  String get reportReasonHate => 'Hate speech';

  @override
  String get reportReasonViolence => 'Violence or threats';

  @override
  String get reportReasonSexual => 'Sexual content';

  @override
  String get reportReasonScam => 'Scam or fraud';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonImpersonation => 'Impersonation';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get reportNoteHint => 'Details (optional)';

  @override
  String get reportSubmit => 'Send report';

  @override
  String get reportSent => 'Report sent. Thank you.';

  @override
  String get reportFailed => 'Could not send. Try again.';

  @override
  String get cannotPlaceCallCheckInternet =>
      'Unable to place a call, check your internet connection and try again.';

  @override
  String get cannotPlaceCallServerFailed =>
      'Unable to place a call. Connection to the server failed. Please try again.';

  @override
  String get connectionRequired => 'Connection required';

  @override
  String get callImpossible => 'Call not possible.';

  @override
  String get errorAcceptingCall => 'Error accepting the call';

  @override
  String get userNotConnected => 'User not connected';

  @override
  String get mediaUnavailableForTransfer => 'Media unavailable for forwarding';

  @override
  String get invalidPositionForTransfer => 'Invalid location for forwarding';

  @override
  String get invalidContactForTransfer => 'Invalid contact for forwarding';

  @override
  String get photoViewOnce => '📷 Photo · View once';

  @override
  String get videoViewOnce => '🎥 Video · View once';

  @override
  String get videoCallPreview => '📹 Video call';

  @override
  String get voiceCallPreview => '📞 Voice call';

  @override
  String get deletePhotoAction => 'Delete photo';

  @override
  String get unavailableOffline => 'Unavailable offline';

  @override
  String get noParticipantsYet => 'No participants yet';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get removeParticipantToAddAnother =>
      'Remove a participant to add another.';

  @override
  String get noContactsYet => 'No contacts yet';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get paused => 'Paused';

  @override
  String get recordOrImportAudio =>
      'Record a voice note or import an audio file';

  @override
  String get tapToAddYourStatus => 'Tap to add your status';

  @override
  String get shareAContact => 'Share a contact';

  @override
  String get searchAContact => 'Search for a contact';

  @override
  String get unmuteMic => 'Unmute mic';

  @override
  String get muteMic => 'Mute mic';

  @override
  String get turnOnSpeaker => 'Turn on speaker';

  @override
  String get notAuthenticated => 'Not authenticated';

  @override
  String get networkTimeout => 'Network timeout';

  @override
  String get networkError =>
      'Connection failed. Check your network and try again.';

  @override
  String get noRefreshToken => 'No refresh token';

  @override
  String get refreshFailed => 'Refresh failed';

  @override
  String addedToPreferredContacts(String name) {
    return '$name added to preferred contacts';
  }

  @override
  String get approximateGpsSlow => 'Approximate location (slow GPS).';

  @override
  String get notYetRead => 'Not read yet';

  @override
  String get sentOnTapSend => 'Tapped send';

  @override
  String maxPhotos(int count) {
    return 'Maximum $count photos.';
  }

  @override
  String maxFiles(int count) {
    return 'Maximum $count files.';
  }

  @override
  String filesSkippedTooLarge(int count) {
    return '$count file(s) skipped: 50 MB limit.';
  }

  @override
  String maxMedias(int count) {
    return 'Maximum $count media.';
  }

  @override
  String get addMore => 'Add';

  @override
  String get removeMedia => 'Remove';

  @override
  String get voiceViewOnce => 'Voice · view once';

  @override
  String get heCanContactYouAgain => 'They will be able to contact you again.';

  @override
  String unableToLoadNamed(String name) {
    return 'Unable to load $name';
  }

  @override
  String get contactNotFound => 'Contact not found';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get nowLabel => 'Now';

  @override
  String get positionUnavailable => 'Location unavailable';

  @override
  String get contactUnavailable => 'Contact unavailable';

  @override
  String tapToViewKind(String kind) {
    return '$kind · Tap to view';
  }

  @override
  String kindViewOnce(String kind) {
    return '$kind · View once';
  }

  @override
  String get viewOnceOpened => 'Opened';

  @override
  String viewOnceDownloadKind(String kind) {
    return '$kind · Download';
  }

  @override
  String get viewOnceDownloading => 'Downloading…';

  @override
  String get viewOnceRetry => 'Failed — Retry';

  @override
  String get recordingEllipsis => 'Recording…';

  @override
  String get unread => 'Unread';

  @override
  String get addAContact => 'Add a contact';

  @override
  String meetingNamed(String when) {
    return 'Meeting $when';
  }

  @override
  String get dataUnavailable => 'data unavailable';

  @override
  String get sendCode => 'Send code';

  @override
  String get unableToLoadCountryList => 'Unable to load the country list';

  @override
  String maxAudioParticipantsHint(int count) {
    return 'Maximum $count participants (audio call). ';
  }

  @override
  String membersOnlyCount(int count) {
    return '$count members';
  }

  @override
  String sendWithCount(int count) {
    return 'Send ($count)';
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
    return 'Delivered at $time';
  }

  @override
  String readAtTime(String time) {
    return 'Read at $time';
  }

  @override
  String durationTapToReturn(String duration) {
    return '$duration · Tap to return';
  }

  @override
  String sessionBannerTapToReturn(String duration, String type) {
    return '$duration · $type · Tap to return';
  }

  @override
  String get usedLabel => 'Used';

  @override
  String limitReachedParticipants(int total, String media) {
    return 'Maximum $total participants in $media (including you)';
  }

  @override
  String get mediaLabelVideo => 'video';

  @override
  String get mediaLabelAudio => 'audio';

  @override
  String activeStatusesTapToView(int count) {
    return '$count active status(es) — tap to view';
  }

  @override
  String viewsCountLabel(int count) {
    return '$count view(s)';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String selectedFeminineCount(int count) {
    return '$count selected';
  }

  @override
  String selectionRatio(int count, int max) {
    return '$count/$max selected';
  }

  @override
  String get groupFallback => 'Group';

  @override
  String get reservedPhoneSearchHelp =>
      'Search the admin list or enter a full pattern (3, 4, or 8 digits XXYYZZTT). Patterns can be assigned directly without being added to the list.';

  @override
  String get reservedPhoneOnlyHint =>
      'Only 3 or 4 digits, or 8 digits XXYYZZTT (e.g. 11 22 33 44). These forms are excluded from automatic registration.';

  @override
  String messagesSummaryMulti(int totalMessages, int convCount) {
    return '$totalMessages messages · $convCount chats';
  }

  @override
  String messagesSummaryOne(int count) {
    return '$count new message';
  }

  @override
  String messagesSummaryMany(int count) {
    return '$count new messages';
  }

  @override
  String dateAtTimeFull(int day, int month, int year, String time) {
    return '$day/$month/$year at $time';
  }

  @override
  String todayTimeShort(String time) {
    return 'Today $time';
  }

  @override
  String get albumCannotBeForwarded => 'This album cannot be forwarded';

  @override
  String userHashId(Object id) {
    return 'User #$id';
  }

  @override
  String listWithCount(int count) {
    return 'List ($count)';
  }

  @override
  String get listLabel => 'List';

  @override
  String get filterLabel => 'Filter';

  @override
  String get freePlural => 'Available';

  @override
  String get assignAction => 'Assign';

  @override
  String get messagesChannelName => 'Messages';

  @override
  String get searchEllipsis => 'Search...';

  @override
  String get callNoun => 'Call';

  @override
  String get allFilter => 'All';

  @override
  String get audioViewOnce => '🎵 Audio · View once';

  @override
  String get mediaFallback => 'Media';

  @override
  String fileWithName(String name) {
    return '📎 $name';
  }

  @override
  String get groupsFilter => 'Groups';

  @override
  String participantsSelected(int count) {
    return '$count participant(s) selected';
  }

  @override
  String get waitingForParticipants => 'Waiting for participants…';

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
  String get text2 => 'Text';

  @override
  String get publishAction => 'Publish';

  @override
  String get importAction => 'Import';

  @override
  String get finishAction => 'Done';

  @override
  String get recordAction => 'Record';

  @override
  String get meLabel => 'Me';

  @override
  String selfChatTitle(String name) {
    return '$name (Me)';
  }

  @override
  String get messageYourself => 'Message yourself';

  @override
  String get selfChatSubtitle => 'Notes, reminders, files';

  @override
  String get selfChatDeleteWarning =>
      'All your notes will be permanently deleted. This cannot be undone.';

  @override
  String get cannotCallYourself => 'You can\'t call yourself';

  @override
  String get statusNoun => 'Status';

  @override
  String get youLabel => 'You';

  @override
  String get hostLabel => 'Host';

  @override
  String get guestLabel => 'Guest';

  @override
  String get chatLabel => 'Chat';

  @override
  String get summaryLabel => 'Summary';

  @override
  String get typeLabel => 'Type';

  @override
  String get accountLabel => 'Account';

  @override
  String get adminDashboard => 'Admin dashboard';

  @override
  String get superAdmin => 'Super Admin';

  @override
  String inMinutes(int mins) {
    return 'In ${mins}min';
  }

  @override
  String get participantFallback => 'Participant';

  @override
  String get userFallback => 'User';

  @override
  String nameYouParen(String name) {
    return '$name (you)';
  }

  @override
  String get contactsLabel => 'Contacts';

  @override
  String get searchUserByNameOrUsername =>
      'Search for a user by name or username';

  @override
  String get endMeetingAction => 'End';

  @override
  String hoursShort(int hours) {
    return '$hours h';
  }

  @override
  String hoursAndMinutesShort(int hours, int minutes) {
    return '$hours h $minutes';
  }

  @override
  String get formatBold => 'Bold';

  @override
  String get formatItalic => 'Italic';

  @override
  String get formatUnderline => 'Underline';

  @override
  String get formatStrikethrough => 'Strikethrough';

  @override
  String get formatHandwriting => 'Handwriting';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get avatarLabel => 'Avatar';

  @override
  String get nameUsernamePasswordRequired =>
      'Name, username and password required';

  @override
  String get usersLabel => 'Users';

  @override
  String get bannedUsers => 'Banned';

  @override
  String get bannedLabel => 'Banned';

  @override
  String get adminsLabel => 'Admins';

  @override
  String get actionsLabel => 'Actions';

  @override
  String get conversationsLabel => 'Conversations';

  @override
  String get totalLabel => 'Total';

  @override
  String get commonBlock => 'Block';

  @override
  String get messageNoun => 'Message';

  @override
  String get albumNoun => 'Album';

  @override
  String get favoriteSingular => 'Favorite';

  @override
  String get hangUp => 'Hang up';

  @override
  String get viewAction => 'View';

  @override
  String invitationFrom(String name) {
    return 'Invitation from $name';
  }

  @override
  String get fileArchive => 'Archive';

  @override
  String get reservationLimitedTo3Or4OrXxyyzztt =>
      'Reservation limited to 3 or 4 digit numbers, or 8 digits in XXYYZZTT format (e.g. 11 22 33 44)';

  @override
  String get discussionFallback => 'Chat';

  @override
  String get overviewSection => 'Overview';

  @override
  String rangeOfTotal(int from, int to, int total) {
    return '$from–$to of $total';
  }

  @override
  String get tryAnotherName => 'Try another name.';

  @override
  String get tryAnotherSearchTerm => 'Try a different search term.';

  @override
  String andNOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '… and $count others',
      one: '… and 1 other',
    );
    return '$_temp0';
  }

  @override
  String get voiceCallOutgoing => 'Outgoing voice call';

  @override
  String get voiceCallIncoming => 'Incoming voice call';

  @override
  String get videoCallOutgoing => 'Outgoing video call';

  @override
  String get videoCallIncoming => 'Incoming video call';

  @override
  String reactionChipLabel(String emoji, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reactions',
      one: '1 reaction',
    );
    return '$emoji, $_temp0';
  }

  @override
  String get reactToMessage => 'React';

  @override
  String get moreReactions => 'More reactions';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSubtitle => 'Messages, calls, privacy';

  @override
  String get notifPrefsSectionAlerts => 'Alerts';

  @override
  String get notifPrefsSectionBehavior => 'Behavior';

  @override
  String get notifPrefMessages => 'Direct messages';

  @override
  String get notifPrefGroupMessages => 'Group messages';

  @override
  String get notifPrefCalls => 'Calls';

  @override
  String get notifPrefMeetings => 'Meetings';

  @override
  String get notifPrefStatusView => 'Status views';

  @override
  String get notifPrefBroadcasts => 'Alanya announcements';

  @override
  String get notifPrefSound => 'Sound';

  @override
  String get notifPrefVibration => 'Vibration';

  @override
  String get notifPrefPreviewTitle => 'Lock screen preview';

  @override
  String get notifPrefPreviewFull => 'Name + content';

  @override
  String get notifPrefPreviewNameOnly => 'Name only';

  @override
  String get notifPrefPreviewGeneric => 'Generic';

  @override
  String get notifPrefsSaveFailed => 'Could not save notification preferences';

  @override
  String get convMuteAction => 'Notifications';

  @override
  String get convMuteSubtitle => 'Mute alerts for this conversation';

  @override
  String convMuteTitle(String name) {
    return 'Notifications — $name';
  }

  @override
  String get convMute8h => 'Mute for 8 hours';

  @override
  String get convMute1w => 'Mute for 1 week';

  @override
  String get convMuteForever => 'Mute always';

  @override
  String get convUnmute => 'Unmute notifications';

  @override
  String convMuteDone(String name) {
    return 'Muted notifications for $name';
  }

  @override
  String convUnmuteDone(String name) {
    return 'Unmuted notifications for $name';
  }

  @override
  String get convMuteFailed => 'Could not update mute settings';

  @override
  String sysGroupCreated(String actor, String value) {
    return '$actor created the group “$value”';
  }

  @override
  String sysGroupCreatedByMe(String value) {
    return 'You created the group “$value”';
  }

  @override
  String sysMemberAdded(String actor, String targets) {
    return '$actor added $targets';
  }

  @override
  String sysMemberAddedByMe(String targets) {
    return 'You added $targets';
  }

  @override
  String sysMemberRemoved(String actor, String targets) {
    return '$actor removed $targets';
  }

  @override
  String sysMemberRemovedByMe(String targets) {
    return 'You removed $targets';
  }

  @override
  String sysMemberLeft(String actor) {
    return '$actor left the group';
  }

  @override
  String get sysMemberLeftByMe => 'You left the group';

  @override
  String sysGroupRenamed(String actor, String value) {
    return '$actor renamed the group to “$value”';
  }

  @override
  String sysGroupRenamedByMe(String value) {
    return 'You renamed the group to “$value”';
  }

  @override
  String sysGroupPhotoChanged(String actor) {
    return '$actor changed the group photo';
  }

  @override
  String get sysGroupPhotoChangedByMe => 'You changed the group photo';

  @override
  String sysGroupDescriptionChanged(String actor) {
    return '$actor changed the description';
  }

  @override
  String get sysGroupDescriptionChangedByMe => 'You changed the description';

  @override
  String sysRolePromoted(String actor, String targets) {
    return '$actor made $targets an admin';
  }

  @override
  String sysRolePromotedByMe(String targets) {
    return 'You made $targets an admin';
  }

  @override
  String sysRoleDemoted(String actor, String targets) {
    return '$actor dismissed $targets as admin';
  }

  @override
  String sysRoleDemotedByMe(String targets) {
    return 'You dismissed $targets as admin';
  }

  @override
  String sysOnlyAdminsSendOn(String actor) {
    return '$actor restricted sending to admins';
  }

  @override
  String get sysOnlyAdminsSendOnByMe => 'You restricted sending to admins';

  @override
  String sysOnlyAdminsSendOff(String actor) {
    return '$actor allowed everyone to send messages';
  }

  @override
  String get sysOnlyAdminsSendOffByMe =>
      'You allowed everyone to send messages';

  @override
  String sysOnlyAdminsEditOn(String actor) {
    return '$actor restricted editing group info to admins';
  }

  @override
  String get sysOnlyAdminsEditOnByMe =>
      'You restricted editing group info to admins';

  @override
  String sysOnlyAdminsEditOff(String actor) {
    return '$actor allowed everyone to edit group info';
  }

  @override
  String get sysOnlyAdminsEditOffByMe =>
      'You allowed everyone to edit group info';

  @override
  String get sysGroupEventFallback => 'The group was updated';

  @override
  String sysPreviewGroupCreated(String actor, String value) {
    return '$actor created \"$value\"';
  }

  @override
  String sysPreviewGroupCreatedShort(String actor) {
    return '$actor created the group';
  }

  @override
  String sysPreviewMemberAdded(String actor) {
    return '$actor added members';
  }

  @override
  String sysPreviewMemberRemoved(String actor) {
    return '$actor removed a member';
  }

  @override
  String sysPreviewMemberLeft(String actor) {
    return '$actor left the group';
  }

  @override
  String sysPreviewGroupRenamed(String actor) {
    return '$actor renamed the group';
  }

  @override
  String sysPreviewGroupPhotoChanged(String actor) {
    return '$actor changed the group photo';
  }

  @override
  String sysPreviewGroupDescriptionChanged(String actor) {
    return '$actor changed the description';
  }

  @override
  String sysPreviewRolePromoted(String actor) {
    return '$actor made someone an admin';
  }

  @override
  String sysPreviewRoleDemoted(String actor) {
    return '$actor removed admin rights';
  }

  @override
  String sysPreviewSettingsChanged(String actor) {
    return '$actor changed group settings';
  }

  @override
  String get groupOwner => 'Owner';

  @override
  String get groupAdmin => 'Admin';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String removeMemberConfirm(String name) {
    return 'Remove $name from the group?';
  }

  @override
  String removeMemberDone(String name) {
    return '$name was removed from the group';
  }

  @override
  String get dismissAdmin => 'Dismiss as admin';

  @override
  String get viewProfile => 'View profile';

  @override
  String get groupDescription => 'Description';

  @override
  String get groupDescriptionHint => 'Add a description…';

  @override
  String get noGroupDescription => 'No description';

  @override
  String get renameGroup => 'Rename group';

  @override
  String get changeGroupPhoto => 'Change photo';

  @override
  String get groupSettings => 'Group settings';

  @override
  String get onlyAdminsCanSendLabel => 'Only admins can send messages';

  @override
  String get onlyAdminsCanSendSubtitle =>
      'Turns the group into an announcement channel';

  @override
  String get onlyAdminsCanEditInfoLabel => 'Only admins can edit info';

  @override
  String get onlyAdminsCanEditInfoSubtitle => 'Name, photo and description';

  @override
  String get hideHistoryForNewMembersLabel => 'Hide history for new members';

  @override
  String get hideHistoryForNewMembersSubtitle =>
      'New members won\'t see messages sent before they joined';

  @override
  String get onlyAdminsCanAddMembersLabel => 'Only admins can add members';

  @override
  String get onlyAdminsCanAddMembersSubtitle =>
      'Invite new participants to the group';

  @override
  String groupJoinBannerBody(String actor, String group) {
    return '$actor added you to the group \"$group\"';
  }

  @override
  String get stay => 'Stay';

  @override
  String sysHideHistoryOn(String actor) {
    return '$actor hid chat history for new members';
  }

  @override
  String get sysHideHistoryOnByMe => 'You hid chat history for new members';

  @override
  String sysHideHistoryOff(String actor) {
    return '$actor made chat history visible for new members';
  }

  @override
  String get sysHideHistoryOffByMe =>
      'You made chat history visible for new members';

  @override
  String sysOnlyAdminsAddOn(String actor) {
    return '$actor restricted adding members to admins';
  }

  @override
  String get sysOnlyAdminsAddOnByMe =>
      'You restricted adding members to admins';

  @override
  String sysOnlyAdminsAddOff(String actor) {
    return '$actor allowed everyone to add members';
  }

  @override
  String get sysOnlyAdminsAddOffByMe => 'You allowed everyone to add members';

  @override
  String get mentionsOnlyLabel => 'Mentions only';

  @override
  String get mentionsOnlySubtitle =>
      'Only get alerted when someone mentions you';

  @override
  String get youWereRemovedFromGroup => 'You are no longer part of this group';

  @override
  String get notAllowedGroupAction => 'Action not allowed';

  @override
  String get ownerMustTransferOnLeave =>
      'You are the owner: the group will pass to the longest-standing member.';

  @override
  String get groupInfoUpdated => 'Group info updated';

  @override
  String get groupUpdateFailed => 'Could not update the group';

  @override
  String get announcementOnlyAdmins => 'Only admins can send messages';

  @override
  String get officialAccountReadonlyBanner =>
      'This account sends announcements. You cannot reply.';

  @override
  String get accountBadgeVerified => 'Alanya Plus subscriber';

  @override
  String get accountBadgeBusinessDeclared => 'Declared business';

  @override
  String get accountBadgeBusinessVerified => 'Verified business';

  @override
  String get accountBadgeOfficial => 'Official Alanya account';

  @override
  String get mentionAll => '@All';

  @override
  String mentionAllSubtitle(int count) {
    return 'Alerts all $count members';
  }

  @override
  String get mentionYou => 'You';

  @override
  String get jumpToMention => 'Go to next mention';

  @override
  String get unreadMessagesSeparator => 'Unread messages';

  @override
  String get signupEmailOptionalHint => 'Email address (optional)';

  @override
  String get signupEmailOptionalSubtitle =>
      'Only used to recover your password';

  @override
  String get signupNoEmailWarningTitle => 'No email address';

  @override
  String get signupNoEmailWarningBody =>
      'Without an email, you will not be able to recover your account if you forget your Alanya ID or password.';

  @override
  String get signupAddEmail => 'Add an email';

  @override
  String get signupContinueWithoutEmail => 'Continue';

  @override
  String get signupCredentialsNoEmailReminder =>
      'Without an email, account recovery is impossible. You can add one anytime in Profile → Account → Edit profile (OTP verification).';

  @override
  String get signupCredentialsEmailOk =>
      'Your email can be used to recover your password if you forget it.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailNotSet => 'Not set';

  @override
  String get emailNeededForRecovery => 'Required to recover your password';

  @override
  String get emailMissingRecoveryBanner =>
      'No email address: you will not be able to recover your account if you forget your credentials.';

  @override
  String get accountSecurityTitle => 'Account & security';

  @override
  String get accountSecuritySubtitle => 'Email and password';

  @override
  String get changeEmailTitle => 'Email address';

  @override
  String get changeEmailSubtitleAdd =>
      'Add an address so you can recover your password.';

  @override
  String get changeEmailSubtitleReplace =>
      'A verification code will be sent to the new address.';

  @override
  String get changeEmailCurrentLabel => 'Current address';

  @override
  String get changeEmailNewLabel => 'New email address';

  @override
  String get changeEmailAddLabel => 'Your email address';

  @override
  String get changeEmailStep1 => '1. Address';

  @override
  String get changeEmailStep2 => '2. Verification';

  @override
  String get changeEmailWhyOtp =>
      'To confirm you own this address, a 6-digit code will be sent by email.';

  @override
  String get changeEmailCheckInbox =>
      'Open your inbox and enter the code you received. Check spam too.';

  @override
  String get changeEmailEditAddress => 'Edit address';

  @override
  String get changeEmailSendCode => 'Send code';

  @override
  String get changeEmailOtpTitle => 'Verification code';

  @override
  String changeEmailOtpSubtitle(String email) {
    return 'Enter the code sent to $email';
  }

  @override
  String get changeEmailResendCode => 'Resend code';

  @override
  String get changeEmailConfirm => 'Verify and save';

  @override
  String get changeEmailSuccess => 'Email address updated';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordSubtitle => 'Current password required';

  @override
  String get changePasswordCurrent => 'Current password';

  @override
  String get changePasswordNew => 'New password';

  @override
  String get changePasswordConfirm => 'Confirm new password';

  @override
  String get changePasswordSubmit => 'Save';

  @override
  String get changePasswordSuccess => 'Password updated';

  @override
  String get changePasswordSameAsCurrent =>
      'New password must be different from the current one';

  @override
  String get profileNoEmailChip => 'Add an email to secure your account';

  @override
  String get addToCall => 'Add to call';

  @override
  String get transferCall => 'Transfer call';

  @override
  String get transferCallSheetTitle => 'Transfer call';

  @override
  String get transferCallConfirmationTitle => 'Transfer this call?';

  @override
  String get transferCallConfirmationBody =>
      'The contact will join the call first. You will leave automatically about 10 seconds after their connection is established.';

  @override
  String get addToCallConfirmBody =>
      'Invite this contact to join the ongoing call?';

  @override
  String get transferWaitingForParticipant => 'Waiting for an answer…';

  @override
  String get transferWaitingForConnection => 'Connecting…';

  @override
  String get transferCountdown =>
      'Transfer in progress… You will leave the call soon.';

  @override
  String transferCountdownSeconds(int seconds) {
    return 'Transfer · ${seconds}s';
  }

  @override
  String get transferCompleted => 'Call transferred';

  @override
  String get mediaConnectionFailed =>
      'Media connection could not be established';

  @override
  String get conferenceTransferInviteBody =>
      'wants to transfer this call to you';

  @override
  String get confCallOfThree => '3-way call';

  @override
  String get confRinging => 'Ringing…';

  @override
  String confAddingInvitee(String name) {
    return 'Adding $name';
  }

  @override
  String confSomeoneAdds(String who, String name) {
    return '$who is adding $name';
  }

  @override
  String confJoinedCall(String name) {
    return '$name joined the call';
  }

  @override
  String confLeftCall(String name) {
    return '$name left the call';
  }

  @override
  String confDeclined(String name) {
    return '$name declined to join';
  }

  @override
  String confBusy(String name) {
    return '$name is already on a call';
  }

  @override
  String confNoAnswer(String name) {
    return '$name did not answer';
  }

  @override
  String confNotJoined(String name) {
    return '$name did not join the call';
  }

  @override
  String get confAddAlreadyUsed =>
      'Someone has already been added to this call';

  @override
  String confCannotAdd(String name) {
    return '$name cannot be added';
  }

  @override
  String get confAddFailed => 'The person could not be added';

  @override
  String confInviteSubtitle(String name) {
    return 'is adding you to a call with $name';
  }

  @override
  String get confAddSheetTitle => 'Add to call';

  @override
  String get noContactsToAdd => 'No contacts to add';

  @override
  String get confAlreadyInCall => 'already here';

  @override
  String get confContactBusy => 'on a call';

  @override
  String get confCancelInvite => 'Cancel';

  @override
  String get qrMyCodeTitle => 'My QR code';

  @override
  String get qrMyCodeTabCode => 'My code';

  @override
  String get qrMyCodeTabScan => 'Scan';

  @override
  String get qrMyCodeSubtitle =>
      'Have this code scanned to be added as a preferred contact.';

  @override
  String get qrMyCodeShare => 'Share';

  @override
  String qrMyCodeExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get qrMyCodeValidityNote =>
      'Valid for 10 minutes and a single person. A new code is generated automatically.';

  @override
  String get qrMyCodeNewCode => 'New code';

  @override
  String get qrMyCodeShareValidity =>
      'This code is valid for 10 minutes and a single person.';

  @override
  String get qrScanReturnTitle => 'New contact';

  @override
  String qrScanReturnBody(String name) {
    return '$name added you to their preferred contacts with your QR code. Add them back?';
  }

  @override
  String get qrScanReturnAccept => 'Add';

  @override
  String get qrScanReturnDecline => 'No thanks';

  @override
  String get qrScanReturnFailed => 'Could not add this contact';

  @override
  String qrScannedMutualInfo(String name) {
    return '$name added you with your QR code';
  }

  @override
  String get qrNoteFieldHint => 'Add a note (place, context…)';

  @override
  String get qrNoteSaved => 'Note saved';

  @override
  String get qrNoteFailed => 'Could not save the note';

  @override
  String get qrContactsFilterAll => 'All';

  @override
  String get qrContactsFilterQr => 'Via QR';

  @override
  String get qrContactAddedViaQr => 'Added via QR code';

  @override
  String qrContactAddedViaQrOn(String date) {
    return 'Added via QR code · $date';
  }

  @override
  String get qrMyCodeShareSheetTitle => 'Share my code';

  @override
  String get qrMyCodeShareLink => 'Share the link';

  @override
  String get qrMyCodeShareLinkHint => 'Tappable link and Alanya ID';

  @override
  String get qrMyCodeShareImage => 'Share the image';

  @override
  String get qrMyCodeShareImageHint => 'The card to scan';

  @override
  String qrMyCodeShareId(String id) {
    return 'My Alanya ID: $id';
  }

  @override
  String get qrMyCodeRegenerate => 'Regenerate';

  @override
  String get qrMyCodeRegenerateConfirmTitle => 'Regenerate your code?';

  @override
  String get qrMyCodeRegenerateConfirmBody =>
      'The old code will stop working right away. Anyone who saved it will no longer be able to add you with it.';

  @override
  String get qrMyCodeRegenerateDone => 'New code generated';

  @override
  String qrMyCodeShareText(String name) {
    return 'Add me on Alanya: I am $name.';
  }

  @override
  String get qrScanTitle => 'Scan a code';

  @override
  String get qrScanEntryButton => 'Scan a code';

  @override
  String get qrScanInstruction => 'Point at a contact\'s QR code';

  @override
  String get qrScanErrorUnreadable =>
      'Code unreadable. Move closer and try again.';

  @override
  String get qrScanErrorUnknown => 'This code has expired or is unknown.';

  @override
  String get qrScanOwnCode => 'This is your own code.';

  @override
  String qrScanAddSuccess(String name) {
    return '$name was added to your preferred contacts';
  }

  @override
  String qrScanAlreadyContact(String name) {
    return '$name is already in your preferred contacts';
  }

  @override
  String get qrScanResultAdded => 'Added to your contacts';

  @override
  String get qrScanResultAlready => 'Already in your contacts';

  @override
  String get qrScanActionMessage => 'Message';

  @override
  String get qrScanActionDetails => 'View details';

  @override
  String get qrScanUndo => 'Undo';

  @override
  String qrScanUndone(String name) {
    return '$name was removed from your preferred contacts';
  }

  @override
  String get qrScanUndoFailed => 'Could not undo the addition';

  @override
  String get qrScanCameraDenied => 'Alanya needs camera access to scan a code.';

  @override
  String get qrScanOpenSettings => 'Open settings';

  @override
  String get qrScanTorchOn => 'Flashlight on';

  @override
  String get qrScanTorchOff => 'Flashlight off';

  @override
  String get qrScanImportImage => 'Import an image';

  @override
  String get qrScanImportNoCode => 'No QR code in this image.';

  @override
  String get qrScanImportNotAlanya => 'This QR code is not an Alanya code.';

  @override
  String get qrScanImportFailed => 'Could not read this image.';

  @override
  String get qrLoginTitle => 'Sign in with QR code';

  @override
  String get qrLoginEntryButton => 'Sign in with a QR code';

  @override
  String get qrLoginUsePassword => 'Sign in with my password';

  @override
  String get qrLoginExplanation =>
      'Open Alanya on the phone you are already signed in on, go to Account & security, then scan this code.';

  @override
  String get qrLoginDeviceNotTrustedNotice =>
      'This phone isn\'t recognised for this account yet. Scan this code from a device that is already signed in. If you no longer have it, reset your password from the sign-in screen.';

  @override
  String qrLoginExpiresIn(String time) {
    return 'Expires in $time';
  }

  @override
  String get qrLoginStatusWaiting => 'Waiting to be scanned…';

  @override
  String get qrLoginStatusScanned =>
      'Code scanned. Confirm on your other device.';

  @override
  String get qrLoginStatusRejected =>
      'Sign-in declined from your other device.';

  @override
  String get qrLoginStatusExpired => 'This code has expired.';

  @override
  String get qrLoginRegenerate => 'Generate a new code';

  @override
  String get qrLoginNetworkError =>
      'Could not connect. Check your network and try again.';

  @override
  String get qrApproveTitle => 'New sign-in';

  @override
  String get qrApproveIntro => 'This code was just scanned from this device:';

  @override
  String get qrApproveDeviceLabel => 'Device (declared name)';

  @override
  String get qrApprovePlatformLabel => 'Platform';

  @override
  String get qrApproveRequestedLabel => 'Requested';

  @override
  String get qrApproveIpLabel => 'IP address';

  @override
  String get qrApproveLocationLabel => 'Approximate location';

  @override
  String get qrApproveDeclaredNotice =>
      'The name and platform are announced by the device requesting access and can be forged. Only the IP address is observed by Alanya.';

  @override
  String get qrApproveSecurityWarning =>
      'If you did not start this request, decline it and change your password.';

  @override
  String get qrApproveReject => 'Decline';

  @override
  String get qrApproveConfirm => 'Confirm';

  @override
  String get qrApproveDone => 'Device connected';

  @override
  String get qrApproveRejectDone => 'Sign-in declined';

  @override
  String get qrApproveSessionExpired =>
      'This request has expired. Show a new code on the other device.';

  @override
  String get qrDevicesTitle => 'Connected devices';

  @override
  String get qrDevicesEntryTitle => 'Connected devices';

  @override
  String get qrDevicesEntrySubtitle => 'See where your account is open';

  @override
  String get qrLinkDeviceTitle => 'Link a new device';

  @override
  String get qrLinkDeviceSubtitle => 'Scan the code shown on the other device';

  @override
  String get qrDevicesThisDevice => 'This device';

  @override
  String get qrDevicesUnknownDevice => 'Unknown device';

  @override
  String get qrDevicesMethodPassword => 'Signed in with password';

  @override
  String get qrDevicesMethodSignup => 'Sign-up device';

  @override
  String get qrDevicesMethodQr => 'Signed in with QR code';

  @override
  String qrDevicesLastActive(String date) {
    return 'Active $date';
  }

  @override
  String get qrDevicesRevoke => 'Sign out';

  @override
  String get qrDevicesRevokeConfirmTitle => 'Sign this device out?';

  @override
  String qrDevicesRevokeConfirmBody(String name) {
    return '$name will be signed out right away. Your password will be required to sign back in on it.';
  }

  @override
  String get qrDevicesRevokeDone => 'Device signed out';

  @override
  String get qrDevicesEmpty => 'No other connected device';

  @override
  String get qrDevicesLoadError => 'Could not load your devices';

  @override
  String get qrDevicesIosNote =>
      'On iPhone, a device may show up again as a new device in this list after Alanya is reinstalled.';

  @override
  String qrBannerNewDevice(String name) {
    return 'New device connected: $name';
  }

  @override
  String get qrBannerSignedOutRemotely =>
      'This device was signed out from another device.';

  @override
  String get myAccountLabel => 'My account';

  @override
  String get accountHubTitle => 'My account';

  @override
  String get accountHubSecurityScore => 'Security score';

  @override
  String accountHubSecurityScoreValue(int score, int max) {
    return '$score / $max';
  }

  @override
  String get securityScoreAddEmail => 'Add an email to improve your score.';

  @override
  String get securityScoreAddBiometric =>
      'Enable biometrics to improve your score.';

  @override
  String get accountHubSectionIdentity => 'Identity';

  @override
  String get accountHubSectionProtection => 'Protection';

  @override
  String get accountHubSectionData => 'Data';

  @override
  String get accountHubEditProfile => 'Edit profile';

  @override
  String get accountHubEditProfileSubtitle => 'Name, username, bio, photo';

  @override
  String get accountHubMyMedia => 'My media';

  @override
  String get accountHubPrivacy => 'Privacy';

  @override
  String get accountHubPrivacySubtitle => 'Visibility, blocking, read receipts';

  @override
  String get accountHubSecurity => 'Account security';

  @override
  String get accountHubSecuritySubtitle => 'Password, devices, biometrics';

  @override
  String get accountHubDataAccount => 'Data & account';

  @override
  String get accountHubDataAccountSubtitle => 'GDPR export, deletion';

  @override
  String get accountHubProfilePreview => 'Profile preview';

  @override
  String get accountHubProfilePreviewSubtitle => 'See how contacts view you';

  @override
  String get profileBioLabel => 'Bio';

  @override
  String get profileBioHint =>
      'Tell others about yourself (500 characters max)';

  @override
  String get profilePreviewLink => 'Profile preview';

  @override
  String get myMediaTitle => 'My media';

  @override
  String get myMediaPlaceholder =>
      'Your shared photos and videos will appear here.';

  @override
  String get storageTitle => 'Storage & cache';

  @override
  String get storageUsed => 'Storage used';

  @override
  String get storageBreakdownTitle => 'Breakdown';

  @override
  String get storageMediaCache => 'Media cache';

  @override
  String get storageDatabase => 'Database';

  @override
  String get storageTempFiles => 'Temporary files';

  @override
  String get storageOther => 'Other data';

  @override
  String get storageClearMediaCache => 'Clear media cache';

  @override
  String get storageClearTemp => 'Clear temporary files';

  @override
  String get storageClearCacheConfirm =>
      'Cached files will be removed. Media still on the server can be downloaded again; older ones will be lost for good.';

  @override
  String get storageClearCacheDone => 'Media cache cleared';

  @override
  String get storageClearTempDone => 'Temporary files cleared';

  @override
  String get networkDataTitle => 'Network & data';

  @override
  String get networkDataSectionNetwork => 'Network';

  @override
  String get networkWifiOnly => 'Wi-Fi only';

  @override
  String get networkWifiOnlySubtitle => 'Only download media on Wi-Fi';

  @override
  String get networkDataSaver => 'Data saver';

  @override
  String get networkDataSaverSubtitle =>
      'Reduces quality and automatic downloads';

  @override
  String get settingsSectionCommunication => 'Communication';

  @override
  String get settingsSectionApplication => 'Application';

  @override
  String get settingsSectionInformation => 'Information';

  @override
  String get settingsStorage => 'Storage & cache';

  @override
  String get settingsStorageSubtitle => 'Usage and cleanup';

  @override
  String get settingsNetwork => 'Network & data';

  @override
  String get settingsNetworkSubtitle => 'Wi-Fi and data saver';

  @override
  String get settingsAccessibility => 'Accessibility';

  @override
  String get settingsAccessibilitySubtitle => 'Text and motion';

  @override
  String get settingsAbout => 'About & legal';

  @override
  String get settingsMutedConversations => 'Muted conversations';

  @override
  String get accessibilityTitle => 'Accessibility';

  @override
  String get accessibilitySectionDisplay => 'Display';

  @override
  String get accessibilityFontScale => 'Text size';

  @override
  String get accessibilityFontScaleSmall => 'Small';

  @override
  String get accessibilityFontScaleDefault => 'Normal';

  @override
  String get accessibilityFontScaleMedium => 'Large';

  @override
  String get accessibilityFontScaleLarge => 'Extra large';

  @override
  String get accessibilityReduceMotion => 'Reduce motion';

  @override
  String get accessibilityReduceMotionSubtitle =>
      'Limits transitions and visual effects';

  @override
  String get accessibilitySaveFailed => 'Could not save preferences';

  @override
  String get mutedConversationsTitle => 'Muted conversations';

  @override
  String get mutedConversationsEmpty => 'No muted conversations';

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
  String get mutedForeverLabel => 'Muted indefinitely';

  @override
  String mutedUntilLabel(String date) {
    return 'Until $date';
  }

  @override
  String get dndScheduleTitle => 'Do not disturb';

  @override
  String get dndEnabled => 'Schedule';

  @override
  String get dndEnabledSubtitle => 'Mute notifications on a time schedule';

  @override
  String get dndScheduleHours => 'Hours';

  @override
  String get dndStartTime => 'Start';

  @override
  String get dndEndTime => 'End';

  @override
  String get dndDays => 'Active days';

  @override
  String get dndDayMon => 'Mon';

  @override
  String get dndDayTue => 'Tue';

  @override
  String get dndDayWed => 'Wed';

  @override
  String get dndDayThu => 'Thu';

  @override
  String get dndDayFri => 'Fri';

  @override
  String get dndDaySat => 'Sat';

  @override
  String get dndDaySun => 'Sun';

  @override
  String get dndSaveFailed => 'Could not save schedule';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutSectionLegal => 'Legal';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutTerms => 'Terms of service';

  @override
  String get aboutPrivacy => 'Privacy policy';

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get aboutSupport => 'Contact support';

  @override
  String get aboutCopyright => '© 2026 Alanya · Made with care in Yaoundé';

  @override
  String get exportDataTitle => 'Data & account';

  @override
  String get exportSectionYourData => 'Your data';

  @override
  String get exportSectionDanger => 'Sensitive zone';

  @override
  String get exportPhase1Title => 'Quick export (GDPR)';

  @override
  String get exportPhase1Subtitle =>
      'Profile, contacts, metadata — available immediately';

  @override
  String get exportPhase2Title => 'Full export';

  @override
  String get exportPhase2Subtitle =>
      'Includes messages and media — ready in ~24 h';

  @override
  String get exportRequestPhase1 => 'Export now';

  @override
  String get exportRequestPhase2 => 'Request full export';

  @override
  String get exportPhase1ReadyTitle => 'Export ready';

  @override
  String get exportPhase2Started =>
      'Full export requested — you will be notified';

  @override
  String get exportInProgress => 'Export in progress';

  @override
  String get exportInProgressHint =>
      'Ready in ~24 h · notification when complete';

  @override
  String get exportReady => 'Your export is ready';

  @override
  String get exportDownload => 'Download';

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountEntrySubtitle => 'Irreversible action';

  @override
  String get deleteAccountStep1Title => 'Irreversible action';

  @override
  String get deleteAccountStep1Bullet1 => 'Messages and media will be deleted';

  @override
  String get deleteAccountStep1Bullet2 => 'Removed from all groups';

  @override
  String get deleteAccountStep1Bullet3 =>
      'Phone number released after the grace period';

  @override
  String get deleteAccountContinue => 'Continue';

  @override
  String get deleteAccountPassword => 'Password';

  @override
  String get deleteAccountConfirmLabel => 'Type DELETE';

  @override
  String get deleteAccountConfirmWord => 'DELETE';

  @override
  String get deleteAccountConfirmMismatch => 'Type DELETE to confirm';

  @override
  String get deleteAccountSubmit => 'Delete my account';

  @override
  String get deleteAccountGraceTitle => 'Deletion scheduled';

  @override
  String deleteAccountGraceBody(String date) {
    return 'Your account will be permanently deleted on $date. You can cancel until then.';
  }

  @override
  String get biometricLock => 'Biometric lock';

  @override
  String get biometricLockTitle => 'Alanya is locked';

  @override
  String get biometricLockUnlock => 'Unlock';

  @override
  String get biometricLockSubtitle => 'Fingerprint or face unlock on open';

  @override
  String get biometricLockEnableConfirm =>
      'Confirm your fingerprint to enable the lock';

  @override
  String get biometricLockUnavailable =>
      'Biometrics unavailable on this device';

  @override
  String get accountSecuritySectionProtection => 'Protection';

  @override
  String get logoutAllDevices => 'Sign out all devices';

  @override
  String get logoutAllDevicesSubtitle => 'Ends all sessions except this one';

  @override
  String get logoutAllDevicesConfirm =>
      'All other devices will be signed out immediately.';

  @override
  String get logoutAllDevicesAction => 'Sign out';

  @override
  String get logoutAllDevicesDone => 'Other devices signed out';

  @override
  String get logoutAllDevicesFailed => 'Could not sign out all devices';

  @override
  String get privacySectionWhoCanSee => 'Who can see me';

  @override
  String get privacySectionMessages => 'Messages';

  @override
  String get privacySectionLists => 'Lists & groups';

  @override
  String get privacyLastSeen => 'Last seen';

  @override
  String get privacyOnlineStatus => 'Online status';

  @override
  String get privacyProfilePhoto => 'Profile photo';

  @override
  String get privacyReadReceipts => 'Read receipts';

  @override
  String get privacyReadReceiptsSubtitle =>
      'Send and receive read confirmations';

  @override
  String get privacyNotificationPreview => 'Notification preview';

  @override
  String get privacyBlockedContacts => 'Blocked contacts';

  @override
  String get privacyBlockedContactsEmpty => 'No blocked contacts';

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
  String get privacyAddToGroups => 'Add to groups';

  @override
  String get privacyVisibilityEveryone => 'Everyone';

  @override
  String get privacyVisibilityContacts => 'My contacts';

  @override
  String get privacyVisibilityNobody => 'Nobody';

  @override
  String get privacySaveFailed => 'Could not save privacy settings';

  @override
  String get onboardingCredentialsTitle => 'Your credentials';

  @override
  String get onboardingCredentialsSubtitle =>
      'Keep this information in a safe place.';

  @override
  String get onboardingCredentialsBanner =>
      'Save your Alanya number and password — they won\'t be shown again.';

  @override
  String get onboardingProfileTitle => 'Your profile';

  @override
  String get onboardingProfileSubtitle =>
      'Photo, gender, age, country, bio: fill in now or anytime in My account.';

  @override
  String get profileBioDefault => 'Hi, I\'m on Alanya';

  @override
  String get onboardingPersonalizeTitle => 'Personalize Alanya';

  @override
  String get onboardingPersonalizeSubtitle =>
      'Theme, language, and lock. Change anytime in Settings.';

  @override
  String onboardingStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingCountryTitle => 'Your country';

  @override
  String get onboardingCountrySubtitle => 'Helps contacts recognize you.';

  @override
  String get onboardingPhotoTitle => 'Profile photo';

  @override
  String get onboardingPhotoSubtitle => 'Add a photo or skip this step.';

  @override
  String get onboardingPhotoChooseGallery => 'Choose from gallery';

  @override
  String get onboardingPhotoCamera => 'Take a photo';

  @override
  String get onboardingPhotoFailed => 'Could not add photo';

  @override
  String get onboardingBioTitle => 'A few words about you';

  @override
  String get onboardingBioSubtitle =>
      'Introduce yourself in one line (optional).';

  @override
  String get onboardingBioHint => 'Hi, I\'m on Alanya';

  @override
  String get onboardingPreferencesTitle => 'Preferences';

  @override
  String get onboardingPreferencesSubtitle => 'App theme and language.';

  @override
  String get onboardingThemeLabel => 'Theme';

  @override
  String get onboardingLanguageLabel => 'Language';

  @override
  String get onboardingBiometricTitle => 'Protect access';

  @override
  String get onboardingBiometricSubtitle =>
      'A quick gesture each time you return to the app.';

  @override
  String get onboardingBiometricFriendlyTitle => 'Fingerprint or face unlock';

  @override
  String get onboardingBiometricFriendlyBody =>
      'Turn on quick unlock. You can change this anytime in Settings.';

  @override
  String get onboardingBiometricUnavailable =>
      'Biometrics unavailable — you can enable this later in settings.';

  @override
  String get onboardingCompleteTitle => 'You\'re all set!';

  @override
  String get onboardingCompleteSubtitle => 'Your account is ready.';

  @override
  String get onboardingCompleteMessage =>
      'Explore Alanya and stay connected with people you care about.';

  @override
  String get onboardingCompleteCta => 'Discover Alanya';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingSkipAll => 'Set up later';

  @override
  String get onboardingSkipAllTitle => 'Skip setup?';

  @override
  String get onboardingSkipAllBody =>
      'You can complete your profile anytime in My account.';

  @override
  String get onboardingSkipAllCredentialsBody =>
      'You won\'t see your password here again. Complete your profile anytime in My account.';

  @override
  String get onboardingSkipAllRecoveryBody =>
      'You won\'t see your password here again, and your recovery code will only reappear in My account → Security. Write them down before continuing.';

  @override
  String get onboardingSaveFailed =>
      'Could not save — try again or skip this step.';

  @override
  String get onboardingCredentialsBannerNoEmail =>
      'Write down your Alanya number, your password and your recovery code — they won\'t be shown here again.';

  @override
  String get onboardingPhotoAdd => 'Tap to add a photo';

  @override
  String get onboardingIdentityTitle => 'About you';

  @override
  String get onboardingIdentitySubtitle =>
      'Gender and age can\'t be changed once saved.';

  @override
  String get profileGenderLabel => 'Gender';

  @override
  String get profileIdentitySection => 'Identity';

  @override
  String get profileGenderSegmentPreferNotSay => 'Prefer not';

  @override
  String get profileGenderMale => 'Male';

  @override
  String get profileGenderFemale => 'Female';

  @override
  String get profileGenderOther => 'Other';

  @override
  String get profileGenderUnspecified => 'Prefer not to say';

  @override
  String get profileAgeLabel => 'Age';

  @override
  String get profileAgeSuffix => 'yrs';

  @override
  String profileAgeBirthYear(int year) {
    return 'Birth year ≈ $year';
  }

  @override
  String profileAgeInvalid(int min, int max) {
    return 'Invalid age (between $min and $max)';
  }

  @override
  String get recoveryCodeTitle => 'Recovery code';

  @override
  String get recoveryCodeKeepSafe => 'Keep it safe';

  @override
  String get recoveryCodeOnboardingHint =>
      'Without an email address, this code is your only way back into your account. Write it down somewhere other than this phone.';

  @override
  String get recoveryCodeCopied => 'Recovery code copied';

  @override
  String get recoveryCodeEntrySubtitle =>
      'Reset your password without an email';

  @override
  String get recoveryCodeIntro =>
      'This code resets your password without going through email. It never changes, not even after a password change.';

  @override
  String get recoveryCodeSecurityWarning =>
      'Anyone who knows this code and your Alanya ID can change your password. Never share it.';

  @override
  String get recoveryCodeReveal => 'Show code';

  @override
  String get recoveryCodeHide => 'Hide';

  @override
  String get recoveryCodePasswordPrompt =>
      'Enter your password to display the code.';

  @override
  String get recoveryCodeRevealFailed => 'Could not display the code';

  @override
  String get forgotMethodTitle => 'Recover your account';

  @override
  String get forgotMethodSubtitle => 'How would you like to proceed?';

  @override
  String get forgotMethodEmail => 'I have an email address';

  @override
  String get forgotMethodEmailSubtitle => 'Get a 6-digit code by email.';

  @override
  String get forgotMethodCode => 'I have a recovery code';

  @override
  String get forgotMethodCodeSubtitle =>
      'The code shown when you created your account.';

  @override
  String get forgotCodeTitle => 'Your recovery code';

  @override
  String get forgotCodeSubtitle =>
      'Enter your Alanya ID and the code you saved at sign-up.';

  @override
  String get forgotCodeHint => 'XXXX-XXXX-XXXX';

  @override
  String get forgotCodeSubmit => 'Validate code';

  @override
  String get validatorRecoveryCode => '12-character recovery code';

  @override
  String deleteAccountGraceDays(int days) {
    return 'Grace period · $days days';
  }

  @override
  String get deleteAccountCancelDeletion => 'Cancel deletion';

  @override
  String get deleteAccountCancelSuccess => 'Deletion cancelled';

  @override
  String get deleteAccountCancelFailed => 'Could not cancel deletion';

  @override
  String get deleteAccountLogoutNow => 'Sign out';

  @override
  String get myMediaEmpty => 'No shared media yet';

  @override
  String get myMediaLoadFailed => 'Could not load your media';

  @override
  String get bytesUnitB => 'B';

  @override
  String get bytesUnitKB => 'KB';

  @override
  String get bytesUnitMB => 'MB';

  @override
  String get bytesUnitGB => 'GB';

  @override
  String get myMediaSortRecent => 'Recent';

  @override
  String get myMediaSortLargest => 'Largest';

  @override
  String myMediaOnThisDevice(String size) {
    return '$size on this device';
  }

  @override
  String get myMediaFreeSpace => 'Free up space';

  @override
  String get myMediaFreeSpaceConfirm =>
      'The local copy of the selected media will be removed. They stay in your chats and will download again when opened.';

  @override
  String get myMediaFreeSpaceConfirmMaybeGone =>
      'The local copy of the selected media will be removed. They stay in your chats, but some are old: if they are no longer available on the server, they will stay unavailable.';

  @override
  String myMediaFreedSpace(String size) {
    return '$size freed on this device';
  }

  @override
  String get myMediaNothingCached =>
      'None of these media take up space on this device';

  @override
  String get myMediaForwardUnavailable =>
      'These media are no longer in your chats on this device';

  @override
  String get myMediaSelectAll => 'Select all';

  @override
  String get myMediaFilterReceived => 'Received';

  @override
  String get myMediaFilterSent => 'Sent';

  @override
  String get myMediaFilterAll => 'All';

  @override
  String myMediaFrom(String name) {
    return 'From $name';
  }

  @override
  String get settingsBackup => 'Backup';

  @override
  String get settingsBackupSubtitle => 'Your messages and settings, encrypted';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle => 'Your messages and settings, encrypted';

  @override
  String get backupFrequencyLabel => 'Frequency';

  @override
  String get backupFrequencyDaily => 'Daily';

  @override
  String get backupFrequencyWeekly => 'Weekly';

  @override
  String get backupFrequencyMonthly => 'Monthly';

  @override
  String get backupFrequencyNever => 'Never';

  @override
  String get backupLastNever => 'No backup yet';

  @override
  String backupLastAt(String when, String size) {
    return 'Last backup: $when · $size';
  }

  @override
  String backupCounts(int messages, int conversations) {
    return '$messages messages · $conversations chats';
  }

  @override
  String get backupRunNow => 'Back up now';

  @override
  String get backupRunning => 'Backing up…';

  @override
  String get backupSucceeded => 'Backup complete';

  @override
  String get backupAlreadyRunning => 'A backup is already running.';

  @override
  String get backupFailed => 'The backup failed';

  @override
  String get backupStaleWarning =>
      'No backup has succeeded for several days. Check your connection and available space.';

  @override
  String get backupDestinationLabel => 'Destination';

  @override
  String backupDestinationDrive(String account) {
    return 'Google Drive $account';
  }

  @override
  String get backupDestinationDriveUnlinked =>
      'Google Drive — no account connected on this device';

  @override
  String get backupDestinationDevice => 'On this device';

  @override
  String get backupChangeAccount => 'Change Google account';

  @override
  String get backupConnectDrive => 'Connect Google Drive';

  @override
  String get backupUseDevice => 'Back up to this device';

  @override
  String get backupDriveConnected =>
      'Google Drive connected. Your next backups will go there.';

  @override
  String get backupDriveRefused => 'Google sign-in cancelled. Nothing changed.';

  @override
  String get backupFellBack =>
      'Drive was unreachable: the backup was made on this device.';

  @override
  String backupFellBackAt(String when) {
    return 'Drive was unreachable. A backup was made on this device on $when.';
  }

  @override
  String get backupLocalRisksTitle => 'Backup on this device';

  @override
  String get backupLocalRisksBody =>
      'Your backup is on this phone, in Downloads › Alanya › Sauvegardes.\n\n✓ It survives reinstalling Alanya.\n✗ It does not survive losing, breaking or having the phone stolen.\n✗ It does not survive a full device wipe.\n\nTo keep your data safe off the phone, connect Google Drive.';

  @override
  String get backupWhatIsSaved =>
      'Backed up: messages, chats, contacts and settings. Photos, videos and files are not — use “Export this period” from My media to keep them.';

  @override
  String get backupNotEndToEnd =>
      'The backup is encrypted. Alanya can technically decrypt it to restore it for you; nobody else can.';

  @override
  String get backupRestoreEntry => 'Restore a backup';

  @override
  String get backupRestoreEntryHint =>
      'From Google Drive or a file on your phone';

  @override
  String get restoreTitle => 'Restore your data';

  @override
  String restoreFound(String when, String size) {
    return 'A backup from $when was found ($size).';
  }

  @override
  String get restoreExplain =>
      'Your messages and settings will be put back. Photos and videos older than 30 days will not return: they are not in the backup.';

  @override
  String get restoreAction => 'Restore';

  @override
  String get restoreConnectGoogle => 'Connect to Google Drive';

  @override
  String get restoreGoogleRefused => 'Google sign-in cancelled';

  @override
  String get restoreGoogleEmpty => 'No backup in this Google account';

  @override
  String get restorePickFile => 'Choose a backup file';

  @override
  String get restorePickHint =>
      'If your backup does not show up — after a reinstall, for instance — point to the .enc file in Downloads › Alanya › Sauvegardes.';

  @override
  String get restorePickCancelled => 'No file chosen';

  @override
  String get restorePickWrongFile => 'This file is not an Alanya backup';

  @override
  String get restoreSkip => 'Skip and continue';

  @override
  String get restoreRunning => 'Restoring…';

  @override
  String get restoreCloseApp => 'Close Alanya';

  @override
  String get restoreDoneRestart =>
      'Restore ready. Close Alanya, then open it again: your data will be in place on startup.';

  @override
  String get restoreFailedMessage =>
      'The restore failed. You can try again from settings.';

  @override
  String get restoreKeyUnknown =>
      'This backup was encrypted with a key we no longer recognise.';

  @override
  String get restoreTooRecent =>
      'This backup comes from a newer version of Alanya. Please update the app.';

  @override
  String get restoreInterrupted =>
      'A previous restore was interrupted. It will start again from the beginning.';

  @override
  String get exportPeriodAction => 'Export this period';

  @override
  String get exportSheetTitle => 'Export this period';

  @override
  String exportSheetSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items · $size',
      one: '1 item · $size',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get exportSheetNothing => 'No media to export for these filters';

  @override
  String exportMissingRecoverable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missing items can be recovered ($size)',
      one: '1 missing item can be recovered ($size)',
    );
    return '$_temp0';
  }

  @override
  String exportMissingRecoverableEstimate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Up to $count missing items can be recovered',
      one: 'Up to 1 missing item can be recovered',
    );
    return '$_temp0';
  }

  @override
  String get exportMissingEstimateHint =>
      'The server could not be reached: some of these items may no longer be there.';

  @override
  String exportDoneWithMissing(String size, int missing) {
    return 'Archive ready: $size · $missing item(s) unavailable';
  }

  @override
  String get exportMissingRecoverableHint =>
      'If ticked, these items are downloaded before assembly. If not, no mobile data is used.';

  @override
  String exportMissingLost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are no longer available on the servers',
      one: '1 item is no longer available on the servers',
    );
    return '$_temp0';
  }

  @override
  String get exportMissingLostHint =>
      'They are listed in the archive, but their content is permanently lost.';

  @override
  String get exportDestinationShare => 'Share';

  @override
  String get exportDestinationDownloads => 'Save to Downloads';

  @override
  String get exportPhaseScanning => 'Taking stock…';

  @override
  String exportPhaseRecovering(int done, int total) {
    return 'Recovering $done / $total';
  }

  @override
  String exportPhaseAssembling(int done, int total) {
    return 'Assembling $done / $total';
  }

  @override
  String exportDone(String size) {
    return 'Archive ready: $size';
  }

  @override
  String get exportFailedGeneric => 'The export failed';

  @override
  String get exportNoSpace => 'Not enough space on the device for this archive';

  @override
  String get exportSaveUnsupported =>
      'This destination is not available on this device';

  @override
  String get exportSavedToDownloads => 'Archive saved to Downloads/Alanya';

  @override
  String get exportCancelled => 'Export cancelled';

  @override
  String get myMediaFilters => 'Filters';

  @override
  String get myMediaFilterDiscussion => 'Chat';

  @override
  String get myMediaAllDiscussions => 'All chats';

  @override
  String get myMediaSearchDiscussion => 'Search for a chat';

  @override
  String get myMediaFilterOrigin => 'Source';

  @override
  String get myMediaFilterPeriod => 'Period';

  @override
  String get myMediaPeriodAny => 'All time';

  @override
  String get myMediaPeriodStart => 'Start';

  @override
  String get myMediaPeriodEnd => 'End';

  @override
  String get myMediaPeriodLast7 => '7 days';

  @override
  String get myMediaPeriodLast30 => '30 days';

  @override
  String get myMediaPeriodThisYear => 'This year';

  @override
  String get myMediaPeriodClear => 'Clear period';

  @override
  String get myMediaKindAll => 'All';

  @override
  String get myMediaKindPhotos => 'Photos';

  @override
  String get myMediaKindVideos => 'Videos';

  @override
  String get myMediaKindAudio => 'Voice';

  @override
  String get myMediaKindFiles => 'Files';

  @override
  String myMediaSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items · $size',
      one: '1 item · $size',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get myMediaEmptyFiltered => 'No media matches these filters';

  @override
  String get myMediaResetFilters => 'Reset filters';

  @override
  String dndSummaryActive(String start, String end, String days) {
    return '$start – $end · $days';
  }

  @override
  String get dndSummaryInactive => 'Off';

  @override
  String get exportPhase1ShareSubject => 'Alanya export (profile and metadata)';

  @override
  String get officialContactSupport => 'Contact support';

  @override
  String get officialComingSoon => 'Coming soon';

  @override
  String get officialHelpAndFaq => 'Help and FAQ';

  @override
  String get officialHelpUnavailable => 'Could not open the help page';

  @override
  String get listKindFamily => 'Family';

  @override
  String get listKindFriends => 'Friends';

  @override
  String get listKindWork => 'Work';

  @override
  String get listKindTrust => 'Trust';

  @override
  String get contactLists => 'Contact lists';

  @override
  String get contactListsManage => 'Manage';

  @override
  String get createList => 'Create a list';

  @override
  String get listName => 'List name';

  @override
  String get listNameHint => 'Family, Friends, Work…';

  @override
  String get renameList => 'Rename list';

  @override
  String get deleteList => 'Delete list';

  @override
  String deleteListConfirm(String name) {
    return 'Delete “$name”? Your contacts stay in your favourites.';
  }

  @override
  String get listColor => 'Chip colour';

  @override
  String get listNameAlreadyExists => 'A list with this name already exists';

  @override
  String get listSaveFailed => 'Could not save the list. Try again.';

  @override
  String get listMembersUpdateFailed => 'Could not update members. Try again.';

  @override
  String listMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String listMembersCountLimited(int current, int limit) {
    return '$current/$limit members';
  }

  @override
  String listMemberLimitReached(int limit) {
    return 'This list is limited to $limit members';
  }

  @override
  String get addToList => 'Add members';

  @override
  String get removeFromList => 'Remove from list';

  @override
  String get createGroupFromList => 'Create a group';

  @override
  String get noLists => 'No contact lists';

  @override
  String get noListsHint =>
      'Sort your preferred contacts into Family, Friends, Work…';

  @override
  String get noListMembers => 'No members in this list';

  @override
  String get noContactToAddToList =>
      'All your preferred contacts are already in this list';

  @override
  String addMembersSelected(int count) {
    return '$count selected';
  }

  @override
  String get newList => 'New list';

  @override
  String get contactListsHint =>
      'A list can only contain contacts already in your favourites. The same contact can belong to several lists.';

  @override
  String get notInThisList => 'Favourite — not in this list';

  @override
  String createGroupNamed(String name) {
    return 'Create a group “$name”';
  }

  @override
  String get manageLists => 'Manage lists';

  @override
  String get contactListsSheetSubtitle =>
      'Open a list, or turn it into a group.';

  @override
  String get markAllAsRead => 'Mark all as read';

  @override
  String markAllAsReadDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats marked as read',
      one: '1 chat marked as read',
      zero: 'No unread chats',
    );
    return '$_temp0';
  }

  @override
  String get optionsAction => 'Options';

  @override
  String get trips => 'Trusted trips';

  @override
  String get tripsCircleEmptyTitle => 'Your trusted circle is empty';

  @override
  String get tripsCircleEmptyBody =>
      'Pick up to five people. They alone will see your trips, and only the ones you share.';

  @override
  String get tripsComposeCircle => 'Set up my circle';

  @override
  String get tripsMyCircle => 'My trusted circle';

  @override
  String get tripsNone => 'No trip in progress.';

  @override
  String get tripsNew => 'New trip';

  @override
  String get tripsKindTaxi => 'Taxi';

  @override
  String get tripsKindTaxiHint => 'A ride, with an expected arrival';

  @override
  String get tripsKindWalk => 'On foot';

  @override
  String get tripsKindWalkHint => 'A walk, with an expected arrival';

  @override
  String get tripsKindMeeting => 'On foot';

  @override
  String get tripsKindMeetingHint => 'A walk, with an expected arrival';

  @override
  String get tripsArrivalIn => 'Arriving in';

  @override
  String tripsMinutes(int count) {
    return '$count min';
  }

  @override
  String get tripsNoteLabel => 'Note for your circle';

  @override
  String get tripsNoteHint => 'Yellow taxi, plate LT 4471';

  @override
  String get tripsStart => 'Start sharing';

  @override
  String tripsContract(int count, String eta, String alert) {
    return 'Your $count contacts will see your live location until $eta. If you haven\'t confirmed by $alert, they will be alerted with your last known position.';
  }

  @override
  String get tripsCircleFrozen =>
      'Your circle is edited in Profile › Contact lists, never when starting a trip. Nobody is told they were added or removed.';

  @override
  String get tripsInProgress => 'Trip in progress';

  @override
  String get tripsLive => 'Live';

  @override
  String get tripsStale => 'Location unavailable';

  @override
  String get tripsAwaitingConfirm => 'Arrival to confirm';

  @override
  String get tripsAlerted => 'Alert sent';

  @override
  String tripsWatcherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are following',
      one: '1 person is following',
    );
    return '$_temp0';
  }

  @override
  String tripsWatcherFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people followed',
      one: '1 person followed',
      zero: 'Nobody followed',
    );
    return '$_temp0';
  }

  @override
  String tripsEtaAt(String time) {
    return 'Expected arrival $time';
  }

  @override
  String get tripsAlreadyActive => 'A trip is already in progress.';

  @override
  String get tripsStartFailed => 'Could not start the trip.';

  @override
  String get tripsSosUnavailable => 'SOS is not available yet.';

  @override
  String get tripsStop => 'Stop sharing';

  @override
  String get tripsForegroundOnly =>
      'Sharing pauses if you leave Alanya. Your circle will still be alerted at the expected time.';

  @override
  String tripsCardStarted(String name) {
    return '$name started a trip';
  }

  @override
  String get tripsCardStartedByMe => 'You started a trip';

  @override
  String tripsCardAwaiting(String name) {
    return '$name should have arrived';
  }

  @override
  String get tripsCardAwaitingByMe => 'You should have arrived';

  @override
  String tripsCardAlert(String name) {
    return '$name did not confirm arrival';
  }

  @override
  String get tripsCardAlertByMe => 'You did not confirm arrival';

  @override
  String tripsCardSos(String name) {
    return '$name triggered an SOS';
  }

  @override
  String get tripsCardSosByMe => 'You triggered an SOS';

  @override
  String tripsCardArrived(String name) {
    return '$name arrived safely';
  }

  @override
  String get tripsCardArrivedByMe => 'You arrived safely';

  @override
  String tripsCardStopped(String name) {
    return '$name stopped sharing';
  }

  @override
  String get tripsCardStoppedByMe => 'You stopped sharing';

  @override
  String get tripsCardFollow => 'Follow live';

  @override
  String get tripsCardView => 'View';

  @override
  String get tripsCardSeePosition => 'See location';

  @override
  String get tripsCardSeeLast => 'See last known location';

  @override
  String get tripsCardFallback => 'Trusted trip — please update the app';

  @override
  String get tripsConfirmArrival => 'I\'ve arrived safely';

  @override
  String tripsExtendBy(int count) {
    return '+$count min';
  }

  @override
  String tripsExtended(int count) {
    return 'Extended by $count minutes. Your circle has been informed.';
  }

  @override
  String get tripsAlreadyClosed => 'This trip is already closed.';

  @override
  String get tripsActionFailed => 'Action failed for now.';

  @override
  String get tripsHistory => 'History';

  @override
  String get tripsHistoryEmpty => 'No trips yet';

  @override
  String get tripsHistoryEmptyBody =>
      'When you share a trip, it will appear here — and only here.';

  @override
  String get tripsHistoryUnavailable => 'History unavailable';

  @override
  String get tripsHistoryOnline =>
      'Your past trips are fetched online: they are not kept on this device.';

  @override
  String get tripsRetentionNote =>
      'Trips are kept for twelve months. Detailed traces for twenty-four hours — thirty days after an alert.';

  @override
  String get tripsOutcomeConfirmed => 'Arrival confirmed';

  @override
  String get tripsOutcomeStopped => 'Trip stopped';

  @override
  String get tripsOutcomeAlert => 'Alert triggered';

  @override
  String get tripsDeleteLocked =>
      'This trip is kept for thirty days after an alert. This rule protects the person involved.';

  @override
  String get loadMore => 'Load more';

  @override
  String get tripsFgsTitle => 'Trusted trip in progress';

  @override
  String get tripsFgsBodyPlain => 'Your location is shared with your circle';

  @override
  String tripsFgsBody(String names) {
    return 'Shared with $names';
  }

  @override
  String get tripsSosTitle => 'SOS';

  @override
  String get tripsSosHold => 'Tap to trigger the SOS';

  @override
  String get tripsSosHoldBody =>
      'The countdown starts immediately and you can cancel before it is sent.';

  @override
  String get tripsSosNotEmergency =>
      'SOS does not call emergency services. It alerts your trusted circle.';

  @override
  String tripsSosSending(int count) {
    return 'Sending in $count seconds';
  }

  @override
  String get tripsSosSendingNow => 'Sending…';

  @override
  String get tripsSosSendingNowBody =>
      'Your circle will be alerted in a moment.';

  @override
  String get tripsSosSent => 'Your circle has been alerted';

  @override
  String get tripsSosDiscreet =>
      'No sound, no vibration. Your location keeps being shared.';

  @override
  String get tripsSosActive => 'Sharing active';

  @override
  String get tripsSosActiveBody =>
      'Your location is being shared. No sound, no vibration.';

  @override
  String get tripsSosTooMany => 'Too many SOS alerts in the last 24 hours.';

  @override
  String get tripsSosFalseAlarm => 'False alarm, I\'m fine';

  @override
  String get tripsSosButton => 'Trigger an SOS';

  @override
  String get tripsKeepsRunning =>
      'Sharing continues even with the screen locked. A notification reminds you, and lets you stop it.';

  @override
  String get tripsDestination => 'Destination';

  @override
  String get tripsDestinationOptional => 'Pick a destination (optional)';

  @override
  String get tripsDestinationRadius => 'Arrival will be detected within 100 m';

  @override
  String get tripsShort => 'Trusted';

  @override
  String get tripsRailStart => 'Start';

  @override
  String get tripsRailFollow => 'Follow';

  @override
  String get tripsRailConfirm => 'Confirm';

  @override
  String get tripsRailClose => 'Close';

  @override
  String get tripsConfirmed => 'Arrival confirmed. Your circle has been told.';

  @override
  String get tripsDeleteTitle => 'Delete this trip?';

  @override
  String get tripsDeleteBody =>
      'The trip and its trace will be erased. This cannot be undone.';

  @override
  String get tripsRecenter => 'Recentre on position';

  @override
  String get tripsMapExpand => 'Full screen';

  @override
  String get tripsMapReduce => 'Exit full screen';

  @override
  String get tripsMapFitBounds => 'Show position and destination';

  @override
  String get tripsDestinationSafetyNet =>
      'With a destination, we\'ll ask you to confirm on arrival — not only at the scheduled time.';

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
    return 'updated $age ago';
  }

  @override
  String get tripsPositionFrozen => 'Position frozen';

  @override
  String get tripsDeleteLockedHint => 'Kept for 30 days after an alert';

  @override
  String tripsEventWatcherSeenGroup(int count) {
    return '$count contacts have seen';
  }

  @override
  String get tripsArrivalReachedTitle => 'Have you arrived?';

  @override
  String get tripsArrivalReachedBody =>
      'You\'ve been at your destination for a minute.';

  @override
  String get tripsArrivalDueTitle => 'Confirm your arrival';

  @override
  String tripsArrivalDueBody(String time) {
    return 'Without a reply, your circle will be alerted at $time with your last known position.';
  }

  @override
  String get tripsArrivalDueBodyPlain =>
      'Without a reply, your circle will be alerted with your last known position.';

  @override
  String get tripsArrivalLater => 'Not yet — the deadline keeps running';

  @override
  String get tripsDegradedPermission => 'Location turned off';

  @override
  String get tripsDegradedPermissionBody =>
      'Your circle can no longer see your position. The deadline still stands: they will be alerted if you don\'t confirm.';

  @override
  String get tripsDegradedStale => 'Location unavailable';

  @override
  String get tripsDegradedStaleBody =>
      'Tunnel, car park or weak signal. This is not an alert — the deadline keeps running.';

  @override
  String get tripsDegradedBattery => 'Low battery';

  @override
  String get tripsDegradedBatteryBody =>
      'Tracking is slowed down. If the phone dies, your last position will be sent.';

  @override
  String get tripsDegradedFix => 'Fix';

  @override
  String get locationSearchHint => 'Search a place or address…';

  @override
  String get locationSearchEmpty =>
      'No results. You can still pick on the map.';

  @override
  String get locationSearchUnavailable =>
      'Search is unavailable. Check your connection and try again.';

  @override
  String get locationPickerChooseDestination => 'Choose a destination';

  @override
  String get locationPickerUseDestination => 'Use this destination';

  @override
  String get locationUseMyPosition => 'Use my location';

  @override
  String get locationPickerInstruction =>
      'Search, move the map, or use your location';

  @override
  String get mapCompassNorth => 'Reset north up';

  @override
  String tripsCardFalseAlarm(String name) {
    return '$name reported a false alarm';
  }

  @override
  String get tripsCardFalseAlarmByMe => 'You reported a false alarm';

  @override
  String get tripsSosFalseAlarmSent =>
      'Your circle has been told you\'re fine.';

  @override
  String get tripsCall => 'Call';

  @override
  String get tripsPermissionTitle => 'Allow location access';

  @override
  String get tripsPermissionBody =>
      'Without it, your circle won\'t see where you are. The arrival time is watched either way.';

  @override
  String get tripsPermissionNever =>
      'Alanya only uses your location during a trip you started. Never before, never after.';

  @override
  String get tripsPermissionAllow => 'Allow';

  @override
  String get tripsPermissionLater => 'Later';

  @override
  String sysTripAlert(String actor) {
    return '$actor didn\'t confirm arrival — the circle was alerted';
  }

  @override
  String get sysTripAlertByMe =>
      'You didn\'t confirm your arrival — your circle was alerted';

  @override
  String sysTripSos(String actor) {
    return '$actor triggered an SOS';
  }

  @override
  String get sysTripSosByMe => 'You triggered an SOS';

  @override
  String get tripsPreviewActive => '🧭 Trip in progress';

  @override
  String get tripsPreviewAwaiting => '🧭 Arrival to confirm';

  @override
  String get tripsPreviewAlert => '🆘 Trip alert';

  @override
  String get tripsPreviewSos => '🆘 SOS';

  @override
  String get tripsPreviewConfirmed => '✅ Arrived safely';

  @override
  String get tripsPreviewStopped => '🧭 Trip stopped';

  @override
  String get tripsPreviewFalseAlarm => '✅ False alarm';

  @override
  String get tripsAlertChannelName => 'Trip alerts';

  @override
  String get tripsAlertChannelBody =>
      'A contact didn\'t confirm arrival, or triggered an SOS. These alerts go through silent mode.';

  @override
  String get tripsChannelName => 'Trusted trips';

  @override
  String get tripsChannelBody =>
      'Arrival confirmation reminders, for your own trips.';

  @override
  String tripsRevokeTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get tripsRevokeBody =>
      'They will stop seeing your position and this trip\'s status. They won\'t be told.';

  @override
  String get tripsRevokeAction => 'Remove';

  @override
  String get tripsWatchersNoneSeen => 'Nobody has opened it yet';

  @override
  String tripsWatchersSeenCount(int seen, int total) {
    return '$seen of $total have seen';
  }

  @override
  String get tripsWatcherSeen => 'has seen';

  @override
  String get tripsOtherDeviceTitle => 'Trip running on your other device';

  @override
  String get tripsOtherDeviceBody =>
      'Only one device sends the position, otherwise the trace would jump between places.';

  @override
  String get tripsOtherDeviceTake => 'Track from this device';

  @override
  String get tripsOtherDeviceKeep => 'Stay read-only';

  @override
  String get tripsNoLongerShared => 'This trip is no longer shared with you';

  @override
  String get tripsNoLongerSharedBody =>
      'It may have ended, or you were removed. No further information is given.';

  @override
  String get tripsLiveEndedArrived => 'Arrived safely';

  @override
  String get tripsLiveEndedStopped => 'Sharing has ended';

  @override
  String get tripsLiveEndedBody => 'Location sharing has ended.';

  @override
  String get tripsDetailTitle => 'Trip details';

  @override
  String get tripsDetailTimeline => 'Timeline';

  @override
  String get tripsDetailNoEvents => 'No events recorded.';

  @override
  String get tripsTraceExpired => 'Trace expired';

  @override
  String get tripsTraceExpiredBody =>
      'Location points for this trip have been purged. The summary and timeline remain available.';

  @override
  String get tripsTraceUnavailable => 'Trace unavailable';

  @override
  String get tripsTraceUnavailableBody =>
      'Could not load this trip\'s location points. They have not been deleted — try again.';

  @override
  String get tripsTraceEmpty => 'No location recorded';

  @override
  String get tripsTraceEmptyBody =>
      'No location was recorded during this trip. The summary and timeline remain available.';

  @override
  String get tripsEventStarted => 'Started';

  @override
  String get tripsEventExtended => 'Extended';

  @override
  String get tripsEventArrivalDetected => 'Arrival detected';

  @override
  String get tripsEventEtaDue => 'ETA reached';

  @override
  String get tripsEventAlerted => 'Alert sent';

  @override
  String get tripsEventClosed => 'Closed';

  @override
  String get tripsEventSignalBack => 'Signal restored';

  @override
  String get tripsEventLowBattery => 'Low battery';

  @override
  String get tripsEventWatcherSeen => 'Seen by a contact';

  @override
  String get tripsEventWatcherRevoked => 'Watcher removed';

  @override
  String get tripsEventDeviceTakeover => 'Taken over on another device';

  @override
  String get tripsUnreachable => 'Trip unavailable';

  @override
  String get tripsUnreachableBody =>
      'The server can\'t be reached. Your connection may be down.';

  @override
  String get tripsLeave => 'Stop following';

  @override
  String get tripsLeaveTitle => 'Stop following this trip?';

  @override
  String get tripsLeaveBody =>
      'You\'ll no longer see their position, and won\'t be alerted if they don\'t confirm arrival.';

  @override
  String get translationSection => 'Translation';

  @override
  String get autoTranslate => 'Automatic translation';

  @override
  String get autoTranslateDescription =>
      'Translate incoming messages that aren\'t in your reading language.';

  @override
  String get onDeviceTranslationNotice =>
      'Translation happens on your device. No message is sent to a third-party service, and it works offline.';

  @override
  String get translateTo => 'Translate into';

  @override
  String translatedFrom(String language) {
    return 'Translated from $language';
  }

  @override
  String get showOriginal => 'see original';

  @override
  String get showTranslation => 'see translation';

  @override
  String get translate => 'Translate';

  @override
  String get translating => 'Translating…';

  @override
  String get translationFailed => 'Couldn\'t translate';

  @override
  String get translationUnavailable =>
      'No translation available for this message.';

  @override
  String get languageModels => 'Language models';

  @override
  String languageModelsDescription(int size) {
    return 'Each language takes about $size MB on your device.';
  }

  @override
  String downloadLanguageModel(String language, int size) {
    return 'Download $language ($size MB) to translate';
  }

  @override
  String get downloadModel => 'Download';

  @override
  String get deleteModel => 'Delete';

  @override
  String get modelBundled => 'Included in the app';

  @override
  String downloadingModel(String language) {
    return 'Downloading $language…';
  }

  @override
  String get modelDownloadFailed =>
      'Download failed. Check your Wi-Fi connection.';

  @override
  String get modelDownloadWifiNotice =>
      'Downloads use Wi-Fi to spare your mobile data.';

  @override
  String get translateThisConversation => 'Translate this conversation';

  @override
  String get translateModeAuto => 'Automatic';

  @override
  String get translateModeAlways => 'Always';

  @override
  String get translateModeNever => 'Never';

  @override
  String get translateModeAutoSubtitle => 'Follows the general setting';

  @override
  String get errDelaiDepasse =>
      'The server is taking too long to respond. Try again.';

  @override
  String get errReseauSuspect =>
      'Secure connection failed. Check your network.';

  @override
  String get errSessionExpiree =>
      'Your session has expired. Please sign in again.';

  @override
  String get errIntrouvable => 'Not found. This content may have been deleted.';

  @override
  String get errConflit => 'This action isn\'t possible right now.';

  @override
  String get errTropDeRequetes => 'Too many attempts. Please wait a moment.';

  @override
  String get errServeur => 'The service is temporarily unavailable. Try again.';

  @override
  String get errPermission => 'Permission denied. Check your device settings.';

  @override
  String get errPeripherique =>
      'Device unavailable or already in use by another app.';

  @override
  String get errStockage => 'Cannot access the file. Check available storage.';

  @override
  String get errGenerique => 'Something went wrong. Try again.';

  @override
  String get errDomaineAuth => 'Sign-in failed. Try again.';

  @override
  String get errDomaineChat => 'Message not sent. Try again.';

  @override
  String get errDomaineAppel => 'The call could not be completed. Try again.';

  @override
  String get errDomaineReunion => 'The meeting could not be opened. Try again.';

  @override
  String get errDomaineQr => 'This code could not be used. Try again.';

  @override
  String get errDomaineMedia => 'The file could not be processed. Try again.';

  @override
  String get errDomaineTrajet => 'The trip could not be updated. Try again.';

  @override
  String get errDomaineStatut => 'The status could not be posted. Try again.';

  @override
  String get errDomaineProfil => 'The change could not be saved. Try again.';

  @override
  String get errDomaineAdmin => 'The operation failed. Try again.';

  @override
  String get errAppelHorsLigne => 'You need a connection to place a call.';

  @override
  String get errChatHorsLigne =>
      'Message queued: it will send when you\'re back online.';

  @override
  String get errMediaStockage =>
      'Cannot save. Check available space on your device.';

  @override
  String get errCodeRefreshExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errCodeDeviceRevoked =>
      'This device was signed out. Please sign in again.';

  @override
  String get errCodeAccountDeletionPending => 'This account is being deleted.';

  @override
  String get errCodeRegisterRateLimited =>
      'Too many sign-up attempts. Try again later.';

  @override
  String get errCodeInvalidCredentials => 'Incorrect sign-in details.';

  @override
  String get errCodePasswordIncorrect => 'Incorrect password.';

  @override
  String get errCodeQrSessionExpired =>
      'This QR code has expired. Display a new one.';

  @override
  String get errCodeDeviceNotOwner =>
      'This device isn\'t authorised for this action.';

  @override
  String get errCodeDeviceNotTrusted =>
      'This phone isn\'t recognised for this account yet. Sign in with a QR code from a device that is already signed in.';

  @override
  String get errCodeAddAlreadyUsed => 'This code has already been used.';

  @override
  String get errCodeAddMePolicyDenied =>
      'This person doesn\'t accept being added by code.';

  @override
  String get errCodeMeetingExpired => 'This meeting has expired.';

  @override
  String get errCodeMeetingEnded => 'This meeting has ended.';

  @override
  String get errCodeMeetingOrganiserRequired =>
      'Only the organiser can do that.';

  @override
  String get errCodeAccountAlreadyInMeeting =>
      'This account is already in the meeting on another device.';

  @override
  String get errCodeSessionBusy => 'A call is in progress. End it first.';

  @override
  String get errCodeMaxDurationReached =>
      'The maximum duration has been reached.';

  @override
  String get errCodeBlockedBySender => 'You can\'t contact this person.';

  @override
  String get errCodeNotAMember => 'You\'re no longer a member of this group.';

  @override
  String get errCodeGroupAdminsOnly => 'Group admins only.';

  @override
  String get errCodeGroupOwnerRequired => 'Only the group owner can do that.';

  @override
  String get errCodeConversationNotFound =>
      'This conversation no longer exists.';

  @override
  String get errCodeOfficialReadonly =>
      'This official account doesn\'t accept replies.';

  @override
  String get errCodeListMemberLimit =>
      'This list has reached its member limit.';

  @override
  String get errCodeSystemListReadonly => 'This system list can\'t be edited.';

  @override
  String get errCodeInviteBlocked => 'This person can\'t be invited.';

  @override
  String get errCodeBusinessOnly => 'Business accounts only.';

  @override
  String get errCodeTrustListEmpty =>
      'Your trusted circle is empty. Add someone first.';

  @override
  String get errCodeTripAlreadyActive => 'A trip is already in progress.';

  @override
  String get errCodeTripTerminal => 'This trip has already ended.';

  @override
  String get errCodeTripStillOpen => 'End the current trip first.';

  @override
  String get errCodeSosRateLimited =>
      'Alert already sent. Wait before sending another.';

  @override
  String get errCodeInvalidEta => 'The arrival time isn\'t valid.';

  @override
  String get errCodeInvalidDestination => 'The destination isn\'t valid.';

  @override
  String get errCodeMediaExpired =>
      'This media has expired and is no longer available.';

  @override
  String get errCodeInvalidExtension => 'This file type isn\'t supported.';

  @override
  String get errCodeInsufficientRole =>
      'You don\'t have permission for this action.';

  @override
  String get errCodeFieldImmutable => 'This field can no longer be changed.';

  @override
  String get errAucuneAppPourFichier => 'No app can open this file.';

  @override
  String get plusBrand => 'Alanya Plus';

  @override
  String get plusFeatureTranslation => 'Translation';

  @override
  String get plusFeatureBackup => 'Backup';

  @override
  String get plusFeatureTrips => 'Trips';

  @override
  String get plusFeatureRingtones => 'Ringtones';

  @override
  String get plusFeatureStyle => 'Style';

  @override
  String get plusFeatureBadge => 'Badge';

  @override
  String plusAmount(String amount) {
    return '$amount FCFA';
  }

  @override
  String get plusPerMonth => '/ month';

  @override
  String get plusPerYear => '/ year';

  @override
  String plusPerNMonths(int count) {
    return '/ $count months';
  }

  @override
  String get plusPlanMonthly => 'Monthly';

  @override
  String get plusPlanYearly => 'Yearly';

  @override
  String get plusRenew => 'Renew';

  @override
  String get plusResubscribe => 'Subscribe again';

  @override
  String get paywallFromLabel => 'From';

  @override
  String get paywallSeeOffer => 'See the offer';

  @override
  String get paywallTranslationTitle => 'Translate your messages';

  @override
  String get paywallTranslationBody =>
      'Translation is part of Alanya Plus. It runs on your phone, even offline, and your messages never leave the device.';

  @override
  String get paywallBackupTitle => 'Back up your chats';

  @override
  String get paywallBackupBody =>
      'Backup is part of Alanya Plus: encrypted, on your phone or your Drive. Your existing backups can always be restored.';

  @override
  String get paywallTripsTitle => 'Start a trusted trip';

  @override
  String get paywallTripsBody =>
      'Trusted trips and SOS are part of Alanya Plus: your circle follows your trip and is alerted if you don\'t arrive. A trip already under way keeps its SOS until it ends.';

  @override
  String get paywallRingtonesTitle => 'A ringtone for each list';

  @override
  String get paywallRingtonesBody =>
      'List ringtones are part of Alanya Plus: recognise family, work or friends before you even look at the screen.';

  @override
  String get paywallGenericTitle => 'Alanya Plus feature';

  @override
  String get paywallGenericBody => 'This feature is part of Alanya Plus.';

  @override
  String get errCodeSubscriptionRequired =>
      'This feature is part of Alanya Plus.';

  @override
  String get errCodeBillingNotActive =>
      'Alanya Plus is free for now: there\'s nothing to pay.';

  @override
  String get errCodePaymentPending =>
      'A payment is already waiting for your confirmation.';

  @override
  String get errCodeInvalidMsisdn => 'This mobile money number isn\'t valid.';

  @override
  String get errCodeInvalidChannel => 'This payment method isn\'t available.';

  @override
  String get errCodePlanNotFound =>
      'This plan is no longer offered. Reload the offer.';

  @override
  String get errCodePaymentProviderError =>
      'The payment service isn\'t responding. Try again in a moment.';

  @override
  String get errDomaineAbonnement =>
      'Your subscription request didn\'t go through.';

  @override
  String plusCardGraceTitle(String date) {
    return 'Paid from $date';
  }

  @override
  String plusCardGraceBody(String date) {
    return 'Translation, backup, trips and list ringtones stay free until then. Subscribe now: your first period will start on $date.';
  }

  @override
  String plusCardGraceDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free days left',
      one: '1 free day left',
      zero: 'last free day',
    );
    return '$_temp0';
  }

  @override
  String get plusCardUpgradeTitle => 'Upgrade to Alanya Plus';

  @override
  String get plusCardDiscover => 'Discover the offer';

  @override
  String plusCardActiveUntil(String date) {
    return 'Active until $date';
  }

  @override
  String plusCardEndsOn(String date) {
    return 'Ends on $date';
  }

  @override
  String plusCardEndsSoonBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left. Renew to keep your features.',
      one: '1 day left. Renew to keep your features.',
      zero: 'Last day. Renew to keep your features.',
    );
    return '$_temp0';
  }

  @override
  String get plusCardAutoRenewOn => 'Auto-renewal is on.';

  @override
  String get plusCardAutoRenewOff => 'Remember to renew before it ends.';

  @override
  String get plusCardBadgeActive => 'Alanya Plus subscriber';

  @override
  String plusCardStartsOn(String date) {
    return 'Your subscription starts on $date';
  }

  @override
  String get plusCardScheduledBody =>
      'Until then, everything stays free for you.';

  @override
  String plusCardLapsedKicker(String date) {
    return 'Ended on $date';
  }

  @override
  String get plusCardLapsedTitle => 'Your Plus features are paused';

  @override
  String get plusCardLapsedBody =>
      'Your settings are kept. Subscribe again to get everything back, badge included.';

  @override
  String get plusOfferUnlocks => 'What Plus unlocks';

  @override
  String get plusOfferUnavailable =>
      'Payment isn\'t available right now. Try again later.';

  @override
  String get plusOfferDuration => 'Duration';

  @override
  String plusOfferContinue(String amount) {
    return 'Continue — $amount';
  }

  @override
  String get plusOfferNoCommitment => 'no commitment';

  @override
  String plusOfferEquivalent(String amount) {
    return 'that\'s $amount a month';
  }

  @override
  String plusOfferMonthsFree(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months free',
      one: '1 month free',
    );
    return '$_temp0';
  }

  @override
  String plusOfferFirstPeriod(String start, String end) {
    return 'First period: $start to $end.';
  }

  @override
  String plusOfferNextPeriod(String start, String end) {
    return 'Next period: $start to $end, right after the current one.';
  }

  @override
  String get plusOfferNoRefund =>
      'Each period is paid in advance and isn\'t refundable.';

  @override
  String get checkoutTitle => 'Payment';

  @override
  String get checkoutPayWith => 'Pay with';

  @override
  String get checkoutNumber => 'Number to charge';

  @override
  String get checkoutNumberHint => '6XX XX XX XX';

  @override
  String get checkoutNumberInvalid =>
      'Enter a Cameroonian mobile number: 9 digits starting with 6.';

  @override
  String get checkoutAutoRenew => 'Renew automatically';

  @override
  String checkoutAutoRenewHint(String operator) {
    return '$operator will ask you to confirm the day before it ends.';
  }

  @override
  String get checkoutSimulated =>
      'Simulated payment: no money is charged. Number ending in 01: insufficient funds · 02: declined · 03: no response.';

  @override
  String checkoutPay(String amount) {
    return 'Pay $amount';
  }

  @override
  String get checkoutWaitingTitle => 'Confirm on your phone';

  @override
  String checkoutWaitingBody(String operator, String amount) {
    return 'Enter your $operator PIN to approve $amount. This screen updates by itself.';
  }

  @override
  String checkoutExpiresIn(String time) {
    return 'the request expires in $time';
  }

  @override
  String get checkoutStepSent => 'Request sent';

  @override
  String checkoutStepSentTo(String number) {
    return 'to $number';
  }

  @override
  String get checkoutStepConfirm => 'Confirmation with your PIN';

  @override
  String get checkoutStepPending => 'waiting';

  @override
  String get checkoutStepActivated => 'Subscription activated';

  @override
  String checkoutStepActivatedHint(String operator) {
    return 'as soon as $operator replies';
  }

  @override
  String get checkoutLeave => 'Leave this screen';

  @override
  String get checkoutLeaveHint =>
      'Your subscription will activate as soon as it\'s confirmed, even if you leave this screen.';

  @override
  String get checkoutSuccessTitle => 'Alanya Plus is active';

  @override
  String checkoutSuccessBody(String plan, String start, String end) {
    return '$plan, from $start to $end.';
  }

  @override
  String get checkoutSuccessScheduled =>
      'Until then, everything stays free for you.';

  @override
  String get checkoutSuccessFeatures =>
      'Translation, backup, trips and list ringtones are on.';

  @override
  String get checkoutSuccessFeaturesScheduled =>
      'Translation, backup, trips and list ringtones stay on without interruption.';

  @override
  String get checkoutDone => 'Done';

  @override
  String get checkoutFailedTitle => 'The payment didn\'t go through';

  @override
  String get checkoutFailedInsufficient =>
      'Not enough balance on this mobile money account.';

  @override
  String get checkoutFailedDeclined => 'The payment was declined on the phone.';

  @override
  String get checkoutFailedTimeout =>
      'No confirmation arrived in time. You can try again.';

  @override
  String get checkoutFailedGeneric => 'The payment failed. You can try again.';

  @override
  String get subscriptionTitle => 'My subscription';

  @override
  String get subscriptionAutoRenew => 'Auto-renewal';

  @override
  String get subscriptionAutoRenewHint =>
      'The day before it ends, your operator will ask you to confirm the payment.';

  @override
  String get subscriptionNextDuration => 'Duration at next renewal';

  @override
  String get subscriptionPayments => 'Payments';

  @override
  String get subscriptionPeriods => 'Periods';

  @override
  String subscriptionRenewAmount(String amount) {
    return 'Renew — $amount';
  }

  @override
  String get subscriptionNoPayments => 'No payments yet.';

  @override
  String get subscriptionSourcePaid => 'Paid';

  @override
  String get subscriptionSourceTrial => 'Trial';

  @override
  String get subscriptionSourceGift => 'Gift';

  @override
  String get subscriptionSourceCompensation => 'Compensation';

  @override
  String subscriptionEndsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
      zero: 'any moment now',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionNoneTitle => 'No active subscription';

  @override
  String get subscriptionNoneBody =>
      'Alanya Plus unlocks translation, backup, trusted trips and list ringtones.';

  @override
  String get subscriptionExemptTitle =>
      'Alanya Plus is included with your account';

  @override
  String get paymentStatusSucceeded => 'Succeeded';

  @override
  String get paymentStatusFailed => 'Failed';

  @override
  String get paymentStatusExpired => 'Expired';

  @override
  String get paymentStatusRefunded => 'Refunded';

  @override
  String get paymentStatusPending => 'Pending';

  @override
  String get plusLockedTranslation =>
      'Without a subscription, translation only applies to your conversations with an Alanya Plus contact.';

  @override
  String get plusLockedBackup =>
      'New backups are part of Alanya Plus. Your existing backups can still be restored.';

  @override
  String get plusLockedRingtones =>
      'List ringtones are part of Alanya Plus. Your settings are kept and will come back when you subscribe.';

  @override
  String get plusLockedTrips =>
      'New trips and SOS outside a trip are part of Alanya Plus. A trip already under way keeps its SOS until it ends.';

  @override
  String plusCardLapsedBodyUntil(String date) {
    return 'Your settings and history are kept until $date. Subscribe again before then to get everything back, badge included.';
  }

  @override
  String get plusCardPurgedBody =>
      'Your Plus settings and history have been deleted. Subscribe again to get your features back.';

  @override
  String get verificationTitle => 'Get the badge';

  @override
  String get verificationStatusTitle => 'My verification';

  @override
  String get verificationIntro =>
      'The badge tells your contacts that you really are the person this account is named after.';

  @override
  String get verificationNameLabel => 'Name to verify';

  @override
  String get verificationNameHint =>
      'This is your profile name. It must match your ID.';

  @override
  String get verificationToProvide => 'To provide';

  @override
  String get verificationIdFront => 'ID document — front';

  @override
  String get verificationIdFrontHint =>
      'National ID, passport or driving licence';

  @override
  String get verificationIdBack => 'ID document — back';

  @override
  String get verificationIdBackHint => 'if your document has one';

  @override
  String get verificationSelfie => 'Selfie holding your ID';

  @override
  String get verificationSelfieHint => 'face and ID clearly visible';

  @override
  String get verificationTakePhoto => 'Take a photo';

  @override
  String get verificationChooseGallery => 'Choose from gallery';

  @override
  String get verificationRemove => 'Remove';

  @override
  String get verificationPrivacy =>
      'Your documents are encrypted, seen only by the admin team, and deleted 90 days after the decision. Every view is logged.';

  @override
  String get verificationSubmit => 'Send my request';

  @override
  String get verificationSendPieces => 'Send the documents';

  @override
  String get verificationPendingTitle => 'Verification in progress';

  @override
  String verificationPendingBody(String date) {
    return 'Submitted on $date · answer within 5 working days';
  }

  @override
  String get verificationStepSent => 'Request sent';

  @override
  String get verificationStepPieces => 'Documents received';

  @override
  String verificationPiecesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
    );
    return '$_temp0';
  }

  @override
  String get verificationStepReview => 'Review by Alanya';

  @override
  String get verificationStepInProgress => 'in progress';

  @override
  String get verificationStepDecision => 'Decision';

  @override
  String get verificationStepDecisionHint => 'you\'ll get a notification';

  @override
  String get verificationPlusNotWaiting =>
      'Your subscription is active: your Plus features don\'t wait for the decision.';

  @override
  String get verificationCancel => 'Cancel my request';

  @override
  String get verificationCancelConfirm =>
      'Cancel the request? Your documents will be deleted.';

  @override
  String get verificationDocRequestedTitle => 'A document is missing';

  @override
  String get verificationRefusedTitle => 'Request refused';

  @override
  String get verificationRevokedTitle => 'Badge removed';

  @override
  String verificationReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get verificationResubmitHint => 'You can submit a new request.';

  @override
  String get verificationRenamedTitle => 'Your name has changed';

  @override
  String get verificationRenamedBody =>
      'The badge is waiting for a new review: submit documents in your displayed name, or go back to the verified name.';

  @override
  String get verificationApprovedTitle => 'Identity verified, badge active';

  @override
  String verificationApprovedUntil(String date) {
    return 'It follows your subscription: until $date.';
  }

  @override
  String get verificationApprovedFree => 'The badge shows next to your name.';

  @override
  String get verificationPausedTitle => 'Identity verified, badge paused';

  @override
  String get verificationPausedBody =>
      'It comes back as soon as your subscription resumes.';

  @override
  String get verificationUnavailableBody =>
      'Identity verification opens soon. Check back in a few days.';

  @override
  String get plusCardBadgeMissing =>
      'The badge shows with an active subscription.';

  @override
  String get errCodeVerificationUnavailable =>
      'Identity verification isn\'t open yet.';

  @override
  String get errCodeDocumentsRequired => 'Add your ID and a selfie holding it.';

  @override
  String get errCodeNameRequired =>
      'Add your name to your profile before getting it verified.';

  @override
  String get errCodeVerificationAlreadyOpen =>
      'A request is already under review.';

  @override
  String get errCodeVerificationAlreadyApproved =>
      'Your identity is already verified under this name.';

  @override
  String get errCodeRequestNotPending =>
      'This request changed in the meantime. Reload the screen.';

  @override
  String get phoneChangeTitle => 'Choose my number';

  @override
  String get phoneChangeProduct => 'Alanya number';

  @override
  String get phoneChangeCurrent => 'Your current number';

  @override
  String phoneChangeIntro(String amount) {
    return 'Choose an 8-digit number that\'s easier to remember, for $amount. It replaces your current one, including to sign in.';
  }

  @override
  String get phoneChangeFieldLabel => 'Number you want';

  @override
  String get phoneChangeCheck => 'Check';

  @override
  String get phoneChangeMustBe8 => 'Enter an 8-digit number.';

  @override
  String get phoneChangeAvailable => 'Available';

  @override
  String get phoneChangeReasonSame => 'This is already your number.';

  @override
  String get phoneChangeReasonTaken =>
      'This number is already in use. Try another one.';

  @override
  String get phoneChangeReasonSetAside =>
      'This number is reserved by Alanya. Try another one.';

  @override
  String get phoneChangeReasonHeld =>
      'Someone is taking this number right now. Try again in a few minutes, or choose another one.';

  @override
  String get phoneChangeReasonQuarantine =>
      'This number was just released by its owner and isn\'t available yet. Try another one.';

  @override
  String phoneChangeReserveAndPay(String amount) {
    return 'Reserve and pay $amount';
  }

  @override
  String get phoneChangeUseCredit => 'Confirm this number';

  @override
  String get phoneChangeCreditBanner =>
      'Your change is already paid for, but the number you chose was taken in the meantime. Choose another one — you won\'t be charged again.';

  @override
  String phoneChangeHeldUntil(String phone, String time) {
    return '$phone is reserved for you until $time.';
  }

  @override
  String get phoneChangeReleaseHold => 'Release this number';

  @override
  String phoneChangePending(String phone) {
    return 'Payment in progress for $phone.';
  }

  @override
  String get phoneChangeSeeWaiting => 'Follow the payment';

  @override
  String get phoneChangeLoginNote =>
      'After the change, sign in with your new number. Your chats, contacts and groups come with you. Your old number won\'t be given to anyone else right away.';

  @override
  String get phoneChangeUnavailable =>
      'Choosing a number isn\'t available right now.';

  @override
  String phoneChangeSummaryHeld(String time) {
    return 'Reserved for you until $time';
  }

  @override
  String get phoneChangeStepApplied => 'Number changed';

  @override
  String get phoneChangeLeaveHint =>
      'Your number will change as soon as the payment is confirmed, even if you leave this screen.';

  @override
  String get phoneChangeSuccessTitle => 'Here\'s your new number';

  @override
  String get phoneChangeSuccessBody =>
      'It\'s now the one you sign in with. Your chats, contacts and groups come with you.';

  @override
  String get phoneChangeCreditTitle => 'Payment confirmed';

  @override
  String get phoneChangeCreditBody =>
      'The number you chose was taken in the meantime. Choose another one — you won\'t be charged again.';

  @override
  String get phoneChangeChooseAnother => 'Choose a number';

  @override
  String get errCodePhonePurchaseUnavailable =>
      'Choosing a number isn\'t offered yet.';

  @override
  String get errCodeOfficialPhoneFixed =>
      'This account\'s number can\'t change.';

  @override
  String get errCodePhoneNotPurchasable =>
      'Only 8-digit numbers can be chosen.';

  @override
  String get errCodePhoneUnavailable =>
      'This number is no longer available. Try another one.';

  @override
  String get errCodePhoneHoldExpired =>
      'Your reservation for this number has expired. Check it again.';

  @override
  String get errCodePhoneOrderNotFound =>
      'This reservation no longer exists. Start again.';

  @override
  String get errCodePhoneOrderPending =>
      'A number payment is already waiting for your confirmation.';

  @override
  String accountSecurityPhoneSubtitle(String amount) {
    return 'Switch to an easier-to-remember number · $amount';
  }

  @override
  String accountSecurityPhonePending(String phone) {
    return 'Change to $phone in progress';
  }

  @override
  String get accountSecurityPhoneCredit => 'Change paid: choose your number';

  @override
  String get receiptsTitle => 'Message info';

  @override
  String receiptsReadBy(int count) {
    return 'Read by $count';
  }

  @override
  String receiptsOutOf(int total) {
    return 'of $total';
  }

  @override
  String receiptsDeliveredBy(int count) {
    return 'Delivered to $count';
  }

  @override
  String receiptsPendingCount(int count) {
    return 'Pending $count';
  }

  @override
  String get receiptsReadSection => 'Read';

  @override
  String receiptsShowAllReaders(int count) {
    return 'See all $count readers';
  }

  @override
  String get receiptsDeliveredNotRead => 'Delivered, not read yet';

  @override
  String get receiptsNotDelivered => 'Not delivered yet';

  @override
  String receiptsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get receiptsNoReaders => 'No one has read it yet';

  @override
  String get receiptsLoadError => 'Couldn\'t load read receipts.';

  @override
  String receiptsBarLabel(int read, int delivered, int pending) {
    return '$read read, $delivered delivered but unread, $pending pending';
  }
}
