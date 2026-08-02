import 'dart:async';
// import 'dart:io'; // requis pour HttpOverrides — réactiver avec le bloc certificate pinning

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
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
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/locale_controller.dart';
import 'core/services/chat/message_sound_service.dart';
import 'core/services/incoming_share_service.dart';
import 'core/services/media_download_preferences.dart';
import 'core/services/playback_speed_preferences.dart';
import 'core/services/ringtone_preferences.dart';
import 'core/services/call_service.dart';
import 'core/services/callkit_service.dart';
import 'core/services/call/ended_call_registry.dart';
import 'core/services/local_cache_repository.dart';
import 'core/services/local_hidden_store.dart';
import 'core/services/meeting_service.dart';
import 'core/services/presence_service.dart';
import 'core/services/qr_contact_flow.dart';
import 'core/services/qr_deep_link_service.dart';
import 'models/qr_models.dart';
import 'core/services/realtime_sync_service.dart';
import 'core/services/voice_message_coordinator.dart';
import 'core/services/voice_playback_service.dart';
import 'core/services/push_service.dart';
import 'core/services/session_end_reason.dart';
import 'core/services/notifications/notification_prefs_cache.dart';
import 'core/services/notifications/badge_sync_service.dart';
import 'core/services/notifications/pending_delivery_ack_store.dart';
import 'core/services/notifications/pending_notification_action_store.dart';
import 'core/services/privacy_prefs_service.dart';
import 'core/services/app_settings_sync_service.dart';
import 'core/services/biometric_lock_service.dart';
import 'core/services/storage_info_service.dart';
import 'firebase_options.dart';
import 'screens/onboarding/account_setup_flow.dart';
import 'screens/authentification/login_screen.dart';
import 'core/services/onboarding_service.dart';
import 'talky_api_client.dart';
import 'talky_models.dart';
import 'widgets/session/biometric_lock_overlay.dart';
import 'widgets/session/active_session_banner.dart';

/// Clé globale exposée à PushService pour naviguer depuis les notifications.
@Deprecated('Use appNavigatorKey from core/navigation/app_navigator.dart')
final GlobalKey<NavigatorState> navigatorKey = appNavigatorKey;

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Garde le splash natif jusqu'à la restauration locale (pas de spinner Flutter).
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
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
    FlutterError.dumpErrorToConsole(details, forceReport: true);
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
  // DÉSACTIVÉ : réactiver avec PinnedCertHttpOverrides si besoin de pinning.
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

  // Charger avant runApp : la première lecture applique la vitesse mémorisée
  // sans attendre, sinon le premier vocal repart à 1×.
  await PlaybackSpeedPreferences.preload();

  // Charger avant runApp : CallService/RingtoneService/CallKitService lisent
  // la sonnerie sélectionnée de façon synchrone dès le premier appel entrant.
  await RingtonePreferences.preload();

  await AppSettingsSyncService.preloadLocal();

  final biometricLock = BiometricLockService();
  await biometricLock.ensureLoaded();

  await IncomingShareService.instance.init();

  // Précharge les sons de messagerie (envoi/réception). Non bloquant : assets
  // embarqués, aucune dépendance réseau.
  unawaited(MessageSoundService.instance.init());

  runApp(TalkyApp(biometricLock: biometricLock));
}

class TalkyApp extends StatefulWidget {
  const TalkyApp({super.key, this.biometricLock});

  final BiometricLockService? biometricLock;

  @override
  State<TalkyApp> createState() => _TalkyAppState();
}

class _TalkyAppState extends State<TalkyApp> {
  late final TalkyApiClient _apiClient = TalkyApiClient();
  late final AppDatabase _database = AppDatabase();
  late final ChatProvider _chatProvider =
      ChatProvider(api: _apiClient, database: _database);
  late final LocalCacheRepository _localCache =
      LocalCacheRepository(db: _database, api: _apiClient);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ThemeController en tête : MaterialApp en dépend via Consumer.
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => LocaleController()..load()),
        ChangeNotifierProvider(
            create: (_) => MediaDownloadPreferences()..load()),
        Provider<TalkyApiClient>.value(value: _apiClient),
        Provider<AppDatabase>.value(value: _database),
        Provider<LocalCacheRepository>.value(value: _localCache),
        ChangeNotifierProvider(
            create: (_) => RingtonePreferences()..load()),
        ChangeNotifierProvider(
            create: (_) => AuthProvider(apiClient: _apiClient)),
        ChangeNotifierProvider(
          create: (ctx) => PrivacyPrefsService(api: ctx.read<TalkyApiClient>())
            ..loadFromCache(),
        ),
        ChangeNotifierProvider(
          create: (_) => widget.biometricLock ?? (BiometricLockService()..load()),
        ),
        ChangeNotifierProvider(create: (_) => StorageInfoService()),
        ChangeNotifierProvider(
          create: (ctx) => AppSettingsSyncService(api: ctx.read<TalkyApiClient>()),
        ),
        // Déclaré avant CallService, qui s'y abonne dans son `create`.
        ChangeNotifierProvider(create: (_) => VoicePlaybackService()),
        ChangeNotifierProvider(create: (ctx) {
          final call = CallService(apiClient: _apiClient);
          final voice = ctx.read<VoicePlaybackService>();
          // Un appel — sonnerie comprise — ne doit pas se superposer à la
          // lecture en cours. `isCallActive` ignore le statut `incoming`,
          // d'où le test sur idle/ended plutôt que sur ce getter.
          var wasBusy = false;
          call.addListener(() {
            final busy = call.status != CallStatus.idle &&
                call.status != CallStatus.ended;
            if (busy && !wasBusy && voice.isPlaying) voice.pause();
            wasBusy = busy;
          });
          return call;
        }),
        ChangeNotifierProvider(
            create: (_) => MeetingService(apiClient: _apiClient)),
        ChangeNotifierProvider.value(value: _chatProvider),
        ChangeNotifierProvider(
            create: (_) =>
                StatusProvider(api: _apiClient, cache: _localCache)),
        ChangeNotifierProvider(create: (_) => AdminProvider(api: _apiClient)),
        ChangeNotifierProvider(
            create: (_) => ConnectivityProvider(api: _apiClient)),
        ChangeNotifierProvider(create: (_) => LocalHiddenStore()..load()),
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
        // Présence : « en ligne » ⇔ app au premier plan, ou appel/réunion en
        // cours. Déclaré après CallService et MeetingService, dont il dépend.
        Provider<PresenceService>(
          create: (ctx) {
            final call = ctx.read<CallService>();
            final meeting = ctx.read<MeetingService>();
            final presence = PresenceService(
              sendPresence: _apiClient.sendPresence,
              registerResolver: _apiClient.setPresenceOnlineCallback,
              isSessionActive: () =>
                  (call.status != CallStatus.idle &&
                      call.status != CallStatus.ended) ||
                  meeting.currentMeeting != null,
            );
            presence.bindSessionSource(call);
            presence.bindSessionSource(meeting);
            return presence;
          },
          dispose: (_, presence) => presence.dispose(),
        ),
      ],
      child: Consumer3<ThemeController, LocaleController, AppSettingsSyncService>(
        builder: (_, tc, lc, __, ___) => MaterialApp(
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
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return ActiveSessionChrome(
              child: MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(
                    AppSettingsSyncService.fontScale,
                  ),
                  disableAnimations: AppSettingsSyncService.reduceMotion,
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
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

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  AuthProvider? _authProvider;
  int? _boundUserId;
  /// Sérialise logout → login : évite qu'un re-login rapide (même compte)
  /// soit ignoré pendant que le vidage local est encore en cours.
  Future<void> _sessionBindingsChain = Future.value();
  VoidCallback? _onBackOnline;
  ConnectivityProvider? _connectivityForListener;
  void Function(dynamic)? _onCallLogUpdated;
  Timer? _callSyncFallbackTimer;

  /// Révocation de CET appareil depuis un autre appareil du compte. L'abonnement
  /// vit ici et non dans un écran : l'événement peut tomber à tout moment, et un
  /// abonné visible seulement sur l'écran « Appareils connectés » le laisserait
  /// filer (flux broadcast, sans mémoire tampon) — l'app resterait alors sur
  /// l'écran d'accueil avec une session morte.
  StreamSubscription<void>? _deviceRevokedSub;

  /// Liens `…/q/u/<jeton>` ouverts depuis la page web d'un code QR partagé.
  /// L'abonnement vit ici pour capter aussi bien le lien qui a démarré l'app
  /// que ceux reçus pendant qu'elle tourne.
  StreamSubscription<({String kind, String token})>? _qrLinkSub;

  /// Quelqu'un vient d'utiliser mon code QR : invitation à l'ajouter en
  /// retour. L'abonnement vit ici et non sur l'écran « Mon code » — le code a
  /// pu être partagé par lien, son propriétaire peut être n'importe où dans
  /// l'app quand le scan survient.
  StreamSubscription<QrContactScan>? _qrScanSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[AuthWrapper] initState - Lancement de init()');
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _authProvider!.addListener(_onAuthChanged);
    _deviceRevokedSub = Provider.of<TalkyApiClient>(context, listen: false)
        .thisDeviceRevoked
        .listen((_) => unawaited(_authProvider?.handleRemoteRevocation() ?? Future.value()));
    _qrLinkSub = QrDeepLinkService.instance.identityTokens
        .listen((lien) => unawaited(_handleQrIdentityLink(lien)));
    _qrScanSub = Provider.of<TalkyApiClient>(context, listen: false)
        .qrContactScans
        .listen((scan) => unawaited(_onQrContactScanned(scan)));
    unawaited(QrDeepLinkService.instance.start());
    Future.microtask(_bootstrap);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider?.removeListener(_onAuthChanged);
    _deviceRevokedSub?.cancel();
    _qrLinkSub?.cancel();
    _qrScanSub?.cancel();
    _clearCallLogBindings();
    if (_onBackOnline != null && _connectivityForListener != null) {
      _connectivityForListener!.removeBackOnlineListener(_onBackOnline!);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final auth = _authProvider;
    if (auth == null) return;
    unawaited(() async {
      await auth.refreshSessionOnResume();
      if (!mounted || !auth.isLoggedIn) return;
      await _ensureSocketReadyOnResume();
    }());
  }

  Future<void> _ensureSocketReadyOnResume() async {
    if (!mounted) return;
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context, listen: false);

    // Pending outbox : ne pas faire confiance à isSocketReady (zombie TCP).
    final hasPending = await chat.repository.hasSyncPending();
    if (!mounted) return;
    if (hasPending) {
      debugPrint('[AuthWrapper] Resume pending outbox → forceReconnect + flush');
      final ready = await apiClient.forceReconnect();
      if (!mounted) return;
      await chat.repository.flushOutbox();
      debugPrint('[AuthWrapper] Resume reconnect ready=$ready');
      return;
    }

    if (apiClient.isSocketReady) return;
    final ready = await apiClient.ensureSocketReady();
    debugPrint('[AuthWrapper] Resume socket ready=$ready');
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
        onMissingConversation: () => chatProvider.refreshConversations(force: true),
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

  /// Bootstrap initial : restaure le cache local, retire le splash, puis lie
  /// les providers. La validation réseau de session continue en arrière-plan.
  Future<void> _bootstrap() async {
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      try {
        await authProvider.init();
        debugPrint('[AuthWrapper] !! init() local complété');
      } finally {
        // Toujours retirer le splash : sinon écran figé si init échoue.
        FlutterNativeSplash.remove();
      }
      await _syncSessionBindings();

      // Actions CallKit dispatchées AVANT PushService.init : un accept depuis
      // la notification (app tuée) doit atteindre CallService dès que la
      // session locale est restaurée. PushService.init fait du réseau
      // (getToken FCM) et d'éventuels dialogues de permission — l'attendre
      // ici retardait l'écran d'appel de plusieurs secondes après le tap
      // « Accepter » (spinner → home → appel).
      void dispatch(IncomingCallAction action) {
        if (!mounted) return;
        final callService = Provider.of<CallService>(context, listen: false);
        unawaited(callService.handleCallKitAction(action));
      }

      CallKitService.instance.setIncomingCallPreviewListener(dispatch);
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
        if (!mounted) return;
        if (active == null) {
          // Rien de plausible : retirer d'éventuels débris (entrées trop
          // vieilles) sans déclencher de reject natif (purge programmatique).
          unawaited(CallKitService.instance.purgeStaleActiveCalls());
        }
        if (active != null) {
          final callId = active['callId'] as String? ?? '';
          if (callId.startsWith('meeting_')) {
            debugPrint('[AuthWrapper] ℹ CallKit réunion ignoré au cold start: $callId');
          } else if (callId.isNotEmpty && await EndedCallRegistry.isEnded(callId)) {
            debugPrint('[AuthWrapper] 🛡 CallKit terminé ignoré au cold start: $callId');
            await CallKitService.instance.endAll(callId: callId);
          } else if (!mounted) {
            return;
          } else if (active['isOutgoing'] == true) {
            final callService = Provider.of<CallService>(context, listen: false);
            if (callService.matchesActiveOutgoingSession(callId)) {
              debugPrint(
                '[AuthWrapper] Appel sortant local actif — conservation CallKit: $callId',
              );
            } else if (await callService.restoreOutgoingFromColdStart(active)) {
              debugPrint(
                '[AuthWrapper] Appel sortant restauré depuis snapshot: $callId',
              );
            } else {
              debugPrint(
                '[AuthWrapper] 🛡 CallKit sortant résiduel → nettoyage: $callId',
              );
              if (callId.isNotEmpty) await EndedCallRegistry.markEnded(callId);
              await CallKitService.instance.endAll(callId: callId);
            }
          } else if (mounted) {
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

      if (!mounted) return;
      // Refus CallKit persistés (app tuée) : rejouer dès que possible.
      if (authProvider.isLoggedIn) {
        final callService = Provider.of<CallService>(context, listen: false);
        unawaited(callService.flushPendingRejects());
        // Actions de notification en attente (réponse rapide, marquer lu) :
        // rejouées ici aussi, pour le cas où le socket ne monte jamais
        // (`auth:verified` n'arrive pas) alors que l'HTTP passe.
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        unawaited(chatProvider.repository.flushPendingNotificationActions());
      }

      try {
        await PushService.init(apiClient, navKey: navigatorKey);
        onCallEndedNotification = ({callId, callerId}) async {
          if (!mounted) return;
          await Provider.of<CallService>(context, listen: false)
              .notifyCallEndedFromExternal(
            callId: callId,
            callerId: callerId,
          );
        };
      } catch (e) {
        debugPrint('[AuthWrapper] PushService init failed: $e');
      }
    } catch (e) {
      debugPrint('[AuthWrapper] ** Erreur init: $e');
      debugPrint('[AuthWrapper] Stack: ${StackTrace.current}');
    }
  }

  /// Appelé sur chaque changement d'AuthProvider (login, logout, refresh user).
  /// Déclenche un bind/unbind des providers dépendants de l'identité.
  void _onAuthChanged() {
    _sessionBindingsChain = _sessionBindingsChain.then((_) async {
      if (!mounted) return;
      await _syncSessionBindings();
    }).catchError((Object e, StackTrace st) {
      debugPrint('[AuthWrapper] _syncSessionBindings échoué: $e');
    });
  }

  /// Aligne l'état des providers (chat, status, admin) sur l'utilisateur
  /// actuellement loggé. Idempotent : ne re-bind pas si déjà bind pour cet ID.
  /// Quelqu'un vient d'utiliser mon code QR. Déjà en contact chez moi :
  /// simple information. Sinon : dialogue oui/non pour l'ajouter en retour —
  /// la rencontre physique doit pouvoir créer le lien dans les deux sens en
  /// deux gestes.
  Future<void> _onQrContactScanned(QrContactScan scan) async {
    debugPrint('[AuthWrapper] scan reçu de ${scan.displayName} '
        '(id=${scan.alanyaID}, mutual=${scan.alreadyMutual}, mounted=$mounted)');
    if (!mounted || scan.alanyaID == 0) return;
    final l10n = context.l10n;
    final messenger = appMessengerKey.currentState;

    if (scan.alreadyMutual) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.qrScannedMutualInfo(scan.displayName)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // La note de contexte vaut dans les deux sens : celui qui ajoute en
    // retour vient de vivre la même rencontre que celui qui a scanné.
    final noteCtrl = TextEditingController();
    final accepter = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.qrScanReturnTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.qrScanReturnBody(scan.displayName)),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLength: 200,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: l10n.qrNoteFieldHint,
                  counterText: '',
                  isDense: true,
                  prefixIcon:
                      const Icon(Icons.sticky_note_2_outlined, size: 20),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.qrScanReturnDecline),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.qrScanReturnAccept),
          ),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (accepter != true || !mounted) return;

    // Capturées ici, sous la garde mounted : le catch s'exécute après des
    // await et ne doit plus toucher au context.
    final api = Provider.of<TalkyApiClient>(context, listen: false);
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);

    try {
      // `viaQr` : les deux directions du lien portent la même origine — la
      // pastille et le filtre « Par QR » valent pour l'ajout en retour aussi.
      final body = await api.addContact(scan.alanyaID, viaQr: true);
      await cache.upsertKnownUser(
        User.fromJson(body),
        preferred: true,
        partial: true,
      );
      if (note.isNotEmpty) {
        await QrContactFlow.saveNote(
          apiClient: api,
          cache: cache,
          user: User.fromJson(body),
          note: note,
        );
      }
      await cache.getPreferredContactsOnce();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.qrScanAddSuccess(scan.displayName)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    } on TalkyException catch (e) {
      // 409 : déjà ajouté entre-temps (double scan, autre appareil) — ce n'est
      // pas un échec du point de vue de l'utilisateur, et sa note reste
      // pertinente : on la pose sur la relation existante.
      final deja = e.statusCode == 409;
      if (deja && note.isNotEmpty) {
        unawaited(QrContactFlow.saveNote(
          apiClient: api,
          cache: cache,
          user: User(
            alanyaID: scan.alanyaID,
            nom: scan.nom,
            pseudo: scan.pseudo,
            alanyaPhone: '',
            email: '',
            idPays: 0,
            avatarUrl: scan.avatarUrl ?? '',
            typeCompte: 0,
            isOnline: false,
            lastSeen: '',
          ),
          note: note,
        ));
      }
      messenger?.showSnackBar(
        SnackBar(
          content: Text(deja
              ? l10n.qrScanAlreadyContact(scan.displayName)
              : l10n.qrScanReturnFailed),
          behavior: SnackBarBehavior.floating,
          backgroundColor: deja ? null : AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, st) {
      AppLog.e('AuthWrapper', 'Ajout en retour échoué', e, st);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.qrScanReturnFailed),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Ajoute le contact désigné par un lien d'identité. Un lien reçu hors
  /// session n'est pas perdu : il reste en attente et sera rejoué par
  /// [_replayPendingQrLink] une fois la connexion faite.
  Future<void> _handleQrIdentityLink(({String kind, String token}) lien) async {
    if (!mounted) return;
    final auth = _authProvider;
    if (auth == null || !auth.isLoggedIn) {
      QrDeepLinkService.instance.stashToken(lien);
      return;
    }
    await QrContactFlow.handleToken(
      kind: lien.kind,
      token: lien.token,
      messenger: ScaffoldMessenger.of(context),
      apiClient: Provider.of<TalkyApiClient>(context, listen: false),
      cache: Provider.of<LocalCacheRepository>(context, listen: false),
      l10n: context.l10n,
    );
  }

  /// Rejoue un lien d'identité reçu avant l'ouverture de session.
  Future<void> _replayPendingQrLink() async {
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);

    final token = QrDeepLinkService.instance.consumePendingToken();
    if (token != null) await _handleQrIdentityLink(token);

    // Même logique pour un scan arrivé par notification quand personne
    // n'écoutait encore (app lancée par le tap) : l'invitation d'ajout en
    // retour ne doit pas se perdre entre le tap et le premier abonné.
    final scan = apiClient.consumePendingQrContactScan();
    if (scan != null && mounted) await _onQrContactScanned(scan);
  }

  Future<void> _syncSessionBindings() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myId = authProvider.currentUser?.alanyaID;

    // Logout : on était bind, plus d'utilisateur → libère les listeners.
    if (myId == null) {
      if (_boundUserId != null) {
        final endReason = currentSessionEndReason;
        currentSessionEndReason = SessionEndReason.none;
        debugPrint(
          '[AuthWrapper] Logout détecté (reason=$endReason) → unbind providers',
        );
        IncomingShareService.instance.onSessionEnded();
        _removeBackOnlineListener();
        _clearCallLogBindings();
        try {
          Provider.of<PresenceService>(context, listen: false).detach();
        } catch (e) {
          debugPrint('[AuthWrapper] PresenceService.detach échoué: $e');
        }
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
        // Révocation à distance : c'est bien une décision de l'utilisateur,
        // le cache local part avec, comme pour un logout explicite.
        if (endReason == SessionEndReason.explicitLogout ||
            endReason == SessionEndReason.revokedRemotely) {
          await _clearLocalSession();
        }
        _boundUserId = null;
      }
      return;
    }

    // Déjà bind sur le même utilisateur, rien à faire — sauf si le chat a été
    // débindé entre-temps (logout/re-login rapide pendant le vidage local).
    if (myId == _boundUserId) {
      final chatBound = Provider.of<ChatProvider>(context, listen: false)
          .repository
          .myId;
      if (chatBound != 0) return;
      debugPrint(
        '[AuthWrapper] myId=$_boundUserId mais chat débindé → re-bind',
      );
    }

    // Changement d'utilisateur : on libère l'ancien bind avant le neuf.
    if (_boundUserId != null && _boundUserId != myId) {
      _clearCallLogBindings();
      try {
        Provider.of<ChatProvider>(context, listen: false).unbind();
        Provider.of<StatusProvider>(context, listen: false).unbind();
        // Repart d'un état de présence vierge pour le nouveau compte.
        Provider.of<PresenceService>(context, listen: false).detach();
      } catch (e) {
        debugPrint('[AuthWrapper] unbind avant switch user: $e');
      }
      await _clearLocalSession();
      if (!mounted) return;
    }

    _boundUserId = myId;
    debugPrint('[AuthWrapper] Bind providers pour userID=$myId');

    // Lien d'identité reçu avant l'ouverture de session (app démarrée par le
    // lien, ou utilisateur qui devait d'abord se connecter) : c'est maintenant
    // qu'on peut l'honorer.
    unawaited(_replayPendingQrLink());

    if (!mounted) return;
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final statusProvider = Provider.of<StatusProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final syncService = Provider.of<RealtimeSyncService>(context, listen: false);
    final presence = Provider.of<PresenceService>(context, listen: false);

    unawaited(PushService.syncTokenWithBackend());
    unawaited(_loadNotificationPrefs(apiClient));
    unawaited(_syncAccountSettings(apiClient));

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

    // Connecter le socket seulement après les listeners chat/status :
    // sinon `message:received` / `auth:verified` peuvent être perdus.
    apiClient.setPendingMessagesCallback(
      () => chatProvider.repository.hasSyncPending(),
    );
    // Avant connectSocket : le résolveur doit être en place quand le premier
    // `auth:verified` arrive, sinon la session s'annoncerait en ligne par
    // défaut même app en arrière-plan.
    presence.attach();
    apiClient.connectSocket();

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
        unawaited(apiClient.ensureSocketReady());
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

    IncomingShareService.instance.onSessionReady();
  }

  /// Efface toutes les données locales liées à la session utilisateur.
  Future<void> _clearLocalSession() async {
    if (!mounted) return;
    debugPrint('[AuthWrapper] Vidage cache local session');
    final chat = Provider.of<ChatProvider>(context, listen: false);
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);
    final hidden = Provider.of<LocalHiddenStore>(context, listen: false);
    final status = Provider.of<StatusProvider>(context, listen: false);
    final privacy = Provider.of<PrivacyPrefsService>(context, listen: false);
    final biometric = Provider.of<BiometricLockService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.alanyaID;
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
    // Files déposées par la couche native : les actions et accusés d'un compte
    // ne doivent jamais être rejoués avec le token d'un autre.
    try {
      await PendingNotificationActionStore.clear();
      await PendingDeliveryAckStore.clear();
    } catch (e) {
      debugPrint('[AuthWrapper] purge files natives échouée: $e');
    }
    try {
      await status.clearSessionPreferences();
    } catch (e) {
      debugPrint('[AuthWrapper] clearSessionPreferences statuts échoué: $e');
    }
    try {
      await BadgeSyncService.clear();
      await NotificationPrefsCache.clear();
      await privacy.clear();
      await biometric.clear();
      if (userId != null) {
        await OnboardingService().clear(userId);
      }
      await PushService.onSessionEnded();
    } catch (e) {
      debugPrint('[AuthWrapper] clear notification session échoué: $e');
    }
  }

  Future<void> _syncAccountSettings(TalkyApiClient api) async {
    if (!mounted) return;
    try {
      final theme = Provider.of<ThemeController>(context, listen: false);
      final locale = Provider.of<LocaleController>(context, listen: false);
      final sync = Provider.of<AppSettingsSyncService>(context, listen: false);
      final privacy =
          Provider.of<PrivacyPrefsService>(context, listen: false);
      await sync.syncFromServer(theme: theme, locale: locale);
      await privacy.syncFromServer();
    } catch (e) {
      debugPrint('[AuthWrapper] syncAccountSettings échoué: $e');
    }
  }

  Future<void> _loadNotificationPrefs(TalkyApiClient api) async {
    try {
      await NotificationPrefsCache.load();
      final prefs = await api.getNotificationPrefs();
      await NotificationPrefsCache.applyFromServer(prefs);
    } catch (e) {
      debugPrint('[AuthWrapper] loadNotificationPrefs échoué: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        debugPrint('[AuthWrapper] build - isInitialized=${auth.isInitialized}, isLoggedIn=${auth.isLoggedIn}');
        if (!auth.isInitialized) {
          // Couverture blanche le temps du cache local ; le splash natif
          // reste affiché grâce à FlutterNativeSplash.preserve (pas de spinner).
          return const Scaffold(
            backgroundColor: Color(0xFFFFFFFF),
            body: SizedBox.shrink(),
          );
        }
        return BiometricLockOverlay(
          sessionActive: auth.isLoggedIn,
          child: auth.isLoggedIn
              ? PostAuthGate(key: ValueKey(auth.currentUser?.alanyaID ?? 0))
              : const LoginScreen(),
        );
      },
    );
  }
}