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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaUpdatedAtMeta = const VerificationMeta(
    'metaUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> metaUpdatedAt =
      GeneratedColumn<DateTime>(
        'meta_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _onlyAdminsCanSendMeta = const VerificationMeta(
    'onlyAdminsCanSend',
  );
  @override
  late final GeneratedColumn<bool> onlyAdminsCanSend = GeneratedColumn<bool>(
    'only_admins_can_send',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("only_admins_can_send" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onlyAdminsCanEditInfoMeta =
      const VerificationMeta('onlyAdminsCanEditInfo');
  @override
  late final GeneratedColumn<bool> onlyAdminsCanEditInfo =
      GeneratedColumn<bool>(
        'only_admins_can_edit_info',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("only_admins_can_edit_info" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _hideHistoryForNewMembersMeta =
      const VerificationMeta('hideHistoryForNewMembers');
  @override
  late final GeneratedColumn<bool> hideHistoryForNewMembers =
      GeneratedColumn<bool>(
        'hide_history_for_new_members',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("hide_history_for_new_members" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _onlyAdminsCanAddMembersMeta =
      const VerificationMeta('onlyAdminsCanAddMembers');
  @override
  late final GeneratedColumn<bool> onlyAdminsCanAddMembers =
      GeneratedColumn<bool>(
        'only_admins_can_add_members',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("only_admins_can_add_members" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _myRoleMeta = const VerificationMeta('myRole');
  @override
  late final GeneratedColumn<int> myRole = GeneratedColumn<int>(
    'my_role',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mutedUntilMeta = const VerificationMeta(
    'mutedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> mutedUntil = GeneratedColumn<DateTime>(
    'muted_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _muteForeverMeta = const VerificationMeta(
    'muteForever',
  );
  @override
  late final GeneratedColumn<bool> muteForever = GeneratedColumn<bool>(
    'mute_forever',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mute_forever" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mentionsOnlyMeta = const VerificationMeta(
    'mentionsOnly',
  );
  @override
  late final GeneratedColumn<bool> mentionsOnly = GeneratedColumn<bool>(
    'mentions_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mentions_only" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _myPendingJoinMsgIDMeta =
      const VerificationMeta('myPendingJoinMsgID');
  @override
  late final GeneratedColumn<int> myPendingJoinMsgID = GeneratedColumn<int>(
    'my_pending_join_msg_i_d',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _myHistoryCutoffAtMeta = const VerificationMeta(
    'myHistoryCutoffAt',
  );
  @override
  late final GeneratedColumn<DateTime> myHistoryCutoffAt =
      GeneratedColumn<DateTime>(
        'my_history_cutoff_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hasUnreadMentionMeta = const VerificationMeta(
    'hasUnreadMention',
  );
  @override
  late final GeneratedColumn<bool> hasUnreadMention = GeneratedColumn<bool>(
    'has_unread_mention',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_unread_mention" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    description,
    createdBy,
    metaUpdatedAt,
    onlyAdminsCanSend,
    onlyAdminsCanEditInfo,
    hideHistoryForNewMembers,
    onlyAdminsCanAddMembers,
    myRole,
    mutedUntil,
    muteForever,
    mentionsOnly,
    myPendingJoinMsgID,
    myHistoryCutoffAt,
    hasUnreadMention,
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('meta_updated_at')) {
      context.handle(
        _metaUpdatedAtMeta,
        metaUpdatedAt.isAcceptableOrUnknown(
          data['meta_updated_at']!,
          _metaUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('only_admins_can_send')) {
      context.handle(
        _onlyAdminsCanSendMeta,
        onlyAdminsCanSend.isAcceptableOrUnknown(
          data['only_admins_can_send']!,
          _onlyAdminsCanSendMeta,
        ),
      );
    }
    if (data.containsKey('only_admins_can_edit_info')) {
      context.handle(
        _onlyAdminsCanEditInfoMeta,
        onlyAdminsCanEditInfo.isAcceptableOrUnknown(
          data['only_admins_can_edit_info']!,
          _onlyAdminsCanEditInfoMeta,
        ),
      );
    }
    if (data.containsKey('hide_history_for_new_members')) {
      context.handle(
        _hideHistoryForNewMembersMeta,
        hideHistoryForNewMembers.isAcceptableOrUnknown(
          data['hide_history_for_new_members']!,
          _hideHistoryForNewMembersMeta,
        ),
      );
    }
    if (data.containsKey('only_admins_can_add_members')) {
      context.handle(
        _onlyAdminsCanAddMembersMeta,
        onlyAdminsCanAddMembers.isAcceptableOrUnknown(
          data['only_admins_can_add_members']!,
          _onlyAdminsCanAddMembersMeta,
        ),
      );
    }
    if (data.containsKey('my_role')) {
      context.handle(
        _myRoleMeta,
        myRole.isAcceptableOrUnknown(data['my_role']!, _myRoleMeta),
      );
    }
    if (data.containsKey('muted_until')) {
      context.handle(
        _mutedUntilMeta,
        mutedUntil.isAcceptableOrUnknown(data['muted_until']!, _mutedUntilMeta),
      );
    }
    if (data.containsKey('mute_forever')) {
      context.handle(
        _muteForeverMeta,
        muteForever.isAcceptableOrUnknown(
          data['mute_forever']!,
          _muteForeverMeta,
        ),
      );
    }
    if (data.containsKey('mentions_only')) {
      context.handle(
        _mentionsOnlyMeta,
        mentionsOnly.isAcceptableOrUnknown(
          data['mentions_only']!,
          _mentionsOnlyMeta,
        ),
      );
    }
    if (data.containsKey('my_pending_join_msg_i_d')) {
      context.handle(
        _myPendingJoinMsgIDMeta,
        myPendingJoinMsgID.isAcceptableOrUnknown(
          data['my_pending_join_msg_i_d']!,
          _myPendingJoinMsgIDMeta,
        ),
      );
    }
    if (data.containsKey('my_history_cutoff_at')) {
      context.handle(
        _myHistoryCutoffAtMeta,
        myHistoryCutoffAt.isAcceptableOrUnknown(
          data['my_history_cutoff_at']!,
          _myHistoryCutoffAtMeta,
        ),
      );
    }
    if (data.containsKey('has_unread_mention')) {
      context.handle(
        _hasUnreadMentionMeta,
        hasUnreadMention.isAcceptableOrUnknown(
          data['has_unread_mention']!,
          _hasUnreadMentionMeta,
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
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      ),
      metaUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}meta_updated_at'],
      ),
      onlyAdminsCanSend: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_admins_can_send'],
      )!,
      onlyAdminsCanEditInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_admins_can_edit_info'],
      )!,
      hideHistoryForNewMembers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hide_history_for_new_members'],
      )!,
      onlyAdminsCanAddMembers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}only_admins_can_add_members'],
      )!,
      myRole: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}my_role'],
      )!,
      mutedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}muted_until'],
      ),
      muteForever: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mute_forever'],
      )!,
      mentionsOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mentions_only'],
      )!,
      myPendingJoinMsgID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}my_pending_join_msg_i_d'],
      ),
      myHistoryCutoffAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}my_history_cutoff_at'],
      ),
      hasUnreadMention: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_unread_mention'],
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

  /// Participants sérialisés tels que renvoyés par le serveur. Le `role` de
  /// chacun voyage dedans : aucune colonne dédiée n'est nécessaire.
  final String participantsJson;
  final String? description;
  final int? createdBy;

  /// `conversation.updatedAt` serveur. Garde anti-réordonnancement : une trame
  /// `conversation:updated` plus ancienne que ce qu'on a déjà est ignorée.
  final DateTime? metaUpdatedAt;
  final bool onlyAdminsCanSend;
  final bool onlyAdminsCanEditInfo;

  /// Masquer l'historique pour les membres ajoutés après activation (défaut OFF).
  final bool hideHistoryForNewMembers;

  /// Seuls les admins peuvent ajouter des membres (défaut OFF = tout le monde).
  final bool onlyAdminsCanAddMembers;

  /// Mon rôle : 0=membre, 1=admin, 2=propriétaire (voir `GroupRole`).
  final int myRole;
  final DateTime? mutedUntil;
  final bool muteForever;
  final bool mentionsOnly;

  /// msgID système `member_added` en attente d'ack « Rester » (null = ok).
  final int? myPendingJoinMsgID;

  /// Borne d'historique pour MOI : null = tout visible ; sinon sendAt >= cutoff.
  final DateTime? myHistoryCutoffAt;

  /// Au moins une mention non lue me ciblant.
  ///
  /// Dérivé par ConversationSummaryReducer à côté de `unreadCount`, et non
  /// calculé par tuile : la liste des discussions ne peut pas se permettre une
  /// requête par ligne à chaque frame.
  final bool hasUnreadMention;
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
    this.description,
    this.createdBy,
    this.metaUpdatedAt,
    required this.onlyAdminsCanSend,
    required this.onlyAdminsCanEditInfo,
    required this.hideHistoryForNewMembers,
    required this.onlyAdminsCanAddMembers,
    required this.myRole,
    this.mutedUntil,
    required this.muteForever,
    required this.mentionsOnly,
    this.myPendingJoinMsgID,
    this.myHistoryCutoffAt,
    required this.hasUnreadMention,
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
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<int>(createdBy);
    }
    if (!nullToAbsent || metaUpdatedAt != null) {
      map['meta_updated_at'] = Variable<DateTime>(metaUpdatedAt);
    }
    map['only_admins_can_send'] = Variable<bool>(onlyAdminsCanSend);
    map['only_admins_can_edit_info'] = Variable<bool>(onlyAdminsCanEditInfo);
    map['hide_history_for_new_members'] = Variable<bool>(
      hideHistoryForNewMembers,
    );
    map['only_admins_can_add_members'] = Variable<bool>(
      onlyAdminsCanAddMembers,
    );
    map['my_role'] = Variable<int>(myRole);
    if (!nullToAbsent || mutedUntil != null) {
      map['muted_until'] = Variable<DateTime>(mutedUntil);
    }
    map['mute_forever'] = Variable<bool>(muteForever);
    map['mentions_only'] = Variable<bool>(mentionsOnly);
    if (!nullToAbsent || myPendingJoinMsgID != null) {
      map['my_pending_join_msg_i_d'] = Variable<int>(myPendingJoinMsgID);
    }
    if (!nullToAbsent || myHistoryCutoffAt != null) {
      map['my_history_cutoff_at'] = Variable<DateTime>(myHistoryCutoffAt);
    }
    map['has_unread_mention'] = Variable<bool>(hasUnreadMention);
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
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      metaUpdatedAt: metaUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(metaUpdatedAt),
      onlyAdminsCanSend: Value(onlyAdminsCanSend),
      onlyAdminsCanEditInfo: Value(onlyAdminsCanEditInfo),
      hideHistoryForNewMembers: Value(hideHistoryForNewMembers),
      onlyAdminsCanAddMembers: Value(onlyAdminsCanAddMembers),
      myRole: Value(myRole),
      mutedUntil: mutedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(mutedUntil),
      muteForever: Value(muteForever),
      mentionsOnly: Value(mentionsOnly),
      myPendingJoinMsgID: myPendingJoinMsgID == null && nullToAbsent
          ? const Value.absent()
          : Value(myPendingJoinMsgID),
      myHistoryCutoffAt: myHistoryCutoffAt == null && nullToAbsent
          ? const Value.absent()
          : Value(myHistoryCutoffAt),
      hasUnreadMention: Value(hasUnreadMention),
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
      description: serializer.fromJson<String?>(json['description']),
      createdBy: serializer.fromJson<int?>(json['createdBy']),
      metaUpdatedAt: serializer.fromJson<DateTime?>(json['metaUpdatedAt']),
      onlyAdminsCanSend: serializer.fromJson<bool>(json['onlyAdminsCanSend']),
      onlyAdminsCanEditInfo: serializer.fromJson<bool>(
        json['onlyAdminsCanEditInfo'],
      ),
      hideHistoryForNewMembers: serializer.fromJson<bool>(
        json['hideHistoryForNewMembers'],
      ),
      onlyAdminsCanAddMembers: serializer.fromJson<bool>(
        json['onlyAdminsCanAddMembers'],
      ),
      myRole: serializer.fromJson<int>(json['myRole']),
      mutedUntil: serializer.fromJson<DateTime?>(json['mutedUntil']),
      muteForever: serializer.fromJson<bool>(json['muteForever']),
      mentionsOnly: serializer.fromJson<bool>(json['mentionsOnly']),
      myPendingJoinMsgID: serializer.fromJson<int?>(json['myPendingJoinMsgID']),
      myHistoryCutoffAt: serializer.fromJson<DateTime?>(
        json['myHistoryCutoffAt'],
      ),
      hasUnreadMention: serializer.fromJson<bool>(json['hasUnreadMention']),
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
      'description': serializer.toJson<String?>(description),
      'createdBy': serializer.toJson<int?>(createdBy),
      'metaUpdatedAt': serializer.toJson<DateTime?>(metaUpdatedAt),
      'onlyAdminsCanSend': serializer.toJson<bool>(onlyAdminsCanSend),
      'onlyAdminsCanEditInfo': serializer.toJson<bool>(onlyAdminsCanEditInfo),
      'hideHistoryForNewMembers': serializer.toJson<bool>(
        hideHistoryForNewMembers,
      ),
      'onlyAdminsCanAddMembers': serializer.toJson<bool>(
        onlyAdminsCanAddMembers,
      ),
      'myRole': serializer.toJson<int>(myRole),
      'mutedUntil': serializer.toJson<DateTime?>(mutedUntil),
      'muteForever': serializer.toJson<bool>(muteForever),
      'mentionsOnly': serializer.toJson<bool>(mentionsOnly),
      'myPendingJoinMsgID': serializer.toJson<int?>(myPendingJoinMsgID),
      'myHistoryCutoffAt': serializer.toJson<DateTime?>(myHistoryCutoffAt),
      'hasUnreadMention': serializer.toJson<bool>(hasUnreadMention),
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
    Value<String?> description = const Value.absent(),
    Value<int?> createdBy = const Value.absent(),
    Value<DateTime?> metaUpdatedAt = const Value.absent(),
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
    bool? hideHistoryForNewMembers,
    bool? onlyAdminsCanAddMembers,
    int? myRole,
    Value<DateTime?> mutedUntil = const Value.absent(),
    bool? muteForever,
    bool? mentionsOnly,
    Value<int?> myPendingJoinMsgID = const Value.absent(),
    Value<DateTime?> myHistoryCutoffAt = const Value.absent(),
    bool? hasUnreadMention,
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
    description: description.present ? description.value : this.description,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    metaUpdatedAt: metaUpdatedAt.present
        ? metaUpdatedAt.value
        : this.metaUpdatedAt,
    onlyAdminsCanSend: onlyAdminsCanSend ?? this.onlyAdminsCanSend,
    onlyAdminsCanEditInfo: onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
    hideHistoryForNewMembers:
        hideHistoryForNewMembers ?? this.hideHistoryForNewMembers,
    onlyAdminsCanAddMembers:
        onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
    myRole: myRole ?? this.myRole,
    mutedUntil: mutedUntil.present ? mutedUntil.value : this.mutedUntil,
    muteForever: muteForever ?? this.muteForever,
    mentionsOnly: mentionsOnly ?? this.mentionsOnly,
    myPendingJoinMsgID: myPendingJoinMsgID.present
        ? myPendingJoinMsgID.value
        : this.myPendingJoinMsgID,
    myHistoryCutoffAt: myHistoryCutoffAt.present
        ? myHistoryCutoffAt.value
        : this.myHistoryCutoffAt,
    hasUnreadMention: hasUnreadMention ?? this.hasUnreadMention,
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
      description: data.description.present
          ? data.description.value
          : this.description,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      metaUpdatedAt: data.metaUpdatedAt.present
          ? data.metaUpdatedAt.value
          : this.metaUpdatedAt,
      onlyAdminsCanSend: data.onlyAdminsCanSend.present
          ? data.onlyAdminsCanSend.value
          : this.onlyAdminsCanSend,
      onlyAdminsCanEditInfo: data.onlyAdminsCanEditInfo.present
          ? data.onlyAdminsCanEditInfo.value
          : this.onlyAdminsCanEditInfo,
      hideHistoryForNewMembers: data.hideHistoryForNewMembers.present
          ? data.hideHistoryForNewMembers.value
          : this.hideHistoryForNewMembers,
      onlyAdminsCanAddMembers: data.onlyAdminsCanAddMembers.present
          ? data.onlyAdminsCanAddMembers.value
          : this.onlyAdminsCanAddMembers,
      myRole: data.myRole.present ? data.myRole.value : this.myRole,
      mutedUntil: data.mutedUntil.present
          ? data.mutedUntil.value
          : this.mutedUntil,
      muteForever: data.muteForever.present
          ? data.muteForever.value
          : this.muteForever,
      mentionsOnly: data.mentionsOnly.present
          ? data.mentionsOnly.value
          : this.mentionsOnly,
      myPendingJoinMsgID: data.myPendingJoinMsgID.present
          ? data.myPendingJoinMsgID.value
          : this.myPendingJoinMsgID,
      myHistoryCutoffAt: data.myHistoryCutoffAt.present
          ? data.myHistoryCutoffAt.value
          : this.myHistoryCutoffAt,
      hasUnreadMention: data.hasUnreadMention.present
          ? data.hasUnreadMention.value
          : this.hasUnreadMention,
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
          ..write('participantsJson: $participantsJson, ')
          ..write('description: $description, ')
          ..write('createdBy: $createdBy, ')
          ..write('metaUpdatedAt: $metaUpdatedAt, ')
          ..write('onlyAdminsCanSend: $onlyAdminsCanSend, ')
          ..write('onlyAdminsCanEditInfo: $onlyAdminsCanEditInfo, ')
          ..write('hideHistoryForNewMembers: $hideHistoryForNewMembers, ')
          ..write('onlyAdminsCanAddMembers: $onlyAdminsCanAddMembers, ')
          ..write('myRole: $myRole, ')
          ..write('mutedUntil: $mutedUntil, ')
          ..write('muteForever: $muteForever, ')
          ..write('mentionsOnly: $mentionsOnly, ')
          ..write('myPendingJoinMsgID: $myPendingJoinMsgID, ')
          ..write('myHistoryCutoffAt: $myHistoryCutoffAt, ')
          ..write('hasUnreadMention: $hasUnreadMention')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    description,
    createdBy,
    metaUpdatedAt,
    onlyAdminsCanSend,
    onlyAdminsCanEditInfo,
    hideHistoryForNewMembers,
    onlyAdminsCanAddMembers,
    myRole,
    mutedUntil,
    muteForever,
    mentionsOnly,
    myPendingJoinMsgID,
    myHistoryCutoffAt,
    hasUnreadMention,
  ]);
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
          other.participantsJson == this.participantsJson &&
          other.description == this.description &&
          other.createdBy == this.createdBy &&
          other.metaUpdatedAt == this.metaUpdatedAt &&
          other.onlyAdminsCanSend == this.onlyAdminsCanSend &&
          other.onlyAdminsCanEditInfo == this.onlyAdminsCanEditInfo &&
          other.hideHistoryForNewMembers == this.hideHistoryForNewMembers &&
          other.onlyAdminsCanAddMembers == this.onlyAdminsCanAddMembers &&
          other.myRole == this.myRole &&
          other.mutedUntil == this.mutedUntil &&
          other.muteForever == this.muteForever &&
          other.mentionsOnly == this.mentionsOnly &&
          other.myPendingJoinMsgID == this.myPendingJoinMsgID &&
          other.myHistoryCutoffAt == this.myHistoryCutoffAt &&
          other.hasUnreadMention == this.hasUnreadMention);
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
  final Value<String?> description;
  final Value<int?> createdBy;
  final Value<DateTime?> metaUpdatedAt;
  final Value<bool> onlyAdminsCanSend;
  final Value<bool> onlyAdminsCanEditInfo;
  final Value<bool> hideHistoryForNewMembers;
  final Value<bool> onlyAdminsCanAddMembers;
  final Value<int> myRole;
  final Value<DateTime?> mutedUntil;
  final Value<bool> muteForever;
  final Value<bool> mentionsOnly;
  final Value<int?> myPendingJoinMsgID;
  final Value<DateTime?> myHistoryCutoffAt;
  final Value<bool> hasUnreadMention;
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
    this.description = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.metaUpdatedAt = const Value.absent(),
    this.onlyAdminsCanSend = const Value.absent(),
    this.onlyAdminsCanEditInfo = const Value.absent(),
    this.hideHistoryForNewMembers = const Value.absent(),
    this.onlyAdminsCanAddMembers = const Value.absent(),
    this.myRole = const Value.absent(),
    this.mutedUntil = const Value.absent(),
    this.muteForever = const Value.absent(),
    this.mentionsOnly = const Value.absent(),
    this.myPendingJoinMsgID = const Value.absent(),
    this.myHistoryCutoffAt = const Value.absent(),
    this.hasUnreadMention = const Value.absent(),
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
    this.description = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.metaUpdatedAt = const Value.absent(),
    this.onlyAdminsCanSend = const Value.absent(),
    this.onlyAdminsCanEditInfo = const Value.absent(),
    this.hideHistoryForNewMembers = const Value.absent(),
    this.onlyAdminsCanAddMembers = const Value.absent(),
    this.myRole = const Value.absent(),
    this.mutedUntil = const Value.absent(),
    this.muteForever = const Value.absent(),
    this.mentionsOnly = const Value.absent(),
    this.myPendingJoinMsgID = const Value.absent(),
    this.myHistoryCutoffAt = const Value.absent(),
    this.hasUnreadMention = const Value.absent(),
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
    Expression<String>? description,
    Expression<int>? createdBy,
    Expression<DateTime>? metaUpdatedAt,
    Expression<bool>? onlyAdminsCanSend,
    Expression<bool>? onlyAdminsCanEditInfo,
    Expression<bool>? hideHistoryForNewMembers,
    Expression<bool>? onlyAdminsCanAddMembers,
    Expression<int>? myRole,
    Expression<DateTime>? mutedUntil,
    Expression<bool>? muteForever,
    Expression<bool>? mentionsOnly,
    Expression<int>? myPendingJoinMsgID,
    Expression<DateTime>? myHistoryCutoffAt,
    Expression<bool>? hasUnreadMention,
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
      if (description != null) 'description': description,
      if (createdBy != null) 'created_by': createdBy,
      if (metaUpdatedAt != null) 'meta_updated_at': metaUpdatedAt,
      if (onlyAdminsCanSend != null) 'only_admins_can_send': onlyAdminsCanSend,
      if (onlyAdminsCanEditInfo != null)
        'only_admins_can_edit_info': onlyAdminsCanEditInfo,
      if (hideHistoryForNewMembers != null)
        'hide_history_for_new_members': hideHistoryForNewMembers,
      if (onlyAdminsCanAddMembers != null)
        'only_admins_can_add_members': onlyAdminsCanAddMembers,
      if (myRole != null) 'my_role': myRole,
      if (mutedUntil != null) 'muted_until': mutedUntil,
      if (muteForever != null) 'mute_forever': muteForever,
      if (mentionsOnly != null) 'mentions_only': mentionsOnly,
      if (myPendingJoinMsgID != null)
        'my_pending_join_msg_i_d': myPendingJoinMsgID,
      if (myHistoryCutoffAt != null) 'my_history_cutoff_at': myHistoryCutoffAt,
      if (hasUnreadMention != null) 'has_unread_mention': hasUnreadMention,
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
    Value<String?>? description,
    Value<int?>? createdBy,
    Value<DateTime?>? metaUpdatedAt,
    Value<bool>? onlyAdminsCanSend,
    Value<bool>? onlyAdminsCanEditInfo,
    Value<bool>? hideHistoryForNewMembers,
    Value<bool>? onlyAdminsCanAddMembers,
    Value<int>? myRole,
    Value<DateTime?>? mutedUntil,
    Value<bool>? muteForever,
    Value<bool>? mentionsOnly,
    Value<int?>? myPendingJoinMsgID,
    Value<DateTime?>? myHistoryCutoffAt,
    Value<bool>? hasUnreadMention,
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
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      metaUpdatedAt: metaUpdatedAt ?? this.metaUpdatedAt,
      onlyAdminsCanSend: onlyAdminsCanSend ?? this.onlyAdminsCanSend,
      onlyAdminsCanEditInfo:
          onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      hideHistoryForNewMembers:
          hideHistoryForNewMembers ?? this.hideHistoryForNewMembers,
      onlyAdminsCanAddMembers:
          onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      myRole: myRole ?? this.myRole,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      muteForever: muteForever ?? this.muteForever,
      mentionsOnly: mentionsOnly ?? this.mentionsOnly,
      myPendingJoinMsgID: myPendingJoinMsgID ?? this.myPendingJoinMsgID,
      myHistoryCutoffAt: myHistoryCutoffAt ?? this.myHistoryCutoffAt,
      hasUnreadMention: hasUnreadMention ?? this.hasUnreadMention,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (metaUpdatedAt.present) {
      map['meta_updated_at'] = Variable<DateTime>(metaUpdatedAt.value);
    }
    if (onlyAdminsCanSend.present) {
      map['only_admins_can_send'] = Variable<bool>(onlyAdminsCanSend.value);
    }
    if (onlyAdminsCanEditInfo.present) {
      map['only_admins_can_edit_info'] = Variable<bool>(
        onlyAdminsCanEditInfo.value,
      );
    }
    if (hideHistoryForNewMembers.present) {
      map['hide_history_for_new_members'] = Variable<bool>(
        hideHistoryForNewMembers.value,
      );
    }
    if (onlyAdminsCanAddMembers.present) {
      map['only_admins_can_add_members'] = Variable<bool>(
        onlyAdminsCanAddMembers.value,
      );
    }
    if (myRole.present) {
      map['my_role'] = Variable<int>(myRole.value);
    }
    if (mutedUntil.present) {
      map['muted_until'] = Variable<DateTime>(mutedUntil.value);
    }
    if (muteForever.present) {
      map['mute_forever'] = Variable<bool>(muteForever.value);
    }
    if (mentionsOnly.present) {
      map['mentions_only'] = Variable<bool>(mentionsOnly.value);
    }
    if (myPendingJoinMsgID.present) {
      map['my_pending_join_msg_i_d'] = Variable<int>(myPendingJoinMsgID.value);
    }
    if (myHistoryCutoffAt.present) {
      map['my_history_cutoff_at'] = Variable<DateTime>(myHistoryCutoffAt.value);
    }
    if (hasUnreadMention.present) {
      map['has_unread_mention'] = Variable<bool>(hasUnreadMention.value);
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
          ..write('participantsJson: $participantsJson, ')
          ..write('description: $description, ')
          ..write('createdBy: $createdBy, ')
          ..write('metaUpdatedAt: $metaUpdatedAt, ')
          ..write('onlyAdminsCanSend: $onlyAdminsCanSend, ')
          ..write('onlyAdminsCanEditInfo: $onlyAdminsCanEditInfo, ')
          ..write('hideHistoryForNewMembers: $hideHistoryForNewMembers, ')
          ..write('onlyAdminsCanAddMembers: $onlyAdminsCanAddMembers, ')
          ..write('myRole: $myRole, ')
          ..write('mutedUntil: $mutedUntil, ')
          ..write('muteForever: $muteForever, ')
          ..write('mentionsOnly: $mentionsOnly, ')
          ..write('myPendingJoinMsgID: $myPendingJoinMsgID, ')
          ..write('myHistoryCutoffAt: $myHistoryCutoffAt, ')
          ..write('hasUnreadMention: $hasUnreadMention')
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
  static const VerificationMeta _mediaSizeMeta = const VerificationMeta(
    'mediaSize',
  );
  @override
  late final GeneratedColumn<int> mediaSize = GeneratedColumn<int>(
    'media_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaPageCountMeta = const VerificationMeta(
    'mediaPageCount',
  );
  @override
  late final GeneratedColumn<int> mediaPageCount = GeneratedColumn<int>(
    'media_page_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaThumbMeta = const VerificationMeta(
    'mediaThumb',
  );
  @override
  late final GeneratedColumn<String> mediaThumb = GeneratedColumn<String>(
    'media_thumb',
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
  static const VerificationMeta _clickSentAtMeta = const VerificationMeta(
    'clickSentAt',
  );
  @override
  late final GeneratedColumn<DateTime> clickSentAt = GeneratedColumn<DateTime>(
    'click_sent_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageTzMeta = const VerificationMeta(
    'messageTz',
  );
  @override
  late final GeneratedColumn<String> messageTz = GeneratedColumn<String>(
    'message_tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageTzOffsetMeta = const VerificationMeta(
    'messageTzOffset',
  );
  @override
  late final GeneratedColumn<int> messageTzOffset = GeneratedColumn<int>(
    'message_tz_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mentionsJsonMeta = const VerificationMeta(
    'mentionsJson',
  );
  @override
  late final GeneratedColumn<String> mentionsJson = GeneratedColumn<String>(
    'mentions_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    mediaSize,
    mediaPageCount,
    mediaThumb,
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
    clickSentAt,
    messageTz,
    messageTzOffset,
    senderNom,
    senderPseudo,
    senderAvatar,
    syncPending,
    lastEmittedAt,
    retryCount,
    failureCode,
    mentionsJson,
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
    if (data.containsKey('media_size')) {
      context.handle(
        _mediaSizeMeta,
        mediaSize.isAcceptableOrUnknown(data['media_size']!, _mediaSizeMeta),
      );
    }
    if (data.containsKey('media_page_count')) {
      context.handle(
        _mediaPageCountMeta,
        mediaPageCount.isAcceptableOrUnknown(
          data['media_page_count']!,
          _mediaPageCountMeta,
        ),
      );
    }
    if (data.containsKey('media_thumb')) {
      context.handle(
        _mediaThumbMeta,
        mediaThumb.isAcceptableOrUnknown(data['media_thumb']!, _mediaThumbMeta),
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
    if (data.containsKey('click_sent_at')) {
      context.handle(
        _clickSentAtMeta,
        clickSentAt.isAcceptableOrUnknown(
          data['click_sent_at']!,
          _clickSentAtMeta,
        ),
      );
    }
    if (data.containsKey('message_tz')) {
      context.handle(
        _messageTzMeta,
        messageTz.isAcceptableOrUnknown(data['message_tz']!, _messageTzMeta),
      );
    }
    if (data.containsKey('message_tz_offset')) {
      context.handle(
        _messageTzOffsetMeta,
        messageTzOffset.isAcceptableOrUnknown(
          data['message_tz_offset']!,
          _messageTzOffsetMeta,
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
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    if (data.containsKey('mentions_json')) {
      context.handle(
        _mentionsJsonMeta,
        mentionsJson.isAcceptableOrUnknown(
          data['mentions_json']!,
          _mentionsJsonMeta,
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
      mediaSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_size'],
      ),
      mediaPageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_page_count'],
      ),
      mediaThumb: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_thumb'],
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
      clickSentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}click_sent_at'],
      ),
      messageTz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_tz'],
      ),
      messageTzOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_tz_offset'],
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
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
      mentionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mentions_json'],
      ),
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

  /// Taille du fichier en octets (documents / médias type fichier).
  final int? mediaSize;

  /// Nombre de pages pour les PDF.
  final int? mediaPageCount;

  /// Vignette vidéo (JPEG base64) transmise avec le message pour l'aperçu chez
  /// le destinataire, disponible immédiatement et hors ligne sans télécharger
  /// la vidéo complète.
  final String? mediaThumb;

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

  /// Heure locale à laquelle l'expéditeur a appuyé sur « envoyer » (heure du
  /// clic). Distincte de `sendAt`, qui devient l'horodatage serveur (départ
  /// effectif) une fois le message confirmé. Désormais synchronisée avec le
  /// serveur : visible aussi bien par l'expéditeur que par le destinataire.
  final DateTime? clickSentAt;

  /// Cache local (dénormalisé, comme [senderNom]) du fuseau horaire de
  /// l'expéditeur, tel que renvoyé par le serveur. PAS de capture côté
  /// appareil ni de colonne dédiée en base : le serveur le dérive à la
  /// volée via une jointure `users` → `pays.timeZone` (le pays enregistré
  /// de l'expéditeur), donc rien n'est dupliqué par message côté backend.
  final String? messageTz;

  /// Décalage horaire (en heures) du pays de l'expéditeur, renvoyé par le
  /// serveur (`pays.decalageHoraire`) — permet un affichage direct type
  /// "UTC+1" sans avoir à interpréter [messageTz].
  final int? messageTzOffset;
  final String? senderNom;
  final String? senderPseudo;
  final String? senderAvatar;

  /// true tant que le message n'a pas été remis au serveur (outbox).
  final bool syncPending;

  /// Dernier instant d'émission via le socket — sert au backoff de l'outbox.
  final DateTime? lastEmittedAt;

  /// Nombre de tentatives de retry pour ce message (failed -> retry).
  final int retryCount;

  /// Code d'échec serveur quand l'envoi a été REFUSÉ définitivement
  /// (`GROUP_ADMINS_ONLY`, `NOT_A_MEMBER`, `BLOCKED_BY_SENDER`).
  ///
  /// Distingue « le réseau a lâché » — où réessayer a du sens — de « le
  /// serveur a dit non » — où le bouton « réessayer » échouerait
  /// indéfiniment et ferait tourner l'utilisateur en rond.
  final String? failureCode;

  /// Ids mentionnés, sérialisés (`[45,46]`), miroir de `message.mentions`.
  ///
  /// Persisté et pas seulement dérivé du texte : `flushOutbox` reconstruit
  /// l'émission depuis cette ligne, et une mention envoyée hors ligne perdrait
  /// sinon sa notification au rejeu.
  final String? mentionsJson;
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
    this.mediaSize,
    this.mediaPageCount,
    this.mediaThumb,
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
    this.clickSentAt,
    this.messageTz,
    this.messageTzOffset,
    this.senderNom,
    this.senderPseudo,
    this.senderAvatar,
    required this.syncPending,
    this.lastEmittedAt,
    required this.retryCount,
    this.failureCode,
    this.mentionsJson,
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
    if (!nullToAbsent || mediaSize != null) {
      map['media_size'] = Variable<int>(mediaSize);
    }
    if (!nullToAbsent || mediaPageCount != null) {
      map['media_page_count'] = Variable<int>(mediaPageCount);
    }
    if (!nullToAbsent || mediaThumb != null) {
      map['media_thumb'] = Variable<String>(mediaThumb);
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
    if (!nullToAbsent || clickSentAt != null) {
      map['click_sent_at'] = Variable<DateTime>(clickSentAt);
    }
    if (!nullToAbsent || messageTz != null) {
      map['message_tz'] = Variable<String>(messageTz);
    }
    if (!nullToAbsent || messageTzOffset != null) {
      map['message_tz_offset'] = Variable<int>(messageTzOffset);
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
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    if (!nullToAbsent || mentionsJson != null) {
      map['mentions_json'] = Variable<String>(mentionsJson);
    }
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
      mediaSize: mediaSize == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaSize),
      mediaPageCount: mediaPageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaPageCount),
      mediaThumb: mediaThumb == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaThumb),
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
      clickSentAt: clickSentAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clickSentAt),
      messageTz: messageTz == null && nullToAbsent
          ? const Value.absent()
          : Value(messageTz),
      messageTzOffset: messageTzOffset == null && nullToAbsent
          ? const Value.absent()
          : Value(messageTzOffset),
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
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
      mentionsJson: mentionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mentionsJson),
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
      mediaSize: serializer.fromJson<int?>(json['mediaSize']),
      mediaPageCount: serializer.fromJson<int?>(json['mediaPageCount']),
      mediaThumb: serializer.fromJson<String?>(json['mediaThumb']),
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
      clickSentAt: serializer.fromJson<DateTime?>(json['clickSentAt']),
      messageTz: serializer.fromJson<String?>(json['messageTz']),
      messageTzOffset: serializer.fromJson<int?>(json['messageTzOffset']),
      senderNom: serializer.fromJson<String?>(json['senderNom']),
      senderPseudo: serializer.fromJson<String?>(json['senderPseudo']),
      senderAvatar: serializer.fromJson<String?>(json['senderAvatar']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      lastEmittedAt: serializer.fromJson<DateTime?>(json['lastEmittedAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
      mentionsJson: serializer.fromJson<String?>(json['mentionsJson']),
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
      'mediaSize': serializer.toJson<int?>(mediaSize),
      'mediaPageCount': serializer.toJson<int?>(mediaPageCount),
      'mediaThumb': serializer.toJson<String?>(mediaThumb),
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
      'clickSentAt': serializer.toJson<DateTime?>(clickSentAt),
      'messageTz': serializer.toJson<String?>(messageTz),
      'messageTzOffset': serializer.toJson<int?>(messageTzOffset),
      'senderNom': serializer.toJson<String?>(senderNom),
      'senderPseudo': serializer.toJson<String?>(senderPseudo),
      'senderAvatar': serializer.toJson<String?>(senderAvatar),
      'syncPending': serializer.toJson<bool>(syncPending),
      'lastEmittedAt': serializer.toJson<DateTime?>(lastEmittedAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'failureCode': serializer.toJson<String?>(failureCode),
      'mentionsJson': serializer.toJson<String?>(mentionsJson),
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
    Value<int?> mediaSize = const Value.absent(),
    Value<int?> mediaPageCount = const Value.absent(),
    Value<String?> mediaThumb = const Value.absent(),
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
    Value<DateTime?> clickSentAt = const Value.absent(),
    Value<String?> messageTz = const Value.absent(),
    Value<int?> messageTzOffset = const Value.absent(),
    Value<String?> senderNom = const Value.absent(),
    Value<String?> senderPseudo = const Value.absent(),
    Value<String?> senderAvatar = const Value.absent(),
    bool? syncPending,
    Value<DateTime?> lastEmittedAt = const Value.absent(),
    int? retryCount,
    Value<String?> failureCode = const Value.absent(),
    Value<String?> mentionsJson = const Value.absent(),
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
    mediaSize: mediaSize.present ? mediaSize.value : this.mediaSize,
    mediaPageCount: mediaPageCount.present
        ? mediaPageCount.value
        : this.mediaPageCount,
    mediaThumb: mediaThumb.present ? mediaThumb.value : this.mediaThumb,
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
    clickSentAt: clickSentAt.present ? clickSentAt.value : this.clickSentAt,
    messageTz: messageTz.present ? messageTz.value : this.messageTz,
    messageTzOffset: messageTzOffset.present
        ? messageTzOffset.value
        : this.messageTzOffset,
    senderNom: senderNom.present ? senderNom.value : this.senderNom,
    senderPseudo: senderPseudo.present ? senderPseudo.value : this.senderPseudo,
    senderAvatar: senderAvatar.present ? senderAvatar.value : this.senderAvatar,
    syncPending: syncPending ?? this.syncPending,
    lastEmittedAt: lastEmittedAt.present
        ? lastEmittedAt.value
        : this.lastEmittedAt,
    retryCount: retryCount ?? this.retryCount,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
    mentionsJson: mentionsJson.present ? mentionsJson.value : this.mentionsJson,
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
      mediaSize: data.mediaSize.present ? data.mediaSize.value : this.mediaSize,
      mediaPageCount: data.mediaPageCount.present
          ? data.mediaPageCount.value
          : this.mediaPageCount,
      mediaThumb: data.mediaThumb.present
          ? data.mediaThumb.value
          : this.mediaThumb,
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
      clickSentAt: data.clickSentAt.present
          ? data.clickSentAt.value
          : this.clickSentAt,
      messageTz: data.messageTz.present ? data.messageTz.value : this.messageTz,
      messageTzOffset: data.messageTzOffset.present
          ? data.messageTzOffset.value
          : this.messageTzOffset,
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
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
      mentionsJson: data.mentionsJson.present
          ? data.mentionsJson.value
          : this.mentionsJson,
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
          ..write('mediaSize: $mediaSize, ')
          ..write('mediaPageCount: $mediaPageCount, ')
          ..write('mediaThumb: $mediaThumb, ')
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
          ..write('clickSentAt: $clickSentAt, ')
          ..write('messageTz: $messageTz, ')
          ..write('messageTzOffset: $messageTzOffset, ')
          ..write('senderNom: $senderNom, ')
          ..write('senderPseudo: $senderPseudo, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('syncPending: $syncPending, ')
          ..write('lastEmittedAt: $lastEmittedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('failureCode: $failureCode, ')
          ..write('mentionsJson: $mentionsJson')
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
    mediaSize,
    mediaPageCount,
    mediaThumb,
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
    clickSentAt,
    messageTz,
    messageTzOffset,
    senderNom,
    senderPseudo,
    senderAvatar,
    syncPending,
    lastEmittedAt,
    retryCount,
    failureCode,
    mentionsJson,
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
          other.mediaSize == this.mediaSize &&
          other.mediaPageCount == this.mediaPageCount &&
          other.mediaThumb == this.mediaThumb &&
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
          other.clickSentAt == this.clickSentAt &&
          other.messageTz == this.messageTz &&
          other.messageTzOffset == this.messageTzOffset &&
          other.senderNom == this.senderNom &&
          other.senderPseudo == this.senderPseudo &&
          other.senderAvatar == this.senderAvatar &&
          other.syncPending == this.syncPending &&
          other.lastEmittedAt == this.lastEmittedAt &&
          other.retryCount == this.retryCount &&
          other.failureCode == this.failureCode &&
          other.mentionsJson == this.mentionsJson);
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
  final Value<int?> mediaSize;
  final Value<int?> mediaPageCount;
  final Value<String?> mediaThumb;
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
  final Value<DateTime?> clickSentAt;
  final Value<String?> messageTz;
  final Value<int?> messageTzOffset;
  final Value<String?> senderNom;
  final Value<String?> senderPseudo;
  final Value<String?> senderAvatar;
  final Value<bool> syncPending;
  final Value<DateTime?> lastEmittedAt;
  final Value<int> retryCount;
  final Value<String?> failureCode;
  final Value<String?> mentionsJson;
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
    this.mediaSize = const Value.absent(),
    this.mediaPageCount = const Value.absent(),
    this.mediaThumb = const Value.absent(),
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
    this.clickSentAt = const Value.absent(),
    this.messageTz = const Value.absent(),
    this.messageTzOffset = const Value.absent(),
    this.senderNom = const Value.absent(),
    this.senderPseudo = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.lastEmittedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.mentionsJson = const Value.absent(),
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
    this.mediaSize = const Value.absent(),
    this.mediaPageCount = const Value.absent(),
    this.mediaThumb = const Value.absent(),
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
    this.clickSentAt = const Value.absent(),
    this.messageTz = const Value.absent(),
    this.messageTzOffset = const Value.absent(),
    this.senderNom = const Value.absent(),
    this.senderPseudo = const Value.absent(),
    this.senderAvatar = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.lastEmittedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.mentionsJson = const Value.absent(),
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
    Expression<int>? mediaSize,
    Expression<int>? mediaPageCount,
    Expression<String>? mediaThumb,
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
    Expression<DateTime>? clickSentAt,
    Expression<String>? messageTz,
    Expression<int>? messageTzOffset,
    Expression<String>? senderNom,
    Expression<String>? senderPseudo,
    Expression<String>? senderAvatar,
    Expression<bool>? syncPending,
    Expression<DateTime>? lastEmittedAt,
    Expression<int>? retryCount,
    Expression<String>? failureCode,
    Expression<String>? mentionsJson,
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
      if (mediaSize != null) 'media_size': mediaSize,
      if (mediaPageCount != null) 'media_page_count': mediaPageCount,
      if (mediaThumb != null) 'media_thumb': mediaThumb,
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
      if (clickSentAt != null) 'click_sent_at': clickSentAt,
      if (messageTz != null) 'message_tz': messageTz,
      if (messageTzOffset != null) 'message_tz_offset': messageTzOffset,
      if (senderNom != null) 'sender_nom': senderNom,
      if (senderPseudo != null) 'sender_pseudo': senderPseudo,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
      if (syncPending != null) 'sync_pending': syncPending,
      if (lastEmittedAt != null) 'last_emitted_at': lastEmittedAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (failureCode != null) 'failure_code': failureCode,
      if (mentionsJson != null) 'mentions_json': mentionsJson,
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
    Value<int?>? mediaSize,
    Value<int?>? mediaPageCount,
    Value<String?>? mediaThumb,
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
    Value<DateTime?>? clickSentAt,
    Value<String?>? messageTz,
    Value<int?>? messageTzOffset,
    Value<String?>? senderNom,
    Value<String?>? senderPseudo,
    Value<String?>? senderAvatar,
    Value<bool>? syncPending,
    Value<DateTime?>? lastEmittedAt,
    Value<int>? retryCount,
    Value<String?>? failureCode,
    Value<String?>? mentionsJson,
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
      mediaSize: mediaSize ?? this.mediaSize,
      mediaPageCount: mediaPageCount ?? this.mediaPageCount,
      mediaThumb: mediaThumb ?? this.mediaThumb,
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
      clickSentAt: clickSentAt ?? this.clickSentAt,
      messageTz: messageTz ?? this.messageTz,
      messageTzOffset: messageTzOffset ?? this.messageTzOffset,
      senderNom: senderNom ?? this.senderNom,
      senderPseudo: senderPseudo ?? this.senderPseudo,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      syncPending: syncPending ?? this.syncPending,
      lastEmittedAt: lastEmittedAt ?? this.lastEmittedAt,
      retryCount: retryCount ?? this.retryCount,
      failureCode: failureCode ?? this.failureCode,
      mentionsJson: mentionsJson ?? this.mentionsJson,
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
    if (mediaSize.present) {
      map['media_size'] = Variable<int>(mediaSize.value);
    }
    if (mediaPageCount.present) {
      map['media_page_count'] = Variable<int>(mediaPageCount.value);
    }
    if (mediaThumb.present) {
      map['media_thumb'] = Variable<String>(mediaThumb.value);
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
    if (clickSentAt.present) {
      map['click_sent_at'] = Variable<DateTime>(clickSentAt.value);
    }
    if (messageTz.present) {
      map['message_tz'] = Variable<String>(messageTz.value);
    }
    if (messageTzOffset.present) {
      map['message_tz_offset'] = Variable<int>(messageTzOffset.value);
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
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (mentionsJson.present) {
      map['mentions_json'] = Variable<String>(mentionsJson.value);
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
          ..write('mediaSize: $mediaSize, ')
          ..write('mediaPageCount: $mediaPageCount, ')
          ..write('mediaThumb: $mediaThumb, ')
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
          ..write('clickSentAt: $clickSentAt, ')
          ..write('messageTz: $messageTz, ')
          ..write('messageTzOffset: $messageTzOffset, ')
          ..write('senderNom: $senderNom, ')
          ..write('senderPseudo: $senderPseudo, ')
          ..write('senderAvatar: $senderAvatar, ')
          ..write('syncPending: $syncPending, ')
          ..write('lastEmittedAt: $lastEmittedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('failureCode: $failureCode, ')
          ..write('mentionsJson: $mentionsJson, ')
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
  static const VerificationMeta _addedViaQrMeta = const VerificationMeta(
    'addedViaQr',
  );
  @override
  late final GeneratedColumn<bool> addedViaQr = GeneratedColumn<bool>(
    'added_via_qr',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("added_via_qr" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _preferredAddedAtMeta = const VerificationMeta(
    'preferredAddedAt',
  );
  @override
  late final GeneratedColumn<DateTime> preferredAddedAt =
      GeneratedColumn<DateTime>(
        'preferred_added_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _preferredNoteMeta = const VerificationMeta(
    'preferredNote',
  );
  @override
  late final GeneratedColumn<String> preferredNote = GeneratedColumn<String>(
    'preferred_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _accountTypeMeta = const VerificationMeta(
    'accountType',
  );
  @override
  late final GeneratedColumn<int> accountType = GeneratedColumn<int>(
    'account_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _verificationStatusMeta =
      const VerificationMeta('verificationStatus');
  @override
  late final GeneratedColumn<int> verificationStatus = GeneratedColumn<int>(
    'verification_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _verifiedUntilMeta = const VerificationMeta(
    'verifiedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> verifiedUntil =
      GeneratedColumn<DateTime>(
        'verified_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
    addedViaQr,
    preferredAddedAt,
    preferredNote,
    typeCompte,
    accountType,
    verificationStatus,
    verifiedUntil,
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
    if (data.containsKey('added_via_qr')) {
      context.handle(
        _addedViaQrMeta,
        addedViaQr.isAcceptableOrUnknown(
          data['added_via_qr']!,
          _addedViaQrMeta,
        ),
      );
    }
    if (data.containsKey('preferred_added_at')) {
      context.handle(
        _preferredAddedAtMeta,
        preferredAddedAt.isAcceptableOrUnknown(
          data['preferred_added_at']!,
          _preferredAddedAtMeta,
        ),
      );
    }
    if (data.containsKey('preferred_note')) {
      context.handle(
        _preferredNoteMeta,
        preferredNote.isAcceptableOrUnknown(
          data['preferred_note']!,
          _preferredNoteMeta,
        ),
      );
    }
    if (data.containsKey('type_compte')) {
      context.handle(
        _typeCompteMeta,
        typeCompte.isAcceptableOrUnknown(data['type_compte']!, _typeCompteMeta),
      );
    }
    if (data.containsKey('account_type')) {
      context.handle(
        _accountTypeMeta,
        accountType.isAcceptableOrUnknown(
          data['account_type']!,
          _accountTypeMeta,
        ),
      );
    }
    if (data.containsKey('verification_status')) {
      context.handle(
        _verificationStatusMeta,
        verificationStatus.isAcceptableOrUnknown(
          data['verification_status']!,
          _verificationStatusMeta,
        ),
      );
    }
    if (data.containsKey('verified_until')) {
      context.handle(
        _verifiedUntilMeta,
        verifiedUntil.isAcceptableOrUnknown(
          data['verified_until']!,
          _verifiedUntilMeta,
        ),
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
      addedViaQr: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}added_via_qr'],
      )!,
      preferredAddedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}preferred_added_at'],
      ),
      preferredNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_note'],
      ),
      typeCompte: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_compte'],
      )!,
      accountType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_type'],
      )!,
      verificationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}verification_status'],
      )!,
      verifiedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}verified_until'],
      ),
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

  /// Origine du lien de contact préféré : vrai si ajouté par code QR (scan ou
  /// lien). Alimente la pastille des listes, le filtre « Par QR » et la
  /// mention datée de la fiche.
  final bool addedViaQr;

  /// Date d'ajout en contact préféré (preferredContact.created_at côté
  /// serveur) — pour la mention « Ajouté par QR code le … » de la fiche.
  final DateTime? preferredAddedAt;

  /// Note contextuelle saisie après un scan (« rencontré au salon de
  /// Douala ») — affichée sur la fiche du contact.
  final String? preferredNote;
  final int typeCompte;
  final int accountType;
  final int verificationStatus;
  final DateTime? verifiedUntil;
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
    required this.addedViaQr,
    this.preferredAddedAt,
    this.preferredNote,
    required this.typeCompte,
    required this.accountType,
    required this.verificationStatus,
    this.verifiedUntil,
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
    map['added_via_qr'] = Variable<bool>(addedViaQr);
    if (!nullToAbsent || preferredAddedAt != null) {
      map['preferred_added_at'] = Variable<DateTime>(preferredAddedAt);
    }
    if (!nullToAbsent || preferredNote != null) {
      map['preferred_note'] = Variable<String>(preferredNote);
    }
    map['type_compte'] = Variable<int>(typeCompte);
    map['account_type'] = Variable<int>(accountType);
    map['verification_status'] = Variable<int>(verificationStatus);
    if (!nullToAbsent || verifiedUntil != null) {
      map['verified_until'] = Variable<DateTime>(verifiedUntil);
    }
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
      addedViaQr: Value(addedViaQr),
      preferredAddedAt: preferredAddedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredAddedAt),
      preferredNote: preferredNote == null && nullToAbsent
          ? const Value.absent()
          : Value(preferredNote),
      typeCompte: Value(typeCompte),
      accountType: Value(accountType),
      verificationStatus: Value(verificationStatus),
      verifiedUntil: verifiedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(verifiedUntil),
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
      addedViaQr: serializer.fromJson<bool>(json['addedViaQr']),
      preferredAddedAt: serializer.fromJson<DateTime?>(
        json['preferredAddedAt'],
      ),
      preferredNote: serializer.fromJson<String?>(json['preferredNote']),
      typeCompte: serializer.fromJson<int>(json['typeCompte']),
      accountType: serializer.fromJson<int>(json['accountType']),
      verificationStatus: serializer.fromJson<int>(json['verificationStatus']),
      verifiedUntil: serializer.fromJson<DateTime?>(json['verifiedUntil']),
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
      'addedViaQr': serializer.toJson<bool>(addedViaQr),
      'preferredAddedAt': serializer.toJson<DateTime?>(preferredAddedAt),
      'preferredNote': serializer.toJson<String?>(preferredNote),
      'typeCompte': serializer.toJson<int>(typeCompte),
      'accountType': serializer.toJson<int>(accountType),
      'verificationStatus': serializer.toJson<int>(verificationStatus),
      'verifiedUntil': serializer.toJson<DateTime?>(verifiedUntil),
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
    bool? addedViaQr,
    Value<DateTime?> preferredAddedAt = const Value.absent(),
    Value<String?> preferredNote = const Value.absent(),
    int? typeCompte,
    int? accountType,
    int? verificationStatus,
    Value<DateTime?> verifiedUntil = const Value.absent(),
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
    addedViaQr: addedViaQr ?? this.addedViaQr,
    preferredAddedAt: preferredAddedAt.present
        ? preferredAddedAt.value
        : this.preferredAddedAt,
    preferredNote: preferredNote.present
        ? preferredNote.value
        : this.preferredNote,
    typeCompte: typeCompte ?? this.typeCompte,
    accountType: accountType ?? this.accountType,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    verifiedUntil: verifiedUntil.present
        ? verifiedUntil.value
        : this.verifiedUntil,
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
      addedViaQr: data.addedViaQr.present
          ? data.addedViaQr.value
          : this.addedViaQr,
      preferredAddedAt: data.preferredAddedAt.present
          ? data.preferredAddedAt.value
          : this.preferredAddedAt,
      preferredNote: data.preferredNote.present
          ? data.preferredNote.value
          : this.preferredNote,
      typeCompte: data.typeCompte.present
          ? data.typeCompte.value
          : this.typeCompte,
      accountType: data.accountType.present
          ? data.accountType.value
          : this.accountType,
      verificationStatus: data.verificationStatus.present
          ? data.verificationStatus.value
          : this.verificationStatus,
      verifiedUntil: data.verifiedUntil.present
          ? data.verifiedUntil.value
          : this.verifiedUntil,
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
          ..write('addedViaQr: $addedViaQr, ')
          ..write('preferredAddedAt: $preferredAddedAt, ')
          ..write('preferredNote: $preferredNote, ')
          ..write('typeCompte: $typeCompte, ')
          ..write('accountType: $accountType, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('verifiedUntil: $verifiedUntil, ')
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
    addedViaQr,
    preferredAddedAt,
    preferredNote,
    typeCompte,
    accountType,
    verificationStatus,
    verifiedUntil,
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
          other.addedViaQr == this.addedViaQr &&
          other.preferredAddedAt == this.preferredAddedAt &&
          other.preferredNote == this.preferredNote &&
          other.typeCompte == this.typeCompte &&
          other.accountType == this.accountType &&
          other.verificationStatus == this.verificationStatus &&
          other.verifiedUntil == this.verifiedUntil &&
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
  final Value<bool> addedViaQr;
  final Value<DateTime?> preferredAddedAt;
  final Value<String?> preferredNote;
  final Value<int> typeCompte;
  final Value<int> accountType;
  final Value<int> verificationStatus;
  final Value<DateTime?> verifiedUntil;
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
    this.addedViaQr = const Value.absent(),
    this.preferredAddedAt = const Value.absent(),
    this.preferredNote = const Value.absent(),
    this.typeCompte = const Value.absent(),
    this.accountType = const Value.absent(),
    this.verificationStatus = const Value.absent(),
    this.verifiedUntil = const Value.absent(),
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
    this.addedViaQr = const Value.absent(),
    this.preferredAddedAt = const Value.absent(),
    this.preferredNote = const Value.absent(),
    this.typeCompte = const Value.absent(),
    this.accountType = const Value.absent(),
    this.verificationStatus = const Value.absent(),
    this.verifiedUntil = const Value.absent(),
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
    Expression<bool>? addedViaQr,
    Expression<DateTime>? preferredAddedAt,
    Expression<String>? preferredNote,
    Expression<int>? typeCompte,
    Expression<int>? accountType,
    Expression<int>? verificationStatus,
    Expression<DateTime>? verifiedUntil,
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
      if (addedViaQr != null) 'added_via_qr': addedViaQr,
      if (preferredAddedAt != null) 'preferred_added_at': preferredAddedAt,
      if (preferredNote != null) 'preferred_note': preferredNote,
      if (typeCompte != null) 'type_compte': typeCompte,
      if (accountType != null) 'account_type': accountType,
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (verifiedUntil != null) 'verified_until': verifiedUntil,
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
    Value<bool>? addedViaQr,
    Value<DateTime?>? preferredAddedAt,
    Value<String?>? preferredNote,
    Value<int>? typeCompte,
    Value<int>? accountType,
    Value<int>? verificationStatus,
    Value<DateTime?>? verifiedUntil,
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
      addedViaQr: addedViaQr ?? this.addedViaQr,
      preferredAddedAt: preferredAddedAt ?? this.preferredAddedAt,
      preferredNote: preferredNote ?? this.preferredNote,
      typeCompte: typeCompte ?? this.typeCompte,
      accountType: accountType ?? this.accountType,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedUntil: verifiedUntil ?? this.verifiedUntil,
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
    if (addedViaQr.present) {
      map['added_via_qr'] = Variable<bool>(addedViaQr.value);
    }
    if (preferredAddedAt.present) {
      map['preferred_added_at'] = Variable<DateTime>(preferredAddedAt.value);
    }
    if (preferredNote.present) {
      map['preferred_note'] = Variable<String>(preferredNote.value);
    }
    if (typeCompte.present) {
      map['type_compte'] = Variable<int>(typeCompte.value);
    }
    if (accountType.present) {
      map['account_type'] = Variable<int>(accountType.value);
    }
    if (verificationStatus.present) {
      map['verification_status'] = Variable<int>(verificationStatus.value);
    }
    if (verifiedUntil.present) {
      map['verified_until'] = Variable<DateTime>(verifiedUntil.value);
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
          ..write('addedViaQr: $addedViaQr, ')
          ..write('preferredAddedAt: $preferredAddedAt, ')
          ..write('preferredNote: $preferredNote, ')
          ..write('typeCompte: $typeCompte, ')
          ..write('accountType: $accountType, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('verifiedUntil: $verifiedUntil, ')
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

class $LocalMessageReactionsTable extends LocalMessageReactions
    with TableInfo<$LocalMessageReactionsTable, LocalMessageReaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessageReactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _msgIDMeta = const VerificationMeta('msgID');
  @override
  late final GeneratedColumn<int> msgID = GeneratedColumn<int>(
    'msg_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIDMeta = const VerificationMeta('userID');
  @override
  late final GeneratedColumn<int> userID = GeneratedColumn<int>(
    'user_i_d',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reactedAtMeta = const VerificationMeta(
    'reactedAt',
  );
  @override
  late final GeneratedColumn<DateTime> reactedAt = GeneratedColumn<DateTime>(
    'reacted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    msgID,
    userID,
    conversationID,
    emoji,
    reactedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_message_reactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessageReaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('msg_i_d')) {
      context.handle(
        _msgIDMeta,
        msgID.isAcceptableOrUnknown(data['msg_i_d']!, _msgIDMeta),
      );
    } else if (isInserting) {
      context.missing(_msgIDMeta);
    }
    if (data.containsKey('user_i_d')) {
      context.handle(
        _userIDMeta,
        userID.isAcceptableOrUnknown(data['user_i_d']!, _userIDMeta),
      );
    } else if (isInserting) {
      context.missing(_userIDMeta);
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
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('reacted_at')) {
      context.handle(
        _reactedAtMeta,
        reactedAt.isAcceptableOrUnknown(data['reacted_at']!, _reactedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {msgID, userID};
  @override
  LocalMessageReaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessageReaction(
      msgID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}msg_i_d'],
      )!,
      userID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_i_d'],
      )!,
      conversationID: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_i_d'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      reactedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reacted_at'],
      )!,
    );
  }

  @override
  $LocalMessageReactionsTable createAlias(String alias) {
    return $LocalMessageReactionsTable(attachedDatabase, alias);
  }
}

class LocalMessageReaction extends DataClass
    implements Insertable<LocalMessageReaction> {
  /// `msgID` serveur du message réagi (pas de réaction sur un message encore
  /// en attente d'envoi : msgID > 0 garanti côté DAO).
  final int msgID;

  /// alanyaID de l'auteur de la réaction.
  final int userID;

  /// Dénormalisé (comme `senderNom` sur [LocalMessages]) pour permettre une
  /// requête directe par conversation sans jointure.
  final int conversationID;

  /// Emoji unique (ex. "👍"). Jamais vide : une ligne sans réaction est
  /// supprimée plutôt que stockée avec un emoji vide.
  final String emoji;
  final DateTime reactedAt;
  const LocalMessageReaction({
    required this.msgID,
    required this.userID,
    required this.conversationID,
    required this.emoji,
    required this.reactedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['msg_i_d'] = Variable<int>(msgID);
    map['user_i_d'] = Variable<int>(userID);
    map['conversation_i_d'] = Variable<int>(conversationID);
    map['emoji'] = Variable<String>(emoji);
    map['reacted_at'] = Variable<DateTime>(reactedAt);
    return map;
  }

  LocalMessageReactionsCompanion toCompanion(bool nullToAbsent) {
    return LocalMessageReactionsCompanion(
      msgID: Value(msgID),
      userID: Value(userID),
      conversationID: Value(conversationID),
      emoji: Value(emoji),
      reactedAt: Value(reactedAt),
    );
  }

  factory LocalMessageReaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessageReaction(
      msgID: serializer.fromJson<int>(json['msgID']),
      userID: serializer.fromJson<int>(json['userID']),
      conversationID: serializer.fromJson<int>(json['conversationID']),
      emoji: serializer.fromJson<String>(json['emoji']),
      reactedAt: serializer.fromJson<DateTime>(json['reactedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'msgID': serializer.toJson<int>(msgID),
      'userID': serializer.toJson<int>(userID),
      'conversationID': serializer.toJson<int>(conversationID),
      'emoji': serializer.toJson<String>(emoji),
      'reactedAt': serializer.toJson<DateTime>(reactedAt),
    };
  }

  LocalMessageReaction copyWith({
    int? msgID,
    int? userID,
    int? conversationID,
    String? emoji,
    DateTime? reactedAt,
  }) => LocalMessageReaction(
    msgID: msgID ?? this.msgID,
    userID: userID ?? this.userID,
    conversationID: conversationID ?? this.conversationID,
    emoji: emoji ?? this.emoji,
    reactedAt: reactedAt ?? this.reactedAt,
  );
  LocalMessageReaction copyWithCompanion(LocalMessageReactionsCompanion data) {
    return LocalMessageReaction(
      msgID: data.msgID.present ? data.msgID.value : this.msgID,
      userID: data.userID.present ? data.userID.value : this.userID,
      conversationID: data.conversationID.present
          ? data.conversationID.value
          : this.conversationID,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      reactedAt: data.reactedAt.present ? data.reactedAt.value : this.reactedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessageReaction(')
          ..write('msgID: $msgID, ')
          ..write('userID: $userID, ')
          ..write('conversationID: $conversationID, ')
          ..write('emoji: $emoji, ')
          ..write('reactedAt: $reactedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(msgID, userID, conversationID, emoji, reactedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessageReaction &&
          other.msgID == this.msgID &&
          other.userID == this.userID &&
          other.conversationID == this.conversationID &&
          other.emoji == this.emoji &&
          other.reactedAt == this.reactedAt);
}

class LocalMessageReactionsCompanion
    extends UpdateCompanion<LocalMessageReaction> {
  final Value<int> msgID;
  final Value<int> userID;
  final Value<int> conversationID;
  final Value<String> emoji;
  final Value<DateTime> reactedAt;
  final Value<int> rowid;
  const LocalMessageReactionsCompanion({
    this.msgID = const Value.absent(),
    this.userID = const Value.absent(),
    this.conversationID = const Value.absent(),
    this.emoji = const Value.absent(),
    this.reactedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMessageReactionsCompanion.insert({
    required int msgID,
    required int userID,
    required int conversationID,
    required String emoji,
    this.reactedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : msgID = Value(msgID),
       userID = Value(userID),
       conversationID = Value(conversationID),
       emoji = Value(emoji);
  static Insertable<LocalMessageReaction> custom({
    Expression<int>? msgID,
    Expression<int>? userID,
    Expression<int>? conversationID,
    Expression<String>? emoji,
    Expression<DateTime>? reactedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (msgID != null) 'msg_i_d': msgID,
      if (userID != null) 'user_i_d': userID,
      if (conversationID != null) 'conversation_i_d': conversationID,
      if (emoji != null) 'emoji': emoji,
      if (reactedAt != null) 'reacted_at': reactedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMessageReactionsCompanion copyWith({
    Value<int>? msgID,
    Value<int>? userID,
    Value<int>? conversationID,
    Value<String>? emoji,
    Value<DateTime>? reactedAt,
    Value<int>? rowid,
  }) {
    return LocalMessageReactionsCompanion(
      msgID: msgID ?? this.msgID,
      userID: userID ?? this.userID,
      conversationID: conversationID ?? this.conversationID,
      emoji: emoji ?? this.emoji,
      reactedAt: reactedAt ?? this.reactedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (msgID.present) {
      map['msg_i_d'] = Variable<int>(msgID.value);
    }
    if (userID.present) {
      map['user_i_d'] = Variable<int>(userID.value);
    }
    if (conversationID.present) {
      map['conversation_i_d'] = Variable<int>(conversationID.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (reactedAt.present) {
      map['reacted_at'] = Variable<DateTime>(reactedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessageReactionsCompanion(')
          ..write('msgID: $msgID, ')
          ..write('userID: $userID, ')
          ..write('conversationID: $conversationID, ')
          ..write('emoji: $emoji, ')
          ..write('reactedAt: $reactedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalContactListsTable extends LocalContactLists
    with TableInfo<$LocalContactListsTable, LocalContactList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContactListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idListMeta = const VerificationMeta('idList');
  @override
  late final GeneratedColumn<int> idList = GeneratedColumn<int>(
    'id_list',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memberLimitMeta = const VerificationMeta(
    'memberLimit',
  );
  @override
  late final GeneratedColumn<int> memberLimit = GeneratedColumn<int>(
    'member_limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memberCountMeta = const VerificationMeta(
    'memberCount',
  );
  @override
  late final GeneratedColumn<int> memberCount = GeneratedColumn<int>(
    'member_count',
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
    idList,
    name,
    kind,
    color,
    memberLimit,
    memberCount,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_contact_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContactList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id_list')) {
      context.handle(
        _idListMeta,
        idList.isAcceptableOrUnknown(data['id_list']!, _idListMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('member_limit')) {
      context.handle(
        _memberLimitMeta,
        memberLimit.isAcceptableOrUnknown(
          data['member_limit']!,
          _memberLimitMeta,
        ),
      );
    }
    if (data.containsKey('member_count')) {
      context.handle(
        _memberCountMeta,
        memberCount.isAcceptableOrUnknown(
          data['member_count']!,
          _memberCountMeta,
        ),
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
  Set<GeneratedColumn> get $primaryKey => {idList};
  @override
  LocalContactList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContactList(
      idList: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_list'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      memberLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}member_limit'],
      ),
      memberCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}member_count'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $LocalContactListsTable createAlias(String alias) {
    return $LocalContactListsTable(attachedDatabase, alias);
  }
}

class LocalContactList extends DataClass
    implements Insertable<LocalContactList> {
  final int idList;
  final String name;

  /// Identifiant stable des listes système (`family`, `friends`, …).
  /// Null pour une liste personnalisée — le libellé affiché est [name].
  final String? kind;

  /// Teinte de la puce (`#RRGGBB`), null = teinte du thème.
  final String? color;

  /// Plafond de membres (ex. Confiance = 5). Null = illimité.
  final int? memberLimit;

  /// Compte renvoyé par le serveur — évite un COUNT par liste à l'affichage.
  final int memberCount;
  final DateTime cachedAt;
  const LocalContactList({
    required this.idList,
    required this.name,
    this.kind,
    this.color,
    this.memberLimit,
    required this.memberCount,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id_list'] = Variable<int>(idList);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || memberLimit != null) {
      map['member_limit'] = Variable<int>(memberLimit);
    }
    map['member_count'] = Variable<int>(memberCount);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LocalContactListsCompanion toCompanion(bool nullToAbsent) {
    return LocalContactListsCompanion(
      idList: Value(idList),
      name: Value(name),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      memberLimit: memberLimit == null && nullToAbsent
          ? const Value.absent()
          : Value(memberLimit),
      memberCount: Value(memberCount),
      cachedAt: Value(cachedAt),
    );
  }

  factory LocalContactList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContactList(
      idList: serializer.fromJson<int>(json['idList']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String?>(json['kind']),
      color: serializer.fromJson<String?>(json['color']),
      memberLimit: serializer.fromJson<int?>(json['memberLimit']),
      memberCount: serializer.fromJson<int>(json['memberCount']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idList': serializer.toJson<int>(idList),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String?>(kind),
      'color': serializer.toJson<String?>(color),
      'memberLimit': serializer.toJson<int?>(memberLimit),
      'memberCount': serializer.toJson<int>(memberCount),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  LocalContactList copyWith({
    int? idList,
    String? name,
    Value<String?> kind = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<int?> memberLimit = const Value.absent(),
    int? memberCount,
    DateTime? cachedAt,
  }) => LocalContactList(
    idList: idList ?? this.idList,
    name: name ?? this.name,
    kind: kind.present ? kind.value : this.kind,
    color: color.present ? color.value : this.color,
    memberLimit: memberLimit.present ? memberLimit.value : this.memberLimit,
    memberCount: memberCount ?? this.memberCount,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  LocalContactList copyWithCompanion(LocalContactListsCompanion data) {
    return LocalContactList(
      idList: data.idList.present ? data.idList.value : this.idList,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      color: data.color.present ? data.color.value : this.color,
      memberLimit: data.memberLimit.present
          ? data.memberLimit.value
          : this.memberLimit,
      memberCount: data.memberCount.present
          ? data.memberCount.value
          : this.memberCount,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactList(')
          ..write('idList: $idList, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('memberLimit: $memberLimit, ')
          ..write('memberCount: $memberCount, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    idList,
    name,
    kind,
    color,
    memberLimit,
    memberCount,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContactList &&
          other.idList == this.idList &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.color == this.color &&
          other.memberLimit == this.memberLimit &&
          other.memberCount == this.memberCount &&
          other.cachedAt == this.cachedAt);
}

class LocalContactListsCompanion extends UpdateCompanion<LocalContactList> {
  final Value<int> idList;
  final Value<String> name;
  final Value<String?> kind;
  final Value<String?> color;
  final Value<int?> memberLimit;
  final Value<int> memberCount;
  final Value<DateTime> cachedAt;
  const LocalContactListsCompanion({
    this.idList = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.color = const Value.absent(),
    this.memberLimit = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  LocalContactListsCompanion.insert({
    this.idList = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.color = const Value.absent(),
    this.memberLimit = const Value.absent(),
    this.memberCount = const Value.absent(),
    required DateTime cachedAt,
  }) : cachedAt = Value(cachedAt);
  static Insertable<LocalContactList> custom({
    Expression<int>? idList,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? color,
    Expression<int>? memberLimit,
    Expression<int>? memberCount,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (idList != null) 'id_list': idList,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (color != null) 'color': color,
      if (memberLimit != null) 'member_limit': memberLimit,
      if (memberCount != null) 'member_count': memberCount,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  LocalContactListsCompanion copyWith({
    Value<int>? idList,
    Value<String>? name,
    Value<String?>? kind,
    Value<String?>? color,
    Value<int?>? memberLimit,
    Value<int>? memberCount,
    Value<DateTime>? cachedAt,
  }) {
    return LocalContactListsCompanion(
      idList: idList ?? this.idList,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      color: color ?? this.color,
      memberLimit: memberLimit ?? this.memberLimit,
      memberCount: memberCount ?? this.memberCount,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idList.present) {
      map['id_list'] = Variable<int>(idList.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (memberLimit.present) {
      map['member_limit'] = Variable<int>(memberLimit.value);
    }
    if (memberCount.present) {
      map['member_count'] = Variable<int>(memberCount.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactListsCompanion(')
          ..write('idList: $idList, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('memberLimit: $memberLimit, ')
          ..write('memberCount: $memberCount, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalContactListMembersTable extends LocalContactListMembers
    with TableInfo<$LocalContactListMembersTable, LocalContactListMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContactListMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idListMeta = const VerificationMeta('idList');
  @override
  late final GeneratedColumn<int> idList = GeneratedColumn<int>(
    'id_list',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idFriendMeta = const VerificationMeta(
    'idFriend',
  );
  @override
  late final GeneratedColumn<int> idFriend = GeneratedColumn<int>(
    'id_friend',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [idList, idFriend];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_contact_list_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContactListMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id_list')) {
      context.handle(
        _idListMeta,
        idList.isAcceptableOrUnknown(data['id_list']!, _idListMeta),
      );
    } else if (isInserting) {
      context.missing(_idListMeta);
    }
    if (data.containsKey('id_friend')) {
      context.handle(
        _idFriendMeta,
        idFriend.isAcceptableOrUnknown(data['id_friend']!, _idFriendMeta),
      );
    } else if (isInserting) {
      context.missing(_idFriendMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idList, idFriend};
  @override
  LocalContactListMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContactListMember(
      idList: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_list'],
      )!,
      idFriend: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id_friend'],
      )!,
    );
  }

  @override
  $LocalContactListMembersTable createAlias(String alias) {
    return $LocalContactListMembersTable(attachedDatabase, alias);
  }
}

class LocalContactListMember extends DataClass
    implements Insertable<LocalContactListMember> {
  final int idList;
  final int idFriend;
  const LocalContactListMember({required this.idList, required this.idFriend});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id_list'] = Variable<int>(idList);
    map['id_friend'] = Variable<int>(idFriend);
    return map;
  }

  LocalContactListMembersCompanion toCompanion(bool nullToAbsent) {
    return LocalContactListMembersCompanion(
      idList: Value(idList),
      idFriend: Value(idFriend),
    );
  }

  factory LocalContactListMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContactListMember(
      idList: serializer.fromJson<int>(json['idList']),
      idFriend: serializer.fromJson<int>(json['idFriend']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idList': serializer.toJson<int>(idList),
      'idFriend': serializer.toJson<int>(idFriend),
    };
  }

  LocalContactListMember copyWith({int? idList, int? idFriend}) =>
      LocalContactListMember(
        idList: idList ?? this.idList,
        idFriend: idFriend ?? this.idFriend,
      );
  LocalContactListMember copyWithCompanion(
    LocalContactListMembersCompanion data,
  ) {
    return LocalContactListMember(
      idList: data.idList.present ? data.idList.value : this.idList,
      idFriend: data.idFriend.present ? data.idFriend.value : this.idFriend,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactListMember(')
          ..write('idList: $idList, ')
          ..write('idFriend: $idFriend')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(idList, idFriend);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContactListMember &&
          other.idList == this.idList &&
          other.idFriend == this.idFriend);
}

class LocalContactListMembersCompanion
    extends UpdateCompanion<LocalContactListMember> {
  final Value<int> idList;
  final Value<int> idFriend;
  final Value<int> rowid;
  const LocalContactListMembersCompanion({
    this.idList = const Value.absent(),
    this.idFriend = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalContactListMembersCompanion.insert({
    required int idList,
    required int idFriend,
    this.rowid = const Value.absent(),
  }) : idList = Value(idList),
       idFriend = Value(idFriend);
  static Insertable<LocalContactListMember> custom({
    Expression<int>? idList,
    Expression<int>? idFriend,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (idList != null) 'id_list': idList,
      if (idFriend != null) 'id_friend': idFriend,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalContactListMembersCompanion copyWith({
    Value<int>? idList,
    Value<int>? idFriend,
    Value<int>? rowid,
  }) {
    return LocalContactListMembersCompanion(
      idList: idList ?? this.idList,
      idFriend: idFriend ?? this.idFriend,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idList.present) {
      map['id_list'] = Variable<int>(idList.value);
    }
    if (idFriend.present) {
      map['id_friend'] = Variable<int>(idFriend.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactListMembersCompanion(')
          ..write('idList: $idList, ')
          ..write('idFriend: $idFriend, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTripsTable extends LocalTrips
    with TableInfo<$LocalTripsTable, LocalTrip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTripsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<int> ownerId = GeneratedColumn<int>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('taxi'),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _etaAtMeta = const VerificationMeta('etaAt');
  @override
  late final GeneratedColumn<DateTime> etaAt = GeneratedColumn<DateTime>(
    'eta_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _graceMinutesMeta = const VerificationMeta(
    'graceMinutes',
  );
  @override
  late final GeneratedColumn<int> graceMinutes = GeneratedColumn<int>(
    'grace_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _extensionsMeta = const VerificationMeta(
    'extensions',
  );
  @override
  late final GeneratedColumn<int> extensions = GeneratedColumn<int>(
    'extensions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destLabelMeta = const VerificationMeta(
    'destLabel',
  );
  @override
  late final GeneratedColumn<String> destLabel = GeneratedColumn<String>(
    'dest_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destLatMeta = const VerificationMeta(
    'destLat',
  );
  @override
  late final GeneratedColumn<double> destLat = GeneratedColumn<double>(
    'dest_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destLngMeta = const VerificationMeta(
    'destLng',
  );
  @override
  late final GeneratedColumn<double> destLng = GeneratedColumn<double>(
    'dest_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _destRadiusMMeta = const VerificationMeta(
    'destRadiusM',
  );
  @override
  late final GeneratedColumn<int> destRadiusM = GeneratedColumn<int>(
    'dest_radius_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLatMeta = const VerificationMeta(
    'lastLat',
  );
  @override
  late final GeneratedColumn<double> lastLat = GeneratedColumn<double>(
    'last_lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLngMeta = const VerificationMeta(
    'lastLng',
  );
  @override
  late final GeneratedColumn<double> lastLng = GeneratedColumn<double>(
    'last_lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAccuracyMMeta = const VerificationMeta(
    'lastAccuracyM',
  );
  @override
  late final GeneratedColumn<int> lastAccuracyM = GeneratedColumn<int>(
    'last_accuracy_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastBatteryMeta = const VerificationMeta(
    'lastBattery',
  );
  @override
  late final GeneratedColumn<int> lastBattery = GeneratedColumn<int>(
    'last_battery',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAtMeta = const VerificationMeta('lastAt');
  @override
  late final GeneratedColumn<DateTime> lastAt = GeneratedColumn<DateTime>(
    'last_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _staleMeta = const VerificationMeta('stale');
  @override
  late final GeneratedColumn<bool> stale = GeneratedColumn<bool>(
    'stale',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("stale" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<DateTime> closedAt = GeneratedColumn<DateTime>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closeReasonMeta = const VerificationMeta(
    'closeReason',
  );
  @override
  late final GeneratedColumn<String> closeReason = GeneratedColumn<String>(
    'close_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isOwnerMeta = const VerificationMeta(
    'isOwner',
  );
  @override
  late final GeneratedColumn<bool> isOwner = GeneratedColumn<bool>(
    'is_owner',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_owner" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _watcherCountMeta = const VerificationMeta(
    'watcherCount',
  );
  @override
  late final GeneratedColumn<int> watcherCount = GeneratedColumn<int>(
    'watcher_count',
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
    id,
    ownerId,
    kind,
    state,
    etaAt,
    graceMinutes,
    extensions,
    note,
    destLabel,
    destLat,
    destLng,
    destRadiusM,
    lastLat,
    lastLng,
    lastAccuracyM,
    lastBattery,
    lastAt,
    stale,
    startedAt,
    closedAt,
    closeReason,
    isOwner,
    watcherCount,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_trips';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTrip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('eta_at')) {
      context.handle(
        _etaAtMeta,
        etaAt.isAcceptableOrUnknown(data['eta_at']!, _etaAtMeta),
      );
    }
    if (data.containsKey('grace_minutes')) {
      context.handle(
        _graceMinutesMeta,
        graceMinutes.isAcceptableOrUnknown(
          data['grace_minutes']!,
          _graceMinutesMeta,
        ),
      );
    }
    if (data.containsKey('extensions')) {
      context.handle(
        _extensionsMeta,
        extensions.isAcceptableOrUnknown(data['extensions']!, _extensionsMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('dest_label')) {
      context.handle(
        _destLabelMeta,
        destLabel.isAcceptableOrUnknown(data['dest_label']!, _destLabelMeta),
      );
    }
    if (data.containsKey('dest_lat')) {
      context.handle(
        _destLatMeta,
        destLat.isAcceptableOrUnknown(data['dest_lat']!, _destLatMeta),
      );
    }
    if (data.containsKey('dest_lng')) {
      context.handle(
        _destLngMeta,
        destLng.isAcceptableOrUnknown(data['dest_lng']!, _destLngMeta),
      );
    }
    if (data.containsKey('dest_radius_m')) {
      context.handle(
        _destRadiusMMeta,
        destRadiusM.isAcceptableOrUnknown(
          data['dest_radius_m']!,
          _destRadiusMMeta,
        ),
      );
    }
    if (data.containsKey('last_lat')) {
      context.handle(
        _lastLatMeta,
        lastLat.isAcceptableOrUnknown(data['last_lat']!, _lastLatMeta),
      );
    }
    if (data.containsKey('last_lng')) {
      context.handle(
        _lastLngMeta,
        lastLng.isAcceptableOrUnknown(data['last_lng']!, _lastLngMeta),
      );
    }
    if (data.containsKey('last_accuracy_m')) {
      context.handle(
        _lastAccuracyMMeta,
        lastAccuracyM.isAcceptableOrUnknown(
          data['last_accuracy_m']!,
          _lastAccuracyMMeta,
        ),
      );
    }
    if (data.containsKey('last_battery')) {
      context.handle(
        _lastBatteryMeta,
        lastBattery.isAcceptableOrUnknown(
          data['last_battery']!,
          _lastBatteryMeta,
        ),
      );
    }
    if (data.containsKey('last_at')) {
      context.handle(
        _lastAtMeta,
        lastAt.isAcceptableOrUnknown(data['last_at']!, _lastAtMeta),
      );
    }
    if (data.containsKey('stale')) {
      context.handle(
        _staleMeta,
        stale.isAcceptableOrUnknown(data['stale']!, _staleMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    if (data.containsKey('close_reason')) {
      context.handle(
        _closeReasonMeta,
        closeReason.isAcceptableOrUnknown(
          data['close_reason']!,
          _closeReasonMeta,
        ),
      );
    }
    if (data.containsKey('is_owner')) {
      context.handle(
        _isOwnerMeta,
        isOwner.isAcceptableOrUnknown(data['is_owner']!, _isOwnerMeta),
      );
    }
    if (data.containsKey('watcher_count')) {
      context.handle(
        _watcherCountMeta,
        watcherCount.isAcceptableOrUnknown(
          data['watcher_count']!,
          _watcherCountMeta,
        ),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalTrip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTrip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}owner_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      etaAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eta_at'],
      ),
      graceMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grace_minutes'],
      )!,
      extensions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}extensions'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      destLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dest_label'],
      ),
      destLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dest_lat'],
      ),
      destLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dest_lng'],
      ),
      destRadiusM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dest_radius_m'],
      ),
      lastLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_lat'],
      ),
      lastLng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_lng'],
      ),
      lastAccuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accuracy_m'],
      ),
      lastBattery: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_battery'],
      ),
      lastAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_at'],
      ),
      stale: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stale'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}closed_at'],
      ),
      closeReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}close_reason'],
      ),
      isOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_owner'],
      )!,
      watcherCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watcher_count'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $LocalTripsTable createAlias(String alias) {
    return $LocalTripsTable(attachedDatabase, alias);
  }
}

class LocalTrip extends DataClass implements Insertable<LocalTrip> {
  final int id;
  final int ownerId;

  /// `taxi` | `walk` | `sos`.
  final String kind;

  /// `active` | `awaiting_confirm` | `alert` | `sos` | `closed_*`.
  final String state;
  final DateTime? etaAt;
  final int graceMinutes;
  final int extensions;
  final String? note;
  final String? destLabel;

  /// Destination déclarée au départ, avec son rayon d'arrivée.
  ///
  /// Mise en cache pour une seule raison : l'écran de suivi doit pouvoir
  /// dessiner le point d'arrivée et son cercle **avant** la première réponse du
  /// serveur, et continuer à les dessiner hors ligne. Sans ces colonnes, la
  /// carte n'affiche qu'un pin qui se déplace sans qu'on sache vers quoi.
  ///
  /// Le libellé, lui, est résolu une seule fois à la création : géocoder la
  /// trace enverrait tout le déplacement à un tiers.
  final double? destLat;
  final double? destLng;
  final int? destRadiusM;

  /// Dernière position connue. `lastAt` est l'heure de **capture** : c'est elle
  /// qu'on affiche (« maj il y a 8 s »), pas l'heure de réception.
  final double? lastLat;
  final double? lastLng;
  final int? lastAccuracyM;
  final int? lastBattery;
  final DateTime? lastAt;

  /// Plus de position reçue depuis le seuil de péremption. **Pas une alerte** :
  /// une information, affichée en gris.
  final bool stale;
  final DateTime startedAt;
  final DateTime? closedAt;
  final String? closeReason;
  final bool isOwner;

  /// Nombre de destinataires. Côté membre, c'est tout ce qu'on connaît d'eux :
  /// le nombre rassure, les identités exposeraient le carnet d'adresses d'un
  /// autre.
  final int watcherCount;
  final DateTime cachedAt;
  const LocalTrip({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.state,
    this.etaAt,
    required this.graceMinutes,
    required this.extensions,
    this.note,
    this.destLabel,
    this.destLat,
    this.destLng,
    this.destRadiusM,
    this.lastLat,
    this.lastLng,
    this.lastAccuracyM,
    this.lastBattery,
    this.lastAt,
    required this.stale,
    required this.startedAt,
    this.closedAt,
    this.closeReason,
    required this.isOwner,
    required this.watcherCount,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['owner_id'] = Variable<int>(ownerId);
    map['kind'] = Variable<String>(kind);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || etaAt != null) {
      map['eta_at'] = Variable<DateTime>(etaAt);
    }
    map['grace_minutes'] = Variable<int>(graceMinutes);
    map['extensions'] = Variable<int>(extensions);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || destLabel != null) {
      map['dest_label'] = Variable<String>(destLabel);
    }
    if (!nullToAbsent || destLat != null) {
      map['dest_lat'] = Variable<double>(destLat);
    }
    if (!nullToAbsent || destLng != null) {
      map['dest_lng'] = Variable<double>(destLng);
    }
    if (!nullToAbsent || destRadiusM != null) {
      map['dest_radius_m'] = Variable<int>(destRadiusM);
    }
    if (!nullToAbsent || lastLat != null) {
      map['last_lat'] = Variable<double>(lastLat);
    }
    if (!nullToAbsent || lastLng != null) {
      map['last_lng'] = Variable<double>(lastLng);
    }
    if (!nullToAbsent || lastAccuracyM != null) {
      map['last_accuracy_m'] = Variable<int>(lastAccuracyM);
    }
    if (!nullToAbsent || lastBattery != null) {
      map['last_battery'] = Variable<int>(lastBattery);
    }
    if (!nullToAbsent || lastAt != null) {
      map['last_at'] = Variable<DateTime>(lastAt);
    }
    map['stale'] = Variable<bool>(stale);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<DateTime>(closedAt);
    }
    if (!nullToAbsent || closeReason != null) {
      map['close_reason'] = Variable<String>(closeReason);
    }
    map['is_owner'] = Variable<bool>(isOwner);
    map['watcher_count'] = Variable<int>(watcherCount);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  LocalTripsCompanion toCompanion(bool nullToAbsent) {
    return LocalTripsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      kind: Value(kind),
      state: Value(state),
      etaAt: etaAt == null && nullToAbsent
          ? const Value.absent()
          : Value(etaAt),
      graceMinutes: Value(graceMinutes),
      extensions: Value(extensions),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      destLabel: destLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(destLabel),
      destLat: destLat == null && nullToAbsent
          ? const Value.absent()
          : Value(destLat),
      destLng: destLng == null && nullToAbsent
          ? const Value.absent()
          : Value(destLng),
      destRadiusM: destRadiusM == null && nullToAbsent
          ? const Value.absent()
          : Value(destRadiusM),
      lastLat: lastLat == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLat),
      lastLng: lastLng == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLng),
      lastAccuracyM: lastAccuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAccuracyM),
      lastBattery: lastBattery == null && nullToAbsent
          ? const Value.absent()
          : Value(lastBattery),
      lastAt: lastAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAt),
      stale: Value(stale),
      startedAt: Value(startedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
      closeReason: closeReason == null && nullToAbsent
          ? const Value.absent()
          : Value(closeReason),
      isOwner: Value(isOwner),
      watcherCount: Value(watcherCount),
      cachedAt: Value(cachedAt),
    );
  }

  factory LocalTrip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTrip(
      id: serializer.fromJson<int>(json['id']),
      ownerId: serializer.fromJson<int>(json['ownerId']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String>(json['state']),
      etaAt: serializer.fromJson<DateTime?>(json['etaAt']),
      graceMinutes: serializer.fromJson<int>(json['graceMinutes']),
      extensions: serializer.fromJson<int>(json['extensions']),
      note: serializer.fromJson<String?>(json['note']),
      destLabel: serializer.fromJson<String?>(json['destLabel']),
      destLat: serializer.fromJson<double?>(json['destLat']),
      destLng: serializer.fromJson<double?>(json['destLng']),
      destRadiusM: serializer.fromJson<int?>(json['destRadiusM']),
      lastLat: serializer.fromJson<double?>(json['lastLat']),
      lastLng: serializer.fromJson<double?>(json['lastLng']),
      lastAccuracyM: serializer.fromJson<int?>(json['lastAccuracyM']),
      lastBattery: serializer.fromJson<int?>(json['lastBattery']),
      lastAt: serializer.fromJson<DateTime?>(json['lastAt']),
      stale: serializer.fromJson<bool>(json['stale']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      closedAt: serializer.fromJson<DateTime?>(json['closedAt']),
      closeReason: serializer.fromJson<String?>(json['closeReason']),
      isOwner: serializer.fromJson<bool>(json['isOwner']),
      watcherCount: serializer.fromJson<int>(json['watcherCount']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ownerId': serializer.toJson<int>(ownerId),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String>(state),
      'etaAt': serializer.toJson<DateTime?>(etaAt),
      'graceMinutes': serializer.toJson<int>(graceMinutes),
      'extensions': serializer.toJson<int>(extensions),
      'note': serializer.toJson<String?>(note),
      'destLabel': serializer.toJson<String?>(destLabel),
      'destLat': serializer.toJson<double?>(destLat),
      'destLng': serializer.toJson<double?>(destLng),
      'destRadiusM': serializer.toJson<int?>(destRadiusM),
      'lastLat': serializer.toJson<double?>(lastLat),
      'lastLng': serializer.toJson<double?>(lastLng),
      'lastAccuracyM': serializer.toJson<int?>(lastAccuracyM),
      'lastBattery': serializer.toJson<int?>(lastBattery),
      'lastAt': serializer.toJson<DateTime?>(lastAt),
      'stale': serializer.toJson<bool>(stale),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'closedAt': serializer.toJson<DateTime?>(closedAt),
      'closeReason': serializer.toJson<String?>(closeReason),
      'isOwner': serializer.toJson<bool>(isOwner),
      'watcherCount': serializer.toJson<int>(watcherCount),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  LocalTrip copyWith({
    int? id,
    int? ownerId,
    String? kind,
    String? state,
    Value<DateTime?> etaAt = const Value.absent(),
    int? graceMinutes,
    int? extensions,
    Value<String?> note = const Value.absent(),
    Value<String?> destLabel = const Value.absent(),
    Value<double?> destLat = const Value.absent(),
    Value<double?> destLng = const Value.absent(),
    Value<int?> destRadiusM = const Value.absent(),
    Value<double?> lastLat = const Value.absent(),
    Value<double?> lastLng = const Value.absent(),
    Value<int?> lastAccuracyM = const Value.absent(),
    Value<int?> lastBattery = const Value.absent(),
    Value<DateTime?> lastAt = const Value.absent(),
    bool? stale,
    DateTime? startedAt,
    Value<DateTime?> closedAt = const Value.absent(),
    Value<String?> closeReason = const Value.absent(),
    bool? isOwner,
    int? watcherCount,
    DateTime? cachedAt,
  }) => LocalTrip(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    kind: kind ?? this.kind,
    state: state ?? this.state,
    etaAt: etaAt.present ? etaAt.value : this.etaAt,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    extensions: extensions ?? this.extensions,
    note: note.present ? note.value : this.note,
    destLabel: destLabel.present ? destLabel.value : this.destLabel,
    destLat: destLat.present ? destLat.value : this.destLat,
    destLng: destLng.present ? destLng.value : this.destLng,
    destRadiusM: destRadiusM.present ? destRadiusM.value : this.destRadiusM,
    lastLat: lastLat.present ? lastLat.value : this.lastLat,
    lastLng: lastLng.present ? lastLng.value : this.lastLng,
    lastAccuracyM: lastAccuracyM.present
        ? lastAccuracyM.value
        : this.lastAccuracyM,
    lastBattery: lastBattery.present ? lastBattery.value : this.lastBattery,
    lastAt: lastAt.present ? lastAt.value : this.lastAt,
    stale: stale ?? this.stale,
    startedAt: startedAt ?? this.startedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
    closeReason: closeReason.present ? closeReason.value : this.closeReason,
    isOwner: isOwner ?? this.isOwner,
    watcherCount: watcherCount ?? this.watcherCount,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  LocalTrip copyWithCompanion(LocalTripsCompanion data) {
    return LocalTrip(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      etaAt: data.etaAt.present ? data.etaAt.value : this.etaAt,
      graceMinutes: data.graceMinutes.present
          ? data.graceMinutes.value
          : this.graceMinutes,
      extensions: data.extensions.present
          ? data.extensions.value
          : this.extensions,
      note: data.note.present ? data.note.value : this.note,
      destLabel: data.destLabel.present ? data.destLabel.value : this.destLabel,
      destLat: data.destLat.present ? data.destLat.value : this.destLat,
      destLng: data.destLng.present ? data.destLng.value : this.destLng,
      destRadiusM: data.destRadiusM.present
          ? data.destRadiusM.value
          : this.destRadiusM,
      lastLat: data.lastLat.present ? data.lastLat.value : this.lastLat,
      lastLng: data.lastLng.present ? data.lastLng.value : this.lastLng,
      lastAccuracyM: data.lastAccuracyM.present
          ? data.lastAccuracyM.value
          : this.lastAccuracyM,
      lastBattery: data.lastBattery.present
          ? data.lastBattery.value
          : this.lastBattery,
      lastAt: data.lastAt.present ? data.lastAt.value : this.lastAt,
      stale: data.stale.present ? data.stale.value : this.stale,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
      closeReason: data.closeReason.present
          ? data.closeReason.value
          : this.closeReason,
      isOwner: data.isOwner.present ? data.isOwner.value : this.isOwner,
      watcherCount: data.watcherCount.present
          ? data.watcherCount.value
          : this.watcherCount,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTrip(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('etaAt: $etaAt, ')
          ..write('graceMinutes: $graceMinutes, ')
          ..write('extensions: $extensions, ')
          ..write('note: $note, ')
          ..write('destLabel: $destLabel, ')
          ..write('destLat: $destLat, ')
          ..write('destLng: $destLng, ')
          ..write('destRadiusM: $destRadiusM, ')
          ..write('lastLat: $lastLat, ')
          ..write('lastLng: $lastLng, ')
          ..write('lastAccuracyM: $lastAccuracyM, ')
          ..write('lastBattery: $lastBattery, ')
          ..write('lastAt: $lastAt, ')
          ..write('stale: $stale, ')
          ..write('startedAt: $startedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('closeReason: $closeReason, ')
          ..write('isOwner: $isOwner, ')
          ..write('watcherCount: $watcherCount, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    ownerId,
    kind,
    state,
    etaAt,
    graceMinutes,
    extensions,
    note,
    destLabel,
    destLat,
    destLng,
    destRadiusM,
    lastLat,
    lastLng,
    lastAccuracyM,
    lastBattery,
    lastAt,
    stale,
    startedAt,
    closedAt,
    closeReason,
    isOwner,
    watcherCount,
    cachedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTrip &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.etaAt == this.etaAt &&
          other.graceMinutes == this.graceMinutes &&
          other.extensions == this.extensions &&
          other.note == this.note &&
          other.destLabel == this.destLabel &&
          other.destLat == this.destLat &&
          other.destLng == this.destLng &&
          other.destRadiusM == this.destRadiusM &&
          other.lastLat == this.lastLat &&
          other.lastLng == this.lastLng &&
          other.lastAccuracyM == this.lastAccuracyM &&
          other.lastBattery == this.lastBattery &&
          other.lastAt == this.lastAt &&
          other.stale == this.stale &&
          other.startedAt == this.startedAt &&
          other.closedAt == this.closedAt &&
          other.closeReason == this.closeReason &&
          other.isOwner == this.isOwner &&
          other.watcherCount == this.watcherCount &&
          other.cachedAt == this.cachedAt);
}

class LocalTripsCompanion extends UpdateCompanion<LocalTrip> {
  final Value<int> id;
  final Value<int> ownerId;
  final Value<String> kind;
  final Value<String> state;
  final Value<DateTime?> etaAt;
  final Value<int> graceMinutes;
  final Value<int> extensions;
  final Value<String?> note;
  final Value<String?> destLabel;
  final Value<double?> destLat;
  final Value<double?> destLng;
  final Value<int?> destRadiusM;
  final Value<double?> lastLat;
  final Value<double?> lastLng;
  final Value<int?> lastAccuracyM;
  final Value<int?> lastBattery;
  final Value<DateTime?> lastAt;
  final Value<bool> stale;
  final Value<DateTime> startedAt;
  final Value<DateTime?> closedAt;
  final Value<String?> closeReason;
  final Value<bool> isOwner;
  final Value<int> watcherCount;
  final Value<DateTime> cachedAt;
  const LocalTripsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.etaAt = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.extensions = const Value.absent(),
    this.note = const Value.absent(),
    this.destLabel = const Value.absent(),
    this.destLat = const Value.absent(),
    this.destLng = const Value.absent(),
    this.destRadiusM = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLng = const Value.absent(),
    this.lastAccuracyM = const Value.absent(),
    this.lastBattery = const Value.absent(),
    this.lastAt = const Value.absent(),
    this.stale = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.closeReason = const Value.absent(),
    this.isOwner = const Value.absent(),
    this.watcherCount = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  LocalTripsCompanion.insert({
    this.id = const Value.absent(),
    required int ownerId,
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.etaAt = const Value.absent(),
    this.graceMinutes = const Value.absent(),
    this.extensions = const Value.absent(),
    this.note = const Value.absent(),
    this.destLabel = const Value.absent(),
    this.destLat = const Value.absent(),
    this.destLng = const Value.absent(),
    this.destRadiusM = const Value.absent(),
    this.lastLat = const Value.absent(),
    this.lastLng = const Value.absent(),
    this.lastAccuracyM = const Value.absent(),
    this.lastBattery = const Value.absent(),
    this.lastAt = const Value.absent(),
    this.stale = const Value.absent(),
    required DateTime startedAt,
    this.closedAt = const Value.absent(),
    this.closeReason = const Value.absent(),
    this.isOwner = const Value.absent(),
    this.watcherCount = const Value.absent(),
    required DateTime cachedAt,
  }) : ownerId = Value(ownerId),
       startedAt = Value(startedAt),
       cachedAt = Value(cachedAt);
  static Insertable<LocalTrip> custom({
    Expression<int>? id,
    Expression<int>? ownerId,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<DateTime>? etaAt,
    Expression<int>? graceMinutes,
    Expression<int>? extensions,
    Expression<String>? note,
    Expression<String>? destLabel,
    Expression<double>? destLat,
    Expression<double>? destLng,
    Expression<int>? destRadiusM,
    Expression<double>? lastLat,
    Expression<double>? lastLng,
    Expression<int>? lastAccuracyM,
    Expression<int>? lastBattery,
    Expression<DateTime>? lastAt,
    Expression<bool>? stale,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? closedAt,
    Expression<String>? closeReason,
    Expression<bool>? isOwner,
    Expression<int>? watcherCount,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (etaAt != null) 'eta_at': etaAt,
      if (graceMinutes != null) 'grace_minutes': graceMinutes,
      if (extensions != null) 'extensions': extensions,
      if (note != null) 'note': note,
      if (destLabel != null) 'dest_label': destLabel,
      if (destLat != null) 'dest_lat': destLat,
      if (destLng != null) 'dest_lng': destLng,
      if (destRadiusM != null) 'dest_radius_m': destRadiusM,
      if (lastLat != null) 'last_lat': lastLat,
      if (lastLng != null) 'last_lng': lastLng,
      if (lastAccuracyM != null) 'last_accuracy_m': lastAccuracyM,
      if (lastBattery != null) 'last_battery': lastBattery,
      if (lastAt != null) 'last_at': lastAt,
      if (stale != null) 'stale': stale,
      if (startedAt != null) 'started_at': startedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (closeReason != null) 'close_reason': closeReason,
      if (isOwner != null) 'is_owner': isOwner,
      if (watcherCount != null) 'watcher_count': watcherCount,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  LocalTripsCompanion copyWith({
    Value<int>? id,
    Value<int>? ownerId,
    Value<String>? kind,
    Value<String>? state,
    Value<DateTime?>? etaAt,
    Value<int>? graceMinutes,
    Value<int>? extensions,
    Value<String?>? note,
    Value<String?>? destLabel,
    Value<double?>? destLat,
    Value<double?>? destLng,
    Value<int?>? destRadiusM,
    Value<double?>? lastLat,
    Value<double?>? lastLng,
    Value<int?>? lastAccuracyM,
    Value<int?>? lastBattery,
    Value<DateTime?>? lastAt,
    Value<bool>? stale,
    Value<DateTime>? startedAt,
    Value<DateTime?>? closedAt,
    Value<String?>? closeReason,
    Value<bool>? isOwner,
    Value<int>? watcherCount,
    Value<DateTime>? cachedAt,
  }) {
    return LocalTripsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      etaAt: etaAt ?? this.etaAt,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      extensions: extensions ?? this.extensions,
      note: note ?? this.note,
      destLabel: destLabel ?? this.destLabel,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      destRadiusM: destRadiusM ?? this.destRadiusM,
      lastLat: lastLat ?? this.lastLat,
      lastLng: lastLng ?? this.lastLng,
      lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
      lastBattery: lastBattery ?? this.lastBattery,
      lastAt: lastAt ?? this.lastAt,
      stale: stale ?? this.stale,
      startedAt: startedAt ?? this.startedAt,
      closedAt: closedAt ?? this.closedAt,
      closeReason: closeReason ?? this.closeReason,
      isOwner: isOwner ?? this.isOwner,
      watcherCount: watcherCount ?? this.watcherCount,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<int>(ownerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (etaAt.present) {
      map['eta_at'] = Variable<DateTime>(etaAt.value);
    }
    if (graceMinutes.present) {
      map['grace_minutes'] = Variable<int>(graceMinutes.value);
    }
    if (extensions.present) {
      map['extensions'] = Variable<int>(extensions.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (destLabel.present) {
      map['dest_label'] = Variable<String>(destLabel.value);
    }
    if (destLat.present) {
      map['dest_lat'] = Variable<double>(destLat.value);
    }
    if (destLng.present) {
      map['dest_lng'] = Variable<double>(destLng.value);
    }
    if (destRadiusM.present) {
      map['dest_radius_m'] = Variable<int>(destRadiusM.value);
    }
    if (lastLat.present) {
      map['last_lat'] = Variable<double>(lastLat.value);
    }
    if (lastLng.present) {
      map['last_lng'] = Variable<double>(lastLng.value);
    }
    if (lastAccuracyM.present) {
      map['last_accuracy_m'] = Variable<int>(lastAccuracyM.value);
    }
    if (lastBattery.present) {
      map['last_battery'] = Variable<int>(lastBattery.value);
    }
    if (lastAt.present) {
      map['last_at'] = Variable<DateTime>(lastAt.value);
    }
    if (stale.present) {
      map['stale'] = Variable<bool>(stale.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<DateTime>(closedAt.value);
    }
    if (closeReason.present) {
      map['close_reason'] = Variable<String>(closeReason.value);
    }
    if (isOwner.present) {
      map['is_owner'] = Variable<bool>(isOwner.value);
    }
    if (watcherCount.present) {
      map['watcher_count'] = Variable<int>(watcherCount.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTripsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('etaAt: $etaAt, ')
          ..write('graceMinutes: $graceMinutes, ')
          ..write('extensions: $extensions, ')
          ..write('note: $note, ')
          ..write('destLabel: $destLabel, ')
          ..write('destLat: $destLat, ')
          ..write('destLng: $destLng, ')
          ..write('destRadiusM: $destRadiusM, ')
          ..write('lastLat: $lastLat, ')
          ..write('lastLng: $lastLng, ')
          ..write('lastAccuracyM: $lastAccuracyM, ')
          ..write('lastBattery: $lastBattery, ')
          ..write('lastAt: $lastAt, ')
          ..write('stale: $stale, ')
          ..write('startedAt: $startedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('closeReason: $closeReason, ')
          ..write('isOwner: $isOwner, ')
          ..write('watcherCount: $watcherCount, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalTripPointsTable extends LocalTripPoints
    with TableInfo<$LocalTripPointsTable, LocalTripPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTripPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientSeqMeta = const VerificationMeta(
    'clientSeq',
  );
  @override
  late final GeneratedColumn<int> clientSeq = GeneratedColumn<int>(
    'client_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMMeta = const VerificationMeta(
    'accuracyM',
  );
  @override
  late final GeneratedColumn<int> accuracyM = GeneratedColumn<int>(
    'accuracy_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speedKmhMeta = const VerificationMeta(
    'speedKmh',
  );
  @override
  late final GeneratedColumn<int> speedKmh = GeneratedColumn<int>(
    'speed_kmh',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batteryMeta = const VerificationMeta(
    'battery',
  );
  @override
  late final GeneratedColumn<int> battery = GeneratedColumn<int>(
    'battery',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pendingMeta = const VerificationMeta(
    'pending',
  );
  @override
  late final GeneratedColumn<bool> pending = GeneratedColumn<bool>(
    'pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pending" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    tripId,
    clientSeq,
    lat,
    lng,
    accuracyM,
    speedKmh,
    battery,
    recordedAt,
    pending,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_trip_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTripPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('client_seq')) {
      context.handle(
        _clientSeqMeta,
        clientSeq.isAcceptableOrUnknown(data['client_seq']!, _clientSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_clientSeqMeta);
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    } else if (isInserting) {
      context.missing(_latMeta);
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    } else if (isInserting) {
      context.missing(_lngMeta);
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(
        _accuracyMMeta,
        accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta),
      );
    }
    if (data.containsKey('speed_kmh')) {
      context.handle(
        _speedKmhMeta,
        speedKmh.isAcceptableOrUnknown(data['speed_kmh']!, _speedKmhMeta),
      );
    }
    if (data.containsKey('battery')) {
      context.handle(
        _batteryMeta,
        battery.isAcceptableOrUnknown(data['battery']!, _batteryMeta),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('pending')) {
      context.handle(
        _pendingMeta,
        pending.isAcceptableOrUnknown(data['pending']!, _pendingMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, clientSeq};
  @override
  LocalTripPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTripPoint(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      clientSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}client_seq'],
      )!,
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      )!,
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      )!,
      accuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accuracy_m'],
      ),
      speedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}speed_kmh'],
      ),
      battery: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}battery'],
      ),
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      pending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pending'],
      )!,
    );
  }

  @override
  $LocalTripPointsTable createAlias(String alias) {
    return $LocalTripPointsTable(attachedDatabase, alias);
  }
}

class LocalTripPoint extends DataClass implements Insertable<LocalTripPoint> {
  final int tripId;
  final int clientSeq;
  final double lat;
  final double lng;
  final int? accuracyM;
  final int? speedKmh;
  final int? battery;

  /// Heure de capture réelle. Un point tamponné hors ligne repart avec **son**
  /// horodatage, jamais celui de l'envoi.
  final DateTime recordedAt;
  final bool pending;
  const LocalTripPoint({
    required this.tripId,
    required this.clientSeq,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.speedKmh,
    this.battery,
    required this.recordedAt,
    required this.pending,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<int>(tripId);
    map['client_seq'] = Variable<int>(clientSeq);
    map['lat'] = Variable<double>(lat);
    map['lng'] = Variable<double>(lng);
    if (!nullToAbsent || accuracyM != null) {
      map['accuracy_m'] = Variable<int>(accuracyM);
    }
    if (!nullToAbsent || speedKmh != null) {
      map['speed_kmh'] = Variable<int>(speedKmh);
    }
    if (!nullToAbsent || battery != null) {
      map['battery'] = Variable<int>(battery);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['pending'] = Variable<bool>(pending);
    return map;
  }

  LocalTripPointsCompanion toCompanion(bool nullToAbsent) {
    return LocalTripPointsCompanion(
      tripId: Value(tripId),
      clientSeq: Value(clientSeq),
      lat: Value(lat),
      lng: Value(lng),
      accuracyM: accuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyM),
      speedKmh: speedKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(speedKmh),
      battery: battery == null && nullToAbsent
          ? const Value.absent()
          : Value(battery),
      recordedAt: Value(recordedAt),
      pending: Value(pending),
    );
  }

  factory LocalTripPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTripPoint(
      tripId: serializer.fromJson<int>(json['tripId']),
      clientSeq: serializer.fromJson<int>(json['clientSeq']),
      lat: serializer.fromJson<double>(json['lat']),
      lng: serializer.fromJson<double>(json['lng']),
      accuracyM: serializer.fromJson<int?>(json['accuracyM']),
      speedKmh: serializer.fromJson<int?>(json['speedKmh']),
      battery: serializer.fromJson<int?>(json['battery']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      pending: serializer.fromJson<bool>(json['pending']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<int>(tripId),
      'clientSeq': serializer.toJson<int>(clientSeq),
      'lat': serializer.toJson<double>(lat),
      'lng': serializer.toJson<double>(lng),
      'accuracyM': serializer.toJson<int?>(accuracyM),
      'speedKmh': serializer.toJson<int?>(speedKmh),
      'battery': serializer.toJson<int?>(battery),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'pending': serializer.toJson<bool>(pending),
    };
  }

  LocalTripPoint copyWith({
    int? tripId,
    int? clientSeq,
    double? lat,
    double? lng,
    Value<int?> accuracyM = const Value.absent(),
    Value<int?> speedKmh = const Value.absent(),
    Value<int?> battery = const Value.absent(),
    DateTime? recordedAt,
    bool? pending,
  }) => LocalTripPoint(
    tripId: tripId ?? this.tripId,
    clientSeq: clientSeq ?? this.clientSeq,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    accuracyM: accuracyM.present ? accuracyM.value : this.accuracyM,
    speedKmh: speedKmh.present ? speedKmh.value : this.speedKmh,
    battery: battery.present ? battery.value : this.battery,
    recordedAt: recordedAt ?? this.recordedAt,
    pending: pending ?? this.pending,
  );
  LocalTripPoint copyWithCompanion(LocalTripPointsCompanion data) {
    return LocalTripPoint(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      clientSeq: data.clientSeq.present ? data.clientSeq.value : this.clientSeq,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      speedKmh: data.speedKmh.present ? data.speedKmh.value : this.speedKmh,
      battery: data.battery.present ? data.battery.value : this.battery,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      pending: data.pending.present ? data.pending.value : this.pending,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTripPoint(')
          ..write('tripId: $tripId, ')
          ..write('clientSeq: $clientSeq, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('battery: $battery, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('pending: $pending')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tripId,
    clientSeq,
    lat,
    lng,
    accuracyM,
    speedKmh,
    battery,
    recordedAt,
    pending,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTripPoint &&
          other.tripId == this.tripId &&
          other.clientSeq == this.clientSeq &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.accuracyM == this.accuracyM &&
          other.speedKmh == this.speedKmh &&
          other.battery == this.battery &&
          other.recordedAt == this.recordedAt &&
          other.pending == this.pending);
}

class LocalTripPointsCompanion extends UpdateCompanion<LocalTripPoint> {
  final Value<int> tripId;
  final Value<int> clientSeq;
  final Value<double> lat;
  final Value<double> lng;
  final Value<int?> accuracyM;
  final Value<int?> speedKmh;
  final Value<int?> battery;
  final Value<DateTime> recordedAt;
  final Value<bool> pending;
  final Value<int> rowid;
  const LocalTripPointsCompanion({
    this.tripId = const Value.absent(),
    this.clientSeq = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.speedKmh = const Value.absent(),
    this.battery = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.pending = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTripPointsCompanion.insert({
    required int tripId,
    required int clientSeq,
    required double lat,
    required double lng,
    this.accuracyM = const Value.absent(),
    this.speedKmh = const Value.absent(),
    this.battery = const Value.absent(),
    required DateTime recordedAt,
    this.pending = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       clientSeq = Value(clientSeq),
       lat = Value(lat),
       lng = Value(lng),
       recordedAt = Value(recordedAt);
  static Insertable<LocalTripPoint> custom({
    Expression<int>? tripId,
    Expression<int>? clientSeq,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<int>? accuracyM,
    Expression<int>? speedKmh,
    Expression<int>? battery,
    Expression<DateTime>? recordedAt,
    Expression<bool>? pending,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (clientSeq != null) 'client_seq': clientSeq,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      if (battery != null) 'battery': battery,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (pending != null) 'pending': pending,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTripPointsCompanion copyWith({
    Value<int>? tripId,
    Value<int>? clientSeq,
    Value<double>? lat,
    Value<double>? lng,
    Value<int?>? accuracyM,
    Value<int?>? speedKmh,
    Value<int?>? battery,
    Value<DateTime>? recordedAt,
    Value<bool>? pending,
    Value<int>? rowid,
  }) {
    return LocalTripPointsCompanion(
      tripId: tripId ?? this.tripId,
      clientSeq: clientSeq ?? this.clientSeq,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyM: accuracyM ?? this.accuracyM,
      speedKmh: speedKmh ?? this.speedKmh,
      battery: battery ?? this.battery,
      recordedAt: recordedAt ?? this.recordedAt,
      pending: pending ?? this.pending,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (clientSeq.present) {
      map['client_seq'] = Variable<int>(clientSeq.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<int>(accuracyM.value);
    }
    if (speedKmh.present) {
      map['speed_kmh'] = Variable<int>(speedKmh.value);
    }
    if (battery.present) {
      map['battery'] = Variable<int>(battery.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (pending.present) {
      map['pending'] = Variable<bool>(pending.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTripPointsCompanion(')
          ..write('tripId: $tripId, ')
          ..write('clientSeq: $clientSeq, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('speedKmh: $speedKmh, ')
          ..write('battery: $battery, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('pending: $pending, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTripEventsTable extends LocalTripEvents
    with TableInfo<$LocalTripEventsTable, LocalTripEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTripEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<int> tripId = GeneratedColumn<int>(
    'trip_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<int> actorId = GeneratedColumn<int>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tripId, seq, kind, actorId, meta, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_trip_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTripEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tripIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('meta')) {
      context.handle(
        _metaMeta,
        meta.isAcceptableOrUnknown(data['meta']!, _metaMeta),
      );
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tripId, seq};
  @override
  LocalTripEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTripEvent(
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trip_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actor_id'],
      ),
      meta: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meta'],
      ),
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $LocalTripEventsTable createAlias(String alias) {
    return $LocalTripEventsTable(attachedDatabase, alias);
  }
}

class LocalTripEvent extends DataClass implements Insertable<LocalTripEvent> {
  final int tripId;
  final int seq;
  final String kind;
  final int? actorId;

  /// JSON brut renvoyé par le serveur, décodé à l'affichage seulement.
  final String? meta;
  final DateTime at;
  const LocalTripEvent({
    required this.tripId,
    required this.seq,
    required this.kind,
    this.actorId,
    this.meta,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trip_id'] = Variable<int>(tripId);
    map['seq'] = Variable<int>(seq);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<int>(actorId);
    }
    if (!nullToAbsent || meta != null) {
      map['meta'] = Variable<String>(meta);
    }
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  LocalTripEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalTripEventsCompanion(
      tripId: Value(tripId),
      seq: Value(seq),
      kind: Value(kind),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      meta: meta == null && nullToAbsent ? const Value.absent() : Value(meta),
      at: Value(at),
    );
  }

  factory LocalTripEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTripEvent(
      tripId: serializer.fromJson<int>(json['tripId']),
      seq: serializer.fromJson<int>(json['seq']),
      kind: serializer.fromJson<String>(json['kind']),
      actorId: serializer.fromJson<int?>(json['actorId']),
      meta: serializer.fromJson<String?>(json['meta']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tripId': serializer.toJson<int>(tripId),
      'seq': serializer.toJson<int>(seq),
      'kind': serializer.toJson<String>(kind),
      'actorId': serializer.toJson<int?>(actorId),
      'meta': serializer.toJson<String?>(meta),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  LocalTripEvent copyWith({
    int? tripId,
    int? seq,
    String? kind,
    Value<int?> actorId = const Value.absent(),
    Value<String?> meta = const Value.absent(),
    DateTime? at,
  }) => LocalTripEvent(
    tripId: tripId ?? this.tripId,
    seq: seq ?? this.seq,
    kind: kind ?? this.kind,
    actorId: actorId.present ? actorId.value : this.actorId,
    meta: meta.present ? meta.value : this.meta,
    at: at ?? this.at,
  );
  LocalTripEvent copyWithCompanion(LocalTripEventsCompanion data) {
    return LocalTripEvent(
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      seq: data.seq.present ? data.seq.value : this.seq,
      kind: data.kind.present ? data.kind.value : this.kind,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      meta: data.meta.present ? data.meta.value : this.meta,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTripEvent(')
          ..write('tripId: $tripId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('actorId: $actorId, ')
          ..write('meta: $meta, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tripId, seq, kind, actorId, meta, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTripEvent &&
          other.tripId == this.tripId &&
          other.seq == this.seq &&
          other.kind == this.kind &&
          other.actorId == this.actorId &&
          other.meta == this.meta &&
          other.at == this.at);
}

class LocalTripEventsCompanion extends UpdateCompanion<LocalTripEvent> {
  final Value<int> tripId;
  final Value<int> seq;
  final Value<String> kind;
  final Value<int?> actorId;
  final Value<String?> meta;
  final Value<DateTime> at;
  final Value<int> rowid;
  const LocalTripEventsCompanion({
    this.tripId = const Value.absent(),
    this.seq = const Value.absent(),
    this.kind = const Value.absent(),
    this.actorId = const Value.absent(),
    this.meta = const Value.absent(),
    this.at = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalTripEventsCompanion.insert({
    required int tripId,
    required int seq,
    required String kind,
    this.actorId = const Value.absent(),
    this.meta = const Value.absent(),
    required DateTime at,
    this.rowid = const Value.absent(),
  }) : tripId = Value(tripId),
       seq = Value(seq),
       kind = Value(kind),
       at = Value(at);
  static Insertable<LocalTripEvent> custom({
    Expression<int>? tripId,
    Expression<int>? seq,
    Expression<String>? kind,
    Expression<int>? actorId,
    Expression<String>? meta,
    Expression<DateTime>? at,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tripId != null) 'trip_id': tripId,
      if (seq != null) 'seq': seq,
      if (kind != null) 'kind': kind,
      if (actorId != null) 'actor_id': actorId,
      if (meta != null) 'meta': meta,
      if (at != null) 'at': at,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalTripEventsCompanion copyWith({
    Value<int>? tripId,
    Value<int>? seq,
    Value<String>? kind,
    Value<int?>? actorId,
    Value<String?>? meta,
    Value<DateTime>? at,
    Value<int>? rowid,
  }) {
    return LocalTripEventsCompanion(
      tripId: tripId ?? this.tripId,
      seq: seq ?? this.seq,
      kind: kind ?? this.kind,
      actorId: actorId ?? this.actorId,
      meta: meta ?? this.meta,
      at: at ?? this.at,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tripId.present) {
      map['trip_id'] = Variable<int>(tripId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<int>(actorId.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTripEventsCompanion(')
          ..write('tripId: $tripId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('actorId: $actorId, ')
          ..write('meta: $meta, ')
          ..write('at: $at, ')
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
  late final $LocalUsersTable localUsers = $LocalUsersTable(this);
  late final $LocalCallsTable localCalls = $LocalCallsTable(this);
  late final $LocalMeetingsTable localMeetings = $LocalMeetingsTable(this);
  late final $LocalStatusesTable localStatuses = $LocalStatusesTable(this);
  late final $LocalMessageReactionsTable localMessageReactions =
      $LocalMessageReactionsTable(this);
  late final $LocalContactListsTable localContactLists =
      $LocalContactListsTable(this);
  late final $LocalContactListMembersTable localContactListMembers =
      $LocalContactListMembersTable(this);
  late final $LocalTripsTable localTrips = $LocalTripsTable(this);
  late final $LocalTripPointsTable localTripPoints = $LocalTripPointsTable(
    this,
  );
  late final $LocalTripEventsTable localTripEvents = $LocalTripEventsTable(
    this,
  );
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
    localMessageReactions,
    localContactLists,
    localContactListMembers,
    localTrips,
    localTripPoints,
    localTripEvents,
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
      Value<String?> description,
      Value<int?> createdBy,
      Value<DateTime?> metaUpdatedAt,
      Value<bool> onlyAdminsCanSend,
      Value<bool> onlyAdminsCanEditInfo,
      Value<bool> hideHistoryForNewMembers,
      Value<bool> onlyAdminsCanAddMembers,
      Value<int> myRole,
      Value<DateTime?> mutedUntil,
      Value<bool> muteForever,
      Value<bool> mentionsOnly,
      Value<int?> myPendingJoinMsgID,
      Value<DateTime?> myHistoryCutoffAt,
      Value<bool> hasUnreadMention,
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
      Value<String?> description,
      Value<int?> createdBy,
      Value<DateTime?> metaUpdatedAt,
      Value<bool> onlyAdminsCanSend,
      Value<bool> onlyAdminsCanEditInfo,
      Value<bool> hideHistoryForNewMembers,
      Value<bool> onlyAdminsCanAddMembers,
      Value<int> myRole,
      Value<DateTime?> mutedUntil,
      Value<bool> muteForever,
      Value<bool> mentionsOnly,
      Value<int?> myPendingJoinMsgID,
      Value<DateTime?> myHistoryCutoffAt,
      Value<bool> hasUnreadMention,
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get metaUpdatedAt => $composableBuilder(
    column: $table.metaUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlyAdminsCanSend => $composableBuilder(
    column: $table.onlyAdminsCanSend,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlyAdminsCanEditInfo => $composableBuilder(
    column: $table.onlyAdminsCanEditInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hideHistoryForNewMembers => $composableBuilder(
    column: $table.hideHistoryForNewMembers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onlyAdminsCanAddMembers => $composableBuilder(
    column: $table.onlyAdminsCanAddMembers,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get myRole => $composableBuilder(
    column: $table.myRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get mutedUntil => $composableBuilder(
    column: $table.mutedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muteForever => $composableBuilder(
    column: $table.muteForever,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mentionsOnly => $composableBuilder(
    column: $table.mentionsOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get myPendingJoinMsgID => $composableBuilder(
    column: $table.myPendingJoinMsgID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get myHistoryCutoffAt => $composableBuilder(
    column: $table.myHistoryCutoffAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasUnreadMention => $composableBuilder(
    column: $table.hasUnreadMention,
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get metaUpdatedAt => $composableBuilder(
    column: $table.metaUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlyAdminsCanSend => $composableBuilder(
    column: $table.onlyAdminsCanSend,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlyAdminsCanEditInfo => $composableBuilder(
    column: $table.onlyAdminsCanEditInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hideHistoryForNewMembers => $composableBuilder(
    column: $table.hideHistoryForNewMembers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onlyAdminsCanAddMembers => $composableBuilder(
    column: $table.onlyAdminsCanAddMembers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get myRole => $composableBuilder(
    column: $table.myRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get mutedUntil => $composableBuilder(
    column: $table.mutedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muteForever => $composableBuilder(
    column: $table.muteForever,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mentionsOnly => $composableBuilder(
    column: $table.mentionsOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get myPendingJoinMsgID => $composableBuilder(
    column: $table.myPendingJoinMsgID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get myHistoryCutoffAt => $composableBuilder(
    column: $table.myHistoryCutoffAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasUnreadMention => $composableBuilder(
    column: $table.hasUnreadMention,
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get metaUpdatedAt => $composableBuilder(
    column: $table.metaUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onlyAdminsCanSend => $composableBuilder(
    column: $table.onlyAdminsCanSend,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onlyAdminsCanEditInfo => $composableBuilder(
    column: $table.onlyAdminsCanEditInfo,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hideHistoryForNewMembers => $composableBuilder(
    column: $table.hideHistoryForNewMembers,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onlyAdminsCanAddMembers => $composableBuilder(
    column: $table.onlyAdminsCanAddMembers,
    builder: (column) => column,
  );

  GeneratedColumn<int> get myRole =>
      $composableBuilder(column: $table.myRole, builder: (column) => column);

  GeneratedColumn<DateTime> get mutedUntil => $composableBuilder(
    column: $table.mutedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get muteForever => $composableBuilder(
    column: $table.muteForever,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get mentionsOnly => $composableBuilder(
    column: $table.mentionsOnly,
    builder: (column) => column,
  );

  GeneratedColumn<int> get myPendingJoinMsgID => $composableBuilder(
    column: $table.myPendingJoinMsgID,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get myHistoryCutoffAt => $composableBuilder(
    column: $table.myHistoryCutoffAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasUnreadMention => $composableBuilder(
    column: $table.hasUnreadMention,
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
                Value<String?> description = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<DateTime?> metaUpdatedAt = const Value.absent(),
                Value<bool> onlyAdminsCanSend = const Value.absent(),
                Value<bool> onlyAdminsCanEditInfo = const Value.absent(),
                Value<bool> hideHistoryForNewMembers = const Value.absent(),
                Value<bool> onlyAdminsCanAddMembers = const Value.absent(),
                Value<int> myRole = const Value.absent(),
                Value<DateTime?> mutedUntil = const Value.absent(),
                Value<bool> muteForever = const Value.absent(),
                Value<bool> mentionsOnly = const Value.absent(),
                Value<int?> myPendingJoinMsgID = const Value.absent(),
                Value<DateTime?> myHistoryCutoffAt = const Value.absent(),
                Value<bool> hasUnreadMention = const Value.absent(),
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
                description: description,
                createdBy: createdBy,
                metaUpdatedAt: metaUpdatedAt,
                onlyAdminsCanSend: onlyAdminsCanSend,
                onlyAdminsCanEditInfo: onlyAdminsCanEditInfo,
                hideHistoryForNewMembers: hideHistoryForNewMembers,
                onlyAdminsCanAddMembers: onlyAdminsCanAddMembers,
                myRole: myRole,
                mutedUntil: mutedUntil,
                muteForever: muteForever,
                mentionsOnly: mentionsOnly,
                myPendingJoinMsgID: myPendingJoinMsgID,
                myHistoryCutoffAt: myHistoryCutoffAt,
                hasUnreadMention: hasUnreadMention,
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
                Value<String?> description = const Value.absent(),
                Value<int?> createdBy = const Value.absent(),
                Value<DateTime?> metaUpdatedAt = const Value.absent(),
                Value<bool> onlyAdminsCanSend = const Value.absent(),
                Value<bool> onlyAdminsCanEditInfo = const Value.absent(),
                Value<bool> hideHistoryForNewMembers = const Value.absent(),
                Value<bool> onlyAdminsCanAddMembers = const Value.absent(),
                Value<int> myRole = const Value.absent(),
                Value<DateTime?> mutedUntil = const Value.absent(),
                Value<bool> muteForever = const Value.absent(),
                Value<bool> mentionsOnly = const Value.absent(),
                Value<int?> myPendingJoinMsgID = const Value.absent(),
                Value<DateTime?> myHistoryCutoffAt = const Value.absent(),
                Value<bool> hasUnreadMention = const Value.absent(),
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
                description: description,
                createdBy: createdBy,
                metaUpdatedAt: metaUpdatedAt,
                onlyAdminsCanSend: onlyAdminsCanSend,
                onlyAdminsCanEditInfo: onlyAdminsCanEditInfo,
                hideHistoryForNewMembers: hideHistoryForNewMembers,
                onlyAdminsCanAddMembers: onlyAdminsCanAddMembers,
                myRole: myRole,
                mutedUntil: mutedUntil,
                muteForever: muteForever,
                mentionsOnly: mentionsOnly,
                myPendingJoinMsgID: myPendingJoinMsgID,
                myHistoryCutoffAt: myHistoryCutoffAt,
                hasUnreadMention: hasUnreadMention,
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
      Value<int?> mediaSize,
      Value<int?> mediaPageCount,
      Value<String?> mediaThumb,
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
      Value<DateTime?> clickSentAt,
      Value<String?> messageTz,
      Value<int?> messageTzOffset,
      Value<String?> senderNom,
      Value<String?> senderPseudo,
      Value<String?> senderAvatar,
      Value<bool> syncPending,
      Value<DateTime?> lastEmittedAt,
      Value<int> retryCount,
      Value<String?> failureCode,
      Value<String?> mentionsJson,
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
      Value<int?> mediaSize,
      Value<int?> mediaPageCount,
      Value<String?> mediaThumb,
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
      Value<DateTime?> clickSentAt,
      Value<String?> messageTz,
      Value<int?> messageTzOffset,
      Value<String?> senderNom,
      Value<String?> senderPseudo,
      Value<String?> senderAvatar,
      Value<bool> syncPending,
      Value<DateTime?> lastEmittedAt,
      Value<int> retryCount,
      Value<String?> failureCode,
      Value<String?> mentionsJson,
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

  ColumnFilters<int> get mediaSize => $composableBuilder(
    column: $table.mediaSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaPageCount => $composableBuilder(
    column: $table.mediaPageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaThumb => $composableBuilder(
    column: $table.mediaThumb,
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

  ColumnFilters<DateTime> get clickSentAt => $composableBuilder(
    column: $table.clickSentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageTz => $composableBuilder(
    column: $table.messageTz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageTzOffset => $composableBuilder(
    column: $table.messageTzOffset,
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

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mentionsJson => $composableBuilder(
    column: $table.mentionsJson,
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

  ColumnOrderings<int> get mediaSize => $composableBuilder(
    column: $table.mediaSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaPageCount => $composableBuilder(
    column: $table.mediaPageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaThumb => $composableBuilder(
    column: $table.mediaThumb,
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

  ColumnOrderings<DateTime> get clickSentAt => $composableBuilder(
    column: $table.clickSentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageTz => $composableBuilder(
    column: $table.messageTz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageTzOffset => $composableBuilder(
    column: $table.messageTzOffset,
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

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mentionsJson => $composableBuilder(
    column: $table.mentionsJson,
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

  GeneratedColumn<int> get mediaSize =>
      $composableBuilder(column: $table.mediaSize, builder: (column) => column);

  GeneratedColumn<int> get mediaPageCount => $composableBuilder(
    column: $table.mediaPageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaThumb => $composableBuilder(
    column: $table.mediaThumb,
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

  GeneratedColumn<DateTime> get clickSentAt => $composableBuilder(
    column: $table.clickSentAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageTz =>
      $composableBuilder(column: $table.messageTz, builder: (column) => column);

  GeneratedColumn<int> get messageTzOffset => $composableBuilder(
    column: $table.messageTzOffset,
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

  GeneratedColumn<DateTime> get lastEmittedAt => $composableBuilder(
    column: $table.lastEmittedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mentionsJson => $composableBuilder(
    column: $table.mentionsJson,
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
                Value<int?> mediaSize = const Value.absent(),
                Value<int?> mediaPageCount = const Value.absent(),
                Value<String?> mediaThumb = const Value.absent(),
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
                Value<DateTime?> clickSentAt = const Value.absent(),
                Value<String?> messageTz = const Value.absent(),
                Value<int?> messageTzOffset = const Value.absent(),
                Value<String?> senderNom = const Value.absent(),
                Value<String?> senderPseudo = const Value.absent(),
                Value<String?> senderAvatar = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<DateTime?> lastEmittedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> mentionsJson = const Value.absent(),
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
                mediaSize: mediaSize,
                mediaPageCount: mediaPageCount,
                mediaThumb: mediaThumb,
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
                clickSentAt: clickSentAt,
                messageTz: messageTz,
                messageTzOffset: messageTzOffset,
                senderNom: senderNom,
                senderPseudo: senderPseudo,
                senderAvatar: senderAvatar,
                syncPending: syncPending,
                lastEmittedAt: lastEmittedAt,
                retryCount: retryCount,
                failureCode: failureCode,
                mentionsJson: mentionsJson,
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
                Value<int?> mediaSize = const Value.absent(),
                Value<int?> mediaPageCount = const Value.absent(),
                Value<String?> mediaThumb = const Value.absent(),
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
                Value<DateTime?> clickSentAt = const Value.absent(),
                Value<String?> messageTz = const Value.absent(),
                Value<int?> messageTzOffset = const Value.absent(),
                Value<String?> senderNom = const Value.absent(),
                Value<String?> senderPseudo = const Value.absent(),
                Value<String?> senderAvatar = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<DateTime?> lastEmittedAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> mentionsJson = const Value.absent(),
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
                mediaSize: mediaSize,
                mediaPageCount: mediaPageCount,
                mediaThumb: mediaThumb,
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
                clickSentAt: clickSentAt,
                messageTz: messageTz,
                messageTzOffset: messageTzOffset,
                senderNom: senderNom,
                senderPseudo: senderPseudo,
                senderAvatar: senderAvatar,
                syncPending: syncPending,
                lastEmittedAt: lastEmittedAt,
                retryCount: retryCount,
                failureCode: failureCode,
                mentionsJson: mentionsJson,
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
      Value<bool> addedViaQr,
      Value<DateTime?> preferredAddedAt,
      Value<String?> preferredNote,
      Value<int> typeCompte,
      Value<int> accountType,
      Value<int> verificationStatus,
      Value<DateTime?> verifiedUntil,
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
      Value<bool> addedViaQr,
      Value<DateTime?> preferredAddedAt,
      Value<String?> preferredNote,
      Value<int> typeCompte,
      Value<int> accountType,
      Value<int> verificationStatus,
      Value<DateTime?> verifiedUntil,
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

  ColumnFilters<bool> get addedViaQr => $composableBuilder(
    column: $table.addedViaQr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get preferredAddedAt => $composableBuilder(
    column: $table.preferredAddedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredNote => $composableBuilder(
    column: $table.preferredNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeCompte => $composableBuilder(
    column: $table.typeCompte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get verifiedUntil => $composableBuilder(
    column: $table.verifiedUntil,
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

  ColumnOrderings<bool> get addedViaQr => $composableBuilder(
    column: $table.addedViaQr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get preferredAddedAt => $composableBuilder(
    column: $table.preferredAddedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredNote => $composableBuilder(
    column: $table.preferredNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeCompte => $composableBuilder(
    column: $table.typeCompte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get verifiedUntil => $composableBuilder(
    column: $table.verifiedUntil,
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

  GeneratedColumn<bool> get addedViaQr => $composableBuilder(
    column: $table.addedViaQr,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get preferredAddedAt => $composableBuilder(
    column: $table.preferredAddedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredNote => $composableBuilder(
    column: $table.preferredNote,
    builder: (column) => column,
  );

  GeneratedColumn<int> get typeCompte => $composableBuilder(
    column: $table.typeCompte,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get verifiedUntil => $composableBuilder(
    column: $table.verifiedUntil,
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
                Value<bool> addedViaQr = const Value.absent(),
                Value<DateTime?> preferredAddedAt = const Value.absent(),
                Value<String?> preferredNote = const Value.absent(),
                Value<int> typeCompte = const Value.absent(),
                Value<int> accountType = const Value.absent(),
                Value<int> verificationStatus = const Value.absent(),
                Value<DateTime?> verifiedUntil = const Value.absent(),
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
                addedViaQr: addedViaQr,
                preferredAddedAt: preferredAddedAt,
                preferredNote: preferredNote,
                typeCompte: typeCompte,
                accountType: accountType,
                verificationStatus: verificationStatus,
                verifiedUntil: verifiedUntil,
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
                Value<bool> addedViaQr = const Value.absent(),
                Value<DateTime?> preferredAddedAt = const Value.absent(),
                Value<String?> preferredNote = const Value.absent(),
                Value<int> typeCompte = const Value.absent(),
                Value<int> accountType = const Value.absent(),
                Value<int> verificationStatus = const Value.absent(),
                Value<DateTime?> verifiedUntil = const Value.absent(),
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
                addedViaQr: addedViaQr,
                preferredAddedAt: preferredAddedAt,
                preferredNote: preferredNote,
                typeCompte: typeCompte,
                accountType: accountType,
                verificationStatus: verificationStatus,
                verifiedUntil: verifiedUntil,
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
typedef $$LocalMessageReactionsTableCreateCompanionBuilder =
    LocalMessageReactionsCompanion Function({
      required int msgID,
      required int userID,
      required int conversationID,
      required String emoji,
      Value<DateTime> reactedAt,
      Value<int> rowid,
    });
typedef $$LocalMessageReactionsTableUpdateCompanionBuilder =
    LocalMessageReactionsCompanion Function({
      Value<int> msgID,
      Value<int> userID,
      Value<int> conversationID,
      Value<String> emoji,
      Value<DateTime> reactedAt,
      Value<int> rowid,
    });

class $$LocalMessageReactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessageReactionsTable> {
  $$LocalMessageReactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get msgID => $composableBuilder(
    column: $table.msgID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userID => $composableBuilder(
    column: $table.userID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get conversationID => $composableBuilder(
    column: $table.conversationID,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reactedAt => $composableBuilder(
    column: $table.reactedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMessageReactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessageReactionsTable> {
  $$LocalMessageReactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get msgID => $composableBuilder(
    column: $table.msgID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userID => $composableBuilder(
    column: $table.userID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get conversationID => $composableBuilder(
    column: $table.conversationID,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reactedAt => $composableBuilder(
    column: $table.reactedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMessageReactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessageReactionsTable> {
  $$LocalMessageReactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get msgID =>
      $composableBuilder(column: $table.msgID, builder: (column) => column);

  GeneratedColumn<int> get userID =>
      $composableBuilder(column: $table.userID, builder: (column) => column);

  GeneratedColumn<int> get conversationID => $composableBuilder(
    column: $table.conversationID,
    builder: (column) => column,
  );

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<DateTime> get reactedAt =>
      $composableBuilder(column: $table.reactedAt, builder: (column) => column);
}

class $$LocalMessageReactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMessageReactionsTable,
          LocalMessageReaction,
          $$LocalMessageReactionsTableFilterComposer,
          $$LocalMessageReactionsTableOrderingComposer,
          $$LocalMessageReactionsTableAnnotationComposer,
          $$LocalMessageReactionsTableCreateCompanionBuilder,
          $$LocalMessageReactionsTableUpdateCompanionBuilder,
          (
            LocalMessageReaction,
            BaseReferences<
              _$AppDatabase,
              $LocalMessageReactionsTable,
              LocalMessageReaction
            >,
          ),
          LocalMessageReaction,
          PrefetchHooks Function()
        > {
  $$LocalMessageReactionsTableTableManager(
    _$AppDatabase db,
    $LocalMessageReactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessageReactionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalMessageReactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalMessageReactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> msgID = const Value.absent(),
                Value<int> userID = const Value.absent(),
                Value<int> conversationID = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<DateTime> reactedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessageReactionsCompanion(
                msgID: msgID,
                userID: userID,
                conversationID: conversationID,
                emoji: emoji,
                reactedAt: reactedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int msgID,
                required int userID,
                required int conversationID,
                required String emoji,
                Value<DateTime> reactedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessageReactionsCompanion.insert(
                msgID: msgID,
                userID: userID,
                conversationID: conversationID,
                emoji: emoji,
                reactedAt: reactedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMessageReactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMessageReactionsTable,
      LocalMessageReaction,
      $$LocalMessageReactionsTableFilterComposer,
      $$LocalMessageReactionsTableOrderingComposer,
      $$LocalMessageReactionsTableAnnotationComposer,
      $$LocalMessageReactionsTableCreateCompanionBuilder,
      $$LocalMessageReactionsTableUpdateCompanionBuilder,
      (
        LocalMessageReaction,
        BaseReferences<
          _$AppDatabase,
          $LocalMessageReactionsTable,
          LocalMessageReaction
        >,
      ),
      LocalMessageReaction,
      PrefetchHooks Function()
    >;
typedef $$LocalContactListsTableCreateCompanionBuilder =
    LocalContactListsCompanion Function({
      Value<int> idList,
      Value<String> name,
      Value<String?> kind,
      Value<String?> color,
      Value<int?> memberLimit,
      Value<int> memberCount,
      required DateTime cachedAt,
    });
typedef $$LocalContactListsTableUpdateCompanionBuilder =
    LocalContactListsCompanion Function({
      Value<int> idList,
      Value<String> name,
      Value<String?> kind,
      Value<String?> color,
      Value<int?> memberLimit,
      Value<int> memberCount,
      Value<DateTime> cachedAt,
    });

class $$LocalContactListsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContactListsTable> {
  $$LocalContactListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get idList => $composableBuilder(
    column: $table.idList,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memberLimit => $composableBuilder(
    column: $table.memberLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContactListsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContactListsTable> {
  $$LocalContactListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get idList => $composableBuilder(
    column: $table.idList,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memberLimit => $composableBuilder(
    column: $table.memberLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContactListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContactListsTable> {
  $$LocalContactListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get idList =>
      $composableBuilder(column: $table.idList, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get memberLimit => $composableBuilder(
    column: $table.memberLimit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$LocalContactListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContactListsTable,
          LocalContactList,
          $$LocalContactListsTableFilterComposer,
          $$LocalContactListsTableOrderingComposer,
          $$LocalContactListsTableAnnotationComposer,
          $$LocalContactListsTableCreateCompanionBuilder,
          $$LocalContactListsTableUpdateCompanionBuilder,
          (
            LocalContactList,
            BaseReferences<
              _$AppDatabase,
              $LocalContactListsTable,
              LocalContactList
            >,
          ),
          LocalContactList,
          PrefetchHooks Function()
        > {
  $$LocalContactListsTableTableManager(
    _$AppDatabase db,
    $LocalContactListsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContactListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContactListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalContactListsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> idList = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int?> memberLimit = const Value.absent(),
                Value<int> memberCount = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => LocalContactListsCompanion(
                idList: idList,
                name: name,
                kind: kind,
                color: color,
                memberLimit: memberLimit,
                memberCount: memberCount,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> idList = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<int?> memberLimit = const Value.absent(),
                Value<int> memberCount = const Value.absent(),
                required DateTime cachedAt,
              }) => LocalContactListsCompanion.insert(
                idList: idList,
                name: name,
                kind: kind,
                color: color,
                memberLimit: memberLimit,
                memberCount: memberCount,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContactListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContactListsTable,
      LocalContactList,
      $$LocalContactListsTableFilterComposer,
      $$LocalContactListsTableOrderingComposer,
      $$LocalContactListsTableAnnotationComposer,
      $$LocalContactListsTableCreateCompanionBuilder,
      $$LocalContactListsTableUpdateCompanionBuilder,
      (
        LocalContactList,
        BaseReferences<
          _$AppDatabase,
          $LocalContactListsTable,
          LocalContactList
        >,
      ),
      LocalContactList,
      PrefetchHooks Function()
    >;
typedef $$LocalContactListMembersTableCreateCompanionBuilder =
    LocalContactListMembersCompanion Function({
      required int idList,
      required int idFriend,
      Value<int> rowid,
    });
typedef $$LocalContactListMembersTableUpdateCompanionBuilder =
    LocalContactListMembersCompanion Function({
      Value<int> idList,
      Value<int> idFriend,
      Value<int> rowid,
    });

class $$LocalContactListMembersTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContactListMembersTable> {
  $$LocalContactListMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get idList => $composableBuilder(
    column: $table.idList,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get idFriend => $composableBuilder(
    column: $table.idFriend,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContactListMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContactListMembersTable> {
  $$LocalContactListMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get idList => $composableBuilder(
    column: $table.idList,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get idFriend => $composableBuilder(
    column: $table.idFriend,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContactListMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContactListMembersTable> {
  $$LocalContactListMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get idList =>
      $composableBuilder(column: $table.idList, builder: (column) => column);

  GeneratedColumn<int> get idFriend =>
      $composableBuilder(column: $table.idFriend, builder: (column) => column);
}

class $$LocalContactListMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContactListMembersTable,
          LocalContactListMember,
          $$LocalContactListMembersTableFilterComposer,
          $$LocalContactListMembersTableOrderingComposer,
          $$LocalContactListMembersTableAnnotationComposer,
          $$LocalContactListMembersTableCreateCompanionBuilder,
          $$LocalContactListMembersTableUpdateCompanionBuilder,
          (
            LocalContactListMember,
            BaseReferences<
              _$AppDatabase,
              $LocalContactListMembersTable,
              LocalContactListMember
            >,
          ),
          LocalContactListMember,
          PrefetchHooks Function()
        > {
  $$LocalContactListMembersTableTableManager(
    _$AppDatabase db,
    $LocalContactListMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContactListMembersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LocalContactListMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalContactListMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> idList = const Value.absent(),
                Value<int> idFriend = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContactListMembersCompanion(
                idList: idList,
                idFriend: idFriend,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int idList,
                required int idFriend,
                Value<int> rowid = const Value.absent(),
              }) => LocalContactListMembersCompanion.insert(
                idList: idList,
                idFriend: idFriend,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContactListMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContactListMembersTable,
      LocalContactListMember,
      $$LocalContactListMembersTableFilterComposer,
      $$LocalContactListMembersTableOrderingComposer,
      $$LocalContactListMembersTableAnnotationComposer,
      $$LocalContactListMembersTableCreateCompanionBuilder,
      $$LocalContactListMembersTableUpdateCompanionBuilder,
      (
        LocalContactListMember,
        BaseReferences<
          _$AppDatabase,
          $LocalContactListMembersTable,
          LocalContactListMember
        >,
      ),
      LocalContactListMember,
      PrefetchHooks Function()
    >;
typedef $$LocalTripsTableCreateCompanionBuilder =
    LocalTripsCompanion Function({
      Value<int> id,
      required int ownerId,
      Value<String> kind,
      Value<String> state,
      Value<DateTime?> etaAt,
      Value<int> graceMinutes,
      Value<int> extensions,
      Value<String?> note,
      Value<String?> destLabel,
      Value<double?> destLat,
      Value<double?> destLng,
      Value<int?> destRadiusM,
      Value<double?> lastLat,
      Value<double?> lastLng,
      Value<int?> lastAccuracyM,
      Value<int?> lastBattery,
      Value<DateTime?> lastAt,
      Value<bool> stale,
      required DateTime startedAt,
      Value<DateTime?> closedAt,
      Value<String?> closeReason,
      Value<bool> isOwner,
      Value<int> watcherCount,
      required DateTime cachedAt,
    });
typedef $$LocalTripsTableUpdateCompanionBuilder =
    LocalTripsCompanion Function({
      Value<int> id,
      Value<int> ownerId,
      Value<String> kind,
      Value<String> state,
      Value<DateTime?> etaAt,
      Value<int> graceMinutes,
      Value<int> extensions,
      Value<String?> note,
      Value<String?> destLabel,
      Value<double?> destLat,
      Value<double?> destLng,
      Value<int?> destRadiusM,
      Value<double?> lastLat,
      Value<double?> lastLng,
      Value<int?> lastAccuracyM,
      Value<int?> lastBattery,
      Value<DateTime?> lastAt,
      Value<bool> stale,
      Value<DateTime> startedAt,
      Value<DateTime?> closedAt,
      Value<String?> closeReason,
      Value<bool> isOwner,
      Value<int> watcherCount,
      Value<DateTime> cachedAt,
    });

class $$LocalTripsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTripsTable> {
  $$LocalTripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get etaAt => $composableBuilder(
    column: $table.etaAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get extensions => $composableBuilder(
    column: $table.extensions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destLabel => $composableBuilder(
    column: $table.destLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get destLat => $composableBuilder(
    column: $table.destLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get destLng => $composableBuilder(
    column: $table.destLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get destRadiusM => $composableBuilder(
    column: $table.destRadiusM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastLat => $composableBuilder(
    column: $table.lastLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastLng => $composableBuilder(
    column: $table.lastLng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccuracyM => $composableBuilder(
    column: $table.lastAccuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastBattery => $composableBuilder(
    column: $table.lastBattery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAt => $composableBuilder(
    column: $table.lastAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get stale => $composableBuilder(
    column: $table.stale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closeReason => $composableBuilder(
    column: $table.closeReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOwner => $composableBuilder(
    column: $table.isOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watcherCount => $composableBuilder(
    column: $table.watcherCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTripsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTripsTable> {
  $$LocalTripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get etaAt => $composableBuilder(
    column: $table.etaAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get extensions => $composableBuilder(
    column: $table.extensions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destLabel => $composableBuilder(
    column: $table.destLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get destLat => $composableBuilder(
    column: $table.destLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get destLng => $composableBuilder(
    column: $table.destLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get destRadiusM => $composableBuilder(
    column: $table.destRadiusM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastLat => $composableBuilder(
    column: $table.lastLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastLng => $composableBuilder(
    column: $table.lastLng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccuracyM => $composableBuilder(
    column: $table.lastAccuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastBattery => $composableBuilder(
    column: $table.lastBattery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAt => $composableBuilder(
    column: $table.lastAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get stale => $composableBuilder(
    column: $table.stale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closeReason => $composableBuilder(
    column: $table.closeReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOwner => $composableBuilder(
    column: $table.isOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watcherCount => $composableBuilder(
    column: $table.watcherCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTripsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTripsTable> {
  $$LocalTripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get etaAt =>
      $composableBuilder(column: $table.etaAt, builder: (column) => column);

  GeneratedColumn<int> get graceMinutes => $composableBuilder(
    column: $table.graceMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get extensions => $composableBuilder(
    column: $table.extensions,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get destLabel =>
      $composableBuilder(column: $table.destLabel, builder: (column) => column);

  GeneratedColumn<double> get destLat =>
      $composableBuilder(column: $table.destLat, builder: (column) => column);

  GeneratedColumn<double> get destLng =>
      $composableBuilder(column: $table.destLng, builder: (column) => column);

  GeneratedColumn<int> get destRadiusM => $composableBuilder(
    column: $table.destRadiusM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lastLat =>
      $composableBuilder(column: $table.lastLat, builder: (column) => column);

  GeneratedColumn<double> get lastLng =>
      $composableBuilder(column: $table.lastLng, builder: (column) => column);

  GeneratedColumn<int> get lastAccuracyM => $composableBuilder(
    column: $table.lastAccuracyM,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastBattery => $composableBuilder(
    column: $table.lastBattery,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastAt =>
      $composableBuilder(column: $table.lastAt, builder: (column) => column);

  GeneratedColumn<bool> get stale =>
      $composableBuilder(column: $table.stale, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  GeneratedColumn<String> get closeReason => $composableBuilder(
    column: $table.closeReason,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOwner =>
      $composableBuilder(column: $table.isOwner, builder: (column) => column);

  GeneratedColumn<int> get watcherCount => $composableBuilder(
    column: $table.watcherCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$LocalTripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTripsTable,
          LocalTrip,
          $$LocalTripsTableFilterComposer,
          $$LocalTripsTableOrderingComposer,
          $$LocalTripsTableAnnotationComposer,
          $$LocalTripsTableCreateCompanionBuilder,
          $$LocalTripsTableUpdateCompanionBuilder,
          (
            LocalTrip,
            BaseReferences<_$AppDatabase, $LocalTripsTable, LocalTrip>,
          ),
          LocalTrip,
          PrefetchHooks Function()
        > {
  $$LocalTripsTableTableManager(_$AppDatabase db, $LocalTripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ownerId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime?> etaAt = const Value.absent(),
                Value<int> graceMinutes = const Value.absent(),
                Value<int> extensions = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> destLabel = const Value.absent(),
                Value<double?> destLat = const Value.absent(),
                Value<double?> destLng = const Value.absent(),
                Value<int?> destRadiusM = const Value.absent(),
                Value<double?> lastLat = const Value.absent(),
                Value<double?> lastLng = const Value.absent(),
                Value<int?> lastAccuracyM = const Value.absent(),
                Value<int?> lastBattery = const Value.absent(),
                Value<DateTime?> lastAt = const Value.absent(),
                Value<bool> stale = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> closedAt = const Value.absent(),
                Value<String?> closeReason = const Value.absent(),
                Value<bool> isOwner = const Value.absent(),
                Value<int> watcherCount = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => LocalTripsCompanion(
                id: id,
                ownerId: ownerId,
                kind: kind,
                state: state,
                etaAt: etaAt,
                graceMinutes: graceMinutes,
                extensions: extensions,
                note: note,
                destLabel: destLabel,
                destLat: destLat,
                destLng: destLng,
                destRadiusM: destRadiusM,
                lastLat: lastLat,
                lastLng: lastLng,
                lastAccuracyM: lastAccuracyM,
                lastBattery: lastBattery,
                lastAt: lastAt,
                stale: stale,
                startedAt: startedAt,
                closedAt: closedAt,
                closeReason: closeReason,
                isOwner: isOwner,
                watcherCount: watcherCount,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ownerId,
                Value<String> kind = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime?> etaAt = const Value.absent(),
                Value<int> graceMinutes = const Value.absent(),
                Value<int> extensions = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> destLabel = const Value.absent(),
                Value<double?> destLat = const Value.absent(),
                Value<double?> destLng = const Value.absent(),
                Value<int?> destRadiusM = const Value.absent(),
                Value<double?> lastLat = const Value.absent(),
                Value<double?> lastLng = const Value.absent(),
                Value<int?> lastAccuracyM = const Value.absent(),
                Value<int?> lastBattery = const Value.absent(),
                Value<DateTime?> lastAt = const Value.absent(),
                Value<bool> stale = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> closedAt = const Value.absent(),
                Value<String?> closeReason = const Value.absent(),
                Value<bool> isOwner = const Value.absent(),
                Value<int> watcherCount = const Value.absent(),
                required DateTime cachedAt,
              }) => LocalTripsCompanion.insert(
                id: id,
                ownerId: ownerId,
                kind: kind,
                state: state,
                etaAt: etaAt,
                graceMinutes: graceMinutes,
                extensions: extensions,
                note: note,
                destLabel: destLabel,
                destLat: destLat,
                destLng: destLng,
                destRadiusM: destRadiusM,
                lastLat: lastLat,
                lastLng: lastLng,
                lastAccuracyM: lastAccuracyM,
                lastBattery: lastBattery,
                lastAt: lastAt,
                stale: stale,
                startedAt: startedAt,
                closedAt: closedAt,
                closeReason: closeReason,
                isOwner: isOwner,
                watcherCount: watcherCount,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTripsTable,
      LocalTrip,
      $$LocalTripsTableFilterComposer,
      $$LocalTripsTableOrderingComposer,
      $$LocalTripsTableAnnotationComposer,
      $$LocalTripsTableCreateCompanionBuilder,
      $$LocalTripsTableUpdateCompanionBuilder,
      (LocalTrip, BaseReferences<_$AppDatabase, $LocalTripsTable, LocalTrip>),
      LocalTrip,
      PrefetchHooks Function()
    >;
typedef $$LocalTripPointsTableCreateCompanionBuilder =
    LocalTripPointsCompanion Function({
      required int tripId,
      required int clientSeq,
      required double lat,
      required double lng,
      Value<int?> accuracyM,
      Value<int?> speedKmh,
      Value<int?> battery,
      required DateTime recordedAt,
      Value<bool> pending,
      Value<int> rowid,
    });
typedef $$LocalTripPointsTableUpdateCompanionBuilder =
    LocalTripPointsCompanion Function({
      Value<int> tripId,
      Value<int> clientSeq,
      Value<double> lat,
      Value<double> lng,
      Value<int?> accuracyM,
      Value<int?> speedKmh,
      Value<int?> battery,
      Value<DateTime> recordedAt,
      Value<bool> pending,
      Value<int> rowid,
    });

class $$LocalTripPointsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTripPointsTable> {
  $$LocalTripPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clientSeq => $composableBuilder(
    column: $table.clientSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get battery => $composableBuilder(
    column: $table.battery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTripPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTripPointsTable> {
  $$LocalTripPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clientSeq => $composableBuilder(
    column: $table.clientSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get speedKmh => $composableBuilder(
    column: $table.speedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get battery => $composableBuilder(
    column: $table.battery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pending => $composableBuilder(
    column: $table.pending,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTripPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTripPointsTable> {
  $$LocalTripPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<int> get clientSeq =>
      $composableBuilder(column: $table.clientSeq, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<int> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<int> get speedKmh =>
      $composableBuilder(column: $table.speedKmh, builder: (column) => column);

  GeneratedColumn<int> get battery =>
      $composableBuilder(column: $table.battery, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pending =>
      $composableBuilder(column: $table.pending, builder: (column) => column);
}

class $$LocalTripPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTripPointsTable,
          LocalTripPoint,
          $$LocalTripPointsTableFilterComposer,
          $$LocalTripPointsTableOrderingComposer,
          $$LocalTripPointsTableAnnotationComposer,
          $$LocalTripPointsTableCreateCompanionBuilder,
          $$LocalTripPointsTableUpdateCompanionBuilder,
          (
            LocalTripPoint,
            BaseReferences<
              _$AppDatabase,
              $LocalTripPointsTable,
              LocalTripPoint
            >,
          ),
          LocalTripPoint,
          PrefetchHooks Function()
        > {
  $$LocalTripPointsTableTableManager(
    _$AppDatabase db,
    $LocalTripPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTripPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTripPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTripPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tripId = const Value.absent(),
                Value<int> clientSeq = const Value.absent(),
                Value<double> lat = const Value.absent(),
                Value<double> lng = const Value.absent(),
                Value<int?> accuracyM = const Value.absent(),
                Value<int?> speedKmh = const Value.absent(),
                Value<int?> battery = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<bool> pending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTripPointsCompanion(
                tripId: tripId,
                clientSeq: clientSeq,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                speedKmh: speedKmh,
                battery: battery,
                recordedAt: recordedAt,
                pending: pending,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tripId,
                required int clientSeq,
                required double lat,
                required double lng,
                Value<int?> accuracyM = const Value.absent(),
                Value<int?> speedKmh = const Value.absent(),
                Value<int?> battery = const Value.absent(),
                required DateTime recordedAt,
                Value<bool> pending = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTripPointsCompanion.insert(
                tripId: tripId,
                clientSeq: clientSeq,
                lat: lat,
                lng: lng,
                accuracyM: accuracyM,
                speedKmh: speedKmh,
                battery: battery,
                recordedAt: recordedAt,
                pending: pending,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTripPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTripPointsTable,
      LocalTripPoint,
      $$LocalTripPointsTableFilterComposer,
      $$LocalTripPointsTableOrderingComposer,
      $$LocalTripPointsTableAnnotationComposer,
      $$LocalTripPointsTableCreateCompanionBuilder,
      $$LocalTripPointsTableUpdateCompanionBuilder,
      (
        LocalTripPoint,
        BaseReferences<_$AppDatabase, $LocalTripPointsTable, LocalTripPoint>,
      ),
      LocalTripPoint,
      PrefetchHooks Function()
    >;
typedef $$LocalTripEventsTableCreateCompanionBuilder =
    LocalTripEventsCompanion Function({
      required int tripId,
      required int seq,
      required String kind,
      Value<int?> actorId,
      Value<String?> meta,
      required DateTime at,
      Value<int> rowid,
    });
typedef $$LocalTripEventsTableUpdateCompanionBuilder =
    LocalTripEventsCompanion Function({
      Value<int> tripId,
      Value<int> seq,
      Value<String> kind,
      Value<int?> actorId,
      Value<String?> meta,
      Value<DateTime> at,
      Value<int> rowid,
    });

class $$LocalTripEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalTripEventsTable> {
  $$LocalTripEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalTripEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalTripEventsTable> {
  $$LocalTripEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meta => $composableBuilder(
    column: $table.meta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalTripEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalTripEventsTable> {
  $$LocalTripEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$LocalTripEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalTripEventsTable,
          LocalTripEvent,
          $$LocalTripEventsTableFilterComposer,
          $$LocalTripEventsTableOrderingComposer,
          $$LocalTripEventsTableAnnotationComposer,
          $$LocalTripEventsTableCreateCompanionBuilder,
          $$LocalTripEventsTableUpdateCompanionBuilder,
          (
            LocalTripEvent,
            BaseReferences<
              _$AppDatabase,
              $LocalTripEventsTable,
              LocalTripEvent
            >,
          ),
          LocalTripEvent,
          PrefetchHooks Function()
        > {
  $$LocalTripEventsTableTableManager(
    _$AppDatabase db,
    $LocalTripEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTripEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTripEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTripEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tripId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> actorId = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalTripEventsCompanion(
                tripId: tripId,
                seq: seq,
                kind: kind,
                actorId: actorId,
                meta: meta,
                at: at,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tripId,
                required int seq,
                required String kind,
                Value<int?> actorId = const Value.absent(),
                Value<String?> meta = const Value.absent(),
                required DateTime at,
                Value<int> rowid = const Value.absent(),
              }) => LocalTripEventsCompanion.insert(
                tripId: tripId,
                seq: seq,
                kind: kind,
                actorId: actorId,
                meta: meta,
                at: at,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalTripEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalTripEventsTable,
      LocalTripEvent,
      $$LocalTripEventsTableFilterComposer,
      $$LocalTripEventsTableOrderingComposer,
      $$LocalTripEventsTableAnnotationComposer,
      $$LocalTripEventsTableCreateCompanionBuilder,
      $$LocalTripEventsTableUpdateCompanionBuilder,
      (
        LocalTripEvent,
        BaseReferences<_$AppDatabase, $LocalTripEventsTable, LocalTripEvent>,
      ),
      LocalTripEvent,
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
  $$LocalMessageReactionsTableTableManager get localMessageReactions =>
      $$LocalMessageReactionsTableTableManager(_db, _db.localMessageReactions);
  $$LocalContactListsTableTableManager get localContactLists =>
      $$LocalContactListsTableTableManager(_db, _db.localContactLists);
  $$LocalContactListMembersTableTableManager get localContactListMembers =>
      $$LocalContactListMembersTableTableManager(
        _db,
        _db.localContactListMembers,
      );
  $$LocalTripsTableTableManager get localTrips =>
      $$LocalTripsTableTableManager(_db, _db.localTrips);
  $$LocalTripPointsTableTableManager get localTripPoints =>
      $$LocalTripPointsTableTableManager(_db, _db.localTripPoints);
  $$LocalTripEventsTableTableManager get localTripEvents =>
      $$LocalTripEventsTableTableManager(_db, _db.localTripEvents);
}
