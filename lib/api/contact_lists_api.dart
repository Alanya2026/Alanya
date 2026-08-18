// Endpoints listes de contacts (part of talky_api_client.dart).
part of '../talky_api_client.dart';

extension ContactListsApi on TalkyApiClient {
  // ── LISTES DE CONTACTS ────────────────────────────────────────────

  Future<List<dynamic>> getContactLists() async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/contact-lists'),
        headers: _headers,
      ),
    );
    return data is List ? data : [];
  }

  Future<Map<String, dynamic>> createContactList(
    String name, {
    String? color,
  }) async {
    final data = await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/contact-lists'),
        headers: _headers,
        body: jsonEncode({'name': name, if (color != null) 'color': color}),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Renomme et/ou recolore. Les champs absents restent inchangés côté
  /// serveur : passer `color: ''` pour effacer la couleur.
  Future<Map<String, dynamic>> updateContactList(
    int idList, {
    String? name,
    String? color,
  }) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/contact-lists/$idList'),
        headers: _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (color != null) 'color': color,
        }),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Enregistre les sonneries d'une liste sur le compte (elles suivent alors
  /// l'utilisateur sur tous ses appareils — voir `ListRingtonePreferences`).
  ///
  /// [patch] ne contient QUE les champs à écrire : `messageSoundType`,
  /// `messageSoundId`, `messageSoundName`, et leurs équivalents `call*`. Une
  /// valeur `null` explicite efface le choix ; un champ absent le laisse tel
  /// quel. Aucun fichier audio n'est transmis : pour un son importé,
  /// `*SoundId` est le SHA-256 du contenu du fichier, qui reste sur
  /// l'appareil.
  Future<Map<String, dynamic>> updateContactListSounds(
    int idList,
    Map<String, dynamic> patch,
  ) async {
    final data = await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/contact-lists/$idList'),
        headers: _headers,
        body: jsonEncode(patch),
      ),
    );
    return data as Map<String, dynamic>;
  }

  /// Ordre de priorité des sonneries : quand un contact appartient à plusieurs
  /// listes, la première de [orderedListIds] désigne le son joué. Synchronisé
  /// comme les sons eux-mêmes, sinon deux appareils d'accord sur les sons
  /// pourraient encore diverger sur un contact multi-listes.
  Future<void> updateContactListSoundOrder(List<int> orderedListIds) async {
    await _handleRequest(
      () => _client.put(
        Uri.parse('${TalkyApiClient.baseUrl}/contact-lists/sound-order'),
        headers: _headers,
        body: jsonEncode({'order': orderedListIds}),
      ),
    );
  }

  Future<void> deleteContactList(int idList) async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse('${TalkyApiClient.baseUrl}/contact-lists/$idList'),
        headers: _headers,
      ),
    );
  }

  Future<List<dynamic>> getListMembers(int idList) async {
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/contact-lists/$idList/members'),
        headers: _headers,
      ),
    );
    return data is List ? data : [];
  }

  Future<void> addListMember(int idList, int friendID) async {
    await _handleRequest(
      () => _client.post(
        Uri.parse(
            '${TalkyApiClient.baseUrl}/contact-lists/$idList/members/$friendID'),
        headers: _headers,
      ),
    );
  }

  Future<void> removeListMember(int idList, int friendID) async {
    await _handleRequest(
      () => _client.delete(
        Uri.parse(
            '${TalkyApiClient.baseUrl}/contact-lists/$idList/members/$friendID'),
        headers: _headers,
      ),
    );
  }
}
