import 'package:flutter/material.dart';

/// Clé globale du [Navigator] racine (MaterialApp).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

NavigatorState? get appNavigator => appNavigatorKey.currentState;

/// Clé globale du [ScaffoldMessenger] racine — permet d'afficher des SnackBars
/// depuis les services (ex. appel occupé / sans réponse) sans contexte d'écran.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
