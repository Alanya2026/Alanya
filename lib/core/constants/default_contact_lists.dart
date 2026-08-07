/// Listes par défaut semées côté serveur (doc liste-contacts.pdf).
///
/// Couleurs alignées sur [kContactListColors] :
/// Famille rouge, Amis vert, Bureau bleu, Confiance or.
class DefaultContactListSpec {
  const DefaultContactListSpec({
    required this.name,
    required this.color,
    this.memberLimit,
  });

  final String name;
  final String color;

  /// Null = pas de plafond (Famille, Amis, Bureau).
  final int? memberLimit;
}

const kDefaultContactLists = <DefaultContactListSpec>[
  DefaultContactListSpec(name: 'Famille', color: '#C2185B'),
  DefaultContactListSpec(name: 'Amis', color: '#00796B'),
  DefaultContactListSpec(name: 'Bureau', color: '#3949AB'),
  DefaultContactListSpec(name: 'Confiance', color: '#B7791F', memberLimit: 5),
];

const kConfianceListName = 'Confiance';
const kConfianceMemberLimit = 5;
