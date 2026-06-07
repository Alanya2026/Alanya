// Upload de fichiers (avatar, médias de chat) — part of talky_api_client.dart.
part of '../talky_api_client.dart';

extension MediaApi on TalkyApiClient {
  Future<Map<String, dynamic>> uploadAvatar(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('${TalkyApiClient.baseUrl}/upload/avatar'));
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(await _multipartFile('file', file));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw TalkyException(jsonDecode(response.body)['error'] ?? 'Upload échoué', response.statusCode);
  }

  Future<Map<String, dynamic>> uploadMedia(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('${TalkyApiClient.baseUrl}/upload/media'));
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(await _multipartFile('file', file));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw TalkyException(jsonDecode(response.body)['error'] ?? 'Upload échoué', response.statusCode);
  }
}
