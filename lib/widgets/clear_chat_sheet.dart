import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors/afficher_erreur.dart';
import '../core/errors/app_error.dart';
import '../core/services/chat/conversation_clear_service.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/byte_format.dart';
import '../providers/chat_provider.dart';

/// « Effacer la discussion » : la feuille de choix, puis l'effacement.
///
/// Ce n'est PAS « Supprimer la discussion » : la conversation reste dans la
/// liste, les autres participants ne voient rien. Deux choix, comme chez
/// WhatsApp — tous les messages, ou seulement les fichiers médias de cet
/// appareil. (Pas de case « messages importants » : l'app n'a pas de favoris
/// personnels, seulement des épingles partagées, que cet effacement retire
/// comme le reste.)
Future<void> showClearChatSheet(
  BuildContext context, {
  required int conversationId,
}) async {
  final repo = context.read<ChatProvider>().repository;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final result = await showModalBottomSheet<ClearMode>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ClearChatSheet(
      estimate: repo.estimateClear(conversationId),
    ),
  );
  if (result == null || !context.mounted) return;
  try {
    await repo.clearConversation(conversationId, mode: result);
    messenger?.showSnackBar(SnackBar(
      content: Text(result == ClearMode.all
          ? l10n.clearChatDone
          : l10n.clearChatMediaDone),
    ));
  } catch (e) {
    if (context.mounted) afficherErreur(context, e, domaine: ErrorDomain.chat);
  }
}

class _ClearChatSheet extends StatefulWidget {
  const _ClearChatSheet({required this.estimate});

  final Future<ClearEstimate> estimate;

  @override
  State<_ClearChatSheet> createState() => _ClearChatSheetState();
}

class _ClearChatSheetState extends State<_ClearChatSheet> {
  ClearMode _mode = ClearMode.all;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: FutureBuilder<ClearEstimate>(
          future: widget.estimate,
          builder: (context, snap) {
            final est = snap.data;
            String? size(ClearMode m) {
              if (est == null) return null;
              final bytes = est.bytesFor(m);
              return bytes > 0 ? formatBytes(bytes, l10n) : null;
            }

            Widget option(ClearMode m, String title, String hint) {
              final s = size(m);
              return RadioListTile<ClearMode>(
                value: m,
                contentPadding: EdgeInsets.zero,
                title: Text(s == null ? title : '$title ($s)'),
                subtitle: Text(hint),
              );
            }

            final total = size(_mode);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.clearChatTitle, style: context.text.titleLarge),
                AppSpacing.vGapMd,
                RadioGroup<ClearMode>(
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v ?? _mode),
                  child: Column(
                    children: [
                      option(ClearMode.all, l10n.clearChatAllMessages,
                          l10n.clearChatAllHint),
                      option(ClearMode.mediaOnly, l10n.clearChatMediaOnly,
                          l10n.clearChatMediaHint),
                    ],
                  ),
                ),
                AppSpacing.vGapMd,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.error,
                      foregroundColor: context.colors.onError,
                    ),
                    onPressed: () => Navigator.pop(context, _mode),
                    child: Text(total == null
                        ? l10n.clearChatButtonNoSize
                        : l10n.clearChatButton(total)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
