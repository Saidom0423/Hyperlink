import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer_device.dart';
import '../models/routing_table.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import '../services/wifi_direct_service.dart';
import '../services/manet_service.dart';
import '../services/file_service.dart';
import '../services/contacts_service.dart';
import '../services/profile_service.dart';
import '../services/peer_name_service.dart';
import 'package:path_provider/path_provider.dart';

// ── Transfer state ────────────────────────────────────────────────────────

class TransferState {
  final String? activeFile;
  final double progress;
  final String? lastReceivedPath;
  final String? lastReceivedName;

  const TransferState({
    this.activeFile,
    this.progress = 0,
    this.lastReceivedPath,
    this.lastReceivedName,
  });

  TransferState copyWith({
    String? activeFile,
    double? progress,
    String? lastReceivedPath,
    String? lastReceivedName,
  }) =>
      TransferState(
        activeFile: activeFile ?? this.activeFile,
        progress: progress ?? this.progress,
        lastReceivedPath: lastReceivedPath ?? this.lastReceivedPath,
        lastReceivedName: lastReceivedName ?? this.lastReceivedName,
      );
}

// ── Network state ─────────────────────────────────────────────────────────

class NetworkState {
  final List<PeerDevice> peers;
  final bool isScanning;
  final String? error;
  final TransferState transfer;

  const NetworkState({
    this.peers = const [],
    this.isScanning = false,
    this.error,
    this.transfer = const TransferState(),
  });

  NetworkState copyWith({
    List<PeerDevice>? peers,
    bool? isScanning,
    String? error,
    TransferState? transfer,
  }) =>
      NetworkState(
        peers: peers ?? this.peers,
        isScanning: isScanning ?? this.isScanning,
        error: error ?? this.error,
        transfer: transfer ?? this.transfer,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class NetworkNotifier extends StateNotifier<NetworkState> {
  late final ManetService _manet;
  late final DiscoveryService _discovery;
  late final TransferService _transfer;
  final WifiDirectService _wifiDirect = WifiDirectService();

  RawDatagramSocket? _udpSocket;
  Timer? _udpPingTimer;
  Timer? _bgScanTimer;

  String? _pendingFilePath;

  bool _manetStarted = false;
  String? _currentManetIp;
  Timer? _manetAnnouncementTimer;

  String? _groupOwnerIp;      // GO's IP — valid only when WE are the CLIENT
  bool   _isGroupOwner = false;
  String? _lastClientIp;      // client's IP — valid only when WE are the GO
  bool _groupFormed = false;

  final Map<String, String> _hashToMacAddress = {};
  final Map<String, DateTime> _connectionAttempts = {};
  final Map<String, DateTime> _firstDiscoveredTimes = {};

  // Chat callback — set by ChatNotifier after construction
  void Function(String fromId, String senderName, String json)? onChatMessageReceived;
  void Function(String fromId, String senderName, String filePath)? onFileReceived;

  NetworkNotifier() : super(const NetworkState()) {
    _discovery = DiscoveryService(
      onPeerFound: _addPeer,
      onPeerLost: _removePeer,
    );

    _manet = ManetService(
      onDataReceived: (fromId, fileName, fileData) async {
        debugPrint('MANET: file arrived: $fileName from $fromId');
        
        state = state.copyWith(
          transfer: state.transfer.copyWith(
            activeFile: fileName,
            progress: 0.5,
          ),
        );

        // Save local copy for app/chat rendering
        String? localPath;
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final receivedDir = Directory('${appDir.path}/received_files');
          if (!await receivedDir.exists()) await receivedDir.create(recursive: true);
          localPath = '${receivedDir.path}/$fileName';
          await File(localPath).writeAsBytes(fileData);
        } catch (e) {
          debugPrint('MANET local save failed: $e');
        }

        String? savedPath;
        try {
          savedPath = await FileService.saveFile(fileName, fileData);
        } catch (e) {
          debugPrint('MANET MediaStore save failed: $e');
        }

        if (savedPath == null) {
          try {
            final dir = Directory('/storage/emulated/0/Download/Hyperlink');
            if (!await dir.exists()) await dir.create(recursive: true);
            final path = '${dir.path}/$fileName';
            await File(path).writeAsBytes(fileData);
            savedPath = path;
          } catch (e) {
            debugPrint('MANET Downloads fallback save failed: $e');
          }
        }

        if (savedPath != null) {
          state = state.copyWith(
            transfer: state.transfer.copyWith(
              activeFile: null,
              progress: 0,
              lastReceivedName: fileName,
              lastReceivedPath: savedPath,
            ),
          );
        } else {
          state = state.copyWith(
            transfer: state.transfer.copyWith(
              activeFile: null,
              progress: 0,
            ),
            error: 'Failed to save MANET file: $fileName',
          );
        }

        if (localPath != null) {
          final peer = state.peers.cast<PeerDevice?>().firstWhere((p) => p?.id == fromId, orElse: () => null);
          final senderName = peer?.name ?? 'Contact';
          PeerNameService.save(fromId, senderName);
          onFileReceived?.call(fromId, senderName, localPath);
        }
      },
      onRelay: (fileName, destId, nextHopIp) {
        debugPrint('Relaying $fileName to $destId via $nextHopIp');
        state = state.copyWith(
          transfer: state.transfer.copyWith(
            activeFile: '[Relaying] $fileName',
            progress: 0.5,
          ),
        );
        
        Timer(const Duration(seconds: 3), () {
          if (mounted && state.transfer.activeFile == '[Relaying] $fileName') {
            state = state.copyWith(
              transfer: state.transfer.copyWith(
                activeFile: null,
                progress: 0,
              ),
            );
          }
        });
      },
    );

    _manet.onRoutingTableChanged = () {
      _syncRoutingTableWithPeers();
    };

    _manet.onHandshakeReceived = _handleHandshakeReceived;

    _manet.onMessageReceived = (fromId, senderName, recipientId, json) {
      debugPrint('MANET: chat message from $senderName ($fromId)');
      onChatMessageReceived?.call(fromId, senderName, json);
    };

    _transfer = TransferService(
      onConnectionReceived: (remoteIp) {
        _handleIncomingConnectionIp(remoteIp);
      },
      onReceiveProgress: (name, progress) {
        state = state.copyWith(
          transfer: state.transfer.copyWith(
            activeFile: name,
            progress: progress,
          ),
        );
      },
      onSendProgress: (name, progress) {
        state = state.copyWith(
          transfer: state.transfer.copyWith(
            activeFile: name,
            progress: progress,
          ),
        );
      },
      onReceiveComplete: (name, path, senderId, senderName) {
        state = state.copyWith(
          transfer: state.transfer.copyWith(
            activeFile: null,
            progress: 0,
            lastReceivedName: name,
            lastReceivedPath: path,
          ),
        );

        onFileReceived?.call(senderId, senderName, path);
      },
    );

    // ── Hook Wi-Fi Direct connection events into the provider ──────────────
    WifiDirectService.initialize();
    WifiDirectService.onConnectionChanged = (info) async {
      final groupFormed = info['groupFormed'] == true;
      _groupFormed = groupFormed;

      final rawIp = (info['groupOwnerIp'] as String? ?? '').trim();
      final groupOwnerIp = (rawIp == '0.0.0.0' || rawIp.isEmpty) ? '' : rawIp;
      final isGroupOwner = info['isGroupOwner'] == true;
      final ownerAddress = info['ownerAddress'] as String?;

      debugPrint('WFD onConnectionChanged: groupFormed=$groupFormed ip=$groupOwnerIp isGO=$isGroupOwner owner=$ownerAddress');

      if (!groupFormed) {
        _groupOwnerIp = null;
        _isGroupOwner = false;
        _firstDiscoveredTimes.clear();
        _connectionAttempts.clear();
        try {
          await _wifiDirect.clearDiscoveredPeers();
        } catch (_) {}
        // Mark all peers offline when disconnected
        _clearPeersNetworkStatus();
        return;
      }

      await _resolveLocalIpAndStartManet();

      _isGroupOwner = isGroupOwner;
      _groupOwnerIp = (isGroupOwner || groupOwnerIp.isEmpty) ? null : groupOwnerIp;

      if (groupOwnerIp.isEmpty) return;

      _manet.addKnownPeer(groupOwnerIp);

      if (!isGroupOwner) {
        // We are Client, immediately trigger handshake to GO
        debugPrint('Client initiating handshake to GO at $groupOwnerIp');
        _manet.sendHandshake(groupOwnerIp);

        // Map GO IP in peers list
        final updated = state.peers.map((p) {
          if (ownerAddress != null && p.id.toLowerCase() == ownerAddress.toLowerCase()) {
            return p.copyWith(ip: groupOwnerIp, status: PeerStatus.connected, hops: 1);
          }
          return p;
        }).toList();
        state = state.copyWith(peers: updated);
      }
    };

    WifiDirectService.onPeersChanged = (rawPeers) {
      debugPrint('WFD onPeersChanged: ${rawPeers.length} peer(s)');
      for (final peer in rawPeers) {
        final name = peer['name'] ?? '';
        final mac = peer['address'] ?? '';
        
        if (name.startsWith('HP_') && name.length == 23) {
          final hash = name.substring(3);
          _hashToMacAddress[hash] = mac;
          
          final contact = ContactsService.lookupHash(hash);
          if (contact != null) {
            debugPrint('Discovered contact ${contact.name} ($hash) at MAC $mac');
            _markContactAsDiscovered(hash, mac);
          } else {
            debugPrint('Discovered nearby non-contact $name ($hash) at MAC $mac');
            _markNearbyPeerAsDiscovered(hash, mac);
          }
        }
      }
    };

    _startUdpPingService();
    _startSendingPings();
    _initialize();
  }

  Future<void> _initialize() async {
    // Wait until profile is loaded
    await ProfileService.loadProfile();
    
    try {
      await _transfer.startServer();
    } catch (e) {
      state = state.copyWith(error: 'Server start failed: $e');
    }

    try {
      await _wifiDirect.removeGroup();
    } catch (_) {}

    // Import contacts and setup initial offline list
    if (ProfileService.isProfileSetup) {
      await syncContactsAndInitialize();
      await startScanning();
    }
  }

  Future<void> syncContactsAndInitialize() async {
    await ContactsService.syncContacts();
    
    final Map<String, PeerDevice> preservedPeers = {
      for (final p in state.peers)
        if (p.hops != -1 || p.ip.isNotEmpty || p.publicKey.isNotEmpty)
          p.id: p
    };

    final List<PeerDevice> newPeers = [];
    
    for (final c in ContactsService.contacts) {
      if (preservedPeers.containsKey(c.hash)) {
        newPeers.add(preservedPeers[c.hash]!.copyWith(name: c.name));
        preservedPeers.remove(c.hash);
      } else {
        newPeers.add(PeerDevice(
          id: c.hash,
          name: c.name,
          ip: '',
          port: 8765,
          publicKey: '',
          hops: -1,
          status: PeerStatus.discovered,
        ));
      }
    }

    newPeers.addAll(preservedPeers.values);
    state = state.copyWith(peers: newPeers);
  }

  void _clearPeersNetworkStatus() {
    final offlinePeers = state.peers.map((p) {
      return p.copyWith(
        ip: '',
        hops: -1,
        status: PeerStatus.discovered,
        nextHopId: null,
      );
    }).toList();
    state = state.copyWith(peers: offlinePeers);
  }

  void _handleHandshakeReceived(String id, String name, String ip, String publicKey, String hashedPhone) {
    debugPrint('Received handshake from contact ID: $id (IP: $ip)');
    
    PeerNameService.save(id, name);
    
    _manet.addKnownPeer(ip);
    
    _manet.routingTable.upsert(RouteEntry(
      destinationId: id,
      destinationName: name,
      nextHopId: id,
      nextHopIp: ip,
      nextHopPort: ManetService.manetPort,
      hopCount: 1,
      lastSeen: DateTime.now(),
    ));
    
    final idx = state.peers.indexWhere((p) => p.id == id);
    bool shouldReply = _isGroupOwner;

    if (idx != -1) {
      final existing = state.peers[idx];
      if (existing.publicKey != publicKey) {
        shouldReply = true;
      }
      final updatedPeer = existing.copyWith(
        ip: ip,
        publicKey: publicKey,
        status: PeerStatus.connected,
        hops: 1,
        name: name,
      );
      final list = List<PeerDevice>.from(state.peers);
      list[idx] = updatedPeer;
      state = state.copyWith(peers: list);

      _checkAndTriggerPendingTransfer(updatedPeer);
      if (onChatMessageReceived != null) {
        // Let chat notifier know routes updated
        _syncRoutingTableWithPeers();
      }
    } else {
      shouldReply = true;
      final newPeer = PeerDevice(
        id: id,
        name: name,
        ip: ip,
        port: 8765,
        publicKey: publicKey,
        hops: 1,
        status: PeerStatus.connected,
      );
      final list = List<PeerDevice>.from(state.peers)..add(newPeer);
      state = state.copyWith(peers: list);
      _checkAndTriggerPendingTransfer(newPeer);
      _syncRoutingTableWithPeers();
    }

    if (shouldReply) {
      debugPrint('Replying with handshake to $ip');
      _manet.sendHandshake(ip);
    }
  }

  void _triggerAutoConnect(PeerDevice peer, String mac) {
    if (_groupFormed) return;

    final myHash = ProfileService.currentProfile!.hashedPhone;
    final hash = peer.id;
    final isInitiator = myHash.compareTo(hash) < 0;

    final lastAttempt = _connectionAttempts[mac];
    final now = DateTime.now();

    if (isInitiator) {
      if (lastAttempt == null || now.difference(lastAttempt).inSeconds > 20) {
        _connectionAttempts[mac] = now;
        debugPrint('Auto-connecting: We ($myHash) < Peer ($hash). Triggering connect to $mac');
        connectToPeer(peer);
      }
    } else {
      // Fallback: If we have a larger hash, wait 8 seconds from discovery to see if group forms.
      // If not, we initiate the connection as fallback.
      final firstDiscovered = _firstDiscoveredTimes[mac] ??= now;
      if (now.difference(firstDiscovered).inSeconds >= 8) {
        if (lastAttempt == null || now.difference(lastAttempt).inSeconds > 20) {
          _connectionAttempts[mac] = now;
          debugPrint('Fallback auto-connecting: We ($myHash) > Peer ($hash) and group not formed after 8s. Triggering connect to $mac');
          connectToPeer(peer);
        }
      }
    }
  }

  void _markNearbyPeerAsDiscovered(String hash, String mac) {
    final idx = state.peers.indexWhere((p) => p.id == hash);
    PeerDevice targetPeer;
    if (idx == -1) {
      targetPeer = PeerDevice(
        id: hash,
        name: 'Nearby Peer (${hash.substring(0, 6)})',
        ip: '',
        port: 8765,
        publicKey: '',
        hops: -1,
        status: PeerStatus.discovered,
      );
      final list = List<PeerDevice>.from(state.peers)..add(targetPeer);
      state = state.copyWith(peers: list);
    } else {
      final peer = state.peers[idx];
      if (peer.hops == -1) {
        targetPeer = peer.copyWith(hops: -1, status: PeerStatus.discovered);
        final list = List<PeerDevice>.from(state.peers);
        list[idx] = targetPeer;
        state = state.copyWith(peers: list);
      } else {
        targetPeer = peer;
      }
    }

    _triggerAutoConnect(targetPeer, mac);
  }

  void _markContactAsDiscovered(String hash, String mac) {
    final idx = state.peers.indexWhere((p) => p.id == hash);
    if (idx == -1) return;

    var peer = state.peers[idx];
    if (peer.hops == -1) {
      // Discovered in-range but not yet connected
      peer = peer.copyWith(hops: -1, status: PeerStatus.discovered);
      final list = List<PeerDevice>.from(state.peers);
      list[idx] = peer;
      state = state.copyWith(peers: list);
    }

    _triggerAutoConnect(peer, mac);
  }

  // ── UDP Ping Service for Peer IP Exchange ──────────────────────────────────
  Future<void> _startUdpPingService() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8766);
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            final msg = utf8.decode(dg.data);
            if (msg.startsWith('HYPERLINK_PING:')) {
              final parts = msg.split(':');
              if (parts.length >= 4) {
                final id = parts[1];
                final ip = parts[2];
                final name = parts[3];
                _handleUdpPing(id, ip, name);
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to start UDP Ping Service: $e');
    }
  }

  void _startSendingPings() {
    _udpPingTimer?.cancel();
    _udpPingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final interfaces = await NetworkInterface.list();
        final allIps = <String>[];
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              allIps.add(addr.address);
            }
          }
        }

        final wfdIps = allIps.where((ip) => ip.startsWith('192.168.49.')).toList();
        final ipsToAdvertise = wfdIps.isNotEmpty ? wfdIps : allIps;

        for (final myIp in ipsToAdvertise) {
          await _ensureManetStarted(myIp);

          final data = utf8.encode('HYPERLINK_PING:$myDeviceId:$myIp:$myDeviceName');
          final broadcastIp = _getBroadcastAddress(myIp);

          RawDatagramSocket? senderSocket;
          try {
            senderSocket = await RawDatagramSocket.bind(myIp, 0);
            senderSocket.broadcastEnabled = true;
            senderSocket.send(data, InternetAddress(broadcastIp), 8766);
            senderSocket.send(data, InternetAddress('255.255.255.255'), 8766);
          } catch (e) {
            try {
              _udpSocket?.send(data, InternetAddress(broadcastIp), 8766);
              _udpSocket?.send(data, InternetAddress('255.255.255.255'), 8766);
            } catch (_) {}
          } finally {
            senderSocket?.close();
          }
        }
      } catch (e) {
        debugPrint('Failed to send UDP ping: $e');
      }
    });
  }

  String _getBroadcastAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    }
    return '255.255.255.255';
  }

  void _handleUdpPing(String peerId, String peerIp, String peerName) {
    if (peerIp.isEmpty || peerIp == '0.0.0.0' || peerId == myDeviceId) return;

    _manet.addKnownPeer(peerIp);

    _manet.routingTable.upsert(RouteEntry(
      destinationId: peerId,
      destinationName: peerName,
      nextHopId: peerId,
      nextHopIp: peerIp,
      nextHopPort: ManetService.manetPort,
      hopCount: 1,
      lastSeen: DateTime.now(),
    ));

    final idx = state.peers.indexWhere((p) => p.id == peerId);
    if (idx != -1) {
      final existing = state.peers[idx];
      if (existing.publicKey.isEmpty) {
        debugPrint('Public key is empty for ${existing.name}. Sending handshake to $peerIp');
        _manet.sendHandshake(peerIp);
      }
      if (existing.ip != peerIp) {
        if (existing.ip.startsWith('192.168.49.') && !peerIp.startsWith('192.168.49.')) {
          return;
        }

        debugPrint('Updating peer ${existing.name} IP via UDP ping → $peerIp');
        final updatedPeer = existing.copyWith(
          ip: peerIp,
          status: PeerStatus.connected,
          hops: 1,
        );
        final updated = List<PeerDevice>.from(state.peers);
        updated[idx] = updatedPeer;
        state = state.copyWith(peers: updated);
        _checkAndTriggerPendingTransfer(updatedPeer);
      }
    } else {
      debugPrint('Discovered new peer $peerName ($peerId) at IP $peerIp via UDP ping');
      final newPeer = PeerDevice(
        id: peerId,
        name: peerName,
        ip: peerIp,
        port: 8765,
        publicKey: '',
        hops: 1,
        status: PeerStatus.connected,
      );
      final updated = List<PeerDevice>.from(state.peers)..add(newPeer);
      state = state.copyWith(peers: updated);
      _checkAndTriggerPendingTransfer(newPeer);
      _manet.sendHandshake(peerIp);
    }
  }

  void setPendingTransfer(String filePath) {
    _pendingFilePath = filePath;
    debugPrint('Pending file transfer set: $filePath');
  }

  void _checkAndTriggerPendingTransfer(PeerDevice peer) {
    if (_pendingFilePath != null && peer.ip.isNotEmpty) {
      final path = _pendingFilePath!;
      _pendingFilePath = null;
      debugPrint('Triggering pending file transfer to ${peer.name} (${peer.ip}): $path');
      sendFile(peer, path);
    }
  }

  // ── Wi-Fi Direct Actions ──────────────────────────────────────────────────

  Future<bool> connectToPeer(PeerDevice peer) async {
    try {
      state = state.copyWith(error: null);
      final mac = _hashToMacAddress[peer.id];
      if (mac == null) {
        throw StateError("MAC Address for ${peer.name} not found in scans.");
      }
      
      debugPrint('Connecting to peer: ${peer.name} (MAC: $mac)');
      final success = await _wifiDirect.connectPeer(mac);
      return success;
    } catch (e) {
      state = state.copyWith(error: 'Connection failed: $e');
      return false;
    }
  }

  Future<void> startScanning() async {
    if (state.isScanning) return;

    state = state.copyWith(
      isScanning: true,
      error: null,
    );

    try {
      await _discovery.start();
      await _wifiDirect.discoverPeers();
      
      final myHash = ProfileService.currentProfile?.hashedPhone;
      if (myHash != null) {
        await _wifiDirect.startAdvertising(myHash);
      }
      await _wifiDirect.startServiceDiscovery();
      
      _bgScanTimer?.cancel();
      _bgScanTimer = Timer.periodic(const Duration(seconds: 12), (timer) async {
        await startWifiDirectDiscovery();
      });
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: e.toString(),
      );
    }
  }

  Future<void> stopScanning() async {
    _bgScanTimer?.cancel();
    await _discovery.stop();
    try {
      await _wifiDirect.stopAdvertising();
      await _wifiDirect.stopServiceDiscovery();
    } catch (_) {}
    state = state.copyWith(isScanning: false);
  }

  Future<void> startWifiDirectDiscovery() async {
    try {
      await _wifiDirect.discoverPeers();
      await _wifiDirect.startServiceDiscovery();
    } catch (e) {
      debugPrint('Wi-Fi Direct discovery failed: $e');
    }
  }

  Future<void> disconnectWifiDirect() async {
    try {
      await _wifiDirect.removeGroup();
    } catch (e) {
      debugPrint('Disconnect failed: $e');
    }
  }

  Future<void> sendFile(PeerDevice peer, String filePath) async {
    final fileName = File(filePath).uri.pathSegments.last;
    try {
      state = state.copyWith(
        error: null,
        transfer: state.transfer.copyWith(
          activeFile: fileName,
          progress: 0.05,
        ),
      );

      var resolvedPeer = peer;
      if (resolvedPeer.ip.isEmpty || resolvedPeer.ip == '0.0.0.0') {
        final fresh = state.peers.firstWhere(
          (p) => p.id == peer.id,
          orElse: () => peer,
        );
        if (fresh.ip.isNotEmpty && fresh.ip != '0.0.0.0') {
          resolvedPeer = fresh;
        }
      }

      if (resolvedPeer.ip.isEmpty || resolvedPeer.ip == '0.0.0.0') {
        final fallback = _isGroupOwner ? _lastClientIp : _groupOwnerIp;
        if (fallback != null && fallback.isNotEmpty) {
          resolvedPeer = resolvedPeer.copyWith(ip: fallback);
        }
      }

      if (resolvedPeer.ip.isEmpty || resolvedPeer.ip == '0.0.0.0') {
        throw StateError('Cannot send: IP for ${peer.name} is unknown.');
      }

      if (resolvedPeer.hops > 1) {
        final file = File(filePath);
        final fileData = await file.readAsBytes();

        await _manet.sendData(
          destinationId: resolvedPeer.id,
          destinationIp: resolvedPeer.ip,
          fileName: fileName,
          fileData: fileData,
        );
      } else {
        await _transfer.sendFile(
          peer: resolvedPeer,
          filePath: filePath,
          senderId: ProfileService.currentProfile!.hashedPhone,
          senderName: ProfileService.currentProfile!.name,
        );
      }

      state = state.copyWith(
        transfer: state.transfer.copyWith(
          activeFile: null,
          progress: 0.0,
        ),
      );
    } catch (e) {
      debugPrint('sendFile error: $e');
      state = state.copyWith(
        transfer: state.transfer.copyWith(
          activeFile: null,
          progress: 0.0,
        ),
        error: e.toString(),
      );
    }
  }

  Future<void> sendChatMessage({
    required PeerDevice peer,
    required String messageJson,
  }) async {
    var resolvedPeer = peer;
    if (resolvedPeer.ip.isEmpty || resolvedPeer.ip == '0.0.0.0') {
      final fresh = state.peers.firstWhere(
        (p) => p.id == peer.id,
        orElse: () => peer,
      );
      if (fresh.ip.isNotEmpty && fresh.ip != '0.0.0.0') {
        resolvedPeer = fresh;
      }
    }
    if (resolvedPeer.ip.isEmpty || resolvedPeer.ip == '0.0.0.0') {
      final fallback = _isGroupOwner ? _lastClientIp : _groupOwnerIp;
      if (fallback != null && fallback.isNotEmpty) {
        resolvedPeer = resolvedPeer.copyWith(ip: fallback);
      }
    }
    if (resolvedPeer.ip.isEmpty || resolvedPeer.ip == '0.0.0.0') {
      throw StateError('Cannot send message: IP for ${peer.name} is unknown.');
    }

    await _manet.sendMessage(
      destinationId: resolvedPeer.id,
      destinationIp: resolvedPeer.ip,
      messageJson: messageJson,
      hops: resolvedPeer.hops,
    );
  }

  void _addPeer(PeerDevice peer) {
    // Keep list unique by hash ID
    final updated = [
      ...state.peers.where((p) => p.id != peer.id),
      peer,
    ];
    state = state.copyWith(peers: updated);
  }

  void _removePeer(String peerId) {
    final existing = state.peers.cast<PeerDevice?>().firstWhere((p) => p?.id == peerId, orElse: () => null);
    if (existing != null && existing.ip.isNotEmpty) {
      _manet.removeKnownPeer(existing.ip);
    }

    final updated = state.peers.where((p) => p.id != peerId).toList();
    state = state.copyWith(peers: updated);
  }

  Future<void> _resolveLocalIpAndStartManet() async {
    try {
      final interfaces = await NetworkInterface.list();
      String? myIp;
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            if (addr.address.startsWith('192.168.49.')) {
              myIp = addr.address;
              break;
            }
          }
        }
      }
      
      if (myIp == null) {
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              myIp = addr.address;
              break;
            }
          }
        }
      }

      if (myIp != null) {
        await _ensureManetStarted(myIp);
      }
    } catch (e) {
      debugPrint('Failed to resolve local IP and start MANET: $e');
    }
  }

  Future<void> _ensureManetStarted(String myIp) async {
    if (_manetStarted && _currentManetIp == myIp) return;

    try {
      _currentManetIp = myIp;
      await _manet.start(
        myIp: myIp,
        myId: myDeviceId,
        myName: myDeviceName,
      );
      _manetStarted = true;
      debugPrint('MANET profile updated for IP $myIp');

      _manetAnnouncementTimer ??= Timer.periodic(const Duration(seconds: 4), (timer) {
        _manet.broadcastAnnouncement();
        _syncRoutingTableWithPeers();
      });
    } catch (e) {
      debugPrint('Failed to start/update MANET service on $myIp: $e');
    }
  }

  void _syncRoutingTableWithPeers() {
    final routes = _manet.routingTable.allRoutes;
    var peersChanged = false;
    final updatedPeers = List<PeerDevice>.from(state.peers);

    final activeRouteDestinations = routes.map((r) => r.destinationId).toSet();

    // 1. Process active routes
    for (final route in routes) {
      if (route.destinationId == myDeviceId) continue;

      final existingIndex = updatedPeers.indexWhere((p) => p.id == route.destinationId);
      if (existingIndex != -1) {
        final existing = updatedPeers[existingIndex];
        // Safeguard: If we already have a verified direct connection (hops = 1),
        // do not downgrade it to a relayed route (hops > 1).
        if (existing.hops == 1 && route.hopCount > 1) {
          continue;
        }
        if (existing.hops != route.hopCount ||
            existing.nextHopId != route.nextHopId ||
            (route.hopCount > 1 && existing.ip != route.nextHopIp)) {
          updatedPeers[existingIndex] = existing.copyWith(
            hops: route.hopCount,
            nextHopId: route.nextHopId,
            ip: route.nextHopIp,
            status: route.hopCount == 1 ? PeerStatus.connected : PeerStatus.relaying,
          );
          peersChanged = true;
        }
      } else {
        final newPeer = PeerDevice(
          id: route.destinationId,
          name: route.destinationName ?? 'Nearby Peer (${route.destinationId.substring(0, 6)})',
          ip: route.nextHopIp,
          port: 8765,
          publicKey: '',
          hops: route.hopCount,
          status: route.hopCount == 1 ? PeerStatus.connected : PeerStatus.relaying,
          nextHopId: route.nextHopId,
        );
        updatedPeers.add(newPeer);
        peersChanged = true;
      }
    }

    // 2. Mark peers offline if they no longer have active routes in RoutingTable
    for (int i = 0; i < updatedPeers.length; i++) {
      final peer = updatedPeers[i];
      if (peer.hops != -1 && !activeRouteDestinations.contains(peer.id)) {
        updatedPeers[i] = peer.copyWith(
          ip: '',
          hops: -1,
          status: PeerStatus.discovered,
          nextHopId: null,
        );
        peersChanged = true;
      }
    }

    if (peersChanged) {
      state = state.copyWith(peers: updatedPeers);
    }
  }

  void _handleIncomingConnectionIp(String ip) {
    if (ip.isEmpty || ip == '0.0.0.0') return;
    debugPrint('Transfer connection received from IP: $ip');

    _lastClientIp = ip;
    _manet.addKnownPeer(ip);

    // Since a handshake will immediately follow and identify the client, 
    // we don't need ad-hoc client IP mappings here.
  }

  String get myDeviceId => _discovery.deviceId;
  String get myDeviceName => _discovery.deviceName;

  @override
  void dispose() {
    _bgScanTimer?.cancel();
    _manetAnnouncementTimer?.cancel();
    _manet.stop();
    _udpPingTimer?.cancel();
    _udpSocket?.close();
    _discovery.stop();
    _transfer.stopServer();
    super.dispose();
  }
}

final networkProvider =
StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  return NetworkNotifier();
});