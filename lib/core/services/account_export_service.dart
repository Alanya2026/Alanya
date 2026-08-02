import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../talky_api_client.dart';
import '../../talky_models.dart';

/// Orchestration des exports de données compte (sync ou job async avec messages).
class AccountExportService {
  final TalkyApiClient _api;

  AccountExportService({TalkyApiClient? api})
      : _api = api ?? TalkyApiClient();

  /// Export immédiat (sans messages) — renvoie le JSON complet.
  Future<Map<String, dynamic>> exportAccountData() async {
    final data = await _api.requestExport(includeMessages: false);
    if (data.containsKey('jobId')) {
      throw TalkyException(
        'Réponse inattendue : export async alors que includeMessages=false',
        0,
      );
    }
    return data;
  }

  /// Lance un export async incluant les messages et attend qu'il soit prêt.
  Future<File> exportWithMessages({
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 10),
    void Function(ExportJob job)? onProgress,
  }) async {
    final started = await _api.requestExport(includeMessages: true);
    final jobId = started['jobId'];
    if (jobId == null) {
      throw TalkyException('Identifiant de job absent', 0);
    }
    final id = jobId is int ? jobId : int.tryParse(jobId.toString()) ?? 0;
    if (id <= 0) throw TalkyException('Identifiant de job invalide', 0);

    final deadline = DateTime.now().add(timeout);
    ExportJob? last;
    while (DateTime.now().isBefore(deadline)) {
      last = await _api.getExportJob(id);
      onProgress?.call(last);
      if (last.isReady) break;
      if (last.isFailed) {
        throw TalkyException(
          last.errorMessage ?? 'Export échoué',
          500,
        );
      }
      await Future<void>.delayed(pollInterval);
    }

    if (last == null || !last.isReady) {
      throw TalkyException('Délai d\'export dépassé', 408);
    }

    final bytes = await _api.downloadExportJob(id);
    return _writeExportFile(id, bytes);
  }

  Future<File> downloadReadyJob(int jobId) async {
    final status = await _api.getExportJob(jobId);
    if (!status.isReady) {
      throw TalkyException(
        'Export non prêt (statut: ${status.status})',
        202,
      );
    }
    final bytes = await _api.downloadExportJob(jobId);
    return _writeExportFile(jobId, bytes);
  }

  Future<File> _writeExportFile(int jobId, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exports'));
    if (!exportsDir.existsSync()) {
      exportsDir.createSync(recursive: true);
    }
    final file = File(
      p.join(exportsDir.path, 'alanya-export-$jobId.json'),
    );
    await file.writeAsBytes(bytes, flush: true);

    if (kDebugMode) {
      try {
        jsonDecode(await file.readAsString());
      } catch (e) {
        debugPrint('[AccountExportService] JSON export illisible: $e');
      }
    }
    return file;
  }
}
