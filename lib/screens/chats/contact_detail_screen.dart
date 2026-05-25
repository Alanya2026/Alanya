import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/db/app_database.dart';
import '../../core/services/call_service.dart';
import '../../core/utils/country_flag.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/contact_action_button.dart';
import '../../widgets/quick_action_button.dart';
import '../../widgets/section_card.dart';
import '../calls/ongoing_call_screen.dart';
import 'chat_detail_screen.dart';
import 'conversation_media_screen.dart';
import 'media_viewer_screen.dart';
/// Fiche d
taill
e d'un contact dans une discussion individuelle.
/// Accessible depuis l'en-t
te du chat ou un chip de l'
cran profil.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({
    super.key,
    required this.userId,
    this.conversationId,
    this.initialName = '',
    this.initialAvatar = '',
  });
  final int userId;
  final int? conversationId;
  final String initialName;
  final String initialAvatar;
  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late final TalkyApiClient _api;
  late final ChatProvider _chat;
  User? _user;
  Pays? _pays;
  bool _loading = true;
  bool _isFavorite = false;
  bool _isBlocked = false;
  bool _busy = false; // verrou pour les actions r
seau (bloquer/favori)
  @override
  void initState() {
    super.initState();
    _api = Provider.of<TalkyApiClient>(context, listen: false);
    _chat = Provider.of<ChatProvider>(context, listen: false);
    _load();
  Future<void> _load() async {
    // Chaque appel est ind
pendant : l'
chec de l'un (ex. /block si le backend
    // n'est pas 
 jour) ne doit pas effacer l'
tat des autres (favori, profil).
    final user = await _api.getUserById(widget.userId).catchError((_) => <String, dynamic>{});
    final favorite = await _api.checkIsContact(widget.userId).catchError((_) => false);
    final blocked = await _api.isBlocked(widget.userId).catchError((_) => false);
    final paysRaw = await _api.getPays().catchError((_) => <dynamic>[]);
    if (!mounted) return;
    final parsedUser = user.isNotEmpty ? User.fromJson(user) : null;
    final countries = paysRaw.map((e) => Pays.fromJson(e as Map<String, dynamic>)).toList();
    setState(() {
      if (parsedUser != null) _user = parsedUser;
      _pays = _findPays(countries, parsedUser?.idPays);
      _isFavorite = favorite;
      _isBlocked = blocked;
      _loading = false;
    });
  Pays? _findPays(List<Pays> countries, int? id) {
    if (id == null) return null;
    for (final p in countries) {
      if (p.idPays == id) return p;
    }
    return null;
  String get _displayName =>
      _user?.nom.isNotEmpty == true ? _user!.nom : (_user?.pseudo ?? widget.initialName);
  String get _avatarUrl => _user?.avatarUrl ?? widget.initialAvatar;
  // 
 Actions 
  Future<void> _initiateCall({required bool isVideo}) async {
    final callService = Provider.of<CallService>(context, listen: false);
    final me = await _api.getMe();
    if (!mounted) return;
    await callService.initiateCall(
      targetUserId: widget.userId,
      myId: me['alanyaID'] ?? 0,
      myName: me['nom'] ?? me['pseudo'] ?? '',
      myPhoto: me['avatar_url'],
      targetUserName: _displayName,
      isVideo: isVideo,
    );
    if (!mounted) return;
    if (callService.errorMessage != null) {
      _snack(callService.errorMessage!, error: true);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OngoingCallScreen()));
  Future<void> _openMessage() async {
    if (widget.conversationId != null) {
      Navigator.pop(context); // revient 
 la discussion d'origine
      return;
    }
    try {
      final conv = await _api.createConversation(participantID: widget.userId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            userName: _displayName,
            conversationId: conv['conversID'],
            userId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      _snack('Impossible d\'ouvrir la discussion : $e', error: true);
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
  Future<void> _toggleBlock() async {
    final next = !_isBlocked;
    final ok = await _confirm(
      title: next ? 'Bloquer ce contact ?' : 'D
bloquer ce contact ?',
      message: next
          ? 'Vous ne recevrez plus ses messages ni ses appels.'
          : 'Vous pourrez 
 nouveau 
changer avec ce contact.',
      confirmLabel: next ? 'Bloquer' : 'D
bloquer',
      destructive: next,
    );
    if (ok != true || _busy) return;
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
  Future<void> _clearConversation() async {
    final convId = widget.conversationId;
    if (convId == null) return;
    final ok = await _confirm(
      title: 'Effacer la discussion ?',
      message: 'Tous les messages seront supprim
s sur cet appareil.',
      confirmLabel: 'Effacer',
      destructive: true,
    );
    if (ok != true) return;
    await _chat.repository.clearConversation(convId);
    if (mounted) _snack('Discussion effac
e');
  Future<void> _deleteConversation() async {
    final convId = widget.conversationId;
    if (convId == null) return;
    final ok = await _confirm(
      title: 'Supprimer la discussion ?',
      message: 'La discussion sera supprim
finitivement.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (ok != true) return;
    await _chat.repository.deleteConversation(convId);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  Future<void> _removeContact() async {
    final ok = await _confirm(
      title: 'Retirer des contacts ?',
      message: '$_displayName sera retir
 de vos contacts pr
s.',
      confirmLabel: 'Retirer',
      destructive: true,
    );
    if (ok != true) return;
    try {
      await _api.removeContact(widget.userId);
      if (mounted) setState(() => _isFavorite = false);
      _snack('Contact retir
    } catch (e) {
      _snack('Action impossible : $e', error: true);
    }
  // 
 Helpers UI 
  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel,
                style: TextStyle(color: destructive ? Colors.red : Colors.indigo)),
          ),
        ],
      ),
    );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (v) {
              switch (v) {
                case 'block':
                  _toggleBlock();
                case 'delete':
                  _deleteConversation();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'block', child: Text(_isBlocked ? 'D
bloquer' : 'Bloquer')),
              if (widget.conversationId != null)
                const PopupMenuItem(value: 'delete', child: Text('Supprimer la discussion')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : ListView(
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildActionButtons(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 20),
                if (widget.conversationId != null) ...[
                  _buildMediaSection(),
                  const SizedBox(height: 20),
                ],
                _buildAdvancedOptions(),
                const SizedBox(height: 32),
              ],
            ),
    );
  // 2. Photo + nom + identifiants
  Widget _buildHeader() {
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
    return Column(
      children: [
        CircleAvatar(
          radius: 56,
          backgroundColor: Colors.indigo.shade100,
          backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
          child: _avatarUrl.isEmpty
              ? Text(initial,
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold, color: Colors.indigo))
              : null,
        ),
        const SizedBox(height: 14),
        Text(_displayName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        if (_user?.pseudo.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          Text('@${_user!.pseudo}',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ],
        if (_user?.alanyaPhone.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_iphone, size: 15, color: Colors.indigo.shade300),
              const SizedBox(width: 4),
              Text('AlanyaPhone ${_user!.alanyaPhone}',
                  style: const TextStyle(fontSize: 14, color: Colors.indigo)),
            ],
          ),
        ],
        if (_pays != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Builder(builder: (_) {
                final flag = CountryFlags.flagFor(_pays!);
                return flag.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(flag, style: const TextStyle(fontSize: 16)),
                      );
              }),
              Text(_pays!.libelle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ],
        if (_isBlocked) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
            child: const Text('Contact bloqu
                style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ContactActionButton(icon: Icons.call, label: 'Appel', onTap: () => _initiateCall(isVideo: false)),
          const SizedBox(width: 12),
          ContactActionButton(icon: Icons.videocam, label: 'Vid
o', onTap: () => _initiateCall(isVideo: true)),
          const SizedBox(width: 12),
          ContactActionButton(icon: Icons.sms_outlined, label: 'Message', onTap: _openMessage),
        ],
      ),
    );
  // 3. Actions rapides
  Widget _buildQuickActions() {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          QuickActionButton(
            icon: _isFavorite ? Icons.star : Icons.star_border,
            label: _isFavorite ? 'Favori' : 'Ajouter',
            active: _isFavorite,
            onTap: _toggleFavorite,
          ),
          QuickActionButton(
            icon: Icons.search,
            label: 'Rechercher',
            onTap: () => _snack('Recherche dans la conversation : bient
t disponible'),
          ),
          if (widget.conversationId != null)
            QuickActionButton(
              icon: Icons.cleaning_services_outlined,
              label: 'Effacer',
              onTap: _clearConversation,
            ),
        ],
      ),
    );
  // 4. M
dias, liens et docs (aper
  Widget _buildMediaSection() {
    final convId = widget.conversationId!;
    return SectionCard(
      title: 'M
dias, liens et docs',
      onSeeAll: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ConversationMediaScreen(conversationId: convId)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: 84,
        child: StreamBuilder<List<LocalMessage>>(
          stream: _chat.watchMessages(convId),
          builder: (context, snapshot) {
            final media = (snapshot.data ?? const <LocalMessage>[])
                .where((m) => !m.isDeleted && (m.type == 1 || m.type == 2))
                .toList()
                .reversed
                .take(12)
                .toList();
            if (media.isEmpty) {
              return Center(
                child: Text('Aucun m
dia partag
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              );
            }
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _MediaThumb(msg: media[i]),
            );
          },
        ),
      ),
    );
  // 6. Options avanc
  Widget _buildAdvancedOptions() {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _optionTile(
            icon: _isBlocked ? Icons.lock_open : Icons.block,
            label: _isBlocked ? 'D
bloquer le contact' : 'Bloquer le contact',
            color: Colors.red,
            onTap: _toggleBlock,
          ),
          if (widget.conversationId != null) ...[
            const Divider(height: 1),
            _optionTile(
              icon: Icons.delete_outline,
              label: 'Supprimer la discussion',
              color: Colors.red,
              onTap: _deleteConversation,
            ),
          ],
          if (_isFavorite) ...[
            const Divider(height: 1),
            _optionTile(
              icon: Icons.person_remove_outlined,
              label: 'Retirer des contacts',
              color: Colors.red,
              onTap: _removeContact,
            ),
          ],
        ],
      ),
    );
  Widget _optionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
class _MediaThumb extends StatelessWidget {
  const _MediaThumb({required this.msg});
  final LocalMessage msg;
  bool get _hasLocal => msg.localMediaPath != null && File(msg.localMediaPath!).existsSync();
  @override
  Widget build(BuildContext context) {
    final isVideo = msg.type == 2;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            isVideo: isVideo,
            localPath: _hasLocal ? msg.localMediaPath : null,
            networkUrl: msg.mediaUrl,
            title: msg.mediaName,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (isVideo)
                Container(
                  color: Colors.black87,
                  child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                )
              else if (_hasLocal)
                Image.file(File(msg.localMediaPath!), fit: BoxFit.cover)
              else
                CachedNetworkImage(
                  imageUrl: msg.mediaUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ColoredBox(color: Colors.black12),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Colors.black12, child: Icon(Icons.broken_image, color: Colors.white54)),
                ),
            ],
          ),
        ),
      ),
    );