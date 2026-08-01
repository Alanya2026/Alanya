import 'dart:convert';

import '../../l10n/app_localizations.dart';

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
  /// (`send` / `edit` / `history` / `add`) et son nouvel état.
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

  /// Phrase affichée dans le fil, dans la langue **du lecteur**.
  ///
  /// [myId] sélectionne la variante `…ByMe` : en français, substituer « Vous »
  /// à l'acteur produirait « Vous a ajouté ». Deux clés par événement, donc.
  ///
  /// Renvoie `null` quand la phrase serait vide de sens (cibles manquantes sur
  /// un événement qui en exige) : l'appelant n'affiche alors aucune bulle.
  String? label(int myId, AppLocalizations l10n) {
    final byMe = actorId != 0 && actorId == myId;
    final actor = actorName.trim().isNotEmpty
        ? actorName.trim()
        : l10n.unknownSender;
    final targets = targetLabel(separator: ', ');
    final v = value ?? '';

    switch (event) {
      case SystemEvent.groupCreated:
        return byMe ? l10n.sysGroupCreatedByMe(v) : l10n.sysGroupCreated(actor, v);

      case SystemEvent.memberAdded:
        if (!hasTargetNames) return l10n.sysGroupEventFallback;
        return byMe
            ? l10n.sysMemberAddedByMe(targets)
            : l10n.sysMemberAdded(actor, targets);

      case SystemEvent.memberRemoved:
        if (!hasTargetNames) return l10n.sysGroupEventFallback;
        return byMe
            ? l10n.sysMemberRemovedByMe(targets)
            : l10n.sysMemberRemoved(actor, targets);

      case SystemEvent.memberLeft:
        return byMe ? l10n.sysMemberLeftByMe : l10n.sysMemberLeft(actor);

      case SystemEvent.groupRenamed:
        return byMe ? l10n.sysGroupRenamedByMe(v) : l10n.sysGroupRenamed(actor, v);

      case SystemEvent.groupPhotoChanged:
        return byMe
            ? l10n.sysGroupPhotoChangedByMe
            : l10n.sysGroupPhotoChanged(actor);

      case SystemEvent.groupDescriptionChanged:
        return byMe
            ? l10n.sysGroupDescriptionChangedByMe
            : l10n.sysGroupDescriptionChanged(actor);

      case SystemEvent.roleChanged:
        if (!hasTargetNames) return l10n.sysGroupEventFallback;
        final promoted = (role ?? 0) >= 1;
        if (promoted) {
          return byMe
              ? l10n.sysRolePromotedByMe(targets)
              : l10n.sysRolePromoted(actor, targets);
        }
        return byMe
            ? l10n.sysRoleDemotedByMe(targets)
            : l10n.sysRoleDemoted(actor, targets);

      case SystemEvent.settingsChanged:
        if (lock == 'send') {
          if (lockEnabled) {
            return byMe
                ? l10n.sysOnlyAdminsSendOnByMe
                : l10n.sysOnlyAdminsSendOn(actor);
          }
          return byMe
              ? l10n.sysOnlyAdminsSendOffByMe
              : l10n.sysOnlyAdminsSendOff(actor);
        }
        if (lock == 'edit') {
          if (lockEnabled) {
            return byMe
                ? l10n.sysOnlyAdminsEditOnByMe
                : l10n.sysOnlyAdminsEditOn(actor);
          }
          return byMe
              ? l10n.sysOnlyAdminsEditOffByMe
              : l10n.sysOnlyAdminsEditOff(actor);
        }
        if (lock == 'history') {
          if (lockEnabled) {
            return byMe
                ? l10n.sysHideHistoryOnByMe
                : l10n.sysHideHistoryOn(actor);
          }
          return byMe
              ? l10n.sysHideHistoryOffByMe
              : l10n.sysHideHistoryOff(actor);
        }
        if (lock == 'add') {
          if (lockEnabled) {
            return byMe
                ? l10n.sysOnlyAdminsAddOnByMe
                : l10n.sysOnlyAdminsAddOn(actor);
          }
          return byMe
              ? l10n.sysOnlyAdminsAddOffByMe
              : l10n.sysOnlyAdminsAddOff(actor);
        }
        return l10n.sysGroupEventFallback;
    }
    return null;
  }

  /// Aperçu court pour la liste de conversations — calqué sur
  /// `systemPreviewFromContent()` côté serveur. Volontairement sans noms de
  /// cibles : une ligne d'aperçu est tronquée, le fil porte la phrase complète.
  String previewLabel(AppLocalizations l10n) {
    final actor = actorName.trim().isNotEmpty
        ? actorName.trim()
        : l10n.unknownSender;
    final v = value?.trim() ?? '';

    switch (event) {
      case SystemEvent.groupCreated:
        return v.isNotEmpty
            ? l10n.sysPreviewGroupCreated(actor, v)
            : l10n.sysPreviewGroupCreatedShort(actor);
      case SystemEvent.memberAdded:
        return l10n.sysPreviewMemberAdded(actor);
      case SystemEvent.memberRemoved:
        return l10n.sysPreviewMemberRemoved(actor);
      case SystemEvent.memberLeft:
        return l10n.sysPreviewMemberLeft(actor);
      case SystemEvent.groupRenamed:
        return l10n.sysPreviewGroupRenamed(actor);
      case SystemEvent.groupPhotoChanged:
        return l10n.sysPreviewGroupPhotoChanged(actor);
      case SystemEvent.groupDescriptionChanged:
        return l10n.sysPreviewGroupDescriptionChanged(actor);
      case SystemEvent.roleChanged:
        return (role ?? 0) >= 1
            ? l10n.sysPreviewRolePromoted(actor)
            : l10n.sysPreviewRoleDemoted(actor);
      case SystemEvent.settingsChanged:
        return l10n.sysPreviewSettingsChanged(actor);
      default:
        return l10n.sysGroupEventFallback;
    }
  }

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
