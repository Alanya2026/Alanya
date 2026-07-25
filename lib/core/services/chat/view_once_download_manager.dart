import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../media_cache_service.dart';

/// État de téléchargement d'un média à vue unique, par message.
enum VoStatus { idle, downloading, ready, error }

@immutable
class VoState {
  final VoStatus status;

  /// Progression 0.0–1.0 pendant le téléchargement, ou `null` si indéterminée.
  final double? progress;

  /// Chemin du fichier temporaire une fois prêt (`ready`).
  final String? path;

  const VoState._(this.status, {this.progress, this.path});

  static const idle = VoState._(VoStatus.idle);
  static const error = VoState._(VoStatus.error);
  factory VoState.downloading(double? p) =>
      VoState._(VoStatus.downloading, progress: p);
  factory VoState.ready(String path) =>
      VoState._(VoStatus.ready, path: path);
}

/// Gère le pré-téléchargement des médias à vue unique **en mémoire** (jamais
/// persisté) : 1ᵉʳ tap = télécharge vers un fichier temporaire ; 2ᵉ tap =
/// ouverture instantanée depuis ce fichier. Un [ValueNotifier] par message
/// permet à la seule bulle concernée de se reconstruire à chaque avancée.
///
/// Invariant confidentialité : télécharger ne « consomme » pas le média (aucun
/// accusé « vu » — voir `markViewed`, appelé uniquement à la fermeture de la
/// visionneuse). Les fichiers téléchargés mais jamais ouverts sont supprimés
/// via [discardAll] en quittant la conversation.
class ViewOnceDownloadManager {
  ViewOnceDownloadManager._();
  static final ViewOnceDownloadManager instance = ViewOnceDownloadManager._();

  final MediaCacheService _cache = MediaCacheService();
  final Map<int, ValueNotifier<VoState>> _notifiers = {};
  final Set<int> _cancelled = {};

  /// Notifier de l'état pour [msgID] (créé à `idle` si absent).
  ValueNotifier<VoState> notifier(int msgID) =>
      _notifiers.putIfAbsent(msgID, () => ValueNotifier(VoState.idle));

  VoStatus statusOf(int msgID) =>
      _notifiers[msgID]?.value.status ?? VoStatus.idle;

  /// Lance (ou relance après erreur) le téléchargement du média.
  Future<void> download(int msgID, String url) async {
    final n = notifier(msgID);
    if (n.value.status == VoStatus.downloading ||
        n.value.status == VoStatus.ready) {
      return;
    }
    _cancelled.remove(msgID);
    n.value = VoState.downloading(null);

    final path = await _cache.downloadToTempWithProgress(
      url,
      onProgress: (p) {
        if (_cancelled.contains(msgID)) return;
        if (n.value.status == VoStatus.downloading) {
          n.value = VoState.downloading(p);
        }
      },
      isCancelled: () => _cancelled.contains(msgID),
    );

    if (_cancelled.contains(msgID)) {
      _cancelled.remove(msgID);
      n.value = VoState.idle;
      if (path != null) _deleteFile(path);
      return;
    }
    if (path == null) {
      n.value = VoState.error;
      return;
    }
    n.value = VoState.ready(path);
    // Léger retour haptique : le média est prêt, tu peux l'ouvrir.
    try {
      HapticFeedback.lightImpact();
    } catch (_) {/* non supporté — ignoré */}
  }

  /// Annule un téléchargement en cours (le flux s'arrête et le temp partiel
  /// est supprimé ; l'état repasse à `idle`).
  void cancel(int msgID) {
    final n = _notifiers[msgID];
    if (n != null && n.value.status == VoStatus.downloading) {
      _cancelled.add(msgID);
    }
  }

  /// Récupère le chemin du fichier prêt et **transfère sa propriété** à
  /// l'appelant (la visionneuse le supprimera à la fermeture) : l'entrée est
  /// retirée SANS supprimer le fichier. `null` si pas prêt.
  String? takePath(int msgID) {
    final n = _notifiers[msgID];
    if (n == null || n.value.status != VoStatus.ready) return null;
    final path = n.value.path;
    _notifiers.remove(msgID);
    return path;
  }

  /// Nettoyage en quittant la conversation : annule les téléchargements en
  /// cours et supprime les temp prêts mais jamais ouverts.
  void discardAll() {
    for (final entry in _notifiers.entries) {
      final st = entry.value.value;
      if (st.status == VoStatus.downloading) _cancelled.add(entry.key);
      if (st.status == VoStatus.ready && st.path != null) {
        _deleteFile(st.path!);
      }
    }
    _notifiers.clear();
  }

  void _deleteFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {/* déjà supprimé — ignoré */}
  }
}
