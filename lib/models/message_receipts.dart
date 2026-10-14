/// Accusés d'un de MES messages de groupe : qui l'a lu, qui l'a reçu, qui ne
/// l'a pas encore reçu (`GET /messages/:id/receipts`, migration serveur 096).
library;

import '../core/utils/contact_aliases.dart';


class ReceiptMember {
  const ReceiptMember({
    required this.alanyaID,
    required this.nom,
    required this.pseudo,
    required this.avatar,
    required this.at,
  });

  final int alanyaID;
  final String nom;
  final String pseudo;
  final String? avatar;

  /// Heure de lecture (ou de réception), `null` si inconnue : messages lus
  /// avant la mise en service des accusés par membre, ou pas encore reçu.
  final DateTime? at;

  String get displayName {
    final alias = ContactAliases.of(alanyaID);
    if (alias != null) return alias;
    if (nom.trim().isNotEmpty) return nom.trim();
    if (pseudo.trim().isNotEmpty) return pseudo.trim();
    return '#$alanyaID';
  }

  factory ReceiptMember.fromJson(Map<String, dynamic> j) {
    final at = j['at'];
    return ReceiptMember(
      alanyaID: (j['alanyaID'] as num?)?.toInt() ?? 0,
      nom: j['nom']?.toString() ?? '',
      pseudo: j['pseudo']?.toString() ?? '',
      avatar: j['avatar']?.toString(),
      at: at == null ? null : DateTime.tryParse(at.toString())?.toLocal(),
    );
  }
}

class MessageReceipts {
  const MessageReceipts({
    required this.total,
    required this.readCount,
    required this.deliveredCount,
    required this.read,
    required this.delivered,
    required this.pending,
  });

  /// Membres à qui le message était destiné (expéditeur et arrivés après exclus).
  final int total;
  final int readCount;

  /// « Reçu par » : lecteurs compris, comme sur WhatsApp.
  final int deliveredCount;
  final List<ReceiptMember> read;

  /// Reçu sans être lu.
  final List<ReceiptMember> delivered;
  final List<ReceiptMember> pending;

  int get pendingCount => total - deliveredCount;

  factory MessageReceipts.fromJson(Map<String, dynamic> j) {
    List<ReceiptMember> liste(String cle) => ((j[cle] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => ReceiptMember.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return MessageReceipts(
      total: (j['total'] as num?)?.toInt() ?? 0,
      readCount: (j['readCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (j['deliveredCount'] as num?)?.toInt() ?? 0,
      read: liste('read'),
      delivered: liste('delivered'),
      pending: liste('pending'),
    );
  }
}

/// Heure d'un accusé : « 10:44 » aujourd'hui, « Hier 10:44 », sinon
/// « 08/10 10:44 ».
String formatReceiptTime(DateTime at, DateTime now, {required String yesterday}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final heure = '${two(at.hour)}:${two(at.minute)}';
  final jour = DateTime(at.year, at.month, at.day);
  final aujourdhui = DateTime(now.year, now.month, now.day);
  final ecart = aujourdhui.difference(jour).inDays;
  if (ecart == 0) return heure;
  if (ecart == 1) return '$yesterday $heure';
  return '${two(at.day)}/${two(at.month)} $heure';
}

/// Parts de la barre empilée lu / reçu seulement / en attente. Les segments
/// vides sont omis (un `Expanded(flex: 0)` est invalide).
List<({String kind, int flex})> receiptBarSegments(MessageReceipts r) {
  final recuSeulement = r.deliveredCount - r.readCount;
  return [
    if (r.readCount > 0) (kind: 'read', flex: r.readCount),
    if (recuSeulement > 0) (kind: 'delivered', flex: recuSeulement),
    if (r.pendingCount > 0) (kind: 'pending', flex: r.pendingCount),
  ];
}
