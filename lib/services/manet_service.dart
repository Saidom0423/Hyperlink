import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import '../models/routing_table.dart';
import 'profile_service.dart';

enum AodvMessageType { rreq, rrep, rerr, data }

class ManetService {
  static const int manetPort = 8767;
  static const int hopLimit = 10;

  final Logger _log = Logger();
  final RoutingTable routingTable = RoutingTable();

  ServerSocket? _server;
  String? _myIp;
  String? _myId;
  String? _myName;

  void Function()? onRoutingTableChanged;

  // Called when a file chunk arrives at final destination
  final void Function(String fromId, String fileName, List<int> data)
  onDataReceived;

  // Called when a text message arrives at final destination
  void Function(String fromId, String senderName, String recipientId, String jsonPayload)? onMessageReceived;

  // Called when we need to relay to next hop
  final void Function(String fileName, String destId, String nextHopIp) onRelay;

  // Called when a handshake packet is received
  void Function(String id, String name, String ip, String publicKey, String hashedPhone)? onHandshakeReceived;

  ManetService({
    required this.onDataReceived,
    required this.onRelay,
  });

  Future<void> start({
    required String myIp,
    required String myId,
    required String myName,
  }) async {
    _myIp = myIp;
    _myId = myId;
    _myName = myName;

    if (_server == null) {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, manetPort);
      _log.i('MANET server bound on port $manetPort');

      _server!.listen((socket) {
        _handleIncoming(socket);
      });
    }
    _log.i('MANET service active for profile $myIp, ID: $myId');
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    _log.i('MANET server stopped.');
  }

  // ── Send Handshake ────────────────────────────────────────────────────
  void sendHandshake(String ip) {
    if (_myId == null || _myIp == null || ProfileService.currentProfile == null) return;
    final packet = {
      'type': 'handshake',
      'deviceId': _myId,
      'deviceName': _myName,
      'publicKey': ProfileService.currentProfile!.publicKey,
      'hashedPhone': ProfileService.currentProfile!.hashedPhone,
    };
    _log.i('MANET: Sending handshake to $ip');
    _sendPacket(ip, ('JSON' + jsonEncode(packet)).codeUnits);
  }

  // ── Send a file via MANET ─────────────────────────────────────────────
  Future<void> sendData({
    required String destinationId,
    required String destinationIp,
    required String fileName,
    required List<int> fileData,
  }) async {
    final route = routingTable.lookup(destinationId);

    if (route != null) {
      final packet = _buildDataPacket(
        destId: destinationId,
        originId: _myId!,
        fileName: fileName,
        data: fileData,
        hopCount: 0,
      );
      _sendPacket(route.nextHopIp, packet);
    } else {
      _log.i('No route to $destinationId — flooding RREQ');
      await _floodRreq(destinationId);

      int waited = 0;
      while (routingTable.lookup(destinationId) == null && waited < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }

      final found = routingTable.lookup(destinationId);
      if (found != null) {
        final packet = _buildDataPacket(
          destId: destinationId,
          originId: _myId!,
          fileName: fileName,
          data: fileData,
          hopCount: 0,
        );
        _sendPacket(found.nextHopIp, packet);
      } else {
        _log.e('Route to $destinationId not found after RREQ flood');
      }
    }
  }

  // ── Send a chat message via MANET ─────────────────────────────────────
  Future<void> sendMessage({
    required String destinationId,
    required String destinationIp,
    required String messageJson, // serialized E2EE message wrapper
    int hops = 0,
  }) async {
    var route = routingTable.lookup(destinationId);

    if (route == null && destinationIp.isNotEmpty) {
      routingTable.upsert(RouteEntry(
        destinationId: destinationId,
        nextHopId: destinationId,
        nextHopIp: destinationIp,
        nextHopPort: manetPort,
        hopCount: hops > 0 ? hops : 1,
        lastSeen: DateTime.now(),
      ));
      route = routingTable.lookup(destinationId);
    }

    if (route == null) {
      await _floodRreq(destinationId);
      int waited = 0;
      while (routingTable.lookup(destinationId) == null && waited < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waited++;
      }
      route = routingTable.lookup(destinationId);
    }

    if (route != null) {
      final packet = _buildMsgPacket(
        destId: destinationId,
        originId: _myId!,
        originName: _myName!,
        messageJson: messageJson,
        hopCount: hops,
      );
      _sendPacket(route.nextHopIp, packet);
    } else {
      _log.e('MANET: no route to $destinationId for message');
      throw StateError("Route to recipient not found.");
    }
  }

  // ── RREQ flood ────────────────────────────────────────────────────────
  Future<void> _floodRreq(String destinationId) async {
    final packet = {
      'type': 'rreq',
      'originId': _myId,
      'originIp': _myIp,
      'originName': _myName,
      'destId': destinationId,
      'hopCount': 0,
      'rreqId': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    _broadcastToAllPeers(jsonEncode(packet).codeUnits);
  }

  // ── Broadcast routing announcement ─────────────────────────────────────
  void broadcastAnnouncement() {
    if (_myId == null || _myIp == null) return;
    final packet = {
      'type': 'announcement',
      'deviceId': _myId,
      'deviceName': _myName,
      'hopCount': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _broadcastToAllPeers(('JSON' + jsonEncode(packet)).codeUnits);
  }

  // ── Handle incoming MANET packet ──────────────────────────────────────
  Future<void> _handleIncoming(Socket socket) async {
    try {
      final bytes = <int>[];
      await for (final chunk in socket) {
        bytes.addAll(chunk);
      }
      if (bytes.isEmpty) return;

      final typeStr = String.fromCharCodes(bytes.sublist(0, 4)).trim();

      if (typeStr == 'JSON') {
        final json = jsonDecode(String.fromCharCodes(bytes.sublist(4)));
        _handleControlPacket(json, socket.remoteAddress.address);
      } else if (typeStr == 'DATA') {
        _handleDataPacket(bytes.sublist(4));
      } else if (typeStr == 'MSG_') {
        _handleMsgPacket(bytes.sublist(4));
      }
    } catch (e) {
      _log.e('MANET incoming error: $e');
    } finally {
      socket.close();
    }
  }

  void _handleControlPacket(Map<String, dynamic> packet, String fromIp) {
    switch (packet['type']) {
      case 'rreq':
        _handleRreq(packet, fromIp);
        break;
      case 'rrep':
        _handleRrep(packet, fromIp);
        break;
      case 'rerr':
        _handleRerr(packet);
        break;
      case 'announcement':
        _handleAnnouncement(packet, fromIp);
        break;
      case 'handshake':
        _handleHandshake(packet, fromIp);
        break;
    }
  }

  void _handleHandshake(Map<String, dynamic> packet, String fromIp) {
    final senderId = packet['deviceId'] as String;
    final senderName = packet['deviceName'] as String;
    final publicKey = packet['publicKey'] as String;
    final hashedPhone = packet['hashedPhone'] as String;

    routingTable.upsert(RouteEntry(
      destinationId: senderId,
      destinationName: senderName,
      nextHopId: senderId,
      nextHopIp: fromIp,
      nextHopPort: manetPort,
      hopCount: 1,
      lastSeen: DateTime.now(),
    ));
    onRoutingTableChanged?.call();

    onHandshakeReceived?.call(senderId, senderName, fromIp, publicKey, hashedPhone);
  }

  void _handleRreq(Map<String, dynamic> rreq, String fromIp) {
    final destId = rreq['destId'] as String;
    final originId = rreq['originId'] as String;
    final originName = rreq['originName'] as String?;
    final hopCount = (rreq['hopCount'] as int) + 1;

    if (hopCount > hopLimit) return;

    routingTable.upsert(RouteEntry(
      destinationId: originId,
      destinationName: originName,
      nextHopId: originId,
      nextHopIp: fromIp,
      nextHopPort: manetPort,
      hopCount: hopCount,
      lastSeen: DateTime.now(),
    ));
    onRoutingTableChanged?.call();

    if (destId == _myId) {
      _sendRrep(
        originId: originId,
        originIp: fromIp,
        destId: destId,
        destName: _myName!,
        hopCount: hopCount,
        publicKey: ProfileService.currentProfile!.publicKey,
      );
    } else {
      final forwarded = Map<String, dynamic>.from(rreq);
      forwarded['hopCount'] = hopCount;
      _broadcastToAllPeers(
        ('JSON' + jsonEncode(forwarded)).codeUnits,
        excludeIp: fromIp,
      );
    }
  }

  void _handleRrep(Map<String, dynamic> rrep, String fromIp) {
    final destId = rrep['destId'] as String;
    final destName = rrep['destName'] as String?;
    final originId = rrep['originId'] as String;
    final hopCount = (rrep['hopCount'] as int);
    final publicKey = rrep['publicKey'] as String? ?? '';

    routingTable.upsert(RouteEntry(
      destinationId: destId,
      destinationName: destName,
      nextHopId: destId,
      nextHopIp: fromIp,
      nextHopPort: manetPort,
      hopCount: hopCount,
      lastSeen: DateTime.now(),
    ));
    onRoutingTableChanged?.call();

    if (publicKey.isNotEmpty && onHandshakeReceived != null) {
      onHandshakeReceived?.call(destId, destName ?? 'Contact', fromIp, publicKey, destId);
    }

    if (originId != _myId) {
      final route = routingTable.lookup(originId);
      if (route != null) {
        _sendPacket(route.nextHopIp, ('JSON' + jsonEncode(rrep)).codeUnits);
      }
    }
  }

  void _handleRerr(Map<String, dynamic> rerr) {
    final brokenDest = rerr['destId'] as String;
    routingTable.invalidate(brokenDest);
    onRoutingTableChanged?.call();
  }

  void _handleAnnouncement(Map<String, dynamic> announcement, String fromIp) {
    final senderId = announcement['deviceId'] as String;
    final senderName = announcement['deviceName'] as String?;
    final hopCount = (announcement['hopCount'] as int) + 1;

    if (senderId == _myId || hopCount > hopLimit) return;

    routingTable.upsert(RouteEntry(
      destinationId: senderId,
      destinationName: senderName,
      nextHopId: senderId,
      nextHopIp: fromIp,
      nextHopPort: manetPort,
      hopCount: hopCount,
      lastSeen: DateTime.now(),
    ));
    onRoutingTableChanged?.call();

    final forwarded = Map<String, dynamic>.from(announcement);
    forwarded['hopCount'] = hopCount;
    _broadcastToAllPeers(
      ('JSON' + jsonEncode(forwarded)).codeUnits,
      excludeIp: fromIp,
    );
  }

  void _sendRrep({
    required String originId,
    required String originIp,
    required String destId,
    required String destName,
    required int hopCount,
    required String publicKey,
  }) {
    final rrep = {
      'type': 'rrep',
      'originId': originId,
      'destId': destId,
      'destName': destName,
      'hopCount': hopCount,
      'publicKey': publicKey,
    };
    _sendPacket(originIp, ('JSON' + jsonEncode(rrep)).codeUnits);
  }

  void _handleDataPacket(List<int> bytes) {
    int offset = 0;

    int destIdLen = _readInt32(bytes, offset); offset += 4;
    final destId = String.fromCharCodes(bytes.sublist(offset, offset + destIdLen));
    offset += destIdLen;

    int originIdLen = _readInt32(bytes, offset); offset += 4;
    final originId = String.fromCharCodes(
        bytes.sublist(offset, offset + originIdLen));
    offset += originIdLen;

    int nameLen = _readInt32(bytes, offset); offset += 4;
    final fileName = String.fromCharCodes(bytes.sublist(offset, offset + nameLen));
    offset += nameLen;

    int hopCount = _readInt32(bytes, offset); offset += 4;
    final data = bytes.sublist(offset);

    if (destId == _myId) {
      _log.i('MANET: file arrived: $fileName from $originId');
      onDataReceived(originId, fileName, data);
    } else {
      final route = routingTable.lookup(destId);
      if (route != null) {
        _log.i('MANET: relaying $fileName to $destId via ${route.nextHopIp}');
        final newPacket = _buildDataPacket(
          destId: destId,
          originId: originId,
          fileName: fileName,
          data: data,
          hopCount: hopCount + 1,
        );
        _sendPacket(route.nextHopIp, newPacket);
        onRelay(fileName, destId, route.nextHopIp);
      } else {
        _log.w('MANET: no route to $destId for relay — sending RERR');
        _sendRerr(destId);
      }
    }
  }

  void _sendRerr(String brokenDestId) {
    final rerr = {'type': 'rerr', 'destId': brokenDestId};
    _broadcastToAllPeers(('JSON' + jsonEncode(rerr)).codeUnits);
  }

  // ── Packet builders ───────────────────────────────────────────────────
  List<int> _buildDataPacket({
    required String destId,
    required String originId,
    required String fileName,
    required List<int> data,
    required int hopCount,
  }) {
    final buf = <int>[];
    buf.addAll('DATA'.codeUnits);

    final destBytes = destId.codeUnits;
    buf.addAll(_int32(destBytes.length));
    buf.addAll(destBytes);

    final origBytes = originId.codeUnits;
    buf.addAll(_int32(origBytes.length));
    buf.addAll(origBytes);

    final nameBytes = fileName.codeUnits;
    buf.addAll(_int32(nameBytes.length));
    buf.addAll(nameBytes);

    buf.addAll(_int32(hopCount));
    buf.addAll(data);
    return buf;
  }

  // ── Network helpers ───────────────────────────────────────────────────
  final List<String> _knownPeerIps = [];

  void addKnownPeer(String ip) {
    if (!_knownPeerIps.contains(ip)) {
      _knownPeerIps.add(ip);
    }
  }

  void removeKnownPeer(String ip) {
    _knownPeerIps.remove(ip);
    routingTable.invalidate(ip);
    onRoutingTableChanged?.call();
  }

  void _broadcastToAllPeers(List<int> packet, {String? excludeIp}) {
    for (final ip in _knownPeerIps) {
      if (ip != excludeIp) {
        _sendPacket(ip, packet);
      }
    }
  }

  Future<void> _sendPacket(String ip, List<int> packet) async {
    try {
      final socket = await Socket.connect(
        ip, manetPort,
        timeout: const Duration(seconds: 5),
      );
      socket.add(packet);
      await socket.flush();
      await socket.close();
    } catch (e) {
      _log.e('MANET send error to $ip: $e');
      routingTable.invalidate(ip);
      onRoutingTableChanged?.call();
    }
  }

  int _readInt32(List<int> bytes, int offset) {
    return (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
  }

  List<int> _buildMsgPacket({
    required String destId,
    required String originId,
    required String originName,
    required String messageJson,
    required int hopCount,
  }) {
    final buf = <int>[];
    buf.addAll('MSG_'.codeUnits);

    final destBytes = destId.codeUnits;
    buf.addAll(_int32(destBytes.length));
    buf.addAll(destBytes);

    final origBytes = originId.codeUnits;
    buf.addAll(_int32(origBytes.length));
    buf.addAll(origBytes);

    final nameBytes = originName.codeUnits;
    buf.addAll(_int32(nameBytes.length));
    buf.addAll(nameBytes);

    buf.addAll(_int32(hopCount));

    final msgBytes = messageJson.codeUnits;
    buf.addAll(msgBytes);
    return buf;
  }

  void _handleMsgPacket(List<int> bytes) {
    int offset = 0;

    int destIdLen = _readInt32(bytes, offset); offset += 4;
    final destId = String.fromCharCodes(bytes.sublist(offset, offset + destIdLen));
    offset += destIdLen;

    int originIdLen = _readInt32(bytes, offset); offset += 4;
    final originId = String.fromCharCodes(bytes.sublist(offset, offset + originIdLen));
    offset += originIdLen;

    int originNameLen = _readInt32(bytes, offset); offset += 4;
    final originName = String.fromCharCodes(bytes.sublist(offset, offset + originNameLen));
    offset += originNameLen;

    int hopCount = _readInt32(bytes, offset); offset += 4;
    final messageJson = String.fromCharCodes(bytes.sublist(offset));

    if (destId == _myId) {
      _log.i('MANET: message from $originId ($originName) arrived');
      onMessageReceived?.call(originId, originName, destId, messageJson);
    } else {
      final route = routingTable.lookup(destId);
      if (route != null) {
        final newPacket = _buildMsgPacket(
          destId: destId,
          originId: originId,
          originName: originName,
          messageJson: messageJson,
          hopCount: hopCount + 1,
        );
        _sendPacket(route.nextHopIp, newPacket);
      } else {
        _log.w('MANET: no route to $destId to relay message — sending RERR');
        _sendRerr(destId);
      }
    }
  }

  static List<int> _int32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];
}