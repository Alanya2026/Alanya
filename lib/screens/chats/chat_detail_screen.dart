import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../../core/db/app_database.dart';
import '../../core/call_limits.dart';
import '../../core/db/chat_dao.dart' show decodeParticipants;
import '../../core/navigation/app_navigator.dart';
import '../../core/services/call_service.dart';
import '../../core/services/message_share_service.dart';
import '../../core/services/chat/view_once_download_manager.dart';
import '../../core/services/chat_repository.dart';
import '../../core/services/voice_chat_context.dart';
import '../../core/services/voice_playback_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/document_file_style.dart';
import '../../core/utils/file_metadata.dart';
import '../../core/utils/forward_message.dart';
import '../../core/utils/media_album.dart';
import '../../core/utils/status_reply_payload.dart';
import '../../core/utils/media_viewer_items.dart';
import '../../core/utils/rich_text_parser.dart';
import '../../l10n/app_localizations.dart';
import 'package:screen_protector/screen_protector.dart';
import 'view_once_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'chat/link_preview_card.dart';
import '../../core/services/pdf_thumbnail_service.dart';
import '../../widgets/video_message_preview.dart';
import '../../widgets/image_message_preview.dart';
import '../../core/services/local_cache_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/chat/chat_wallpaper.dart';
import '../../widgets/chat/message_status_icon.dart';
import '../../widgets/chat/reaction_chips.dart';
import '../calls/group_participants_picker_screen.dart';
import 'contact_detail_screen.dart';
import 'group_detail_screen.dart';
import 'forward_message_screen.dart';
import 'album_media_list_screen.dart';
import 'media_send_screen.dart';
import 'media_viewer_screen.dart';
import 'camera_screen.dart';
import 'location_picker_screen.dart';
import 'voice_message_bubble.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/contact_payload.dart';
import '../../core/utils/location_payload.dart';
import '../../widgets/chat/contact_message_preview.dart';
import '../../widgets/chat/location_message_preview.dart';
import '../../widgets/chat/reply_quote_bar.dart';
import '../../widgets/chat/styled_preview_text.dart';
import '../../widgets/chat/status_reply_quote.dart';
import '../../widgets/chat/share_preferred_contact_sheet.dart';

// Écran réparti par responsabilité (même librairie / membres privés partagés) :
part 'chat/chat_actions.dart';  // handlers : envoi, médias, vocal, appels
part 'chat/chat_bubbles.dart';  // rendu des bulles & médias
part 'chat/chat_input.dart';    // barre de saisie, emoji, bandeau réponse

// Limite alignée sur multer (50 Mo) côté backend.
const int _maxMediaBytes = 50 * 1024 * 1024;
const Duration _messageEditWindow = Duration(minutes: 30);
const int _maxSelectionCount = 50;

class ChatDetailScreen extends StatefulWidget {
  final String userName;
  final int? conversationId;
  final int? userId;
  final bool isGroup;
  final String? avatarUrl;
  const ChatDetailScreen({
    super.key,
    required this.userName,
    this.conversationId,
    this.userId,
    this.isGroup = false,
    this.avatarUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with RouteAware, WidgetsBindingObserver {
  /// Vrai quand ce chat est réellement visible (au sommet de la pile) ET l'app
  /// au premier plan. Sert à ne marquer « lu » que le chat effectivement lu.
  bool _chatVisible = false;
  ModalRoute<dynamic>? _observedRoute;
  final TextEditingController _messageController = RichTextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final TalkyApiClient _apiClient;
  late final ChatProvider _chat;
  int? _convId;
  Future<int?>? _ensureConversationInFlight;
  int? _myId;
  bool _hasText = false;
  bool _showEmoji = false;
  bool _showFormatBar = false;
  bool _pendingViewOnce = false;
  bool _voiceViewOnce = false;
  int _pinnedIndex = 0;
  LocalMessage? _replyTo;
  final FocusNode _inputFocus = FocusNode();
  Timer? _typingTimer;

  bool _loadingOlder = false;
  bool _historySyncInFlight = false;
  /// True si la conv a un aperçu serveur (lastMessageAt) → le fil ne devrait pas rester vide.
  bool _expectMessages = false;
  bool _atBottom = true;
  bool _suppressAutoScroll = false;
  int? _highlightMsgId;
  int? _pendingScrollMsgId;
  Timer? _highlightTimer;
  final Map<int, GlobalKey> _messageKeys = {};

  final ImagePicker _picker = ImagePicker();

  // ── Messages vocaux ────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  bool _isBlocked = false;
  bool _blockedByThem = false;

  bool _selectionMode = false;
  final Set<int> _selectedMsgIDs = {};
  /// msgID en cours de téléchargement manuel (overlay WhatsApp).
  final Set<int> _mediaDownloadingIds = {};
  /// albumId en cours de téléchargement groupé depuis la bulle.
  final Set<String> _downloadingAlbumIds = {};
  /// Chemins résolus avant que le flux Drift ne rafraîchisse l'UI.
  final Map<int, String> _localMediaPathOverrides = {};
  List<LocalMessage> _currentMessages = const [];
  /// Réactions de la conversation active, regroupées par `msgID` — alimenté
  /// par l'abonnement dédié et lu par la barre de réaction rapide
  /// (`chat_actions.dart`) et les bulles (`chat_bubbles.dart`).
  Map<int, List<LocalMessageReaction>> _currentReactionsByMsg = const {};
  StreamSubscription<List<LocalMessageReaction>>? _reactionsSub;

  Map<int, List<LocalMessageReaction>> _groupReactionsByMsg(
    List<LocalMessageReaction> reactions,
  ) {
    final byMsg = <int, List<LocalMessageReaction>>{};
    for (final r in reactions) {
      (byMsg[r.msgID] ??= []).add(r);
    }
    return byMsg;
  }

  /// Mise à jour immédiate de l'UI avant l'écriture Drift (ressenti instantané).
  /// [emoji] null ou vide = retrait de ma réaction sur [msgID].
  void _applyOptimisticReaction(int msgID, String? emoji) {
    final myId = _myId;
    final convId = _convId;
    if (myId == null || convId == null || msgID == 0) return;

    final updated = Map<int, List<LocalMessageReaction>>.from(_currentReactionsByMsg);
    final list = List<LocalMessageReaction>.from(updated[msgID] ?? const []);
    list.removeWhere((r) => r.userID == myId);
    if (emoji != null && emoji.isNotEmpty) {
      list.add(
        LocalMessageReaction(
          msgID: msgID,
          userID: myId,
          conversationID: convId,
          emoji: emoji,
          reactedAt: DateTime.now(),
        ),
      );
    }
    if (list.isEmpty) {
      updated.remove(msgID);
    } else {
      updated[msgID] = list;
    }
    setState(() => _currentReactionsByMsg = updated);
  }

  /// Pont public vers `setState()` (lui-même `@protected`), afin que les
  /// extensions de cette librairie puissent déclencher un rebuild.
  void rebuild(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    _chat = Provider.of<ChatProvider>(context, listen: false);
    _myId = Provider.of<AuthProvider>(context, listen: false).currentUser?.alanyaID;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _observedRoute) {
      if (_observedRoute is PageRoute) {
        appRouteObserver.unsubscribe(this);
      }
      _observedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  // ── Visibilité réelle du chat (route au sommet + app au premier plan) ──
  @override
  void didPush() => _setChatVisible(true); // ouvert et affiché
  @override
  void didPopNext() => _setChatVisible(true); // revenu (sous-écran fermé)
  @override
  void didPushNext() => _setChatVisible(false); // recouvert par un autre écran
  @override
  void didPop() => _setChatVisible(false); // quitté

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ne réactive que si ce chat est bien la route courante.
      if (_observedRoute?.isCurrent ?? false) _setChatVisible(true);
    } else {
      _setChatVisible(false);
    }
  }

  /// Applique l'état visible/masqué : « conversation active » = ce chat est lu
  /// en direct uniquement quand il est réellement à l'écran.
  void _setChatVisible(bool visible) {
    if (_chatVisible == visible) return;
    _chatVisible = visible;
    final convId = _convId;
    if (convId == null) return;
    if (visible) {
      _chat.repository.setActiveConversation(convId);
      unawaited(_chat.repository.markAsRead(convId));
    } else {
      _chat.repository.clearActiveConversation(convId);
    }
  }

  void _onScroll() {
    final pos = _scrollController.position;
    // reverse: true → offset 0 = bas (messages récents).
    final atBottom = pos.pixels <= 150;
    if (atBottom != _atBottom && mounted) {
      setState(() => _atBottom = atBottom);
    } else {
      _atBottom = atBottom;
    }

    // Près du haut visuel → charger une page d'anciens messages.
    if (pos.pixels >= pos.maxScrollExtent - 80 && !_loadingOlder) {
      final convId = _convId;
      if (convId == null) return;
      _loadingOlder = true;
      _chat.repository.loadOlderMessages(convId).whenComplete(() {
        if (mounted) _loadingOlder = false;
      });
    }
  }

  Future<void> _init() async {
    _convId = widget.conversationId;

    if (!widget.isGroup && widget.userId != null) {
      await _loadBlockStatus();
    }

    // Ouverture via userId seul (contacts préférés, nouvelle discussion…) :
    // rattacher la conversation 1-1 existante avant d'afficher, sinon l'UI
    // reste sur « Aucun message » sans jamais charger l'historique.
    if (_convId == null && !widget.isGroup && widget.userId != null) {
      final existing = await _findLocalDirectConversation(widget.userId!);
      if (existing != null) {
        if (!mounted) return;
        setState(() => _convId = existing);
      } else {
        // Pas en cache local : l'API renvoie la conversation existante
        // (idempotent) ou en crée une nouvelle.
        await _ensureConversation();
        return;
      }
    }

    final convId = _convId;
    if (convId != null) {
      await _attachToConversation(convId);
    }
  }

  Future<int?> _findLocalDirectConversation(int peerUserId) async {
    final myId = _myId;
    if (myId == null) return null;
    final convs = await _chat.repository.dao.getAllConversations();
    return findLocalDirectConversationId(convs, myId, peerUserId);
  }

  Future<void> _attachToConversation(int convId) async {
    // 1) Marque ce chat visible → conversation active + lecture immédiate.
    //    (didPush a pu se déclencher avant la résolution async du convId ;
    //    on force donc l'état visible ici une fois le convId connu.)
    _chatVisible = true;
    _chat.repository.setActiveConversation(convId);

    final voice = context.read<VoicePlaybackService>();
    voice
      ..setChatContext(VoiceChatContext(
        conversationId: convId,
        title: widget.userName,
        userId: widget.userId,
        isGroup: widget.isGroup,
        avatarUrl: widget.avatarUrl,
      ))
      ..enterChat(convId);

    // 2) Badge à 0 immédiat (await = local seulement ; HTTP/socket en fond).
    await _chat.repository.markAsRead(convId);

    // 3) Room temps réel : messages poussés pendant l'écran = actifs / lus.
    _apiClient.sendSocketEvent(SocketEvents.joinConversation, {'conversationID': convId});

    // 4) Sync historique + vocaux (ne bloque pas le badge, mais l'UI attend
    // tant qu'un aperçu serveur existe et que le fil est encore vide).
    final convMeta =
        await _chat.repository.dao.watchConversation(convId).first;
    if (!mounted || _convId != convId) return;
    final expectMessages = convMeta?.lastMessageAt != null;
    setState(() {
      _expectMessages = expectMessages;
      _historySyncInFlight = expectMessages;
    });
    unawaited(_syncConversationHistory(convId));

    // 5) Réactions : abonnement dédié plutôt qu'un StreamBuilder imbriqué —
    //    une réaction qui arrive une frame plus tard que les messages n'a pas
    //    besoin de geler l'affichage de la conversation.
    _bindReactionsStream(convId);
  }

  void _bindReactionsStream(int convId) {
    _reactionsSub?.cancel();
    _reactionsSub = _chat.repository.watchReactions(convId).listen((reactions) {
      if (!mounted) return;
      setState(() => _currentReactionsByMsg = _groupReactionsByMsg(reactions));
    });
  }

  Future<void> _syncConversationHistory(int convId) async {
    try {
      var activeConvId = convId;
      for (var attempt = 0; attempt < 2; attempt++) {
        await _chat.repository.syncMessages(activeConvId);
        await _chat.repository.syncReactions(activeConvId);
        if (!mounted || _convId != activeConvId) return;
        var stillEmpty = (await _chat.repository.dao
                .watchMessages(activeConvId, _myId ?? 0)
                .first)
            .isEmpty;
        if (!stillEmpty) break;

        // Doublon 1-1 : aperçu sur conv vide, messages sur une autre conv.
        if (stillEmpty &&
            !widget.isGroup &&
            widget.userId != null &&
            _myId != null &&
            attempt >= 0) {
          final resolved = await _chat.repository.resolveDirectConversationWithHistory(
            myId: _myId!,
            peerUserId: widget.userId!,
            currentConvId: activeConvId,
          );
          if (resolved != null && resolved != activeConvId) {
            activeConvId = resolved;
            if (mounted) setState(() => _convId = resolved);
            _chat.repository.setActiveConversation(resolved);
            _bindReactionsStream(resolved);
            _apiClient.sendSocketEvent(
              SocketEvents.joinConversation,
              {'conversationID': resolved},
            );
            continue;
          }
        }

        if (!_expectMessages) break;
        if (attempt < 1) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
      if (!mounted) return;
      final finalConvId = _convId;
      if (finalConvId == null) return;
      await _chat.repository.reconcileVoiceLocalPaths(finalConvId);
      // Appels : l'aperçu « Appel vocal » n'est pas dans la table message.
      if (!widget.isGroup && _myId != null && mounted) {
        unawaited(
          context.read<LocalCacheRepository>().syncCalls(myId: _myId!),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _historySyncInFlight = false);
      }
    }
  }

  Future<int?> _ensureConversation() async {
    if (_convId != null) return _convId;
    if (widget.isGroup || widget.userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.unableToOpenTheConversation)),
        );
      }
      return null;
    }

    _ensureConversationInFlight ??= _createConversation();
    try {
      return await _ensureConversationInFlight!;
    } finally {
      _ensureConversationInFlight = null;
    }
  }

  Future<int?> _createConversation() async {
    try {
      final result =
          await _apiClient.createConversation(participantID: widget.userId!);
      final conversationId = result['conversID'] as int?;
      if (conversationId == null || !mounted) return null;

      setState(() => _convId = conversationId);
      await _chat.refreshConversations(force: true);
      if (!mounted) return conversationId;
      await _attachToConversation(conversationId);
      return conversationId;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorCreatingTheConversation),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _loadBlockStatus() async {
    final userId = widget.userId;
    if (userId == null) return;
    try {
      final status = await _apiClient.getBlockStatus(userId);
      if (!mounted) return;
      setState(() {
        _isBlocked = status.isBlocked;
        _blockedByThem = status.blockedByThem;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _unblockContact() async {
    final userId = widget.userId;
    if (userId == null) return;
    try {
      await _apiClient.unblockUser(userId);
      if (!mounted) return;
      setState(() {
        _isBlocked = false;
        _blockedByThem = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contactUnblocked)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cannotUnblockWithError('$e'))),
      );
    }
  }

  bool get _callsDisabled =>
      !widget.isGroup && (_isBlocked || _blockedByThem);

  bool get _inputBlocked => !widget.isGroup && _isBlocked;

  GlobalKey _keyForMessage(int msgID) =>
      _messageKeys.putIfAbsent(msgID, GlobalKey.new);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_observedRoute is PageRoute) appRouteObserver.unsubscribe(this);
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _highlightTimer?.cancel();
    _reactionsSub?.cancel();
    _recorder.dispose();
    context.read<VoicePlaybackService>().leaveChat();
    final convId = _convId;
    if (convId != null) _chat.repository.clearActiveConversation(convId);
    _stopTyping();
    // Supprime les médias vue-unique pré-téléchargés mais jamais ouverts
    // (aucune trace persistante).
    ViewOnceDownloadManager.instance.discardAll();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild sur changement de présence / typing (header + bulle).
    final chat = Provider.of<ChatProvider>(context);
    final convId = _convId;
    final partnerTyping = convId != null &&
        chat.isPartnerTyping(
          convId,
          partnerUserId: widget.isGroup ? null : widget.userId,
        );
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: _selectionMode ? _buildSelectionAppBar() : _buildChatAppBar(partnerTyping),
      body: Stack(
        children: [
          const Positioned.fill(child: ChatWallpaper()),
          Column(
            children: [
              const OfflineBanner(wrapSafeArea: false),
              _buildPinnedBanner(),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: convId == null
                          ? (widget.userId != null && !widget.isGroup
                              ? EmptyState(
                                  icon: Icons.waving_hand_outlined,
                                  title: context.l10n.noMessages,
                                  message:
                                      context.l10n.sayHelloToStartTheConversation,
                                )
                              : EmptyState(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: context.l10n.conversationNotFound,
                                ))
                          : StreamBuilder<List<LocalMessage>>(
                              stream: _chat.watchMessages(convId),
                              builder: (context, snapshot) {
                                final messages = snapshot.data ?? const [];
                                _currentMessages = messages;
                                if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                                  return const LoadingState();
                                }
                                // Journal d'appels : discussions 1-1 uniquement.
                                final callsStream = (!widget.isGroup && widget.userId != null)
                                    ? context.read<LocalCacheRepository>().watchCalls()
                                    : Stream<List<LocalCall>>.value(const []);
                                return StreamBuilder<List<LocalCall>>(
                                  stream: callsStream,
                                  builder: (context, callSnap) {
                                    final calls = (callSnap.data ?? const <LocalCall>[])
                                        .where((c) =>
                                            (c.idCaller == _myId && c.idReceiver == widget.userId) ||
                                            (c.idCaller == widget.userId && c.idReceiver == _myId))
                                        .toList();

                                    if (messages.isEmpty && calls.isEmpty && !partnerTyping) {
                                      if (_historySyncInFlight ||
                                          (_expectMessages &&
                                              snapshot.connectionState !=
                                                  ConnectionState.active)) {
                                        return const LoadingState();
                                      }
                                      return EmptyState(
                                        icon: Icons.waving_hand_outlined,
                                        title: context.l10n.noMessages,
                                        message: context.l10n.sayHelloToStartTheConversation,
                                      );
                                    }
                                    // Auto-scroll si déjà en bas (nouveau message, frappe…).
                                    if (!_suppressAutoScroll && _atBottom) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _scrollToBottom();
                                      });
                                    }
                                    // Fil unifié : messages/albums + appels, triés par date.
                                    final feed = <Object>[
                                      ...groupMessagesForDisplay(messages),
                                      ...calls,
                                    ]..sort((a, b) => _feedTime(a).compareTo(_feedTime(b)));
                                    // reverse: true → index 0 en bas ; on inverse pour afficher
                                    // les récents près de la zone de saisie.
                                    final reversedFeed = feed.reversed.toList();

                                    return SlidableAutoCloseBehavior(
                                      child: ListView.builder(
                                        controller: _scrollController,
                                        reverse: true,
                                        padding: const EdgeInsets.all(AppSpacing.lg),
                                        itemCount: reversedFeed.length + 1,
                                        itemBuilder: (context, index) {
                                          if (index == 0) {
                                            return TypingBubbleSlot(visible: partnerTyping);
                                          }
                                          final feedIndex = index - 1;
                                          final item = reversedFeed[feedIndex];
                                          final itemTime = _feedTime(item);
                                          final olderTime = feedIndex < reversedFeed.length - 1
                                              ? _feedTime(reversedFeed[feedIndex + 1])
                                              : null;
                                          final showDate = olderTime == null ||
                                              !_sameDay(olderTime.toLocal(), itemTime.toLocal());

                                          // Entrée d'appel (journal type WhatsApp).
                                          if (item is LocalCall) {
                                            return Column(
                                              children: [
                                                if (showDate) _buildDateSeparator(itemTime.toLocal()),
                                                _buildCallBubble(item),
                                              ],
                                            );
                                          }

                                          final chatItem = item as ChatListItem;
                                          final msg = switch (chatItem) {
                                            ChatListSingle(:final message) => message,
                                            ChatListAlbum(:final messages) => messages.last,
                                          };
                                          if (msg.msgID == _pendingScrollMsgId) {
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _tryRevealMessage(msg.msgID);
                                            });
                                          }
                                          return Column(
                                            key: msg.msgID != 0 ? _keyForMessage(msg.msgID) : null,
                                            children: [
                                              if (showDate) _buildDateSeparator(itemTime.toLocal()),
                                              switch (chatItem) {
                                                ChatListSingle(:final message) =>
                                                  _buildMessageBubble(
                                                    message,
                                                    message.senderID == _myId,
                                                    reactions: _currentReactionsByMsg[message.msgID] ?? const [],
                                                  ),
                                                ChatListAlbum(:final messages) =>
                                                  _buildAlbumBubble(messages, messages.first.senderID == _myId),
                                              },
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                    // Retour rapide en bas du fil (évite de re-scroller tout l'historique).
                    if (convId != null && !_selectionMode && !_atBottom)
                      Positioned(
                        right: AppSpacing.lg,
                        bottom: AppSpacing.md,
                        child: _buildScrollToBottomButton(),
                      ),
                  ],
                ),
              ),
              if (!_selectionMode && _replyTo != null) _buildReplyBanner(),
              if (!_selectionMode && _inputBlocked) _buildBlockedBanner(),
              if (!_selectionMode && _showFormatBar && !_inputBlocked) _buildFormatBar(),
              if (!_selectionMode) _buildInputBar(),
              if (!_selectionMode && _showEmoji) _buildEmojiPicker(),
            ],
          ),
        ],
      ),
      ),
    );
  }


  PreferredSizeWidget _buildChatAppBar(bool partnerTyping) {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: InkWell(
        onTap: widget.isGroup
            ? (_convId != null
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(
                          conversationId: _convId!,
                          groupName: widget.userName,
                          groupAvatar: widget.avatarUrl,
                        ),
                      ),
                    )
                : null)
            : (widget.userId != null
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContactDetailScreen(
                          userId: widget.userId!,
                          conversationId: _convId,
                          initialName: widget.userName,
                          initialAvatar: widget.avatarUrl ?? '',
                        ),
                      ),
                    );
                    if (mounted) _loadBlockStatus();
                  }
                : null),
        child: Row(
          children: [
            ProfileAvatar(
              imageUrl: widget.avatarUrl,
              name: widget.userName,
              userId: widget.userId ?? 0,
              isGroup: widget.isGroup,
              conversationId: _convId,
              hidePhoto: !widget.isGroup && _blockedByThem,
              size: 40,
              borderRadius: 20,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: context.text.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Builder(builder: (_) {
                    if (widget.isGroup) {
                      if (partnerTyping) {
                        return Text(
                          context.l10n.typing2,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.primary,
                          ),
                        );
                      }
                      return _buildGroupMembersLine();
                    }
                    final label =
                        partnerTyping ? context.l10n.typing : _presenceLabel();
                    if (label.isEmpty) return const SizedBox.shrink();
                    final online = !partnerTyping && label == context.l10n.online;
                    return Text(
                      label,
                      style: context.text.bodySmall?.copyWith(
                        color: partnerTyping
                            ? context.colors.primary
                            : (online
                                ? context.semantic.online
                                : context.colors.onSurfaceVariant),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_callsDisabled && !widget.isGroup) ...[
          IconButton(
            icon: const Icon(Icons.videocam_rounded),
            color: context.colors.primary,
            onPressed: () => _initiateCall(isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded),
            color: context.colors.primary,
            onPressed: () => _initiateCall(isVideo: false),
          ),
          AppSpacing.hGapSm,
        ],
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final count = _selectedMsgIDs.length;
    final selected = _resolveSelectedMessages();
    final single = selected.length == 1 ? selected.first : null;
    final canForward =
        selected.isNotEmpty && selected.every(canForwardMessage);
    final canShare = canForward;
    final canDelete = selected.isNotEmpty;
    final canReply = single != null;
    final canPin = single != null && single.msgID != 0 && !single.isDeleted;
    final canInfo = single != null && single.msgID != 0;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text(context.l10n.selectedCount(count)),
      actions: [
        if (canReply)
          IconButton(
            icon: const Icon(Icons.reply),
            tooltip: context.l10n.reply,
            onPressed: _replyToSelected,
          ),
        if (canForward)
          IconButton(
            icon: const Icon(Icons.forward),
            tooltip: context.l10n.forward,
            onPressed: _forwardSelected,
          ),
        if (canShare)
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: context.l10n.share,
            onPressed: _shareSelected,
          ),
        if (canPin)
          IconButton(
            icon: Icon(
              single.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            tooltip: single.isPinned ? context.l10n.unpin2 : context.l10n.pin,
            onPressed: _togglePinSelected,
          ),
        if (canInfo)
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: context.l10n.infoAction,
            onPressed: _showInfoSelected,
          ),
        if (canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.l10n.commonDelete,
            onPressed: _showDeleteSelectedMenu,
          ),
      ],
    );
  }
}

/// Bouton circulaire indigo en relief (50 px) — utilisé pour mic / send.
class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.primary,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, color: context.colors.onPrimary, size: AppIconSize.sm + 2),
        ),
      ),
    );
  }
}

/// Pastille rouge qui pulse pendant l'enregistrement.
class _RecordingDot extends StatefulWidget {
  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
      ),
    );
  }
}
