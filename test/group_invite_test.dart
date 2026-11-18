import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/services/groups/group_invite_link.dart';
import 'package:talky_flutter/core/utils/system_event_payload.dart';
import 'package:talky_flutter/l10n/app_localizations.dart';
import 'package:talky_flutter/models/group_invite_models.dart';
import 'package:talky_flutter/models/qr_models.dart';
// Compilés ici faute de test d'écran : un import cassé fait échouer ce fichier.
// ignore: unused_import
import 'package:talky_flutter/screens/chats/group_invite/group_invite_link_screen.dart';
// ignore: unused_import
import 'package:talky_flutter/screens/chats/group_invite/group_join_requests_screen.dart';
// ignore: unused_import
import 'package:talky_flutter/screens/chats/group_invite/group_invite_preview_sheet.dart';
// ignore: unused_import
import 'package:talky_flutter/screens/chats/group_detail_screen.dart';
// ignore: unused_import
import 'package:talky_flutter/screens/chats/chat_detail_screen.dart';
// ignore: unused_import
import 'package:talky_flutter/screens/profile/qr_scanner_screen.dart';
// ignore: unused_import
import 'package:talky_flutter/screens/home/home_screen.dart';
// ignore: unused_import
import 'package:talky_flutter/main.dart';

/// Lien et QR code d'invitation de groupe : lecture des liens, modèles des
/// réponses serveur, messages système du fil.
void main() {
  const jeton = 'K7mQ2pVt9LwR4hZc';

  group('GroupInviteLink', () {
    test('formes reconnues', () {
      expect(GroupInviteLink.fromUri(Uri.parse('https://www.alanya237.com/g/$jeton')), jeton);
      expect(GroupInviteLink.fromUri(Uri.parse('alanya://group/$jeton')), jeton);
      expect(GroupInviteLink.parse('Rejoins-nous : https://www.alanya237.com/g/$jeton.'), jeton);
    });

    test('formes refusées', () {
      for (final u in [
        'https://evil.example/g/$jeton',
        'https://user@www.alanya237.com/g/$jeton',
        'https://www.alanya237.com:8443/g/$jeton',
        'https://www.alanya237.com/g/court',
        'https://www.alanya237.com/s/$jeton',
        'https://www.alanya237.com/g/$jeton/plus',
        'alanya://sticker/$jeton',
      ]) {
        expect(GroupInviteLink.fromUri(Uri.parse(u)), isNull, reason: u);
      }
      expect(GroupInviteLink.parse('aucun lien ici'), isNull);
    });
  });

  group('modèles', () {
    test('aperçu : état et identifiant réservé aux membres', () {
      final p = GroupInvitePreview.fromJson(jeton, {
        'state': 'can_join',
        'group': {'name': 'Tontine', 'memberCount': 48, 'hideHistory': true, 'approval': false, 'photo': null},
      });
      expect(p.state, GroupInviteState.canJoin);
      expect(p.memberCount, 48);
      expect(p.hideHistory, isTrue);
      expect(p.conversationId, isNull);

      final m = GroupInvitePreview.fromJson(jeton, {
        'state': 'already_member',
        'group': {'conversID': 10, 'name': 'Tontine', 'memberCount': 3},
      });
      expect(m.state, GroupInviteState.alreadyMember);
      expect(m.conversationId, 10);
    });

    test('scan d\'un QR de groupe', () {
      final r = QrResolveResult.fromJson({
        'type': 'group',
        'token': jeton,
        'state': 'pending',
        'group': {'name': 'Tontine', 'memberCount': 3, 'approval': true},
      });
      expect(r.isGroup, isTrue);
      expect(r.group!.token, jeton);
      expect(r.group!.state, GroupInviteState.pending);
      expect(r.group!.approval, isTrue);
    });

    test('résultat d\'adhésion', () {
      final j = GroupJoinResult.fromJson({'state': 'joined', 'conversation': {'conversID': 7}});
      expect(j.isMember, isTrue);
      expect(j.conversationId, 7);
      expect(GroupJoinResult.fromJson({'state': 'pending'}).isMember, isFalse);
    });

    test('demande d\'adhésion', () {
      final d = GroupJoinRequest.fromJson({
        'alanyaID': 5, 'nom': '', 'pseudo': 'mimi', 'avatar_url': null,
        'requestedAt': '2026-11-18T10:00:00.000Z', 'isContact': true,
      });
      expect(d.displayName, 'mimi');
      expect(d.isContact, isTrue);
      expect(d.requestedAt, isNotNull);
    });
  });

  group('messages système', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    String? label(Map<String, dynamic> p, {int me = 99}) =>
        SystemEventPayload.tryParse(jsonEncode(p))?.label(me, fr);

    test('arrivée par lien, acceptation, réinitialisation', () {
      expect(label({'e': 'member_joined_link', 'by': 4, 'byName': 'Clarisse', 'ids': [4], 'names': ['Clarisse']}),
          "Clarisse a rejoint via le lien d'invitation");
      expect(label({'e': 'member_joined_link', 'by': 4, 'byName': 'Clarisse'}, me: 4),
          "Vous avez rejoint via le lien d'invitation");
      expect(label({'e': 'join_approved', 'by': 2, 'byName': 'Awa', 'ids': [5], 'names': ['Mireille']}),
          'Awa a approuvé Mireille');
      expect(label({'e': 'invite_link_reset', 'by': 2, 'byName': 'Awa'}),
          "Awa a réinitialisé le lien d'invitation");
    });

    test('réglages du lien', () {
      expect(label({'e': 'settings_changed', 'by': 2, 'byName': 'Awa', 'lock': 'approve', 'on': 1}),
          "Awa a activé l'approbation des nouveaux membres");
      expect(label({'e': 'settings_changed', 'by': 2, 'byName': 'Awa', 'lock': 'link', 'on': 0}),
          "Awa a ouvert le lien d'invitation à tous les membres");
    });

    test('aperçu de liste', () {
      final p = SystemEventPayload.tryParse(jsonEncode({'e': 'invite_link_reset', 'by': 2, 'byName': 'Awa'}))!;
      expect(p.previewLabel(fr), "Awa a réinitialisé le lien d'invitation");
    });
  });
}
