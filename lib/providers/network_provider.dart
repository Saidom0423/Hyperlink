import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer_device.dart';
import '../services/discovery_service.dart';

// ── State ────────────────────────────────────────────────────────────────────

class NetworkState {
  final List<PeerDevice> peers;
  final bool isScanning;
  final String? error;

  const NetworkState({
    this.peers = const [],
    this.isScanning = false,
    this.error,
  });

  NetworkState copyWith({
    List<PeerDevice>? peers,
    bool? isScanning,
    String? error,
  }) =>
      NetworkState(
        peers: peers ?? this.peers,
        isScanning: isScanning ?? this.isScanning,
        error: error ?? this.error,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class NetworkNotifier extends StateNotifier<NetworkState> {
  late final DiscoveryService _discovery;

  NetworkNotifier() : super(const NetworkState()) {
    _discovery = DiscoveryService(
      onPeerFound: _addPeer,
      onPeerLost: _removePeer,
    );
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

  void _addPeer(PeerDevice peer) {
    final updated = [...state.peers.where((p) => p.id != peer.id), peer];
    state = state.copyWith(peers: updated);
  }

  void _removePeer(String peerId) {
    // peerId here is name-based until we improve the lost callback
    final updated = state.peers.where((p) => p.id != peerId).toList();
    state = state.copyWith(peers: updated);
  }

  String get myDeviceId => _discovery.deviceId;
  String get myDeviceName => _discovery.deviceName;

  @override
  void dispose() {
    _discovery.stop();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final networkProvider =
StateNotifierProvider<NetworkNotifier, NetworkState>((ref) {
  return NetworkNotifier();
});