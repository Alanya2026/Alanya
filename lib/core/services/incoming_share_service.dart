import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../navigation/app_navigator.dart';
import '../utils/incoming_share_payload.dart';
import 'qr_deep_link_service.dart';
import '../../screens/chats/share_to_conversation_screen.dart';

/// Reçoit les partages entrants (Galerie, Fichiers, navigateur…) et ouvre
/// l'écran de sélection de conversation une fois l'utilisateur connecté.
class IncomingShareService {
  IncomingShareService._();
  static final IncomingShareService instance = IncomingShareService._();

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  IncomingSharePayload? _pending;
  bool _sessionReady = false;
  bool _screenOpen = false;

  Future<void> init() async {
    if (_subscription != null) return;

    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        _enqueue(initial);
      }
    } catch (e) {
      debugPrint('[IncomingShare] getInitialMedia échoué: $e');
    }

    _subscription =
        ReceiveSharingIntent.instance.getMediaStream().listen(
      _enqueue,
      onError: (Object e) {
        debugPrint('[IncomingShare] stream error: $e');
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// À appeler quand la session utilisateur est prête (login / bootstrap).
  void onSessionReady() {
    _sessionReady = true;
    _tryPresentPending();
  }

  /// À appeler au logout : garde le pending mais n'ouvre pas l'écran.
  void onSessionEnded() {
    _sessionReady = false;
    _screenOpen = false;
  }

  void _enqueue(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // `receive_sharing_intent` capte TOUT ACTION_VIEW, y compris l'ouverture
    // d'un lien d'identité `alanya://q/u/<jeton>` par le bouton « Ouvrir dans
    // Alanya ». Sans ce filtre, l'écran de transfert s'ouvrait par-dessus
    // l'ajout du contact, pré-rempli avec l'URL brute — alors que `app_links`
    // traitait déjà correctement le même lien.
    //
    // Le tri se fait sur le type et non sur le seul contenu : un lien Alanya
    // arrivé par ACTION_SEND (texte partagé depuis un navigateur pour être
    // transmis à quelqu'un) est un `text`, pas un `url`, et reste un partage
    // légitime qu'il ne faut pas avaler.
    final restants = files
        .where((f) => !(f.type == SharedMediaType.url && _estLienAlanya(f.path)))
        .toList();
    if (restants.isEmpty) {
      unawaited(ReceiveSharingIntent.instance.reset());
      return;
    }

    final payload = incomingSharePayloadFromSharedMedia(restants);
    if (payload.isEmpty) {
      unawaited(ReceiveSharingIntent.instance.reset());
      return;
    }
    _pending = payload;
    _tryPresentPending();
  }

  /// Vrai si le chemin reçu est un lien d'identité Alanya. La reconnaissance
  /// est déléguée à [QrDeepLinkService], seul juge de cette forme : dupliquer
  /// la règle ici ferait diverger les deux chemins au premier changement.
  static bool _estLienAlanya(String path) {
    final uri = Uri.tryParse(path.trim());
    if (uri == null) return false;
    return QrDeepLinkService.extractIdentityToken(uri) != null;
  }

  void _tryPresentPending() {
    if (!_sessionReady || _pending == null || _screenOpen) return;

    final nav = appNavigator;
    if (nav == null) {
      Future.delayed(const Duration(milliseconds: 400), _tryPresentPending);
      return;
    }

    final payload = _pending!;
    _pending = null;
    _screenOpen = true;

    unawaited(
      nav
          .push<bool>(
        MaterialPageRoute(
          builder: (_) => ShareToConversationScreen(payload: payload),
          fullscreenDialog: true,
        ),
      )
          .then((_) {
        _screenOpen = false;
        unawaited(ReceiveSharingIntent.instance.reset());
        if (_pending != null) _tryPresentPending();
      }),
    );
  }
}
