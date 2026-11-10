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
}
