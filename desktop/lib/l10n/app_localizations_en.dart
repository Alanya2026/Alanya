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
  String get folderEmptyHint => 'Add files from your phone.';

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
}
