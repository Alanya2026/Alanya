//  Choix des discussions où envoyer un fichier du coffre (« Envoyer dans une
//  discussion », depuis un dossier du coffre). Même liste que le transfert
//  de messages, sans légende : le fichier part tel quel.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/conversation_display.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/common/common.dart';
import 'safebox_widgets.dart';

/// Les discussions choisies, ou null si l'inscrit renonce.
/// [others] : nombre de fichiers envoyés en plus de [file] (sélection).
Future<List<int>?> pickSafeboxConversations(BuildContext context, {required SafeboxFile file, int others = 0}) =>
    Navigator.push<List<int>>(
      context,
      MaterialPageRoute(builder: (_) => SafeboxChatPickerScreen(file: file, others: others)),
    );

class SafeboxChatPickerScreen extends StatefulWidget {
  const SafeboxChatPickerScreen({super.key, required this.file, this.others = 0});
  final SafeboxFile file;
  final int others;

  @override
  State<SafeboxChatPickerScreen> createState() => _SafeboxChatPickerScreenState();
}

class _SafeboxChatPickerScreenState extends State<SafeboxChatPickerScreen> {
  final _recherche = TextEditingController();
  final Set<int> _choisies = {};

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
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
            onPressed: _choisies.isEmpty ? null : () => Navigator.pop(context, _choisies.toList()),
            child: Text(_choisies.isEmpty ? l10n.commonSend : l10n.sendWithCount(_choisies.length)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: SafeboxFileThumb(file: f, size: 44),
            title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(widget.others > 0 ? '${formatBytes(f.plainBytes, l10n)} · +${widget.others}' : formatBytes(f.plainBytes, l10n)),
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
                          ? Text(l10n.groupFallback,
                              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant))
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
    );
  }
}
