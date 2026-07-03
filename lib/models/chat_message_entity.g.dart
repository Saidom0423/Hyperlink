// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_entity.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors

extension GetChatMessageEntityCollection on Isar {
  IsarCollection<int, ChatMessageEntity> get chatMessageEntitys =>
      this.collection();
}

const ChatMessageEntitySchema = IsarCollectionSchema(
  schema:
      '{"name":"ChatMessageEntity","idName":"id","properties":[{"name":"messageId","type":"String"},{"name":"senderId","type":"String"},{"name":"senderName","type":"String"},{"name":"recipientId","type":"String"},{"name":"content","type":"String"},{"name":"timestamp","type":"DateTime"},{"name":"isMe","type":"Bool"},{"name":"statusIndex","type":"Long"},{"name":"hops","type":"Long"}]}',
  converter: IsarObjectConverter<int, ChatMessageEntity>(
    serialize: serializeChatMessageEntity,
    deserialize: deserializeChatMessageEntity,
    deserializeProperty: deserializeChatMessageEntityProp,
  ),
  embeddedSchemas: [],
  hash: -7322056294181745004,
);

@isarProtected
int serializeChatMessageEntity(IsarWriter writer, ChatMessageEntity object) {
  IsarCore.writeString(writer, 1, IsarCore.toNativeString(object.messageId));
  IsarCore.writeString(writer, 2, IsarCore.toNativeString(object.senderId));
  IsarCore.writeString(writer, 3, IsarCore.toNativeString(object.senderName));
  IsarCore.writeString(writer, 4, IsarCore.toNativeString(object.recipientId));
  IsarCore.writeString(writer, 5, IsarCore.toNativeString(object.content));
  IsarCore.writeLong(
      writer, 6, object.timestamp.toUtc().microsecondsSinceEpoch);
  IsarCore.writeBool(writer, 7, object.isMe);
  IsarCore.writeLong(writer, 8, object.statusIndex);
  IsarCore.writeLong(writer, 9, object.hops);
  return object.id;
}

@isarProtected
ChatMessageEntity deserializeChatMessageEntity(IsarReader reader) {
  final object = ChatMessageEntity();
  object.id = IsarCore.readId(reader);
  object.messageId = IsarCore.readString(reader, 1) ?? '';
  object.senderId = IsarCore.readString(reader, 2) ?? '';
  object.senderName = IsarCore.readString(reader, 3) ?? '';
  object.recipientId = IsarCore.readString(reader, 4) ?? '';
  object.content = IsarCore.readString(reader, 5) ?? '';
  {
    final value = IsarCore.readLong(reader, 6);
    if (value == -9223372036854775808) {
      object.timestamp =
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
    } else {
      object.timestamp =
          DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true).toLocal();
    }
  }
  object.isMe = IsarCore.readBool(reader, 7);
  object.statusIndex = IsarCore.readLong(reader, 8);
  object.hops = IsarCore.readLong(reader, 9);
  return object;
}

@isarProtected
dynamic deserializeChatMessageEntityProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      return IsarCore.readString(reader, 4) ?? '';
    case 5:
      return IsarCore.readString(reader, 5) ?? '';
    case 6:
      {
        final value = IsarCore.readLong(reader, 6);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true)
              .toLocal();
        }
      }
    case 7:
      return IsarCore.readBool(reader, 7);
    case 8:
      return IsarCore.readLong(reader, 8);
    case 9:
      return IsarCore.readLong(reader, 9);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _ChatMessageEntityUpdate {
  bool call({
    required int id,
    String? messageId,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    bool? isMe,
    int? statusIndex,
    int? hops,
  });
}

class _ChatMessageEntityUpdateImpl implements _ChatMessageEntityUpdate {
  const _ChatMessageEntityUpdateImpl(this.collection);

  final IsarCollection<int, ChatMessageEntity> collection;

  @override
  bool call({
    required int id,
    Object? messageId = ignore,
    Object? senderId = ignore,
    Object? senderName = ignore,
    Object? recipientId = ignore,
    Object? content = ignore,
    Object? timestamp = ignore,
    Object? isMe = ignore,
    Object? statusIndex = ignore,
    Object? hops = ignore,
  }) {
    return collection.updateProperties([
          id
        ], {
          if (messageId != ignore) 1: messageId as String?,
          if (senderId != ignore) 2: senderId as String?,
          if (senderName != ignore) 3: senderName as String?,
          if (recipientId != ignore) 4: recipientId as String?,
          if (content != ignore) 5: content as String?,
          if (timestamp != ignore) 6: timestamp as DateTime?,
          if (isMe != ignore) 7: isMe as bool?,
          if (statusIndex != ignore) 8: statusIndex as int?,
          if (hops != ignore) 9: hops as int?,
        }) >
        0;
  }
}

sealed class _ChatMessageEntityUpdateAll {
  int call({
    required List<int> id,
    String? messageId,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    bool? isMe,
    int? statusIndex,
    int? hops,
  });
}

class _ChatMessageEntityUpdateAllImpl implements _ChatMessageEntityUpdateAll {
  const _ChatMessageEntityUpdateAllImpl(this.collection);

  final IsarCollection<int, ChatMessageEntity> collection;

  @override
  int call({
    required List<int> id,
    Object? messageId = ignore,
    Object? senderId = ignore,
    Object? senderName = ignore,
    Object? recipientId = ignore,
    Object? content = ignore,
    Object? timestamp = ignore,
    Object? isMe = ignore,
    Object? statusIndex = ignore,
    Object? hops = ignore,
  }) {
    return collection.updateProperties(id, {
      if (messageId != ignore) 1: messageId as String?,
      if (senderId != ignore) 2: senderId as String?,
      if (senderName != ignore) 3: senderName as String?,
      if (recipientId != ignore) 4: recipientId as String?,
      if (content != ignore) 5: content as String?,
      if (timestamp != ignore) 6: timestamp as DateTime?,
      if (isMe != ignore) 7: isMe as bool?,
      if (statusIndex != ignore) 8: statusIndex as int?,
      if (hops != ignore) 9: hops as int?,
    });
  }
}

extension ChatMessageEntityUpdate on IsarCollection<int, ChatMessageEntity> {
  _ChatMessageEntityUpdate get update => _ChatMessageEntityUpdateImpl(this);

  _ChatMessageEntityUpdateAll get updateAll =>
      _ChatMessageEntityUpdateAllImpl(this);
}

sealed class _ChatMessageEntityQueryUpdate {
  int call({
    String? messageId,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    bool? isMe,
    int? statusIndex,
    int? hops,
  });
}

class _ChatMessageEntityQueryUpdateImpl
    implements _ChatMessageEntityQueryUpdate {
  const _ChatMessageEntityQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<ChatMessageEntity> query;
  final int? limit;

  @override
  int call({
    Object? messageId = ignore,
    Object? senderId = ignore,
    Object? senderName = ignore,
    Object? recipientId = ignore,
    Object? content = ignore,
    Object? timestamp = ignore,
    Object? isMe = ignore,
    Object? statusIndex = ignore,
    Object? hops = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (messageId != ignore) 1: messageId as String?,
      if (senderId != ignore) 2: senderId as String?,
      if (senderName != ignore) 3: senderName as String?,
      if (recipientId != ignore) 4: recipientId as String?,
      if (content != ignore) 5: content as String?,
      if (timestamp != ignore) 6: timestamp as DateTime?,
      if (isMe != ignore) 7: isMe as bool?,
      if (statusIndex != ignore) 8: statusIndex as int?,
      if (hops != ignore) 9: hops as int?,
    });
  }
}

extension ChatMessageEntityQueryUpdate on IsarQuery<ChatMessageEntity> {
  _ChatMessageEntityQueryUpdate get updateFirst =>
      _ChatMessageEntityQueryUpdateImpl(this, limit: 1);

  _ChatMessageEntityQueryUpdate get updateAll =>
      _ChatMessageEntityQueryUpdateImpl(this);
}

extension ChatMessageEntityQueryFilter
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 0,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 1,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 1,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      messageIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 2,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 2,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 3,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 3,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      senderNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 4,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 4,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      recipientIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 4,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 5,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 5,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      contentIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 5,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      timestampEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      timestampGreaterThanOrEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      timestampLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      timestampLessThanOrEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 6,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 6,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      isMeEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 7,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      statusIndexEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 8,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      statusIndexGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 8,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      statusIndexGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 8,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      statusIndexLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 8,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      statusIndexLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 8,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      statusIndexBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 8,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      hopsEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 9,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      hopsGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 9,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      hopsGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 9,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      hopsLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 9,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      hopsLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 9,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterFilterCondition>
      hopsBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 9,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }
}

extension ChatMessageEntityQueryObject
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QFilterCondition> {}

extension ChatMessageEntityQuerySortBy
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QSortBy> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByMessageIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        3,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortBySenderNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        3,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByRecipientId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        4,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByRecipientIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        4,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        5,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        5,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByIsMe() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByIsMeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByHops() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      sortByHopsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }
}

extension ChatMessageEntityQuerySortThenBy
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QSortThenBy> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByMessageIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenBySenderNameDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByRecipientId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByRecipientIdDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByContentDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByIsMe() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByIsMeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByStatusIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByHops() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterSortBy>
      thenByHopsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }
}

extension ChatMessageEntityQueryWhereDistinct
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QDistinct> {
  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctByMessageId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctBySenderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctBySenderName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctByRecipientId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctByContent({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctByIsMe() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctByStatusIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<ChatMessageEntity, ChatMessageEntity, QAfterDistinct>
      distinctByHops() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }
}

extension ChatMessageEntityQueryProperty1
    on QueryBuilder<ChatMessageEntity, ChatMessageEntity, QProperty> {
  QueryBuilder<ChatMessageEntity, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ChatMessageEntity, String, QAfterProperty> messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ChatMessageEntity, String, QAfterProperty> senderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ChatMessageEntity, String, QAfterProperty> senderNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ChatMessageEntity, String, QAfterProperty>
      recipientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ChatMessageEntity, String, QAfterProperty> contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ChatMessageEntity, DateTime, QAfterProperty>
      timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ChatMessageEntity, bool, QAfterProperty> isMeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ChatMessageEntity, int, QAfterProperty> statusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ChatMessageEntity, int, QAfterProperty> hopsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension ChatMessageEntityQueryProperty2<R>
    on QueryBuilder<ChatMessageEntity, R, QAfterProperty> {
  QueryBuilder<ChatMessageEntity, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, String), QAfterProperty>
      messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, String), QAfterProperty>
      senderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, String), QAfterProperty>
      senderNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, String), QAfterProperty>
      recipientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, String), QAfterProperty>
      contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, DateTime), QAfterProperty>
      timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, bool), QAfterProperty> isMeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, int), QAfterProperty>
      statusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ChatMessageEntity, (R, int), QAfterProperty> hopsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}

extension ChatMessageEntityQueryProperty3<R1, R2>
    on QueryBuilder<ChatMessageEntity, (R1, R2), QAfterProperty> {
  QueryBuilder<ChatMessageEntity, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, String), QOperations>
      messageIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, String), QOperations>
      senderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, String), QOperations>
      senderNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, String), QOperations>
      recipientIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, String), QOperations>
      contentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, DateTime), QOperations>
      timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, bool), QOperations> isMeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, int), QOperations>
      statusIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<ChatMessageEntity, (R1, R2, int), QOperations> hopsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }
}
