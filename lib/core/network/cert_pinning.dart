// cert_pinning.dart — Certificate pinning pour le backend Alanya
//
// Le backend présente un certificat AUTO-SIGNÉ (CN = 158.220.107.211, sans SAN).
// Les CA publiques ne le reconnaissent donc pas → la validation TLS par défaut
// échoue (CERTIFICATE_VERIFY_FAILED). Plutôt que de désactiver toute vérification
// (dangereux : ouvre la porte au MITM), on embarque CE certificat exact dans
// l'app (assets/server_cert.pem) et on ne fait confiance QU'À LUI.
//
// Comme `HttpOverrides.global` s'applique à toute la couche dart:io, ce pinning
// couvre d'un seul coup :
//   • les requêtes http (TalkyApiClient)
//   • les uploads MultipartRequest
//   • le websocket socket.io
//   • le chargement d'images cached_network_image
//
// On NE désactive PAS les CA racines : `badCertificateCallback` n'est appelé que
// lorsque la validation par défaut a déjà échoué. Les autres hôtes (Firebase,
// images externes…) restent donc validés normalement ; seul notre cert
// auto-signé passe par le contrôle d'épinglage ci-dessous.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class PinnedCertHttpOverrides extends HttpOverrides {
  PinnedCertHttpOverrides(this._pinnedDer);

  /// Certificat épinglé, en représentation DER (octets bruts).
  final Uint8List _pinnedDer;

  /// Charge le certificat épinglé depuis les assets et construit l'override.
  /// À appeler après `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<PinnedCertHttpOverrides> load({
    String asset = 'assets/server_cert.pem',
  }) async {
    final pem = await rootBundle.loadString(asset);
    return PinnedCertHttpOverrides(_pemToDer(pem));
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..badCertificateCallback = _verify;
  }

  /// N'accepte QUE le certificat épinglé (comparaison octet par octet du DER).
  /// Retourne `true` ⇒ on accepte malgré l'échec de la validation par défaut.
  bool _verify(X509Certificate cert, String host, int port) {
    final ok = _bytesEqual(cert.der, _pinnedDer);
    if (!ok) {
      debugPrint('[CertPinning] ✗ Certificat NON épinglé refusé pour $host:$port');
    }
    return ok;
  }
}

/// Convertit un PEM (`-----BEGIN CERTIFICATE----- … -----END…-----`) en DER.
Uint8List _pemToDer(String pem) {
  final body = pem
      .split('\n')
      .where((l) => !l.startsWith('-----') && l.trim().isNotEmpty)
      .join();
  return base64.decode(body);
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
