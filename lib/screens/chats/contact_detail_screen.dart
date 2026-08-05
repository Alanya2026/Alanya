import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/call_service.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/document_file_style.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/utils/country_utils.dart';
import '../../widgets/common/common.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../widgets/image_message_preview.dart';
import '../../widgets/video_message_preview.dart';
import 'chat_detail_screen.dart';
import 'conversation_media_screen.dart';
import 'media_viewer_screen.dart';
import '../../widgets/conversation_mute_sheet.dart';

/// Fiche détaillée d'un contact, réutilisable depuis :
/// — l'en-tête d'une discussion 1-1
/// — un appel récent
/// — un membre dans la fiche d'un groupe
class ContactDetailScreen extends StatefulWidget {
  final int userId;
  final int? conversationId;
  final String initialName;
  final String initialAvatar;

  const ContactDetailScreen({
    super.key,
    required this.userId,
    this.conversationId,
    this.initialName = '',
    this.initialAvatar = '',
  });

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late final TalkyApiClient _api;
  User? _contact;
  bool _isLoading = true;
  bool _isFavorite = false;

  /// Relation « ajouté par QR » lue du cache local — la seule source qui la
  /// connaît, le profil réseau ne portant pas la relation.
  bool _addedViaQr = false;
  DateTime? _preferredAddedAt;
  String? _preferredNote;
  bool _isBlocked = false;
  bool _blockedByThem = false;
  bool _busy = false;
  /// Vrai dès que `GET /users/:id` a répondu : le cache local, plus pauvre,
  /// ne doit plus écraser l'en-tête s'il arrive après (course possible depuis
  /// que les requêtes partent en parallèle).
  bool _profileFromNetwork = false;
  /// 1-1 locale avec [widget.userId] si [widget.conversationId] est absent.
  int? _resolvedConvId;

  int? get _effectiveConvId => widget.conversationId ?? _resolvedConvId;

  /// Mon propre profil, ouvert depuis une conversation avec moi-même.
  ///
  /// L'écran se réduit alors à l'en-tête, aux médias et à la gestion de la
  /// conversation : ni appels, ni blocage, ni contacts — tout ce qui suppose
  /// une relation avec un tiers disparaît.
  bool get _isSelf {
    final myId = context.read<AuthProvider>().currentUser?.alanyaID;
    return myId != null && myId == widget.userId;
  }

  @override
  void initState() {
    super.initState();
    _api = context.read<TalkyApiClient>();
    _load();
  }

  Future<void> _resolveDirectConversation() async {
    if (widget.conversationId != null) return;
    final myId = context.read<AuthProvider>().currentUser?.alanyaID;
    if (myId == null) return;
    try {
      final convs = await context
          .read<ChatProvider>()
          .repository
          .dao
          .getAllConversations();
      if (!mounted) return;
      final id = findLocalDirectConversationId(convs, myId, widget.userId);
      if (mounted) setState(() => _resolvedConvId = id);
    } catch (e, st) {
      AppLog.e('ContactDetail', 'Résolution conversation 1-1 échouée', e, st);
    }
  }

  /// Exécute [run] en repliant toute erreur sur [fallback] (les statuts
  /// annexes ne doivent jamais empêcher l'affichage du profil).
  Future<T> _guard<T>(
    Future<T> Function() run,
    T fallback,
    String label,
  ) async {
    try {
      return await run();
    } catch (e, st) {
      AppLog.e('ContactDetail', label, e, st);
      return fallback;
    }
  }

  Future<void> _load() async {
    final cache = context.read<LocalCacheRepository>();
    // Mon propre profil : ni « suis-je dans mes contacts ? », ni « me suis-je
    // bloqué ? » — deux allers-retours réseau sans objet. Lu avant tout await
    // (le context ne doit pas être touché après démontage).
    final isSelf = _isSelf;

    // La 1-1 locale ne conditionne que les médias et les actions : la
    // résoudre en tâche de fond plutôt que devant les requêtes profil.
    unawaited(_resolveDirectConversation());

    // Les trois requêtes partent ensemble. Le téléphone et le pays ne
    // transitent que par `getUserById` : les faire attendre `checkIsContact`
    // puis `getBlockStatus` en série coûtait deux allers-retours réseau
    // pendant lesquels l'en-tête restait incomplet.
    // `null` = statut inconnu (réseau indisponible) : on garde alors la
    // valeur déjà hydratée depuis le cache plutôt que de la remettre à faux.
    final profileFuture = _api.getUserById(widget.userId);
    final favFuture = isSelf
        ? Future<bool?>.value(false)
        : _guard<bool?>(
            () => _api.checkIsContact(widget.userId),
            null,
            'checkIsContact échoué',
          );
    final blockFuture = isSelf
        ? Future<({bool isBlocked, bool blockedByThem})?>.value(
            (isBlocked: false, blockedByThem: false),
          )
        : _guard<({bool isBlocked, bool blockedByThem})?>(
            () => _api.getBlockStatus(widget.userId),
            null,
            'getBlockStatus échoué',
          );

    if (widget.initialName.isNotEmpty || widget.initialAvatar.isNotEmpty) {
      setState(() {
        _contact = User(
          alanyaID: widget.userId,
          nom: widget.initialName,
          pseudo: '',
          alanyaPhone: '',
          email: '',
          idPays: 0,
          avatarUrl: widget.initialAvatar,
          typeCompte: 0,
          isOnline: false,
          lastSeen: '',
        );
        _isLoading = false;
      });
    }
    try {
      final profile = await cache.getKnownUserProfile(widget.userId);
      final relation = await cache.getKnownUserRelation(widget.userId);
      if (profile != null && mounted && !_profileFromNetwork) {
        setState(() {
          _contact = profile;
          _isFavorite = relation?.isPreferredContact ?? false;
          _addedViaQr = relation?.addedViaQr ?? false;
          _preferredAddedAt = relation?.preferredAddedAt;
          _preferredNote = relation?.preferredNote;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      AppLog.e('ContactDetail', 'Chargement contact (cache) échoué', e, st);
    }

    // Premier rendu complet dès la réponse profil — sans attendre les deux
    // statuts annexes.
    User? user;
    try {
      final data = await profileFuture;
      if (!mounted) return;
      user = User.fromJson(data);
      setState(() {
        _contact = user;
        _profileFromNetwork = true;
        _isLoading = false;
      });
    } catch (e, st) {
      AppLog.e('ContactDetail', 'getUserById échoué', e, st);
      if (mounted && _contact == null) setState(() => _isLoading = false);
    }

    // Second rendu : contact préféré et blocage, qui n'ont d'effet que sur
    // les actions du bas de fiche.
    final fav = await favFuture;
    final blockStatus = await blockFuture;
    if (!mounted) return;
    setState(() {
      if (fav != null) _isFavorite = fav;
      if (blockStatus != null) {
        _isBlocked = blockStatus.isBlocked;
        _blockedByThem = blockStatus.blockedByThem;
      }
    });

    if (user != null) {
      unawaited(cache.upsertKnownUser(user, preferred: fav ?? _isFavorite));
    }
  }

  // ── Actions ────────────────────────────────────────────────────────

  /// Appel sortant depuis la fiche contact. Ces deux boutons affichaient
  /// « bientôt disponible » alors que le service existait et servait déjà
  /// ailleurs (widgets/profile_image_modal.dart) : ils étaient morts par
  /// simple oubli de câblage.
  Future<void> _startCall({required bool isVideo}) async {
    final contact = _contact;
    final me = context.read<AuthProvider>().currentUser;
    if (contact == null || me == null) return;
    try {
      await context.read<CallService>().initiateCall(
            targetUserId: widget.userId,
            myId: me.alanyaID,
            myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
            myPhoto: me.avatarUrl,
            targetUserName: contact.nom,
            targetUserPhoto: contact.avatarUrl,
            isVideo: isVideo,
          );
    } catch (e, st) {
      AppLog.e('ContactDetail', 'Appel sortant échoué', e, st);
    }
  }

  Future<void> _openChat() async {
    if (_contact == null) return;
    if (!mounted) return;

    // Utiliser la conv fournie ou celle résolue au chargement ; sinon re-chercher.
    int? convId = _effectiveConvId;
    if (convId == null) {
      final myId =
          context.read<AuthProvider>().currentUser?.alanyaID;
      if (myId != null) {
        final convs = await context
            .read<ChatProvider>()
            .repository
            .dao
            .getAllConversations();
        convId = findLocalDirectConversationId(convs, myId, widget.userId);
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: _contact!.nom,
          conversationId: convId,
          userId: widget.userId,
          avatarUrl: _contact!.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_busy) return;
    setState(() => _busy = true);
    final next = !_isFavorite;
    try {
      if (next) {
        await _api.addContact(widget.userId);
      } else {
        await _api.removeContact(widget.userId);
      }
      if (mounted) setState(() => _isFavorite = next);
    } catch (e) {
      _snack(context.l10n.actionFailedWithError('$e'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock() async {
    if (_busy) return;
    final next = !_isBlocked;
    final confirmed = await _confirm(
      title: next ? context.l10n.blockThisContact : context.l10n.unblockThisContact,
      message: next
          ? context.l10n.theyWillNoLongerBeAble
          : context.l10n.heCanContactYouAgain,
      confirmLabel: next ? context.l10n.commonBlock : context.l10n.unblock,
      destructive: next,
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      if (next) {
        await _api.blockUser(widget.userId);
      } else {
        await _api.unblockUser(widget.userId);
      }
      if (mounted) setState(() {
        _isBlocked = next;
        if (next) _blockedByThem = false;
      });
    } catch (e) {
      _snack(context.l10n.actionFailedWithError('$e'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearMessages() async {
    final convId = _effectiveConvId;
    if (convId == null) {
      _snack(context.l10n.noConversationToClear);
      return;
    }
    final confirmed = await _confirm(
      title: context.l10n.clearMessages,
      message:
          context.l10n.localMessagesInThisChatWill,
      confirmLabel: context.l10n.clearAction,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final dao = context.read<ChatProvider>().repository.dao;
    await (dao.db.delete(dao.db.localMessages)
          ..where((m) => m.conversationID.equals(convId)))
        .go();
    if (mounted) _snack(context.l10n.messagesCleared);
  }

  Future<void> _deleteConversation() async {
    final convId = _effectiveConvId;
    if (convId == null) {
      _snack(context.l10n.noConversationToDelete);
      return;
    }
    // Conversation avec soi-même : un seul participant, donc le serveur purge
    // messages ET conversation. Contrairement à un 1-1, aucune copie ne
    // survit chez un pair — l'avertissement doit le dire.
    final confirmed = await _confirm(
      title: context.l10n.deleteConversation,
      message: _isSelf
          ? context.l10n.selfChatDeleteWarning
          : context.l10n.historyWillBeDeleted,
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteConversation(convId);
    } catch (e, st) {
      AppLog.e('ContactDetail', 'deleteConversation serveur échouée', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.conversationDeletedLocallyServerUnreachable),
          ),
        );
      }
    }
    if (!mounted) return;
    final dao = context.read<ChatProvider>().repository.dao;
    await dao.deleteConversation(convId);
    if (!mounted) return;
    await context.read<ChatProvider>().refreshConversations(force: true);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: destructive ? context.colors.error : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: error ? context.colors.error : null),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'block':
                  _toggleBlock();
                  break;
                case 'clear':
                  _clearMessages();
                  break;
                case 'delete':
                  _deleteConversation();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (!_isSelf)
                PopupMenuItem(
                  value: 'block',
                  child: Text(_isBlocked ? context.l10n.unblock : context.l10n.commonBlock),
                ),
              if (_effectiveConvId != null) ...[
                PopupMenuItem(
                    value: 'clear', child: Text(context.l10n.clearMessages2)),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(context.l10n.deleteConversation2)),
              ],
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _contact == null
              ? _ErrorState(name: widget.initialName)
              : _buildContent(_contact!),
    );
  }

  Widget _buildContent(User u) {
    // Mon propre profil : en-tête, médias et gestion de la conversation. Tout
    // ce qui suppose un tiers (appels, blocage, contacts, mise en sourdine)
    // disparaît — aucune notification ne peut viser mes propres notes.
    final isSelf = _isSelf;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
          AppSpacing.xxl),
      children: [
        _Header(user: u, hidePhoto: !isSelf && _blockedByThem),
        if (!isSelf && _isFavorite && _addedViaQr) ...[
          AppSpacing.vGapMd,
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: context.semantic.brandContainer,
                borderRadius: AppRadius.brPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 15,
                    color: context.colors.primary,
                  ),
                  AppSpacing.hGapXs,
                  Text(
                    _preferredAddedAt != null
                        ? context.l10n.qrContactAddedViaQrOn(
                            DateFormat.yMMMd(
                                    Localizations.localeOf(context).toString())
                                .format(_preferredAddedAt!))
                        : context.l10n.qrContactAddedViaQr,
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        // La note contextuelle saisie après un scan (« rencontré au salon de
        // Douala ») — le souvenir appartient à la relation, il s'affiche donc
        // ici, jamais sur le profil public de l'autre.
        if (!isSelf &&
            _isFavorite &&
            (_preferredNote ?? '').trim().isNotEmpty) ...[
          AppSpacing.vGapSm,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 15,
                  color: context.colors.onSurfaceVariant,
                ),
                AppSpacing.hGapXs,
                Flexible(
                  child: Text(
                    '« ${_preferredNote!.trim()} »',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        AppSpacing.vGapXl,
        if (!isSelf) ...[
          _PrimaryActions(
            callsDisabled: _isBlocked || _blockedByThem,
            onCall: () => unawaited(_startCall(isVideo: false)),
            onVideo: () => unawaited(_startCall(isVideo: true)),
            onMessage: _openChat,
          ),
          AppSpacing.vGapLg,
        ],
        _QuickActionsCard(
          isFavorite: _isFavorite,
          showFavorite: !isSelf,
          onToggleFavorite: _toggleFavorite,
          onSearch: () => _snack(context.l10n.searchComingSoon),
          onClear: _clearMessages,
        ),
        AppSpacing.vGapLg,
        if (!isSelf && _effectiveConvId != null) ...[
          _Card(
            padding: EdgeInsets.zero,
            child: ConversationMuteListTile(
              conversationId: _effectiveConvId!,
              conversationName: u.nom.isNotEmpty ? u.nom : u.pseudo,
            ),
          ),
          AppSpacing.vGapLg,
        ],
        _MediaCard(
          key: ValueKey('media-${_effectiveConvId ?? 'none'}'),
          conversationId: _effectiveConvId,
          conversationName: u.nom,
        ),
        AppSpacing.vGapLg,
        _DangerActionsCard(
          isBlocked: _isBlocked,
          isFavorite: _isFavorite,
          showBlock: !isSelf,
          showRemoveContact: !isSelf,
          hasConversation: _effectiveConvId != null,
          onBlock: _toggleBlock,
          onDeleteConversation: _deleteConversation,
          onRemoveContact: _toggleFavorite,
        ),
      ],
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final User user;
  final bool hidePhoto;
  const _Header({required this.user, this.hidePhoto = false});

  @override
  Widget build(BuildContext context) {
    final name = user.nom.isNotEmpty ? user.nom : user.pseudo;
    return Column(
      children: [
        AppAvatar(
          imageUrl: hidePhoto || user.avatarUrl.isEmpty ? null : user.avatarUrl,
          name: name,
          size: 120,
        ),
        AppSpacing.vGapMd,
        Text(name, style: context.text.headlineSmall, textAlign: TextAlign.center),
        if (resolveAccountBadge(user.accountType, user.verificationStatus) !=
            AccountBadge.none) ...[
          AppSpacing.vGapXs,
          AccountBadgeIcon(
            accountType: user.accountType,
            verificationStatus: user.verificationStatus,
            size: 18,
          ),
        ],
        if (user.pseudo.isNotEmpty) ...[
          AppSpacing.vGapXs,
          Text('@${user.pseudo}',
              style: context.text.bodyLarge
                  ?.copyWith(color: context.colors.onSurfaceVariant)),
        ],
        if (user.alanyaPhone.isNotEmpty) ...[
          AppSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge_outlined,
                  size: AppIconSize.sm, color: context.colors.primary),
              AppSpacing.hGapXs,
              AlanyaPhoneText(
                user.alanyaPhone,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
        if ((user.paysLibelle ?? '').isNotEmpty) ...[
          AppSpacing.vGapXs,
          CountryRow(country: user.paysLibelle!),
        ],
      ],
    );
  }
}

// ── PRIMARY ACTIONS ────────────────────────────────────────────────────

class _PrimaryActions extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onVideo;
  final VoidCallback onMessage;
  final bool callsDisabled;
  const _PrimaryActions({
    required this.onCall,
    required this.onVideo,
    required this.onMessage,
    this.callsDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrimaryActionTile(
            icon: Icons.call,
            label: context.l10n.callNoun,
            onTap: callsDisabled ? null : onCall,
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: _PrimaryActionTile(
            icon: Icons.videocam,
            label: context.l10n.video2,
            onTap: callsDisabled ? null : onVideo,
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(child: _PrimaryActionTile(icon: Icons.chat_bubble, label: context.l10n.messageNoun, onTap: onMessage)),
      ],
    );
  }
}

class _PrimaryActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _PrimaryActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? context.colors.primary
        : context.colors.onSurfaceVariant.withValues(alpha: 0.45);
    return Material(
      color: enabled
          ? context.colors.primaryContainer
          : context.colors.surfaceContainerHighest,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg + 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              AppSpacing.vGapSm,
              Text(label,
                  style: context.text.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── QUICK ACTIONS ──────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  final bool isFavorite;

  /// Masqué sur mon propre profil : on ne s'ajoute pas à ses contacts.
  final bool showFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  const _QuickActionsCard({
    required this.isFavorite,
    this.showFavorite = true,
    required this.onToggleFavorite,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
      child: Row(
        children: [
          if (showFavorite)
            Expanded(
              child: _QuickAction(
                icon: isFavorite ? Icons.star : Icons.star_border,
                label: isFavorite ? context.l10n.favoriteSingular : context.l10n.add,
                iconColor: isFavorite ? context.semantic.warning : context.colors.primary,
                bg: isFavorite ? context.semantic.warningContainer : context.colors.primaryContainer,
                onTap: onToggleFavorite,
              ),
            ),
          Expanded(
            child: _QuickAction(
              icon: Icons.search,
              label: context.l10n.commonSearch,
              iconColor: context.colors.primary,
              bg: context.colors.primaryContainer,
              onTap: onSearch,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.cleaning_services,
              label: context.l10n.clearAction,
              iconColor: context.colors.primary,
              bg: context.colors.primaryContainer,
              onTap: onClear,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bg;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: AppIconSize.md),
            ),
            AppSpacing.vGapSm,
            Text(
              label,
              style: context.text.labelSmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MEDIA CARD ────────────────────────────────────────────────────────

class _MediaCard extends StatefulWidget {
  final int? conversationId;
  final String conversationName;
  const _MediaCard({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  StreamSubscription<List<LocalMessage>>? _messagesSub;
  List<LocalMessage> _mediaMessages = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }

  void _init() {
    final id = widget.conversationId;
    if (id == null) return;
    final chat = context.read<ChatProvider>();
    // Local-first : Drift immédiat, sync réseau en fond.
    _messagesSub = chat.watchMessages(id).listen(_onMessages);
    unawaited(chat.repository.syncMessages(id));
  }

  void _onMessages(List<LocalMessage> messages) {
    final media = <LocalMessage>[];
    for (final m in messages) {
      if ((m.type == 1 || m.type == 2 || m.type == 4) &&
          m.mediaUrl != null &&
          m.mediaUrl!.isNotEmpty) {
        media.add(m);
      }
    }
    if (!mounted) return;
    setState(() => _mediaMessages = media.reversed.take(4).toList());
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(context.l10n.mediaLinksAndDocs, style: context.text.titleSmall),
              ),
              if (widget.conversationId != null)
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConversationMediaScreen(
                        conversationId: widget.conversationId!,
                        conversationName: widget.conversationName,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Row(
                      children: [
                        Text(context.l10n.seeAll,
                            style: context.text.labelMedium?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right,
                            color: context.colors.primary, size: AppIconSize.sm),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          AppSpacing.vGapLg,
          _mediaMessages.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: Text(context.l10n.noSharedMedia,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant)),
                  ),
                )
              : SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaMessages.length,
                    separatorBuilder: (_, __) => AppSpacing.hGapSm,
                    itemBuilder: (context, index) {
                      final msg = _mediaMessages[index];
                      return GestureDetector(
                        onTap: msg.type == 4
                            ? () => _openDoc(msg)
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MediaViewerScreen(
                                    isVideo: msg.type == 2,
                                    localPath: msg.localMediaPath,
                                    networkUrl: msg.mediaUrl,
                                    title: msg.mediaName,
                                  ),
                                ),
                              ),
                        child: ClipRRect(
                          borderRadius: AppRadius.brSm,
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildThumb(msg),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildThumb(LocalMessage msg) {
    if (msg.type == 4) {
      final style = DocumentFileStyle.fromMessage(
        mediaName: msg.mediaName,
        mediaUrl: msg.mediaUrl,
      );
      return Container(
        color: context.colors.surfaceContainerHighest,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: style.color, borderRadius: AppRadius.brSm),
            child: Center(
              child: Text(style.extension,
                  style: const TextStyle(
                      color: AppColors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }
    if (msg.type == 2) {
      return VideoMessagePreview(
        pendingPath: msg.pendingUploadPath,
        localPath: msg.localMediaPath,
        thumbBase64: msg.mediaThumb,
        durationSeconds: msg.mediaDuration,
        borderRadius: BorderRadius.zero,
        expandToFill: true,
        playIconSize: 22,
        playPadding: 5,
        showDuration: false,
        fallbackColor: context.colors.surfaceContainerHighest,
      );
    }

    final placeholder = context.colors.surfaceContainerHighest;
    final hasLocal = msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();
    final myId = context.read<ChatProvider>().repository.myId;
    final needsDl = !msg.isViewOnce &&
        msg.senderID != myId &&
        !hasLocal &&
        msg.mediaUrl != null &&
        msg.mediaUrl!.isNotEmpty;

    return ImageMessagePreview(
      localPath: msg.localMediaPath,
      networkUrl: msg.mediaUrl,
      thumbBase64: msg.mediaThumb,
      useBlurredThumb: needsDl,
      borderRadius: BorderRadius.zero,
      expandToFill: true,
      fallbackColor: placeholder,
    );
  }

  Future<void> _openDoc(LocalMessage msg) async {
    String? path = (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
        ? msg.localMediaPath
        : null;

    if (path == null) {
      if (msg.mediaUrl == null) return;
      _showLoading();
      final chat = context.read<ChatProvider>();
      final isMine = msg.senderID == chat.repository.myId;
      path = await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl!,
        type: msg.type,
        isMine: isMine,
        isViewOnce: msg.isViewOnce,
        mediaName: msg.mediaName,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } else if (!msg.isViewOnce && msg.msgID != 0) {
      final chat = context.read<ChatProvider>();
      final isMine = msg.senderID == chat.repository.myId;
      await chat.repository.ensureReceivedMediaLocal(
        msgID: msg.msgID,
        mediaUrl: msg.mediaUrl ?? '',
        type: msg.type,
        isMine: isMine,
        isViewOnce: false,
        mediaName: msg.mediaName,
        existingLocalPath: path,
      );
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.unableToDownloadTheFile),
              backgroundColor: context.colors.error),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cannotOpenFileApp(res.message)),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          Center(child: CircularProgressIndicator(color: ctx.colors.primary)),
    );
  }
}

// ── DANGER ACTIONS ────────────────────────────────────────────────────

class _DangerActionsCard extends StatelessWidget {
  final bool isBlocked;
  final bool isFavorite;
  final bool hasConversation;

  /// Masqués sur mon propre profil : on ne se bloque ni ne se retire de ses
  /// propres contacts. Ne reste alors que la suppression de la conversation.
  final bool showBlock;
  final bool showRemoveContact;
  final VoidCallback onBlock;
  final VoidCallback onDeleteConversation;
  final VoidCallback onRemoveContact;
  const _DangerActionsCard({
    required this.isBlocked,
    required this.isFavorite,
    required this.hasConversation,
    this.showBlock = true,
    this.showRemoveContact = true,
    required this.onBlock,
    required this.onDeleteConversation,
    required this.onRemoveContact,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (showBlock)
        _DangerRow(
          icon: CupertinoIcons.nosign,
          label: isBlocked ? context.l10n.unblockContact : context.l10n.blockContact,
          onTap: onBlock,
        ),
      if (hasConversation) ...[
        // Pas de séparateur en tête de carte si « Bloquer » est masqué.
        if (showBlock) _DangerDivider(),
        _DangerRow(
          icon: Icons.delete_outline,
          label: context.l10n.deleteConversation2,
          onTap: onDeleteConversation,
        ),
      ],
      if (showRemoveContact && isFavorite) ...[
        _DangerDivider(),
        _DangerRow(
          icon: Icons.person_remove_outlined,
          label: context.l10n.removeFromContacts,
          onTap: onRemoveContact,
        ),
      ],
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _Card(padding: EdgeInsets.zero, child: Column(children: rows));
  }
}

class _DangerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DangerRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon, color: context.colors.error, size: AppIconSize.md),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(label,
                  style: context.text.bodyLarge?.copyWith(
                      color: context.colors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.colors.outline,
      indent: AppSpacing.lg,
      endIndent: AppSpacing.lg,
    );
  }
}

// ── ERROR STATE ────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String name;
  const _ErrorState({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.exclamationmark_circle,
              color: context.colors.onSurfaceVariant, size: 48),
          AppSpacing.vGapMd,
          Text(
            name.isNotEmpty
                ? context.l10n.unableToLoadNamed(name)
                : context.l10n.contactNotFound,
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.vGapLg,
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.back),
          ),
        ],
      ),
    );
  }
}

// ── CARD CONTAINER ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card(
      {required this.child,
      this.padding = const EdgeInsets.all(AppSpacing.lg)});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        // En sombre, `surface` est plus foncé que `surfaceMuted` (fond page) :
        // on élève la carte pour garder le contraste carte / fond.
        color: isDark
            ? context.colors.surfaceContainerHigh
            : context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: isDark ? null : AppShadows.subtle,
        border: isDark
            ? Border.all(color: context.colors.outline.withValues(alpha: 0.55))
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
