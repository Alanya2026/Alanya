import '../db/app_database.dart';
import '../../talky_models.dart';
import 'alanya_phone_formatter.dart';

User localUserToUser(LocalUser u) => User(
      alanyaID: u.alanyaID,
      nom: u.nom,
      pseudo: u.pseudo,
      alanyaPhone: u.alanyaPhone,
      email: u.email,
      idPays: u.idPays,
      avatarUrl: u.avatarUrl,
      typeCompte: u.typeCompte,
      isOnline: u.isOnline,
      lastSeen: u.lastSeen?.toIso8601String() ?? '',
      addedViaQr: u.addedViaQr,
      preferredAddedAt: u.preferredAddedAt,
      preferredNote: u.preferredNote ?? '',
      paysLibelle: u.paysLibelle,
    );

/// Filtre local par nom, pseudo ou numéro Alanya (partiel).
bool userMatchesSearch(User user, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;

  if (user.nom.toLowerCase().contains(q)) return true;
  if (user.pseudo.toLowerCase().contains(q)) return true;

  final qDigits = AlanyaPhoneFormatter.normalize(q);
  if (qDigits.isNotEmpty && user.alanyaPhone.contains(qDigits)) return true;

  return false;
}

List<User> filterUsersBySearch(List<User> users, String query) =>
    users.where((u) => userMatchesSearch(u, query)).toList();
