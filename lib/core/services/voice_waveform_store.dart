import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Waveforms extraites ou générées, avec cache mémoire + disque.
/// Retourne toujours une liste non vide de barres.
class VoiceWaveformStore {
  static const int defaultSampleCount = 56;

  final Map<String, List<double>> _memory = {};
  Future<void>? _extractQueue;

  Directory? _dir;

  Future<Directory> _cacheDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'waveform_cache'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  String fingerprintFor(String localPath) {
    final file = File(localPath);
    final stat = file.statSync();
    final payload =
        '$localPath|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    return sha1.convert(utf8.encode(payload)).toString();
  }

  /// Barres déterministes quand l'extraction échoue (jamais vide).
  static List<double> generateDeterministicFallback(
    String localPath,
    int durationSeconds, {
    int samples = defaultSampleCount,
  }) {
    final seed = Object.hash(localPath, durationSeconds);
    final rng = Random(seed);
    return List<double>.generate(samples, (i) {
      final t = i / samples;
      final wave = 0.35 + 0.45 * sin(t * pi * 5 + (seed % 7));
      final noise = rng.nextDouble() * 0.2;
      return (wave + noise).clamp(0.08, 1.0);
    });
  }

  Future<List<double>> loadOrGenerate({
    required String localPath,
    required int durationSeconds,
    int samples = defaultSampleCount,
  }) async {
    try {
      if (!File(localPath).existsSync()) {
        return generateDeterministicFallback(localPath, durationSeconds,
            samples: samples);
      }

      final fingerprint = fingerprintFor(localPath);
      final cached = _memory[fingerprint];
      if (cached != null && cached.isNotEmpty) return cached;

      final fromDisk = await _readDisk(fingerprint);
      if (fromDisk != null && fromDisk.isNotEmpty) {
        _memory[fingerprint] = fromDisk;
        return fromDisk;
      }

      final extracted = await _serialize(() => _extract(localPath, samples));
      final data = (extracted != null && extracted.isNotEmpty)
          ? extracted
          : generateDeterministicFallback(localPath, durationSeconds,
              samples: samples);

      _memory[fingerprint] = data;
      unawaited(_writeDisk(fingerprint, data));
      return data;
    } catch (e) {
      debugPrint('[VoiceWaveformStore] loadOrGenerate repli: $e');
      return generateDeterministicFallback(localPath, durationSeconds,
          samples: samples);
    }
  }

  Future<T> _serialize<T>(Future<T> Function() fn) async {
    final prev = _extractQueue ?? Future<void>.value();
    final gate = Completer<void>();
    _extractQueue = gate.future;
    await prev;
    try {
      return await fn();
    } finally {
      gate.complete();
    }
  }

  Future<List<double>?> _extract(String path, int samples) async {
    PlayerController? controller;
    WaveformExtractionController? extractor;
    StreamSubscription<List<double>>? sub;
    try {
      extractor = WaveformExtractionController();
      List<double>? streamed;
      sub = extractor.onCurrentExtractedWaveformData.listen((data) {
        if (data.isNotEmpty) streamed = List<double>.from(data);
      });
      try {
        final data = await extractor
            .extractWaveformData(path: path, noOfSamples: samples)
            .timeout(const Duration(seconds: 15));
        if (data.isNotEmpty) return data;
      } catch (_) {
        if (streamed != null && streamed!.isNotEmpty) return streamed;
      }

      controller = PlayerController();
      await controller.preparePlayer(
        path: path,
        shouldExtractWaveform: true,
        noOfSamples: samples,
      );
      for (var i = 0; i < 25; i++) {
        final data = controller.waveformExtraction.waveformData;
        if (data.isNotEmpty) return List<double>.from(data);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('[VoiceWaveformStore] extraction échouée $path: $e');
      return null;
    } finally {
      await sub?.cancel();
      try {
        controller?.dispose();
      } catch (_) {}
    }
    return null;
  }

  Future<List<double>?> _readDisk(String fingerprint) async {
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, '$fingerprint.json'));
      if (!file.existsSync()) return null;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return null;
      return raw.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String fingerprint, List<double> data) async {
    try {
      final dir = await _cacheDir();
      final file = File(p.join(dir.path, '$fingerprint.json'));
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('[VoiceWaveformStore] écriture disque échouée: $e');
    }
  }
}
