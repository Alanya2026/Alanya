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
import '../../core/services/call/call_history_rules.dart';
import '../../core/services/call/voicemail_provider.dart';
import '../../widgets/calls/voicemail_quick_sheet.dart';
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
  /// Taille de page — doit rester <= au plafond serveur (100).
  static const int _pageSize = 50;

  List<Call> _recentCalls = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  /// Rafraîchissement en cours — voir `canLoadMorePage`.
  bool _isRefreshing = false;
  bool _hasMore = true;
  // !! ID mis en cache — pas de FutureBuilder dans chaque ListTile
  int _myId = 0;
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  String _search = '';
  final Map<int, LocalUser> _knownUsers = {};

  @override
  void initState() {
    super.initState();
    _initCurrentUser();
    _scrollCtrl.addListener(_onScroll);
    _loadRecentCalls();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    // Marge de 300 px : la page suivante arrive avant que le pouce touche le bas.
    if (pos.pixels >= pos.maxScrollExtent - 300) _loadMoreCalls();
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

  /// Fusionne une page dans la liste courante — jamais d'affectation directe.
  /// Le cache local garde plus d'historique qu'une page serveur : écraser
  /// faisait disparaître de l'écran les appels déjà descendus, à chaque
  /// rafraîchissement. La version serveur l'emporte sur la copie en cache
  /// (statut et durée y sont à jour), le reste est conservé.
  void _mergeCalls(Iterable<Call> incoming) {
    final byId = {for (final c in _recentCalls) c.idCall: c};
    for (final c in incoming) {
      byId[c.idCall] = c;
    }
    // Date décodée une fois par appel, pas à chaque comparaison : le tri rejoue
    // sur la liste entière à chaque page chargée, et elle ne fait que grandir.
    final dated = [
      for (final c in byId.values) (date: _callDate(c), call: c),
    ]..sort((a, b) {
        final cmp = b.date.compareTo(a.date);
        return cmp != 0 ? cmp : b.call.idCall.compareTo(a.call.idCall);
      });
    _recentCalls = [for (final e in dated) e.call];
  }

  DateTime _callDate(Call c) =>
      DateTime.tryParse(c.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

  List<Call> _parseCalls(List<dynamic> raw) => raw
      .map((item) =>
          item is Call ? item : Call.fromJson(item as Map<String, dynamic>))
      .toList();

  Future<void> _loadRecentCalls() async {
    // Le rafraîchissement et le chargement de page suivante écrivent tous deux
    // `_hasMore`, et `_isLoading` n'était posé que si le cache local était vide :
    // les deux pouvaient se courir après, le plus lent écrasant la conclusion du
    // plus rapide. Ce drapeau-ci les exclut vraiment l'un de l'autre.
    _isRefreshing = true;
    _hasMore = true; // un refresh rouvre la pagination fermée par une erreur
    // 1) Hydrate immédiatement depuis le cache local (instantané, offline-safe).
    try {
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      final localCalls = await cache.watchCalls().first;
      if (!mounted) return;
      if (localCalls.isNotEmpty) {
        await _hydrateKnownUsers(localCalls, cache);
        if (!mounted) return;
        setState(() {
          _mergeCalls(localCalls.map(_localToCall));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = true);
      }
    } catch (e, st) {
      AppLog.e('CallsScreen', 'Chargement appels (cache) échoué', e, st);
    }

    // 2) Rafraîchit la page la plus récente depuis l'API (best-effort).
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final raw = await apiClient.getCallHistory(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _mergeCalls(_parseCalls(raw));
        // Page pleine = il reste probablement de l'historique en dessous.
        _hasMore = raw.length >= _pageSize;
        _isLoading = false;
      });
      // Réutilise la réponse déjà téléchargée pour alimenter le cache local :
      // l'ancien `syncCalls` refaisait un GET /calls identique juste derrière.
      if (mounted && _myId != 0) {
        final cache = Provider.of<LocalCacheRepository>(context, listen: false);
        cache.ingestCallsRaw(raw, myId: _myId);
      }
    } catch (e) {
      // Hors ligne : on reste sur le cache et on referme la pagination, sinon
      // le pied de liste tournerait dans le vide. Le pull-to-refresh la rouvre.
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Page suivante : on repart du plus ancien appel déjà en main. Le curseur
  /// porte sur la liste complète (masqués compris) pour ne pas sauter de ligne.
  Future<void> _loadMoreCalls() async {
    if (!canLoadMorePage(
      isLoadingMore: _isLoadingMore,
      isLoading: _isLoading,
      isRefreshing: _isRefreshing,
      hasMore: _hasMore,
      hasCalls: _recentCalls.isNotEmpty,
    )) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final raw = await apiClient.getCallHistory(
        before: _recentCalls.last.idCall,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _mergeCalls(_parseCalls(raw));
        _hasMore = raw.length >= _pageSize;
        _isLoadingMore = false;
      });
      // L'historique profond descend aussi dans le cache : il restera lisible
      // hors ligne à la prochaine ouverture.
      if (mounted && _myId != 0) {
        final cache = Provider.of<LocalCacheRepository>(context, listen: false);
        cache.ingestCallsRaw(raw, myId: _myId);
      }
    } catch (e, st) {
      AppLog.e('CallsScreen', 'Page d\'appels suivante échouée', e, st);
      // Une page qui échoue arrête le défilement plutôt que de retenter à
      // chaque pixel scrollé ; le pull-to-refresh remet la pagination en route.
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  Future<void> _hydrateKnownUsers(
    Iterable<LocalCall> calls,
    LocalCacheRepository cache,
  ) async {
    for (final c in calls) {
      final id = c.idCaller != _myId ? c.idCaller : c.idReceiver;
      if (_knownUsers.containsKey(id)) continue;
      final u = await cache.getKnownUser(id);
      if (u != null) _knownUsers[id] = u;
    }
  }

  User _otherUserFromLocal(LocalCall c) {
    final id = c.idCaller != _myId ? c.idCaller : c.idReceiver;
    final known = _knownUsers[id];
    return User(
      alanyaID: id,
      nom: c.otherNom ?? '',
      pseudo: known?.pseudo ?? '',
      alanyaPhone: known?.alanyaPhone ?? '',
      email: known?.email ?? '',
      idPays: known?.idPays ?? 0,
      avatarUrl: c.otherAvatar ?? known?.avatarUrl ?? '',
      typeCompte: known?.typeCompte ?? 0,
      accountType: known?.accountType ?? 0,
      verificationStatus: known?.verificationStatus ?? 0,
      verifiedUntil: known?.verifiedUntil?.toIso8601String(),
      isOnline: known?.isOnline ?? false,
      lastSeen: known?.lastSeen?.toIso8601String() ?? '',
      paysLibelle: known?.paysLibelle,
    );
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
      caller: c.idCaller != _myId ? _otherUserFromLocal(c) : null,
      receiver: c.idReceiver != _myId ? _otherUserFromLocal(c) : null,
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
      targetUserName: otherUser.displayName,
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
        title: Text(context.l10n.navCalls, style: context.text.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _searchOpen ? context.l10n.closeSearch : context.l10n.commonSearch,
            onPressed: _toggleSearch,
          ),
          // Le répondeur se commande depuis l'onglet Appels, pas seulement
          // depuis les réglages : c'est un geste du quotidien (« je rentre en
          // réunion »), pas une configuration. L'icône se teinte quand un
          // créneau court, pour que l'état se voie sans ouvrir la feuille.
          Consumer<VoicemailProvider>(
            builder: (context, vm, _) => IconButton(
              icon: Icon(vm.isActive
                  ? Icons.voicemail_rounded
                  : Icons.voicemail_outlined),
              color: vm.isActive ? context.colors.primary : null,
              tooltip: context.l10n.voicemailScheduleTitle,
              onPressed: () => showVoicemailQuickSheet(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_call),
            tooltip: context.l10n.newCall,
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
            return (otherUser?.displayName ?? '').toLowerCase().contains(_search) ||
          (otherUser?.nom ?? '').toLowerCase().contains(_search);
          }).toList();
    if (filtered.isEmpty) {
      // Écran vide ne veut pas dire historique épuisé : masquer localement la
      // première page, ou y chercher un nom qui n'apparaît qu'à la suivante,
      // remplaçait la liste par un cul-de-sac — plus de défilement pour
      // appeler la page suivante, plus de tirer-pour-rafraîchir. On garde donc
      // la surface défilable, et on continue de dérouler l'historique tant
      // qu'il en reste : aucun geste ne pourrait révéler une correspondance
      // située trois pages plus loin.
      final keepsLoading = _hasMore && _recentCalls.isNotEmpty;
      if (keepsLoading && !_isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadMoreCalls();
        });
      }
      return RefreshIndicator(
        onRefresh: _loadRecentCalls,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.call_outlined,
                title:
                    _search.isEmpty ? context.l10n.noRecentCalls : context.l10n.noResults,
                message: _search.isEmpty
                    ? context.l10n.yourPastAndReceivedCallsWill
                    : context.l10n.tryAnotherName,
                action: keepsLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
    }
    final colors = context.colors;
    return RefreshIndicator(
      onRefresh: _loadRecentCalls,
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
        itemCount: filtered.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filtered.length) {
            // Atteindre ce pied de page déclenche déjà `_loadMoreCalls`.
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final call = filtered[index];
          // !! Calcul direct — pas de FutureBuilder
          // `idCaller != _myId` dit déjà que l'appel est entrant : le journal
          // affichait pourtant la flèche « sortant » pour tout appel non manqué.
          final isIncoming = call.idCaller != _myId;
          final otherUser = isIncoming ? call.caller : call.receiver;
          final isMissed = call.isMissed;
          final isVideo = call.isVideo;
          // Renvoyé au répondeur : c'est bien un appel non abouti, il compte
          // donc dans le badge d'appels manqués. Mais la LIGNE ne doit pas dire
          // « manqué » ni s'afficher en rouge — le téléphone n'a jamais sonné,
          // il n'y avait rien à manquer, et rien ne va mal. Sans cette
          // distinction, la fonctionnalité serait invisible à l'endroit précis
          // où elle devrait le plus se voir.
          final isVoicemail = callWentToVoicemail(call.status);
          final direction = callDirection(
            isMissed: isMissed,
            isIncoming: isIncoming,
          );
          final teinte = isVoicemail
              ? colors.primary
              : (isMissed ? colors.error : context.semantic.success);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            onLongPress: () => _showCallActions(call, otherUser?.displayName ?? context.l10n.unknownSender),
            leading: ProfileAvatar(
              imageUrl: otherUser?.avatarUrl,
              name: otherUser?.displayName ?? context.l10n.unknownSender,
              userId: otherUser?.alanyaID ?? 0,
              isGroup: false,
              size: AppSizes.avatarLg,
              borderRadius: AppSizes.avatarLg / 2,
            ),
            title: Text(
              otherUser?.displayName ?? context.l10n.unknownSender,
              style: context.text.titleMedium?.copyWith(
                color: isVoicemail
                    ? colors.onSurface
                    : (isMissed ? colors.error : colors.onSurface),
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(
                    isVoicemail
                        ? Icons.voicemail_rounded
                        : switch (direction) {
                            CallDirection.missed => Icons.call_missed,
                            CallDirection.incoming => Icons.call_received,
                            CallDirection.outgoing => Icons.call_made,
                          },
                    size: 16,
                    color: teinte,
                  ),
                  AppSpacing.hGapXs,
                  Flexible(
                    child: Text(
                      '${_formatDate(call.createdAt)} • ${isVoicemail ? context.l10n.voicemailCallStatus : (isVideo ? context.l10n.video2 : context.l10n.audio2)}'
                      '${call.hasDuration ? " • ${call.formattedDuration}" : ""}',
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
              title: Text(context.l10n.commonDelete, style: TextStyle(color: error)),
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
      final hm = '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return context.l10n.todayTimeShort(hm);
      }
      // L'année manquait, et l'heure n'avait pas son zéro de tête : un appel
      // de mars 2025 était indistinguable d'un appel de mars 2026, et
      // « 3/3 9:05 » ne s'alignait pas avec « 3/3 14:05 ». L'écran de détail
      // utilise déjà `dateAtTimeFull` — c'est la même donnée, elle mérite la
      // même forme.
      return context.l10n.dateAtTimeFull(date.day, date.month, date.year, hm);
    } catch (_) {
      return context.l10n.recently;
    }
  }
}