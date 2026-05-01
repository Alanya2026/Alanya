class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  AppException(this.message, {this.code, this.statusCode});

  @override
  String toString() => 'AppException: $message';
}

class AuthException extends AppException {
  AuthException(String message, {String? code, int? statusCode})
      : super(message, code: code, statusCode: statusCode);
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message, code: 'NETWORK_ERROR');
}

class TokenExpiredException extends AuthException {
  TokenExpiredException() : super('Session expired', code: 'TOKEN_EXPIRED', statusCode: 401);
}
