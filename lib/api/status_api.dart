// Endpoints statuts / stories (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension StatusApi on TalkyApiClient {
  Future<List<dynamic>> getStatuts() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/status'), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<List<dynamic>> getMyStatuts() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/status/me'), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> createStatut({
    String? text,
    String? mediaUrl,
    String? backgroundColor,
    int type = 0,
    int? mediaDurationMs,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/status'),
        headers: _headers,
        body: jsonEncode({
          if (text != null) 'text': text,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (backgroundColor != null) 'backgroundColor': backgroundColor,
          if (mediaDurationMs != null) 'mediaDurationMs': mediaDurationMs,
          'type': type,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> deleteStatut(int id) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('${TalkyApiClient.baseUrl}/status/$id'), headers: _headers),
    );
  }

  Future<Map<String, dynamic>> viewStatut(int id) async {
    final data = await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/status/$id/view'), headers: _headers),
    );
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<dynamic>> getStatutViews(int id) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/status/$id/views'), headers: _headers),
    );
    return data is List ? data : [];
  }

  Future<void> likeStatut(int id) async {
    await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/status/$id/like'), headers: _headers),
    );
  }

  Future<void> unlikeStatut(int id) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('${TalkyApiClient.baseUrl}/status/$id/like'), headers: _headers),
    );
  }
}
