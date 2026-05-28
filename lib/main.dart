import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/status_provider.dart';
import 'providers/admin_provider.dart';
import 'core/db/app_database.dart';
import 'core/services/call_service.dart'; 
import 'core/services/callkit_service.dart';
import 'core/services/local_cache_repository.dart';
import 'core/services/meeting_service.dart';
import 'core/services/push_service.dart';
import 'firebase_options.dart';
import 'screens/authentification/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'talky_api_client.dart';

/// Clé globale exposée à PushService pour naviguer depuis les notifications.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] ======== Application démarrée ========');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await CallKitService.instance.init();
    debugPrint('[Main] Firebase + CallKit initialisés');
  } catch (e) {
    debugPrint('[Main] ** Init Firebase échouée — push désactivé: $e');
  }

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
        Provider<TalkyApiClient>.value(value: apiClient),
        Provider<AppDatabase>.value(value: database),
        Provider<LocalCacheRepository>.value(value: localCache),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient: apiClient)),
        //  CallService enregistré
        ChangeNotifierProvider(create: (_) => CallService(apiClient: apiClient)),
        //  MeetingService enregistré (manquait)
        ChangeNotifierProvider(create: (_) => MeetingService(apiClient: apiClient)),
        //  ChatProvider : chats offline-first (drift) + présence temps réel
        ChangeNotifierProvider.value(value: chatProvider),
        //  StatusProvider : statuts/stories avec persistence offline
        ChangeNotifierProvider(
            create: (_) => StatusProvider(api: apiClient, cache: localCache)),
        //  AdminProvider : dashboard admin avec pagination
        ChangeNotifierProvider(create: (_) => AdminProvider(api: apiClient)),
        //  ConnectivityProvider : état réseau OS pour l'UI offline + triggers
        ChangeNotifierProvider(create: (_) => ConnectivityProvider(api: apiClient)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Talky',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
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
    super.dispose();
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
        try {
          Provider.of<ChatProvider>(context, listen: false).unbind();
        } catch (e) {
          debugPrint('[AuthWrapper] ChatProvider.unbind échoué: $e');
        }
        try {
          Provider.of<StatusProvider>(context, listen: false).unbind();
        } catch (e) {
          debugPrint('[AuthWrapper] StatusProvider.unbind échoué: $e');
        }
        _boundUserId = null;
      }
      return;
    }

    // Déjà bind sur le même utilisateur, rien à faire.
    if (myId == _boundUserId) return;

    // Changement d'utilisateur : on libère l'ancien bind avant le neuf.
    if (_boundUserId != null && _boundUserId != myId) {
      try {
        Provider.of<ChatProvider>(context, listen: false).unbind();
        Provider.of<StatusProvider>(context, listen: false).unbind();
      } catch (e) {
        debugPrint('[AuthWrapper] unbind avant switch user: $e');
      }
    }

    _boundUserId = myId;
    debugPrint('[AuthWrapper] Bind providers pour userID=$myId');

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    try {
      await chatProvider.bind(myId);
      if (mounted) {
        final cache = Provider.of<LocalCacheRepository>(context, listen: false);
        cache.syncPreferredContacts();
        cache.syncCalls(myId: myId);
        cache.syncMeetings();
        cache.purgeExpiredStatuses();
      }
      if (mounted) {
        final connectivity =
            Provider.of<ConnectivityProvider>(context, listen: false);
        final cache =
            Provider.of<LocalCacheRepository>(context, listen: false);
        connectivity.addBackOnlineListener(() {
          debugPrint('[AuthWrapper] Réseau revenu → refresh caches secondaires');
          cache.syncPreferredContacts();
          cache.syncCalls(myId: myId);
          cache.syncMeetings();
        });
      }
    } catch (e) {
      debugPrint('[AuthWrapper] ChatProvider.bind échoué: $e');
    }

    try {
      await statusProvider.bind(myId);
    } catch (e) {
      debugPrint('[AuthWrapper] StatusProvider.bind échoué: $e');
    }

    try {
      await adminProvider.loadStats();
    } catch (e) {
      debugPrint('[AuthWrapper] AdminProvider.loadStats échoué: $e');
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