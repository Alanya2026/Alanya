import 'dart:convert';

import '../../l10n/app_localizations.dart';
import '../../talky_models.dart';

/// Type de message porteur d'une carte de trajet de confiance.
///
/// Les types vont de 0 à 8 (texte, image, vidéo, audio, fichier, localisation,
/// système, contact, CTA de bienvenue) ; le 9 est le premier libre.
///
/// Choisir un type de message plutôt qu'une entité séparée apporte trois choses
/// gratuitement : la notification poussée, le compteur de non-lus, et la
/// persistance dans l'archive. Et `local_messages` n'a pas à changer — le JSON
/// tient dans `content`, comme pour le type 5.
const int kTripMessageType = 9;

/// Contenu d'un message de type 9.
///
/// **Le message porte l'état, le socket porte le mouvement.** Ce contenu est
/// réécrit uniquement aux transitions — cinq à six fois sur toute la vie d'un
/// trajet. Les positions ne touchent jamais la table des messages : entre deux
/// transitions, la carte s'anime à partir du flux temps réel.
class TripCardPayload {
  /// Version du format. Un client plus ancien doit pouvoir reconnaître qu'il ne
  /// sait pas lire, plutôt que d'afficher du JSON brut.
  static const int currentVersion = 1;

  final int tripId;
  final String kind;
  final String state;
  final DateTime? etaAt;
  final String? destLabel;
  final String? note;

  /// Motif de clôture (`stopped_by_owner`, `false_alarm`, `confirmed`…).
  ///
  /// Indispensable parce que `closed_cancelled` recouvre deux situations qui
  /// n'ont rien à voir pour qui reçoit la carte : « j'ai arrêté le partage » et
  /// « c'était une fausse alerte, je vais bien ». Sans lui, un cercle qu'on
  /// vient d'alarmer lirait « a arrêté le partage » — la pire phrase possible à
  /// cet instant.
  final String? closeReason;

  /// Instantané de la dernière position connue, figé à la transition.
  ///
  /// Ce n'est **pas** un flux : le serveur ne l'écrit qu'aux changements d'état,
  /// cinq à six fois sur la vie d'un trajet. Il sert de fond à la vignette quand
  /// le trajet n'est plus suivi en direct — carte d'alerte rouverte des semaines
  /// plus tard, destinataire hors ligne, trace déjà purgée.
  ///
  /// Sur un trajet ouvert, le client lui préfère la position du cache local, qui
  /// vit au rythme du socket.
  final double? lastLat;
  final double? lastLng;
  final DateTime? lastAt;

  bool get hasPoint => lastLat != null && lastLng != null;

  const TripCardPayload({
    required this.tripId,
    required this.kind,
    required this.state,
    this.etaAt,
    this.destLabel,
    this.note,
    this.closeReason,
    this.lastLat,
    this.lastLng,
    this.lastAt,
  });

  /// Clôture consécutive à un démenti explicite après une alerte.
  bool get isFalseAlarm =>
      closeReason == 'false_alarm' && state == TripState.closedCancelled;

  /// Encode le payload tel que le serveur l'écrit dans `message.content`.
  String encode() => jsonEncode({
        'v': currentVersion,
        'tripId': tripId,
        'kind': kind,
        'state': state,
        'etaAt': etaAt?.toUtc().toIso8601String(),
        'destLabel': destLabel,
        'note': note,
        'closeReason': closeReason,
        'lastLat': lastLat,
        'lastLng': lastLng,
        'lastAt': lastAt?.toUtc().toIso8601String(),
      });

  /// Construit une carte à jour depuis un [Trip] (après confirm / cancel).
  ///
  /// Sert à réécrire le cache local **sans attendre** `trip:card_update` :
  /// l'owner qui vient de clôturer ne doit pas revoir « Suivre en direct »
  /// ni pouvoir rappuyer sur « Je suis bien arrivé·e ».
  factory TripCardPayload.fromTrip(Trip t) => TripCardPayload(
        tripId: t.id,
        kind: t.kind,
        state: t.state,
        etaAt: t.etaAt,
        destLabel: t.destLabel,
        note: t.note,
        closeReason: t.closeReason,
        lastLat: t.lastPoint?.lat,
        lastLng: t.lastPoint?.lng,
        lastAt: t.lastPoint?.recordedAt,
      );

  /// Renvoie `null` sur tout contenu non reconnu — y compris une version future
  /// du format. L'appelant rend alors un repli explicite.
  static TripCardPayload? tryParse(String? content) {
    if (content == null || content.isEmpty) return null;
    try {
      final j = jsonDecode(content);
      if (j is! Map) return null;

      final version = (j['v'] as num?)?.toInt() ?? 1;
      if (version > currentVersion) return null;

      final id = (j['tripId'] as num?)?.toInt();
      if (id == null || id <= 0) return null;

      return TripCardPayload(
        tripId: id,
        kind: j['kind']?.toString() ?? TripKind.taxi,
        state: j['state']?.toString() ?? TripState.active,
        etaAt: DateTime.tryParse(j['etaAt']?.toString() ?? '')?.toLocal(),
        destLabel: _nonVide(j['destLabel']),
        note: _nonVide(j['note']),
        closeReason: _nonVide(j['closeReason']),
        lastLat: _coord(j['lastLat'], 90),
        lastLng: _coord(j['lastLng'], 180),
        lastAt: DateTime.tryParse(j['lastAt']?.toString() ?? '')?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Coordonnée bornée. Une valeur hors domaine ferait planter la projection de
  /// la carte plutôt que d'afficher un mauvais point — on rend `null`, et la
  /// vignette disparaît proprement.
  static double? _coord(dynamic raw, double max) {
    final v = (raw as num?)?.toDouble();
    if (v == null || v.isNaN || v.abs() > max) return null;
    return v;
  }

  static String? _nonVide(dynamic raw) {
    final s = raw?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Libellé pour la liste des conversations et le corps des notifications.
  ///
  /// Équivalent de `SystemEventPayload.previewLabel`. Indispensable : l'aperçu
  /// est **recalculé localement** après chaque synchronisation
  /// (`conversation_summary_reducer`), ce qui écrase celui qu'envoie le serveur.
  /// Sans cette méthode, le cas générique reprend le `content` — donc le JSON.
  /// ⚠ Clés **dédiées à l'aperçu**, distinctes des libellés d'état affichés dans
  /// la carte et l'historique. Deux raisons, et il faut les deux.
  ///
  /// **Le mot n'est pas le même.** Une puce d'état dit « Arrivée confirmée » ;
  /// une ligne de liste de conversations dit « ✅ Bien arrivé·e ». L'une qualifie
  /// un état, l'autre raconte ce qui vient de se passer.
  ///
  /// **L'émoji est réservé à l'aperçu.** La liste des conversations se parcourt
  /// du regard, et l'application y marque déjà ses types (« 📷 Photo »,
  /// « 🎵 Audio »). Le même émoji dans la puce d'état de la carte serait du
  /// bruit.
  ///
  /// Ces chaînes doivent rester **mot pour mot identiques** à celles de
  /// `tripPreviewFromContent` (messagePreview.js). Le serveur écrit
  /// `conversation.lastMessage` à la transition, le client le recalcule à la
  /// synchronisation du message : deux écrivains pour un seul champ. Tant qu'ils
  /// disaient des choses différentes — « ✅ Bien arrivé·e » d'un côté, « Arrivée
  /// confirmée » de l'autre — l'aperçu changeait de texte tout seul selon celui
  /// qui avait écrit en dernier.
  String previewLabel(AppLocalizations l10n) => switch (state) {
        _ when isFalseAlarm => l10n.tripsPreviewFalseAlarm,
        TripState.awaitingConfirm => l10n.tripsPreviewAwaiting,
        TripState.alert => l10n.tripsPreviewAlert,
        TripState.sos => l10n.tripsPreviewSos,
        TripState.closedConfirmed => l10n.tripsPreviewConfirmed,
        TripState.closedCancelled ||
        TripState.closedExpired ||
        TripState.closedUnwatched =>
          l10n.tripsPreviewStopped,
        _ => l10n.tripsPreviewActive,
      };
}
