import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/talky_models.dart';

void main() {
  test('SocketEvents transfer / ready constants', () {
    expect(SocketEvents.callConfReady, 'call_conf_ready');
    expect(SocketEvents.callTransferArmed, 'call_transfer_armed');
    expect(SocketEvents.callTransferDone, 'call_transfer_done');
    expect(SocketEvents.callAddParticipant, 'call_add_participant');
    expect(SocketEvents.callConfJoin, 'call_conf_join');
  });
}
