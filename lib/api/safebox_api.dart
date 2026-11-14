// Coffre-fort : le client de l'application pour le paquet alanya_safebox
// (part of talky_api_client.dart).
//
// Les appels du coffre (`fetchSafebox`, `putSafeboxBlock`…) viennent de
// `SafeboxCalls`, ajouté à [TalkyApiClient]. Ce fichier ne fournit que la
// plomberie : jeton et renouvellement ([TalkyApiClient._handleRequest]),
// erreurs [TalkyException] traduites.
part of '../talky_api_client.dart';

class _TalkySafeboxHttp implements SafeboxHttp {
  _TalkySafeboxHttp(this._api);

  final TalkyApiClient _api;

  @override
  Future<dynamic> send(String method, String path, {Map<String, String>? query, Object? body}) {
    final url = Uri.parse('${TalkyApiClient.baseUrl}/safebox$path').replace(queryParameters: query);
    final corps = body == null ? null : jsonEncode(body);
    final client = _api._client;
    return _api._handleRequest(() => switch (method) {
          'GET' => client.get(url, headers: _api._headers),
          'POST' => client.post(url, headers: _api._headers, body: corps),
          'PUT' => client.put(url, headers: _api._headers, body: corps),
          'PATCH' => client.patch(url, headers: _api._headers, body: corps),
          'DELETE' => client.delete(url, headers: _api._headers, body: corps),
          _ => throw ArgumentError.value(method, 'method'),
        });
  }

  @override
  http.Client get transferClient => _api._client;

  @override
  Duration get stallTimeout => _api.uploadStallTimeout;

  @override
  SafeboxHttpException transferFailure(SafeboxTransferFailure kind, {int status = 0, String? code, Object? cause}) =>
      switch (kind) {
        SafeboxTransferFailure.rejected => TalkyException(resolveL10n().serverError, status, code: code),
        SafeboxTransferFailure.timeout => TalkyException(resolveL10n().networkTimeout, 0, cause: cause),
        SafeboxTransferFailure.network => TalkyException(resolveL10n().networkError, 0, cause: cause),
      };
}
