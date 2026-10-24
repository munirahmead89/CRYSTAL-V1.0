// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LocalProfilesTable extends LocalProfiles
    with TableInfo<$LocalProfilesTable, LocalProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarUrlMeta = const VerificationMeta(
    'avatarUrl',
  );
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
    'avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bioMeta = const VerificationMeta('bio');
  @override
  late final GeneratedColumn<String> bio = GeneratedColumn<String>(
    'bio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _presenceMeta = const VerificationMeta(
    'presence',
  );
  @override
  late final GeneratedColumn<String> presence = GeneratedColumn<String>(
    'presence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('offline'),
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    phone,
    avatarUrl,
    bio,
    presence,
    lastSeenAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('avatar_url')) {
      context.handle(
        _avatarUrlMeta,
        avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta),
      );
    }
    if (data.containsKey('bio')) {
      context.handle(
        _bioMeta,
        bio.isAcceptableOrUnknown(data['bio']!, _bioMeta),
      );
    }
    if (data.containsKey('presence')) {
      context.handle(
        _presenceMeta,
        presence.isAcceptableOrUnknown(data['presence']!, _presenceMeta),
      );
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      avatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_url'],
      ),
      bio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bio'],
      ),
      presence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}presence'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $LocalProfilesTable createAlias(String alias) {
    return $LocalProfilesTable(attachedDatabase, alias);
  }
}

class LocalProfile extends DataClass implements Insertable<LocalProfile> {
  final String id;
  final String? displayName;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final String presence;
  final DateTime? lastSeenAt;
  final DateTime? updatedAt;
  const LocalProfile({
    required this.id,
    this.displayName,
    this.phone,
    this.avatarUrl,
    this.bio,
    required this.presence,
    this.lastSeenAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    if (!nullToAbsent || bio != null) {
      map['bio'] = Variable<String>(bio);
    }
    map['presence'] = Variable<String>(presence);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  LocalProfilesCompanion toCompanion(bool nullToAbsent) {
    return LocalProfilesCompanion(
      id: Value(id),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      bio: bio == null && nullToAbsent ? const Value.absent() : Value(bio),
      presence: Value(presence),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LocalProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      phone: serializer.fromJson<String?>(json['phone']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      bio: serializer.fromJson<String?>(json['bio']),
      presence: serializer.fromJson<String>(json['presence']),
      lastSeenAt: serializer.fromJson<DateTime?>(json['lastSeenAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String?>(displayName),
      'phone': serializer.toJson<String?>(phone),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'bio': serializer.toJson<String?>(bio),
      'presence': serializer.toJson<String>(presence),
      'lastSeenAt': serializer.toJson<DateTime?>(lastSeenAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  LocalProfile copyWith({
    String? id,
    Value<String?> displayName = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> avatarUrl = const Value.absent(),
    Value<String?> bio = const Value.absent(),
    String? presence,
    Value<DateTime?> lastSeenAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => LocalProfile(
    id: id ?? this.id,
    displayName: displayName.present ? displayName.value : this.displayName,
    phone: phone.present ? phone.value : this.phone,
    avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
    bio: bio.present ? bio.value : this.bio,
    presence: presence ?? this.presence,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  LocalProfile copyWithCompanion(LocalProfilesCompanion data) {
    return LocalProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      phone: data.phone.present ? data.phone.value : this.phone,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      bio: data.bio.present ? data.bio.value : this.bio,
      presence: data.presence.present ? data.presence.value : this.presence,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('bio: $bio, ')
          ..write('presence: $presence, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    phone,
    avatarUrl,
    bio,
    presence,
    lastSeenAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.phone == this.phone &&
          other.avatarUrl == this.avatarUrl &&
          other.bio == this.bio &&
          other.presence == this.presence &&
          other.lastSeenAt == this.lastSeenAt &&
          other.updatedAt == this.updatedAt);
}

class LocalProfilesCompanion extends UpdateCompanion<LocalProfile> {
  final Value<String> id;
  final Value<String?> displayName;
  final Value<String?> phone;
  final Value<String?> avatarUrl;
  final Value<String?> bio;
  final Value<String> presence;
  final Value<DateTime?> lastSeenAt;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const LocalProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.bio = const Value.absent(),
    this.presence = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfilesCompanion.insert({
    required String id,
    this.displayName = const Value.absent(),
    this.phone = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.bio = const Value.absent(),
    this.presence = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<LocalProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? phone,
    Expression<String>? avatarUrl,
    Expression<String>? bio,
    Expression<String>? presence,
    Expression<DateTime>? lastSeenAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (bio != null) 'bio': bio,
      if (presence != null) 'presence': presence,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfilesCompanion copyWith({
    Value<String>? id,
    Value<String?>? displayName,
    Value<String?>? phone,
    Value<String?>? avatarUrl,
    Value<String?>? bio,
    Value<String>? presence,
    Value<DateTime?>? lastSeenAt,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      presence: presence ?? this.presence,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (bio.present) {
      map['bio'] = Variable<String>(bio.value);
    }
    if (presence.present) {
      map['presence'] = Variable<String>(presence.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('phone: $phone, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('bio: $bio, ')
          ..write('presence: $presence, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalConversationsTable extends LocalConversations
    with TableInfo<$LocalConversationsTable, LocalConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peerDisplayNameMeta = const VerificationMeta(
    'peerDisplayName',
  );
  @override
  late final GeneratedColumn<String> peerDisplayName = GeneratedColumn<String>(
    'peer_display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peerAvatarUrlMeta = const VerificationMeta(
    'peerAvatarUrl',
  );
  @override
  late final GeneratedColumn<String> peerAvatarUrl = GeneratedColumn<String>(
    'peer_avatar_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peerPresenceMeta = const VerificationMeta(
    'peerPresence',
  );
  @override
  late final GeneratedColumn<String> peerPresence = GeneratedColumn<String>(
    'peer_presence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _peerLastSeenAtMeta = const VerificationMeta(
    'peerLastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> peerLastSeenAt =
      GeneratedColumn<DateTime>(
        'peer_last_seen_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _memberJsonMeta = const VerificationMeta(
    'memberJson',
  );
  @override
  late final GeneratedColumn<String> memberJson = GeneratedColumn<String>(
    'member_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageIdMeta = const VerificationMeta(
    'lastMessageId',
  );
  @override
  late final GeneratedColumn<String> lastMessageId = GeneratedColumn<String>(
    'last_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessagePreviewMeta =
      const VerificationMeta('lastMessagePreview');
  @override
  late final GeneratedColumn<String> lastMessagePreview =
      GeneratedColumn<String>(
        'last_message_preview',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastMessageTypeMeta = const VerificationMeta(
    'lastMessageType',
  );
  @override
  late final GeneratedColumn<String> lastMessageType = GeneratedColumn<String>(
    'last_message_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastMessageSenderIdMeta =
      const VerificationMeta('lastMessageSenderId');
  @override
  late final GeneratedColumn<String> lastMessageSenderId =
      GeneratedColumn<String>(
        'last_message_sender_id',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    isGroup,
    peerId,
    peerDisplayName,
    peerAvatarUrl,
    peerPresence,
    peerLastSeenAt,
    displayName,
    memberJson,
    lastMessageId,
    lastMessagePreview,
    lastMessageType,
    lastMessageSenderId,
    lastMessageAt,
    unreadCount,
    updatedAt,
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
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('is_group')) {
      context.handle(
        _isGroupMeta,
        isGroup.isAcceptableOrUnknown(data['is_group']!, _isGroupMeta),
      );
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    }
    if (data.containsKey('peer_display_name')) {
      context.handle(
        _peerDisplayNameMeta,
        peerDisplayName.isAcceptableOrUnknown(
          data['peer_display_name']!,
          _peerDisplayNameMeta,
        ),
      );
    }
    if (data.containsKey('peer_avatar_url')) {
      context.handle(
        _peerAvatarUrlMeta,
        peerAvatarUrl.isAcceptableOrUnknown(
          data['peer_avatar_url']!,
          _peerAvatarUrlMeta,
        ),
      );
    }
    if (data.containsKey('peer_presence')) {
      context.handle(
        _peerPresenceMeta,
        peerPresence.isAcceptableOrUnknown(
          data['peer_presence']!,
          _peerPresenceMeta,
        ),
      );
    }
    if (data.containsKey('peer_last_seen_at')) {
      context.handle(
        _peerLastSeenAtMeta,
        peerLastSeenAt.isAcceptableOrUnknown(
          data['peer_last_seen_at']!,
          _peerLastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('member_json')) {
      context.handle(
        _memberJsonMeta,
        memberJson.isAcceptableOrUnknown(data['member_json']!, _memberJsonMeta),
      );
    }
    if (data.containsKey('last_message_id')) {
      context.handle(
        _lastMessageIdMeta,
        lastMessageId.isAcceptableOrUnknown(
          data['last_message_id']!,
          _lastMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('last_message_preview')) {
      context.handle(
        _lastMessagePreviewMeta,
        lastMessagePreview.isAcceptableOrUnknown(
          data['last_message_preview']!,
          _lastMessagePreviewMeta,
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
    if (data.containsKey('last_message_sender_id')) {
      context.handle(
        _lastMessageSenderIdMeta,
        lastMessageSenderId.isAcceptableOrUnknown(
          data['last_message_sender_id']!,
          _lastMessageSenderIdMeta,
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
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      isGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_group'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      ),
      peerDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_display_name'],
      ),
      peerAvatarUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_avatar_url'],
      ),
      peerPresence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_presence'],
      ),
      peerLastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}peer_last_seen_at'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      memberJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_json'],
      ),
      lastMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_id'],
      ),
      lastMessagePreview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_preview'],
      ),
      lastMessageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_type'],
      ),
      lastMessageSenderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_sender_id'],
      ),
      lastMessageAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_message_at'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
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
  final String id;
  final bool isGroup;
  final String? peerId;
  final String? peerDisplayName;
  final String? peerAvatarUrl;
  final String? peerPresence;
  final DateTime? peerLastSeenAt;
  final String? displayName;
  final String? memberJson;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime updatedAt;
  const LocalConversation({
    required this.id,
    required this.isGroup,
    this.peerId,
    this.peerDisplayName,
    this.peerAvatarUrl,
    this.peerPresence,
    this.peerLastSeenAt,
    this.displayName,
    this.memberJson,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.unreadCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['is_group'] = Variable<bool>(isGroup);
    if (!nullToAbsent || peerId != null) {
      map['peer_id'] = Variable<String>(peerId);
    }
    if (!nullToAbsent || peerDisplayName != null) {
      map['peer_display_name'] = Variable<String>(peerDisplayName);
    }
    if (!nullToAbsent || peerAvatarUrl != null) {
      map['peer_avatar_url'] = Variable<String>(peerAvatarUrl);
    }
    if (!nullToAbsent || peerPresence != null) {
      map['peer_presence'] = Variable<String>(peerPresence);
    }
    if (!nullToAbsent || peerLastSeenAt != null) {
      map['peer_last_seen_at'] = Variable<DateTime>(peerLastSeenAt);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || memberJson != null) {
      map['member_json'] = Variable<String>(memberJson);
    }
    if (!nullToAbsent || lastMessageId != null) {
      map['last_message_id'] = Variable<String>(lastMessageId);
    }
    if (!nullToAbsent || lastMessagePreview != null) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview);
    }
    if (!nullToAbsent || lastMessageType != null) {
      map['last_message_type'] = Variable<String>(lastMessageType);
    }
    if (!nullToAbsent || lastMessageSenderId != null) {
      map['last_message_sender_id'] = Variable<String>(lastMessageSenderId);
    }
    if (!nullToAbsent || lastMessageAt != null) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalConversationsCompanion toCompanion(bool nullToAbsent) {
    return LocalConversationsCompanion(
      id: Value(id),
      isGroup: Value(isGroup),
      peerId: peerId == null && nullToAbsent
          ? const Value.absent()
          : Value(peerId),
      peerDisplayName: peerDisplayName == null && nullToAbsent
          ? const Value.absent()
          : Value(peerDisplayName),
      peerAvatarUrl: peerAvatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(peerAvatarUrl),
      peerPresence: peerPresence == null && nullToAbsent
          ? const Value.absent()
          : Value(peerPresence),
      peerLastSeenAt: peerLastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(peerLastSeenAt),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      memberJson: memberJson == null && nullToAbsent
          ? const Value.absent()
          : Value(memberJson),
      lastMessageId: lastMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageId),
      lastMessagePreview: lastMessagePreview == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessagePreview),
      lastMessageType: lastMessageType == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageType),
      lastMessageSenderId: lastMessageSenderId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageSenderId),
      lastMessageAt: lastMessageAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageAt),
      unreadCount: Value(unreadCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConversation(
      id: serializer.fromJson<String>(json['id']),
      isGroup: serializer.fromJson<bool>(json['isGroup']),
      peerId: serializer.fromJson<String?>(json['peerId']),
      peerDisplayName: serializer.fromJson<String?>(json['peerDisplayName']),
      peerAvatarUrl: serializer.fromJson<String?>(json['peerAvatarUrl']),
      peerPresence: serializer.fromJson<String?>(json['peerPresence']),
      peerLastSeenAt: serializer.fromJson<DateTime?>(json['peerLastSeenAt']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      memberJson: serializer.fromJson<String?>(json['memberJson']),
      lastMessageId: serializer.fromJson<String?>(json['lastMessageId']),
      lastMessagePreview: serializer.fromJson<String?>(
        json['lastMessagePreview'],
      ),
      lastMessageType: serializer.fromJson<String?>(json['lastMessageType']),
      lastMessageSenderId: serializer.fromJson<String?>(
        json['lastMessageSenderId'],
      ),
      lastMessageAt: serializer.fromJson<DateTime?>(json['lastMessageAt']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'isGroup': serializer.toJson<bool>(isGroup),
      'peerId': serializer.toJson<String?>(peerId),
      'peerDisplayName': serializer.toJson<String?>(peerDisplayName),
      'peerAvatarUrl': serializer.toJson<String?>(peerAvatarUrl),
      'peerPresence': serializer.toJson<String?>(peerPresence),
      'peerLastSeenAt': serializer.toJson<DateTime?>(peerLastSeenAt),
      'displayName': serializer.toJson<String?>(displayName),
      'memberJson': serializer.toJson<String?>(memberJson),
      'lastMessageId': serializer.toJson<String?>(lastMessageId),
      'lastMessagePreview': serializer.toJson<String?>(lastMessagePreview),
      'lastMessageType': serializer.toJson<String?>(lastMessageType),
      'lastMessageSenderId': serializer.toJson<String?>(lastMessageSenderId),
      'lastMessageAt': serializer.toJson<DateTime?>(lastMessageAt),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalConversation copyWith({
    String? id,
    bool? isGroup,
    Value<String?> peerId = const Value.absent(),
    Value<String?> peerDisplayName = const Value.absent(),
    Value<String?> peerAvatarUrl = const Value.absent(),
    Value<String?> peerPresence = const Value.absent(),
    Value<DateTime?> peerLastSeenAt = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    Value<String?> memberJson = const Value.absent(),
    Value<String?> lastMessageId = const Value.absent(),
    Value<String?> lastMessagePreview = const Value.absent(),
    Value<String?> lastMessageType = const Value.absent(),
    Value<String?> lastMessageSenderId = const Value.absent(),
    Value<DateTime?> lastMessageAt = const Value.absent(),
    int? unreadCount,
    DateTime? updatedAt,
  }) => LocalConversation(
    id: id ?? this.id,
    isGroup: isGroup ?? this.isGroup,
    peerId: peerId.present ? peerId.value : this.peerId,
    peerDisplayName: peerDisplayName.present
        ? peerDisplayName.value
        : this.peerDisplayName,
    peerAvatarUrl: peerAvatarUrl.present
        ? peerAvatarUrl.value
        : this.peerAvatarUrl,
    peerPresence: peerPresence.present ? peerPresence.value : this.peerPresence,
    peerLastSeenAt: peerLastSeenAt.present
        ? peerLastSeenAt.value
        : this.peerLastSeenAt,
    displayName: displayName.present ? displayName.value : this.displayName,
    memberJson: memberJson.present ? memberJson.value : this.memberJson,
    lastMessageId: lastMessageId.present
        ? lastMessageId.value
        : this.lastMessageId,
    lastMessagePreview: lastMessagePreview.present
        ? lastMessagePreview.value
        : this.lastMessagePreview,
    lastMessageType: lastMessageType.present
        ? lastMessageType.value
        : this.lastMessageType,
    lastMessageSenderId: lastMessageSenderId.present
        ? lastMessageSenderId.value
        : this.lastMessageSenderId,
    lastMessageAt: lastMessageAt.present
        ? lastMessageAt.value
        : this.lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalConversation copyWithCompanion(LocalConversationsCompanion data) {
    return LocalConversation(
      id: data.id.present ? data.id.value : this.id,
      isGroup: data.isGroup.present ? data.isGroup.value : this.isGroup,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      peerDisplayName: data.peerDisplayName.present
          ? data.peerDisplayName.value
          : this.peerDisplayName,
      peerAvatarUrl: data.peerAvatarUrl.present
          ? data.peerAvatarUrl.value
          : this.peerAvatarUrl,
      peerPresence: data.peerPresence.present
          ? data.peerPresence.value
          : this.peerPresence,
      peerLastSeenAt: data.peerLastSeenAt.present
          ? data.peerLastSeenAt.value
          : this.peerLastSeenAt,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      memberJson: data.memberJson.present
          ? data.memberJson.value
          : this.memberJson,
      lastMessageId: data.lastMessageId.present
          ? data.lastMessageId.value
          : this.lastMessageId,
      lastMessagePreview: data.lastMessagePreview.present
          ? data.lastMessagePreview.value
          : this.lastMessagePreview,
      lastMessageType: data.lastMessageType.present
          ? data.lastMessageType.value
          : this.lastMessageType,
      lastMessageSenderId: data.lastMessageSenderId.present
          ? data.lastMessageSenderId.value
          : this.lastMessageSenderId,
      lastMessageAt: data.lastMessageAt.present
          ? data.lastMessageAt.value
          : this.lastMessageAt,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversation(')
          ..write('id: $id, ')
          ..write('isGroup: $isGroup, ')
          ..write('peerId: $peerId, ')
          ..write('peerDisplayName: $peerDisplayName, ')
          ..write('peerAvatarUrl: $peerAvatarUrl, ')
          ..write('peerPresence: $peerPresence, ')
          ..write('peerLastSeenAt: $peerLastSeenAt, ')
          ..write('displayName: $displayName, ')
          ..write('memberJson: $memberJson, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageSenderId: $lastMessageSenderId, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    isGroup,
    peerId,
    peerDisplayName,
    peerAvatarUrl,
    peerPresence,
    peerLastSeenAt,
    displayName,
    memberJson,
    lastMessageId,
    lastMessagePreview,
    lastMessageType,
    lastMessageSenderId,
    lastMessageAt,
    unreadCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConversation &&
          other.id == this.id &&
          other.isGroup == this.isGroup &&
          other.peerId == this.peerId &&
          other.peerDisplayName == this.peerDisplayName &&
          other.peerAvatarUrl == this.peerAvatarUrl &&
          other.peerPresence == this.peerPresence &&
          other.peerLastSeenAt == this.peerLastSeenAt &&
          other.displayName == this.displayName &&
          other.memberJson == this.memberJson &&
          other.lastMessageId == this.lastMessageId &&
          other.lastMessagePreview == this.lastMessagePreview &&
          other.lastMessageType == this.lastMessageType &&
          other.lastMessageSenderId == this.lastMessageSenderId &&
          other.lastMessageAt == this.lastMessageAt &&
          other.unreadCount == this.unreadCount &&
          other.updatedAt == this.updatedAt);
}

class LocalConversationsCompanion extends UpdateCompanion<LocalConversation> {
  final Value<String> id;
  final Value<bool> isGroup;
  final Value<String?> peerId;
  final Value<String?> peerDisplayName;
  final Value<String?> peerAvatarUrl;
  final Value<String?> peerPresence;
  final Value<DateTime?> peerLastSeenAt;
  final Value<String?> displayName;
  final Value<String?> memberJson;
  final Value<String?> lastMessageId;
  final Value<String?> lastMessagePreview;
  final Value<String?> lastMessageType;
  final Value<String?> lastMessageSenderId;
  final Value<DateTime?> lastMessageAt;
  final Value<int> unreadCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LocalConversationsCompanion({
    this.id = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.peerId = const Value.absent(),
    this.peerDisplayName = const Value.absent(),
    this.peerAvatarUrl = const Value.absent(),
    this.peerPresence = const Value.absent(),
    this.peerLastSeenAt = const Value.absent(),
    this.displayName = const Value.absent(),
    this.memberJson = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.lastMessageSenderId = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalConversationsCompanion.insert({
    required String id,
    this.isGroup = const Value.absent(),
    this.peerId = const Value.absent(),
    this.peerDisplayName = const Value.absent(),
    this.peerAvatarUrl = const Value.absent(),
    this.peerPresence = const Value.absent(),
    this.peerLastSeenAt = const Value.absent(),
    this.displayName = const Value.absent(),
    this.memberJson = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.lastMessagePreview = const Value.absent(),
    this.lastMessageType = const Value.absent(),
    this.lastMessageSenderId = const Value.absent(),
    this.lastMessageAt = const Value.absent(),
    this.unreadCount = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAt = Value(updatedAt);
  static Insertable<LocalConversation> custom({
    Expression<String>? id,
    Expression<bool>? isGroup,
    Expression<String>? peerId,
    Expression<String>? peerDisplayName,
    Expression<String>? peerAvatarUrl,
    Expression<String>? peerPresence,
    Expression<DateTime>? peerLastSeenAt,
    Expression<String>? displayName,
    Expression<String>? memberJson,
    Expression<String>? lastMessageId,
    Expression<String>? lastMessagePreview,
    Expression<String>? lastMessageType,
    Expression<String>? lastMessageSenderId,
    Expression<DateTime>? lastMessageAt,
    Expression<int>? unreadCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isGroup != null) 'is_group': isGroup,
      if (peerId != null) 'peer_id': peerId,
      if (peerDisplayName != null) 'peer_display_name': peerDisplayName,
      if (peerAvatarUrl != null) 'peer_avatar_url': peerAvatarUrl,
      if (peerPresence != null) 'peer_presence': peerPresence,
      if (peerLastSeenAt != null) 'peer_last_seen_at': peerLastSeenAt,
      if (displayName != null) 'display_name': displayName,
      if (memberJson != null) 'member_json': memberJson,
      if (lastMessageId != null) 'last_message_id': lastMessageId,
      if (lastMessagePreview != null)
        'last_message_preview': lastMessagePreview,
      if (lastMessageType != null) 'last_message_type': lastMessageType,
      if (lastMessageSenderId != null)
        'last_message_sender_id': lastMessageSenderId,
      if (lastMessageAt != null) 'last_message_at': lastMessageAt,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalConversationsCompanion copyWith({
    Value<String>? id,
    Value<bool>? isGroup,
    Value<String?>? peerId,
    Value<String?>? peerDisplayName,
    Value<String?>? peerAvatarUrl,
    Value<String?>? peerPresence,
    Value<DateTime?>? peerLastSeenAt,
    Value<String?>? displayName,
    Value<String?>? memberJson,
    Value<String?>? lastMessageId,
    Value<String?>? lastMessagePreview,
    Value<String?>? lastMessageType,
    Value<String?>? lastMessageSenderId,
    Value<DateTime?>? lastMessageAt,
    Value<int>? unreadCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalConversationsCompanion(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      peerId: peerId ?? this.peerId,
      peerDisplayName: peerDisplayName ?? this.peerDisplayName,
      peerAvatarUrl: peerAvatarUrl ?? this.peerAvatarUrl,
      peerPresence: peerPresence ?? this.peerPresence,
      peerLastSeenAt: peerLastSeenAt ?? this.peerLastSeenAt,
      displayName: displayName ?? this.displayName,
      memberJson: memberJson ?? this.memberJson,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (isGroup.present) {
      map['is_group'] = Variable<bool>(isGroup.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (peerDisplayName.present) {
      map['peer_display_name'] = Variable<String>(peerDisplayName.value);
    }
    if (peerAvatarUrl.present) {
      map['peer_avatar_url'] = Variable<String>(peerAvatarUrl.value);
    }
    if (peerPresence.present) {
      map['peer_presence'] = Variable<String>(peerPresence.value);
    }
    if (peerLastSeenAt.present) {
      map['peer_last_seen_at'] = Variable<DateTime>(peerLastSeenAt.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (memberJson.present) {
      map['member_json'] = Variable<String>(memberJson.value);
    }
    if (lastMessageId.present) {
      map['last_message_id'] = Variable<String>(lastMessageId.value);
    }
    if (lastMessagePreview.present) {
      map['last_message_preview'] = Variable<String>(lastMessagePreview.value);
    }
    if (lastMessageType.present) {
      map['last_message_type'] = Variable<String>(lastMessageType.value);
    }
    if (lastMessageSenderId.present) {
      map['last_message_sender_id'] = Variable<String>(
        lastMessageSenderId.value,
      );
    }
    if (lastMessageAt.present) {
      map['last_message_at'] = Variable<DateTime>(lastMessageAt.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversationsCompanion(')
          ..write('id: $id, ')
          ..write('isGroup: $isGroup, ')
          ..write('peerId: $peerId, ')
          ..write('peerDisplayName: $peerDisplayName, ')
          ..write('peerAvatarUrl: $peerAvatarUrl, ')
          ..write('peerPresence: $peerPresence, ')
          ..write('peerLastSeenAt: $peerLastSeenAt, ')
          ..write('displayName: $displayName, ')
          ..write('memberJson: $memberJson, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('lastMessagePreview: $lastMessagePreview, ')
          ..write('lastMessageType: $lastMessageType, ')
          ..write('lastMessageSenderId: $lastMessageSenderId, ')
          ..write('lastMessageAt: $lastMessageAt, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientMessageIdMeta = const VerificationMeta(
    'clientMessageId',
  );
  @override
  late final GeneratedColumn<String> clientMessageId = GeneratedColumn<String>(
    'client_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderIdMeta = const VerificationMeta(
    'senderId',
  );
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
    'sender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaJsonMeta = const VerificationMeta(
    'mediaJson',
  );
  @override
  late final GeneratedColumn<String> mediaJson = GeneratedColumn<String>(
    'media_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reactionsJsonMeta = const VerificationMeta(
    'reactionsJson',
  );
  @override
  late final GeneratedColumn<String> reactionsJson = GeneratedColumn<String>(
    'reactions_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forwardedMeta = const VerificationMeta(
    'forwarded',
  );
  @override
  late final GeneratedColumn<bool> forwarded = GeneratedColumn<bool>(
    'forwarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("forwarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localStateMeta = const VerificationMeta(
    'localState',
  );
  @override
  late final GeneratedColumn<String> localState = GeneratedColumn<String>(
    'local_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _remoteStatusMeta = const VerificationMeta(
    'remoteStatus',
  );
  @override
  late final GeneratedColumn<String> remoteStatus = GeneratedColumn<String>(
    'remote_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sent'),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outgoingMeta = const VerificationMeta(
    'outgoing',
  );
  @override
  late final GeneratedColumn<bool> outgoing = GeneratedColumn<bool>(
    'outgoing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("outgoing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _serverCreatedAtMeta = const VerificationMeta(
    'serverCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverCreatedAt =
      GeneratedColumn<DateTime>(
        'server_created_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retentionStateMeta = const VerificationMeta(
    'retentionState',
  );
  @override
  late final GeneratedColumn<String> retentionState = GeneratedColumn<String>(
    'retention_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('retained'),
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _encryptionVersionMeta = const VerificationMeta(
    'encryptionVersion',
  );
  @override
  late final GeneratedColumn<int> encryptionVersion = GeneratedColumn<int>(
    'encryption_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientMessageId,
    ownerId,
    serverId,
    conversationId,
    senderId,
    type,
    body,
    mediaJson,
    reactionsJson,
    replyToId,
    forwarded,
    localState,
    remoteStatus,
    createdAt,
    updatedAt,
    outgoing,
    deleted,
    deliveredAt,
    readAt,
    serverCreatedAt,
    deletedAt,
    retentionState,
    schemaVersion,
    encryptionVersion,
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
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_message_id')) {
      context.handle(
        _clientMessageIdMeta,
        clientMessageId.isAcceptableOrUnknown(
          data['client_message_id']!,
          _clientMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientMessageIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(
        _senderIdMeta,
        senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('media_json')) {
      context.handle(
        _mediaJsonMeta,
        mediaJson.isAcceptableOrUnknown(data['media_json']!, _mediaJsonMeta),
      );
    }
    if (data.containsKey('reactions_json')) {
      context.handle(
        _reactionsJsonMeta,
        reactionsJson.isAcceptableOrUnknown(
          data['reactions_json']!,
          _reactionsJsonMeta,
        ),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('forwarded')) {
      context.handle(
        _forwardedMeta,
        forwarded.isAcceptableOrUnknown(data['forwarded']!, _forwardedMeta),
      );
    }
    if (data.containsKey('local_state')) {
      context.handle(
        _localStateMeta,
        localState.isAcceptableOrUnknown(data['local_state']!, _localStateMeta),
      );
    }
    if (data.containsKey('remote_status')) {
      context.handle(
        _remoteStatusMeta,
        remoteStatus.isAcceptableOrUnknown(
          data['remote_status']!,
          _remoteStatusMeta,
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('outgoing')) {
      context.handle(
        _outgoingMeta,
        outgoing.isAcceptableOrUnknown(data['outgoing']!, _outgoingMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
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
    if (data.containsKey('server_created_at')) {
      context.handle(
        _serverCreatedAtMeta,
        serverCreatedAt.isAcceptableOrUnknown(
          data['server_created_at']!,
          _serverCreatedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('retention_state')) {
      context.handle(
        _retentionStateMeta,
        retentionState.isAcceptableOrUnknown(
          data['retention_state']!,
          _retentionStateMeta,
        ),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    }
    if (data.containsKey('encryption_version')) {
      context.handle(
        _encryptionVersionMeta,
        encryptionVersion.isAcceptableOrUnknown(
          data['encryption_version']!,
          _encryptionVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_message_id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      mediaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_json'],
      ),
      reactionsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reactions_json'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      forwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}forwarded'],
      )!,
      localState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_state'],
      )!,
      remoteStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      outgoing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}outgoing'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      deliveredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}delivered_at'],
      ),
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      ),
      serverCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_created_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      retentionState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}retention_state'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      encryptionVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encryption_version'],
      )!,
    );
  }

  @override
  $LocalMessagesTable createAlias(String alias) {
    return $LocalMessagesTable(attachedDatabase, alias);
  }
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final String id;
  final String clientMessageId;

  /// Account this row belongs to.
  ///
  /// Empty string means "not yet claimed": every install created before this
  /// column existed has rows in that state, and the first account to sign in
  /// after the upgrade adopts them. Without an owner column a second account
  /// signing in on the same device sees the first account's messages AND
  /// flushes its queued outbox under its own identity.
  final String ownerId;

  /// Server-assigned row id, recorded once the relay accepts the message.
  ///
  /// Stored alongside [id] (the client id) so a reconcile can map a fetched
  /// row back to the local row that is still keyed by the client id, without
  /// a delete-then-insert that would lose the row on a crash.
  final String? serverId;
  final String conversationId;
  final String senderId;
  final String type;
  final String? body;
  final String? mediaJson;
  final String? reactionsJson;
  final String? replyToId;

  /// Marks a forwarded message, so the "Forwarded" label survives an app
  /// restart and an offline flush instead of being a transient UI flag.
  final bool forwarded;
  final String localState;
  final String remoteStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool outgoing;
  final bool deleted;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  /// Server receipt time. Authoritative for ordering; the local clock is not
  /// trusted for it.
  final DateTime? serverCreatedAt;
  final DateTime? deletedAt;

  /// Relay payload lifecycle, mirrored from the server row so a purged message
  /// still renders as "deleted" rather than as an empty bubble.
  final String retentionState;

  /// Envelope versions, carried through so a row written by a newer build is
  /// interpretable rather than best-effort.
  final int schemaVersion;
  final int encryptionVersion;
  const LocalMessage({
    required this.id,
    required this.clientMessageId,
    required this.ownerId,
    this.serverId,
    required this.conversationId,
    required this.senderId,
    required this.type,
    this.body,
    this.mediaJson,
    this.reactionsJson,
    this.replyToId,
    required this.forwarded,
    required this.localState,
    required this.remoteStatus,
    required this.createdAt,
    this.updatedAt,
    required this.outgoing,
    required this.deleted,
    this.deliveredAt,
    this.readAt,
    this.serverCreatedAt,
    this.deletedAt,
    required this.retentionState,
    required this.schemaVersion,
    required this.encryptionVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['client_message_id'] = Variable<String>(clientMessageId);
    map['owner_id'] = Variable<String>(ownerId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || mediaJson != null) {
      map['media_json'] = Variable<String>(mediaJson);
    }
    if (!nullToAbsent || reactionsJson != null) {
      map['reactions_json'] = Variable<String>(reactionsJson);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    map['forwarded'] = Variable<bool>(forwarded);
    map['local_state'] = Variable<String>(localState);
    map['remote_status'] = Variable<String>(remoteStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['outgoing'] = Variable<bool>(outgoing);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || deliveredAt != null) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt);
    }
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<DateTime>(readAt);
    }
    if (!nullToAbsent || serverCreatedAt != null) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['retention_state'] = Variable<String>(retentionState);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['encryption_version'] = Variable<int>(encryptionVersion);
    return map;
  }

  LocalMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalMessagesCompanion(
      id: Value(id),
      clientMessageId: Value(clientMessageId),
      ownerId: Value(ownerId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      type: Value(type),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      mediaJson: mediaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaJson),
      reactionsJson: reactionsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reactionsJson),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      forwarded: Value(forwarded),
      localState: Value(localState),
      remoteStatus: Value(remoteStatus),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      outgoing: Value(outgoing),
      deleted: Value(deleted),
      deliveredAt: deliveredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deliveredAt),
      readAt: readAt == null && nullToAbsent
          ? const Value.absent()
          : Value(readAt),
      serverCreatedAt: serverCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverCreatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      retentionState: Value(retentionState),
      schemaVersion: Value(schemaVersion),
      encryptionVersion: Value(encryptionVersion),
    );
  }

  factory LocalMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      id: serializer.fromJson<String>(json['id']),
      clientMessageId: serializer.fromJson<String>(json['clientMessageId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      type: serializer.fromJson<String>(json['type']),
      body: serializer.fromJson<String?>(json['body']),
      mediaJson: serializer.fromJson<String?>(json['mediaJson']),
      reactionsJson: serializer.fromJson<String?>(json['reactionsJson']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      forwarded: serializer.fromJson<bool>(json['forwarded']),
      localState: serializer.fromJson<String>(json['localState']),
      remoteStatus: serializer.fromJson<String>(json['remoteStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      outgoing: serializer.fromJson<bool>(json['outgoing']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      deliveredAt: serializer.fromJson<DateTime?>(json['deliveredAt']),
      readAt: serializer.fromJson<DateTime?>(json['readAt']),
      serverCreatedAt: serializer.fromJson<DateTime?>(json['serverCreatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      retentionState: serializer.fromJson<String>(json['retentionState']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      encryptionVersion: serializer.fromJson<int>(json['encryptionVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientMessageId': serializer.toJson<String>(clientMessageId),
      'ownerId': serializer.toJson<String>(ownerId),
      'serverId': serializer.toJson<String?>(serverId),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'type': serializer.toJson<String>(type),
      'body': serializer.toJson<String?>(body),
      'mediaJson': serializer.toJson<String?>(mediaJson),
      'reactionsJson': serializer.toJson<String?>(reactionsJson),
      'replyToId': serializer.toJson<String?>(replyToId),
      'forwarded': serializer.toJson<bool>(forwarded),
      'localState': serializer.toJson<String>(localState),
      'remoteStatus': serializer.toJson<String>(remoteStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'outgoing': serializer.toJson<bool>(outgoing),
      'deleted': serializer.toJson<bool>(deleted),
      'deliveredAt': serializer.toJson<DateTime?>(deliveredAt),
      'readAt': serializer.toJson<DateTime?>(readAt),
      'serverCreatedAt': serializer.toJson<DateTime?>(serverCreatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'retentionState': serializer.toJson<String>(retentionState),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'encryptionVersion': serializer.toJson<int>(encryptionVersion),
    };
  }

  LocalMessage copyWith({
    String? id,
    String? clientMessageId,
    String? ownerId,
    Value<String?> serverId = const Value.absent(),
    String? conversationId,
    String? senderId,
    String? type,
    Value<String?> body = const Value.absent(),
    Value<String?> mediaJson = const Value.absent(),
    Value<String?> reactionsJson = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    bool? forwarded,
    String? localState,
    String? remoteStatus,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? outgoing,
    bool? deleted,
    Value<DateTime?> deliveredAt = const Value.absent(),
    Value<DateTime?> readAt = const Value.absent(),
    Value<DateTime?> serverCreatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    String? retentionState,
    int? schemaVersion,
    int? encryptionVersion,
  }) => LocalMessage(
    id: id ?? this.id,
    clientMessageId: clientMessageId ?? this.clientMessageId,
    ownerId: ownerId ?? this.ownerId,
    serverId: serverId.present ? serverId.value : this.serverId,
    conversationId: conversationId ?? this.conversationId,
    senderId: senderId ?? this.senderId,
    type: type ?? this.type,
    body: body.present ? body.value : this.body,
    mediaJson: mediaJson.present ? mediaJson.value : this.mediaJson,
    reactionsJson: reactionsJson.present
        ? reactionsJson.value
        : this.reactionsJson,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    forwarded: forwarded ?? this.forwarded,
    localState: localState ?? this.localState,
    remoteStatus: remoteStatus ?? this.remoteStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    outgoing: outgoing ?? this.outgoing,
    deleted: deleted ?? this.deleted,
    deliveredAt: deliveredAt.present ? deliveredAt.value : this.deliveredAt,
    readAt: readAt.present ? readAt.value : this.readAt,
    serverCreatedAt: serverCreatedAt.present
        ? serverCreatedAt.value
        : this.serverCreatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    retentionState: retentionState ?? this.retentionState,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    encryptionVersion: encryptionVersion ?? this.encryptionVersion,
  );
  LocalMessage copyWithCompanion(LocalMessagesCompanion data) {
    return LocalMessage(
      id: data.id.present ? data.id.value : this.id,
      clientMessageId: data.clientMessageId.present
          ? data.clientMessageId.value
          : this.clientMessageId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      type: data.type.present ? data.type.value : this.type,
      body: data.body.present ? data.body.value : this.body,
      mediaJson: data.mediaJson.present ? data.mediaJson.value : this.mediaJson,
      reactionsJson: data.reactionsJson.present
          ? data.reactionsJson.value
          : this.reactionsJson,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      forwarded: data.forwarded.present ? data.forwarded.value : this.forwarded,
      localState: data.localState.present
          ? data.localState.value
          : this.localState,
      remoteStatus: data.remoteStatus.present
          ? data.remoteStatus.value
          : this.remoteStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      outgoing: data.outgoing.present ? data.outgoing.value : this.outgoing,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      deliveredAt: data.deliveredAt.present
          ? data.deliveredAt.value
          : this.deliveredAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      serverCreatedAt: data.serverCreatedAt.present
          ? data.serverCreatedAt.value
          : this.serverCreatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      retentionState: data.retentionState.present
          ? data.retentionState.value
          : this.retentionState,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      encryptionVersion: data.encryptionVersion.present
          ? data.encryptionVersion.value
          : this.encryptionVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('id: $id, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('ownerId: $ownerId, ')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwarded: $forwarded, ')
          ..write('localState: $localState, ')
          ..write('remoteStatus: $remoteStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('outgoing: $outgoing, ')
          ..write('deleted: $deleted, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('retentionState: $retentionState, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('encryptionVersion: $encryptionVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    clientMessageId,
    ownerId,
    serverId,
    conversationId,
    senderId,
    type,
    body,
    mediaJson,
    reactionsJson,
    replyToId,
    forwarded,
    localState,
    remoteStatus,
    createdAt,
    updatedAt,
    outgoing,
    deleted,
    deliveredAt,
    readAt,
    serverCreatedAt,
    deletedAt,
    retentionState,
    schemaVersion,
    encryptionVersion,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.id == this.id &&
          other.clientMessageId == this.clientMessageId &&
          other.ownerId == this.ownerId &&
          other.serverId == this.serverId &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          other.type == this.type &&
          other.body == this.body &&
          other.mediaJson == this.mediaJson &&
          other.reactionsJson == this.reactionsJson &&
          other.replyToId == this.replyToId &&
          other.forwarded == this.forwarded &&
          other.localState == this.localState &&
          other.remoteStatus == this.remoteStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.outgoing == this.outgoing &&
          other.deleted == this.deleted &&
          other.deliveredAt == this.deliveredAt &&
          other.readAt == this.readAt &&
          other.serverCreatedAt == this.serverCreatedAt &&
          other.deletedAt == this.deletedAt &&
          other.retentionState == this.retentionState &&
          other.schemaVersion == this.schemaVersion &&
          other.encryptionVersion == this.encryptionVersion);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<String> id;
  final Value<String> clientMessageId;
  final Value<String> ownerId;
  final Value<String?> serverId;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<String> type;
  final Value<String?> body;
  final Value<String?> mediaJson;
  final Value<String?> reactionsJson;
  final Value<String?> replyToId;
  final Value<bool> forwarded;
  final Value<String> localState;
  final Value<String> remoteStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> outgoing;
  final Value<bool> deleted;
  final Value<DateTime?> deliveredAt;
  final Value<DateTime?> readAt;
  final Value<DateTime?> serverCreatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> retentionState;
  final Value<int> schemaVersion;
  final Value<int> encryptionVersion;
  final Value<int> rowid;
  const LocalMessagesCompanion({
    this.id = const Value.absent(),
    this.clientMessageId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.type = const Value.absent(),
    this.body = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.forwarded = const Value.absent(),
    this.localState = const Value.absent(),
    this.remoteStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.outgoing = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.retentionState = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMessagesCompanion.insert({
    required String id,
    required String clientMessageId,
    this.ownerId = const Value.absent(),
    this.serverId = const Value.absent(),
    required String conversationId,
    required String senderId,
    this.type = const Value.absent(),
    this.body = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.reactionsJson = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.forwarded = const Value.absent(),
    this.localState = const Value.absent(),
    this.remoteStatus = const Value.absent(),
    required DateTime createdAt,
    this.updatedAt = const Value.absent(),
    this.outgoing = const Value.absent(),
    this.deleted = const Value.absent(),
    this.deliveredAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.retentionState = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.encryptionVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientMessageId = Value(clientMessageId),
       conversationId = Value(conversationId),
       senderId = Value(senderId),
       createdAt = Value(createdAt);
  static Insertable<LocalMessage> custom({
    Expression<String>? id,
    Expression<String>? clientMessageId,
    Expression<String>? ownerId,
    Expression<String>? serverId,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<String>? type,
    Expression<String>? body,
    Expression<String>? mediaJson,
    Expression<String>? reactionsJson,
    Expression<String>? replyToId,
    Expression<bool>? forwarded,
    Expression<String>? localState,
    Expression<String>? remoteStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? outgoing,
    Expression<bool>? deleted,
    Expression<DateTime>? deliveredAt,
    Expression<DateTime>? readAt,
    Expression<DateTime>? serverCreatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? retentionState,
    Expression<int>? schemaVersion,
    Expression<int>? encryptionVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      if (ownerId != null) 'owner_id': ownerId,
      if (serverId != null) 'server_id': serverId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (type != null) 'type': type,
      if (body != null) 'body': body,
      if (mediaJson != null) 'media_json': mediaJson,
      if (reactionsJson != null) 'reactions_json': reactionsJson,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (forwarded != null) 'forwarded': forwarded,
      if (localState != null) 'local_state': localState,
      if (remoteStatus != null) 'remote_status': remoteStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (outgoing != null) 'outgoing': outgoing,
      if (deleted != null) 'deleted': deleted,
      if (deliveredAt != null) 'delivered_at': deliveredAt,
      if (readAt != null) 'read_at': readAt,
      if (serverCreatedAt != null) 'server_created_at': serverCreatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (retentionState != null) 'retention_state': retentionState,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (encryptionVersion != null) 'encryption_version': encryptionVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? clientMessageId,
    Value<String>? ownerId,
    Value<String?>? serverId,
    Value<String>? conversationId,
    Value<String>? senderId,
    Value<String>? type,
    Value<String?>? body,
    Value<String?>? mediaJson,
    Value<String?>? reactionsJson,
    Value<String?>? replyToId,
    Value<bool>? forwarded,
    Value<String>? localState,
    Value<String>? remoteStatus,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? outgoing,
    Value<bool>? deleted,
    Value<DateTime?>? deliveredAt,
    Value<DateTime?>? readAt,
    Value<DateTime?>? serverCreatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? retentionState,
    Value<int>? schemaVersion,
    Value<int>? encryptionVersion,
    Value<int>? rowid,
  }) {
    return LocalMessagesCompanion(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      ownerId: ownerId ?? this.ownerId,
      serverId: serverId ?? this.serverId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      body: body ?? this.body,
      mediaJson: mediaJson ?? this.mediaJson,
      reactionsJson: reactionsJson ?? this.reactionsJson,
      replyToId: replyToId ?? this.replyToId,
      forwarded: forwarded ?? this.forwarded,
      localState: localState ?? this.localState,
      remoteStatus: remoteStatus ?? this.remoteStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      outgoing: outgoing ?? this.outgoing,
      deleted: deleted ?? this.deleted,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      retentionState: retentionState ?? this.retentionState,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      encryptionVersion: encryptionVersion ?? this.encryptionVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientMessageId.present) {
      map['client_message_id'] = Variable<String>(clientMessageId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (mediaJson.present) {
      map['media_json'] = Variable<String>(mediaJson.value);
    }
    if (reactionsJson.present) {
      map['reactions_json'] = Variable<String>(reactionsJson.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (forwarded.present) {
      map['forwarded'] = Variable<bool>(forwarded.value);
    }
    if (localState.present) {
      map['local_state'] = Variable<String>(localState.value);
    }
    if (remoteStatus.present) {
      map['remote_status'] = Variable<String>(remoteStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (outgoing.present) {
      map['outgoing'] = Variable<bool>(outgoing.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (deliveredAt.present) {
      map['delivered_at'] = Variable<DateTime>(deliveredAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (serverCreatedAt.present) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (retentionState.present) {
      map['retention_state'] = Variable<String>(retentionState.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (encryptionVersion.present) {
      map['encryption_version'] = Variable<int>(encryptionVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessagesCompanion(')
          ..write('id: $id, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('ownerId: $ownerId, ')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('reactionsJson: $reactionsJson, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwarded: $forwarded, ')
          ..write('localState: $localState, ')
          ..write('remoteStatus: $remoteStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('outgoing: $outgoing, ')
          ..write('deleted: $deleted, ')
          ..write('deliveredAt: $deliveredAt, ')
          ..write('readAt: $readAt, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('retentionState: $retentionState, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('encryptionVersion: $encryptionVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxMessagesTable extends OutboxMessages
    with TableInfo<$OutboxMessagesTable, OutboxMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _clientMessageIdMeta = const VerificationMeta(
    'clientMessageId',
  );
  @override
  late final GeneratedColumn<String> clientMessageId = GeneratedColumn<String>(
    'client_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('text'),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaJsonMeta = const VerificationMeta(
    'mediaJson',
  );
  @override
  late final GeneratedColumn<String> mediaJson = GeneratedColumn<String>(
    'media_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyToIdMeta = const VerificationMeta(
    'replyToId',
  );
  @override
  late final GeneratedColumn<String> replyToId = GeneratedColumn<String>(
    'reply_to_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forwardedMeta = const VerificationMeta(
    'forwarded',
  );
  @override
  late final GeneratedColumn<bool> forwarded = GeneratedColumn<bool>(
    'forwarded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("forwarded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    clientMessageId,
    conversationId,
    type,
    body,
    mediaJson,
    replyToId,
    forwarded,
    attemptCount,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('client_message_id')) {
      context.handle(
        _clientMessageIdMeta,
        clientMessageId.isAcceptableOrUnknown(
          data['client_message_id']!,
          _clientMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientMessageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('media_json')) {
      context.handle(
        _mediaJsonMeta,
        mediaJson.isAcceptableOrUnknown(data['media_json']!, _mediaJsonMeta),
      );
    }
    if (data.containsKey('reply_to_id')) {
      context.handle(
        _replyToIdMeta,
        replyToId.isAcceptableOrUnknown(data['reply_to_id']!, _replyToIdMeta),
      );
    }
    if (data.containsKey('forwarded')) {
      context.handle(
        _forwardedMeta,
        forwarded.isAcceptableOrUnknown(data['forwarded']!, _forwardedMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      clientMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      mediaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_json'],
      ),
      replyToId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply_to_id'],
      ),
      forwarded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}forwarded'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxMessagesTable createAlias(String alias) {
    return $OutboxMessagesTable(attachedDatabase, alias);
  }
}

class OutboxMessage extends DataClass implements Insertable<OutboxMessage> {
  final String id;

  /// Account this queued send belongs to.
  ///
  /// Without it, an unsent message composed by one account is flushed by the
  /// next account to sign in — sent under their identity, into the first
  /// account's conversation.
  final String ownerId;
  final String clientMessageId;
  final String conversationId;
  final String type;
  final String? body;
  final String? mediaJson;

  /// Message this one replies to.
  ///
  /// Has to survive the queue: the reply target is chosen in the UI and the
  /// message is written to the outbox before the network call, so a column is
  /// the only place it can live in between. Without it a reply sent while
  /// offline reached the other side as an unanchored message.
  final String? replyToId;

  /// Forwarded marker, carried through the queue for the same reason as
  /// [replyToId]: the value is decided in the UI and the row is written before
  /// the network call.
  final bool forwarded;
  final int attemptCount;
  final int status;
  final DateTime createdAt;
  const OutboxMessage({
    required this.id,
    required this.ownerId,
    required this.clientMessageId,
    required this.conversationId,
    required this.type,
    this.body,
    this.mediaJson,
    this.replyToId,
    required this.forwarded,
    required this.attemptCount,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['client_message_id'] = Variable<String>(clientMessageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || mediaJson != null) {
      map['media_json'] = Variable<String>(mediaJson);
    }
    if (!nullToAbsent || replyToId != null) {
      map['reply_to_id'] = Variable<String>(replyToId);
    }
    map['forwarded'] = Variable<bool>(forwarded);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['status'] = Variable<int>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxMessagesCompanion toCompanion(bool nullToAbsent) {
    return OutboxMessagesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      clientMessageId: Value(clientMessageId),
      conversationId: Value(conversationId),
      type: Value(type),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      mediaJson: mediaJson == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaJson),
      replyToId: replyToId == null && nullToAbsent
          ? const Value.absent()
          : Value(replyToId),
      forwarded: Value(forwarded),
      attemptCount: Value(attemptCount),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxMessage(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      clientMessageId: serializer.fromJson<String>(json['clientMessageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      type: serializer.fromJson<String>(json['type']),
      body: serializer.fromJson<String?>(json['body']),
      mediaJson: serializer.fromJson<String?>(json['mediaJson']),
      replyToId: serializer.fromJson<String?>(json['replyToId']),
      forwarded: serializer.fromJson<bool>(json['forwarded']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      status: serializer.fromJson<int>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'clientMessageId': serializer.toJson<String>(clientMessageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'type': serializer.toJson<String>(type),
      'body': serializer.toJson<String?>(body),
      'mediaJson': serializer.toJson<String?>(mediaJson),
      'replyToId': serializer.toJson<String?>(replyToId),
      'forwarded': serializer.toJson<bool>(forwarded),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'status': serializer.toJson<int>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxMessage copyWith({
    String? id,
    String? ownerId,
    String? clientMessageId,
    String? conversationId,
    String? type,
    Value<String?> body = const Value.absent(),
    Value<String?> mediaJson = const Value.absent(),
    Value<String?> replyToId = const Value.absent(),
    bool? forwarded,
    int? attemptCount,
    int? status,
    DateTime? createdAt,
  }) => OutboxMessage(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    clientMessageId: clientMessageId ?? this.clientMessageId,
    conversationId: conversationId ?? this.conversationId,
    type: type ?? this.type,
    body: body.present ? body.value : this.body,
    mediaJson: mediaJson.present ? mediaJson.value : this.mediaJson,
    replyToId: replyToId.present ? replyToId.value : this.replyToId,
    forwarded: forwarded ?? this.forwarded,
    attemptCount: attemptCount ?? this.attemptCount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxMessage copyWithCompanion(OutboxMessagesCompanion data) {
    return OutboxMessage(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      clientMessageId: data.clientMessageId.present
          ? data.clientMessageId.value
          : this.clientMessageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      type: data.type.present ? data.type.value : this.type,
      body: data.body.present ? data.body.value : this.body,
      mediaJson: data.mediaJson.present ? data.mediaJson.value : this.mediaJson,
      replyToId: data.replyToId.present ? data.replyToId.value : this.replyToId,
      forwarded: data.forwarded.present ? data.forwarded.value : this.forwarded,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessage(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwarded: $forwarded, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    clientMessageId,
    conversationId,
    type,
    body,
    mediaJson,
    replyToId,
    forwarded,
    attemptCount,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxMessage &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.clientMessageId == this.clientMessageId &&
          other.conversationId == this.conversationId &&
          other.type == this.type &&
          other.body == this.body &&
          other.mediaJson == this.mediaJson &&
          other.replyToId == this.replyToId &&
          other.forwarded == this.forwarded &&
          other.attemptCount == this.attemptCount &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class OutboxMessagesCompanion extends UpdateCompanion<OutboxMessage> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> clientMessageId;
  final Value<String> conversationId;
  final Value<String> type;
  final Value<String?> body;
  final Value<String?> mediaJson;
  final Value<String?> replyToId;
  final Value<bool> forwarded;
  final Value<int> attemptCount;
  final Value<int> status;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxMessagesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.clientMessageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.type = const Value.absent(),
    this.body = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.forwarded = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxMessagesCompanion.insert({
    required String id,
    this.ownerId = const Value.absent(),
    required String clientMessageId,
    required String conversationId,
    this.type = const Value.absent(),
    this.body = const Value.absent(),
    this.mediaJson = const Value.absent(),
    this.replyToId = const Value.absent(),
    this.forwarded = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       clientMessageId = Value(clientMessageId),
       conversationId = Value(conversationId),
       createdAt = Value(createdAt);
  static Insertable<OutboxMessage> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? clientMessageId,
    Expression<String>? conversationId,
    Expression<String>? type,
    Expression<String>? body,
    Expression<String>? mediaJson,
    Expression<String>? replyToId,
    Expression<bool>? forwarded,
    Expression<int>? attemptCount,
    Expression<int>? status,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (type != null) 'type': type,
      if (body != null) 'body': body,
      if (mediaJson != null) 'media_json': mediaJson,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (forwarded != null) 'forwarded': forwarded,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? clientMessageId,
    Value<String>? conversationId,
    Value<String>? type,
    Value<String?>? body,
    Value<String?>? mediaJson,
    Value<String?>? replyToId,
    Value<bool>? forwarded,
    Value<int>? attemptCount,
    Value<int>? status,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxMessagesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      conversationId: conversationId ?? this.conversationId,
      type: type ?? this.type,
      body: body ?? this.body,
      mediaJson: mediaJson ?? this.mediaJson,
      replyToId: replyToId ?? this.replyToId,
      forwarded: forwarded ?? this.forwarded,
      attemptCount: attemptCount ?? this.attemptCount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (clientMessageId.present) {
      map['client_message_id'] = Variable<String>(clientMessageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (mediaJson.present) {
      map['media_json'] = Variable<String>(mediaJson.value);
    }
    if (replyToId.present) {
      map['reply_to_id'] = Variable<String>(replyToId.value);
    }
    if (forwarded.present) {
      map['forwarded'] = Variable<bool>(forwarded.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxMessagesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('type: $type, ')
          ..write('body: $body, ')
          ..write('mediaJson: $mediaJson, ')
          ..write('replyToId: $replyToId, ')
          ..write('forwarded: $forwarded, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageReactionsOutboxTable extends MessageReactionsOutbox
    with TableInfo<$MessageReactionsOutboxTable, MessageReactionsOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageReactionsOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    emoji,
    attemptCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_reactions_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageReactionsOutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, emoji};
  @override
  MessageReactionsOutboxData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageReactionsOutboxData(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MessageReactionsOutboxTable createAlias(String alias) {
    return $MessageReactionsOutboxTable(attachedDatabase, alias);
  }
}

class MessageReactionsOutboxData extends DataClass
    implements Insertable<MessageReactionsOutboxData> {
  final String messageId;
  final String emoji;
  final int attemptCount;
  final DateTime createdAt;
  const MessageReactionsOutboxData({
    required this.messageId,
    required this.emoji,
    required this.attemptCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['emoji'] = Variable<String>(emoji);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MessageReactionsOutboxCompanion toCompanion(bool nullToAbsent) {
    return MessageReactionsOutboxCompanion(
      messageId: Value(messageId),
      emoji: Value(emoji),
      attemptCount: Value(attemptCount),
      createdAt: Value(createdAt),
    );
  }

  factory MessageReactionsOutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageReactionsOutboxData(
      messageId: serializer.fromJson<String>(json['messageId']),
      emoji: serializer.fromJson<String>(json['emoji']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'emoji': serializer.toJson<String>(emoji),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MessageReactionsOutboxData copyWith({
    String? messageId,
    String? emoji,
    int? attemptCount,
    DateTime? createdAt,
  }) => MessageReactionsOutboxData(
    messageId: messageId ?? this.messageId,
    emoji: emoji ?? this.emoji,
    attemptCount: attemptCount ?? this.attemptCount,
    createdAt: createdAt ?? this.createdAt,
  );
  MessageReactionsOutboxData copyWithCompanion(
    MessageReactionsOutboxCompanion data,
  ) {
    return MessageReactionsOutboxData(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageReactionsOutboxData(')
          ..write('messageId: $messageId, ')
          ..write('emoji: $emoji, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, emoji, attemptCount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageReactionsOutboxData &&
          other.messageId == this.messageId &&
          other.emoji == this.emoji &&
          other.attemptCount == this.attemptCount &&
          other.createdAt == this.createdAt);
}

class MessageReactionsOutboxCompanion
    extends UpdateCompanion<MessageReactionsOutboxData> {
  final Value<String> messageId;
  final Value<String> emoji;
  final Value<int> attemptCount;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const MessageReactionsOutboxCompanion({
    this.messageId = const Value.absent(),
    this.emoji = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageReactionsOutboxCompanion.insert({
    required String messageId,
    required String emoji,
    this.attemptCount = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       emoji = Value(emoji),
       createdAt = Value(createdAt);
  static Insertable<MessageReactionsOutboxData> custom({
    Expression<String>? messageId,
    Expression<String>? emoji,
    Expression<int>? attemptCount,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (emoji != null) 'emoji': emoji,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageReactionsOutboxCompanion copyWith({
    Value<String>? messageId,
    Value<String>? emoji,
    Value<int>? attemptCount,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return MessageReactionsOutboxCompanion(
      messageId: messageId ?? this.messageId,
      emoji: emoji ?? this.emoji,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageReactionsOutboxCompanion(')
          ..write('messageId: $messageId, ')
          ..write('emoji: $emoji, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeviceSyncCursorsTable extends DeviceSyncCursors
    with TableInfo<$DeviceSyncCursorsTable, DeviceSyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceSyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, cursor, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceSyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  DeviceSyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceSyncCursor(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DeviceSyncCursorsTable createAlias(String alias) {
    return $DeviceSyncCursorsTable(attachedDatabase, alias);
  }
}

class DeviceSyncCursor extends DataClass
    implements Insertable<DeviceSyncCursor> {
  final String key;
  final String? cursor;
  final DateTime? updatedAt;
  const DeviceSyncCursor({required this.key, this.cursor, this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DeviceSyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return DeviceSyncCursorsCompanion(
      key: Value(key),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DeviceSyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceSyncCursor(
      key: serializer.fromJson<String>(json['key']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'cursor': serializer.toJson<String?>(cursor),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  DeviceSyncCursor copyWith({
    String? key,
    Value<String?> cursor = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => DeviceSyncCursor(
    key: key ?? this.key,
    cursor: cursor.present ? cursor.value : this.cursor,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DeviceSyncCursor copyWithCompanion(DeviceSyncCursorsCompanion data) {
    return DeviceSyncCursor(
      key: data.key.present ? data.key.value : this.key,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSyncCursor(')
          ..write('key: $key, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, cursor, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceSyncCursor &&
          other.key == this.key &&
          other.cursor == this.cursor &&
          other.updatedAt == this.updatedAt);
}

class DeviceSyncCursorsCompanion extends UpdateCompanion<DeviceSyncCursor> {
  final Value<String> key;
  final Value<String?> cursor;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const DeviceSyncCursorsCompanion({
    this.key = const Value.absent(),
    this.cursor = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceSyncCursorsCompanion.insert({
    required String key,
    this.cursor = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<DeviceSyncCursor> custom({
    Expression<String>? key,
    Expression<String>? cursor,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (cursor != null) 'cursor': cursor,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceSyncCursorsCompanion copyWith({
    Value<String>? key,
    Value<String?>? cursor,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DeviceSyncCursorsCompanion(
      key: key ?? this.key,
      cursor: cursor ?? this.cursor,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceSyncCursorsCompanion(')
          ..write('key: $key, ')
          ..write('cursor: $cursor, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String key;
  final String? value;
  final DateTime? updatedAt;
  const SyncStateData({required this.key, this.value, this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  SyncStateData copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => SyncStateData(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<SyncStateData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}


    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta(
    'settingsJson',
  );
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [userId, settingsJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(
          data['settings_json']!,
          _settingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final String userId;
  final String? settingsJson;
  final DateTime? updatedAt;
  const UserSetting({required this.userId, this.settingsJson, this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || settingsJson != null) {
      map['settings_json'] = Variable<String>(settingsJson);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      userId: Value(userId),
      settingsJson: settingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(settingsJson),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory UserSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      userId: serializer.fromJson<String>(json['userId']),
      settingsJson: serializer.fromJson<String?>(json['settingsJson']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'settingsJson': serializer.toJson<String?>(settingsJson),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  UserSetting copyWith({
    String? userId,
    Value<String?> settingsJson = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => UserSetting(
    userId: userId ?? this.userId,
    settingsJson: settingsJson.present ? settingsJson.value : this.settingsJson,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      userId: data.userId.present ? data.userId.value : this.userId,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('userId: $userId, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(userId, settingsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.userId == this.userId &&
          other.settingsJson == this.settingsJson &&
          other.updatedAt == this.updatedAt);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<String> userId;
  final Value<String?> settingsJson;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const UserSettingsCompanion({
    this.userId = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    required String userId,
    this.settingsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : userId = Value(userId);
  static Insertable<UserSetting> custom({
    Expression<String>? userId,
    Expression<String>? settingsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsCompanion copyWith({
    Value<String>? userId,
    Value<String?>? settingsJson,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserSettingsCompanion(
      userId: userId ?? this.userId,
      settingsJson: settingsJson ?? this.settingsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('userId: $userId, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorIdMeta = const VerificationMeta(
    'authorId',
  );
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
    'author_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _viewCountMeta = const VerificationMeta(
    'viewCount',
  );
  @override
  late final GeneratedColumn<int> viewCount = GeneratedColumn<int>(
    'view_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _viewedByMeMeta = const VerificationMeta(
    'viewedByMe',
  );
  @override
  late final GeneratedColumn<bool> viewedByMe = GeneratedColumn<bool>(
    'viewed_by_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("viewed_by_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    authorId,
    content,
    mediaUrl,
    mediaType,
    caption,
    createdAt,
    expiresAt,
    viewCount,
    viewedByMe,
    syncedAt,
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
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(
        _authorIdMeta,
        authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('media_url')) {
      context.handle(
        _mediaUrlMeta,
        mediaUrl.isAcceptableOrUnknown(data['media_url']!, _mediaUrlMeta),
      );
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
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
    if (data.containsKey('view_count')) {
      context.handle(
        _viewCountMeta,
        viewCount.isAcceptableOrUnknown(data['view_count']!, _viewCountMeta),
      );
    }
    if (data.containsKey('viewed_by_me')) {
      context.handle(
        _viewedByMeMeta,
        viewedByMe.isAcceptableOrUnknown(
          data['viewed_by_me']!,
          _viewedByMeMeta,
        ),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalStatuse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStatuse(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      authorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      ),
      mediaUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_url'],
      ),
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      ),
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      viewCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}view_count'],
      )!,
      viewedByMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}viewed_by_me'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $LocalStatusesTable createAlias(String alias) {
    return $LocalStatusesTable(attachedDatabase, alias);
  }
}

class LocalStatuse extends DataClass implements Insertable<LocalStatuse> {
  final String id;
  final String authorId;
  final String? content;
  final String? mediaUrl;
  final String? mediaType;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final bool viewedByMe;
  final DateTime? syncedAt;
  const LocalStatuse({
    required this.id,
    required this.authorId,
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    required this.viewCount,
    required this.viewedByMe,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['author_id'] = Variable<String>(authorId);
    if (!nullToAbsent || content != null) {
      map['content'] = Variable<String>(content);
    }
    if (!nullToAbsent || mediaUrl != null) {
      map['media_url'] = Variable<String>(mediaUrl);
    }
    if (!nullToAbsent || mediaType != null) {
      map['media_type'] = Variable<String>(mediaType);
    }
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['view_count'] = Variable<int>(viewCount);
    map['viewed_by_me'] = Variable<bool>(viewedByMe);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  LocalStatusesCompanion toCompanion(bool nullToAbsent) {
    return LocalStatusesCompanion(
      id: Value(id),
      authorId: Value(authorId),
      content: content == null && nullToAbsent
          ? const Value.absent()
          : Value(content),
      mediaUrl: mediaUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaUrl),
      mediaType: mediaType == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaType),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      viewCount: Value(viewCount),
      viewedByMe: Value(viewedByMe),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory LocalStatuse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStatuse(
      id: serializer.fromJson<String>(json['id']),
      authorId: serializer.fromJson<String>(json['authorId']),
      content: serializer.fromJson<String?>(json['content']),
      mediaUrl: serializer.fromJson<String?>(json['mediaUrl']),
      mediaType: serializer.fromJson<String?>(json['mediaType']),
      caption: serializer.fromJson<String?>(json['caption']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      viewCount: serializer.fromJson<int>(json['viewCount']),
      viewedByMe: serializer.fromJson<bool>(json['viewedByMe']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'authorId': serializer.toJson<String>(authorId),
      'content': serializer.toJson<String?>(content),
      'mediaUrl': serializer.toJson<String?>(mediaUrl),
      'mediaType': serializer.toJson<String?>(mediaType),
      'caption': serializer.toJson<String?>(caption),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'viewCount': serializer.toJson<int>(viewCount),
      'viewedByMe': serializer.toJson<bool>(viewedByMe),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  LocalStatuse copyWith({
    String? id,
    String? authorId,
    Value<String?> content = const Value.absent(),
    Value<String?> mediaUrl = const Value.absent(),
    Value<String?> mediaType = const Value.absent(),
    Value<String?> caption = const Value.absent(),
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    bool? viewedByMe,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => LocalStatuse(
    id: id ?? this.id,
    authorId: authorId ?? this.authorId,
    content: content.present ? content.value : this.content,
    mediaUrl: mediaUrl.present ? mediaUrl.value : this.mediaUrl,
    mediaType: mediaType.present ? mediaType.value : this.mediaType,
    caption: caption.present ? caption.value : this.caption,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    viewCount: viewCount ?? this.viewCount,
    viewedByMe: viewedByMe ?? this.viewedByMe,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  LocalStatuse copyWithCompanion(LocalStatusesCompanion data) {
    return LocalStatuse(
      id: data.id.present ? data.id.value : this.id,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      content: data.content.present ? data.content.value : this.content,
      mediaUrl: data.mediaUrl.present ? data.mediaUrl.value : this.mediaUrl,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      caption: data.caption.present ? data.caption.value : this.caption,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      viewCount: data.viewCount.present ? data.viewCount.value : this.viewCount,
      viewedByMe: data.viewedByMe.present
          ? data.viewedByMe.value
          : this.viewedByMe,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStatuse(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('content: $content, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaType: $mediaType, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('viewCount: $viewCount, ')
          ..write('viewedByMe: $viewedByMe, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    authorId,
    content,
    mediaUrl,
    mediaType,
    caption,
    createdAt,
    expiresAt,
    viewCount,
    viewedByMe,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStatuse &&
          other.id == this.id &&
          other.authorId == this.authorId &&
          other.content == this.content &&
          other.mediaUrl == this.mediaUrl &&
          other.mediaType == this.mediaType &&
          other.caption == this.caption &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.viewCount == this.viewCount &&
          other.viewedByMe == this.viewedByMe &&
          other.syncedAt == this.syncedAt);
}

class LocalStatusesCompanion extends UpdateCompanion<LocalStatuse> {
  final Value<String> id;
  final Value<String> authorId;
  final Value<String?> content;
  final Value<String?> mediaUrl;
  final Value<String?> mediaType;
  final Value<String?> caption;
  final Value<DateTime> createdAt;
  final Value<DateTime> expiresAt;
  final Value<int> viewCount;
  final Value<bool> viewedByMe;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const LocalStatusesCompanion({
    this.id = const Value.absent(),
    this.authorId = const Value.absent(),
    this.content = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.caption = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.viewCount = const Value.absent(),
    this.viewedByMe = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStatusesCompanion.insert({
    required String id,
    required String authorId,
    this.content = const Value.absent(),
    this.mediaUrl = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.caption = const Value.absent(),
    required DateTime createdAt,
    required DateTime expiresAt,
    this.viewCount = const Value.absent(),
    this.viewedByMe = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       authorId = Value(authorId),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt);
  static Insertable<LocalStatuse> custom({
    Expression<String>? id,
    Expression<String>? authorId,
    Expression<String>? content,
    Expression<String>? mediaUrl,
    Expression<String>? mediaType,
    Expression<String>? caption,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? expiresAt,
    Expression<int>? viewCount,
    Expression<bool>? viewedByMe,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (authorId != null) 'author_id': authorId,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (mediaType != null) 'media_type': mediaType,
      if (caption != null) 'caption': caption,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (viewCount != null) 'view_count': viewCount,
      if (viewedByMe != null) 'viewed_by_me': viewedByMe,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStatusesCompanion copyWith({
    Value<String>? id,
    Value<String>? authorId,
    Value<String?>? content,
    Value<String?>? mediaUrl,
    Value<String?>? mediaType,
    Value<String?>? caption,
    Value<DateTime>? createdAt,
    Value<DateTime>? expiresAt,
    Value<int>? viewCount,
    Value<bool>? viewedByMe,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return LocalStatusesCompanion(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewCount: viewCount ?? this.viewCount,
      viewedByMe: viewedByMe ?? this.viewedByMe,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (mediaUrl.present) {
      map['media_url'] = Variable<String>(mediaUrl.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (viewCount.present) {
      map['view_count'] = Variable<int>(viewCount.value);
    }
    if (viewedByMe.present) {
      map['viewed_by_me'] = Variable<bool>(viewedByMe.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStatusesCompanion(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('content: $content, ')
          ..write('mediaUrl: $mediaUrl, ')
          ..write('mediaType: $mediaType, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('viewCount: $viewCount, ')
          ..write('viewedByMe: $viewedByMe, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalStatusViewsTable extends LocalStatusViews
    with TableInfo<$LocalStatusViewsTable, LocalStatusView> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalStatusViewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusIdMeta = const VerificationMeta(
    'statusId',
  );
  @override
  late final GeneratedColumn<String> statusId = GeneratedColumn<String>(
    'status_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viewerIdMeta = const VerificationMeta(
    'viewerId',
  );
  @override
  late final GeneratedColumn<String> viewerId = GeneratedColumn<String>(
    'viewer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _viewerNameMeta = const VerificationMeta(
    'viewerName',
  );
  @override
  late final GeneratedColumn<String> viewerName = GeneratedColumn<String>(
    'viewer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _viewedAtMeta = const VerificationMeta(
    'viewedAt',
  );
  @override
  late final GeneratedColumn<DateTime> viewedAt = GeneratedColumn<DateTime>(
    'viewed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    statusId,
    viewerId,
    viewerName,
    viewedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_status_views';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalStatusView> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status_id')) {
      context.handle(
        _statusIdMeta,
        statusId.isAcceptableOrUnknown(data['status_id']!, _statusIdMeta),
      );
    } else if (isInserting) {
      context.missing(_statusIdMeta);
    }
    if (data.containsKey('viewer_id')) {
      context.handle(
        _viewerIdMeta,
        viewerId.isAcceptableOrUnknown(data['viewer_id']!, _viewerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_viewerIdMeta);
    }
    if (data.containsKey('viewer_name')) {
      context.handle(
        _viewerNameMeta,
        viewerName.isAcceptableOrUnknown(data['viewer_name']!, _viewerNameMeta),
      );
    }
    if (data.containsKey('viewed_at')) {
      context.handle(
        _viewedAtMeta,
        viewedAt.isAcceptableOrUnknown(data['viewed_at']!, _viewedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_viewedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalStatusView map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalStatusView(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      statusId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_id'],
      )!,
      viewerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viewer_id'],
      )!,
      viewerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}viewer_name'],
      ),
      viewedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}viewed_at'],
      )!,
    );
  }

  @override
  $LocalStatusViewsTable createAlias(String alias) {
    return $LocalStatusViewsTable(attachedDatabase, alias);
  }
}

class LocalStatusView extends DataClass implements Insertable<LocalStatusView> {
  final String id;
  final String statusId;
  final String viewerId;
  final String? viewerName;
  final DateTime viewedAt;
  const LocalStatusView({
    required this.id,
    required this.statusId,
    required this.viewerId,
    this.viewerName,
    required this.viewedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status_id'] = Variable<String>(statusId);
    map['viewer_id'] = Variable<String>(viewerId);
    if (!nullToAbsent || viewerName != null) {
      map['viewer_name'] = Variable<String>(viewerName);
    }
    map['viewed_at'] = Variable<DateTime>(viewedAt);
    return map;
  }

  LocalStatusViewsCompanion toCompanion(bool nullToAbsent) {
    return LocalStatusViewsCompanion(
      id: Value(id),
      statusId: Value(statusId),
      viewerId: Value(viewerId),
      viewerName: viewerName == null && nullToAbsent
          ? const Value.absent()
          : Value(viewerName),
      viewedAt: Value(viewedAt),
    );
  }

  factory LocalStatusView.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalStatusView(
      id: serializer.fromJson<String>(json['id']),
      statusId: serializer.fromJson<String>(json['statusId']),
      viewerId: serializer.fromJson<String>(json['viewerId']),
      viewerName: serializer.fromJson<String?>(json['viewerName']),
      viewedAt: serializer.fromJson<DateTime>(json['viewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'statusId': serializer.toJson<String>(statusId),
      'viewerId': serializer.toJson<String>(viewerId),
      'viewerName': serializer.toJson<String?>(viewerName),
      'viewedAt': serializer.toJson<DateTime>(viewedAt),
    };
  }

  LocalStatusView copyWith({
    String? id,
    String? statusId,
    String? viewerId,
    Value<String?> viewerName = const Value.absent(),
    DateTime? viewedAt,
  }) => LocalStatusView(
    id: id ?? this.id,
    statusId: statusId ?? this.statusId,
    viewerId: viewerId ?? this.viewerId,
    viewerName: viewerName.present ? viewerName.value : this.viewerName,
    viewedAt: viewedAt ?? this.viewedAt,
  );
  LocalStatusView copyWithCompanion(LocalStatusViewsCompanion data) {
    return LocalStatusView(
      id: data.id.present ? data.id.value : this.id,
      statusId: data.statusId.present ? data.statusId.value : this.statusId,
      viewerId: data.viewerId.present ? data.viewerId.value : this.viewerId,
      viewerName: data.viewerName.present
          ? data.viewerName.value
          : this.viewerName,
      viewedAt: data.viewedAt.present ? data.viewedAt.value : this.viewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalStatusView(')
          ..write('id: $id, ')
          ..write('statusId: $statusId, ')
          ..write('viewerId: $viewerId, ')
          ..write('viewerName: $viewerName, ')
          ..write('viewedAt: $viewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, statusId, viewerId, viewerName, viewedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalStatusView &&
          other.id == this.id &&
          other.statusId == this.statusId &&
          other.viewerId == this.viewerId &&
          other.viewerName == this.viewerName &&
          other.viewedAt == this.viewedAt);
}

class LocalStatusViewsCompanion extends UpdateCompanion<LocalStatusView> {
  final Value<String> id;
  final Value<String> statusId;
  final Value<String> viewerId;
  final Value<String?> viewerName;
  final Value<DateTime> viewedAt;
  final Value<int> rowid;
  const LocalStatusViewsCompanion({
    this.id = const Value.absent(),
    this.statusId = const Value.absent(),
    this.viewerId = const Value.absent(),
    this.viewerName = const Value.absent(),
    this.viewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalStatusViewsCompanion.insert({
    required String id,
    required String statusId,
    required String viewerId,
    this.viewerName = const Value.absent(),
    required DateTime viewedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       statusId = Value(statusId),
       viewerId = Value(viewerId),
       viewedAt = Value(viewedAt);
  static Insertable<LocalStatusView> custom({
    Expression<String>? id,
    Expression<String>? statusId,
    Expression<String>? viewerId,
    Expression<String>? viewerName,
    Expression<DateTime>? viewedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (statusId != null) 'status_id': statusId,
      if (viewerId != null) 'viewer_id': viewerId,
      if (viewerName != null) 'viewer_name': viewerName,
      if (viewedAt != null) 'viewed_at': viewedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalStatusViewsCompanion copyWith({
    Value<String>? id,
    Value<String>? statusId,
    Value<String>? viewerId,
    Value<String?>? viewerName,
    Value<DateTime>? viewedAt,
    Value<int>? rowid,
  }) {
    return LocalStatusViewsCompanion(
      id: id ?? this.id,
      statusId: statusId ?? this.statusId,
      viewerId: viewerId ?? this.viewerId,
      viewerName: viewerName ?? this.viewerName,
      viewedAt: viewedAt ?? this.viewedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (statusId.present) {
      map['status_id'] = Variable<String>(statusId.value);
    }
    if (viewerId.present) {
      map['viewer_id'] = Variable<String>(viewerId.value);
    }
    if (viewerName.present) {
      map['viewer_name'] = Variable<String>(viewerName.value);
    }
    if (viewedAt.present) {
      map['viewed_at'] = Variable<DateTime>(viewedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalStatusViewsCompanion(')
          ..write('id: $id, ')
          ..write('statusId: $statusId, ')
          ..write('viewerId: $viewerId, ')
          ..write('viewerName: $viewerName, ')
          ..write('viewedAt: $viewedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessageTombstonesTable extends MessageTombstones
    with TableInfo<$MessageTombstonesTable, MessageTombstone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessageTombstonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('everyone'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadVersionMeta = const VerificationMeta(
    'payloadVersion',
  );
  @override
  late final GeneratedColumn<int> payloadVersion = GeneratedColumn<int>(
    'payload_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    conversationId,
    scope,
    deletedAt,
    payloadVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'message_tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageTombstone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    if (data.containsKey('payload_version')) {
      context.handle(
        _payloadVersionMeta,
        payloadVersion.isAcceptableOrUnknown(
          data['payload_version']!,
          _payloadVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId};
  @override
  MessageTombstone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageTombstone(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      )!,
      payloadVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_version'],
      )!,
    );
  }

  @override
  $MessageTombstonesTable createAlias(String alias) {
    return $MessageTombstonesTable(attachedDatabase, alias);
  }
}

class MessageTombstone extends DataClass
    implements Insertable<MessageTombstone> {
  final String ownerId;
  final String messageId;
  final String conversationId;
  final String scope;
  final DateTime deletedAt;
  final int payloadVersion;
  const MessageTombstone({
    required this.ownerId,
    required this.messageId,
    required this.conversationId,
    required this.scope,
    required this.deletedAt,
    required this.payloadVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['scope'] = Variable<String>(scope);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    map['payload_version'] = Variable<int>(payloadVersion);
    return map;
  }

  MessageTombstonesCompanion toCompanion(bool nullToAbsent) {
    return MessageTombstonesCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      conversationId: Value(conversationId),
      scope: Value(scope),
      deletedAt: Value(deletedAt),
      payloadVersion: Value(payloadVersion),
    );
  }

  factory MessageTombstone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageTombstone(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      scope: serializer.fromJson<String>(json['scope']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
      payloadVersion: serializer.fromJson<int>(json['payloadVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'conversationId': serializer.toJson<String>(conversationId),
      'scope': serializer.toJson<String>(scope),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
      'payloadVersion': serializer.toJson<int>(payloadVersion),
    };
  }

  MessageTombstone copyWith({
    String? ownerId,
    String? messageId,
    String? conversationId,
    String? scope,
    DateTime? deletedAt,
    int? payloadVersion,
  }) => MessageTombstone(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    conversationId: conversationId ?? this.conversationId,
    scope: scope ?? this.scope,
    deletedAt: deletedAt ?? this.deletedAt,
    payloadVersion: payloadVersion ?? this.payloadVersion,
  );
  MessageTombstone copyWithCompanion(MessageTombstonesCompanion data) {
    return MessageTombstone(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      scope: data.scope.present ? data.scope.value : this.scope,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      payloadVersion: data.payloadVersion.present
          ? data.payloadVersion.value
          : this.payloadVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageTombstone(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('scope: $scope, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('payloadVersion: $payloadVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ownerId,
    messageId,
    conversationId,
    scope,
    deletedAt,
    payloadVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageTombstone &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.conversationId == this.conversationId &&
          other.scope == this.scope &&
          other.deletedAt == this.deletedAt &&
          other.payloadVersion == this.payloadVersion);
}

class MessageTombstonesCompanion extends UpdateCompanion<MessageTombstone> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> conversationId;
  final Value<String> scope;
  final Value<DateTime> deletedAt;
  final Value<int> payloadVersion;
  final Value<int> rowid;
  const MessageTombstonesCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.scope = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.payloadVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessageTombstonesCompanion.insert({
    this.ownerId = const Value.absent(),
    required String messageId,
    required String conversationId,
    this.scope = const Value.absent(),
    required DateTime deletedAt,
    this.payloadVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       conversationId = Value(conversationId),
       deletedAt = Value(deletedAt);
  static Insertable<MessageTombstone> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? conversationId,
    Expression<String>? scope,
    Expression<DateTime>? deletedAt,
    Expression<int>? payloadVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (scope != null) 'scope': scope,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (payloadVersion != null) 'payload_version': payloadVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessageTombstonesCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? conversationId,
    Value<String>? scope,
    Value<DateTime>? deletedAt,
    Value<int>? payloadVersion,
    Value<int>? rowid,
  }) {
    return MessageTombstonesCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      scope: scope ?? this.scope,
      deletedAt: deletedAt ?? this.deletedAt,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (payloadVersion.present) {
      map['payload_version'] = Variable<int>(payloadVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessageTombstonesCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('conversationId: $conversationId, ')
          ..write('scope: $scope, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('payloadVersion: $payloadVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeliveryAckLedgerTable extends DeliveryAckLedger
    with TableInfo<$DeliveryAckLedgerTable, DeliveryAckLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveryAckLedgerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _reportedMeta = const VerificationMeta(
    'reported',
  );
  @override
  late final GeneratedColumn<bool> reported = GeneratedColumn<bool>(
    'reported',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reported" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    messageId,
    kind,
    reported,
    attempts,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'delivery_ack_ledger';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeliveryAckLedgerData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('reported')) {
      context.handle(
        _reportedMeta,
        reported.isAcceptableOrUnknown(data['reported']!, _reportedMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, messageId, kind};
  @override
  DeliveryAckLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeliveryAckLedgerData(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      reported: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reported'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DeliveryAckLedgerTable createAlias(String alias) {
    return $DeliveryAckLedgerTable(attachedDatabase, alias);
  }
}

class DeliveryAckLedgerData extends DataClass
    implements Insertable<DeliveryAckLedgerData> {
  final String ownerId;

  /// Server message id. A device acknowledgement is about a relay row, not
  /// about a local draft, so this is the server id specifically.
  final String messageId;

  /// 'delivered' | 'read' — the two receipts are tracked independently.
  final String kind;
  final bool reported;
  final int attempts;
  final DateTime? updatedAt;
  const DeliveryAckLedgerData({
    required this.ownerId,
    required this.messageId,
    required this.kind,
    required this.reported,
    required this.attempts,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['message_id'] = Variable<String>(messageId);
    map['kind'] = Variable<String>(kind);
    map['reported'] = Variable<bool>(reported);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DeliveryAckLedgerCompanion toCompanion(bool nullToAbsent) {
    return DeliveryAckLedgerCompanion(
      ownerId: Value(ownerId),
      messageId: Value(messageId),
      kind: Value(kind),
      reported: Value(reported),
      attempts: Value(attempts),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory DeliveryAckLedgerData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeliveryAckLedgerData(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      kind: serializer.fromJson<String>(json['kind']),
      reported: serializer.fromJson<bool>(json['reported']),
      attempts: serializer.fromJson<int>(json['attempts']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'messageId': serializer.toJson<String>(messageId),
      'kind': serializer.toJson<String>(kind),
      'reported': serializer.toJson<bool>(reported),
      'attempts': serializer.toJson<int>(attempts),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  DeliveryAckLedgerData copyWith({
    String? ownerId,
    String? messageId,
    String? kind,
    bool? reported,
    int? attempts,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => DeliveryAckLedgerData(
    ownerId: ownerId ?? this.ownerId,
    messageId: messageId ?? this.messageId,
    kind: kind ?? this.kind,
    reported: reported ?? this.reported,
    attempts: attempts ?? this.attempts,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  DeliveryAckLedgerData copyWithCompanion(DeliveryAckLedgerCompanion data) {
    return DeliveryAckLedgerData(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      kind: data.kind.present ? data.kind.value : this.kind,
      reported: data.reported.present ? data.reported.value : this.reported,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryAckLedgerData(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('kind: $kind, ')
          ..write('reported: $reported, ')
          ..write('attempts: $attempts, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(ownerId, messageId, kind, reported, attempts, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeliveryAckLedgerData &&
          other.ownerId == this.ownerId &&
          other.messageId == this.messageId &&
          other.kind == this.kind &&
          other.reported == this.reported &&
          other.attempts == this.attempts &&
          other.updatedAt == this.updatedAt);
}

class DeliveryAckLedgerCompanion
    extends UpdateCompanion<DeliveryAckLedgerData> {
  final Value<String> ownerId;
  final Value<String> messageId;
  final Value<String> kind;
  final Value<bool> reported;
  final Value<int> attempts;
  final Value<DateTime?> updatedAt;
  final Value<int> rowid;
  const DeliveryAckLedgerCompanion({
    this.ownerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.kind = const Value.absent(),
    this.reported = const Value.absent(),
    this.attempts = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeliveryAckLedgerCompanion.insert({
    this.ownerId = const Value.absent(),
    required String messageId,
    required String kind,
    this.reported = const Value.absent(),
    this.attempts = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       kind = Value(kind);
  static Insertable<DeliveryAckLedgerData> custom({
    Expression<String>? ownerId,
    Expression<String>? messageId,
    Expression<String>? kind,
    Expression<bool>? reported,
    Expression<int>? attempts,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (messageId != null) 'message_id': messageId,
      if (kind != null) 'kind': kind,
      if (reported != null) 'reported': reported,
      if (attempts != null) 'attempts': attempts,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeliveryAckLedgerCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? messageId,
    Value<String>? kind,
    Value<bool>? reported,
    Value<int>? attempts,
    Value<DateTime?>? updatedAt,
    Value<int>? rowid,
  }) {
    return DeliveryAckLedgerCompanion(
      ownerId: ownerId ?? this.ownerId,
      messageId: messageId ?? this.messageId,
      kind: kind ?? this.kind,
      reported: reported ?? this.reported,
      attempts: attempts ?? this.attempts,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (reported.present) {
      map['reported'] = Variable<bool>(reported.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryAckLedgerCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('messageId: $messageId, ')
          ..write('kind: $kind, ')
          ..write('reported: $reported, ')
          ..write('attempts: $attempts, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeletionCursorsTable extends DeletionCursors
    with TableInfo<$DeletionCursorsTable, DeletionCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeletionCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastDeletedAtMeta = const VerificationMeta(
    'lastDeletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastDeletedAt =
      GeneratedColumn<DateTime>(
        'last_deleted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    conversationId,
    lastDeletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deletion_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeletionCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('last_deleted_at')) {
      context.handle(
        _lastDeletedAtMeta,
        lastDeletedAt.isAcceptableOrUnknown(
          data['last_deleted_at']!,
          _lastDeletedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, conversationId};
  @override
  DeletionCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeletionCursor(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      lastDeletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_deleted_at'],
      ),
    );
  }

  @override
  $DeletionCursorsTable createAlias(String alias) {
    return $DeletionCursorsTable(attachedDatabase, alias);
  }
}

class DeletionCursor extends DataClass implements Insertable<DeletionCursor> {
  final String ownerId;
  final String conversationId;
  final DateTime? lastDeletedAt;
  const DeletionCursor({
    required this.ownerId,
    required this.conversationId,
    this.lastDeletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || lastDeletedAt != null) {
      map['last_deleted_at'] = Variable<DateTime>(lastDeletedAt);
    }
    return map;
  }

  DeletionCursorsCompanion toCompanion(bool nullToAbsent) {
    return DeletionCursorsCompanion(
      ownerId: Value(ownerId),
      conversationId: Value(conversationId),
      lastDeletedAt: lastDeletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDeletedAt),
    );
  }

  factory DeletionCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeletionCursor(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      lastDeletedAt: serializer.fromJson<DateTime?>(json['lastDeletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'conversationId': serializer.toJson<String>(conversationId),
      'lastDeletedAt': serializer.toJson<DateTime?>(lastDeletedAt),
    };
  }

  DeletionCursor copyWith({
    String? ownerId,
    String? conversationId,
    Value<DateTime?> lastDeletedAt = const Value.absent(),
  }) => DeletionCursor(
    ownerId: ownerId ?? this.ownerId,
    conversationId: conversationId ?? this.conversationId,
    lastDeletedAt: lastDeletedAt.present
        ? lastDeletedAt.value
        : this.lastDeletedAt,
  );
  DeletionCursor copyWithCompanion(DeletionCursorsCompanion data) {
    return DeletionCursor(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      lastDeletedAt: data.lastDeletedAt.present
          ? data.lastDeletedAt.value
          : this.lastDeletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeletionCursor(')
          ..write('ownerId: $ownerId, ')
          ..write('conversationId: $conversationId, ')
          ..write('lastDeletedAt: $lastDeletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, conversationId, lastDeletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeletionCursor &&
          other.ownerId == this.ownerId &&
          other.conversationId == this.conversationId &&
          other.lastDeletedAt == this.lastDeletedAt);
}

class DeletionCursorsCompanion extends UpdateCompanion<DeletionCursor> {
  final Value<String> ownerId;
  final Value<String> conversationId;
  final Value<DateTime?> lastDeletedAt;
  final Value<int> rowid;
  const DeletionCursorsCompanion({
    this.ownerId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.lastDeletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeletionCursorsCompanion.insert({
    this.ownerId = const Value.absent(),
    required String conversationId,
    this.lastDeletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId);
  static Insertable<DeletionCursor> custom({
    Expression<String>? ownerId,
    Expression<String>? conversationId,
    Expression<DateTime>? lastDeletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (lastDeletedAt != null) 'last_deleted_at': lastDeletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeletionCursorsCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? conversationId,
    Value<DateTime?>? lastDeletedAt,
    Value<int>? rowid,
  }) {
    return DeletionCursorsCompanion(
      ownerId: ownerId ?? this.ownerId,
      conversationId: conversationId ?? this.conversationId,
      lastDeletedAt: lastDeletedAt ?? this.lastDeletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (lastDeletedAt.present) {
      map['last_deleted_at'] = Variable<DateTime>(lastDeletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeletionCursorsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('conversationId: $conversationId, ')
          ..write('lastDeletedAt: $lastDeletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountScopeClaimsTable extends AccountScopeClaims
    with TableInfo<$AccountScopeClaimsTable, AccountScopeClaim> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountScopeClaimsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta(
    'claimedAt',
  );
  @override
  late final GeneratedColumn<DateTime> claimedAt = GeneratedColumn<DateTime>(
    'claimed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adoptedRowsMeta = const VerificationMeta(
    'adoptedRows',
  );
  @override
  late final GeneratedColumn<int> adoptedRows = GeneratedColumn<int>(
    'adopted_rows',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [ownerId, claimedAt, adoptedRows];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_scope_claims';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountScopeClaim> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_claimedAtMeta);
    }
    if (data.containsKey('adopted_rows')) {
      context.handle(
        _adoptedRowsMeta,
        adoptedRows.isAcceptableOrUnknown(
          data['adopted_rows']!,
          _adoptedRowsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId};
  @override
  AccountScopeClaim map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountScopeClaim(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}claimed_at'],
      )!,
      adoptedRows: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}adopted_rows'],
      )!,
    );
  }

  @override
  $AccountScopeClaimsTable createAlias(String alias) {
    return $AccountScopeClaimsTable(attachedDatabase, alias);
  }
}

class AccountScopeClaim extends DataClass
    implements Insertable<AccountScopeClaim> {
  final String ownerId;
  final DateTime claimedAt;
  final int adoptedRows;
  const AccountScopeClaim({
    required this.ownerId,
    required this.claimedAt,
    required this.adoptedRows,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['claimed_at'] = Variable<DateTime>(claimedAt);
    map['adopted_rows'] = Variable<int>(adoptedRows);
    return map;
  }

  AccountScopeClaimsCompanion toCompanion(bool nullToAbsent) {
    return AccountScopeClaimsCompanion(
      ownerId: Value(ownerId),
      claimedAt: Value(claimedAt),
      adoptedRows: Value(adoptedRows),
    );
  }

  factory AccountScopeClaim.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountScopeClaim(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      claimedAt: serializer.fromJson<DateTime>(json['claimedAt']),
      adoptedRows: serializer.fromJson<int>(json['adoptedRows']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'claimedAt': serializer.toJson<DateTime>(claimedAt),
      'adoptedRows': serializer.toJson<int>(adoptedRows),
    };
  }

  AccountScopeClaim copyWith({
    String? ownerId,
    DateTime? claimedAt,
    int? adoptedRows,
  }) => AccountScopeClaim(
    ownerId: ownerId ?? this.ownerId,
    claimedAt: claimedAt ?? this.claimedAt,
    adoptedRows: adoptedRows ?? this.adoptedRows,
  );
  AccountScopeClaim copyWithCompanion(AccountScopeClaimsCompanion data) {
    return AccountScopeClaim(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
      adoptedRows: data.adoptedRows.present
          ? data.adoptedRows.value
          : this.adoptedRows,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountScopeClaim(')
          ..write('ownerId: $ownerId, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('adoptedRows: $adoptedRows')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, claimedAt, adoptedRows);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountScopeClaim &&
          other.ownerId == this.ownerId &&
          other.claimedAt == this.claimedAt &&
          other.adoptedRows == this.adoptedRows);
}

class AccountScopeClaimsCompanion extends UpdateCompanion<AccountScopeClaim> {
  final Value<String> ownerId;
  final Value<DateTime> claimedAt;
  final Value<int> adoptedRows;
  final Value<int> rowid;
  const AccountScopeClaimsCompanion({
    this.ownerId = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.adoptedRows = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountScopeClaimsCompanion.insert({
    required String ownerId,
    required DateTime claimedAt,
    this.adoptedRows = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ownerId = Value(ownerId),
       claimedAt = Value(claimedAt);
  static Insertable<AccountScopeClaim> custom({
    Expression<String>? ownerId,
    Expression<DateTime>? claimedAt,
    Expression<int>? adoptedRows,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (adoptedRows != null) 'adopted_rows': adoptedRows,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountScopeClaimsCompanion copyWith({
    Value<String>? ownerId,
    Value<DateTime>? claimedAt,
    Value<int>? adoptedRows,
    Value<int>? rowid,
  }) {
    return AccountScopeClaimsCompanion(
      ownerId: ownerId ?? this.ownerId,
      claimedAt: claimedAt ?? this.claimedAt,
      adoptedRows: adoptedRows ?? this.adoptedRows,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<DateTime>(claimedAt.value);
    }
    if (adoptedRows.present) {
      map['adopted_rows'] = Variable<int>(adoptedRows.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountScopeClaimsCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('adoptedRows: $adoptedRows, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalProfilesTable localProfiles = $LocalProfilesTable(this);
  late final $LocalConversationsTable localConversations =
      $LocalConversationsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $OutboxMessagesTable outboxMessages = $OutboxMessagesTable(this);
  late final $MessageReactionsOutboxTable messageReactionsOutbox =
      $MessageReactionsOutboxTable(this);
  late final $DeviceSyncCursorsTable deviceSyncCursors =
      $DeviceSyncCursorsTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  
  late final $LocalStatusesTable localStatuses = $LocalStatusesTable(this);
  late final $LocalStatusViewsTable localStatusViews = $LocalStatusViewsTable(
    this,
  );
  late final $MessageTombstonesTable messageTombstones =
      $MessageTombstonesTable(this);
  late final $DeliveryAckLedgerTable deliveryAckLedger =
      $DeliveryAckLedgerTable(this);
  late final $DeletionCursorsTable deletionCursors = $DeletionCursorsTable(
    this,
  );
  late final $AccountScopeClaimsTable accountScopeClaims =
      $AccountScopeClaimsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localProfiles,
    localConversations,
    localMessages,
    outboxMessages,
    messageReactionsOutbox,
    deviceSyncCursors,
    syncState,
    userSettings,
    localStatuses,
    localStatusViews,
    messageTombstones,
    deliveryAckLedger,
    deletionCursors,
    accountScopeClaims,
  ];
}

typedef $$LocalProfilesTableCreateCompanionBuilder =
    LocalProfilesCompanion Function({
      required String id,
      Value<String?> displayName,
      Value<String?> phone,
      Value<String?> avatarUrl,
      Value<String?> bio,
      Value<String> presence,
      Value<DateTime?> lastSeenAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalProfilesTableUpdateCompanionBuilder =
    LocalProfilesCompanion Function({
      Value<String> id,
      Value<String?> displayName,
      Value<String?> phone,
      Value<String?> avatarUrl,
      Value<String?> bio,
      Value<String> presence,
      Value<DateTime?> lastSeenAt,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$LocalProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bio => $composableBuilder(
    column: $table.bio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presence => $composableBuilder(
    column: $table.presence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
    column: $table.avatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bio => $composableBuilder(
    column: $table.bio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presence => $composableBuilder(
    column: $table.presence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get bio =>
      $composableBuilder(column: $table.bio, builder: (column) => column);

  GeneratedColumn<String> get presence =>
      $composableBuilder(column: $table.presence, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProfilesTable,
          LocalProfile,
          $$LocalProfilesTableFilterComposer,
          $$LocalProfilesTableOrderingComposer,
          $$LocalProfilesTableAnnotationComposer,
          $$LocalProfilesTableCreateCompanionBuilder,
          $$LocalProfilesTableUpdateCompanionBuilder,
          (
            LocalProfile,
            BaseReferences<_$AppDatabase, $LocalProfilesTable, LocalProfile>,
          ),
          LocalProfile,
          PrefetchHooks Function()
        > {
  $$LocalProfilesTableTableManager(_$AppDatabase db, $LocalProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String?> bio = const Value.absent(),
                Value<String> presence = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion(
                id: id,
                displayName: displayName,
                phone: phone,
                avatarUrl: avatarUrl,
                bio: bio,
                presence: presence,
                lastSeenAt: lastSeenAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> displayName = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> avatarUrl = const Value.absent(),
                Value<String?> bio = const Value.absent(),
                Value<String> presence = const Value.absent(),
                Value<DateTime?> lastSeenAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                phone: phone,
                avatarUrl: avatarUrl,
                bio: bio,
                presence: presence,
                lastSeenAt: lastSeenAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProfilesTable,
      LocalProfile,
      $$LocalProfilesTableFilterComposer,
      $$LocalProfilesTableOrderingComposer,
      $$LocalProfilesTableAnnotationComposer,
      $$LocalProfilesTableCreateCompanionBuilder,
      $$LocalProfilesTableUpdateCompanionBuilder,
      (
        LocalProfile,
        BaseReferences<_$AppDatabase, $LocalProfilesTable, LocalProfile>,
      ),
      LocalProfile,
      PrefetchHooks Function()
    >;
typedef $$LocalConversationsTableCreateCompanionBuilder =
    LocalConversationsCompanion Function({
      required String id,
      Value<bool> isGroup,
      Value<String?> peerId,
      Value<String?> peerDisplayName,
      Value<String?> peerAvatarUrl,
      Value<String?> peerPresence,
      Value<DateTime?> peerLastSeenAt,
      Value<String?> displayName,
      Value<String?> memberJson,
      Value<String?> lastMessageId,
      Value<String?> lastMessagePreview,
      Value<String?> lastMessageType,
      Value<String?> lastMessageSenderId,
      Value<DateTime?> lastMessageAt,
      Value<int> unreadCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$LocalConversationsTableUpdateCompanionBuilder =
    LocalConversationsCompanion Function({
      Value<String> id,
      Value<bool> isGroup,
      Value<String?> peerId,
      Value<String?> peerDisplayName,
      Value<String?> peerAvatarUrl,
      Value<String?> peerPresence,
      Value<DateTime?> peerLastSeenAt,
      Value<String?> displayName,
      Value<String?> memberJson,
      Value<String?> lastMessageId,
      Value<String?> lastMessagePreview,
      Value<String?> lastMessageType,
      Value<String?> lastMessageSenderId,
      Value<DateTime?> lastMessageAt,
      Value<int> unreadCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
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
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerDisplayName => $composableBuilder(
    column: $table.peerDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerAvatarUrl => $composableBuilder(
    column: $table.peerAvatarUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerPresence => $composableBuilder(
    column: $table.peerPresence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get peerLastSeenAt => $composableBuilder(
    column: $table.peerLastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberJson => $composableBuilder(
    column: $table.memberJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isGroup => $composableBuilder(
    column: $table.isGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerDisplayName => $composableBuilder(
    column: $table.peerDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerAvatarUrl => $composableBuilder(
    column: $table.peerAvatarUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerPresence => $composableBuilder(
    column: $table.peerPresence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get peerLastSeenAt => $composableBuilder(
    column: $table.peerLastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberJson => $composableBuilder(
    column: $table.memberJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isGroup =>
      $composableBuilder(column: $table.isGroup, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get peerDisplayName => $composableBuilder(
    column: $table.peerDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerAvatarUrl => $composableBuilder(
    column: $table.peerAvatarUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerPresence => $composableBuilder(
    column: $table.peerPresence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get peerLastSeenAt => $composableBuilder(
    column: $table.peerLastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memberJson => $composableBuilder(
    column: $table.memberJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessagePreview => $composableBuilder(
    column: $table.lastMessagePreview,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageType => $composableBuilder(
    column: $table.lastMessageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageSenderId => $composableBuilder(
    column: $table.lastMessageSenderId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastMessageAt => $composableBuilder(
    column: $table.lastMessageAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
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
                Value<String> id = const Value.absent(),
                Value<bool> isGroup = const Value.absent(),
                Value<String?> peerId = const Value.absent(),
                Value<String?> peerDisplayName = const Value.absent(),
                Value<String?> peerAvatarUrl = const Value.absent(),
                Value<String?> peerPresence = const Value.absent(),
                Value<DateTime?> peerLastSeenAt = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> memberJson = const Value.absent(),
                Value<String?> lastMessageId = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<String?> lastMessageType = const Value.absent(),
                Value<String?> lastMessageSenderId = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConversationsCompanion(
                id: id,
                isGroup: isGroup,
                peerId: peerId,
                peerDisplayName: peerDisplayName,
                peerAvatarUrl: peerAvatarUrl,
                peerPresence: peerPresence,
                peerLastSeenAt: peerLastSeenAt,
                displayName: displayName,
                memberJson: memberJson,
                lastMessageId: lastMessageId,
                lastMessagePreview: lastMessagePreview,
                lastMessageType: lastMessageType,
                lastMessageSenderId: lastMessageSenderId,
                lastMessageAt: lastMessageAt,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> isGroup = const Value.absent(),
                Value<String?> peerId = const Value.absent(),
                Value<String?> peerDisplayName = const Value.absent(),
                Value<String?> peerAvatarUrl = const Value.absent(),
                Value<String?> peerPresence = const Value.absent(),
                Value<DateTime?> peerLastSeenAt = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> memberJson = const Value.absent(),
                Value<String?> lastMessageId = const Value.absent(),
                Value<String?> lastMessagePreview = const Value.absent(),
                Value<String?> lastMessageType = const Value.absent(),
                Value<String?> lastMessageSenderId = const Value.absent(),
                Value<DateTime?> lastMessageAt = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalConversationsCompanion.insert(
                id: id,
                isGroup: isGroup,
                peerId: peerId,
                peerDisplayName: peerDisplayName,
                peerAvatarUrl: peerAvatarUrl,
                peerPresence: peerPresence,
                peerLastSeenAt: peerLastSeenAt,
                displayName: displayName,
                memberJson: memberJson,
                lastMessageId: lastMessageId,
                lastMessagePreview: lastMessagePreview,
                lastMessageType: lastMessageType,
                lastMessageSenderId: lastMessageSenderId,
                lastMessageAt: lastMessageAt,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
                rowid: rowid,
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
      required String id,
      required String clientMessageId,
      Value<String> ownerId,
      Value<String?> serverId,
      required String conversationId,
      required String senderId,
      Value<String> type,
      Value<String?> body,
      Value<String?> mediaJson,
      Value<String?> reactionsJson,
      Value<String?> replyToId,
      Value<bool> forwarded,
      Value<String> localState,
      Value<String> remoteStatus,
      required DateTime createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> outgoing,
      Value<bool> deleted,
      Value<DateTime?> deliveredAt,
      Value<DateTime?> readAt,
      Value<DateTime?> serverCreatedAt,
      Value<DateTime?> deletedAt,
      Value<String> retentionState,
      Value<int> schemaVersion,
      Value<int> encryptionVersion,
      Value<int> rowid,
    });
typedef $$LocalMessagesTableUpdateCompanionBuilder =
    LocalMessagesCompanion Function({
      Value<String> id,
      Value<String> clientMessageId,
      Value<String> ownerId,
      Value<String?> serverId,
      Value<String> conversationId,
      Value<String> senderId,
      Value<String> type,
      Value<String?> body,
      Value<String?> mediaJson,
      Value<String?> reactionsJson,
      Value<String?> replyToId,
      Value<bool> forwarded,
      Value<String> localState,
      Value<String> remoteStatus,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<bool> outgoing,
      Value<bool> deleted,
      Value<DateTime?> deliveredAt,
      Value<DateTime?> readAt,
      Value<DateTime?> serverCreatedAt,
      Value<DateTime?> deletedAt,
      Value<String> retentionState,
      Value<int> schemaVersion,
      Value<int> encryptionVersion,
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
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get forwarded => $composableBuilder(
    column: $table.forwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localState => $composableBuilder(
    column: $table.localState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteStatus => $composableBuilder(
    column: $table.remoteStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get outgoing => $composableBuilder(
    column: $table.outgoing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
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

  ColumnFilters<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get retentionState => $composableBuilder(
    column: $table.retentionState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
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
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderId => $composableBuilder(
    column: $table.senderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get forwarded => $composableBuilder(
    column: $table.forwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localState => $composableBuilder(
    column: $table.localState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteStatus => $composableBuilder(
    column: $table.remoteStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get outgoing => $composableBuilder(
    column: $table.outgoing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
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

  ColumnOrderings<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get retentionState => $composableBuilder(
    column: $table.retentionState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get mediaJson =>
      $composableBuilder(column: $table.mediaJson, builder: (column) => column);

  GeneratedColumn<String> get reactionsJson => $composableBuilder(
    column: $table.reactionsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<bool> get forwarded =>
      $composableBuilder(column: $table.forwarded, builder: (column) => column);

  GeneratedColumn<String> get localState => $composableBuilder(
    column: $table.localState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteStatus => $composableBuilder(
    column: $table.remoteStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get outgoing =>
      $composableBuilder(column: $table.outgoing, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deliveredAt => $composableBuilder(
    column: $table.deliveredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get retentionState => $composableBuilder(
    column: $table.retentionState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get encryptionVersion => $composableBuilder(
    column: $table.encryptionVersion,
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
                Value<String> id = const Value.absent(),
                Value<String> clientMessageId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> mediaJson = const Value.absent(),
                Value<String?> reactionsJson = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<bool> forwarded = const Value.absent(),
                Value<String> localState = const Value.absent(),
                Value<String> remoteStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> outgoing = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime?> serverCreatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> retentionState = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion(
                id: id,
                clientMessageId: clientMessageId,
                ownerId: ownerId,
                serverId: serverId,
                conversationId: conversationId,
                senderId: senderId,
                type: type,
                body: body,
                mediaJson: mediaJson,
                reactionsJson: reactionsJson,
                replyToId: replyToId,
                forwarded: forwarded,
                localState: localState,
                remoteStatus: remoteStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                outgoing: outgoing,
                deleted: deleted,
                deliveredAt: deliveredAt,
                readAt: readAt,
                serverCreatedAt: serverCreatedAt,
                deletedAt: deletedAt,
                retentionState: retentionState,
                schemaVersion: schemaVersion,
                encryptionVersion: encryptionVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String clientMessageId,
                Value<String> ownerId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                required String conversationId,
                required String senderId,
                Value<String> type = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> mediaJson = const Value.absent(),
                Value<String?> reactionsJson = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<bool> forwarded = const Value.absent(),
                Value<String> localState = const Value.absent(),
                Value<String> remoteStatus = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> outgoing = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime?> deliveredAt = const Value.absent(),
                Value<DateTime?> readAt = const Value.absent(),
                Value<DateTime?> serverCreatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> retentionState = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<int> encryptionVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion.insert(
                id: id,
                clientMessageId: clientMessageId,
                ownerId: ownerId,
                serverId: serverId,
                conversationId: conversationId,
                senderId: senderId,
                type: type,
                body: body,
                mediaJson: mediaJson,
                reactionsJson: reactionsJson,
                replyToId: replyToId,
                forwarded: forwarded,
                localState: localState,
                remoteStatus: remoteStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
                outgoing: outgoing,
                deleted: deleted,
                deliveredAt: deliveredAt,
                readAt: readAt,
                serverCreatedAt: serverCreatedAt,
                deletedAt: deletedAt,
                retentionState: retentionState,
                schemaVersion: schemaVersion,
                encryptionVersion: encryptionVersion,
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
typedef $$OutboxMessagesTableCreateCompanionBuilder =
    OutboxMessagesCompanion Function({
      required String id,
      Value<String> ownerId,
      required String clientMessageId,
      required String conversationId,
      Value<String> type,
      Value<String?> body,
      Value<String?> mediaJson,
      Value<String?> replyToId,
      Value<bool> forwarded,
      Value<int> attemptCount,
      Value<int> status,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$OutboxMessagesTableUpdateCompanionBuilder =
    OutboxMessagesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> clientMessageId,
      Value<String> conversationId,
      Value<String> type,
      Value<String?> body,
      Value<String?> mediaJson,
      Value<String?> replyToId,
      Value<bool> forwarded,
      Value<int> attemptCount,
      Value<int> status,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$OutboxMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get forwarded => $composableBuilder(
    column: $table.forwarded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaJson => $composableBuilder(
    column: $table.mediaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replyToId => $composableBuilder(
    column: $table.replyToId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get forwarded => $composableBuilder(
    column: $table.forwarded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxMessagesTable> {
  $$OutboxMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get mediaJson =>
      $composableBuilder(column: $table.mediaJson, builder: (column) => column);

  GeneratedColumn<String> get replyToId =>
      $composableBuilder(column: $table.replyToId, builder: (column) => column);

  GeneratedColumn<bool> get forwarded =>
      $composableBuilder(column: $table.forwarded, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxMessagesTable,
          OutboxMessage,
          $$OutboxMessagesTableFilterComposer,
          $$OutboxMessagesTableOrderingComposer,
          $$OutboxMessagesTableAnnotationComposer,
          $$OutboxMessagesTableCreateCompanionBuilder,
          $$OutboxMessagesTableUpdateCompanionBuilder,
          (
            OutboxMessage,
            BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>,
          ),
          OutboxMessage,
          PrefetchHooks Function()
        > {
  $$OutboxMessagesTableTableManager(
    _$AppDatabase db,
    $OutboxMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> clientMessageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> mediaJson = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<bool> forwarded = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxMessagesCompanion(
                id: id,
                ownerId: ownerId,
                clientMessageId: clientMessageId,
                conversationId: conversationId,
                type: type,
                body: body,
                mediaJson: mediaJson,
                replyToId: replyToId,
                forwarded: forwarded,
                attemptCount: attemptCount,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> ownerId = const Value.absent(),
                required String clientMessageId,
                required String conversationId,
                Value<String> type = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> mediaJson = const Value.absent(),
                Value<String?> replyToId = const Value.absent(),
                Value<bool> forwarded = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int> status = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxMessagesCompanion.insert(
                id: id,
                ownerId: ownerId,
                clientMessageId: clientMessageId,
                conversationId: conversationId,
                type: type,
                body: body,
                mediaJson: mediaJson,
                replyToId: replyToId,
                forwarded: forwarded,
                attemptCount: attemptCount,
                status: status,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxMessagesTable,
      OutboxMessage,
      $$OutboxMessagesTableFilterComposer,
      $$OutboxMessagesTableOrderingComposer,
      $$OutboxMessagesTableAnnotationComposer,
      $$OutboxMessagesTableCreateCompanionBuilder,
      $$OutboxMessagesTableUpdateCompanionBuilder,
      (
        OutboxMessage,
        BaseReferences<_$AppDatabase, $OutboxMessagesTable, OutboxMessage>,
      ),
      OutboxMessage,
      PrefetchHooks Function()
    >;
typedef $$MessageReactionsOutboxTableCreateCompanionBuilder =
    MessageReactionsOutboxCompanion Function({
      required String messageId,
      required String emoji,
      Value<int> attemptCount,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$MessageReactionsOutboxTableUpdateCompanionBuilder =
    MessageReactionsOutboxCompanion Function({
      Value<String> messageId,
      Value<String> emoji,
      Value<int> attemptCount,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$MessageReactionsOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $MessageReactionsOutboxTable> {
  $$MessageReactionsOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageReactionsOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageReactionsOutboxTable> {
  $$MessageReactionsOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageReactionsOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageReactionsOutboxTable> {
  $$MessageReactionsOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MessageReactionsOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageReactionsOutboxTable,
          MessageReactionsOutboxData,
          $$MessageReactionsOutboxTableFilterComposer,
          $$MessageReactionsOutboxTableOrderingComposer,
          $$MessageReactionsOutboxTableAnnotationComposer,
          $$MessageReactionsOutboxTableCreateCompanionBuilder,
          $$MessageReactionsOutboxTableUpdateCompanionBuilder,
          (
            MessageReactionsOutboxData,
            BaseReferences<
              _$AppDatabase,
              $MessageReactionsOutboxTable,
              MessageReactionsOutboxData
            >,
          ),
          MessageReactionsOutboxData,
          PrefetchHooks Function()
        > {
  $$MessageReactionsOutboxTableTableManager(
    _$AppDatabase db,
    $MessageReactionsOutboxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageReactionsOutboxTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MessageReactionsOutboxTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MessageReactionsOutboxTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageReactionsOutboxCompanion(
                messageId: messageId,
                emoji: emoji,
                attemptCount: attemptCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String emoji,
                Value<int> attemptCount = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => MessageReactionsOutboxCompanion.insert(
                messageId: messageId,
                emoji: emoji,
                attemptCount: attemptCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageReactionsOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageReactionsOutboxTable,
      MessageReactionsOutboxData,
      $$MessageReactionsOutboxTableFilterComposer,
      $$MessageReactionsOutboxTableOrderingComposer,
      $$MessageReactionsOutboxTableAnnotationComposer,
      $$MessageReactionsOutboxTableCreateCompanionBuilder,
      $$MessageReactionsOutboxTableUpdateCompanionBuilder,
      (
        MessageReactionsOutboxData,
        BaseReferences<
          _$AppDatabase,
          $MessageReactionsOutboxTable,
          MessageReactionsOutboxData
        >,
      ),
      MessageReactionsOutboxData,
      PrefetchHooks Function()
    >;
typedef $$DeviceSyncCursorsTableCreateCompanionBuilder =
    DeviceSyncCursorsCompanion Function({
      required String key,
      Value<String?> cursor,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$DeviceSyncCursorsTableUpdateCompanionBuilder =
    DeviceSyncCursorsCompanion Function({
      Value<String> key,
      Value<String?> cursor,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$DeviceSyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceSyncCursorsTable> {
  $$DeviceSyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceSyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceSyncCursorsTable> {
  $$DeviceSyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceSyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceSyncCursorsTable> {
  $$DeviceSyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeviceSyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceSyncCursorsTable,
          DeviceSyncCursor,
          $$DeviceSyncCursorsTableFilterComposer,
          $$DeviceSyncCursorsTableOrderingComposer,
          $$DeviceSyncCursorsTableAnnotationComposer,
          $$DeviceSyncCursorsTableCreateCompanionBuilder,
          $$DeviceSyncCursorsTableUpdateCompanionBuilder,
          (
            DeviceSyncCursor,
            BaseReferences<
              _$AppDatabase,
              $DeviceSyncCursorsTable,
              DeviceSyncCursor
            >,
          ),
          DeviceSyncCursor,
          PrefetchHooks Function()
        > {
  $$DeviceSyncCursorsTableTableManager(
    _$AppDatabase db,
    $DeviceSyncCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceSyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceSyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceSyncCursorsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceSyncCursorsCompanion(
                key: key,
                cursor: cursor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> cursor = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceSyncCursorsCompanion.insert(
                key: key,
                cursor: cursor,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceSyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceSyncCursorsTable,
      DeviceSyncCursor,
      $$DeviceSyncCursorsTableFilterComposer,
      $$DeviceSyncCursorsTableOrderingComposer,
      $$DeviceSyncCursorsTableAnnotationComposer,
      $$DeviceSyncCursorsTableCreateCompanionBuilder,
      $$DeviceSyncCursorsTableUpdateCompanionBuilder,
      (
        DeviceSyncCursor,
        BaseReferences<
          _$AppDatabase,
          $DeviceSyncCursorsTable,
          DeviceSyncCursor
        >,
      ),
      DeviceSyncCursor,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String key,
      Value<String?> value,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$SyncStateTableUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateData,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateData,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
          ),
          SyncStateData,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateData,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateData,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateData>,
      ),
      SyncStateData,
      PrefetchHooks Function()
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      required String userId,
      Value<String?> settingsJson,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<String> userId,
      Value<String?> settingsJson,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
    column: $table.settingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSetting,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSetting,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
          ),
          UserSetting,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<String?> settingsJson = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsCompanion(
                userId: userId,
                settingsJson: settingsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<String?> settingsJson = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                userId: userId,
                settingsJson: settingsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSetting,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSetting,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
      ),
      UserSetting,
      PrefetchHooks Function()
    >;
typedef $$LocalStatusesTableCreateCompanionBuilder =
    LocalStatusesCompanion Function({
      required String id,
      required String authorId,
      Value<String?> content,
      Value<String?> mediaUrl,
      Value<String?> mediaType,
      Value<String?> caption,
      required DateTime createdAt,
      required DateTime expiresAt,
      Value<int> viewCount,
      Value<bool> viewedByMe,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$LocalStatusesTableUpdateCompanionBuilder =
    LocalStatusesCompanion Function({
      Value<String> id,
      Value<String> authorId,
      Value<String?> content,
      Value<String?> mediaUrl,
      Value<String?> mediaType,
      Value<String?> caption,
      Value<DateTime> createdAt,
      Value<DateTime> expiresAt,
      Value<int> viewCount,
      Value<bool> viewedByMe,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
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
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
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

  ColumnFilters<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get viewedByMe => $composableBuilder(
    column: $table.viewedByMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
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
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorId => $composableBuilder(
    column: $table.authorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaUrl => $composableBuilder(
    column: $table.mediaUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
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

  ColumnOrderings<int> get viewCount => $composableBuilder(
    column: $table.viewCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get viewedByMe => $composableBuilder(
    column: $table.viewedByMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
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
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get mediaUrl =>
      $composableBuilder(column: $table.mediaUrl, builder: (column) => column);

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<int> get viewCount =>
      $composableBuilder(column: $table.viewCount, builder: (column) => column);

  GeneratedColumn<bool> get viewedByMe => $composableBuilder(
    column: $table.viewedByMe,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
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
                Value<String> id = const Value.absent(),
                Value<String> authorId = const Value.absent(),
                Value<String?> content = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaType = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> viewCount = const Value.absent(),
                Value<bool> viewedByMe = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStatusesCompanion(
                id: id,
                authorId: authorId,
                content: content,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
                caption: caption,
                createdAt: createdAt,
                expiresAt: expiresAt,
                viewCount: viewCount,
                viewedByMe: viewedByMe,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String authorId,
                Value<String?> content = const Value.absent(),
                Value<String?> mediaUrl = const Value.absent(),
                Value<String?> mediaType = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                required DateTime createdAt,
                required DateTime expiresAt,
                Value<int> viewCount = const Value.absent(),
                Value<bool> viewedByMe = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStatusesCompanion.insert(
                id: id,
                authorId: authorId,
                content: content,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
                caption: caption,
                createdAt: createdAt,
                expiresAt: expiresAt,
                viewCount: viewCount,
                viewedByMe: viewedByMe,
                syncedAt: syncedAt,
                rowid: rowid,
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
typedef $$LocalStatusViewsTableCreateCompanionBuilder =
    LocalStatusViewsCompanion Function({
      required String id,
      required String statusId,
      required String viewerId,
      Value<String?> viewerName,
      required DateTime viewedAt,
      Value<int> rowid,
    });
typedef $$LocalStatusViewsTableUpdateCompanionBuilder =
    LocalStatusViewsCompanion Function({
      Value<String> id,
      Value<String> statusId,
      Value<String> viewerId,
      Value<String?> viewerName,
      Value<DateTime> viewedAt,
      Value<int> rowid,
    });

class $$LocalStatusViewsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalStatusViewsTable> {
  $$LocalStatusViewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusId => $composableBuilder(
    column: $table.statusId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewerId => $composableBuilder(
    column: $table.viewerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get viewerName => $composableBuilder(
    column: $table.viewerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get viewedAt => $composableBuilder(
    column: $table.viewedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalStatusViewsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalStatusViewsTable> {
  $$LocalStatusViewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusId => $composableBuilder(
    column: $table.statusId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewerId => $composableBuilder(
    column: $table.viewerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get viewerName => $composableBuilder(
    column: $table.viewerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get viewedAt => $composableBuilder(
    column: $table.viewedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalStatusViewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalStatusViewsTable> {
  $$LocalStatusViewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get statusId =>
      $composableBuilder(column: $table.statusId, builder: (column) => column);

  GeneratedColumn<String> get viewerId =>
      $composableBuilder(column: $table.viewerId, builder: (column) => column);

  GeneratedColumn<String> get viewerName => $composableBuilder(
    column: $table.viewerName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get viewedAt =>
      $composableBuilder(column: $table.viewedAt, builder: (column) => column);
}

class $$LocalStatusViewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalStatusViewsTable,
          LocalStatusView,
          $$LocalStatusViewsTableFilterComposer,
          $$LocalStatusViewsTableOrderingComposer,
          $$LocalStatusViewsTableAnnotationComposer,
          $$LocalStatusViewsTableCreateCompanionBuilder,
          $$LocalStatusViewsTableUpdateCompanionBuilder,
          (
            LocalStatusView,
            BaseReferences<
              _$AppDatabase,
              $LocalStatusViewsTable,
              LocalStatusView
            >,
          ),
          LocalStatusView,
          PrefetchHooks Function()
        > {
  $$LocalStatusViewsTableTableManager(
    _$AppDatabase db,
    $LocalStatusViewsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalStatusViewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalStatusViewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalStatusViewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> statusId = const Value.absent(),
                Value<String> viewerId = const Value.absent(),
                Value<String?> viewerName = const Value.absent(),
                Value<DateTime> viewedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalStatusViewsCompanion(
                id: id,
                statusId: statusId,
                viewerId: viewerId,
                viewerName: viewerName,
                viewedAt: viewedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String statusId,
                required String viewerId,
                Value<String?> viewerName = const Value.absent(),
                required DateTime viewedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalStatusViewsCompanion.insert(
                id: id,
                statusId: statusId,
                viewerId: viewerId,
                viewerName: viewerName,
                viewedAt: viewedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalStatusViewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalStatusViewsTable,
      LocalStatusView,
      $$LocalStatusViewsTableFilterComposer,
      $$LocalStatusViewsTableOrderingComposer,
      $$LocalStatusViewsTableAnnotationComposer,
      $$LocalStatusViewsTableCreateCompanionBuilder,
      $$LocalStatusViewsTableUpdateCompanionBuilder,
      (
        LocalStatusView,
        BaseReferences<_$AppDatabase, $LocalStatusViewsTable, LocalStatusView>,
      ),
      LocalStatusView,
      PrefetchHooks Function()
    >;
typedef $$MessageTombstonesTableCreateCompanionBuilder =
    MessageTombstonesCompanion Function({
      Value<String> ownerId,
      required String messageId,
      required String conversationId,
      Value<String> scope,
      required DateTime deletedAt,
      Value<int> payloadVersion,
      Value<int> rowid,
    });
typedef $$MessageTombstonesTableUpdateCompanionBuilder =
    MessageTombstonesCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> conversationId,
      Value<String> scope,
      Value<DateTime> deletedAt,
      Value<int> payloadVersion,
      Value<int> rowid,
    });

class $$MessageTombstonesTableFilterComposer
    extends Composer<_$AppDatabase, $MessageTombstonesTable> {
  $$MessageTombstonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessageTombstonesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessageTombstonesTable> {
  $$MessageTombstonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessageTombstonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessageTombstonesTable> {
  $$MessageTombstonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get payloadVersion => $composableBuilder(
    column: $table.payloadVersion,
    builder: (column) => column,
  );
}

class $$MessageTombstonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessageTombstonesTable,
          MessageTombstone,
          $$MessageTombstonesTableFilterComposer,
          $$MessageTombstonesTableOrderingComposer,
          $$MessageTombstonesTableAnnotationComposer,
          $$MessageTombstonesTableCreateCompanionBuilder,
          $$MessageTombstonesTableUpdateCompanionBuilder,
          (
            MessageTombstone,
            BaseReferences<
              _$AppDatabase,
              $MessageTombstonesTable,
              MessageTombstone
            >,
          ),
          MessageTombstone,
          PrefetchHooks Function()
        > {
  $$MessageTombstonesTableTableManager(
    _$AppDatabase db,
    $MessageTombstonesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessageTombstonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessageTombstonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessageTombstonesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
                Value<int> payloadVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageTombstonesCompanion(
                ownerId: ownerId,
                messageId: messageId,
                conversationId: conversationId,
                scope: scope,
                deletedAt: deletedAt,
                payloadVersion: payloadVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                required String messageId,
                required String conversationId,
                Value<String> scope = const Value.absent(),
                required DateTime deletedAt,
                Value<int> payloadVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessageTombstonesCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                conversationId: conversationId,
                scope: scope,
                deletedAt: deletedAt,
                payloadVersion: payloadVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessageTombstonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessageTombstonesTable,
      MessageTombstone,
      $$MessageTombstonesTableFilterComposer,
      $$MessageTombstonesTableOrderingComposer,
      $$MessageTombstonesTableAnnotationComposer,
      $$MessageTombstonesTableCreateCompanionBuilder,
      $$MessageTombstonesTableUpdateCompanionBuilder,
      (
        MessageTombstone,
        BaseReferences<
          _$AppDatabase,
          $MessageTombstonesTable,
          MessageTombstone
        >,
      ),
      MessageTombstone,
      PrefetchHooks Function()
    >;
typedef $$DeliveryAckLedgerTableCreateCompanionBuilder =
    DeliveryAckLedgerCompanion Function({
      Value<String> ownerId,
      required String messageId,
      required String kind,
      Value<bool> reported,
      Value<int> attempts,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });
typedef $$DeliveryAckLedgerTableUpdateCompanionBuilder =
    DeliveryAckLedgerCompanion Function({
      Value<String> ownerId,
      Value<String> messageId,
      Value<String> kind,
      Value<bool> reported,
      Value<int> attempts,
      Value<DateTime?> updatedAt,
      Value<int> rowid,
    });

class $$DeliveryAckLedgerTableFilterComposer
    extends Composer<_$AppDatabase, $DeliveryAckLedgerTable> {
  $$DeliveryAckLedgerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reported => $composableBuilder(
    column: $table.reported,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeliveryAckLedgerTableOrderingComposer
    extends Composer<_$AppDatabase, $DeliveryAckLedgerTable> {
  $$DeliveryAckLedgerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reported => $composableBuilder(
    column: $table.reported,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeliveryAckLedgerTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeliveryAckLedgerTable> {
  $$DeliveryAckLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get reported =>
      $composableBuilder(column: $table.reported, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeliveryAckLedgerTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeliveryAckLedgerTable,
          DeliveryAckLedgerData,
          $$DeliveryAckLedgerTableFilterComposer,
          $$DeliveryAckLedgerTableOrderingComposer,
          $$DeliveryAckLedgerTableAnnotationComposer,
          $$DeliveryAckLedgerTableCreateCompanionBuilder,
          $$DeliveryAckLedgerTableUpdateCompanionBuilder,
          (
            DeliveryAckLedgerData,
            BaseReferences<
              _$AppDatabase,
              $DeliveryAckLedgerTable,
              DeliveryAckLedgerData
            >,
          ),
          DeliveryAckLedgerData,
          PrefetchHooks Function()
        > {
  $$DeliveryAckLedgerTableTableManager(
    _$AppDatabase db,
    $DeliveryAckLedgerTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveryAckLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveryAckLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveryAckLedgerTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<bool> reported = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeliveryAckLedgerCompanion(
                ownerId: ownerId,
                messageId: messageId,
                kind: kind,
                reported: reported,
                attempts: attempts,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                required String messageId,
                required String kind,
                Value<bool> reported = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeliveryAckLedgerCompanion.insert(
                ownerId: ownerId,
                messageId: messageId,
                kind: kind,
                reported: reported,
                attempts: attempts,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeliveryAckLedgerTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeliveryAckLedgerTable,
      DeliveryAckLedgerData,
      $$DeliveryAckLedgerTableFilterComposer,
      $$DeliveryAckLedgerTableOrderingComposer,
      $$DeliveryAckLedgerTableAnnotationComposer,
      $$DeliveryAckLedgerTableCreateCompanionBuilder,
      $$DeliveryAckLedgerTableUpdateCompanionBuilder,
      (
        DeliveryAckLedgerData,
        BaseReferences<
          _$AppDatabase,
          $DeliveryAckLedgerTable,
          DeliveryAckLedgerData
        >,
      ),
      DeliveryAckLedgerData,
      PrefetchHooks Function()
    >;
typedef $$DeletionCursorsTableCreateCompanionBuilder =
    DeletionCursorsCompanion Function({
      Value<String> ownerId,
      required String conversationId,
      Value<DateTime?> lastDeletedAt,
      Value<int> rowid,
    });
typedef $$DeletionCursorsTableUpdateCompanionBuilder =
    DeletionCursorsCompanion Function({
      Value<String> ownerId,
      Value<String> conversationId,
      Value<DateTime?> lastDeletedAt,
      Value<int> rowid,
    });

class $$DeletionCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $DeletionCursorsTable> {
  $$DeletionCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastDeletedAt => $composableBuilder(
    column: $table.lastDeletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeletionCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeletionCursorsTable> {
  $$DeletionCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastDeletedAt => $composableBuilder(
    column: $table.lastDeletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeletionCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeletionCursorsTable> {
  $$DeletionCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastDeletedAt => $composableBuilder(
    column: $table.lastDeletedAt,
    builder: (column) => column,
  );
}

class $$DeletionCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeletionCursorsTable,
          DeletionCursor,
          $$DeletionCursorsTableFilterComposer,
          $$DeletionCursorsTableOrderingComposer,
          $$DeletionCursorsTableAnnotationComposer,
          $$DeletionCursorsTableCreateCompanionBuilder,
          $$DeletionCursorsTableUpdateCompanionBuilder,
          (
            DeletionCursor,
            BaseReferences<
              _$AppDatabase,
              $DeletionCursorsTable,
              DeletionCursor
            >,
          ),
          DeletionCursor,
          PrefetchHooks Function()
        > {
  $$DeletionCursorsTableTableManager(
    _$AppDatabase db,
    $DeletionCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeletionCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeletionCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeletionCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<DateTime?> lastDeletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeletionCursorsCompanion(
                ownerId: ownerId,
                conversationId: conversationId,
                lastDeletedAt: lastDeletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                required String conversationId,
                Value<DateTime?> lastDeletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeletionCursorsCompanion.insert(
                ownerId: ownerId,
                conversationId: conversationId,
                lastDeletedAt: lastDeletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeletionCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeletionCursorsTable,
      DeletionCursor,
      $$DeletionCursorsTableFilterComposer,
      $$DeletionCursorsTableOrderingComposer,
      $$DeletionCursorsTableAnnotationComposer,
      $$DeletionCursorsTableCreateCompanionBuilder,
      $$DeletionCursorsTableUpdateCompanionBuilder,
      (
        DeletionCursor,
        BaseReferences<_$AppDatabase, $DeletionCursorsTable, DeletionCursor>,
      ),
      DeletionCursor,
      PrefetchHooks Function()
    >;
typedef $$AccountScopeClaimsTableCreateCompanionBuilder =
    AccountScopeClaimsCompanion Function({
      required String ownerId,
      required DateTime claimedAt,
      Value<int> adoptedRows,
      Value<int> rowid,
    });
typedef $$AccountScopeClaimsTableUpdateCompanionBuilder =
    AccountScopeClaimsCompanion Function({
      Value<String> ownerId,
      Value<DateTime> claimedAt,
      Value<int> adoptedRows,
      Value<int> rowid,
    });

class $$AccountScopeClaimsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountScopeClaimsTable> {
  $$AccountScopeClaimsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get adoptedRows => $composableBuilder(
    column: $table.adoptedRows,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountScopeClaimsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountScopeClaimsTable> {
  $$AccountScopeClaimsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get claimedAt => $composableBuilder(
    column: $table.claimedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get adoptedRows => $composableBuilder(
    column: $table.adoptedRows,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountScopeClaimsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountScopeClaimsTable> {
  $$AccountScopeClaimsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<DateTime> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);

  GeneratedColumn<int> get adoptedRows => $composableBuilder(
    column: $table.adoptedRows,
    builder: (column) => column,
  );
}

class $$AccountScopeClaimsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountScopeClaimsTable,
          AccountScopeClaim,
          $$AccountScopeClaimsTableFilterComposer,
          $$AccountScopeClaimsTableOrderingComposer,
          $$AccountScopeClaimsTableAnnotationComposer,
          $$AccountScopeClaimsTableCreateCompanionBuilder,
          $$AccountScopeClaimsTableUpdateCompanionBuilder,
          (
            AccountScopeClaim,
            BaseReferences<
              _$AppDatabase,
              $AccountScopeClaimsTable,
              AccountScopeClaim
            >,
          ),
          AccountScopeClaim,
          PrefetchHooks Function()
        > {
  $$AccountScopeClaimsTableTableManager(
    _$AppDatabase db,
    $AccountScopeClaimsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountScopeClaimsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountScopeClaimsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountScopeClaimsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<DateTime> claimedAt = const Value.absent(),
                Value<int> adoptedRows = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountScopeClaimsCompanion(
                ownerId: ownerId,
                claimedAt: claimedAt,
                adoptedRows: adoptedRows,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ownerId,
                required DateTime claimedAt,
                Value<int> adoptedRows = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountScopeClaimsCompanion.insert(
                ownerId: ownerId,
                claimedAt: claimedAt,
                adoptedRows: adoptedRows,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountScopeClaimsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountScopeClaimsTable,
      AccountScopeClaim,
      $$AccountScopeClaimsTableFilterComposer,
      $$AccountScopeClaimsTableOrderingComposer,
      $$AccountScopeClaimsTableAnnotationComposer,
      $$AccountScopeClaimsTableCreateCompanionBuilder,
      $$AccountScopeClaimsTableUpdateCompanionBuilder,
      (
        AccountScopeClaim,
        BaseReferences<
          _$AppDatabase,
          $AccountScopeClaimsTable,
          AccountScopeClaim
        >,
      ),
      AccountScopeClaim,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalProfilesTableTableManager get localProfiles =>
      $$LocalProfilesTableTableManager(_db, _db.localProfiles);
  $$LocalConversationsTableTableManager get localConversations =>
      $$LocalConversationsTableTableManager(_db, _db.localConversations);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
  $$OutboxMessagesTableTableManager get outboxMessages =>
      $$OutboxMessagesTableTableManager(_db, _db.outboxMessages);
  $$MessageReactionsOutboxTableTableManager get messageReactionsOutbox =>
      $$MessageReactionsOutboxTableTableManager(
        _db,
        _db.messageReactionsOutbox,
      );
  $$DeviceSyncCursorsTableTableManager get deviceSyncCursors =>
      $$DeviceSyncCursorsTableTableManager(_db, _db.deviceSyncCursors);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
  
  $$LocalStatusesTableTableManager get localStatuses =>
      $$LocalStatusesTableTableManager(_db, _db.localStatuses);
  $$LocalStatusViewsTableTableManager get localStatusViews =>
      $$LocalStatusViewsTableTableManager(_db, _db.localStatusViews);
  $$MessageTombstonesTableTableManager get messageTombstones =>
      $$MessageTombstonesTableTableManager(_db, _db.messageTombstones);
  $$DeliveryAckLedgerTableTableManager get deliveryAckLedger =>
      $$DeliveryAckLedgerTableTableManager(_db, _db.deliveryAckLedger);
  $$DeletionCursorsTableTableManager get deletionCursors =>
      $$DeletionCursorsTableTableManager(_db, _db.deletionCursors);
  $$AccountScopeClaimsTableTableManager get accountScopeClaims =>
      $$AccountScopeClaimsTableTableManager(_db, _db.accountScopeClaims);
}
