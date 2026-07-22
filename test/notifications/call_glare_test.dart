import 'package:flutter_test/flutter_test.dart';

/// Logique glare extraite (miroir call_signaling) pour test unitaire sans socket.
bool shouldAcceptIncomingDespiteOutgoing({
  required String status,
  required String? remoteUserId,
  required String incomingCallerId,
  required bool waitingForOffer,
  required bool callerMatches,
}) {
  final outgoingGlare = (status == 'outgoing' || status == 'connecting') &&
      incomingCallerId.isNotEmpty &&
      incomingCallerId == remoteUserId;
  if (status != 'idle' && !(waitingForOffer && callerMatches) && !outgoingGlare) {
    return false;
  }
  return true;
}

void main() {
  group('Call glare client', () {
    test('outgoing to same peer accepts incoming (glare)', () {
      expect(
        shouldAcceptIncomingDespiteOutgoing(
          status: 'connecting',
          remoteUserId: '42',
          incomingCallerId: '42',
          waitingForOffer: false,
          callerMatches: false,
        ),
        isTrue,
      );
    });

    test('outgoing to other peer ignores incoming', () {
      expect(
        shouldAcceptIncomingDespiteOutgoing(
          status: 'connecting',
          remoteUserId: '42',
          incomingCallerId: '99',
          waitingForOffer: false,
          callerMatches: false,
        ),
        isFalse,
      );
    });

    test('idle always accepts', () {
      expect(
        shouldAcceptIncomingDespiteOutgoing(
          status: 'idle',
          remoteUserId: null,
          incomingCallerId: '1',
          waitingForOffer: false,
          callerMatches: false,
        ),
        isTrue,
      );
    });

    test('incoming waiting for offer from same caller accepted', () {
      expect(
        shouldAcceptIncomingDespiteOutgoing(
          status: 'incoming',
          remoteUserId: '7',
          incomingCallerId: '7',
          waitingForOffer: true,
          callerMatches: true,
        ),
        isTrue,
      );
    });
  });
}
