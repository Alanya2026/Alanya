import 'package:talky_flutter/core/services/onboarding_service.dart';
import 'package:talky_flutter/talky_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingService', () {
    test('needsOnboarding false when already completed', () async {
      final service = OnboardingService();
      final user = User(
        alanyaID: 42,
        nom: 'Test',
        pseudo: 'test',
        alanyaPhone: '+237600000000',
        email: 'done@example.com',
        idPays: 10,
        avatarUrl: '',
        typeCompte: 0,
        isOnline: false,
        lastSeen: '',
      );
      await service.markCompleted(42);
      expect(await service.needsOnboarding(user), isFalse);
    });

    test('profileLooksComplete skips onboarding for legacy users', () async {
      final service = OnboardingService();
      final user = User(
        alanyaID: 7,
        nom: 'Legacy',
        pseudo: 'legacy',
        alanyaPhone: '+237600000001',
        email: 'a@b.com',
        idPays: 10,
        avatarUrl: '',
        typeCompte: 0,
        isOnline: false,
        lastSeen: '',
      );
      expect(service.profileLooksComplete(user), isTrue);
      expect(await service.needsOnboarding(user), isFalse);
      expect(await service.isCompleted(7), isFalse);
    });

    test('persists and restores step index', () async {
      final service = OnboardingService();
      await service.setStepIndex(99, 3);
      expect(await service.getStepIndex(99), 3);
      await service.markCompleted(99);
      expect(await service.getStepIndex(99), 0);
    });

    test('normalizeStepIndex maps legacy 8-step flow to 3 steps', () {
      expect(OnboardingService.normalizeStepIndex(0), 0);
      expect(OnboardingService.normalizeStepIndex(1), 1);
      expect(OnboardingService.normalizeStepIndex(4), 1);
      expect(OnboardingService.normalizeStepIndex(5), 2);
      expect(OnboardingService.normalizeStepIndex(7), 2);
    });

    test('clear removes completion flag', () async {
      final service = OnboardingService();
      await service.markCompleted(5);
      await service.clear(5);
      expect(await service.isCompleted(5), isFalse);
    });

    test('new account with NON DEFINI avatar still needs onboarding', () async {
      final service = OnboardingService();
      final user = User(
        alanyaID: 99,
        nom: 'Nouveau',
        pseudo: 'nouveau',
        alanyaPhone: '+237600000099',
        email: '',
        idPays: 10,
        avatarUrl: 'NON DEFINI',
        typeCompte: 0,
        isOnline: false,
        lastSeen: '',
      );
      expect(service.profileLooksComplete(user), isFalse);
      expect(await service.needsOnboarding(user), isTrue);
    });

    test('recovers false completion once when profile still empty', () async {
      final service = OnboardingService();
      final user = User(
        alanyaID: 88,
        nom: 'Bug',
        pseudo: 'bug',
        alanyaPhone: '+237600000088',
        email: '',
        idPays: 10,
        avatarUrl: 'NON DEFINI',
        typeCompte: 0,
        isOnline: false,
        lastSeen: '',
      );
      await service.markCompleted(88);
      expect(await service.needsOnboarding(user), isTrue);
      expect(await service.isCompleted(88), isFalse);
      // Deuxième passage : déjà corrigé une fois, ne reboucle pas si re-marqué.
      await service.markCompleted(88);
      expect(await service.needsOnboarding(user), isFalse);
    });

    test('afterRegister always requires onboarding', () async {
      final service = OnboardingService();
      final user = User(
        alanyaID: 1,
        nom: 'N',
        pseudo: 'n',
        alanyaPhone: '+237600000001',
        email: 'x@y.com',
        idPays: 12,
        avatarUrl: 'https://example.com/a.jpg',
        bio: 'bio',
        typeCompte: 0,
        isOnline: false,
        lastSeen: '',
      );
      expect(
        await service.needsOnboarding(user, afterRegister: true),
        isTrue,
      );
    });
  });
}
