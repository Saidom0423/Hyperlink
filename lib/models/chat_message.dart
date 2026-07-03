import 'dart:convert';

enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final MessageStatus status;
  final int hops; // 0 = direct, >0 = relayed via MANET

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.status = MessageStatus.sending,
    this.hops = 0,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? content,
    DateTime? timestamp,
    bool? isMe,
    MessageStatus? status,
    int? hops,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isMe: isMe ?? this.isMe,
      status: status ?? this.status,
      hops: hops ?? this.hops,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'recipientId': recipientId,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'hops': hops,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json, {required bool isMe}) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      recipientId: json['recipientId'] as String,
      content: json['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isMe: isMe,
      status: MessageStatus.delivered,
      hops: json['hops'] as int? ?? 0,
    );
  }

  String toWire() => jsonEncode(toJson());

  Map<String, dynamic> toPersistenceJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'recipientId': recipientId,
        'content': content,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'hops': hops,
        'status': status.name,
        'isMe': isMe,
      };

  factory ChatMessage.fromPersistenceJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      recipientId: json['recipientId'] as String,
      content: json['content'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isMe: json['isMe'] as bool,
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.delivered,
      ),
      hops: json['hops'] as int? ?? 0,
    );
  }
}
