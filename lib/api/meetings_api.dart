// Endpoints réunions (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension MeetingsApi on TalkyApiClient {
  Future<List<dynamic>> getMeetings() async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/meetings'), headers: _headers),
    );
    return data is List ? data : [];
  }

  /// Crée une réunion — backend attend: objet, start_time, room, duree, type_media
  Future<Map<String, dynamic>> createMeeting({
    required String objet,
    required String startTime, // ISO8601 ex: "2026-05-03T14:00:00"
    required String room,
    int duree = 60,
    int typeMedia = 0,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/meetings'),
        headers: _headers,
        body: jsonEncode({
          'objet': objet,
          'start_time': startTime,
          'room': room,
          'duree': duree,
          'type_media': typeMedia,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMeeting(int idMeeting) async {
    final data = await _handleRequest(
      () => _client.get(Uri.parse('${TalkyApiClient.baseUrl}/meetings/$idMeeting'), headers: _headers),
    );
    return data as Map<String, dynamic>;
  }

  /// Résout une réunion par son code de room (même si on n'en est pas encore
  /// participant). Lève une exception si introuvable / terminée.
  Future<Map<String, dynamic>> getMeetingByRoom(String room) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/meetings/by-room/${Uri.encodeComponent(room)}'),
        headers: _headers,
      ),
    );
    return data as Map<String, dynamic>;
  }

  Future<void> joinMeetingHttp(int idMeeting) async {
    await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/meetings/$idMeeting/join'), headers: _headers),
    );
  }

  Future<void> leaveMeetingHttp(int idMeeting) async {
    await _handleRequest(
      () => _client.post(Uri.parse('${TalkyApiClient.baseUrl}/meetings/$idMeeting/leave'), headers: _headers),
    );
  }

  Future<void> deleteMeeting(int idMeeting) async {
    await _handleRequest(
      () => _client.delete(Uri.parse('${TalkyApiClient.baseUrl}/meetings/$idMeeting'), headers: _headers),
    );
  }

  Future<void> updateMeeting(int idMeeting, {
    String? objet,
    String? startTime,
    int? duree,
    int? typeMedia,
  }) async {
    final body = <String, dynamic>{};
    if (objet != null) body['objet'] = objet;
    if (startTime != null) body['start_time'] = startTime;
    if (duree != null) body['duree'] = duree;
    if (typeMedia != null) body['type_media'] = typeMedia;
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/meetings/$idMeeting'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<void> inviteParticipants(int idMeeting, List<int> participantIds) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/meetings/$idMeeting/invite'),
        headers: _headers,
        body: jsonEncode({'participant_ids': participantIds}),
      ),
    );
  }
}
