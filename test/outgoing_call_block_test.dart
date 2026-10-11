import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talky_flutter/core/services/billing/entitlement_service.dart';
import 'package:talky_flutter/core/services/call_service.dart';
import 'package:talky_flutter/talky_api_client.dart';

/// Essai fini, aucun abonnement : on décroche, on ne compose pas.
///
/// Refus avant toute fenêtre d'appel : aucun état « sortant » n'est posé, aucune
/// offre WebRTC ne part, rien n'est à défaire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TalkyApiClient api;
  late EntitlementService rights;
  late CallService calls;
  late List<void> blocked;
  late StreamSubscription<void> sub;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = TalkyApiClient();
    rights = EntitlementService(api: api);
    blocked = [];
    sub = rights.outgoingBlocked.listen(blocked.add);
    calls = CallService(apiClient: api);
  });

  tearDown(() async {
    await sub.cancel();
    calls.dispose();
    rights.dispose();
  });

  Future<void> restrict() => rights.apply({
        'model': 2,
        'phase': 'paid',
        'trial': {'endsAt': '2026-01-01T00:00:00.000Z', 'active': false},
        'exempt': false,
        'features': {'outgoing': false},
      });

  test('un appel 1-à-1 est refusé avant toute fenêtre d\'appel', () async {
    await restrict();
    await calls.initiateCall(
      targetUserId: 7,
      myId: 1,
      myName: 'Moi',
      isVideo: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls.status, CallStatus.idle, reason: 'aucun état sortant posé');
    expect(blocked, hasLength(1), reason: 'le panneau de l\'abonnement s\'ouvre');
  });

  test('un appel de groupe est refusé de même', () async {
    await restrict();
    await calls.createGroupCall(
      roomId: 'room-1',
      myId: 1,
      myName: 'Moi',
      targetUserIds: const [7, 8],
      isVideo: false,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls.status, CallStatus.idle);
    expect(blocked, hasLength(1));
  });

  test('sans appel en cours, ajouter quelqu\'un ne fait rien', () async {
    await restrict();
    // Pas d'appel en cours : `canAddParticipant` est faux, rien ne part non plus.
    calls.addParticipant(9, myName: 'Moi');
    await Future<void>.delayed(Duration.zero);
    expect(calls.status, CallStatus.idle);
  });

  test('avec le droit, aucun signal de refus n\'est émis', () async {
    // Droits inconnus (serveur ancien) : tout est permis — le garde ne se déclenche pas.
    expect(EntitlementService.allowsOutgoing, isTrue);
    expect(blocked, isEmpty);
  });
}
