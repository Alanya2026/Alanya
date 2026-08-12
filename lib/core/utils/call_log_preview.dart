import '../../l10n/app_localizations.dart';

/// Types d'aperçu réservés aux **journaux d'appel** dans `lastMessageType`.
///
/// Un appel n'est pas un message : il vit dans `callHistory` côté serveur et
/// dans `local_calls` côté client, pas dans `messages`. Mais il fait avancer la
/// conversation — il apparaît dans le fil et doit remonter la discussion dans la
/// liste. Le serveur écrit donc un aperçu dans `conversation.lastMessage`, et
/// `lastMessageType` doit dire de quoi il s'agit.
///
/// ⚠ **Il écrivait 5 et 6**, avec le commentaire « réservés ». Ils ne l'étaient
/// pas : dans ce dépôt, **5 = localisation** et **6 = message système**. Un
/// appel vocal terminé marquait donc la conversation comme portant une position,
/// et un appel vidéo comme portant un événement de groupe — deux types dont le
/// client sait qu'ils contiennent du JSON structuré, et qu'il tente de décoder.
///
/// Les valeurs sont prises loin au-dessus des types de messages (0 à 9) pour
/// qu'aucune extension future du fil ne vienne les reprendre. Un client plus
/// ancien qui ne les connaît pas retombe sur le cas générique et affiche la
/// chaîne d'aperçu telle quelle, ce qui reste correct.
const int kCallLogAudioPreviewType = 20;
const int kCallLogVideoPreviewType = 21;

/// Valeurs héritées, écrites par le cache local avant que les trois écrivains ne
/// s'accordent.
///
/// Trois écrivains se partageaient `lastMessageType` avec trois numérotations :
/// le serveur écrivait 5/6, le cache local 10/11, et le réducteur y mettait le
/// type du dernier *message*. Chacun écrasait les autres à tour de rôle — c'est
/// exactement ce que l'utilisateur voyait clignoter.
///
/// On les reconnaît toujours en **lecture** pour que les conversations déjà en
/// base se comportent correctement dès la mise à jour, sans attendre un nouvel
/// appel. Plus personne ne les **écrit**.
///
/// 10 et 11 n'ont pas été retenus comme valeurs cibles précisément parce qu'ils
/// sont adjacents aux types de messages : ceux-ci vont aujourd'hui de 0 à 9, et
/// le volet des trajets vient d'en consommer un. Un type 10 finirait par exister.
const int _kCallLogAudioLegacy = 10;
const int _kCallLogVideoLegacy = 11;

bool isCallLogPreviewType(int? type) =>
    type == kCallLogAudioPreviewType ||
    type == kCallLogVideoPreviewType ||
    type == _kCallLogAudioLegacy ||
    type == _kCallLogVideoLegacy;

/// Libellé d'aperçu d'un journal d'appel, **dans la langue du lecteur**.
///
/// Le serveur stocke « 📞 Appel vocal » en français en dur. On ne s'en sert pas :
/// le type suffit à reconstruire la phrase, et c'est la seule façon qu'un
/// utilisateur anglophone ne lise pas du français dans sa liste.
String callLogPreviewLabel(int type, AppLocalizations l10n) =>
    (type == kCallLogVideoPreviewType || type == _kCallLogVideoLegacy)
        ? '📹 ${l10n.videoCall}'
        : '📞 ${l10n.voiceCall}';
