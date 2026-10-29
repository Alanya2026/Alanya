// Documents sensibles : traces et empreintes (part of talky_api_client.dart).
// Plan : PLAN-DOCUMENTS-SENSIBLES.md ; serveur : migration 110.
part of '../talky_api_client.dart';

/// Ce qu'on fait d'un document sensible : le geste noté par le serveur.
enum GesteSensible {
  consultation('CONSULTATION'),
  telechargement('TELECHARGEMENT'),
  partage('PARTAGE'),
  transfert('TRANSFERT');

  const GesteSensible(this.code);

  /// La valeur attendue par `POST /api/documents-sensibles/consultations`.
  final String code;
}

String? _appareilSensible;

extension DocumentsSensiblesApi on TalkyApiClient {
  /// Marque et modèle de ce téléphone (« samsung SM-A515F »), lus une fois :
  /// ils s'écrivent dans la signature et accompagnent chaque trace.
  Future<String> appareilCourant() async =>
      _appareilSensible ??= await TalkyApiClient._currentDeviceModel();

  /// Note une consultation, ou une copie signée qui sort avec son
  /// [empreinte]. Lève [TalkyException] : à l'appelant de décider si l'échec
  /// compte (une consultation ne doit jamais empêcher la lecture).
  Future<void> noterGesteSensible({
    required int msgID,
    GesteSensible geste = GesteSensible.consultation,
    String? empreinte,
  }) async {
    final appareil = await appareilCourant();
    await _handleRequest(
      () => _client.post(
        Uri.parse('${TalkyApiClient.baseUrl}/documents-sensibles/consultations'),
        headers: _headers,
        body: jsonEncode({
          'msgID': msgID,
          'geste': geste.code,
          if (empreinte != null) 'empreinte': empreinte,
          'appareil': appareil,
        }),
      ),
    );
  }

  /// Qui a fait sortir la copie qui porte [empreinte] : `empreinte`, `geste`,
  /// `date`, `appareil`, `utilisateur` et `expediteur` (`{alanyaId, nom}`),
  /// `document` (`{msgID, nom}`). 404 si elle est inconnue ou hors de portée,
  /// 422 si elle est mal formée.
  Future<Map<String, dynamic>> verifierEmpreinte(String empreinte) async {
    final code = Uri.encodeComponent(empreinte.replaceAll(RegExp(r'\s'), ''));
    final data = await _handleRequest(
      () => _client.get(
        Uri.parse('${TalkyApiClient.baseUrl}/documents-sensibles/empreintes/$code'),
        headers: _headers,
      ),
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
