import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ringtone_preferences.dart';

/// Sonneries propres aux listes de contacts, stockées sur cet appareil.
///
/// Un contact peut appartenir à plusieurs listes : la première liste dans
/// [priority] qui possède une sonnerie pour l'événement concerné gagne.
class ListRingtonePreferences extends ChangeNotifier {
  static const _settingsKey = 'list_ringtone_settings_v1';
  static const _priorityKey = 'list_ringtone_priority_v1';
  static const _membersKey = 'list_ringtone_members_v1';

  static bool _loaded = false;
  static Map<int, ListRingtoneSetting> _settings = {};
  static List<int> _priority = [];
  static Map<int, Set<int>> _members = {};

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
    _loaded = true;
  }

  Future<void> load() async {
    await preload();
    notifyListeners();
  }

  ListRingtoneSetting settingFor(int listId) =>
      _settings[listId] ?? const ListRingtoneSetting();

  Future<void> setRingtone(
    int listId, {
    String? messageRingtoneId,
    String? callRingtoneId,
  }) async {
    final old = settingFor(listId);
    _settings[listId] = ListRingtoneSetting(
      messageRingtoneId: messageRingtoneId ?? old.messageRingtoneId,
      callRingtoneId: callRingtoneId ?? old.callRingtoneId,
    );
    if (!_priority.contains(listId)) _priority.add(listId);
    await _persist();
    notifyListeners();
  }

  Future<void> reorder(List<int> orderedListIds) async {
    _priority = [...orderedListIds];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _priorityKey,
      _priority.map((id) => id.toString()).toList(),
    );
    notifyListeners();
  }

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
  }
}

@immutable
class ListRingtoneSetting {
  const ListRingtoneSetting({
    this.messageRingtoneId,
    this.callRingtoneId,
  });

  final String? messageRingtoneId;
  final String? callRingtoneId;

  factory ListRingtoneSetting.fromJson(Map<String, dynamic> json) =>
      ListRingtoneSetting(
        messageRingtoneId: json['messageRingtoneId']?.toString(),
        callRingtoneId: json['callRingtoneId']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'messageRingtoneId': messageRingtoneId,
        'callRingtoneId': callRingtoneId,
      };
}
