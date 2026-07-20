import '../theme/locale_controller.dart';

class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  AppException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'AppException: $message';
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.statusCode});
}

class NetworkException extends AppException {
  NetworkException(super.message) : super(code: 'NETWORK_ERROR');
}

class TokenExpiredException extends AuthException {
  TokenExpiredException() : super(LocaleController.instance.l10n.sessionExpired, code: 'TOKEN_EXPIRED', statusCode: 401);
}
