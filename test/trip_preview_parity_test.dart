import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/trip_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/talky_models.dart';

/// Parité des aperçus de trajet entre le serveur et le client.
///
/// **Deux écrivains se partagent `conversation.lastMessage`** : le serveur à
/// chaque transition, le client à chaque resynchronisation du message. Tant
/// qu'ils ne disaient pas la même chose — « ✅ Bien arrivé·e » d'un côté,
/// « Arrivée confirmée » de l'autre — l'aperçu changeait de texte tout seul,
/// selon celui qui avait écrit en dernier.
///
/// Ce test lit les libellés **directement dans le source du backend** plutôt
/// que d'en recopier une liste : une copie diverge en silence, ce qui est
/// exactement le défaut qu'on cherche à empêcher.
void main() {
  const chemin =
      '/mnt/data/Alanya-Backend/src/utils/messagePreview.js';

  /// Extrait la table état → libellé de `tripPreviewFromContent`.
  Map<String, String> libellesServeur(String source) {
    final debut = source.indexOf('function tripPreviewFromContent');
    expect(debut, greaterThan(-1),
        reason: 'tripPreviewFromContent introuvable — le backend a bougé');
    final corps = source.substring(debut, debut + 2000);

    final table = <String, String>{};
    // `case 'closed_confirmed': return '✅ Bien arrivé·e';`
    for (final m in RegExp(r"case '(\w+)':\s*return '([^']+)'").allMatches(corps)) {
      table[m.group(1)!] = m.group(2)!;
    }
    // Le démenti n'est pas un `case` : il est testé avant le switch.
    final fa = RegExp(r"false_alarm'\)\s*\{\s*return '([^']+)'").firstMatch(corps);
    if (fa != null) table['false_alarm'] = fa.group(1)!;
    return table;
  }

  test('les libellés d\'aperçu sont identiques des deux côtés', () async {
    final fichier = File(chemin);
    if (!fichier.existsSync()) {
      markTestSkipped('backend absent de cette machine ($chemin)');
      return;
    }

    final serveur = libellesServeur(fichier.readAsStringSync());
    expect(serveur, isNotEmpty);

    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));

    String client(String etat, {String? closeReason}) {
      final p = TripCardPayload.tryParse(jsonEncode({
        'v': 1,
        'tripId': 1,
        'kind': TripKind.taxi,
        'state': etat,
        if (closeReason != null) 'closeReason': closeReason,
      }));
      return p!.previewLabel(l10n);
    }

    final ecarts = <String>[];
    for (final entree in serveur.entries) {
      final etat = entree.key;
      final attendu = entree.value;
      final obtenu = etat == 'false_alarm'
          ? client(TripState.closedCancelled, closeReason: 'false_alarm')
          : client(etat);
      if (obtenu != attendu) {
        ecarts.add('$etat : serveur=«$attendu» client=«$obtenu»');
      }
    }

    expect(ecarts, isEmpty,
        reason: 'l\'aperçu changerait de texte selon l\'écrivain :\n'
            '${ecarts.join('\n')}');
  });

  test('chaque état ouvert ou clos produit un aperçu, jamais du JSON', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    for (final etat in const [
      TripState.active,
      TripState.awaitingConfirm,
      TripState.alert,
      TripState.sos,
      TripState.closedConfirmed,
      TripState.closedCancelled,
      TripState.closedExpired,
      TripState.closedUnwatched,
    ]) {
      final p = TripCardPayload.tryParse(
          jsonEncode({'v': 1, 'tripId': 1, 'state': etat}));
      final libelle = p!.previewLabel(l10n);
      expect(libelle, isNotEmpty, reason: etat);
      expect(libelle.contains('{'), isFalse,
          reason: 'du JSON brut est remonté dans l\'aperçu pour « $etat »');
    }
  });
}
