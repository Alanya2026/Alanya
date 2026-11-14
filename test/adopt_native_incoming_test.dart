// Un entrant peut sonner dans la notification native sans que Dart le sache :
// socket tombé pendant l'arrière-plan, le push fait sonner CallKit seul.
//
// Au retour au premier plan (icône, ou tap sur la notification d'un appel
// vidéo), l'application affichait l'accueil pendant que la notification
// sonnait. On reprend désormais l'entrant dans l'écran d'appel de
// l'application — mais seulement quand c'est sans ambiguïté.
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/call/call_terminal_guards.dart';

bool decide({
  bool idle = true,
  bool autoReponse = false,
  String? actif = '4242',
  bool accepte = false,
  bool sortant = false,
}) =>
    shouldAdoptNativeIncoming(
      statusIsIdle: idle,
      autoAnswering: autoReponse,
      activeCallId: actif,
      activeAccepted: accepte,
      activeOutgoing: sortant,
    );

void main() {
  test('entrant qui sonne, Dart sans appel → on le reprend', () {
    expect(decide(), isTrue);
  });

  test('Dart a déjà un appel en main → rien', () {
    // Entrant déjà connu : c'est `resumeForegroundIncoming` qui bascule.
    expect(decide(idle: false), isFalse);
  });

  test('auto-réponse en vol → surtout pas un écran qui sonne', () {
    expect(decide(autoReponse: true), isFalse);
  });

  test('entrée acceptée → c\'est un décrochage, pas un entrant', () {
    expect(decide(accepte: true), isFalse);
  });

  test('notre propre appel sortant n\'est pas un entrant', () {
    expect(decide(sortant: true), isFalse);
  });

  test('aucune entrée, ou un débris de réunion → rien', () {
    expect(decide(actif: null), isFalse);
    expect(decide(actif: '  '), isFalse);
    expect(decide(actif: 'meeting_12'), isFalse);
  });
}
