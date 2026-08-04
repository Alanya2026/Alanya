/// Raison de la fin de session — permet à [AuthWrapper] de ne vider le cache
/// local que sur un logout explicite, pas sur une expiration de token.
enum SessionEndReason {
  none,
  explicitLogout,
  tokenExpired,

  /// Cet appareil a été déconnecté depuis un autre appareil du compte
  /// (écran « Appareils connectés »). Traité comme un logout explicite : c'est
  /// bien une décision de l'utilisateur, le cache local doit partir avec.
  revokedRemotely,
}

/// Dernière raison de fin de session (lue par AuthWrapper / LoginScreen).
SessionEndReason currentSessionEndReason = SessionEndReason.none;
