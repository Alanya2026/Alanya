import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'ringtone_preferences.dart';

/// Sonneries propres aux listes de contacts.
///
/// **Préférence du compte, pas de l'appareil** : le choix fait sur un appareil
/// suit l'utilisateur sur tous les autres (colonnes `*_sound_*` de
/// `contact_list`, migration serveur 055, transportées par le `GET`/`PUT`
/// /contact-lists déjà utilisé pour les listes elles-mêmes).
///
/// Deux natures de son, traitées différemment :
///  - **fourni avec l'app** (`builtin`) — l'identifiant (`notif_pop`,
///    `bundled_son3`, `__system_default__`) suffit : le fichier existe sur tous
///    les appareils.
///  - **importé par l'utilisateur** (`custom`) — le fichier audio reste LOCAL,
///    il n'est jamais envoyé au serveur. Ce qui se synchronise est son
///    identité : le SHA-256 de son contenu. Un appareil qui possède un fichier
///    de même empreinte rejoue exactement le même son ; sinon il retombe sur
///    son son de remplacement habituel, **sans que la préférence soit
///    effacée** — elle se rebranchera toute seule le jour où le fichier sera
///    importé ici aussi (voir [rebindCustomSounds]).
///
/// Chaque réglage porte donc DEUX choses par évènement :
///  - `*RingtoneId` : l'identifiant d'option valide **sur cet appareil**. C'est
///    le seul champ que relit le code natif Android quand l'app est tuée
///    (`CallIncomingHelper`, `MessageNotificationHelper`) — son format ne
///    change pas, d'où l'absence de modification côté natif. Il vaut null
///    quand le son personnalisé attendu n'est pas (encore) présent ici.
///  - `*Sound` : l'identité synchronisée, indépendante de l'appareil.
///
/// Un contact peut appartenir à plusieurs listes : la première liste dans
/// [priority] qui possède une sonnerie pour l'évènement concerné gagne. Cet
/// ordre est synchronisé lui aussi, sinon deux appareils d'accord sur les sons
/// pouvaient encore jouer des sonneries différentes pour un contact
/// multi-listes.
class ListRingtonePreferences extends ChangeNotifier {
  static const _settingsKey = 'list_ringtone_settings_v1';
  static const _priorityKey = 'list_ringtone_priority_v1';
  static const _membersKey = 'list_ringtone_members_v1';

  /// Listes dont le choix de l'utilisateur n'a pas encore pu être poussé au
  /// serveur (hors ligne, serveur injoignable). Repoussées avant d'appliquer
  /// les valeurs distantes : un choix fait hors connexion ne doit pas être
  /// écrasé par la version périmée du serveur.
  static const _pendingKey = 'list_ringtone_pending_v1';

  /// Réglages hérités de l'époque « préférence locale » : ils datent d'avant la
  /// synchronisation et sont poussés au serveur UNIQUEMENT là où il n'a encore
  /// rien. Un appareil qui se met à jour ne doit pas écraser le choix récent
  /// fait depuis un autre appareil.
  static const _legacyKey = 'list_ringtone_legacy_pending_v1';

  /// Idem pour l'ordre de priorité (booléens sérialisés en `'1'`).
  static const _pendingOrderKey = 'list_ringtone_pending_order_v1';
  static const _legacyOrderKey = 'list_ringtone_legacy_order_v1';

  static bool _loaded = false;
  static Map<int, ListRingtoneSetting> _settings = {};
  static List<int> _priority = [];
  static Map<int, Set<int>> _members = {};
  static Set<int> _pending = {};
  static Set<int> _legacyPending = {};
  static bool _pendingOrder = false;
  static bool _legacyOrder = false;

  /// Instance vivante (celle du `MultiProvider`). Même motif que
  /// `RingtonePreferences._bound` : `LocalCacheRepository` n'a pas accès aux
  /// Providers, mais doit pouvoir livrer les sonneries reçues avec les listes.
  static ListRingtonePreferences? _bound;

  final TalkyApiClient? _api;

  ListRingtonePreferences({TalkyApiClient? api}) : _api = api {
    _bound = this;
    // Un import (ou une suppression) de sonnerie change ce qui est disponible
    // ici : on rebranche aussitôt les listes concernées.
    RingtonePreferences.onCustomRingtonesChanged =
        () => unawaited(_onCustomRingtonesChanged());
  }

  Map<int, ListRingtoneSetting> get settings => Map.unmodifiable(_settings);
  List<int> get priority => List.unmodifiable(_priority);

  static Future<void> preload() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_settingsKey) ?? '{}') as Map;
      _settings = {
        for (final entry in raw.entries)
          if (int.tryParse(entry.key.toString()) != null && entry.value is Map)
            int.parse(entry.key.toString()): ListRingtoneSetting.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
      };
    } catch (_) {
      _settings = {};
    }
    _priority = (prefs.getStringList(_priorityKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    try {
      final raw = jsonDecode(prefs.getString(_membersKey) ?? '{}') as Map;
      _members = {
        for (final entry in raw.entries)
          if (int.tryParse(entry.key.toString()) != null && entry.value is List)
            int.parse(entry.key.toString()): (entry.value as List)
                .map((e) => int.tryParse(e.toString()))
                .whereType<int>()
                .toSet(),
      };
    } catch (_) {
      _members = {};
    }
    _pending = _readIdSet(prefs, _pendingKey);
    _legacyPending = _readIdSet(prefs, _legacyKey);
    _pendingOrder = prefs.getBool(_pendingOrderKey) ?? false;
    _legacyOrder = prefs.getBool(_legacyOrderKey) ?? false;
    _loaded = true;
  }

  /// Remet l'état statique à zéro (tests uniquement).
  @visibleForTesting
  static void resetForTesting() {
    _bound = null;
    _loaded = false;
    _settings = {};
    _priority = [];
    _members = {};
    _pending = {};
    _legacyPending = {};
    _pendingOrder = false;
    _legacyOrder = false;
  }

  static Set<int> _readIdSet(SharedPreferences prefs, String key) =>
      (prefs.getStringList(key) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  Future<void> load() async {
    await preload();
    await _adoptLegacyLocalChoices();
    await rebindCustomSounds(notify: false);
    notifyListeners();
  }

  /// La liste des sonneries importées vient de changer sur cet appareil.
  ///
  /// On repasse par l'adoption des choix hérités : l'empreinte d'un fichier
  /// importé avant cette version n'est calculée qu'au démarrage suivant, donc
  /// après le premier passage de [load].
  Future<void> _onCustomRingtonesChanged() async {
    await _adoptLegacyLocalChoices();
    await rebindCustomSounds();
    await _flushPending();
  }

  ListRingtoneSetting settingFor(int listId) =>
      _settings[listId] ?? const ListRingtoneSetting();

  /// Enregistre le choix de l'utilisateur pour une liste, puis le pousse au
  /// compte. Passer un identifiant vide (ou `RingtoneOption.systemId`) reste
  /// un choix explicite : « son par défaut de l'appareil ».
  Future<void> setRingtone(
    int listId, {
    String? messageRingtoneId,
    String? callRingtoneId,
  }) async {
    final old = settingFor(listId);
    final message = messageRingtoneId == null
        ? (id: old.messageRingtoneId, sound: old.messageSound)
        : _identify(messageRingtoneId);
    final call = callRingtoneId == null
        ? (id: old.callRingtoneId, sound: old.callSound)
        : _identify(callRingtoneId);

    _settings[listId] = ListRingtoneSetting(
      messageRingtoneId: message.id,
      callRingtoneId: call.id,
      messageSound: message.sound,
      callSound: call.sound,
    );
    if (!_priority.contains(listId)) {
      // Nouvelle liste en queue de file : l'ordre change, il doit suivre.
      _priority.add(listId);
      _pendingOrder = true;
    }
    _pending.add(listId);
    await _persist();
    notifyListeners();
    await _flushPending();
  }

  /// Traduit un identifiant d'option choisi dans l'interface en couple
  /// « identifiant local » + « identité synchronisable ».
  ///
  /// Pour un son importé, l'identité est l'empreinte de son contenu : c'est ce
  /// qui permettra à un autre appareil de reconnaître LE MÊME fichier, et à
  /// celui-ci seulement — un homonyme au contenu différent n'est pas le même
  /// son.
  ({String? id, ListSoundChoice? sound}) _identify(String optionId) {
    if (optionId.isEmpty) return (id: null, sound: null);

    final option = RingtonePreferences.optionById(optionId);
    if (option == null && optionId.startsWith('custom_')) {
      // Sonnerie importée qui n'existe plus ici : son identifiant local ne veut
      // rien dire ailleurs, on ne le synchronise surtout pas comme un son
      // fourni avec l'app.
      return (id: null, sound: null);
    }
    if (option == null || option.type != RingtoneSourceType.custom) {
      // Son fourni avec l'app (ou sonnerie système) : l'identifiant est déjà
      // stable et compris par tous les appareils.
      return (
        id: optionId,
        sound: ListSoundChoice(type: ListSoundType.builtin, id: optionId),
      );
    }

    final hash = option.contentHash;
    if (hash == null) {
      // Empreinte indisponible (fichier illisible au moment de l'import) : le
      // son reste utilisable ici, il ne peut simplement pas être reconnu
      // ailleurs. On n'invente pas d'identité, on ne synchronise rien.
      return (id: optionId, sound: null);
    }
    return (
      id: optionId,
      sound: ListSoundChoice(
        type: ListSoundType.custom,
        id: hash,
        name: option.label,
      ),
    );
  }

  Future<void> reorder(List<int> orderedListIds) async {
    _priority = [...orderedListIds];
    _pendingOrder = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _priorityKey,
      _priority.map((id) => id.toString()).toList(),
    );
    await prefs.setBool(_pendingOrderKey, true);
    notifyListeners();
    await _flushPending();
  }

  // ── SYNCHRONISATION ────────────────────────────────────────────────

  /// Point d'entrée de `LocalCacheRepository.syncContactLists()` : la sonnerie
  /// voyage avec la liste, sans requête supplémentaire ni second système de
  /// synchronisation.
  ///
  /// Sans instance liée (avant la construction des Providers), on ne fait
  /// rien : la synchronisation suivante repassera par là.
  static Future<void> applyServerLists(List<ContactList> lists) async {
    await _bound?.applyFromServer(lists);
  }

  /// Applique les sonneries renvoyées par le serveur avec les listes.
  Future<void> applyFromServer(List<ContactList> lists) async {
    await preload();
    // Serveur pas encore à jour (migration 055 absente) : il ne renvoie aucun
    // champ de son. Ses silences ne valent pas « aucune sonnerie » — on ne
    // touche à rien et on garde ce qui attend d'être poussé, pour que les
    // réglages repartent tels quels le jour où le backend est déployé.
    if (lists.isNotEmpty && !lists.any((list) => list.soundSyncSupported)) {
      return;
    }
    // D'abord pousser ce qui attend : un choix fait hors ligne est plus récent
    // que ce que le serveur nous renvoie ici.
    await _flushPending(lists: lists);

    var changed = false;
    for (final list in lists) {
      if (_pending.contains(list.idList)) continue; // notre version gagne
      // Réglage hérité pas encore poussé (hors ligne) : le serveur n'a rien à
      // dire dessus, et surtout rien à effacer. `_flushPending` a déjà retiré
      // de cette file les listes pour lesquelles le compte a mieux.
      if (_legacyPending.contains(list.idList)) continue;
      final remoteMessage = ListSoundChoice.fromParts(
        list.messageSoundType,
        list.messageSoundId,
        list.messageSoundName,
      );
      final remoteCall = ListSoundChoice.fromParts(
        list.callSoundType,
        list.callSoundId,
        list.callSoundName,
      );
      final old = settingFor(list.idList);
      final next = ListRingtoneSetting(
        messageRingtoneId: _localIdFor(remoteMessage),
        callRingtoneId: _localIdFor(remoteCall),
        messageSound: remoteMessage,
        callSound: remoteCall,
      );
      if (next == old) continue;
      _settings[list.idList] = next;
      // La liste a été configurée ailleurs : elle entre dans l'arbitrage.
      if (next.hasChoice && !_priority.contains(list.idList)) {
        _priority.add(list.idList);
      }
      changed = true;
    }

    // Ordre de priorité : le serveur fait foi dès qu'au moins une liste porte
    // un rang. Les listes sans rang passent après, dans l'ordre reçu.
    final ranked = lists.where((l) => l.soundPriority != null).toList()
      ..sort((a, b) => a.soundPriority!.compareTo(b.soundPriority!));
    if (ranked.isNotEmpty && !_pendingOrder) {
      final remoteOrder = [
        ...ranked.map((l) => l.idList),
        ..._priority.where(
          (id) => !ranked.any((l) => l.idList == id),
        ),
      ];
      if (!listEquals(remoteOrder, _priority)) {
        _priority = remoteOrder;
        changed = true;
      }
    } else if (ranked.isEmpty && _priority.isNotEmpty && _legacyOrder) {
      // Le compte n'a encore aucun ordre : on lui offre celui de cet appareil.
      _pendingOrder = true;
      _legacyOrder = false;
      changed = true;
    }

    if (changed) {
      await _persist();
      notifyListeners();
    }
    await _flushPending(lists: lists);
  }

  /// Identifiant d'option utilisable **sur cet appareil** pour une identité
  /// synchronisée, ou null si le fichier personnalisé attendu manque ici.
  static String? _localIdFor(ListSoundChoice? sound) {
    if (sound == null) return null;
    if (sound.type == ListSoundType.builtin) return sound.id;
    // Recherche par empreinte : ni le nom du fichier, ni l'identifiant local de
    // l'appareil d'origine ne veulent dire quoi que ce soit ici.
    return RingtonePreferences.customByContentHash(sound.id)?.id;
  }

  /// Rebranche les listes dont le son personnalisé vient d'apparaître ou de
  /// disparaître sur cet appareil (import, réimport, suppression).
  ///
  /// C'est ce qui évite à l'utilisateur de refaire sa sélection : il importe le
  /// bon fichier, la liste le retrouve à l'empreinte. L'identité synchronisée
  /// n'est jamais effacée ici — une absence locale n'est pas un renoncement.
  Future<void> rebindCustomSounds({bool notify = true}) async {
    await preload();
    var changed = false;
    for (final entry in _settings.entries.toList()) {
      final setting = entry.value;
      final message = setting.messageSound;
      final call = setting.callSound;
      if (message?.type != ListSoundType.custom &&
          call?.type != ListSoundType.custom) {
        continue;
      }
      final next = ListRingtoneSetting(
        messageRingtoneId: message?.type == ListSoundType.custom
            ? _localIdFor(message)
            : setting.messageRingtoneId,
        callRingtoneId: call?.type == ListSoundType.custom
            ? _localIdFor(call)
            : setting.callRingtoneId,
        messageSound: message,
        callSound: call,
      );
      if (next == setting) continue;
      _settings[entry.key] = next;
      changed = true;
    }
    if (!changed) return;
    await _persist();
    if (notify) notifyListeners();
  }

  /// Donne une identité synchronisable aux réglages faits avant l'arrivée de
  /// la synchronisation (ils n'avaient qu'un identifiant local). Ils seront
  /// proposés au serveur là où il n'a encore rien — jamais par-dessus un choix
  /// venu d'un autre appareil.
  Future<void> _adoptLegacyLocalChoices() async {
    var changed = false;
    for (final entry in _settings.entries.toList()) {
      final setting = entry.value;
      // Évènement par évènement : un réglage peut très bien avoir déjà adopté
      // son son de message (fourni avec l'app) et attendre encore l'empreinte
      // de sa sonnerie d'appel importée.
      final message = setting.messageSound == null &&
              setting.messageRingtoneId != null
          ? _identify(setting.messageRingtoneId!)
          : (id: setting.messageRingtoneId, sound: setting.messageSound);
      final call =
          setting.callSound == null && setting.callRingtoneId != null
              ? _identify(setting.callRingtoneId!)
              : (id: setting.callRingtoneId, sound: setting.callSound);

      final next = ListRingtoneSetting(
        messageRingtoneId: message.id,
        callRingtoneId: call.id,
        messageSound: message.sound,
        callSound: call.sound,
      );
      if (next == setting) continue;
      _settings[entry.key] = next;
      if (next.hasChoice) _legacyPending.add(entry.key);
      changed = true;
    }
    if (_priority.isNotEmpty && _legacyPending.isNotEmpty) _legacyOrder = true;
    if (!changed) return;
    await _persist();
  }

  /// Pousse au serveur les choix en attente. Silencieux en cas d'échec : la
  /// liste reste marquée et repartira à la prochaine synchronisation — c'est ce
  /// qui rend le réglage utilisable hors connexion.
  Future<void> _flushPending({List<ContactList>? lists}) async {
    final api = _api;
    if (api == null) return;
    if (_pending.isEmpty && _legacyPending.isEmpty && !_pendingOrder) return;

    for (final listId in {..._pending}) {
      if (await _push(api, listId)) _pending.remove(listId);
    }

    // Héritage local : uniquement là où le compte n'a encore aucun choix.
    for (final listId in {..._legacyPending}) {
      final remote = _findList(lists, listId);
      if (remote == null) continue; // on attend d'avoir vu la liste côté serveur
      if (remote.messageSoundId != null || remote.callSoundId != null) {
        _legacyPending.remove(listId); // le serveur a déjà mieux : on s'efface
        continue;
      }
      if (await _push(api, listId)) _legacyPending.remove(listId);
    }

    if (_pendingOrder && _priority.isNotEmpty) {
      try {
        await api.updateContactListSoundOrder(_priority);
        _pendingOrder = false;
      } catch (e) {
        debugPrint('[ListRingtone] ordre non synchronisé: $e');
      }
    }

    await _persistFlags();
  }

  static ContactList? _findList(List<ContactList>? lists, int listId) {
    if (lists == null) return null;
    for (final list in lists) {
      if (list.idList == listId) return list;
    }
    return null;
  }

  Future<bool> _push(TalkyApiClient api, int listId) async {
    final setting = settingFor(listId);
    try {
      await api.updateContactListSounds(listId, {
        'messageSoundType': setting.messageSound?.type.wire,
        'messageSoundId': setting.messageSound?.id,
        'messageSoundName': setting.messageSound?.name,
        'callSoundType': setting.callSound?.type.wire,
        'callSoundId': setting.callSound?.id,
        'callSoundName': setting.callSound?.name,
      });
      return true;
    } catch (e) {
      debugPrint('[ListRingtone] sonneries de la liste $listId non poussées: $e');
      return false;
    }
  }

  // ── APPARTENANCES ET RÉSOLUTION ────────────────────────────────────

  static Future<void> updateMemberships(
    Map<int, Set<int>> membersByList,
  ) async {
    await preload();
    _members = {
      for (final entry in membersByList.entries) entry.key: {...entry.value},
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _membersKey,
      jsonEncode({
        for (final entry in _members.entries)
          entry.key.toString(): entry.value.toList(),
      }),
    );
  }

  static RingtoneOption? resolveMessage(int contactId) =>
      _resolve(contactId, message: true);

  static RingtoneOption? resolveCall(int contactId) =>
      _resolve(contactId, message: false);

  /// Sonnerie à jouer pour un contact, ou null pour « rien de particulier » —
  /// l'appelant retombe alors sur son comportement habituel (son de réception
  /// standard, sonnerie choisie globalement…). C'est aussi ce qui se passe
  /// quand la liste attend un son personnalisé absent de cet appareil :
  /// remplacement provisoire, préférence conservée.
  static RingtoneOption? _resolve(int contactId, {required bool message}) {
    final ordered = <int>[
      ..._priority,
      ..._settings.keys.where((id) => !_priority.contains(id)),
    ];
    for (final listId in ordered) {
      if (!(_members[listId]?.contains(contactId) ?? false)) continue;
      final setting = _settings[listId];
      final ringtoneId = message
          ? setting?.messageRingtoneId
          : setting?.callRingtoneId;
      if (ringtoneId == null || ringtoneId.isEmpty) continue;
      return RingtonePreferences.optionById(ringtoneId);
    }
    return null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settingsKey,
      jsonEncode({
        for (final entry in _settings.entries)
          entry.key.toString(): entry.value.toJson(),
      }),
    );
    await prefs.setStringList(
      _priorityKey,
      _priority.map((id) => id.toString()).toList(),
    );
    await _persistFlags(prefs);
  }

  Future<void> _persistFlags([SharedPreferences? prefsArg]) async {
    final prefs = prefsArg ?? await SharedPreferences.getInstance();
    await prefs.setStringList(
      _pendingKey,
      _pending.map((id) => id.toString()).toList(),
    );
    await prefs.setStringList(
      _legacyKey,
      _legacyPending.map((id) => id.toString()).toList(),
    );
    await prefs.setBool(_pendingOrderKey, _pendingOrder);
    await prefs.setBool(_legacyOrderKey, _legacyOrder);
  }
}

/// Nature d'un son choisi pour une liste.
enum ListSoundType {
  /// Son fourni avec l'application : présent sur tous les appareils, identifié
  /// par son identifiant stable (`notif_pop`, `bundled_son3`, `__system_default__`).
  builtin('builtin'),

  /// Son importé par l'utilisateur : le fichier reste sur l'appareil, seule son
  /// empreinte SHA-256 circule.
  custom('custom');

  const ListSoundType(this.wire);

  /// Valeur échangée avec le serveur (colonnes `*_sound_type`).
  final String wire;

  static ListSoundType? fromWire(String? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// Identité d'un son, indépendante de l'appareil — c'est ce qui se synchronise.
@immutable
class ListSoundChoice {
  const ListSoundChoice({required this.type, required this.id, this.name});

  final ListSoundType type;

  /// Identifiant du son fourni, ou SHA-256 du contenu du fichier importé.
  final String id;

  /// Nom du fichier importé, **pour l'affichage seulement**. Deux fichiers de
  /// même nom et de contenu différent restent deux sons différents : seul [id]
  /// fait foi.
  final String? name;

  static ListSoundChoice? fromParts(String? type, String? id, String? name) {
    final kind = ListSoundType.fromWire(type);
    if (kind == null || id == null || id.isEmpty) return null;
    return ListSoundChoice(type: kind, id: id, name: name);
  }

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'id': id,
        if (name != null) 'name': name,
      };

  static ListSoundChoice? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    return fromParts(
      raw['type']?.toString(),
      raw['id']?.toString(),
      raw['name']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListSoundChoice &&
      other.type == type &&
      other.id == id &&
      other.name == name;

  @override
  int get hashCode => Object.hash(type, id, name);
}

/// Réglage d'une liste : ce qui est jouable ICI, et ce qui est partagé avec les
/// autres appareils du compte.
@immutable
class ListRingtoneSetting {
  const ListRingtoneSetting({
    this.messageRingtoneId,
    this.callRingtoneId,
    this.messageSound,
    this.callSound,
  });

  /// Identifiant d'option valide **sur cet appareil**, seul champ relu par le
  /// code natif Android quand l'app est tuée. Null quand le son personnalisé
  /// attendu (voir [messageSound]) n'est pas présent ici.
  final String? messageRingtoneId;
  final String? callRingtoneId;

  /// Identité synchronisée du son, conservée même quand le fichier manque sur
  /// cet appareil — c'est elle qui permet le rebranchement automatique après
  /// un import ultérieur.
  final ListSoundChoice? messageSound;
  final ListSoundChoice? callSound;

  bool get hasChoice => messageSound != null || callSound != null;

  /// Le son de message est un fichier importé, absent de cet appareil : une
  /// sonnerie de remplacement est jouée en attendant qu'il soit importé ici.
  bool get messageSoundMissing =>
      messageSound?.type == ListSoundType.custom && messageRingtoneId == null;

  bool get callSoundMissing =>
      callSound?.type == ListSoundType.custom && callRingtoneId == null;

  factory ListRingtoneSetting.fromJson(Map<String, dynamic> json) =>
      ListRingtoneSetting(
        messageRingtoneId: _text(json['messageRingtoneId']),
        callRingtoneId: _text(json['callRingtoneId']),
        messageSound: ListSoundChoice.fromJson(json['messageSound']),
        callSound: ListSoundChoice.fromJson(json['callSound']),
      );

  static String? _text(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString();
    return value.isEmpty ? null : value;
  }

  Map<String, dynamic> toJson() => {
        // Clé historique, relue telle quelle par le natif Android : format
        // inchangé, et toujours écrite en premier.
        'messageRingtoneId': messageRingtoneId,
        'callRingtoneId': callRingtoneId,
        'messageSound': messageSound?.toJson(),
        'callSound': callSound?.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      other is ListRingtoneSetting &&
      other.messageRingtoneId == messageRingtoneId &&
      other.callRingtoneId == callRingtoneId &&
      other.messageSound == messageSound &&
      other.callSound == callSound;

  @override
  int get hashCode => Object.hash(
        messageRingtoneId,
        callRingtoneId,
        messageSound,
        callSound,
      );
}
