import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/call/call_conf_routing.dart';
import 'package:talky_flutter/core/services/callkit_service.dart';

void main() {
  group('isConferenceCallIncoming', () {
    test('sessionKind conference', () {
      expect(
        isConferenceCallIncoming(sessionKind: 'conference', callId: '1'),
        isTrue,
      );
    });
    test('callId conf_ prefix', () {
      expect(
        isConferenceCallIncoming(callId: 'conf_123_1'),
        isTrue,
      );
    });
    test('roomId conf_ prefix', () {
      expect(
        isConferenceCallIncoming(callId: 'x', roomId: 'conf_9_1'),
        isTrue,
      );
    });
    test('1-1 classique', () {
      expect(
        isConferenceCallIncoming(callId: '42', roomId: null),
        isFalse,
      );
    });
  });

  group('IncomingCallAction.isConference', () {
    test('route acceptConferenceInvite', () {
      final a = IncomingCallAction(
        callId: 'conf_1_1',
        callerId: '2',
        callerName: 'A',
        callerPhoto: null,
        isVideo: false,
        roomId: 'conf_1_1',
        sessionKind: 'conference',
        mode: 'transfer',
        action: IncomingCallActionType.accept,
      );
      expect(a.isConference, isTrue);
      expect(a.mode, 'transfer');
    });
    test('1-1 pas conférence', () {
      final a = IncomingCallAction(
        callId: '99',
        callerId: '2',
        callerName: 'A',
        callerPhoto: null,
        isVideo: false,
        roomId: null,
        action: IncomingCallActionType.accept,
      );
      expect(a.isConference, isFalse);
    });
  });

  group('shouldMergeConfInvite', () {
    test('même session incoming → merge', () {
      expect(
        shouldMergeConfInvite(
          callStatusName: 'incoming',
          confSessionId: 'conf_1',
          currentCallId: 'conf_1',
          incomingSessionId: 'conf_1',
        ),
        isTrue,
      );
    });
    test('autre status → pas merge', () {
      expect(
        shouldMergeConfInvite(
          callStatusName: 'connected',
          confSessionId: 'conf_1',
          currentCallId: 'conf_1',
          incomingSessionId: 'conf_1',
        ),
        isFalse,
      );
    });
    test('autre session → pas merge', () {
      expect(
        shouldMergeConfInvite(
          callStatusName: 'incoming',
          confSessionId: 'conf_1',
          currentCallId: 'conf_1',
          incomingSessionId: 'conf_2',
        ),
        isFalse,
      );
    });
  });

  group('canLocalEmitConfReady', () {
    test('B restant peut émettre vers C', () {
      expect(
        canLocalEmitConfReady(
          confMode: 'transfer',
          isTransferInitiator: false,
          isConfInvitee: false,
          peerId: '3',
          localUserId: 2,
          transferTargetId: '3',
        ),
        isTrue,
      );
    });
    test('initiateur n\'émet pas', () {
      expect(
        canLocalEmitConfReady(
          confMode: 'transfer',
          isTransferInitiator: true,
          isConfInvitee: false,
          peerId: '3',
          localUserId: 1,
          transferTargetId: '3',
        ),
        isFalse,
      );
    });
    test('C invité n\'émet pas', () {
      expect(
        canLocalEmitConfReady(
          confMode: 'transfer',
          isTransferInitiator: false,
          isConfInvitee: true,
          peerId: '1',
          localUserId: 3,
          transferTargetId: '3',
        ),
        isFalse,
      );
    });
    test('mode join n\'émet pas', () {
      expect(
        canLocalEmitConfReady(
          confMode: 'join',
          isTransferInitiator: false,
          isConfInvitee: false,
          peerId: '3',
          localUserId: 2,
          transferTargetId: '3',
        ),
        isFalse,
      );
    });
    test('peer ≠ cible transfert → pas de ready', () {
      expect(
        canLocalEmitConfReady(
          confMode: 'transfer',
          isTransferInitiator: false,
          isConfInvitee: false,
          peerId: '1',
          localUserId: 2,
          transferTargetId: '3',
        ),
        isFalse,
      );
    });
    test('sans transferTargetId → pas de ready', () {
      expect(
        canLocalEmitConfReady(
          confMode: 'transfer',
          isTransferInitiator: false,
          isConfInvitee: false,
          peerId: '3',
          localUserId: 2,
        ),
        isFalse,
      );
    });
  });

  group('confJoinFlushDecision', () {
    test('emit quand prêt', () {
      expect(
        confJoinFlushDecision(
          pendingSessionId: 'conf_1',
          confSessionId: 'conf_1',
          isTerminal: false,
          callStatusName: 'joining',
          socketReady: true,
        ),
        ConfQueueFlushResult.emit,
      );
    });
    test('keep si socket pas prêt', () {
      expect(
        confJoinFlushDecision(
          pendingSessionId: 'conf_1',
          confSessionId: 'conf_1',
          isTerminal: false,
          callStatusName: 'connected',
          socketReady: false,
        ),
        ConfQueueFlushResult.keep,
      );
    });
    test('drop si terminal', () {
      expect(
        confJoinFlushDecision(
          pendingSessionId: 'conf_1',
          confSessionId: 'conf_1',
          isTerminal: true,
          callStatusName: 'joining',
          socketReady: true,
        ),
        ConfQueueFlushResult.drop,
      );
    });
  });

  group('confReadyFlushDecision + clé unique', () {
    test('clé idempotente', () {
      expect(confReadyKey('conf_1', '3'), 'conf_1|3');
    });
    test('emit unique path', () {
      expect(
        confReadyFlushDecision(
          keySessionId: 'conf_1',
          confSessionId: 'conf_1',
          isTerminal: false,
          confMode: 'transfer',
          isTransferInitiator: false,
          callStatusName: 'connected',
          socketReady: true,
        ),
        ConfQueueFlushResult.emit,
      );
    });
    test('drop si initiateur', () {
      expect(
        confReadyFlushDecision(
          keySessionId: 'conf_1',
          confSessionId: 'conf_1',
          isTerminal: false,
          confMode: 'transfer',
          isTransferInitiator: true,
          callStatusName: 'connected',
          socketReady: true,
        ),
        ConfQueueFlushResult.drop,
      );
    });
  });

  group('refus conférence', () {
    test('decline CallKit conf → call_conf_reject (contrat event)', () {
      // Le chemin CallKit decline utilise action.isConference pour router
      // vers call_conf_reject plutôt que reject_call.
      final decline = IncomingCallAction(
        callId: 'conf_5_1',
        callerId: '1',
        callerName: 'A',
        callerPhoto: null,
        isVideo: false,
        roomId: 'conf_5_1',
        sessionKind: 'conference',
        mode: 'join',
        action: IncomingCallActionType.decline,
      );
      expect(decline.isConference, isTrue);
      expect(decline.action, IncomingCallActionType.decline);
    });
  });
}
