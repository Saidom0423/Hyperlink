import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/peer_device.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/network_provider.dart';
import '../services/profile_service.dart';
import 'chat_screen.dart';
import 'profile_setup_screen.dart';
import 'wifi_direct_screen.dart';
import '../services/backup_service.dart';
import '../services/peer_name_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final network = ref.watch(networkProvider);
    final chatState = ref.watch(chatProvider);

    // 1. Check if profile setup is done
    if (!ProfileService.isProfileSetup) {
      return const ProfileSetupScreen();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter peers/contacts based on search query
    final allPeers = network.peers;
    final activeChats = chatState.conversations.keys.map((peerId) {
      return allPeers.firstWhere(
        (p) => p.id == peerId,
        orElse: () => PeerDevice(
          id: peerId,
          name: PeerNameService.get(peerId, fallback: 'Contact'),
          ip: '',
          port: 8765,
          publicKey: '',
          hops: -1,
        ),
      );
    }).toList();

    final filteredPeers = allPeers.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery);
      return matchesSearch;
    }).toList()
      ..sort((a, b) {
        if (a.hops != -1 && b.hops == -1) return -1;
        if (a.hops == -1 && b.hops != -1) return 1;
        return a.name.compareTo(b.name);
      });

    final filteredChats = activeChats.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery);
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hyperlink',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            Text(
              'Offline Chat • ${ProfileService.currentProfile?.name}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (network.isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering_rounded),
            tooltip: 'Wi-Fi Direct Status',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WifiDirectScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sync Contacts',
            onPressed: () async {
              await ref.read(networkProvider.notifier).syncContactsAndInitialize();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contacts synced successfully')),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onSelected: (value) async {
              if (value == 'backup') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Backing up chat history...'),
                      ],
                    ),
                    duration: Duration(days: 1),
                  ),
                );

                final success = await BackupService.backupDatabase();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Backup saved to Downloads/Hyperlink/'
                            : 'Failed to create database backup',
                      ),
                    ),
                  );
                }
              } else if (value == 'restore') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Restore Chat History?'),
                    content: const Text(
                      'This will automatically look for your backup in Downloads/Hyperlink/ and restore all your chats in one click.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Restore', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Restoring database...'),
                        ],
                      ),
                      duration: Duration(days: 1),
                    ),
                  );

                  final success = await BackupService.restoreDatabase();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    if (success) {
                      await ref.read(chatProvider.notifier).reloadChatHistory();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat history restored successfully!')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to restore chat history')),
                      );
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Backup Chats'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.settings_backup_restore_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Restore Chats'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Builder(builder: (context) {
                final totalUnread = chatState.conversations.entries.fold(0, (sum, entry) {
                  return sum + entry.value.where((m) => !m.isMe && m.status != MessageStatus.read).length;
                });
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Chats'),
                    if (totalUnread > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          totalUnread > 99 ? '99+' : '$totalUnread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ),
            const Tab(text: 'Contacts'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Inline file transfer progress
          if (network.transfer.activeFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colorScheme.primaryContainer.withOpacity(0.4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.swap_horizontal_circle_outlined, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          network.transfer.activeFile!.startsWith('[Relaying]')
                              ? network.transfer.activeFile!
                              : 'File transfer in progress: ${network.transfer.activeFile}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Text(
                        '${(network.transfer.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: network.transfer.progress,
                    backgroundColor: colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              ),
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. CHATS TAB
                filteredChats.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No active conversations',
                        subtitle: 'Go to Contacts to start chatting with nearby friends.',
                        colorScheme: colorScheme,
                        theme: theme,
                      )
                    : ListView.separated(
                        itemCount: filteredChats.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
                        itemBuilder: (ctx, i) {
                          final peer = filteredChats[i];
                          final messages = chatState.messagesFor(peer.id);
                          final lastMsg = messages.isNotEmpty ? messages.last : null;
                          final unread = messages.where((m) => !m.isMe && m.status != MessageStatus.read).length;
                          final isOnline = peer.hops != -1;

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: colorScheme.primaryContainer,
                                  child: Text(
                                    peer.name.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimaryContainer,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: colorScheme.surface, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              peer.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              () {
                                if (lastMsg == null) {
                                  return isOnline ? 'Tap to chat' : 'Offline';
                                }
                                final c = lastMsg.content;
                                if (c.startsWith('[Image] ')) {
                                  return '📷 Photo';
                                } else if (c.startsWith('[File] ')) {
                                  return '📎 ${c.substring(7).split('/').last}';
                                }
                                return c;
                              }(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (lastMsg != null)
                                  Text(
                                    '${lastMsg.timestamp.hour.toString().padLeft(2, "0")}:${lastMsg.timestamp.minute.toString().padLeft(2, "0")}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                if (unread > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(peer: peer),
                                ),
                              );
                            },
                            onLongPress: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Delete Chat with ${peer.name}?'),
                                  content: const Text('This will delete this conversation and all its history permanently.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(chatProvider.notifier).deleteConversation(peer.id);
                              }
                            },
                          );
                        },
                      ),

                // 2. CONTACTS TAB
                filteredPeers.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.contacts_outlined,
                        title: 'No contacts found',
                        subtitle: 'Please sync contacts or make sure permission is granted.',
                        colorScheme: colorScheme,
                        theme: theme,
                      )
                    : ListView.separated(
                        itemCount: filteredPeers.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
                        itemBuilder: (ctx, i) {
                          final peer = filteredPeers[i];
                          final isOnline = peer.hops != -1;

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isOnline
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surfaceContainerHighest,
                                  child: Text(
                                    peer.name.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isOnline
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: colorScheme.surface, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              peer.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isOnline
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            subtitle: Text(
                              isOnline
                                  ? (peer.hops <= 1
                                      ? 'Online • Direct link'
                                      : 'Online • Relayed (${peer.hops - 1} hops)')
                                  : 'Offline',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isOnline
                                    ? Colors.green.shade700
                                    : colorScheme.onSurfaceVariant.withOpacity(0.6),
                              ),
                            ),
                            trailing: isOnline
                                ? Icon(Icons.chat_bubble_outline, color: colorScheme.primary, size: 20)
                                : null,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(peer: peer),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Switch to contacts tab
          _tabController.animateTo(1);
        },
        child: const Icon(Icons.message_rounded),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}