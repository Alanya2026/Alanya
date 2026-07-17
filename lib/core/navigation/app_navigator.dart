import 'package:flutter/material.dart';

/// Clé globale du [Navigator] racine (MaterialApp).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Observateur de routes global : permet aux écrans (ex. ChatDetail) de savoir
/// s'ils sont réellement visibles (au sommet de la pile) via [RouteAware],
/// pour ne marquer « lu » que le chat effectivement affiché.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

NavigatorState? get appNavigator => appNavigatorKey.currentState;

/// Clé globale du [ScaffoldMessenger] racine — permet d'afficher des SnackBars
/// depuis les services (ex. appel occupé / sans réponse) sans contexte d'écran.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
