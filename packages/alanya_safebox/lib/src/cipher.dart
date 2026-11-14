//  Chiffrement des fichiers du coffre-fort — format « SBX1 ».
//
//  Conception : backend/docs/conception/coffre-fort.html, sections 03 et 05.
//  MEGA S4 ne chiffre rien : le téléphone chiffre chaque fichier sous une clé
//  tirée au hasard, que le serveur garde ensuite sous sa clé maîtresse.
//
//  Le fichier est découpé en morceaux chiffrés en AES-256-GCM, chacun de
//  1 Mio une fois chiffré (1 Mio − 16 octets en clair, plus 16 d'étiquette).
//  Un bloc de stockage chez MEGA (8 Mio) contient donc exactement 8 morceaux :
//  un bloc se chiffre, s'envoie, se télécharge et se déchiffre SEUL. C'est ce
//  qui permet d'envoyer un fichier de 1 Go bloc par bloc, sans en garder de
//  copie chiffrée entière sur le téléphone, et de reprendre après une coupure.
//
//  Le nonce de 12 octets se déduit de la position (construction STREAM, comme
//  le format AGB1 des médias chiffrés) :
//
//    octet 0      domaine : 0 = contenu, 1 = aperçu
//    octets 1–6   zéro
//    octets 7–10  numéro du morceau (gros-boutiste)
//    octet 11     1 pour le DERNIER morceau, 0 sinon
//
//  Un morceau déplacé, retiré ou un fichier coupé net sont donc refusés. Un
//  nonce déterministe n'est sûr que parce que la clé est neuve pour chaque
//  fichier, et qu'un même morceau n'est jamais chiffré deux fois avec un
//  contenu différent : l'envoi vérifie que la source n'a pas changé avant de
//  rechiffrer un bloc (voir safebox_upload_manager.dart).

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

const String kSafeboxCipherFormat = 'SBX1';

/// Taille d'un morceau chiffré.
const int kSafeboxChunkCipherBytes = 1 << 20;

/// Étiquette GCM ajoutée à chaque morceau.
const int kSafeboxTagBytes = 16;

/// Octets en clair d'un morceau plein.
const int kSafeboxChunkPlainBytes = kSafeboxChunkCipherBytes - kSafeboxTagBytes;

const int _domaineContenu = 0;
const int _domaineApercu = 1;
final List<int> _aad = 'SBX1'.codeUnits;

/// Nombre de morceaux d'un fichier de [plainSize] octets en clair.
int safeboxChunkCount(int plainSize) {
  if (plainSize < 1) throw ArgumentError.value(plainSize, 'plainSize', 'fichier vide');
  return (plainSize + kSafeboxChunkPlainBytes - 1) ~/ kSafeboxChunkPlainBytes;
}

/// Taille chiffrée exacte d'un fichier : c'est elle qui compte dans l'espace.
int safeboxEncryptedLength(int plainSize) =>
    plainSize + kSafeboxTagBytes * safeboxChunkCount(plainSize);

/// Taille chiffrée d'un aperçu de [previewSize] octets.
int safeboxPreviewEncryptedLength(int previewSize) => previewSize + kSafeboxTagBytes;

/// Ce que contient le bloc de stockage [n] (numéroté à partir de 1).
class SafeboxBlockPlan {
  const SafeboxBlockPlan({
    required this.number,
    required this.plainStart,
    required this.plainEnd,
    required this.firstChunk,
    required this.totalChunks,
  });

  final int number;

  /// Plage en clair couverte par ce bloc : [plainStart, plainEnd).
  final int plainStart;
  final int plainEnd;

  /// Numéro du premier morceau du bloc.
  final int firstChunk;

  /// Nombre de morceaux du fichier entier : le dernier porte le drapeau.
  final int totalChunks;

  int get plainLength => plainEnd - plainStart;

  int get cipherLength =>
      plainLength + kSafeboxTagBytes * ((plainLength + kSafeboxChunkPlainBytes - 1) ~/ kSafeboxChunkPlainBytes);
}

/// Morceaux par bloc de stockage. Le serveur fixe la taille du bloc : elle doit
/// être un multiple exact du morceau chiffré, sinon un bloc ne se déchiffrerait
/// pas seul.
int safeboxChunksPerBlock(int blockSize) {
  if (blockSize <= 0 || blockSize % kSafeboxChunkCipherBytes != 0) {
    throw ArgumentError.value(blockSize, 'blockSize', 'doit être un multiple de 1 Mio');
  }
  return blockSize ~/ kSafeboxChunkCipherBytes;
}

SafeboxBlockPlan safeboxPlanBlock(
  int number, {
  required int plainSize,
  required int blockSize,
}) {
  final parBloc = safeboxChunksPerBlock(blockSize);
  final total = safeboxChunkCount(plainSize);
  final premier = (number - 1) * parBloc;
  if (number < 1 || premier >= total) {
    throw RangeError('bloc $number hors du fichier');
  }
  final debut = premier * kSafeboxChunkPlainBytes;
  final fin = math.min(debut + parBloc * kSafeboxChunkPlainBytes, plainSize);
  return SafeboxBlockPlan(
    number: number,
    plainStart: debut,
    plainEnd: fin,
    firstChunk: premier,
    totalChunks: total,
  );
}

/// Nombre de blocs de stockage d'un fichier.
int safeboxBlockCount(int plainSize, int blockSize) {
  final parBloc = safeboxChunksPerBlock(blockSize);
  return (safeboxChunkCount(plainSize) + parBloc - 1) ~/ parBloc;
}

Uint8List safeboxNonce(int index, {required bool last, int domain = _domaineContenu}) {
  final n = Uint8List(12);
  n[0] = domain;
  ByteData.sublistView(n).setUint32(7, index);
  n[11] = last ? 1 : 0;
  return n;
}

DartAesGcm _aes() => DartAesGcm(secretKeyLength: 32);

void _verifierCle(List<int> key) {
  if (key.length != 32) throw ArgumentError('clé de fichier : 32 octets attendus');
}

/// Chiffre la partie en clair d'un bloc. Synchrone : à appeler dans un isolat
/// ([safeboxEncryptBlock]) pour ne pas geler l'écran.
Uint8List safeboxEncryptBlockSync(
  List<int> key,
  Uint8List plain,
  SafeboxBlockPlan plan,
) {
  _verifierCle(key);
  if (plain.length != plan.plainLength) {
    throw ArgumentError('bloc ${plan.number} : ${plain.length} octets au lieu de ${plan.plainLength}');
  }
  final aes = _aes();
  final cle = SecretKeyData(key);
  final out = BytesBuilder(copy: false);
  var i = 0;
  var morceau = plan.firstChunk;
  while (i < plain.length) {
    final fin = math.min(i + kSafeboxChunkPlainBytes, plain.length);
    final dernier = morceau == plan.totalChunks - 1;
    final boite = aes.encryptSync(
      Uint8List.sublistView(plain, i, fin),
      secretKeyData: cle,
      nonce: safeboxNonce(morceau, last: dernier),
      aad: _aad,
    );
    out.add(boite.cipherText);
    out.add(boite.mac.bytes);
    i = fin;
    morceau += 1;
  }
  return out.takeBytes();
}

/// Déchiffre un bloc reçu de MEGA. Lève si un morceau est altéré, déplacé ou
/// si le fichier a été coupé.
Uint8List safeboxDecryptBlockSync(
  List<int> key,
  Uint8List cipher,
  SafeboxBlockPlan plan,
) {
  _verifierCle(key);
  if (cipher.length != plan.cipherLength) {
    throw ArgumentError('bloc ${plan.number} : ${cipher.length} octets au lieu de ${plan.cipherLength}');
  }
  final aes = _aes();
  final cle = SecretKeyData(key);
  final out = BytesBuilder(copy: false);
  var i = 0;
  var morceau = plan.firstChunk;
  while (i < cipher.length) {
    final fin = math.min(i + kSafeboxChunkCipherBytes, cipher.length);
    final dernier = morceau == plan.totalChunks - 1;
    final clair = aes.decryptSync(
      SecretBox(
        Uint8List.sublistView(cipher, i, fin - kSafeboxTagBytes),
        nonce: safeboxNonce(morceau, last: dernier),
        mac: Mac(Uint8List.sublistView(cipher, fin - kSafeboxTagBytes, fin)),
      ),
      secretKeyData: cle,
      aad: _aad,
    );
    out.add(clair);
    i = fin;
    morceau += 1;
  }
  return out.takeBytes();
}

/// Aperçu chiffré : un seul morceau, dans son propre domaine de nonces.
Uint8List safeboxEncryptPreviewSync(List<int> key, Uint8List preview) {
  _verifierCle(key);
  if (preview.isEmpty || preview.length > kSafeboxChunkPlainBytes) {
    throw ArgumentError('aperçu de ${preview.length} octets');
  }
  final boite = _aes().encryptSync(
    preview,
    secretKeyData: SecretKeyData(key),
    nonce: safeboxNonce(0, last: true, domain: _domaineApercu),
    aad: _aad,
  );
  return Uint8List.fromList([...boite.cipherText, ...boite.mac.bytes]);
}

Uint8List safeboxDecryptPreviewSync(List<int> key, Uint8List cipher) {
  _verifierCle(key);
  if (cipher.length <= kSafeboxTagBytes) throw ArgumentError('aperçu tronqué');
  final fin = cipher.length;
  return Uint8List.fromList(_aes().decryptSync(
    SecretBox(
      Uint8List.sublistView(cipher, 0, fin - kSafeboxTagBytes),
      nonce: safeboxNonce(0, last: true, domain: _domaineApercu),
      mac: Mac(Uint8List.sublistView(cipher, fin - kSafeboxTagBytes, fin)),
    ),
    secretKeyData: SecretKeyData(key),
    aad: _aad,
  ));
}

/// Versions asynchrones : le calcul tourne dans un isolat. AES-GCM en Dart pur
/// sur 8 Mio prend de l'ordre de la seconde sur un téléphone moyen.
Future<Uint8List> safeboxEncryptBlock(List<int> key, Uint8List plain, SafeboxBlockPlan plan) =>
    Isolate.run(() => safeboxEncryptBlockSync(key, plain, plan));

Future<Uint8List> safeboxDecryptBlock(List<int> key, Uint8List cipher, SafeboxBlockPlan plan) =>
    Isolate.run(() => safeboxDecryptBlockSync(key, cipher, plan));

/// Clé neuve pour un fichier.
Uint8List safeboxNewFileKey() {
  final r = math.Random.secure();
  return Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)));
}
