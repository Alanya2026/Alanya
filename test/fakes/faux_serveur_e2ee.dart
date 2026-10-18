import 'package:drift/native.dart';
import 'package:talky_flutter/core/e2ee/e2ee_coffre.dart';
import 'package:talky_flutter/core/e2ee/e2ee_database.dart';
import 'package:talky_flutter/core/e2ee/e2ee_service.dart';

/// Faux serveur : l'annuaire, la liste des appareils d'une conversation, la
/// distribution des paquets et des enveloppes — ce que fait le vrai backend,
/// sans HTTP. Il éprouve le protocole, pas le contrat HTTP (docs/e2ee,
/// chapitre 10) ; les noms de champs sont ceux des routes /api/e2ee.
class FauxServeur {
  final Map<int, _Inscrit> inscrits = {}; // appareilId → inscrit
  DateTime? e2eeSince;
  int bundlesServis = 0;
  int appelsAppareils = 0;

  E2eeApiPort port(int alanyaID, int appareilId) => _Port(this, alanyaID, appareilId);

  /// Ce que reçoit [appareil] pour un message envoyé par ([emetteur], [appareilEmetteur]).
  Map<String, dynamic>? livrer({
    required EnvoiChiffre envoi,
    required int emetteur,
    required int appareilEmetteur,
    required int appareil,
    required String clientId,
    int conv = 7,
  }) {
    final env = envoi.envelopes.where((e) => e['appareilId'] == appareil).toList();
    if (env.isEmpty) return null;
    return {
      'senderID': emetteur,
      'conversationID': conv,
      'clientId': clientId,
      'enc_version': 1,
      'content': null,
      'body': {...envoi.body, 'senderAppareilId': appareilEmetteur},
      'envelope': env.first,
    };
  }
}

class _Inscrit {
  _Inscrit(this.alanyaID);
  final int alanyaID;
  Map<String, dynamic>? bundle;
  final List<Map<String, dynamic>> stock = [];
}

class _Port implements E2eeApiPort {
  _Port(this.s, this.alanyaID, this.appareilId);
  final FauxServeur s;
  final int alanyaID;
  final int appareilId;

  _Inscrit get _moi => s.inscrits.putIfAbsent(appareilId, () => _Inscrit(alanyaID));

  @override
  Future<Map<String, dynamic>> etat() async {
    final b = _moi.bundle;
    return {
      'appareilId': appareilId,
      'publie': b != null,
      if (b != null) ...{
        'identityKey': b['identityKey'],
        'registrationId': b['registrationId'],
        'capacite': b['capacite'],
        'signedPreKeyId': (b['signedPreKey'] as Map)['keyId'],
      },
      'otpkLibres': _moi.stock.length,
      'regarnissageNecessaire': _moi.stock.length < 20,
    };
  }

  @override
  Future<Map<String, dynamic>> publier(Map<String, dynamic> bundle) async {
    final nouvelle = _moi.bundle == null || _moi.bundle!['identityKey'] != bundle['identityKey'];
    _moi.bundle = Map<String, dynamic>.from(bundle);
    if (nouvelle) _moi.stock.clear();
    _moi.stock.addAll((bundle['oneTimePreKeys'] as List).cast<Map<String, dynamic>>());
    return {};
  }

  @override
  Future<Map<String, dynamic>> regarnir(List<Map<String, dynamic>> cles) async {
    _moi.stock.addAll(cles);
    return {};
  }

  @override
  Future<Map<String, dynamic>> tournerSignedPreKey(Map<String, dynamic> spk) async {
    _moi.bundle!['signedPreKey'] = spk;
    return {};
  }

  @override
  Future<void> retirer() async {
    _moi.bundle = null;
    _moi.stock.clear();
  }

  @override
  Future<Map<String, dynamic>> appareils(int conversationID) async {
    s.appelsAppareils += 1;
    return {
        'conversationID': conversationID,
        'cibles': [
          for (final e in s.inscrits.entries)
            if (e.key != appareilId && e.value.bundle != null)
              {
                'appareilId': e.key,
                'alanyaID': e.value.alanyaID,
                'estMoi': e.value.alanyaID == alanyaID,
                'identityKey': e.value.bundle!['identityKey'],
                'capacite': e.value.bundle!['capacite'],
              },
        ],
        'e2eeSince': s.e2eeSince?.toIso8601String(),
      };
  }

  @override
  Future<Map<String, dynamic>> bundles(List<int> appareilIds) async {
    final sortie = <Map<String, dynamic>>[];
    for (final id in appareilIds) {
      final i = s.inscrits[id];
      if (i == null || i.bundle == null) continue;
      s.bundlesServis += 1;
      sortie.add({
        'appareilId': id,
        'alanyaID': i.alanyaID,
        'registrationId': i.bundle!['registrationId'],
        'identityKey': i.bundle!['identityKey'],
        'signedPreKey': i.bundle!['signedPreKey'],
        'oneTimePreKey': i.stock.isEmpty ? null : i.stock.removeAt(0),
      });
    }
    return {'bundles': sortie, 'sansCles': <int>[], 'refuses': <int>[]};
  }
}

class Telephone {
  Telephone(FauxServeur serveur, this.alanyaID, this.appareilId)
      : service = E2eeService(
          db: E2eeDatabase(NativeDatabase.memory()),
          cleDuCoffre: CleDuCoffreMemoire(),
          api: serveur.port(alanyaID, appareilId),
        );
  final int alanyaID;
  final int appareilId;
  E2eeService service;
}
