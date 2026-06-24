import 'dart:convert';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:nsd/nsd.dart';
import 'package:uuid/uuid.dart';

import '../models/peer_device.dart';

class DiscoveryService {
  static const String _serviceType = '_hyperlink._tcp';
  static const int _servicePort = 8765;

  final Logger _log = Logger();
  final NetworkInfo _networkInfo = NetworkInfo();

  Registration? _registration;
  Discovery? _discovery;

  final String deviceId = const Uuid().v4();

  late String deviceName;

  String? _localIp;

  final void Function(PeerDevice peer) onPeerFound;
  final void Function(String peerId) onPeerLost;

  DiscoveryService({
    required this.onPeerFound,
    required this.onPeerLost,
  });

  Future<void> _initDeviceName() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP() ?? '';

      deviceName = 'Android-${ip.split('.').last}';
    } catch (_) {
      deviceName =
      'Android-${DateTime.now().millisecondsSinceEpoch % 9999}';
    }
  }

  Future<void> start() async {
    await _initDeviceName();

    _localIp = await _networkInfo.getWifiIP();

    if (_localIp == null) {
      _log.w('No Wi-Fi IP — discovery skipped');
      return;
    }

    await _advertise();
    await _scan();

    _log.i('Discovery started on $_localIp:$_servicePort');
  }

  Future<void> stop() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }

    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }

    _log.i('Discovery stopped');
  }

  Future<void> _advertise() async {
    final service = Service(
      name: deviceName,
      type: _serviceType,
      port: _servicePort,
      txt: {
        'id': utf8.encode(deviceId),
        'name': utf8.encode(deviceName),
        'ip': utf8.encode(_localIp!),
      },
    );

    _registration = await register(service);

    _log.i('Registered service: ${service.name}');
  }

  Future<void> _scan() async {
    _discovery = await startDiscovery(_serviceType);

    _discovery!.addServiceListener((service, status) async {
      if (status == ServiceStatus.found) {
        await _onServiceFound(service);
      } else if (status == ServiceStatus.lost) {
        _onServiceLost(service);
      }
    });
  }

  Future<void> _onServiceFound(Service service) async {
    try {
      final resolved = await resolve(service);

      final txt = resolved.txt ?? {};

      final id = _decodeTxt(txt['id']);
      final name = _decodeTxt(txt['name']);
      final ip = _decodeTxt(txt['ip']);

      if (id == null || id == deviceId) {
        return;
      }

      final peer = PeerDevice(
        id: id,
        name: name ?? resolved.name ?? 'Unknown Device',
        ip: ip ?? '',
        port: resolved.port ?? _servicePort,
        publicKey: '',
        hops: 0,
        status: PeerStatus.discovered,
      );

      _log.i(
        'Peer found: ${peer.name} @ ${peer.ip}:${peer.port}',
      );

      onPeerFound(peer);
    } catch (e) {
      _log.e('Failed to resolve service: $e');
    }
  }

  void _onServiceLost(Service service) {
    _log.i('Peer lost: ${service.name}');
    onPeerLost(service.name ?? '');
  }

  String? _decodeTxt(Uint8List? bytes) {
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }
}