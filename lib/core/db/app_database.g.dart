part of 'app_database.dart';

 
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
    readAt,
    mediaUrl,
    mediaName,
    mediaDuration,
    localMediaPath,
    pendingUploadPath,
    replyToID,
    replyToContent,
    isEdited,
    isDeleted,
    isStatusReply,
    senderNom,
    senderPseudo,
    senderAvatar,
    syncPending,
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
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
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
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      isStatusReply: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_status_reply'],
      )!,
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
  final bool isDeleted;
  final int isStatusReply;
  final String? senderNom;
  final String? senderPseudo;
  final String? senderAvatar;

  /// true tant que le message n'a pas été remis au serveur (outbox).
  final bool syncPending;
  const LocalMessage({
    required this.clientId,
    required this.msgID,
    required this.conversationID,
    required this.senderID,
    this.content,
    required this.type,
    required this.status,
    required this.sendAt,
    this.readAt,
    this.mediaUrl,
    this.mediaName,
    this.mediaDuration,
    this.localMediaPath,
    this.pendingUploadPath,
    this.replyToID,
    this.replyToContent,
    required this.isEdited,
    required this.isDeleted,
    required this.isStatusReply,
    this.senderNom,
    this.senderPseudo,
    this.senderAvatar,
    required this.syncPending,
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
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['is_status_reply'] = Variable<int>(isStatusReply);
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
      isDeleted: Value(isDeleted),
      isStatusReply: Value(isStatusReply),
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
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      isStatusReply: serializer.fromJson<int>(json['isStatusReply']),
      senderNom: serializer.fromJson<String?>(json['senderNom']),
      senderPseudo: serializer.fromJson<String?>(json['senderPseudo']),
      senderAvatar: serializer.fromJson<String?>(json['senderAvatar']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
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
      'readAt': serializer.toJson<DateTime?>(readAt),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'mediaName': serializer.toJson<String?>(mediaName),
      'mediaDuration': serializer.toJson<int?>(mediaDuration),
      'localMediaPath': serializer.toJson<String?>(localMediaPath),
      'pendingUploadPath': serializer.toJson<String?>(pendingUploadPath),
      'replyToID': serializer.toJson<int?>(replyToID),
      'replyToContent': serializer.toJson<String?>(replyToContent),
      'isEdited': serializer.toJson<bool>(isEdited),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'isStatusReply': serializer.toJson<int>(isStatusReply),
      'senderNom': serializer.toJson<String?>(senderNom),
      'senderPseudo': serializer.toJson<String?>(senderPseudo),
      'senderAvatar': serializer.toJson<String?>(senderAvatar),
      'syncPending': serializer.toJson<bool>(syncPending),
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
    Value<DateTime?> readAt = const Value.absent(),
    Value<String?> mediaUrl = const Value.absent(),
    Value<String?> mediaName = const Value.absent(),
    Value<int?> mediaDuration = const Value.absent(),
    Value<String?> localMediaPath = const Value.absent(),
    Value<String?> pendingUploadPath = const Value.absent(),
    Value<int?> replyToID = const Value.absent(),
    Value<String?> replyToContent = const Value.absent(),
    bool? isEdited,
    bool? isDeleted,
    int? isStatusReply,
    Value<String?> senderNom = const Value.absent(),
    Value<String?> senderPseudo = const Value.absent(),
    Value<String?> senderAvatar = const Value.absent(),
    bool? syncPending,
  }) => LocalMessage(
    clientId: clientId ?? this.clientId,
    msgID: msgID ?? this.msgID,
    conversationID: conversationID ?? this.conversationID,
    senderID: senderID ?? this.senderID,
    content: content.present ? content.value : this.content,
    type: type ?? this.type,
    status: status ?? this.status,
    sendAt: sendAt ?? this.sendAt,
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
    isDeleted: isDeleted ?? this.isDeleted,
    isStatusReply: isStatusReply ?? this.isStatusReply,
    senderNom: senderNom.present ? senderNom.value : this.senderNom,
    senderPseudo: senderPseudo.present ? senderPseudo.value : this.senderPseudo,
    senderAvatar: senderAvatar.present ? senderAvatar.value : this.senderAvatar,
    syncPending: syncPending ?? this.syncPending,
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
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      isStatusReply: data.isStatusReply.present
          ? data.isStatusReply.value
          : this.isStatusReply,
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
          ..write('readAt: $readAt, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaName: $mediaName, ')
          ..write('mediaDuration: $mediaDuration, ')
          ..write('localMediaPath: $localMediaPath, ')
          ..write('pendingUploadPath: $pendingUploadPath, ')
          ..write('replyToID: $replyToID, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('isEdited: $isEdited, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isStatusReply: $isStatusReply, ')
          ..write('senderNom: $senderNom, ')
          ..write('senderPseudo: $senderPseudo, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('syncPending: $syncPending')
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
    readAt,
    mediaUrl,
    mediaName,
    mediaDuration,
    localMediaPath,
    pendingUploadPath,
    replyToID,
    replyToContent,
    isEdited,
    isDeleted,
    isStatusReply,
    senderNom,
    senderPseudo,
    senderAvatar,
    syncPending,
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
          other.readAt == this.readAt &&
          other.mediaUrl == this.mediaUrl &&
          other.mediaName == this.mediaName &&
          other.mediaDuration == this.mediaDuration &&
          other.localMediaPath == this.localMediaPath &&
          other.pendingUploadPath == this.pendingUploadPath &&
          other.replyToID == this.replyToID &&
          other.replyToContent == this.replyToContent &&
          other.isEdited == this.isEdited &&
          other.isDeleted == this.isDeleted &&
          other.isStatusReply == this.isStatusReply &&
          other.senderNom == this.senderNom &&
          other.senderPseudo == this.senderPseudo &&
          other.senderAvatar == this.senderAvatar &&
          other.syncPending == this.syncPending);
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
  final Value<DateTime?> readAt;
  final Value<String?> mediaUrl;
  final Value<String?> mediaName;
  final Value<int?> mediaDuration;
  final Value<String?> localMediaPath;
  final Value<String?> pendingUploadPath;
  final Value<int?> replyToID;
  final Value<String?> replyToContent;
  final Value<bool> isEdited;
  final Value<bool> isDeleted;
  final Value<int> isStatusReply;
  final Value<String?> senderNom;
  final Value<String?> senderPseudo;
  final Value<String?> senderAvatar;
  final Value<bool> syncPending;
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
    this.readAt = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaName = const Value.absent(),
    this.mediaDuration = const Value.absent(),
    this.localMediaPath = const Value.absent(),
    this.pendingUploadPath = const Value.absent(),
    this.replyToID = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isStatusReply = const Value.absent(),
    this.senderNom = const Value.absent(),
    this.senderPseudo = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.syncPending = const Value.absent(),
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
    this.readAt = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaName = const Value.absent(),
    this.mediaDuration = const Value.absent(),
    this.localMediaPath = const Value.absent(),
    this.pendingUploadPath = const Value.absent(),
    this.replyToID = const Value.absent(),
    this.replyToContent = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isStatusReply = const Value.absent(),
    this.senderNom = const Value.absent(),
    this.senderPseudo = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.syncPending = const Value.absent(),
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
    Expression<DateTime>? readAt,
    Expression<String>? mediaUrl,
    Expression<String>? mediaName,
    Expression<int>? mediaDuration,
    Expression<String>? localMediaPath,
    Expression<String>? pendingUploadPath,
    Expression<int>? replyToID,
    Expression<String>? replyToContent,
    Expression<bool>? isEdited,
    Expression<bool>? isDeleted,
    Expression<int>? isStatusReply,
    Expression<String>? senderNom,
    Expression<String>? senderPseudo,
    Expression<String>? senderAvatar,
    Expression<bool>? syncPending,
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
      if (readAt != null) 'read_at': readAt,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaName != null) 'media_name': mediaName,
      if (mediaDuration != null) 'media_duration': mediaDuration,
      if (localMediaPath != null) 'local_media_path': localMediaPath,
      if (pendingUploadPath != null) 'pending_upload_path': pendingUploadPath,
      if (replyToID != null) 'reply_to_i_d': replyToID,
      if (replyToContent != null) 'reply_to_content': replyToContent,
      if (isEdited != null) 'is_edited': isEdited,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (isStatusReply != null) 'is_status_reply': isStatusReply,
      if (senderNom != null) 'sender_nom': senderNom,
      if (senderPseudo != null) 'sender_pseudo': senderPseudo,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
      if (syncPending != null) 'sync_pending': syncPending,
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
    Value<DateTime?>? readAt,
    Value<String?>? mediaUrl,
    Value<String?>? mediaName,
    Value<int?>? mediaDuration,
    Value<String?>? localMediaPath,
    Value<String?>? pendingUploadPath,
    Value<int?>? replyToID,
    Value<String?>? replyToContent,
    Value<bool>? isEdited,
    Value<bool>? isDeleted,
    Value<int>? isStatusReply,
    Value<String?>? senderNom,
    Value<String?>? senderPseudo,
    Value<String?>? senderAvatar,
    Value<bool>? syncPending,
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
      readAt: readAt ?? this.readAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaName: mediaName ?? this.mediaName,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      localMediaPath: localMediaPath ?? this.localMediaPath,
      pendingUploadPath: pendingUploadPath ?? this.pendingUploadPath,
      replyToID: replyToID ?? this.replyToID,
      replyToContent: replyToContent ?? this.replyToContent,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isStatusReply: isStatusReply ?? this.isStatusReply,
      senderNom: senderNom ?? this.senderNom,
      senderPseudo: senderPseudo ?? this.senderPseudo,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      syncPending: syncPending ?? this.syncPending,
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
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (isStatusReply.present) {
      map['is_status_reply'] = Variable<int>(isStatusReply.value);
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
          ..write('readAt: $readAt, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaName: $mediaName, ')
          ..write('mediaDuration: $mediaDuration, ')
          ..write('localMediaPath: $localMediaPath, ')
          ..write('pendingUploadPath: $pendingUploadPath, ')
          ..write('replyToID: $replyToID, ')
          ..write('replyToContent: $replyToContent, ')
          ..write('isEdited: $isEdited, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isStatusReply: $isStatusReply, ')
          ..write('senderNom: $senderNom, ')
          ..write('senderPseudo: $senderPseudo, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('syncPending: $syncPending, ')
          ..write('rowid: $rowid')
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
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localConversations,
    localMessages,
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
      Value<DateTime?> readAt,
      Value<String?> mediaUrl,
      Value<String?> mediaName,
      Value<int?> mediaDuration,
      Value<String?> localMediaPath,
      Value<String?> pendingUploadPath,
      Value<int?> replyToID,
      Value<String?> replyToContent,
      Value<bool> isEdited,
      Value<bool> isDeleted,
      Value<int> isStatusReply,
      Value<String?> senderNom,
      Value<String?> senderPseudo,
      Value<String?> senderAvatar,
      Value<bool> syncPending,
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
      Value<DateTime?> readAt,
      Value<String?> mediaUrl,
      Value<String?> mediaName,
      Value<int?> mediaDuration,
      Value<String?> localMediaPath,
      Value<String?> pendingUploadPath,
      Value<int?> replyToID,
      Value<String?> replyToContent,
      Value<bool> isEdited,
      Value<bool> isDeleted,
      Value<int> isStatusReply,
      Value<String?> senderNom,
      Value<String?> senderPseudo,
      Value<String?> senderAvatar,
      Value<bool> syncPending,
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

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isStatusReply => $composableBuilder(
    column: $table.isStatusReply,
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

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isStatusReply => $composableBuilder(
    column: $table.isStatusReply,
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

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get isStatusReply => $composableBuilder(
    column: $table.isStatusReply,
    builder: (column) => column,
  );

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
                Value<DateTime?> readAt = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaName = const Value.absent(),
                Value<int?> mediaDuration = const Value.absent(),
                Value<String?> localMediaPath = const Value.absent(),
                Value<String?> pendingUploadPath = const Value.absent(),
                Value<int?> replyToID = const Value.absent(),
                Value<String?> replyToContent = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> isStatusReply = const Value.absent(),
                Value<String?> senderNom = const Value.absent(),
                Value<String?> senderPseudo = const Value.absent(),
                Value<String?> senderAvatar = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
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
                readAt: readAt,
                mediaUrl: mediaUrl,
                mediaName: mediaName,
                mediaDuration: mediaDuration,
                localMediaPath: localMediaPath,
                pendingUploadPath: pendingUploadPath,
                replyToID: replyToID,
                replyToContent: replyToContent,
                isEdited: isEdited,
                isDeleted: isDeleted,
                isStatusReply: isStatusReply,
                senderNom: senderNom,
                senderPseudo: senderPseudo,
                senderAvatar: senderAvatar,
                syncPending: syncPending,
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
                Value<DateTime?> readAt = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaName = const Value.absent(),
                Value<int?> mediaDuration = const Value.absent(),
                Value<String?> localMediaPath = const Value.absent(),
                Value<String?> pendingUploadPath = const Value.absent(),
                Value<int?> replyToID = const Value.absent(),
                Value<String?> replyToContent = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> isStatusReply = const Value.absent(),
                Value<String?> senderNom = const Value.absent(),
                Value<String?> senderPseudo = const Value.absent(),
                Value<String?> senderAvatar = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
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
                readAt: readAt,
                mediaUrl: mediaUrl,
                mediaName: mediaName,
                mediaDuration: mediaDuration,
                localMediaPath: localMediaPath,
                pendingUploadPath: pendingUploadPath,
                replyToID: replyToID,
                replyToContent: replyToContent,
                isEdited: isEdited,
                isDeleted: isDeleted,
                isStatusReply: isStatusReply,
                senderNom: senderNom,
                senderPseudo: senderPseudo,
                senderAvatar: senderAvatar,
                syncPending: syncPending,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalConversationsTableTableManager get localConversations =>
      $$LocalConversationsTableTableManager(_db, _db.localConversations);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
}
