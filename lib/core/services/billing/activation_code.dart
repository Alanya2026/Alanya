/// Format des codes d'activation, côté téléphone.
///
/// Miroir de la règle du serveur (Alanya-Backend,
/// src/services/billing/codeFormat.js) : mêmes symboles, même contrôle. Le
/// serveur tranche toujours — vérifier ici ne sert qu'à refuser une faute de
/// frappe sans aller-retour, et sans qu'elle compte comme un essai.
library;

/// Alphabet Crockford : ni I, L, O ni U (confondus avec 1 et 0, ou grossiers).
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// 14 symboles de données et un symbole de contrôle.
const kActivationCodeLength = 15;

enum ActivationCodeIssue {
  /// Longueur ou symbole impossible.
  format,

  /// Bien formé, mais le contrôle échoue : une faute de frappe.
  checksum,
}

/// Poids impairs, modulo 32 : un poids impair est premier avec 32, donc la
/// substitution d'un seul symbole change toujours le contrôle.
String _checkSymbol(String data) {
  var sum = 0;
  for (var i = 0; i < data.length; i++) {
    sum += _alphabet.indexOf(data[i]) * (2 * i + 1);
  }
  return _alphabet[sum % 32];
}

/// Ramène une saisie à sa forme canonique : majuscules, séparateurs ignorés,
/// confusions usuelles corrigées (O→0, I et L→1).
String _clean(String input) => input
    .toUpperCase()
    .replaceAll(RegExp(r'[\s\-_.]'), '')
    .replaceAll('O', '0')
    .replaceAll(RegExp(r'[IL]'), '1');

/// Le résultat de la lecture d'une saisie : le code canonique, ou ce qui cloche.
typedef ActivationCodeParse = ({String? canonical, ActivationCodeIssue? issue});

ActivationCodeParse parseActivationCode(String input) {
  final cleaned = _clean(input);
  if (cleaned.length != kActivationCodeLength) {
    return (canonical: null, issue: ActivationCodeIssue.format);
  }
  for (final c in cleaned.split('')) {
    if (!_alphabet.contains(c)) {
      return (canonical: null, issue: ActivationCodeIssue.format);
    }
  }
  final data = cleaned.substring(0, kActivationCodeLength - 1);
  if (_checkSymbol(data) != cleaned[kActivationCodeLength - 1]) {
    return (canonical: null, issue: ActivationCodeIssue.checksum);
  }
  return (canonical: cleaned, issue: null);
}

/// La saisie en cours, mise en forme `XXXXX-XXXXX-XXXXX` au fil de la frappe :
/// seuls les symboles valides restent, quinze au plus, un tiret tous les cinq.
String formatActivationInput(String raw) {
  final kept = StringBuffer();
  for (final c in _clean(raw).split('')) {
    if (_alphabet.contains(c)) kept.write(c);
    if (kept.length >= kActivationCodeLength) break;
  }
  final s = kept.toString();
  final groups = <String>[
    for (var i = 0; i < s.length; i += 5)
      s.substring(i, i + 5 > s.length ? s.length : i + 5),
  ];
  return groups.join('-');
}
