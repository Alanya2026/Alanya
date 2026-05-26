import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/db/app_database.dart';
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
    try {
      final data = await _api.getUserById(widget.userId);
      bool fav = false;
      try {
        fav = await _api.checkIsContact(widget.userId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _contact = User.fromJson(data);
        _isFavorite = fav;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
      message: 'Les messages locaux de cette discussion seront supprimés.',
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
                color: destructive ? Colors.red : null,
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
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
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
                PopupMenuItem(value: 'clear', child: Text('Effacer les messages')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer la discussion')),
              ],
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contact == null
              ? _ErrorState(name: widget.initialName)
              : _buildContent(_contact!),
    );
  }

  Widget _buildContent(User u) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _Header(user: u),
        const SizedBox(height: 20),
        _PrimaryActions(
          onCall: () => _snack('Appel à venir'),
          onVideo: () => _snack('Vidéo à venir'),
          onMessage: _openChat,
        ),
        const SizedBox(height: 16),
        _QuickActionsCard(
          isFavorite: _isFavorite,
          onToggleFavorite: _toggleFavorite,
          onSearch: () => _snack('Recherche à venir'),
          onClear: _clearMessages,
        ),
        const SizedBox(height: 16),
        _MediaCard(
          conversationId: widget.conversationId,
          conversationName: u.nom,
        ),
        const SizedBox(height: 16),
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

// ── HEADER (avatar + name + identifiants) ────────────────────────────

class _Header extends StatelessWidget {
  final User user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user.nom.isNotEmpty ? user.nom : user.pseudo;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: const Color(0xFFCBD0E8),
          backgroundImage: user.avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(user.avatarUrl)
              : null,
          child: user.avatarUrl.isEmpty
              ? Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        if (user.pseudo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '@${user.pseudo}',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ],
        if (user.alanyaPhone.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phone_iphone,
                size: 16,
                color: Colors.indigo.shade400,
              ),
              const SizedBox(width: 4),
              Text(
                'AlanyaPhone ${user.alanyaPhone}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E66D8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
        if ((user.paysLibelle ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _flagEmoji(user.paysLibelle!),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
              Text(
                user.paysLibelle!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _flagEmoji(String country) {
    // Mapping libellé (table `pays`) → ISO 3166-1 alpha-2.
    // Ajouter une entrée ici quand un pays est ajouté en DB.
    const iso = {
      'france': 'FR',
      'united states': 'US',
      'united kingdom': 'GB',
      'germany': 'DE',
      'spain': 'ES',
      'italy': 'IT',
      'belgium': 'BE',
      'switzerland': 'CH',
      'canada': 'CA',
      'cameroun': 'CM',
      'congo': 'CD',
      'gabon': 'GA',
      'côte d\'ivoire': 'CI',
      'senegal': 'SN',
      'mali': 'ML',
      'burkina faso': 'BF',
      'niger': 'NE',
      'chad': 'TD',
      'central african republic': 'CF',
      'equatorial guinea': 'GQ',
      'china': 'CN',
      'japan': 'JP',
      'india': 'IN',
      'brazil': 'BR',
      'argentina': 'AR',
      'mexico': 'MX',
      'australia': 'AU',
      'russia': 'RU',
      'south africa': 'ZA',
      'nigeria': 'NG',
    };
    final code = iso[country.toLowerCase().trim()];
    if (code == null || code.length != 2) return '🌍';
    // Construction algorithmique : chaque lettre ISO → regional indicator symbol.
    const base = 0x1F1E6; // 'A' regional indicator
    final a = 'A'.codeUnitAt(0);
    return String.fromCharCodes([
      base + code.codeUnitAt(0) - a,
      base + code.codeUnitAt(1) - a,
    ]);
  }
}

// ── PRIMARY ACTIONS (Appel / Vidéo / Message) ────────────────────────

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
        Expanded(
          child: _PrimaryActionTile(
            icon: Icons.call,
            label: 'Appel',
            onTap: onCall,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryActionTile(
            icon: Icons.videocam,
            label: 'Vidéo',
            onTap: onVideo,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryActionTile(
            icon: Icons.chat_bubble,
            label: 'Message',
            onTap: onMessage,
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PrimaryActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE3EEFE),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF1E66D8), size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1E66D8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── QUICK ACTIONS (Ajouter favori / Rechercher / Effacer) ────────────

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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: isFavorite ? Icons.star : Icons.star_border,
              label: isFavorite ? 'Favori' : 'Ajouter',
              iconColor: isFavorite ? Colors.amber.shade600 : const Color(0xFF1E66D8),
              bg: isFavorite ? const Color(0xFFFEF3CB) : const Color(0xFFE3EEFE),
              onTap: onToggleFavorite,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.search,
              label: 'Rechercher',
              iconColor: const Color(0xFF1E66D8),
              bg: const Color(0xFFE3EEFE),
              onTap: onSearch,
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.cleaning_services,
              label: 'Effacer',
              iconColor: const Color(0xFF1E66D8),
              bg: const Color(0xFFE3EEFE),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
    required this.conversationId,
    required this.conversationName,
  });

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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Médias, liens et docs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
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
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Text(
                          'Voir tout',
                          style: TextStyle(
                            color: Color(0xFF1E66D8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Color(0xFF1E66D8),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _mediaMessages.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Aucun média partagé',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              : SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mediaMessages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                          borderRadius: BorderRadius.circular(10),
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
      final ext = name.contains('.')
          ? name.split('.').last.toUpperCase()
          : 'FILE';
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _docColor(ext),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                ext,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (msg.type == 2) {
      return Container(color: Colors.grey.shade200);
    }

    final hasLocal = msg.localMediaPath != null &&
        File(msg.localMediaPath!).existsSync();
    if (hasLocal) {
      return Image.file(
        File(msg.localMediaPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    }
    final url = msg.mediaUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(color: Colors.grey.shade200),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Icon(Icons.image, color: Colors.grey),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }

  Color _docColor(String ext) {
    switch (ext) {
      case 'PDF':
        return Colors.red.shade400;
      case 'DOC':
      case 'DOCX':
        return Colors.blue.shade400;
      case 'XLS':
      case 'XLSX':
        return Colors.green.shade400;
      case 'PPT':
      case 'PPTX':
        return Colors.orange.shade400;
      case 'ZIP':
      case 'RAR':
        return Colors.purple.shade400;
      default:
        return Colors.grey.shade500;
    }
  }

  Future<void> _openDoc(LocalMessage msg) async {
    String? path = (msg.localMediaPath != null &&
            File(msg.localMediaPath!).existsSync())
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
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Aucune app pour ouvrir ce fichier (${res.message})'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
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
  const _DangerRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFEF4444), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
      color: Colors.grey.shade200,
      indent: 16,
      endIndent: 16,
    );
  }
}

// ── ERROR STATE ───────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String name;
  const _ErrorState({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle,
            color: Colors.grey,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            name.isNotEmpty
                ? 'Impossible de charger $name'
                : 'Contact introuvable',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
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
  const _Card({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
