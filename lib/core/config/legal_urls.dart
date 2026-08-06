/// URLs et contacts légaux affichés dans « À propos » et les écrans RGPD.
abstract final class LegalUrls {
  static const String baseHost = 'https://www.alanya237.com';

  static const String termsOfService = '$baseHost/legal/terms';
  static const String privacyPolicy = '$baseHost/legal/privacy';
  static const String openSourceLicenses = '$baseHost/legal/licenses';
  static const String supportEmail = 'support@alanya237.com';
  static Uri get supportMailto => Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: 'subject=Support%20Alanya',
      );
}
