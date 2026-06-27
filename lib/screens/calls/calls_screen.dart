import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/call_service.dart';
import '../../providers/auth_provider.dart';
import '../../core/db/app_database.dart';
import '../../core/utils/app_log.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/services/local_hidden_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/common/common.dart';
import '../../widgets/profile_avatar.dart';
import '../home/glass_nav_bar.dart' show kGlassNavBarSpace;
import 'call_detail_screen.dart';
import 'keypad_screen.dart';
import 'select_contact_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<Call> _recentCalls = [];
  bool _isLoading = true;
  // !! ID mis en cache — pas de FutureBuilder dans chaque ListTile
  int _myId = 0;
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _initCurrentUser();
    _loadRecentCalls();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _search = '';
      }
    });
  }

  void _initCurrentUser() {
    // Récupérer l'ID depuis AuthProvider (déjà chargé, pas d'appel réseau)
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _myId = auth.currentUser?.alanyaID ?? 0;
  }

  Future<void> _loadRecentCalls() async {
    // 1) Hydrate immédiatement depuis le cache local (instantané, offline-safe).
    try {
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      final localCalls = await cache.watchCalls().first;
      if (!mounted) return;
      if (localCalls.isNotEmpty) {
        setState(() {
          _recentCalls = localCalls.map(_localToCall).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = true);
      }
    } catch (e, st) {
      AppLog.e('CallsScreen', 'Chargement appels (cache) échoué', e, st);
    }

    // 2) Rafraîchit depuis l'API (best-effort, écrase le cache si succès).
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final raw = await apiClient.getCallHistory();
      final calls = raw
          .map((item) => item is Call
              ? item
              : Call.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _recentCalls = calls;
        _isLoading = false;
      });
      // Sync background → met aussi à jour le cache local pour la prochaine fois.
      if (mounted && _myId != 0) {
        final cache = Provider.of<LocalCacheRepository>(context, listen: false);
        cache.syncCalls(myId: _myId);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Call _localToCall(LocalCall c) {
    return Call(
      idCall: c.idCall,
      idCaller: c.idCaller,
      idReceiver: c.idReceiver,
      type: c.type,
      status: c.status,
      createdAt: c.createdAt.toIso8601String(),
      duree: c.duration,
      caller: c.idCaller != _myId
          ? User(
              alanyaID: c.idCaller,
              nom: c.otherNom ?? '',
              pseudo: '',
              alanyaPhone: '',
              email: '',
              idPays: 0,
              avatarUrl: c.otherAvatar ?? '',
              typeCompte: 0,
              isOnline: false,
              lastSeen: '',
            )
          : null,
      receiver: c.idReceiver != _myId
          ? User(
              alanyaID: c.idReceiver,
              nom: c.otherNom ?? '',
              pseudo: '',
              alanyaPhone: '',
              email: '',
              idPays: 0,
              avatarUrl: c.otherAvatar ?? '',
              typeCompte: 0,
              isOnline: false,
              lastSeen: '',
            )
          : null,
    );
  }

  Future<void> _callFromHistory(Call call, bool isVideo) async {
    // Déterminer l'autre participant
    final otherUser = call.idCaller != _myId ? call.caller : call.receiver;
    if (otherUser == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myName = auth.currentUser?.nom ?? '';
    final myPhoto = auth.currentUser?.avatarUrl;

    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: otherUser.alanyaID,
      myId: _myId,
      myName: myName,
      myPhoto: myPhoto,
      targetUserName: otherUser.nom,
      targetUserPhoto: otherUser.avatarUrl,
      isVideo: isVideo,
    );

    if (context.mounted) {
      // Vérifier s'il y a eu une erreur (ex: permissions refusées)
      if (callService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(callService.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      await callService.navigateToCallUi(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appels', style: context.text.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher',
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add_call),
            tooltip: 'Nouvel appel',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SelectContactScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSearchBar(
            open: _searchOpen,
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            onClose: _toggleSearch,
          ),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KeypadScreen()),
        ),
        child: const Icon(Icons.dialpad),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const LoadingState();
    }
    // Réactif : se rebuild quand l'utilisateur supprime un appel localement.
    final hidden = context.watch<LocalHiddenStore>();
    final visible = _recentCalls.where((c) => !hidden.isCallHidden(c.idCall));
    final filtered = _search.isEmpty
        ? visible.toList()
        : visible.where((call) {
            final otherUser = call.idCaller != _myId ? call.caller : call.receiver;
            return (otherUser?.nom ?? '').toLowerCase().contains(_search);
          }).toList();
    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.call_outlined,
        title: _search.isEmpty ? 'Aucun appel récent' : 'Aucun résultat',
        message: _search.isEmpty
            ? 'Vos appels passés et reçus apparaîtront ici.'
            : 'Essayez un autre nom.',
      );
    }
    final colors = context.colors;
    return RefreshIndicator(
      onRefresh: _loadRecentCalls,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final call = filtered[index];
          // !! Calcul direct — pas de FutureBuilder
          final otherUser = call.idCaller != _myId ? call.caller : call.receiver;
          final isMissed = call.isMissed;
          final isVideo = call.isVideo;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            onLongPress: () => _showCallActions(call, otherUser?.nom ?? 'Inconnu'),
            leading: ProfileAvatar(
              imageUrl: otherUser?.avatarUrl,
              name: otherUser?.nom ?? 'Inconnu',
              userId: otherUser?.alanyaID ?? 0,
              isGroup: false,
              size: AppSizes.avatarLg,
              borderRadius: AppSizes.avatarLg / 2,
            ),
            title: Text(
              otherUser?.nom ?? 'Inconnu',
              style: context.text.titleMedium?.copyWith(
                color: isMissed ? colors.error : colors.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(
                    isMissed ? Icons.call_missed : Icons.call_made,
                    size: 16,
                    color: isMissed ? colors.error : context.semantic.success,
                  ),
                  AppSpacing.hGapXs,
                  Flexible(
                    child: Text(
                      '${_formatDate(call.createdAt)} • ${isVideo ? "Vidéo" : "Audio"}'
                      '${call.duree != null && call.duree! > 0 ? " • ${call.formattedDuration}" : ""}',
                      style: context.text.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded),
              color: colors.primary,
              onPressed: () => _callFromHistory(call, isVideo),
            ),
            onTap: otherUser == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallDetailScreen(
                          user: otherUser,
                          call: call,
                        ),
                      ),
                    ),
          );
        },
      ),
    );
  }

  Future<void> _showCallActions(Call call, String name) async {
    final hidden = context.read<LocalHiddenStore>();
    final error = context.colors.error;
    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => AppBottomSheet(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(name, style: context.text.titleMedium),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: error),
              title: Text('Supprimer', style: TextStyle(color: error)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await hidden.hideCall(call.idCall);
              },
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return 'Aujourd\'hui ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Récemment';
    }
  }
}