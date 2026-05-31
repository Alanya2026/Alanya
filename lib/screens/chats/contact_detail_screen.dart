import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/db/app_database.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/utils/country_utils.dart';
import '../../widgets/common/common.dart';
import 'chat_detail_screen.dart';
import 'conversation_media_screen.dart';
import 'media_viewer_screen.dart';

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
  bool _isBlocked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<TalkyApiClient>();
    _load();
  }

  Future<void> _load() async {
    final cache = context.read<LocalCacheRepository>();

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
      final u = await cache.getKnownUser(widget.userId);
      if (u != null && mounted) {
        setState(() {
          _contact = User(
            alanyaID: u.alanyaID,
            nom: u.nom,
            pseudo: u.pseudo,
            alanyaPhone: u.alanyaPhone,
            email: u.email,
            idPays: u.idPays,
            avatarUrl: u.avatarUrl,
            typeCompte: u.typeCompte,
            isOnline: u.isOnline,
            lastSeen: u.lastSeen?.toIso8601String() ?? '',
            paysLibelle: u.paysLibelle,
          );
          _isFavorite = u.isPreferredContact;
          _isLoading = false;
        });
      }
    } catch (_) {}

    try {
      final data = await _api.getUserById(widget.userId);
      bool fav = false;
      try {
        fav = await _api.checkIsContact(widget.userId);
      } catch (_) {}
      if (!mounted) return;
      final user = User.fromJson(data);
      setState(() {
        _contact = user;
        _isFavorite = fav;
        _isLoading = false;
      });
      cache.upsertKnownUser(user, preferred: fav);
    } catch (_) {
      if (mounted && _contact == null) setState(() => _isLoading = false);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────

  Future<void> _openChat() async {
    if (_contact == null) return;
    final convId = widget.conversationId ??
        (await _api
                .createConversation(participantID: widget.userId)
                .catchError((_) => <String, dynamic>{}))['conversID']
            as int?;
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
      _snack('Action impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock() async {
    if (_busy) return;
    final next = !_isBlocked;
    final confirmed = await _confirm(
      title: next ? 'Bloquer ce contact ?' : 'Débloquer ce contact ?',
      message: next
          ? 'Il ne pourra plus vous envoyer de messages ni vous appeler.'
          : 'Il pourra de nouveau vous contacter.',
      confirmLabel: next ? 'Bloquer' : 'Débloquer',
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
      if (mounted) setState(() => _isBlocked = next);
    } catch (e) {
      _snack('Action impossible : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearMessages() async {
    final convId = widget.conversationId;
    if (convId == null) {
      _snack('Aucune discussion à effacer');
      return;
    }
    final confirmed = await _confirm(
      title: 'Effacer les messages ?',
      message:
          'Les messages locaux de cette discussion seront supprimés.',
      confirmLabel: 'Effacer',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    final dao = context.read<ChatProvider>().repository.dao;
    await (dao.db.delete(dao.db.localMessages)
          ..where((m) => m.conversationID.equals(convId)))
        .go();
    if (mounted) _snack('Messages effacés');
  }

  Future<void> _deleteConversation() async {
    final convId = widget.conversationId;
    if (convId == null) {
      _snack('Aucune discussion à supprimer');
      return;
    }
    final confirmed = await _confirm(
      title: 'Supprimer la discussion ?',
      message: 'L\'historique sera supprimé.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteConversation(convId);
    } catch (_) {}
    if (!mounted) return;
    final dao = context.read<ChatProvider>().repository.dao;
    await dao.deleteConversation(convId);
    if (!mounted) return;
    await context.read<ChatProvider>().refreshConversations();
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
            child: const Text('Annuler'),
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
          backgroundColor: error ? AppColors.error : null),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceMuted,
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
              PopupMenuItem(
                value: 'block',
                child: Text(_isBlocked ? 'Débloquer' : 'Bloquer'),
              ),
              if (widget.conversationId != null) ...const [
                PopupMenuItem(
                    value: 'clear', child: Text('Effacer les messages')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer la discussion')),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
          AppSpacing.xxl),
      children: [
        _Header(user: u),
        AppSpacing.vGapXl,
        _PrimaryActions(
          onCall: () => _snack('Appel à venir'),
          onVideo: () => _snack('Vidéo à venir'),
          onMessage: _openChat,
        ),
        AppSpacing.vGapLg,
        _QuickActionsCard(
          isFavorite: _isFavorite,
          onToggleFavorite: _toggleFavorite,
          onSearch: () => _snack('Recherche à venir'),
          onClear: _clearMessages,
        ),
        AppSpacing.vGapLg,
        _MediaCard(
          conversationId: widget.conversationId,
          conversationName: u.nom,
        ),
        AppSpacing.vGapLg,
        _DangerActionsCard(
          isBlocked: _isBlocked,
          isFavorite: _isFavorite,
          hasConversation: widget.conversationId != null,
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
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user.nom.isNotEmpty ? user.nom : user.pseudo;
    return Column(
      children: [
        AppAvatar(imageUrl: user.avatarUrl, name: name, size: 120),
        AppSpacing.vGapMd,
        Text(name, style: context.text.headlineSmall, textAlign: TextAlign.center),
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
              Icon(Icons.phone_iphone,
                  size: AppIconSize.sm, color: context.colors.primary),
              AppSpacing.hGapXs,
              Text(
                'AlanyaPhone ${user.alanyaPhone}',
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
  const _PrimaryActions({
    required this.onCall,
    required this.onVideo,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PrimaryActionTile(icon: Icons.call, label: 'Appel', onTap: onCall)),
        AppSpacing.hGapMd,
        Expanded(child: _PrimaryActionTile(icon: Icons.videocam, label: 'Vidéo', onTap: onVideo)),
        AppSpacing.hGapMd,
        Expanded(child: _PrimaryActionTile(icon: Icons.chat_bubble, label: 'Message', onTap: onMessage)),
      ],
    );
  }
}

class _PrimaryActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.primaryContainer,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        borderRadius: AppRadius.brMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg + 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: context.colors.primary, size: 28),
              AppSpacing.vGapSm,
              Text(label,
                  style: context.text.labelSmall?.copyWith(
                      color: context.colors.primary,
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
  final VoidCallback onToggleFavorite;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  const _QuickActionsCard({
    required this.isFavorite,
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
          Expanded(
            child: _QuickAction(
              icon: isFavorite ? Icons.star : Icons.star_border,
              label: isFavorite ? 'Favori' : 'Ajouter',
              iconColor: isFavorite ? Colors.amber.shade600 : context.colors.primary,
              bg: isFavorite ? const Color(0xFFFEF3CB) : context.colors.primaryContainer,
              onTap: onToggleFavorite,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.search,
              label: 'Rechercher',
              iconColor: context.colors.primary,
              bg: context.colors.primaryContainer,
              onTap: onSearch,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.cleaning_services,
              label: 'Effacer',
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
  const _MediaCard({required this.conversationId, required this.conversationName});

  @override
  State<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<_MediaCard> {
  List<LocalMessage> _mediaMessages = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = widget.conversationId;
    if (id == null) return;
    final chat = context.read<ChatProvider>();
    await chat.repository.syncMessages(id);
    chat.watchMessages(id).listen(_onMessages);
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
                child: Text('Médias, liens et docs', style: context.text.titleSmall),
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
                        Text('Voir tout',
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
                    child: Text('Aucun média partagé',
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
                                if (msg.type == 2)
                                  Container(
                                    color: Colors.black26,
                                    child: const Icon(
                                      CupertinoIcons.play_circle_fill,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
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
      final name = msg.mediaName ?? 'Document';
      final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
      return Container(
        color: AppColors.surfaceSubtle,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _docColor(ext), borderRadius: AppRadius.brSm),
            child: Center(
              child: Text(ext,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      );
    }
    if (msg.type == 2) return Container(color: AppColors.surfaceSubtle);

    final hasLocal = msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();
    if (hasLocal) {
      return Image.file(File(msg.localMediaPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceSubtle));
    }
    final url = msg.mediaUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppColors.surfaceSubtle),
        errorWidget: (context, url, error) => Container(color: AppColors.surfaceSubtle),
      );
    }
    return Container(color: AppColors.surfaceSubtle);
  }

  Color _docColor(String ext) {
    switch (ext) {
      case 'PDF': return Colors.red.shade400;
      case 'DOC': case 'DOCX': return Colors.blue.shade400;
      case 'XLS': case 'XLSX': return Colors.green.shade400;
      case 'PPT': case 'PPTX': return Colors.orange.shade400;
      case 'ZIP': case 'RAR': return Colors.purple.shade400;
      default: return Colors.grey.shade500;
    }
  }

  Future<void> _openDoc(LocalMessage msg) async {
    String? path = (msg.localMediaPath != null && File(msg.localMediaPath!).existsSync())
        ? msg.localMediaPath
        : null;

    if (path == null) {
      if (msg.mediaUrl == null) return;
      _showLoading();
      final chat = context.read<ChatProvider>();
      path = await chat.repository.mediaCache.ensureCached(msg.mediaUrl!);
      if (path != null && msg.msgID != 0) {
        await chat.repository.dao.setLocalMediaPath(msg.msgID, path);
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Impossible de télécharger le fichier'),
              backgroundColor: AppColors.error),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aucune app pour ouvrir ce fichier (${res.message})'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ── DANGER ACTIONS ────────────────────────────────────────────────────

class _DangerActionsCard extends StatelessWidget {
  final bool isBlocked;
  final bool isFavorite;
  final bool hasConversation;
  final VoidCallback onBlock;
  final VoidCallback onDeleteConversation;
  final VoidCallback onRemoveContact;
  const _DangerActionsCard({
    required this.isBlocked,
    required this.isFavorite,
    required this.hasConversation,
    required this.onBlock,
    required this.onDeleteConversation,
    required this.onRemoveContact,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _DangerRow(
        icon: CupertinoIcons.nosign,
        label: isBlocked ? 'Débloquer le contact' : 'Bloquer le contact',
        onTap: onBlock,
      ),
      if (hasConversation) ...[
        _DangerDivider(),
        _DangerRow(
          icon: Icons.delete_outline,
          label: 'Supprimer la discussion',
          onTap: onDeleteConversation,
        ),
      ],
      if (isFavorite) ...[
        _DangerDivider(),
        _DangerRow(
          icon: Icons.person_remove_outlined,
          label: 'Retirer des contacts',
          onTap: onRemoveContact,
        ),
      ],
    ];
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
            Icon(icon, color: AppColors.error, size: AppIconSize.md),
            AppSpacing.hGapMd,
            Expanded(
              child: Text(label,
                  style: context.text.bodyLarge?.copyWith(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
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
                ? 'Impossible de charger $name'
                : 'Contact introuvable',
            style: context.text.bodyMedium
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.vGapLg,
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
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
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: AppShadows.subtle,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
