// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalConversationsTable extends LocalConversations
    with TableInfo<$LocalConversationsTable, LocalConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversIDMeta = const VerificationMeta(
    'conversID',
  );
  @override
  late final GeneratedColumn<int> conversID = GeneratedColumn<int>(
    'convers_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isGroupMeta = const VerificationMeta(
    'isGroup',
  );
  @override
  late final GeneratedColumn<bool> isGroup = GeneratedColumn<bool>(
    'is_group',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_group" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupPhotoMeta = const VerificationMeta(
    'groupPhoto',
  );
  @override
  late final GeneratedColumn<String> groupPhoto = GeneratedColumn<String>(
    'group_photo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageMeta = const VerificationMeta(
    'lastMessage',
  );
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
    'last_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageAtMeta = const VerificationMeta(
    'lastMessageAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastMessageAt =
      GeneratedColumn<DateTime>(
        'last_message_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageSenderIDMeta =
      const VerificationMeta('lastMessageSenderID');
  @override
  late final GeneratedColumn<int> lastMessageSenderID = GeneratedColumn<int>(
    'last_message_sender_i_d',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageTypeMeta = const VerificationMeta(
    'lastMessageType',
  );
  @override
  late final GeneratedColumn<int> lastMessageType = GeneratedColumn<int>(
    'last_message_type',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageStatusMeta = const VerificationMeta(
    'lastMessageStatus',
  );
  @override
  late final GeneratedColumn<int> lastMessageStatus = GeneratedColumn<int>(
    'last_message_status',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _participantsJsonMeta = const VerificationMeta(
    'participantsJson',
  );
  @override
  late final GeneratedColumn<String> participantsJson = GeneratedColumn<String>(
    'participants_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversID,
    isGroup,
    groupName,
    groupPhoto,
    lastMessage,
    lastMessageAt,
    lastMessageSenderID,
    lastMessageType,
    lastMessageStatus,
    unreadCount,
    isPinned,
    isArchived,
    participantsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('convers_i_d')) {
      context.handle(
        _conversIDMeta,
        conversID.isAcceptableOrUnknown(data['convers_i_d']!, _conversIDMeta),
      );
    }
    if (data.containsKey('is_group')) {
      context.handle(
        _isGroupMeta,
        isGroup.isAcceptableOrUnknown(data['is_group']!, _isGroupMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('group_photo')) {
      context.handle(
        _groupPhotoMeta,
        groupPhoto.isAcceptableOrUnknown(data['group_photo']!, _groupPhotoMeta),
      );
    }
    if (data.containsKey('last_message')) {
      context.handle(
        _lastMessageMeta,
        lastMessage.isAcceptableOrUnknown(
          data['last_message']!,
          _lastMessageMeta,
        ),
      );
    }
    if (data.containsKey('last_message_at')) {
      context.handle(
        _lastMessageAtMeta,
        lastMessageAt.isAcceptableOrUnknown(
          data['last_message_at']!,
          _lastMessageAtMeta,
        ),
      );
    }
    if (data.containsKey('last_message_sender_i_d')) {
      context.handle(
        _lastMessageSenderIDMeta,
        lastMessageSenderID.isAcceptableOrUnknown(
          data['last_message_sender_i_d']!,
          _lastMessageSenderIDMeta,
        ),
      );
    }
    if (data.containsKey('last_message_type')) {
      context.handle(
        _lastMessageTypeMeta,
        lastMessageType.isAcceptableOrUnknown(
          data['last_message_type']!,
          _lastMessageTypeMeta,
        ),
      );
    }
    if (data.containsKey('last_message_status')) {
      context.handle(
        _lastMessageStatusMeta,
        lastMessageStatus.isAcceptableOrUnknown(
          data['last_message_status']!,
          _lastMessageStatusMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('participants_json')) {
      context.handle(
        _participantsJsonMeta,
        participantsJson.isAcceptableOrUnknown(
          data['participants_json']!,
          _participantsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversID};
  @override
  LocalConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConversation(
      conversID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}convers_i_d'],
      )!,
      isGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_group'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      groupPhoto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_photo'],
      ),
      lastMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message'],
      ),
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_at'],
      ),
      lastMessageSenderID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_sender_i_d'],
      ),
      lastMessageType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_type'],
      ),
      lastMessageStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_message_status'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      participantsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participants_json'],
      )!,
    );
  }

  @override
  $LocalConversationsTable createAlias(String alias) {
    return $LocalConversationsTable(attachedDatabase, alias);
  }
}

class LocalConversation extends DataClass
    implements Insertable<LocalConversation> {
  final int conversID;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int? lastMessageSenderID;
  final int? lastMessageType;
  final int? lastMessageStatus;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final String participantsJson;
  const LocalConversation({
    required this.conversID,
    required this.isGroup,
    this.groupName,
    this.groupPhoto,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderID,
    this.lastMessageType,
    this.lastMessageStatus,
    required this.unreadCount,
    required this.isPinned,
    required this.isArchived,
    required this.participantsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['convers_i_d'] = Variable<int>(conversID);
    map['is_group'] = Variable<bool>(isGroup);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    if (!nullToAbsent || groupPhoto != null) {
      map['group_photo'] = Variable<String>(groupPhoto);
    }
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    if (!nullToAbsent || lastMessageSenderID != null) {
      map['last_message_sender_i_d'] = Variable<int>(lastMessageSenderID);
    }
    if (!nullToAbsent || lastMessageType != null) {
      map['last_message_type'] = Variable<int>(lastMessageType);
    }
    if (!nullToAbsent || lastMessageStatus != null) {
      map['last_message_status'] = Variable<int>(lastMessageStatus);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_archived'] = Variable<bool>(isArchived);
    map['participants_json'] = Variable<String>(participantsJson);
    return map;
  }

  LocalConversationsCompanion toCompanion(bool nullToAbsent) {
    return LocalConversationsCompanion(
      conversID: Value(conversID),
      isGroup: Value(isGroup),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      groupPhoto: groupPhoto == null && nullToAbsent
          ? const Value.absent()
          : Value(groupPhoto),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      lastMessageSenderID: lastMessageSenderID == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageSenderID),
      lastMessageType: lastMessageType == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageType),
      lastMessageStatus: lastMessageStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageStatus),
      unreadCount: Value(unreadCount),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
      participantsJson: Value(participantsJson),
    );
  }

  factory LocalConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConversation(
      conversID: serializer.fromJson<int>(json['conversID']),
      isGroup: serializer.fromJson<bool>(json['isGroup']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      groupPhoto: serializer.fromJson<String?>(json['groupPhoto']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      lastMessageSenderID: serializer.fromJson<int?>(
        json['lastMessageSenderID'],
      ),
      lastMessageType: serializer.fromJson<int?>(json['lastMessageType']),
      lastMessageStatus: serializer.fromJson<int?>(json['lastMessageStatus']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      participantsJson: serializer.fromJson<String>(json['participantsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversID': serializer.toJson<int>(conversID),
      'isGroup': serializer.toJson<bool>(isGroup),
      'groupName': serializer.toJson<String?>(groupName),
      'groupPhoto': serializer.toJson<String?>(groupPhoto),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'lastMessageSenderID': serializer.toJson<int?>(lastMessageSenderID),
      'lastMessageType': serializer.toJson<int?>(lastMessageType),
      'lastMessageStatus': serializer.toJson<int?>(lastMessageStatus),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isArchived': serializer.toJson<bool>(isArchived),
      'participantsJson': serializer.toJson<String>(participantsJson),
    };
  }

  LocalConversation copyWith({
    int? conversID,
    bool? isGroup,
    Value<String?> groupName = const Value.absent(),
    Value<String?> groupPhoto = const Value.absent(),
    Value<String?> lastMessage = const Value.absent(),
    Value<DateTime?> lastMessageAt = const Value.absent(),
    Value<int?> lastMessageSenderID = const Value.absent(),
    Value<int?> lastMessageType = const Value.absent(),
    Value<int?> lastMessageStatus = const Value.absent(),
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    String? participantsJson,
  }) => LocalConversation(
    conversID: conversID ?? this.conversID,
    isGroup: isGroup ?? this.isGroup,
    groupName: groupName.present ? groupName.value : this.groupName,
    groupPhoto: groupPhoto.present ? groupPhoto.value : this.groupPhoto,
    lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    lastMessageSenderID: lastMessageSenderID.present
        ? lastMessageSenderID.value
        : this.lastMessageSenderID,
    lastMessageType: lastMessageType.present
        ? lastMessageType.value
        : this.lastMessageType,
    lastMessageStatus: lastMessageStatus.present
        ? lastMessageStatus.value
        : this.lastMessageStatus,
    unreadCount: unreadCount ?? this.unreadCount,
    isPinned: isPinned ?? this.isPinned,
    isArchived: isArchived ?? this.isArchived,
    participantsJson: participantsJson ?? this.participantsJson,
  );
  LocalConversation copyWithCompanion(LocalConversationsCompanion data) {
    return LocalConversation(
      conversID: data.conversID.present ? data.conversID.value : this.conversID,
      isGroup: data.isGroup.present ? data.isGroup.value : this.isGroup,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      groupPhoto: data.groupPhoto.present
          ? data.groupPhoto.value
          : this.groupPhoto,
      lastMessage: data.lastMessage.present
          ? data.lastMessage.value
          : this.lastMessage,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      lastMessageSenderID: data.lastMessageSenderID.present
          ? data.lastMessageSenderID.value
          : this.lastMessageSenderID,
      lastMessageType: data.lastMessageType.present
          ? data.lastMessageType.value
          : this.lastMessageType,
      lastMessageStatus: data.lastMessageStatus.present
          ? data.lastMessageStatus.value
          : this.lastMessageStatus,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      participantsJson: data.participantsJson.present
          ? data.participantsJson.value
          : this.participantsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversation(')
          ..write('conversID: $conversID, ')
          ..write('isGroup: $isGroup, ')
          ..write('groupName: $groupName, ')
          ..write('groupPhoto: $groupPhoto, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessageSenderID: $lastMessageSenderID, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageStatus: $lastMessageStatus, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('participantsJson: $participantsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conversID,
    isGroup,
    groupName,
    groupPhoto,
    lastMessage,
    lastMessageAt,
    lastMessageSenderID,
    lastMessageType,
    lastMessageStatus,
    unreadCount,
    isPinned,
    isArchived,
    participantsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConversation &&
          other.conversID == this.conversID &&
          other.isGroup == this.isGroup &&
          other.groupName == this.groupName &&
          other.groupPhoto == this.groupPhoto &&
          other.lastMessage == this.lastMessage &&
          other.lastMessageAt == this.lastMessageAt &&
          other.lastMessageSenderID == this.lastMessageSenderID &&
          other.lastMessageType == this.lastMessageType &&
          other.lastMessageStatus == this.lastMessageStatus &&
          other.unreadCount == this.unreadCount &&
          other.isPinned == this.isPinned &&
          other.isArchived == this.isArchived &&
          other.participantsJson == this.participantsJson);
}

class LocalConversationsCompanion extends UpdateCompanion<LocalConversation> {
  final Value<int> conversID;
  final Value<bool> isGroup;
  final Value<String?> groupName;
  final Value<String?> groupPhoto;
  final Value<String?> lastMessage;
  final Value<DateTime?> lastMessageAt;
  final Value<int?> lastMessageSenderID;
  final Value<int?> lastMessageType;
  final Value<int?> lastMessageStatus;
  final Value<int> unreadCount;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<String> participantsJson;
  const LocalConversationsCompanion({
    this.conversID = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.groupName = const Value.absent(),
    this.groupPhoto = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastMessageSenderID = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.lastMessageStatus = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.participantsJson = const Value.absent(),
  });
  LocalConversationsCompanion.insert({
    this.conversID = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.groupName = const Value.absent(),
    this.groupPhoto = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.lastMessageSenderID = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.lastMessageStatus = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.participantsJson = const Value.absent(),
  });
  static Insertable<LocalConversation> custom({
    Expression<int>? conversID,
    Expression<bool>? isGroup,
    Expression<String>? groupName,
    Expression<String>? groupPhoto,
    Expression<String>? lastMessage,
    Expression<DateTime>? lastMessageAt,
    Expression<int>? lastMessageSenderID,
    Expression<int>? lastMessageType,
    Expression<int>? lastMessageStatus,
    Expression<int>? unreadCount,
    Expression<bool>? isPinned,
    Expression<bool>? isArchived,
    Expression<String>? participantsJson,
  }) {
    return RawValuesInsertable({
      if (conversID != null) 'convers_i_d': conversID,
      if (isGroup != null) 'is_group': isGroup,
      if (groupName != null) 'group_name': groupName,
      if (groupPhoto != null) 'group_photo': groupPhoto,
      if (lastMessage != null) 'last_message': lastMessage,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (lastMessageSenderID != null)
        'last_message_sender_i_d': lastMessageSenderID,
      if (lastMessageType != null) 'last_message_type': lastMessageType,
      if (lastMessageStatus != null) 'last_message_status': lastMessageStatus,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isArchived != null) 'is_archived': isArchived,
      if (participantsJson != null) 'participants_json': participantsJson,
    });
  }

  LocalConversationsCompanion copyWith({
    Value<int>? conversID,
    Value<bool>? isGroup,
    Value<String?>? groupName,
    Value<String?>? groupPhoto,
    Value<String?>? lastMessage,
    Value<DateTime?>? lastMessageAt,
    Value<int?>? lastMessageSenderID,
    Value<int?>? lastMessageType,
    Value<int?>? lastMessageStatus,
    Value<int>? unreadCount,
    Value<bool>? isPinned,
    Value<bool>? isArchived,
    Value<String>? participantsJson,
  }) {
    return LocalConversationsCompanion(
      conversID: conversID ?? this.conversID,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupPhoto: groupPhoto ?? this.groupPhoto,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderID: lastMessageSenderID ?? this.lastMessageSenderID,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageStatus: lastMessageStatus ?? this.lastMessageStatus,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      participantsJson: participantsJson ?? this.participantsJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversID.present) {
      map['convers_i_d'] = Variable<int>(conversID.value);
    }
    if (isGroup.present) {
      map['is_group'] = Variable<bool>(isGroup.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (groupPhoto.present) {
      map['group_photo'] = Variable<String>(groupPhoto.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (lastMessageSenderID.present) {
      map['last_message_sender_i_d'] = Variable<int>(lastMessageSenderID.value);
    }
    if (lastMessageType.present) {
      map['last_message_type'] = Variable<int>(lastMessageType.value);
    }
    if (lastMessageStatus.present) {
      map['last_message_status'] = Variable<int>(lastMessageStatus.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (participantsJson.present) {
      map['participants_json'] = Variable<String>(participantsJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversationsCompanion(')
          ..write('conversID: $conversID, ')
          ..write('isGroup: $isGroup, ')
          ..write('groupName: $groupName, ')
          ..write('groupPhoto: $groupPhoto, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('lastMessageSenderID: $lastMessageSenderID, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageStatus: $lastMessageStatus, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('participantsJson: $participantsJson')
          ..write(')'))
        .toString();
  }
}

class $LocalMessagesTable extends LocalMessages
    with TableInfo<$LocalMessagesTable, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _msgIDMeta = const VerificationMeta('msgID');
  @override
  late final GeneratedColumn<int> msgID = GeneratedColumn<int>(
    'msg_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _conversationIDMeta = const VerificationMeta(
    'conversationID',
  );
  @override
  late final GeneratedColumn<int> conversationID = GeneratedColumn<int>(
    'conversation_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIDMeta = const VerificationMeta(
    'senderID',
  );
  @override
  late final GeneratedColumn<int> senderID = GeneratedColumn<int>(
    'sender_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sendAtMeta = const VerificationMeta('sendAt');
  @override
  late final GeneratedColumn<DateTime> sendAt = GeneratedColumn<DateTime>(
    'send_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveredAtMeta = const VerificationMeta(
    'deliveredAt',
  );
  @override
  late final GeneratedColumn<DateTime> deliveredAt = GeneratedColumn<DateTime>(
    'delivered_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaUrlMeta = const VerificationMeta(
    'mediaUrl',
  );
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
    'media_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaNameMeta = const VerificationMeta(
    'mediaName',
  );
  @override
  late final GeneratedColumn<String> mediaName = GeneratedColumn<String>(
    'media_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaDurationMeta = const VerificationMeta(
    'mediaDuration',
  );
  @override
  late final GeneratedColumn<int> mediaDuration = GeneratedColumn<int>(
    'media_duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localMediaPathMeta = const VerificationMeta(
    'localMediaPath',
  );
  @override
  late final GeneratedColumn<String> localMediaPath = GeneratedColumn<String>(
    'local_media_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingUploadPathMeta = const VerificationMeta(
    'pendingUploadPath',
  );
  @override
  late final GeneratedColumn<String> pendingUploadPath =
      GeneratedColumn<String>(
        'pending_upload_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _replyToIDMeta = const VerificationMeta(
    'replyToID',
  );
  @override
  late final GeneratedColumn<int> replyToID = GeneratedColumn<int>(
    'reply_to_i_d',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToContentMeta = const VerificationMeta(
    'replyToContent',
  );
  @override
  late final GeneratedColumn<String> replyToContent = GeneratedColumn<String>(
    'reply_to_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEditedMeta = const VerificationMeta(
    'isEdited',
  );
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
    'is_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _editedAtMeta = const VerificationMeta(
    'editedAt',
  );
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
    'edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedForIDMeta = const VerificationMeta(
    'deletedForID',
  );
  @override
  late final GeneratedColumn<int> deletedForID = GeneratedColumn<int>(
    'deleted_for_i_d',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isStatusReplyMeta = const VerificationMeta(
    'isStatusReply',
  );
  @override
  late final GeneratedColumn<int> isStatusReply = GeneratedColumn<int>(
    'is_status_reply',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isForwardedMeta = const VerificationMeta(
    'isForwarded',
  );
  @override
  late final GeneratedColumn<bool> isForwarded = GeneratedColumn<bool>(
    'is_forwarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_forwarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isViewOnceMeta = const VerificationMeta(
    'isViewOnce',
  );
  @override
  late final GeneratedColumn<bool> isViewOnce = GeneratedColumn<bool>(
    'is_view_once',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_view_once" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _viewedAtMeta = const VerificationMeta(
    'viewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> viewedAt = GeneratedColumn<DateTime>(
    'viewed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderNomMeta = const VerificationMeta(
    'senderNom',
  );
  @override
  late final GeneratedColumn<String> senderNom = GeneratedColumn<String>(
    'sender_nom',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderPseudoMeta = const VerificationMeta(
    'senderPseudo',
  );
  @override
  late final GeneratedColumn<String> senderPseudo = GeneratedColumn<String>(
    'sender_pseudo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderAvatarMeta = const VerificationMeta(
    'senderAvatar',
  );
  @override
  late final GeneratedColumn<String> senderAvatar = GeneratedColumn<String>(
    'sender_avatar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastEmittedAtMeta = const VerificationMeta(
    'lastEmittedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastEmittedAt =
      GeneratedColumn<DateTime>(
        'last_emitted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientId,
    msgID,
    conversationID,
    senderID,
    content,
    type,
    status,
    sendAt,
    deliveredAt,
    readAt,
    mediaUrl,
    mediaName,
    mediaDuration,
    localMediaPath,
    pendingUploadPath,
    replyToID,
    replyToContent,
    isEdited,
    editedAt,
    isDeleted,
    deletedForID,
    isStatusReply,
    isForwarded,
    isPinned,
    isViewOnce,
    viewedAt,
    senderNom,
    senderPseudo,
    senderAvatar,
    syncPending,
    lastEmittedAt,
    retryCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('msg_i_d')) {
      context.handle(
        _msgIDMeta,
        msgID.isAcceptableOrUnknown(data['msg_i_d']!, _msgIDMeta),
      );
    }
    if (data.containsKey('conversation_i_d')) {
      context.handle(
        _conversationIDMeta,
        conversationID.isAcceptableOrUnknown(
          data['conversation_i_d']!,
          _conversationIDMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIDMeta);
    }
    if (data.containsKey('sender_i_d')) {
      context.handle(
        _senderIDMeta,
        senderID.isAcceptableOrUnknown(data['sender_i_d']!, _senderIDMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIDMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('send_at')) {
      context.handle(
        _sendAtMeta,
        sendAt.isAcceptableOrUnknown(data['send_at']!, _sendAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sendAtMeta);
    }
    if (data.containsKey('delivered_at')) {
      context.handle(
        _deliveredAtMeta,
        deliveredAt.isAcceptableOrUnknown(
          data['delivered_at']!,
          _deliveredAtMeta,
        ),
      );
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    }
    if (data.containsKey('media_url')) {
      context.handle(
        _mediaUrlMeta,
        mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta),
      );
    }
    if (data.containsKey('media_name')) {
      context.handle(
        _mediaNameMeta,
        mediaName.isAcceptableOrUnknown(data['media_name']!, _mediaNameMeta),
      );
    }
    if (data.containsKey('media_duration')) {
      context.handle(
        _mediaDurationMeta,
        mediaDuration.isAcceptableOrUnknown(
          data['media_duration']!,
          _mediaDurationMeta,
        ),
      );
    }
    if (data.containsKey('local_media_path')) {
      context.handle(
        _localMediaPathMeta,
        localMediaPath.isAcceptableOrUnknown(
          data['local_media_path']!,
          _localMediaPathMeta,
        ),
      );
    }
    if (data.containsKey('pending_upload_path')) {
      context.handle(
        _pendingUploadPathMeta,
        pendingUploadPath.isAcceptableOrUnknown(
          data['pending_upload_path']!,
          _pendingUploadPathMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_i_d')) {
      context.handle(
        _replyToIDMeta,
        replyToID.isAcceptableOrUnknown(data['reply_to_i_d']!, _replyToIDMeta),
      );
    }
    if (data.containsKey('reply_to_content')) {
      context.handle(
        _replyToContentMeta,
        replyToContent.isAcceptableOrUnknown(
          data['reply_to_content']!,
          _replyToContentMeta,
        ),
      );
    }
    if (data.containsKey('is_edited')) {
      context.handle(
        _isEditedMeta,
        isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta),
      );
    }
    if (data.containsKey('edited_at')) {
      context.handle(
        _editedAtMeta,
        editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_for_i_d')) {
      context.handle(
        _deletedForIDMeta,
        deletedForID.isAcceptableOrUnknown(
          data['deleted_for_i_d']!,
          _deletedForIDMeta,
        ),
      );
    }
    if (data.containsKey('is_status_reply')) {
      context.handle(
        _isStatusReplyMeta,
        isStatusReply.isAcceptableOrUnknown(
          data['is_status_reply']!,
          _isStatusReplyMeta,
        ),
      );
    }
    if (data.containsKey('is_forwarded')) {
      context.handle(
        _isForwardedMeta,
        isForwarded.isAcceptableOrUnknown(
          data['is_forwarded']!,
          _isForwardedMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_view_once')) {
      context.handle(
        _isViewOnceMeta,
        isViewOnce.isAcceptableOrUnknown(
          data['is_view_once']!,
          _isViewOnceMeta,
        ),
      );
    }
    if (data.containsKey('viewed_at')) {
      context.handle(
        _viewedAtMeta,
        viewedAt.isAcceptableOrUnknown(data['viewed_at']!, _viewedAtMeta),
      );
    }
    if (data.containsKey('sender_nom')) {
      context.handle(
        _senderNomMeta,
        senderNom.isAcceptableOrUnknown(data['sender_nom']!, _senderNomMeta),
      );
    }
    if (data.containsKey('sender_pseudo')) {
      context.handle(
        _senderPseudoMeta,
        senderPseudo.isAcceptableOrUnknown(
          data['sender_pseudo']!,
          _senderPseudoMeta,
        ),
      );
    }
    if (data.containsKey('sender_avatar')) {
      context.handle(
        _senderAvatarMeta,
        senderAvatar.isAcceptableOrUnknown(
          data['sender_avatar']!,
          _senderAvatarMeta,
        ),
      );
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    if (data.containsKey('last_emitted_at')) {
      context.handle(
        _lastEmittedAtMeta,
        lastEmittedAt.isAcceptableOrUnknown(
          data['last_emitted_at']!,
          _lastEmittedAtMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      msgID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}msg_i_d'],
      )!,
      conversationID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_i_d'],
      )!,
      senderID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sender_i_d'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      sendAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}send_at'],
      )!,
      deliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}delivered_at'],
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
      mediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_url'],
      ),
      mediaName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_name'],
      ),
      mediaDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_duration'],
      ),
      localMediaPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_media_path'],
      ),
      pendingUploadPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_upload_path'],
      ),
      replyToID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reply_to_i_d'],
      ),
      replyToContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_content'],
      ),
      isEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_edited'],
      )!,
      editedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}edited_at'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedForID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_for_i_d'],
      ),
      isStatusReply: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_status_reply'],
      )!,
      isForwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_forwarded'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isViewOnce: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_view_once'],
      )!,
      viewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}viewed_at'],
      ),
      senderNom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_nom'],
      ),
      senderPseudo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_pseudo'],
      ),
      senderAvatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_avatar'],
      ),
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
      lastEmittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_emitted_at'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
    );
  }

  @override
  $LocalMessagesTable createAlias(String alias) {
    return $LocalMessagesTable(attachedDatabase, alias);
  }
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final String clientId;

  /// `msgID` serveur — 0 tant que le message n'est pas confirmé.
  final int msgID;
  final int conversationID;
  final int senderID;
  final String? content;

  /// 0=texte 1=image 2=vidéo 3=audio 4=fichier 5=localisation
  final int type;

  /// 0=sending 1=sent 2=delivered 3=read 4=failed
  final int status;
  final DateTime sendAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? mediaUrl;
  final String? mediaName;
  final int? mediaDuration;

  /// Chemin du média téléchargé/mis en cache localement (consultable offline).
  final String? localMediaPath;

  /// Chemin du fichier local à uploader (envoi offline d'un média).
  final String? pendingUploadPath;
  final int? replyToID;
  final String? replyToContent;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;

  /// alanyaID de l'utilisateur pour qui le message est masqué (suppression "pour moi").
  final int? deletedForID;
  final int isStatusReply;
  final bool isForwarded;

  /// Message épinglé dans la conversation (visible de tous les participants).
  final bool isPinned;

  /// Média à vue unique (« view once »).
  final bool isViewOnce;

  /// Instant où CE média vue unique a été consommé (ouvert par moi, ou signalé
  /// « vu » via socket). Non nul ⇒ le média n'est plus ré-ouvrable.
  final DateTime? viewedAt;
  final String? senderNom;
  final String? senderPseudo;
  final String? senderAvatar;

  /// true tant que le message n'a pas été remis au serveur (outbox).
  final bool syncPending;

  /// Dernier instant d'émission via le socket — sert au backoff de l'outbox.
  final DateTime? lastEmittedAt;

  /// Nombre de tentatives de retry pour ce message (failed -> retry).
  final int retryCount;
  const LocalMessage({
    required this.clientId,
    required this.msgID,
    required this.conversationID,
    required this.senderID,
    this.content,
    required this.type,
    required this.status,
    required this.sendAt,
    this.deliveredAt,
    this.readAt,
    this.mediaUrl,
    this.mediaName,
    this.mediaDuration,
    this.localMediaPath,
    this.pendingUploadPath,
    this.replyToID,
    this.replyToContent,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    this.deletedForID,
    required this.isStatusReply,
    required this.isForwarded,
    required this.isPinned,
    required this.isViewOnce,
    this.viewedAt,
    this.senderNom,
    this.senderPseudo,
    this.senderAvatar,
    required this.syncPending,
    this.lastEmittedAt,
    required this.retryCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_id'] = Variable<String>(clientId);
    map['msg_i_d'] = Variable<int>(msgID);
    map['conversation_i_d'] = Variable<int>(conversationID);
    map['sender_i_d'] = Variable<int>(senderID);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    map['type'] = Variable<int>(type);
    map['status'] = Variable<int>(status);
    map['send_at'] = Variable<DateTime>(sendAt);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || mediaName != null) {
      map['media_name'] = Variable<String>(mediaName);
    }
    if (!nullToAbsent || mediaDuration != null) {
      map['media_duration'] = Variable<int>(mediaDuration);
    }
    if (!nullToAbsent || localMediaPath != null) {
      map['local_media_path'] = Variable<String>(localMediaPath);
    }
    if (!nullToAbsent || pendingUploadPath != null) {
      map['pending_upload_path'] = Variable<String>(pendingUploadPath);
    }
    if (!nullToAbsent || replyToID != null) {
      map['reply_to_i_d'] = Variable<int>(replyToID);
    }
    if (!nullToAbsent || replyToContent != null) {
      map['reply_to_content'] = Variable<String>(replyToContent);
    }
    map['is_edited'] = Variable<bool>(isEdited);
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedForID != null) {
      map['deleted_for_i_d'] = Variable<int>(deletedForID);
    }
    map['is_status_reply'] = Variable<int>(isStatusReply);
    map['is_forwarded'] = Variable<bool>(isForwarded);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_view_once'] = Variable<bool>(isViewOnce);
    if (!nullToAbsent || viewedAt != null) {
      map['viewed_at'] = Variable<DateTime>(viewedAt);
    }
    if (!nullToAbsent || senderNom != null) {
      map['sender_nom'] = Variable<String>(senderNom);
    }
    if (!nullToAbsent || senderPseudo != null) {
      map['sender_pseudo'] = Variable<String>(senderPseudo);
    }
    if (!nullToAbsent || senderAvatar != null) {
      map['sender_avatar'] = Variable<String>(senderAvatar);
    }
    map['sync_pending'] = Variable<bool>(syncPending);
    if (!nullToAbsent || lastEmittedAt != null) {
      map['last_emitted_at'] = Variable<DateTime>(lastEmittedAt);
    }
    map['retry_count'] = Variable<int>(retryCount);
    return map;
  }

  LocalMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalMessagesCompanion(
      clientId: Value(clientId),
      msgID: Value(msgID),
      conversationID: Value(conversationID),
      senderID: Value(senderID),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      type: Value(type),
      status: Value(status),
      sendAt: Value(sendAt),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      mediaName: mediaName == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaName),
      mediaDuration: mediaDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaDuration),
      localMediaPath: localMediaPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localMediaPath),
      pendingUploadPath: pendingUploadPath == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingUploadPath),
      replyToID: replyToID == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToID),
      replyToContent: replyToContent == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToContent),
      isEdited: Value(isEdited),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      isDeleted: Value(isDeleted),
      deletedForID: deletedForID == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedForID),
      isStatusReply: Value(isStatusReply),
      isForwarded: Value(isForwarded),
      isPinned: Value(isPinned),
      isViewOnce: Value(isViewOnce),
      viewedAt: viewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(viewedAt),
      senderNom: senderNom == null && nullToAbsent
          ? const Value.absent()
          : Value(senderNom),
      senderPseudo: senderPseudo == null && nullToAbsent
          ? const Value.absent()
          : Value(senderPseudo),
      senderAvatar: senderAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(senderAvatar),
      syncPending: Value(syncPending),
      lastEmittedAt: lastEmittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastEmittedAt),
      retryCount: Value(retryCount),
    );
  }

  factory LocalMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      clientId: serializer.fromJson<String>(json['clientId']),
      msgID: serializer.fromJson<int>(json['msgID']),
      conversationID: serializer.fromJson<int>(json['conversationID']),
      senderID: serializer.fromJson<int>(json['senderID']),
      content: serializer.fromJson<String?>(json['content']),
      type: serializer.fromJson<int>(json['type']),
      status: serializer.fromJson<int>(json['status']),
      sendAt: serializer.fromJson<DateTime>(json['sendAt']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      mediaName: serializer.fromJson<String?>(json['mediaName']),
      mediaDuration: serializer.fromJson<int?>(json['mediaDuration']),
      localMediaPath: serializer.fromJson<String?>(json['localMediaPath']),
      pendingUploadPath: serializer.fromJson<String?>(
        json['pendingUploadPath'],
      ),
      replyToID: serializer.fromJson<int?>(json['replyToID']),
      replyToContent: serializer.fromJson<String?>(json['replyToContent']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedForID: serializer.fromJson<int?>(json['deletedForID']),
      isStatusReply: serializer.fromJson<int>(json['isStatusReply']),
      isForwarded: serializer.fromJson<bool>(json['isForwarded']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isViewOnce: serializer.fromJson<bool>(json['isViewOnce']),
      viewedAt: serializer.fromJson<DateTime?>(json['viewedAt']),
      senderNom: serializer.fromJson<String?>(json['senderNom']),
      senderPseudo: serializer.fromJson<String?>(json['senderPseudo']),
      senderAvatar: serializer.fromJson<String?>(json['senderAvatar']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      lastEmittedAt: serializer.fromJson<DateTime?>(json['lastEmittedAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientId': serializer.toJson<String>(clientId),
      'msgID': serializer.toJson<int>(msgID),
      'conversationID': serializer.toJson<int>(conversationID),
      'senderID': serializer.toJson<int>(senderID),
      'content': serializer.toJson<String?>(content),
      'type': serializer.toJson<int>(type),
      'status': serializer.toJson<int>(status),
      'sendAt': serializer.toJson<DateTime>(sendAt),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'mediaName': serializer.toJson<String?>(mediaName),
      'mediaDuration': serializer.toJson<int?>(mediaDuration),
      'localMediaPath': serializer.toJson<String?>(localMediaPath),
      'pendingUploadPath': serializer.toJson<String?>(pendingUploadPath),
      'replyToID': serializer.toJson<int?>(replyToID),
      'replyToContent': serializer.toJson<String?>(replyToContent),
      'isEdited': serializer.toJson<bool>(isEdited),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedForID': serializer.toJson<int?>(deletedForID),
      'isStatusReply': serializer.toJson<int>(isStatusReply),
      'isForwarded': serializer.toJson<bool>(isForwarded),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isViewOnce': serializer.toJson<bool>(isViewOnce),
      'viewedAt': serializer.toJson<DateTime?>(viewedAt),
      'senderNom': serializer.toJson<String?>(senderNom),
      'senderPseudo': serializer.toJson<String?>(senderPseudo),
      'senderAvatar': serializer.toJson<String?>(senderAvatar),
      'syncPending': serializer.toJson<bool>(syncPending),
      'lastEmittedAt': serializer.toJson<DateTime?>(lastEmittedAt),
      'retryCount': serializer.toJson<int>(retryCount),
    };
  }

  LocalMessage copyWith({
    String? clientId,
    int? msgID,
    int? conversationID,
    int? senderID,
    Value<String?> content = const Value.absent(),
    int? type,
    int? status,
    DateTime? sendAt,
    Value<DateTime?> deliveredAt = const Value.absent(),
    Value<DateTime?> readAt = const Value.absent(),
    Value<String?> mediaUrl = const Value.absent(),
    Value<String?> mediaName = const Value.absent(),
    Value<int?> mediaDuration = const Value.absent(),
    Value<String?> localMediaPath = const Value.absent(),
    Value<String?> pendingUploadPath = const Value.absent(),
    Value<int?> replyToID = const Value.absent(),
    Value<String?> replyToContent = const Value.absent(),
    bool? isEdited,
    Value<DateTime?> editedAt = const Value.absent(),
    bool? isDeleted,
    Value<int?> deletedForID = const Value.absent(),
    int? isStatusReply,
    bool? isForwarded,
    bool? isPinned,
    bool? isViewOnce,
    Value<DateTime?> viewedAt = const Value.absent(),
    Value<String?> senderNom = const Value.absent(),
    Value<String?> senderPseudo = const Value.absent(),
    Value<String?> senderAvatar = const Value.absent(),
    bool? syncPending,
    Value<DateTime?> lastEmittedAt = const Value.absent(),
    int? retryCount,
  }) => LocalMessage(
    clientId: clientId ?? this.clientId,
    msgID: msgID ?? this.msgID,
    conversationID: conversationID ?? this.conversationID,
    senderID: senderID ?? this.senderID,
    content: content.present ? content.value : this.content,
    type: type ?? this.type,
    status: status ?? this.status,
    sendAt: sendAt ?? this.sendAt,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
    mediaName: mediaName.present ? mediaName.value : this.mediaName,
    mediaDuration: mediaDuration.present
        ? mediaDuration.value
        : this.mediaDuration,
    localMediaPath: localMediaPath.present
        ? localMediaPath.value
        : this.localMediaPath,
    pendingUploadPath: pendingUploadPath.present
        ? pendingUploadPath.value
        : this.pendingUploadPath,
    replyToID: replyToID.present ? replyToID.value : this.replyToID,
    replyToContent: replyToContent.present
        ? replyToContent.value
        : this.replyToContent,
    isEdited: isEdited ?? this.isEdited,
    editedAt: editedAt.present ? editedAt.value : this.editedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedForID: deletedForID.present ? deletedForID.value : this.deletedForID,
    isStatusReply: isStatusReply ?? this.isStatusReply,
    isForwarded: isForwarded ?? this.isForwarded,
    isPinned: isPinned ?? this.isPinned,
    isViewOnce: isViewOnce ?? this.isViewOnce,
    viewedAt: viewedAt.present ? viewedAt.value : this.viewedAt,
    senderNom: senderNom.present ? senderNom.value : this.senderNom,
    senderPseudo: senderPseudo.present ? senderPseudo.value : this.senderPseudo,
    senderAvatar: senderAvatar.present ? senderAvatar.value : this.senderAvatar,
    syncPending: syncPending ?? this.syncPending,
    lastEmittedAt: lastEmittedAt.present
        ? lastEmittedAt.value
        : this.lastEmittedAt,
    retryCount: retryCount ?? this.retryCount,
  );
  LocalMessage copyWithCompanion(LocalMessagesCompanion data) {
    return LocalMessage(
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      msgID: data.msgID.present ? data.msgID.value : this.msgID,
      conversationID: data.conversationID.present
          ? data.conversationID.value
          : this.conversationID,
      senderID: data.senderID.present ? data.senderID.value : this.senderID,
      content: data.content.present ? data.content.value : this.content,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      sendAt: data.sendAt.present ? data.sendAt.value : this.sendAt,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      mediaName: data.mediaName.present ? data.mediaName.value : this.mediaName,
      mediaDuration: data.mediaDuration.present
          ? data.mediaDuration.value
          : this.mediaDuration,
      localMediaPath: data.localMediaPath.present
          ? data.localMediaPath.value
          : this.localMediaPath,
      pendingUploadPath: data.pendingUploadPath.present
          ? data.pendingUploadPath.value
          : this.pendingUploadPath,
      replyToID: data.replyToID.present ? data.replyToID.value : this.replyToID,
      replyToContent: data.replyToContent.present
          ? data.replyToContent.value
          : this.replyToContent,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedForID: data.deletedForID.present
          ? data.deletedForID.value
          : this.deletedForID,
      isStatusReply: data.isStatusReply.present
          ? data.isStatusReply.value
          : this.isStatusReply,
      isForwarded: data.isForwarded.present
          ? data.isForwarded.value
          : this.isForwarded,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isViewOnce: data.isViewOnce.present
          ? data.isViewOnce.value
          : this.isViewOnce,
      viewedAt: data.viewedAt.present ? data.viewedAt.value : this.viewedAt,
      senderNom: data.senderNom.present ? data.senderNom.value : this.senderNom,
      senderPseudo: data.senderPseudo.present
          ? data.senderPseudo.value
          : this.senderPseudo,
      senderAvatar: data.senderAvatar.present
          ? data.senderAvatar.value
          : this.senderAvatar,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
      lastEmittedAt: data.lastEmittedAt.present
          ? data.lastEmittedAt.value
          : this.lastEmittedAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('clientId: $clientId, ')
          ..write('msgID: $msgID, ')
          ..write('conversationID: $conversationID, ')
          ..write('senderID: $senderID, ')
          ..write('content: $content, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('sendAt: $sendAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaName: $mediaName, ')
          ..write('mediaDuration: $mediaDuration, ')
          ..write('localMediaPath: $localMediaPath, ')
          ..write('pendingUploadPath: $pendingUploadPath, ')
          ..write('replyToID: $replyToID, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('isEdited: $isEdited, ')
          ..write('editedAt: $editedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedForID: $deletedForID, ')
          ..write('isStatusReply: $isStatusReply, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('isPinned: $isPinned, ')
          ..write('isViewOnce: $isViewOnce, ')
          ..write('viewedAt: $viewedAt, ')
          ..write('senderNom: $senderNom, ')
          ..write('senderPseudo: $senderPseudo, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('syncPending: $syncPending, ')
          ..write('lastEmittedAt: $lastEmittedAt, ')
          ..write('retryCount: $retryCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    clientId,
    msgID,
    conversationID,
    senderID,
    content,
    type,
    status,
    sendAt,
    deliveredAt,
    readAt,
    mediaUrl,
    mediaName,
    mediaDuration,
    localMediaPath,
    pendingUploadPath,
    replyToID,
    replyToContent,
    isEdited,
    editedAt,
    isDeleted,
    deletedForID,
    isStatusReply,
    isForwarded,
    isPinned,
    isViewOnce,
    viewedAt,
    senderNom,
    senderPseudo,
    senderAvatar,
    syncPending,
    lastEmittedAt,
    retryCount,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.clientId == this.clientId &&
          other.msgID == this.msgID &&
          other.conversationID == this.conversationID &&
          other.senderID == this.senderID &&
          other.content == this.content &&
          other.type == this.type &&
          other.status == this.status &&
          other.sendAt == this.sendAt &&
          other.deliveredAt == this.deliveredAt &&
          other.readAt == this.readAt &&
          other.mediaUrl == this.mediaUrl &&
          other.mediaName == this.mediaName &&
          other.mediaDuration == this.mediaDuration &&
          other.localMediaPath == this.localMediaPath &&
          other.pendingUploadPath == this.pendingUploadPath &&
          other.replyToID == this.replyToID &&
          other.replyToContent == this.replyToContent &&
          other.isEdited == this.isEdited &&
          other.editedAt == this.editedAt &&
          other.isDeleted == this.isDeleted &&
          other.deletedForID == this.deletedForID &&
          other.isStatusReply == this.isStatusReply &&
          other.isForwarded == this.isForwarded &&
          other.isPinned == this.isPinned &&
          other.isViewOnce == this.isViewOnce &&
          other.viewedAt == this.viewedAt &&
          other.senderNom == this.senderNom &&
          other.senderPseudo == this.senderPseudo &&
          other.senderAvatar == this.senderAvatar &&
          other.syncPending == this.syncPending &&
          other.lastEmittedAt == this.lastEmittedAt &&
          other.retryCount == this.retryCount);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<String> clientId;
  final Value<int> msgID;
  final Value<int> conversationID;
  final Value<int> senderID;
  final Value<String?> content;
  final Value<int> type;
  final Value<int> status;
  final Value<DateTime> sendAt;
  final Value<DateTime?> deliveredAt;
  final Value<DateTime?> readAt;
  final Value<String?> mediaUrl;
  final Value<String?> mediaName;
  final Value<int?> mediaDuration;
  final Value<String?> localMediaPath;
  final Value<String?> pendingUploadPath;
  final Value<int?> replyToID;
  final Value<String?> replyToContent;
  final Value<bool> isEdited;
  final Value<DateTime?> editedAt;
  final Value<bool> isDeleted;
  final Value<int?> deletedForID;
  final Value<int> isStatusReply;
  final Value<bool> isForwarded;
  final Value<bool> isPinned;
  final Value<bool> isViewOnce;
  final Value<DateTime?> viewedAt;
  final Value<String?> senderNom;
  final Value<String?> senderPseudo;
  final Value<String?> senderAvatar;
  final Value<bool> syncPending;
  final Value<DateTime?> lastEmittedAt;
  final Value<int> retryCount;
  final Value<int> rowid;
  const LocalMessagesCompanion({
    this.clientId = const Value.absent(),
    this.msgID = const Value.absent(),
    this.conversationID = const Value.absent(),
    this.senderID = const Value.absent(),
    this.content = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.sendAt = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaName = const Value.absent(),
    this.mediaDuration = const Value.absent(),
    this.localMediaPath = const Value.absent(),
    this.pendingUploadPath = const Value.absent(),
    this.replyToID = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedForID = const Value.absent(),
    this.isStatusReply = const Value.absent(),
    this.isForwarded = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isViewOnce = const Value.absent(),
    this.viewedAt = const Value.absent(),
    this.senderNom = const Value.absent(),
    this.senderPseudo = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.lastEmittedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMessagesCompanion.insert({
    required String clientId,
    this.msgID = const Value.absent(),
    required int conversationID,
    required int senderID,
    this.content = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime sendAt,
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaName = const Value.absent(),
    this.mediaDuration = const Value.absent(),
    this.localMediaPath = const Value.absent(),
    this.pendingUploadPath = const Value.absent(),
    this.replyToID = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedForID = const Value.absent(),
    this.isStatusReply = const Value.absent(),
    this.isForwarded = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isViewOnce = const Value.absent(),
    this.viewedAt = const Value.absent(),
    this.senderNom = const Value.absent(),
    this.senderPseudo = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.lastEmittedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientId = Value(clientId),
       conversationID = Value(conversationID),
       senderID = Value(senderID),
       sendAt = Value(sendAt);
  static Insertable<LocalMessage> custom({
    Expression<String>? clientId,
    Expression<int>? msgID,
    Expression<int>? conversationID,
    Expression<int>? senderID,
    Expression<String>? content,
    Expression<int>? type,
    Expression<int>? status,
    Expression<DateTime>? sendAt,
    Expression<DateTime>? deliveredAt,
    Expression<DateTime>? readAt,
    Expression<String>? mediaUrl,
    Expression<String>? mediaName,
    Expression<int>? mediaDuration,
    Expression<String>? localMediaPath,
    Expression<String>? pendingUploadPath,
    Expression<int>? replyToID,
    Expression<String>? replyToContent,
    Expression<bool>? isEdited,
    Expression<DateTime>? editedAt,
    Expression<bool>? isDeleted,
    Expression<int>? deletedForID,
    Expression<int>? isStatusReply,
    Expression<bool>? isForwarded,
    Expression<bool>? isPinned,
    Expression<bool>? isViewOnce,
    Expression<DateTime>? viewedAt,
    Expression<String>? senderNom,
    Expression<String>? senderPseudo,
    Expression<String>? senderAvatar,
    Expression<bool>? syncPending,
    Expression<DateTime>? lastEmittedAt,
    Expression<int>? retryCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (msgID != null) 'msg_i_d': msgID,
      if (conversationID != null) 'conversation_i_d': conversationID,
      if (senderID != null) 'sender_i_d': senderID,
      if (content != null) 'content': content,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (sendAt != null) 'send_at': sendAt,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (readAt != null) 'read_at': readAt,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaName != null) 'media_name': mediaName,
      if (mediaDuration != null) 'media_duration': mediaDuration,
      if (localMediaPath != null) 'local_media_path': localMediaPath,
      if (pendingUploadPath != null) 'pending_upload_path': pendingUploadPath,
      if (replyToID != null) 'reply_to_i_d': replyToID,
      if (replyToContent != null) 'reply_to_content': replyToContent,
      if (isEdited != null) 'is_edited': isEdited,
      if (editedAt != null) 'edited_at': editedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedForID != null) 'deleted_for_i_d': deletedForID,
      if (isStatusReply != null) 'is_status_reply': isStatusReply,
      if (isForwarded != null) 'is_forwarded': isForwarded,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isViewOnce != null) 'is_view_once': isViewOnce,
      if (viewedAt != null) 'viewed_at': viewedAt,
      if (senderNom != null) 'sender_nom': senderNom,
      if (senderPseudo != null) 'sender_pseudo': senderPseudo,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
      if (syncPending != null) 'sync_pending': syncPending,
      if (lastEmittedAt != null) 'last_emitted_at': lastEmittedAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMessagesCompanion copyWith({
    Value<String>? clientId,
    Value<int>? msgID,
    Value<int>? conversationID,
    Value<int>? senderID,
    Value<String?>? content,
    Value<int>? type,
    Value<int>? status,
    Value<DateTime>? sendAt,
    Value<DateTime?>? deliveredAt,
    Value<DateTime?>? readAt,
    Value<String?>? mediaUrl,
    Value<String?>? mediaName,
    Value<int?>? mediaDuration,
    Value<String?>? localMediaPath,
    Value<String?>? pendingUploadPath,
    Value<int?>? replyToID,
    Value<String?>? replyToContent,
    Value<bool>? isEdited,
    Value<DateTime?>? editedAt,
    Value<bool>? isDeleted,
    Value<int?>? deletedForID,
    Value<int>? isStatusReply,
    Value<bool>? isForwarded,
    Value<bool>? isPinned,
    Value<bool>? isViewOnce,
    Value<DateTime?>? viewedAt,
    Value<String?>? senderNom,
    Value<String?>? senderPseudo,
    Value<String?>? senderAvatar,
    Value<bool>? syncPending,
    Value<DateTime?>? lastEmittedAt,
    Value<int>? retryCount,
    Value<int>? rowid,
  }) {
    return LocalMessagesCompanion(
      clientId: clientId ?? this.clientId,
      msgID: msgID ?? this.msgID,
      conversationID: conversationID ?? this.conversationID,
      senderID: senderID ?? this.senderID,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      sendAt: sendAt ?? this.sendAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaName: mediaName ?? this.mediaName,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      localMediaPath: localMediaPath ?? this.localMediaPath,
      pendingUploadPath: pendingUploadPath ?? this.pendingUploadPath,
      replyToID: replyToID ?? this.replyToID,
      replyToContent: replyToContent ?? this.replyToContent,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedForID: deletedForID ?? this.deletedForID,
      isStatusReply: isStatusReply ?? this.isStatusReply,
      isForwarded: isForwarded ?? this.isForwarded,
      isPinned: isPinned ?? this.isPinned,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewedAt: viewedAt ?? this.viewedAt,
      senderNom: senderNom ?? this.senderNom,
      senderPseudo: senderPseudo ?? this.senderPseudo,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      syncPending: syncPending ?? this.syncPending,
      lastEmittedAt: lastEmittedAt ?? this.lastEmittedAt,
      retryCount: retryCount ?? this.retryCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (msgID.present) {
      map['msg_i_d'] = Variable<int>(msgID.value);
    }
    if (conversationID.present) {
      map['conversation_i_d'] = Variable<int>(conversationID.value);
    }
    if (senderID.present) {
      map['sender_i_d'] = Variable<int>(senderID.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (sendAt.present) {
      map['send_at'] = Variable<DateTime>(sendAt.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (mediaName.present) {
      map['media_name'] = Variable<String>(mediaName.value);
    }
    if (mediaDuration.present) {
      map['media_duration'] = Variable<int>(mediaDuration.value);
    }
    if (localMediaPath.present) {
      map['local_media_path'] = Variable<String>(localMediaPath.value);
    }
    if (pendingUploadPath.present) {
      map['pending_upload_path'] = Variable<String>(pendingUploadPath.value);
    }
    if (replyToID.present) {
      map['reply_to_i_d'] = Variable<int>(replyToID.value);
    }
    if (replyToContent.present) {
      map['reply_to_content'] = Variable<String>(replyToContent.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedForID.present) {
      map['deleted_for_i_d'] = Variable<int>(deletedForID.value);
    }
    if (isStatusReply.present) {
      map['is_status_reply'] = Variable<int>(isStatusReply.value);
    }
    if (isForwarded.present) {
      map['is_forwarded'] = Variable<bool>(isForwarded.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isViewOnce.present) {
      map['is_view_once'] = Variable<bool>(isViewOnce.value);
    }
    if (viewedAt.present) {
      map['viewed_at'] = Variable<DateTime>(viewedAt.value);
    }
    if (senderNom.present) {
      map['sender_nom'] = Variable<String>(senderNom.value);
    }
    if (senderPseudo.present) {
      map['sender_pseudo'] = Variable<String>(senderPseudo.value);
    }
    if (senderAvatar.present) {
      map['sender_avatar'] = Variable<String>(senderAvatar.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (lastEmittedAt.present) {
      map['last_emitted_at'] = Variable<DateTime>(lastEmittedAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessagesCompanion(')
          ..write('clientId: $clientId, ')
          ..write('msgID: $msgID, ')
          ..write('conversationID: $conversationID, ')
          ..write('senderID: $senderID, ')
          ..write('content: $content, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('sendAt: $sendAt, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaName: $mediaName, ')
          ..write('mediaDuration: $mediaDuration, ')
          ..write('localMediaPath: $localMediaPath, ')
          ..write('pendingUploadPath: $pendingUploadPath, ')
          ..write('replyToID: $replyToID, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('isEdited: $isEdited, ')
          ..write('editedAt: $editedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedForID: $deletedForID, ')
          ..write('isStatusReply: $isStatusReply, ')
          ..write('isForwarded: $isForwarded, ')
          ..write('isPinned: $isPinned, ')
          ..write('isViewOnce: $isViewOnce, ')
          ..write('viewedAt: $viewedAt, ')
          ..write('senderNom: $senderNom, ')
          ..write('senderPseudo: $senderPseudo, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('syncPending: $syncPending, ')
          ..write('lastEmittedAt: $lastEmittedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalUsersTable extends LocalUsers
    with TableInfo<$LocalUsersTable, LocalUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _alanyaIDMeta = const VerificationMeta(
    'alanyaID',
  );
  @override
  late final GeneratedColumn<int> alanyaID = GeneratedColumn<int>(
    'alanya_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nomMeta = const VerificationMeta('nom');
  @override
  late final GeneratedColumn<String> nom = GeneratedColumn<String>(
    'nom',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pseudoMeta = const VerificationMeta('pseudo');
  @override
  late final GeneratedColumn<String> pseudo = GeneratedColumn<String>(
    'pseudo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _alanyaPhoneMeta = const VerificationMeta(
    'alanyaPhone',
  );
  @override
  late final GeneratedColumn<String> alanyaPhone = GeneratedColumn<String>(
    'alanya_phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _idPaysMeta = const VerificationMeta('idPays');
  @override
  late final GeneratedColumn<int> idPays = GeneratedColumn<int>(
    'id_pays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _paysLibelleMeta = const VerificationMeta(
    'paysLibelle',
  );
  @override
  late final GeneratedColumn<String> paysLibelle = GeneratedColumn<String>(
    'pays_libelle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOnlineMeta = const VerificationMeta(
    'isOnline',
  );
  @override
  late final GeneratedColumn<bool> isOnline = GeneratedColumn<bool>(
    'is_online',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_online" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPreferredContactMeta =
      const VerificationMeta('isPreferredContact');
  @override
  late final GeneratedColumn<bool> isPreferredContact = GeneratedColumn<bool>(
    'is_preferred_contact',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_preferred_contact" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _typeCompteMeta = const VerificationMeta(
    'typeCompte',
  );
  @override
  late final GeneratedColumn<int> typeCompte = GeneratedColumn<int>(
    'type_compte',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    alanyaID,
    nom,
    pseudo,
    alanyaPhone,
    email,
    avatarUrl,
    idPays,
    paysLibelle,
    isOnline,
    lastSeen,
    isPreferredContact,
    typeCompte,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_users';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalUser> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('alanya_i_d')) {
      context.handle(
        _alanyaIDMeta,
        alanyaID.isAcceptableOrUnknown(data['alanya_i_d']!, _alanyaIDMeta),
      );
    }
    if (data.containsKey('nom')) {
      context.handle(
        _nomMeta,
        nom.isAcceptableOrUnknown(data['nom']!, _nomMeta),
      );
    }
    if (data.containsKey('pseudo')) {
      context.handle(
        _pseudoMeta,
        pseudo.isAcceptableOrUnknown(data['pseudo']!, _pseudoMeta),
      );
    }
    if (data.containsKey('alanya_phone')) {
      context.handle(
        _alanyaPhoneMeta,
        alanyaPhone.isAcceptableOrUnknown(
          data['alanya_phone']!,
          _alanyaPhoneMeta,
        ),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('id_pays')) {
      context.handle(
        _idPaysMeta,
        idPays.isAcceptableOrUnknown(data['id_pays']!, _idPaysMeta),
      );
    }
    if (data.containsKey('pays_libelle')) {
      context.handle(
        _paysLibelleMeta,
        paysLibelle.isAcceptableOrUnknown(
          data['pays_libelle']!,
          _paysLibelleMeta,
        ),
      );
    }
    if (data.containsKey('is_online')) {
      context.handle(
        _isOnlineMeta,
        isOnline.isAcceptableOrUnknown(data['is_online']!, _isOnlineMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('is_preferred_contact')) {
      context.handle(
        _isPreferredContactMeta,
        isPreferredContact.isAcceptableOrUnknown(
          data['is_preferred_contact']!,
          _isPreferredContactMeta,
        ),
      );
    }
    if (data.containsKey('type_compte')) {
      context.handle(
        _typeCompteMeta,
        typeCompte.isAcceptableOrUnknown(data['type_compte']!, _typeCompteMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {alanyaID};
  @override
  LocalUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUser(
      alanyaID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alanya_i_d'],
      )!,
      nom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nom'],
      )!,
      pseudo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pseudo'],
      )!,
      alanyaPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alanya_phone'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      )!,
      idPays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_pays'],
      )!,
      paysLibelle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pays_libelle'],
      ),
      isOnline: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_online'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      ),
      isPreferredContact: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_preferred_contact'],
      )!,
      typeCompte: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_compte'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $LocalUsersTable createAlias(String alias) {
    return $LocalUsersTable(attachedDatabase, alias);
  }
}

class LocalUser extends DataClass implements Insertable<LocalUser> {
  final int alanyaID;
  final String nom;
  final String pseudo;
  final String alanyaPhone;
  final String email;
  final String avatarUrl;
  final int idPays;
  final String? paysLibelle;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool isPreferredContact;
  final int typeCompte;
  final DateTime cachedAt;
  const LocalUser({
    required this.alanyaID,
    required this.nom,
    required this.pseudo,
    required this.alanyaPhone,
    required this.email,
    required this.avatarUrl,
    required this.idPays,
    this.paysLibelle,
    required this.isOnline,
    this.lastSeen,
    required this.isPreferredContact,
    required this.typeCompte,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['alanya_i_d'] = Variable<int>(alanyaID);
    map['nom'] = Variable<String>(nom);
    map['pseudo'] = Variable<String>(pseudo);
    map['alanya_phone'] = Variable<String>(alanyaPhone);
    map['email'] = Variable<String>(email);
    map['avatar_url'] = Variable<String>(avatarUrl);
    map['id_pays'] = Variable<int>(idPays);
    if (!nullToAbsent || paysLibelle != null) {
      map['pays_libelle'] = Variable<String>(paysLibelle);
    }
    map['is_online'] = Variable<bool>(isOnline);
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    map['is_preferred_contact'] = Variable<bool>(isPreferredContact);
    map['type_compte'] = Variable<int>(typeCompte);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LocalUsersCompanion toCompanion(bool nullToAbsent) {
    return LocalUsersCompanion(
      alanyaID: Value(alanyaID),
      nom: Value(nom),
      pseudo: Value(pseudo),
      alanyaPhone: Value(alanyaPhone),
      email: Value(email),
      avatarUrl: Value(avatarUrl),
      idPays: Value(idPays),
      paysLibelle: paysLibelle == null && nullToAbsent
          ? const Value.absent()
          : Value(paysLibelle),
      isOnline: Value(isOnline),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      isPreferredContact: Value(isPreferredContact),
      typeCompte: Value(typeCompte),
      cachedAt: Value(cachedAt),
    );
  }

  factory LocalUser.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUser(
      alanyaID: serializer.fromJson<int>(json['alanyaID']),
      nom: serializer.fromJson<String>(json['nom']),
      pseudo: serializer.fromJson<String>(json['pseudo']),
      alanyaPhone: serializer.fromJson<String>(json['alanyaPhone']),
      email: serializer.fromJson<String>(json['email']),
      avatarUrl: serializer.fromJson<String>(json['avatarUrl']),
      idPays: serializer.fromJson<int>(json['idPays']),
      paysLibelle: serializer.fromJson<String?>(json['paysLibelle']),
      isOnline: serializer.fromJson<bool>(json['isOnline']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
      isPreferredContact: serializer.fromJson<bool>(json['isPreferredContact']),
      typeCompte: serializer.fromJson<int>(json['typeCompte']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'alanyaID': serializer.toJson<int>(alanyaID),
      'nom': serializer.toJson<String>(nom),
      'pseudo': serializer.toJson<String>(pseudo),
      'alanyaPhone': serializer.toJson<String>(alanyaPhone),
      'email': serializer.toJson<String>(email),
      'avatarUrl': serializer.toJson<String>(avatarUrl),
      'idPays': serializer.toJson<int>(idPays),
      'paysLibelle': serializer.toJson<String?>(paysLibelle),
      'isOnline': serializer.toJson<bool>(isOnline),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
      'isPreferredContact': serializer.toJson<bool>(isPreferredContact),
      'typeCompte': serializer.toJson<int>(typeCompte),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  LocalUser copyWith({
    int? alanyaID,
    String? nom,
    String? pseudo,
    String? alanyaPhone,
    String? email,
    String? avatarUrl,
    int? idPays,
    Value<String?> paysLibelle = const Value.absent(),
    bool? isOnline,
    Value<DateTime?> lastSeen = const Value.absent(),
    bool? isPreferredContact,
    int? typeCompte,
    DateTime? cachedAt,
  }) => LocalUser(
    alanyaID: alanyaID ?? this.alanyaID,
    nom: nom ?? this.nom,
    pseudo: pseudo ?? this.pseudo,
    alanyaPhone: alanyaPhone ?? this.alanyaPhone,
    email: email ?? this.email,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    idPays: idPays ?? this.idPays,
    paysLibelle: paysLibelle.present ? paysLibelle.value : this.paysLibelle,
    isOnline: isOnline ?? this.isOnline,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    isPreferredContact: isPreferredContact ?? this.isPreferredContact,
    typeCompte: typeCompte ?? this.typeCompte,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  LocalUser copyWithCompanion(LocalUsersCompanion data) {
    return LocalUser(
      alanyaID: data.alanyaID.present ? data.alanyaID.value : this.alanyaID,
      nom: data.nom.present ? data.nom.value : this.nom,
      pseudo: data.pseudo.present ? data.pseudo.value : this.pseudo,
      alanyaPhone: data.alanyaPhone.present
          ? data.alanyaPhone.value
          : this.alanyaPhone,
      email: data.email.present ? data.email.value : this.email,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      idPays: data.idPays.present ? data.idPays.value : this.idPays,
      paysLibelle: data.paysLibelle.present
          ? data.paysLibelle.value
          : this.paysLibelle,
      isOnline: data.isOnline.present ? data.isOnline.value : this.isOnline,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      isPreferredContact: data.isPreferredContact.present
          ? data.isPreferredContact.value
          : this.isPreferredContact,
      typeCompte: data.typeCompte.present
          ? data.typeCompte.value
          : this.typeCompte,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUser(')
          ..write('alanyaID: $alanyaID, ')
          ..write('nom: $nom, ')
          ..write('pseudo: $pseudo, ')
          ..write('alanyaPhone: $alanyaPhone, ')
          ..write('email: $email, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('idPays: $idPays, ')
          ..write('paysLibelle: $paysLibelle, ')
          ..write('isOnline: $isOnline, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isPreferredContact: $isPreferredContact, ')
          ..write('typeCompte: $typeCompte, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    alanyaID,
    nom,
    pseudo,
    alanyaPhone,
    email,
    avatarUrl,
    idPays,
    paysLibelle,
    isOnline,
    lastSeen,
    isPreferredContact,
    typeCompte,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUser &&
          other.alanyaID == this.alanyaID &&
          other.nom == this.nom &&
          other.pseudo == this.pseudo &&
          other.alanyaPhone == this.alanyaPhone &&
          other.email == this.email &&
          other.avatarUrl == this.avatarUrl &&
          other.idPays == this.idPays &&
          other.paysLibelle == this.paysLibelle &&
          other.isOnline == this.isOnline &&
          other.lastSeen == this.lastSeen &&
          other.isPreferredContact == this.isPreferredContact &&
          other.typeCompte == this.typeCompte &&
          other.cachedAt == this.cachedAt);
}

class LocalUsersCompanion extends UpdateCompanion<LocalUser> {
  final Value<int> alanyaID;
  final Value<String> nom;
  final Value<String> pseudo;
  final Value<String> alanyaPhone;
  final Value<String> email;
  final Value<String> avatarUrl;
  final Value<int> idPays;
  final Value<String?> paysLibelle;
  final Value<bool> isOnline;
  final Value<DateTime?> lastSeen;
  final Value<bool> isPreferredContact;
  final Value<int> typeCompte;
  final Value<DateTime> cachedAt;
  const LocalUsersCompanion({
    this.alanyaID = const Value.absent(),
    this.nom = const Value.absent(),
    this.pseudo = const Value.absent(),
    this.alanyaPhone = const Value.absent(),
    this.email = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.idPays = const Value.absent(),
    this.paysLibelle = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isPreferredContact = const Value.absent(),
    this.typeCompte = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  LocalUsersCompanion.insert({
    this.alanyaID = const Value.absent(),
    this.nom = const Value.absent(),
    this.pseudo = const Value.absent(),
    this.alanyaPhone = const Value.absent(),
    this.email = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.idPays = const Value.absent(),
    this.paysLibelle = const Value.absent(),
    this.isOnline = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.isPreferredContact = const Value.absent(),
    this.typeCompte = const Value.absent(),
    required DateTime cachedAt,
  }) : cachedAt = Value(cachedAt);
  static Insertable<LocalUser> custom({
    Expression<int>? alanyaID,
    Expression<String>? nom,
    Expression<String>? pseudo,
    Expression<String>? alanyaPhone,
    Expression<String>? email,
    Expression<String>? avatarUrl,
    Expression<int>? idPays,
    Expression<String>? paysLibelle,
    Expression<bool>? isOnline,
    Expression<DateTime>? lastSeen,
    Expression<bool>? isPreferredContact,
    Expression<int>? typeCompte,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (alanyaID != null) 'alanya_i_d': alanyaID,
      if (nom != null) 'nom': nom,
      if (pseudo != null) 'pseudo': pseudo,
      if (alanyaPhone != null) 'alanya_phone': alanyaPhone,
      if (email != null) 'email': email,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (idPays != null) 'id_pays': idPays,
      if (paysLibelle != null) 'pays_libelle': paysLibelle,
      if (isOnline != null) 'is_online': isOnline,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (isPreferredContact != null)
        'is_preferred_contact': isPreferredContact,
      if (typeCompte != null) 'type_compte': typeCompte,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  LocalUsersCompanion copyWith({
    Value<int>? alanyaID,
    Value<String>? nom,
    Value<String>? pseudo,
    Value<String>? alanyaPhone,
    Value<String>? email,
    Value<String>? avatarUrl,
    Value<int>? idPays,
    Value<String?>? paysLibelle,
    Value<bool>? isOnline,
    Value<DateTime?>? lastSeen,
    Value<bool>? isPreferredContact,
    Value<int>? typeCompte,
    Value<DateTime>? cachedAt,
  }) {
    return LocalUsersCompanion(
      alanyaID: alanyaID ?? this.alanyaID,
      nom: nom ?? this.nom,
      pseudo: pseudo ?? this.pseudo,
      alanyaPhone: alanyaPhone ?? this.alanyaPhone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      idPays: idPays ?? this.idPays,
      paysLibelle: paysLibelle ?? this.paysLibelle,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      isPreferredContact: isPreferredContact ?? this.isPreferredContact,
      typeCompte: typeCompte ?? this.typeCompte,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (alanyaID.present) {
      map['alanya_i_d'] = Variable<int>(alanyaID.value);
    }
    if (nom.present) {
      map['nom'] = Variable<String>(nom.value);
    }
    if (pseudo.present) {
      map['pseudo'] = Variable<String>(pseudo.value);
    }
    if (alanyaPhone.present) {
      map['alanya_phone'] = Variable<String>(alanyaPhone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (idPays.present) {
      map['id_pays'] = Variable<int>(idPays.value);
    }
    if (paysLibelle.present) {
      map['pays_libelle'] = Variable<String>(paysLibelle.value);
    }
    if (isOnline.present) {
      map['is_online'] = Variable<bool>(isOnline.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (isPreferredContact.present) {
      map['is_preferred_contact'] = Variable<bool>(isPreferredContact.value);
    }
    if (typeCompte.present) {
      map['type_compte'] = Variable<int>(typeCompte.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUsersCompanion(')
          ..write('alanyaID: $alanyaID, ')
          ..write('nom: $nom, ')
          ..write('pseudo: $pseudo, ')
          ..write('alanyaPhone: $alanyaPhone, ')
          ..write('email: $email, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('idPays: $idPays, ')
          ..write('paysLibelle: $paysLibelle, ')
          ..write('isOnline: $isOnline, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('isPreferredContact: $isPreferredContact, ')
          ..write('typeCompte: $typeCompte, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalCallsTable extends LocalCalls
    with TableInfo<$LocalCallsTable, LocalCall> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idCallMeta = const VerificationMeta('idCall');
  @override
  late final GeneratedColumn<int> idCall = GeneratedColumn<int>(
    'id_call',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idCallerMeta = const VerificationMeta(
    'idCaller',
  );
  @override
  late final GeneratedColumn<int> idCaller = GeneratedColumn<int>(
    'id_caller',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idReceiverMeta = const VerificationMeta(
    'idReceiver',
  );
  @override
  late final GeneratedColumn<int> idReceiver = GeneratedColumn<int>(
    'id_receiver',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _otherNomMeta = const VerificationMeta(
    'otherNom',
  );
  @override
  late final GeneratedColumn<String> otherNom = GeneratedColumn<String>(
    'other_nom',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _otherAvatarMeta = const VerificationMeta(
    'otherAvatar',
  );
  @override
  late final GeneratedColumn<String> otherAvatar = GeneratedColumn<String>(
    'other_avatar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    idCall,
    idCaller,
    idReceiver,
    type,
    status,
    duration,
    createdAt,
    otherNom,
    otherAvatar,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCall> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id_call')) {
      context.handle(
        _idCallMeta,
        idCall.isAcceptableOrUnknown(data['id_call']!, _idCallMeta),
      );
    }
    if (data.containsKey('id_caller')) {
      context.handle(
        _idCallerMeta,
        idCaller.isAcceptableOrUnknown(data['id_caller']!, _idCallerMeta),
      );
    } else if (isInserting) {
      context.missing(_idCallerMeta);
    }
    if (data.containsKey('id_receiver')) {
      context.handle(
        _idReceiverMeta,
        idReceiver.isAcceptableOrUnknown(data['id_receiver']!, _idReceiverMeta),
      );
    } else if (isInserting) {
      context.missing(_idReceiverMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('other_nom')) {
      context.handle(
        _otherNomMeta,
        otherNom.isAcceptableOrUnknown(data['other_nom']!, _otherNomMeta),
      );
    }
    if (data.containsKey('other_avatar')) {
      context.handle(
        _otherAvatarMeta,
        otherAvatar.isAcceptableOrUnknown(
          data['other_avatar']!,
          _otherAvatarMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idCall};
  @override
  LocalCall map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCall(
      idCall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_call'],
      )!,
      idCaller: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_caller'],
      )!,
      idReceiver: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_receiver'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      otherNom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_nom'],
      ),
      otherAvatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}other_avatar'],
      ),
    );
  }

  @override
  $LocalCallsTable createAlias(String alias) {
    return $LocalCallsTable(attachedDatabase, alias);
  }
}

class LocalCall extends DataClass implements Insertable<LocalCall> {
  final int idCall;
  final int idCaller;
  final int idReceiver;

  /// 0=audio, 1=vidéo
  final int type;

  /// 0=missed, 1=answered, 2=rejected, 3=outgoing answered…
  final int status;
  final int? duration;
  final DateTime createdAt;

  /// Snapshot dénormalisé pour affichage offline (avatar/nom du correspondant).
  final String? otherNom;
  final String? otherAvatar;
  const LocalCall({
    required this.idCall,
    required this.idCaller,
    required this.idReceiver,
    required this.type,
    required this.status,
    this.duration,
    required this.createdAt,
    this.otherNom,
    this.otherAvatar,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id_call'] = Variable<int>(idCall);
    map['id_caller'] = Variable<int>(idCaller);
    map['id_receiver'] = Variable<int>(idReceiver);
    map['type'] = Variable<int>(type);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || duration != null) {
      map['duration'] = Variable<int>(duration);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || otherNom != null) {
      map['other_nom'] = Variable<String>(otherNom);
    }
    if (!nullToAbsent || otherAvatar != null) {
      map['other_avatar'] = Variable<String>(otherAvatar);
    }
    return map;
  }

  LocalCallsCompanion toCompanion(bool nullToAbsent) {
    return LocalCallsCompanion(
      idCall: Value(idCall),
      idCaller: Value(idCaller),
      idReceiver: Value(idReceiver),
      type: Value(type),
      status: Value(status),
      duration: duration == null && nullToAbsent
          ? const Value.absent()
          : Value(duration),
      createdAt: Value(createdAt),
      otherNom: otherNom == null && nullToAbsent
          ? const Value.absent()
          : Value(otherNom),
      otherAvatar: otherAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(otherAvatar),
    );
  }

  factory LocalCall.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCall(
      idCall: serializer.fromJson<int>(json['idCall']),
      idCaller: serializer.fromJson<int>(json['idCaller']),
      idReceiver: serializer.fromJson<int>(json['idReceiver']),
      type: serializer.fromJson<int>(json['type']),
      status: serializer.fromJson<int>(json['status']),
      duration: serializer.fromJson<int?>(json['duration']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      otherNom: serializer.fromJson<String?>(json['otherNom']),
      otherAvatar: serializer.fromJson<String?>(json['otherAvatar']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idCall': serializer.toJson<int>(idCall),
      'idCaller': serializer.toJson<int>(idCaller),
      'idReceiver': serializer.toJson<int>(idReceiver),
      'type': serializer.toJson<int>(type),
      'status': serializer.toJson<int>(status),
      'duration': serializer.toJson<int?>(duration),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'otherNom': serializer.toJson<String?>(otherNom),
      'otherAvatar': serializer.toJson<String?>(otherAvatar),
    };
  }

  LocalCall copyWith({
    int? idCall,
    int? idCaller,
    int? idReceiver,
    int? type,
    int? status,
    Value<int?> duration = const Value.absent(),
    DateTime? createdAt,
    Value<String?> otherNom = const Value.absent(),
    Value<String?> otherAvatar = const Value.absent(),
  }) => LocalCall(
    idCall: idCall ?? this.idCall,
    idCaller: idCaller ?? this.idCaller,
    idReceiver: idReceiver ?? this.idReceiver,
    type: type ?? this.type,
    status: status ?? this.status,
    duration: duration.present ? duration.value : this.duration,
    createdAt: createdAt ?? this.createdAt,
    otherNom: otherNom.present ? otherNom.value : this.otherNom,
    otherAvatar: otherAvatar.present ? otherAvatar.value : this.otherAvatar,
  );
  LocalCall copyWithCompanion(LocalCallsCompanion data) {
    return LocalCall(
      idCall: data.idCall.present ? data.idCall.value : this.idCall,
      idCaller: data.idCaller.present ? data.idCaller.value : this.idCaller,
      idReceiver: data.idReceiver.present
          ? data.idReceiver.value
          : this.idReceiver,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      duration: data.duration.present ? data.duration.value : this.duration,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      otherNom: data.otherNom.present ? data.otherNom.value : this.otherNom,
      otherAvatar: data.otherAvatar.present
          ? data.otherAvatar.value
          : this.otherAvatar,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCall(')
          ..write('idCall: $idCall, ')
          ..write('idCaller: $idCaller, ')
          ..write('idReceiver: $idReceiver, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('duration: $duration, ')
          ..write('createdAt: $createdAt, ')
          ..write('otherNom: $otherNom, ')
          ..write('otherAvatar: $otherAvatar')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    idCall,
    idCaller,
    idReceiver,
    type,
    status,
    duration,
    createdAt,
    otherNom,
    otherAvatar,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCall &&
          other.idCall == this.idCall &&
          other.idCaller == this.idCaller &&
          other.idReceiver == this.idReceiver &&
          other.type == this.type &&
          other.status == this.status &&
          other.duration == this.duration &&
          other.createdAt == this.createdAt &&
          other.otherNom == this.otherNom &&
          other.otherAvatar == this.otherAvatar);
}

class LocalCallsCompanion extends UpdateCompanion<LocalCall> {
  final Value<int> idCall;
  final Value<int> idCaller;
  final Value<int> idReceiver;
  final Value<int> type;
  final Value<int> status;
  final Value<int?> duration;
  final Value<DateTime> createdAt;
  final Value<String?> otherNom;
  final Value<String?> otherAvatar;
  const LocalCallsCompanion({
    this.idCall = const Value.absent(),
    this.idCaller = const Value.absent(),
    this.idReceiver = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.duration = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.otherNom = const Value.absent(),
    this.otherAvatar = const Value.absent(),
  });
  LocalCallsCompanion.insert({
    this.idCall = const Value.absent(),
    required int idCaller,
    required int idReceiver,
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.duration = const Value.absent(),
    required DateTime createdAt,
    this.otherNom = const Value.absent(),
    this.otherAvatar = const Value.absent(),
  }) : idCaller = Value(idCaller),
       idReceiver = Value(idReceiver),
       createdAt = Value(createdAt);
  static Insertable<LocalCall> custom({
    Expression<int>? idCall,
    Expression<int>? idCaller,
    Expression<int>? idReceiver,
    Expression<int>? type,
    Expression<int>? status,
    Expression<int>? duration,
    Expression<DateTime>? createdAt,
    Expression<String>? otherNom,
    Expression<String>? otherAvatar,
  }) {
    return RawValuesInsertable({
      if (idCall != null) 'id_call': idCall,
      if (idCaller != null) 'id_caller': idCaller,
      if (idReceiver != null) 'id_receiver': idReceiver,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (duration != null) 'duration': duration,
      if (createdAt != null) 'created_at': createdAt,
      if (otherNom != null) 'other_nom': otherNom,
      if (otherAvatar != null) 'other_avatar': otherAvatar,
    });
  }

  LocalCallsCompanion copyWith({
    Value<int>? idCall,
    Value<int>? idCaller,
    Value<int>? idReceiver,
    Value<int>? type,
    Value<int>? status,
    Value<int?>? duration,
    Value<DateTime>? createdAt,
    Value<String?>? otherNom,
    Value<String?>? otherAvatar,
  }) {
    return LocalCallsCompanion(
      idCall: idCall ?? this.idCall,
      idCaller: idCaller ?? this.idCaller,
      idReceiver: idReceiver ?? this.idReceiver,
      type: type ?? this.type,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      otherNom: otherNom ?? this.otherNom,
      otherAvatar: otherAvatar ?? this.otherAvatar,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idCall.present) {
      map['id_call'] = Variable<int>(idCall.value);
    }
    if (idCaller.present) {
      map['id_caller'] = Variable<int>(idCaller.value);
    }
    if (idReceiver.present) {
      map['id_receiver'] = Variable<int>(idReceiver.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (otherNom.present) {
      map['other_nom'] = Variable<String>(otherNom.value);
    }
    if (otherAvatar.present) {
      map['other_avatar'] = Variable<String>(otherAvatar.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCallsCompanion(')
          ..write('idCall: $idCall, ')
          ..write('idCaller: $idCaller, ')
          ..write('idReceiver: $idReceiver, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('duration: $duration, ')
          ..write('createdAt: $createdAt, ')
          ..write('otherNom: $otherNom, ')
          ..write('otherAvatar: $otherAvatar')
          ..write(')'))
        .toString();
  }
}

class $LocalMeetingsTable extends LocalMeetings
    with TableInfo<$LocalMeetingsTable, LocalMeeting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMeetingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeetingMeta = const VerificationMeta(
    'idMeeting',
  );
  @override
  late final GeneratedColumn<int> idMeeting = GeneratedColumn<int>(
    'id_meeting',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _objetMeta = const VerificationMeta('objet');
  @override
  late final GeneratedColumn<String> objet = GeneratedColumn<String>(
    'objet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _roomMeta = const VerificationMeta('room');
  @override
  late final GeneratedColumn<String> room = GeneratedColumn<String>(
    'room',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dureeMeta = const VerificationMeta('duree');
  @override
  late final GeneratedColumn<int> duree = GeneratedColumn<int>(
    'duree',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _typeMediaMeta = const VerificationMeta(
    'typeMedia',
  );
  @override
  late final GeneratedColumn<int> typeMedia = GeneratedColumn<int>(
    'type_media',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _organiserIDMeta = const VerificationMeta(
    'organiserID',
  );
  @override
  late final GeneratedColumn<int> organiserID = GeneratedColumn<int>(
    'organiser_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _organiserNomMeta = const VerificationMeta(
    'organiserNom',
  );
  @override
  late final GeneratedColumn<String> organiserNom = GeneratedColumn<String>(
    'organiser_nom',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _participantsJsonMeta = const VerificationMeta(
    'participantsJson',
  );
  @override
  late final GeneratedColumn<String> participantsJson = GeneratedColumn<String>(
    'participants_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _statutMeta = const VerificationMeta('statut');
  @override
  late final GeneratedColumn<int> statut = GeneratedColumn<int>(
    'statut',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    idMeeting,
    objet,
    room,
    startTime,
    duree,
    typeMedia,
    organiserID,
    organiserNom,
    participantsJson,
    statut,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_meetings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMeeting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id_meeting')) {
      context.handle(
        _idMeetingMeta,
        idMeeting.isAcceptableOrUnknown(data['id_meeting']!, _idMeetingMeta),
      );
    }
    if (data.containsKey('objet')) {
      context.handle(
        _objetMeta,
        objet.isAcceptableOrUnknown(data['objet']!, _objetMeta),
      );
    }
    if (data.containsKey('room')) {
      context.handle(
        _roomMeta,
        room.isAcceptableOrUnknown(data['room']!, _roomMeta),
      );
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('duree')) {
      context.handle(
        _dureeMeta,
        duree.isAcceptableOrUnknown(data['duree']!, _dureeMeta),
      );
    }
    if (data.containsKey('type_media')) {
      context.handle(
        _typeMediaMeta,
        typeMedia.isAcceptableOrUnknown(data['type_media']!, _typeMediaMeta),
      );
    }
    if (data.containsKey('organiser_i_d')) {
      context.handle(
        _organiserIDMeta,
        organiserID.isAcceptableOrUnknown(
          data['organiser_i_d']!,
          _organiserIDMeta,
        ),
      );
    }
    if (data.containsKey('organiser_nom')) {
      context.handle(
        _organiserNomMeta,
        organiserNom.isAcceptableOrUnknown(
          data['organiser_nom']!,
          _organiserNomMeta,
        ),
      );
    }
    if (data.containsKey('participants_json')) {
      context.handle(
        _participantsJsonMeta,
        participantsJson.isAcceptableOrUnknown(
          data['participants_json']!,
          _participantsJsonMeta,
        ),
      );
    }
    if (data.containsKey('statut')) {
      context.handle(
        _statutMeta,
        statut.isAcceptableOrUnknown(data['statut']!, _statutMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idMeeting};
  @override
  LocalMeeting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMeeting(
      idMeeting: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_meeting'],
      )!,
      objet: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}objet'],
      )!,
      room: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      duree: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duree'],
      )!,
      typeMedia: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_media'],
      )!,
      organiserID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}organiser_i_d'],
      )!,
      organiserNom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organiser_nom'],
      ),
      participantsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}participants_json'],
      )!,
      statut: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}statut'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $LocalMeetingsTable createAlias(String alias) {
    return $LocalMeetingsTable(attachedDatabase, alias);
  }
}

class LocalMeeting extends DataClass implements Insertable<LocalMeeting> {
  final int idMeeting;
  final String objet;
  final String room;
  final DateTime startTime;
  final int duree;
  final int typeMedia;
  final int organiserID;
  final String? organiserNom;
  final String participantsJson;

  /// 0=upcoming, 1=ongoing, 2=ended, 3=cancelled
  final int statut;
  final DateTime cachedAt;
  const LocalMeeting({
    required this.idMeeting,
    required this.objet,
    required this.room,
    required this.startTime,
    required this.duree,
    required this.typeMedia,
    required this.organiserID,
    this.organiserNom,
    required this.participantsJson,
    required this.statut,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id_meeting'] = Variable<int>(idMeeting);
    map['objet'] = Variable<String>(objet);
    map['room'] = Variable<String>(room);
    map['start_time'] = Variable<DateTime>(startTime);
    map['duree'] = Variable<int>(duree);
    map['type_media'] = Variable<int>(typeMedia);
    map['organiser_i_d'] = Variable<int>(organiserID);
    if (!nullToAbsent || organiserNom != null) {
      map['organiser_nom'] = Variable<String>(organiserNom);
    }
    map['participants_json'] = Variable<String>(participantsJson);
    map['statut'] = Variable<int>(statut);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LocalMeetingsCompanion toCompanion(bool nullToAbsent) {
    return LocalMeetingsCompanion(
      idMeeting: Value(idMeeting),
      objet: Value(objet),
      room: Value(room),
      startTime: Value(startTime),
      duree: Value(duree),
      typeMedia: Value(typeMedia),
      organiserID: Value(organiserID),
      organiserNom: organiserNom == null && nullToAbsent
          ? const Value.absent()
          : Value(organiserNom),
      participantsJson: Value(participantsJson),
      statut: Value(statut),
      cachedAt: Value(cachedAt),
    );
  }

  factory LocalMeeting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMeeting(
      idMeeting: serializer.fromJson<int>(json['idMeeting']),
      objet: serializer.fromJson<String>(json['objet']),
      room: serializer.fromJson<String>(json['room']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      duree: serializer.fromJson<int>(json['duree']),
      typeMedia: serializer.fromJson<int>(json['typeMedia']),
      organiserID: serializer.fromJson<int>(json['organiserID']),
      organiserNom: serializer.fromJson<String?>(json['organiserNom']),
      participantsJson: serializer.fromJson<String>(json['participantsJson']),
      statut: serializer.fromJson<int>(json['statut']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idMeeting': serializer.toJson<int>(idMeeting),
      'objet': serializer.toJson<String>(objet),
      'room': serializer.toJson<String>(room),
      'startTime': serializer.toJson<DateTime>(startTime),
      'duree': serializer.toJson<int>(duree),
      'typeMedia': serializer.toJson<int>(typeMedia),
      'organiserID': serializer.toJson<int>(organiserID),
      'organiserNom': serializer.toJson<String?>(organiserNom),
      'participantsJson': serializer.toJson<String>(participantsJson),
      'statut': serializer.toJson<int>(statut),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  LocalMeeting copyWith({
    int? idMeeting,
    String? objet,
    String? room,
    DateTime? startTime,
    int? duree,
    int? typeMedia,
    int? organiserID,
    Value<String?> organiserNom = const Value.absent(),
    String? participantsJson,
    int? statut,
    DateTime? cachedAt,
  }) => LocalMeeting(
    idMeeting: idMeeting ?? this.idMeeting,
    objet: objet ?? this.objet,
    room: room ?? this.room,
    startTime: startTime ?? this.startTime,
    duree: duree ?? this.duree,
    typeMedia: typeMedia ?? this.typeMedia,
    organiserID: organiserID ?? this.organiserID,
    organiserNom: organiserNom.present ? organiserNom.value : this.organiserNom,
    participantsJson: participantsJson ?? this.participantsJson,
    statut: statut ?? this.statut,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  LocalMeeting copyWithCompanion(LocalMeetingsCompanion data) {
    return LocalMeeting(
      idMeeting: data.idMeeting.present ? data.idMeeting.value : this.idMeeting,
      objet: data.objet.present ? data.objet.value : this.objet,
      room: data.room.present ? data.room.value : this.room,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      duree: data.duree.present ? data.duree.value : this.duree,
      typeMedia: data.typeMedia.present ? data.typeMedia.value : this.typeMedia,
      organiserID: data.organiserID.present
          ? data.organiserID.value
          : this.organiserID,
      organiserNom: data.organiserNom.present
          ? data.organiserNom.value
          : this.organiserNom,
      participantsJson: data.participantsJson.present
          ? data.participantsJson.value
          : this.participantsJson,
      statut: data.statut.present ? data.statut.value : this.statut,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMeeting(')
          ..write('idMeeting: $idMeeting, ')
          ..write('objet: $objet, ')
          ..write('room: $room, ')
          ..write('startTime: $startTime, ')
          ..write('duree: $duree, ')
          ..write('typeMedia: $typeMedia, ')
          ..write('organiserID: $organiserID, ')
          ..write('organiserNom: $organiserNom, ')
          ..write('participantsJson: $participantsJson, ')
          ..write('statut: $statut, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    idMeeting,
    objet,
    room,
    startTime,
    duree,
    typeMedia,
    organiserID,
    organiserNom,
    participantsJson,
    statut,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMeeting &&
          other.idMeeting == this.idMeeting &&
          other.objet == this.objet &&
          other.room == this.room &&
          other.startTime == this.startTime &&
          other.duree == this.duree &&
          other.typeMedia == this.typeMedia &&
          other.organiserID == this.organiserID &&
          other.organiserNom == this.organiserNom &&
          other.participantsJson == this.participantsJson &&
          other.statut == this.statut &&
          other.cachedAt == this.cachedAt);
}

class LocalMeetingsCompanion extends UpdateCompanion<LocalMeeting> {
  final Value<int> idMeeting;
  final Value<String> objet;
  final Value<String> room;
  final Value<DateTime> startTime;
  final Value<int> duree;
  final Value<int> typeMedia;
  final Value<int> organiserID;
  final Value<String?> organiserNom;
  final Value<String> participantsJson;
  final Value<int> statut;
  final Value<DateTime> cachedAt;
  const LocalMeetingsCompanion({
    this.idMeeting = const Value.absent(),
    this.objet = const Value.absent(),
    this.room = const Value.absent(),
    this.startTime = const Value.absent(),
    this.duree = const Value.absent(),
    this.typeMedia = const Value.absent(),
    this.organiserID = const Value.absent(),
    this.organiserNom = const Value.absent(),
    this.participantsJson = const Value.absent(),
    this.statut = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  LocalMeetingsCompanion.insert({
    this.idMeeting = const Value.absent(),
    this.objet = const Value.absent(),
    this.room = const Value.absent(),
    required DateTime startTime,
    this.duree = const Value.absent(),
    this.typeMedia = const Value.absent(),
    this.organiserID = const Value.absent(),
    this.organiserNom = const Value.absent(),
    this.participantsJson = const Value.absent(),
    this.statut = const Value.absent(),
    required DateTime cachedAt,
  }) : startTime = Value(startTime),
       cachedAt = Value(cachedAt);
  static Insertable<LocalMeeting> custom({
    Expression<int>? idMeeting,
    Expression<String>? objet,
    Expression<String>? room,
    Expression<DateTime>? startTime,
    Expression<int>? duree,
    Expression<int>? typeMedia,
    Expression<int>? organiserID,
    Expression<String>? organiserNom,
    Expression<String>? participantsJson,
    Expression<int>? statut,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (idMeeting != null) 'id_meeting': idMeeting,
      if (objet != null) 'objet': objet,
      if (room != null) 'room': room,
      if (startTime != null) 'start_time': startTime,
      if (duree != null) 'duree': duree,
      if (typeMedia != null) 'type_media': typeMedia,
      if (organiserID != null) 'organiser_i_d': organiserID,
      if (organiserNom != null) 'organiser_nom': organiserNom,
      if (participantsJson != null) 'participants_json': participantsJson,
      if (statut != null) 'statut': statut,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  LocalMeetingsCompanion copyWith({
    Value<int>? idMeeting,
    Value<String>? objet,
    Value<String>? room,
    Value<DateTime>? startTime,
    Value<int>? duree,
    Value<int>? typeMedia,
    Value<int>? organiserID,
    Value<String?>? organiserNom,
    Value<String>? participantsJson,
    Value<int>? statut,
    Value<DateTime>? cachedAt,
  }) {
    return LocalMeetingsCompanion(
      idMeeting: idMeeting ?? this.idMeeting,
      objet: objet ?? this.objet,
      room: room ?? this.room,
      startTime: startTime ?? this.startTime,
      duree: duree ?? this.duree,
      typeMedia: typeMedia ?? this.typeMedia,
      organiserID: organiserID ?? this.organiserID,
      organiserNom: organiserNom ?? this.organiserNom,
      participantsJson: participantsJson ?? this.participantsJson,
      statut: statut ?? this.statut,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idMeeting.present) {
      map['id_meeting'] = Variable<int>(idMeeting.value);
    }
    if (objet.present) {
      map['objet'] = Variable<String>(objet.value);
    }
    if (room.present) {
      map['room'] = Variable<String>(room.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (duree.present) {
      map['duree'] = Variable<int>(duree.value);
    }
    if (typeMedia.present) {
      map['type_media'] = Variable<int>(typeMedia.value);
    }
    if (organiserID.present) {
      map['organiser_i_d'] = Variable<int>(organiserID.value);
    }
    if (organiserNom.present) {
      map['organiser_nom'] = Variable<String>(organiserNom.value);
    }
    if (participantsJson.present) {
      map['participants_json'] = Variable<String>(participantsJson.value);
    }
    if (statut.present) {
      map['statut'] = Variable<int>(statut.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMeetingsCompanion(')
          ..write('idMeeting: $idMeeting, ')
          ..write('objet: $objet, ')
          ..write('room: $room, ')
          ..write('startTime: $startTime, ')
          ..write('duree: $duree, ')
          ..write('typeMedia: $typeMedia, ')
          ..write('organiserID: $organiserID, ')
          ..write('organiserNom: $organiserNom, ')
          ..write('participantsJson: $participantsJson, ')
          ..write('statut: $statut, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalStatusesTable extends LocalStatuses
    with TableInfo<$LocalStatusesTable, LocalStatuse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idStatutMeta = const VerificationMeta(
    'idStatut',
  );
  @override
  late final GeneratedColumn<int> idStatut = GeneratedColumn<int>(
    'id_statut',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorIDMeta = const VerificationMeta(
    'authorID',
  );
  @override
  late final GeneratedColumn<int> authorID = GeneratedColumn<int>(
    'author_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorNomMeta = const VerificationMeta(
    'authorNom',
  );
  @override
  late final GeneratedColumn<String> authorNom = GeneratedColumn<String>(
    'author_nom',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorAvatarMeta = const VerificationMeta(
    'authorAvatar',
  );
  @override
  late final GeneratedColumn<String> authorAvatar = GeneratedColumn<String>(
    'author_avatar',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaUrlMeta = const VerificationMeta(
    'mediaUrl',
  );
  @override
  late final GeneratedColumn<String> mediaUrl = GeneratedColumn<String>(
    'media_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localMediaPathMeta = const VerificationMeta(
    'localMediaPath',
  );
  @override
  late final GeneratedColumn<String> localMediaPath = GeneratedColumn<String>(
    'local_media_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backgroundColorMeta = const VerificationMeta(
    'backgroundColor',
  );
  @override
  late final GeneratedColumn<String> backgroundColor = GeneratedColumn<String>(
    'background_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaDurationMsMeta = const VerificationMeta(
    'mediaDurationMs',
  );
  @override
  late final GeneratedColumn<int> mediaDurationMs = GeneratedColumn<int>(
    'media_duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isMineMeta = const VerificationMeta('isMine');
  @override
  late final GeneratedColumn<bool> isMine = GeneratedColumn<bool>(
    'is_mine',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_mine" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    idStatut,
    authorID,
    authorNom,
    authorAvatar,
    type,
    textContent,
    mediaUrl,
    localMediaPath,
    backgroundColor,
    mediaDurationMs,
    createdAt,
    expiresAt,
    isMine,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStatuse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id_statut')) {
      context.handle(
        _idStatutMeta,
        idStatut.isAcceptableOrUnknown(data['id_statut']!, _idStatutMeta),
      );
    }
    if (data.containsKey('author_i_d')) {
      context.handle(
        _authorIDMeta,
        authorID.isAcceptableOrUnknown(data['author_i_d']!, _authorIDMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIDMeta);
    }
    if (data.containsKey('author_nom')) {
      context.handle(
        _authorNomMeta,
        authorNom.isAcceptableOrUnknown(data['author_nom']!, _authorNomMeta),
      );
    }
    if (data.containsKey('author_avatar')) {
      context.handle(
        _authorAvatarMeta,
        authorAvatar.isAcceptableOrUnknown(
          data['author_avatar']!,
          _authorAvatarMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    }
    if (data.containsKey('media_url')) {
      context.handle(
        _mediaUrlMeta,
        mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta),
      );
    }
    if (data.containsKey('local_media_path')) {
      context.handle(
        _localMediaPathMeta,
        localMediaPath.isAcceptableOrUnknown(
          data['local_media_path']!,
          _localMediaPathMeta,
        ),
      );
    }
    if (data.containsKey('background_color')) {
      context.handle(
        _backgroundColorMeta,
        backgroundColor.isAcceptableOrUnknown(
          data['background_color']!,
          _backgroundColorMeta,
        ),
      );
    }
    if (data.containsKey('media_duration_ms')) {
      context.handle(
        _mediaDurationMsMeta,
        mediaDurationMs.isAcceptableOrUnknown(
          data['media_duration_ms']!,
          _mediaDurationMsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('is_mine')) {
      context.handle(
        _isMineMeta,
        isMine.isAcceptableOrUnknown(data['is_mine']!, _isMineMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idStatut};
  @override
  LocalStatuse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStatuse(
      idStatut: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_statut'],
      )!,
      authorID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}author_i_d'],
      )!,
      authorNom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_nom'],
      ),
      authorAvatar: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_avatar'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type'],
      )!,
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      ),
      mediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_url'],
      ),
      localMediaPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_media_path'],
      ),
      backgroundColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}background_color'],
      ),
      mediaDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_duration_ms'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      isMine: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mine'],
      )!,
    );
  }

  @override
  $LocalStatusesTable createAlias(String alias) {
    return $LocalStatusesTable(attachedDatabase, alias);
  }
}

class LocalStatuse extends DataClass implements Insertable<LocalStatuse> {
  final int idStatut;
  final int authorID;
  final String? authorNom;
  final String? authorAvatar;

  /// 0=texte, 1=image, 2=vidéo, 3=audio
  final int type;
  final String? textContent;
  final String? mediaUrl;
  final String? localMediaPath;
  final String? backgroundColor;
  final int? mediaDurationMs;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isMine;
  const LocalStatuse({
    required this.idStatut,
    required this.authorID,
    this.authorNom,
    this.authorAvatar,
    required this.type,
    this.textContent,
    this.mediaUrl,
    this.localMediaPath,
    this.backgroundColor,
    this.mediaDurationMs,
    required this.createdAt,
    required this.expiresAt,
    required this.isMine,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id_statut'] = Variable<int>(idStatut);
    map['author_i_d'] = Variable<int>(authorID);
    if (!nullToAbsent || authorNom != null) {
      map['author_nom'] = Variable<String>(authorNom);
    }
    if (!nullToAbsent || authorAvatar != null) {
      map['author_avatar'] = Variable<String>(authorAvatar);
    }
    map['type'] = Variable<int>(type);
    if (!nullToAbsent || textContent != null) {
      map['text_content'] = Variable<String>(textContent);
    }
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || localMediaPath != null) {
      map['local_media_path'] = Variable<String>(localMediaPath);
    }
    if (!nullToAbsent || backgroundColor != null) {
      map['background_color'] = Variable<String>(backgroundColor);
    }
    if (!nullToAbsent || mediaDurationMs != null) {
      map['media_duration_ms'] = Variable<int>(mediaDurationMs);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['is_mine'] = Variable<bool>(isMine);
    return map;
  }

  LocalStatusesCompanion toCompanion(bool nullToAbsent) {
    return LocalStatusesCompanion(
      idStatut: Value(idStatut),
      authorID: Value(authorID),
      authorNom: authorNom == null && nullToAbsent
          ? const Value.absent()
          : Value(authorNom),
      authorAvatar: authorAvatar == null && nullToAbsent
          ? const Value.absent()
          : Value(authorAvatar),
      type: Value(type),
      textContent: textContent == null && nullToAbsent
          ? const Value.absent()
          : Value(textContent),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      localMediaPath: localMediaPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localMediaPath),
      backgroundColor: backgroundColor == null && nullToAbsent
          ? const Value.absent()
          : Value(backgroundColor),
      mediaDurationMs: mediaDurationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaDurationMs),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      isMine: Value(isMine),
    );
  }

  factory LocalStatuse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStatuse(
      idStatut: serializer.fromJson<int>(json['idStatut']),
      authorID: serializer.fromJson<int>(json['authorID']),
      authorNom: serializer.fromJson<String?>(json['authorNom']),
      authorAvatar: serializer.fromJson<String?>(json['authorAvatar']),
      type: serializer.fromJson<int>(json['type']),
      textContent: serializer.fromJson<String?>(json['textContent']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      localMediaPath: serializer.fromJson<String?>(json['localMediaPath']),
      backgroundColor: serializer.fromJson<String?>(json['backgroundColor']),
      mediaDurationMs: serializer.fromJson<int?>(json['mediaDurationMs']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      isMine: serializer.fromJson<bool>(json['isMine']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idStatut': serializer.toJson<int>(idStatut),
      'authorID': serializer.toJson<int>(authorID),
      'authorNom': serializer.toJson<String?>(authorNom),
      'authorAvatar': serializer.toJson<String?>(authorAvatar),
      'type': serializer.toJson<int>(type),
      'textContent': serializer.toJson<String?>(textContent),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'localMediaPath': serializer.toJson<String?>(localMediaPath),
      'backgroundColor': serializer.toJson<String?>(backgroundColor),
      'mediaDurationMs': serializer.toJson<int?>(mediaDurationMs),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'isMine': serializer.toJson<bool>(isMine),
    };
  }

  LocalStatuse copyWith({
    int? idStatut,
    int? authorID,
    Value<String?> authorNom = const Value.absent(),
    Value<String?> authorAvatar = const Value.absent(),
    int? type,
    Value<String?> textContent = const Value.absent(),
    Value<String?> mediaUrl = const Value.absent(),
    Value<String?> localMediaPath = const Value.absent(),
    Value<String?> backgroundColor = const Value.absent(),
    Value<int?> mediaDurationMs = const Value.absent(),
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isMine,
  }) => LocalStatuse(
    idStatut: idStatut ?? this.idStatut,
    authorID: authorID ?? this.authorID,
    authorNom: authorNom.present ? authorNom.value : this.authorNom,
    authorAvatar: authorAvatar.present ? authorAvatar.value : this.authorAvatar,
    type: type ?? this.type,
    textContent: textContent.present ? textContent.value : this.textContent,
    mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
    localMediaPath: localMediaPath.present
        ? localMediaPath.value
        : this.localMediaPath,
    backgroundColor: backgroundColor.present
        ? backgroundColor.value
        : this.backgroundColor,
    mediaDurationMs: mediaDurationMs.present
        ? mediaDurationMs.value
        : this.mediaDurationMs,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    isMine: isMine ?? this.isMine,
  );
  LocalStatuse copyWithCompanion(LocalStatusesCompanion data) {
    return LocalStatuse(
      idStatut: data.idStatut.present ? data.idStatut.value : this.idStatut,
      authorID: data.authorID.present ? data.authorID.value : this.authorID,
      authorNom: data.authorNom.present ? data.authorNom.value : this.authorNom,
      authorAvatar: data.authorAvatar.present
          ? data.authorAvatar.value
          : this.authorAvatar,
      type: data.type.present ? data.type.value : this.type,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      localMediaPath: data.localMediaPath.present
          ? data.localMediaPath.value
          : this.localMediaPath,
      backgroundColor: data.backgroundColor.present
          ? data.backgroundColor.value
          : this.backgroundColor,
      mediaDurationMs: data.mediaDurationMs.present
          ? data.mediaDurationMs.value
          : this.mediaDurationMs,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      isMine: data.isMine.present ? data.isMine.value : this.isMine,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStatuse(')
          ..write('idStatut: $idStatut, ')
          ..write('authorID: $authorID, ')
          ..write('authorNom: $authorNom, ')
          ..write('authorAvatar: $authorAvatar, ')
          ..write('type: $type, ')
          ..write('textContent: $textContent, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('localMediaPath: $localMediaPath, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('mediaDurationMs: $mediaDurationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('isMine: $isMine')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    idStatut,
    authorID,
    authorNom,
    authorAvatar,
    type,
    textContent,
    mediaUrl,
    localMediaPath,
    backgroundColor,
    mediaDurationMs,
    createdAt,
    expiresAt,
    isMine,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStatuse &&
          other.idStatut == this.idStatut &&
          other.authorID == this.authorID &&
          other.authorNom == this.authorNom &&
          other.authorAvatar == this.authorAvatar &&
          other.type == this.type &&
          other.textContent == this.textContent &&
          other.mediaUrl == this.mediaUrl &&
          other.localMediaPath == this.localMediaPath &&
          other.backgroundColor == this.backgroundColor &&
          other.mediaDurationMs == this.mediaDurationMs &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.isMine == this.isMine);
}

class LocalStatusesCompanion extends UpdateCompanion<LocalStatuse> {
  final Value<int> idStatut;
  final Value<int> authorID;
  final Value<String?> authorNom;
  final Value<String?> authorAvatar;
  final Value<int> type;
  final Value<String?> textContent;
  final Value<String?> mediaUrl;
  final Value<String?> localMediaPath;
  final Value<String?> backgroundColor;
  final Value<int?> mediaDurationMs;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<bool> isMine;
  const LocalStatusesCompanion({
    this.idStatut = const Value.absent(),
    this.authorID = const Value.absent(),
    this.authorNom = const Value.absent(),
    this.authorAvatar = const Value.absent(),
    this.type = const Value.absent(),
    this.textContent = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.localMediaPath = const Value.absent(),
    this.backgroundColor = const Value.absent(),
    this.mediaDurationMs = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.isMine = const Value.absent(),
  });
  LocalStatusesCompanion.insert({
    this.idStatut = const Value.absent(),
    required int authorID,
    this.authorNom = const Value.absent(),
    this.authorAvatar = const Value.absent(),
    this.type = const Value.absent(),
    this.textContent = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.localMediaPath = const Value.absent(),
    this.backgroundColor = const Value.absent(),
    this.mediaDurationMs = const Value.absent(),
    required DateTime createdAt,
    required DateTime expiresAt,
    this.isMine = const Value.absent(),
  }) : authorID = Value(authorID),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt);
  static Insertable<LocalStatuse> custom({
    Expression<int>? idStatut,
    Expression<int>? authorID,
    Expression<String>? authorNom,
    Expression<String>? authorAvatar,
    Expression<int>? type,
    Expression<String>? textContent,
    Expression<String>? mediaUrl,
    Expression<String>? localMediaPath,
    Expression<String>? backgroundColor,
    Expression<int>? mediaDurationMs,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<bool>? isMine,
  }) {
    return RawValuesInsertable({
      if (idStatut != null) 'id_statut': idStatut,
      if (authorID != null) 'author_i_d': authorID,
      if (authorNom != null) 'author_nom': authorNom,
      if (authorAvatar != null) 'author_avatar': authorAvatar,
      if (type != null) 'type': type,
      if (textContent != null) 'text_content': textContent,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (localMediaPath != null) 'local_media_path': localMediaPath,
      if (backgroundColor != null) 'background_color': backgroundColor,
      if (mediaDurationMs != null) 'media_duration_ms': mediaDurationMs,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (isMine != null) 'is_mine': isMine,
    });
  }

  LocalStatusesCompanion copyWith({
    Value<int>? idStatut,
    Value<int>? authorID,
    Value<String?>? authorNom,
    Value<String?>? authorAvatar,
    Value<int>? type,
    Value<String?>? textContent,
    Value<String?>? mediaUrl,
    Value<String?>? localMediaPath,
    Value<String?>? backgroundColor,
    Value<int?>? mediaDurationMs,
    Value<DateTime>? createdAt,
    Value<DateTime>? expiresAt,
    Value<bool>? isMine,
  }) {
    return LocalStatusesCompanion(
      idStatut: idStatut ?? this.idStatut,
      authorID: authorID ?? this.authorID,
      authorNom: authorNom ?? this.authorNom,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      type: type ?? this.type,
      textContent: textContent ?? this.textContent,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      localMediaPath: localMediaPath ?? this.localMediaPath,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      mediaDurationMs: mediaDurationMs ?? this.mediaDurationMs,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isMine: isMine ?? this.isMine,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idStatut.present) {
      map['id_statut'] = Variable<int>(idStatut.value);
    }
    if (authorID.present) {
      map['author_i_d'] = Variable<int>(authorID.value);
    }
    if (authorNom.present) {
      map['author_nom'] = Variable<String>(authorNom.value);
    }
    if (authorAvatar.present) {
      map['author_avatar'] = Variable<String>(authorAvatar.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (localMediaPath.present) {
      map['local_media_path'] = Variable<String>(localMediaPath.value);
    }
    if (backgroundColor.present) {
      map['background_color'] = Variable<String>(backgroundColor.value);
    }
    if (mediaDurationMs.present) {
      map['media_duration_ms'] = Variable<int>(mediaDurationMs.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (isMine.present) {
      map['is_mine'] = Variable<bool>(isMine.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStatusesCompanion(')
          ..write('idStatut: $idStatut, ')
          ..write('authorID: $authorID, ')
          ..write('authorNom: $authorNom, ')
          ..write('authorAvatar: $authorAvatar, ')
          ..write('type: $type, ')
          ..write('textContent: $textContent, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('localMediaPath: $localMediaPath, ')
          ..write('backgroundColor: $backgroundColor, ')
          ..write('mediaDurationMs: $mediaDurationMs, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('isMine: $isMine')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalConversationsTable localConversations =
      $LocalConversationsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $LocalUsersTable localUsers = $LocalUsersTable(this);
  late final $LocalCallsTable localCalls = $LocalCallsTable(this);
  late final $LocalMeetingsTable localMeetings = $LocalMeetingsTable(this);
  late final $LocalStatusesTable localStatuses = $LocalStatusesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localConversations,
    localMessages,
    localUsers,
    localCalls,
    localMeetings,
    localStatuses,
  ];
}

typedef $$LocalConversationsTableCreateCompanionBuilder =
    LocalConversationsCompanion Function({
      Value<int> conversID,
      Value<bool> isGroup,
      Value<String?> groupName,
      Value<String?> groupPhoto,
      Value<String?> lastMessage,
      Value<DateTime?> lastMessageAt,
      Value<int?> lastMessageSenderID,
      Value<int?> lastMessageType,
      Value<int?> lastMessageStatus,
      Value<int> unreadCount,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<String> participantsJson,
    });
typedef $$LocalConversationsTableUpdateCompanionBuilder =
    LocalConversationsCompanion Function({
      Value<int> conversID,
      Value<bool> isGroup,
      Value<String?> groupName,
      Value<String?> groupPhoto,
      Value<String?> lastMessage,
      Value<DateTime?> lastMessageAt,
      Value<int?> lastMessageSenderID,
      Value<int?> lastMessageType,
      Value<int?> lastMessageStatus,
      Value<int> unreadCount,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<String> participantsJson,
    });

class $$LocalConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get conversID => $composableBuilder(
    column: $table.conversID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupPhoto => $composableBuilder(
    column: $table.groupPhoto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageSenderID => $composableBuilder(
    column: $table.lastMessageSenderID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantsJson => $composableBuilder(
    column: $table.participantsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get conversID => $composableBuilder(
    column: $table.conversID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupPhoto => $composableBuilder(
    column: $table.groupPhoto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageSenderID => $composableBuilder(
    column: $table.lastMessageSenderID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantsJson => $composableBuilder(
    column: $table.participantsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get conversID =>
      $composableBuilder(column: $table.conversID, builder: (column) => column);

  GeneratedColumn<bool> get isGroup =>
      $composableBuilder(column: $table.isGroup, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get groupPhoto => $composableBuilder(
    column: $table.groupPhoto,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageSenderID => $composableBuilder(
    column: $table.lastMessageSenderID,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastMessageStatus => $composableBuilder(
    column: $table.lastMessageStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get participantsJson => $composableBuilder(
    column: $table.participantsJson,
    builder: (column) => column,
  );
}

class $$LocalConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation,
          $$LocalConversationsTableFilterComposer,
          $$LocalConversationsTableOrderingComposer,
          $$LocalConversationsTableAnnotationComposer,
          $$LocalConversationsTableCreateCompanionBuilder,
          $$LocalConversationsTableUpdateCompanionBuilder,
          (
            LocalConversation,
            BaseReferences<
              _$AppDatabase,
              $LocalConversationsTable,
              LocalConversation
            >,
          ),
          LocalConversation,
          PrefetchHooks Function()
        > {
  $$LocalConversationsTableTableManager(
    _$AppDatabase db,
    $LocalConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> conversID = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String?> groupPhoto = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<int?> lastMessageSenderID = const Value.absent(),
                Value<int?> lastMessageType = const Value.absent(),
                Value<int?> lastMessageStatus = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String> participantsJson = const Value.absent(),
              }) => LocalConversationsCompanion(
                conversID: conversID,
                isGroup: isGroup,
                groupName: groupName,
                groupPhoto: groupPhoto,
                lastMessage: lastMessage,
                lastMessageAt: lastMessageAt,
                lastMessageSenderID: lastMessageSenderID,
                lastMessageType: lastMessageType,
                lastMessageStatus: lastMessageStatus,
                unreadCount: unreadCount,
                isPinned: isPinned,
                isArchived: isArchived,
                participantsJson: participantsJson,
              ),
          createCompanionCallback:
              ({
                Value<int> conversID = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String?> groupPhoto = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<int?> lastMessageSenderID = const Value.absent(),
                Value<int?> lastMessageType = const Value.absent(),
                Value<int?> lastMessageStatus = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String> participantsJson = const Value.absent(),
              }) => LocalConversationsCompanion.insert(
                conversID: conversID,
                isGroup: isGroup,
                groupName: groupName,
                groupPhoto: groupPhoto,
                lastMessage: lastMessage,
                lastMessageAt: lastMessageAt,
                lastMessageSenderID: lastMessageSenderID,
                lastMessageType: lastMessageType,
                lastMessageStatus: lastMessageStatus,
                unreadCount: unreadCount,
                isPinned: isPinned,
                isArchived: isArchived,
                participantsJson: participantsJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalConversationsTable,
      LocalConversation,
      $$LocalConversationsTableFilterComposer,
      $$LocalConversationsTableOrderingComposer,
      $$LocalConversationsTableAnnotationComposer,
      $$LocalConversationsTableCreateCompanionBuilder,
      $$LocalConversationsTableUpdateCompanionBuilder,
      (
        LocalConversation,
        BaseReferences<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation
        >,
      ),
      LocalConversation,
      PrefetchHooks Function()
    >;
typedef $$LocalMessagesTableCreateCompanionBuilder =
    LocalMessagesCompanion Function({
      required String clientId,
      Value<int> msgID,
      required int conversationID,
      required int senderID,
      Value<String?> content,
      Value<int> type,
      Value<int> status,
      required DateTime sendAt,
      Value<DateTime?> deliveredAt,
      Value<DateTime?> readAt,
      Value<String?> mediaUrl,
      Value<String?> mediaName,
      Value<int?> mediaDuration,
      Value<String?> localMediaPath,
      Value<String?> pendingUploadPath,
      Value<int?> replyToID,
      Value<String?> replyToContent,
      Value<bool> isEdited,
      Value<DateTime?> editedAt,
      Value<bool> isDeleted,
      Value<int?> deletedForID,
      Value<int> isStatusReply,
      Value<bool> isForwarded,
      Value<bool> isPinned,
      Value<bool> isViewOnce,
      Value<DateTime?> viewedAt,
      Value<String?> senderNom,
      Value<String?> senderPseudo,
      Value<String?> senderAvatar,
      Value<bool> syncPending,
      Value<DateTime?> lastEmittedAt,
      Value<int> retryCount,
      Value<int> rowid,
    });
typedef $$LocalMessagesTableUpdateCompanionBuilder =
    LocalMessagesCompanion Function({
      Value<String> clientId,
      Value<int> msgID,
      Value<int> conversationID,
      Value<int> senderID,
      Value<String?> content,
      Value<int> type,
      Value<int> status,
      Value<DateTime> sendAt,
      Value<DateTime?> deliveredAt,
      Value<DateTime?> readAt,
      Value<String?> mediaUrl,
      Value<String?> mediaName,
      Value<int?> mediaDuration,
      Value<String?> localMediaPath,
      Value<String?> pendingUploadPath,
      Value<int?> replyToID,
      Value<String?> replyToContent,
      Value<bool> isEdited,
      Value<DateTime?> editedAt,
      Value<bool> isDeleted,
      Value<int?> deletedForID,
      Value<int> isStatusReply,
      Value<bool> isForwarded,
      Value<bool> isPinned,
      Value<bool> isViewOnce,
      Value<DateTime?> viewedAt,
      Value<String?> senderNom,
      Value<String?> senderPseudo,
      Value<String?> senderAvatar,
      Value<bool> syncPending,
      Value<DateTime?> lastEmittedAt,
      Value<int> retryCount,
      Value<int> rowid,
    });

class $$LocalMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get msgID => $composableBuilder(
    column: $table.msgID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationID => $composableBuilder(
    column: $table.conversationID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get senderID => $composableBuilder(
    column: $table.senderID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sendAt => $composableBuilder(
    column: $table.sendAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaName => $composableBuilder(
    column: $table.mediaName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaDuration => $composableBuilder(
    column: $table.mediaDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localMediaPath => $composableBuilder(
    column: $table.localMediaPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingUploadPath => $composableBuilder(
    column: $table.pendingUploadPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get replyToID => $composableBuilder(
    column: $table.replyToID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToContent => $composableBuilder(
    column: $table.replyToContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedForID => $composableBuilder(
    column: $table.deletedForID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isStatusReply => $composableBuilder(
    column: $table.isStatusReply,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isViewOnce => $composableBuilder(
    column: $table.isViewOnce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get viewedAt => $composableBuilder(
    column: $table.viewedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderNom => $composableBuilder(
    column: $table.senderNom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderPseudo => $composableBuilder(
    column: $table.senderPseudo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderAvatar => $composableBuilder(
    column: $table.senderAvatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastEmittedAt => $composableBuilder(
    column: $table.lastEmittedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get msgID => $composableBuilder(
    column: $table.msgID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationID => $composableBuilder(
    column: $table.conversationID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get senderID => $composableBuilder(
    column: $table.senderID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sendAt => $composableBuilder(
    column: $table.sendAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaName => $composableBuilder(
    column: $table.mediaName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaDuration => $composableBuilder(
    column: $table.mediaDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localMediaPath => $composableBuilder(
    column: $table.localMediaPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingUploadPath => $composableBuilder(
    column: $table.pendingUploadPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get replyToID => $composableBuilder(
    column: $table.replyToID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToContent => $composableBuilder(
    column: $table.replyToContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedForID => $composableBuilder(
    column: $table.deletedForID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isStatusReply => $composableBuilder(
    column: $table.isStatusReply,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isViewOnce => $composableBuilder(
    column: $table.isViewOnce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get viewedAt => $composableBuilder(
    column: $table.viewedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderNom => $composableBuilder(
    column: $table.senderNom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderPseudo => $composableBuilder(
    column: $table.senderPseudo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderAvatar => $composableBuilder(
    column: $table.senderAvatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastEmittedAt => $composableBuilder(
    column: $table.lastEmittedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<int> get msgID =>
      $composableBuilder(column: $table.msgID, builder: (column) => column);

  GeneratedColumn<int> get conversationID => $composableBuilder(
    column: $table.conversationID,
    builder: (column) => column,
  );

  GeneratedColumn<int> get senderID =>
      $composableBuilder(column: $table.senderID, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get sendAt =>
      $composableBuilder(column: $table.sendAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get mediaName =>
      $composableBuilder(column: $table.mediaName, builder: (column) => column);

  GeneratedColumn<int> get mediaDuration => $composableBuilder(
    column: $table.mediaDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localMediaPath => $composableBuilder(
    column: $table.localMediaPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pendingUploadPath => $composableBuilder(
    column: $table.pendingUploadPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get replyToID =>
      $composableBuilder(column: $table.replyToID, builder: (column) => column);

  GeneratedColumn<String> get replyToContent => $composableBuilder(
    column: $table.replyToContent,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get deletedForID => $composableBuilder(
    column: $table.deletedForID,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isStatusReply => $composableBuilder(
    column: $table.isStatusReply,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isForwarded => $composableBuilder(
    column: $table.isForwarded,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isViewOnce => $composableBuilder(
    column: $table.isViewOnce,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get viewedAt =>
      $composableBuilder(column: $table.viewedAt, builder: (column) => column);

  GeneratedColumn<String> get senderNom =>
      $composableBuilder(column: $table.senderNom, builder: (column) => column);

  GeneratedColumn<String> get senderPseudo => $composableBuilder(
    column: $table.senderPseudo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderAvatar => $composableBuilder(
    column: $table.senderAvatar,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastEmittedAt => $composableBuilder(
    column: $table.lastEmittedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );
}

class $$LocalMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMessagesTable,
          LocalMessage,
          $$LocalMessagesTableFilterComposer,
          $$LocalMessagesTableOrderingComposer,
          $$LocalMessagesTableAnnotationComposer,
          $$LocalMessagesTableCreateCompanionBuilder,
          $$LocalMessagesTableUpdateCompanionBuilder,
          (
            LocalMessage,
            BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
          ),
          LocalMessage,
          PrefetchHooks Function()
        > {
  $$LocalMessagesTableTableManager(_$AppDatabase db, $LocalMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientId = const Value.absent(),
                Value<int> msgID = const Value.absent(),
                Value<int> conversationID = const Value.absent(),
                Value<int> senderID = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime> sendAt = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaName = const Value.absent(),
                Value<int?> mediaDuration = const Value.absent(),
                Value<String?> localMediaPath = const Value.absent(),
                Value<String?> pendingUploadPath = const Value.absent(),
                Value<int?> replyToID = const Value.absent(),
                Value<String?> replyToContent = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<DateTime?> editedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedForID = const Value.absent(),
                Value<int> isStatusReply = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isViewOnce = const Value.absent(),
                Value<DateTime?> viewedAt = const Value.absent(),
                Value<String?> senderNom = const Value.absent(),
                Value<String?> senderPseudo = const Value.absent(),
                Value<String?> senderAvatar = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<DateTime?> lastEmittedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion(
                clientId: clientId,
                msgID: msgID,
                conversationID: conversationID,
                senderID: senderID,
                content: content,
                type: type,
                status: status,
                sendAt: sendAt,
                deliveredAt: deliveredAt,
                readAt: readAt,
                mediaUrl: mediaUrl,
                mediaName: mediaName,
                mediaDuration: mediaDuration,
                localMediaPath: localMediaPath,
                pendingUploadPath: pendingUploadPath,
                replyToID: replyToID,
                replyToContent: replyToContent,
                isEdited: isEdited,
                editedAt: editedAt,
                isDeleted: isDeleted,
                deletedForID: deletedForID,
                isStatusReply: isStatusReply,
                isForwarded: isForwarded,
                isPinned: isPinned,
                isViewOnce: isViewOnce,
                viewedAt: viewedAt,
                senderNom: senderNom,
                senderPseudo: senderPseudo,
                senderAvatar: senderAvatar,
                syncPending: syncPending,
                lastEmittedAt: lastEmittedAt,
                retryCount: retryCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientId,
                Value<int> msgID = const Value.absent(),
                required int conversationID,
                required int senderID,
                Value<String?> content = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> status = const Value.absent(),
                required DateTime sendAt,
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaName = const Value.absent(),
                Value<int?> mediaDuration = const Value.absent(),
                Value<String?> localMediaPath = const Value.absent(),
                Value<String?> pendingUploadPath = const Value.absent(),
                Value<int?> replyToID = const Value.absent(),
                Value<String?> replyToContent = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<DateTime?> editedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> deletedForID = const Value.absent(),
                Value<int> isStatusReply = const Value.absent(),
                Value<bool> isForwarded = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isViewOnce = const Value.absent(),
                Value<DateTime?> viewedAt = const Value.absent(),
                Value<String?> senderNom = const Value.absent(),
                Value<String?> senderPseudo = const Value.absent(),
                Value<String?> senderAvatar = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<DateTime?> lastEmittedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion.insert(
                clientId: clientId,
                msgID: msgID,
                conversationID: conversationID,
                senderID: senderID,
                content: content,
                type: type,
                status: status,
                sendAt: sendAt,
                deliveredAt: deliveredAt,
                readAt: readAt,
                mediaUrl: mediaUrl,
                mediaName: mediaName,
                mediaDuration: mediaDuration,
                localMediaPath: localMediaPath,
                pendingUploadPath: pendingUploadPath,
                replyToID: replyToID,
                replyToContent: replyToContent,
                isEdited: isEdited,
                editedAt: editedAt,
                isDeleted: isDeleted,
                deletedForID: deletedForID,
                isStatusReply: isStatusReply,
                isForwarded: isForwarded,
                isPinned: isPinned,
                isViewOnce: isViewOnce,
                viewedAt: viewedAt,
                senderNom: senderNom,
                senderPseudo: senderPseudo,
                senderAvatar: senderAvatar,
                syncPending: syncPending,
                lastEmittedAt: lastEmittedAt,
                retryCount: retryCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMessagesTable,
      LocalMessage,
      $$LocalMessagesTableFilterComposer,
      $$LocalMessagesTableOrderingComposer,
      $$LocalMessagesTableAnnotationComposer,
      $$LocalMessagesTableCreateCompanionBuilder,
      $$LocalMessagesTableUpdateCompanionBuilder,
      (
        LocalMessage,
        BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
      ),
      LocalMessage,
      PrefetchHooks Function()
    >;
typedef $$LocalUsersTableCreateCompanionBuilder =
    LocalUsersCompanion Function({
      Value<int> alanyaID,
      Value<String> nom,
      Value<String> pseudo,
      Value<String> alanyaPhone,
      Value<String> email,
      Value<String> avatarUrl,
      Value<int> idPays,
      Value<String?> paysLibelle,
      Value<bool> isOnline,
      Value<DateTime?> lastSeen,
      Value<bool> isPreferredContact,
      Value<int> typeCompte,
      required DateTime cachedAt,
    });
typedef $$LocalUsersTableUpdateCompanionBuilder =
    LocalUsersCompanion Function({
      Value<int> alanyaID,
      Value<String> nom,
      Value<String> pseudo,
      Value<String> alanyaPhone,
      Value<String> email,
      Value<String> avatarUrl,
      Value<int> idPays,
      Value<String?> paysLibelle,
      Value<bool> isOnline,
      Value<DateTime?> lastSeen,
      Value<bool> isPreferredContact,
      Value<int> typeCompte,
      Value<DateTime> cachedAt,
    });

class $$LocalUsersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalUsersTable> {
  $$LocalUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get alanyaID => $composableBuilder(
    column: $table.alanyaID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nom => $composableBuilder(
    column: $table.nom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pseudo => $composableBuilder(
    column: $table.pseudo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alanyaPhone => $composableBuilder(
    column: $table.alanyaPhone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idPays => $composableBuilder(
    column: $table.idPays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paysLibelle => $composableBuilder(
    column: $table.paysLibelle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPreferredContact => $composableBuilder(
    column: $table.isPreferredContact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeCompte => $composableBuilder(
    column: $table.typeCompte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalUsersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalUsersTable> {
  $$LocalUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get alanyaID => $composableBuilder(
    column: $table.alanyaID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nom => $composableBuilder(
    column: $table.nom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pseudo => $composableBuilder(
    column: $table.pseudo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alanyaPhone => $composableBuilder(
    column: $table.alanyaPhone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idPays => $composableBuilder(
    column: $table.idPays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paysLibelle => $composableBuilder(
    column: $table.paysLibelle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOnline => $composableBuilder(
    column: $table.isOnline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPreferredContact => $composableBuilder(
    column: $table.isPreferredContact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeCompte => $composableBuilder(
    column: $table.typeCompte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalUsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalUsersTable> {
  $$LocalUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get alanyaID =>
      $composableBuilder(column: $table.alanyaID, builder: (column) => column);

  GeneratedColumn<String> get nom =>
      $composableBuilder(column: $table.nom, builder: (column) => column);

  GeneratedColumn<String> get pseudo =>
      $composableBuilder(column: $table.pseudo, builder: (column) => column);

  GeneratedColumn<String> get alanyaPhone => $composableBuilder(
    column: $table.alanyaPhone,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<int> get idPays =>
      $composableBuilder(column: $table.idPays, builder: (column) => column);

  GeneratedColumn<String> get paysLibelle => $composableBuilder(
    column: $table.paysLibelle,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOnline =>
      $composableBuilder(column: $table.isOnline, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<bool> get isPreferredContact => $composableBuilder(
    column: $table.isPreferredContact,
    builder: (column) => column,
  );

  GeneratedColumn<int> get typeCompte => $composableBuilder(
    column: $table.typeCompte,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$LocalUsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalUsersTable,
          LocalUser,
          $$LocalUsersTableFilterComposer,
          $$LocalUsersTableOrderingComposer,
          $$LocalUsersTableAnnotationComposer,
          $$LocalUsersTableCreateCompanionBuilder,
          $$LocalUsersTableUpdateCompanionBuilder,
          (
            LocalUser,
            BaseReferences<_$AppDatabase, $LocalUsersTable, LocalUser>,
          ),
          LocalUser,
          PrefetchHooks Function()
        > {
  $$LocalUsersTableTableManager(_$AppDatabase db, $LocalUsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> alanyaID = const Value.absent(),
                Value<String> nom = const Value.absent(),
                Value<String> pseudo = const Value.absent(),
                Value<String> alanyaPhone = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> avatarUrl = const Value.absent(),
                Value<int> idPays = const Value.absent(),
                Value<String?> paysLibelle = const Value.absent(),
                Value<bool> isOnline = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<bool> isPreferredContact = const Value.absent(),
                Value<int> typeCompte = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => LocalUsersCompanion(
                alanyaID: alanyaID,
                nom: nom,
                pseudo: pseudo,
                alanyaPhone: alanyaPhone,
                email: email,
                avatarUrl: avatarUrl,
                idPays: idPays,
                paysLibelle: paysLibelle,
                isOnline: isOnline,
                lastSeen: lastSeen,
                isPreferredContact: isPreferredContact,
                typeCompte: typeCompte,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> alanyaID = const Value.absent(),
                Value<String> nom = const Value.absent(),
                Value<String> pseudo = const Value.absent(),
                Value<String> alanyaPhone = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> avatarUrl = const Value.absent(),
                Value<int> idPays = const Value.absent(),
                Value<String?> paysLibelle = const Value.absent(),
                Value<bool> isOnline = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<bool> isPreferredContact = const Value.absent(),
                Value<int> typeCompte = const Value.absent(),
                required DateTime cachedAt,
              }) => LocalUsersCompanion.insert(
                alanyaID: alanyaID,
                nom: nom,
                pseudo: pseudo,
                alanyaPhone: alanyaPhone,
                email: email,
                avatarUrl: avatarUrl,
                idPays: idPays,
                paysLibelle: paysLibelle,
                isOnline: isOnline,
                lastSeen: lastSeen,
                isPreferredContact: isPreferredContact,
                typeCompte: typeCompte,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalUsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalUsersTable,
      LocalUser,
      $$LocalUsersTableFilterComposer,
      $$LocalUsersTableOrderingComposer,
      $$LocalUsersTableAnnotationComposer,
      $$LocalUsersTableCreateCompanionBuilder,
      $$LocalUsersTableUpdateCompanionBuilder,
      (LocalUser, BaseReferences<_$AppDatabase, $LocalUsersTable, LocalUser>),
      LocalUser,
      PrefetchHooks Function()
    >;
typedef $$LocalCallsTableCreateCompanionBuilder =
    LocalCallsCompanion Function({
      Value<int> idCall,
      required int idCaller,
      required int idReceiver,
      Value<int> type,
      Value<int> status,
      Value<int?> duration,
      required DateTime createdAt,
      Value<String?> otherNom,
      Value<String?> otherAvatar,
    });
typedef $$LocalCallsTableUpdateCompanionBuilder =
    LocalCallsCompanion Function({
      Value<int> idCall,
      Value<int> idCaller,
      Value<int> idReceiver,
      Value<int> type,
      Value<int> status,
      Value<int?> duration,
      Value<DateTime> createdAt,
      Value<String?> otherNom,
      Value<String?> otherAvatar,
    });

class $$LocalCallsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalCallsTable> {
  $$LocalCallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get idCall => $composableBuilder(
    column: $table.idCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idCaller => $composableBuilder(
    column: $table.idCaller,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idReceiver => $composableBuilder(
    column: $table.idReceiver,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherNom => $composableBuilder(
    column: $table.otherNom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherAvatar => $composableBuilder(
    column: $table.otherAvatar,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCallsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalCallsTable> {
  $$LocalCallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get idCall => $composableBuilder(
    column: $table.idCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idCaller => $composableBuilder(
    column: $table.idCaller,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idReceiver => $composableBuilder(
    column: $table.idReceiver,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherNom => $composableBuilder(
    column: $table.otherNom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherAvatar => $composableBuilder(
    column: $table.otherAvatar,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCallsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalCallsTable> {
  $$LocalCallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get idCall =>
      $composableBuilder(column: $table.idCall, builder: (column) => column);

  GeneratedColumn<int> get idCaller =>
      $composableBuilder(column: $table.idCaller, builder: (column) => column);

  GeneratedColumn<int> get idReceiver => $composableBuilder(
    column: $table.idReceiver,
    builder: (column) => column,
  );

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get otherNom =>
      $composableBuilder(column: $table.otherNom, builder: (column) => column);

  GeneratedColumn<String> get otherAvatar => $composableBuilder(
    column: $table.otherAvatar,
    builder: (column) => column,
  );
}

class $$LocalCallsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalCallsTable,
          LocalCall,
          $$LocalCallsTableFilterComposer,
          $$LocalCallsTableOrderingComposer,
          $$LocalCallsTableAnnotationComposer,
          $$LocalCallsTableCreateCompanionBuilder,
          $$LocalCallsTableUpdateCompanionBuilder,
          (
            LocalCall,
            BaseReferences<_$AppDatabase, $LocalCallsTable, LocalCall>,
          ),
          LocalCall,
          PrefetchHooks Function()
        > {
  $$LocalCallsTableTableManager(_$AppDatabase db, $LocalCallsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> idCall = const Value.absent(),
                Value<int> idCaller = const Value.absent(),
                Value<int> idReceiver = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> otherNom = const Value.absent(),
                Value<String?> otherAvatar = const Value.absent(),
              }) => LocalCallsCompanion(
                idCall: idCall,
                idCaller: idCaller,
                idReceiver: idReceiver,
                type: type,
                status: status,
                duration: duration,
                createdAt: createdAt,
                otherNom: otherNom,
                otherAvatar: otherAvatar,
              ),
          createCompanionCallback:
              ({
                Value<int> idCall = const Value.absent(),
                required int idCaller,
                required int idReceiver,
                Value<int> type = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int?> duration = const Value.absent(),
                required DateTime createdAt,
                Value<String?> otherNom = const Value.absent(),
                Value<String?> otherAvatar = const Value.absent(),
              }) => LocalCallsCompanion.insert(
                idCall: idCall,
                idCaller: idCaller,
                idReceiver: idReceiver,
                type: type,
                status: status,
                duration: duration,
                createdAt: createdAt,
                otherNom: otherNom,
                otherAvatar: otherAvatar,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCallsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalCallsTable,
      LocalCall,
      $$LocalCallsTableFilterComposer,
      $$LocalCallsTableOrderingComposer,
      $$LocalCallsTableAnnotationComposer,
      $$LocalCallsTableCreateCompanionBuilder,
      $$LocalCallsTableUpdateCompanionBuilder,
      (LocalCall, BaseReferences<_$AppDatabase, $LocalCallsTable, LocalCall>),
      LocalCall,
      PrefetchHooks Function()
    >;
typedef $$LocalMeetingsTableCreateCompanionBuilder =
    LocalMeetingsCompanion Function({
      Value<int> idMeeting,
      Value<String> objet,
      Value<String> room,
      required DateTime startTime,
      Value<int> duree,
      Value<int> typeMedia,
      Value<int> organiserID,
      Value<String?> organiserNom,
      Value<String> participantsJson,
      Value<int> statut,
      required DateTime cachedAt,
    });
typedef $$LocalMeetingsTableUpdateCompanionBuilder =
    LocalMeetingsCompanion Function({
      Value<int> idMeeting,
      Value<String> objet,
      Value<String> room,
      Value<DateTime> startTime,
      Value<int> duree,
      Value<int> typeMedia,
      Value<int> organiserID,
      Value<String?> organiserNom,
      Value<String> participantsJson,
      Value<int> statut,
      Value<DateTime> cachedAt,
    });

class $$LocalMeetingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMeetingsTable> {
  $$LocalMeetingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get idMeeting => $composableBuilder(
    column: $table.idMeeting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objet => $composableBuilder(
    column: $table.objet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get room => $composableBuilder(
    column: $table.room,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duree => $composableBuilder(
    column: $table.duree,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeMedia => $composableBuilder(
    column: $table.typeMedia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get organiserID => $composableBuilder(
    column: $table.organiserID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organiserNom => $composableBuilder(
    column: $table.organiserNom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get participantsJson => $composableBuilder(
    column: $table.participantsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMeetingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMeetingsTable> {
  $$LocalMeetingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get idMeeting => $composableBuilder(
    column: $table.idMeeting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objet => $composableBuilder(
    column: $table.objet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get room => $composableBuilder(
    column: $table.room,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duree => $composableBuilder(
    column: $table.duree,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeMedia => $composableBuilder(
    column: $table.typeMedia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get organiserID => $composableBuilder(
    column: $table.organiserID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organiserNom => $composableBuilder(
    column: $table.organiserNom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get participantsJson => $composableBuilder(
    column: $table.participantsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMeetingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMeetingsTable> {
  $$LocalMeetingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get idMeeting =>
      $composableBuilder(column: $table.idMeeting, builder: (column) => column);

  GeneratedColumn<String> get objet =>
      $composableBuilder(column: $table.objet, builder: (column) => column);

  GeneratedColumn<String> get room =>
      $composableBuilder(column: $table.room, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<int> get duree =>
      $composableBuilder(column: $table.duree, builder: (column) => column);

  GeneratedColumn<int> get typeMedia =>
      $composableBuilder(column: $table.typeMedia, builder: (column) => column);

  GeneratedColumn<int> get organiserID => $composableBuilder(
    column: $table.organiserID,
    builder: (column) => column,
  );

  GeneratedColumn<String> get organiserNom => $composableBuilder(
    column: $table.organiserNom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get participantsJson => $composableBuilder(
    column: $table.participantsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statut =>
      $composableBuilder(column: $table.statut, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$LocalMeetingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMeetingsTable,
          LocalMeeting,
          $$LocalMeetingsTableFilterComposer,
          $$LocalMeetingsTableOrderingComposer,
          $$LocalMeetingsTableAnnotationComposer,
          $$LocalMeetingsTableCreateCompanionBuilder,
          $$LocalMeetingsTableUpdateCompanionBuilder,
          (
            LocalMeeting,
            BaseReferences<_$AppDatabase, $LocalMeetingsTable, LocalMeeting>,
          ),
          LocalMeeting,
          PrefetchHooks Function()
        > {
  $$LocalMeetingsTableTableManager(_$AppDatabase db, $LocalMeetingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMeetingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMeetingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMeetingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> idMeeting = const Value.absent(),
                Value<String> objet = const Value.absent(),
                Value<String> room = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<int> duree = const Value.absent(),
                Value<int> typeMedia = const Value.absent(),
                Value<int> organiserID = const Value.absent(),
                Value<String?> organiserNom = const Value.absent(),
                Value<String> participantsJson = const Value.absent(),
                Value<int> statut = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => LocalMeetingsCompanion(
                idMeeting: idMeeting,
                objet: objet,
                room: room,
                startTime: startTime,
                duree: duree,
                typeMedia: typeMedia,
                organiserID: organiserID,
                organiserNom: organiserNom,
                participantsJson: participantsJson,
                statut: statut,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> idMeeting = const Value.absent(),
                Value<String> objet = const Value.absent(),
                Value<String> room = const Value.absent(),
                required DateTime startTime,
                Value<int> duree = const Value.absent(),
                Value<int> typeMedia = const Value.absent(),
                Value<int> organiserID = const Value.absent(),
                Value<String?> organiserNom = const Value.absent(),
                Value<String> participantsJson = const Value.absent(),
                Value<int> statut = const Value.absent(),
                required DateTime cachedAt,
              }) => LocalMeetingsCompanion.insert(
                idMeeting: idMeeting,
                objet: objet,
                room: room,
                startTime: startTime,
                duree: duree,
                typeMedia: typeMedia,
                organiserID: organiserID,
                organiserNom: organiserNom,
                participantsJson: participantsJson,
                statut: statut,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMeetingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMeetingsTable,
      LocalMeeting,
      $$LocalMeetingsTableFilterComposer,
      $$LocalMeetingsTableOrderingComposer,
      $$LocalMeetingsTableAnnotationComposer,
      $$LocalMeetingsTableCreateCompanionBuilder,
      $$LocalMeetingsTableUpdateCompanionBuilder,
      (
        LocalMeeting,
        BaseReferences<_$AppDatabase, $LocalMeetingsTable, LocalMeeting>,
      ),
      LocalMeeting,
      PrefetchHooks Function()
    >;
typedef $$LocalStatusesTableCreateCompanionBuilder =
    LocalStatusesCompanion Function({
      Value<int> idStatut,
      required int authorID,
      Value<String?> authorNom,
      Value<String?> authorAvatar,
      Value<int> type,
      Value<String?> textContent,
      Value<String?> mediaUrl,
      Value<String?> localMediaPath,
      Value<String?> backgroundColor,
      Value<int?> mediaDurationMs,
      required DateTime createdAt,
      required DateTime expiresAt,
      Value<bool> isMine,
    });
typedef $$LocalStatusesTableUpdateCompanionBuilder =
    LocalStatusesCompanion Function({
      Value<int> idStatut,
      Value<int> authorID,
      Value<String?> authorNom,
      Value<String?> authorAvatar,
      Value<int> type,
      Value<String?> textContent,
      Value<String?> mediaUrl,
      Value<String?> localMediaPath,
      Value<String?> backgroundColor,
      Value<int?> mediaDurationMs,
      Value<DateTime> createdAt,
      Value<DateTime> expiresAt,
      Value<bool> isMine,
    });

class $$LocalStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStatusesTable> {
  $$LocalStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get idStatut => $composableBuilder(
    column: $table.idStatut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get authorID => $composableBuilder(
    column: $table.authorID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorNom => $composableBuilder(
    column: $table.authorNom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorAvatar => $composableBuilder(
    column: $table.authorAvatar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localMediaPath => $composableBuilder(
    column: $table.localMediaPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaDurationMs => $composableBuilder(
    column: $table.mediaDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMine => $composableBuilder(
    column: $table.isMine,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStatusesTable> {
  $$LocalStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get idStatut => $composableBuilder(
    column: $table.idStatut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get authorID => $composableBuilder(
    column: $table.authorID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorNom => $composableBuilder(
    column: $table.authorNom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorAvatar => $composableBuilder(
    column: $table.authorAvatar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localMediaPath => $composableBuilder(
    column: $table.localMediaPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaDurationMs => $composableBuilder(
    column: $table.mediaDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMine => $composableBuilder(
    column: $table.isMine,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStatusesTable> {
  $$LocalStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get idStatut =>
      $composableBuilder(column: $table.idStatut, builder: (column) => column);

  GeneratedColumn<int> get authorID =>
      $composableBuilder(column: $table.authorID, builder: (column) => column);

  GeneratedColumn<String> get authorNom =>
      $composableBuilder(column: $table.authorNom, builder: (column) => column);

  GeneratedColumn<String> get authorAvatar => $composableBuilder(
    column: $table.authorAvatar,
    builder: (column) => column,
  );

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get localMediaPath => $composableBuilder(
    column: $table.localMediaPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backgroundColor => $composableBuilder(
    column: $table.backgroundColor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaDurationMs => $composableBuilder(
    column: $table.mediaDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<bool> get isMine =>
      $composableBuilder(column: $table.isMine, builder: (column) => column);
}

class $$LocalStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStatusesTable,
          LocalStatuse,
          $$LocalStatusesTableFilterComposer,
          $$LocalStatusesTableOrderingComposer,
          $$LocalStatusesTableAnnotationComposer,
          $$LocalStatusesTableCreateCompanionBuilder,
          $$LocalStatusesTableUpdateCompanionBuilder,
          (
            LocalStatuse,
            BaseReferences<_$AppDatabase, $LocalStatusesTable, LocalStatuse>,
          ),
          LocalStatuse,
          PrefetchHooks Function()
        > {
  $$LocalStatusesTableTableManager(_$AppDatabase db, $LocalStatusesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStatusesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStatusesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> idStatut = const Value.absent(),
                Value<int> authorID = const Value.absent(),
                Value<String?> authorNom = const Value.absent(),
                Value<String?> authorAvatar = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> localMediaPath = const Value.absent(),
                Value<String?> backgroundColor = const Value.absent(),
                Value<int?> mediaDurationMs = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<bool> isMine = const Value.absent(),
              }) => LocalStatusesCompanion(
                idStatut: idStatut,
                authorID: authorID,
                authorNom: authorNom,
                authorAvatar: authorAvatar,
                type: type,
                textContent: textContent,
                mediaUrl: mediaUrl,
                localMediaPath: localMediaPath,
                backgroundColor: backgroundColor,
                mediaDurationMs: mediaDurationMs,
                createdAt: createdAt,
                expiresAt: expiresAt,
                isMine: isMine,
              ),
          createCompanionCallback:
              ({
                Value<int> idStatut = const Value.absent(),
                required int authorID,
                Value<String?> authorNom = const Value.absent(),
                Value<String?> authorAvatar = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> localMediaPath = const Value.absent(),
                Value<String?> backgroundColor = const Value.absent(),
                Value<int?> mediaDurationMs = const Value.absent(),
                required DateTime createdAt,
                required DateTime expiresAt,
                Value<bool> isMine = const Value.absent(),
              }) => LocalStatusesCompanion.insert(
                idStatut: idStatut,
                authorID: authorID,
                authorNom: authorNom,
                authorAvatar: authorAvatar,
                type: type,
                textContent: textContent,
                mediaUrl: mediaUrl,
                localMediaPath: localMediaPath,
                backgroundColor: backgroundColor,
                mediaDurationMs: mediaDurationMs,
                createdAt: createdAt,
                expiresAt: expiresAt,
                isMine: isMine,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStatusesTable,
      LocalStatuse,
      $$LocalStatusesTableFilterComposer,
      $$LocalStatusesTableOrderingComposer,
      $$LocalStatusesTableAnnotationComposer,
      $$LocalStatusesTableCreateCompanionBuilder,
      $$LocalStatusesTableUpdateCompanionBuilder,
      (
        LocalStatuse,
        BaseReferences<_$AppDatabase, $LocalStatusesTable, LocalStatuse>,
      ),
      LocalStatuse,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalConversationsTableTableManager get localConversations =>
      $$LocalConversationsTableTableManager(_db, _db.localConversations);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
  $$LocalUsersTableTableManager get localUsers =>
      $$LocalUsersTableTableManager(_db, _db.localUsers);
  $$LocalCallsTableTableManager get localCalls =>
      $$LocalCallsTableTableManager(_db, _db.localCalls);
  $$LocalMeetingsTableTableManager get localMeetings =>
      $$LocalMeetingsTableTableManager(_db, _db.localMeetings);
  $$LocalStatusesTableTableManager get localStatuses =>
      $$LocalStatusesTableTableManager(_db, _db.localStatuses);
}
