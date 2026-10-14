// Le badge de l'onglet Discussions compte les discussions, pas les messages
// (signalement du groupe 3GI 2029, bug A19).
import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/unread_badge.dart';

typedef _Conv = ({int nonLus, bool archivee});

int _compter(List<_Conv> convs) => compterDiscussionsNonLues<_Conv>(
      convs,
      nonLus: (c) => c.nonLus,
      archivee: (c) => c.archivee,
    );

void main() {
  test('246 messages dans un groupe : une discussion', () {
    expect(_compter([(nonLus: 246, archivee: false)]), 1);
  });

  test('discussions lues et archivées exclues', () {
    expect(
      _compter([
        (nonLus: 3, archivee: false),
        (nonLus: 0, archivee: false),
        (nonLus: 12, archivee: true),
        (nonLus: 1, archivee: false),
      ]),
      2,
    );
  });
}
