import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer_device.dart';
import '../providers/network_provider.dart';
import '../services/file_service.dart';
import 'wifi_direct_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _lastReceivedName;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(networkProvider.notifier).startScanning();
    });
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkProvider);
    debugPrint(
      'HOME SCREEN PEERS = ${network.peers.length}',
    );
    final notifier = ref.read(networkProvider.notifier);

    final receivedName = network.transfer.lastReceivedName;
    if (receivedName != null && receivedName != _lastReceivedName) {
      _lastReceivedName = receivedName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received: $receivedName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hyperlink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_find),
            tooltip: 'WiFi Direct',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WifiDirectScreen()),
            ),
          ),
          if (network.isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  network.isScanning
                      ? 'Searching for nearby devices...'
                      : '${network.peers.length} device(s) found',
                ),
                if (network.isScanning)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),

          // Transfer progress
          if (network.transfer.activeFile != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sending: ${network.transfer.activeFile} '
                        '(${(network.transfer.progress * 100).toStringAsFixed(0)}%)',
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: network.transfer.progress),
                ],
              ),
            ),

          if (network.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                network.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          // Peer list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notifier.startScanning(),
              child: network.peers.isEmpty
                  ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.devices_other, size: 64,
                      color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Scanning for nearby devices...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Devices will appear here automatically via Wi-Fi Direct.',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                itemCount: network.peers.length,
                itemBuilder: (ctx, i) => _buildPeerTile(
                  context,
                  network.peers[i],
                  notifier,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeerTile(
      BuildContext context,
      PeerDevice peer,
      NetworkNotifier notifier,
      ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(peer.name),
        subtitle: Text(
          peer.hops == 0
              ? '${peer.ip} • direct'
              : '${peer.hops} hop${peer.hops > 1 ? "s" : ""} away',
        ),
        trailing: FilledButton.icon(
          onPressed: () => _sendFile(peer, notifier),
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Send'),
        ),
      ),
    );
  }

  Future<void> _sendFile(
      PeerDevice peer,
      NetworkNotifier notifier,
      ) async {
    // If the peer's IP is empty, pick the file first, save it as pending, and auto-connect
    if (peer.ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening file picker...'),
          duration: Duration(seconds: 1),
        ),
      );

      final path = await FileService.pickFile();
      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
        return;
      }

      final fileName = path.split('/').last;
      notifier.setPendingTransfer(path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connecting to ${peer.name} to send $fileName... Please accept the prompt on their screen.'),
          duration: const Duration(seconds: 6),
        ),
      );

      await notifier.connectToPeer(peer);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening file picker...'),
        duration: Duration(seconds: 1),
      ),
    );

    final path = await FileService.pickFile();

    if (!mounted) return;

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected')),
      );
      return;
    }

    final fileName = path.split('/').last;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sending $fileName to ${peer.name}...')),
    );

    try {
      await notifier.sendFile(peer, path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(' Sent $fileName to ${peer.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(' Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}