// Capture d'écran d'une discussion à deux : la ligne système que les deux
// participants lisent, et l'anti-rafale côté client.
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/screenshot_watcher.dart';
import 'package:talky_flutter/core/utils/system_event_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';

import 'fakes/chat_test_harness.dart';

void main() {
  String content({int by = 7, String name = 'Awa'}) =>
      jsonEncode({'e': 'screenshot', 'by': by, 'byName': name});

  group('ligne système « screenshot »', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));

    test('événement connu : une ancienne app l\'ignorait, celle-ci l\'affiche', () {
      expect(SystemEvent.isKnown('screenshot'), isTrue);
      expect(SystemEventPayload.tryParse(content()), isNotNull);
    });

    test('lue par l\'autre : nomme l\'auteur, dans la langue du lecteur', () {
      final p = SystemEventPayload.tryParse(content())!;
      expect(p.label(8, fr), "Awa a fait une capture d'écran de cette discussion");
      expect(p.label(8, en), 'Awa took a screenshot of this chat');
      expect(p.label(8, zh), contains('Awa'));
    });

    test('lue par l\'auteur : « Vous »', () {
      final p = SystemEventPayload.tryParse(content())!;
      expect(p.label(7, fr), "Vous avez fait une capture d'écran de cette discussion");
      expect(p.label(7, en), 'You took a screenshot of this chat');
    });

    test('aperçu de la liste : jamais le JSON, jamais le repli « groupe mis à jour »', () {
      final p = SystemEventPayload.tryParse(content())!;
      final apercu = p.previewLabel(fr);
      expect(apercu, contains('Awa'));
      expect(apercu, isNot(contains('{')));
      expect(apercu, isNot(fr.sysGroupEventFallback));
    });
  });

  group('anti-rafale', () {
    test('une seule alerte par fenêtre, une nouvelle après', () {
      var t = DateTime.utc(2026, 10, 11, 8);
      final gate = ScreenshotAlertGate(clock: () => t);
      expect(gate.allow(), isTrue);
      t = t.add(const Duration(seconds: 59));
      expect(gate.allow(), isFalse);
      t = t.add(const Duration(seconds: 2));
      expect(gate.allow(), isTrue);
    });

    test('un refus ne repousse pas la fenêtre', () {
      var t = DateTime.utc(2026, 10, 11, 8);
      final gate = ScreenshotAlertGate(clock: () => t);
      expect(gate.allow(), isTrue);
      for (var i = 0; i < 5; i++) {
        t = t.add(const Duration(seconds: 20));
        gate.allow();
      }
      // 100 s après la première : la fenêtre est repartie à la 3e (t+60).
      expect(gate.allow(), isFalse);
    });
  });

  group('signalement au serveur', () {
    late ChatTestHarness h;
    setUp(() async {
      h = ChatTestHarness();
      await h.setUp();
    });
    tearDown(() async => h.tearDown());

    test('appelle la route de la conversation', () async {
      await h.repo.signalScreenshot(ChatTestHarness.convId);
      expect(h.api.screenshotSignals, [ChatTestHarness.convId]);
    });

    test('hors ligne ou refus : silencieux', () async {
      h.api.screenshotError = Exception('hors ligne');
      await h.repo.signalScreenshot(ChatTestHarness.convId);
      expect(h.api.screenshotSignals, isEmpty);
    });

    test('identifiant invalide : aucun appel', () async {
      await h.repo.signalScreenshot(0);
      expect(h.api.httpLog.where((l) => l.startsWith('signalScreenshot')), isEmpty);
    });
  });
}
