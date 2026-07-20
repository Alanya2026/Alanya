import 'dart:convert';

import '../db/app_database.dart';
import '../theme/locale_controller.dart';

/// Payload JSON d'un message contact partagé (`type = 7`).
/// Instantané figé au moment de l'envoi (nom / tel / avatar).
class ContactPayload {
  const ContactPayload({
    required this.alanyaID,
    required this.nom,
    this.pseudo,
    this.alanyaPhone,
    this.avatarUrl,
  });

  final int alanyaID;
  final String nom;
  final String? pseudo;
  final String? alanyaPhone;
  final String? avatarUrl;

  String get displayLabel {
    final n = nom.trim();
    if (n.isNotEmpty) return n;
    final p = pseudo?.trim();
    if (p != null && p.isNotEmpty) return p;
    return LocaleController.instance.l10n.contact2;
  }

  String get previewLabel => '👤 $displayLabel';

  String encode() {
    final map = <String, dynamic>{
      'alanyaID': alanyaID,
      'nom': nom.trim(),
    };
    final p = pseudo?.trim();
    if (p != null && p.isNotEmpty) map['pseudo'] = p;
    final phone = alanyaPhone?.trim();
    if (phone != null && phone.isNotEmpty) map['alanyaPhone'] = phone;
    final avatar = avatarUrl?.trim();
    if (avatar != null && avatar.isNotEmpty) map['avatarUrl'] = avatar;
    return jsonEncode(map);
  }

  static ContactPayload? tryParse(String? content) {
    if (content == null || content.trim().isEmpty) return null;
    try {
      final data = jsonDecode(content);
      if (data is! Map) return null;
      final id = data['alanyaID'];
      final alanyaID = id is int
          ? id
          : (id is num ? id.toInt() : int.tryParse(id?.toString() ?? ''));
      if (alanyaID == null || alanyaID <= 0) return null;
      final nom = data['nom'] is String ? (data['nom'] as String).trim() : '';
      final pseudo =
          data['pseudo'] is String ? (data['pseudo'] as String).trim() : null;
      final phone = data['alanyaPhone'] is String
          ? (data['alanyaPhone'] as String).trim()
          : null;
      final avatar = data['avatarUrl'] is String
          ? (data['avatarUrl'] as String).trim()
          : null;
      return ContactPayload(
        alanyaID: alanyaID,
        nom: nom,
        pseudo: (pseudo != null && pseudo.isNotEmpty) ? pseudo : null,
        alanyaPhone: (phone != null && phone.isNotEmpty) ? phone : null,
        avatarUrl: (avatar != null && avatar.isNotEmpty) ? avatar : null,
      );
    } catch (_) {
      return null;
    }
  }

  factory ContactPayload.fromLocalUser(LocalUser u) => ContactPayload(
        alanyaID: u.alanyaID,
        nom: u.nom,
        pseudo: u.pseudo.isNotEmpty ? u.pseudo : null,
        alanyaPhone: u.alanyaPhone.isNotEmpty ? u.alanyaPhone : null,
        avatarUrl: u.avatarUrl.isNotEmpty ? u.avatarUrl : null,
      );
}

/// Aperçu conversation / notif pour un message type 7.
String contactPreviewLabel(String? content) {
  final c = ContactPayload.tryParse(content);
  return c?.previewLabel ?? LocaleController.instance.l10n.contact;
}
