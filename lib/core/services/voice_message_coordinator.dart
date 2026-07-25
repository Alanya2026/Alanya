import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'chat_repository.dart';
import 'voice_asset_resolver.dart';
import 'voice_waveform_store.dart';
import '../theme/locale_controller.dart';
import '../utils/audio_message_kind.dart';

enum VoiceUiPhase {
  resolving,
  needsDownload,
  downloading,
  ready,
  error,
}

class VoiceMessageRef {
  final String clientId;
  final int serverMsgId;
  final bool isMe;
  final String? dbPath;
  final String? pendingPath;
  final String? mediaUrl;
  final int durationSeconds;

  /// Vocal ou musique : conditionne l'extraction de waveform et le plafond
  /// de téléchargement.
  final AudioMessageKind kind;

  const VoiceMessageRef({
    required this.clientId,
    required this.serverMsgId,
    required this.isMe,
    this.dbPath,
    this.pendingPath,
    this.mediaUrl,
    required this.durationSeconds,
    this.kind = AudioMessageKind.voiceNote,
  });

  @override
  bool operator ==(Object other) {
    return other is VoiceMessageRef &&
        other.clientId == clientId &&
        other.serverMsgId == serverMsgId &&
        other.isMe == isMe &&
        other.dbPath == dbPath &&
        other.pendingPath == pendingPath &&
        other.mediaUrl == mediaUrl &&
        other.durationSeconds == durationSeconds &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(
        clientId,
        serverMsgId,
        isMe,
        dbPath,
        pendingPath,
        mediaUrl,
        durationSeconds,
        kind,
      );
}

class VoiceMessageSnapshot {
  final VoiceUiPhase phase;
  final VoiceMessageRef ref;
  final String? localPath;
  final List<double>? waveform;
  final double? downloadProgress;
  final String? error;

  const VoiceMessageSnapshot({
    required this.phase,
    required this.ref,
    this.localPath,
    this.waveform,
    this.downloadProgress,
    this.error,
  });

  VoiceMessageSnapshot copyWith({
    VoiceUiPhase? phase,
    VoiceMessageRef? ref,
    String? localPath,
    List<double>? waveform,
    double? downloadProgress,
    String? error,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return VoiceMessageSnapshot(
      phase: phase ?? this.phase,
      ref: ref ?? this.ref,
      localPath: localPath ?? this.localPath,
      waveform: waveform ?? this.waveform,
      downloadProgress:
          clearProgress ? null : (downloadProgress ?? this.downloadProgress),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Orchestrateur unique : résolution fichier local, téléchargement, waveform.
class VoiceMessageCoordinator extends ChangeNotifier {
  VoiceMessageCoordinator({required ChatRepository repository})
      : _repository = repository,
        _resolver = VoiceAssetResolver(
          mediaCache: repository.mediaCache,
          dao: repository.dao,
        );

  final ChatRepository _repository;
  final VoiceAssetResolver _resolver;
  final VoiceWaveformStore _waveforms = VoiceWaveformStore();

  final Map<String, VoiceMessageSnapshot> _snapshots = {};
  final Map<String, Future<VoiceMessageSnapshot>> _inFlight = {};

  /// Extractions de waveform en cours, par clientId. La waveform étant
  /// purement décorative, elle est calculée hors du chemin critique.
  final Set<String> _waveformJobs = {};

  VoiceMessageSnapshot? snapshotFor(String clientId) => _snapshots[clientId];

  void invalidate(String clientId) {
    _snapshots.remove(clientId);
    _inFlight.remove(clientId);
    _waveformJobs.remove(clientId);
    notifyListeners();
  }

  void invalidateAll() {
    _snapshots.clear();
    _inFlight.clear();
    _waveformJobs.clear();
    notifyListeners();
  }

  Future<VoiceMessageSnapshot> ensureReady(VoiceMessageRef ref) {
    final cached = _snapshots[ref.clientId];
    if (cached != null &&
        cached.phase == VoiceUiPhase.ready &&
        cached.ref.clientId == ref.clientId &&
        cached.localPath != null &&
        File(cached.localPath!).existsSync()) {
      if (cached.ref != ref) {
        _setSnapshot(cached.copyWith(ref: ref));
      }
      final current = _snapshots[ref.clientId]!;
      // Snapshot jouable mais waveform absente (extraction échouée ou
      // jamais lancée) : on relance sans bloquer la lecture.
      if (current.waveform == null) {
        _scheduleWaveform(current.ref, current.localPath!);
      }
      return Future.value(current);
    }

    final pending = _inFlight[ref.clientId];
    if (pending != null) return pending;

    final future = _ensureReady(ref);
    _inFlight[ref.clientId] = future;
    return future;
  }

  Future<void> download(
    VoiceMessageRef ref, {
    void Function(double? progress)? onProgress,
  }) async {
    if (ref.serverMsgId == 0) return;
    final url = ref.mediaUrl;
    if (url == null || url.isEmpty) return;

    _setSnapshot(
      VoiceMessageSnapshot(
        phase: VoiceUiPhase.downloading,
        ref: ref,
        downloadProgress: 0.0,
      ),
    );

    try {
      final path = await _repository.downloadVoiceMessage(
        msgID: ref.serverMsgId,
        mediaUrl: url,
        // Un morceau pèse couramment plus que le plafond vocal de 15 Mo,
        // alors que l'app en autorise l'envoi jusqu'à 50 Mo.
        maxBytes: ref.kind == AudioMessageKind.music
            ? 50 * 1024 * 1024
            : 15 * 1024 * 1024,
        onProgress: (p) {
          onProgress?.call(p);
          final current = _snapshots[ref.clientId];
          if (current != null && current.phase == VoiceUiPhase.downloading) {
            _setSnapshot(current.copyWith(downloadProgress: p));
          }
        },
      );
      if (path == null || !File(path).existsSync()) {
        _setSnapshot(
          VoiceMessageSnapshot(
            phase: VoiceUiPhase.error,
            ref: ref,
            error: LocaleController.instance.l10n.downloadFailed,
          ),
        );
        return;
      }
      invalidate(ref.clientId);
      final updated = ref.copyWith(dbPath: path);
      await ensureReady(updated);
    } catch (e) {
      _setSnapshot(
        VoiceMessageSnapshot(
          phase: VoiceUiPhase.error,
          ref: ref,
          error: LocaleController.instance.l10n.downloadFailed,
        ),
      );
    }
  }

  Future<VoiceMessageSnapshot> _ensureReady(VoiceMessageRef ref) async {
    _setSnapshot(
      VoiceMessageSnapshot(phase: VoiceUiPhase.resolving, ref: ref),
    );

    try {
      final local = await _resolver.resolve(
        serverMsgId: ref.serverMsgId,
        isMe: ref.isMe,
        dbPath: ref.dbPath,
        pendingPath: ref.pendingPath,
        mediaUrl: ref.mediaUrl,
      );

      if (local == null) {
        final snap = VoiceMessageSnapshot(
          phase: VoiceUiPhase.needsDownload,
          ref: ref,
        );
        _setSnapshot(snap);
        return snap;
      }

      // Le fichier est sur le disque, donc jouable immédiatement : on passe
      // en `ready` sans attendre la waveform. L'extraction est sérialisée et
      // peut prendre plusieurs secondes (timeout 15 s) — l'attendre bloquait
      // le bouton de lecture sur un spinner alors que rien ne l'empêchait.
      final snap = VoiceMessageSnapshot(
        phase: VoiceUiPhase.ready,
        ref: ref,
        localPath: local.path,
      );
      _setSnapshot(snap);
      _scheduleWaveform(ref, local.path);
      return snap;
    } catch (e) {
      debugPrint('[VoiceMessageCoordinator] ensureReady échoué: $e');
      final snap = VoiceMessageSnapshot(
        phase: VoiceUiPhase.error,
        ref: ref,
        error: LocaleController.instance.l10n.audioUnavailable,
      );
      _setSnapshot(snap);
      return snap;
    } finally {
      _inFlight.remove(ref.clientId);
    }
  }

  /// Lance l'extraction de waveform en tâche de fond. Ne bloque jamais la
  /// lecture : le snapshot est déjà `ready`, la waveform arrive après.
  void _scheduleWaveform(VoiceMessageRef ref, String localPath) {
    // La carte musique n'affiche pas de waveform : extraction inutile, et
    // coûteuse sur un morceau de plusieurs minutes.
    if (ref.kind == AudioMessageKind.music) return;
    if (_waveformJobs.contains(ref.clientId)) return;
    _waveformJobs.add(ref.clientId);
    unawaited(_runWaveform(ref.clientId, localPath, ref.durationSeconds));
  }

  Future<void> _runWaveform(
    String clientId,
    String localPath,
    int durationSeconds,
  ) async {
    try {
      final waveform = await _waveforms.loadOrGenerate(
        localPath: localPath,
        durationSeconds: durationSeconds,
      );
      // Le snapshot a pu être invalidé ou remplacé pendant l'extraction :
      // on n'écrase que s'il s'agit toujours du même fichier prêt.
      final current = _snapshots[clientId];
      if (current == null ||
          current.phase != VoiceUiPhase.ready ||
          current.localPath != localPath) {
        return;
      }
      _setSnapshot(current.copyWith(waveform: waveform));
    } catch (e) {
      debugPrint('[VoiceMessageCoordinator] waveform échouée: $e');
    } finally {
      _waveformJobs.remove(clientId);
    }
  }

  void _setSnapshot(VoiceMessageSnapshot snap) {
    _snapshots[snap.ref.clientId] = snap;
    notifyListeners();
  }
}

extension on VoiceMessageRef {
  VoiceMessageRef copyWith({String? dbPath}) {
    return VoiceMessageRef(
      clientId: clientId,
      serverMsgId: serverMsgId,
      isMe: isMe,
      dbPath: dbPath ?? this.dbPath,
      pendingPath: pendingPath,
      mediaUrl: mediaUrl,
      durationSeconds: durationSeconds,
    );
  }
}
