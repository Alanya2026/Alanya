//  Choix des discussions où envoyer un fichier du coffre (« Envoyer dans une
//  discussion », depuis un dossier du coffre). Même liste que le transfert
//  de messages, sans légende : le fichier part tel quel.
//
//  L'écran reste ouvert le temps de créer le lien (rien ne remonte vers le
//  coffre : une seconde, même pour 1 Go), puis une discussion seule s'ouvre
//  pour y voir la carte ; plusieurs : retour au coffre, avec un message.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/notification_navigation.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/conversation_display.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/common.dart';
import 'safebox_widgets.dart';

/// Envoi d'un fichier du coffre (ou d'une sélection) dans les discussions
/// choisies. [send] envoie depuis l'écran du choix (ses questions, comme
/// celle des vidéos H.265, s'y posent) et rend le nombre de discussions
/// servies, ou null si l'inscrit renonce en chemin. Rend ce nombre, ou null.
/// [others] : nombre de fichiers envoyés en plus de [file] (sélection).
Future<int?> sendSafeboxToConversations(
  BuildContext context, {
  required SafeboxFile file,
  int others = 0,
  required SafeboxConversationsSend send,
}) async {
  final r = await Navigator.push<(int, List<int>)>(
    context,
    MaterialPageRoute(
      builder: (_) => SafeboxChatPickerScreen(file: file, others: others, send: send),
    ),
  );
  if (r == null || !context.mounted) return null;
  final (n, ids) = r;
  if (n > 0 && ids.length == 1) {
    await NotificationNavigation.openConversation(context, {'conversationId': '${ids.single}'});
  } else if (n > 0) {
    safeboxSnack(context, context.l10n.safeboxSendDone(n));
  }
  return n;
}

typedef SafeboxConversationsSend = Future<int?> Function(BuildContext context, List<int> conversationIds);

/// Les cartes d'un envoi, découpées par [max] fichiers : « Kribi · 1/3 »,
/// « Kribi · 2/3 »… Une carte vide disparaît.
List<(String?, List<T>)> safeboxShareParts<T>(List<(String?, List<T>)> cartes, {int max = kSafeboxShareMaxItems}) => [
      for (final (nom, lot) in cartes)
        for (var i = 0, n = (lot.length + max - 1) ~/ max; i < n; i += 1)
          (
            n > 1 && nom != null ? '$nom · ${i + 1}/$n' : nom,
            lot.sublist(i * max, (i + 1) * max > lot.length ? lot.length : (i + 1) * max),
          ),
    ];

/// Envoie chaque morceau dans chaque discussion, sauf ce que [done] marque
/// déjà parti (« morceau:discussion »), qu'il complète. Tente tout, puis lève
/// la première erreur : un nouvel essai n'envoie que ce qui manque. Rend vrai
/// si quelque chose est (ou était déjà) parti.
Future<bool> safeboxSendParts({
  required int parts,
  required List<int> conversationIds,
  required Set<String> done,
  required Future<void> Function(int part, int conversationId) send,
}) async {
  Object? erreur;
  var parti = false;
  for (var i = 0; i < parts; i += 1) {
    for (final conv in conversationIds) {
      if (!done.contains('$i:$conv')) {
        try {
          await send(i, conv);
          done.add('$i:$conv');
        } catch (e) {
          erreur ??= e;
          continue;
        }
      }
      parti = true;
    }
  }
  if (erreur != null) throw erreur;
  return parti;
}

class SafeboxChatPickerScreen extends StatefulWidget {
  const SafeboxChatPickerScreen({super.key, required this.file, this.others = 0, required this.send});
  final SafeboxFile file;
  final int others;
  final SafeboxConversationsSend send;

  @override
  State<SafeboxChatPickerScreen> createState() => _SafeboxChatPickerScreenState();
}

class _SafeboxChatPickerScreenState extends State<SafeboxChatPickerScreen> {
  final _recherche = TextEditingController();
  final Set<int> _choisies = {};
  bool _envoi = false;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final ids = _choisies.toList();
    setState(() => _envoi = true);
    try {
      final n = await widget.send(context, ids);
      if (n != null && mounted) Navigator.pop(context, (n, ids));
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final moi = context.select<AuthProvider, int>((a) => a.currentUser?.alanyaID ?? 0);
    final chat = context.watch<ChatProvider>();
    final f = widget.file;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.safeboxSendPickTitle),
        actions: [
          TextButton(
            onPressed: _choisies.isEmpty || _envoi ? null : _envoyer,
            child: Text(
              _envoi
                  ? l10n.sending
                  : _choisies.isEmpty
                  ? l10n.commonSend
                  : l10n.sendWithCount(_choisies.length),
            ),
          ),
        ],
        bottom: _envoi
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: AbsorbPointer(
        absorbing: _envoi,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: SafeboxFileThumb(file: f, size: 44),
              title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                widget.others > 0
                    ? '${formatBytes(f.plainBytes, l10n)} · +${widget.others}'
                    : formatBytes(f.plainBytes, l10n),
              ),
            ),
            Padding(
              padding: AppSpacing.screenH,
              child: AppSearchField(
                controller: _recherche,
                hintText: l10n.searchChats,
                onChanged: (_) => setState(() {}),
                onClear: () {
                  _recherche.clear();
                  setState(() {});
                },
              ),
            ),
            AppSpacing.vGapSm,
            Expanded(
              child: StreamBuilder<List<LocalConversation>>(
                stream: chat.watchConversations(),
                builder: (context, snap) {
                  final convs = (snap.data ?? const <LocalConversation>[])
                      .where((c) => conversationMatchesSearch(c, moi, _recherche.text))
                      .toList();
                  if (convs.isEmpty) {
                    return EmptyState(
                      icon: Icons.forum_outlined,
                      title: _recherche.text.trim().isEmpty ? l10n.noChats : l10n.noResults,
                    );
                  }
                  return ListView.builder(
                    itemCount: convs.length,
                    itemBuilder: (_, i) {
                      final c = convs[i];
                      final nom = conversationDisplayName(c, moi);
                      final choisie = _choisies.contains(c.conversID);
                      return CheckboxListTile(
                        value: choisie,
                        onChanged: (_) => setState(() {
                          choisie ? _choisies.remove(c.conversID) : _choisies.add(c.conversID);
                        }),
                        secondary: AppAvatar(
                          imageUrl: conversationDisplayAvatar(c, moi),
                          name: nom,
                          isGroup: c.isGroup,
                          size: AppSizes.avatarMd,
                        ),
                        title: Text(nom, style: context.text.titleSmall),
                        subtitle: c.isGroup
                            ? Text(
                                l10n.groupFallback,
                                style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                              )
                            : null,
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
