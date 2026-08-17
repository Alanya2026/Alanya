/// Décide ce qui, dans un message, peut être confié à un traducteur.
///
/// Fonction pure et isolée du service : c'est le filtre dont dépend l'intégrité
/// du fil, et il doit être testable sans instancier ML Kit ni base de données.
library;

import '../../db/app_database.dart';
import '../../utils/media_album.dart';

/// Types dont le contenu est de la prose.
///
/// **Liste blanche volontaire.** 0 = texte, 1 à 4 = médias (seule leur légende
/// est concernée). Les types 5 et suivants — localisation, message système,
/// contact, CTA de bienvenue, trajet — stockent du **JSON** dans `content` :
/// le passer à un traducteur détruirait le rendu de la bulle.
///
/// Une liste noire laisserait un futur type 10 filer au traducteur par défaut ;
/// ici il reste exclu tant que personne ne l'a explicitement autorisé.
const Set<int> kTranslatableMessageTypes = {0, 1, 2, 3, 4};

/// En deçà, l'identification de langue devine plus qu'elle ne détecte.
///
/// Une bonne part du trafic d'un chat (« ok », « 👍 », « à demain ») tombe sous
/// ce seuil et restera non traduite : c'est délibéré. Abaisser le seuil
/// produirait des traductions absurdes sur des messages que le lecteur
/// comprenait de toute façon.
const int kMinTranslatableChars = 15;

/// Texte traduisible d'un message, ou `null` s'il n'y a rien à traduire.
String? translatableTextOf(LocalMessage m) {
  if (m.isDeleted) return null;
  if (!kTranslatableMessageTypes.contains(m.type)) return null;

  // Vue unique non consultée : la légende n'apparaît que dans la visionneuse,
  // et le média peut disparaître avant d'être ouvert.
  if (m.isViewOnce && m.viewedAt == null) return null;

  final raw = m.content?.trim();
  if (raw == null || raw.isEmpty) return null;

  // Marqueur d'album (`__talky_album__|…`) : sentinelle technique, pas de la
  // prose. Le traduire casserait le regroupement des médias.
  if (raw.startsWith(albumMarkerPrefix)) return null;

  if (raw.length < kMinTranslatableChars) return null;
  return raw;
}
