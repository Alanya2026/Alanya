class AlanyaPhoneFormatter {
  static const validLengths = [3, 4, 8];

  static String normalize(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static int? getTier(String canonical) {
    if (validLengths.contains(canonical.length)) return canonical.length;
    return null;
  }

  static String? validate(String canonical) {
    if (canonical.isEmpty) return 'Numéro Alanya requis';
    if (!RegExp(r'^\d+$').hasMatch(canonical)) {
      return 'Le numéro ne doit contenir que des chiffres';
    }
    if (getTier(canonical) == null) {
      return 'Numéro invalide : 3, 4 ou 8 chiffres requis';
    }
    return null;
  }

  static String formatDisplay(String? canonical) {
    final digits = normalize(canonical);
    if (digits.isEmpty) return '';
    final tier = getTier(digits);
    if (tier == 3) return digits;
    if (tier == 4) return _groupDigits(digits, const [2, 2]);
    if (tier == 8) return _groupDigits(digits, const [2, 2, 2, 2]);
    return digits;
  }

  static String formatLiveInput(String input) {
    final digits = normalize(input);
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return digits;
    if (digits.length <= 4) return _groupDigits(digits, const [2, 2]);
    // Longueurs intermédiaires 5–7 (et 8) : ne pas appeler substring(0, 8)
    // si la chaîne est plus courte — RangeError et écran gris sur le pavé.
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;
    return _groupDigits(limited, const [2, 2, 2, 2]);
  }

  static String _groupDigits(String digits, List<int> groups) {
    final parts = <String>[];
    var i = 0;
    for (final size in groups) {
      if (i >= digits.length) break;
      final end = (i + size > digits.length) ? digits.length : i + size;
      parts.add(digits.substring(i, end));
      i += size;
    }
    if (i < digits.length) {
      parts.add(digits.substring(i));
    }
    return parts.join(' ');
  }

  static bool isNumericQuery(String q) =>
      RegExp(r'^\d+$').hasMatch(normalize(q));
}
