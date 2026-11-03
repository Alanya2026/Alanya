import 'alanya_phone_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../theme/locale_controller.dart';

/// Validateurs de formulaires réutilisables.
/// Passer [l10n] pour les messages localisés ; sinon fallback FR.
class Validators {
  Validators._();

  static String? required(String? v, {AppLocalizations? l10n}) {
    if (v == null || v.trim().isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    return null;
  }

  static String? email(String? v, {AppLocalizations? l10n}) {
    if (v == null || v.trim().isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : (l10n?.validatorEmail ?? LocaleController.instance.l10n.validatorEmail);
  }

  /// Email facultatif : vide = OK ; sinon même format que [email].
  static String? optionalEmail(String? v, {AppLocalizations? l10n}) {
    if (v == null || v.trim().isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : (l10n?.validatorEmail ?? LocaleController.instance.l10n.validatorEmail);
  }

  static String? minLength(
    String? v,
    int n, {
    AppLocalizations? l10n,
    String? message,
  }) {
    if (v == null || v.isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    if (v.length < n) {
      return message ?? l10n?.validatorMinLength(n) ?? LocaleController.instance.l10n.validatorMinLength(n);
    }
    return null;
  }

  /// Nom ou pseudo : au moins 3 caractères ; lettres de toutes écritures,
  /// chiffres, espace, tiret, apostrophe et tiret bas. La ponctuation
  /// (`. , ; : ! ? @`…) est refusée. Même règle que `accountInputRules.js`.
  static String? displayName(String? v, {AppLocalizations? l10n}) {
    final value = (v ?? '').trim();
    if (value.isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    if (value.runes.length < 3) {
      return l10n?.validatorMinLength(3) ?? LocaleController.instance.l10n.validatorMinLength(3);
    }
    if (!_displayNamePattern.hasMatch(value)) {
      return l10n?.validatorNameChars ?? LocaleController.instance.l10n.validatorNameChars;
    }
    return null;
  }

  static final _displayNamePattern =
      RegExp(r"^[\p{L}\p{M}\p{N} _'’-]+$", unicode: true);

  /// Nouveau mot de passe : au moins 6 caractères, sans espace.
  /// La connexion garde [minLength] : un ancien mot de passe peut en contenir.
  static String? newPassword(String? v, {AppLocalizations? l10n}) {
    final tooShort = minLength(v, 6, l10n: l10n);
    if (tooShort != null) return tooShort;
    if (RegExp(r'\s').hasMatch(v!)) {
      return l10n?.validatorPasswordNoSpaces ??
          LocaleController.instance.l10n.validatorPasswordNoSpaces;
    }
    return null;
  }

  static String? otp6(String? v, {AppLocalizations? l10n}) {
    if (v == null || v.trim().isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) {
      return l10n?.validatorOtp6 ?? LocaleController.instance.l10n.validatorOtp6;
    }
    return null;
  }

  static String? passwordMatch(
    String? v,
    String other, {
    AppLocalizations? l10n,
  }) {
    if (v == null || v.isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    if (v != other) {
      return l10n?.validatorPasswordMatch ??
          LocaleController.instance.l10n.validatorPasswordMatch;
    }
    return null;
  }

  /// Code de récupération : 12 caractères alphanumériques.
  ///
  /// La saisie est normalisée avant contrôle (majuscules, tirets et espaces
  /// retirés) exactement comme côté serveur : un code recopié depuis un papier
  /// arrive rarement avec la ponctuation d'origine, et refuser cette saisie-là
  /// serait refuser le cas normal.
  static String? recoveryCode(String? v, {AppLocalizations? l10n}) {
    final canonical =
        (v ?? '').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (canonical.isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    if (canonical.length != 12) {
      return l10n?.validatorRecoveryCode ??
          LocaleController.instance.l10n.validatorRecoveryCode;
    }
    return null;
  }

  /// Délègue à [AlanyaPhoneFormatter.validate] (numéro canonique).
  static String? alanyaPhone(String? canonical, {AppLocalizations? l10n}) {
    if (canonical == null || canonical.trim().isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    return AlanyaPhoneFormatter.validate(canonical.trim());
  }
}
