import 'dart:io';

import 'package:flutter/foundation.dart';

import 'chat_repository.dart';
import 'voice_asset_resolver.dart';
import 'voice_waveform_store.dart';

enum VoiceUiPhase {
  resolving,
  needsDownload,
  downloading,
  extracting,
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

  const VoiceMessageRef({
    required this.clientId,
    required this.serverMsgId,
    required this.isMe,
    this.dbPath,
    this.pendingPath,
    this.mediaUrl,
    required this.durationSeconds,
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
        other.durationSeconds == durationSeconds;
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
    String? localPath,
    List<double>? waveform,
    double? downloadProgress,
    String? error,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return VoiceMessageSnapshot(
      phase: phase ?? this.phase,
      ref: ref,
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

  VoiceMessageSnapshot? snapshotFor(String clientId) => _snapshots[clientId];

  void invalidate(String clientId) {
    _snapshots.remove(clientId);
    _inFlight.remove(clientId);
    notifyListeners();
  }

  void invalidateAll() {
    _snapshots.clear();
    _inFlight.clear();
    notifyListeners();
  }

  Future<VoiceMessageSnapshot> ensureReady(VoiceMessageRef ref) {
    final cached = _snapshots[ref.clientId];
    if (cached != null &&
        cached.phase == VoiceUiPhase.ready &&
        cached.ref == ref &&
        cached.localPath != null &&
        File(cached.localPath!).existsSync() &&
        cached.waveform != null) {
      return Future.value(cached);
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
            error: 'Échec du téléchargement',
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
          error: 'Échec du téléchargement',
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

      _setSnapshot(
        VoiceMessageSnapshot(
          phase: VoiceUiPhase.extracting,
          ref: ref,
          localPath: local.path,
        ),
      );

      final waveform = await _waveforms.loadOrGenerate(
        localPath: local.path,
        durationSeconds: ref.durationSeconds,
      );

      final snap = VoiceMessageSnapshot(
        phase: VoiceUiPhase.ready,
        ref: ref,
        localPath: local.path,
        waveform: waveform,
      );
      _setSnapshot(snap);
      return snap;
    } catch (e) {
      debugPrint('[VoiceMessageCoordinator] ensureReady échoué: $e');
      final snap = VoiceMessageSnapshot(
        phase: VoiceUiPhase.error,
        ref: ref,
        error: 'Audio indisponible',
      );
      _setSnapshot(snap);
      return snap;
    } finally {
      _inFlight.remove(ref.clientId);
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
