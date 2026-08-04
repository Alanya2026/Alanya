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

    // Depuis que l'e-mail est saisi à l'inscription, un compte tout neuf
    // satisfait `profileLooksComplete` dès sa création. Sans le drapeau
    // « started », relancer l'app en plein onboarding sauterait le parcours —
    // et l'écran identifiants, seul endroit où le code de récupération est
    // montré, ne serait jamais revu.
    test('markStarted forces resuming onboarding even if the profile looks complete',
        () async {
      final service = OnboardingService();
      final user = User(
        alanyaID: 55,
        nom: 'Fresh',
        pseudo: 'fresh',
        alanyaPhone: '+237600000055',
        email: 'fresh@example.com',
        idPays: 10,
        avatarUrl: 'NON DEFINI',
        typeCompte: 0,
        isOnline: false,
        lastSeen: '',
      );

      // Sans le drapeau : l'e-mail seul suffisait à faire passer le compte
      // pour « déjà configuré ».
      expect(service.profileLooksComplete(user), isTrue);

      await service.markStarted(55);
      expect(await service.isStarted(55), isTrue);
      expect(await service.needsOnboarding(user), isTrue);
    });

    test('markCompleted clears the started flag', () async {
      final service = OnboardingService();
      final user = User(
        alanyaID: 56,
        nom: 'Done',
        pseudo: 'done',
        alanyaPhone: '+237600000056',
        email: 'done@example.com',
        idPays: 10,
        avatarUrl: 'https://example.com/a.jpg',
        bio: 'bio',
        typeCompte: 0,
        isOnline: false,
        lastSeen: '',
      );
      await service.markStarted(56);
      await service.markCompleted(56);
      expect(await service.isStarted(56), isFalse);
      expect(await service.needsOnboarding(user), isFalse);
    });

    test('User keeps genre, age, birth year and city through the local cache',
        () {
      final user = User.fromJson({
        'alanyaID': 3,
        'nom': 'Demo',
        'pseudo': 'demo',
        'alanyaPhone': '12345678',
        'email': '',
        'idPays': 10,
        'avatar_url': 'NON DEFINI',
        'type_compte': 0,
        'is_online': 0,
        'last_seen': '',
        'genre': 'femme',
        // MySQL peut renvoyer les entiers en chaîne selon la colonne.
        'age': '27',
        'annee_naissance': 1999,
        'ville': 'Douala',
      });

      expect(user.genre, 'femme');
      expect(user.age, 27);
      expect(user.anneeNaissance, 1999);
      expect(user.ville, 'Douala');

      // Aller-retour par le cache sécurisé (toJson → fromJson) : un champ
      // oublié dans toJson disparaîtrait au redémarrage de l'app.
      final relu = User.fromJson(user.toJson());
      expect(relu.genre, 'femme');
      expect(relu.age, 27);
      expect(relu.anneeNaissance, 1999);
      expect(relu.ville, 'Douala');
    });
  });
}
