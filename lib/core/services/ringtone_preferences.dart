import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  /// Empreinte SHA-256 du **contenu** du fichier (`custom` uniquement).
  ///
  /// C'est l'identité du son entre appareils : l'[id] (`custom_<horodatage>`)
  /// et le nom du fichier ne valent que sur cet appareil-ci — deux fichiers
  /// peuvent s'appeler `MaSonnerie.mp3` sans être le même son, et le même
  /// fichier importé deux fois donne deux ids différents. Le hash, lui, ne
  /// dépend que des octets : c'est ce qui permet à une liste configurée sur
  /// l'appareil A de retrouver son son sur l'appareil B (voir
  /// `ListRingtonePreferences`). Null pour les entrées importées avant
  /// l'arrivée de la synchronisation — [RingtonePreferences.load] les
  /// complète.
  final String? contentHash;

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
    this.contentHash,
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

  /// Sonneries embarquées avec l'app. Chaque entrée existe en DEUX exemplaires :
  ///  - un asset Flutter `assets/sounds/ringtones/<nom>.ogg` (aperçu + lecture
  ///    quand l'app est au premier plan, via `just_audio`) ;
  ///  - une ressource Android compilée `res/raw/rt_<nom>.ogg` référencée par
  ///    [androidRawResource] (lecture par CallKit quand l'app est tuée).
  /// Pour en remplacer une : déposer les deux fichiers (même nom) ; pour en
  /// ajouter/supprimer ou renommer, éditer cette liste.
  static const List<RingtoneOption> bundled = [
    RingtoneOption(
      id: 'bundled_son1',
      label: 'Sonnerie 1',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son1.ogg',
      androidRawResource: 'rt_son1',
    ),
    RingtoneOption(
      id: 'bundled_son2',
      label: 'Sonnerie 2',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son2.ogg',
      androidRawResource: 'rt_son2',
    ),
    RingtoneOption(
      id: 'bundled_son3',
      label: 'Sonnerie 3',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son3.ogg',
      androidRawResource: 'rt_son3',
    ),
    RingtoneOption(
      id: 'bundled_son4',
      label: 'Sonnerie 4',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son4.ogg',
      androidRawResource: 'rt_son4',
    ),
    RingtoneOption(
      id: 'bundled_son5',
      label: 'Sonnerie 5',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son5.ogg',
      androidRawResource: 'rt_son5',
    ),
    RingtoneOption(
      id: 'bundled_son6',
      label: 'Sonnerie 6',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son6.ogg',
      androidRawResource: 'rt_son6',
    ),
    RingtoneOption(
      id: 'bundled_son7',
      label: 'Sonnerie 7',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son7.ogg',
      androidRawResource: 'rt_son7',
    ),
    RingtoneOption(
      id: 'bundled_son8',
      label: 'Sonnerie 8',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/ringtones/son8.ogg',
      androidRawResource: 'rt_son8',
    ),
  ];

  /// Sons de **notification de message** fournis avec l'app — catalogue
  /// volontairement distinct de [bundled] : ces sons durent 1 à 2 s (contre 15
  /// à 60 s pour une sonnerie d'appel) et n'ont de sens que pour signaler
  /// l'arrivée d'un message. Les deux listes ne se mélangent jamais dans les
  /// sélecteurs — voir `RingtonePreferences.allOptions` (appels) et
  /// `notificationOptions` (messages).
  ///
  /// Même contrainte de double dépôt que [bundled], avec le préfixe `nt_` au
  /// lieu de `rt_` :
  ///  - asset Flutter `assets/sounds/notifications/<nom>.ogg` (aperçu + app au
  ///    premier plan, via `just_audio`) ;
  ///  - ressource Android compilée `res/raw/nt_<nom>.ogg` référencée par
  ///    [androidRawResource] (canal de notification quand l'app est tuée —
  ///    voir `MessageNotificationHelper.resolveListMessageSound`, qui déduit le
  ///    nom de ressource du préfixe `notif_` de l'identifiant).
  static const List<RingtoneOption> notifications = [
    RingtoneOption(
      id: 'notif_pop',
      label: 'Pop',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/pop.ogg',
      androidRawResource: 'nt_pop',
    ),
    RingtoneOption(
      id: 'notif_ping',
      label: 'Ping',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/ping.ogg',
      androidRawResource: 'nt_ping',
    ),
    RingtoneOption(
      id: 'notif_duo',
      label: 'Duo',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/duo.ogg',
      androidRawResource: 'nt_duo',
    ),
    RingtoneOption(
      id: 'notif_trio',
      label: 'Trio',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/trio.ogg',
      androidRawResource: 'nt_trio',
    ),
    RingtoneOption(
      id: 'notif_tick',
      label: 'Tic',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/tick.ogg',
      androidRawResource: 'nt_tick',
    ),
    RingtoneOption(
      id: 'notif_chime',
      label: 'Carillon',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/chime.ogg',
      androidRawResource: 'nt_chime',
    ),
    RingtoneOption(
      id: 'notif_drop',
      label: 'Goutte',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/drop.ogg',
      androidRawResource: 'nt_drop',
    ),
    RingtoneOption(
      id: 'notif_blip',
      label: 'Bip',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/blip.ogg',
      androidRawResource: 'nt_blip',
    ),
    RingtoneOption(
      id: 'notif_bloom',
      label: 'Éclosion',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/bloom.ogg',
      androidRawResource: 'nt_bloom',
    ),
    RingtoneOption(
      id: 'notif_tap',
      label: 'Marimba',
      type: RingtoneSourceType.bundled,
      assetPath: 'assets/sounds/notifications/tap.ogg',
      androidRawResource: 'nt_tap',
    ),
  ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'filePath': filePath,
        'contentHash': contentHash,
      };

  factory RingtoneOption.fromJson(Map<String, dynamic> json) => RingtoneOption(
        id: json['id'] as String,
        label: json['label'] as String,
        type: RingtoneSourceType.custom,
        filePath: json['filePath'] as String?,
        contentHash: json['contentHash'] as String?,
      );

  RingtoneOption copyWith({String? contentHash}) => RingtoneOption(
        id: id,
        label: label,
        type: type,
        assetPath: assetPath,
        filePath: filePath,
        contentHash: contentHash ?? this.contentHash,
        androidRawResource: androidRawResource,
        iosCafResource: iosCafResource,
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

/// Nombre maximal de sonneries importées par l'utilisateur.
const int kMaxCustomRingtones = 10;

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

  /// Chemin du fichier de la sonnerie *importée* actuellement sélectionnée,
  /// ou chaîne vide si l'utilisateur est sur la sonnerie système / fournie.
  ///
  /// Clé plate (String simple) lisible par le code natif Android — qui ne peut
  /// pas décoder la liste `_kCustomListKey` du plugin shared_preferences — pour
  /// jouer la sonnerie importée quand l'app est tuée (voir
  /// `CallIncomingHelper.resolveCustomRingtonePath`).
  static const _kActivePathKey = 'call_ringtone_active_path';

  /// Nom de la ressource `res/raw` (sans extension) que le chemin natif app
  /// tuée doit passer à CallKit pour la sélection courante — `'ringback'`
  /// (Sonnerie Alanya), `'system_ringtone_default'` (système), etc. Distinct
  /// de [_kActivePathKey] : ici CallKit joue lui-même une ressource compilée ;
  /// là, on lui demande le silence et on joue un fichier importé.
  static const _kNativeNameKey = 'call_ringtone_native_name';

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

  /// Options proposées pour les **appels** : système + sonneries d'appel
  /// fournies + sonneries importées. Ne contient volontairement pas les sons
  /// de notification de message (voir [notificationOptions]).
  List<RingtoneOption> get allOptions => [
        RingtoneOption.system,
        ...RingtoneOption.bundled,
        ..._custom,
      ];

  /// Options proposées pour les **notifications de message** : système + sons
  /// de notification fournis + sonneries importées (l'utilisateur qui a
  /// importé un son court doit pouvoir s'en servir ici aussi).
  List<RingtoneOption> get notificationOptions => [
        RingtoneOption.system,
        ...RingtoneOption.notifications,
        ..._custom,
      ];

  String get selectedId => _selectedId;

  RingtoneOption get selected =>
      allOptions.firstWhere((o) => o.id == _selectedId, orElse: () => RingtoneOption.system);

  List<RingtoneOption> get customRingtones => _custom;

  /// Nombre de sonneries importées actuellement, et plafond associé.
  int get customCount => _custom.length;
  int get customMax => kMaxCustomRingtones;

  /// L'utilisateur peut-il encore importer une sonnerie ? (limite non atteinte)
  bool get canAddCustom => _custom.length < kMaxCustomRingtones;

  /// Lecture synchrone utilisable depuis un service non lié au Provider
  /// (ex. `CallService` au moment de sonner un appel entrant).
  static RingtoneOption get currentSelection {
    if (_bound != null) return _bound!.selected;
    final match = [RingtoneOption.system, ...RingtoneOption.bundled, ..._cachedCustom]
        .where((o) => o.id == _cachedSelectedId);
    return match.isNotEmpty ? match.first : RingtoneOption.system;
  }

  /// Notifié après toute mutation de la liste des sonneries importées :
  /// import, suppression, complétion des empreintes.
  ///
  /// `ListRingtonePreferences` s'y abonne pour rebrancher les listes dont le
  /// son personnalisé vient d'apparaître (fichier réimporté) ou de disparaître
  /// sur cet appareil, sans que l'utilisateur ait à refaire sa sélection. Un
  /// simple rappel plutôt qu'un import croisé : la couche « sonneries » ne
  /// connaît pas la couche « listes ».
  static VoidCallback? onCustomRingtonesChanged;

  /// Empreinte SHA-256 du contenu d'un fichier de sonnerie.
  ///
  /// Lecture en un bloc : l'import plafonne les fichiers à
  /// [kMaxRingtoneFileSizeBytes] (5 Mo).
  static Future<String> computeContentHash(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  /// Sonnerie importée présente sur CET appareil dont le contenu correspond à
  /// [hash], ou null. Seul le contenu compte : deux fichiers homonymes de
  /// contenu différent ne s'apparient pas, et le même fichier importé sous un
  /// autre nom s'apparie quand même.
  static RingtoneOption? customByContentHash(String hash) {
    if (hash.isEmpty) return null;
    for (final option in _bound?.customRingtones ?? _cachedCustom) {
      if (option.contentHash == hash) return option;
    }
    return null;
  }

  /// Résout une option enregistrée par son identifiant. Sert notamment aux
  /// sonneries propres aux listes de contacts.
  ///
  /// Cherche dans les DEUX catalogues (appels et notifications) : le même
  /// appel sert à résoudre `callRingtoneId` et `messageRingtoneId`, et une
  /// liste configurée avant l'arrivée des sons de notification peut encore
  /// pointer vers une sonnerie d'appel — on continue de la résoudre.
  static RingtoneOption? optionById(String id) {
    final custom = _bound?.customRingtones ?? _cachedCustom;
    for (final option in [
      RingtoneOption.system,
      ...RingtoneOption.bundled,
      ...RingtoneOption.notifications,
      ...custom,
    ]) {
      if (option.id == id) return option;
    }
    return null;
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

  /// Remet le cache statique à zéro (tests uniquement).
  @visibleForTesting
  static void resetForTesting() {
    _bound = null;
    _prefsLoaded = false;
    _cachedSelectedId = RingtoneOption.systemId;
    _cachedCustom = const [];
    onCustomRingtonesChanged = null;
  }

  /// À appeler avant `runApp`, comme `MediaDownloadPreferences.preload()`.
  static Future<void> preload() async {
    if (_prefsLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cachedSelectedId =
        prefs.getString(_kSelectedKey) ?? RingtoneOption.systemId;
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
    // Dès le préchargement, écrire les clés lues par le natif : garantit qu'un
    // nouvel utilisateur (défaut = sonnerie Alanya) sonne correctement même
    // app tuée, avant toute ouverture des réglages.
    await _persistNativeKeys(prefs, _cachedSelectionFromCache());
  }

  /// Sélection courante calculée depuis le cache statique (utilisable sans
  /// instance liée, ex. depuis [preload]).
  static RingtoneOption _cachedSelectionFromCache() {
    return [RingtoneOption.system, ...RingtoneOption.bundled, ..._cachedCustom]
        .firstWhere((o) => o.id == _cachedSelectedId,
            orElse: () => RingtoneOption.bundled.first);
  }

  /// Écrit les deux clés plates lues par le natif Android à partir d'une
  /// sélection : chemin du fichier importé (ou '') + nom de ressource res/raw.
  static Future<void> _persistNativeKeys(
    SharedPreferences prefs,
    RingtoneOption sel,
  ) async {
    final path = sel.type == RingtoneSourceType.custom ? (sel.filePath ?? '') : '';
    await prefs.setString(_kActivePathKey, path);
    await prefs.setString(
      _kNativeNameKey,
      sel.androidRawResource ?? 'system_ringtone_default',
    );
  }

  Future<void> load() async {
    await preload();
    _selectedId = _cachedSelectedId;
    _custom = _cachedCustom;
    notifyListeners();
    // Backfill / resynchronise la clé plate lue par le natif (utile pour une
    // sélection faite avant l'introduction de `_kActivePathKey`).
    await _persistActivePath();
    // Complète les empreintes manquantes (sonneries importées avant la
    // synchronisation entre appareils). Volontairement ici et pas dans
    // `preload()` : celui-ci est attendu avant `runApp`, et hacher jusqu'à
    // 10 fichiers de 5 Mo retarderait le premier écran pour rien.
    await _backfillContentHashes();
  }

  /// Calcule et enregistre l'empreinte des sonneries importées qui n'en ont
  /// pas encore. Sans elle, une sonnerie importée avant cette version ne
  /// pourrait pas être reconnue par un autre appareil du compte.
  Future<void> _backfillContentHashes() async {
    if (_custom.every((o) => o.contentHash != null)) return;
    final updated = <RingtoneOption>[];
    var changed = false;
    for (final option in _custom) {
      if (option.contentHash != null || option.filePath == null) {
        updated.add(option);
        continue;
      }
      try {
        final hash = await computeContentHash(File(option.filePath!));
        updated.add(option.copyWith(contentHash: hash));
        changed = true;
      } catch (_) {
        // Fichier illisible : on garde l'entrée telle quelle, elle reste
        // jouable localement — seule la reconnaissance entre appareils manque.
        updated.add(option);
      }
    }
    if (!changed) return;
    _custom = updated;
    _cachedCustom = updated;
    await _persistCustomList();
    notifyListeners();
    onCustomRingtonesChanged?.call();
  }

  Future<void> select(String id) async {
    if (_selectedId == id) return;
    _selectedId = id;
    _cachedSelectedId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedKey, id);
    await _persistActivePath(prefs);
  }

  /// Écrit le chemin natif-lisible de la sonnerie importée sélectionnée (ou ''
  /// pour système / fournie). À garder synchronisé avec toute mutation de la
  /// sélection ou de la liste des sonneries importées.
  Future<void> _persistActivePath([SharedPreferences? prefsArg]) async {
    final prefs = prefsArg ?? await SharedPreferences.getInstance();
    await _persistNativeKeys(prefs, selected);
  }

  /// Copie le fichier choisi par l'utilisateur dans le dossier documents de
  /// l'app (le chemin renvoyé par `file_picker` peut être un cache temporaire
  /// non garanti de survivre à un redémarrage) et l'ajoute à la liste.
  Future<RingtoneOption> addCustomRingtone({
    required String sourcePath,
    required String label,
  }) async {
    if (_custom.length >= kMaxCustomRingtones) {
      throw RingtoneImportException(
        'Limite atteinte ($kMaxCustomRingtones sonneries importées max). '
        'Supprimez-en une pour en ajouter une nouvelle.',
      );
    }

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

    // Empreinte du contenu : identité du son entre les appareils du compte.
    // Calculée sur la copie, donc sur les octets réellement conservés.
    String? contentHash;
    try {
      contentHash = await computeContentHash(File(destPath));
    } catch (_) {
      // Import tout de même accepté : la sonnerie marche sur cet appareil, elle
      // ne pourra simplement pas être reconnue sur les autres.
      contentHash = null;
    }

    final option = RingtoneOption(
      id: id,
      label: label.trim().isEmpty ? 'Sonnerie personnalisée' : label.trim(),
      type: RingtoneSourceType.custom,
      filePath: destPath,
      contentHash: contentHash,
    );

    _custom = [..._custom, option];
    _cachedCustom = _custom;
    notifyListeners();
    await _persistCustomList();
    // Une liste qui attendait ce son (préférence synchronisée depuis un autre
    // appareil) se rebranche ici, sans que l'utilisateur refasse son choix.
    onCustomRingtonesChanged?.call();
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

    // Si la sonnerie supprimée était sélectionnée, on retombe sur la sonnerie
    // par défaut de l'app.
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

    // Les listes qui utilisaient ce son retombent sur leur son de remplacement.
    // Leur préférence synchronisée, elle, est CONSERVÉE : un autre appareil du
    // compte peut très bien posséder encore le fichier, et un réimport ici
    // rebranchera la liste tout seul.
    onCustomRingtonesChanged?.call();
  }

  Future<void> _persistCustomList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kCustomListKey,
      _custom.map((o) => jsonEncode(o.toJson())).toList(),
    );
  }
}
