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

  /// Forme XXYYZZTT (ex. 11223344).
  static bool isXxyyzztt(String canonical) {
    return canonical.length == 8 &&
        RegExp(r'^\d{8}$').hasMatch(canonical) &&
        canonical[0] == canonical[1] &&
        canonical[2] == canonical[3] &&
        canonical[4] == canonical[5] &&
        canonical[6] == canonical[7];
  }

  /// Patterns réservés : 3 ch., 4 ch., ou 8 ch. XXYYZZTT.
  static bool isPatternReserved(String canonical) {
    if (canonical.isEmpty || !RegExp(r'^\d+$').hasMatch(canonical)) {
      return false;
    }
    final len = canonical.length;
    if (len == 3 || len == 4) return true;
    if (len == 8) return isXxyyzztt(canonical);
    return false;
  }

  static String? validateReservedCandidate(String canonical) {
    final err = validate(canonical);
    if (err != null) return err;
    if (!isPatternReserved(canonical)) {
      return 'Réservation limitée aux numéros 3 ou 4 chiffres, '
          'ou 8 chiffres au format XXYYZZTT (ex. 11 22 33 44)';
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

  static bool isCompletePhone(String canonical) => validate(canonical) == null;

  static bool isAssignableQuery(String q) {
    final digits = normalize(q);
    return digits.isNotEmpty && isCompletePhone(digits);
  }
}
