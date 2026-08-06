// Endpoints utilisateurs, blocage et contacts préférés (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension UsersApi on TalkyApiClient {
  // ── USERS ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserById(int alanyaID) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/users/$alanyaID'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUserByPhone(String phone) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/users/phone/$phone'), headers: _headers),
    );
    return data is List ? data : [data];
  }

  Future<List<dynamic>> searchUsers(String query) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/users/search?q=$query'), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<void> blockUser(int userId) async {
    await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/users/$userId/block'), headers: _headers),
    );
  }

  Future<void> unblockUser(int userId) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('${TalkyApiClient.baseUrl}/users/$userId/block'), headers: _headers),
    );
  }

  Future<({bool isBlocked, bool blockedByThem})> getBlockStatus(int userId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/users/$userId/block'), headers: _headers),
    );
    final map = data as Map<String, dynamic>;
    return (
      isBlocked: map['isBlocked'] == true,
      blockedByThem: map['blockedByThem'] == true,
    );
  }

  Future<List<dynamic>> getBlockedUsers() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/users/blocked'), headers: _headers),
    );
    return data is List ? data : [];
  }

  // ── CONTACTS PRÉFÉRÉS ─────────────────────────────────────────────

  Future<List<dynamic>> getContacts() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/contacts'), headers: _headers),
    );
    return data is List ? data : [];
  }

  /// [viaQr] marque l'ajout comme issu d'un code QR — utilisé par l'ajout EN
  /// RETOUR après un scan, pour que les deux directions du lien portent la
  /// même origine (pastille, filtre « Par QR »).
  Future<Map<String, dynamic>> addContact(int userId, {bool viaQr = false}) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/contacts/$userId'),
        headers: _headers,
        body: viaQr ? jsonEncode({'addedVia': 'qr'}) : null,
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Pose ou remplace la note contextuelle d'un contact préféré. Vide pour
  /// effacer.
  Future<void> setContactNote(int userId, String note) async {
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/contacts/$userId/note'),
        headers: _headers,
        body: jsonEncode({'note': note}),
      ),
    );
  }

  Future<void> removeContact(int userId) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('${TalkyApiClient.baseUrl}/contacts/$userId'), headers: _headers),
    );
  }

  Future<bool> checkIsContact(int userId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/contacts/check/$userId'), headers: _headers),
    );
    return (data as Map<String, dynamic>)['isContact'] == true;
  }
}
