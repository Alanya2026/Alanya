import 'dart:async';
// import 'dart:io'; // requis pour HttpOverrides — réactiver avec le bloc certificate pinning

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/status_provider.dart';
import 'providers/admin_provider.dart';
import 'core/db/app_database.dart';
// import 'core/network/cert_pinning.dart'; // réactiver avec le bloc certificate pinning
import 'core/navigation/app_navigator.dart';
import 'core/utils/app_log.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/locale_controller.dart';
import 'core/services/media_download_preferences.dart';
import 'core/services/call_service.dart';
import 'core/services/callkit_service.dart';
import 'core/services/local_cache_repository.dart';
import 'core/services/local_hidden_store.dart';
import 'core/services/meeting_service.dart';
import 'core/services/realtime_sync_service.dart';
import 'core/services/voice_message_coordinator.dart';
import 'core/services/voice_playback_service.dart';
import 'core/services/push_service.dart';
import 'firebase_options.dart';
import 'screens/authentification/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'talky_api_client.dart';
import 'talky_models.dart';
import 'widgets/session/active_session_banner.dart';

/// Clé globale exposée à PushService pour naviguer depuis les notifications.
@Deprecated('Use appNavigatorKey from core/navigation/app_navigator.dart')
final GlobalKey<NavigatorState> navigatorKey = appNavigatorKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] ======== Application démarrée ========');

  // Photo Picker Android (grille + cases à cocher pour pickMultiImage / pickMultiVideo).
  // Sans ça, le plugin retombe sur l'ancien sélecteur fichiers (souvent identique
  // au picker une seule vidéo, multi via appui long — peu visible).
  final imagePickerImpl = ImagePickerPlatform.instance;
  if (imagePickerImpl is ImagePickerAndroid) {
    imagePickerImpl.useAndroidPhotoPicker = true;
    debugPrint('[Main] Android Photo Picker activé');
  }

  // Capture centralisée des erreurs non interceptées (UI + asynchrones).
  // Sans ça, une exception dans un build/callback partait dans le vide.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLog.e('FlutterError', details.exceptionAsString(),
        details.exception, details.stack);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLog.e('PlatformDispatcher', 'Erreur asynchrone non interceptée',
        error, stack);
    return true;
  };

  // Certificate pinning : le backend utilisait un certificat auto-signé. On ne
  // faisait confiance qu'à ce certificat précis (embarqué dans les assets), ce qui
  // règle le HandshakeException sans ouvrir la porte au MITM. Couvre http,
  // uploads, socket.io et cached_network_image via HttpOverrides.global.
  //
  // DÉSACTIVÉ : le serveur ne fait plus de HTTPS (HTTP simple sur 158.220.107.211),
  // donc plus de TLS à valider — réactiver ce bloc si le backend repasse en HTTPS.
  // try {
  //   HttpOverrides.global = await PinnedCertHttpOverrides.load();
  //   debugPrint('[Main] Certificate pinning activé');
  // } catch (e) {
  //   debugPrint('[Main] ** Échec activation cert pinning: $e');
  // }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await CallKitService.instance.init();
    debugPrint('[Main] Firebase + CallKit initialisés');
  } catch (e) {
    debugPrint('[Main] ** Init Firebase échouée — push désactivé: $e');
  }

  // Charger avant runApp : le prefetch socket/sync lit ce flag de façon sync.
  await MediaDownloadPreferences.preload();

  runApp(const TalkyApp());
}

class TalkyApp extends StatelessWidget {
  const TalkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = TalkyApiClient();
    final database = AppDatabase();
    final chatProvider = ChatProvider(api: apiClient, database: database);
    final localCache = LocalCacheRepository(db: database, api: apiClient);
    return MultiProvider(
      providers: [
        // ThemeController en tête : MaterialApp en dépend via Consumer.
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => LocaleController()..load()),
        ChangeNotifierProvider(
            create: (_) => MediaDownloadPreferences()..load()),
        Provider<TalkyApiClient>.value(value: apiClient),
        Provider<AppDatabase>.value(value: database),
        Provider<LocalCacheRepository>.value(value: localCache),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient: apiClient)),
        ChangeNotifierProvider(create: (_) => CallService(apiClient: apiClient)),
        ChangeNotifierProvider(create: (_) => MeetingService(apiClient: apiClient)),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider(
            create: (_) => StatusProvider(api: apiClient, cache: localCache)),
        ChangeNotifierProvider(create: (_) => AdminProvider(api: apiClient)),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider(api: apiClient)),
        ChangeNotifierProvider(create: (_) => LocalHiddenStore()..load()),
        ChangeNotifierProvider(create: (_) => VoicePlaybackService()),
        ChangeNotifierProvider(
          create: (ctx) => VoiceMessageCoordinator(
            repository: ctx.read<ChatProvider>().repository,
          ),
        ),
        Provider<RealtimeSyncService>(
          create: (ctx) => RealtimeSyncService(
            chat: ctx.read<ChatProvider>(),
            status: ctx.read<StatusProvider>(),
          ),
        ),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (_, tc, lc, __) => MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [appRouteObserver],
          scaffoldMessengerKey: appMessengerKey,
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (ctx) => AppLocalizations.of(ctx)?.appTitle ?? 'Alanya',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: tc.mode,
          locale: lc.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeResolutionCallback: (device, supported) {
            if (lc.preference != AppLocalePreference.system && lc.locale != null) {
              return lc.locale;
            }
            if (device != null) {
              for (final l in supported) {
                if (l.languageCode == device.languageCode) return l;
              }
            }
            return const Locale('fr');
          },
          builder: (context, child) => ActiveSessionChrome(child: child),
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  AuthProvider? _authProvider;
  int? _boundUserId;
  VoidCallback? _onBackOnline;
  ConnectivityProvider? _connectivityForListener;
  void Function(dynamic)? _onCallLogUpdated;
  Timer? _callSyncFallbackTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('[AuthWrapper] initState - Lancement de init()');
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _authProvider!.addListener(_onAuthChanged);
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _clearCallLogBindings();
    if (_onBackOnline != null && _connectivityForListener != null) {
      _connectivityForListener!.removeBackOnlineListener(_onBackOnline!);
    }
    super.dispose();
  }

  void _removeBackOnlineListener() {
    if (_onBackOnline != null && _connectivityForListener != null) {
      _connectivityForListener!.removeBackOnlineListener(_onBackOnline!);
      _onBackOnline = null;
      _connectivityForListener = null;
    }
  }

  void _removeCallLogListener() {
    if (_onCallLogUpdated == null) return;
    try {
      Provider.of<TalkyApiClient>(context, listen: false)
          .removeSocketListener(SocketEvents.callLogUpdated, _onCallLogUpdated!);
    } catch (e) {
      debugPrint('[AuthWrapper] removeCallLogListener échoué: $e');
    }
    _onCallLogUpdated = null;
  }

  void _cancelCallSyncFallback() {
    _callSyncFallbackTimer?.cancel();
    _callSyncFallbackTimer = null;
  }

  void _scheduleCallSyncFallback(LocalCacheRepository cache, int myId) {
    _cancelCallSyncFallback();
    _callSyncFallbackTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      unawaited(cache.syncCalls(myId: myId));
    });
  }

  void _bindCallLogListener(int myId) {
    _removeCallLogListener();
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);
    final callService = Provider.of<CallService>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    _onCallLogUpdated = (data) async {
      debugPrint('[AuthWrapper] call_log_updated → upsertCallFromPayload');
      await cache.upsertCallFromPayload(
        data,
        myId: myId,
        onMissingConversation: () => chatProvider.refreshConversations(),
      );
      if (!mounted) return;
      _scheduleCallSyncFallback(cache, myId);
    };
    apiClient.onSocketEvent(SocketEvents.callLogUpdated, _onCallLogUpdated!);
    callService.onCallTerminatedHook = () async {
      if (!mounted) return;
      _scheduleCallSyncFallback(cache, myId);
    };
  }

  void _clearCallLogBindings() {
    _removeCallLogListener();
    _cancelCallSyncFallback();
    try {
      Provider.of<CallService>(context, listen: false).onCallTerminatedHook = null;
    } catch (e) {
      debugPrint('[AuthWrapper] clearCallLogBindings échoué: $e');
    }
  }

  /// Bootstrap initial : restaure la session puis lie les providers et services
  /// au compte courant si l'utilisateur est déjà loggé.
  Future<void> _bootstrap() async {
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.init();
      debugPrint('[AuthWrapper] !! init() complété');
      await _syncSessionBindings();

      try {
        await PushService.init(apiClient, navKey: navigatorKey);
      } catch (e) {
        debugPrint('[AuthWrapper] PushService init failed: $e');
      }

      void dispatch(IncomingCallAction action) {
        if (!mounted) return;
        final callService = Provider.of<CallService>(context, listen: false);
        switch (action.action) {
          case IncomingCallActionType.accept:
            callService.acceptIncomingCallFromPush(
              callId:      action.callId,
              callerId:    action.callerId,
              callerName:  action.callerName,
              callerPhoto: action.callerPhoto,
              isVideo:     action.isVideo,
              roomId:      action.roomId,
            );
            break;
          case IncomingCallActionType.decline:
          case IncomingCallActionType.timeout:
          case IncomingCallActionType.ended:
            callService.rejectIncomingCallFromPush(
              callerId: action.callerId,
              callId: action.callId,
            );
            break;
        }
      }

      CallKitService.instance.actions.listen(dispatch);

      final pending = CallKitService.instance.consumePendingAction();
      if (pending != null) {
        debugPrint('[AuthWrapper]  Pending CallKit action trouvée: ${pending.action}');
        debugPrint('[AuthWrapper] Dispatcher l\'action...');
        dispatch(pending);
        debugPrint('[AuthWrapper] !! Action dispatchée');
      } else {
        debugPrint('[AuthWrapper] ℹ Aucune action pending au démarrage');
        // Repli cold start : l'événement CallKit est souvent perdu avant que Flutter
        // soit prêt. activeCalls() conserve isAccepted côté natif.
        final active = await CallKitService.instance.getActiveCall();
        if (active != null && mounted) {
          final callId = active['callId'] as String? ?? '';
          if (callId.startsWith('meeting_')) {
            debugPrint('[AuthWrapper] ℹ CallKit réunion ignoré au cold start: $callId');
          } else {
            final callService = Provider.of<CallService>(context, listen: false);
            final isAccepted = active['isAccepted'] == true;
            if (isAccepted) {
              debugPrint('[AuthWrapper]  Appel CallKit déjà accepté → auto-réponse');
              unawaited(callService.acceptIncomingCallFromPush(
                callId:      callId,
                callerId:    active['callerId'] as String,
                callerName:  active['callerName'] as String,
                callerPhoto: active['callerPhoto'] as String?,
                isVideo:     active['isVideo'] as bool,
                roomId:      active['roomId'] as String?,
              ));
            } else {
              debugPrint('[AuthWrapper]  Appel CallKit actif → écran d\'appel entrant');
              callService.prepareIncomingFromCallKit(
                callId:      callId,
                callerId:    active['callerId'] as String,
                callerName:  active['callerName'] as String,
                callerPhoto: active['callerPhoto'] as String?,
                isVideo:     active['isVideo'] as bool,
                roomId:      active['roomId'] as String?,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthWrapper] ** Erreur init: $e');
      debugPrint('[AuthWrapper] Stack: ${StackTrace.current}');
    }
  }

  /// Appelé sur chaque changement d'AuthProvider (login, logout, refresh user).
  /// Déclenche un bind/unbind des providers dépendants de l'identité.
  void _onAuthChanged() {
    unawaited(_syncSessionBindings());
  }

  /// Aligne l'état des providers (chat, status, admin) sur l'utilisateur
  /// actuellement loggé. Idempotent : ne re-bind pas si déjà bind pour cet ID.
  Future<void> _syncSessionBindings() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myId = authProvider.currentUser?.alanyaID;

    // Logout : on était bind, plus d'utilisateur → libère les listeners.
    if (myId == null) {
      if (_boundUserId != null) {
        debugPrint('[AuthWrapper] Logout détecté → unbind providers');
        _removeBackOnlineListener();
        _clearCallLogBindings();
        try {
          Provider.of<ChatProvider>(context, listen: false).unbind();
          Provider.of<ChatProvider>(context, listen: false).onSocketReadyHook = null;
        } catch (e) {
          debugPrint('[AuthWrapper] ChatProvider.unbind échoué: $e');
        }
        try {
          Provider.of<StatusProvider>(context, listen: false).unbind();
        } catch (e) {
          debugPrint('[AuthWrapper] StatusProvider.unbind échoué: $e');
        }
        await _clearLocalSession();
        _boundUserId = null;
      }
      return;
    }

    // Déjà bind sur le même utilisateur, rien à faire.
    if (myId == _boundUserId) return;

    // Changement d'utilisateur : on libère l'ancien bind avant le neuf.
    if (_boundUserId != null && _boundUserId != myId) {
      _clearCallLogBindings();
      try {
        Provider.of<ChatProvider>(context, listen: false).unbind();
        Provider.of<StatusProvider>(context, listen: false).unbind();
      } catch (e) {
        debugPrint('[AuthWrapper] unbind avant switch user: $e');
      }
      await _clearLocalSession();
      if (!mounted) return;
    }

    _boundUserId = myId;
    debugPrint('[AuthWrapper] Bind providers pour userID=$myId');

    unawaited(PushService.syncTokenWithBackend());

    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final syncService = Provider.of<RealtimeSyncService>(context, listen: false);

    try {
      await chatProvider.bind(myId);
      if (mounted) {
        final cache = Provider.of<LocalCacheRepository>(context, listen: false);
        cache.syncPreferredContacts();
        cache.syncCalls(myId: myId);
        cache.syncMeetings();
        cache.purgeExpiredStatuses();
        _bindCallLogListener(myId);
      }
    } catch (e) {
      debugPrint('[AuthWrapper] ChatProvider.bind échoué: $e');
    }

    try {
      await statusProvider.bind(myId);
    } catch (e) {
      debugPrint('[AuthWrapper] StatusProvider.bind échoué: $e');
    }

    chatProvider.onSocketReadyHook = syncService.refreshStatuses;

    if (mounted) {
      _removeBackOnlineListener();
      final connectivity =
          Provider.of<ConnectivityProvider>(context, listen: false);
      final cache =
          Provider.of<LocalCacheRepository>(context, listen: false);
      _connectivityForListener = connectivity;
      _onBackOnline = () {
        debugPrint('[AuthWrapper] Réseau revenu → catch-up + caches');
        if (!apiClient.isSocketConnected) {
          apiClient.connectSocket();
        }
        unawaited(syncService.catchUp());
        cache.syncPreferredContacts();
        cache.syncCalls(myId: myId);
        cache.syncMeetings();
      };
      connectivity.addBackOnlineListener(_onBackOnline!);
    }

    try {
      await adminProvider.loadStats();
    } catch (e) {
      debugPrint('[AuthWrapper] AdminProvider.loadStats échoué: $e');
    }
  }

  /// Efface toutes les données locales liées à la session utilisateur.
  Future<void> _clearLocalSession() async {
    if (!mounted) return;
    debugPrint('[AuthWrapper] Vidage cache local session');
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);
    final hidden = Provider.of<LocalHiddenStore>(context, listen: false);
    final status = Provider.of<StatusProvider>(context, listen: false);
    try {
      await chat.clearLocalSession();
    } catch (e) {
      debugPrint('[AuthWrapper] clearLocalSession chat échoué: $e');
    }
    try {
      await cache.clearSession();
    } catch (e) {
      debugPrint('[AuthWrapper] clearSession cache échoué: $e');
    }
    try {
      await hidden.clearAll();
    } catch (e) {
      debugPrint('[AuthWrapper] LocalHiddenStore.clearAll échoué: $e');
    }
    try {
      await status.clearSessionPreferences();
    } catch (e) {
      debugPrint('[AuthWrapper] clearSessionPreferences statuts échoué: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        debugPrint('[AuthWrapper] build - isInitialized=${auth.isInitialized}, isLoggedIn=${auth.isLoggedIn}');
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}