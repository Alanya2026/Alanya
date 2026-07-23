/// Raison de la fin de session — permet à [AuthWrapper] de ne vider le cache
/// local que sur un logout explicite, pas sur une expiration de token.
enum SessionEndReason {
  none,
  explicitLogout,
  tokenExpired,
}

/// Dernière raison de fin de session (lue par AuthWrapper / LoginScreen).
SessionEndReason currentSessionEndReason = SessionEndReason.none;
