import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer_device.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import '../services/wifi_direct_service.dart';

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
  late final DiscoveryService _discovery;
  late final TransferService _transfer;
  final WifiDirectService _wifiDirect = WifiDirectService();

  RawDatagramSocket? _udpSocket;
  Timer? _udpPingTimer;

  bool _isGroupFormed = false;
  bool _isConnecting = false;

  String? _pendingFilePath;

  NetworkNotifier() : super(const NetworkState()) {
    _discovery = DiscoveryService(
      onPeerFound: _addPeer,
      onPeerLost: _removePeer,
    );

    _transfer = TransferService(
      onReceiveProgress: (name, progress) {
        state = state.copyWith(
          transfer: state.transfer.copyWith(
            activeFile: name,
            progress: progress,
          ),
        );
      },
      onReceiveComplete: (name, path) {
        state = state.copyWith(
          transfer: state.transfer.copyWith(
            activeFile: null,
            progress: 0,
            lastReceivedName: name,
            lastReceivedPath: path,
          ),
        );
      },
    );

    // ── Hook Wi-Fi Direct connection events into the provider ──────────────
    WifiDirectService.initialize();
    WifiDirectService.onConnectionChanged = (info) {
      final groupFormed = info['groupFormed'] == true;
      _isGroupFormed = groupFormed;
      _isConnecting = false;

      final rawIp = (info['groupOwnerIp'] as String? ?? '').trim();
      final groupOwnerIp = (rawIp == '0.0.0.0' || rawIp.isEmpty) ? '' : rawIp;
      final isGroupOwner = info['isGroupOwner'] == true;

      debugPrint('WFD onConnectionChanged: groupFormed=$groupFormed ip=$groupOwnerIp isGroupOwner=$isGroupOwner');

      if (!groupFormed || groupOwnerIp.isEmpty) return;

      // If we are NOT the Group Owner, the peer is the Group Owner.
      // We can immediately set the peer's IP to the groupOwnerIp.
      if (!isGroupOwner) {
        PeerDevice? groupOwnerPeer;
        final updated = state.peers.map((p) {
          if (p.ip.trim().isEmpty || p.ip == '0.0.0.0') {
            debugPrint('Updating peer ${p.name} IP → $groupOwnerIp (as client)');
            final updatedPeer = p.copyWith(ip: groupOwnerIp);
            groupOwnerPeer = updatedPeer;
            return updatedPeer;
          }
          return p;
        }).toList();

        state = state.copyWith(peers: updated);
        if (groupOwnerPeer != null) {
          _checkAndTriggerPendingTransfer(groupOwnerPeer!);
        }
      }
    };

    WifiDirectService.onPeersChanged = (rawPeers) {
      debugPrint('WFD onPeersChanged: ${rawPeers.length} peer(s)');
      for (final peer in rawPeers) {
        final device = PeerDevice(
          id: peer['address'] ?? '',
          name: peer['name'] ?? 'Unknown Device',
          ip: '',  // resolved asynchronously via connection or UDP ping
          port: 8765,
          publicKey: '',
        );
        _addPeer(device);
      }
    };

    _startUdpPingService();
    _startSendingPings();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _transfer.startServer();
    } catch (e) {
      state = state.copyWith(
        error: 'Server start failed: $e',
      );
    }

    // Clear any stale Wi-Fi Direct group from a previous session —
    // this is a one-time cleanup so new connections aren't blocked.
    try {
      await _wifiDirect.removeGroup();
    } catch (_) {}

    try {
      await startScanning();
    } catch (e) {
      state = state.copyWith(
        error: 'Discovery failed: $e',
      );
    }
  }

  // ── UDP Ping Service for Peer IP Exchange over Wi-Fi Direct ──────────────

  Future<void> _startUdpPingService() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8766);
      _udpSocket!.broadcastEnabled = true;
      debugPrint('UDP Ping Service listening on port 8766');

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg != null) {
            final msg = utf8.decode(dg.data);
            debugPrint('Received UDP ping: $msg from ${dg.address.address}');
            if (msg.startsWith('HYPERLINK_PING:')) {
              final parts = msg.split(':');
              if (parts.length >= 4) {
                final id = parts[1];
                final ip = parts[2];
                final name = parts[3];
                _handleUdpPing(id, ip, name);
              } else if (parts.length == 3) {
                final ip = parts[1];
                final name = parts[2];
                _handleUdpPing(ip, ip, name);
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to start UDP Ping Service: $e');
    }
  }

  String _getBroadcastAddress(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}.255';
    }
    return '255.255.255.255';
  }

  void _startSendingPings() {
    _udpPingTimer?.cancel();
    _udpPingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final interfaces = await NetworkInterface.list();
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              final myIp = addr.address;
              final data = utf8.encode('HYPERLINK_PING:$myDeviceId:$myIp:$myDeviceName');
              
              // Broadcast to interface's broadcast address
              final broadcastIp = _getBroadcastAddress(myIp);
              _udpSocket?.send(data, InternetAddress(broadcastIp), 8766);
              
              // Also send to the global broadcast address for extra redundancy
              _udpSocket?.send(data, InternetAddress('255.255.255.255'), 8766);
              
              debugPrint('Sent UDP ping: $myIp (broadcast: $broadcastIp) from $myDeviceName');
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to send UDP ping: $e');
      }
    });
  }

  void _handleUdpPing(String peerId, String peerIp, String peerName) {
    if (peerIp.isEmpty || peerIp == '0.0.0.0' || peerId == myDeviceId) return;

    final existingIndex = state.peers.indexWhere((p) => p.id == peerId);
    if (existingIndex != -1) {
      final existing = state.peers[existingIndex];
      if (existing.ip != peerIp || existing.name != peerName) {
        debugPrint('Updating peer $peerName IP/Name via UDP ping → $peerIp');
        final updatedPeer = existing.copyWith(ip: peerIp, name: peerName);
        final updated = List<PeerDevice>.from(state.peers);
        updated[existingIndex] = updatedPeer;
        state = state.copyWith(peers: updated);
        _checkAndTriggerPendingTransfer(updatedPeer);
      }
    } else {
      debugPrint('Adding new peer $peerName via UDP ping → $peerIp');
      final newPeer = PeerDevice(
        id: peerId,
        name: peerName,
        ip: peerIp,
        port: 8765,
        publicKey: '',
      );
      _addPeer(newPeer);
      _checkAndTriggerPendingTransfer(newPeer);
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
      debugPrint('Connecting to peer: ${peer.name} (${peer.id})');
      final success = await _wifiDirect.connectPeer(peer.id);
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
      // Do NOT remove existing Wi-Fi Direct groups here — that would
      // destroy active connections.  Groups are only removed explicitly
      // via the disconnect action.
      await _discovery.start();
      await _wifiDirect.discoverPeers();
      
      // Keep isScanning true for 10 seconds to show active scanning in UI
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          state = state.copyWith(isScanning: false);
        }
      });
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: e.toString(),
      );
    }
  }

  Future<void> stopScanning() async {
    await _discovery.stop();
    state = state.copyWith(isScanning: false);
  }

  /// Start Wi-Fi Direct peer discovery without touching group state.
  /// Safe to call while already connected — will not disrupt active groups.
  Future<void> startWifiDirectDiscovery() async {
    try {
      await _wifiDirect.discoverPeers();
    } catch (e) {
      debugPrint('Wi-Fi Direct discovery failed: $e');
    }
  }

  /// Explicitly disconnect from the current Wi-Fi Direct group.
  Future<void> disconnectWifiDirect() async {
    try {
      await _wifiDirect.removeGroup();
      _isGroupFormed = false;
      _isConnecting = false;
    } catch (e) {
      debugPrint('Disconnect failed: $e');
    }
  }

  Future<void> sendFile(PeerDevice peer, String filePath) async {
    try {
      await _transfer.sendFile(
        peer: peer,
        filePath: filePath,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _addPeer(PeerDevice peer) {
    debugPrint('ADDING PEER: ${peer.name} ip=${peer.ip}');

    final updated = [
      ...state.peers.where((p) => p.id != peer.id),
      peer,
    ];

    state = state.copyWith(
      peers: updated,
    );

    debugPrint('STATE PEERS = ${state.peers.length}');
  }

  void _removePeer(String peerId) {
    final updated =
    state.peers.where((p) => p.id != peerId).toList();

    state = state.copyWith(
      peers: updated,
    );
  }

  String get myDeviceId => _discovery.deviceId;
  String get myDeviceName => _discovery.deviceName;

  @override
  void dispose() {
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