import 'package:drift/drift.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import 'e2ee_coffre.dart';
import 'e2ee_database.dart';

/// Le store Signal de cet appareil : ce que `libsignal_protocol_dart` lit et
/// écrit pendant qu'il ouvre une session, chiffre ou déchiffre.
///
/// Toutes les valeurs privées passent par [CoffreE2ee] : la base ne voit que
/// des enregistrements scellés, chacun lié à son adresse.
///
/// ── Ce store n'est PAS sûr en accès concurrent, et c'est voulu ──
///
/// La bibliothèque lit une session, la fait avancer, puis la réécrit. Deux
/// opérations entrelacées sur la même session repartiraient du même état, et
/// la seconde écriture effacerait la première : une clé de message servirait
/// deux fois, ou une session saine serait détruite (docs/e2ee, chapitres 11 et
/// 19). La bibliothèque Dart ne sérialise rien elle-même. C'est donc
/// `E2eeService` qui fait passer toute opération une par une ; personne d'autre
/// ne doit appeler ce store.
class AlanyaSignalStore extends SignalProtocolStore {
  AlanyaSignalStore(this._db, this._coffre, {DateTime Function()? horloge})
      : _horloge = horloge ?? DateTime.now;

  final E2eeDatabase _db;
  final CoffreE2ee _coffre;

  /// L'horloge de `E2eeService`. Les dates rangées ici décident de la
  /// rotation et de la conservation des pré-clés signées : elles doivent venir
  /// de la même horloge que celle qui les compare.
  final DateTime Function() _horloge;

  int get _maintenant => _horloge().millisecondsSinceEpoch;

  static String _adresseSession(SignalProtocolAddress a) =>
      'session/${a.getName()}.${a.getDeviceId()}';
  static String _adresseIdentiteDistante(SignalProtocolAddress a) =>
      'identite_distante/${a.getName()}.${a.getDeviceId()}';
  static String _adressePreKey(int id) => 'prekey/$id';
  static String _adresseSignedPreKey(int id) => 'spk/$id';
  static const String _adresseIdentite = 'identite';

  // ── Identité de cet appareil ───────────────────────────────────────────

  /// Pose l'identité de cet appareil. Appelé une seule fois par installation.
  Future<void> poserIdentite(IdentityKeyPair paire, int registrationId) async {
    final scelle = await _coffre.sceller(paire.serialize(), _adresseIdentite);
    await _db.customStatement(
      'INSERT OR REPLACE INTO e2ee_identite (id, registration_id, key_pair, cree_le) '
      'VALUES (1, ?, ?, ?)',
      [registrationId, scelle, _maintenant],
    );
  }

  /// L'identité existe-t-elle ? Sans rien ouvrir.
  Future<bool> aUneIdentite() async {
    final rows = await _db
        .customSelect('SELECT 1 FROM e2ee_identite WHERE id = 1')
        .get();
    return rows.isNotEmpty;
  }

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    final scelle = await _db.lireBlob('e2ee_identite', 'key_pair', 1);
    if (scelle == null) {
      throw StateError('identité E2EE absente : E2eeService.preparer() non appelé');
    }
    return IdentityKeyPair.fromSerialized(
      await _coffre.ouvrirEnregistrement(scelle, _adresseIdentite),
    );
  }

  @override
  Future<int> getLocalRegistrationId() async {
    final rows = await _db
        .customSelect('SELECT registration_id FROM e2ee_identite WHERE id = 1')
        .get();
    if (rows.isEmpty) {
      throw StateError('identité E2EE absente : E2eeService.preparer() non appelé');
    }
    return rows.first.read<int>('registration_id');
  }

  // ── Identités des correspondants ───────────────────────────────────────

  /// Range l'identité d'un correspondant. Rend `true` quand elle REMPLACE une
  /// identité différente — une réinstallation, ou une substitution.
  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    if (identityKey == null) return false;
    final existante = await getIdentity(address);
    if (existante != null && existante == identityKey) return false;
    final scelle = await _coffre.sceller(
      identityKey.serialize(),
      _adresseIdentiteDistante(address),
    );
    await _db.customStatement(
      'INSERT INTO e2ee_identites_distantes (nom, appareil, identity_key, vu_le) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(nom, appareil) DO UPDATE SET '
      'identity_key = excluded.identity_key, vu_le = excluded.vu_le',
      [
        address.getName(),
        address.getDeviceId(),
        scelle,
        _maintenant,
      ],
    );
    return existante != null;
  }

  /// Confiance au premier contact, sans blocage au changement.
  ///
  /// La référence de la bibliothèque refuse une identité qui a changé, ce qui
  /// lève `UntrustedIdentityException` et bloque l'envoi jusqu'à une
  /// validation manuelle. On fait le choix de WhatsApp : la réinstallation est
  /// de loin la cause la plus fréquente d'un changement, et bloquer la
  /// conversation à chaque fois la rendrait inutilisable. Le changement n'est
  /// pas ignoré pour autant : `saveIdentity` le constate, et il deviendra une
  /// alerte persistante jusqu'à lecture (étape 3 du plan).
  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async =>
      identityKey != null;

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final rows = await _db.customSelect(
      'SELECT identity_key FROM e2ee_identites_distantes WHERE nom = ? AND appareil = ?',
      variables: [
        Variable.withString(address.getName()),
        Variable.withInt(address.getDeviceId()),
      ],
    ).get();
    if (rows.isEmpty) return null;
    final clair = await _coffre.ouvrirEnregistrement(
      rows.first.read<Uint8List>('identity_key'),
      _adresseIdentiteDistante(address),
    );
    return IdentityKey.fromBytes(clair, 0);
  }

  // ── Pré-clés à usage unique ────────────────────────────────────────────

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    final scelle = await _db.lireBlob('e2ee_prekeys', 'record', preKeyId);
    if (scelle == null) {
      throw InvalidKeyIdException('pré-clé $preKeyId inconnue');
    }
    return PreKeyRecord.fromBuffer(
      await _coffre.ouvrirEnregistrement(scelle, _adressePreKey(preKeyId)),
    );
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    final scelle = await _coffre.sceller(record.serialize(), _adressePreKey(preKeyId));
    await _db.customStatement(
      'INSERT OR REPLACE INTO e2ee_prekeys (id, record) VALUES (?, ?)',
      [preKeyId, scelle],
    );
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async =>
      (await _db.lireBlob('e2ee_prekeys', 'record', preKeyId)) != null;

  @override
  Future<void> removePreKey(int preKeyId) =>
      _db.customStatement('DELETE FROM e2ee_prekeys WHERE id = ?', [preKeyId]);

  /// Plus grand identifiant de pré-clé rangé, 0 s'il n'y en a aucune.
  Future<int> plusGrandePreKey() async {
    final rows = await _db
        .customSelect('SELECT COALESCE(MAX(id), 0) AS m FROM e2ee_prekeys')
        .get();
    return rows.first.read<int>('m');
  }

  // ── Pré-clés signées ───────────────────────────────────────────────────

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    final scelle = await _db.lireBlob('e2ee_signed_prekeys', 'record', signedPreKeyId);
    if (scelle == null) {
      throw InvalidKeyIdException('pré-clé signée $signedPreKeyId inconnue');
    }
    return SignedPreKeyRecord.fromSerialized(
      await _coffre.ouvrirEnregistrement(scelle, _adresseSignedPreKey(signedPreKeyId)),
    );
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    final rows = await _db
        .customSelect('SELECT id, record FROM e2ee_signed_prekeys ORDER BY id')
        .get();
    final sortie = <SignedPreKeyRecord>[];
    for (final r in rows) {
      final id = r.read<int>('id');
      sortie.add(SignedPreKeyRecord.fromSerialized(
        await _coffre.ouvrirEnregistrement(
          r.read<Uint8List>('record'),
          _adresseSignedPreKey(id),
        ),
      ));
    }
    return sortie;
  }

  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async {
    final scelle = await _coffre.sceller(
      record.serialize(),
      _adresseSignedPreKey(signedPreKeyId),
    );
    await _db.customStatement(
      'INSERT OR REPLACE INTO e2ee_signed_prekeys (id, record, cree_le) VALUES (?, ?, ?)',
      [signedPreKeyId, scelle, _maintenant],
    );
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async =>
      (await _db.lireBlob('e2ee_signed_prekeys', 'record', signedPreKeyId)) != null;

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) => _db.customStatement(
        'DELETE FROM e2ee_signed_prekeys WHERE id = ?',
        [signedPreKeyId],
      );

  /// Pré-clés signées et leur date de création, de la plus récente à la plus
  /// ancienne, sans rien ouvrir.
  Future<List<({int id, DateTime creeLe})>> pagesSignedPreKeys() async {
    final rows = await _db
        .customSelect('SELECT id, cree_le FROM e2ee_signed_prekeys ORDER BY cree_le DESC, id DESC')
        .get();
    return [
      for (final r in rows)
        (
          id: r.read<int>('id'),
          creeLe: DateTime.fromMillisecondsSinceEpoch(r.read<int>('cree_le')),
        ),
    ];
  }

  // ── Sessions ───────────────────────────────────────────────────────────

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final rows = await _db.customSelect(
      'SELECT record FROM e2ee_sessions WHERE nom = ? AND appareil = ?',
      variables: [
        Variable.withString(address.getName()),
        Variable.withInt(address.getDeviceId()),
      ],
    ).get();
    if (rows.isEmpty) return SessionRecord();
    return SessionRecord.fromSerialized(
      await _coffre.ouvrirEnregistrement(
        rows.first.read<Uint8List>('record'),
        _adresseSession(address),
      ),
    );
  }

  /// Tous les appareils d'un correspondant avec qui une session existe.
  ///
  /// La référence de la bibliothèque écarte l'appareil n° 1, que Signal
  /// réserve au téléphone principal. Chez Alanya, le numéro d'appareil est
  /// `appareils.id` : le n° 1 est un appareil comme un autre.
  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    final rows = await _db.customSelect(
      'SELECT appareil FROM e2ee_sessions WHERE nom = ? ORDER BY appareil',
      variables: [Variable.withString(name)],
    ).get();
    return [for (final r in rows) r.read<int>('appareil')];
  }

  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) async {
    final scelle = await _coffre.sceller(record.serialize(), _adresseSession(address));
    await _db.customStatement(
      'INSERT INTO e2ee_sessions (nom, appareil, record) VALUES (?, ?, ?) '
      'ON CONFLICT(nom, appareil) DO UPDATE SET record = excluded.record',
      [address.getName(), address.getDeviceId(), scelle],
    );
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final rows = await _db.customSelect(
      'SELECT 1 FROM e2ee_sessions WHERE nom = ? AND appareil = ?',
      variables: [
        Variable.withString(address.getName()),
        Variable.withInt(address.getDeviceId()),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) => _db.customStatement(
        'DELETE FROM e2ee_sessions WHERE nom = ? AND appareil = ?',
        [address.getName(), address.getDeviceId()],
      );

  @override
  Future<void> deleteAllSessions(String name) =>
      _db.customStatement('DELETE FROM e2ee_sessions WHERE nom = ?', [name]);
}
