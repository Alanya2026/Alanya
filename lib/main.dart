import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'core/services/call_service.dart';
import 'core/services/callkit_service.dart';
import 'core/services/meeting_service.dart';
import 'core/services/push_service.dart';
import 'firebase_options.dart';
import 'screens/authentification/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'talky_api_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Main] 🚀 Application démarrée');

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await CallKitService.instance.init();
    debugPrint('[Main] Firebase + CallKit initialisés');
  } catch (e) {
    debugPrint('[Main] ⚠️ Init Firebase échouée — push désactivé: $e');
  }

  runApp(const TalkyApp());
}

class TalkyApp extends StatelessWidget {
  const TalkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiClient = TalkyApiClient();
    return MultiProvider(
      providers: [
        Provider<TalkyApiClient>.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient: apiClient)),
        //  CallService enregistré
        ChangeNotifierProvider(create: (_) => CallService(apiClient: apiClient)),
        //  MeetingService enregistré (manquait)
        ChangeNotifierProvider(create: (_) => MeetingService(apiClient: apiClient)),
      ],
      child: MaterialApp(
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
  @override
  void initState() {
    super.initState();
    debugPrint('[AuthWrapper] initState - Lancement de init()');
    Future.microtask(
      () async {
        try {
          final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
          await Provider.of<AuthProvider>(context, listen: false).init();
          debugPrint('[AuthWrapper] ✅ init() complété');

          // Démarre PushService une fois l'auth initialisée pour pouvoir
          // pousser le FCM token au backend si l'utilisateur est connecté.
          try {
            await PushService.init(apiClient);
          } catch (e) {
            debugPrint('[AuthWrapper] PushService init failed: $e');
          }

          // Relaie les actions CallKit (Accept/Decline depuis l'écran système)
          // vers CallService.
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

          // Cas app tuée → user tape "Accepter" → l'event est arrivé AVANT
          // que ce listener ne soit prêt. On consomme la dernière action
          // bufferisée par CallKitService.
          final pending = CallKitService.instance.consumePendingAction();
          if (pending != null) {
            debugPrint('[AuthWrapper] 🎯 Pending CallKit action trouvée: ${pending.action}');
            debugPrint('[AuthWrapper] Dispatcher l\'action...');
            dispatch(pending);
            debugPrint('[AuthWrapper] ✅ Action dispatchée');
          } else {
            debugPrint('[AuthWrapper] ℹ️ Aucune action pending au démarrage');
          }
        } catch (e) {
          debugPrint('[AuthWrapper] ❌ Erreur init: $e');
          debugPrint('[AuthWrapper] Stack: ${StackTrace.current}');
        }
      },
    );
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