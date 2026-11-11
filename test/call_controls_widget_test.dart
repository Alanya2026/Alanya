import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/call/call_audio_routes.dart';
import 'package:talky_flutter/core/services/call/call_video_transition_policy.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/widgets/calls/call_control_bar.dart';
import 'package:talky_flutter/widgets/calls/call_top_bar.dart';

/// Les surfaces d'appel de l'interface n'avaient aucun test : plusieurs
/// correctifs livrés ne reposaient que sur la relecture. `CallTopBar` et
/// `CallControlBar` se montent seuls, sans CallService — `context.callUi`
/// retombe sur `CallUiColors.light` quand le thème ne porte pas l'extension.
Widget host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('fr'),
  home: Scaffold(body: child),
);

void main() {
  group('CallTopBar — durée et statut cohabitent (F2)', () {
    testWidgets('les deux s\'affichent ensemble', (tester) async {
      await tester.pumpWidget(
        host(
          CallTopBar(
            name: 'Alfredinho',
            status: 'Reconnexion…',
            duration: '01:23',
            onMinimize: () {},
            useVideoChrome: false,
          ),
        ),
      );

      expect(find.text('01:23'), findsOneWidget);
      expect(
        find.text('Reconnexion…'),
        findsOneWidget,
        reason:
            'la barre affichait la durée OU le statut : « Reconnexion… » '
            'était calculé puis jeté, la durée n\'étant jamais nulle en '
            'reconnexion',
      );
    });

    testWidgets('la durée seule reste seule', (tester) async {
      await tester.pumpWidget(
        host(
          CallTopBar(
            name: 'Alfredinho',
            status: '',
            duration: '00:05',
            onMinimize: () {},
            useVideoChrome: false,
          ),
        ),
      );

      expect(find.text('00:05'), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('sans durée, le statut porte seul', (tester) async {
      await tester.pumpWidget(
        host(
          CallTopBar(
            name: 'Alfredinho',
            status: 'Appel en cours',
            duration: null,
            onMinimize: () {},
            useVideoChrome: false,
          ),
        ),
      );

      expect(find.text('Appel en cours'), findsOneWidget);
    });
  });

  group('CallControlBar — sortie audio accessible en vidéo (F3, T7)', () {
    Widget bar({
      required bool isVideo,
      bool showCameraInAudio = false,
      CallAudioRoute route = CallAudioRoute.earpiece,
      List<CallAudioRoute> routes = const [
        CallAudioRoute.earpiece,
        CallAudioRoute.speaker,
      ],
      VoidCallback? onSpeaker,
    }) => host(
      CallControlBar(
        isVideo: isVideo,
        isMuted: false,
        isVideoOn: true,
        isSpeakerOn: route == CallAudioRoute.speaker,
        audioRoute: route,
        audioRoutes: routes,
        useVideoChrome: isVideo,
        showCameraInAudio: showCameraInAudio,
        onMute: () {},
        onSpeaker: onSpeaker ?? () {},
        onCamera: () {},
        onSwitchCam: () {},
        onHangUp: () {},
      ),
    );

    testWidgets('en audio, le bouton de sortie est dans la barre', (
      tester,
    ) async {
      await tester.pumpWidget(bar(isVideo: false));
      expect(find.byIcon(Icons.bluetooth_audio), findsNothing);
      // L'écouteur est la sortie par défaut d'un appel voix.
      expect(find.byType(CallControlBar), findsOneWidget);
    });

    testWidgets('un appel audio peut afficher le bouton de passage en vidéo', (
      tester,
    ) async {
      await tester.pumpWidget(bar(isVideo: false, showCameraInAudio: true));

      expect(find.byIcon(Icons.videocam), findsOneWidget);
      expect(
        find.bySemanticsLabel('Passer à un appel vidéo ?'),
        findsOneWidget,
      );
    });

    testWidgets(
      'la sortie audio reste accessible avec le bouton caméra audio',
      (tester) async {
        var tapped = 0;
        await tester.pumpWidget(
          bar(
            isVideo: false,
            showCameraInAudio: true,
            onSpeaker: () => tapped += 1,
          ),
        );

        await tester.tap(find.bySemanticsLabel('Activer le haut-parleur'));
        await tester.pump();

        expect(tapped, 1);
      },
    );

    testWidgets('un casque Bluetooth se voit sur le bouton', (tester) async {
      await tester.pumpWidget(
        bar(
          isVideo: false,
          route: CallAudioRoute.bluetooth,
          routes: const [
            CallAudioRoute.earpiece,
            CallAudioRoute.speaker,
            CallAudioRoute.bluetooth,
          ],
        ),
      );

      expect(
        find.byIcon(Icons.bluetooth_audio),
        findsOneWidget,
        reason:
            'le bouton ne disait que « haut-parleur allumé / éteint » : '
            'personne ne savait où sortait le son',
      );
    });

    testWidgets('un casque filaire aussi', (tester) async {
      await tester.pumpWidget(
        bar(
          isVideo: false,
          route: CallAudioRoute.wired,
          routes: const [
            CallAudioRoute.earpiece,
            CallAudioRoute.speaker,
            CallAudioRoute.wired,
          ],
        ),
      );

      expect(find.byIcon(Icons.headset), findsOneWidget);
    });

    testWidgets('en vidéo, la sortie audio est dans la barre, à côté de la caméra', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(bar(isVideo: true, onSpeaker: () => tapped += 1));

      expect(find.byIcon(Icons.videocam), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Activer le haut-parleur'));
      await tester.pump();
      expect(tapped, 1, reason: 'le bouton doit réellement changer la sortie');
    });

    testWidgets('avec trois sorties, le bouton annonce le tour, pas la bascule', (
      tester,
    ) async {
      await tester.pumpWidget(
        bar(
          isVideo: true,
          route: CallAudioRoute.bluetooth,
          routes: const [
            CallAudioRoute.earpiece,
            CallAudioRoute.speaker,
            CallAudioRoute.bluetooth,
          ],
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Changer la sortie audio.*Bluetooth')),
        findsOneWidget,
        reason: '« Activer le haut-parleur » mentirait une fois sur deux',
      );
    });
  });

  test('la caméra ne s\'ouvre à la sonnerie qu\'en vidéo individuelle', () {
    bool applies({
      bool isVideo = true,
      bool isGroup = false,
      bool isConference = false,
      bool cameraTurnedOff = false,
    }) => shouldOpenCameraWhileRinging(
      isVideo: isVideo,
      isGroup: isGroup,
      isConference: isConference,
      cameraTurnedOff: cameraTurnedOff,
    );

    expect(applies(), isTrue);
    expect(applies(isVideo: false), isFalse);
    expect(applies(isGroup: true), isFalse);
    expect(applies(isConference: true), isFalse);
    expect(
      applies(cameraTurnedOff: true),
      isFalse,
      reason: 'couper sa caméra avant de décrocher doit la fermer vraiment',
    );
  });

  test(
    'une renégociation vidéo distante ne coupe pas une caméra déjà active',
    () {
      expect(
        shouldTurnLocalCameraOffForRemoteUpgrade(alreadyInVideoMode: true),
        isFalse,
      );
      expect(
        shouldTurnLocalCameraOffForRemoteUpgrade(alreadyInVideoMode: false),
        isTrue,
      );
    },
  );

  test('une transition terminée ne reste pas valide pour un nouvel appel', () {
    expect(
      isCurrentVideoUpgradeSession(
        activeCallId: 'call-2',
        operationCallId: 'call-1',
        activeRemoteUserId: 20,
        operationRemoteUserId: 20,
        activeTransitionId: 'transition-2',
        operationTransitionId: 'transition-1',
        isConnected: true,
      ),
      isFalse,
    );
  });

  test('une transition reste réconciliable pendant une reconnexion', () {
    expect(
      isActiveVideoUpgradeSession(
        isConnectedOrReconnecting: true,
        activeCallId: 'call-1',
        operationCallId: 'call-1',
        activeRemoteUserId: 20,
        operationRemoteUserId: 20,
        activeTransitionId: 'transition-1',
        operationTransitionId: 'transition-1',
      ),
      isTrue,
    );
  });
}
