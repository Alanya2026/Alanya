// Le bouton de sortie audio ne faisait rien : depuis que chaque appel est
// déclaré à Telecom, c'est Android qui arbitre la route, et nos demandes
// passaient par `AudioManager.setSpeakerphoneOn`, qu'il ignore. Second défaut,
// indépendant : « enlever le haut-parleur » signifie, côté flutter_webrtc,
// « prendre le premier appareil disponible parmi Bluetooth, filaire, écouteur »
// — avec un casque appairé, l'écouteur était donc inatteignable.

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/call/call_audio_routes.dart';

void main() {
  group('chaque sortie se demande par son nom', () {
    test('les quatre identifiants attendus par flutter_webrtc', () {
      expect(webrtcDeviceId(CallAudioRoute.earpiece), 'earpiece');
      expect(webrtcDeviceId(CallAudioRoute.speaker), 'speaker');
      expect(webrtcDeviceId(CallAudioRoute.wired), 'wired-headset');
      expect(webrtcDeviceId(CallAudioRoute.bluetooth), 'bluetooth');
    });

    test('l\'écouteur ne se confond plus avec le filaire', () {
      expect(
        webrtcDeviceId(CallAudioRoute.earpiece),
        isNot(webrtcDeviceId(CallAudioRoute.wired)),
        reason: 'les deux passaient par le même appel booléen, qui rendait la '
            'main au premier appareil branché',
      );
    });
  });

  group('aller-retour avec Telecom', () {
    test('chaque sortie se nomme et se relit', () {
      for (final route in CallAudioRoute.values) {
        expect(
          routeFromTelecomName(telecomRouteName(route)),
          route,
          reason: route.name,
        );
      }
    });

    test('un nom inconnu ne désigne rien', () {
      for (final nom in [null, '', 'inconnu', 'ROUTE_SPEAKER']) {
        expect(routeFromTelecomName(nom), isNull, reason: '$nom');
      }
    });
  });

  group('sorties disponibles d\'après le masque Telecom', () {
    test('écouteur et haut-parleur seuls', () {
      expect(
        routesFromSupportedMask(1 | 8),
        [CallAudioRoute.earpiece, CallAudioRoute.speaker],
      );
    });

    test('avec un casque Bluetooth', () {
      expect(
        routesFromSupportedMask(1 | 8 | 2),
        [
          CallAudioRoute.earpiece,
          CallAudioRoute.speaker,
          CallAudioRoute.bluetooth,
        ],
        reason: 'le Bluetooth doit être atteignable, mais après l\'écouteur : '
            'l\'ordre du bouton ne change pas',
      );
    });

    test('les quatre, dans l\'ordre d\'affichage', () {
      expect(
        routesFromSupportedMask(1 | 2 | 4 | 8),
        [
          CallAudioRoute.earpiece,
          CallAudioRoute.speaker,
          CallAudioRoute.wired,
          CallAudioRoute.bluetooth,
        ],
      );
    });

    test('un masque vide n\'annonce rien', () {
      expect(routesFromSupportedMask(0), isEmpty);
    });
  });

  group('la sortie affichée est celle qui s\'applique', () {
    test('le natif fait autorité', () {
      expect(
        resolveAppliedRoute(
          requested: CallAudioRoute.earpiece,
          reportedName: 'bluetooth',
        ),
        CallAudioRoute.bluetooth,
        reason: 'Telecom peut refuser la demande : afficher l\'écouteur alors '
            'que le son sort du casque, c\'est mentir à l\'utilisateur',
      );
    });

    test('sans réponse du natif, on montre ce qu\'on a demandé', () {
      for (final absent in [null, '', 'inconnu']) {
        expect(
          resolveAppliedRoute(
            requested: CallAudioRoute.speaker,
            reportedName: absent,
          ),
          CallAudioRoute.speaker,
          reason: '$absent',
        );
      }
    });
  });

  // Il fallait deux appuis sur le bouton pour changer de sortie. Telecom relit
  // la route avant d'avoir fini de l'appliquer — plus d'une seconde vers un
  // casque Bluetooth —, l'application adoptait cette lecture périmée, et
  // l'appui suivant recalculait donc la même cible.
  group('après une demande', () {
    test('une relecture qui annonce la sortie précédente est périmée', () {
      expect(
        routeApresDemande(
          precedente: CallAudioRoute.bluetooth,
          demandee: CallAudioRoute.earpiece,
          rapportee: 'bluetooth',
        ),
        CallAudioRoute.earpiece,
        reason: 'Telecom n\'a pas fini d\'appliquer : sa relecture est en '
            'retard, pas en désaccord',
      );
    });

    test('une troisième sortie est un vrai arbitrage, et elle gagne', () {
      expect(
        routeApresDemande(
          precedente: CallAudioRoute.speaker,
          demandee: CallAudioRoute.earpiece,
          rapportee: 'wired',
        ),
        CallAudioRoute.wired,
        reason: 'ni la précédente ni la demandée : un casque filaire a imposé '
            'sa loi, et l\'interface doit le montrer',
      );
    });

    test('la demande confirmée reste la demande', () {
      expect(
        routeApresDemande(
          precedente: CallAudioRoute.earpiece,
          demandee: CallAudioRoute.speaker,
          rapportee: 'speaker',
        ),
        CallAudioRoute.speaker,
      );
    });

    test('sans relecture, la demande fait foi', () {
      for (final absent in [null, '', 'inconnu']) {
        expect(
          routeApresDemande(
            precedente: CallAudioRoute.earpiece,
            demandee: CallAudioRoute.speaker,
            rapportee: absent,
          ),
          CallAudioRoute.speaker,
          reason: absent ?? 'null',
        );
      }
    });
  });

  // Mesuré sur un Xiaomi sous Android 16 : le haut-parleur posé par le chemin
  // WebRTC, Telecom encore sur l'écouteur. La relecture périmée passait pour un
  // arbitrage : l'icône annonçait l'écouteur et le son sortait du haut-parleur.
  group('la sortie que tenait Telecom', () {
    test('reconnaît une relecture périmée quand l\'application croit autre chose',
        () {
      expect(
        routeApresDemande(
          precedente: CallAudioRoute.speaker,
          demandee: CallAudioRoute.speaker,
          rapportee: 'earpiece',
          avantTelecom: 'earpiece',
        ),
        CallAudioRoute.speaker,
      );
    });

    test('laisse passer un vrai arbitrage', () {
      expect(
        routeApresDemande(
          precedente: CallAudioRoute.speaker,
          demandee: CallAudioRoute.speaker,
          rapportee: 'wired',
          avantTelecom: 'earpiece',
        ),
        CallAudioRoute.wired,
      );
    });

    test('à défaut, on compare à ce que croyait l\'application', () {
      expect(
        routeApresDemande(
          precedente: CallAudioRoute.earpiece,
          demandee: CallAudioRoute.speaker,
          rapportee: 'earpiece',
        ),
        CallAudioRoute.speaker,
      );
    });
  });

  // Appel vidéo reçu : Telecom crée sa connexion après la demande et prend
  // l'écouteur. Sans cette vérification, le son restait à l'écouteur.
  group('convergerRouteTelecom', () {
    Future<(CallAudioRoute?, int)> converger(
      List<CallAudioRoute?> lectures, {
      CallAudioRoute voulue = CallAudioRoute.speaker,
      bool Function()? valable,
    }) async {
      var demandes = 0;
      var i = 0;
      final tenue = await convergerRouteTelecom(
        voulue: voulue,
        redemander: () async => demandes++,
        lire: () async => lectures[i++],
        valable: valable ?? () => true,
        battement: Duration.zero,
      );
      return (tenue, demandes);
    }

    test('ne redemande rien quand Telecom a déjà pris la sortie', () async {
      final (tenue, demandes) = await converger([CallAudioRoute.speaker]);
      expect(tenue, CallAudioRoute.speaker);
      expect(demandes, 0);
    });

    test('redemande tant que Telecom reste sur l\'écouteur', () async {
      final (tenue, demandes) = await converger([
        CallAudioRoute.earpiece,
        CallAudioRoute.speaker,
      ]);
      expect(tenue, CallAudioRoute.speaker);
      expect(demandes, 1);
    });

    test('rend la sortie réelle quand Telecom refuse jusqu\'au bout', () async {
      final (tenue, demandes) = await converger([
        CallAudioRoute.earpiece,
        CallAudioRoute.earpiece,
        CallAudioRoute.earpiece,
      ]);
      expect(tenue, CallAudioRoute.earpiece,
          reason: 'l\'icône doit dire la vérité');
      expect(demandes, 2);
    });

    test('ne combat jamais un casque', () async {
      for (final casque in [CallAudioRoute.wired, CallAudioRoute.bluetooth]) {
        final (tenue, demandes) = await converger([casque]);
        expect(tenue, casque);
        expect(demandes, 0);
      }
    });

    test('s\'arrête dès que l\'appel ou la demande a changé', () async {
      final (tenue, demandes) = await converger(
        [CallAudioRoute.earpiece],
        valable: () => false,
      );
      expect(tenue, isNull);
      expect(demandes, 0);
    });

    test('sans lecture, rien à corriger', () async {
      final (tenue, demandes) = await converger([null]);
      expect(tenue, isNull);
      expect(demandes, 0);
    });
  });

  // Le test qui tient la régression : il compose les deux fonctions exactement
  // comme le fait `setAudioRoute`, face à un natif systématiquement en retard.
  group('le bouton face à un natif en retard', () {
    const disponibles = [
      CallAudioRoute.earpiece,
      CallAudioRoute.speaker,
      CallAudioRoute.bluetooth,
    ];

    /// Trois appuis, avec un natif qui relit toujours la sortie précédente.
    List<CallAudioRoute> troisAppuis() {
      var courante = CallAudioRoute.earpiece;
      final visitees = <CallAudioRoute>[];
      for (var i = 0; i < 3; i++) {
        final cible = nextAudioRoute(current: courante, available: disponibles);
        courante = routeApresDemande(
          precedente: courante,
          demandee: cible,
          rapportee: telecomRouteName(courante),
        );
        visitees.add(courante);
      }
      return visitees;
    }

    test('chaque appui avance d\'un cran', () {
      expect(
        troisAppuis(),
        const [
          CallAudioRoute.speaker,
          CallAudioRoute.bluetooth,
          CallAudioRoute.earpiece,
        ],
        reason: 'le tour complet en trois appuis ; en adoptant la relecture, '
            'le bouton restait sur place et il en fallait six',
      );
    });

    test('aucun appui ne retombe sur la sortie qu\'il quittait', () {
      final visitees = troisAppuis();
      expect(visitees.toSet().length, visitees.length);
    });
  });
}
