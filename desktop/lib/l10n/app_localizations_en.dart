// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Alanya SafeBox';

  @override
  String get safeboxName => 'SafeBox';

  @override
  String get navHome => 'Home';

  @override
  String get navSettings => 'Settings';

  @override
  String get rootPhotos => 'Photos';

  @override
  String get rootVideos => 'Videos';

  @override
  String get rootAudios => 'Audio';

  @override
  String get rootDocuments => 'Documents';

  @override
  String get rootAlbums => 'Albums';

  @override
  String get rootShare => 'Share';

  @override
  String get back => 'Back';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get errorNetwork =>
      'Can\'t reach the server. Check your Internet connection and try again.';

  @override
  String get errorGeneric => 'Something went wrong. Try again in a moment.';

  @override
  String bytesB(int n) {
    return '$n B';
  }

  @override
  String bytesKB(String n) {
    return '$n KB';
  }

  @override
  String bytesMB(String n) {
    return '$n MB';
  }

  @override
  String bytesGB(String n) {
    return '$n GB';
  }

  @override
  String spaceUsedOf(String used, String total) {
    return '$used of $total';
  }

  @override
  String spaceFree(String free) {
    return '$free free';
  }

  @override
  String spaceTrash(String size) {
    return 'Trash · $size';
  }

  @override
  String fileCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files',
      one: '1 file',
      zero: 'No files',
    );
    return '$_temp0';
  }

  @override
  String get homeFolders => 'Your folders';

  @override
  String get homeRecentAlbums => 'Recent albums';

  @override
  String get folderEmpty => 'Empty';

  @override
  String get folderEmptyHint => 'Add files with “Add”, or drop them here.';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get dateUnknown => 'Unknown date';

  @override
  String get loginTitle => 'Connect your SafeBox to this computer';

  @override
  String get loginStep1 => 'Open Alanya on your phone.';

  @override
  String get loginStep2 => 'Go to Account & security › Link a new device.';

  @override
  String get loginStep3 => 'Scan this code, then confirm on your phone.';

  @override
  String get loginSharedComputer =>
      'On a shared computer, sign out when you leave (Settings › Sign out). You can also remove this computer remotely from \"Connected devices\" on your phone.';

  @override
  String get loginEndedRemotely =>
      'This computer was signed out. Scan the code again to use it.';

  @override
  String get loginQrLabel => 'Sign-in QR code';

  @override
  String get loginQrHint => 'The code changes every 90 seconds.';

  @override
  String get loginScannedTitle => 'Code scanned';

  @override
  String get loginScannedText => 'Confirm the sign-in on your phone.';

  @override
  String get loginDeniedTitle => 'Sign-in refused';

  @override
  String get loginDeniedText => 'The sign-in was refused on the phone.';

  @override
  String get loginExpiredTitle => 'Code expired';

  @override
  String get loginExpiredText => 'Show a new code to sign in.';

  @override
  String get loginNewCode => 'New code';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsComputerHint =>
      'Shown in \"Connected devices\" on your phone';

  @override
  String settingsConnectedOn(String date) {
    return 'Signed in on $date · shown in \"Connected devices\" on your phone';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String settingsVersion(String version) {
    return 'Alanya SafeBox $version';
  }

  @override
  String get logout => 'Sign out';

  @override
  String get logoutTitle => 'Sign out of this computer';

  @override
  String get logoutText =>
      'Erases everything the app keeps on this computer. Your files stay in your SafeBox.';

  @override
  String get logoutConfirmTitle => 'Sign out?';

  @override
  String get logoutConfirmText =>
      'The app erases what it keeps on this computer. Your files stay in your SafeBox; to come back, you\'ll scan the code again with your phone.';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get open => 'Open';

  @override
  String get empty => 'Empty';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get download => 'Download';

  @override
  String get downloadFolder => 'Download folder';

  @override
  String downloadSaved(String path) {
    return 'Saved: $path';
  }

  @override
  String get downloadFailed => 'The download didn\'t finish. Try again.';

  @override
  String get showInFolder => 'Show in folder';

  @override
  String get openWith => 'Open with…';

  @override
  String get openFailed => 'No app on this computer can open this file.';

  @override
  String viewerPosition(int index, int total) {
    return '$index of $total';
  }

  @override
  String get viewerKeys =>
      '← → to move between files · scroll to zoom · Esc to close';

  @override
  String get viewerCannotShow => 'This computer can\'t show this photo here.';

  @override
  String get viewerVideoHint => 'The video opens in the computer\'s player.';

  @override
  String get viewerAudioHint => 'The audio opens in the computer\'s player.';

  @override
  String get viewerDocumentHint =>
      'The document opens with the computer\'s app.';

  @override
  String get viewerPlay => 'Play';

  @override
  String get fileLost =>
      'This file can\'t be found at the host: it can no longer be opened.';

  @override
  String get noteNone => 'No comment.';

  @override
  String get noteAdd => 'Add a comment';

  @override
  String get noteEdit => 'Edit comment';

  @override
  String get noteEditTitle => 'Comment';

  @override
  String get noteHint => 'A few words about this file (up to 200 characters)';

  @override
  String get noteAudio => 'Audio comment';

  @override
  String get noteListen => 'Listen to the audio comment';

  @override
  String exportRunning(String name) {
    return 'Downloading $name';
  }

  @override
  String exportRunningMany(String name, int done, int total) {
    return 'Downloading $name: $done of $total';
  }

  @override
  String exportDone(String name) {
    return '$name is on this computer';
  }

  @override
  String exportFailed(String name) {
    return '$name couldn\'t be downloaded';
  }

  @override
  String exportCancelled(String name) {
    return 'Download of $name stopped';
  }

  @override
  String get settingsFiles => 'Files on this computer';

  @override
  String get settingsDownloadFolder => 'Download folder';

  @override
  String get settingsKeptFiles => 'Files kept for the viewer';

  @override
  String settingsKeptFilesSize(String size) {
    return '$size · downloaded again when needed';
  }

  @override
  String get add => 'Add';

  @override
  String get addFiles => 'Files…';

  @override
  String get addFolder => 'A folder…';

  @override
  String dropHere(String folder) {
    return 'Drop here to add to $folder';
  }

  @override
  String importScanning(int n) {
    return 'Looking at the files… $n';
  }

  @override
  String importChecking(int done, int total) {
    return 'Comparing with your SafeBox… $done / $total';
  }

  @override
  String importPreparing(int done, int total) {
    return 'Preparing uploads… $done / $total';
  }

  @override
  String importTitle(String folder) {
    return 'Add to $folder';
  }

  @override
  String importSend(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files to upload',
      one: '1 file to upload',
    );
    return '$_temp0 · $size';
  }

  @override
  String importLink(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          '$n files already in your SafeBox, added to the album without uploading them again',
      one:
          '1 file already in your SafeBox, added to the album without uploading it again',
    );
    return '$_temp0';
  }

  @override
  String importAlready(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files already in your SafeBox, not uploaded again',
      one: '1 file already in your SafeBox, not uploaded again',
    );
    return '$_temp0';
  }

  @override
  String importDiverted(int n, String root) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files will go to $root, the folder for their type',
      one: '1 file will go to $root, the folder for its type',
    );
    return '$_temp0';
  }

  @override
  String importTooLarge(int n, String max) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files are over $max and won\'t be uploaded',
      one: '1 file is over $max and won\'t be uploaded',
    );
    return '$_temp0';
  }

  @override
  String importIgnored(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hidden, empty or shortcut files left out',
      one: '1 hidden, empty or shortcut file left out',
    );
    return '$_temp0';
  }

  @override
  String importFree(String size) {
    return 'Free space in your SafeBox: $size';
  }

  @override
  String importNoRoom(String size) {
    return 'Not enough space: $size short. Empty the trash or add fewer files.';
  }

  @override
  String get importOriginal =>
      'Files are uploaded in Original quality, exactly as they are on the computer. They stay on the computer.';

  @override
  String get importNothing =>
      'Nothing to upload: everything is already in your SafeBox.';

  @override
  String get importStart => 'Upload';

  @override
  String get importFailed => 'The files couldn\'t be read.';

  @override
  String get importBusy => 'Files are already being prepared.';

  @override
  String get uploadsTitle => 'Uploads to your SafeBox';

  @override
  String uploadsRunning(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Uploading $n files',
      one: 'Uploading 1 file',
    );
    return '$_temp0';
  }

  @override
  String uploadsDone(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files added to your SafeBox',
      one: '1 file added to your SafeBox',
    );
    return '$_temp0';
  }

  @override
  String uploadsFailed(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n uploads didn\'t finish',
      one: '1 upload didn\'t finish',
    );
    return '$_temp0';
  }

  @override
  String uploadsPaused(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n uploads paused',
      one: '1 upload paused',
    );
    return '$_temp0';
  }

  @override
  String get uploadsWaitingNetwork => 'Waiting for the network';

  @override
  String get pauseAll => 'Pause all';

  @override
  String get resumeAll => 'Resume all';

  @override
  String get details => 'Details';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get clearFinished => 'Clear finished';

  @override
  String speed(String size) {
    return '$size/s';
  }

  @override
  String get uploadQueued => 'Waiting';

  @override
  String get uploadPaused => 'Paused';

  @override
  String get uploadDone => 'In your SafeBox';

  @override
  String get uploadErrorQuota => 'Not enough space in your SafeBox';

  @override
  String get uploadErrorChanged =>
      'The file changed on the computer during the upload';

  @override
  String get uploadErrorMissing => 'The file is no longer on the computer';

  @override
  String get uploadErrorGeneric => 'The upload didn\'t finish';

  @override
  String get change => 'Change';

  @override
  String get newFolder => 'New folder';

  @override
  String get newAlbum => 'New album';

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get albumNameLabel => 'Album name';

  @override
  String get fileNameLabel => 'File name';

  @override
  String get create => 'Create';

  @override
  String get rename => 'Rename';

  @override
  String get move => 'Move…';

  @override
  String get moveTitle => 'Move to';

  @override
  String get moveHere => 'Move here';

  @override
  String get addToAlbum => 'Add to an album…';

  @override
  String get addToAlbumTitle => 'Add to an album';

  @override
  String get addHere => 'Add here';

  @override
  String addedToAlbum(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files added to the album, without a copy',
      one: '1 file added to the album, without a copy',
    );
    return '$_temp0';
  }

  @override
  String moved(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items moved',
      one: '1 item moved',
    );
    return '$_temp0';
  }

  @override
  String get toTrash => 'Move to trash';

  @override
  String movedToTrash(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items moved to the trash',
      one: '1 item moved to the trash',
    );
    return '$_temp0';
  }

  @override
  String deleteWhich(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Some of these files are also somewhere else in your SafeBox',
      one: 'This file is also somewhere else in your SafeBox',
    );
    return '$_temp0';
  }

  @override
  String deleteHereOnly(String place) {
    return 'Remove from “$place” only';
  }

  @override
  String deleteHereOnlyHint(String other) {
    return 'It stays in “$other”. No space is freed.';
  }

  @override
  String get deleteEverywhere => 'Delete everywhere';

  @override
  String get deleteEverywhereHint =>
      'It goes to the trash; the space is freed when the trash is emptied.';

  @override
  String selectedCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items selected',
      one: '1 item selected',
    );
    return '$_temp0';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get folderKeysHint =>
      'Double-click to open · Ctrl or Shift + click to select · Delete: trash · F2: rename · right-click: menu';

  @override
  String get errorNameTaken => 'This name is already used in this folder.';

  @override
  String get errorWrongFamily =>
      'This folder doesn\'t accept this type of file.';

  @override
  String get errorInvalidMove => 'A folder can\'t go inside itself.';

  @override
  String get errorTooDeep => 'Too many folder levels.';

  @override
  String get errorFolderLimit => 'Too many folders in your SafeBox.';

  @override
  String get errorInvalidName => 'This name isn\'t valid.';

  @override
  String get errorRootLocked =>
      'Main folders can\'t be renamed, moved or deleted.';

  @override
  String get errorNotFound => 'This item no longer exists.';

  @override
  String get navTrash => 'Trash';

  @override
  String get trashEmptyState => 'The trash is empty';

  @override
  String trashHint(int days) {
    return 'Items stay in the trash for $days days, then are deleted for good. They count towards your space until then.';
  }

  @override
  String get emptyTrash => 'Empty the trash';

  @override
  String get emptyTrashConfirm =>
      'Everything in the trash will be deleted for good. This can\'t be undone.';

  @override
  String get restore => 'Restore';

  @override
  String get restored => 'Restored';

  @override
  String get deleteForever => 'Delete for good';

  @override
  String deleteForeverConfirm(String name) {
    return '“$name” will be deleted for good.';
  }

  @override
  String trashPurgeIn(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Deleted for good in $n days',
      one: 'Deleted for good tomorrow',
      zero: 'Deleted for good today',
    );
    return '$_temp0';
  }

  @override
  String trashFrom(String place) {
    return 'From $place';
  }

  @override
  String get freeUp => 'Free up space';

  @override
  String get freeUpIntro =>
      'The largest files in your SafeBox. The ones you choose are removed everywhere, albums included, so their space is really freed.';

  @override
  String get freeUpHint =>
      'Files in the trash still count towards your space until the trash is emptied.';

  @override
  String freeUpSelected(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files',
      one: '1 file',
    );
    return '$_temp0 · $size';
  }

  @override
  String freeUpTrash(String size) {
    return 'The trash takes up $size';
  }

  @override
  String get freeUpNothing => 'No files in your SafeBox';

  @override
  String get navPcBackup => 'PC backup';

  @override
  String get pcBackupIntro =>
      'Each chosen folder is recreated in Albums with its subfolders, and its files also show up in Photos, Videos, Audio or Documents, using no extra space. A file deleted from the PC stays in your SafeBox; a file deleted from your SafeBox doesn\'t come back.';

  @override
  String get pcBackupSwitch => 'Back up these folders automatically';

  @override
  String get pcBackupOpenOnly =>
      'While the app is open: a pass at startup, after each change in the folders, and every 15 minutes. In Original quality.';

  @override
  String get pcBackupFolders => 'Backed-up folders';

  @override
  String get pcBackupAddFolder => 'Add a folder…';

  @override
  String get pcBackupNoFolder =>
      'No folder chosen yet. Add Pictures or Documents, for example.';

  @override
  String get pcBackupRemoveFolder => 'Stop backing up this folder';

  @override
  String pcBackupRemoveConfirm(String name) {
    return '“$name” will no longer be backed up. What\'s already in your SafeBox stays there.';
  }

  @override
  String get pcBackupFolderMissing => 'Folder not found on this PC';

  @override
  String get pcBackupAlreadyAdded => 'This folder is already backed up.';

  @override
  String get pcBackupNoType => 'Choose at least one type of file.';

  @override
  String get pcBackupRunNow => 'Back up now';

  @override
  String get pcBackupListing => 'Reading the folders…';

  @override
  String pcBackupChecking(int done, int total) {
    return 'Comparing with your SafeBox… $done / $total';
  }

  @override
  String pcBackupRemaining(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files to upload',
      one: '1 file to upload',
      zero: 'Up to date',
    );
    return '$_temp0';
  }

  @override
  String pcBackupLast(String time) {
    return 'Last pass: $time';
  }

  @override
  String get pcBackupNever => 'No pass yet';

  @override
  String get pcBackupOff => 'Backup is off';

  @override
  String pcBackupQueued(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files uploaded',
      one: '1 file uploaded',
      zero: 'nothing new',
    );
    return '$_temp0';
  }

  @override
  String pcBackupAlready(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n already in your SafeBox',
      one: '1 already in your SafeBox',
    );
    return '$_temp0';
  }

  @override
  String pcBackupSkipped(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n deleted from your SafeBox, not uploaded again',
      one: '1 deleted from your SafeBox, not uploaded again',
    );
    return '$_temp0';
  }

  @override
  String pcBackupNoRoom(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files are waiting for space in your SafeBox',
      one: '1 file is waiting for space in your SafeBox',
    );
    return '$_temp0';
  }

  @override
  String pcBackupUnreadable(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n unreadable files',
      one: '1 unreadable file',
    );
    return '$_temp0';
  }

  @override
  String pcBackupFailed(String reason) {
    return 'The last pass didn\'t finish. $reason';
  }

  @override
  String pcBackupEstimateTitle(String name) {
    return 'Back up “$name”';
  }

  @override
  String get pcBackupTypes => 'What\'s backed up:';

  @override
  String pcBackupEstimate(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n files · $size',
      one: '1 file · $size',
      zero: 'No files of these types yet.',
    );
    return '$_temp0';
  }

  @override
  String get pcBackupEstimateHint =>
      'What\'s already in your SafeBox (backed up from your phone, for example) won\'t be uploaded again, so the real upload may be smaller. The newest files go first; if space runs out, the oldest wait.';

  @override
  String get pcBackupStart => 'Back up';

  @override
  String get pcBackupHome => 'PC backup';

  @override
  String updateAvailable(String version) {
    return 'Version $version of Alanya SafeBox is available.';
  }

  @override
  String get updateDownload => 'Download';

  @override
  String get updateLater => 'Later';

  @override
  String get filterWithNote => 'With a comment';

  @override
  String get filterAll => 'All';

  @override
  String get folderCamera => 'Camera';

  @override
  String get folderScreenshots => 'Screenshots';

  @override
  String get folderDownloads => 'Downloaded images';

  @override
  String get pcRemoveTitle => 'Remove from the computer after backup';

  @override
  String get pcRemoveHint =>
      'Photos and videos kept in Original quality in your SafeBox go to the computer\'s trash, where you can get them back until it\'s emptied. Documents and audio files stay on the computer.';

  @override
  String get pcRemoveWhen => 'When to remove them';

  @override
  String pcRemoveAfter(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'After $n days',
      one: 'After 1 day',
    );
    return '$_temp0';
  }

  @override
  String get pcRemoveNow => 'Right away';

  @override
  String get pcRemoveConfirmTitle => 'Remove from the computer?';

  @override
  String get pcRemoveConfirm =>
      'Once they\'re in your SafeBox in Original quality, and checked with the server just before, photos and videos from the backed-up folders go to the computer\'s trash. You can get them back from the trash until you empty it, and always from your SafeBox.';

  @override
  String get pcRemoveConfirmAction => 'Turn on';

  @override
  String pcRemoved(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n photos and videos moved to the computer\'s trash',
      one: '1 photo or video moved to the computer\'s trash',
    );
    return '$_temp0 · $size freed';
  }

  @override
  String get pcBackupRename => 'Rename';

  @override
  String get pcBackupNameLabel => 'Name in your SafeBox';

  @override
  String get pcBackupRenameHint =>
      'The folder takes this name in your SafeBox (its album in Albums, and the source folder in Photos and Videos). The folder on the computer doesn\'t change, and the backup carries on.';
}
