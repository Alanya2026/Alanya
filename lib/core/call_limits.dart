import 'theme/locale_controller.dart';

/// Limites de participants pour appels de groupe et réunions.
abstract final class CallLimits {
  static const int maxVideoParticipants = 4;
  static const int maxAudioParticipants = 6;

  /// Nombre total max (initiateur/organisateur inclus).
  static int maxParticipants({required bool isVideo}) =>
      isVideo ? maxVideoParticipants : maxAudioParticipants;

  /// Nombre max sélectionnable hors initiateur/organisateur.
  static int maxSelectable({required bool isVideo}) =>
      maxParticipants(isVideo: isVideo) - 1;

  /// Réunion : [typeMedia] 0 = vidéo, 1 = audio seul.
  static int maxParticipantsForMeeting(int typeMedia) =>
      maxParticipants(isVideo: typeMedia == 0);

  static int maxSelectableForMeeting(int typeMedia) =>
      maxParticipantsForMeeting(typeMedia) - 1;

  static String mediaLabel({required bool isVideo}) {
    final l10n = LocaleController.instance.l10n;
    return isVideo ? l10n.mediaLabelVideo : l10n.mediaLabelAudio;
  }

  static String limitReachedMessage({required bool isVideo}) {
    final total = maxParticipants(isVideo: isVideo);
    return LocaleController.instance.l10n.limitReachedParticipants(
      total,
      mediaLabel(isVideo: isVideo),
    );
  }
}
