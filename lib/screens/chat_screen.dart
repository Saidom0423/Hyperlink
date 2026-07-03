import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/peer_device.dart';
import '../providers/chat_provider.dart';
import '../providers/network_provider.dart';
import '../services/file_service.dart';
import '../services/peer_name_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final PeerDevice peer;

  const ChatScreen({required this.peer, super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  bool _pickingFile = false;

  @override
  void initState() {
    super.initState();
    PeerNameService.save(widget.peer.id, widget.peer.name);
    // Mark messages read when entering chat
    Future.microtask(() {
      ref.read(chatProvider.notifier).markMessagesAsRead(widget.peer.id);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      final network = ref.read(networkProvider);
      final freshPeer = network.peers.firstWhere(
        (p) => p.id == widget.peer.id,
        orElse: () => widget.peer,
      );
      final networkNotifier = ref.read(networkProvider.notifier);
      await ref.read(chatProvider.notifier).sendMessage(
            peer: freshPeer,
            content: text,
            myId: networkNotifier.myDeviceId,
            myName: networkNotifier.myDeviceName,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    _scrollToBottom();
  }

  Future<void> _pickAndSendFile() async {
    if (_pickingFile) return;
    
    final activeFile = ref.read(networkProvider).transfer.activeFile;
    if (activeFile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A file transfer is already in progress.')),
      );
      return;
    }

    setState(() => _pickingFile = true);
    try {
      final path = await FileService.pickFile();
      if (path == null || !mounted) return;

      final fileName = path.split('/').last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Encrypting and sending $fileName...')),
      );

      final network = ref.read(networkProvider);
      final freshPeer = network.peers.firstWhere(
        (p) => p.id == widget.peer.id,
        orElse: () => widget.peer,
      );

      final networkNotifier = ref.read(networkProvider.notifier);
      await ref.read(chatProvider.notifier).sendFileMessage(
            peer: freshPeer,
            filePath: path,
            myId: networkNotifier.myDeviceId,
            myName: networkNotifier.myDeviceName,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File transfer failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pickingFile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync latest peer status from network state
    final network = ref.watch(networkProvider);
    final freshPeer = network.peers.firstWhere(
      (p) => p.id == widget.peer.id,
      orElse: () => widget.peer,
    );

    final messages = ref.watch(chatProvider).messagesFor(freshPeer.id);

    // Scroll and mark messages as read when messages update
    ref.listen(chatProvider, (_, __) {
      ref.read(chatProvider.notifier).markMessagesAsRead(freshPeer.id);
      _scrollToBottom();
    });

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isDirect = freshPeer.hops == 1;
    final isOnline = freshPeer.hops != -1;
    final displayHops = isDirect ? 0 : freshPeer.hops - 1;

    String hopLabel = 'Offline';
    if (isOnline) {
      hopLabel = isDirect
          ? 'Online • Direct link'
          : 'Online • $displayHops hop${displayHops > 1 ? "s" : ""} via MANET';
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerHigh,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              freshPeer.name,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              hopLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOnline ? Colors.green.shade700 : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline
                  ? (isDirect ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15))
                  : Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline
                      ? (isDirect ? Icons.wifi_rounded : Icons.hub_rounded)
                      : Icons.wifi_off_rounded,
                  size: 14,
                  color: isOnline
                      ? (isDirect ? Colors.green : Colors.orange)
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? (isDirect ? 'P2P' : 'MANET') : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOnline
                        ? (isDirect ? Colors.green : Colors.orange)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Chat History?'),
                    content: const Text('This will delete all messages in this chat permanently.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(chatProvider.notifier).clearConversation(freshPeer.id);
                }
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Chat?'),
                    content: const Text('This will delete this conversation and all its history.'),
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
                  await ref.read(chatProvider.notifier).deleteConversation(freshPeer.id);
                  if (context.mounted) {
                    Navigator.pop(context); // Go back to Home
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Clear History'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Chat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // E2EE Encryption banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: colorScheme.primaryContainer.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  'Messages and files are end-to-end encrypted.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Message list
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(colorScheme, freshPeer)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final showDate = i == 0 ||
                          !_sameDay(messages[i - 1].timestamp, msg.timestamp);
                      return Column(
                        children: [
                          if (showDate) _buildDateChip(msg.timestamp, colorScheme),
                          _buildBubble(msg, colorScheme, theme, freshPeer),
                        ],
                      );
                    },
                  ),
          ),

          // Input bar
          _buildInputBar(colorScheme, theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, PeerDevice peer) {
    final isOnline = peer.hops != -1;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Say hi to ${peer.name}!',
            style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            isOnline
                ? (peer.hops <= 1
                    ? 'Connected directly via Wi-Fi Direct'
                    : 'Connected via MANET (${peer.hops - 1} hops)')
                : 'Offline. Messages will queue and send once in range.',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(DateTime dt, ColorScheme cs) {
    final now = DateTime.now();
    String label;
    if (_sameDay(dt, now)) {
      label = 'Today';
    } else if (_sameDay(dt, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = '${dt.day}/${dt.month}/${dt.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage msg, PeerDevice peer) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Message Options',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(ctx);
                String textToCopy = msg.content;
                if (msg.content.startsWith('[Image] ')) {
                  textToCopy = msg.content.substring(8);
                } else if (msg.content.startsWith('[File] ')) {
                  textToCopy = msg.content.substring(7);
                }
                Clipboard.setData(ClipboardData(text: textToCopy));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Delete Message?'),
                    content: const Text('This will delete this message from your device history.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(chatProvider.notifier).deleteMessage(peer.id, msg.id);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(
      ChatMessage msg, ColorScheme cs, ThemeData theme, PeerDevice peer) {
    final isMe = msg.isMe;
    final bubbleColor =
        isMe ? cs.primary : cs.surfaceContainerHigh;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;

    final time =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    final isFileOrImage = msg.content.startsWith('[Image] ') || msg.content.startsWith('[File] ');

    Widget bodyWidget;
    if (msg.content.startsWith('[Image] ')) {
      final path = msg.content.substring(8);
      bodyWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: File(path).existsSync()
                ? Image.file(
                    File(path),
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFileErrorPlaceholder(cs, path),
                  )
                : _buildFileErrorPlaceholder(cs, path),
          ),
          const SizedBox(height: 6),
          Text(
            path.split('/').last,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (msg.content.startsWith('[File] ')) {
      final path = msg.content.substring(7);
      final fileName = path.split('/').last;
      bodyWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, color: isMe ? cs.onPrimary : cs.primary, size: 36),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Tap to view path',
                  style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      bodyWidget = Text(msg.content, style: TextStyle(fontSize: 15, color: textColor));
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, peer),
        onTap: () {
          if (isFileOrImage) {
            final prefixLen = msg.content.startsWith('[Image] ') ? 8 : 7;
            final path = msg.content.substring(prefixLen);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File location: $path'),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: path));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path copied to clipboard')),
                    );
                  },
                ),
              ),
            );
          }
        },
        child: Container(
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isMe ? 60 : 0,
            right: isMe ? 0 : 60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(msg.senderName,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.primary)),
                ),
              bodyWidget,
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.hops > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.hub_rounded,
                          size: 10, color: textColor.withOpacity(0.6)),
                    ),
                  Text(time,
                      style: TextStyle(
                          fontSize: 10, color: textColor.withOpacity(0.7))),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _statusIcon(msg.status, textColor, cs),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileErrorPlaceholder(ColorScheme cs, String path) {
    return Container(
      width: 150,
      height: 120,
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_rounded, color: cs.outline, size: 36),
            const SizedBox(height: 4),
            const Text(
              'Image file offline',
              style: TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(MessageStatus status, Color color, ColorScheme cs) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule, size: 12, color: color.withOpacity(0.6));
      case MessageStatus.sent:
        return Icon(Icons.check, size: 12, color: color.withOpacity(0.6));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 12, color: color.withOpacity(0.6));
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 12, color: Colors.red.shade300);
    }
  }

  Widget _buildInputBar(ColorScheme cs, ThemeData theme) {
    return Container(
      color: cs.surfaceContainerHigh,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file_rounded),
              onPressed: _pickAndSendFile,
              tooltip: 'Send File',
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(12),
                        minimumSize: Size.zero,
                      ),
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
