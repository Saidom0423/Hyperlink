import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer_device.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';

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
  }) => TransferState(
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
  }) => NetworkState(
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
    _transfer.startServer();
  }

  Future<void> startScanning() async {
    state = state.copyWith(isScanning: true, error: null);
    try {
      await _discovery.start();
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  Future<void> stopScanning() async {
    await _discovery.stop();
    state = state.copyWith(isScanning: false);
  }

  Future<void> sendFile(PeerDevice peer, String filePath) async {
    try {
      await _transfer.sendFile(peer: peer, filePath: filePath);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _addPeer(PeerDevice peer) {
    final updated = [...state.peers.where((p) => p.id != peer.id), peer];
    state = state.copyWith(peers: updated);
  }

  void _removePeer(String peerId) {
    final updated = state.peers.where((p) => p.id != peerId).toList();
    state = state.copyWith(peers: updated);
  }

  String get myDeviceId => _discovery.deviceId;
  String get myDeviceName => _discovery.deviceName;

  @override
  void dispose() {
    _discovery.stop();
    _transfer.stopServer();
    super.dispose();
  }
}

final networkProvider =
StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  return NetworkNotifier();
});