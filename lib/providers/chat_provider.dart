import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_message_entity.dart';
import '../models/peer_device.dart';
import '../services/crypto_service.dart';
import '../services/profile_service.dart';
import '../services/database_service.dart';
import 'network_provider.dart';

class QueuedMessage {
  final PeerDevice peer;
  final ChatMessage message;
  final String payload;
  final DateTime timestamp;

  QueuedMessage({
    required this.peer,
    required this.message,
    required this.payload,
    required this.timestamp,
  });
}

class ChatState {
  final Map<String, List<ChatMessage>> conversations;

  const ChatState({this.conversations = const {}});

  ChatState copyWith({Map<String, List<ChatMessage>>? conversations}) {
    return ChatState(conversations: conversations ?? this.conversations);
  }

  List<ChatMessage> messagesFor(String peerId) =>
      conversations[peerId] ?? const [];
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final List<QueuedMessage> _queue = [];
  Timer? _retryTimer;

  ChatNotifier(this._ref) : super(const ChatState()) {
    final network = _ref.read(networkProvider.notifier);
    network.onChatMessageReceived = _handleIncoming;
    network.onFileReceived = receiveFileMessage;

    _loadChatHistory();
    _loadPersistedQueue();

    // Run a periodic fallback retry loop every 5 seconds
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _processQueue();
    });
  }

  // ── Persistent queue helpers ────────────────────────────────────────────

  Future<File> _queueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/pending_queue.json');
  }

  Future<void> _loadPersistedQueue() async {
    try {
      final file = await _queueFile();
      if (!await file.exists()) return;
      final List<dynamic> raw = jsonDecode(await file.readAsString());
      for (final item in raw) {
        final msgMap = item['message'] as Map<String, dynamic>;
        final msg = ChatMessage.fromPersistenceJson(msgMap);
        final peerId = msg.recipientId;
        // Only restore if message is still pending (not yet in a sent/delivered state in DB)
        final alreadySent = DatabaseService.isar.chatMessageEntitys
            .where()
            .messageIdEqualTo(msg.id)
            .findFirst()
            ?.statusIndex ?? -1;
        if (alreadySent == MessageStatus.sending.index || alreadySent == -1) {
          _queue.add(QueuedMessage(
            peer: PeerDevice(id: peerId, name: item['peerName'] as String? ?? 'Contact', ip: '', port: 8765, publicKey: ''),
            message: msg,
            payload: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(item['timestamp'] as int),
          ));
        }
      }
      debugPrint('Restored ${_queue.length} pending messages from queue');
    } catch (e) {
      debugPrint('Failed to load persisted queue: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final file = await _queueFile();
      final data = _queue.map((item) => {
        'peerName': item.peer.name,
        'message': item.message.toPersistenceJson(),
        'timestamp': item.timestamp.millisecondsSinceEpoch,
      }).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to save queue: $e');
    }
  }

  // Handle incoming message envelope from MANET
  void _handleIncoming(String fromId, String senderName, String json) async {
    try {
      final envelope = jsonDecode(json) as Map<String, dynamic>;
      final type = envelope['type'] as String;

      if (type == 'e2ee_message') {
        final encryptedKey = envelope['encryptedKey'] as String;
        final iv = envelope['iv'] as String;
        final ciphertext = envelope['ciphertext'] as String;

        // Decrypt using our private key
        final privateKey = ProfileService.currentProfile!.privateKey;
        final decryptedJson = await CryptoService.decryptText(
          encryptedKey: encryptedKey,
          iv: iv,
          encryptedData: ciphertext,
          privateKey: privateKey,
        );

        final msgMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
        
        // Check if message already exists to avoid duplicates
        final conversations = state.conversations[fromId] ?? [];
        if (conversations.any((m) => m.id == msgMap['id'])) {
          // Already have it, send ack again just in case
          _sendAck(fromId, msgMap['id'], 'delivered');
          return;
        }

        final msg = ChatMessage.fromJson(msgMap, isMe: false);
        _append(fromId, msg);

        // Immediately reply with a delivered acknowledgment
        _sendAck(fromId, msg.id, 'delivered');
      } else if (type == 'ack') {
        final ackType = envelope['ackType'] as String;
        final messageId = envelope['messageId'] as String;
        final status = ackType == 'delivered' ? MessageStatus.delivered : MessageStatus.read;
        _updateStatus(fromId, messageId, status);
      }
    } catch (e) {
      debugPrint('ChatNotifier: failed to parse incoming message envelope: $e');
    }
  }

  Future<void> sendMessage({
    required PeerDevice peer,
    required String content,
    required String myId,
    required String myName,
  }) async {
    final msg = ChatMessage(
      id: const Uuid().v4(),
      senderId: myId,
      senderName: myName,
      recipientId: peer.id,
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sending,
      hops: peer.hops,
    );

    // Optimistically add to list
    _append(peer.id, msg);

    try {
      final network = _ref.read(networkProvider.notifier);
      final freshPeer = network.state.peers.firstWhere((p) => p.id == peer.id, orElse: () => peer);
      
      if (freshPeer.ip.isEmpty || freshPeer.ip == '0.0.0.0' || freshPeer.hops == -1 || freshPeer.publicKey.isEmpty) {
        // Queue it — will be sent when A comes online and handshake provides public key
        debugPrint('Peer ${peer.name} is offline or key not yet received. Message queued.');
        _queue.add(QueuedMessage(
          peer: freshPeer,
          message: msg,
          payload: '',
          timestamp: DateTime.now(),
        ));
        _saveQueue(); // Persist so queue survives app restarts
      } else {
        // Encrypt and send directly
        final cleanContentJson = jsonEncode(msg.toJson());
        final encryptedMap = await CryptoService.encryptText(cleanContentJson, freshPeer.publicKey);
        final encryptedKey = encryptedMap['encryptedKey']!;
        final iv = encryptedMap['iv']!;
        final ciphertext = encryptedMap['encryptedData']!;

        final payload = jsonEncode({
          'type': 'e2ee_message',
          'encryptedKey': encryptedKey,
          'iv': iv,
          'ciphertext': ciphertext,
        });

        await network.sendChatMessage(peer: freshPeer, messageJson: payload);
        _updateStatus(peer.id, msg.id, MessageStatus.sent);
      }
    } catch (e) {
      debugPrint('ChatNotifier: send failed, putting in retry queue: $e');
      final network = _ref.read(networkProvider.notifier);
      final freshPeer = network.state.peers.firstWhere((p) => p.id == peer.id, orElse: () => peer);
      _queue.add(QueuedMessage(
        peer: freshPeer,
        message: msg,
        payload: '',
        timestamp: DateTime.now(),
      ));
      _saveQueue();
    }
  }

  void markMessagesAsRead(String peerId) {
    final list = state.conversations[peerId] ?? [];
    for (final msg in list) {
      if (!msg.isMe && msg.status != MessageStatus.read) {
        _updateStatus(peerId, msg.id, MessageStatus.read);
        _sendAck(peerId, msg.id, 'read');
      }
    }
  }

  Future<void> _sendAck(String peerId, String messageId, String ackType) async {
    try {
      final network = _ref.read(networkProvider.notifier);
      final peer = network.state.peers.firstWhere((p) => p.id == peerId, orElse: () => const PeerDevice(id: '', name: '', ip: '', port: 0, publicKey: ''));
      if (peer.ip.isEmpty || peer.hops == -1) return;

      final ackPayload = jsonEncode({
        'type': 'ack',
        'ackType': ackType,
        'messageId': messageId,
      });

      await network.sendChatMessage(peer: peer, messageJson: ackPayload);
    } catch (e) {
      debugPrint('Failed to send ACK: $e');
    }
  }

  void _processQueue() async {
    if (_queue.isEmpty) return;

    final network = _ref.read(networkProvider.notifier);
    final List<QueuedMessage> toRemove = [];

    for (final item in _queue) {
      final freshPeer = network.state.peers.firstWhere((p) => p.id == item.peer.id, orElse: () => item.peer);
      // Wait until we have both a valid IP/route AND the peer's public key (from handshake)
      if (freshPeer.ip.isNotEmpty &&
          freshPeer.ip != '0.0.0.0' &&
          freshPeer.hops != -1 &&
          freshPeer.publicKey.isNotEmpty) {
        try {
          // Re-encrypt with latest public key (may have been empty when originally queued)
          final cleanContentJson = jsonEncode(item.message.toJson());
          final encryptedMap = await CryptoService.encryptText(cleanContentJson, freshPeer.publicKey);
          final encryptedKey = encryptedMap['encryptedKey']!;
          final iv = encryptedMap['iv']!;
          final ciphertext = encryptedMap['encryptedData']!;

          final payload = jsonEncode({
            'type': 'e2ee_message',
            'encryptedKey': encryptedKey,
            'iv': iv,
            'ciphertext': ciphertext,
          });

          await network.sendChatMessage(peer: freshPeer, messageJson: payload);
          _updateStatus(freshPeer.id, item.message.id, MessageStatus.sent);
          toRemove.add(item);
          debugPrint('Queued message delivered to ${freshPeer.name}');
        } catch (e) {
          debugPrint('Failed to send queued message to ${freshPeer.name}: $e');
        }
      }
    }

    if (toRemove.isNotEmpty) {
      for (final item in toRemove) {
        _queue.remove(item);
      }
      _saveQueue(); // Persist the updated (smaller) queue
    }
  }

  void _append(String peerId, ChatMessage msg) {
    final current = Map<String, List<ChatMessage>>.from(state.conversations);
    final list = List<ChatMessage>.from(current[peerId] ?? []);
    list.add(msg);
    current[peerId] = list;
    state = state.copyWith(conversations: current);
    
    _saveMessage(msg);
  }

  void _updateStatus(String peerId, String msgId, MessageStatus status) {
    final current = Map<String, List<ChatMessage>>.from(state.conversations);
    final list = (current[peerId] ?? []).map((m) {
      // Don't downgrade status (e.g. read back to delivered)
      if (m.id == msgId) {
        if (m.status == MessageStatus.read) return m;
        if (m.status == MessageStatus.delivered && status == MessageStatus.sent) return m;
        return m.copyWith(status: status);
      }
      return m;
    }).toList();
    current[peerId] = list;
    state = state.copyWith(conversations: current);

    _updateMessageStatusInDb(msgId, status);
  }

  void _saveMessage(ChatMessage msg) {
    try {
      final entity = ChatMessageEntity.fromModel(msg);
      DatabaseService.isar.write((isar) {
        entity.id = isar.chatMessageEntitys.autoIncrement();
        isar.chatMessageEntitys.put(entity);
      });
    } catch (e) {
      debugPrint('Failed to save message to Isar: $e');
    }
  }

  void _updateMessageStatusInDb(String msgId, MessageStatus status) {
    try {
      DatabaseService.isar.write((isar) {
        final entity = isar.chatMessageEntitys
            .where()
            .messageIdEqualTo(msgId)
            .findFirst();
        
        if (entity != null) {
          final currentEnum = MessageStatus.values[entity.statusIndex];
          if (currentEnum == MessageStatus.read) return;
          if (currentEnum == MessageStatus.delivered && status == MessageStatus.sent) return;

          entity.statusIndex = status.index;
          isar.chatMessageEntitys.put(entity);
        }
      });
    } catch (e) {
      debugPrint('Failed to update message status in Isar: $e');
    }
  }

  Future<void> reloadChatHistory() async {
    await _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final messages = DatabaseService.isar.chatMessageEntitys
          .where()
          .sortByTimestamp()
          .findAll();
      
      final Map<String, List<ChatMessage>> conversations = {};
      for (final entity in messages) {
        final model = entity.toModel();
        final peerId = model.isMe ? model.recipientId : model.senderId;
        conversations.putIfAbsent(peerId, () => []).add(model);
      }
      
      state = state.copyWith(conversations: conversations);
      debugPrint('Loaded chat history from Isar: ${messages.length} messages');
    } catch (e) {
      debugPrint('Failed to load chat history from Isar: $e');
    }
  }


  void receiveFileMessage(String fromId, String senderName, String filePath) {
    final fileName = filePath.split('/').last;
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
        .any((ext) => fileName.toLowerCase().endsWith(ext));
    
    final content = isImage ? '[Image] $filePath' : '[File] $filePath';

    final msg = ChatMessage(
      id: const Uuid().v4(),
      senderId: fromId,
      senderName: senderName,
      recipientId: ProfileService.currentProfile!.hashedPhone,
      content: content,
      timestamp: DateTime.now(),
      isMe: false,
      status: MessageStatus.delivered,
      hops: 1,
    );

    _append(fromId, msg);
  }

  Future<void> sendFileMessage({
    required PeerDevice peer,
    required String filePath,
    required String myId,
    required String myName,
  }) async {
    final fileName = filePath.split('/').last;
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
        .any((ext) => fileName.toLowerCase().endsWith(ext));
    
    final content = isImage ? '[Image] $filePath' : '[File] $filePath';
    
    final msg = ChatMessage(
      id: const Uuid().v4(),
      senderId: myId,
      senderName: myName,
      recipientId: peer.id,
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
      status: MessageStatus.sending,
      hops: peer.hops,
    );

    _append(peer.id, msg);

    try {
      final network = _ref.read(networkProvider.notifier);
      await network.sendFile(peer, filePath);
      _updateStatus(peer.id, msg.id, MessageStatus.sent);
    } catch (e) {
      _updateStatus(peer.id, msg.id, MessageStatus.failed);
      rethrow;
    }
  }

  Future<void> deleteConversation(String peerId) async {
    try {
      DatabaseService.isar.write((isar) {
        final entities = isar.chatMessageEntitys
            .where()
            .senderIdEqualTo(peerId)
            .or()
            .recipientIdEqualTo(peerId)
            .findAll();
        final ids = entities.map((e) => e.id).toList();
        isar.chatMessageEntitys.deleteAll(ids);
      });

      final current = Map<String, List<ChatMessage>>.from(state.conversations);
      current.remove(peerId);
      state = state.copyWith(conversations: current);
      debugPrint('Deleted conversation with peer $peerId');
    } catch (e) {
      debugPrint('Failed to delete conversation: $e');
    }
  }

  Future<void> clearConversation(String peerId) async {
    try {
      DatabaseService.isar.write((isar) {
        final entities = isar.chatMessageEntitys
            .where()
            .senderIdEqualTo(peerId)
            .or()
            .recipientIdEqualTo(peerId)
            .findAll();
        final ids = entities.map((e) => e.id).toList();
        isar.chatMessageEntitys.deleteAll(ids);
      });

      final current = Map<String, List<ChatMessage>>.from(state.conversations);
      current[peerId] = [];
      state = state.copyWith(conversations: current);
      debugPrint('Cleared conversation with peer $peerId');
    } catch (e) {
      debugPrint('Failed to clear conversation: $e');
    }
  }

  Future<void> deleteMessage(String peerId, String messageId) async {
    try {
      DatabaseService.isar.write((isar) {
        final entity = isar.chatMessageEntitys
            .where()
            .messageIdEqualTo(messageId)
            .findFirst();
        if (entity != null) {
          isar.chatMessageEntitys.delete(entity.id);
        }
      });

      final current = Map<String, List<ChatMessage>>.from(state.conversations);
      final list = List<ChatMessage>.from(current[peerId] ?? []);
      list.removeWhere((m) => m.id == messageId);
      current[peerId] = list;
      state = state.copyWith(conversations: current);
      debugPrint('Deleted message $messageId');
    } catch (e) {
      debugPrint('Failed to delete message: $e');
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final notifier = ChatNotifier(ref);
  ref.listen<NetworkState>(networkProvider, (previous, next) {
    notifier._processQueue();
  });
  return notifier;
});
