import 'package:talky_flutter/core/services/call/call_audio_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('passage en vidéo', () {
    test('l\'écouteur cède la place au haut-parleur', () {
      expect(
        routeForVideoUpgrade(
          current: CallAudioRoute.earpiece,
          wasAlreadyVideo: false,
        ),
        CallAudioRoute.speaker,
      );
    });

    test('un casque reste en place', () {
      for (final route in [CallAudioRoute.wired, CallAudioRoute.bluetooth]) {
        expect(
          routeForVideoUpgrade(current: route, wasAlreadyVideo: false),
          isNull,
          reason: route.name,
        );
      }
    });

    test('rallumer sa caméra dans un appel vidéo garde le choix fait', () {
      expect(
        routeForVideoUpgrade(
          current: CallAudioRoute.earpiece,
          wasAlreadyVideo: true,
        ),
        isNull,
      );
    });
  });

  group('familles d\'appareils', () {
    test('les types Bluetooth sont reconnus, profil compris', () {
      for (final t in ['bluetoothSco', 'bluetoothA2dp', 'bluetoothLe']) {
        expect(
          audioOutputKindFromTypeName(t),
          AudioOutputKind.bluetooth,
          reason: t,
        );
      }
    });

    test('le filaire couvre casque, écouteurs et prise ligne', () {
      for (final t in [
        'wiredHeadset',
        'wiredHeadphones',
        'headsetMic',
        'lineAnalog',
        'lineDigital',
        'usbHeadset',
      ]) {
        expect(audioOutputKindFromTypeName(t), AudioOutputKind.wired, reason: t);
      }
    });

    test('écouteur et haut-parleur intégrés', () {
      expect(
        audioOutputKindFromTypeName('builtInEarpiece'),
        AudioOutputKind.earpiece,
      );
      expect(
        audioOutputKindFromTypeName('builtInSpeaker'),
        AudioOutputKind.speaker,
      );
    });

    test('un type inconnu ne devient pas une route', () {
      expect(audioOutputKindFromTypeName('hdmi'), AudioOutputKind.other);
      expect(audioOutputKindFromTypeName(''), AudioOutputKind.other);
    });
  });

  group('routes disponibles', () {
    test('sans périphérique : écouteur et haut-parleur', () {
      expect(
        availableAudioRoutes({AudioOutputKind.earpiece, AudioOutputKind.speaker}),
        [CallAudioRoute.earpiece, CallAudioRoute.speaker],
      );
    });

    test('les deux intégrés sont offerts même si la plateforme les tait', () {
      expect(
        availableAudioRoutes({AudioOutputKind.bluetooth}),
        [CallAudioRoute.earpiece, CallAudioRoute.speaker, CallAudioRoute.bluetooth],
        reason: 'certains Android n\'énumèrent plus l\'écouteur quand un casque '
            'est connecté',
      );
    });

    test('un casque Bluetooth ajoute sa route', () {
      expect(
        availableAudioRoutes({
          AudioOutputKind.earpiece,
          AudioOutputKind.speaker,
          AudioOutputKind.bluetooth,
        }),
        contains(CallAudioRoute.bluetooth),
      );
    });

    test('un type inconnu n\'ajoute rien', () {
      expect(
        availableAudioRoutes({AudioOutputKind.earpiece, AudioOutputKind.other}),
        [CallAudioRoute.earpiece, CallAudioRoute.speaker],
      );
    });
  });

  group('route par défaut', () {
    test('le Bluetooth gagne, même en vidéo', () {
      expect(
        defaultAudioRoute(kinds: {AudioOutputKind.bluetooth}, isVideo: true),
        CallAudioRoute.bluetooth,
      );
      expect(
        defaultAudioRoute(kinds: {AudioOutputKind.bluetooth}, isVideo: false),
        CallAudioRoute.bluetooth,
      );
    });

    test('le filaire passe avant les intégrés', () {
      expect(
        defaultAudioRoute(kinds: {AudioOutputKind.wired}, isVideo: true),
        CallAudioRoute.wired,
      );
    });

    test('le Bluetooth passe avant le filaire', () {
      expect(
        defaultAudioRoute(
          kinds: {AudioOutputKind.wired, AudioOutputKind.bluetooth},
          isVideo: false,
        ),
        CallAudioRoute.bluetooth,
      );
    });

    test('sans périphérique, on garde le comportement d\'avant', () {
      expect(
        defaultAudioRoute(kinds: {}, isVideo: true),
        CallAudioRoute.speaker,
        reason: 'la vidéo sortait déjà au haut-parleur',
      );
      expect(
        defaultAudioRoute(kinds: {}, isVideo: false),
        CallAudioRoute.earpiece,
      );
    });
  });

  group('rotation du bouton', () {
    final deux = [CallAudioRoute.earpiece, CallAudioRoute.speaker];
    final trois = [
      CallAudioRoute.earpiece,
      CallAudioRoute.speaker,
      CallAudioRoute.bluetooth,
    ];

    test('à deux routes, le bouton reste une bascule', () {
      expect(
        nextAudioRoute(current: CallAudioRoute.earpiece, available: deux),
        CallAudioRoute.speaker,
      );
      expect(
        nextAudioRoute(current: CallAudioRoute.speaker, available: deux),
        CallAudioRoute.earpiece,
      );
    });

    test('à trois, il fait le tour et revient', () {
      expect(
        nextAudioRoute(current: CallAudioRoute.speaker, available: trois),
        CallAudioRoute.bluetooth,
      );
      expect(
        nextAudioRoute(current: CallAudioRoute.bluetooth, available: trois),
        CallAudioRoute.earpiece,
      );
    });

    test('depuis une route disparue, on repart du début', () {
      expect(
        nextAudioRoute(current: CallAudioRoute.bluetooth, available: deux),
        CallAudioRoute.earpiece,
      );
    });

    test('liste vide : rien ne bouge', () {
      expect(
        nextAudioRoute(current: CallAudioRoute.speaker, available: const []),
        CallAudioRoute.speaker,
      );
    });
  });

  group('changement de périphérique en cours d\'appel', () {
    test('le choix de l\'utilisateur est conservé s\'il reste possible', () {
      expect(
        resolveAudioRouteAfterChange(
          current: CallAudioRoute.earpiece,
          kinds: {AudioOutputKind.bluetooth},
          isVideo: false,
        ),
        CallAudioRoute.earpiece,
        reason: 'brancher un casque ne doit pas voler le choix en cours',
      );
    });

    test('un casque débranché renvoie au défaut', () {
      expect(
        resolveAudioRouteAfterChange(
          current: CallAudioRoute.bluetooth,
          kinds: {AudioOutputKind.earpiece, AudioOutputKind.speaker},
          isVideo: false,
        ),
        CallAudioRoute.earpiece,
      );
      expect(
        resolveAudioRouteAfterChange(
          current: CallAudioRoute.wired,
          kinds: {},
          isVideo: true,
        ),
        CallAudioRoute.speaker,
      );
    });

    test('un casque débranché au profit d\'un autre suit le nouveau', () {
      expect(
        resolveAudioRouteAfterChange(
          current: CallAudioRoute.wired,
          kinds: {AudioOutputKind.bluetooth},
          isVideo: false,
        ),
        CallAudioRoute.bluetooth,
      );
    });
  });

  group('réglage WebRTC', () {
    test('seul le haut-parleur allume le haut-parleur', () {
      expect(speakerphoneForRoute(CallAudioRoute.speaker), isTrue);
      for (final r in [
        CallAudioRoute.earpiece,
        CallAudioRoute.wired,
        CallAudioRoute.bluetooth,
      ]) {
        expect(speakerphoneForRoute(r), isFalse, reason: r.name);
      }
    });
  });

  group('extinction par proximité', () {
    test('l\'écouteur interne éteint l\'écran', () {
      expect(
        proximityBlankingApplies(
          route: CallAudioRoute.earpiece,
          callActive: true,
        ),
        isTrue,
      );
    });

    test('toute autre sortie le laisse allumé', () {
      for (final r in [
        CallAudioRoute.speaker,
        CallAudioRoute.wired,
        CallAudioRoute.bluetooth,
      ]) {
        expect(
          proximityBlankingApplies(route: r, callActive: true),
          isFalse,
          reason: '${r.name} : on regarde l\'écran à distance, une main qui '
              'passe devant le capteur ne doit pas l\'éteindre',
        );
      }
    });

    test('hors appel, jamais', () {
      expect(
        proximityBlankingApplies(
          route: CallAudioRoute.earpiece,
          callActive: false,
        ),
        isFalse,
      );
    });
  });

  group('wakelock écran', () {
    bool wakelock({
      bool isVideo = true,
      CallAudioRoute route = CallAudioRoute.speaker,
      bool callActive = true,
    }) =>
        screenWakelockApplies(
          isVideo: isVideo,
          route: route,
          callActive: callActive,
        );

    test('une vidéo sur haut-parleur tient l\'écran allumé', () {
      expect(wakelock(), isTrue);
    });

    test('la voix n\'a pas besoin du wakelock', () {
      expect(wakelock(isVideo: false), isFalse);
    });

    test('une vidéo basculée sur l\'écouteur laisse la proximité gagner', () {
      expect(
        wakelock(route: CallAudioRoute.earpiece),
        isFalse,
        reason: 'les deux s\'opposent : l\'un force l\'écran allumé pendant '
            'que l\'autre veut l\'éteindre',
      );
    });

    test('hors appel, jamais', () {
      expect(wakelock(callActive: false), isFalse);
    });
  });
}
