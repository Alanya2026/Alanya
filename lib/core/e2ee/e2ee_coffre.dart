import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/secure_storage_guard.dart';

/// Où vit la clé du coffre : le Keystore (Android) ou le Keychain (iOS).
///
/// Une interface plutôt que `FlutterSecureStorage` en dur : les tests n'ont
/// ni Keystore ni Keychain, et c'est précisément la perte de cette clé — une
/// restauration sur un autre téléphone, un Keystore invalidé — qu'ils doivent
/// pouvoir simuler.
abstract class CleDuCoffreStore {
  Future<Uint8List?> lire();
  Future<void> ecrire(Uint8List cle);
  Future<void> effacer();
}

/// Clé du coffre dans `flutter_secure_storage`, avec les options communes de
/// l'application (`kSecureStorageAndroidOptions` / `kSecureStorageIosOptions`).
///
/// iOS : `first_unlock_this_device` — la clé ne suit pas une sauvegarde vers
/// un autre iPhone. C'est voulu : sur un appareil neuf, le coffre restauré
/// serait illisible, et l'application repart d'une identité neuve au lieu de
/// réutiliser des sessions qui ne correspondent plus à rien.
class CleDuCoffreSecureStorage implements CleDuCoffreStore {
  CleDuCoffreSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: kSecureStorageAndroidOptions,
              iOptions: kSecureStorageIosOptions,
            );

  static const String _cle = 'e2ee_coffre_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> lire() async {
    final b64 = await SecureStorageGuard.readString(_storage, _cle);
    if (b64 == null || b64.isEmpty) return null;
    try {
      final octets = base64Decode(b64);
      return octets.length == 32 ? Uint8List.fromList(octets) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> ecrire(Uint8List cle) =>
      SecureStorageGuard.writeString(_storage, _cle, base64Encode(cle));

  @override
  Future<void> effacer() => SecureStorageGuard.deleteKey(_storage, _cle);
}

/// Clé en mémoire, pour les tests.
class CleDuCoffreMemoire implements CleDuCoffreStore {
  Uint8List? valeur;

  @override
  Future<Uint8List?> lire() async => valeur;

  @override
  Future<void> ecrire(Uint8List cle) async => valeur = cle;

  @override
  Future<void> effacer() async => valeur = null;
}

/// Le contenu du coffre ne s'ouvre pas avec cette clé.
///
/// Deux causes, indiscernables et c'est voulu : la clé a changé (Keystore
/// invalidé, restauration sur un autre appareil) ou l'enregistrement a été
/// altéré. Dans les deux cas l'état Signal est perdu, et la seule issue sûre
/// est de repartir d'une identité neuve.
class CoffreIllisible implements Exception {
  const CoffreIllisible(this.raison);
  final String raison;
  @override
  String toString() => 'CoffreIllisible($raison)';
}

/// Scelle et ouvre les enregistrements privés de l'état Signal.
///
/// ── Ce que le coffre protège, et contre qui ──
///
/// Les enregistrements (identité privée, pré-clés, sessions) dorment dans une
/// base SQLite, chiffrés par une clé qui ne quitte jamais le Keystore /
/// Keychain. Une copie du fichier de base — sauvegarde, téléphone rooté lu à
/// froid — ne livre donc rien sans l'appareil. Contre du code qui s'exécute
/// DANS l'application, le coffre ne peut rien : il doit bien ouvrir ce qu'il
/// garde. On passe de « copier et partir » à « être présent et agir »
/// (docs/e2ee, chapitre 4).
///
/// ── Pourquoi des données associées ──
///
/// Chaque enregistrement est scellé avec son adresse (`session/<compte>.<appareil>`,
/// `prekey/<id>`…) en données associées. Déplacer en base la session d'un
/// correspondant sur la ligne d'un autre fait alors échouer l'ouverture, au
/// lieu de faire chiffrer pour le mauvais destinataire sans bruit.
///
/// Format : nonce (12 octets) ‖ chiffré ‖ étiquette GCM (16 octets).
class CoffreE2ee {
  CoffreE2ee(this._store);

  final CleDuCoffreStore _store;
  final AesGcm _aes = AesGcm.with256bits();
  SecretKey? _cle;

  static const int _nonceOctets = 12;
  static const int _macOctets = 16;

  /// Charge la clé du coffre, ou la crée.
  ///
  /// Rend `true` quand la clé vient d'être créée : un coffre existant scellé
  /// sous une autre clé devient alors illisible, et l'appelant doit le vider.
  Future<bool> ouvrir() async {
    if (_cle != null) return false;
    final existante = await _store.lire();
    if (existante != null) {
      _cle = SecretKey(existante);
      return false;
    }
    final neuve = Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    await _store.ecrire(neuve);
    _cle = SecretKey(neuve);
    return true;
  }

  /// Oublie la clé, en mémoire et dans le Keystore / Keychain.
  Future<void> detruire() async {
    _cle = null;
    await _store.effacer();
  }

  SecretKey get _cleOuverte {
    final cle = _cle;
    if (cle == null) {
      throw StateError('coffre lu avant ouvrir()');
    }
    return cle;
  }

  Future<Uint8List> sceller(Uint8List clair, String adresse) async {
    final boite = await _aes.encrypt(
      clair,
      secretKey: _cleOuverte,
      nonce: _aes.newNonce(),
      aad: utf8.encode(adresse),
    );
    return Uint8List.fromList([
      ...boite.nonce,
      ...boite.cipherText,
      ...boite.mac.bytes,
    ]);
  }

  Future<Uint8List> ouvrirEnregistrement(Uint8List scelle, String adresse) async {
    if (scelle.length < _nonceOctets + _macOctets) {
      throw const CoffreIllisible('enregistrement tronqué');
    }
    final boite = SecretBox(
      scelle.sublist(_nonceOctets, scelle.length - _macOctets),
      nonce: scelle.sublist(0, _nonceOctets),
      mac: Mac(scelle.sublist(scelle.length - _macOctets)),
    );
    try {
      final clair = await _aes.decrypt(
        boite,
        secretKey: _cleOuverte,
        aad: utf8.encode(adresse),
      );
      return Uint8List.fromList(clair);
    } on SecretBoxAuthenticationError {
      throw const CoffreIllisible('authentification échouée');
    }
  }
}
