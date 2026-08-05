import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/widgets/common/account_badge.dart';

void main() {
  group('resolveAccountBadge', () {
    test('personnel sans vérif → none', () {
      expect(resolveAccountBadge(0, 0), AccountBadge.none);
    });
    test('business non vérifié → panierDeclare', () {
      expect(resolveAccountBadge(1, 0), AccountBadge.panierDeclare);
    });
    test('business vérifié → panierVerifie', () {
      expect(resolveAccountBadge(1, 2), AccountBadge.panierVerifie);
    });
    test('officiel ignore verification_status → officiel', () {
      expect(resolveAccountBadge(2, 0), AccountBadge.officiel);
      expect(resolveAccountBadge(2, 2), AccountBadge.officiel);
    });
    test('personnel avec statut vérif reste none', () {
      expect(resolveAccountBadge(0, 2), AccountBadge.none);
    });
  });
}
