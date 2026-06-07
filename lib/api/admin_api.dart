// Endpoints d'administration (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension AdminApi on TalkyApiClient {
  Future<Map<String, dynamic>> adminGetUsers({
    String? search,
    String? status,
    String? from,
    String? to,
    int? idPays,
    String sort = 'created_at',
    String order = 'desc',
    int page = 1,
    int limit = 20,
  }) async {
    final q = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'sort': sort,
      'order': order,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      if (idPays != null) 'idPays': '$idPays',
    };
    final uri = Uri.parse('${TalkyApiClient.baseUrl}/admin/users').replace(queryParameters: q);
    final data = await _handleRequest(() => _client.get(uri, headers: _headers));
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetStats({String? from, String? to}) async {
    final q = <String, String>{
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
    };
    final uri = Uri.parse('${TalkyApiClient.baseUrl}/admin/stats').replace(queryParameters: q);
    final data = await _handleRequest(() => _client.get(uri, headers: _headers));
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetUserById(int userId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/admin/users/$userId'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminGetUserActivity(int userId) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/admin/users/$userId/activity'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> adminGetUserLogins(int userId, {int limit = 50}) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/admin/users/$userId/logins?limit=$limit'),
        headers: _headers,
      ),
    );
    return data is List ? data : [];
  }

  Future<void> adminBanUser(int userId, {String? reason}) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/admin/users/$userId/ban'),
        headers: _headers,
        body: jsonEncode({if (reason != null) 'reason': reason}),
      ),
    );
  }

  Future<void> adminUnbanUser(int userId) async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/admin/users/$userId/ban'),
        headers: _headers,
      ),
    );
  }

  Future<void> adminSetAccountType(int userId, {required int typeCompte}) async {
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/admin/users/$userId/role'),
        headers: _headers,
        body: jsonEncode({'type_compte': typeCompte}),
      ),
    );
  }

  Future<void> adminDeleteUser(int userId) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('${TalkyApiClient.baseUrl}/admin/users/$userId'), headers: _headers),
    );
  }
}
