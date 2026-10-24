//  Fichiers reçus par le coffre, enregistrés dans Téléchargements/Alanya
//  (conception, section 07).
//
//  Le téléchargement se fait d'abord dans le dossier privé de l'application,
//  où il reprend après une coupure. Une fois le fichier déchiffré, il est
//  copié dans Téléchargements — visible dans le gestionnaire de fichiers,
//  gardé si l'application est désinstallée — et la copie privée est
//  supprimée : un fichier de 1 Go n'occupe la place qu'une fois.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'safebox_models.dart';

/// Copie un fichier dans Téléchargements ; rend son emplacement (adresse
/// `content://` ou chemin), ou null.
typedef SafeboxPublish = Future<String?> Function(String path, String name, String mime, String subdir);

class SafeboxReceivedFiles {
  SafeboxReceivedFiles({
    SafeboxPublish? publish,
    Future<bool> Function(String location)? exists,
    Future<bool> Function(String location, String mime)? open,
  })  : _publier = publish ?? _publierSurLeTelephone,
        _existe = exists ?? _existeSurLeTelephone,
        _ouvrir = open ?? _ouvrirSurLeTelephone;

  static const _cle = 'safebox_received_locations_v1';
  static const _max = 500;
  static const _channel = MethodChannel('com.alanya/media_export');

  final SafeboxPublish _publier;
  final Future<bool> Function(String) _existe;
  final Future<bool> Function(String, String) _ouvrir;

  /// Même rangement que les médias reçus dans les discussions.
  static String subdirFor(SafeboxFamily family) => switch (family) {
        SafeboxFamily.photos => 'Alanya/Alanya Images',
        SafeboxFamily.videos => 'Alanya/Alanya Videos',
        SafeboxFamily.audios => 'Alanya/Alanya Audio',
        SafeboxFamily.documents => 'Alanya/Alanya Documents',
      };

  static String mimeFor(String name, String? mime) =>
      lookupMimeType(name) ?? mime ?? 'application/octet-stream';

  Future<Map<String, String>> _lire() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final d = jsonDecode(prefs.getString(_cle) ?? '{}');
      return d is Map ? d.map((k, v) => MapEntry('$k', '$v')) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _ecrire(Map<String, String> m) async {
    while (m.length > _max) {
      m.remove(m.keys.first);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle, jsonEncode(m));
  }

  /// Où se trouve le fichier de ce partage, s'il est encore sur le téléphone.
  /// Un fichier supprimé par l'inscrit est oublié.
  Future<String?> location(int shareId) async {
    final m = await _lire();
    final loc = m['$shareId'];
    if (loc == null) return null;
    if (await _existe(loc)) return loc;
    m.remove('$shareId');
    await _ecrire(m);
    return null;
  }

  /// Copie le fichier déchiffré dans Téléchargements/Alanya et retient où.
  /// Null si la copie échoue : le fichier reste alors dans l'application.
  Future<String?> publish(File file, {required int shareId, required String name, String? mime, required SafeboxFamily family}) async {
    String? loc;
    try {
      loc = await _publier(file.path, name, mimeFor(name, mime), subdirFor(family));
    } catch (e) {
      debugPrint('[Coffre] copie dans Téléchargements impossible : $e');
    }
    if (loc == null) return null;
    final m = await _lire()
      ..remove('$shareId');
    m['$shareId'] = loc;
    await _ecrire(m);
    return loc;
  }

  Future<bool> open(String location, String? mime) => _ouvrir(location, mime ?? 'application/octet-stream');

  // ── Sur le téléphone ─────────────────────────────────────────────────────

  static Future<String?> _publierSurLeTelephone(String path, String name, String mime, String subdir) async {
    if (Platform.isAndroid) {
      return _channel.invokeMethod<String>('saveToDownloads', {
        'path': path,
        'fileName': name,
        'mimeType': mime,
        'subdir': subdir,
      });
    }
    if (Platform.isIOS) {
      // Pas de Téléchargements partagé : le dossier Documents de l'application,
      // visible dans l'app Fichiers.
      final base = await getApplicationDocumentsDirectory();
      final dossier = Directory(p.join(base.path, subdir));
      await dossier.create(recursive: true);
      var cible = File(p.join(dossier.path, name));
      if (await cible.exists()) {
        cible = File(p.join(dossier.path,
            '${p.basenameWithoutExtension(name)}_${DateTime.now().millisecondsSinceEpoch}${p.extension(name)}'));
      }
      await File(path).copy(cible.path);
      return cible.path;
    }
    return null;
  }

  static Future<bool> _existeSurLeTelephone(String location) async {
    if (!location.startsWith('content://')) return File(location).exists();
    try {
      return await _channel.invokeMethod<bool>('downloadedExists', {'location': location}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _ouvrirSurLeTelephone(String location, String mime) async {
    if (location.startsWith('content://')) {
      try {
        return await _channel.invokeMethod<bool>('openDownloaded', {'location': location, 'mimeType': mime}) ?? false;
      } catch (_) {
        return false;
      }
    }
    return (await OpenFilex.open(location, type: mime)).type == ResultType.done;
  }
}
