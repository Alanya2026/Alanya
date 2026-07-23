import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Origine d'une sonnerie proposée à l'utilisateur.
enum RingtoneSourceType {
  /// Sonnerie par défaut du téléphone (gérée par l'OS — voir [RingtoneService]
  /// / `CallKitService`, qui savent jouer/déclarer ce choix nativement).
  system,

  /// Sonnerie fournie avec l'application (asset embarqué).
  bundled,

  /// Sonnerie importée par l'utilisateur depuis son appareil.
  custom,
}

/// Une sonnerie sélectionnable dans les réglages d'appel.
@immutable
class RingtoneOption {
  final String id;
  final String label;
  final RingtoneSourceType type;

  /// Chemin de l'asset Flutter (`bundled`) — ex. `assets/sounds/ringback.wav`.
  final String? assetPath;

  /// Chemin absolu sur le disque (`custom`) — fichier copié dans le
  /// dossier documents de l'app pour rester disponible hors sandbox du picker.
  final String? filePath;

  /// Nom de la ressource `android/app/src/main/res/raw/<nom>.mp3` (SANS
  /// extension), pour les sonneries `bundled` uniquement. CallKit/Android
  /// résout les sonneries par nom de ressource compilée — un fichier
  /// importé par l'utilisateur au runtime ne peut PAS être référencé ainsi,
  /// d'où ce champ réservé aux sonneries fournies avec l'app. Null = pas
  /// (encore) déclarée côté natif → l'appel entrant en arrière-plan retombe
  /// sur la sonnerie système (voir `CallKitService.showIncoming`).
  final String? androidRawResource;

  /// Nom du fichier `.caf` (SANS extension) copié dans
  /// `ios/Runner/Ringtone.caf`-style bundle resources. Même contrainte
  /// « compile-time only » que ci-dessus, côté iOS.
  final String? iosCafResource;

  const RingtoneOption({
    required this.id,
    required this.label,
    required this.type,
    this.assetPath,
    this.filePath,
    this.androidRawResource,
    this.iosCafResource,
  });

  /// Identifiant réservé à l'option « sonnerie système ».
  static const String systemId = '__system_default__';

  static const RingtoneOption system = RingtoneOption(
    id: systemId,
    label: 'Sonnerie par défaut de l\'appareil',
    type: RingtoneSourceType.system,
  );

  /// Sonneries embarquées avec l'app (assets déjà présents dans
  /// `assets/sounds/`, déclarés dans pubspec.yaml).
  static const List<RingtoneOption> bundled = [
    RingtoneOption(
      id: 'bundled_ringback',
      label: 'Sonnerie Alanya',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringback.wav',
    ),
  ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'filePath': filePath,
      };

  factory RingtoneOption.fromJson(Map<String, dynamic> json) => RingtoneOption(
        id: json['id'] as String,
        label: json['label'] as String,
        type: RingtoneSourceType.custom,
        filePath: json['filePath'] as String?,
      );
}

/// Extensions audio acceptées à l'import. `just_audio` (lecture en foreground)
/// les lit toutes ; seules `wav`/`aiff`/`caf` sont directement utilisables par
/// CallKit sur iOS pour l'écran d'appel natif en arrière-plan — voir la note
/// dans `RingtoneImportException`.
const List<String> kSupportedRingtoneExtensions = ['mp3', 'wav', 'm4a', 'aac', 'ogg'];

/// Taille max d'une sonnerie importée (garde-fou : évite qu'un utilisateur
/// importe un fichier de plusieurs dizaines de Mo par erreur).
const int kMaxRingtoneFileSizeBytes = 5 * 1024 * 1024; // 5 Mo

class RingtoneImportException implements Exception {
  final String message;
  RingtoneImportException(this.message);
  @override
  String toString() => message;
}

/// Préférence utilisateur : sonnerie utilisée pour les appels entrants
/// (par appareil, non synchronisée entre appareils — comme le ton de
/// notification d'un OS classique).
///
/// Suit le même pattern que [MediaDownloadPreferences] : un cache statique
/// pour permettre une lecture synchrone depuis des services qui ne vivent
/// pas forcément sous le `MultiProvider` (CallService, RingtoneService,
/// CallKitService), en plus de l'API `ChangeNotifier` pour l'UI réactive.
class RingtonePreferences extends ChangeNotifier {
  static const _kSelectedKey = 'call_ringtone_selected_id';
  static const _kCustomListKey = 'call_ringtone_custom_list';

  static RingtonePreferences? _bound;

  static bool _prefsLoaded = false;
  static String _cachedSelectedId = RingtoneOption.systemId;
  static List<RingtoneOption> _cachedCustom = const [];

  String _selectedId = RingtoneOption.systemId;
  List<RingtoneOption> _custom = const [];

  RingtonePreferences() {
    _bound = this;
    if (_prefsLoaded) {
      _selectedId = _cachedSelectedId;
      _custom = _cachedCustom;
    }
  }

  /// Toutes les options proposées à l'utilisateur : système + fournies +
  /// importées.
  List<RingtoneOption> get allOptions => [
        RingtoneOption.system,
        ...RingtoneOption.bundled,
        ..._custom,
      ];

  String get selectedId => _selectedId;

  RingtoneOption get selected =>
      allOptions.firstWhere((o) => o.id == _selectedId, orElse: () => RingtoneOption.system);

  List<RingtoneOption> get customRingtones => _custom;

  /// Lecture synchrone utilisable depuis un service non lié au Provider
  /// (ex. `CallService` au moment de sonner un appel entrant).
  static RingtoneOption get currentSelection {
    if (_bound != null) return _bound!.selected;
    final match = [RingtoneOption.system, ...RingtoneOption.bundled, ..._cachedCustom]
        .where((o) => o.id == _cachedSelectedId);
    return match.isNotEmpty ? match.first : RingtoneOption.system;
  }

  /// Résout l'identifiant natif à passer à CallKit (écran d'appel
  /// système en arrière-plan) pour la sélection courante.
  ///
  /// - Sonnerie système ou sonnerie personnalisée (fichier importé au
  ///   runtime) → `'system_ringtone_default'` : CallKit/Android résout ses
  ///   sonneries par ressource compilée (`res/raw`) et CallKit/iOS par
  ///   fichier `.caf` embarqué dans le bundle — un chemin de fichier
  ///   arbitraire choisi par l'utilisateur ne peut pas lui être passé.
  ///   La sonnerie personnalisée reste utilisée quand l'app est au premier
  ///   plan (voir `RingtoneService`, qui lit un fichier quelconque).
  /// - Sonnerie fournie par l'app *et* déclarée côté natif (voir
  ///   `RingtoneOption.androidRawResource`/`iosCafResource`) → ce nom de
  ///   ressource natif.
  static String resolveAndroidCallKitRingtone() {
    final selection = currentSelection;
    return selection.androidRawResource ?? 'system_ringtone_default';
  }

  static String? resolveIosCallKitRingtone() {
    final selection = currentSelection;
    return selection.iosCafResource; // null → CallKit garde son défaut iOS.
  }

  /// À appeler avant `runApp`, comme `MediaDownloadPreferences.preload()`.
  static Future<void> preload() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cachedSelectedId = prefs.getString(_kSelectedKey) ?? RingtoneOption.systemId;
    final raw = prefs.getStringList(_kCustomListKey) ?? const [];
    _cachedCustom = raw
        .map((s) {
          try {
            return RingtoneOption.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<RingtoneOption>()
        // Ignore les entrées dont le fichier a disparu (désinstall/partiel).
        .where((o) => o.filePath != null && File(o.filePath!).existsSync())
        .toList();
    _prefsLoaded = true;
  }

  Future<void> load() async {
    await preload();
    _selectedId = _cachedSelectedId;
    _custom = _cachedCustom;
    notifyListeners();
  }

  Future<void> select(String id) async {
    if (_selectedId == id) return;
    _selectedId = id;
    _cachedSelectedId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedKey, id);
  }

  /// Copie le fichier choisi par l'utilisateur dans le dossier documents de
  /// l'app (le chemin renvoyé par `file_picker` peut être un cache temporaire
  /// non garanti de survivre à un redémarrage) et l'ajoute à la liste.
  Future<RingtoneOption> addCustomRingtone({
    required String sourcePath,
    required String label,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw RingtoneImportException('Fichier introuvable.');
    }

    final ext = sourcePath.split('.').last.toLowerCase();
    if (!kSupportedRingtoneExtensions.contains(ext)) {
      throw RingtoneImportException(
        'Format non supporté ($ext). Formats acceptés : ${kSupportedRingtoneExtensions.join(', ')}.',
      );
    }

    final size = await sourceFile.length();
    if (size > kMaxRingtoneFileSizeBytes) {
      throw RingtoneImportException('Fichier trop volumineux (max 5 Mo).');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final ringtonesDir = Directory('${docsDir.path}/ringtones');
    if (!await ringtonesDir.exists()) {
      await ringtonesDir.create(recursive: true);
    }

    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final destPath = '${ringtonesDir.path}/$id.$ext';
    await sourceFile.copy(destPath);

    final option = RingtoneOption(
      id: id,
      label: label.trim().isEmpty ? 'Sonnerie personnalisée' : label.trim(),
      type: RingtoneSourceType.custom,
      filePath: destPath,
    );

    _custom = [..._custom, option];
    _cachedCustom = _custom;
    notifyListeners();
    await _persistCustomList();
    return option;
  }

  Future<void> removeCustomRingtone(String id) async {
    RingtoneOption? option;
    for (final o in _custom) {
      if (o.id == id) {
        option = o;
        break;
      }
    }
    if (option == null) return;

    _custom = _custom.where((o) => o.id != id).toList();
    _cachedCustom = _custom;

    // Si la sonnerie supprimée était sélectionnée, on retombe sur le défaut.
    if (_selectedId == id) {
      await select(RingtoneOption.systemId);
    } else {
      notifyListeners();
    }

    await _persistCustomList();

    try {
      final file = File(option.filePath!);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Non bloquant : au pire le fichier orphelin reste sur le disque.
    }
  }

  Future<void> _persistCustomList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kCustomListKey,
      _custom.map((o) => jsonEncode(o.toJson())).toList(),
    );
  }
}
