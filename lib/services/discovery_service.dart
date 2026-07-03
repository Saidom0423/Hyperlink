import 'package:logger/logger.dart';
import '../models/peer_device.dart';
import 'profile_service.dart';

class DiscoveryService {
  final Logger _log = Logger();

  String get deviceId => ProfileService.currentProfile?.hashedPhone ?? 'unknown_device';
  String get deviceName => ProfileService.currentProfile?.name ?? 'Unknown Profile';

  final void Function(PeerDevice peer) onPeerFound;
  final void Function(String peerId) onPeerLost;

  DiscoveryService({
    required this.onPeerFound,
    required this.onPeerLost,
  });

  Future<void> start() async {
    _log.i('Discovery Service started (coordinating with background WFD)');
  }

  Future<void> stop() async {
    _log.i('Discovery Service stopped');
  }
}