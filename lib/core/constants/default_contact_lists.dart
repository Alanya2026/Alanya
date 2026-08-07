/// Identifiants stables des listes système (alignés sur le backend).
abstract final class ContactListKind {
  static const family = 'family';
  static const friends = 'friends';
  static const work = 'work';
  static const trust = 'trust';
}

/// Spécification d'une liste système semée côté serveur.
class DefaultContactListSpec {
  const DefaultContactListSpec({
    required this.kind,
    required this.color,
    this.memberLimit,
  });

  final String kind;
  final String color;
  final int? memberLimit;
}

const kDefaultContactLists = <DefaultContactListSpec>[
  DefaultContactListSpec(kind: ContactListKind.family, color: '#C2185B'),
  DefaultContactListSpec(kind: ContactListKind.friends, color: '#00796B'),
  DefaultContactListSpec(kind: ContactListKind.work, color: '#3949AB'),
  DefaultContactListSpec(
    kind: ContactListKind.trust,
    color: '#B7791F',
    memberLimit: 5,
  ),
];

const kTrustMemberLimit = 5;

int? memberLimitForContactListKind(String? kind) {
  for (final def in kDefaultContactLists) {
    if (def.kind == kind) return def.memberLimit;
  }
  return null;
}

int defaultContactListSortKey(String? kind) {
  for (var i = 0; i < kDefaultContactLists.length; i++) {
    if (kDefaultContactLists[i].kind == kind) return i;
  }
  return 100;
}

bool isSystemContactListKind(String? kind) =>
    kind != null && defaultContactListSortKey(kind) < 100;
