import 'dart:async';

import 'package:flutter/widgets.dart';

/// Émet la présence vers le serveur (`presence:online` / `presence:offline`).
typedef PresenceSink = void Function({required bool online});

/// Installe (ou retire, avec `null`) le résolveur consulté à chaque
/// `auth:verified` pour savoir quelle présence déclarer.
typedef PresenceResolverSink = void Function(bool Function()? resolver);

/// Décide si l'utilisateur doit apparaître « en ligne » et le signale au
/// serveur.
///
/// Règle : en ligne ⇔ l'application est réellement au premier plan, ou une
/// session temps réel (appel, réunion) est en cours. Garder la socket ouverte
/// en arrière-plan reste nécessaire pour recevoir messages et appels, mais ne
/// vaut plus « en ligne » — c'était le comportement d'avant, où l'on restait
/// affiché en ligne tant que l'OS n'avait pas tué la socket.
class PresenceService with WidgetsBindingObserver {
  /// Un aller-retour rapide hors de l'app (sélecteur de fichiers, dialogue de
  /// permission, volet de notifications) ne doit pas faire clignoter la
  /// présence chez les correspondants.
  static const Duration defaultOfflineDebounce = Duration(milliseconds: 1500);

  PresenceService({
    required PresenceSink sendPresence,
    required PresenceResolverSink registerResolver,
    required bool Function() isSessionActive,
    Duration offlineDebounce = defaultOfflineDebounce,
  })  : _sendPresence = sendPresence,
        _registerResolver = registerResolver,
        _isSessionActive = isSessionActive,
        _offlineDebounce = offlineDebounce;

  final PresenceSink _sendPresence;
  final PresenceResolverSink _registerResolver;
  final bool Function() _isSessionActive;
  final Duration _offlineDebounce;

  final List<Listenable> _sessionSources = [];

  bool _foreground = true;
  bool _attached = false;

  /// Dernier état effectivement annoncé au serveur. `null` tant que rien n'a
  /// été annoncé.
  bool? _declared;
  Timer? _offlineTimer;

  bool get shouldBeOnline => _foreground || _isSessionActive();

  @visibleForTesting
  bool? get declared => _declared;

  @visibleForTesting
  bool get hasPendingOfflineTransition => _offlineTimer != null;

  /// À appeler une fois la session ouverte.
  void attach() {
    if (_attached) return;
    _attached = true;
    _foreground = _resolveInitialForeground();
    WidgetsBinding.instance.addObserver(this);
    _registerResolver(_resolvePresenceForHandshake);
  }

  /// À appeler à la fermeture de session (logout, changement de compte). Ne
  /// signale pas « hors ligne » : la déconnexion du socket s'en charge côté
  /// serveur. Les sources de session restent suivies pour qu'un [attach]
  /// ultérieur reparte sans reconfiguration.
  void detach() {
    if (!_attached) return;
    _attached = false;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    _declared = null;
    WidgetsBinding.instance.removeObserver(this);
    _registerResolver(null);
  }

  /// Libère définitivement le service (fin de vie du provider).
  void dispose() {
    detach();
    for (final source in _sessionSources) {
      source.removeListener(_onSessionChanged);
    }
    _sessionSources.clear();
  }

  /// Suit un `ChangeNotifier` (CallService, MeetingService) pour réévaluer la
  /// présence quand une session se termine alors que l'app est déjà en
  /// arrière-plan.
  void bindSessionSource(Listenable source) {
    if (_sessionSources.contains(source)) return;
    _sessionSources.add(source);
    source.addListener(_onSessionChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setForeground(true);
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _setForeground(false);
      case AppLifecycleState.inactive:
        // Transition iOS, volet de notifications, changeur d'apps : l'app est
        // toujours à l'écran. Même choix que la suppression des push dans
        // HomeScreen.
        break;
    }
  }

  @visibleForTesting
  void handleLifecycleState(AppLifecycleState state) =>
      didChangeAppLifecycleState(state);

  void _setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _evaluate();
  }

  void _onSessionChanged() => _evaluate();

  void _evaluate() {
    if (!_attached) return;
    final target = shouldBeOnline;
    if (target == _declared) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      return;
    }
    if (target) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      _emit(true);
      return;
    }
    // Passage hors ligne : différé, et annulé si l'app revient entre-temps.
    _offlineTimer ??= Timer(_offlineDebounce, () {
      _offlineTimer = null;
      if (shouldBeOnline) return;
      _emit(false);
    });
  }

  void _emit(bool online) {
    _declared = online;
    _sendPresence(online: online);
  }

  /// Consulté par la couche socket juste après `auth:verified` : la présence
  /// est (ré)annoncée à chaque reconnexion, ce qui resynchronise le serveur
  /// après une coupure réseau.
  bool _resolvePresenceForHandshake() {
    _offlineTimer?.cancel();
    _offlineTimer = null;
    final online = shouldBeOnline;
    _declared = online;
    return online;
  }

  bool _resolveInitialForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }
}
