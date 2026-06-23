import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/network_provider.dart';
import '../models/peer_device.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final network = ref.watch(networkProvider);
    final notifier = ref.read(networkProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('hyperlink'),
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
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Text(
              network.isScanning
                  ? 'Scanning for nearby devices...'
                  : 'Tap scan to find devices',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // Error
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
              itemBuilder: (ctx, i) =>
                  _PeerTile(peer: network.peers[i]),
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
}

class _PeerTile extends StatelessWidget {
  final PeerDevice peer;

  const _PeerTile({
    required this.peer,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _showSendOptions(context),
      leading: CircleAvatar(
        backgroundColor:
        Theme.of(context).colorScheme.primaryContainer,
        child: Text(peer.name[0].toUpperCase()),
      ),
      title: Text(peer.name),
      subtitle: Text(
        peer.hops == 0
            ? '${peer.ip}:${peer.port} • direct'
            : '${peer.hops} hop${peer.hops > 1 ? "s" : ""} away',
      ),
      trailing: Chip(
        label: Text(peer.status.name),
        backgroundColor: peer.status == PeerStatus.connected
            ? Colors.green.shade100
            : Colors.grey.shade200,
      ),
    );
  }

  void _showSendOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.send),
              title: Text('Send file to ${peer.name}'),
              subtitle: const Text('Pick a file to send'),
              onTap: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'File picker coming next - transfer service ready!',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}