/// Bio affichée / enregistrée quand l'utilisateur n'en renseigne pas.
class ProfileBio {
  ProfileBio._();

  static String display(String bio, String defaultText) {
    final trimmed = bio.trim();
    return trimmed.isEmpty ? defaultText : trimmed;
  }

  static String valueToSave(String input, String defaultText) {
    final trimmed = input.trim();
    return trimmed.isEmpty ? defaultText : trimmed;
  }
}
