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

  /// Délègue à [AlanyaPhoneFormatter.validate] (numéro canonique).
  static String? alanyaPhone(String? canonical, {AppLocalizations? l10n}) {
    if (canonical == null || canonical.trim().isEmpty) {
      return l10n?.validatorRequired ?? LocaleController.instance.l10n.validatorRequired;
    }
    return AlanyaPhoneFormatter.validate(canonical.trim());
  }
}
