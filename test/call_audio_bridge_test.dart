// La sortie audio ne changeait plus : Telecom possède la route depuis que
// chaque appel lui est déclaré, et nos demandes partaient vers `AudioManager`,
// qu'il ignore. Ce test tient le contrat du pont : à qui l'on parle, ce qu'on
// lui dit, et ce qu'on fait quand il n'y a personne au bout.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/audio_helper.dart';
import 'package:talky_flutter/core/services/call/call_audio_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const canal = MethodChannel('com.alanya237.alanya/call_audio');
  final appels = <MethodCall>[];
  Map<String, dynamic>? reponse;

  void brancherPont() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (call) async {
      appels.add(call);
      return reponse;
    });
  }

  setUp(() {
    appels.clear();
    reponse = null;
    // Le pont Telecom n'existe que sur Android ; sans cela, la machine de test
    // se déclare « linux » et rien ne partirait.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    brancherPont();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);
  });

  test('la demande part vers Telecom avec l\'identifiant et le nom de sortie',
      () async {
    reponse = {'route': 'speaker', 'available': 1 | 8};

    await AudioHelper.applyAudioRoute(
      CallAudioRoute.speaker,
      telecomCallId: '1789508940989',
    );

    expect(appels.single.method, 'setRoute');
    expect(appels.single.arguments, {
      'callId': '1789508940989',
      'route': 'speaker',
    });
  });

  test('ce que Telecom rapporte fait foi', () async {
    reponse = {'route': 'bluetooth', 'available': 1 | 2 | 8};

    final applique = await AudioHelper.applyAudioRoute(
      CallAudioRoute.earpiece,
      telecomCallId: '42',
    );

    expect(
      resolveAppliedRoute(
        requested: CallAudioRoute.earpiece,
        reportedName: applique.routeName,
      ),
      CallAudioRoute.bluetooth,
      reason: 'Telecom a refusé l\'écouteur : l\'interface doit montrer le '
          'casque, pas la demande',
    );
    expect(
      routesFromSupportedMask(applique.supportedMask!),
      contains(CallAudioRoute.bluetooth),
    );
  });

  test('la sortie tenue avant la demande est transmise', () async {
    reponse = {'route': 'earpiece', 'available': 1 | 8, 'before': 'earpiece'};

    final applique = await AudioHelper.applyAudioRoute(
      CallAudioRoute.speaker,
      telecomCallId: '42',
    );

    expect(applique.routeBeforeName, 'earpiece');
  });

  group('attente de la connexion Telecom', () {
    test('rend vrai dès que Telecom tient l\'appel', () async {
      reponse = {'route': 'earpiece', 'available': 1 | 8};

      expect(await AudioHelper.waitForTelecomConnection('42'), isTrue);
      expect(appels.single.method, 'readRoute');
    });

    test('réessaie tant que la connexion n\'existe pas', () async {
      var lectures = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
        lectures++;
        return lectures < 3 ? null : {'route': 'earpiece'};
      });

      expect(
        await AudioHelper.waitForTelecomConnection(
          '42',
          interval: Duration.zero,
        ),
        isTrue,
      );
      expect(lectures, 3);
    });

    test('abandonne à l\'échéance', () async {
      expect(
        await AudioHelper.waitForTelecomConnection(
          '42',
          timeout: Duration.zero,
          interval: Duration.zero,
        ),
        isFalse,
      );
    });

    test('sans identifiant, ne dérange pas Telecom', () async {
      expect(await AudioHelper.waitForTelecomConnection(null), isFalse);
      expect(appels, isEmpty);
    });

    test('sans pont natif, rend faux sans attendre', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, null);

      expect(await AudioHelper.waitForTelecomConnection('42'), isFalse);
    });
  });

  test('sans connexion Telecom, on retombe sur le chemin WebRTC', () async {
    reponse = null; // le natif répond « je ne tiens pas cet appel »

    final applique = await AudioHelper.applyAudioRoute(
      CallAudioRoute.speaker,
      telecomCallId: '42',
    );

    expect(appels.single.method, 'setRoute');
    expect(applique.routeName, isNull);
    expect(
      applique.supportedMask,
      isNull,
      reason: 'rien de rapporté : la sortie affichée reste celle demandée, et '
          'le repli WebRTC a fait le travail',
    );
  });

  test('sans identifiant d\'appel, on ne dérange pas Telecom', () async {
    for (final id in [null, '', '   ']) {
      appels.clear();
      await AudioHelper.applyAudioRoute(
        CallAudioRoute.earpiece,
        telecomCallId: id,
      );
      expect(appels, isEmpty, reason: 'identifiant=${id ?? "null"}');
    }
  });

  test('la relecture interroge le même pont', () async {
    reponse = {'route': 'earpiece', 'available': 1 | 8};

    final lue = await AudioHelper.readAppliedRoute('42');

    expect(appels.single.method, 'readRoute');
    expect(appels.single.arguments, {'callId': '42'});
    expect(lue?.routeName, 'earpiece');
  });

  test('sans pont natif, l\'appel continue sans lever', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, null);

    final applique = await AudioHelper.applyAudioRoute(
      CallAudioRoute.speaker,
      telecomCallId: '42',
    );

    expect(applique.routeName, isNull);
    expect(await AudioHelper.readAppliedRoute('42'), isNull);
  });
}
