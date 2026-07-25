/// Distingue un message vocal enregistré au micro d'un fichier musical
/// importé. Les deux sont des messages `type = 3` : le discriminant est
/// l'extension portée par `mediaName`.
///
/// C'est fiable parce qu'un vocal enregistré porte toujours
/// `mediaName = l10n.voiceMessage` (« Message vocal »), une chaîne localisée
/// sans extension, tandis qu'un fichier importé conserve son nom réel.
enum AudioMessageKind { voiceNote, music }

/// Extensions traitées comme de la musique.
///
/// Miroir de la liste de `src/utils/messagePreview.js` côté backend —
/// garder les deux alignées.
const Set<String> kMusicExtensions = {
  'mp3', 'm4a', 'm4b', 'aac', 'wav', 'flac', 'ogg', 'oga', 'opus',
  'wma', 'aiff', 'aif', 'caf', 'amr', 'weba', 'mid', 'midi', 'alac',
};

/// Ne jamais appeler avec un chemin de fichier : un vocal est stagé en
/// `voice_<timestamp>.m4a` et serait pris pour de la musique.
AudioMessageKind audioKindFromName(String? mediaName) {
  return musicExtensionOf(mediaName) != null
      ? AudioMessageKind.music
      : AudioMessageKind.voiceNote;
}

/// Extension musicale en minuscules (`mp3`), ou `null` si le nom n'en porte
/// pas ou qu'elle n'est pas reconnue.
String? musicExtensionOf(String? mediaName) {
  if (mediaName == null || mediaName.isEmpty) return null;
  final base = mediaName.split('/').last.split('?').first;
  final dot = base.lastIndexOf('.');
  if (dot < 0 || dot >= base.length - 1) return null;
  final ext = base.substring(dot + 1).toLowerCase().trim();
  return kMusicExtensions.contains(ext) ? ext : null;
}

/// Nom affiché d'un morceau : nom de fichier privé de son extension.
String musicTitleFromName(String? mediaName, {required String fallback}) {
  if (mediaName == null || mediaName.trim().isEmpty) return fallback;
  final name = mediaName.trim();
  if (musicExtensionOf(name) == null) return name;
  final dot = name.lastIndexOf('.');
  final title = name.substring(0, dot).trim();
  return title.isEmpty ? fallback : title;
}
