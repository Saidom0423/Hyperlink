import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/network_provider.dart';
import '../services/wifi_direct_service.dart';

class WifiDirectScreen extends ConsumerStatefulWidget {
  const WifiDirectScreen({super.key});

  @override
  ConsumerState<WifiDirectScreen> createState() => _WifiDirectScreenState();
}

class _WifiDirectScreenState extends ConsumerState<WifiDirectScreen> {
  List<Map<String, String>> _peers = [];
  Map<String, dynamic> _connectionInfo = {};
  bool _connecting = false;
  bool _discovering = false;
  String? _connectingAddress;
  String _status = 'Starting Wi-Fi Direct discovery...';

  // Saved so we can restore NetworkNotifier's callbacks on dispose
  void Function(List<Map<String, String>>)? _savedOnPeersChanged;
  void Function(Map<String, dynamic>)? _savedOnConnectionChanged;

  @override
  void initState() {
    super.initState();

    // Layer our local UI callbacks on top of NetworkNotifier's global ones.
    final prevPeersChanged = WifiDirectService.onPeersChanged;
    _savedOnPeersChanged = prevPeersChanged;
    WifiDirectService.onPeersChanged = (peers) {
      prevPeersChanged?.call(peers); // keep NetworkNotifier updated
      if (!mounted) return;
      setState(() {
        _peers = peers;
        if (peers.isNotEmpty) {
          _status = '${peers.length} peer(s) found';
        }
      });
    };

    final prevConnectionChanged = WifiDirectService.onConnectionChanged;
    _savedOnConnectionChanged = prevConnectionChanged;
    WifiDirectService.onConnectionChanged = (info) {
      prevConnectionChanged?.call(info); // keep NetworkNotifier updated
      if (!mounted) return;
      setState(() {
        _connectionInfo = info;
        _connecting = false;
        _connectingAddress = null;
        if (info['groupFormed'] == true) {
          _status = info['isGroupOwner'] == true
              ? ' Connected — You are Group Owner (IP: ${info['groupOwnerIp']})'
              : ' Connected — GO IP: ${info['groupOwnerIp']}';
        } else {
          _status = 'Disconnected';
        }
      });
    };

    // Auto-start discovery immediately — no role selection needed
    _discoverPeers();
  }

  @override
  void dispose() {
    // Restore the NetworkNotifier callbacks so WFD events keep flowing
    // to the provider after this screen is popped.
    WifiDirectService.onPeersChanged = _savedOnPeersChanged;
    WifiDirectService.onConnectionChanged = _savedOnConnectionChanged;
    super.dispose();
  }

  Future<void> _discoverPeers() async {
    setState(() {
      _discovering = true;
      _status = 'Scanning for nearby devices...';
    });
    try {
      // Use the provider's safe discovery method that doesn't touch groups
      await ref.read(networkProvider.notifier).startWifiDirectDiscovery();
      if (!mounted) return;
      setState(() {
        _discovering = false;
        if (_peers.isEmpty) {
          _status = 'Discovery active — waiting for peers...';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _discovering = false;
        _status = 'Discovery failed: $e';
      });
    }
  }

  Future<void> _connect(String address, String name) async {
    if (_connecting) return;
    setState(() {
      _connecting = true;
      _connectingAddress = address;
      _status = 'Connecting to $name...';
    });
    try {
      final wfd = WifiDirectService();
      await wfd.connectPeer(address);
      if (!mounted) return;
      setState(() => _status = 'Connection request sent to $name. Please accept on their device.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _connectingAddress = null;
        _status = 'Connect failed: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await ref.read(networkProvider.notifier).disconnectWifiDirect();
      if (!mounted) return;
      setState(() {
        _connectionInfo = {};
        _peers = [];
        _status = 'Disconnected';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Disconnect failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupFormed = _connectionInfo['groupFormed'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Direct'),
        actions: [
          if (groupFormed)
            TextButton(
              onPressed: _disconnect,
              child: const Text(
                'Disconnect',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: groupFormed
                  ? Colors.green.shade50
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: groupFormed ? Colors.green.shade300 : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_connecting || _discovering)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (groupFormed) ...[
                  const SizedBox(height: 8),
                  Text('Group Owner IP: ${_connectionInfo['groupOwnerIp']}'),
                  Text(
                    'Your role: ${_connectionInfo['isGroupOwner'] == true ? "Group Owner" : "Client"}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Both devices can send & receive files.',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Single discover button (replaces the old Create Group / Scan pair)
          if (!groupFormed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _discovering ? null : _discoverPeers,
                  icon: const Icon(Icons.wifi_find),
                  label: Text(_discovering ? 'Scanning...' : 'Discover Peers'),
                ),
              ),
            ),

          // Peers list
          Expanded(
            child: _peers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_find, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          groupFormed
                              ? 'Connected — no other peers visible'
                              : 'Searching for nearby devices...',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (!groupFormed) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Make sure the other device also has the app open.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _peers.length,
                    itemBuilder: (ctx, i) {
                      final peer = _peers[i];
                      final addr = peer['address'] ?? '';
                      final name = peer['name'] ?? 'Unknown';
                      final isConnecting = _connecting && _connectingAddress == addr;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(addr),
                          trailing: isConnecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : groupFormed
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : FilledButton(
                                      onPressed: () => _connect(addr, name),
                                      child: const Text('Connect'),
                                    ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}