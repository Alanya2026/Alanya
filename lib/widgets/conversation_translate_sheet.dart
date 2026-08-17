import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/db/app_database.dart';
import '../core/db/chat_dao.dart';
import '../core/services/translation/message_translation_service.dart';
import '../core/theme/app_dimens.dart';
import '../core/theme/app_theme.dart';

/// Override de traduction d'une conversation.
///
/// `null` (automatique) suit le réglage général ; les deux autres valeurs le
/// contredisent délibérément pour cette conversation seulement — utile quand on
/// est bilingue avec une personne précise, ou au contraire quand une seule
/// discussion a besoin d'être traduite.
enum ConversationTranslateChoice { auto, always, never }

int? _modeOf(ConversationTranslateChoice choice) => switch (choice) {
      ConversationTranslateChoice.auto => null,
      ConversationTranslateChoice.always => 1,
      ConversationTranslateChoice.never => 0,
    };

ConversationTranslateChoice _choiceOf(int? mode) => switch (mode) {
      1 => ConversationTranslateChoice.always,
      0 => ConversationTranslateChoice.never,
      _ => ConversationTranslateChoice.auto,
    };

Future<void> showConversationTranslateSheet(
  BuildContext context, {
  required int conversationId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _ConversationTranslateSheet(conversationId: conversationId),
  );
}

class _ConversationTranslateSheet extends StatelessWidget {
  const _ConversationTranslateSheet({required this.conversationId});

  final int conversationId;

  Future<void> _apply(
    BuildContext context,
    ConversationTranslateChoice choice,
  ) async {
    final dao = ChatDao(context.read<AppDatabase>());
    Navigator.pop(context);
    await dao.setConversationTranslateMode(conversationId, _modeOf(choice));
    // Réexamine la conversation : passer sur « toujours » doit rattraper les
    // messages laissés de côté, pas seulement s'appliquer aux suivants.
    await MessageTranslationService.maybeInstance
        ?.refreshConversation(conversationId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dao = ChatDao(context.read<AppDatabase>());

    return StreamBuilder<LocalConversation?>(
      stream: dao.watchConversation(conversationId),
      builder: (context, snapshot) {
        final current = _choiceOf(snapshot.data?.translateMode);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Text(
                  l10n.translateThisConversation,
                  style: context.text.titleMedium,
                ),
              ),
              _option(context, ConversationTranslateChoice.auto, current,
                  l10n.translateModeAuto, l10n.translateModeAutoSubtitle),
              _option(context, ConversationTranslateChoice.always, current,
                  l10n.translateModeAlways, null),
              _option(context, ConversationTranslateChoice.never, current,
                  l10n.translateModeNever, null),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  Widget _option(
    BuildContext context,
    ConversationTranslateChoice choice,
    ConversationTranslateChoice current,
    String title,
    String? subtitle,
  ) {
    final selected = choice == current;
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: selected
          ? Icon(Icons.check, color: context.colors.primary)
          : null,
      onTap: () => _apply(context, choice),
    );
  }
}

/// Tuile d'entrée, à poser à côté de [ConversationMuteListTile].
class ConversationTranslateListTile extends StatelessWidget {
  const ConversationTranslateListTile({super.key, required this.conversationId});

  final int conversationId;

  @override
  Widget build(BuildContext context) {
    final dao = ChatDao(context.read<AppDatabase>());
    return StreamBuilder<LocalConversation?>(
      stream: dao.watchConversation(conversationId),
      builder: (context, snapshot) {
        final choice = _choiceOf(snapshot.data?.translateMode);
        final l10n = context.l10n;
        final subtitle = switch (choice) {
          ConversationTranslateChoice.always => l10n.translateModeAlways,
          ConversationTranslateChoice.never => l10n.translateModeNever,
          ConversationTranslateChoice.auto => l10n.translateModeAutoSubtitle,
        };

        return ListTile(
          leading: Container(
            width: AppIconSize.xl,
            height: AppIconSize.xl,
            decoration: BoxDecoration(
              color: context.semantic.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.translate,
              color: context.colors.onSurfaceVariant,
              size: AppIconSize.md,
            ),
          ),
          title: Text(
            l10n.translateThisConversation,
            style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            subtitle,
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          trailing:
              Icon(Icons.chevron_right, color: context.colors.outlineVariant),
          onTap: () =>
              showConversationTranslateSheet(context, conversationId: conversationId),
        );
      },
    );
  }
}
