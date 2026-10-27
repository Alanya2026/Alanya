import 'dart:async';
import 'dart:io';

import 'package:mime/mime.dart';

import '../../../talky_api_client.dart';
import '../alanya_media_export_service.dart';
import 'signature_document.dart';

/// Le résultat d'un enregistrement : la copie, et si elle a pu être rangée.
class CopieEnregistree {
  const CopieEnregistree({required this.copie, required this.enregistree});

  final CopieSignee copie;
  final bool enregistree;
}

/// FAIRE SORTIR UN DOCUMENT SENSIBLE (reprise d'Alanya Work).
///
/// Seul l'ENREGISTREMENT sort un document sensible de l'application : ni
/// partage ni transfert. La copie enregistrée est signée
/// (`SignatureDocument` : texte aux quatre bords, métadonnées, empreinte) et
/// le geste est noté par le serveur avec l'empreinte.
class SortieDocumentSensible {
  SortieDocumentSensible(this._api, {required this.numero});

  final TalkyApiClient _api;

  /// L'Alanya ID de qui fait sortir la copie.
  final String numero;

  /// Signe [clair], range la copie dans les dossiers Alanya (et la galerie
  /// pour une photo ou une vidéo), puis note le geste. Une signature
  /// impossible n'empêche pas l'enregistrement (`copie.signee` vaut faux) ;
  /// la trace, elle, n'est notée que si la copie est bien sortie.
  Future<CopieEnregistree> enregistrer({
    required File clair,
    required int msgID,
    required int type,
    required String nom,
    required bool jeSuisExpediteur,
  }) async {
    final signature = SignatureSortie.nouvelle(
      geste: GesteSortie.telechargement,
      alanyaId: numero,
      appareil: await _api.appareilCourant(),
      // Le destinataire n'apprend pas le numéro de l'expéditeur par la copie.
      expediteurId: jeSuisExpediteur ? numero : null,
      mediaId: '$msgID',
    );
    final copie = await SignatureDocument.signer(
      source: clair,
      nom: nom,
      mime: lookupMimeType(nom) ?? '',
      signature: signature,
    );
    final ok = await AlanyaMediaExportService.instance.saveNow(
      // Un audio n'a pas de dossier à lui : il rejoint les documents.
      type: type == 3 ? 4 : type,
      localPath: copie.fichier.path,
      mediaName: copie.nom,
    );
    if (ok) unawaited(_noter(signature, msgID));
    return CopieEnregistree(copie: copie, enregistree: ok);
  }

  /// La trace au serveur. Ne bloque jamais le geste : hors ligne, la copie
  /// garde ses métadonnées, seule la ligne serveur manque.
  Future<void> _noter(SignatureSortie s, int msgID) async {
    try {
      await _api.noterGesteSensible(
        msgID: msgID,
        geste: GesteSensible.values.firstWhere((g) => g.code == s.geste.code),
        empreinte: s.code,
      );
    } catch (_) {}
  }
}
