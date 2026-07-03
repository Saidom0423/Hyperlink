import 'package:flutter/services.dart';

class WifiDirectService {
  static const MethodChannel _channel =
  MethodChannel('com.hyperlink/wifi_direct');

  static void Function(List<Map<String, String>>)? onPeersChanged;
  static void Function(Map<String, dynamic>)? onConnectionChanged;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPeersChanged':
          final peers = (call.arguments as List)
              .map((e) => Map<String, String>.from(e as Map))
              .toList();
          onPeersChanged?.call(peers);
          break;
        case 'onConnectionChanged':
          final info = Map<String, dynamic>.from(call.arguments as Map);
          onConnectionChanged?.call(info);
          break;
      }
    });
  }

  Future<void> discoverPeers() async {
    await _channel.invokeMethod('discoverPeers');
  }

  Future<List<Map<String, String>>> getPeers() async {
    final peers = await _channel.invokeMethod<List<dynamic>>('getPeers');
    return (peers ?? [])
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<bool> connectPeer(String address) async {
    final result = await _channel.invokeMethod<bool>(
      'connectPeer',
      {'address': address},
    );
    return result ?? false;
  }

  Future<bool> createGroup() async {
    final result = await _channel.invokeMethod<bool>('createGroup');
    return result ?? false;
  }

  Future<void> removeGroup() async {
    await _channel.invokeMethod('removeGroup');
  }

  Future<Map<String, dynamic>> getConnectionInfo() async {
    final info = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getConnectionInfo',
    );
    return info != null ? Map<String, dynamic>.from(info) : {};
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
  }

  Future<bool> startAdvertising(String hash) async {
    final result = await _channel.invokeMethod<bool>(
      'startAdvertising',
      {'hash': hash},
    );
    return result ?? false;
  }

  Future<bool> stopAdvertising() async {
    final result = await _channel.invokeMethod<bool>('stopAdvertising');
    return result ?? false;
  }

  Future<bool> startServiceDiscovery() async {
    final result = await _channel.invokeMethod<bool>('startServiceDiscovery');
    return result ?? false;
  }

  Future<bool> stopServiceDiscovery() async {
    final result = await _channel.invokeMethod<bool>('stopServiceDiscovery');
    return result ?? false;
  }

  Future<void> clearDiscoveredPeers() async {
    await _channel.invokeMethod('clearDiscoveredPeers');
  }

  Future<bool> isWifiEnabled() async {
    final result = await _channel.invokeMethod<bool>('isWifiEnabled');
    return result ?? false;
  }

  Future<void> openWifiSettings() async {
    await _channel.invokeMethod('openWifiSettings');
  }
}