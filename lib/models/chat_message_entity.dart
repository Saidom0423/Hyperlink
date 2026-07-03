import 'package:isar/isar.dart';
import 'chat_message.dart';

part 'chat_message_entity.g.dart';

@collection
class ChatMessageEntity {
  int id = 0;

  @Index(unique: true)
  late String messageId;
  
  late String senderId;
  late String senderName;
  late String recipientId;
  late String content;
  late DateTime timestamp;
  late bool isMe;
  late int statusIndex;
  late int hops;

  ChatMessageEntity();

  ChatMessageEntity.create({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    required this.isMe,
    required this.statusIndex,
    required this.hops,
  });

  factory ChatMessageEntity.fromModel(ChatMessage model) {
    return ChatMessageEntity.create(
      messageId: model.id,
      senderId: model.senderId,
      senderName: model.senderName,
      recipientId: model.recipientId,
      content: model.content,
      timestamp: model.timestamp,
      isMe: model.isMe,
      statusIndex: model.status.index,
      hops: model.hops,
    );
  }

  ChatMessage toModel() {
    return ChatMessage(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      recipientId: recipientId,
      content: content,
      timestamp: timestamp,
      isMe: isMe,
      status: MessageStatus.values[statusIndex],
      hops: hops,
    );
  }
}
