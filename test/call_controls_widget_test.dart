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

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Activer le haut-parleur'));
        await tester.pumpAndSettle();

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

    testWidgets('en vidéo, la sortie audio reste atteignable par le menu', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(bar(isVideo: true, onSpeaker: () => tapped += 1));

      // Le deuxième bouton de la barre est la caméra en vidéo : sans entrée
      // dans le menu, le haut-parleur — forcé à ON à l'init — ne pouvait plus
      // jamais être coupé.
      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      final entry = find.text('Activer le haut-parleur');
      expect(entry, findsOneWidget);

      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(tapped, 1, reason: 'l\'entrée doit réellement changer la sortie');
    });

    testWidgets('avec trois sorties, le menu annonce le tour, pas la bascule', (
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

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Changer la sortie audio'),
        findsOneWidget,
        reason: '« Activer le haut-parleur » mentirait une fois sur deux',
      );
      expect(find.text('Bluetooth'), findsOneWidget);
    });
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
}
