// Code QR d'identité et résolution d'un code scanné (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension QrApi on TalkyApiClient {
  /// Code QR d'identité de l'utilisateur connecté.
  Future<QrIdentity> getMyQr() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/qr/me'),
        headers: _headers,
      ),
    );
    return QrIdentity.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Invalide l'ancien code d'identité et en émet un nouveau.
  Future<QrIdentity> regenerateQr() async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/qr/me/regenerate'),
        headers: _headers,
      ),
    );
    return QrIdentity.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Envoie la chaîne scannée telle quelle : le serveur est seul juge du type
  /// de payload (identité ou connexion). On retient uniquement le scanSecret
  /// qu'on vient de lire, indispensable pour approuver ensuite la session —
  /// le serveur ne le renvoie pas, il l'a déjà.
  /// Génère mon code d'ajout de contact éphémère (10 minutes, usage unique).
  /// Un seul code actif : en générer un nouveau invalide le précédent.
  Future<QrContactCode> createContactQr() async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/qr/contact-token'),
        headers: _headers,
      ),
    );
    return QrContactCode.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<QrResolveResult> resolveQr(String rawPayload) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/qr/resolve'),
        headers: _headers,
        body: jsonEncode({'payload': rawPayload}),
      ),
    );
    final map = Map<String, dynamic>.from(data as Map);
    return QrResolveResult.fromJson(
      map,
      scanSecret: map['type'] == 'login'
          ? _qrScanSecretFromPayload(rawPayload)
          : null,
    );
  }
}

/// Extrait le scanSecret d'un payload de connexion `…/q/l/<sessionId>.<scanSecret>`.
/// Retourne null si la chaîne n'a pas cette forme : le serveur ayant déjà validé
/// le payload, on préfère un secret absent à un secret inventé.
String? _qrScanSecretFromPayload(String rawPayload) {
  final trimmed = rawPayload.trim();
  final lastSlash = trimmed.lastIndexOf('/');
  final segment = lastSlash >= 0 ? trimmed.substring(lastSlash + 1) : trimmed;
  final dot = segment.indexOf('.');
  if (dot <= 0 || dot == segment.length - 1) return null;
  return segment.substring(dot + 1);
}
