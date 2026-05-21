import 'package:flutter/widgets.dart';

/// Retourne true si l'URL d'avatar est réellement chargeable.
/// Le backend renvoie parfois le placeholder "NON DEFINI" (ou une chaîne vide),
/// que NetworkImage interpréterait comme `file:///NON%20DEFINI` → crash
/// "No host specified in URI". On ne garde donc que les vraies URLs http(s).
bool hasValidAvatarUrl(String? url) {
  if (url == null) return false;
  final u = url.trim();
  if (u.isEmpty) return false;
  if (u.toUpperCase() == 'NON DEFINI') return false;
  return u.startsWith('http://') || u.startsWith('https://');
}

/// ImageProvider prêt à l'emploi, ou null si l'URL n'est pas valide.
ImageProvider? avatarImage(String? url) =>
    hasValidAvatarUrl(url) ? NetworkImage(url!.trim()) : null;
