import 'package:flutter/material.dart';

/// Clé globale du [Navigator] racine (MaterialApp).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

NavigatorState? get appNavigator => appNavigatorKey.currentState;
