import '../../l10n/app_localizations.dart';
import '../constants/default_contact_lists.dart';
import '../db/app_database.dart';
import '../../talky_models.dart';

/// Libellé affiché d'une liste : l10n pour les listes système, `name` sinon.
String contactListDisplayName(
  AppLocalizations l10n, {
  String? kind,
  required String name,
}) {
  switch (kind) {
    case ContactListKind.family:
      return l10n.listKindFamily;
    case ContactListKind.friends:
      return l10n.listKindFriends;
    case ContactListKind.work:
      return l10n.listKindWork;
    case ContactListKind.trust:
      return l10n.listKindTrust;
    default:
      return name;
  }
}

extension ContactListDisplay on ContactList {
  String displayName(AppLocalizations l10n) =>
      contactListDisplayName(l10n, kind: kind, name: name);
}

extension LocalContactListDisplay on LocalContactList {
  String displayName(AppLocalizations l10n) =>
      contactListDisplayName(l10n, kind: kind, name: name);
}
