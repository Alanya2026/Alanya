// Connexion lente : un bloc qui part au rythme du réseau ne doit jamais être
// coupé par la surveillance des envois bloqués (stallTimeout), tant que des
// octets avancent vraiment. Un serveur local lit le corps lentement, comme
// une ligne mobile.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Http implements SafeboxHttp {
  _Http(this.stallTimeout);

  @override
  final Duration stallTimeout;

  @override
  final http.Client transferClient = http.Client();

  @override
  Future<dynamic> send(String method, String path, {Map<String, String>? query, Object? body}) async => const {};

  @override
  SafeboxHttpException transferFailure(SafeboxTransferFailure kind, {int status = 0, String? code, Object? cause}) =>
      SafeboxHttpException(kind.name, status, code: code, cause: cause);
}

/// Un serveur HTTP minimal qui lit [octetsParSeconde] au plus, puis répond
/// 200. Son tampon de réception est réduit à 64 Kio : sans cela, le système
/// avale des dizaines de Mo en local et rien ne ralentit le client, ce qui
/// n'arrive pas sur une vraie ligne lente.
Future<ServerSocket> _serveurLent(int octetsParSeconde, {required void Function(int recus) onFin}) async {
  final serveur = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  serveur.listen((socket) {
    // SO_RCVBUF (8) au niveau SOL_SOCKET (1), Linux.
    socket.setRawOption(RawSocketOption.fromInt(RawSocketOption.levelSocket, 8, 64 * 1024));
    final entete = BytesBuilder();
    int? attendu;
    var corps = 0;
    final debut = DateTime.now();
    late StreamSubscription<Uint8List> abonnement;
    abonnement = socket.listen((morceau) async {
      if (attendu == null) {
        entete.add(morceau);
        final texte = String.fromCharCodes(entete.toBytes());
        final fin = texte.indexOf('\r\n\r\n');
        if (fin < 0) return;
        attendu = int.parse(RegExp(r'content-length: *(\d+)', caseSensitive: false).firstMatch(texte)!.group(1)!);
        corps = entete.length - (fin + 4);
      } else {
        corps += morceau.length;
      }
      if (corps >= attendu!) {
        onFin(corps);
        socket.add('HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'.codeUnits);
        await socket.flush();
        await socket.close();
        return;
      }
      final duree = Duration(microseconds: corps * 1000000 ~/ octetsParSeconde);
      final ecoule = DateTime.now().difference(debut);
      if (duree > ecoule) {
        abonnement.pause();
        await Future<void>.delayed(duree - ecoule);
        abonnement.resume();
      }
    });
  });
  return serveur;
}

void main() {
  test('un bloc de 12 Mo à 1 Mo/s arrive entier malgré une surveillance de 3 s', () async {
    // 12 s d'envoi : la surveillance (3 s) ne voit que des octets qui
    // avancent. La fin, gardée par les tampons du système (jusqu'à 4 Mo
    // côté client, ~4 s ici), s'attend sans nouvelle : elle a droit à un
    // délai plus long (bodySent).
    var recusParLeServeur = -1;
    final serveur = await _serveurLent(1 << 20, onFin: (n) => recusParLeServeur = n);
    addTearDown(serveur.close);
    final api = SafeboxClient(_Http(const Duration(seconds: 3)));
    final bloc = Uint8List(12 << 20);
    final progression = <int>[];

    await api.putSafeboxBlock('http://127.0.0.1:${serveur.port}/bloc', bloc, onProgress: progression.add);

    expect(recusParLeServeur, bloc.length);
    expect(progression.last, bloc.length);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('un envoi vraiment bloqué est coupé au bout du délai', () async {
    // Le serveur ne lit rien : plus un octet ne part.
    final serveur = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => serveur.close(force: true));
    serveur.listen((req) => req.listen(null)..pause());
    final api = SafeboxClient(_Http(const Duration(seconds: 2)));
    final debut = DateTime.now();

    await expectLater(
      api.putSafeboxBlock('http://127.0.0.1:${serveur.port}/bloc', Uint8List(32 << 20)),
      throwsA(isA<SafeboxHttpException>().having((e) => e.statusCode, 'statut', 0)),
    );
    expect(DateTime.now().difference(debut), lessThan(const Duration(seconds: 20)));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
