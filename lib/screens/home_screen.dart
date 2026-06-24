
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer_device.dart';
import '../providers/network_provider.dart';
import '../services/file_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _lastReceivedName;

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkProvider);
    final notifier = ref.read(networkProvider.notifier);

    // Show snackbar when file received
    final receivedName = network.transfer.lastReceivedName;
    if (receivedName != null && receivedName != _lastReceivedName) {
      _lastReceivedName = receivedName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Received: $receivedName'),
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
          if (network.isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
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
            child: Text(
              network.isScanning
                  ? 'Scanning for nearby devices...'
                  : 'Tap scan to find devices',
            ),
          ),

          // Transfer progress bar
          if (network.transfer.activeFile != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sending: ${network.transfer.activeFile}'),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: network.transfer.progress,
                  ),
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
            child: network.peers.isEmpty
                ? const Center(child: Text('No devices found yet'))
                : ListView.builder(
              itemCount: network.peers.length,
              itemBuilder: (ctx, i) => _buildPeerTile(
                context, network.peers[i], notifier,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: network.isScanning
            ? () => notifier.stopScanning()
            : () => notifier.startScanning(),
        icon: Icon(network.isScanning ? Icons.stop : Icons.radar),
        label: Text(network.isScanning ? 'Stop' : 'Scan'),
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
          onPressed: () => _sendFile(context, peer, notifier),
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Send'),
        ),
      ),
    );
  }

  Future<void> _sendFile(
      BuildContext context,
      PeerDevice peer,
      NetworkNotifier notifier,
      ) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening file picker...'),
        duration: Duration(seconds: 1),
      ),
    );

    final path = await FileService.pickFile();

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
      }
      return;
    }

    final fileName = path.split('/').last;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sending $fileName to ${peer.name}...')),
      );
    }

    try {
      await notifier.sendFile(peer, path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Sent $fileName to ${peer.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}