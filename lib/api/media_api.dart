// Upload de fichiers (avatar, médias de chat) — part of talky_api_client.dart.
part of '../talky_api_client.dart';

extension MediaApi on TalkyApiClient {
  /// Héberge une image côté serveur et retourne `{ url, filename }`.
  /// Ne met pas à jour le profil — utiliser [AuthProvider.updateAvatar] pour un avatar personnel.
  Future<Map<String, dynamic>> uploadImage(File file) async {
    final request = http.MultipartRequest('POST', Uri.parse('${TalkyApiClient.baseUrl}/upload/avatar'));
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(await _multipartFile('file', file));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw uploadHttpException(response);
  }

  /// Alias de [uploadImage] — préférer [uploadImage] hors contexte profil.
  Future<Map<String, dynamic>> uploadAvatar(File file) => uploadImage(file);

  Future<Map<String, dynamic>> uploadMedia(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final timeout = uploadTimeoutForFileSize(await file.length());
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${TalkyApiClient.baseUrl}/upload/media'),
    );
    request.headers['Authorization'] = 'Bearer $_accessToken';
    request.files.add(await _multipartFile('file', file, onProgress: onProgress));
    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw uploadHttpException(response);
  }
}
