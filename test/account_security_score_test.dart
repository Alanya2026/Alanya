import 'package:talky_flutter/core/utils/account_security_score.dart';
import 'package:talky_flutter/talky_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final userWithEmail = User(
    alanyaID: 1,
    nom: 'Test',
    pseudo: 'test',
    alanyaPhone: '12345678',
    email: 'a@b.com',
    idPays: 10,
    avatarUrl: '',
    typeCompte: 0,
    isOnline: false,
    lastSeen: '',
  );

  final userNoEmail = User(
    alanyaID: 1,
    nom: 'Test',
    pseudo: 'test',
    alanyaPhone: '12345678',
    email: '',
    idPays: 10,
    avatarUrl: '',
    typeCompte: 0,
    isOnline: false,
    lastSeen: '',
  );

  test('score complet avec email et biométrie', () {
    final r = calculateAccountSecurityScore(
      user: userWithEmail,
      biometricEnabled: true,
    );
    expect(r.score, 100);
    expect(r.suggestionTypes, isEmpty);
    expect(r.isStrong, isTrue);
  });

  test('score partiel sans email ni biométrie', () {
    final r = calculateAccountSecurityScore(
      user: userNoEmail,
      biometricEnabled: false,
    );
    expect(r.score, 32);
    expect(r.suggestionTypes, contains(SecuritySuggestion.addEmail));
    expect(r.suggestionTypes, contains(SecuritySuggestion.enableBiometric));
    expect(r.isStrong, isFalse);
  });

  test('score avec email seulement', () {
    final r = calculateAccountSecurityScore(
      user: userWithEmail,
      biometricEnabled: false,
    );
    expect(r.score, 62);
    expect(r.isModerate, isTrue);
  });
}
