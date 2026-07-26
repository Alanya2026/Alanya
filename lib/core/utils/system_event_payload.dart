import 'dart:convert';

/// Type de message réservé aux événements de groupe (« X a ajouté Y »).
///
/// Le 6 était le seul code libre entre la localisation (5) et la carte de
/// contact (7). Voir la migration serveur 024.
const int kSystemMessageType = 6;

/// Événements portés par un message système. Les valeurs sont le champ `e` du
/// JSON serveur et ne doivent jamais changer : elles sont écrites en base.
abstract final class SystemEvent {
  static const groupCreated = 'group_created';
  static const memberAdded = 'member_added';
  static const memberRemoved = 'member_removed';
  static const memberLeft = 'member_left';
  static const groupRenamed = 'group_renamed';
  static const groupPhotoChanged = 'group_photo_changed';
  static const groupDescriptionChanged = 'group_description_changed';
  static const roleChanged = 'role_changed';
  static const settingsChanged = 'settings_changed';

  static const _known = {
    groupCreated,
    memberAdded,
    memberRemoved,
    memberLeft,
    groupRenamed,
    groupPhotoChanged,
    groupDescriptionChanged,
    roleChanged,
    settingsChanged,
  };

  static bool isKnown(String e) => _known.contains(e);
}

/// Contenu décodé d'un message système.
///
/// Le serveur stocke un payload **machine-lisible**, jamais une phrase
/// pré-rendue : le fil doit s'afficher dans la langue du lecteur, pas dans
/// celle de l'acteur. Le rendu du libellé se fait côté widget.
///
/// [actorName] et [names] sont **dénormalisés à l'écriture** côté serveur : le
/// nom d'un membre exclu n'est plus résoluble via `participants`, et le fil
/// afficherait sinon « a retiré (inconnu) ». Même parti pris que
/// `Message.replyToContent`.
class SystemEventPayload {
  /// Identifiant de l'événement (`member_added`, …).
  final String event;

  /// Auteur de l'action.
  final int actorId;
  final String actorName;

  /// Cibles de l'action, quand il y en a (ajout, retrait, changement de rôle).
  final List<int> targetIds;
  final List<String> targetNames;

  /// Valeur associée : nouveau nom du groupe, nouvelle description…
  final String? value;

  /// `role_changed` : rôle attribué. `settings_changed` : verrou concerné
  /// (`send` / `edit`) et son nouvel état.
  final int? role;
  final String? lock;
  final bool lockEnabled;

  const SystemEventPayload({
    required this.event,
    required this.actorId,
    required this.actorName,
    this.targetIds = const [],
    this.targetNames = const [],
    this.value,
    this.role,
    this.lock,
    this.lockEnabled = false,
  });

  /// Décode le `content` d'un message de type [kSystemMessageType].
  ///
  /// Renvoie `null` sur un JSON invalide **ou un événement inconnu** : une
  /// version future du serveur peut émettre un événement que ce client ne
  /// connaît pas, et il vaut mieux ne rien afficher que du JSON brut.
  static SystemEventPayload? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;

    final event = decoded['e'];
    if (event is! String || !SystemEvent.isKnown(event)) return null;

    return SystemEventPayload(
      event: event,
      actorId: _asInt(decoded['by']) ?? 0,
      actorName: decoded['byName']?.toString() ?? '',
      targetIds: _intList(decoded['ids']),
      targetNames: _stringList(decoded['names']),
      value: decoded['value']?.toString(),
      role: _asInt(decoded['role']),
      lock: decoded['lock']?.toString(),
      lockEnabled: decoded['on'] == 1 || decoded['on'] == true ||
          decoded['on'] == '1',
    );
  }

  /// Un `as num?` lèverait sur une valeur transmise en chaîne — ce qui arrive
  /// dès qu'un intermédiaire (payload push, sérialisation JS) stringifie les
  /// entiers. Le parseur doit dégrader, pas planter.
  static int? _asInt(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Les noms tels qu'ils seront affichés, joints proprement.
  ///
  /// Repli sur `targetIds` quand `names` manque (payload d'une version
  /// antérieure) : mieux vaut « a retiré 2 membres » qu'une phrase tronquée.
  String targetLabel({required String separator}) =>
      targetNames.where((n) => n.trim().isNotEmpty).join(separator);

  bool get hasTargetNames =>
      targetNames.any((n) => n.trim().isNotEmpty);

  static List<int> _intList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => (e is num) ? e.toInt() : int.tryParse('$e'))
        .whereType<int>()
        .toList(growable: false);
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => '$e').toList(growable: false);
  }
}
